"""Assemble docs/skins/planche_v3.png : un candidat libre par skin de tour, sans dessin maison.

Usage (depuis la racine) : python3 -I docs/skins/generer_planche.py
Pillow (licence HPND, libre) seulement. Aucun sprite n'est retouché : le fanion bleu de la marque de couleur
est posé par-dessus à l'affichage, comme le fera le jeu (T11.7), et n'entre dans aucun fichier de sprite.
"""

import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RACINE = Path(__file__).resolve().parents[2]
APERCUS = RACINE / "docs" / "skins" / "apercus"
TS = RACINE / "assets" / "tiny_swords"
# clé -> (fichier Tiny Swords, zone recadrée pour une feuille de plusieurs images)
TINY = {
    "gob_tower": ("Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_Blue.png", (48, 0, 208, 192)),
    "gob_scaffold": ("Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_InConstruction.png", None),
    "gob_house": ("Factions/Goblins/Buildings/Wood_House/Goblin_House.png", None),
    "kn_construction": ("Factions/Knights/Buildings/Tower/Tower_Construction.png", None),
    "kn_ruin": ("Factions/Knights/Buildings/Tower/Tower_Destroyed.png", None),
    "kn_house": ("Factions/Knights/Buildings/House/House_Blue.png", None),
    "gold_mine": ("Resources/Gold Mine/GoldMine_Active.png", None),
}
# Sprites qui portent déjà la couleur du joueur (bleu de Tiny Swords, teintable) : pas de fanion posé.
MARQUE_D_ORIGINE = {"gob_tower", "kn_house", "kn_construction", "S1a1", "S1a2", "S1a3"}

# skin -> (candidat, B bon | P partiel | R rapprochement). Un candidat déjà pris est signalé « réemploi ».
CHOIX = {
    "tour_de_guet": ("gob_tower", "B"),
    "tour_de_pierre": ("S3a1", "P"),
    "tour_du_vainqueur": ("S1a3", "P"),
    "tour_sans_horizon": ("S4a3", "R"),
    "tour_lame": ("S2a2", "R"),
    "tour_pointe": ("S3a3", "B"),
    "tour_arcane": ("S3b1", "B"),
    "tour_bastion": ("S2a3", "P"),
    "tour_fissure": ("S3b3", "B"),
    "tour_oeil": ("S3b2", "R"),
    "tour_nuee": ("S4a2", "R"),
    "tour_ricochet": ("S4a1", "P"),
    "tour_sonore": ("S2b1", "R"),
    "tour_salve": ("S1a2", "P"),
    "tour_embuscade": ("gob_house", "R"),
    "tour_sapeur": ("S2b3", "R"),
    "tour_halo": ("S4b1", "R"),
    "tour_manege": ("S2a1", "R"),
    "tour_venimeuse": ("S1b3", "B"),
    "tour_braise": ("S1b2", "B"),
    "tour_gelee": ("S1b1", "B"),
    "tour_tonnerre": ("S4b2", "R"),
    "tour_sanguine": ("S3b2", "R"),
    "tour_monolame": ("S2a1", "B"),
    "tour_du_duelliste": ("S1a1", "P"),
    "tour_du_tresor": ("S4b3", "B"),
    "tour_ascete": ("S3a1", "R"),
    "tour_du_puits": ("kn_construction", "P"),
    "tour_du_dragon_avare": ("gold_mine", "P"),
    "tour_du_chariot": ("S2b2", "P"),
    "tour_du_banquier": ("gold_mine", "R"),
    "tour_de_granit": ("S3a2", "R"),
    "tour_rafistolee": ("gob_scaffold", "P"),
    "tour_du_bouclier": ("S3a2", "R"),
    "tour_cicatrisee": ("S2a3", "R"),
    "tour_nue": ("S3a1", "R"),
    "tour_a_faux": ("S3a3", "R"),
    "tour_arsenal": ("S1a2", "R"),
    "tour_de_ronces": ("S1b3", "R"),
    "tour_survivante": ("kn_ruin", "P"),
    "tour_familiere": ("kn_house", "R"),
    "tour_veterane": ("S1a3", "R"),
    "tour_conquerante": ("S4b2", "P"),
    "tour_ossuaire": ("S3b2", "R"),
    "tour_comptoir": ("gob_house", "R"),
    "tour_eternelle": ("S2a2", "R"),
    "tour_de_la_table_ronde": ("kn_construction", "P"),
    "tour_du_dernier_rempart": ("S4b3", "R"),
    "tour_zone_posee": ("S4a2", "R"),
    "tour_bombe": ("S2b3", "R"),
}
# Skins dont le défi n'est pas encore dans docs/defis.md (PR #85) : identifiants provisoires.
PROVISOIRES = [
    ("seul_zone_posee", "tour_zone_posee", "disque de zone posé au pied (provisoire)"),
    ("seul_bombe", "tour_bombe", "bombes rondes à mèche (provisoire)"),
]
COUL = {"B": (60, 160, 80), "P": (220, 170, 40), "R": (210, 110, 40)}
LIB = {"B": "bon", "P": "partiel", "R": "rapproché"}


def lire_skins() -> list[tuple[str, str, str]]:
    texte = (RACINE / "docs/defis.md").read_text(encoding="utf-8")
    section = texte.split("## 5. Un skin par défi")[1].split("## 6.")[0]
    return [
        (m[0], m[1], m[2].strip())
        for m in re.findall(r"^\| `(\w+)`\s*\| `(\w+)`\s*\| (.+?)\s*\|$", section, re.M)
    ] + PROVISOIRES


def image(cle: str) -> Image.Image:
    if cle in TINY:
        chemin, zone = TINY[cle]
        im = Image.open(TS / chemin).convert("RGBA")
        return im.crop(zone) if zone else im
    famille, rang = cle[1], cle[2:]
    nom = f"spire{famille}_{rang}.png"
    return Image.open(APERCUS / nom).convert("RGBA")


def fanion(im: Image.Image) -> None:
    """Pose le fanion de la marque (bleu de Tiny Swords) en haut à droite, par-dessus l'aperçu."""
    d = ImageDraw.Draw(im)
    x = im.width - 22
    d.line((x, 4, x, 24), fill=(90, 70, 70), width=2)
    d.polygon([(x + 1, 4), (x + 15, 9), (x + 1, 15)], fill=(68, 142, 159), outline=(22, 28, 46))


def main() -> None:
    police = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    gras = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
    skins = lire_skins()
    cols, lc, hc = 3, 400, 215
    lignes = (len(skins) + cols - 1) // cols
    planche = Image.new("RGBA", (cols * lc, lignes * hc + 60), (36, 38, 44, 255))
    d = ImageDraw.Draw(planche)
    nb = {k: 0 for k in COUL}
    pris: dict[str, int] = {}
    for _, skin, _ in skins:
        pris[CHOIX[skin][0]] = pris.get(CHOIX[skin][0], 0) + 1
    reemplois = sum(1 for n in pris.values() if n > 1 for _ in range(n - 1))
    for i, (defi, skin, idee) in enumerate(skins):
        x, y = (i % cols) * lc, (i // cols) * hc + 60
        cle, q = CHOIX[skin]
        nb[q] += 1
        d.rectangle((x + 4, y + 4, x + lc - 4, y + hc - 4), outline=COUL[q], width=2)
        im = image(cle)
        if im.width < 128:
            im = im.resize((im.width * 3 // 2, im.height * 3 // 2), Image.NEAREST)
        im.thumbnail((160, 200), Image.NEAREST)
        if cle not in MARQUE_D_ORIGINE:
            fanion(im)
        planche.paste(im, (x + 10, y + 8), im)
        d.text((x + 180, y + 10), skin, font=gras, fill=(240, 240, 240))
        d.text((x + 180, y + 32), f"défi : {defi}", font=police, fill=(170, 170, 180))
        d.text((x + 180, y + 52), f"adéquation : {LIB[q]}", font=gras, fill=COUL[q])
        if pris[cle] > 1:
            d.text((x + 180, y + 72), f"réemploi ({pris[cle]} skins)", font=police, fill=(230, 130, 130))
        ligne, ys = "", y + 94
        for m in idee.split():
            if d.textlength(ligne + " " + m, font=police) > 205:
                d.text((x + 180, ys), ligne.strip(), font=police, fill=(210, 210, 215))
                ligne, ys = "", ys + 17
            ligne += " " + m
        d.text((x + 180, ys), ligne.strip(), font=police, fill=(210, 210, 215))
        note = "marque d'origine" if cle in MARQUE_D_ORIGINE else "fanion posé à l'affichage"
        d.text((x + 180, y + hc - 46), "marque : " + note, font=police, fill=(150, 200, 230))
        d.text((x + 180, y + hc - 28), cle, font=police, fill=(120, 120, 130))
    d.text(
        (10, 18),
        f"{len(skins)} skins : {nb['B']} bons, {nb['P']} partiels, {nb['R']} rapprochés ; "
        f"{len(pris)} sprites distincts, {reemplois} réemplois",
        font=gras,
        fill=(240, 240, 240),
    )
    planche.convert("RGB").save(RACINE / "docs/skins/planche_v3.png")
    print(dict(nb), len(skins), len(pris), reemplois)


if __name__ == "__main__":
    main()
