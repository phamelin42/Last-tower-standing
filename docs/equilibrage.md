# Équilibrage

Mesure : `godot --headless --path . --script res://tools/equilibrage.gd -- --graines 50 --strategie <passive|raisonnable|bonne|toutes>`.
Un joueur seul, une partie complète à pleine vitesse, graines 1 à 50. Les robots vivent dans
`tests/outils/strategies_joueur.gd` ; `tests/unitaires/test_equilibrage_partie.gd` garde les
cibles dans la suite. Compter une vingtaine de minutes pour « raisonnable » et une demi-heure
pour « bonne » à 50 graines (les parties longues vont jusqu'au boss) : essayer un réglage sur les
graines 1 à 10 d'abord.

## Cibles et résultats (T8.21, 26/11/2026)

| Robot       | Cible                                                            | Mesuré (50 graines)                                       |
| ----------- | ---------------------------------------------------------------- | --------------------------------------------------------- |
| passive     | tombe au plus tard à la fin de la manche 3 (D16, T8.8)           | manche 3 pour les 50 graines (min 3, médiane 3, max 3)    |
| raisonnable | manche médiane de 18 à 25                                        | min 7, **médiane 20**, max 31, victoires 2/50 (4 %)       |
| bonne       | bat le boss sur 10 à 30 % des graines ; ne tombe pas avant la 20 | min **13**, médiane 30, max 31, victoires 9/50 (**18 %**) |
| toutes      | aucune ne survit indéfiniment (mur de PV après la manche 20)     | atteint : 14 des 50 parties « bonne » meurent au boss     |

**Écart à la cible de la conception (§6.12) : le robot « bonne » n'est pas éliminé avant la manche
20 sur la plupart des graines, mais pas sur toutes.** Sur les graines 1 à 10 il atteint les manches
31 (victoire), 31 (victoire), 31, 24, 17, 31, 25, 31 (victoire), 17, 31 : minimum 17 (écart de 3
manches), médiane 31. Sur 50 graines, le minimum est la manche 13. Le test de garde pose donc :
médiane ≥ 20 et minimum ≥ 12 sur les graines 1 à 10. La cible « manche 20 pour tous » vient de la
conception, pas d'une décision de Phil.

## Historique des réglages (le robot « bonne » sur les graines 1 à 10)

| Réglage                                                          | Manches atteintes                   |
| ---------------------------------------------------------------- | ----------------------------------- |
| T8.8 : dégâts ×0,2 → ×1,79, PV ×1 → ×2,16 sur les manches 1 à 20 | min 6, médiane 14                   |
| Dégâts ×1,05 puis ×1,03 par manche, PV inchangés                 | min 6 (graine 6 tombe en manche 6)  |
| Rampes presque plates (dégâts ×1,01, PV ×1,002)                  | min 8 : la graine 6 manque d'or     |
| Prime des ennemis jaunes ×2,0, rampes ×1,03                      | min 9 ; graine 6 tient jusqu'à 31   |
| **Prime jaune ×3,0, rampes ×1,03, PV ×3,0 après la manche 20**   | **min 17, médiane 31, 3 victoires** |

Les rampes de dégâts et de PV ne sont pas le levier des morts précoces : avec des rampes presque
plates, une graine tombait encore en manche 8, faute d'or pour armer la tour. Les **primes** du
palier jaune sont ce qui compte, parce que les premières manches décident de l'arsenal.

## Réglages retenus

- `data/difficulte.json` (T8.21) :
  - dégâts : ×0,2, ×0,224 et ×0,252 aux manches 1 à 3 (inchangés : D16, le joueur passif tombe en
    manche 3), puis ×1,03 par manche, soit ×0,417 à la manche 20 ;
  - PV : ×1,03 par manche, soit ×1,754 à la manche 20 ; table strictement croissante pour les PV
    et les dégâts (D17, gardée par `test_pv_et_degats_des_ennemis_augmentent_a_chaque_manche`) ;
  - vitesse ×1,01 par manche et résistance ×0,97 environ par manche dès la manche 11 (T8.8) ;
  - `apres_table` : PV ×3,0 par manche après la 20 (le mur), dégâts ×1,06, vitesse ×1,01,
    résistance ×0,97 ; accélérations temporelles inchangées.
- `data/ennemis.json` : prime du palier jaune ×3,0 (elle était à ×1,0) ; le Guerrier apparaît à
  la manche 2 et le Tonneau à la manche 4 (manche 1 pour les deux avant). Les autres paliers et
  modèles sont inchangés.
- `data/partie.json` : la clé `emplacements_armes` est supprimée (plus de plafond d'armes depuis
  le lot 8) ; `test_emplacements_armes_n_est_plus_lu_nulle_part` garde qu'aucun fichier ne la lit.
- `tests/outils/strategies_joueur.gd` : le robot « bonne » achète d'abord trois armes avant de
  privilégier l'économie (`ARMES_MINIMUM_BONNE`).
- Armes, améliorations, boutique, économie : inchangées.

## Causes de mort (50 graines)

- Passive : sans achat, la tour tombe au plus tard à la fin de la manche 3.
- Raisonnable : surtout après la manche 11 ; des archers (portée 450) et des artificiers
  (portée 350) frappent hors de portée des armes de 300 ; 8 parties sur 50 meurent au boss.
- Bonne : le boss (14 parties sur 50), puis les archers violets et bleus ; quelques morts
  précoces (manche 13 et suivantes) quand le tirage de la boutique n'offre pas d'arme.

## Points ouverts

- Le mur de PV après la manche 20 (×3,0 par manche) est démesuré : la puissance du joueur croît
  sans plafond (améliorations multiplicatives, or inutilisé une fois l'arsenal plein). Plafonner
  ou renchérir les empilements tardifs sort du périmètre de cette passe.
- Le boss est retenu par les gels et les étourdissements.
- Les armes de portée 300 sont trop courtes face aux archers : à vérifier si c'est voulu.
- Les robots sont approximatifs ; une bonne stratégie humaine peut faire nettement mieux ou pire.
- Le lot 9 ajoute 66 armes et 47 améliorations : refaire une mesure à 50 graines après T9.22.
