"""Assemble les planches finales des skins de tour (T11.6) à partir d'une capture de la vitrine en jeu.

Usage (depuis la racine) :
  tools/capturer.sh res://tools/vitrines/vitrine_skins_tour.tscn --images 612 --sortie /tmp/capture -- --zoom 0.6
  python3 -I docs/skins/generer_planche.py /tmp/capture

La vitrine pose chaque skin de `data/skins_tour.json` dans une vraie `Arene2D` (12 images par skin, l'avant-dernière image écrite est celle
qu'on regarde). Écrit `docs/skins/planche_skins.png` (les 50 skins, recadrés autour de la tour, avec leur défi, leur
adéquation avec la silhouette de docs/defis.md et leur licence) et `docs/skins/captures_en_jeu.png` (quatre images
entières de l'arène, décor complet). Pillow (licence HPND, libre) seulement.
"""

import json
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RACINE = Path(__file__).resolve().parents[2]
IMAGES_PAR_SKIN = 12
COUL = {"B": (60, 160, 80), "P": (220, 170, 40), "R": (210, 110, 40)}
LIB = {"B": "bon", "P": "partiel", "R": "rapproché"}
RECADRAGE = (346, 50, 806, 390)


def main() -> None:
    capture = Path(sys.argv[1])
    police = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    gras = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
    donnees = json.loads((RACINE / "data/skins_tour.json").read_text(encoding="utf-8"))
    choix = json.loads((RACINE / "tools/skins_realistes.json").read_text(encoding="utf-8"))["skins"]
    texte = (RACINE / "docs/defis.md").read_text(encoding="utf-8").split("## 5. Un skin par défi")[1]
    idees = {m[1]: m[2].strip() for m in re.findall(r"^\| `(\w+)`\s*\| `(\w+)`\s*\| (.+?)\s*\|$", texte, re.M)}
    ids = list(donnees)
    skins = [(i, s) for i, s in enumerate(ids) if s != "defaut"]
    cols, lc, hc = 4, 480, 400
    lignes = (len(skins) + cols - 1) // cols
    planche = Image.new("RGB", (cols * lc, lignes * hc + 50), (36, 38, 44))
    d = ImageDraw.Draw(planche)
    nb = {k: 0 for k in COUL}
    emploi: dict[str, int] = {}
    for _, s in skins:
        emploi[donnees[s]["sprite"]] = emploi.get(donnees[s]["sprite"], 0) + 1
    for n, (i, s) in enumerate(skins):
        x, y = (n % cols) * lc, (n // cols) * hc + 50
        image = Image.open(capture / f"image_{i * IMAGES_PAR_SKIN + IMAGES_PAR_SKIN - 2:08d}.png").convert("RGB")
        planche.paste(image.crop(RECADRAGE), (x + 10, y + 6))
        q = choix[s]["adequation"]
        nb[q] += 1
        d.text((x + 12, y + 350), s, font=gras, fill=(240, 240, 240))
        d.text((x + 12, y + 372), f"{LIB[q]} · {Path(donnees[s]['sprite']).stem}", font=police, fill=COUL[q])
        reemploi = emploi[donnees[s]["sprite"]]
        if reemploi > 1:
            d.text((x + 260, y + 372), f"réemploi ({reemploi} skins)", font=police, fill=(230, 130, 130))
    distincts = len(emploi)
    d.text(
        (10, 16),
        f"{len(skins)} skins en jeu : {nb['B']} bons, {nb['P']} partiels, {nb['R']} rapprochés ; "
        f"{distincts} images distinctes, {len(skins) - distincts} réemplois",
        font=gras,
        fill=(240, 240, 240),
    )
    planche.save(RACINE / "docs/skins/planche_skins.png")
    montrer = ["tour_de_guet", "tour_sans_horizon", "tour_arcane", "tour_du_tresor"]
    grande = Image.new("RGB", (1152, 648))
    for k, s in enumerate(montrer):
        i = ids.index(s)
        image = Image.open(capture / f"image_{i * IMAGES_PAR_SKIN + IMAGES_PAR_SKIN - 2:08d}.png").convert("RGB")
        grande.paste(image.resize((576, 324), Image.LANCZOS), ((k % 2) * 576, (k // 2) * 324))
    grande.save(RACINE / "docs/skins/captures_en_jeu.png")
    print(dict(nb), len(skins), distincts)


if __name__ == "__main__":
    main()
