"""Compose data/skins_tour.json (T11.6) : un skin par défi, avec sprite, cadre, ancrages et marque.

Usage (depuis la racine) : python3 -I tools/composer_skins_tour.py
Pillow (licence HPND, libre) seulement. Le skin `defaut` garde ses ancrages de T9.24 ; les autres
reprennent les mêmes proportions dans la boîte opaque de leur sprite, ce qui reste à ajuster à l'œil
(T11.7). Les tailles viennent des fichiers : rien n'est écrit à la main. La liste ci-dessous grandit
quand les archives Spire de Foozle entrent dans assets/tours/.
"""

import colorsys
import json
from pathlib import Path
from PIL import Image

RACINE = Path(__file__).resolve().parents[1]
STATS = ["epines", "mana", "armure", "esquive", "regen", "vol_de_vie"]
TS = "res://assets/tiny_swords/"
TINY = {"licence": "CC0 1.0", "source": "Tiny Swords (Pixel Frog), assets/tiny_swords/LICENCE.md"}
# Le château des Chevaliers (320 × 256) dépasse les 256 px de large permis : il n'est pas un skin.
# skin -> (sprite, cadre (x, y, largeur, hauteur) ou None pour l'image entière)
SKINS = {
    "tour_de_guet": (TS + "Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_Blue.png", (0, 0, 256, 192)),
    "tour_embuscade": (TS + "Factions/Goblins/Buildings/Wood_House/Goblin_House.png", None),
    "tour_comptoir": (TS + "Factions/Goblins/Buildings/Wood_House/Goblin_House.png", None),
    "tour_du_puits": (TS + "Factions/Knights/Buildings/Tower/Tower_Construction.png", None),
    "tour_de_la_table_ronde": (TS + "Factions/Knights/Buildings/Tower/Tower_Construction.png", None),
    "tour_rafistolee": (TS + "Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_InConstruction.png", None),
    "tour_survivante": (TS + "Factions/Knights/Buildings/Tower/Tower_Destroyed.png", None),
    "tour_familiere": (TS + "Factions/Knights/Buildings/House/House_Blue.png", None),
    "tour_du_dragon_avare": ("res://assets/tours/mine_d_or.png", None),
    "tour_du_banquier": ("res://assets/tours/mine_d_or.png", None),
}
LICENCES = {"assets/tiny_swords/": TINY}
PIXELS_TEINTABLES_MIN = 500  # en dessous, le sprite n'a pas de marque d'origine : le jeu pose un fanion


def image(sprite: str, cadre) -> Image.Image:
    im = Image.open(RACINE / sprite.removeprefix("res://")).convert("RGBA")
    if cadre:
        x, y, w, h = cadre
        im = im.crop((x, y, x + w, y + h))
    return im


def boite_opaque(im: Image.Image) -> tuple[int, int, int, int]:
    return im.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()


def zone_teintable(im: Image.Image):
    """Boîte et nombre des pixels bleu-vert de Tiny Swords, ceux que la teinte du joueur recolore."""
    px = im.load()
    pts = []
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.43 <= h <= 0.68 and s > 0.25 and v > 0.3:
                pts.append((x, y))
    if not pts:
        return None, 0
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1), len(pts)


def main() -> None:
    chemin = RACINE / "data" / "skins_tour.json"
    existant = json.loads(chemin.read_text(encoding="utf-8"))
    defaut = existant["defaut"]
    ref = boite_opaque(image(defaut["sprite"], None))
    prop = {
        s: ((defaut["ancrages"][s]["y"] - ref[1]) / (ref[3] - ref[1])) for s in STATS
    }
    defis = {d["skin"]: d["id"] for d in json.loads((RACINE / "data/defis.json").read_text(encoding="utf-8"))}
    sortie = {}
    for skin, (sprite, cadre) in [("defaut", (defaut["sprite"], None))] + list(SKINS.items()):
        im = image(sprite, cadre)
        g, h, d, b = boite_opaque(im)
        zone, nb = zone_teintable(im)
        if skin == "defaut":
            ancrages = defaut["ancrages"]
        else:
            ancrages = {
                s: {"x": round((g + d) / 2), "y": round(h + prop[s] * (b - h))} for s in STATS
            }
        if nb >= PIXELS_TEINTABLES_MIN:
            marque = {"genre": "origine", "x": zone[0], "y": zone[1], "largeur": zone[2] - zone[0], "hauteur": zone[3] - zone[1]}
        else:  # fanion posé par le jeu en haut à droite de la boîte opaque
            marque = {"genre": "fanion", "x": d - 20, "y": h, "largeur": 16, "hauteur": 24}
        entree = {"sprite": sprite}
        if cadre:
            entree["cadre"] = dict(zip(("x", "y", "largeur", "hauteur"), cadre))
        entree["defi"] = "" if skin == "defaut" else defis[skin]
        entree["marque"] = marque
        entree["licence"] = TINY["licence"]
        entree["source"] = TINY["source"]
        entree["ancrages"] = ancrages
        sortie[skin] = entree
    chemin.write_text(json.dumps(sortie, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(len(sortie), "skins écrits dans", chemin)


if __name__ == "__main__":
    main()
