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
| raisonnable | manche médiane de 18 à 25                                   | 19, 31, 23, 20, 17, 19, 26, 25, 16, 17 → minimum 16, **médiane 20** (31 avant la limite de six armes)                                                                                                   |

La cible « la bonne stratégie ne tombe pas avant la manche 20 » est tenue sur les graines 1 à 10
(`test_le_robot_de_reference_n_est_pas_elimine_avant_la_manche_20`). **Correction du joueur raisonnable (Phil, 26/11/2026)** : sa médiane valait 31 (cinq graines sur dix
atteignaient le boss), parce que le robot bâtissait un arsenal complet de huit armes comme la
bonne stratégie. Il s'arrête désormais à six armes (`ARMES_VISEES_RAISONNABLE`, un joueur
raisonnable ne cherche pas l'arsenal parfait) : médiane 20, minimum 16. Avant : 21, 31, 31, 20, 18,
31, 31, 31, 18, 19 (médiane 31). Resserrer le mur après la 20 n'y changeait rien (graines 2, 3 et 8
passaient le boss même à ×3,6) et aurait supprimé les victoires de la bonne stratégie. La mesure
à 50 graines est à refaire après T9.22 (parties de plus d'une demi-heure pour la bonne stratégie).

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
  l'économie (`ARMES_MINIMUM_BONNE`) ; le joueur raisonnable s'arrête à six armes
  (`ARMES_VISEES_RAISONNABLE`).

## Partie gagnable (Phil, 27/11/2026)

Définition de Phil, citée telle quelle :

> « Pour l'avenir on préparera des scénarios pour jauger la difficulté. Une partie gagnable est une partie
> où on trouve un peu toutes les bonnes armes et améliorations, il faut aussi trouver suffisamment
> d'améliorations d'income. »

Conséquences pour toute mesure d'équilibrage :

- Une partie est **gagnable** quand la boutique a donné au joueur assez de bonnes armes et de bonnes
  améliorations, **et** assez d'améliorations de revenu. Un tirage pauvre (peu de bonnes offres, peu de revenu)
  peut perdre : c'est voulu, pas un défaut d'équilibrage.
- Un résultat se juge donc **sur les graines qui ont donné le bon tirage**, pas sur la médiane de toutes les
  graines. Toute mesure donne la part de graines où le robot a trouvé « les bonnes armes et assez de revenu »
  et son résultat sur ces graines seulement.
- Les scénarios à graine fixe qui servent de référence sont décrits en T12.11 du plan.

## Points ouverts

- Le mur de PV après la manche 20 (×2,8 par manche) est démesuré : la puissance du joueur croît
  sans plafond (améliorations multiplicatives, or inutilisé une fois l'arsenal plein).
- Les armes de portée 300 sont trop courtes face aux archers : à vérifier si c'est voulu.
- Les robots sont approximatifs ; une bonne stratégie humaine peut faire nettement mieux ou pire.
- Mesure à 50 graines : après T9.22.

## Niveaux d'arme et fin de la vente (T12.1 et T12.1b, 27/11/2026)

Un doublon monte l'arme de niveau (+30 % de dégâts de base, `niveaux.gain_degats`, et un gain de cadence
`niveaux.gain_cadence`), la vente disparaît, et le robot « bonne » ne vend plus ; il monte les niveaux d'une
arme déjà portée quand l'arsenal est plein (`GAIN_NIVEAU` de `strategies_joueur.gd`). Robot « bonne », arrêt à
la manche 20, graines 1 à 10 : `gain_cadence` 0,10 → 19 pour la graine 6 (les autres 20) ; 0,15 → 18 pour la
graine 6 ; **0,20 → 20 sur les dix graines**, valeur retenue. La graine 6 est sensible : une mesure à 50 graines
et un nouveau réglage sont l'objet de T12.9.
