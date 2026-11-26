# Équilibrage

Mesure : `godot --headless --path . --script res://tools/equilibrage.gd -- --graines 50 --strategie <passive|raisonnable|bonne|toutes>`.
Un joueur seul, une partie complète à pleine vitesse, graines 1 à 50. Les robots vivent dans
`tests/outils/strategies_joueur.gd` ; `tests/unitaires/test_equilibrage_partie.gd` garde la
cible grossière dans la suite.

## Cible

| Stratégie   | Cible                                                   |
| ----------- | ------------------------------------------------------- |
| passive     | tombe vers la manche 4 à 5                              |
| raisonnable | manche médiane de 18 à 25                               |
| bonne       | bat le boss de la manche 31 sur 10 à 30 % des graines   |
| toutes      | aucune ne survit indéfiniment (PV ennemis exponentiels) |

## Résultats (50 graines)

Résultat : manches min / médiane / max, victoires sur le boss.

| Réglage                                   | passive        | raisonnable        | bonne             |
| ----------------------------------------- | -------------- | ------------------ | ----------------- |
| 0. Données d'origine                      | 2 / 2 / 2, 0 % | 2 / 3 / 8, 0 %     | 2 / 3 / 8, 0 %    |
| 1. Dégâts des armes ×3 (20 graines)       | 2 / 2 / 2, 0 % | 2 / 11 / 25, 0 %   | 2 / 6 / 20, 0 %   |
| 2. Dégâts ennemis 3 % → 100 % (manche 10) | 4 / 5 / 7, 0 % | 11 / 18 / 31, 15 % | 8 / 18 / 31, 15 % |
| 3. Robot « bonne » spécialisé, remplace   | idem           | idem               | 8 / 31 / 31, 83 % |
| 4. PV ennemis ×1,08/manche puis ×1,35     | idem           | 11 / 19 / 31, 13 % | 8 / 31 / 31, 70 % |
| 5. PV ennemis ×2,0 après la manche 20     | 4 / 5 / 7, 0 % | 11 / 19 / 31, 7 %  | 8 / 26 / 31, 33 % |
| 6. **PV ennemis ×2,2 après la manche 20** | 4 / 5 / 7, 0 % | 7 / 19 / 31, 8 %   | 7 / 25 / 31, 22 % |

Les lignes 1 et 2 portent sur 20 à 30 graines ; la ligne 3 sur 30. Les robots ont évolué
entre les lignes 0 et 3 (la ligne 0 est mesurée avec le robot « bonne » d'avant la
spécialisation : sa différence avec « raisonnable » y était nulle).

## Réglages retenus (ligne 6)

- `data/armes.json` : dégâts de toutes les armes ×3 ; puis ×0,8 pour les rares et ×0,7 pour
  les épiques (le rendement moyen reste croissant : 0,46 / 0,64 / 0,71 / 0,78).
- `data/difficulte.json` :
  - T8.8 : une ligne par manche de 1 à 20, strictement croissante (D17) : PV ×1 à ×2,16
    (progression géométrique, ×1,0413 par manche), dégâts ×0,2 à ×1,79 (×1,0975 par manche),
    vitesse ×1,01 par manche dès la 11 et résistance ×0,97 environ par manche dès la 11 ;
  - `apres_table` : PV ×2,2 par manche (dégâts ×1,06, vitesse ×1,01, résistance ×0,97) ;
  - accélérations temporelles inchangées.
- `data/ennemis.json`, `data/economie.json`, `data/boutique.json`, `data/partie.json` : inchangés.

## Causes de mort

- Passive : sans achat, la tour tombe au plus tard à la fin de la manche 3 sur les graines 1 à 10 (D16, dégâts ×0,2 à la manche 1).
- Raisonnable : les manches 11 à 25, quand les PV ennemis dépassent ce que quatre à six armes
  communes et peu communes tuent avant qu'ils n'arrivent ; les archers (portée 450) et les
  spectres (portée 250) frappent hors de portée des armes de 300.
- Bonne : surtout après la manche 22, par le mur de PV ; quelques morts précoces (manche 7 à 8)
  quand l'économie passe avant les armes.

## Points douteux

- T8.8 : robots `raisonnable` et `bonne` sur les graines 1 à 10, médianes 12 à 14 et minimum 6 ;
  la cible « un robot qui achète ne tombe pas avant la manche 20 » reste à la passe finale (T8.21).
- Le mur de PV (×2,2 par manche) est démesuré (×2 000 à la manche 31) : le joueur bien
  construit dépasse déjà 10⁵ dégâts par seconde. Le vrai problème est la croissance de la
  puissance du joueur : améliorations de dégâts multiplicatives, or inutilisé (plusieurs
  milliers de pièces) une fois les huit emplacements d'épiques remplis. Une solution plus propre
  serait de plafonner ou de renchérir les empilements tardifs ; elle sort du périmètre de cette passe.
- Le boss est peu dangereux : retenu à distance par les gels et étourdissements, il meurt sans
  atteindre la tour. Un boss à 400 000 PV n'a pas changé le taux de victoire.
- Les armes de portée 300 sont trop courtes face aux archers : à vérifier si c'est voulu.
- Les robots sont approximatifs ; une bonne stratégie humaine pourrait faire nettement mieux ou pire.
