# Défis et skins de tour : relevé et liste à valider

Seconde proposition du 26/11/2026, validée par Phil le même jour avec trois ajouts (voir §7) pour la tâche T11.1 (lot 11, décision D20, §6.15 de
`docs/superpowers/specs/2026-11-25-retours-partie-design.md`), après le refus de la première liste par Phil :
« reprends les mêmes défis que la carte ; "gagner uniquement avec des armes de type…" (siège, chaos, rebond, poison,
froid, feu…) ; ajoute des défis sur l'income ; un défi "être le dernier en vie" ; ajoute des défis cumulés ».
**Rien n'est implémenté avant la validation de Phil.** Les défis de la map d'origine ne sont relevés que pour leur
**mécanique** : aucun nom, texte ni chiffre de la map ne passe ici (le garde-fou `tests/unitaires/test_noms_origine.gd`
lit ce document). Les noms, les textes et les seuils ci-dessous sont les nôtres.

## 1. Ce que fait la map d'origine, pour sa seule mécanique

Sources : le fil de la map sur Hive (https://www.hiveworkshop.com/threads/tower-survivors.353429/, sa page 2 et son
journal des modifications), des vidéos de joueurs décrites en texte, et une page de wiki, tels que les remontent les
recherches (les pages elles-mêmes refusent la lecture automatique : HTTP 403). La **liste complète des défis de la map
reste introuvable** : aucune source lisible ne la donne. Ce qui suit est tout ce qui a pu être établi.

- **Un défi débloque un skin de tour**, purement cosmétique : la map en annonce jusqu'à 42. Un système de score
  ajoute un seuil de points à atteindre pour chaque déblocage ; **écarté** (voir plus bas).
- **« Tenir N minutes avec une contrainte »** : le journal cite des défis de 8, 10, 12, 15 et 20 minutes (la map dure au
  plus 20 minutes, boss compris). Repris : tenir jusqu'à une manche, vaincre le boss.
- **« Uniquement des armes de… »** : des vidéos montrent un défi de 20 minutes avec un seul type de dégâts (perçant,
  siège) et un défi lié au poison ; une page de wiki note que certaines armes ne servent qu'à débloquer le skin d'un type ou
  d'un statut (siège, étourdissement). C'est le modèle des 15 défis « uniquement… » ci-dessous.
- **Des contraintes de revenu** : ne tirer d'or que d'une seule sorte d'amélioration de revenu ; acheter un objet à la
  première manche et ne jamais s'en servir ; un défi de prime en pourcentage. C'est le modèle des défis de revenu.
- **Des contraintes de défense** : garder son bouclier de mana intact quinze minutes après l'avoir acheté avant la
  première manche ; tenir dix minutes sans aucune amélioration ; un défi de fontaine de soin. Repris : bouclier intact,
  mains nues, sans soin.
- **Le boss final** (un géant qui apparaît après vingt minutes, que l'on tue pour un skin) : repris par « Siège levé ».
- **La dernière tour debout** : la map note une « dernière résistance » quand on reste le dernier joueur en vie. C'est
  le défi « Dernier debout ».
- **Un mode de prestige** (verrouiller les défis pour gagner un score, puis les refaire) et **les récompenses de jeu**
  (clé dorée, lancer gratuit) : **écartés**, car la progression reste cosmétique (B2, B5).

Recherches web utilisées : 20 pour les deux relevés (8 puis 12), plus 3 pages lues sans résultat (HTTP 403 ou aucune
liste de défis).

## 2. Les compteurs du bilan

Le bilan d'une partie (T11.2) est produit par la simulation pour chaque joueur et lu par les défis. Chaque compteur est
une donnée pure, déterministe, qui ne dépend que de la partie. Une arme compte pour chacun de ses genres et de ses statuts :
les compteurs `armes_genre_*` et `armes_statut_*` ne s'excluent pas entre eux.

| compteur                        | définition                                                                                                                                                   | unité         | mesure dans la simulation                                     |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------- | ------------------------------------------------------------- |
| `manche_atteinte`               | Plus haute manche atteinte, mode sans fin compris                                                                                                            | manche        | `JoueurPartie.manche`                                         |
| `victoire`                      | 1 si le joueur a vaincu le boss, sinon 0                                                                                                                     | 0 ou 1        | `JoueurPartie.victorieux`                                     |
| `dernier_rempart`               | 1 si la tour du joueur est la dernière debout (partie à plusieurs joueurs), sinon 0                                                                          | 0 ou 1        | `Classement.dernier_rempart`                                  |
| `pv_min_ratio`                  | Plus bas rapport entre les PV de la tour et ses PV max sur la partie                                                                                         | rapport       | minimum de `pv / pv_max` relevé à chaque pas                  |
| `manches_sans_degats_de_suite`  | Plus longue série de manches terminées sans que la tour perde de PV                                                                                          | manches       | remise à zéro au premier coup reçu pendant une manche         |
| `pv_soignes`                    | Total des PV rendus à la tour (régénération, soins, vol de vie)                                                                                              | points de vie | somme des gains de PV dans `Arene`                            |
| `mana_max_avant_manche_1`       | Mana maximale de la tour au début de la première manche                                                                                                      | mana          | `Arene` au passage de la préparation à la manche 1            |
| `chutes_bouclier_mana`          | Nombre de fois où la mana tombe à 0 sous un coup                                                                                                             | chutes        | compteur dans le calcul des dégâts reçus                      |
| `degats_epines`                 | Dégâts renvoyés aux ennemis par les épines                                                                                                                   | points de vie | somme des dégâts d'épines dans `Arene`                        |
| `serie_eliminations_5s`         | Plus grand nombre d’éliminations dans une fenêtre glissante de 5 s                                                                                           | ennemis       | file des pas d'élimination dans `Arene`, fenêtre de 100 pas   |
| `armes_equipees_max`            | Plus grand nombre d’armes équipées en même temps                                                                                                             | armes         | `Inventaire.armes.size()` relevé à chaque achat               |
| `ameliorations_achetees`        | Améliorations achetées, toutes catégories                                                                                                                    | améliorations | incrémenté par `Boutique.acheter` pour une amélioration       |
| `ameliorations_revenu_achetees` | Améliorations de la catégorie `revenu` achetées                                                                                                              | améliorations | idem, selon le champ `categorie` de `data/ameliorations.json` |
| `stats_revenu_distinctes`       | Nombre de statistiques de revenu différentes parmi les améliorations achetées (`revenu_fixe`, `revenu_croissant`, `revenu_mult`, `prime_mult`, `bonus_elim`) | statistiques  | ensemble des `stat` des effets achetés, lu dans `Inventaire`  |
| `or_max_detenu`                 | Plus grand montant d’or détenu en même temps                                                                                                                 | or            | maximum de l'or du joueur relevé à chaque pas                 |
| `or_depense`                    | Total d’or dépensé en achats et en relances                                                                                                                  | or            | somme des prix payés dans `Boutique`                          |
| `or_gagne_total`                | Total d’or gagné (revenu, primes, bonus)                                                                                                                     | or            | somme des gains d'or dans `Economie`                          |
| `or_gagne_primes`               | Or gagné par les primes d’élimination et le bonus d’élimination                                                                                              | or            | gains d'or de `Economie` issus des éliminations               |
| `armes_achetees`                | Armes achetées (un exemplaire en double compte)                                                                                                              | armes         | incrémenté par `Boutique.acheter` pour une arme               |
| `armes_distinctes`              | Nombre d’armes différentes parmi les armes achetées (les exemplaires d’une même arme comptent pour une)                                                      | armes         | ensemble des identifiants d'armes de `Inventaire.armes`       |
| `armes_type_tranchant`          | Armes achetées dont le type de dégâts est « tranchant »                                                                                                      | armes         | champ `type_degats` de l'arme                                 |
| `armes_type_percant`            | Armes achetées dont le type de dégâts est « perçant »                                                                                                        | armes         | champ `type_degats` de l'arme                                 |
| `armes_type_magique`            | Armes achetées dont le type de dégâts est « magique »                                                                                                        | armes         | champ `type_degats` de l'arme                                 |
| `armes_type_siege`              | Armes achetées dont le type de dégâts est « siège »                                                                                                          | armes         | champ `type_degats` de l'arme                                 |
| `armes_type_chaos`              | Armes achetées dont le type de dégâts est « chaos »                                                                                                          | armes         | champ `type_degats` de l'arme                                 |
| `armes_genre_cible_unique`      | Armes achetées ayant un effet de genre `cible_unique` (une arme compte pour chacun de ses genres)                                                            | armes         | champ `kind` des `effets` de l'arme                           |
| `armes_genre_zone`              | Armes achetées ayant un effet de genre `zone` (une arme compte pour chacun de ses genres)                                                                    | armes         | champ `kind` des `effets` de l'arme                           |
| `armes_genre_rebond`            | Armes achetées ayant un effet de genre `rebond` (une arme compte pour chacun de ses genres)                                                                  | armes         | champ `kind` des `effets` de l'arme                           |
| `armes_genre_onde`              | Armes achetées ayant un effet de genre `onde` (une arme compte pour chacun de ses genres)                                                                    | armes         | champ `kind` des `effets` de l'arme                           |
| `armes_genre_barrage`           | Armes achetées ayant un effet de genre `barrage` (une arme compte pour chacun de ses genres)                                                                 | armes         | champ `kind` des `effets` de l'arme                           |
| `armes_genre_piege`             | Armes achetées ayant un effet de genre `piege` (une arme compte pour chacun de ses genres)                                                                   | armes         | champ `kind` des `effets` de l'arme                           |
| `armes_genre_mine`              | Armes achetées ayant un effet de genre `mine` (une arme compte pour chacun de ses genres)                                                                    | armes         | champ `kind` des `effets` de l'arme                           |
| `armes_statut_poison`           | Armes achetées ayant le statut `poison` (une arme compte pour chacun de ses statuts)                                                                         | armes         | champ `kind` des `statuts` de l'arme                          |
| `armes_statut_brulure`          | Armes achetées ayant le statut `brulure` (une arme compte pour chacun de ses statuts)                                                                        | armes         | champ `kind` des `statuts` de l'arme                          |
| `armes_statut_givre`            | Armes achetées ayant le statut `givre` (une arme compte pour chacun de ses statuts)                                                                          | armes         | champ `kind` des `statuts` de l'arme                          |
| `armes_statut_etourdissement`   | Armes achetées ayant le statut `etourdissement` (une arme compte pour chacun de ses statuts)                                                                 | armes         | champ `kind` des `statuts` de l'arme                          |
| `armes_statut_vol_de_vie`       | Armes achetées ayant le statut `vol_de_vie` (une arme compte pour chacun de ses statuts)                                                                     | armes         | champ `kind` des `statuts` de l'arme                          |

## 3. Les compteurs cumulés

Les défis cumulés se jouent sur plusieurs parties. Le bilan reste **par partie** ; les cumuls vivent dans la sauvegarde
(`progression/`, voir le §6) et s'enrichissent du bilan à la fin de chaque partie.

| compteur                    | définition                                                       | unité   | source dans la sauvegarde                       |
| --------------------------- | ---------------------------------------------------------------- | ------- | ----------------------------------------------- |
| `parties`                   | Parties jouées jusqu’à leur fin                                  | parties | déjà dans `Profil.parties`                      |
| `cumul_victoires`           | Parties où le boss a été vaincu                                  | parties | somme de `victoire`                             |
| `cumul_eliminations`        | Ennemis éliminés, toutes parties                                 | ennemis | somme de `JoueurPartie.eliminations`            |
| `cumul_or_gagne`            | Or gagné, toutes parties                                         | or      | somme de `or_gagne_total`                       |
| `cumul_manches`             | Manches survécues, toutes parties                                | manches | somme de `manche_atteinte`                      |
| `cumul_parties_multijoueur` | Parties jouées à plusieurs joueurs                               | parties | 1 par partie qui a compté au moins deux joueurs |
| `cumul_dernier_rempart`     | Parties à plusieurs joueurs terminées comme dernière tour debout | parties | somme de `dernier_rempart`                      |

## 4. Les défis proposés

46 défis en 10 familles : tenir (4), uniquement un type de dégâts (5), uniquement un genre d'arme (7), uniquement un statut (5), une seule arme (2), revenu (6), survie (5), construction (3), multijoueur (1), cumulés (8). Chacun vaut en **solo et en
multijoueur** (B4) sauf ceux qui parlent de la dernière tour debout ; en multijoueur, chaque joueur présent le valide
pour lui-même. Les seuils sont des valeurs de départ ; ils ne reprennent aucun chiffre de la map. Un défi « uniquement… »
se gagne en vainquant le boss : il demande donc au moins une arme achetée.

| id                      | nom                  | texte                                                                                                | condition                                                                                  | compteurs                                                            | mode        |
| ----------------------- | -------------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- | ----------- |
| `premier_rempart`       | Premier rempart      | Tenez jusqu’à la dixième manche.                                                                     | `manche_atteinte` ≥ 10                                                                     | `manche_atteinte`                                                    | les deux    |
| `mi_parcours`           | Mi-parcours          | Tenez jusqu’à la vingtième manche.                                                                   | `manche_atteinte` ≥ 20                                                                     | `manche_atteinte`                                                    | les deux    |
| `siege_leve`            | Siège levé           | Vainquez le boss.                                                                                    | `victoire` = 1                                                                             | `victoire`                                                           | les deux    |
| `au_dela_du_boss`       | Au-delà du boss      | Atteignez la quarante-cinquième manche en mode sans fin.                                             | `manche_atteinte` ≥ 45                                                                     | `manche_atteinte`                                                    | les deux    |
| `seul_tranchant`        | Fil du rasoir        | Vainquez le boss en n’achetant que des armes tranchantes.                                            | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_type_tranchant` = `armes_achetees`        | `armes_achetees`, `armes_type_tranchant`, `victoire`                 | les deux    |
| `seul_percant`          | Pointe sèche         | Vainquez le boss en n’achetant que des armes perçantes.                                              | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_type_percant` = `armes_achetees`          | `armes_achetees`, `armes_type_percant`, `victoire`                   | les deux    |
| `seul_magique`          | Magie pure           | Vainquez le boss en n’achetant que des armes magiques.                                               | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_type_magique` = `armes_achetees`          | `armes_achetees`, `armes_type_magique`, `victoire`                   | les deux    |
| `seul_siege`            | Maître de siège      | Vainquez le boss en n’achetant que des armes de siège.                                               | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_type_siege` = `armes_achetees`            | `armes_achetees`, `armes_type_siege`, `victoire`                     | les deux    |
| `seul_chaos`            | Chaos assumé         | Vainquez le boss en n’achetant que des armes du chaos.                                               | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_type_chaos` = `armes_achetees`            | `armes_achetees`, `armes_type_chaos`, `victoire`                     | les deux    |
| `seul_cible_unique`     | Œil unique           | Vainquez le boss en n’achetant que des armes à cible unique.                                         | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_genre_cible_unique` = `armes_achetees`    | `armes_achetees`, `armes_genre_cible_unique`, `victoire`             | les deux    |
| `seul_zone`             | Maître de zone       | Vainquez le boss en n’achetant que des armes de zone.                                                | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_genre_zone` = `armes_achetees`            | `armes_achetees`, `armes_genre_zone`, `victoire`                     | les deux    |
| `seul_rebond`           | Roi du ricochet      | Vainquez le boss en n’achetant que des armes à rebond.                                               | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_genre_rebond` = `armes_achetees`          | `armes_achetees`, `armes_genre_rebond`, `victoire`                   | les deux    |
| `seul_onde`             | Houle                | Vainquez le boss en n’achetant que des armes à onde.                                                 | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_genre_onde` = `armes_achetees`            | `armes_achetees`, `armes_genre_onde`, `victoire`                     | les deux    |
| `seul_barrage`          | Pluie de traits      | Vainquez le boss en n’achetant que des armes à barrage.                                              | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_genre_barrage` = `armes_achetees`         | `armes_achetees`, `armes_genre_barrage`, `victoire`                  | les deux    |
| `seul_piege`            | Maître des pièges    | Vainquez le boss en n’achetant que des armes de piège.                                               | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_genre_piege` = `armes_achetees`           | `armes_achetees`, `armes_genre_piege`, `victoire`                    | les deux    |
| `seul_mine`             | Poseur de mines      | Vainquez le boss en n’achetant que des armes de mine.                                                | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_genre_mine` = `armes_achetees`            | `armes_achetees`, `armes_genre_mine`, `victoire`                     | les deux    |
| `seul_poison`           | Venin pur            | Vainquez le boss en n’achetant que des armes empoisonnantes.                                         | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_statut_poison` = `armes_achetees`         | `armes_achetees`, `armes_statut_poison`, `victoire`                  | les deux    |
| `seul_brulure`          | Braise pure          | Vainquez le boss en n’achetant que des armes incendiaires.                                           | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_statut_brulure` = `armes_achetees`        | `armes_achetees`, `armes_statut_brulure`, `victoire`                 | les deux    |
| `seul_givre`            | Gel pur              | Vainquez le boss en n’achetant que des armes glaçantes.                                              | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_statut_givre` = `armes_achetees`          | `armes_achetees`, `armes_statut_givre`, `victoire`                   | les deux    |
| `seul_etourdissement`   | Coup de tonnerre     | Vainquez le boss en n’achetant que des armes étourdissantes.                                         | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_statut_etourdissement` = `armes_achetees` | `armes_achetees`, `armes_statut_etourdissement`, `victoire`          | les deux    |
| `seul_vol_de_vie`       | Soif de sang         | Vainquez le boss en n’achetant que des armes vampiriques.                                            | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_statut_vol_de_vie` = `armes_achetees`     | `armes_achetees`, `armes_statut_vol_de_vie`, `victoire`              | les deux    |
| `arme_unique`           | Arme unique          | Vainquez le boss avec les exemplaires d’une seule arme.                                              | `victoire` = 1 et `armes_achetees` ≥ 1 et `armes_distinctes` ≤ 1                           | `armes_achetees`, `armes_distinctes`, `victoire`                     | les deux    |
| `arme_unique_endurante` | Duelliste endurant   | Atteignez la vingtième manche avec les exemplaires d’une seule arme.                                 | `manche_atteinte` ≥ 20 et `armes_achetees` ≥ 1 et `armes_distinctes` ≤ 1                   | `armes_achetees`, `armes_distinctes`, `manche_atteinte`              | les deux    |
| `bourse_pleine`         | Bourse pleine        | Détenez vingt mille pièces d’or en même temps.                                                       | `or_max_detenu` ≥ 20000                                                                    | `or_max_detenu`                                                      | les deux    |
| `sans_rente`            | Sans un sou de rente | Vainquez le boss sans acheter aucune amélioration de revenu.                                         | `victoire` = 1 et `ameliorations_revenu_achetees` = 0                                      | `ameliorations_revenu_achetees`, `victoire`                          | les deux    |
| `source_unique`         | Source unique        | Vainquez le boss en n’achetant qu’une seule sorte de revenu.                                         | `victoire` = 1 et `stats_revenu_distinctes` ≤ 1                                            | `stats_revenu_distinctes`, `victoire`                                | les deux    |
| `thesauriseur`          | Thésauriseur         | Atteignez la vingtième manche en dépensant au plus mille pièces d’or.                                | `manche_atteinte` ≥ 20 et `or_depense` ≤ 1000                                              | `manche_atteinte`, `or_depense`                                      | les deux    |
| `primes_en_cascade`     | Primes en cascade    | Gagnez cinquante mille pièces d’or en primes d’élimination.                                          | `or_gagne_primes` ≥ 50000                                                                  | `or_gagne_primes`                                                    | les deux    |
| `grande_fortune`        | Grande fortune       | Gagnez cent cinquante mille pièces d’or en une partie.                                               | `or_gagne_total` ≥ 150000                                                                  | `or_gagne_total`                                                     | les deux    |
| `pierre_sans_fissure`   | Pierre sans fissure  | Terminez dix manches de suite sans perdre un point de vie.                                           | `manches_sans_degats_de_suite` ≥ 10                                                        | `manches_sans_degats_de_suite`                                       | les deux    |
| `a_un_cheveu`           | À un cheveu          | Vainquez le boss après être tombé sous un dixième de vos points de vie.                              | `victoire` = 1 et `pv_min_ratio` ≤ 0.1                                                     | `pv_min_ratio`, `victoire`                                           | les deux    |
| `bouclier_intact`       | Bouclier intact      | Dotez la tour de mana avant la première manche et atteignez la trentième sans que la mana tombe à 0. | `mana_max_avant_manche_1` > 0 et `manche_atteinte` ≥ 30 et `chutes_bouclier_mana` = 0      | `chutes_bouclier_mana`, `mana_max_avant_manche_1`, `manche_atteinte` | les deux    |
| `sans_soin`             | Sans soin            | Vainquez le boss sans que la tour ne récupère un seul point de vie.                                  | `victoire` = 1 et `pv_soignes` = 0                                                         | `pv_soignes`, `victoire`                                             | les deux    |
| `mains_nues`            | Mains nues           | Atteignez la vingtième manche sans acheter une seule amélioration.                                   | `manche_atteinte` ≥ 20 et `ameliorations_achetees` = 0                                     | `ameliorations_achetees`, `manche_atteinte`                          | les deux    |
| `fauchage`              | Fauchage             | Éliminez cinquante ennemis en cinq secondes.                                                         | `serie_eliminations_5s` ≥ 50                                                               | `serie_eliminations_5s`                                              | les deux    |
| `arsenal_complet`       | Arsenal complet      | Équipez huit armes en même temps.                                                                    | `armes_equipees_max` ≥ 8                                                                   | `armes_equipees_max`                                                 | les deux    |
| `haie_d_epines`         | Haie d’épines        | Renvoyez cinquante mille points de dégâts avec vos épines.                                           | `degats_epines` ≥ 50000                                                                    | `degats_epines`                                                      | les deux    |
| `dernier_debout`        | Dernier debout       | Soyez la dernière tour debout d’une partie à plusieurs.                                              | `dernier_rempart` = 1                                                                      | `dernier_rempart`                                                    | multijoueur |
| `habitue`               | Habitué              | Jouez dix parties.                                                                                   | `parties` ≥ 10                                                                             | `parties`                                                            | les deux    |
| `veteran`               | Vétéran              | Jouez cinquante parties.                                                                             | `parties` ≥ 50                                                                             | `parties`                                                            | les deux    |
| `conquerant`            | Conquérant           | Vainquez cinq fois le boss.                                                                          | `cumul_victoires` ≥ 5                                                                      | `cumul_victoires`                                                    | les deux    |
| `faucheur_de_masse`     | Faucheur de masse    | Éliminez cent mille ennemis, toutes parties confondues.                                              | `cumul_eliminations` ≥ 100000                                                              | `cumul_eliminations`                                                 | les deux    |
| `banquier`              | Banquier             | Gagnez un million de pièces d’or, toutes parties confondues.                                         | `cumul_or_gagne` ≥ 1000000                                                                 | `cumul_or_gagne`                                                     | les deux    |
| `endurant`              | Endurant             | Survivez à cinq cents manches, toutes parties confondues.                                            | `cumul_manches` ≥ 500                                                                      | `cumul_manches`                                                      | les deux    |
| `compagnon_de_table`    | Compagnon de table   | Jouez dix parties à plusieurs.                                                                       | `cumul_parties_multijoueur` ≥ 10                                                           | `cumul_parties_multijoueur`                                          | multijoueur |
| `maitre_des_remparts`   | Maître des remparts  | Soyez trois fois la dernière tour debout.                                                            | `cumul_dernier_rempart` ≥ 3                                                                | `cumul_dernier_rempart`                                              | multijoueur |

## 5. Un skin par défi

Chaque défi débloque **un** skin de tour (B5), purement cosmétique : 46 skins, (la map en annonce jusqu'à 42). Les sprites
restent à trouver ou à dessiner sous licence CC0 ou CC-BY (B6) ; ce tableau fixe seulement le nombre de skins, un
identifiant et une idée de silhouette, pour que T11.6 sache quoi chercher. Les tours Gobelin de Tiny Swords
(`Wood_Tower_{couleur}`) sont candidates pour un ou deux d'entre eux ; les autres demandent un pack à trouver.

| défi                    | skin (identifiant)        | idée de silhouette                               |
| ----------------------- | ------------------------- | ------------------------------------------------ |
| `premier_rempart`       | `tour_de_guet`            | palissade basse en bois, une seule plateforme    |
| `mi_parcours`           | `tour_de_pierre`          | tour en pierre brute, créneaux                   |
| `siege_leve`            | `tour_du_vainqueur`       | tour claire, oriflamme au sommet                 |
| `au_dela_du_boss`       | `tour_sans_horizon`       | tour très haute, plusieurs étages                |
| `seul_tranchant`        | `tour_lame`               | arêtes et lames saillantes                       |
| `seul_percant`          | `tour_pointe`             | flèches plantées dans la pierre                  |
| `seul_magique`          | `tour_arcane`             | cristaux et runes lumineuses                     |
| `seul_siege`            | `tour_bastion`            | masse de pierre, bélier au pied                  |
| `seul_chaos`            | `tour_fissure`            | pierre noire fendue, lueurs rouges               |
| `seul_cible_unique`     | `tour_oeil`               | un grand œil sculpté au sommet                   |
| `seul_zone`             | `tour_nuee`               | halo circulaire à la base                        |
| `seul_rebond`           | `tour_ricochet`           | plaques de métal poli qui renvoient la lumière   |
| `seul_onde`             | `tour_sonore`             | anneaux concentriques gravés                     |
| `seul_barrage`          | `tour_salve`              | râteliers de traits sur toute la hauteur         |
| `seul_piege`            | `tour_embuscade`          | cordes, fosses et pieux autour du pied           |
| `seul_mine`             | `tour_sapeur`             | tonneaux de poudre empilés au pied               |
| `seul_poison`           | `tour_venimeuse`          | pierre verdie, gouttes sombres                   |
| `seul_brulure`          | `tour_braise`             | pierre rougeoyante, fumerolles                   |
| `seul_givre`            | `tour_gelee`              | glace et givre sur les créneaux                  |
| `seul_etourdissement`   | `tour_tonnerre`           | éclairs gravés, étincelles                       |
| `seul_vol_de_vie`       | `tour_sanguine`           | drapés rouge sombre                              |
| `arme_unique`           | `tour_monolame`           | tour portant une arme unique, immense, au sommet |
| `arme_unique_endurante` | `tour_du_duelliste`       | tour dépouillée, une seule arme plantée devant   |
| `bourse_pleine`         | `tour_du_tresor`          | tour dorée, coffre au pied                       |
| `sans_rente`            | `tour_ascete`             | tour de pierre nue, sans ornement                |
| `source_unique`         | `tour_du_puits`           | tour posée sur un puits                          |
| `thesauriseur`          | `tour_du_dragon_avare`    | tour surmontée d'un tas de pièces                |
| `primes_en_cascade`     | `tour_du_chariot`         | chariot de butin collé à la tour                 |
| `grande_fortune`        | `tour_du_banquier`        | tour à colonnes, sacs d'or empilés               |
| `pierre_sans_fissure`   | `tour_de_granit`          | pierre lisse, aucune lézarde                     |
| `a_un_cheveu`           | `tour_rafistolee`         | tour étayée de planches, visiblement réparée     |
| `bouclier_intact`       | `tour_du_bouclier`        | dôme translucide sur la tour                     |
| `sans_soin`             | `tour_cicatrisee`         | pierre marquée de balafres                       |
| `mains_nues`            | `tour_nue`                | tour minimale, aucun accessoire                  |
| `fauchage`              | `tour_a_faux`             | tour hérissée de lames                           |
| `arsenal_complet`       | `tour_arsenal`            | tour couverte de râteliers d'armes               |
| `haie_d_epines`         | `tour_de_ronces`          | tour entourée de pieux et de ronces              |
| `dernier_debout`        | `tour_survivante`         | tour fumante au milieu de ruines                 |
| `habitue`               | `tour_familiere`          | tour ordinaire, patine d'usage                   |
| `veteran`               | `tour_veterane`           | tour bardée de trophées                          |
| `conquerant`            | `tour_conquerante`        | tour ornée de bannières de victoire              |
| `faucheur_de_masse`     | `tour_ossuaire`           | tour entourée de crânes                          |
| `banquier`              | `tour_comptoir`           | tour-comptoir, balance sur le toit               |
| `endurant`              | `tour_eternelle`          | tour couverte de mousse, très ancienne           |
| `compagnon_de_table`    | `tour_de_la_table_ronde`  | tour ronde aux sièges                            |
| `maitre_des_remparts`   | `tour_du_dernier_rempart` | tour couronnée, étendard unique                  |

## 6. Ce que la sauvegarde doit porter en plus (T11.3bis)

La sauvegarde de T11.3 (`Profil`, version 1) porte déjà `parties` et `meilleure_manche`. Les défis cumulés demandent :

- **Six compteurs cumulés** de plus dans `Profil` (`cumul_victoires`, `cumul_eliminations`, `cumul_or_gagne`,
  `cumul_manches`, `cumul_parties_multijoueur`, `cumul_dernier_rempart`) ; `parties` sert de `parties` pour les défis.
- **Version 2 du fichier** : la version 1 se **migre** (les six compteurs partent de 0, rien n'est perdu), le fichier de
  version 2 refuse d'être relu par un jeu plus ancien (version inconnue, jamais écrasé) ; le test de migration de T11.3
  (`test_chaque_version_precedente_se_migre`) cesse d'être vide.
- Des **bornes** comme les autres champs : chaque compteur entre 0 et un maximum (un milliard pour l'or, dix millions
  pour les éliminations, un million pour les parties et les manches), un type faux refuse le fichier, la liste blanche de
  clés s'élargit des six noms.
- La **mise à jour** : à la fin d'une partie, `progression/` ajoute le bilan aux cumuls, puis évalue les défis ; le tout
  s'écrit en **un seul enregistrement** (aucune perte si l'écriture échoue, comme en T11.3).

## 7. Décisions de Phil et points ouverts

Décisions de Phil du 26/11/2026 (validation de la liste) :

1. **La liste est validée**, avec trois ajouts.
2. **Des défis « uniquement… » pour les pièges aussi** : « Maître des pièges » et « Poseur de mines » s'ajoutent aux genres d'arme.
3. **Des défis « une seule arme »**, comme dans la map : un défi générique (« Arme unique », vaincre le boss avec les
   exemplaires d'une seule arme) et une variante à la vingtième manche (« Duelliste endurant »). Pas un défi par arme.
4. **Un sprite par skin, pour tous** (B6) : le nombre de skins suit celui des défis, soit 46.

Points ouverts (valeur par défaut retenue) :

1. **L'aura** (deux armes, comme les pièges et les mines) n'a **pas** de défi « uniquement » : elle n'a pas été citée par Phil.
   Défaut : pas de défi ; à ajouter en une ligne si Phil le veut.
2. **Les seuils** sont des valeurs de départ à ajuster après quelques parties.
3. **Les genres du lot 9** (tir tournant, zone posée, bombe, invocation) recevront un défi « uniquement » à la livraison de
   leurs armes.
4. **Le statut « givre »** n'a que deux armes aujourd'hui : le défi « Gel pur » devient jouable surtout après les armes du
   lot 9.

## 8. Statuts et genres du lot 9 : défi à décider par Phil

Les armes du lot 9 introduisent des statuts et des genres d'effet que la liste du § 4 ne couvre pas. Aucun défi n'est inventé ici : chaque ligne attend la décision de Phil, puis la session des défis la remplace par un vrai défi « uniquement ». `test_defis_document` exige pour chaque statut et chaque genre de 3 armes ou plus soit un défi du § 4, soit sa ligne dans ce tableau.

| nature | nom                   | introduit par |
| ------ | --------------------- | ------------- |
| statut | `vulnerabilite`       | T9.13         |
| statut | `malediction_toucher` | T9.13         |
| genre  | `aura`                | T9.13         |
| genre  | `tournant`            | T9.13         |
