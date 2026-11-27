# Retours de la première partie de Phil — conception

> Date : 25/11/2026. Source : 13 retours de Phil après une partie jouée sous Godot, et ses
> réponses aux questions de cadrage le même soir. Cette conception complète la spec du jeu
> (`2026-11-24-jeu-tour-design.md`) et l'emporte sur elle là où elles diffèrent. Elle donnera le
> lot 8 du plan. **Validée par Phil le 25/11/2026** ; D19, D20 et D21 ajoutées le 26/11/2026, D23 le 27/11/2026 (validée).

## 1. Intention

Phil a joué une partie. Trois choses lui manquent :

- **lire la partie** : texte net, interface plus petite (la boutique surtout), icônes, PV de la
  tour au-dessus de la tour, un effet visuel reconnaissable par arme, un tableau des scores qui
  dit qui progresse (revenu, dégâts par seconde) ;
- **une partie qui démarre plus vite** : la tour ne tire que quand les ennemis sont tout près ;
- **la fidélité aux mécaniques de « Tower Survivors »** : armes illimitées, vagues mêlées,
  portées d'ennemis variées, mana en bouclier, et seulement les ennemis du pack Tiny Swords.

La règle du projet ne change pas : mêmes mécaniques que la map, mais noms, chiffres, textes et
graphismes originaux.

## 2. Décisions de Phil (25/11/2026)

Ces décisions ne se remettent pas en cause ; une objection se dit dans la PR.

| #   | Sujet               | Décision                                                                                                                                                                                                                                                                      |
| --- | ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | Icônes              | La barre du haut montre une icône par information (temps, or…).                                                                                                                                                                                                               |
| D2  | Armes               | **Aucun plafond** au nombre d'armes portées (fin des 8 emplacements de la spec §5.3).                                                                                                                                                                                         |
| D3  | Zoom                | On peut dézoomer plus loin qu'aujourd'hui.                                                                                                                                                                                                                                    |
| D4  | Mini-carte          | Une mini-carte permet de se repérer et de **déplacer la vue en cliquant**. Elle **montre aussi les arènes des autres joueurs**.                                                                                                                                               |
| D5  | Effets d'armes      | Chaque arme a un effet visuel **différent et facilement reconnaissable**, « comme sur Warcraft ».                                                                                                                                                                             |
| D6  | Portée et vitesse   | Les portées des armes augmentent, et **la vitesse des ennemis** aussi (la tour reste immobile).                                                                                                                                                                               |
| D7  | Ennemis             | La guêpe maison est retirée : **seulement les ennemis du pack**, **tous présents** dans le jeu, **plusieurs sortes par vague**.                                                                                                                                               |
| D8  | Portées d'ennemis   | Trois classes : corps à corps, moyenne portée, longue portée.                                                                                                                                                                                                                 |
| D9  | Police              | Texte net et lisible : « Inquisition » (Woodcutter) n'est pas redistribuable (usage personnel seulement), Phil retient **Metamorphous** (OFL).                                                                                                                                |
| D10 | Tableau des scores  | Pour chaque joueur, le **revenu** et les **dégâts par seconde**.                                                                                                                                                                                                              |
| D11 | PV de la tour       | Une **barre de PV au-dessus de la tour**, plus dans la barre du haut.                                                                                                                                                                                                         |
| D12 | Mécaniques          | Reprendre celles de la map. La **mana** est un **bouclier** : elle absorbe les coups à la place des PV. **Certaines armes font des dégâts en fonction de la mana maximale.**                                                                                                  |
| D13 | ATH                 | Trop grand : **c'est la boutique qui prend trop de place**.                                                                                                                                                                                                                   |
| D14 | Catégories          | Dans la boutique, on distingue d'un coup d'œil **les armes, les améliorations et le revenu** (demandé après la première version de cette conception).                                                                                                                         |
| D15 | Sons des armes      | « Pas assez de diversité dans les sons des armes » : chaque arme a son propre son de tir (demandé après la validation de cette conception).                                                                                                                                   |
| D16 | Difficulté          | « Jeu beaucoup trop simple : je n'ai rien acheté pendant 10 manches et je ne suis toujours pas mort. » **Sans aucun achat, la tour tombe au plus tard à la fin de la manche 3.**                                                                                              |
| D17 | Montée en puissance | « Les ennemis doivent faire de plus en plus de dégâts et être de plus en plus résistants avec les manches. » Leurs **dégâts et leurs PV augmentent à chaque manche**, dès la manche 1.                                                                                        |
| D18 | Catalogue           | « On doit faire le même nombre d'armes dans le même type » que la map : **15 armes par type de dégâts** (75), réparties comme la map ; **84 améliorations** comme la map, plus nos 3 sans homologue (87) ; les **dix mécaniques d'armes** qui nous manquent. Détail au §6.13. |
| D19 | Tour                | **L'apparence de la tour suit ses améliorations** (demandé le 26/11/2026, « défaut oui pour tout ») : épines, PV, mana, armure, esquive, régénération et vol de vie se voient sur la tour, aussi sur celles des autres joueurs. Détail au §6.14.                              |
| D20 | Progression         | **Sauvegarde de la progression, défis et skins de tour** (26/11/2026) : défis réussis, skins débloqués et choisis, statistiques, enregistrés en local ; un skin par défi, purement cosmétique. Détail au §6.15.                                                               |
| D21 | Mouvement           | **Mouvement réduit** (26/11/2026) : aucune secousse de caméra dans le jeu, quel que soit le réglage ; une case « mouvement réduit » dans les réglages, décochée par défaut, coupe le gel d'impact et ne laisse qu'un éclat bref à l'impact. Détail au §6.16.                  |
| D23 | Fin de partie       | « Oui très bien pour les armes plus puissantes » (27/11/2026) : deux **raretés de fin de partie** à la mesure du revenu ; **une arme achetée en double monte l’arme de niveau** (elle ne s’empile plus). Détail au §6.17.                                                     |

Les propositions de la session de pilotage acceptées par Phil le même soir :

- portées des armes de 300 / 600 / 900 / 1 200 à **500 / 750 / 1 000 / 1 250**, vitesse de
  tous les ennemis **×1,5** ;
- **24 ennemis** : les 6 modèles du pack (Torche, Dynamite, Tonneau, Paysan, Archer, Guerrier)
  dans leurs 4 couleurs, **chaque couleur étant un palier de force** qui arrive au fil des
  manches ;
- classes de portée : corps à corps pour le Guerrier, le Paysan, la Torche et le Tonneau (qui
  explose au contact) ; **moyenne portée 350** pour la Dynamite ; **longue portée 650** pour
  l'Archer ;
- chaque manche mêle **2 ou 3 familles, dont une majoritaire** ; la barre du haut annonce leurs
  armures ;
- **plus d'ennemi volant** : la mécanique de vol (mines et pièges qui l'ignorent) est retirée ;
- tableau des scores : revenu (or versé à chaque période de 10 s, comme la barre du haut),
  dégâts par seconde (moyenne glissante des 10 dernières secondes) et dégâts totaux ;
- caméra : déplacement de la vue aux flèches et à ZQSD, **Espace** recentre sur la tour, dézoom
  jusqu'à voir **deux fois le cercle d'apparition** ; mini-carte en bas à droite ;
- armes illimitées : la liste des armes équipées défile ; la revente reste à 50 % ;
- barre de PV au-dessus de la tour, et une pour le boss ;
- effets d'armes : une **planche des 30 signatures** validée par Phil avant leur intégration ;
- réglage « Taille de l'interface » de 75 à 125 %.

## 3. Objectifs, non-objectifs, anti-objectifs

**Objectifs** : les 13 décisions ci-dessus, jouables en solo, en réseau local et sur serveur
dédié, et une passe d'équilibrage qui vérifie que la partie reste gagnable.

**Non-objectifs** :

- la musique d'ambiance (reportée par Phil le 25/11/2026) ;
- des capacités actives lancées par le joueur : la mana ne sert qu'au bouclier et aux armes qui
  en dépendent ;
- la deuxième monnaie de la map (« lumber »), toujours hors périmètre (spec §8).

**Anti-objectifs** (ce qui ferait échouer le lot même si tout « marche ») :

- un ennemi, une icône ou un effet qui ne ressemble pas au reste du pack ; aucun sprite d'ennemi
  dessiné par nous ;
- une police ou une image sans licence libre vérifiée ;
- dépasser le budget réseau de 50 000 o/s par client (spec, T3.3), mesuré à 1 000 ennemis et
  8 joueurs ;
- une mini-carte ou une caméra libre qui laisse le joueur perdre sa propre tour de vue sans
  moyen immédiat de revenir (Espace) ;
- casser l'observation après la mort, le mode sans fin ou le serveur dédié.

## 4. Contraintes

- `sim/` reste pure (`RefCounted`, 20 Hz) et ne dépend que de `data/` ; tous les chiffres vivent
  dans `data/*.json`, validés au chargement.
- Le protocole est versionné : **toutes les nouveautés réseau du lot passent en une seule
  version** (v5), pour ne pas casser deux fois la compatibilité.
- Le `Variant` implicite reste interdit ; chaque énumération se teste en entier ; tout hasard de
  test a une graine fixe.
- Les images, polices et sons sont versionnés avec leur licence et cités dans `CREDITS.md`.
- Godot 4.7.2 importe sur un seul thread (`editor/import/use_multiple_threads=false`) : à ne pas
  retirer.

## 5. Approches

| Approche                                                                                                                                                       | Ce qu'elle donne                                                                                                                                              | Écartée parce que                                                                                                                                       |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A. Un lot 8 découpé par zone** : d'abord la simulation, les données et le réseau (interfaces figées dans le plan), puis en parallèle le rendu et l'interface | Peu de conflits : chaque session possède ses fichiers ; les interfaces figées laissent démarrer le rendu et l'interface sans attendre la fin de la simulation | **Retenue**                                                                                                                                             |
| B. Tout dans la session du lot 5, à la suite                                                                                                                   | Aucun conflit                                                                                                                                                 | Trop lent : 13 sujets à la file dans un seul contexte déjà chargé                                                                                       |
| C. Une session par retour (13)                                                                                                                                 | Le plus de parallélisme                                                                                                                                       | `app/jeu.gd`, `ui/hud.gd`, `visuels/arene_2d.gd` et `reseau/protocole.gd` seraient touchés par 4 à 6 sessions : c'est la cause du `main` rouge du 25/11 |

## 6. Conception par sujet

Chaque sous-section dit **qui décide** : _(Phil)_ pour une décision de Phil, _(proposition)_ pour
un choix de la session de pilotage, à relire par Phil.

### 6.1 Ennemis (D7, D8)

- **Familles** _(Phil)_ : 24 = 6 modèles × 4 couleurs. La guêpe (`guepe_de_laiton`,
  `assets/maison/`, `tools/dessiner_guepe.gd`) est retirée, avec son test de génération et sa
  ligne de `CREDITS.md`.
- **Modèle → rôle** _(proposition)_ : l'armure, la classe de portée et le comportement suivent le
  modèle ; la couleur ne change que la force.

| Modèle   | Armure    | Classe de portée | Particularité                                                                                            |
| -------- | --------- | ---------------- | -------------------------------------------------------------------------------------------------------- |
| Torche   | légère    | corps à corps    | rapide, fragile                                                                                          |
| Paysan   | moyenne   | corps à corps    | équilibré                                                                                                |
| Guerrier | lourde    | corps à corps    | lent, résistant                                                                                          |
| Tonneau  | fortifiée | corps à corps    | explose au contact : dégâts sur la tour, puis disparaît ; il ne rapporte sa prime que s'il est tué avant |
| Dynamite | aucune    | moyenne (350)    | lance des projectiles                                                                                    |
| Archer   | moyenne   | longue (650)     | tire de loin                                                                                             |

- **Paliers de couleur** _(proposition)_ : jaune (palier 1), rouge (2), violet (3), bleu (4),
  dans `data/ennemis.json` par multiplicateurs de PV, de dégâts et de prime sur la famille de
  base. Un palier entre dans le tirage à partir d'une manche donnée (par exemple 1, 8, 16, 24) ;
  les chiffres vivent dans `data/` et sont réglés par la passe d'équilibrage.
- **Boss** : inchangé (Guerrier bleu ×3) ; il garde son armure de boss. **Convoi** : inchangé
  (moutons).
- **Vagues mêlées** _(Phil)_ : `Planning` tire pour chaque manche 2 ou 3 familles parmi celles
  autorisées par les paliers, dont une majoritaire _(proposition : 60 % des apparitions)_. Le
  tirage est le même pour tous les joueurs d'une partie (graine de partie) ; jamais la même
  famille majoritaire deux manches de suite.
- **Budget d'une manche** _(proposition)_ : le nombre d'apparitions et leur cadence ne changent pas (spec §5.5) ; seule la composition change. Chaque apparition tire sa famille selon les poids de la manche (60 % pour la majoritaire, le reste partagé), en mélange dans le temps et non par blocs. Boss et convoi gardent leurs règles. En mode sans fin, tous les paliers restent dans le tirage et les multiplicateurs de difficulté continuent (`apres_table`).
- **Annonce** : la vue globale porte les familles de la manche suivante ; la barre du haut
  montre leurs armures en icônes (texte en infobulle).
- **Vol retiré** _(Phil)_ : `volante` disparaît des données et de `sim/` ; mines et pièges
  touchent tous les ennemis.
- **Portées** _(Phil)_ : corps à corps (portée d'attaque ≤ 60), moyenne 350, longue 650. Avec les
  nouvelles portées d'armes, toutes les armes atteignent la moyenne portée ; seules les armes
  de 750 et plus atteignent l'Archer (à vérifier par la passe d'équilibrage, comme un choix de
  jeu et non un défaut).
- _(proposition)_ L'Archer n'entre dans le tirage qu'à partir de la manche 5, pour laisser au joueur le temps d'acheter une arme de portée 750 ou plus.

### 6.2 Portées des armes et vitesse des ennemis (D6)

- _(Phil)_ Paliers de portée des armes : 500 / 750 / 1 000 / 1 250 (`data/armes.json`, spec
  §5.4 mise à jour) ; vitesse de toutes les familles ×1,5 (`data/ennemis.json`).
- L'aura ignore toujours la portée (suivi déjà relevé, hors de ce lot).
- La passe d'équilibrage du lot (6.12) vérifie la courbe de difficulté avec ces valeurs.

### 6.3 Armes illimitées (D2)

- _(Phil)_ Plus de plafond : `emplacements_armes` disparaît de `data/partie.json` ;
  `Inventaire.ajouter` n'échoue plus pour cette raison ; `Resultat.EMPLACEMENTS_PLEINS` est
  retiré (ou reste inutilisé, au choix du réalisateur, avec un test qui le dit).
- Les tests qui figeaient « la 9e arme refusée » sont **inversés** : la 9e, et la 40e, sont
  acceptées.
- **Protocole** : `MAX_ARMES` passe de 16 à 255 (le nombre tient sur un octet). Au-delà, la
  boutique refuse l'achat proprement _(proposition)_ plutôt que de produire un état que le
  réseau ne sait pas encoder.
- **Performance** _(proposition)_ : le test de performance des tirs passe de 8 à 40 armes face
  à 1 000 ennemis ; le pas de simulation doit rester sous 5 ms.
- **Interface** : la liste des armes équipées devient une grille compacte d'icônes (images de
  T5.8b) qui défile ; le détail d'une arme est en infobulle.

### 6.4 Mana (D12)

- _(Phil)_ La mana est un **bouclier** : un coup reçu par la tour est d'abord absorbé par la
  mana, le reste va aux PV.
- _(proposition)_ Ordre : esquive, puis armure, puis mana, puis PV. **1 point de mana absorbe
  1 point de dégât.** La mana se régénère chaque seconde.
- _(Phil, 25/11/2026)_ La tour commence avec 0 de mana maximale (chiffre de `data/`, réglable après essai) : la mana vient des améliorations.
  Nouvelles améliorations dans `data/ameliorations.json` : mana maximale (+), régénération de
  mana (+). Les épines et le vol de vie gardent leur effet actuel.
- _(Phil)_ Des armes font des **dégâts en fonction de la mana maximale** : un champ d'arme
  `degats_par_mana_max` (ratio) ajoute `ratio × mana_max` aux dégâts de base.
  _(proposition)_ Environ 4 armes, plutôt magiques, l'utilisent : armes existantes modifiées ou
  nouvelles, au choix de la passe de contenu, avec un test d'équilibrage qui garde la règle de la
  spec §5.6 (dégâts par seconde par pièce d'or croissants avec la rareté).
- **Vue et réseau** : `VueArene` porte `tour_mana` et `tour_mana_max` ; protocole v5.
- **Rendu** : une barre de mana bleue sous la barre de PV au-dessus de la tour ; un éclat bleu
  sur la tour quand la mana absorbe un coup.

### 6.5 Effets visuels par arme (D5)

- _(Phil)_ Chacune des 30 armes a une **signature visuelle** qu'on reconnaît d'un coup d'œil :
  forme du projectile, couleur, traînée, impact, et effet de statut.
- _(proposition)_ Une table `visuels/signatures_armes.gd` (identifiant d'arme → signature), et
  un test qui vérifie que **deux armes n'ont jamais la même signature**, en boucle sur toutes les
  paires.
- Sources : les effets du pack Tiny Swords d'abord, puis des formes dessinées par code (traits,
  particules, anneaux) aux couleurs du pack. Aucune image tierce sans licence.
- Les statuts deviennent tous visibles, **vol de vie compris** (aujourd'hui sans visuel) : soin
  vert qui remonte vers la tour.
- _(Phil)_ Une **planche** des 30 signatures (captures en jeu ou rendu par un script de `tools/`)
  est validée par Phil **avant** l'intégration en jeu.
- L'intégration attend cette validation : la planche est une tâche courte à part, marquée « attend Phil », et les signatures entrent en jeu dans une tâche suivante, hors du chemin des autres tâches de la vague 2.
- Plafond d'effets simultanés conservé ; taille et luminosité suffisantes pour se lire au zoom

### 6.5 bis Sons des armes (D15)

- _(Phil)_ Les armes ne doivent plus partager un même son de tir.
- _(proposition)_ La signature d'une arme (6.5) comprend un **son de tir** propre, choisi dans le « 400 Sounds Pack » (CC0, https://ci.itch.io/400-sounds-pack, dossier Drive fourni par Phil, déjà cité dans `CREDITS.md`), surtout dans ses dossiers Weapons et Combat and Gore. L'impact reçoit un son par type de dégâts (5).
- Le catalogue de `sons/` accepte un identifiant par arme (`tir_<id d'arme>`), avec repli sur le son `tir` actuel. Une légère variation de hauteur à chaque tir évite la répétition, sans rendre deux armes confondables.
- Test : pour les 30 armes, en boucle, chaque arme a un fichier de tir versionné, et **deux armes n'ont jamais le même fichier**. Les sources sont listées dans `assets/sons/SOURCES.md`.
  le plus lointain.

### 6.6 Police (D9)

- _(Phil)_ Metamorphous (SIL OFL 1.1), fichier et `OFL.txt` versionnés sous
  `assets/polices/metamorphous/`, cités dans `CREDITS.md`. Elle remplace Tiny5 partout ; le
  repli DejaVu Sans reste pour les symboles.
- Vérifier la couverture : é, è, ê, à, ç, œ, « », espace insécable et espace fine.
- Les tailles passent par un seul réglage du thème (`ThemeJeu`) au lieu des 5 surcharges
  locales actuelles ; les tests de mise en page restent verts.

### 6.7 ATH, boutique et taille de l'interface (D1, D11, D13)

- **Barre du haut** _(Phil)_ : une icône par information (or, revenu, manche, temps, armures de
  la prochaine manche, nombre d'armes), plus de PV. _(proposition)_ Hauteur ramenée d'environ
  60 px à 40 px.
  - Icônes : Ravenmore (CC BY 3.0) et Tiny Swords (CC0) déjà versionnés. Il manque un sablier :
    le réalisateur en cherche un sous licence libre (CC0 ou CC BY) ; à défaut, il le demande à
    Phil.
- **Boutique** _(Phil : c'est elle qui prend trop de place)_ :
  - _(proposition)_ cartes compactes : image, nom, prix et rareté visibles ; la description en
    infobulle ;
  - le panneau se replie et se déplie (touche B et bouton) ;
  - les raccourcis 1 à 4 et R restent.
- **Catégories des offres** _(Phil, D14)_ : une arme, une amélioration et une offre de revenu se reconnaissent d'un coup d'œil.
  - _(proposition)_ Chaque carte porte en tête un ruban du pack Tiny Swords, d'une couleur propre à sa catégorie (rouge pour une arme, bleu pour une amélioration, jaune pour le revenu, selon les couleurs que le pack fournit), avec une icône (épée, flèche montante, pièce) et le mot écrit « Arme », « Amélioration » ou « Revenu ». La couleur ne porte jamais seule l'information.
  - Le revenu regroupe les améliorations économiques : revenu fixe, revenu croissant, multiplicateurs de revenu et de prime, bonus d'éliminations. La catégorie devient un champ de `data/`, validé au chargement, plutôt qu'une déduction du code.
  - Les mêmes repères servent dans la grille des armes équipées, dans la liste des améliorations achetées et au marché noir.
- **Taille de l'interface** : réglage de 75 à 125 % (défaut 100 %), persistant, appliqué à
  tout l'ATH.
- **Barres au-dessus de la tour** _(Phil)_ : PV (vert vers rouge sous 30 %), chiffres « x / y »,
  et barre de mana dessous (6.4). Une barre de PV au-dessus du boss.

### 6.8 Tableau des scores (D10)

- _(Phil)_ Colonnes ajoutées : **revenu** (or par période de 10 s, intitulé « Revenu / 10 s »),
  **dégâts par seconde** (moyenne glissante des 10 dernières secondes) et dégâts totaux.
- **Simulation** : chaque arène tient les dégâts infligés par seconde sur les 10 dernières
  secondes (tampon circulaire), épines comprises ; la vue globale porte `dps` (f32) par joueur ;
  protocole v5.

### 6.9 Caméra (D3)

- _(Phil)_ Déplacement de la vue aux flèches et à ZQSD ; **Espace** recentre sur la tour ;
  dézoom jusqu'à deux fois le cercle d'apparition (aujourd'hui : le cercle entier au plus loin).
- _(proposition)_ Vitesse de déplacement de la caméra réglable dans les réglages ; la vue ne
  s'éloigne pas à plus de deux rayons d'apparition de la tour.
- Les raccourcis existants (1 à 4, R, Tab, Échap) ne changent pas ; ZQSD et les flèches ne
  servent à rien d'autre aujourd'hui.

### 6.10 Mini-carte (D4)

- _(Phil)_ En bas à droite. Elle montre **sa propre arène** : la tour, les ennemis en points
  (couleur de palier), le cercle d'apparition et le cadre de la vue. **Un clic** y déplace la
  vue.
- _(Phil)_ Elle montre **aussi les arènes des autres joueurs**, en vignettes (une par joueur,
  avec son nom et une barre de PV). _(proposition)_ Un clic sur une vignette **affiche cette
  arène** dans la vue principale, comme l'observation après la mort ; **Espace** revient à la
  sienne. Le HUD et la boutique restent ceux du joueur.
- **Réseau** _(proposition, à mesurer)_ :
  - pour chaque autre arène, la vue globale porte une **carte de densité des ennemis** de
    16 × 16 cases (un octet par case), envoyée à 1 Hz : environ 2 Ko/s par client à 8 joueurs ;
  - regarder une autre arène de son vivant demande au serveur de l'envoyer en plus de la sienne,
    à fréquence réduite (5 Hz) ; la sienne reste à 15 Hz ;
  - la mesure de T3.3 (8 clients, 1 000 ennemis) est refaite : le budget de 50 000 o/s par client
    doit tenir, sinon la fréquence de l'arène regardée baisse.
- Le solo n'a que sa propre arène ; la mini-carte n'affiche alors pas de vignette.

### 6.11 Réseau : version 5 du protocole

Une seule montée de version pour : armes jusqu'à 255, `tour_mana` et `tour_mana_max`, `dps`
par joueur, familles de la manche suivante (jusqu'à 3), carte de densité par arène, demande
d'observer une autre arène de son vivant. Décodage défensif et tests de fuzz comme les versions
précédentes.

Aucun client ni serveur de jeu en version 4 n'est distribué. L'annuaire du lot 7 (T7.4) ne relaie aucune donnée de jeu et liste chaque salon avec sa version : la version 5 ne demande donc aucune coordination de mise en service, seulement un numéro de version à jour dans l'annonce.

### 6.12 Passe d'équilibrage

Après les données (6.1 à 6.4) : l'outil d'équilibrage existant (`docs/equilibrage.md`) rejoue
des parties par robot avec les nouvelles portées, vitesses, familles, paliers et mana. Il vérifie
qu'une partie reste gagnable et que la difficulté monte sans mur, puis consigne ses chiffres dans
`docs/equilibrage.md`. Les suivis déjà ouverts (rampe de dégâts, mur de PV après la manche 20)
sont revus avec ces nouvelles valeurs.

- **Critère** _(proposition)_ : les cibles du robot consignées dans `docs/equilibrage.md` restent atteintes, et le robot de référence n'est pas éliminé avant la manche 20.
- **Seuil bas** _(Phil, D16)_ : un robot qui n'achète rien perd sa tour au plus tard à la fin de la manche 3, pour toute graine testée. Aujourd'hui, les ennemis ne font que 3 % de leurs dégâts des manches 1 à 4 et 100 % à la manche 10 (`data/difficulte.json`) : cette rampe est relevée. Le test vit avec la simulation (vague 1), pas seulement dans la passe finale.
- **Montée continue** _(Phil, D17)_ : les multiplicateurs de PV et de dégâts de `data/difficulte.json` croissent strictement d'une manche à la suivante, de la manche 1 à la 30, puis en mode sans fin. Aujourd'hui, les PV restent à ×1 des manches 1 à 10. Les paliers de couleur (6.1) s'y ajoutent sans la remplacer. Test en boucle sur toutes les manches : `pv(n + 1) > pv(n)` et `degats(n + 1) > degats(n)`. La pente est réglée par la passe, entre le seuil bas (D16) et le critère du robot qui achète.
- **Leviers autorisés sans revenir à Phil** : manches d'entrée des paliers et de l'Archer, PV, dégâts et primes par palier, poids des familles, chiffres de la mana et des armes de mana, poids de rareté de la boutique, rampe de dégâts et de PV de `data/difficulte.json`.
- **Non modifiables sans Phil** : les paliers de portée des armes (500 / 750 / 1 000 / 1 250), la vitesse ×1,5, les portées d'ennemis 350 et 650.

### 6.13 Catalogue aligné sur la map (D18)

Décidé par Phil le 25/11/2026 au vu du comparatif `docs/tower_survivors.md` (map v1.58, dernière
version publique ; le « type » est le type de dégâts, comme dans la boutique de la map).

- **Armes** _(Phil)_ : **15 par type de dégâts**, 75 au total, soit 45 de plus. Répartition de
  la map dans chaque type : **1 commune, 6 peu communes, 6 rares, 2 épiques**. Dans chaque
  type, une de nos deux communes passe peu commune et l'on ajoute 3 peu communes, 5 rares et
  1 épique. La commune qui change de palier est celle dont les dégâts par seconde par pièce d'or
  sont les plus hauts (critère du test d'équilibrage de la spec §5.6) ; son prix suit son palier.
- **Améliorations** _(Phil)_ : autant que la map, **84**, famille par famille (tableau du §6.2
  de `docs/tower_survivors.md`) : états (poison, givre, feu, étourdissement), épines, bouclier
  de mana, classes d'armes, points de vie, régénération, armure, revenu, boutique, aura mixte.
  Nos 3 améliorations sans homologue dans la map (2 coups critiques, 1 cadence de plus) **restent** _(Phil, 26/11/2026)_ : **87 améliorations en tout**, 47 à ajouter, aucune retirée.
- **Mécaniques d'armes** _(Phil : « toutes »)_ : vulnérabilité cumulable par type de dégâts,
  malédiction (dégâts ennemis réduits, chances de toucher réduites), repoussement, siphon de
  mana et mana au coup, dégâts selon les PV maximum, le nombre d'exemplaires ou les améliorations
  possédées, invocation d'alliés temporaires, tir tournant, zone posée qui inflige ses dégâts
  dans le temps, bombe à retardement. Les épines deviennent aussi un second type de dégâts
  possible pour une arme, comme dans la map.
- **Précisions de Phil (26/11/2026)** :
  - les armes « selon les PV maximum » ajoutent un ratio des PV maximum de **la tour**, comme les
    armes de mana avec la mana maximale ;
  - les alliés invoqués sont **invulnérables et ignorés** des ennemis, qui continuent vers la
    tour ; 64 au plus, ils disparaissent à la fin de la manche ;
  - le critère de la commune qui change de palier s'applique partout, même s'il laisse un piège
    seule commune de son type.
- **Ce qui ne change pas** : noms, textes et chiffres restent originaux ; aucun prix, dégât ni
  durée de la map ne se recopie (`docs/tower_survivors.md` l'interdit en tête). Nos prix restent
  ceux de `data/`, calés par le test d'équilibrage. Nos pièges (`chausse_trape`, `sablier_fele`),
  absents de la map, restent. Chaque nouvelle arme a sa signature visuelle (D5, planche validée
  par Phil) et son son de tir (D15).
- **Garde-fou** : un test échoue si un nom d'origine listé dans `docs/tower_survivors.md`
  (§4.1 et §4.2) apparaît dans `data/`, `i18n/` ou le code.
- **Ordre** : lot 9, après les tâches du lot 8 qui touchent `data/armes.json` et les schémas
  (T8.1, T8.3, T8.5, T8.7) et après la planche des signatures (T8.14), pour ne pas mettre deux
  sessions sur les mêmes fichiers. La passe d'équilibrage du lot 8 (T8.21) est rejouée à la fin du
  lot 9.

### 6.14 Apparence de la tour (D19)

Décisions de Phil du 26/11/2026 (« défaut oui pour tout »). Livrée par les tâches T9.23 à T9.25 du
plan, **après** T9.10 à T9.12 (les améliorations qui donnent les statistiques) ; la revue du lot 10
reste en dernier.

- **A1, ce qui se voit.** Une statistique offensive reste montrée par les armes ; les sept
  statistiques de survie se voient sur la tour :

  | Statistique  | Ce qu'on voit                                                                     |
  | ------------ | --------------------------------------------------------------------------------- |
  | épines       | piques sur les murs                                                               |
  | PV maximum   | la tour grandit                                                                   |
  | mana         | bulle bleue, d'autant plus pleine que mana / mana maximale est haut, disparue à 0 |
  | armure       | couches de plaques                                                                |
  | esquive      | flou et images rémanentes                                                         |
  | régénération | lueur verte                                                                       |
  | vol de vie   | filets rouges aspirés                                                             |

- **A2, trois paliers nets** par statistique. Les seuils vivent dans `data/apparence_tour.json`
  (validé au chargement), jamais dans le code. Une statistique sous son premier seuil ne montre
  rien. Pour la mana, le palier est celui de la **mana maximale** (taille et opacité de la bulle) ;
  son remplissage suit le ratio mana / mana maximale à chaque image, et la bulle disparaît à 0
  (lecture du plan : la conception ne dit pas à quoi sert le palier de la mana, voir les points
  ouverts).
- **A3, agrandissement purement visuel**, **+25 % au plus** (borne validée dans
  `data/apparence_tour.json`). Il ne s'applique qu'au sprite : le rayon de la tour dans `sim/`, la
  distance d'arrêt des ennemis (`Arene2D.distance_arret`) et leur portée ne changent pas. Un test
  le garde : agrandir la tour au maximum ne déplace aucun ennemi ni aucun tir de la simulation.
- **A4, on voit aussi les tours des autres joueurs** (arène regardée, T8.13). Les statistiques
  nécessaires passent donc dans `VueArene` (épines, esquive, régénération, vol de vie, s'ajoutant à
  `tour_pv_max`, `tour_armure`, `tour_mana` et `tour_mana_max` qui y sont déjà), avec **une montée de
  `Protocole.VERSION`** : relire celle de `main` avant de l'incrémenter (piège de `CLAUDE.md`).
  La simulation ne transmet que des **statistiques**, jamais un palier ni une apparence : elle ne
  connaît pas l'apparence.
- **A5, superpositions dessinées** dans le style de Tiny Swords, avec des outils libres (licence
  OSI ; ni Aseprite ni générateur d'images par IA). **Une planche avant/après** est montrée à Phil
  pour validation avant leur intégration en jeu, comme T9.18.
- **Rendu dans `visuels/` seulement.** `sim/` ne connaît pas l'apparence ; `visuels/` lit la vue et
  les seuils, n'écrit jamais dans `sim/`. Chaque superposition a un **point d'ancrage** décrit dans
  `data/` (voir B7 : les skins du §6.15 en ont chacun les leurs).

### 6.15 Progression, défis et skins de tour (D20)

Décisions de Phil du 26/11/2026 (« défaut oui pour tout »). Livrée par un lot 11 du plan, avant la
revue du lot 10.

- **B1, ce qu'on sauvegarde** : les défis réussis, les skins débloqués, le skin choisi et des
  statistiques (nombre de parties, meilleure manche). Un fichier local sous `user://`, **versionné**,
  avec une **copie de secours**. **Aucune perte en cas d'échec d'écriture** : on écrit dans un
  fichier temporaire, on le relit pour le contrôler, puis on le **renomme** par-dessus l'ancien (qui
  devient la copie de secours) ; un fichier absent, tronqué ou d'une version inconnue se remplace par
  la copie de secours, jamais par un fichier vide. Un fichier trop gros est refusé avant lecture
  (entrée d'un tiers : le contexte commun §11).
- **B2, locale et non vérifiée.** La progression est cosmétique : le serveur ne la vérifie pas. Le
  **skin choisi est transmis au serveur** pour que les autres joueurs le voient ; le serveur borne
  l'index reçu (un index hors catalogue vaut le skin par défaut), comme tout champ venu d'un
  client. Un serveur dédié n'enregistre rien.
- **B3, les défis de la map d'origine**, relevés pour leur **seule mécanique** : noms et textes
  originaux, garde-fou des noms d'origine (T9.1) appliqué à `data/defis.json` et aux textes. La liste
  est **soumise à Phil pour validation avant toute implémentation** (tâche qui attend Phil).
- **B4, solo et multijoueur** : un défi vaut dans les deux modes ; en multijoueur, **chaque joueur
  présent valide le défi** pour lui-même (chaque poste enregistre dans son fichier local).
- **B5 (Phil), un skin par défi**, purement cosmétique : aucun effet sur le jeu, la simulation ou
  l'équilibrage.
- **B6, sprites de tour** en pixel art proches de Tiny Swords, sous licence **CC0**, ou **CC-BY**
  avec crédit dans `CREDITS.md` et la licence **vérifiée à la source** (citée dans
  `assets/tours/SOURCES.md`). Les sprites existants ne sont **pas retouchés** pour en faire des
  skins. Une **planche des skins** est montrée à Phil avant l'intégration. Les tours Gobelin de
  Tiny Swords, déjà dans le dépôt (`Wood_Tower_{C}`), sont candidates.
- **B7, les superpositions de D19 se posent sur n'importe quel skin**, à des points d'ancrage **par
  skin** décrits dans `data/skins_tour.json` ; un skin sans ancrage pour une superposition est refusé
  au chargement.
- **B8, la couleur du joueur reste lisible** : chaque skin garde une marque de la couleur du joueur
  (drapeau ou liseré), pour les huit couleurs ; la couleur n'est jamais la seule information (le nom
  reste écrit sous la tour, comme aujourd'hui).
- **B9, des défis cumulés sur plusieurs parties** _(Phil, 26/11/2026, remplace le « non » par défaut)_ :
  certains défis se jouent d'une partie à l'autre (parties jouées, victoires, éliminations, or gagné,
  manches survécues, parties à plusieurs, dernière tour debout). Le **bilan reste par partie** (T11.2) ;
  les **cumuls vivent dans la sauvegarde** (`progression/`, T11.3bis : version 2 du fichier, migration de
  la version 1, bornes, aucune perte). `sim/` n'en sait rien.
- **B10, la liste des défis suit la map et les demandes de Phil** _(26/11/2026, la première liste a été
  refusée)_ : les mêmes **mécaniques** que les défis de la map (tenir un temps avec une contrainte,
  contraintes de revenu et de défense, boss final), **« gagner uniquement avec des armes de… »** (un défi par type
  de dégâts, par statut et par genre d'effet que les données comptent vraiment), des défis de **revenu**,
  **« être la dernière tour debout »** en multijoueur et des **défis cumulés**. Un skin par défi (B5) : 46 défis,
  46 skins dans `docs/defis.md`. Noms, textes et seuils restent les nôtres (garde-fou T9.1).
- **B11, la liste est validée** _(Phil, 26/11/2026)_ avec trois ajouts : des défis « uniquement… » pour
  les **pièges** et les **mines** (l'aura n'en a pas, point ouvert), des défis **« une seule arme »** (un
  générique, « vaincre le boss avec les exemplaires d'une seule arme », et une variante à la vingtième manche ;
  pas un défi par arme) et **un sprite par skin, pour tous** (B6 confirmé). Total : **46 défis, 46 skins**.
- **B12, un défi par nouveau genre d'arme, aucun par statut** _(Phil, 26/11/2026)_ : chaque genre du lot 9 qui compte
  au moins trois armes a son défi « uniquement… » et son skin (§6.15, un skin par défi) : aura et tir tournant (T9.13),
  puis zone posée, bombe et invocation (T9.15 à T9.17). Les statuts du lot 9 (`vulnerabilite`, `malediction_toucher`,
  `malediction_degats`, `repoussement`, `siphon`, `mana_au_coup`) n'en ont pas, ce que `docs/defis.md` liste. Total à la fin du lot :
  **51 défis, 51 skins**.

**Règles de dépendance du lot 11** (celles de `CLAUDE.md`, aucune exception) :

- La **sauvegarde et l'évaluation des défis** vivent dans un nouveau dossier **`progression/`**,
  **hors de `sim/`** : `sim/` ne connaît ni `progression/`, ni les skins, ni `user://`.
  `progression/` lit l'état d'arène et le bilan de partie par l'API publique (`sim/partie.gd`) ;
  il n'écrit jamais dans `sim/`.
- Le **bilan de partie** (compteurs que les défis lisent) est produit par `sim/` comme donnée pure
  et transmis par le réseau à la fin de la partie ; le skin choisi n'est pour `sim/` qu'un entier
  opaque rangé avec le joueur.
- `ui/` porte le choix du skin et la liste des défis ; tous les textes passent par `i18n/*.csv`.
- `visuels/` dessine les skins et les superpositions, depuis `data/skins_tour.json` et
  `data/apparence_tour.json`.

**Points ouverts** (une valeur par défaut est retenue dans le plan ; Phil la change s'il le veut) :

1. **Palier de la mana** (A2) : lu comme celui de la mana maximale, avec remplissage par ratio.
2. **Source des compteurs de défis** : un bilan calculé par la simulation et envoyé à la fin de la
   partie (déterministe, testable), plutôt qu'un cumul côté client sur un canal non fiable. **Tranché par
   Phil le 26/11/2026 : les cumuls entre parties vivent dans la sauvegarde locale** (B9), le bilan reste par
   partie.
3. **« Joueur présent »** (B4) : tout joueur connecté à la fin de la partie ou au moment où la
   condition du défi est remplie ; un joueur qui a quitté avant ne valide pas.
4. **Tours des autres joueurs** (A4) : on les voit dans l'arène regardée ; le tableau des scores
   n'affiche pas de tour. Si Phil veut une vignette de tour au tableau, il faut des statistiques
   par joueur dans la vue globale (autre montée de protocole).
5. **Nombre de skins** : un par défi, donc connu seulement après la liste validée (B3) ; les sprites
   à trouver ou à dessiner en dépendent (B6).
6. **Un skin non débloqué** peut être montré par un client modifié : accepté, la progression est
   cosmétique et non vérifiée (B2).

### 6.16 Mouvement réduit (D21)

Décision de Phil du 26/11/2026. Livrée par les tâches T8.22 (gel d'impact et propriété de l'arène) et
T8.23 (la case des réglages) du plan.

- **Aucune secousse de caméra**, quel que soit le réglage : la caméra ne bouge que sur la commande du
  joueur (flèches, ZQSD, Espace, molette, §6.9). Cette règle **remplace** la secousse que préconise le
  skill `game-feel` (écarté, voir `CLAUDE.md`).
- **Le gel d'impact** frappe les **coups forts** (zone, explosion, siège) : 2 à 3 images à 60 Hz,
  **l'attaquant et la cible seuls**, jamais la scène entière ; au plus trois par seconde. Il suspend
  l'animation et l'interpolation de leurs sprites et reste **purement visuel** (`CLAUDE.md`) : la
  simulation à 20 Hz et le réseau gardent le temps réel, et `Engine.time_scale` ne bouge jamais.
- **Case « Mouvement réduit »** dans les réglages, **décochée par défaut** (le gel est donc actif),
  conservée comme les autres réglages (`app/reglages.gd`) et reliée à la propriété
  `Arene2D.mouvement_reduit`. Cochée, elle **coupe le gel d'impact, le recul et le rebond d'échelle**
  de l'ennemi touché (des mouvements) ; il ne reste à l'impact **qu'un éclat bref** (l'éclaircissement
  de l'ennemi touché, déjà borné à trois par seconde par ennemi, WCAG 2.3.1).

### 6.17 Armes de fin de partie et niveaux d'arme (D23, validée le 27/11/2026)

> **Statut : validé par Phil le 27/11/2026** (réponses au §6.17.7 : Q1 dégâts **et** cadence par niveau,
> Q4 plus de vente, Q6 améliorations de fin de partie aussi, le reste par défaut). Les valeurs
> chiffrées restent des propositions à confirmer par la mesure (T12.9). D23 remplace D2 sur un seul
> point : un doublon ne fait plus une arme de plus, il monte l'arme existante (« aucun plafond »
> reste vrai : le niveau n'a pas de plafond par défaut).

**Décision de Phil (27/11/2026)** : « Oui très bien pour les armes plus puissantes, par contre je
vois pas bien l'intérêt de juste monter le prix des armes en double sans monter leurs stats. Autre
point, plutôt que d'acheter la même arme x10, les armes achetées en double doivent compter comme
une amélioration de la première et juste monter les dégâts. » Le boss de la manche 31 doit être
battu par ces armes plus puissantes, **sans plafonner ses PV**.

#### 6.17.1 Constat chiffré (mesuré sur `main`, robot « bonne », graines 1 à 8)

| Mesure                        | Valeur                                                                                                                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Prix du catalogue             | commune 100 à 130, peu commune 100 à 300, rare 500 à 560, épique 950 à 1 150 ; **rien au-dessus de 1 150 or**                                                                  |
| Or en fin de partie           | graine 1 : 727 or (manche 26), **11 578 (27), 76 509 (28)**, 42 969 au boss ; graines 2 à 8 : 160 à 1 040 or au boss (le robot dépense tout en améliorations)                  |
| Arsenal du robot              | 8 armes dont 6 à 8 distinctes : il achète des doublons faute d'autre achat utile                                                                                               |
| PV du boss au début du combat | 35 000 × 1,754 (manche 20) × 2,8 par manche de 21 à 31 × 2,197 (trois accélérations de 300, 600 et 900 s) ≈ **1,1 × 10¹⁰**                                                     |
| Combat contre le boss         | victoire en 2 200 et 2 691 s (graines 2 et 8) ; **aucune victoire en 3 070 s** pour les six autres ; l'arène est tenue (le robot ne meurt pas) mais le boss ne tombe pas       |
| Doublons                      | `Inventaire.armes` garde un id par exemplaire (jusqu'à 255) ; chaque exemplaire tire seul ; seules 2 armes (`degats_par_exemplaire` 0,4 et 0,5) lisent le nombre d'exemplaires |

Lecture : les victoires actuelles sont des **combats d'usure de 37 à 45 minutes**, à environ
5 × 10⁶ dégâts par seconde. Pour tuer le boss en **5 minutes**, il faut environ 3,7 × 10⁷ dégâts par
seconde, soit **×7 à ×8** sur les meilleures constructions d'aujourd'hui, avec un or qui, dans la
plupart des parties, est déjà dépensé : le gain doit venir de **plus de puissance par pièce d'or**
dans les achats de fin de partie, et d'**or qui s'accumule** (primes) quand la partie va bien.

#### 6.17.2 Raretés de fin de partie

- **Deux raretés au-dessus de l'épique**, aux noms originaux : **ancestrale** (`ancestrale`) et
  **souveraine** (`souveraine`). `Types.Rarete` et `NOMS_RARETES` passent à six ; la couleur et le
  symbole de chaque rareté (`Apparence.couleur_rarete`, `symbole_rarete`) et leurs textes
  (`i18n/`) suivent, avec un symbole distinct de la couleur seule.
- **Prix qui suivent le revenu** : ancestrale **3 000 à 5 000 or**, souveraine **8 000 à 10 000 or**
  (l'épique d'aujourd'hui reste à 950 à 1 150 : les raretés actuelles ne bougent pas, la partie
  jusqu'à la manche 20 non plus). Ordre de grandeur de la map d'origine : 500 / 2 000 / 5 000 /
  10 000 ; nos chiffres restent les nôtres et vivent dans `data/armes.json`.
- **Apparition** (`data/boutique.json`, `poids`) : ancestrale **dès la manche 14** (poids 4 en
  manche 14, 10 en manche 28), souveraine **dès la manche 22** (poids 2, puis 6) ; la boutique
  n'en propose pas avant, le marché noir non plus (`raretes_max` reste « rare »).
- **Catalogue d'armes** : **15 armes**, soit 3 par type de dégâts (2 ancestrales, 1 souveraine),
  noms originaux.
- **Améliorations de fin de partie** (Phil, Q6 : « Oui late game upgrade aussi ») : **20
  améliorations**, une ancestrale et une souveraine par **famille des 10 épiques d'aujourd'hui**
  (dégâts globaux, cadence, revenu, dégâts de chacun des 5 types, PV maximum, résurrection),
  noms originaux. Valeur de l'effet **1,2 ×** (ancestrale) et **1,5 ×** (souveraine) celle de
  l'épique de la même famille (0,35 → 0,42 et 0,525 pour un type de dégâts) ; prix dans les mêmes
  bandes que les armes de la rareté (3 000 à 5 000 et 8 000 à 10 000 or). **Plafonds respectés** :
  `ameliorations.facteur_degats_max` (20) borne toujours le produit des dégâts ; les nouvelles
  améliorations de dégâts entrent dans la catégorie C des épiques (additives entre elles), pas dans
  une catégorie multiplicative de plus ; les résurrections et le revenu gardent leurs bornes.
  `Inventaire` empile déjà les améliorations (n exemplaires = n fois la valeur) : un test
  vérifie que la pile d'une amélioration tardive reste dans les plafonds.
- **Puissance** : le rendement (`Equilibrage.rendement`, dégâts par seconde par pièce d'or) d'une
  arme ancestrale vaut **1,2 ×** celui de la meilleure épique du même type, celui d'une souveraine
  **1,5 ×**. Dépenser de l'or tardif est donc toujours plus rentable que de le garder, et la
  concentration (les niveaux, §6.17.3) récompense un build.
- **Effet attendu sur l'or** : avec des offres à 3 000 à 10 000 or, la prime de 64 000 or par
  manche des manches 26 à 28 (graine 1) se convertit en 6 à 20 achats par manche au lieu de rester
  inutilisée.

#### 6.17.3 Un doublon monte l'arme de niveau

- **Inventaire** : une arme est portée **une seule fois** ; `Inventaire.armes` garde les ids
  distincts dans l'ordre d'achat et un `niveaux: Dictionary` (id → niveau, 1 au premier achat).
  Acheter une arme déjà portée **monte son niveau de 1** ; rien n'est ajouté à la liste.
  `ArmeEquipee` (recharge, mines, ondes, phase) est créée une fois par arme, pas par exemplaire :
  l'état de tir ne se multiplie plus.
- **Gain par niveau** (**Phil : « 30 % is good but cadence need to get better as well »**) :
  **+30 % des dégâts de base** de l'arme, **additif** (dégâts du niveau n = base × (1 + 0,30 ×
  (n − 1))), **et** une cadence qui monte aussi : **+20 % de cadence par niveau**, additif
  (cadence du niveau n = cadence de base × (1 + 0,20 × (n − 1)), s'ajoutant à la cadence des
  améliorations). Ces deux facteurs vivent dans `data/partie.json` (`niveaux.gain_degats` 0,30 et
  `niveaux.gain_cadence` 0,20) ; **0,20 est la valeur retenue par la mesure de T12.1 (le robot de référence tombait à la manche 19 avec 0,10 et tient la 20 sur les dix graines avec 0,20), à reconfirmer par T12.9** (levier
  de la passe d'équilibrage). La cadence totale d'une arme (améliorations et niveaux) est bornée
  par `niveaux.cadence_max` (proposition : +300 %, soit une recharge divisée par quatre ; aucun
  plafond de cadence n'existe aujourd'hui, voir le risque 9). Seuls les **dégâts et la cadence**
  montent (portée, nombre de projectiles, durée des statuts ne bougent pas) ; les bonus de type,
  globaux et d'améliorations s'appliquent ensuite comme aujourd'hui.
- **Prix d'un niveau** : le **prix de l'arme** (sans surcoût, puisque le niveau fait monter
  dégâts et cadence). Le premier niveau ajoute environ 43 % du débit de dégâts de base (×1,3 de
  dégâts et ×1,2 de cadence) pour le prix plein : une arme nouvelle (100 % du débit de base)
  reste **1,8 fois plus rentable qu'un niveau**, ce qui pousse à diversifier, et le niveau reste
  le moyen de convertir de l'or quand la boutique ne propose rien de neuf.
- **Plafond** : aucun niveau maximal par défaut (D2) ; le réseau borne le niveau à 255 (un octet).
- **Pas de vente** (Phil, Q4) : voir §6.17.4. Une arme achetée reste portée jusqu'à la fin de la
  partie ; rien ne baisse de niveau.
- **`copie_prochaine_offre`** : le second exemplaire gratuit devient un niveau gratuit.
- **M5 `degats_par_exemplaire`** (2 armes) : renommé `degats_par_niveau`, même sens (ratio de la
  base par niveau au-dessus du premier, borné par `bonus_selon_stat_max`), **en plus** du gain
  générique. `Tir.degats_de_base` reçoit le niveau à la place du nombre d'exemplaires ;
  `Equilibrage.rendement` et la description de l'arme (`ui/description_offre.gd`) suivent.
- **Effets dessinés par exemplaire** : une arme = un effet visuel. Le niveau se lit sur
  l'icône de l'arme (insigne « niv. N ») et, pour l'effet, par un léger grossissement (≤ 25 %,
  même règle que l'apparence de la tour) laissé à la session de rendu ; aucun projectile de plus.
- **Performance** : au plus 75 armes actives (une par arme du catalogue) au lieu de 255
  exemplaires : le test de performance des tirs ne peut que s'améliorer.

#### 6.17.4 Boutique, ATH, réseau, sauvegarde, défis

- **Boutique** : l'offre d'une arme déjà portée affiche **« niv. N → N + 1 »** et les dégâts
  gagnés (« + X dégâts »), au lieu d'un doublon muet ; `Resultat.ARMES_AU_MAXIMUM` n'est plus
  renvoyé (le test qui le garde est inversé, pas supprimé).
- **ATH** : la grille des armes montre une icône par arme distincte avec son niveau ; le détail en
  infobulle donne les dégâts du niveau courant.
- **Réseau** : `VueArene.armes` garde `id` et `recharge_ratio` et gagne **`niveau`** (un octet par
  arme : 4 octets par arme au lieu de 3). **`Protocole.VERSION` monte** : relire celle de `main`
  avant de l'incrémenter (10 aujourd'hui), garder les formats précédents refusés par un test en
  boucle. La liste est plus courte (ids distincts) : le budget de 50 000 octets par client ne peut
  que baisser. `Protocole.MAX_ARMES` (255) reste la borne des ids distincts.
- **Fin de la vente** (Phil, Q4) : `Boutique.vendre`, `Arene.vendre`, `Partie.intention_vendre`,
  `Inventaire.prix_vente` et la clé `vente_ratio` de `data/partie.json` sont retirés ; l'intention
  « vendre » du réseau (`Protocole`, `Client.vendre`, `Serveur`) aussi, son numéro de genre reste
  réservé et refusé ; le bouton « Vendre » et ses textes (`BOUTIQUE_VENDRE_PRIX`,
  `BOUTIQUE_ARME_A_VENDRE`, `i18n/textes_boutique.csv`) disparaissent, la grille des armes ne sert
  plus qu'à lire (infobulle) ; `StrategiesJoueur` ne vend plus. Aucun défi ni `Bilan` ne lit la
  vente (grep fait : seul un commentaire de `Economie` la cite). Les tests de la vente sont
  inversés (« on ne peut pas vendre ») et non supprimés.
- **Sauvegarde** : le profil enregistre des compteurs de bilan, pas l'inventaire : **aucun
  changement de format**, vérifié par un test. `Bilan.achat_arme` compte toujours un achat par
  niveau (`armes_achetees`), `armes_distinctes` ne change pas.
- **Défis** : « n'acheter que des armes de tel type ou tel genre » reste exact (`armes_achetees`
  compte les niveaux). Les deux défis « les exemplaires d'une seule arme » (`arme_unique`,
  `arme_unique_endurante`) deviennent « les niveaux d'une seule arme » : même condition
  (`armes_distinctes ≤ 1`), texte et traduction corrigés, un test les garde.

#### 6.17.5 Le boss : de la puissance, pas un plafond de PV

- Les PV du boss et la rampe après la manche 20 **ne changent pas** (aucun plafond). Le critère
  de réussite est mesuré, pas supposé : voir le plan, T12.9.
- **Cibles de mesure** (`SimulationEquilibrage`, graines 1 à 10, robot « bonne » qui a le droit
  d'acheter les raretés de fin de partie et de monter les niveaux) : (1) l'or restant à l'arrivée
  du boss est au plus **10 % de l'or gagné** dans la partie sur au moins 8 graines ; (2) le boss
  tombe en **moins de 10 minutes** (cible souhaitée : 5) sur au moins 5 graines sur 10 ; (3) les
  cibles du robot de `docs/equilibrage.md` (D16, D17, médiane du raisonnable, victoire de la bonne
  stratégie sur 10 à 30 %) restent tenues, ou sont déplacées et justifiées dans la PR de la passe.
- Si le boss ne tombe pas assez vite malgré des armes à ×8 : les leviers sont le **gain de
  cadence par niveau** (valeur à confirmer par la mesure T12.9) et la **puissance des raretés
  tardives** (rendement 1,5 → 2, ou plus d'armes), jamais le plafond de PV ; si cela ne
  suffit pas, question à Phil (Q8).

#### 6.17.6 Risques

1. **Le premier tiers de la partie change** : aujourd'hui, 2 exemplaires d'une arme à 100 or
   valent +100 % de dégâts ; un niveau vaut +30 % de dégâts et +20 % de cadence, soit environ
   ×1,56 sur le débit de dégâts de l'arme au lieu de ×2. La rampe D16/D17 (la tour passive tombe en
   manche 3, le robot « bonne » tient la manche 20) se rejoue ; les gains par niveau sont le premier
   levier (T12.9).
2. **Les robots achètent des doublons et vendent** (6 à 8 armes distinctes sur 8 ; la stratégie
   de remplacement d'arme utilise `intention_vendre`) : `StrategiesJoueur` est à réécrire pour monter des niveaux,
   acheter les raretés tardives et ne plus vendre, sinon les mesures comparent deux robots
   différents.
3. **Un contenu tardif que personne ne verra** : les raretés n'apparaissent qu'à partir de la
   manche 14 et 22 ; si la plupart des parties se terminent avant, les 15 armes et les 20
   améliorations sont mortes. Les poids d'apparition se mesurent (nombre de parties qui voient une
   souveraine).
4. **Protocole** : version partagée par tous les lots (deux PR parallèles l'ont déjà portée au
   même numéro) ; le lot 12 la relit avant de l'incrémenter. La fin de la vente retire une
   intention, le niveau ajoute un champ : deux montées consécutives, ou une seule si les deux
   tâches sont intégrées ensemble.
5. **Signatures et sons des 15 armes** (D5, D15) : un travail de rendu par arme ; défaut :
   réutiliser les familles de signatures existantes avec une teinte de fin de partie, planche à
   valider (Q5).
6. **Tests qui figeaient « N exemplaires » ou la vente** : une douzaine de fichiers lisent
   `armes` comme une liste d'exemplaires (grep `exemplaires(`, `armes.size()`) et quatorze
   fichiers touchent la vente ; ils sont inversés, pas supprimés.
7. **Or que le robot ne dépense pas** (graine 1 : 76 509 or en manche 28) : à vérifier que ce
   n'est pas un défaut du robot (arsenal plafonné à 8, `ARMES_VISEES`) avant de conclure sur
   l'économie.
8. **Sans vente, un mauvais achat est définitif** : la boutique n'a plus de sortie pour une arme
   inutile ; le niveau et le choix des offres compensent, à vérifier à la mesure (la tour
   passive, D16, ne change pas).
9. **Pas de plafond de cadence dans les données** : `StatsTour.cadence` n'est borné nulle part
   (la durée de recharge n'a pas de plancher) ; les niveaux y ajoutent un bonus, donc un plafond
   `niveaux.cadence_max` est ajouté (T12.1), sans quoi l'arme de niveau élevé tirerait à chaque pas.

#### 6.17.7 Réponses de Phil (27/11/2026) et défauts retenus

| #   | Question                                                 | Réponse / défaut retenu                                                                                                 |
| --- | -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Q1  | Gain d'un niveau                                         | **Phil : « 30 % is good but cadence need to get better as well »** : +30 % de dégâts **et** +20 % de cadence par niveau |
| Q2  | Un niveau maximal                                        | Défaut : **aucun** (D2), 255 pour le réseau                                                                             |
| Q3  | Prix d'un niveau                                         | Défaut : **le prix de l'arme**, sans surcoût                                                                            |
| Q4  | Vendre une arme                                          | **Phil : « No selling in game »** : la vente disparaît du jeu                                                           |
| Q5  | Effets et sons des 15 nouvelles armes                    | Défaut : **familles existantes teintées**, planche à valider avant l'intégration                                        |
| Q6  | Améliorations de fin de partie                           | **Phil : « Oui late game upgrade aussi »** : 20 améliorations tardives (§6.17.2)                                        |
| Q7  | Noms des deux raretés                                    | Défaut : **ancestrale**, **souveraine**                                                                                 |
| Q8  | Si le boss ne tombe pas assez vite malgré les armes à ×8 | Défaut : **renforcer les raretés tardives**, jamais plafonner les PV ; sinon redemander à Phil                          |
| Q9  | Les doublons déjà achetés d'une partie en cours          | Sans objet : une partie n'est pas sauvegardée ; **aucune migration**                                                    |

## 7. Découpage proposé pour le plan (lot 8)

**Interfaces figées d'abord** (dans le plan, avant tout code) : champs ajoutés à `VueArene`, à
la vue globale et à `StatsTour`, schéma des familles d'ennemis (modèle, couleur, palier, classe
de portée), signature d'arme, messages de la version 5.

| Vague                         | Session                       | Tâches                                                                                                                                                                      |
| ----------------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1                             | Simulation, données et réseau | armes illimitées ; 24 ennemis, paliers, vagues mêlées, retrait du vol ; portées et vitesses ; mana ; DPS ; carte de densité ; protocole v5                                  |
| 2 (dès les interfaces figées) | Rendu                         | sprites des 24 ennemis et retrait de la guêpe ; barres de PV et de mana ; caméra libre et dézoom ; planche puis intégration des 30 signatures d'armes, sons de tir par arme |
| 2 (dès les interfaces figées) | Interface                     | police ; barre du haut à icônes ; boutique compacte et repliable, catégories des offres ; grille des armes ; taille de l'interface ; tableau des scores ; mini-carte        |
| 3                             | Équilibrage                   | passe d'équilibrage (6.12)                                                                                                                                                  |

T5.5 (bascule et retrait de l'arène 3D) passe avant la vague 2, puisque le rendu 3D n'a pas à
suivre ces changements.

## 8. Laissé au réalisateur

Les chiffres exacts dans `data/` (dans les bornes ci-dessus), la mise en page au pixel près,
le choix des effets du pack par arme (avant la planche), le nom des nouveaux fichiers, et le
nombre d'améliorations de mana. Les noms des 24 familles et des nouvelles améliorations sont
originaux, en français, et entrent dans `i18n/`.
