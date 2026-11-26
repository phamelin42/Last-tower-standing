# Défis et skins de tour : relevé et liste à valider

Proposition du 26/11/2026 pour la tâche T11.1 (lot 11, décision D20, §6.15 de
`docs/superpowers/specs/2026-11-25-retours-partie-design.md`). **Rien n'est implémenté avant la validation de Phil.**
Les défis de la map d'origine ne sont relevés que pour leur **mécanique** : aucun nom, texte ni chiffre de la map ne
passe ici (le garde-fou `tests/unitaires/test_noms_origine.gd` lit ce document). Les noms, les textes et les seuils
ci-dessous sont les nôtres.

## 1. Ce que fait la map d'origine, pour sa seule mécanique

Source : le fil de la map sur Hive (https://www.hiveworkshop.com/threads/tower-survivors.353429/ et sa page 2) et son
journal des modifications, tels que les remontent les recherches ; le fichier de la map n'a pas été relu pour cette
tâche. Les pages détaillées des défis restent illisibles (voir `docs/tower_survivors.md`, §2).

- **Un défi débloque un skin de tour**, purement cosmétique : la map en annonce jusqu'à 42, sans effet sur le jeu.
  C'est ce que décide B5 (un skin par défi).
- **Des défis de durée** : tenir un temps donné (le journal parle de défis de 12 minutes, corrigés pour durer
  réellement 12 minutes), parfois avec une contrainte de build (« un seul élément »). Repris : tenir jusqu'à une manche,
  vaincre le boss avec une contrainte de build.
- **Des défis de butin** : un défi dépend du pourcentage de prime d'élimination, ce qui montre que l'or fait partie des
  conditions. Repris : or détenu et or gagné.
- **Des défis d'enchaînement** : une série d'éliminations maximale. Repris : éliminations en une courte fenêtre.
- **Un mode de prestige** : verrouiller tous les défis pour gagner un score, puis les refaire. **Écarté** : il ajoute
  une boucle de progression que Phil n'a pas demandée, et un score n'a pas de place dans une progression cosmétique.
- **Des défis très longs** (l'autel du survivant, seul à ne pas avoir été raccourci). **Écarté** : un défi qui exige
  plusieurs parties d'affilée demanderait un cumul entre parties, absent du bilan de partie (point ouvert 2 du §6.15).
- **Des récompenses de jeu** (une clé dorée, un lancer gratuit) : **écartées**. Nos récompenses sont des skins (B5), et
  un avantage de jeu romprait le caractère cosmétique de la progression (B2).

Recherches web utilisées pour ce relevé : 8.

## 2. Les compteurs du bilan

Le bilan d'une partie (T11.2) est produit par la simulation pour chaque joueur et lu par les défis. Chaque compteur est
une donnée pure, déterministe, qui ne dépend que de la partie.

| compteur                       | définition                                                           | unité         | mesure dans la simulation                                             |
| ------------------------------ | -------------------------------------------------------------------- | ------------- | --------------------------------------------------------------------- |
| `manche_atteinte`              | Plus haute manche atteinte, mode sans fin compris                    | manche        | `JoueurPartie.manche`                                                 |
| `victoire`                     | 1 si le joueur a vaincu le boss, sinon 0                             | 0 ou 1        | `JoueurPartie.victorieux`                                             |
| `degats_epines`                | Dégâts renvoyés aux ennemis par les épines                           | points de vie | somme des dégâts d'épines dans `Arene`                                |
| `pv_min_ratio`                 | Plus bas rapport entre les PV de la tour et ses PV max sur la partie | rapport       | minimum de `pv / pv_max` relevé à chaque pas                          |
| `manches_sans_degats_de_suite` | Plus longue série de manches terminées sans que la tour perde de PV  | manches       | compteur remis à zéro au premier coup reçu pendant une manche         |
| `types_degats_utilises`        | Nombre de types de dégâts différents parmi les armes jamais équipées | types         | ensemble des `type_degats` des armes équipées (`Inventaire`)          |
| `serie_eliminations_5s`        | Plus grand nombre d'éliminations dans une fenêtre glissante de 5 s   | ennemis       | file des pas d'élimination dans `Arene`, fenêtre de 100 pas           |
| `armes_equipees_max`           | Plus grand nombre d'emplacements d'armes occupés en même temps       | armes         | `Inventaire.armes.size()` relevé à chaque achat                       |
| `or_max_detenu`                | Plus grand montant d'or détenu en même temps                         | or            | maximum de l'or du joueur relevé à chaque pas                         |
| `offres_achetees`              | Nombre d'offres achetées (armes et améliorations, relances exclues)  | offres        | compteur incrémenté par `Boutique.acheter` quand le résultat est `OK` |

## 3. Les défis proposés

Douze défis. Chacun vaut en **solo et en multijoueur** (B4) ; en multijoueur, chaque joueur présent le valide pour
lui-même. Les seuils sont des valeurs de départ, à ajuster à l'œil après quelques parties ; ils ne reprennent aucun
chiffre de la map.

| id                    | nom                 | texte                                                                   | condition                                     | compteurs                           | mode     |
| --------------------- | ------------------- | ----------------------------------------------------------------------- | --------------------------------------------- | ----------------------------------- | -------- |
| `premier_rempart`     | Premier rempart     | Tenez jusqu’à la cinquième manche.                                      | `manche_atteinte` ≥ 5                         | `manche_atteinte`                   | les deux |
| `mi_parcours`         | Mi-parcours         | Tenez jusqu’à la quinzième manche.                                      | `manche_atteinte` ≥ 15                        | `manche_atteinte`                   | les deux |
| `siege_leve`          | Siège levé          | Vainquez le boss.                                                       | `victoire` = 1                                | `victoire`                          | les deux |
| `au_dela_du_boss`     | Au-delà du boss     | Atteignez la quarante-cinquième manche en mode sans fin.                | `manche_atteinte` ≥ 45                        | `manche_atteinte`                   | les deux |
| `pierre_sans_fissure` | Pierre sans fissure | Terminez dix manches de suite sans perdre un point de vie.              | `manches_sans_degats_de_suite` ≥ 10           | `manches_sans_degats_de_suite`      | les deux |
| `a_un_cheveu`         | À un cheveu         | Vainquez le boss après être tombé sous un dixième de vos points de vie. | `victoire` = 1 et `pv_min_ratio` ≤ 0.1        | `victoire`, `pv_min_ratio`          | les deux |
| `maitre_d_un_element` | Maître d’un élément | Vainquez le boss avec des armes d’un seul type de dégâts.               | `victoire` = 1 et `types_degats_utilises` ≤ 1 | `victoire`, `types_degats_utilises` | les deux |
| `fauchage`            | Fauchage            | Éliminez cinquante ennemis en cinq secondes.                            | `serie_eliminations_5s` ≥ 50                  | `serie_eliminations_5s`             | les deux |
| `arsenal_complet`     | Arsenal complet     | Remplissez les huit emplacements d’armes.                               | `armes_equipees_max` ≥ 8                      | `armes_equipees_max`                | les deux |
| `coffre_plein`        | Coffre plein        | Détenez vingt mille pièces d’or en même temps.                          | `or_max_detenu` ≥ 20000                       | `or_max_detenu`                     | les deux |
| `haie_d_epines`       | Haie d’épines       | Renvoyez cinquante mille points de dégâts avec vos épines.              | `degats_epines` ≥ 50000                       | `degats_epines`                     | les deux |
| `main_serree`         | Main serrée         | Vainquez le boss en achetant au plus douze offres.                      | `victoire` = 1 et `offres_achetees` ≤ 12      | `victoire`, `offres_achetees`       | les deux |

## 4. Un skin par défi

Chaque défi débloque **un** skin de tour (B5), purement cosmétique. Les sprites restent à trouver ou à dessiner sous
licence CC0 ou CC-BY (B6) ; ce tableau fixe seulement le nombre de skins, un identifiant et une idée de silhouette,
pour que T11.6 sache quoi chercher. Les tours Gobelin de Tiny Swords (`Wood_Tower_{couleur}`) sont candidates pour un
ou deux d'entre eux ; les autres demandent un pack à trouver.

| défi                  | skin (identifiant)  | idée de silhouette                            |
| --------------------- | ------------------- | --------------------------------------------- |
| `premier_rempart`     | `tour_de_guet`      | palissade basse en bois, une seule plateforme |
| `mi_parcours`         | `tour_de_pierre`    | tour en pierre brute, créneaux                |
| `siege_leve`          | `tour_du_vainqueur` | tour claire, oriflamme au sommet              |
| `au_dela_du_boss`     | `tour_sans_horizon` | tour très haute, plusieurs étages             |
| `pierre_sans_fissure` | `tour_de_granit`    | pierre lisse, aucune lézarde                  |
| `a_un_cheveu`         | `tour_rafistolee`   | tour étayée de planches, visiblement réparée  |
| `maitre_d_un_element` | `tour_monochrome`   | tour d'une seule teinte, sans ornement        |
| `fauchage`            | `tour_a_faux`       | tour hérissée de lames                        |
| `arsenal_complet`     | `tour_arsenal`      | tour couverte de râteliers d'armes            |
| `coffre_plein`        | `tour_du_tresor`    | tour dorée, coffre au pied                    |
| `haie_d_epines`       | `tour_de_ronces`    | tour entourée de pieux et de ronces           |
| `main_serree`         | `tour_nue`          | tour minimale, aucun accessoire               |

## 5. Ce que Phil doit trancher

1. **La liste de défis** : douze, plus ou moins ? Défaut : ces douze.
2. **Les seuils** : valeurs de départ à ajuster après quelques parties. Défaut : celles du tableau.
3. **Le nombre de skins** suit celui des défis (B5) : douze skins à trouver ou à dessiner. Défaut : douze.
4. **Un défi cumulé sur plusieurs parties** (par exemple « dix parties jouées ») : écarté ici, car le bilan est celui
   d'une seule partie. Défaut : non.
