# Skins de tour réalistes : deux pistes (T11.6, 27/11/2026)

Décision de Phil (27/11) : aucun skin pixel art ne convient ; chercher des tours **réalistes ou peintes**, le reste du
jeu restant en pixel art (Tiny Swords). **Rien n'est intégré** : ni `data/skins_tour.json` ni `assets/tours/`.

- Planche de la piste a : `planche_piste_a.png` (8 sprites 2D réalistes).
- Planche de la piste b : `planche_piste_b.png` (12 tours rendues par Blender).
- Maquettes en jeu, à la taille réelle : `maquettes_en_jeu.png` (tour par défaut, 4 candidats de chaque piste). Le fond est
  une capture de `tools/vitrines/vitrine_mouvement.tscn` dont la tour par défaut a été recouverte d'une pièce d'herbe
  (les raccords se voient : c'est une maquette, pas un rendu du jeu).

## Piste a : sprites 2D réalistes ou peints

Licences lues sur la page OpenGameArt de chaque sprite (champ « License(s) ») ; téléchargement par lien direct,
sans jeton.

| Sprite                                    | Auteur                      | Licence   | Source                                                                    |
| ----------------------------------------- | --------------------------- | --------- | ------------------------------------------------------------------------- |
| Tour de garde en pierre (iso 2.5D)        | Colorado Stark              | CC0       | https://opengameart.org/content/medieval-stone-guard-tower-isometric-25d  |
| Tour de garde en bois (iso 2.5D)          | OpenGameArt (CityBuilding…) | CC0       | https://opengameart.org/content/medieval-wooden-guard-tower-isometric-25d |
| Vieille tour moussue                      | manwesulimo2004             | CC0       | https://opengameart.org/content/old-tower                                 |
| Tour ronde en brique                      | shirish                     | CC-BY 3.0 | https://opengameart.org/content/brick-tower-large-sprite                  |
| Tour sombre fantastique                   | Snabisch                    | CC0       | https://opengameart.org/content/fantasy-tower-dark                        |
| Tour d'archers en métal (Medieval series) | Snabisch (CityBuildingKit)  | CC0       | https://opengameart.org/content/steampunk-archer-tower-medieval-series    |
| Tour viking en bois                       | OpenGameArt (CityBuilding…) | CC0       | https://opengameart.org/content/viking-archer-tower-low-poly              |
| Château d'Europe de l'Ouest (iso 2.5D)    | Andrettin                   | CC0       | https://opengameart.org/content/western-european-castle-isometric-25d     |

Constat : huit sprites seulement, de perspectives différentes (isométrique, face, dessus), dont deux avec un losange
d'herbe au pied ; une seule tour par thème ; une licence CC-BY (crédit à écrire). Aucun ne couvre les thèmes de lame,
d'œil, de glace, d'or, de poison, etc. Écartés : Galata Tower (fond opaque), Dark Towers (CC-BY-SA), Tower 4 damaged
versions (CC-BY-SA), Electric tower (CC-BY-SA), Stone Tower Defense de CraftPix (OGA-BY, vectoriel).

## Piste b : modèles 3D CC0 rendus en sprites par Blender

**Blender 4.5.17 LTS** s'installe dans le conteneur : archive officielle de `download.blender.org`, somme SHA-256 du
fichier `.sha256` publié par l'éditeur vérifiée, aucune installation système. Rendu headless Cycles (CPU, sans GPU),
glTF et FBX importables. Blender est sous GPL : outil libre autorisé.

| Source                                                      | Contenu utilisé                                               | Licence | URL                                                         |
| ----------------------------------------------------------- | ------------------------------------------------------------- | ------- | ----------------------------------------------------------- |
| Kenney, Castle Kit 2.0                                      | pièces de tours carrées, hexagonales, toits, drapeaux, engins | CC0     | https://opengameart.org/content/castle-kit                  |
| Kenney, Graveyard Kit 5.0                                   | stèles, croix, obélisque, panier de feu, cryptes, squelette   | CC0     | https://opengameart.org/content/graveyard-kit               |
| Kenney, Fantasy Town Kit 2.0                                | étal, chariot, bannières, lanternes                           | CC0     | https://opengameart.org/content/fantasy-town-kit            |
| Kenney, Tower Defense Kit (disponible, non utilisé ici)     | tours rondes et carrées en pièces, cristaux, armes            | CC0     | https://opengameart.org/content/tower-defense-kit           |
| Poly Haven, textures PBR 1k (pierre, brique, mousse, bois…) | `old_stone_wall`, `mossy_brick`, `snow_02`, `marble_01`, etc. | CC0     | https://polyhaven.com/license (licence CC0 de tout le site) |
| Poly Haven, HDRI `belfast_open_field` 1k                    | éclairage                                                     | CC0     | https://polyhaven.com/a/belfast_open_field                  |

Les archives Kenney viennent de liens directs d'OpenGameArt ; leur `License.txt` dit « Creative Commons Zero, CC0 ».
Poly Haven : API publique `api.polyhaven.com`, fichiers sur `dl.polyhaven.org`, sans jeton. Auteurs des textures : Rob
Tuytel, Amal Kumar, Charlotte Baglioni, Dario Barresi et Dimitrios Savva (crédits facultatifs sous CC0).

Chaîne : `rendre_tours.py` (script Blender) assemble les pièces d'une tour, les habille de textures PBR (projection en
boîte, sans dépliage), ajoute des accessoires, éclaire par HDRI et soleil, photographie en orthographique à 28° de
plongée, ombre au sol par « shadow catcher », fond transparent, 512 × 768 puis réduction à 256 × 384. `compose_planches.py`
assemble les planches et les maquettes. Aucune image n'est générée par IA ; aucune n'est copiée d'un jeu.

### Coût des 50 tours (estimation)

- **Calcul :** 13 s par tour en 512 × 768 sur 4 cœurs CPU, soit environ **11 minutes** pour 50 tours ; un rendu 1024 × 1536
  (plus net après réduction) coûterait environ quatre fois plus, 45 minutes. Poids : 50 PNG de 256 × 384, environ 2 Mo.
- **Travail de l'agent :** une ligne de recette par tour (pièces, texture, teinte, accessoires) ; un thème sur deux se
  règle au premier rendu, les autres demandent deux ou trois essais. Compter **2 à 3 heures de session** pour les 50, plus
  les retouches après les remarques de Phil. Chaque tour reste un fichier PNG remplaçable (règle des assets remplaçables).
- **Intégration :** les tours sont statiques (pas d'animation), un PNG par skin ; `echelle` et ancrages se règlent comme
  pour les autres skins. Le champ d'agrandissement du sprite (nouveau, dans `skins_tour.json`) n'est pas nécessaire :
  les rendus sont produits à la taille voulue.

### Thèmes faisables

Les 12 tours de la planche couvrent une partie des 50 skins. Classement par difficulté :

| Difficulté                                   | Skins                                                                                                                                                                                                                                                                                                                                             |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Facile : autre texture ou autre forme (≈ 22) | de pierre, nue, ascète, granit, du vainqueur, guet, rafistolée, familière, éternelle (mousse), du puits, gelée, braise, fissure, sanguine, trésor, banquier, dragon avare, ricochet, tonnerre (métal), sans horizon (empilée), conquérante, dernier rempart                                                                                       |
| Moyen : accessoires de Kenney (≈ 16)         | embuscade (palissade, fosses), sapeur et artificier (tonneaux, caisses), comptoir (étal, balance), chariot, arsenal (râteliers, engins de siège), bastion (bélier), ossuaire (stèles, squelette), survivante (ruines, panier de feu), table ronde, veterane (trophées, bannières), cratère (blocs, braises), duelliste, monolame, bouclier (dôme) |
| Difficile : géométrie à construire (≈ 12)    | œil (sphère et paupières), lame et faux (pointes, lames), halo et nuée (anneau lumineux au sol), ondes (anneaux gravés), manège (bras articulés), cicatrisée (entailles), ronces (lianes), salve (râteliers de traits), venimeuse (écoulements), pointe (traits plantés), magique (cristaux)                                                      |

Les skins « difficiles » se construisent avec les primitives de Blender (cônes, tores, cylindres) et des matériaux émissifs :
faisable, mais chaque tour demande plus d'essais.

## Recommandation

**Piste b**, avec une réserve de style. Elle seule peut donner 50 tours distinctes et cohérentes entre elles (même
lumière, même caméra, même échelle), avec des matériaux réalistes (textures photographiques Poly Haven) et des
accessoires par thème ; chaque tour est un PNG remplaçable. Réserve : les formes de Kenney sont simples (tours carrées
et hexagonales), le rendu est « 3D propre » plutôt que photoréaliste, et le saut de style avec le pixel art de l'arène
est net (voir les maquettes). La piste a est plus peinte et plus détaillée, mais elle ne livre que huit sprites
hétérogènes (perspectives différentes, une licence à créditer) : elle sert au mieux de **renfort** pour quelques skins
« héros » (vieille tour moussue pour l'éternelle, tour viking pour le guet, tour d'archers pour le ricochet).

Prochaine étape suggérée : Phil choisit la piste ; pour la b, un lot de quelques tours « difficiles » (œil, lame, halo)
et une passe de matériaux avant de produire les 50.
