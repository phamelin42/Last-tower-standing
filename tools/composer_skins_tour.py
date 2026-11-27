"""Compose data/skins_tour.json (T11.6) : un skin par défi, avec sprite, échelle, ancrages et marque.

Usage (depuis la racine) : python3 -I tools/composer_skins_tour.py
Pillow (licence HPND, libre) seulement. Le skin `defaut` (tour de Tiny Swords) garde son entrée ; les autres skins sont
ceux de `tools/skins_realistes.json` (sprite et adéquation), lus sur les fichiers de `assets/tours/` : l'échelle ramène
la surface visible du sprite à celle de la tour par défaut, les ancrages reprennent ses proportions dans la boîte
opaque du sprite, la marque est un fanion posé en haut à droite. Rien n'est écrit à la main sur la taille d'un sprite :
remplacer une image puis relancer ce script suffit à changer un skin.
"""

import json
from pathlib import Path
from PIL import Image

RACINE = Path(__file__).resolve().parents[1]
STATS = ["epines", "mana", "armure", "esquive", "regen", "vol_de_vie"]
FILTRE = "lineaire"  # images lissées : Phil veut des tours réalistes, pas du pixel art
ECHELLE_MAX = 2.0
FANION = (24, 36)  # taille voulue du fanion à l'écran, en pixels de la tour par défaut


def boite_opaque(im: Image.Image) -> tuple[int, int, int, int]:
    return im.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()


def main() -> None:
    chemin = RACINE / "data" / "skins_tour.json"
    existant = json.loads(chemin.read_text(encoding="utf-8"))
    defaut = existant["defaut"]
    im_defaut = Image.open(RACINE / defaut["sprite"].removeprefix("res://")).convert("RGBA")
    ref = boite_opaque(im_defaut)
    surface_ref = (ref[2] - ref[0]) * (ref[3] - ref[1])
    prop = {s: (defaut["ancrages"][s]["y"] - ref[1]) / (ref[3] - ref[1]) for s in STATS}
    defis = {d["skin"]: d["id"] for d in json.loads((RACINE / "data/defis.json").read_text(encoding="utf-8"))}
    sources = json.loads((RACINE / "tools/skins_realistes.json").read_text(encoding="utf-8"))
    sortie = {"defaut": defaut}
    for skin, choix in sources["skins"].items():
        sprite = sources["sprites"][choix["sprite"]]
        im = Image.open(RACINE / "assets" / "tours" / f"{choix['sprite']}.png").convert("RGBA")
        g, h, d, b = boite_opaque(im)
        echelle = min(ECHELLE_MAX, round((surface_ref / ((d - g) * (b - h))) ** 0.5, 2))
        zone_l, zone_h = round(FANION[0] / echelle), round(FANION[1] / echelle)
        sortie[skin] = {
            "sprite": f"res://assets/tours/{choix['sprite']}.png",
            "filtre": FILTRE,
            "defi": defis[skin],
            "echelle": echelle,
            "marque": {"genre": "fanion", "x": max(0, d - zone_l), "y": h, "largeur": zone_l, "hauteur": zone_h},
            "licence": sprite["licence"],
            "source": f"{sprite['auteur']}, https://opengameart.org/content/{sprite['page']}",
            "ancrages": {
                s: {"x": round((g + d) / 2), "y": round(h + prop[s] * (b - h))} for s in STATS
            },
        }
    chemin.write_text(json.dumps(sortie, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(len(sortie), "skins écrits dans", chemin)


if __name__ == "__main__":
    main()
