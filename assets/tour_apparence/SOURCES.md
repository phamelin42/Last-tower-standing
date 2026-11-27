# Origine des images de l’apparence de la tour

Les images (6 statistiques × 3 paliers × 2 couches, `arriere` derrière la tour et `avant` devant, plus
les images du tour lent des piques et des filets du palier 3) sont dessinées pour ce jeu par
`tools/dessiner_apparence_tour.gd`, du code Godot 4.7.2 (licence MIT, libre au sens de l’OSI) qui
compose des pixels avec la classe `Image` : aucun éditeur propriétaire, aucune génération d’image par
IA. Seule l’esquive part d’un sprite existant, la tour
`assets/tiny_swords/Factions/Knights/Buildings/Tower/Tower_Blue.png` (Tiny Swords, CC0 1.0, voir
`assets/tiny_swords/LICENCE.md`), dont elle ne garde que la silhouette teintée et décalée. Les images
sont publiées sous CC0 1.0 avec le jeu ; le script fait foi :
`godot --headless --path . --script res://tools/dessiner_apparence_tour.gd` les régénère à
l’identique. Points de pose : `data/skins_tour.json`.

| Image                         | Ce qu’elle montre                                                                                                   | Outil                      | Licence |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------- | -------------------------- | ------- |
| `epines_1_arriere.png`        | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 1, couche arriere                          | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_1_avant.png`          | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 1, couche avant                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_2_arriere.png`        | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 2, couche arriere                          | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_2_avant.png`          | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 2, couche avant                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_3_arriere.png`        | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 3, couche arriere                          | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_3_avant.png`          | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 3, couche avant                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `mana_1_arriere.png`          | bulle bleue (film arrière pâle, film avant avec reflet), palier 1, couche arriere                                   | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `mana_1_avant.png`            | bulle bleue (film arrière pâle, film avant avec reflet), palier 1, couche avant                                     | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `mana_2_arriere.png`          | bulle bleue (film arrière pâle, film avant avec reflet), palier 2, couche arriere                                   | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `mana_2_avant.png`            | bulle bleue (film arrière pâle, film avant avec reflet), palier 2, couche avant                                     | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `mana_3_arriere.png`          | bulle bleue (film arrière pâle, film avant avec reflet), palier 3, couche arriere                                   | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `mana_3_avant.png`            | bulle bleue (film arrière pâle, film avant avec reflet), palier 3, couche avant                                     | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `armure_1_arriere.png`        | blocs de plaques irréguliers qui suivent le fût, palier 1, couche arriere                                           | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `armure_1_avant.png`          | blocs de plaques irréguliers qui suivent le fût, palier 1, couche avant                                             | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `armure_2_arriere.png`        | blocs de plaques irréguliers qui suivent le fût, palier 2, couche arriere                                           | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `armure_2_avant.png`          | blocs de plaques irréguliers qui suivent le fût, palier 2, couche avant                                             | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `armure_3_arriere.png`        | blocs de plaques irréguliers qui suivent le fût, palier 3, couche arriere                                           | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `armure_3_avant.png`          | blocs de plaques irréguliers qui suivent le fût, palier 3, couche avant                                             | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `esquive_1_arriere.png`       | deux silhouettes fines (contour) de part et d’autre (silhouette de `Tower_Blue.png`, CC0), palier 1, couche arriere | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `esquive_1_avant.png`         | deux silhouettes fines (contour) de part et d’autre (silhouette de `Tower_Blue.png`, CC0), palier 1, couche avant   | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `esquive_2_arriere.png`       | deux silhouettes fines (contour) de part et d’autre (silhouette de `Tower_Blue.png`, CC0), palier 2, couche arriere | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `esquive_2_avant.png`         | deux silhouettes fines (contour) de part et d’autre (silhouette de `Tower_Blue.png`, CC0), palier 2, couche avant   | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `esquive_3_arriere.png`       | deux silhouettes fines (contour) de part et d’autre (silhouette de `Tower_Blue.png`, CC0), palier 3, couche arriere | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `esquive_3_avant.png`         | deux silhouettes fines (contour) de part et d’autre (silhouette de `Tower_Blue.png`, CC0), palier 3, couche avant   | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `regen_1_arriere.png`         | halo pâle derrière, lueur et étincelles devant, palier 1, couche arriere                                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `regen_1_avant.png`           | halo pâle derrière, lueur et étincelles devant, palier 1, couche avant                                              | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `regen_2_arriere.png`         | halo pâle derrière, lueur et étincelles devant, palier 2, couche arriere                                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `regen_2_avant.png`           | halo pâle derrière, lueur et étincelles devant, palier 2, couche avant                                              | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `regen_3_arriere.png`         | halo pâle derrière, lueur et étincelles devant, palier 3, couche arriere                                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `regen_3_avant.png`           | halo pâle derrière, lueur et étincelles devant, palier 3, couche avant                                              | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_1_arriere.png`    | filets rouges en spirale, d’épaisseurs variées, palier 1, couche arriere                                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_1_avant.png`      | filets rouges en spirale, d’épaisseurs variées, palier 1, couche avant                                              | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_2_arriere.png`    | filets rouges en spirale, d’épaisseurs variées, palier 2, couche arriere                                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_2_avant.png`      | filets rouges en spirale, d’épaisseurs variées, palier 2, couche avant                                              | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_3_arriere.png`    | filets rouges en spirale, d’épaisseurs variées, palier 3, couche arriere                                            | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_3_avant.png`      | filets rouges en spirale, d’épaisseurs variées, palier 3, couche avant                                              | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_3_arriere_a1.png`     | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 3, couche arriere, image 2 du tour lent    | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_3_avant_a1.png`       | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 3, couche avant, image 2 du tour lent      | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_3_arriere_a1.png` | filets rouges en spirale, d’épaisseurs variées, palier 3, couche arriere, image 2 du tour lent                      | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_3_avant_a1.png`   | filets rouges en spirale, d’épaisseurs variées, palier 3, couche avant, image 2 du tour lent                        | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_3_arriere_a2.png`     | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 3, couche arriere, image 3 du tour lent    | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_3_avant_a2.png`       | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 3, couche avant, image 3 du tour lent      | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_3_arriere_a2.png` | filets rouges en spirale, d’épaisseurs variées, palier 3, couche arriere, image 3 du tour lent                      | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_3_avant_a2.png`   | filets rouges en spirale, d’épaisseurs variées, palier 3, couche avant, image 3 du tour lent                        | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_3_arriere_a3.png`     | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 3, couche arriere, image 4 du tour lent    | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `epines_3_avant_a3.png`       | ceinture de piques de longueurs, d’épaisseurs et d’angles variés, palier 3, couche avant, image 4 du tour lent      | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_3_arriere_a3.png` | filets rouges en spirale, d’épaisseurs variées, palier 3, couche arriere, image 4 du tour lent                      | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `vol_de_vie_3_avant_a3.png`   | filets rouges en spirale, d’épaisseurs variées, palier 3, couche avant, image 4 du tour lent                        | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
| `fanion.png`                  | fanion de la marque de couleur des skins sans couleur propre (mât et flamme bleue, teintée au joueur)               | Godot 4.7.2, `Image` (MIT) | CC0 1.0 |
