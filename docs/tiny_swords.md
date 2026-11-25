# Tiny Swords : inventaire et correspondance (T5.0)

Décisions de Phil (25/11/2026) : le jeu passe en **2D pixel art, vue de dessus**, avec l’**ancienne version CC0** du pack « Tiny Swords » de Pixel Frog. La simulation, le réseau et l’interface ne changent pas ; seul le rendu passera de la 3D à la 2D (T5.1). Ce document sert de référence à T5.1 : il décrit les images, propose quel sprite joue quel rôle, et liste ce qui manque. **Les noms et les choix de la section 3 attendent la validation de Phil.**

## 1. Provenance et règles

- Les images vivent dans `assets/tiny_swords/`, avec l’arborescence du pack (sans son dossier racine). Seuls les `.png` sont versionnés ; licence et source dans `assets/tiny_swords/LICENCE.md`, crédit dans `CREDITS.md`.
- **Jamais la version actuelle du pack** : elle n’est pas redistribuable.
- Les noms de fichiers sont ceux du pack, fautes comprises (`Archer_Purlple.png`). Plusieurs noms contiennent des espaces et des parenthèses (`Archer + Bow/`, `Gold Mine/`, `G_Idle_(NoShadow).png`) : à citer entre guillemets dans les chemins `res://`.
- Toutes les unités sont dessinées de **trois quarts de face, tournées vers la droite** : la gauche s’obtient en miroir horizontal. Elles ont leur ombre dans l’image (sauf les variantes `NoShadow`).
- Filtrage de texture **nearest** (pixel net) sur chaque nœud de rendu ; `project.godot` n’est pas modifié par T5.0.

## 2. Inventaire

Tableau produit par un script de session, non versionné (Python avec `-I` et la bibliothèque standard seulement : lecture de l’en-tête PNG, décodage de l’alpha, comptage des images non vides par ligne), pas à la main. Les dimensions, la taille d’image, le nombre de lignes et le nombre d’images par ligne sont **mesurés** : une feuille est découpée en cases de la taille d’image annoncée et on compte, ligne par ligne, les cases qui contiennent au moins un pixel non transparent. La taille d’image est donc vérifiée par le contenu (192×192 pour les unités, sauf le tonneau, en 128×128). Les **noms d’animations sont des déductions** faites en regardant chaque feuille : à confirmer à l’intégration.

### Unités (feuilles animées)

| Chemin (`{C}` = couleur)                                              | Couleurs                   | Feuille   | Image        | Lignes | Images par ligne              | Animations (noms probables)                                                                                                                                 |
| --------------------------------------------------------------------- | -------------------------- | --------- | ------------ | ------ | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Factions/Goblins/Troops/Barrel/{C}/Barrel_{C}.png`                   | bleu, rouge, jaune, violet | 768×768   | 128×128      | 6      | 1 / 6 / 1 / 6 / 3 / 3         | 0 caché (tonneau fermé) · 1 sortie du tonneau · 2 repos éveillé · 3 rentrée dans le tonneau · 4 course (pattes) · 5 explosion (mèche allumée) ; à confirmer |
| `Factions/Goblins/Troops/TNT/Dynamite/Dynamite.png`                   | —                          | 384×64    | 64×64        | 1      | 6                             | projectile : bâton de dynamite qui tourne (6 images de 64)                                                                                                  |
| `Factions/Goblins/Troops/TNT/{C}/TNT_{C}.png`                         | bleu, rouge, jaune, violet | 1344×576  | 192×192      | 3      | 6 / 6 / 7                     | 0 repos · 1 course · 2 lancer de dynamite                                                                                                                   |
| `Factions/Goblins/Troops/Torch/{C}/Torch_{C}.png`                     | bleu, rouge, jaune, violet | 1344×960  | 192×192      | 5      | 7 / 6 / 6 / 6 / 6             | 0 repos · 1 course · 2 attaque côté · 3 attaque bas · 4 attaque haut (torche)                                                                               |
| `Factions/Knights/Troops/Archer/Archer + Bow/Archer_Bow_{C}.png`      | bleu, rouge, jaune, violet | 1536×384  | 192×192      | 2      | 1 / 8                         | arc seul : 0 arc au repos (1 image) · 1 tir (8 images)                                                                                                      |
| `Factions/Knights/Troops/Archer/Archer + Bow/Archer_{C}_(NoArms).png` | bleu, rouge, jaune, violet | 1152×384  | 192×192      | 2      | 6 / 6                         | corps seul : 0 repos · 1 course (l’arc se pose à part, orientable à tout angle)                                                                             |
| `Factions/Knights/Troops/Archer/Arrow/Arrow.png`                      | —                          | 64×128    | image unique | —      | —                             |                                                                                                                                                             |
| `Factions/Knights/Troops/Archer/{C}/Archer_{C}.png`                   | bleu, rouge, jaune, violet | 1536×1344 | 192×192      | 7      | 6 / 6 / 8 / 8 / 8 / 8 / 8     | 0 repos · 1 course · 2 tir haut · 3 tir haut-côté · 4 tir côté · 5 tir bas-côté · 6 tir bas                                                                 |
| `Factions/Knights/Troops/Dead/Dead.png`                               | —                          | 896×256   | 128×128      | 2      | 7 / 7                         | mort générique (crâne) : 2 lignes de 7 images, une seule animation lue ligne après ligne ; la première image de la ligne 0 est quasi vide                   |
| `Factions/Knights/Troops/Pawn/{C}/Pawn_{C}.png`                       | bleu, rouge, jaune, violet | 1152×1152 | 192×192      | 6      | 6 / 6 / 6 / 6 / 6 / 6         | 0 repos · 1 course · 2 et 3 action à l’outil (marteau, côtés droit et gauche) · 4 repos en portant · 5 course en portant                                    |
| `Factions/Knights/Troops/Warrior/{C}/Warrior_{C}.png`                 | bleu, rouge, jaune, violet | 1152×1536 | 192×192      | 8      | 6 / 6 / 6 / 6 / 6 / 6 / 6 / 6 | 0 repos · 1 course · 2 et 3 attaque côté (deux coups) · 4 et 5 attaque bas (de face) · 6 et 7 attaque haut (de dos)                                         |

### Bâtiments

| Chemin (`{C}` = couleur)                                              | Couleurs                   | Feuille  | Image        | Lignes | Images par ligne | Animations (noms probables)               |
| --------------------------------------------------------------------- | -------------------------- | -------- | ------------ | ------ | ---------------- | ----------------------------------------- |
| `Factions/Goblins/Buildings/Wood_House/Goblin_House.png`              | —                          | 128×192  | image unique | —      | —                |                                           |
| `Factions/Goblins/Buildings/Wood_House/Goblin_House_Destroyed.png`    | —                          | 128×192  | image unique | —      | —                |                                           |
| `Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_Destroyed.png`      | —                          | 256×192  | image unique | —      | —                |                                           |
| `Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_InConstruction.png` | —                          | 256×192  | image unique | —      | —                |                                           |
| `Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_{C}.png`            | bleu, rouge, jaune, violet | 1024×192 | 256×192      | 1      | 4                | 1 ligne de 4 images : fanions qui bougent |
| `Factions/Knights/Buildings/Castle/Castle_Construction.png`           | —                          | 320×256  | image unique | —      | —                |                                           |
| `Factions/Knights/Buildings/Castle/Castle_Destroyed.png`              | —                          | 320×256  | image unique | —      | —                |                                           |
| `Factions/Knights/Buildings/Castle/Castle_{C}.png`                    | bleu, rouge, jaune, violet | 320×256  | image unique | —      | —                |                                           |
| `Factions/Knights/Buildings/House/House_Construction.png`             | —                          | 128×192  | image unique | —      | —                |                                           |
| `Factions/Knights/Buildings/House/House_Destroyed.png`                | —                          | 128×192  | image unique | —      | —                |                                           |
| `Factions/Knights/Buildings/House/House_{C}.png`                      | bleu, rouge, jaune, violet | 128×192  | image unique | —      | —                |                                           |
| `Factions/Knights/Buildings/Tower/Tower_Construction.png`             | —                          | 128×256  | image unique | —      | —                |                                           |
| `Factions/Knights/Buildings/Tower/Tower_Destroyed.png`                | —                          | 128×256  | image unique | —      | —                |                                           |
| `Factions/Knights/Buildings/Tower/Tower_{C}.png`                      | bleu, rouge, jaune, violet | 128×256  | image unique | —      | —                |                                           |

### Terrain

| Chemin (`{C}` = couleur)                 | Couleurs | Feuille  | Image        | Lignes | Images par ligne | Animations (noms probables)       |
| ---------------------------------------- | -------- | -------- | ------------ | ------ | ---------------- | --------------------------------- |
| `Terrain/Bridge/Bridge_All.png`          | —        | 192×256  | image unique | —      | —                |                                   |
| `Terrain/Ground/Shadows.png`             | —        | 192×192  | image unique | —      | —                |                                   |
| `Terrain/Ground/Tilemap_Elevation.png`   | —        | 256×512  | image unique | —      | —                |                                   |
| `Terrain/Ground/Tilemap_Flat.png`        | —        | 640×256  | image unique | —      | —                |                                   |
| `Terrain/Water/Foam/Foam.png`            | —        | 1536×192 | 192×192      | 1      | 8                | écume de rivage (8 images de 192) |
| `Terrain/Water/Rocks/Rocks_{N}.png (×4)` | —        | 1024×128 | 128×128      | 1      | 8                |                                   |
| `Terrain/Water/Water.png`                | —        | 64×64    | image unique | —      | —                |                                   |

### Effets

| Chemin (`{C}` = couleur)           | Couleurs | Feuille  | Image   | Lignes | Images par ligne | Animations (noms probables)                                     |
| ---------------------------------- | -------- | -------- | ------- | ------ | ---------------- | --------------------------------------------------------------- |
| `Effects/Explosion/Explosions.png` | —        | 1728×192 | 192×192 | 1      | 9                | explosion : fumée, flash, nuage, éclats, dissipation (9 images) |
| `Effects/Fire/Fire.png`            | —        | 896×128  | 128×128 | 1      | 7                | flamme (7 images)                                               |

### Ressources, moutons, arbres, décor

| Chemin (`{C}` = couleur)                     | Couleurs | Feuille  | Image        | Lignes | Images par ligne | Animations (noms probables)                                                     |
| -------------------------------------------- | -------- | -------- | ------------ | ------ | ---------------- | ------------------------------------------------------------------------------- |
| `Deco/{N}.png (×15)`                         | —        | 64×64    | image unique | —      | —                |                                                                                 |
| `Deco/{N}.png (×2)`                          | —        | 64×128   | image unique | —      | —                |                                                                                 |
| `Deco/{N}.png`                               | —        | 192×192  | image unique | —      | —                |                                                                                 |
| `Resources/Gold Mine/GoldMine_Active.png`    | —        | 192×128  | image unique | —      | —                |                                                                                 |
| `Resources/Gold Mine/GoldMine_Destroyed.png` | —        | 192×128  | image unique | —      | —                |                                                                                 |
| `Resources/Gold Mine/GoldMine_Inactive.png`  | —        | 192×128  | image unique | —      | —                |                                                                                 |
| `Resources/Resources/G_Idle.png`             | —        | 128×128  | image unique | —      | —                |                                                                                 |
| `Resources/Resources/G_Idle_(NoShadow).png`  | —        | 128×128  | image unique | —      | —                |                                                                                 |
| `Resources/Resources/G_Spawn.png`            | —        | 896×128  | 128×128      | 1      | 7                | apparition de la ressource (7 images)                                           |
| `Resources/Resources/M_Idle.png`             | —        | 128×128  | image unique | —      | —                |                                                                                 |
| `Resources/Resources/M_Idle_(NoShadow).png`  | —        | 128×128  | image unique | —      | —                |                                                                                 |
| `Resources/Resources/M_Spawn.png`            | —        | 896×128  | 128×128      | 1      | 7                | apparition de la ressource (7 images)                                           |
| `Resources/Resources/W_Idle.png`             | —        | 128×128  | image unique | —      | —                |                                                                                 |
| `Resources/Resources/W_Idle_(NoShadow).png`  | —        | 128×128  | image unique | —      | —                |                                                                                 |
| `Resources/Resources/W_Spawn.png`            | —        | 896×128  | 128×128      | 1      | 7                | apparition de la ressource (7 images)                                           |
| `Resources/Sheep/HappySheep_All.png`         | —        | 1024×256 | 128×128      | 2      | 8 / 6            | 0 repos (8) · 1 bond (6) ; les deux autres feuilles en sont les lignes séparées |
| `Resources/Sheep/HappySheep_Bouncing.png`    | —        | 768×128  | 128×128      | 1      | 6                | bond (6)                                                                        |
| `Resources/Sheep/HappySheep_Idle.png`        | —        | 1024×128 | 128×128      | 1      | 8                | repos (8)                                                                       |
| `Resources/Trees/Tree.png`                   | —        | 768×576  | 192×192      | 3      | 4 / 2 / 1        | 0 sapin qui bouge (4) · 1 sapin coupé qui vacille (2) · 2 souche (1)            |

### Interface

| Chemin (`{C}` = couleur)                             | Couleurs           | Feuille | Image        | Lignes | Images par ligne | Animations (noms probables) |
| ---------------------------------------------------- | ------------------ | ------- | ------------ | ------ | ---------------- | --------------------------- |
| `UI/Banners/Banner_Connection_Down.png`              | —                  | 192×192 | image unique | —      | —                |                             |
| `UI/Banners/Banner_Connection_Left.png`              | —                  | 192×192 | image unique | —      | —                |                             |
| `UI/Banners/Banner_Connection_Right.png`             | —                  | 192×192 | image unique | —      | —                |                             |
| `UI/Banners/Banner_Connection_Up.png`                | —                  | 192×192 | image unique | —      | —                |                             |
| `UI/Banners/Banner_Horizontal.png`                   | —                  | 192×192 | image unique | —      | —                |                             |
| `UI/Banners/Banner_Vertical.png`                     | —                  | 192×192 | image unique | —      | —                |                             |
| `UI/Banners/Carved_3Slides.png`                      | —                  | 192×64  | image unique | —      | —                |                             |
| `UI/Banners/Carved_9Slides.png`                      | —                  | 192×192 | image unique | —      | —                |                             |
| `UI/Banners/Carved_Regular.png`                      | —                  | 64×64   | image unique | —      | —                |                             |
| `UI/Buttons/Button_Disable.png`                      | —                  | 64×64   | image unique | —      | —                |                             |
| `UI/Buttons/Button_Disable_3Slides.png`              | —                  | 192×64  | image unique | —      | —                |                             |
| `UI/Buttons/Button_Disable_9Slides.png`              | —                  | 192×192 | image unique | —      | —                |                             |
| `UI/Buttons/Button_Hover.png`                        | —                  | 64×64   | image unique | —      | —                |                             |
| `UI/Buttons/Button_Hover_3Slides.png`                | —                  | 192×64  | image unique | —      | —                |                             |
| `UI/Buttons/Button_Hover_9Slides.png`                | —                  | 192×192 | image unique | —      | —                |                             |
| `UI/Buttons/Button_{C}.png`                          | bleu, rouge        | 64×64   | image unique | —      | —                |                             |
| `UI/Buttons/Button_{C}_3Slides.png`                  | bleu, rouge        | 192×64  | image unique | —      | —                |                             |
| `UI/Buttons/Button_{C}_3Slides_Pressed.png`          | bleu, rouge        | 192×64  | image unique | —      | —                |                             |
| `UI/Buttons/Button_{C}_9Slides.png`                  | bleu, rouge        | 192×192 | image unique | —      | —                |                             |
| `UI/Buttons/Button_{C}_9Slides_Pressed.png`          | bleu, rouge        | 192×192 | image unique | —      | —                |                             |
| `UI/Buttons/Button_{C}_Pressed.png`                  | bleu, rouge        | 64×64   | image unique | —      | —                |                             |
| `UI/Icons/Disable_{N}.png (×10)`                     | —                  | 64×64   | image unique | —      | —                |                             |
| `UI/Icons/Pressed_{N}.png (×10)`                     | —                  | 64×64   | image unique | —      | —                |                             |
| `UI/Icons/Regular_{N}.png (×10)`                     | —                  | 64×64   | image unique | —      | —                |                             |
| `UI/Pointers/{N}.png (×6)`                           | —                  | 64×64   | image unique | —      | —                |                             |
| `UI/Ribbons/Ribbon_{C}_3Slides.png`                  | bleu, rouge, jaune | 192×64  | image unique | —      | —                |                             |
| `UI/Ribbons/Ribbon_{C}_Connection_Down.png`          | bleu, rouge, jaune | 64×64   | image unique | —      | —                |                             |
| `UI/Ribbons/Ribbon_{C}_Connection_Down_Pressed.png`  | bleu, rouge, jaune | 64×64   | image unique | —      | —                |                             |
| `UI/Ribbons/Ribbon_{C}_Connection_Left.png`          | bleu, rouge, jaune | 64×64   | image unique | —      | —                |                             |
| `UI/Ribbons/Ribbon_{C}_Connection_Left_Pressed.png`  | bleu, rouge, jaune | 64×64   | image unique | —      | —                |                             |
| `UI/Ribbons/Ribbon_{C}_Connection_Right.png`         | bleu, rouge, jaune | 64×64   | image unique | —      | —                |                             |
| `UI/Ribbons/Ribbon_{C}_Connection_Right_Pressed.png` | bleu, rouge, jaune | 64×64   | image unique | —      | —                |                             |
| `UI/Ribbons/Ribbon_{C}_Connection_Up.png`            | bleu, rouge, jaune | 64×64   | image unique | —      | —                |                             |
| `UI/Ribbons/Ribbon_{C}_Connection_Up_Pressed.png`    | bleu, rouge, jaune | 64×64   | image unique | —      | —                |                             |

Remarques de lecture :

- **Terrain.** Tuile de **64×64**. `Tilemap_Flat.png` (640×256) porte deux herbes côte à côte, verte à gauche et sable à droite, chacune en 5 colonnes × 4 lignes de tuiles (grand bloc central, bords, bandes, îlots). `Tilemap_Elevation.png` (256×512, 4×8 tuiles) sert aux falaises ; `Shadows.png` à l’ombre portée des falaises ; `Bridge_All.png` (192×256, 3×4 tuiles) au pont ; `Water.png` (64×64) se répète pour l’eau ; `Foam.png` et `Rocks_0x.png` s’animent sur les rivages.
- **Interface.** Les `*_3Slides` (192×64) se découpent en trois bandes de 64 (neuf-tranches horizontales) et les `*_9Slides` (192×192) en 3×3 : utilisables en `NinePatchRect` ou `StyleBoxTexture`. Les icônes existent en trois états (`Regular`, `Pressed`, `Disable`) : croix, engrenage, haut-parleur, 1, 2, 3, chariot, plus, moins, cadenas (ordre des fichiers 01 à 10). Les pointeurs 01 à 06 sont une flèche, des coins de sélection et des angles.
- **Ressources.** `G_`, `M_` et `W_` (très probablement or, viande, bois ; seule la pile `G_` est confirmée à l’œil) existent en `Idle` et `Idle_(NoShadow)` (128×128) et en `Spawn` (7 images).
- **Décor.** `Deco/01.png` à `18.png` : 15 images de 64×64, deux de 64×128 et une de 192×192, statiques. Leur contenu n’est pas détaillé ici.
- **Archer + arc.** Le dossier `Archer + Bow/` sépare le corps (`NoArms`) et l’arc : on peut faire tourner l’arc à n’importe quel angle sur un corps fixe, ce qui convient mieux à la vue de dessus que les cinq directions de tir de la feuille complète.

## 3. Proposition de correspondance

### 3.1 La tour du joueur

| Élément                 | Proposition                                                                                                                                                                                                                                                                                                    |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Bâtiment                | `Factions/Knights/Buildings/Tower/Tower_{C}.png` (128×256, une image fixe). Variantes `Tower_Construction.png` (phase de préparation, facultatif) et `Tower_Destroyed.png` (défaite).                                                                                                                          |
| Pourquoi pas le château | `Castle_{C}.png` (320×256) est bien plus large que la tour de 60 unités de rayon ; il peut servir de décor de salon ou de l’écran de fin.                                                                                                                                                                      |
| Joueurs 1 à 4           | Les quatre couleurs du pack : bleu, rouge, jaune, violet.                                                                                                                                                                                                                                                      |
| Joueurs 5 à 8           | **Teinte calculée** à partir de la tour bleue (rotation de la teinte des pixels colorés, gris de pierre conservés) : vert, orange, turquoise, rose. Soit par un petit shader `canvas_item` (une valeur de teinte par joueur), soit en recolorant l’image une fois au chargement. Rendu visible sur la planche. |
| Lecture sans la couleur | Le nom du joueur reste écrit sous la tour et dans le tableau des scores, avec un numéro : la couleur ne porte jamais seule l’information (règle d’accessibilité du contexte commun).                                                                                                                           |
| Risque signalé          | Des ennemis rouges ressemblent à la tour rouge de J2. Peu gênant (la tour ne bouge pas, les ennemis marchent), mais on peut éviter le rouge pour J2 si Phil préfère.                                                                                                                                           |

### 3.2 Les 8 familles

Valeurs lues dans `data/ennemis.json`. « Cac » = corps à corps (`portee_attaque` ≤ 60). Les numéros de ligne renvoient aux feuilles de la section 2 (ligne 0 = première ligne).

| Famille actuelle                           | Armure, rôle                                | Sprite proposé                                                                            | Animations utilisées                                                               | Échelle | Nom français proposé                                                       |
| ------------------------------------------ | ------------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------- | -------------------------------------------------------------------------- |
| `mite_de_laiton` « Mites de laiton »       | légère, **volante**, portée 30, vitesse 90  | **AUCUN dans le pack (manquant)** ; voir 3.4                                              | à créer : vol, mort                                                                | n. d.   | inchangé : « Mites de laiton »                                             |
| `rodeur_de_suie` « Rôdeurs de suie »       | légère, cac 40, vitesse 75                  | Gobelin à torche, **jaune** (`Torch/Yellow/Torch_Yellow.png`)                             | repos 0, course 1, attaque 2 (côté), 3 (bas), 4 (haut)                             | ×1      | inchangé : la torche et la suie vont ensemble                              |
| `pillard_de_brume` « Pillards de brume »   | moyenne, cac 45, vitesse 60                 | Paysan **rouge** (`Pawn/Red/Pawn_Red.png`)                                                | repos 0, course 1, action à l’outil 2 ou 3                                         | ×1      | inchangé                                                                   |
| `archer_de_cendre` « Archers de cendre »   | moyenne, **distance 450**, vitesse 50       | Archer **jaune** (`Archer/Yellow/Archer_Yellow.png`) + flèche (`Arrow/Arrow.png`)         | repos 0, course 1, tirs 2 à 6 selon l’angle (haut, haut-côté, côté, bas-côté, bas) | ×1      | inchangé                                                                   |
| `golem_d_argile` « Golems d’argile »       | lourde, cac 55, vitesse 35                  | Guerrier **rouge** (`Warrior/Red/Warrior_Red.png`)                                        | repos 0, course 1, attaques 2 à 7                                                  | ×1      | **« Heaumes d’argile »** : le heaume crème, rond, a la couleur de l’argile |
| `brute_de_forge` « Brutes de forge »       | lourde, cac 60, vitesse 30                  | Guerrier **violet** (`Warrior/Purple/Warrior_Purple.png`)                                 | idem                                                                               | ×1,25   | inchangé                                                                   |
| `colosse_de_granit` « Colosses de granit » | fortifiée, cac 50, 520 PV, vitesse 25       | Gobelin au **tonneau** rouge (`Barrel/Red/Barrel_Red.png`), tonneau cerclé, gros et lent  | sortie 1 (à l’apparition), repos 2, course 4, explosion 5 (attaque ou mort)        | ×1,5    | **« Tonneaux de poudre »** : le granit jure avec un tonneau de bois        |
| `spectre_de_vapeur` « Spectres de vapeur » | aucune, **distance 250**, 60 PV, vitesse 65 | Gobelin artificier **rouge** (`TNT/Red/TNT_Red.png`) + dynamite (`Dynamite/Dynamite.png`) | repos 0, course 1, lancer 2 ; la dynamite vole jusqu’à la tour                     | ×1      | **« Artificiers de fumée »** : la mèche fume, rien de spectral             |

Rôles respectés : une seule famille volante (la mite, sans sprite pour l’instant), deux à distance (les archers à 450 et les artificiers à 250, tous deux avec un projectile visible), cinq au corps à corps. Les gobelins à torche, à dynamite et à tonneau et les chevaliers (guerrier, archer, paysan) du pack couvrent sept des huit familles. **Mort** : le pack n’offre qu’une animation de mort générique (`Dead/Dead.png`, un crâne qui s’évanouit) ; elle servira à toutes les familles. Les TNT et les tonneaux peuvent à la place mourir sur `Explosions.png`. Les couleurs des familles sont un choix de lisibilité : jaune, rouge et violet se distinguent entre elles à distance.

### 3.3 Convoi et boss

| Entité                                                                                                      | Valeurs                       | Sprite proposé                                                                                                                                                    | Animations                                                                                                          |
| ----------------------------------------------------------------------------------------------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Convoi `charrette_du_colporteur` « Charrette du colporteur » (400 PV, vitesse 45, prime 120, ne combat pas) | pas de charrette dans le pack | **Mouton** (`Resources/Sheep/HappySheep_All.png`), ×2, avec un sac d’or (`Resources/Resources/G_Idle.png`) posé à côté ou au-dessus pour dire « la prime est là » | repos (ligne 0), bond (ligne 1) pour la marche                                                                      |
| Boss `aieul_de_fer` « Aïeul de fer » (20 000 PV, vitesse 35, portée 80, armure boss)                        |                               | Guerrier **bleu** (`Warrior/Blue/Warrior_Blue.png`) à ×3, flamme (`Effects/Fire/Fire.png`) sous les pieds                                                         | repos 0, course 1, attaques 2 à 7 ; la portée 80 dépasse un peu le corps à corps, l’attaque reste celle du guerrier |

Nom proposé pour le convoi : **« Troupeau du colporteur »** (une charrette n’existe pas dans le pack). Le boss garde son nom : le chevalier en armure y colle.

### 3.4 Ce qui manque

| Manque                                                                                                  | Solution proposée                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Unité volante** (`mite_de_laiton`) : aucun sprite volant dans tout le pack. **À traiter avant T5.1.** | Choix recommandé : **un sprite fait par nous dans le même style** (pixel art 64×64 ou 128×128, ombre grise détachée du corps, trois ou quatre couleurs du pack, ligne de vol de 6 images à répéter, mort par `Dead.png`). Palliatif en attendant : gobelin à torche **violet** à ×0,7, décollé du sol (ombre restée par terre), avec un léger mouvement de haut en bas ; les frames de bond du mouton (`HappySheep_All.png`, ligne 1) montrent déjà une ombre détachée du corps pour dire « en l’air ». |
| Charrette (convoi)                                                                                      | Remplacée par le mouton et le sac d’or ; ou un chariot fait par nous. Décision de Phil.                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Mort propre à chaque famille                                                                            | `Dead.png` pour tous ; teinte ou échelle de la famille pour la distinguer ; explosion pour TNT et tonneau.                                                                                                                                                                                                                                                                                                                                                                                              |
| Tirs de la tour (armes)                                                                                 | Effets du pack : `Arrow.png`, `Fire.png`, `Explosions.png`, `Dynamite.png`, foudre, glace et poison absents. Les types magique, givre et poison se feront en **particules colorées** (rond de couleur teinté par `modulate`).                                                                                                                                                                                                                                                                           |
| Couleurs des joueurs 5 à 8                                                                              | Teinte calculée (voir 3.1).                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Plus de quatre teintes d’ennemi                                                                         | Variation d’échelle et de couleur de `modulate`, pas de nouveau sprite.                                                                                                                                                                                                                                                                                                                                                                                                                                 |

### 3.5 Noms des familles

Cinq des huit familles de `data/ennemis.json` gardent leur nom (mites, rôdeurs, pillards, archers, brutes). Trois jurent avec le sprite proposé, et le convoi aussi :

| Actuel                  | Problème                                                 | Proposé                |
| ----------------------- | -------------------------------------------------------- | ---------------------- |
| Golems d’argile         | un golem est une masse d’argile, pas un chevalier        | Heaumes d’argile       |
| Colosses de granit      | un tonneau de bois n’est pas du granit                   | Tonneaux de poudre     |
| Spectres de vapeur      | un gobelin qui lance de la dynamite n’est pas un spectre | Artificiers de fumée   |
| Charrette du colporteur | pas de charrette, un mouton                              | Troupeau du colporteur |

**Ces noms ne sont pas appliqués dans `data/` ni dans `i18n/`** : c’est Phil qui valide. Les `id` (`golem_d_argile`…) ne changent pas, seuls les libellés.

## 4. Planche de validation

Une image de 1920×1080 montre la tour (8 joueurs), le convoi, le boss, les 8 familles avec nom proposé et armure, un échantillon de terrain et les éléments d’interface. Elle n’est pas dans le dépôt (scratchpad de la session, `planche_tiny_swords.png`).

## 5. Pour T5.1

- Un `AnimatedSprite2D` ou un `Sprite2D` avec `hframes`, `vframes` et `frame` par feuille ; la feuille complète sert de `SpriteFrames` (région découpée selon la table de la section 2).
- Le rendu 2D lit toujours `VueArene` (mêmes positions, `Vector2(x, z)` en unités de jeu). L’échelle des unités de jeu vers les pixels est à fixer en T5.1 : le rayon de la tour est de 60 unités, la tour du pack fait 128 px de large.
- Orientation : miroir horizontal selon le signe de `dx` vers la tour ; `flip_h` sur le nœud.
- Choix d’animation de la ligne : repos si l’ennemi s’arrête (à distance), course sinon, attaque selon l’angle vers la tour (haut, bas, côté) pour la torche et le guerrier.
- Les feuilles à une ligne par animation se lisent à 10 images par seconde en première approximation ; à régler à l’œil.
