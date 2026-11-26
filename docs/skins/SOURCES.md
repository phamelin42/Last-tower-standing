# Candidats de sprites de tour : sources et licences (T11.6, partie 1)

Relevé du 26/11/2026. **Rien n'est intégré** : ces images sont des candidats pour la validation de Phil.
Planche v2 : `docs/skins/planche_v2.png` (générée par `docs/skins/generer_planche.py`), 50 skins : 18 candidats Spire ou Gobelin, 32 sprites dessinés.

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

- Les aperçus de `docs/skins/apercus/` sont recadrés dans les images de couverture publiées par l'auteur : il faut
  télécharger les packs (itch.io demande un clic, que le conteneur a refusé de scripter) pour les vrais fichiers.
- Les Spire sont plus détaillés que Tiny Swords et portent déjà une arme ou un cristal au sommet, ce qui peut
  gêner les superpositions de D19 et la zone de marque de couleur (ils n'ont ni drapeau ni liseré de couleur joueur
  garanti, sauf la bannière bleue des packs 1 et 3).
- Recherches : 0 appel de WebSearch ; une vingtaine de requêtes de recherche OpenGameArt et itch.io (pages de listes
  filtrées par licence) et une trentaine de pages de packs lues directement.

## Sprites dessinés (planche v2)

Décision de Phil relayée par la pilote (26/11/2026) : les 7 skins « faibles » et les 23 manques sont **dessinés par
script**, sans IA ni Aseprite ni sprite retouché ; s'y ajoutent deux skins provisoires pour les défis « zone posée »
et « bombe » (PR #85, pas encore dans `docs/defis.md`), soit 32 sprites.

- `tools/dessiner_tours.py` trace chaque tour de zéro (rectangles, ellipses, lignes de Pillow sur une grille de
  64 × 96, agrandie au plus proche voisin en 128 × 192), dans la palette de Tiny Swords (contour `#161c2e`, pierre,
  bois). Aucune image n'est lue : licence du dessin = celle du dépôt.
- Chaque sprite porte une **marque de la couleur du joueur** (drapeau, liseré ou bannière) dans le bleu de Tiny
  Swords, teintable ; sa zone est dans `docs/skins/dessines/marques.json`. Les candidats Spire n'ont pas tous de
  marque : seule la bannière bleue du pack 1 (arbalète) en a une, les autres la reçoivent du jeu (T11.7).
- Ce sont des **ébauches** de planche : lisibles à la taille du jeu, mais plus simples que les Spire. À valider ou
  retoucher par Phil avant toute intégration.
