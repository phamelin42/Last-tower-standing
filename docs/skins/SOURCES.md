# Skins de tour : décision et historique (T11.6)

## Décision (Phil, 27/11/2026)

**Piste A, réaliste, sans brique.** Les skins sont des sprites 2D réalistes (rendus 3D isométriques) d'OpenGameArt,
sous CC0 ou CC-BY 3.0, avec **filtre linéaire** (`filtre` = `lineaire` dans `data/skins_tour.json`). La tour par
défaut reste celle de Tiny Swords. La piste B (modèles 3D rendus par Blender, packs Kenney) est abandonnée : elle a
été jugée « catastrophique » et sa PR (#118) est fermée. La tour ronde en brique est retirée.

Un décor réaliste est possible plus tard : **les assets restent remplaçables**. Chemin, échelle, ancrages et marque
vivent dans `data/skins_tour.json` ; changer un skin demande de remplacer le PNG de `assets/tours/`, puis de relancer
`tools/composer_skins_tour.py`.

## Ce qui est livré

- `assets/tours/*.png` : 33 images distinctes pour 50 skins, soit **17 réemplois** (une même image sert deux ou trois
  skins, accepté par Phil, sans variante de couleur). Sources, auteurs, licences : `assets/tours/SOURCES.md`.
- `tools/skins_realistes.json` : image et adéquation (B bon, P partiel, R rapproché : 16, 19 et 15) de chaque skin.
- `tools/preparer_skins_realistes.py` : rogne chaque archive à son contenu opaque et la réduit à environ 45 000 px².
- `docs/skins/planche_skins.png` : les 50 skins capturés dans une vraie `Arene2D` (`tools/capturer.sh` sur
  `tools/vitrines/vitrine_skins_tour.tscn`, zoom 0,6), avec leur adéquation et leurs réemplois.
- `docs/skins/captures_en_jeu.png` : quatre images d'arène entière (décor, barre de vie, nom, fanion de couleur).
- `docs/skins/generer_planche.py` : refait les deux planches à partir d'un dossier de captures.

## Limites connues

- Les deux tours de garde (pierre, bois) portent un losange de sol dans l'image de l'auteur.
- Les sprites sont réduits (Lanczos), jamais retouchés dans leur contenu.
- Les superpositions (D19) suivent l'échelle du skin : elles apparaissent vers 0,66 de leur taille de conception.
- Les CC-BY 3.0 (Varkalandar, rubberduck, Bleed, MedicineStorm, tir2, mold, Snabisch) sont créditées dans
  `CREDITS.md`.

## Historique

1. **Pixel art** (26/11/2026) : packs Spire de Foozle (CC0) et bâtiments de Tiny Swords ; planches v1 à v4,
   19 réemplois. Phil : « aucun skin ne me convient, sors du pixel art ».
2. **Deux pistes** : A, sprites réalistes d'OpenGameArt ; B, 3D rendue par Blender. Phil (27/11/2026) : « à part la
   tour ronde en brique, j'adore la piste A. La piste B est catastrophique. »
3. **Intégration de la piste A** : cette PR.

Recherches web de T11.6 : 32 sur les 40 permises, plus 2 sur les 10 accordées pour la piste A ; le reste est passé
par les pages OpenGameArt lues directement. Rien n'est à télécharger à la main.
