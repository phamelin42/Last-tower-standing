"""Dessine à zéro les sprites de tour qui n'ont pas de candidat libre (T11.6, partie 2).

Usage (depuis la racine) : python3 -I tools/dessiner_tours.py

Pixel art procédural, palette proche de Tiny Swords, sans IA ni image existante : chaque tour est
tracée par des rectangles, des ellipses et des lignes sur une grille de 64 × 96, puis agrandie
au plus proche voisin en 128 × 192 (largeur de la tour des Chevaliers). Chaque skin porte une marque
de la couleur du joueur (drapeau, liseré ou bannière) dans le bleu de Tiny Swords, teintable ; sa zone
est écrite dans docs/skins/dessines/marques.json. Pillow (licence HPND, libre) seulement.
"""

import json
from pathlib import Path
from PIL import Image, ImageDraw

RACINE = Path(__file__).resolve().parents[1]
SORTIE = RACINE / "docs" / "skins" / "dessines"
L, H, ECHELLE = 64, 96, 2
CONTOUR = (22, 28, 46, 255)
MARQUE = [(67, 91, 125), (68, 142, 159), (90, 185, 187), (143, 226, 185)]

# (clair, moyen, sombre)
PAL = {
    "pierre": ((190, 195, 205), (150, 155, 168), (100, 105, 122)),
    "granit": ((225, 205, 205), (190, 170, 172), (140, 120, 126)),
    "noire": ((96, 98, 118), (62, 64, 82), (40, 42, 56)),
    "chaude": ((215, 190, 150), (180, 150, 110), (125, 100, 80)),
    "mousse": ((170, 190, 150), (125, 150, 115), (80, 105, 85)),
    "rouge": ((150, 70, 80), (110, 40, 56), (70, 24, 40)),
    "bois": ((218, 181, 112), (180, 131, 85), (134, 99, 83)),
    "or": ((255, 235, 140), (235, 190, 70), (170, 125, 40)),
    "fer": ((220, 225, 235), (170, 178, 190), (110, 118, 134)),
}
OS = (236, 232, 214)
ROUGE = (200, 60, 60)
VERT = (96, 160, 84)
FEU = (250, 150, 40)
JAUNE = (255, 220, 90)
EAU = (90, 170, 215)


class Toile:
    def __init__(self) -> None:
        self.im = Image.new("RGBA", (L, H), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def r(self, x0: int, y0: int, x1: int, y1: int, c: tuple) -> None:
        self.d.rectangle((x0, y0, x1, y1), fill=c)

    def e(self, x0: int, y0: int, x1: int, y1: int, c: tuple, bord: tuple | None = None) -> None:
        self.d.ellipse((x0, y0, x1, y1), fill=c, outline=bord)

    def p(self, x: int, y: int, c: tuple) -> None:
        if 0 <= x < L and 0 <= y < H:
            self.im.putpixel((x, y), c if len(c) == 4 else c + (255,))

    def l(self, pts: list, c: tuple, w: int = 1) -> None:
        self.d.line(pts, fill=c, width=w)

    def poly(self, pts: list, c: tuple) -> None:
        self.d.polygon(pts, fill=c)


def corps(t: Toile, pal: str, bw: int = 30, bh: int = 50, briques: bool = True, plat: bool = False,
          porte: bool = True, base: int = 88) -> dict:
    """Fût, plinthe, créneaux et porte. Retourne la géométrie pour les décors."""
    cl, mo, so = PAL[pal]
    cx = 32
    g = {"cx": cx, "l": cx - bw // 2, "r": cx + bw // 2, "base": base, "top": base - bh, "bw": bw, "pal": pal}
    t.r(g["l"] - 3, base - 6, g["r"] + 3, base, PAL["bois"][1])  # plinthe
    t.r(g["l"] - 3, base - 6, g["l"] - 1, base, PAL["bois"][0])
    t.r(g["l"], g["top"], g["r"], base - 6, mo)
    t.r(g["l"], g["top"], g["l"] + 3, base - 6, cl)
    t.r(g["r"] - 5, g["top"], g["r"], base - 6, so)
    if briques:
        for y in range(g["top"] + 6, base - 6, 6):
            t.l([(g["l"], y), (g["r"], y)], so)
            for x in range(g["l"] + 4 + (y // 6 % 2) * 5, g["r"], 10):
                t.l([(x, y), (x, y + 5)], so)
    if plat:
        t.r(g["l"] - 2, g["top"] - 3, g["r"] + 2, g["top"], cl)
        t.r(g["l"] - 2, g["top"], g["r"] + 2, g["top"] + 1, so)
    else:
        for x in range(g["l"] - 2, g["r"] - 2, 8):
            t.r(x, g["top"] - 6, x + 5, g["top"] + 1, mo)
            t.r(x, g["top"] - 6, x + 5, g["top"] - 5, cl)
    if porte:
        t.r(cx - 4, base - 17, cx + 4, base - 6, PAL["bois"][2])
        t.e(cx - 4, base - 21, cx + 4, base - 13, PAL["bois"][2])
        t.r(cx - 3, base - 16, cx + 3, base - 6, PAL["bois"][1])
    return g


def marque(t: Toile, g: dict, genre: str) -> tuple:
    """Pose la marque de couleur du joueur ; retourne sa zone (x, y, largeur, hauteur) dans la grille."""
    m = Toile()
    c0, c1, c2, c3 = MARQUE
    if genre == "drapeau":
        x, y = g["r"] - 5, g["top"] - 20
        m.l([(x, y), (x, g["top"] - 5)], (90, 70, 70))
        m.poly([(x + 1, y), (x + 13, y + 4), (x + 1, y + 9)], c1)
        m.l([(x + 1, y), (x + 13, y + 4)], c2)
        m.l([(x + 1, y + 9), (x + 13, y + 4)], c0)
    elif genre == "liseré":
        y = g["top"] + 12
        m.r(g["l"], y, g["r"], y + 3, c1)
        m.r(g["l"], y, g["r"], y, c2)
        m.r(g["l"], y + 3, g["r"], y + 3, c0)
    else:  # bannière pendante sur la face
        x, y = g["cx"] - 5, g["top"] + 6
        m.r(x, y, x + 10, y + 15, c1)
        m.poly([(x, y + 15), (x + 5, y + 20), (x + 10, y + 15)], c1)
        m.r(x, y, x + 10, y + 1, c2)
        m.r(x + 4, y + 5, x + 6, y + 10, c3)
    t.im.alpha_composite(m.im)
    return m.im.getchannel("A").getbbox()


# --- décors : chacun reçoit la toile et la géométrie ---

def d_sans_horizon(t, g):
    for y in (g["top"] + 12, g["top"] + 26, g["top"] + 40):
        t.r(g["l"] - 2, y, g["r"] + 2, y + 2, PAL["pierre"][0])
        t.r(g["l"] - 2, y + 2, g["r"] + 2, y + 3, PAL["pierre"][2])
        t.r(g["cx"] - 1, y - 8, g["cx"] + 1, y - 3, PAL["noire"][2])


def d_lame(t, g):
    for y in (g["top"] + 8, g["top"] + 22, g["top"] + 36):
        t.poly([(g["l"], y), (g["l"] - 10, y + 2), (g["l"], y + 5)], PAL["fer"][0])
        t.poly([(g["r"], y), (g["r"] + 10, y + 2), (g["r"], y + 5)], PAL["fer"][1])
    t.poly([(g["cx"] - 3, g["top"] - 6), (g["cx"], g["top"] - 22), (g["cx"] + 3, g["top"] - 6)], PAL["fer"][0])


def d_oeil(t, g):
    t.e(g["cx"] - 11, g["top"] - 16, g["cx"] + 11, g["top"] + 2, OS, (60, 40, 40))
    t.e(g["cx"] - 5, g["top"] - 14, g["cx"] + 5, g["top"] - 2, (180, 70, 70))
    t.e(g["cx"] - 2, g["top"] - 11, g["cx"] + 2, g["top"] - 5, (20, 20, 30))
    t.p(g["cx"] - 3, g["top"] - 12, (255, 255, 255))


def d_nuee(t, g):
    t.e(g["cx"] - 27, g["base"] - 10, g["cx"] + 27, g["base"] + 4, (0, 0, 0, 0), JAUNE)
    t.e(g["cx"] - 22, g["base"] - 7, g["cx"] + 22, g["base"] + 2, (0, 0, 0, 0), (150, 220, 255))
    for i in range(6):
        t.p(g["cx"] - 24 + i * 9, g["base"] - 12 + (i % 2) * 14, (255, 255, 255))


def d_sonore(t, g):
    for k, rad in enumerate((4, 9, 14)):
        t.e(g["cx"] - rad, g["top"] + 22 - rad, g["cx"] + rad, g["top"] + 22 + rad, (0, 0, 0, 0), PAL[g["pal"]][2 - (k % 2)])
    t.e(g["cx"] - 1, g["top"] + 21, g["cx"] + 1, g["top"] + 23, JAUNE)


def d_embuscade(t, g):
    t.e(g["cx"] - 14, g["base"] - 4, g["cx"] + 14, g["base"] + 5, (30, 24, 28))
    for x in (g["l"] - 8, g["l"] - 3, g["r"] + 3, g["r"] + 8):
        t.poly([(x - 2, g["base"] + 2), (x + 3, g["base"] - 14), (x + 4, g["base"] + 2)], PAL["bois"][1])
        t.l([(x + 3, g["base"] - 14), (x + 3, g["base"] - 11)], PAL["bois"][0])
    t.l([(g["l"] - 7, g["base"] - 4), (g["r"] + 7, g["base"] - 4)], (205, 170, 110))


def d_sapeur(t, g):
    for i, (x, y) in enumerate(((g["l"] - 10, g["base"] - 8), (g["l"] + 1, g["base"] - 8), (g["l"] - 5, g["base"] - 20))):
        t.r(x, y, x + 10, y + 11, PAL["bois"][1])
        t.r(x, y + 2, x + 10, y + 3, PAL["fer"][2])
        t.r(x, y + 8, x + 10, y + 9, PAL["fer"][2])
    t.l([(g["l"], g["base"] - 20), (g["l"] + 2, g["base"] - 26)], (90, 70, 70))
    t.p(g["l"] + 2, g["base"] - 27, FEU)


def d_halo(t, g):
    t.e(g["cx"] - 28, g["base"] - 9, g["cx"] + 28, g["base"] + 5, (0, 0, 0, 0), JAUNE)
    for i in range(7):
        x = g["cx"] - 24 + i * 8
        t.poly([(x, g["base"] + 3), (x + 2, g["base"] - 4), (x + 4, g["base"] + 3)], PAL["pierre"][1])


def d_manege(t, g):
    y = g["top"] + 20
    t.r(g["l"] - 14, y, g["r"] + 14, y + 3, PAL["pierre"][1])
    t.r(g["l"] - 14, y, g["r"] + 14, y, PAL["pierre"][0])
    for x in (g["l"] - 14, g["r"] + 11):
        t.e(x - 1, y - 2, x + 5, y + 6, PAL["pierre"][2])
    t.e(g["cx"] - 3, y - 2, g["cx"] + 3, y + 5, PAL["fer"][0])


def d_ascete(t, g):
    pass


def d_puits(t, g):
    t.e(g["cx"] - 22, g["base"] - 6, g["cx"] + 22, g["base"] + 6, PAL["pierre"][2])
    t.e(g["cx"] - 18, g["base"] - 9, g["cx"] + 18, g["base"] + 2, PAL["pierre"][1])
    t.e(g["cx"] - 14, g["base"] - 7, g["cx"] + 14, g["base"], EAU)
    t.r(g["cx"] + 10, g["base"] - 30, g["cx"] + 11, g["base"] - 4, PAL["bois"][2])
    t.r(g["cx"] + 6, g["base"] - 8, g["cx"] + 12, g["base"] - 2, PAL["bois"][1])


def d_dragon(t, g):
    t.e(g["cx"] - 15, g["top"] - 14, g["cx"] + 15, g["top"] + 2, PAL["or"][1])
    for x, y in ((-8, -10), (0, -12), (7, -9), (-3, -6), (5, -5), (-11, -4)):
        t.e(g["cx"] + x - 2, g["top"] + y - 2, g["cx"] + x + 2, g["top"] + y + 2, PAL["or"][0], PAL["or"][2])
    t.p(g["cx"] + 12, g["top"] - 17, (255, 255, 255))


def d_granit(t, g):
    for i in range(40):
        x, y = g["l"] + 2 + (i * 7) % (g["bw"] - 3), g["top"] + 2 + (i * 11) % (g["base"] - g["top"] - 10)
        t.p(x, y, PAL["granit"][2] if i % 2 else (255, 245, 245))


def d_cicatrisee(t, g):
    for x, y in ((g["l"] + 3, g["top"] + 6), (g["cx"] + 1, g["top"] + 20), (g["l"] + 6, g["top"] + 32)):
        t.l([(x, y), (x + 9, y + 9)], PAL["noire"][2], 2)
        t.l([(x + 1, y), (x + 10, y + 9)], PAL["pierre"][0])


def d_nue(t, g):
    pass


def d_faux(t, g):
    for y in (g["top"] + 4, g["top"] + 18, g["top"] + 32):
        for s in (-1, 1):
            x = g["l"] if s < 0 else g["r"]
            t.l([(x, y + 4), (x + s * 7, y + 4)], PAL["bois"][2], 2)
            t.d.arc((x + s * 5 - 6, y - 8, x + s * 5 + 6, y + 6), 200 if s < 0 else 300, 360 if s < 0 else 60, fill=PAL["fer"][0], width=2)


def d_ronces(t, g):
    for i, y in enumerate(range(g["top"] + 2, g["base"] - 8, 5)):
        x0, x1 = (g["l"], g["r"]) if i % 2 else (g["r"], g["l"])
        t.l([(x0, y), (x1, y + 5)], VERT, 2)
        t.p((x0 + x1) // 2, y, (230, 235, 200))
    for x in (g["l"] - 6, g["r"] + 6):
        t.poly([(x - 2, g["base"] + 2), (x, g["base"] - 12), (x + 2, g["base"] + 2)], PAL["bois"][1])


def d_survivante(t, g):
    t.r(g["l"] - 2, g["top"] - 6, g["r"] + 2, g["top"] + 6, (0, 0, 0, 0))
    for x in range(g["l"] - 2, g["r"] + 2, 5):
        t.r(x, g["top"] - 2 - (x * 7) % 6, x + 3, g["top"] + 6, PAL["pierre"][1])
    for x, y in ((-24, 0), (-18, 2), (20, 1), (25, -1)):
        t.r(g["cx"] + x, g["base"] + y - 3, g["cx"] + x + 5, g["base"] + y + 1, PAL["pierre"][2])
    for k, (x, y, r) in enumerate(((0, -14, 5), (-3, -22, 4), (3, -29, 3))):
        t.e(g["cx"] + x - r, g["top"] + y - r, g["cx"] + x + r, g["top"] + y + r, (120, 120, 130, 200))


def d_familiere(t, g):
    for x in (g["l"] + 5, g["r"] - 9, g["cx"] - 2):
        t.l([(x, g["top"] + 7), (x, g["top"] + 24)], PAL["chaude"][2])
    t.r(g["r"] - 12, g["base"] - 14, g["r"] - 6, g["base"] - 8, PAL["bois"][1])
    t.r(g["r"] - 11, g["base"] - 13, g["r"] - 7, g["base"] - 9, JAUNE)


def d_veterane(t, g):
    for x, y, c in ((g["l"] + 4, g["top"] + 24, ROUGE), (g["r"] - 12, g["top"] + 24, EAU), (g["cx"] - 4, g["top"] + 34, JAUNE)):
        t.e(x, y, x + 8, y + 8, c, CONTOUR)
        t.p(x + 4, y + 4, (255, 255, 255))
    t.poly([(g["cx"] - 8, g["top"] - 6), (g["cx"] - 12, g["top"] - 16), (g["cx"] - 5, g["top"] - 8)], OS)
    t.poly([(g["cx"] + 8, g["top"] - 6), (g["cx"] + 12, g["top"] - 16), (g["cx"] + 5, g["top"] - 8)], OS)


def d_comptoir(t, g):
    y = g["top"] - 14
    t.r(g["cx"] - 1, y, g["cx"] + 1, g["top"] - 6, PAL["fer"][2])
    t.l([(g["cx"] - 13, y + 2), (g["cx"] + 13, y + 2)], PAL["fer"][0], 2)
    for s in (-1, 1):
        t.l([(g["cx"] + s * 12, y + 3), (g["cx"] + s * 12, y + 9)], PAL["fer"][2])
        t.e(g["cx"] + s * 12 - 5, y + 9, g["cx"] + s * 12 + 5, y + 13, PAL["or"][1])
    for i, x in enumerate(range(g["l"] + 2, g["r"] - 2, 6)):
        t.r(x, g["base"] - 26, x + 5, g["base"] - 21, ROUGE if i % 2 else OS)


def d_table(t, g):
    t.e(g["cx"] - 26, g["base"] - 12, g["cx"] + 26, g["base"] + 5, PAL["bois"][2])
    t.e(g["cx"] - 23, g["base"] - 10, g["cx"] + 23, g["base"] + 2, PAL["bois"][0])
    for k in range(8):
        x = g["cx"] - 24 + k * 7
        y = g["base"] + 1 + (4 if 1 < k < 6 else 0) - (3 if k in (0, 7) else 0)
        t.r(x, y, x + 3, y + 3, PAL["rouge"][1])


def d_dernier(t, g):
    y = g["top"] - 14
    t.r(g["cx"] - 12, y + 6, g["cx"] + 12, g["top"] - 5, PAL["or"][1])
    for x in (-12, -6, 0, 6, 12):
        t.poly([(g["cx"] + x - 3, y + 6), (g["cx"] + x, y), (g["cx"] + x + 3, y + 6)], PAL["or"][0])
    t.p(g["cx"], y - 2, ROUGE)


def d_tonnerre(t, g):
    for x, y in ((g["l"] + 4, g["top"] + 6), (g["r"] - 12, g["top"] + 24)):
        t.l([(x + 6, y), (x + 2, y + 7), (x + 7, y + 9), (x + 3, y + 18)], JAUNE, 2)
    t.l([(g["cx"], g["top"] - 6), (g["cx"], g["top"] - 24)], PAL["fer"][1])
    t.p(g["cx"] - 3, g["top"] - 26, JAUNE)
    t.p(g["cx"] + 4, g["top"] - 22, (255, 255, 255))


def d_sanguine(t, g):
    for i, x in enumerate(range(g["l"] + 1, g["r"] - 1, 6)):
        t.r(x, g["top"] + 1, x + 4, g["top"] + 22 + (i % 3) * 4, PAL["rouge"][1])
        t.r(x, g["top"] + 1, x, g["top"] + 22 + (i % 3) * 4, PAL["rouge"][0])
        t.e(x, g["top"] + 18 + (i % 3) * 4, x + 4, g["top"] + 25 + (i % 3) * 4, PAL["rouge"][1])


def d_banquier(t, g):
    for x in (g["l"] + 1, g["r"] - 5):
        t.r(x, g["top"] + 6, x + 4, g["base"] - 6, PAL["pierre"][0])
        t.r(x - 1, g["top"] + 4, x + 5, g["top"] + 7, PAL["pierre"][1])
    for x, y in ((g["r"] + 2, g["base"] - 9), (g["r"] + 11, g["base"] - 9), (g["r"] + 6, g["base"] - 19)):
        t.e(x, y, x + 9, y + 10, PAL["chaude"][0], PAL["chaude"][2])
        t.r(x + 3, y - 1, x + 6, y + 1, PAL["bois"][2])


def d_chariot(t, g):
    x = g["r"] + 2
    t.r(x, g["base"] - 14, x + 22, g["base"] - 5, PAL["bois"][1])
    t.r(x, g["base"] - 14, x + 22, g["base"] - 13, PAL["bois"][0])
    for k in range(5):
        t.e(x + 2 + k * 4, g["base"] - 19 + (k % 2) * 2, x + 6 + k * 4, g["base"] - 14, PAL["or"][1])
    for wx in (x + 3, x + 17):
        t.e(wx - 4, g["base"] - 8, wx + 4, g["base"] + 2, PAL["bois"][2], CONTOUR)
        t.p(wx, g["base"] - 3, PAL["bois"][0])


def d_bouclier(t, g):
    dome = Toile()  # couche à part : ImageDraw remplace les pixels au lieu de les mélanger
    dome.e(g["l"] - 8, g["top"] - 16, g["r"] + 8, g["base"] + 4, (130, 210, 255, 70), (170, 230, 255, 200))
    dome.d.arc((g["l"] - 4, g["top"] - 10, g["cx"], g["top"] + 12), 190, 260, fill=(255, 255, 255, 230), width=2)
    t.im.alpha_composite(dome.im)


def d_eternelle(t, g):
    for i in range(14):
        x, y = g["l"] + (i * 5) % g["bw"], g["top"] + (i * 9) % (g["base"] - g["top"] - 8)
        t.r(x, y, x + 3, y + 2, PAL["mousse"][1])
    for x in (g["l"] + 3, g["r"] - 6):
        t.l([(x, g["top"] + 4), (x + 1, g["top"] + 22)], VERT, 2)
    t.r(g["l"] - 2, g["top"] - 8, g["r"] + 2, g["top"] - 5, PAL["mousse"][1])


def d_ossuaire(t, g):
    for k, x in enumerate(range(g["l"] - 16, g["r"] + 10, 9)):
        y = g["base"] - 3 + (k % 2) * 3
        t.e(x, y - 6, x + 7, y + 1, OS, (120, 110, 100))
        t.r(x + 1, y - 1, x + 6, y + 2, OS)
        t.p(x + 2, y - 3, (30, 24, 28))
        t.p(x + 5, y - 3, (30, 24, 28))
    t.l([(g["l"] + 2, g["top"] + 14), (g["r"] - 2, g["top"] + 24)], OS, 2)


def d_zone(t, g):
    t.e(g["cx"] - 27, g["base"] - 9, g["cx"] + 27, g["base"] + 5, (0, 0, 0, 0), FEU)
    t.e(g["cx"] - 17, g["base"] - 5, g["cx"] + 17, g["base"] + 2, (250, 150, 40, 90), FEU)
    for k in range(8):
        x = g["cx"] - 22 + k * 6
        t.p(x, g["base"] - 8 + (k % 2) * 11, JAUNE)


def d_bombe(t, g):
    for x, y, r in ((g["l"] - 9, g["base"] - 3, 6), (g["l"] - 2, g["base"] - 12, 5), (g["r"] + 6, g["base"] - 4, 6)):
        t.e(x - r, y - r, x + r, y + r, (35, 35, 50), CONTOUR)
        t.p(x - 2, y - 2, (120, 120, 140))
        t.l([(x, y - r), (x + 2, y - r - 4)], (205, 170, 110))
        t.p(x + 2, y - r - 5, FEU)
    t.e(g["cx"] - 7, g["top"] - 14, g["cx"] + 7, g["top"] - 1, (35, 35, 50), CONTOUR)
    t.p(g["cx"] - 3, g["top"] - 10, (120, 120, 140))
    t.p(g["cx"] + 1, g["top"] - 16, FEU)


# skin -> (palette, options du corps, décor, genre de marque)
SKINS = {
    "tour_sans_horizon": ("pierre", {"bh": 74, "bw": 26}, d_sans_horizon, "liseré"),
    "tour_lame": ("fer", {}, d_lame, "bannière"),
    "tour_oeil": ("noire", {}, d_oeil, "liseré"),
    "tour_nuee": ("pierre", {}, d_nuee, "drapeau"),
    "tour_sonore": ("chaude", {}, d_sonore, "drapeau"),
    "tour_embuscade": ("bois", {}, d_embuscade, "drapeau"),
    "tour_sapeur": ("pierre", {}, d_sapeur, "drapeau"),
    "tour_halo": ("pierre", {}, d_halo, "bannière"),
    "tour_manege": ("pierre", {}, d_manege, "drapeau"),
    "tour_ascete": ("pierre", {"briques": False, "plat": True, "porte": False}, d_ascete, "liseré"),
    "tour_du_puits": ("pierre", {"bh": 44, "bw": 24, "base": 80}, d_puits, "drapeau"),
    "tour_du_dragon_avare": ("pierre", {}, d_dragon, "bannière"),
    "tour_de_granit": ("granit", {"briques": False}, d_granit, "liseré"),
    "tour_cicatrisee": ("pierre", {}, d_cicatrisee, "drapeau"),
    "tour_nue": ("pierre", {"bw": 20, "bh": 40, "briques": False, "plat": True, "porte": False}, d_nue, "liseré"),
    "tour_a_faux": ("noire", {}, d_faux, "bannière"),
    "tour_de_ronces": ("mousse", {}, d_ronces, "drapeau"),
    "tour_survivante": ("noire", {}, d_survivante, "liseré"),
    "tour_familiere": ("chaude", {}, d_familiere, "drapeau"),
    "tour_veterane": ("pierre", {}, d_veterane, "drapeau"),
    "tour_comptoir": ("chaude", {}, d_comptoir, "liseré"),
    "tour_de_la_table_ronde": ("pierre", {"bw": 28}, d_table, "drapeau"),
    "tour_du_dernier_rempart": ("pierre", {}, d_dernier, "bannière"),
    "tour_tonnerre": ("noire", {}, d_tonnerre, "drapeau"),
    "tour_sanguine": ("noire", {"briques": False}, d_sanguine, "liseré"),
    "tour_du_banquier": ("chaude", {}, d_banquier, "drapeau"),
    "tour_du_chariot": ("pierre", {"bw": 26}, d_chariot, "drapeau"),
    "tour_du_bouclier": ("pierre", {}, d_bouclier, "drapeau"),
    "tour_eternelle": ("mousse", {}, d_eternelle, "liseré"),
    "tour_ossuaire": ("noire", {}, d_ossuaire, "drapeau"),
    # provisoires : leurs défis (zone posée, bombe) ne sont pas encore dans docs/defis.md
    "tour_zone_posee": ("pierre", {}, d_zone, "drapeau"),
    "tour_bombe": ("noire", {}, d_bombe, "liseré"),
}


def dessiner(skin: str) -> tuple[Image.Image, list]:
    pal, opts, decor, genre = SKINS[skin]
    t = Toile()
    opts = dict(opts)
    opts["bh"] = opts.pop("bh", 50)
    g = corps(t, pal, bw=opts.pop("bw", 30), bh=opts.pop("bh"), **opts)
    decor(t, g)
    zone = marque(t, g, genre)
    # contour 1 px autour de tout pixel opaque, puis ombre au sol
    a = t.im.getchannel("A")
    out = t.im.copy()
    for y in range(H):
        for x in range(L):
            if a.getpixel((x, y)) < 100:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < L and 0 <= ny < H and a.getpixel((nx, ny)) >= 100:
                        out.putpixel((x, y), CONTOUR)
                        break
    ombre = Image.new("RGBA", (L, H), (0, 0, 0, 0))
    ImageDraw.Draw(ombre).ellipse((g["cx"] - 24, g["base"] - 3, g["cx"] + 24, g["base"] + 6), fill=(22, 28, 46, 80))
    ombre.alpha_composite(out)
    img = ombre.resize((L * ECHELLE, H * ECHELLE), Image.NEAREST)
    return img, [zone[0] * ECHELLE, zone[1] * ECHELLE, (zone[2] - zone[0]) * ECHELLE, (zone[3] - zone[1]) * ECHELLE]


def main() -> None:
    SORTIE.mkdir(parents=True, exist_ok=True)
    marques = {}
    for skin in SKINS:
        img, zone = dessiner(skin)
        img.save(SORTIE / f"{skin}.png")
        marques[skin] = {"genre": SKINS[skin][3], "x": zone[0], "y": zone[1], "largeur": zone[2], "hauteur": zone[3]}
    (SORTIE / "marques.json").write_text(json.dumps(marques, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(len(SKINS), "sprites dessinés dans", SORTIE)


if __name__ == "__main__":
    main()
