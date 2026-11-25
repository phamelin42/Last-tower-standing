# Crédits

Chaque ressource tierce (licence libre uniquement) est listée ici.

| Source                                                                            | Auteur                                        | Licence                                       | Usage                                                                                                                              |
| --------------------------------------------------------------------------------- | --------------------------------------------- | --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| [Godot Engine 4.7.2](https://godotengine.org)                                     | Juan Linietsky, Ariel Manzur et contributeurs | MIT                                           | Moteur, exécuté par le joueur et par la CI (`tools/install-godot.sh`).                                                             |
| [gdtoolkit 4](https://github.com/Scony/godot-gdscript-toolkit) (gdlint, gdformat) | Bartosz Sokołowski (Scony) et contributeurs   | MIT                                           | Outils de développement : lint et format GDScript (`tools/install-gdtoolkit.sh`), hors du jeu.                                     |
| Police par défaut de Godot                                                        | Fournie avec le moteur                        | Licence de la police, indiquée dans le moteur | Repli de Tiny5 pour les signes qu’elle n’a pas (l’infini « ∞ ») ; aucun fichier versionné.                                         |
| [Tiny5](https://fonts.google.com/specimen/Tiny5) (`assets/polices/tiny5/`)        | The Tiny5 Project Authors (Gissio)            | SIL OFL 1.1 (`assets/polices/tiny5/OFL.txt`)  | Police pixel de toute l’interface (paquet npm `@fontsource/tiny5` 5.3.0, sous-ensemble latin, seul fichier utilisé).               |
| [Tiny Swords](https://pixelfrog-assets.itch.io/tiny-swords), « Update 010 »       | Pixel Frog                                    | CC0 1.0                                       | Images du lot 5 (`assets/tiny_swords/`, détail dans `assets/tiny_swords/LICENCE.md`).                                              |
| Guêpe de laiton (`assets/maison/`)                                                | Faite pour ce jeu (`tools/dessiner_guepe.gd`) | CC0 1.0                                       | Sprite de l'unité volante, dessiné par script dans le style et la palette de Tiny Swords (détail dans `assets/maison/LICENCE.md`). |

## Tiny Swords : seulement l'ancienne version CC0

- Seule l'ancienne version du pack, « Update 010 », publiée sous CC0, est dans le dépôt. Sa
  licence et sa provenance sont dans `assets/tiny_swords/LICENCE.md`.
- **La version actuelle du pack interdit la redistribution des fichiers et ne doit jamais entrer
  dans le dépôt**, même modifiée.
- Tant que le lot 5 n'est pas terminé, l'arène affichée reste faite de primitives Godot
  (`BoxMesh`, `CylinderMesh`, `SphereMesh`…).
