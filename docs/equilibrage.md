# Équilibrage

Mesure d'une partie : `godot --headless --path . --script res://tools/equilibrage.gd -- --graines 50 --strategie <passive|raisonnable|bonne|toutes>`.
Un joueur seul, une partie complète à pleine vitesse. Les robots vivent dans
`tests/outils/strategies_joueur.gd` ; `tests/unitaires/test_equilibrage_partie.gd` garde les
cibles dans la suite. Une partie qui va jusqu'au boss dure plusieurs minutes : pour essayer un
réglage, lancer `SimulationEquilibrage.jouer(d, graine, robot, 20)`, qui s'arrête à la manche 20
(deux secondes par graine), puis les parties complètes sur les graines 1 à 10.

## Cibles et résultats (T8.21 et T9.26, 26/11/2026)

Catalogue final du lot 9 : 75 armes et 87 améliorations.

| Robot       | Cible                                                       | Mesuré, graines 1 à 10                                                                                                                                                                                  |
| ----------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| passive     | tombe au plus tard à la fin de la manche 3 (D16, T8.8)      | manche 3 (tenu par `test_sans_achat_la_tour_tombe_…`)                                                                                                                                                   |
| bonne       | ne tombe pas avant la manche 20 ; bat le boss sur 10 à 30 % | **20 / 20 / 20 / 20 / 20 / 20 / 20 / 20 / 20 / 20** (arrêt à la 20) ; parties complètes : 31, 31 (victoire), 31, 31, 31, 31, 31, 31 (victoire), 25, 31 → minimum 25, médiane 31, **2 victoires sur 10** |
| raisonnable | manche médiane de 18 à 25                                   | 21, 31, 31, 20, 18, 31, 31, 31, 18, 19 → minimum 18, **médiane 31** (au-dessus de la cible)                                                                                                             |

La cible « la bonne stratégie ne tombe pas avant la manche 20 » est tenue sur les graines 1 à 10
(`test_le_robot_de_reference_n_est_pas_elimine_avant_la_manche_20`). **Écart** : la médiane du
joueur raisonnable (31) dépasse la cible de 18 à 25 : cinq graines sur dix atteignent le boss. Les
fermer davantage ferait tomber le taux de victoire de la bonne stratégie sous 10 %. La mesure à
50 graines est à refaire après T9.22 (parties de plus d'une demi-heure pour la bonne stratégie).

Les D16 (passive en manche 3) et D17 (PV et dégâts strictement croissants) sont intacts.

## Ce qui a fait bouger les chiffres

| Réglage (robot « bonne », graines 1 à 10, arrêt manche 20)                 | Manches atteintes                       |
| -------------------------------------------------------------------------- | --------------------------------------- |
| T8.8 : dégâts ×0,2 → ×1,79, PV ×1 → ×2,16 sur les manches 1 à 20           | min 6, médiane 14                       |
| Rampes presque plates (dégâts ×1,01, PV ×1,002)                            | min 8 : la graine 6 manque d'or         |
| Prime des ennemis jaunes ×3, rampes ×1,03 par manche                       | min 17 sur l'ancien catalogue           |
| Catalogue de 75 armes, mêmes réglages                                      | min 5 (graine 4), 3 graines sous 12     |
| Prix des cinq communes promues ramenés à leur rendement                    | min 8, médiane 20                       |
| Primes 4,5 / 5 / 5,5 / 7 par palier                                        | min 13, médiane 20                      |
| **Poids de genre de la boutique : armes ×3 au début, ×2 dès la manche 12** | **toutes les graines atteignent la 20** |

Les rampes de dégâts et de PV ne sont pas le levier des morts précoces. Deux choses décident de
l'arsenal des premières manches :

- **L'or** : les primes du palier jaune (la bonne stratégie tombait en manche 8 faute d'or) ;
- **L'offre** : avec 75 armes, la boutique de départ ne proposait parfois aucune arme abordable
  (les communes sont cinq sur dix-huit communes ; les rares coûtent plus de 500 or). Le poids de
  genre (`poids_genre` de `data/boutique.json`, lu par `Boutique`) règle la part d'armes dans les
  offres sans toucher aux raretés.

## Réglages retenus

- `data/difficulte.json` : dégâts ×0,2, ×0,224 et ×0,252 aux manches 1 à 3 (D16), puis ×1,03 par
  manche (×0,417 à la manche 20) ; PV ×1,03 par manche (×1,754 à la manche 20) ; vitesse et
  résistance de T8.8 ; `apres_table` : PV ×2,8 par manche après la 20, dégâts ×1,06.
- `data/ennemis.json` : primes des paliers 4,5 (jaune), 5 (rouge), 5,5 (violet), 7 (bleu), croissantes
  comme l'exige `test_la_force_croit_avec_le_palier` ; le Guerrier apparaît à la manche 2 et le
  Tonneau à la manche 4 ; le boss a 35 000 PV (20 000 avant).
- `data/armes.json` : prix des cinq communes promues, au rendement de leur rareté (lame de fil 110,
  arbalète de bureau 125, étincelle runique 120, bombarde de poche 165, dé pipé 100).
- `data/boutique.json` : poids de rareté de la manche 1 : 30 / 55 / 15 / 0 ; nouveau `poids_genre`.
- `data/partie.json` : la clé `emplacements_armes` est supprimée (plus de plafond d'armes depuis
  le lot 8), gardée par `test_emplacements_armes_n_est_plus_lu_nulle_part`.
- `tests/outils/strategies_joueur.gd` : la bonne stratégie achète d'abord trois armes avant
  l'économie (`ARMES_MINIMUM_BONNE`).

## Points ouverts

- Le mur de PV après la manche 20 (×2,8 par manche) est démesuré : la puissance du joueur croît
  sans plafond (améliorations multiplicatives, or inutilisé une fois l'arsenal plein).
- Les armes de portée 300 sont trop courtes face aux archers : à vérifier si c'est voulu.
- Les robots sont approximatifs ; une bonne stratégie humaine peut faire nettement mieux ou pire.
- Mesure à 50 graines et réglage fin de la médiane de « raisonnable » : après T9.22.
