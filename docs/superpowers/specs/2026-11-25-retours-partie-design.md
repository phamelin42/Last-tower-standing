# Retours de la première partie de Phil — conception

> Date : 25/11/2026. Source : 13 retours de Phil après une partie jouée sous Godot, et ses
> réponses aux questions de cadrage le même soir. Cette conception complète la spec du jeu
> (`2026-11-24-jeu-tour-design.md`) et l'emporte sur elle là où elles diffèrent. Elle donnera le
> lot 8 du plan. **Validée par Phil le 25/11/2026.**

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
