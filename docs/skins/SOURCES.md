# Candidats de sprites de tour : sources et licences (T11.6, partie 1)

Relevé du 26/11/2026. **Rien n'est intégré** : ces images sont des candidats pour la validation de Phil.
Planche v4 : `docs/skins/planche_v4.png` (générée par `docs/skins/generer_planche.py`), 50 skins.

## Licences vérifiées

Chaque licence a été lue sur la page de la source (champ « License(s) » d'OpenGameArt, champ « license » d'itch.io
et texte de l'auteur). Les archives des packs n'ont **pas** été téléchargées : leur fichier de licence reste à lire
avant toute intégration.

| Pack                                        | Auteur            | URL                                                        | Licence                          | Style / adéquation                                                                    |
| ------------------------------------------- | ----------------- | ---------------------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------- |
| Spire – Tower Pack 1                        | Foozle            | https://foozlecc.itch.io/spire-tower-pack-1                | CC0 1.0 (« No generative AI »)   | Pixel art, vue de trois quarts : 2 tours × 3 niveaux (arbalète, cristal)              |
| Spire – Tower Pack 2                        | Foozle            | https://foozlecc.itch.io/spire-tower-pack-2                | CC0 1.0                          | Pixel art : 2 tours × 3 niveaux (marteau, baliste à gemmes)                           |
| Spire – Tower Pack 3                        | Foozle            | https://foozlecc.itch.io/spire-tower-pack-3                | CC0 1.0                          | Pixel art : 2 tours × 3 niveaux (arbalète à écu, tour noire runique)                  |
| Spire – Tower Pack 4                        | Foozle            | https://foozlecc.itch.io/spire-tower-pack-4                | CC0 1.0                          | Pixel art : 2 tours × 3 niveaux (réacteur, cristal doré en bois)                      |
| Wood_Tower (Tiny Swords, Gobelins)          | Pixel Frog        | `assets/tiny_swords/…/Wood_Tower/` (déjà dans le dépôt)    | licence de `assets/tiny_swords/` | Candidat tel quel, non retouché (`tour_de_guet`)                                      |
| Cannon tower, Towers of Defense, etc        | vk, LFA, d'autres | https://opengameart.org/content/cannon-tower (et voisines) | CC0                              | **Écartés** : rendu peint ou en 3D, ou trop petit (64 × 96) pour le style Tiny Swords |
| Towers for Tower Defense, Steampunk Turrets | looneybits        | https://opengameart.org/content/towers-for-tower-defense   | CC-BY 3.0                        | **Écartés** : illustrations vectorielles, pas du pixel art                            |
| Tower Defense (Top-Down)                    | Kenney            | https://opengameart.org/content/tower-defense-top-down     | CC0                              | **Écarté** : vectoriel, pas du pixel art                                              |
| TRI-GUN TURRET SET X 5                      | trockk            | https://trockk.itch.io/tri-gun-turret-set-x-5              | CC0                              | **Écarté** : rendu 3D                                                                 |

La licence Tiny Swords du dépôt est dans `assets/tiny_swords/LICENCE.md` ; la tour des Chevaliers
(`Knights/Buildings/Tower`) sert déjà de tour par défaut (`docs/tiny_swords.md` §3.1), donc elle n'est pas candidate.

## Bilan de la planche v1 (48 skins de `docs/defis.md` §5, remplacée par la v2)

9 bons candidats, 9 partiels, 7 faibles, **23 manques**. Les Spire donnent 24 images mais 8 familles seulement
(trois niveaux d'une même tour se ressemblent) : au-delà d'une quinzaine de skins distincts, il faut un autre pack ou
dessiner. Les silhouettes sans candidat : hauteur à étages, lames, œil, halo, ondes, pièges, mines, tourelles
tournantes, ruines, trophées, crânes, rond de sièges, couronne, puits, ronces, pierre fendue ou balafrée, tas de pièces.

## Limites

- Les Spire sont plus détaillés que Tiny Swords et n'ont pas de marque de couleur joueur : le jeu pose un fanion
  (zone `marque` du JSON). Leurs superpositions (D19) sont dessinées pour la tour par défaut : l'`echelle` du
  skin les adapte, à ajuster à l'œil en T11.7.
- Recherches de la première passe : 0 appel de WebSearch ; une vingtaine de requêtes de listes OpenGameArt et
  itch.io et une trentaine de pages de packs lues directement.

## Nouvelle recherche (planches v3 et v4)

Décision de Phil (26/11/2026) : les ébauches dessinées sont écartées (le script de dessin est supprimé), changer de
famille est permis, et un skin sans candidat reçoit le **meilleur rapprochement** plutôt qu'un dessin pauvre.

- **Recherche :** 9 recherches web, plus un relevé par requêtes directes d'OpenGameArt (11 mots-clés, filtres CC0 et
  CC-BY, 195 fiches ouvertes, vignettes regardées une à une). itch.io a répondu 403 au relevé par étiquettes après les
  premiers essais.
- **Résultat :** aucun autre pack de tours en pixel art sous CC0 ou CC-BY ne forme une famille cohérente. Les packs de
  tours « libres » trouvés (Pixel Tower Defenders de codelaboratory, Archer et Guardian Towers de free-game-assets,
  Pixel Castle Towers de pixelmateai, Simple Tower Defense de skyel13) ont des conditions maison ou CC-BY-ND, donc
  **hors critère** (CC0 ou CC-BY seulement). OpenGameArt ne donne que des tuiles 16 × 16, des rendus 3D ou des
  vecteurs (Kenney, looneybits, Bleed, LPC, MiniWorld de Shade en 16 × 16, Tiny Town de Kenney).
- **Famille retenue :** les 24 tours **Spire** de Foozle (CC0), mêlées aux bâtiments de **Tiny Swords** déjà dans le
  dépôt (`assets/tiny_swords/`, CC0, non retouchés) : tour de bois et cabane des Gobelins, tour en chantier et tour en
  ruine, maison, mine d'or des Chevaliers (le château, 320 px de large, dépasse les 256 px permis). La tour des Chevaliers reste la tour par défaut.
- **Planche v4** (`docs/skins/planche_v4.png`, 50 skins, lue dans `data/skins_tour.json`) : 9 bons candidats, 13
  partiels, 28 rapprochés ; 31 images distinctes pour 50 skins, soit **19 réemplois** (une même image sert deux ou
  trois skins), acceptés par Phil (26/11/2026), sans variante de couleur. Un skin vraiment distinct pour chacun
  demande un pack de plus ou un dessinateur.
- **Archives Spire** (27/11/2026) : fournies par Phil, `Readme.txt` de chaque pack lu (CC0, commandé à Baldur,
  distribué par Foozle). Les fichiers de base des huit tours (`Towers bases/PNGs/`) sont copiés tels quels sous
  `assets/tours/` ; les armes, projectiles, GIF et `.aseprite` ne sont pas repris. La tour est vide : les armes du
  joueur y sont dessinées par le jeu. Les couvertures de pack utilisées par la planche v3 sont remplacées par ces
  vrais sprites (`docs/skins/apercus/` supprimé).
- **Marque de couleur** :** le fanion bleu de la planche est posé à l'affichage, dans la zone `marque` du JSON, comme le fera le jeu (T11.7) ;
  aucun fichier de sprite n'est modifié. Marque d'origine (teintable) : les bâtiments bleus de Tiny Swords. Les
  Spire reçoivent toujours un fanion : leurs couleurs (cristaux, runes) sont celles de leur dessin.

Sources des bâtiments Tiny Swords : `assets/tiny_swords/LICENCE.md` (Pixel Frog, https://pixelfrog-assets.itch.io/tiny-swords,
« TS_old version_CC0 Licensed »).

## Candidats de remplacement (étape 3, 27/11/2026)

Décision de Phil (27/11) : chercher d'autres packs gratuits pour remplacer les skins qui ne collent pas à leur thème
(les 28 rapprochés, puis les 13 partiels), avec un style compatible ou une autre famille. Planche :
`docs/skins/planche_candidats_v5.png` (script `docs/skins/generer_candidats.py`). **Rien n'est intégré** :
`data/skins_tour.json` et `assets/tours/` ne changent pas.

- **Recherche :** 9 recherches web de plus (18 au total pour T11.6), un relevé OpenGameArt par requêtes directes, et
  la lecture des pages des packs trouvés.
- **Retenu : MiniWorld Sprites** (Shade), CC0 : https://opengameart.org/content/miniworld-sprites (page : « License(s) :
  CC0 ») et https://merchant-shade.itch.io/16x16-mini-world-sprites (listé dans les assets CC0 d'itch.io).
  Archive téléchargée par le lien direct d'OpenGameArt (`miniworldsprites_1.zip`), sans jeton ni contournement ; elle
  ne contient pas de fichier de licence (seulement `OtherLinks.docx`, un mot de remerciement) : la licence est celle de la
  page. Des bâtiments de 16 px aux contours épais, d'un style voisin de Tiny Swords : puits, étals de marché, palissade
  de pieux, maisons, tavernes, ateliers, casernes, donjon, mausolée, tours de pierre, coffres.
- **Retenu : Ruining tower** (Blarumyrran), CC0 : https://opengameart.org/content/ruining-tower (une tour en ruine,
  pixel art).
- **Écartés :** Tiny Town et Tiny Dungeon (Kenney, CC0) : des tuiles de décor, pas de bâtiments ; Old tower
  (manwesulimo2004, CC0) : une tour moussue peinte, pas du pixel art ; Castle and Village de edermunizz (CC-BY 4.0) :
  payant (9 $) et interdit de redistribution des fichiers ; Stone Tower Defense de CraftPix (OGA-BY 3.0, vectoriel),
  CraftPix et GameArt2D en général (licences maison) ; Pixel Castle Towers, Pixel Buildings, Building Pack et les
  packs de pixel-1992 (conditions maison ou génération par IA) ; Tower 4 damaged versions (CC-BY-SA 3.0) et Platformer
  Ice Tileset (CC-BY-SA 3.0) : partage à l'identique.
- **Bilan :** sur les 41 skins visés, 18 ont un candidat. « Bons » : **9 aujourd'hui, 17** avec les meilleurs candidats
  (puits, comptoir, embuscade, famille, les trois tours de pierre unie, tour de pierre). Aucun candidat libre pour la
  lame, l'œil, le halo, le manège, le tonnerre, le sang, le bouclier, les balafres, la faux, les trophées, le cratère,
  l'artificier, le sapeur, la nuée, les ondes (pas de pack de tours magiques, élémentaires ou à pièges en pixel art
  libre de droits).
- **À télécharger à la main :** aucun pack. Les deux archives retenues viennent de liens directs d'OpenGameArt.
- **Point technique avant intégration :** les candidats MiniWorld font 16 px : le jeu devra les agrandir d'un facteur
  entier (huit pour s'approcher de la tour par défaut). Ce facteur doit vivre dans `data/skins_tour.json` (nouveau
  champ, à ajouter avec la session Apparence) et non dans le code ; changer la taille d'un fichier ne doit pas
  demander de toucher au code.
