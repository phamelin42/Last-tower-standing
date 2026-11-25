# Last Tower Standing — spécification

> Nom du jeu : **Last Tower Standing** (Phil, 25/11/2026), licence MIT. Décisions de Phil
> marquées **(Phil)** ; le reste est un choix de l'agent principal, marqué **(choix)**, que Phil
> peut corriger.

## 1. Intention

Un jeu de survie à tour, multijoueur, sous Godot. Il reprend **seulement les mécaniques et le
gameplay** de la map Warcraft 3 « Tower Survivors » v1.95 (auteur : Nethalythic) **(Phil)**.
Noms, objets, ennemis, chiffres, textes et graphismes sont originaux. Aucun fichier de la map
n'est réutilisé.

Le sel du jeu à préserver : une course exponentielle entre l'économie, les dégâts et la survie,
face à une montée de difficulté planifiée. Chaque manche oblige à un pari (investir maintenant
ou se protéger), et la boutique aléatoire donne un build différent à chaque partie.

## 2. Contraintes

- **Godot 4.7.2 stable, GDScript typé** (choix ; pas de C#, pour un export simple). Phil a Godot
  installé sur son poste ; le conteneur cloud utilise Godot sans interface (`--headless`).
- **Uniquement de l'open source et des licences gratuites (Phil)** : moteur MIT, outils MIT/BSD,
  ressources CC0 ou équivalentes. Chaque ressource tierce est listée dans `CREDITS.md`
  (source, auteur, licence).
- **Graphismes : les modèles de Godot (Phil)**, c'est-à-dire les maillages primitifs intégrés
  (`BoxMesh`, `CylinderMesh`, `SphereMesh`, `CapsuleMesh`, `PrismMesh`, `TorusMesh`) avec des
  `StandardMaterial3D`. Toute la correspondance « entité → apparence » passe par un seul
  endroit (`visuels/`), pour qu'un modèle CC0 puisse remplacer une primitive plus tard sans
  toucher au code de jeu.
- **Multijoueur : le même que l'original (Phil)** : 1 à 8 joueurs, chacun sa tour, son arène,
  ses ennemis et son or. Aucune interaction directe entre les arènes ; on se compare au tableau
  des scores, et le dernier en vie gagne.
- Interface en **français** (règle commune), avec les textes dans un fichier de traduction Godot
  (`i18n/textes.csv`, colonne `fr`) pour pouvoir ajouter l'anglais plus tard.
- Pas de dépendance téléchargée depuis GitHub dans le conteneur (le proxy la bloque). Les tests
  utilisent donc un **petit lanceur maison** (`tests/lanceur.gd`), pas GUT ni gdUnit.
- Tous les chiffres d'équilibrage sont dans `data/*.json`, chargés et **validés au démarrage**
  (une donnée invalide fait échouer le chargement avec un message clair, pas un plantage plus
  loin).

## 3. Approches envisagées pour le réseau

1. **Serveur autoritaire (retenue, choix).** L'hôte, ou un serveur dédié sans interface,
   simule toutes les arènes. Les clients n'envoient que des intentions (acheter, relancer,
   vendre) et reçoivent l'état de leur arène. Pas de triche possible, une seule vérité, et le
   même binaire tourne en serveur dédié sur un VPS. Coût : le serveur simule jusqu'à 8 arènes,
   d'où une simulation en données (tableaux), sans nœud par ennemi.
2. Chaque client simule sa propre arène, et le serveur arbitre les scores. Réseau très léger,
   mais la triche est triviale et l'observation d'un autre joueur devient compliquée. Écartée.
3. Simulation en lockstep déterministe, comme Warcraft 3. Elle exige des flottants identiques
   sur toutes les machines, ce que Godot ne garantit pas. Écartée.

## 4. Architecture

```
project.godot
data/            *.json : armes, améliorations, ennemis, manches, économie, tableau d'efficacité
sim/             simulation pure (RefCounted, aucune dépendance aux nœuds ni au réseau)
  donnees.gd       chargement + validation de data/
  arene.gd         une arène : tour, ennemis, armes, projectiles logiques, effets
  boutique.gd      offres, rareté, achat, relance, vente
  economie.gd      or, revenu périodique, primes
  partie.gd        N arènes, horloge des manches, montée en difficulté, boss, fin de partie
  combat.gd        formules : efficacité type/armure, armure, critique, esquive, effets
reseau/          ENet (API multijoueur de haut niveau de Godot)
  serveur.gd       boucle de simulation à pas fixe, réception des intentions, envoi des états
  client.gd        réception, interpolation, envoi des intentions
  protocole.gd     encodage compact des messages (PackedByteArray), version du protocole
visuels/         rendu 3D (MultiMeshInstance3D pour les ennemis), caméra, effets
ui/              menus, salon, HUD, boutique, tableau des scores, écran de fin
tests/           lanceur.gd + tests/unitaires/test_*.gd + tests/integration/
tools/           install-godot.sh, scripts de vérification
```

- **Simulation à pas fixe de 20 Hz** côté serveur, indépendante du rendu (choix). Les ennemis
  sont stockés en tableaux compacts (`PackedVector2Array` pour les positions sur le plan,
  `PackedFloat32Array` pour les PV…), parce qu'il peut y en avoir plusieurs centaines par arène.
  Le monde est en 2D logique (plan XZ) ; le rendu le pose en 3D.
- **Hasard reproductible** : chaque arène a son `RandomNumberGenerator`, initialisé depuis la
  graine de la partie. Pour une graine et une suite d'intentions données, le résultat est
  identique (c'est testé).
- **Réseau** : ENet sur le port UDP 7777 par défaut, configurable. Les clients envoient des
  intentions (RPC fiables). Le serveur envoie à chaque client l'état de l'arène qu'il regarde
  (la sienne, ou celle d'un autre joueur après sa mort) à 15 Hz, de façon non fiable et
  compacte (positions quantifiées), plus les événements de tir et d'impact pour les effets
  visuels, et l'état global (scores, vivants, horloge) à 2 Hz, de façon fiable.
- **Jouer seul** emprunte le même chemin, avec un serveur local et un seul joueur.
- **Serveur dédié** : `godot --headless -- --serveur --port 7777`.
- Débit visé : moins de 50 Ko/s par client avec 300 ennemis visibles.

## 5. Règles du jeu (mécaniques ; tous les chiffres sont des valeurs de départ dans `data/`)

### 5.1 Déroulement

- **Salon** : l'hôte voit les joueurs connectés (nom, prêt). Ses options : vitesse de partie
  (×1, ×0,66, ×0,5, qui multiplie toutes les durées) et graine (aléatoire ou fixe).
- **Préparation** : 30 s avant la première vague. La boutique est ouverte.
- **Manches de 30 s**. Au début de chaque manche : une nouvelle offre de boutique, une famille
  d'ennemis tirée au hasard (jamais deux fois de suite), et la difficulté qui monte.
- **Boss** à la manche 31 (environ 15 min) : les apparitions normales s'arrêtent, et le boss
  marche sur la tour. Le tuer, c'est la **victoire** du joueur, qui peut ensuite continuer en
  **mode sans fin** (les manches reprennent et la difficulté continue de monter).
- **Défaite** : la tour tombe à 0 PV. Le joueur voit son récapitulatif, puis peut observer les
  arènes des autres.
- **Fin de partie** : quand plus aucun joueur n'est en vie, ou quand tous les survivants ont
  vaincu le boss et quittent. Le classement se fait par manche atteinte, puis par dégâts infligés.
  Le dernier en vie reçoit la mention « Dernier rempart ».
- Un joueur qui se déconnecte est compté comme éliminé, et son arène est retirée.

### 5.2 Économie

- Or de départ : 500 (choix d'échelle, l'original étant 10 fois plus grand).
- **Revenu** toutes les 10 s : `revenu_de_base(manche) + revenu_acheté × multiplicateur_revenu`.
  Le revenu de base augmente d'un palier à chaque manche.
- **Prime** par ennemi tué, selon l'ennemi et un multiplicateur qui monte par paliers de
  manches ; certains objets l'augmentent.
- Objets d'économie : revenu fixe, revenu qui croît avec le temps, multiplicateur de primes,
  bonus toutes les n éliminations.

### 5.3 Boutique

- À chaque manche, **4 offres** tirées selon leur rareté : commune, peu commune, rare, épique.
  Les poids de chaque rareté évoluent au fil des manches (`data/boutique.json`).
- **Relancer** coûte de l'or ; le coût augmente à chaque relance dans la même manche, puis
  revient au départ à la manche suivante. Certains objets donnent des relances gratuites.
- Une offre achetée disparaît de l'offre en cours.
- Un objet spécial, le « marché noir », permet de choisir une amélioration dans une liste au
  lieu du hasard.
- **8 emplacements d'armes** (choix). Une arme se revend à 50 % de son prix. Les améliorations
  n'occupent pas d'emplacement.

### 5.4 Combat

- **Types de dégâts** : tranchant, perçant, magique, siège, chaos. **Armures** : légère,
  moyenne, lourde, fortifiée, aucune, et une armure de boss.
- **Tableau d'efficacité** (validé par Phil, dans `data/efficacite.json`) : ×2 pour tranchant
  contre moyenne, perçant contre légère, magique contre lourde et siège contre fortifiée ; ×1
  partout ailleurs, chaos compris. Aucun malus.
- Les ennemis n'ont pas de valeur d'armure. Celle de la tour réduit les dégâts subis :
  `réduction = 0,05 × armure / (1 + 0,05 × armure)`.
- **Armes** : un type de dégâts, des dégâts, un temps de recharge, un palier de portée
  (300 / 600 / 900 / 1200 unités), un mode de ciblage (l'ennemi le plus proche par défaut) et
  un ou plusieurs effets : cible unique, zone, rebond (4 à 8 cibles), onde, barrage, mine ou
  piège au sol, aura.
- **Améliorations** : bonus de dégâts par type (cumul additif dans un type, multiplicatif entre
  catégories), PV max, régénération, armure, esquive, épines, critique, cadence, tirs
  multiples, éclaboussure, focalisation sur cible unique.
- **Effets** :
  - critique : chance par paliers de 5 % ; au-delà de 100 % de chance, l'excédent augmente
    la puissance du critique ;
  - esquive : rendement décroissant ;
  - vol de vie : soin à chaque coup porté, ou à chaque ennemi tué ;
  - poison : dégâts répartis dans le temps ;
  - brûlure : un pourcentage des dégâts infligés ;
  - givre : ralentissement qui se cumule, puis gel de 3 s au maximum de cumuls ;
  - étourdissement : sa durée est multipliée par la résistance de l'ennemi, qui baisse au fil
    de la partie ;
  - épines : renvoient des dégâts à l'attaquant au corps à corps.
- **Cibles volantes** : ciblées comme les autres. Elles ignorent les mines et les pièges au sol.

### 5.5 Ennemis

- Environ **8 familles originales**, chacune avec une seule armure. Toute la famille partage le
  même modèle, mais avec des PV, une vitesse et une portée d'attaque (corps à corps ou distance)
  différents ; une famille est volante. Une manche spéciale rare apporte un convoi qui ne
  frappe pas, mais rapporte beaucoup d'or.
- Les ennemis apparaissent sur un cercle de rayon 1300 autour de la tour, à un angle aléatoire,
  vont droit sur elle et l'attaquent.
- **Cadence** : un intervalle de 2,0 s entre deux apparitions au départ, qui baisse de 0,08 s
  par manche jusqu'à un plancher de 0,1 s.
- **Montée en difficulté** : à chaque manche, des multiplicateurs de PV, de dégâts et de
  vitesse, avec des accélérations à 5, 10 et 15 minutes, et une résistance aux contrôles qui
  grandit.

### 5.6 Contenu de la version 1

- Au moins **25 armes** (5 par type de dégâts, réparties entre les raretés) et environ
  **30 améliorations**, toutes originales.
- Un test d'équilibrage vérifie que, dans une catégorie, les dégâts par seconde par pièce d'or
  croissent avec la rareté, et que chaque objet peut être proposé (atteignabilité).

## 6. Rendu et interface

- 3D : caméra fixe, en plongée inclinée au-dessus de l'arène regardée, avec un zoom. Sol en
  damier doux, tour au centre, ennemis en `MultiMeshInstance3D` (un par famille), projectiles et
  impacts en effets légers. Les positions sont interpolées entre deux états reçus.
- HUD : PV de la tour, or et revenu, manche et temps restant, prochaine famille annoncée
  (armure comprise), armes équipées.
- Boutique : 4 cartes, chacune avec le nom, la rareté (couleur **et** texte), le prix, le type
  de dégâts et une description courte. Boutons pour acheter et pour relancer (avec son coût).
- Raccourcis clavier : 1 à 4 pour acheter, R pour relancer, Tab pour le tableau des scores.
- Tableau des scores (Tab) : joueurs, manche, éliminations, dégâts, revenu, état (en vie ou
  éliminé).
- Lisibilité : contrastes suffisants, la couleur ne porte jamais seule une information
  (rareté, armure).

## 7. Qualité et vérification

- GDScript **typé partout**. Les avertissements de typage manquant sont traités comme des
  erreurs dans `project.godot`.
- `gdlint` et `gdformat --check` (gdtoolkit 4) sur tout le code.
- Tests : `godot --headless --path . --script res://tests/lanceur.gd`, qui renvoie 0 si tout
  passe. La simulation est testée à fond, sans nœud. Test d'intégration : un serveur sans
  interface et deux clients robots sur localhost jouent une partie accélérée jusqu'à son terme,
  sans erreur dans les journaux.
- CI GitHub Actions : installer Godot (`tools/install-godot.sh`) puis gdtoolkit, puis
  `--import`, lint, format, tests unitaires et intégration. Les exports (Windows, Linux) seront
  ajoutés dans un second temps.
- Un `tools/verifier.sh` lance localement exactement ce que lance la CI.

## 8. Hors périmètre (version 1)

Le « lumber », la deuxième monnaie de l'original. Les skins à défis et le score persistant. Les
classements en ligne. Le serveur de mise en relation et le passage des NAT : on joue en LAN, par
IP directe (redirection de port), ou sur un serveur dédié. Les sons, qui viendront dans un second
temps (CC0). Les manettes.

## 9. Laissé à l'implémenteur

Le format exact des messages réseau (dans la limite du §4), les formes et couleurs de chaque
primitive, et l'équilibrage fin (dans la limite des tests du §5.6).
