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
- Mesure à 50 graines : après T9.22, et **reprise par T12.9** une fois les armes tardives du lot 12 en place
  (le lot 12 rééquilibre tout) ; aucune valeur de T9.22 n'est donc figée à 50 graines.

## Niveaux d'arme et fin de la vente (T12.1 et T12.1b, 27/11/2026)

Un doublon monte l'arme de niveau (+30 % de dégâts de base, `niveaux.gain_degats`, et un gain de cadence
`niveaux.gain_cadence`), la vente disparaît, et le robot « bonne » ne vend plus ; il monte les niveaux d'une
arme déjà portée quand l'arsenal est plein (`GAIN_NIVEAU` de `strategies_joueur.gd`). Robot « bonne », arrêt à
la manche 20, graines 1 à 10 : `gain_cadence` 0,10 → 19 pour la graine 6 (les autres 20) ; 0,15 → 18 pour la
graine 6 ; **0,20 → 20 sur les dix graines**, valeur retenue. La graine 6 est sensible : une mesure à 50 graines
et un nouveau réglage sont l'objet de T12.9.

## Rampe de dégâts ennemis (proposition du 27/11/2026, appliquée : voir « La mana chère »)

Phil a laissé la décision au lot 12 (T12.9). Mesure du 27/11 sur le robot « bonne », graines 1 à 4, build normal
(avec siphon de mana) et sans siphon ; `apres_table.degats` agit après la manche 20 seulement, donc D16 et D17
(manches 1 à 20) sont intactes à toute valeur.

| Manche | 1,06 (actuel) | 1,10 | 1,14 |
| ------ | ------------- | ---- | ---- |
| 25     | 0,80          | 0,97 | 1,16 |
| 30     | 1,29          | 1,87 | 2,67 |
| 35     | 1,73          | 3,01 | 5,14 |

- PV perdus sans siphon après la manche 20 (graines 1 et 4) : 14 397 et 3 490 à 1,06, contre 24 862 et 6 827 à
  1,14, sans mort avant le boss (manche 31 conservée). 1,10 pèse trop peu (+40 à 60 %) ; 1,18 tue des builds
  (graine 2 : 1 440 → 20 829 PV perdus).
- Avec siphon (`nova_celeste`), la tour reste invulnérable à toute rampe : voulu, le bouclier de mana n'a pas de
  plafond (D12).
- « Raisonnable » tombe avant la manche 20 : la rampe ne l'atteint pas.
- Partie gagnable (10 graines, « bonne ») : victoires sur 3 graines ; à 30 améliorations de revenu ou plus, 3
  victoires sur 6, en dessous 0 sur 4 : le revenu sépare les résultats, l'arme seule non.
- Plancher de défense de 15 % (`reduction_degats_max`, #135) : neutre en jeu tant que la mana siphonnée absorbe
  le reste.

## Suivis : ce qui ne se fait pas

- **Tirs des ennemis à distance (Phil, 27/11/2026 : « on laisse comme ça »)** : purement visuels
  (`visuels/tirs_ennemis.gd`, réglages dans `data/assets.json`), déduits de la vue d'arène. Aucun événement de tir
  ennemi dans `VueArene` ni dans `Protocole` : ne pas l'ajouter.

## Robots du lot 12 (T12.9, première phase, 27/11/2026)

`StrategiesJoueur` suit les règles du lot 12 : plus de vente, un niveau de plus d'une arme déjà portée quand
l'arsenal est plein (valeur : `niveaux.gain_degats + niveaux.gain_cadence`, lue dans les données), les raretés de fin
de partie s'achètent, et la « bonne » stratégie préfère de 2 fois les améliorations de revenu tant qu'elle en a moins de
30 (Phil, 27/11/2026 : « suffisamment d'améliorations d'income »). Mesure de départ, robot « bonne », graines 1 à 10,
catalogue d'avant les 15 armes tardives (T12.7), combat contre le boss limité à 400 s :

| Mesure                                  | Résultat                                                                      |
| --------------------------------------- | ----------------------------------------------------------------------------- |
| Or restant au début du combat du boss   | 99 à 584 or sur 9 graines (la graine 8 tombe en manche 23) : l'or est dépensé |
| Niveaux d'armes au boss                 | 63 à 102 niveaux répartis sur 8 armes                                         |
| Améliorations de fin de partie achetées | 1 à 5 par graine                                                              |
| Améliorations de revenu au boss         | 11 à 28 (le tirage en offre peu : la cible de 30 n'est jamais atteinte)       |
| Boss vaincu en moins de 400 s           | 0 graine sur 9 (une victoire en 142 s sans le boost de revenu, graine 6)      |

La mesure complète (boss, 50 graines, leviers) attend T12.7 (15 armes) et S27 : voir T12.9.

## La mana chère (T12.9, 27/11/2026)

Phil, 27/11/2026 : « arrivé jusqu'au boss avec 1 200 ennemis […] je ne perdais aucun point de vie […] le mana
ça semble trop fort ». Mesure sur `main` avant changement, robot de siphon (armes et améliorations de mana
d'abord, puis « bonne »), graine 5, manche 30 : 8 500 dégâts bruts par seconde, ramenés à 2 600 par l'armure et la
réduction du voile de brume, absorbés par la mana, que le siphon rendait à 4 600 à 5 600 par seconde. Le siphon
verse un débit **par ennemi** : il croît avec la foule et n'avait aucun plafond. Le vol de vie soigne aussi de
400 à 5 000 PV par seconde en manches 24 à 30 sur d'autres graines : non touché ici.

Décision de Phil (D12 inchangé : le bouclier absorbe tout, mais il coûte plus et se recharge moins) :

- `tour.siphon_mana_max_par_s` = **600** : plafond du siphon de mana de toute la tour, par seconde ;
- `tour.mana_cout_par_pv` = **2** : points de mana pour absorber un point de dégât ;
- `apres_table.degats` = **1,14** (au lieu de 1,06 : table ci-dessus).

Mesure (graines 1 à 8, 60 s de combat contre le boss ; « tient » = vivante après ces 60 s) :

| Configuration                   | Siphon : au boss | Bonne : au boss | Raisonnable : au boss (morts) |
| ------------------------------- | ---------------- | --------------- | ----------------------------- |
| Avant (plafond ∞, coût 1, 1,06) | 5/8              | 6/8             | 5/8 (19, 23, 24)              |
| Rampe 1,14 seule                | 5/8              | 5/8             | 4/8 (19, 23, 24, 26)          |
| 600/s, coût 2, 1,14 (retenu)    | 6/8              | 3/8             | 4/8 (17, 19, 23, 24)          |
| 400/s, coût 3, 1,14             | 5/8              | 3/8             | 3/8 (17, 19, 22, 24, 27)      |
| 600/s, coût 1,5, 1,14           | 5/8              | 4/8             | 4/8 (18, 19, 23, 24)          |
| 800 ou 1 000/s, coût 2, 1,14    | 6/8              | 3/8             | 4/8 (17, 19, 23, 24)          |

- Un siphon bien construit tient toujours (graines 4, 5, 6, 7 et 8 tiennent) mais ne reste plus à 100 % : graine 5,
  qui ne perdait aucun PV, passe sous 100 % pendant 79 des 272 secondes mesurées à partir de la manche 24 et
  descend à 82 %.
- Aucune « bonne » ne tombe avant la manche 23 (D17 intacte) ; la tour qui achète tout, jouée par un robot qui
  prend sans réfléchir, ne tenait déjà pas avant le changement (1 graine sur 8 au boss) : pas une référence.
- Le plafond de 600 par seconde ne pèse presque rien face au coût : 800 ou 1 000 donnent les mêmes résultats.
  C'est le coût de la mana qui travaille ; le plafond empêche la foule de le contourner.
- Prix : la « bonne » passe de 6 à 3 graines sur 8 au boss, et la graine 6 de « raisonnable » tombe en manche 17
  (26 avec la seule rampe, 31 avant). La mesure à 50 graines de T12.9 réajuste les leviers de puissance.
- Le plafond ne porte que sur le siphon ; la mana rendue au coup (`mana_au_coup`, 500 à 800 par seconde sur la
  graine 5) n'est pas plafonnée.

## Coût d'un pas de simulation (S27, 27/11/2026)

Profil par section d'un pas d'arène (`Arene.avancer`), catalogue complet, 10e centile de blocs de quatre pas avec
une lecture de la vue (`test_cout_du_pas`) :

| Scénario (90 armes, lot 12 compris) | Avant   | Après        |
| ----------------------------------- | ------- | ------------ |
| aucun ennemi                        | 8,2 ms  | 0,38 ms      |
| 500 ennemis à portée                | —       | 3,1 à 3,9 ms |
| 1 000 ennemis à portée              | 10,1 ms | 5,2 à 5,7 ms |
| 1 000 ennemis et 64 alliés          | 11,0 ms | 5,4 à 5,9 ms |

- Cause principale : le contexte de tir était reconstruit pour chaque arme prête à chaque pas, même sans ennemi à
  sa portée (`communes_par_type`, 60 µs par arme). Il l'est maintenant une fois par pas et seulement si une cible
  existe à portée.
- Le reste vient des coups portés : environ 4 µs par ennemi touché, 8 à 12 µs avec des statuts. Les armes du lot 12
  (auras, ondes et barrages à statuts, portée 1 000 à 1 250) en ajoutent. Le plan vise 5 ms au pire cas : il reste
  à tenir avec 1 000 ennemis, à reprendre en T12.9 (budget actuel du test : 7 ms).
- Comportement inchangé : empreintes de vue identiques avant et après sur 600 pas (catalogue complet) et sous
  charge (1 000 ennemis, 64 alliés), équilibrage identique sur 4 graines pour les trois robots.
