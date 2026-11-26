"""Assemble docs/skins/planche_candidats.png : un candidat de sprite par skin de tour.

Usage (depuis la racine) : python3 -I docs/skins/generer_planche.py
Pillow (licence HPND, libre) seulement ; aucun sprite n'est retouché, les aperçus sont recadrés tels quels.
"""

import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RACINE = Path(__file__).resolve().parents[2]
APERCUS = RACINE / "docs" / "skins" / "apercus"
GOBELIN = RACINE / "assets/tiny_swords/Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_Blue.png"

# skin -> (candidat, adéquation) ; B bon, P partiel, F faible. Tout skin absent est un manque.
CHOIX = {
    "tour_de_guet": ("goblin", "B"),
    "tour_de_pierre": ("spire3_a1", "P"),
    "tour_du_vainqueur": ("spire1_a3", "P"),
    "tour_pointe": ("spire3_a3", "B"),
    "tour_arcane": ("spire3_b1", "B"),
    "tour_fissure": ("spire3_b3", "B"),
    "tour_gelee": ("spire1_b1", "B"),
    "tour_braise": ("spire1_b2", "B"),
    "tour_venimeuse": ("spire1_b3", "B"),
    "tour_bastion": ("spire2_a3", "P"),
    "tour_monolame": ("spire2_a1", "B"),
    "tour_ricochet": ("spire4_a1", "P"),
    "tour_tonnerre": ("spire4_a2", "F"),
    "tour_sanguine": ("spire3_b2", "F"),
    "tour_salve": ("spire1_a2", "P"),
    "tour_du_tresor": ("spire4_b3", "B"),
    "tour_conquerante": ("spire4_b2", "P"),
    "tour_du_banquier": ("spire4_b1", "F"),
    "tour_rafistolee": ("spire2_b1", "P"),
    "tour_du_duelliste": ("spire1_a1", "P"),
    "tour_du_chariot": ("spire2_b2", "F"),
    "tour_arsenal": ("spire2_b3", "P"),
    "tour_du_bouclier": ("spire3_a2", "F"),
    "tour_eternelle": ("spire2_a2", "F"),
    "tour_ossuaire": ("spire4_a3", "F"),
}
COUL = {"B": (60, 160, 80), "P": (220, 170, 40), "F": (210, 110, 40), "M": (190, 60, 60)}
LIB = {"B": "bon", "P": "partiel", "F": "faible", "M": "MANQUE"}


def lire_skins() -> list[tuple[str, str, str]]:
    texte = (RACINE / "docs/defis.md").read_text(encoding="utf-8")
    section = texte.split("## 5. Un skin par défi")[1].split("## 6.")[0]
    return [
        (m[0], m[1], m[2].strip())
        for m in re.findall(r"^\| `(\w+)`\s*\| `(\w+)`\s*\| (.+?)\s*\|$", section, re.M)
    ]


def image(cle: str) -> Image.Image:
    if cle == "goblin":
        return Image.open(GOBELIN).convert("RGBA").crop((48, 0, 208, 192))
    return Image.open(APERCUS / f"{cle}.png").convert("RGBA")


def main() -> None:
    police = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    gras = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
    skins = lire_skins()
    cols, lc, hc = 3, 400, 215
    lignes = (len(skins) + cols - 1) // cols
    planche = Image.new("RGBA", (cols * lc, lignes * hc + 60), (36, 38, 44, 255))
    d = ImageDraw.Draw(planche)
    nb = {k: 0 for k in COUL}
    for i, (defi, skin, idee) in enumerate(skins):
        x, y = (i % cols) * lc, (i // cols) * hc + 60
        cle, q = CHOIX.get(skin, (None, "M"))
        nb[q] += 1
        d.rectangle((x + 4, y + 4, x + lc - 4, y + hc - 4), outline=COUL[q], width=2)
        if cle:
            im = image(cle)
            im = im.resize((im.width * 3 // 2, im.height * 3 // 2), Image.NEAREST)
            im.thumbnail((150, 200), Image.NEAREST)
            planche.paste(im, (x + 10, y + 8), im)
        else:
            d.text((x + 50, y + 90), "aucun candidat", font=police, fill=(150, 150, 150))
        d.text((x + 170, y + 10), skin, font=gras, fill=(240, 240, 240))
        d.text((x + 170, y + 32), f"défi : {defi}", font=police, fill=(170, 170, 180))
        d.text((x + 170, y + 52), f"adéquation : {LIB[q]}", font=gras, fill=COUL[q])
        mots, ligne, ys = idee.split(), "", y + 80
        for m in mots:
            if d.textlength(ligne + " " + m, font=police) > 215:
                d.text((x + 170, ys), ligne.strip(), font=police, fill=(210, 210, 215))
                ligne, ys = "", ys + 17
            ligne += " " + m
        d.text((x + 170, ys), ligne.strip(), font=police, fill=(210, 210, 215))
        if cle:
            d.text((x + 170, y + hc - 30), cle, font=police, fill=(120, 120, 130))
    d.text(
        (10, 18),
        f"{len(skins)} skins : bon {nb['B']}, partiel {nb['P']}, faible {nb['F']}, manque {nb['M']}",
        font=gras,
        fill=(240, 240, 240),
    )
    planche.convert("RGB").save(RACINE / "docs/skins/planche_candidats.png")
    print(dict(nb), len(skins))


if __name__ == "__main__":
    main()
