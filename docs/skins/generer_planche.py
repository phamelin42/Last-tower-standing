"""Assemble docs/skins/planche_v2.png : les 50 skins, candidat CC0 ou sprite dessiné par tools/dessiner_tours.py.

Usage (depuis la racine) : python3 -I docs/skins/generer_planche.py
Pillow (licence HPND, libre) seulement ; aucun sprite n'est retouché, les aperçus sont recadrés tels quels.
"""

import json
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
DESSINES = RACINE / "docs" / "skins" / "dessines"
# Skins dont le défi n'est pas encore dans docs/defis.md (PR #85) : identifiants provisoires.
PROVISOIRES = [
    ("seul_zone_posee", "tour_zone_posee", "disque de zone posé au pied, runes orangées (provisoire)"),
    ("seul_bombe", "tour_bombe", "bombes rondes à mèche au pied et au sommet (provisoire)"),
]
COUL = {"D": (80, 140, 220), "B": (60, 160, 80), "P": (220, 170, 40), "F": (210, 110, 40), "M": (190, 60, 60)}
LIB = {"D": "dessiné", "B": "bon", "P": "partiel", "F": "faible", "M": "MANQUE"}


def lire_skins() -> list[tuple[str, str, str]]:
    texte = (RACINE / "docs/defis.md").read_text(encoding="utf-8")
    section = texte.split("## 5. Un skin par défi")[1].split("## 6.")[0]
    return [
        (m[0], m[1], m[2].strip())
        for m in re.findall(r"^\| `(\w+)`\s*\| `(\w+)`\s*\| (.+?)\s*\|$", section, re.M)
    ] + PROVISOIRES


def image(cle: str) -> Image.Image:
    if cle.startswith("tour_"):
        return Image.open(DESSINES / f"{cle}.png").convert("RGBA")
    if cle == "goblin":
        return Image.open(GOBELIN).convert("RGBA").crop((48, 0, 208, 192))
    return Image.open(APERCUS / f"{cle}.png").convert("RGBA")


def main() -> None:
    police = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    gras = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
    skins = lire_skins()
    marques = json.loads((DESSINES / "marques.json").read_text(encoding="utf-8"))
    choix = {k: v for k, v in CHOIX.items() if v[1] in "BP"}  # faibles : remplacés par un dessin
    cols, lc, hc = 3, 400, 215
    lignes = (len(skins) + cols - 1) // cols
    planche = Image.new("RGBA", (cols * lc, lignes * hc + 60), (36, 38, 44, 255))
    d = ImageDraw.Draw(planche)
    nb = {k: 0 for k in COUL}
    for i, (defi, skin, idee) in enumerate(skins):
        x, y = (i % cols) * lc, (i // cols) * hc + 60
        cle, q = choix.get(skin, (None, "M"))
        if cle is None and skin in marques:
            cle, q = skin, "D"
        nb[q] += 1
        d.rectangle((x + 4, y + 4, x + lc - 4, y + hc - 4), outline=COUL[q], width=2)
        if cle:
            im = image(cle)
            if q != "D":
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
            if q == "D":
                note = "marque : " + marques[skin]["genre"] + " bleu"
            elif cle.startswith("spire1_a"):
                note = "marque : bannière bleue d'origine"
            elif cle == "goblin":
                note = "marque : fanions de couleur du pack"
            else:
                note = "marque : à poser par le jeu"
            d.text((x + 170, y + hc - 46), note, font=police, fill=(150, 200, 230))
            d.text((x + 170, y + hc - 28), cle, font=police, fill=(120, 120, 130))
    d.text(
        (10, 18),
        f"{len(skins)} skins : {nb['B']} bons et {nb['P']} partiels (Spire, CC0), {nb['D']} dessinés, {nb['M']} sans sprite",
        font=gras,
        fill=(240, 240, 240),
    )
    planche.convert("RGB").save(RACINE / "docs/skins/planche_v2.png")
    print(dict(nb), len(skins))


if __name__ == "__main__":
    main()
