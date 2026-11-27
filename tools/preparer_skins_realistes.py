"""Prépare les sprites réalistes des skins de tour (T11.6) : rognage des bords transparents, réduction, SOURCES.md.

Usage (depuis la racine) : python3 -I tools/preparer_skins_realistes.py <dossier des archives>
Le dossier contient un sous-dossier par page OpenGameArt (nom de la page dans l'URL), décompressé, comme le liste
`tools/skins_realistes.json` (clé `origine`, relative à ce dossier). Pillow (licence HPND, libre) seulement.

Chaque image est rognée à son contenu opaque et, si sa surface dépasse `SURFACE_MAX`, réduite à cette surface par
rééchantillonnage Lanczos (le dessin garde ses proportions) : aucune retouche de contenu. La surface voulue vaut environ
deux fois celle de la tour par défaut (114 × 172 px visibles), pour que les superpositions de D19 et le fanion gardent
une taille proche de leur dessin quand `echelle` ramène le skin à la taille de la tour. Les archives ne sont pas dans le dépôt : elles se
téléchargent par les liens directs des pages OpenGameArt (sans jeton). Écrit `assets/tours/<id>.png` et
`assets/tours/SOURCES.md`.
"""

import json
import sys
from pathlib import Path
from PIL import Image

RACINE = Path(__file__).resolve().parents[1]
SORTIE = RACINE / "assets" / "tours"
OGA = "https://opengameart.org/content/"
SURFACE_MAX = 45000  # px², environ 2,3 fois la surface visible de la tour par défaut


def main() -> None:
    archives = Path(sys.argv[1])
    donnees = json.loads((RACINE / "tools" / "skins_realistes.json").read_text(encoding="utf-8"))
    SORTIE.mkdir(parents=True, exist_ok=True)
    lignes = []
    for ident, s in donnees["sprites"].items():
        im = Image.open(archives / s["origine"]).convert("RGBA")
        boite = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        im = im.crop(boite)
        origine = im.size
        if im.width * im.height > SURFACE_MAX:
            f = (SURFACE_MAX / (im.width * im.height)) ** 0.5
            im = im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS)
        im.save(SORTIE / f"{ident}.png", optimize=True)
        taille = f"{origine[0]} × {origine[1]}" + (
            f" → {im.width} × {im.height}" if im.size != origine else " (inchangée)"
        )
        lignes.append(
            f"| `{ident}.png` | {s['auteur']} | {s['licence']} | {OGA}{s['page']} | {taille} |"
        )
    texte = f"""# Origine des sprites de tour (`assets/tours/`)

Sprites 2D réalistes (rendus 3D isométriques) d'OpenGameArt, choisis par Phil (27/11/2026). Chaque image est le sprite
de l'auteur, **rogné à son contenu opaque** et, s'il est grand, **réduit** par rééchantillonnage Lanczos à environ 45 000 px² (colonne
« taille ») : aucune retouche de contenu. Les licences sont celles du champ « License(s) » de la page de chaque sprite,
lues le 27/11/2026 ; téléchargement par lien direct, sans jeton. `tools/preparer_skins_realistes.py` refait ces fichiers
à partir des archives ; `tools/composer_skins_tour.py` compose `data/skins_tour.json`.

Crédits à écrire pour les CC-BY 3.0 (voir `CREDITS.md`) : Varkalandar, rubberduck, Bleed, MedicineStorm, tir2, mold et
Snabisch (Catapult), chacun avec la page ci-dessous.

| Fichier | Auteur | Licence | Page | Taille (px) |
| ------- | ------ | ------- | ---- | ----------- |
""" + "\n".join(lignes) + "\n"
    (SORTIE / "SOURCES.md").write_text(texte, encoding="utf-8")
    print(len(lignes), "sprites écrits dans", SORTIE)


if __name__ == "__main__":
    main()
