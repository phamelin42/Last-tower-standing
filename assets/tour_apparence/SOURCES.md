# Origine des images de l’apparence de la tour

Les 18 images (6 statistiques × 3 paliers) sont dessinées pour ce jeu par `tools/dessiner_apparence_tour.gd`,
du code Godot 4.7.2 (licence MIT, libre au sens de l’OSI) qui compose des pixels avec la classe `Image` : aucun
éditeur propriétaire, aucune génération d’image par IA. Seule l’esquive part d’un sprite existant, la tour
`assets/tiny_swords/Factions/Knights/Buildings/Tower/Tower_Blue.png` (Tiny Swords, CC0 1.0, voir
`assets/tiny_swords/LICENCE.md`), dont elle ne garde que la silhouette décalée. Les images sont publiées sous
CC0 1.0 avec le jeu ; le script fait foi : `godot --headless --path . --script res://tools/dessiner_apparence_tour.gd`
les régénère à l’identique. Points de pose : `data/skins_tour.json`.

| Image              | Ce qu’elle montre                                                                          | Outil                      | Licence |
| ------------------ | ------------------------------------------------------------------------------------------ | -------------------------- | ------- |
| `epines_1.png`     | piques de fer sur le mur, palier 1                                                         | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_2.png`     | piques de fer sur le mur, palier 2                                                         | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_3.png`     | piques de fer sur le mur, palier 3                                                         | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `mana_1.png`       | bulle bleue, palier 1                                                                      | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `mana_2.png`       | bulle bleue, palier 2                                                                      | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `mana_3.png`       | bulle bleue, palier 3                                                                      | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `armure_1.png`     | couches de plaques d’acier, palier 1                                                       | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `armure_2.png`     | couches de plaques d’acier, palier 2                                                       | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `armure_3.png`     | couches de plaques d’acier, palier 3                                                       | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `esquive_1.png`    | images rémanentes (silhouette décalée de `Tower_Blue.png`, CC0, sans ses pixels), palier 1 | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `esquive_2.png`    | images rémanentes (silhouette décalée de `Tower_Blue.png`, CC0, sans ses pixels), palier 2 | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `esquive_3.png`    | images rémanentes (silhouette décalée de `Tower_Blue.png`, CC0, sans ses pixels), palier 3 | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `regen_1.png`      | lueur verte et étincelles, palier 1                                                        | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `regen_2.png`      | lueur verte et étincelles, palier 2                                                        | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `regen_3.png`      | lueur verte et étincelles, palier 3                                                        | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_1.png` | filets rouges aspirés, palier 1                                                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_2.png` | filets rouges aspirés, palier 2                                                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_3.png` | filets rouges aspirés, palier 3                                                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
