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

## Structure

- `project.godot` : configuration ; les avertissements de typage manquant sont des erreurs.
- `data/*.json` : armes, améliorations, ennemis, manches, économie, efficacité. Tous les chiffres
  d'équilibrage vivent ici, validés au chargement.
- `sim/` : simulation pure (`RefCounted`), à pas fixe de 20 Hz, sans nœud ni réseau.
  `partie.gd` est son API publique.
- `reseau/` : ENet (serveur, client, protocole compact). Il n'appelle que l'API publique de `sim/partie.gd`.
- `visuels/` : rendu 3D, caméra, effets. Les primitives Godot et les matériaux sont dans `visuels/apparence.gd`.
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
- Avant de rendre une tâche : `tools/verifier.sh` vert, `gdlint` et `gdformat --check` verts sur ce qui a changé.

## Tableau d'avancement en direct

Demandé par Phil le 25/11/2026 : https://claude.ai/artifact/QQaqHHiz3E9tmc5tsgiLa2 (tableau de bord
privé, lu en direct). Ses lignes vivent dans sa base, pas dans la page :
`data/avancement/taches/T<lot>.<n>` (`statut` : `a_faire`, `en_cours`, `a_valider` ou `fait` ;
`pourcentage` ; `etape` ; `attend` ; `pr` ; `maj` en ISO UTC), `data/avancement/lots/L<n>` et
`data/avancement/suivis/S<n>` (`statut` `ouvert` ou `clos`).

- Dès qu'une tâche change d'état (commencée, PR ouverte, attend Phil, cochée, ajoutée au plan),
  l'agent principal met à jour sa ligne par `ArtifactData` (`get`, puis `update` avec `if_version`),
  dans la même étape que le plan. `pourcentage` : 0 à faire, 100 cochée, sinon une estimation dont
  `etape` dit ce qui reste. Un suivi relevé ou réglé met aussi à jour sa ligne.
- Ne jamais republier la page pour changer un chiffre : les pages ouvertes suivent la base seules.

## Écarts au contexte commun

- Pas de Node, npm, Angular, Fuda, Playwright ni Vitest. Le hook de session installe Godot et gdtoolkit, pas Node.
- GDScript typé au lieu de TypeScript ; gdlint et gdformat au lieu d'ESLint et Prettier.
- Tests par le lanceur maison `tests/lanceur.gd`, sans GUT ni gdUnit (interdits : dépendance téléchargée depuis GitHub).
- Prettier ne sert qu'au Markdown : `npx -y prettier@3.9.10 --check <fichiers .md>` avant de pousser.
- Les contrôles d'accessibilité et de bundle du contexte commun ne s'appliquent pas.

## Pièges déjà rencontrés

- Les sommes SHA-512 de Godot sont sur la release GitHub `godotengine/godot-builds`, pas sur downloads.godotengine.org.
- Le paquet gdtoolkit ne s'installe pas avec `pip` dans le Python du système (PEP 668) : utiliser le venv de `tools/install-gdtoolkit.sh`.
- Un nouveau `class_name` reste inconnu tant que `godot --headless --path . --import` n'a pas tourné : le lancer avant le premier test. Les avertissements de typage sont des erreurs : typer aussi les variables de boucle (`for i: int in …`) et ne rien inférer d'un `Variant`.
- `godot --headless --import` à froid plantait au hasard (« double free or corruption », code 134 ou 139, au réimport de `textes_salon.csv`) : course entre threads d'import, mesurée sur `ubuntu-latest` à 20 plantages sur 60 imports (28 sur 60 sans les textures, donc pas liée au lot 5), 0 sur 60 avec un seul cœur, 0 sur 300 avec `editor/import/use_multiple_threads=false` (réglage de `project.godot`, à ne pas retirer). Ni la glibc ni `MALLOC_ARENA_MAX` n'y changent rien. Pour mesurer un plantage rare : boucle d'imports sur des copies neuves (`git archive | tar -x`) dans un workflow temporaire, pas des essais isolés.
- Les noms d'enums des JSON sont comparés tels quels, accents compris (« perçant », « siège », « légère », « fortifiée ») ; toute autre graphie est refusée.
- Un test qui dépend d'une classe encore à venir va dans un fichier de test séparé, pour ne pas bloquer les autres.
- `.claude/` porte un `.gdignore` et est exclu de gdlint : les worktrees des agents y vivent.
- `.gdlintrc` est en YAML (`max-line-length: 100`), pas en `clé=valeur` : sinon gdlint plante.
- Le lanceur lance les tests au premier `process_frame`, arbre actif : `_ready`, RPC, `await` et `attendre_images(n)` fonctionnent. Une méthode `test_*` qui dépasse `delai_max` (10 s) échoue, et le moteur libère les nœuds qu'elle a ajoutés sous `arbre.root`. Toute erreur de script ou `push_error` la fait échouer ; `attendre_erreur(motif)` déclare une erreur voulue (Godot l'imprime quand même sur stderr).
- Tout fichier écrit par un test va sous `dossier_temporaire()` ; tout port réseau est tiré à l'exécution (d'autres agents lancent leurs tests en même temps).
- Godot 4.7.2 importe les CSV de traduction en parallèle, et chaque import inscrit son `.translation` dans l'arbre de l'éditeur sans verrou (`EditorFileSystem::update_files`, godot#125712, sans correctif) : l'import à froid mourait sur « double free or corruption », code 134 ou 139 (sur `ubuntu-latest` : 20 imports sur 60, mesurés par la PR 10 ; rarement en local). D'où `editor/import/use_multiple_threads=false` (0 sur 300 en CI, +3 s par import à froid), gardé par `test_configuration_projet`. Ne le retirer qu'après `tools/stress-import-csv.sh --threads` à 0 plantage sur un Godot plus récent. `textes_salon.csv` n'y est pour rien : c'est le premier libellé du groupe importé.
