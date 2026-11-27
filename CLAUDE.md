# Last Tower Standing — jeu de tour multijoueur

Règles communes à tous les projets de Phil (copie de `phamelin42/claude-context`, ne pas la modifier ici ; ce fichier l'emporte en cas de désaccord) : @.claude/CLAUDE.commun.md

## Le projet

Jeu de survie à tour, multijoueur, sous Godot 4.7.2 en GDScript typé. Une course entre économie,
dégâts et survie face à une difficulté planifiée ; une boutique aléatoire donne un build différent à
chaque partie. Il reprend seulement les mécaniques de la map Warcraft 3 « Tower Survivors » ; noms,
chiffres, textes et graphismes sont originaux, aucun fichier de la map n'est réutilisé.

Spécification : `docs/superpowers/specs/2026-11-24-jeu-tour-design.md`. Plan :
`docs/superpowers/plans/2026-11-24-jeu-tour-plan.md`. Chaque tâche cite ses paragraphes.

## Commandes

| Commande                                                       | Rôle                                                                       |
| -------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `tools/verifier.sh`                                            | Toutes les étapes de la CI, arrêt à la première rouge                      |
| `tools/verifier.sh --etape <nom>`                              | Une étape : `import`, `lint`, `format`, `tests`, `controle`, `integration` |
| `tools/install-godot.sh`                                       | Installe Godot 4.7.2 (somme SHA-512 vérifiée)                              |
| `tools/install-gdtoolkit.sh`                                   | Installe gdlint et gdformat 4.x dans un venv                               |
| `godot --headless --path . --script res://tests/lanceur.gd --` | Lanceur de tests (`-- --filtre test_<fichier>` pour un test ciblé)         |
| `tools/stress-import-csv.sh [--threads]`                       | Imports à froid en boucle, 400 CSV : rejoue le plantage de godot#125712    |
| `tools/capturer.sh res://<scène>`                              | Rend une scène sans écran en images PNG et en planche-contact, à regarder  |

## Structure

- `project.godot` : configuration ; les avertissements de typage manquant sont des erreurs.
- `data/*.json` : armes, améliorations, ennemis, manches, économie, efficacité. Tous les chiffres
  d'équilibrage vivent ici, validés au chargement.
- `sim/` : simulation pure (`RefCounted`), à pas fixe de 20 Hz, sans nœud ni réseau.
  `partie.gd` est son API publique.
- `reseau/` : ENet (serveur, client, protocole compact). Il n'appelle que l'API publique de `sim/partie.gd`.
- `visuels/` : rendu 2D pixel art (Tiny Swords), caméra, décor, effets. La correspondance entité → sprites est dans `visuels/apparence.gd`. Tout ce qui est propre à un fichier d'image (chemin, case, régions, échelle, cadence) est dans `data/assets.json` (lu par `Assets`, `PlanchesEffets` pour les effets d'attaque), jamais dans le code (T10.4).
  Attaques d'élément (D22) : `attaques_elementaires.gd` aiguille, un fichier par élément sous `visuels/attaques/` (`AttaqueElement`) ; leurs sprites sont dessinés par `tools/dessiner_effets_attaques.gd` et un fichier de dessins par famille sous `tools/dessin/` ; les mécaniques de genre (aura, onde, saut) sont dans `visuels/mecaniques_genres.gd`. Ajouter un élément : un fichier sous `visuels/attaques/`, ses dessins, une ligne de table ; un genre posé au sol (piège, mine) s'aiguille aussi dans `Effets._tir`.
- `ui/` : menus, salon, HUD, boutique, tableau des scores, écran de fin.
- `i18n/*.csv` : tous les textes visibles (colonne `fr`).
- `tests/` : `lanceur.gd`, `tests/unitaires/test_*.gd`, `tests/integration/`.
- `tools/` : installeurs et `verifier.sh`.

## Règles de dépendance

- `sim/` ne dépend de rien d'autre que `data/`. Il ne connaît ni `reseau/`, ni `visuels/`, ni `ui/`.
- `visuels/` et `ui/` lisent l'état d'arène ; ils n'écrivent jamais dans `sim/` directement.
- `reseau/` ne parle à la simulation que par `sim/partie.gd`.

## Règles pour les agents

- GDScript typé partout : variables, paramètres, retours. Pas de type `Variant` implicite.
- Identifiants de code en français sans accent ou en anglais ; `class_name` en PascalCase, fichiers
  en snake_case. Textes visibles en français, avec espaces insécables avant `: ; ? !` et dans « ».
- Un test décrit ce que le joueur doit obtenir. Une énumération se teste en entier, en boucle.
  Toute source de hasard dans un test reçoit une graine fixe.
- Écrire le test, le voir échouer pour la bonne raison, puis implémenter.
- Ne toucher qu'aux fichiers de sa tâche. Une interface fausse chez un voisin se signale, elle ne se corrige pas.
- Avant de pousser : `origin/main` fusionnée, puis les tests ciblés de ses fichiers (`--filtre`), `gdlint` et
  `gdformat --check` verts sur ce qui a changé. `tools/verifier.sh` complet en local seulement si la tâche touche
  une interface partagée (`sim/partie.gd`, `reseau/protocole.gd`, schéma de `data/`) : sinon, la CI de la PR le passe.
- Outils de dessin, d'animation et bibliothèques : gratuits et open source seulement (licence OSI) ;
  Aseprite et les générateurs d'images par IA sont exclus (Phil, 26/11/2026).
- Sons et ressources sonores : l'agent choisit lui-même un pack sous licence CC0, sans attendre Phil, une fois la licence vérifiée à sa source et citée dans `assets/sons/SOURCES.md` (Phil, 26/11/2026).
- Assets remplaçables (Phil, 26/11/2026) : changer un pack d'images ou de sons ne doit demander que de remplacer
  les fichiers. Chemin, taille de case, nombre d'images, régions, ancrages, échelle et durée vivent dans
  les données (`data/*.json`) ou se lisent sur la texture, jamais dans des constantes de `visuels/` ou de
  `ui/` ; chaque chemin d'asset passe par un seul point d'accès (`visuels/apparence.gd`, `ui/theme.gd`,
  `sons/catalogue_sons.gd`). Une valeur géométrique trouvée en dur se signale (audit T10.4).

## Skills de jeu tiers

Douze skills de `.claude/skills/` viennent de dépôts tiers (source et commit dans `skills-lock.json`),
relus fichier par fichier avant d'entrer ; le choix est expliqué dans `docs/skills-claude/`. Ils sont
génériques et en anglais : ce fichier et les règles de dépendance l'emportent.

- Animation d'attaque, de tir, d'impact ou de sort : skill local `animer-attaques-sorts` (principes
  chiffrés, capture avant et après par `tools/capturer.sh`, outils libres).
- Hit-stop, ralenti, gel d'impact : purement visuels, en suspendant l'animation et l'interpolation dans
  `visuels/` ; la simulation à 20 Hz et le réseau gardent le temps réel. `game-feel` passe par
  `Engine.time_scale` : remplacer ce passage par le gel visuel. **Aucune secousse de caméra, quel que soit le réglage** (D21, Phil, 26/11/2026) : le « screen shake » de `game-feel` est écarté ; la case « mouvement réduit » des réglages coupe le gel d'impact, le recul et le rebond d'échelle (T8.22, T8.23).
- `godot-multiplayer`, `godot-signals-groups` et `game-ai` servent pour l'API et les pièges (ENet,
  `@rpc`, A\*) ; l'architecture reste `sim/` pure et `reseau/` qui n'appelle que `sim/partie.gd`.
- `godot-gdscript-headless-testing` : ses pièges de code de sortie et d'`await` valent pour
  `tests/lanceur.gd`, qui reste le seul lanceur.
- Leurs exemples ne sont pas tous typés : typer en recopiant.
- Ajouter ou mettre à jour un skill tiers : le lire en entier, scripts compris, puis
  `DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 npx -y skills@1.9.0 add <source> --skill <nom> -a claude-code --copy -y`
  (sans ces variables, l'outil envoie un événement à skills.sh), relire le `git diff`, passer Prettier
  sur les `.md` copiés.

## Tableau d'avancement en direct

Demandé par Phil le 25/11/2026 : https://claude.ai/artifact/QQaqHHiz3E9tmc5tsgiLa2 (tableau de bord
privé, lu en direct). Ses lignes vivent dans sa base, pas dans la page :
`data/avancement/taches/T<lot>.<n>` (`statut` : `a_faire`, `en_cours`, `a_valider` ou `fait` ;
`pourcentage` ; `etape` ; `attend` ; `pr` ; `maj` en ISO UTC), `data/avancement/lots/L<n>` et
`data/avancement/suivis/S<n>` (`statut` `ouvert` ou `clos`).

- Dès qu'une tâche change d'état (commencée, PR ouverte, attend Phil, cochée, ajoutée au plan),
  l'agent principal met à jour sa ligne par `ArtifactData` (`get`, puis `update` avec `if_version`),
  dans la même étape que le plan. `pourcentage` : 0 à faire, 100 cochée, sinon une estimation dont
  `etape` dit ce qui reste. Un suivi relevé ou réglé met aussi à jour sa ligne. `maj` se lit par
  `date -u`, jamais estimée (deux heures écrites de tête étaient dans le futur).
- Ne jamais republier la page pour changer un chiffre : les pages ouvertes suivent la base seules.

## Écarts au contexte commun

- Pas de Node, npm, Angular, Fuda, Playwright ni Vitest. Le hook de session installe Godot et gdtoolkit, pas Node.
- GDScript typé au lieu de TypeScript ; gdlint et gdformat au lieu d'ESLint et Prettier.
- Tests par le lanceur maison `tests/lanceur.gd`, sans GUT ni gdUnit (interdits : dépendance téléchargée depuis GitHub).
- Prettier ne sert qu'au Markdown : `npx -y prettier@3.9.10 --check <fichiers .md>` avant de pousser.
- Les contrôles d'accessibilité et de bundle du contexte commun ne s'appliquent pas.
- Efficacité (Phil, 26/11/2026), à la place du § 4 et du suivi de PR du § 3 du commun :
  - suite complète en local seulement pour une interface partagée (voir « Règles pour les agents ») ;
  - la PR s'ouvre avec la fusion automatique (`enable_pr_auto_merge`, commit de fusion), puis la session
    passe à la suite sans attendre la CI ; une CI rouge se corrige dès son événement ;
  - une PR de Markdown seul ne passe que Prettier en CI (`.github/workflows/ci.yml`) ;
  - jusqu'à trois tâches qui s'enchaînent sur les mêmes fichiers partent dans une seule PR ;
  - la CI de `main` après fusion est vérifiée par la pilote, pas par la session.

## Pièges déjà rencontrés

- Les sommes SHA-512 de Godot sont sur la release GitHub `godotengine/godot-builds`, pas sur downloads.godotengine.org.
- Le paquet gdtoolkit ne s'installe pas avec `pip` dans le Python du système (PEP 668) : utiliser le venv de `tools/install-gdtoolkit.sh`.
- Un nouveau `class_name` reste inconnu tant que `godot --headless --path . --import` n'a pas tourné : le lancer avant le premier test. Les avertissements de typage sont des erreurs : typer aussi les variables de boucle (`for i: int in …`) et ne rien inférer d'un `Variant`.
- Les noms d'enums des JSON sont comparés tels quels, accents compris (« perçant », « siège », « légère », « fortifiée ») ; toute autre graphie est refusée.
- Un test qui dépend d'une classe encore à venir va dans un fichier de test séparé, pour ne pas bloquer les autres.
- `.claude/` porte un `.gdignore` et est exclu de gdlint : les worktrees des agents y vivent.
- `.gdlintrc` est en YAML (`max-line-length: 100`), pas en `clé=valeur` : sinon gdlint plante.
- Le lanceur lance les tests au premier `process_frame`, arbre actif : `_ready`, RPC, `await` et `attendre_images(n)` fonctionnent. Une méthode `test_*` qui dépasse `delai_max` (10 s) échoue, et le moteur libère les nœuds qu'elle a ajoutés sous `arbre.root`. Toute erreur de script ou `push_error` la fait échouer ; `attendre_erreur(motif)` déclare une erreur voulue (Godot l'imprime quand même sur stderr).
- Tout fichier écrit par un test va sous `dossier_temporaire()` ; tout port réseau est tiré à l'exécution (d'autres agents lancent leurs tests en même temps).
- Godot 4.7.2 importe les CSV de traduction en parallèle, et chaque import inscrit son `.translation` dans l'arbre de l'éditeur sans verrou (`EditorFileSystem::update_files`, godot#125712, sans correctif) : l'import à froid plantait au hasard (« double free or corruption », code 134 ou 139). Sur `ubuntu-latest` : 20 imports sur 60 (28 sur 60 sans les textures, 0 sur 60 sur un seul cœur), rarement en local. `textes_salon.csv` n'y est pour rien : c'est le premier libellé du groupe importé. D'où `editor/import/use_multiple_threads=false` dans `project.godot` (0 sur 300 en CI, +1 à 3 s par import à froid), gardé par `test_configuration_projet`. Ne le retirer qu'après `tools/stress-import-csv.sh --threads` (400 CSV, imports à froid en boucle) à 0 plantage sur un Godot plus récent.
- `restart: unless-stopped` ne relance pas un conteneur arrêté par `docker kill` (arrêt voulu) : pour éprouver le redémarrage du service d'annuaire, tuer son processus depuis l'hôte (`kill -9 <PID>`).
- `Protocole.VERSION` est partagé par tous les lots : deux PR parallèles l'ont portée au même numéro (T5.3b et T7.2b, 3). Avant de l'incrémenter, relire celle de `main` ; à l'intégration, la seconde prend le numéro suivant et garde les deux formats, avec un test qui refuse en boucle les versions précédentes.
- Les ids de joueur réseau sont des ids de pair ENet (i32 aléatoires, ex. 665857105), jamais des index 0..255 : tout champ ou test qui les transporte doit les tenir sur 32 bits.
- Le « 400 Sounds Pack » compte environ 314 fichiers, dont 111 jingles musicaux, et une cinquantaine de tirs ou d'impacts nettement distincts : le lot 9 complète avec les packs CC0 de Kenney (T9.20).
- Écrire du texte dans une `Image` sans écran (planche, capture) : passer par les glyphes du `TextServer`, le rendu de `Label` n'existe pas en `--headless`.
- Équilibrage (T8.21) : les primes du palier jaune (`data/ennemis.json`) pèsent bien plus que les rampes de PV et de dégâts ; avec des rampes presque plates, le robot « bonne » tombait encore en manche 8, faute d'or. Mesurer par graine (`SimulationEquilibrage.jouer`), pas sur la médiane seule : une même graine peut passer de 8 à 31 sur un changement minime. Un réglage s'essaie sur les graines 1 à 10 avant les 50 (une mesure à 50 graines dure plusieurs minutes une fois les parties longues).
- `Dictionary.merged(autre)` ne remplace pas les clés existantes (`overwrite` vaut `false`) : pour qu'une mutation remette une case en dur dans un `planches()`, il faut renvoyer le dictionnaire seul.
- Après un `git commit` enchaîné à d'autres commandes, relire `git log -1` : un commit raté ne se voit pas toujours dans la sortie.
- Attaques d'élément (D22) : une arme qui reçoit un élément quitte le rendu par signature ; avant d'en ajouter, relire les tests qui prennent « la première arme » de `SignaturesArmes` ou bouclent sur ses ids (`test_arene_2d` en prenait une). La vitrine des armes coupe les effets de plus de 50 px de rayon : juger une aura ou une onde sur une vue large (`-- --armes <id> --large` : une arme, la tour au centre).
- Les 30 armes du lot 8 ont un élément (D22) : le repli par signature ne se teste plus qu'avec `Effets.rendu_par_element = false`. Une vitrine à six armes fait déborder les effets larges d'une bande sur l'autre : juger une aura, une onde ou une zone sur une capture d'une seule arme.
- Une vitrine qui passe par une vraie `Arene2D` (`vitrine_mecaniques`) doit écarter ses positions : les sprites sont bien plus grands que les unités de jeu et se recouvrent sinon.
- Une vitrine dessine son fond dans le `_draw` de sa racine : un effet à `z_index` -1 (objet au sol, ombre) y est recouvert et reste invisible ; un objet posé reste à 0 (`kind` `piege` de `AttaquesElementaires`).
- Dans un worktree qui contient des fichiers non suivis d'autres tâches, `git add` se fait par chemins explicites, jamais `git add visuels` ni `-A` : un commit par arme a embarqué les éléments des armes suivantes, et un `git checkout -- <dossier>` a défait des retouches non commitées.
- Une douzaine de fichiers de test lisent le catalogue (signatures, sons, effets, défis, événements, descriptions) : un ajout dans `data/armes.json` ou `data/ameliorations.json` passe par `tools/verifier.sh --etape tests` avant de pousser. L'ordre des armes dans `armes.json` fixe les tirages de la boutique : un test d'équilibrage ne repose jamais sur une seule graine.
- Une mutation (casser le code pour voir un test échouer) se fait après un commit et par `Edit`, jamais défaite par `git checkout` : celui-ci efface aussi le travail non commité.
- Un budget de temps par pas se mesure au 10e centile de plusieurs pas (`MesurePas`, PR #71) : une mesure seule échoue sous la charge d'autres agents.
- Lire un fichier de l'utilisateur : `JSON.new().parse` (code de retour), pas `JSON.parse_string`, qui imprime une erreur du moteur sur un fichier abîmé et fait échouer le test.
- Après un changement de police, relancer `test_mise_en_page` : les largeurs du HUD et de la boutique en dépendent. Une image ou une icône se charge par `ui/theme.gd`, sinon `test_garde_ressources` (liste fermée) échoue.
- Une session écrit à la pilote par l'outil `mcp__claude-code-remote__send_message`, pas par `SendMessage` (erreur 401 vers une session cloud).
- Une classe interne GDScript ne voit pas les fonctions statiques de sa classe englobante : les appeler par la classe interne elle-même ou les y dupliquer (`tools/dessin/planche_outils.gd`).
- Une signature ajoutée à `SignaturesArmes` est utilisée en jeu par `Effets` : celles qui attendent la validation de Phil vont dans `TABLE_LOT_9`, que garde `SignaturesArmes.en_jeu` (T9.19 la lève).
- gdlint refuse plus de 40 méthodes publiques par fichier, tests compris : un fichier de test qui grossit se répartit en plusieurs `test_*.gd` qui étendent une base à `class_name` sous `tests/outils/` (`CasAttaquesTranchant`).
- Une bombe (genre `bombe`) n'explose qu'après son délai : la vitrine l'attend, et la fiche de son élément ne dit jamais `explosion` (c'est l'explosion du pack, en double de celle de l'élément). Un tic de zone posée n'est pas un coup de siège : ni gel ni recul (`Effets._impact_element`, `tic`).
- Une invocation n'émet qu'un événement `tir` (de la tour à l'allié) et un `impact` par coup de l'allié : l'élément pose l'apparition à l'arrivée de son projectile (`AttaqueChaos.apparaitre`, impact à âge négatif) ; les planches carrées neuves de D22 donnent leur case et leur diamètre visible par `GeometriePlanches`, pas par des constantes (T10.4).
