"""Planche des candidats de remplacement (T11.6, étape 3) : pour chaque skin visé, l'image actuelle puis
1 à 3 candidats libres, avec leur pack et leur licence.

Usage (depuis la racine) : python3 -I docs/skins/generer_candidats.py <dossier MiniWorldSprites> <dossier Ruining tower>
Les archives ne sont pas dans le dépôt : elles se téléchargent sur OpenGameArt (liens directs, sans jeton).
Pillow (licence HPND, libre) seulement. Aucun sprite n'est retouché : chaque candidat est un recadrage de
tuiles contiguës d'une feuille, agrandi au plus proche voisin pour l'affichage.
"""

import json
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RACINE = Path(__file__).resolve().parents[2]
MW = "MiniWorld Sprites (Shade), CC0"
RUIN = "Ruining tower (Blarumyrran), CC0"
# skin -> [(étiquette, source, feuille, col, ligne, largeur en tuiles, hauteur en tuiles, adéquation)]
CANDIDATS = {
    "tour_du_puits": [("puits", MW, "Miscellaneous/Well", 0, 0, 1, 1, "B")],
    "tour_comptoir": [
        ("étal aux pommes", MW, "Buildings/Wood/Market", 0, 1, 1, 1, "B"),
        ("étal aux balances", MW, "Buildings/Wood/Market", 1, 0, 1, 1, "P"),
    ],
    "tour_du_banquier": [
        ("étal d'or", MW, "Buildings/Wood/Market", 2, 2, 1, 1, "P"),
        ("coffre d'or", MW, "Miscellaneous/Chests", 1, 0, 1, 1, "P"),
    ],
    "tour_du_dragon_avare": [
        ("remise à minerai d'or", MW, "Buildings/Wood/Resources", 0, 4, 1, 1, "P"),
        ("coffre d'or", MW, "Miscellaneous/Chests", 1, 0, 1, 1, "P"),
    ],
    "tour_embuscade": [("palissade de pieux", MW, "Buildings/Enemy/SpearWall", 0, 0, 1, 1, "B")],
    "tour_de_ronces": [("palissade de pieux", MW, "Buildings/Enemy/SpearWall", 2, 0, 1, 1, "P")],
    "tour_familiere": [
        ("maison", MW, "Buildings/Wood/Houses", 1, 1, 1, 1, "B"),
        ("maison", MW, "Buildings/Wood/Houses", 2, 2, 1, 1, "B"),
    ],
    "tour_de_la_table_ronde": [("taverne", MW, "Buildings/Wood/Taverns", 1, 0, 1, 1, "P")],
    "tour_ossuaire": [
        ("mausolée sombre", MW, "Buildings/Enemy/Mausoleum", 0, 0, 2, 2, "P"),
        ("pierre tombale", MW, "Miscellaneous/Tombstones", 1, 0, 1, 1, "P"),
    ],
    "tour_arsenal": [
        ("atelier", MW, "Buildings/Wood/Workshops", 1, 1, 1, 1, "P"),
        ("caserne", MW, "Buildings/Wood/Barracks", 1, 0, 1, 1, "P"),
    ],
    "tour_eternelle": [("grotte moussue", MW, "Buildings/Wood/CaveV2", 0, 0, 1, 1, "P")],
    "tour_du_dernier_rempart": [("donjon", MW, "Buildings/Wood/Keep", 0, 0, 2, 2, "P")],
    "tour_nue": [("tour de pierre unie", MW, "Buildings/Wood/Tower2", 0, 3, 1, 1, "B")],
    "tour_ascete": [("tour de pierre unie", MW, "Buildings/Wood/Tower2", 1, 3, 1, 1, "B")],
    "tour_de_granit": [("tour de pierre lisse", MW, "Buildings/Wood/Tower2", 2, 3, 1, 1, "B")],
    "tour_sans_horizon": [("trois étages empilés", MW, "Buildings/Wood/Tower2", 0, 0, 1, 3, "P")],
    "tour_de_pierre": [("tour crénelée", MW, "Buildings/Wood/Tower", 0, 3, 1, 1, "B")],
    "tour_survivante": [("tour en ruine", RUIN, "towerruin", None, None, None, None, "P")],
}
COUL = {"B": (60, 160, 80), "P": (220, 170, 40), "R": (210, 110, 40)}
LIB = {"B": "bon", "P": "partiel", "R": "rapproché"}


def adequation_actuelle() -> dict:
    texte = (RACINE / "docs/skins/generer_planche.py").read_text(encoding="utf-8")
    return dict(re.findall(r'"(tour_\w+)": "([BPR])"', texte))


def image_actuelle(skin: dict) -> Image.Image:
    im = Image.open(RACINE / skin["sprite"].removeprefix("res://")).convert("RGBA")
    if "cadre" in skin:
        c = skin["cadre"]
        im = im.crop((c["x"], c["y"], c["x"] + c["largeur"], c["y"] + c["hauteur"]))
    return im


def candidat(dossiers: dict, c: tuple) -> Image.Image:
    _, source, feuille, col, lig, w, h, _ = c
    base = dossiers[source]
    im = Image.open(base / (feuille + ".png")).convert("RGBA")
    if col is not None:
        im = im.crop((col * 16, lig * 16, (col + w) * 16, (lig + h) * 16))
    return im


def main() -> None:
    dossiers = {MW: Path(sys.argv[1]), RUIN: Path(sys.argv[2])}
    police = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    gras = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
    adequation = adequation_actuelle()
    donnees = json.loads((RACINE / "data/skins_tour.json").read_text(encoding="utf-8"))
    doc = (RACINE / "docs/defis.md").read_text(encoding="utf-8").split("## 5. Un skin par défi")[1]
    idees = {m[1]: m[2].strip() for m in re.findall(r"^\| `(\w+)`\s*\| `(\w+)`\s*\| (.+?)\s*\|$", doc, re.M)}
    cibles = [s for s in adequation if adequation[s] in "RP"]
    cibles.sort(key=lambda s: (adequation[s] != "R", s))
    lh, lc = 170, 1150
    planche = Image.new("RGBA", (lc, lh * len(cibles) + 80), (36, 38, 44, 255))
    d = ImageDraw.Draw(planche)
    avant = sum(1 for v in adequation.values() if v == "B")
    apres = avant
    for i, skin in enumerate(cibles):
        y = 80 + i * lh
        q = adequation[skin]
        d.rectangle((4, y + 2, lc - 4, y + lh - 4), outline=COUL[q], width=2)
        d.text((12, y + 8), skin, font=gras, fill=(240, 240, 240))
        d.text((12, y + 30), f"actuel : {LIB[q]}", font=gras, fill=COUL[q])
        mots, ligne, ys = idees[skin].split(), "", y + 54
        for m in mots:
            if d.textlength(ligne + " " + m, font=police) > 190:
                d.text((12, ys), ligne.strip(), font=police, fill=(210, 210, 215))
                ligne, ys = "", ys + 16
            ligne += " " + m
        d.text((12, ys), ligne.strip(), font=police, fill=(210, 210, 215))
        im = image_actuelle(donnees[skin])
        im.thumbnail((150, lh - 20), Image.NEAREST)
        planche.paste(im, (220, y + 8), im)
        x = 400
        for c in CANDIDATS.get(skin, []):
            cim = candidat(dossiers, c)
            f = max(1, min(8, (lh - 50) // cim.height))
            cim = cim.resize((cim.width * f, cim.height * f), Image.NEAREST)
            planche.paste(cim, (x, y + 8), cim)
            d.text((x, y + lh - 42), c[0], font=police, fill=(240, 240, 240))
            d.text((x, y + lh - 26), f"{LIB[c[7]]} · {c[1].split(' (')[0]}", font=police, fill=COUL[c[7]])
            x += max(cim.width, 170) + 20
        if skin not in CANDIDATS:
            d.text((400, y + 60), "aucun nouveau candidat libre trouvé", font=police, fill=(150, 150, 150))
        elif q != "B" and any(c[7] == "B" for c in CANDIDATS[skin]):
            apres += 1
    n_cand = sum(1 for s in cibles if s in CANDIDATS)
    d.text(
        (12, 14),
        f"{len(cibles)} skins visés (rapprochés puis partiels) : {n_cand} ont un candidat, "
        f"« bons » : {avant} aujourd'hui, {apres} avec les meilleurs candidats",
        font=gras,
        fill=(240, 240, 240),
    )
    d.text(
        (12, 40),
        "Candidats : MiniWorld Sprites (16 px, CC0) et Ruining tower (CC0), agrandis au plus proche voisin ici ; "
        "le jeu devra les agrandir (champ à prévoir).",
        font=police,
        fill=(170, 170, 180),
    )
    planche.convert("RGB").save(RACINE / "docs/skins/planche_candidats_v5.png")
    print(len(cibles), n_cand, avant, apres)


if __name__ == "__main__":
    main()
