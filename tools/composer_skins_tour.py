"""Compose data/skins_tour.json (T11.6) : un skin par défi, avec sprite, cadre, échelle, ancrages et marque.

Usage (depuis la racine) : python3 -I tools/composer_skins_tour.py
Pillow (licence HPND, libre) seulement. Le skin `defaut` garde ses ancrages de T9.24 ; les autres
reprennent les mêmes proportions dans la boîte opaque de leur sprite, et une échelle égale au
rapport des largeurs, ce qui reste à ajuster à l'œil (T11.7). Les tailles viennent des fichiers :
rien n'est écrit à la main, remplacer une image puis relancer ce script suffit à changer un skin.
"""

import colorsys
import json
from pathlib import Path
from PIL import Image

RACINE = Path(__file__).resolve().parents[1]
STATS = ["epines", "mana", "armure", "esquive", "regen", "vol_de_vie"]
TS = "res://assets/tiny_swords/"
TOURS = "res://assets/tours/"
TINY = {"licence": "CC0 1.0", "source": "Tiny Swords (Pixel Frog), assets/tiny_swords/LICENCE.md"}
SPIRE = {"licence": "CC0 1.0", "source": "Spire Tower Pack (Foozle), assets/tours/SOURCES.md"}
# Le château des Chevaliers (320 × 256) dépasse les 256 px de large permis : il n'est pas un skin.
# skin -> (sprite, nombre d'images côte à côte dans le fichier, rang de l'image retenue, licence).
# Le cadre se déduit de la taille du fichier.
SKINS = {
    "tour_de_guet": (TS + "Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_Blue.png", 4, 0, TINY),
    "tour_embuscade": (TS + "Factions/Goblins/Buildings/Wood_House/Goblin_House.png", 1, 0, TINY),
    "tour_comptoir": (TS + "Factions/Goblins/Buildings/Wood_House/Goblin_House.png", 1, 0, TINY),
    "tour_du_puits": (TS + "Factions/Knights/Buildings/Tower/Tower_Construction.png", 1, 0, TINY),
    "tour_de_la_table_ronde": (TS + "Factions/Knights/Buildings/Tower/Tower_Construction.png", 1, 0, TINY),
    "tour_rafistolee": (TS + "Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_InConstruction.png", 1, 0, TINY),
    "tour_survivante": (TS + "Factions/Knights/Buildings/Tower/Tower_Destroyed.png", 1, 0, TINY),
    "tour_familiere": (TS + "Factions/Knights/Buildings/House/House_Blue.png", 1, 0, TINY),
    "tour_du_dragon_avare": (TOURS + "mine_d_or.png", 1, 0, TINY),
    "tour_du_banquier": (TOURS + "mine_d_or.png", 1, 0, TINY),
}
# Tours de Spire (Foozle) : huit fichiers de base, trois niveaux côte à côte chacun. Skin -> (tour 1 à 8, niveau 1 à 3).
# La tour 3 est la baliste de bois, la 4 la tour de pierre au marteau, la 5 la tour noire à runes, la 6 l'arbalète à écu.
SPIRE_SKINS = {
    "tour_de_pierre": (6, 1),
    "tour_du_vainqueur": (1, 3),
    "tour_sans_horizon": (7, 3),
    "tour_lame": (4, 2),
    "tour_pointe": (6, 3),
    "tour_arcane": (5, 1),
    "tour_bastion": (4, 3),
    "tour_fissure": (5, 3),
    "tour_oeil": (5, 2),
    "tour_nuee": (7, 2),
    "tour_ricochet": (7, 1),
    "tour_sonore": (3, 1),
    "tour_salve": (1, 2),
    "tour_sapeur": (3, 3),
    "tour_halo": (8, 1),
    "tour_manege": (4, 1),
    "tour_venimeuse": (2, 3),
    "tour_braise": (2, 2),
    "tour_gelee": (2, 1),
    "tour_tonnerre": (8, 2),
    "tour_sanguine": (5, 2),
    "tour_monolame": (4, 1),
    "tour_du_duelliste": (1, 1),
    "tour_du_tresor": (8, 3),
    "tour_ascete": (6, 1),
    "tour_du_chariot": (3, 2),
    "tour_de_granit": (6, 2),
    "tour_du_bouclier": (6, 2),
    "tour_cicatrisee": (4, 3),
    "tour_nue": (6, 1),
    "tour_a_faux": (6, 3),
    "tour_arsenal": (1, 2),
    "tour_de_ronces": (2, 3),
    "tour_veterane": (1, 3),
    "tour_conquerante": (8, 2),
    "tour_ossuaire": (5, 2),
    "tour_eternelle": (4, 2),
    "tour_du_dernier_rempart": (8, 3),
    "tour_cratere": (7, 2),
    "tour_artificier": (3, 3),
}
for _skin, (_tour, _niveau) in SPIRE_SKINS.items():
    SKINS[_skin] = (TOURS + "spire_tour_%02d.png" % _tour, 3, _niveau - 1, SPIRE)
PIXELS_TEINTABLES_MIN = 500  # en dessous, le sprite n'a pas de marque d'origine : le jeu pose un fanion


def cadre_de(sprite: str, images: int, rang: int):
    """Cadre (x, y, largeur, hauteur) de l'image `rang` du fichier, ou None s'il n'y en a qu'une."""
    if images == 1:
        return None
    largeur, hauteur = Image.open(RACINE / sprite.removeprefix("res://")).size
    pas = largeur // images
    return (rang * pas, 0, pas, hauteur)


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
    prop = {s: ((defaut["ancrages"][s]["y"] - ref[1]) / (ref[3] - ref[1])) for s in STATS}
    defis = {d["skin"]: d["id"] for d in json.loads((RACINE / "data/defis.json").read_text(encoding="utf-8"))}
    toutes = [("defaut", (defaut["sprite"], 1, 0, TINY))] + list(SKINS.items())
    sortie = {}
    for skin, (sprite, images, rang, licence) in toutes:
        cadre = cadre_de(sprite, images, rang)
        im = image(sprite, cadre)
        g, h, d, b = boite_opaque(im)
        zone, nb = zone_teintable(im)
        if skin == "defaut":
            ancrages = defaut["ancrages"]
        else:
            ancrages = {s: {"x": round((g + d) / 2), "y": round(h + prop[s] * (b - h))} for s in STATS}
        # Les couleurs des Spire sont celles de leur dessin (cristaux, runes) : jamais teintées par le joueur.
        if licence is TINY and nb >= PIXELS_TEINTABLES_MIN:
            marque = {"genre": "origine", "x": zone[0], "y": zone[1], "largeur": zone[2] - zone[0], "hauteur": zone[3] - zone[1]}
        else:  # fanion posé par le jeu en haut à droite de la boîte opaque
            marque = {"genre": "fanion", "x": d - 20, "y": h, "largeur": 16, "hauteur": 24}
        entree = {"sprite": sprite}
        if cadre:
            entree["cadre"] = dict(zip(("x", "y", "largeur", "hauteur"), cadre))
        entree["defi"] = "" if skin == "defaut" else defis[skin]
        entree["echelle"] = 1.0 if skin == "defaut" else round((d - g) / (ref[2] - ref[0]), 2)
        entree["marque"] = marque
        entree["licence"] = licence["licence"]
        entree["source"] = licence["source"]
        entree["ancrages"] = ancrages
        sortie[skin] = entree
    chemin.write_text(json.dumps(sortie, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(len(sortie), "skins écrits dans", chemin)


if __name__ == "__main__":
    main()
