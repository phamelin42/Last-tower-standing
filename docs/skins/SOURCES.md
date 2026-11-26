# Candidats de sprites de tour : sources et licences (T11.6, partie 1)

Relevé du 26/11/2026. **Rien n'est intégré** : ces images sont des candidats pour la validation de Phil.
Planche v3 : `docs/skins/planche_v3.png` (générée par `docs/skins/generer_planche.py`), 50 skins.

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

## Nouvelle recherche (planche v3)

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
- **Planche v3** (`docs/skins/planche_v3.png`, 50 skins) : 9 bons candidats, 13 partiels, 28 rapprochés ; 31 sprites
  distincts pour 50 skins, soit **19 réemplois** (un même sprite sert deux ou trois skins). Un vrai skin distinct
  pour chacun demande un pack de plus ou un dessinateur : à décider.
- **Marque de couleur :** le fanion bleu de la planche est posé à l'affichage, par-dessus l'aperçu, comme le fera le
  jeu (T11.7) ; aucun fichier de sprite n'est modifié. Marque d'origine : fanions du Gobelin, tout le bleu des
  bâtiments Chevaliers et la bannière du pack Spire 1.

Sources des bâtiments Tiny Swords : `assets/tiny_swords/LICENCE.md` (Pixel Frog, https://pixelfrog-assets.itch.io/tiny-swords,
« TS_old version_CC0 Licensed »).
