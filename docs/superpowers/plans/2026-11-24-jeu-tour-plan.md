# Last Tower Standing — plan d’implémentation

> **Pour les agents d'exécution :** sous-skill requis : `superpowers:subagent-driven-development` (recommandé) ou `superpowers:executing-plans`. Une tâche = un agent. Le suivi se fait par les cases `- [ ]` en tête de tâche.

**Objectif :** livrer le jeu de tour multijoueur de la spécification (1 à 8 joueurs, serveur autoritaire, jouable seul, serveur dédié).

**Architecture :** simulation pure en données (`sim/`, `RefCounted`, 20 Hz, sans nœud ni réseau) ; un état « vue d'arène » sérialisable lu par le rendu (`visuels/`) et l'interface (`ui/`), identique en solo et en réseau ; `reseau/` (ENet) n'appelle que l'API publique de `sim/partie.gd`.

**Pile :** Godot 4.7.2 stable, GDScript typé, gdtoolkit 4 (gdlint, gdformat), lanceur de tests maison, GitHub Actions.

**Spec :** `docs/superpowers/specs/2026-11-24-jeu-tour-design.md` (à lire en entier par l'agent qui n'a pas le contexte ; chaque tâche cite ses §).

## Contraintes globales (valeurs de la spec)

- Godot **4.7.2**, GDScript typé ; avertissements `untyped_declaration`, `unsafe_method_access`, `unsafe_property_access` = **erreur** dans `project.godot`.
- Licences libres uniquement ; graphismes = primitives Godot (`BoxMesh`, `CylinderMesh`, `SphereMesh`, `CapsuleMesh`, `PrismMesh`, `TorusMesh`) + `StandardMaterial3D`, **uniquement** dans `visuels/apparence.gd`.
- Aucune dépendance téléchargée depuis GitHub (ni GUT ni gdUnit) ; interface en français via `i18n/*.csv` (colonne `fr`) ; aucun texte visible en dur dans le code.
- Chiffres d'équilibrage **uniquement** dans `data/*.json`, validés au chargement (message clair, pas de plantage plus loin).
- Simulation **20 Hz** (pas fixe 0,05 s), tableaux compacts pour les ennemis ; un `RandomNumberGenerator` par arène, graine reproductible.
- Réseau : ENet, UDP **7777** par défaut ; clients → intentions (fiables) ; serveur → état d'arène **15 Hz** (non fiable, quantifié) ; état global **2 Hz** (fiable) ; **< 50 Ko/s** par client à 300 ennemis.
- Contenu : **≥ 25 armes** (≥ 5 par type de dégâts, toutes raretés présentes dans chaque type), **≥ 30 améliorations**, ~**8 familles** d'ennemis + convoi + boss ; tout est original (noms, textes, chiffres), rien de la map d'origine.
- Mécaniques chiffrées de la spec à respecter : 8 emplacements d'armes, vente à 50 %, 4 offres, or de départ 500, revenu toutes les 10 s, préparation 30 s, manches de 30 s, boss à la manche 31, rayon d'apparition 1300, intervalle 2,0 s − 0,08 s/manche (plancher 0,1 s), portées 300/600/900/1200, rebond 4 à 8 cibles, gel ≤ 3 s, critique par paliers de 5 %, réduction d'armure `0,05·a/(1+0,05·a)`, efficacité ×2 (tranchant/moyenne, perçant/légère, magique/lourde, siège/fortifiée) et ×1 ailleurs.

## Règles pour chaque agent

1. GDScript **typé** partout (variables, paramètres, retours) ; `class_name` en PascalCase, fichiers en snake_case, identifiants de code en français sans accent ou anglais, **textes visibles en français** avec espaces insécables avant `: ; ? !` et dans « ».
2. `gdlint` et `gdformat --check` verts sur tout ce que la tâche touche ; **`tools/verifier.sh` vert avant de rendre la tâche** (avant le lot 0 terminé : lancer à la main les commandes de la tâche).
3. **Tests d'abord** (TDD) : écrire le test, le voir échouer pour la bonne raison, implémenter, le voir passer. Tests ciblés : `T --filtre test_<fichier>` avec `T = godot --headless --path . --script res://tests/lanceur.gd --`.
4. **Ne toucher qu'aux fichiers de sa tâche** (liste « Fichiers »). Une interface manquante ou fausse chez un voisin : le signaler dans le rapport, ne pas la corriger.
5. Un test décrit **ce que le joueur doit obtenir**, pas ce que fait le code ; il ne fige jamais un comportement douteux. Une énumération (« chaque famille », « chaque type », « 1 à 8 joueurs ») se teste **en entier, en boucle**. Données de test : les plus longs libellés réels.
6. Commits découpés par intention, message **en français à l'impératif** (« Ajoute… », « Corrige… »), première ligne ≤ 72 caractères, terminés par deux lignes : la ligne `Co-Authored-By:` **de ton propre modèle**, telle que ton environnement te la donne (un agent Haiku signe Haiku, un agent Sonnet signe Sonnet), puis exactement :
   ```
   Claude-Session: https://claude.ai/code/session_01FhwUoeWipkh43S9RGFfnwA
   ```
7. Jamais de garde-fou désactivé (règle gdlint coupée, test ignoré, `--no-verify`). Une graine fixe dans tout test qui tire au hasard.
8. **Rapport final** : fichiers créés, vérifications réellement lancées (sortie résumée), écarts aux interfaces du plan, puis **rétro en 3 lignes** (ce qui a coûté du temps, ce qui a marché, ce qu'il faudrait écrire dans le contexte).

## Points de vigilance (« Review Focus »), chacun pinglé par un test dans la tâche indiquée

1. Zéro joueur, ou tous déconnectés pendant la préparation : la partie se termine proprement, sans erreur (1.10, 3.3).
2. Intention hors phase, après la mort, indice hors bornes, paquet tronqué ou en rafale : refus propre, aucun plantage (1.9, 3.1, 3.3).
3. JSON absent, id dupliqué, rareté ou statut inconnu, référence orpheline : message clair nommant fichier et champ (1.1, 1.5).
4. Client coupé en pleine partie, protocole ou données de versions différentes : éliminé proprement / refusé avec un motif (3.3, 3.4).
5. Plus de 1 000 ennemis dans une arène (plancher d'intervalle 0,1 s) : le pas reste sous 5 ms par arène en moyenne, aucune fuite de tableau (1.7, 1.9).

## Structure finale des fichiers (une tâche propriétaire par fichier, par lot)

`project.godot`, `.gdlintrc`, `.gitignore`, `CREDITS.md`, `CLAUDE.md` · `data/*.json` · `sim/*.gd` · `app/*.gd` (sources de vue, réglages, arguments, scènes pilotes) · `visuels/*.gd` · `ui/*.gd` · `scenes/*.tscn` · `i18n/*.csv` · `reseau/*.gd` · `tests/` · `tools/` · `.github/workflows/ci.yml` · `.claude/`.

## Interfaces figées (créées par T1.1, T1.4, T2.1, citées partout)

### Énumérations et constantes — `sim/types.gd`, `class_name Types extends RefCounted`

```gdscript
enum TypeDegats { TRANCHANT, PERCANT, MAGIQUE, SIEGE, CHAOS }
enum Armure { LEGERE, MOYENNE, LOURDE, FORTIFIEE, AUCUNE, BOSS }
enum Rarete { COMMUNE, PEU_COMMUNE, RARE, EPIQUE }
enum Ciblage { PLUS_PROCHE, PLUS_FORT, PLUS_FAIBLE }
enum Phase { PREPARATION, MANCHE, BOSS, VICTOIRE, DEFAITE }
enum Genre { ARME, AMELIORATION }
enum Resultat { OK, OR_INSUFFISANT, EMPLACEMENTS_PLEINS, OFFRE_INVALIDE, DEJA_ACHETE, MAUVAISE_PHASE, ARENE_MORTE, INDICE_INVALIDE, NON_DISPONIBLE }
const STATUT_GELE := 1; const STATUT_RALENTI := 2; const STATUT_EMPOISONNE := 4; const STATUT_BRULE := 8; const STATUT_ETOURDI := 16
static func type_depuis_nom(nom: String) -> int  # « tranchant » → TRANCHANT ; -1 si inconnu (idem armure_depuis_nom, rarete_depuis_nom, ciblage_depuis_nom)
```

### Vue d'arène — `sim/vue_arene.gd` (T1.4) : seul état lu par `visuels/` et `ui/`

Unités : distances en **unités de jeu** (plan, tour en `(0,0)`, `Vector2(x, z)`), temps en **secondes**, PV en points, ratios 0..1. Rendu : `1 unité = 0,02 m` (`Apparence.ECHELLE`).

```gdscript
class_name VueArene extends RefCounted
var tick: int                       # pas de simulation (20 Hz), croît de 1 par pas
var manche: int                     # 0 pendant la préparation
var phase: int                      # Types.Phase
var temps_restant: float            # s restantes dans la phase (0 pour BOSS/VICTOIRE/DEFAITE)
var prochaine_famille: int          # index dans Donnees.familles, -1 si aucune (convoi : index_convoi)
var prochaine_armure: int           # Types.Armure de la prochaine famille
var sans_fin: bool
var tour_pv: float; var tour_pv_max: float; var tour_armure: float
var argent: int; var revenu: int    # revenu = or par période de 10 s (hors prime)
var revenu_dans: float              # s avant le prochain versement
var cout_relance: int; var relances_gratuites: int
var offres: Array[Dictionary]       # 4 entrées {id: String, genre: int, rarete: int, prix: int, vendu: bool}
var armes: Array[Dictionary]        # ≤ 8 entrées {id: String, recharge_ratio: float}
var ameliorations: Dictionary       # id (String) → nombre (int)
var marche_noir_ouvert: bool        # vrai si un choix de marché noir est en attente
var ennemis_id: PackedInt32Array    # identifiant stable (pour l'interpolation)
var ennemis_pos: PackedVector2Array
var ennemis_famille: PackedByteArray
var ennemis_pv: PackedByteArray     # ratio × 255
var ennemis_statuts: PackedByteArray  # bits Types.STATUT_*
var evenements: Array[Dictionary]   # depuis la vue précédente : {k: "tir"|"impact"|"mort", t: int (tick), de: Vector2, vers: Vector2, type_degats: int, rayon: float}
# 2026-11-25 (T5.3b) : tir et impact portent aussi, facultatifs, `genre: int` (index dans `VueArene.GENRES_ARME`, 0 = aucun) et `statut: int` (index dans `VueArene.STATUTS_ARME`, 0 = aucun) ; une mort n'en a pas. Protocole version 3 : 12 octets par événement.
var eliminations: int; var degats_infliges: float; var manche_max: int
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> VueArene   # null si champ manquant ou de mauvais type
```

`sim/vue_globale.gd` : `class_name VueGlobale` — `joueurs: Array[Dictionary]` `{id: int, nom: String, manche: int, eliminations: int, degats: float, revenu: int, vivant: bool, victorieux: bool}`, `temps_ecoule: float`, `en_cours: bool`, `termine: bool`, `classement: Array[int]` (ids, vide tant que non terminé), `dernier_rempart: int` (id, −1 sinon) ; mêmes `to_dict()` / `from_dict()`.

### Source de vue — `app/source_vue.gd` (T2.1) : ce que `ui/` et `visuels/` consomment, en solo comme en réseau

```gdscript
class_name SourceVue extends Node
signal vue_arene_recue(vue: VueArene)
signal vue_globale_recue(vue: VueGlobale)
signal resultat_intention(genre: String, code: int)    # Types.Resultat
signal connexion_perdue(motif: String)
func id_local() -> int
func cible_observee() -> int                           # id du joueur dont l'arène est affichée
func acheter(index_offre: int) -> void
func relancer() -> void
func vendre(index_arme: int) -> void
func choisir_marche_noir(id_amelioration: String) -> void
func observer(id_joueur: int) -> void                  # refusé si le joueur local est vivant
func continuer_sans_fin() -> void
func quitter_partie() -> void
```

Implémentations : `SourceLocale` (solo, `Partie` en processus, T2.1) et `Client` (réseau, T3.4).

### Schémas de données (`data/`, validés par `Donnees`, exemples valides)

- `partie.json` : `{"pas_s":0.05,"preparation_s":30,"manche_s":30,"manche_boss":31,"rayon_spawn":1300,"spawn_intervalle_depart":2.0,"spawn_baisse_par_manche":0.08,"spawn_plancher":0.1,"tour":{"pv":1000,"armure":0,"regen":0,"rayon":60},"emplacements_armes":8,"nb_offres":4,"vente_ratio":0.5,"gel_max_s":3.0,"givre":{"cumuls_max":8,"ralentissement_par_cumul":0.08,"plafond":0.6},"critique":{"palier":0.05,"puissance_base":2.0,"coef_exces":1.0},"esquive_k":1.0,"vitesses_partie":[1.0,0.66,0.5],"reseau":{"hz_arene":15,"hz_global":2},"convoi":{"probabilite":0.08,"manche_min":4}}`
- `economie.json` : `{"or_depart":500,"revenu_periode_s":10,"revenu_base":[{"manche":1,"valeur":20},{"manche":6,"valeur":30}],"prime_mult":[{"manche":1,"valeur":1.0},{"manche":10,"valeur":1.5}]}` — paliers triés par `manche` croissante, le premier à 1 ; la valeur s'applique dès cette manche.
- `difficulte.json` : `{"paliers":[{"manche":1,"pv":1.0,"degats":1.0,"vitesse":1.0,"resistance_controle":1.0}],"accelerations":[{"temps_s":300,"pv":1.3,"degats":1.2,"vitesse":1.05},{"temps_s":600,…},{"temps_s":900,…}],"apres_table":{"pv":1.08,"degats":1.06,"vitesse":1.01,"resistance_controle":0.97},"resistance_plancher":0.1}`
- `efficacite.json` : `{"lignes":["tranchant","perçant","magique","siège","chaos"],"colonnes":["légère","moyenne","lourde","fortifiée","aucune","boss"],"valeurs":[[1,2,1,1,1,1],…]}`
- `boutique.json` : `{"poids":[{"manche":1,"commune":70,"peu_commune":25,"rare":5,"epique":0}],"relance":{"cout_depart":50,"increment":25},"marche_noir":{"raretes_max":"rare"}}` (poids par paliers de manche, comme l'économie).
- `ennemis.json` : `{"familles":[{"id":"…","nom":"…","armure":"légère","volant":false,"pv":40,"vitesse":60,"degats":4,"portee_attaque":40,"cadence_attaque":1.0,"prime":2}],"convoi":{"id":"…","nom":"…","pv":400,"vitesse":45,"prime":120},"boss":{"id":"…","nom":"…","pv":20000,"vitesse":35,"degats":60,"portee_attaque":80,"cadence_attaque":1.5}}` — `portee_attaque ≤ 60` = corps à corps (épines applicables), sinon à distance (l'ennemi s'arrête à cette portée).
- `armes.json` : liste d'`{"id":"…","nom":"…","description":"…","rarete":"rare","prix":900,"type_degats":"magique","degats":42.0,"recharge":1.2,"portee":600,"ciblage":"plus_proche","effets":[{"kind":"rebond","cibles":5,"portee_saut":250,"decroissance":0.9}],"statuts":[{"kind":"givre"}]}`. `kind` d'effet : `cible_unique` · `zone{rayon}` · `rebond{cibles 4..8,portee_saut,decroissance}` · `onde{rayon_max,vitesse}` · `barrage{projectiles,dispersion_deg,rayon}` · `mine{rayon,max_actives}` · `piege{rayon,max_actives}` · `aura{rayon,periode}`. `kind` de statut : `poison{total_ratio,duree}` · `brulure{ratio,duree}` · `givre{}` · `etourdissement{duree}` · `vol_de_vie{ratio,a_la_mort}`. `portee` ∈ {300,600,900,1200}.
- `ameliorations.json` : liste d'`{"id","nom","description","rarete","prix","effets":[{"stat":"degats_type","type_degats":"magique","valeur":0.1,"categorie":"A"}]}`. `stat` ∈ `degats_type` (ou `degats_global`, `categorie` A/B/C : additif dans une catégorie, **multiplicatif entre catégories**), `pv_max`, `regen`, `armure`, `esquive`, `epines`, `critique_chance`, `cadence`, `tirs_multiples`, `eclaboussure`, `focalisation`, `vol_de_vie_coup`, `vol_de_vie_mort`, `revenu_fixe`, `revenu_croissant`, `revenu_mult`, `prime_mult`, `bonus_elim{tous_les:int,or:int}`, `relance_gratuite`, `marche_noir`.

---

# Lot 0 — Outillage

**Parallélisme :** T0.1 d'abord ; puis T0.2, T0.3, T0.4, T0.5 en parallèle (fichiers disjoints).

### Task 0.1 : Squelette du projet — `haiku`

- [x] **Objectif :** projet Godot vide qui s'ouvre en `--headless`, avec les arborescences et les réglages de typage stricts.
- **Fichiers (crée) :** `project.godot` (nom, `run/main_scene` provisoire vide, `config/features=["4.7"]`, avertissements typés en erreur, `[internationalization] locale/translations` vide, `[rendering]` Forward+), `.gdlintrc` (limite de ligne 100), `.gitignore` (`.godot/`, `*.translation`, `export/`), `CREDITS.md` (en-tête + tableau vide source/auteur/licence), `sim/.gitkeep`, `data/.gitkeep`, `app/.gitkeep`, `visuels/.gitkeep`, `ui/.gitkeep`, `scenes/.gitkeep`, `i18n/.gitkeep`, `reseau/.gitkeep`, `tests/unitaires/.gitkeep`.
- **Lire :** spec §2, §4, §7.
- **Interfaces :** aucune.
- **Tests :** aucun (outillage).
- **Vérif :** `godot --headless --path . --import` sort avec le code 0 et sans « ERROR ». **Terminé :** idem + `git status` propre après commit.

### Task 0.2 : Lanceur de tests maison — `sonnet`

- [x] **Objectif :** exécuter `tests/**/test_*.gd` sans dépendance externe.
- **Fichiers (crée) :** `tests/lanceur.gd` (fin : `extends SceneTree`, lit les arguments, appelle le moteur, `quit(code)`), `tests/moteur.gd`, `tests/cas_de_test.gd`, `tests/unitaires/test_moteur.gd`, `tests/unitaires/test_cas_de_test.gd`, `tests/controle/test_echec_volontaire.gd`.
- **Lire :** spec §7 ; doc Godot `SceneTree`, `OS.get_cmdline_user_args`, `DirAccess`.
- **Contrat du lanceur :** `godot --headless --path . --script res://tests/lanceur.gd -- [--filtre motif] [--dossier res://tests/unitaires] [--controle]`.
  - Découvre récursivement les `test_*.gd` du dossier (défaut `res://tests`), **hors** `res://tests/controle/`, triés par chemin ; `--filtre` ne garde que les fichiers ou méthodes dont le nom contient le motif.
  - Charge chaque script, l'instancie, exige qu'il étende `CasDeTest` (sinon : échec du fichier), appelle `avant_chaque()`, chaque méthode dont le nom commence par `test_` (ordre alphabétique), puis `apres_chaque()`. Une instance **neuve par méthode**.
  - Une assertion qui échoue **n'interrompt pas** la méthode : elle enregistre l'échec. Une méthode **sans aucune assertion** est un échec (« aucune assertion »). Un script qui ne se charge pas (erreur d'analyse) est un échec du fichier, pas un plantage.
  - Sortie : une ligne `OK`/`ECHEC res://chemin.gd::test_nom — message (attendu … reçu …)` par échec, puis `N tests, M échecs, K assertions`. Code de sortie **0** si M = 0, sinon **1**.
  - `--controle` : ne lance **que** `res://tests/controle/` et sort **0 si et seulement si chaque test y a échoué** (preuve que le lanceur détecte un échec), sinon 1.
- **Interfaces :**

```gdscript
class_name CasDeTest extends RefCounted
var arbre: SceneTree                 # fourni par le lanceur (pour instancier des nœuds)
var echecs: Array[String]; var nb_assertions: int
func avant_chaque() -> void; func apres_chaque() -> void
func verifier(condition: bool, message: String = "") -> void
func verifier_faux(condition: bool, message: String = "") -> void
func verifier_egal(recu: Variant, attendu: Variant, message: String = "") -> void   # égalité de valeur, tableaux et dictionnaires compris
func verifier_different(recu: Variant, interdit: Variant, message: String = "") -> void
func verifier_proche(recu: float, attendu: float, tolerance: float = 0.0001, message: String = "") -> void
func verifier_nul(valeur: Variant, message: String = "") -> void; func verifier_non_nul(valeur: Variant, message: String = "") -> void
func verifier_contient(collection: Variant, element: Variant, message: String = "") -> void
class_name MoteurDeTests extends RefCounted
func decouvrir(dossier: String, filtre: String, controle: bool) -> PackedStringArray
func executer(chemins: PackedStringArray, filtre: String, arbre: SceneTree) -> Dictionary   # {tests:int, echecs:int, assertions:int, lignes:PackedStringArray}
```

- **Tests :** (dans `test_cas_de_test.gd`, instancier une sous-classe interne et lire `echecs`) chaque assertion réussit sur une valeur juste et échoue sur une fausse ; `verifier_egal` sur tableaux imbriqués, `null`, `int` contre `float` (`1` ≠ `1.0` : documenter et tester) ; `verifier_proche` aux bornes exactes de la tolérance ; message vide accepté. (Dans `test_moteur.gd`) `decouvrir` exclut `controle/`, trie, respecte `--filtre` ; un test sans assertion est rapporté en échec ; un fichier non chargeable est un échec et n'arrête pas les autres ; une classe qui n'étend pas `CasDeTest` est rejetée ; code de sortie 1 sur un échec, 0 sinon. **Contrôle :** `tests/controle/test_echec_volontaire.gd` contient `test_echec_assertion` (assertion fausse) et `test_sans_assertion` (corps vide).
- **Vérif :** `T` (suite normale : code 0, aucun test du dossier `controle/`) **et** `T --controle` (code 0). **Terminé :** les deux commandes, le code de sortie lu avec `echo $?`, et la preuve qu'un `verifier(false)` temporaire dans `test_moteur.gd` donne le code 1 (à annuler avant de commiter).

### Task 0.3 : `tools/verifier.sh` et installation — `haiku`

- [x] **Objectif :** une seule commande locale qui fait exactement ce que fait la CI.
- **Fichiers (crée) :** `tools/verifier.sh`, `tools/install-godot.sh`, `tools/install-gdtoolkit.sh`.
- **Lire :** spec §7 ; `tests/lanceur.gd` (contrat ci-dessus).
- **Interfaces :** `tools/verifier.sh [--etape import|lint|format|tests|controle|integration]` ; sans argument, toutes les étapes dans cet ordre, **arrêt à la première rouge**, code de sortie de l'étape fautive. Étapes : `godot --headless --path . --import` ; `gdlint .` ; `gdformat --check sim app visuels ui reseau tests tools` (dossiers existants seulement) ; `T` ; `T --controle` ; `tools/integration.sh` **si le fichier existe** (sinon « étape absente, ignorée » affiché clairement). `install-godot.sh` : saute si `godot --version` commence par `4.7.2`, sinon télécharge la version headless Linux x86_64 depuis les sources officielles de Godot, vérifie la somme SHA-512 publiée, installe dans `/usr/local/bin/godot`. `install-gdtoolkit.sh` : `pip install "gdtoolkit==4.*"`.
- **Tests :** `bash -n tools/*.sh` ; `tools/verifier.sh --etape controle` rend 0 après la 0.2 ; une étape inconnue rend un code ≠ 0 avec message.
- **Vérif :** `bash -n tools/*.sh && tools/verifier.sh` (vert une fois 0.1 et 0.2 fusionnés). **Terminé :** sortie complète collée dans le rapport.

### Task 0.4 : CI GitHub Actions — `haiku`

- [x] **Objectif :** la CI rejoue `tools/verifier.sh`, étape par étape.
- **Fichiers (crée) :** `.github/workflows/ci.yml`.
- **Lire :** `tools/verifier.sh`, spec §7.
- **Interfaces :** déclencheurs `pull_request` et `push` sur `main` ; un job `qualite` (Ubuntu) : checkout → `tools/install-godot.sh` → `tools/install-gdtoolkit.sh` → une étape nommée par `--etape` (import, lint, format, tests unitaires, contrôle du lanceur, intégration). Jamais `continue-on-error`. Pas d'export (second temps).
- **Tests :** validation YAML (`python -c "import yaml…"`) ; les noms d'étapes correspondent aux `--etape` de `verifier.sh` (grep).
- **Vérif :** YAML valide ; relecture croisée avec `verifier.sh`. **Terminé :** idem.

### Task 0.5 : Hook de session et `CLAUDE.md` du projet — `haiku`

- [x] **Objectif :** une session cloud neuve est prête sans bricolage.
- **Fichiers (crée) :** `.claude/hooks/session-start.sh`, `.claude/settings.json` (déclare le hook `SessionStart`), `CLAUDE.md` (≤ 80 lignes : ce qu'est le projet, structure §4, règles de dépendance `sim/` ← `reseau/`, `visuels/`, `ui/`, commande `tools/verifier.sh`, règles pour les agents ci-dessus résumées).
- **Lire :** spec entière ; `tools/install-godot.sh`.
- **Interfaces :** le hook lance `tools/install-godot.sh` puis `tools/install-gdtoolkit.sh` puis `godot --headless --path . --import`, est idempotent, n'échoue jamais bruyamment hors-ligne (message et code 0).
- **Tests :** `bash -n` ; deux exécutions successives donnent le même résultat ; `settings.json` est du JSON valide.
- **Vérif :** `bash -n .claude/hooks/session-start.sh && python -m json.tool .claude/settings.json`. **Terminé :** idem.

---

# Lot 1 — Données et simulation pure (aucun nœud, aucun réseau)

**Parallélisme :** vague A : T1.1 seule. Vague B (en parallèle) : T1.2, T1.3, T1.4, T1.5, T1.7. Vague C (en parallèle) : T1.6 (après 1.1, 1.3, 1.5), T1.8 (après 1.2, 1.7). Vague D : T1.9. Vague E : T1.10. **Chaque test de ce lot tourne sans nœud de scène** (pas d'`add_child`).

### Task 1.1 : Types, chargement et validation des données — `sonnet`

- [x] **Objectif :** `Types`, `StatsTour`, `Donnees` ; les fichiers `data/partie.json`, `economie.json`, `difficulte.json`, `efficacite.json`, `boutique.json` aux valeurs de départ des schémas ci-dessus.
- **Fichiers (crée) :** `sim/types.gd`, `sim/stats_tour.gd`, `sim/donnees.gd`, `data/partie.json`, `data/economie.json`, `data/difficulte.json`, `data/efficacite.json`, `data/boutique.json`, `tests/unitaires/test_donnees.gd`.
- **Lire :** spec §2, §5.2 à §5.5 ; la section « Schémas de données » de ce plan.
- **Interfaces :**

```gdscript
class_name StatsTour extends RefCounted   # agrégat des améliorations, toutes à leur valeur neutre par défaut
var degats_type: Array[float]             # 5 entrées, multiplicateur final par Types.TypeDegats (1.0 neutre)
var degats_global: float = 1.0; var pv_max_bonus: float; var regen: float; var armure: float; var esquive: float
var epines: float; var critique_chance: float; var cadence: float; var tirs_multiples: int
var eclaboussure: float; var focalisation: float; var vol_de_vie_coup: float; var vol_de_vie_mort: float
var revenu_fixe: int; var revenu_croissant: float; var revenu_mult: float = 1.0; var prime_mult: float = 1.0
var bonus_elim_tous_les: int; var bonus_elim_or: int; var relances_gratuites: int; var marche_noir: int

class_name Donnees extends RefCounted
var partie: Dictionary; var economie: Dictionary; var difficulte: Dictionary; var boutique: Dictionary
var efficacite: Array                     # 5×6 de float, ordre des enums de Types
var armes: Dictionary; var ameliorations: Dictionary   # id → dictionnaire normalisé (enums déjà convertis en int)
var familles: Array[Dictionary]; var convoi: Dictionary; var boss: Dictionary
var ids_catalogue: PackedStringArray      # tous les ids armes + améliorations triés (index réseau)
var empreinte: int                        # hash stable du contenu des fichiers (poignée de main réseau)
static func charger(dossier: String = "res://data") -> Donnees          # null si invalide ; erreurs via push_error
static func valider(brut: Dictionary) -> PackedStringArray               # brut: nom de fichier → contenu ; erreurs « fichier: chemin.du.champ: raison »
static func depuis_brut(brut: Dictionary) -> Donnees                     # null si valider() ≠ []
func palier(table: Array, manche: int, cle: String) -> float             # dernier palier dont .manche ≤ manche
```

`charger` accepte l'absence d'`armes.json`, `ameliorations.json`, `ennemis.json` **uniquement** si le dossier est un dossier de test (liste vide) ; sur `res://data` leur absence est une erreur.

- **Tests :** données réelles valides ; fichier absent, JSON malformé, champ manquant, mauvais type, `rarete` inconnue, `kind` inconnu, id dupliqué (armes et améliorations dans le même espace), `portee` hors {300,600,900,1200}, `cibles` de rebond hors 4..8, palier de manche non trié ou ne commençant pas à 1, poids de rareté tous nuls, ratio négatif : **chaque cas** produit un message contenant le nom du fichier et le champ (boucle sur une table de mutations) ; `palier()` aux bornes (manche 1, manche entre deux paliers, manche > dernier) ; la matrice d'efficacité de la spec **entière** (30 cases, en boucle) ; deux chargements donnent la même `empreinte`, une valeur modifiée change l'empreinte ; `Types.*_depuis_nom` pour chaque nom FR avec accents.
- **Vérif :** `T --filtre test_donnees`. **Terminé :** vert, `Donnees.charger()` renvoie une instance sur les cinq fichiers de cette tâche.

### Task 1.2 : Formules de combat — `sonnet`

- [x] **Objectif :** toutes les formules pures de §5.4, aucune dépendance aux arènes.
- **Fichiers (crée) :** `sim/combat.gd`, `tests/unitaires/test_combat.gd`.
- **Lire :** spec §5.4 ; `sim/types.gd`, `sim/donnees.gd` (champs `efficacite`, `partie`).
- **Interfaces :** `class_name Combat extends RefCounted`, toutes `static` :

```gdscript
func efficacite(table: Array, type_degats: int, armure: int) -> float
func reduction_armure(armure: float) -> float                     # 0,05·a / (1 + 0,05·a) ; armure < 0 → 0
func degats_subis(degats: float, armure: float) -> float
func chance_critique_effective(chance: float, palier: float) -> float   # arrondie au palier inférieur, plafonnée à 1,0
func puissance_critique(chance: float, base: float, coef_exces: float) -> float   # base + coef × max(0, chance − 1)
func chance_esquive(points: float, k: float) -> float             # points / (points + k), rendement décroissant
func duree_etourdissement(base: float, resistance: float) -> float
func ralentissement(cumuls: int, par_cumul: float, plafond: float) -> float   # min(cumuls × par_cumul, plafond)
func duree_gel(base: float, resistance: float, gel_max: float) -> float        # min(base × résistance, gel_max)
func repartir_dot(total: float, duree: float, dt: float) -> float # dégâts d'un pas : total × dt / durée
func soin_vol_de_vie(degats: float, ratio: float) -> float
```

- **Tests :** les 30 couples type/armure en boucle (×2 aux quatre cases de la spec, ×1 ailleurs, **aucun malus**, chaos ×1 partout, BOSS et AUCUNE ×1) ; réduction d'armure : 0 → 0, 20 → 0,5, très grande → < 1 sans jamais l'atteindre, négative → 0 ; critique : 0 %, 4 %, 5 %, 99 %, 100 %, 150 %, 300 % (excédent), valeur exactement sur un palier malgré l'arrondi flottant (0,15) ; esquive : 0 → 0, croissante, < 1 pour toute valeur, rendement décroissant (2e point < 1er) ; étourdissement : résistance 1,0 / 0,5 / plancher 0,1 / 0 ; givre : 0 cumul, cumul max, plafond ; gel jamais > 3 s même base 100 ; DoT : la somme des pas = total (tolérance), durée 0 sans division par zéro.
- **Vérif :** `T --filtre test_combat`. **Terminé :** vert.

### Task 1.3 : Économie — `haiku`

- [x] **Objectif :** or, revenu périodique, primes, bonus d'éliminations.
- **Fichiers (crée) :** `sim/economie.gd`, `tests/unitaires/test_economie.gd`.
- **Lire :** spec §5.2 ; `sim/donnees.gd` (`palier`, `economie`), `sim/stats_tour.gd`.
- **Interfaces :**

```gdscript
class_name Economie extends RefCounted
var argent: int
func _init(donnees: Donnees) -> void                               # argent = or_depart
func revenu_par_periode(manche: int, stats: StatsTour, temps_ecoule: float) -> int   # base(manche) + (revenu_fixe + revenu_croissant × temps_ecoule/60) × revenu_mult
func avancer(dt: float, manche: int, stats: StatsTour, temps_ecoule: float) -> int   # verse chaque période de 10 s écoulée ; renvoie le montant versé ce pas
func temps_avant_versement() -> float
func prime(famille_prime: int, manche: int, stats: StatsTour) -> int           # arrondi à l'entier le plus proche, ≥ 0
func enregistrer_elimination(stats: StatsTour) -> int              # renvoie l'or du bonus « tous les n » (0 le plus souvent)
func peut_payer(montant: int) -> bool
func payer(montant: int) -> bool                                   # faux et aucun effet si insuffisant ou montant < 0
func gagner(montant: int) -> void                                  # ignore les montants ≤ 0
```

- **Tests :** or de départ 500 ; `payer` exact (or = prix → 0), insuffisant (prix = or + 1 : refus, or inchangé), montant 0, négatif ; versement à 10,0 s pile, à 9,95 s non, un grand `dt` (35 s) verse trois fois ; revenu de base aux paliers de manche (1, 5, 6, 40) ; revenu fixe + croissant, avec `revenu_mult` (seule la partie achetée est multipliée, pas la base) ; prime avec multiplicateur à plusieurs paliers et `prime_mult` des objets ; bonus tous les n (n = 0 → jamais, n = 3 : 3e, 6e) ; `dt` négatif ignoré.
- **Vérif :** `T --filtre test_economie`. **Terminé :** vert.

### Task 1.4 : Vue d'arène et vue globale sérialisables — `haiku`

- [x] **Objectif :** les deux structures figées de ce plan, avec aller-retour dictionnaire.
- **Fichiers (crée) :** `sim/vue_arene.gd`, `sim/vue_globale.gd`, `tests/unitaires/test_vues.gd`.
- **Lire :** la section « Vue d'arène » de ce plan.
- **Interfaces :** exactement celles de la section « Interfaces figées » (champs, types, `to_dict`, `from_dict`) ; `from_dict` renvoie `null` si une clé manque, si un type est faux ou si les tableaux d'ennemis n'ont pas la même longueur ; les `Packed*Array` sont copiés (une vue ne partage pas de mémoire avec la simulation).
- **Tests :** aller-retour exact d'une vue remplie (tous les champs, 0 ennemi, 300 ennemis, 8 armes, 4 offres dont une vendue, événements des trois genres) ; dictionnaire sans clé, avec type erroné, avec tableaux de longueurs différentes → `null` sans exception ; une vue copiée n'est pas modifiée par la source ; `VueGlobale` avec 0 et 8 joueurs.
- **Vérif :** `T --filtre test_vues`. **Terminé :** vert.

### Task 1.5 : Contenu et équilibrage (armes, améliorations, familles) — `sonnet`

- [x] **Objectif :** le contenu de la version 1, **entièrement original** (noms et textes en français inventés, chiffres propres ; rien de la map d'origine), plus les tests du §5.6.
- **Fichiers (crée) :** `data/armes.json`, `data/ameliorations.json`, `data/ennemis.json`, `sim/equilibrage.gd`, `tests/unitaires/test_contenu.gd`.
- **Lire :** spec §5.3 à §5.6 ; schémas de données ; `sim/donnees.gd`, `sim/types.gd`.
- **Contenu exigé :** ≥ 25 armes (≥ 5 par type de dégâts, **les quatre raretés présentes dans chaque type**, les sept `kind` d'effet tous représentés, les cinq `kind` de statut tous représentés, portées 300/600/900/1200 toutes utilisées) ; ≥ 30 améliorations (chaque `stat` du schéma utilisée au moins une fois, y compris `marche_noir` ; les trois catégories A/B/C) ; 8 familles (au moins une par armure légère, moyenne, lourde, fortifiée ; au moins une volante ; au moins une à distance ; PV, vitesse et portée tous différents), un convoi sans dégâts, un boss à armure `boss`. Textes courts (≤ 90 caractères), typographie française soignée.
- **Interfaces :**

```gdscript
class_name Equilibrage extends RefCounted
static func tirs_par_seconde(arme: Dictionary) -> float            # 1 / recharge
static func cibles_estimees(arme: Dictionary) -> float             # cible_unique 1 ; zone 3 ; rebond = cibles × 0,6 ; onde 4 ; barrage = projectiles × 0,5 ; mine/piège 2 ; aura 3
static func dps_estime(arme: Dictionary) -> float                  # degats × tirs/s × cibles_estimees
static func rendement(arme: Dictionary) -> float                   # dps_estime / prix
```

- **Tests :** (sur les données réelles) comptages ci-dessus **en boucle** sur chaque type, chaque rareté, chaque `kind`, chaque `stat` ; ids uniques et en snake_case ; noms uniques ; aucune description vide ; **équilibrage** : par type de dégâts, le rendement moyen par rareté croît strictement commune < peu commune < rare < épique ; aucune arme n'a un rendement > 4× ou < 1/4 de la médiane de son type ; **atteignabilité des données** : chaque arme et chaque amélioration a une rareté dont le poids est > 0 à au moins une manche de 1 à 31 ; `Equilibrage` sur cas limites (recharge minimale, prix 1). Les tests de tirage effectif sont dans T1.6.
- **Vérif :** `T --filtre test_contenu` ; `Donnees.charger()` doit renvoyer une instance. **Terminé :** vert et les chiffres relus pour ne rien reprendre de l'original.

### Task 1.6 : Inventaire et boutique — `sonnet`

- [x] **Objectif :** 8 emplacements, agrégation des améliorations en `StatsTour`, offres par rareté, achat, relance, vente, marché noir.
- **Fichiers (crée) :** `sim/inventaire.gd`, `sim/boutique.gd`, `tests/unitaires/test_inventaire.gd`, `tests/unitaires/test_boutique.gd`.
- **Lire :** spec §5.3, §5.4 (cumul des améliorations) ; `sim/donnees.gd`, `sim/economie.gd`, `sim/stats_tour.gd`, `data/boutique.json`.
- **Interfaces :**

```gdscript
class_name Inventaire extends RefCounted
var armes: Array[String]                                           # ids, ≤ emplacements_armes
var ameliorations: Dictionary                                      # id → nombre
func _init(donnees: Donnees) -> void
func ajouter(id: String) -> int                                    # Types.Resultat ; EMPLACEMENTS_PLEINS pour une 9e arme ; une amélioration n'occupe pas d'emplacement
func retirer_arme(index: int) -> String                            # "" si indice invalide
func stats() -> StatsTour                                          # dégâts d'un type = Π sur les catégories (1 + Σ valeurs de la catégorie), `degats_global` idem ; autres stats additives
func prix_vente(index: int) -> int                                 # floor(prix × 0,5)

class_name Boutique extends RefCounted
var offres: Array[Dictionary]                                      # {id, genre, rarete, prix, vendu}
var cout_relance: int
func _init(donnees: Donnees, rng: RandomNumberGenerator) -> void
func nouvelle_manche(manche: int, relances_gratuites: int) -> void # 4 nouvelles offres, coût de relance remis au départ
func tirer(manche: int) -> void                                    # remplace les 4 offres (vendues ou non) par un nouveau tirage
func acheter(index: int, economie: Economie, inventaire: Inventaire) -> int
func relancer(economie: Economie, relances_gratuites: int) -> Array  # [Types.Resultat, relances_gratuites_restantes:int]
func vendre(index_arme: int, economie: Economie, inventaire: Inventaire) -> int
func choix_marche_noir(donnees: Donnees) -> PackedStringArray      # ids des améliorations de rareté ≤ raretes_max, triés
func acheter_marche_noir(id: String, economie: Economie, inventaire: Inventaire) -> int   # consomme un jeton `marche_noir` obtenu en achetant l'objet du même nom
```

Tirage : choisir la rareté selon les poids de la manche (`Donnees.palier`), puis un objet **uniforme** de cette rareté parmi armes + améliorations ; une rareté sans objet est retirée du tirage ; jamais deux fois le même id dans les 4 offres tant qu'il reste des candidats. Relance : coût `cout_depart + n × increment` pour la n-ième relance de la manche ; une relance gratuite ne fait pas monter le coût.

- **Tests :** 4 offres toujours (boucle sur les manches 1 à 40, graine fixe) ; **8 emplacements pleins** : la 9e arme est refusée, **l'or n'est pas débité**, l'offre reste ; amélioration acceptée même à 8 armes ; **or insuffisant** (prix − 1) : refus, rien ne bouge ; or exact : OK et or à 0 ; achat d'une offre déjà vendue : `DEJA_ACHETE` ; indice −1 / 4 / 99 : `INDICE_INVALIDE` ; **relance à 0 or** : refusée, offres inchangées ; coûts 50, 75, 100 ; remise à 50 à la manche suivante ; relance gratuite consommée avant l'or et ne faisant pas monter le coût ; vente à 50 % (prix impair : arrondi inférieur), vente d'un emplacement vide refusée, l'emplacement libéré est réutilisable ; **cumul des améliorations** : deux +10 % dans la même catégorie = +20 %, deux catégories = ×1,1 × 1,1, types indépendants, état vide = valeurs neutres ; marché noir : refusé sans jeton, un jeton = un choix ; **reproductibilité** : même graine → mêmes offres sur 20 manches ; **atteignabilité** : sur 20 000 tirages (graine fixe) à chaque manche de 1 à 40, chaque arme et chaque amélioration est proposée au moins une fois à au moins une manche ; les poids de la manche 1 ne proposent jamais d'épique.
- **Vérif :** `T --filtre test_inventaire` et `T --filtre test_boutique`. **Terminé :** vert.

### Task 1.7 : Ennemis en tableaux compacts et statuts — `sonnet`

- [x] **Objectif :** stockage compact, déplacement, attaques, statuts (poison, brûlure, givre, étourdissement), morts différées.
- **Fichiers (crée) :** `sim/ennemis.gd`, `tests/unitaires/test_ennemis.gd`.
- **Lire :** spec §4 (tableaux), §5.4 (effets), §5.5 ; `sim/combat.gd` (interface), `sim/types.gd`.
- **Interfaces :**

```gdscript
class_name Ennemis extends RefCounted
var taille: int                                                    # vivants, morts en attente non comptés
func _init(donnees: Donnees) -> void
func ajouter(famille: int, pos: Vector2, pv: float, vitesse: float, degats: float, portee_attaque: float, cadence: float, prime: int, volant: bool, armure: int) -> int   # id stable croissant
func indice_de(id: int) -> int                                     # -1 si absent
func infliger(i: int, montant: float, type_degats: int) -> float   # dégâts réels après efficacité ; marque la mort une seule fois ; 0 si déjà mort
func empoisonner(i: int, total: float, duree: float) -> void       # cumul : ajoute `total` au reste et prend max(durée restante, duree)
func bruler(i: int, ratio: float, degats_du_coup: float, duree: float) -> void   # DoT = ratio × degats_du_coup, cumulatif
func givrer(i: int, resistance: float) -> void                     # +1 cumul ; au maximum de cumuls : gel de min(gel_max_s × résistance, gel_max_s), cumuls remis à 0, pas de nouveau cumul pendant le gel
func etourdir(i: int, duree: float, resistance: float) -> void     # durée × résistance, prolonge sans cumuler
func avancer(dt: float, centre: Vector2, rayon_tour: float, mult_vitesse: float, mult_degats: float) -> Dictionary   # {degats_tour: float, attaquants_cac: PackedInt32Array, tues_par_statut: PackedInt32Array} (statuts avancés dans ce pas)
func dans_rayon(centre: Vector2, rayon: float, inclure_volants: bool) -> PackedInt32Array   # indices, ordre croissant d'id
func choisir(centre: Vector2, portee: float, mode: int) -> int     # indice ou −1 ; égalités départagées par le plus petit id
func purger() -> Array[Dictionary]                                 # retire les morts (échange avec le dernier) → [{id, famille, prime, pos}] ; ordre stable par id
func vers_vue(vue: VueArene) -> void                               # remplit les 5 tableaux ennemis_* (copie)
```

Pseudo-algorithmes : **ciblage** = parmi les ennemis vivants à distance ≤ portée du centre (volants inclus), `PLUS_PROCHE` min de `|pos − centre|²`, `PLUS_FORT` max de PV, `PLUS_FAIBLE` min de PV, égalité → plus petit id. **Givre** : `cumuls++` ; ralentissement = `Combat.ralentissement(cumuls, …)` appliqué à la vitesse ; si `cumuls ≥ cumuls_max` → `gel = Combat.duree_gel(…)`, `cumuls = 0` ; les cumuls non entretenus retombent d'un cran par seconde. **Déplacement** : corps à corps → droit sur la tour, s'arrête à `rayon_tour + portee_attaque` et attaque à la cadence ; à distance → s'arrête à `portee_attaque` ; gelé ou étourdi → immobile et n'attaque pas.

- **Tests :** ajout/purge de 0, 1, 1 000 ennemis ; **zéro ennemi** : toutes les méthodes sans exception, `choisir` → −1 ; ids stables après purges successives (swap-remove) ; mort unique (deux `infliger` mortels dans le même pas : un seul `purger`, prime comptée une fois) ; poison seul (somme = total), brûlure seule, **poison + brûlure + givre + étourdissement sur le même ennemi** (chaque effet agit, la mort par statut n'est comptée qu'une fois) ; poison recommencé cumule sans dépasser l'intention ; **givre** : 7 cumuls = ralenti mais pas gelé, 8e = gelé 3 s (jamais plus), pendant le gel pas de nouveau cumul, dégel puis re-gel possible ; **résistance** : étourdissement ×0,5, ×0,1, ×0 ; gel plafonné à 3 s même à résistance 1 ; volants et sol traités par `dans_rayon` selon le drapeau ; ciblage aux trois modes avec égalités exactes ; ennemi à distance s'arrête à sa portée ; corps à corps listé dans `attaquants_cac` ; `vers_vue` copie 300 ennemis sans partage de mémoire ; **performance** : 1 000 ennemis, 100 pas en moins de 500 ms au total, soit 5 ms/pas en moyenne (`Time.get_ticks_usec`, marge large).
- **Vérif :** `T --filtre test_ennemis`. **Terminé :** vert.

### Task 1.8 : Armes équipées et résolution des tirs — `sonnet`

- [x] **Objectif :** recharge, ciblage, effets cible unique / zone / rebond / onde / barrage / mine / piège / aura, critique, statuts, vol de vie, éclaboussure, tirs multiples, focalisation.
- **Fichiers (crée) :** `sim/arme_equipee.gd`, `sim/tir.gd`, `tests/unitaires/test_tir.gd`.
- **Lire :** spec §5.4 ; `sim/ennemis.gd`, `sim/combat.gd`, `sim/stats_tour.gd`, schéma d'`armes.json`.
- **Interfaces :**

```gdscript
class_name ArmeEquipee extends RefCounted
var id: String; var def: Dictionary; var recharge_restante: float
var mines: PackedVector2Array; var ondes: Array[Dictionary]         # {rayon: float, deja_touches: PackedInt32Array}
func _init(def: Dictionary) -> void
func recharge_ratio(stats: StatsTour) -> float                      # 0 = prête, 1 = vient de tirer

class_name Tir extends RefCounted
class Bilan: var degats: float; var tues_directs: int; var soin: float; var evenements: Array[Dictionary]
static func avancer_arme(arme: ArmeEquipee, dt: float, stats: StatsTour, ennemis: Ennemis, centre: Vector2, donnees: Donnees, rng: RandomNumberGenerator, resistance: float, bilan: Bilan) -> void
```

Formules : `recharge_eff = recharge / (1 + stats.cadence)` ; `dégâts = degats × degats_type[type] × degats_global × (critique ? puissance : 1) × (cible_unique ? 1 + focalisation : 1)`, puis `Ennemis.infliger(i, dégâts, type)`, qui applique **seul et une seule fois** l'efficacité type/armure (ne jamais la multiplier aussi dans `Tir` : un test vérifie qu'un tir tranchant sur armure moyenne fait exactement ×2, pas ×4) ; nombre de tirs = `1 + tirs_multiples`, chaque tir vise une cible **distincte** quand il y en a assez (sinon la même). Critique : tirage `rng.randf() < chance_effective`.
**Rebond (pseudo)** : `touchees = {}` ; `c = choisir(centre, portee, ciblage)` ; pour `k = 0 .. cibles−1` : frapper `c` avec `dégâts × decroissance^k` ; `touchees += c` ; `c = plus proche non touchée dans portee_saut autour de c` ; arrêt si aucune. **Zone** : tous les ennemis dans `rayon` du point d'impact (volants inclus). **Onde** : anneau centré sur la tour qui grandit de `vitesse × dt` jusqu'à `rayon_max` et touche **une seule fois** chaque ennemi traversé. **Barrage** : `projectiles` impacts de rayon `rayon`, dirigés autour de la cible avec une dispersion `dispersion_deg` tirée par le `rng`. **Mine / piège** : pose jusqu'à `max_actives` à la position d'un ennemi **au sol** ; se déclenche quand un ennemi **au sol** passe dans le rayon ; **les volants l'ignorent**. **Aura** : à chaque `periode`, frappe tous les ennemis dans `rayon`. **Éclaboussure** : autour de la cible d'un tir `cible_unique`, ratio × dégâts dans 80 unités. Statuts appliqués sur chaque cible touchée, un coup à la fois.

- **Tests :** chaque `kind` d'effet en boucle sur une arme-type ; recharge (pas de tir avant la fin, un seul tir par recharge malgré un grand `dt`) ; cadence ×2 ; **zéro ennemi** : aucune exception, aucun tir consommé, recharge conservée prête ; cible hors portée aux quatre paliers de portée (299/300/301 unités…) ; rebond avec 1, 3, 8 ennemis autour (jamais deux fois le même, jamais plus que `cibles`, décroissance respectée) ; zone qui touche les volants, **mine qui ignore un volant** et se déclenche pour un fantassin, `max_actives` respecté ; onde : chaque ennemi touché une seule fois ; critique : 0 % jamais, 100 % toujours, 200 % → puissance accrue, graine fixe reproductible ; efficacité ×2 appliquée aux 4 couples, ×1 sinon ; focalisation uniquement en cible unique ; vol de vie au coup / à la mort ; **plusieurs effets sur le même ennemi** (givre + poison + brûlure du même tir) ; éclaboussure ; tirs multiples sur cibles distinctes ; évènements `tir` et `impact` émis avec positions et types.
- **Vérif :** `T --filtre test_tir`. **Terminé :** vert.

### Task 1.9 : Arène (une tour, un joueur) — `sonnet`

- [x] **Objectif :** assembler économie, boutique, inventaire, ennemis, armes, apparitions, tour ; produire la `VueArene`.
- **Fichiers (crée) :** `sim/arene.gd`, `tests/unitaires/test_arene.gd`.
- **Lire :** spec §5.1 à §5.5 ; interfaces de 1.3, 1.4, 1.6, 1.7, 1.8.
- **Interfaces :**

```gdscript
class_name Arene extends RefCounted
signal tour_detruite
func _init(donnees: Donnees, graine: int) -> void
func demarrer_manche(numero: int, famille: int, mult: Dictionary) -> void   # mult : {pv, degats, vitesse, resistance_controle} ; famille = index, ou Donnees.familles.size() pour le convoi
func demarrer_boss(mult: Dictionary) -> void                                # arrête les apparitions normales
func avancer(dt: float) -> void                                             # dt = 0,05 ; ordre : revenu → apparitions → ennemis/tour → statuts → armes → purge/primes → défaite
func acheter(index: int) -> int; func relancer() -> int; func vendre(index_arme: int) -> int; func choisir_marche_noir(id: String) -> int   # Types.Resultat
func vue(phase: int, temps_restant: float, prochaine_famille: int, sans_fin: bool) -> VueArene   # vide `evenements` ensuite
func est_detruite() -> bool; func boss_vaincu() -> bool
func nombre_ennemis() -> int
```

Apparitions : cumulateur de temps, intervalle `max(plancher, depart − baisse × (manche−1))`, angle `rng.randf() × TAU` sur le cercle de rayon 1300, PV/vitesse/dégâts × `mult`. Dégâts à la tour : `Combat.degats_subis(dégâts, armure)` ; esquive de la tour : tirage par attaque ; épines : chaque attaquant au corps à corps subit `stats.epines × dégâts` ; régénération par seconde ; PV max = base + `pv_max_bonus`. Le convoi n'inflige aucun dégât et verse sa prime élevée. Intentions d'une arène détruite : `ARENE_MORTE` ; la boutique est ouverte dans toute phase d'une arène non détruite (préparation comprise).

- **Tests :** **reproductibilité** : même graine et mêmes intentions → mêmes 2 000 pas (comparer `vue().to_dict()` tous les 100 pas) ; graines différentes → apparitions différentes ; apparitions aux angles dans [0, TAU), sur le cercle exact ; intervalle 2,0 s à la manche 1, 1,92 s à la 2, plancher 0,1 s dès la manche 25+ ; **1 000+ ennemis** sur plancher sans exception et pas moyen < 5 ms ; défaite à PV 0 : `tour_detruite` émis **une fois**, intentions suivantes → `ARENE_MORTE` ; armure de la tour (0, 20, 1000) ; épines sur corps à corps seulement ; esquive à 0 et très haute ; regen ; primes et revenus versés, bonus d'éliminations ; achat/vente/relance via l'arène (débit exact, 8 armes) ; convoi : or élevé, aucun dégât ; arme achetée tire dès qu'un ennemi est à portée ; boss : plus d'apparitions normales ; `vue()` : 4 offres, ≤ 8 armes, tableaux ennemis de même longueur, événements vidés après lecture ; **intentions invalides** (indices −1, 4, 8, 99) → `INDICE_INVALIDE`, aucun effet.
- **Vérif :** `T --filtre test_arene`. **Terminé :** vert.

### Task 1.10 : Partie (N arènes, manches, difficulté, boss, fin) — `sonnet`

- [x] **Objectif :** le seul point d'entrée public de la simulation, consommé tel quel par `reseau/` et `SourceLocale`.
- **Fichiers (crée) :** `sim/partie.gd`, `tests/unitaires/test_partie.gd`.
- **Lire :** spec §5.1, §5.5 ; `sim/arene.gd`, `sim/vue_globale.gd`, `data/difficulte.json`.
- **Interfaces :**

```gdscript
class_name Partie extends RefCounted
signal manche_commencee(numero: int); signal joueur_elimine(id: int); signal joueur_victorieux(id: int); signal partie_terminee(classement: Array)
class Config: var graine: int; var facteur_duree: float = 1.0   # 1,0 / 0,66 / 0,5 (spec §5.1)
func _init(donnees: Donnees, config: Config) -> void
func ajouter_joueur(id: int, nom: String) -> bool                  # faux si partie démarrée, id déjà pris ou 8 joueurs
func retirer_joueur(id: int) -> void                               # = éliminé, arène retirée ; sans effet si inconnu
func demarrer() -> bool                                            # faux si 0 joueur
func avancer(dt_reel: float) -> int                                # nombre de pas simulés ; accumulateur : `acc += dt_reel / facteur_duree`, un pas par 0,05 s ; dt ≤ 0 → 0
func intention_acheter(id: int, index: int) -> int; func intention_relancer(id: int) -> int; func intention_vendre(id: int, index_arme: int) -> int; func intention_marche_noir(id: int, ami: String) -> int
func intention_continuer_sans_fin(id: int) -> int                  # Types.NON_DISPONIBLE tant que T4.3 n'est pas fait
func intention_quitter(id: int) -> int                             # un vainqueur qui quitte est « terminé »
func vue_arene(demandeur: int, cible: int) -> VueArene            # null si le demandeur est vivant et cible ≠ demandeur, ou si la cible n'existe pas
func vue_globale() -> VueGlobale
func temps_ecoule() -> float; func est_terminee() -> bool
```

Déroulement : préparation 30 s (manche 0) puis manches de 30 s ; à chaque manche, **une famille commune à tous les joueurs**, tirée par le `rng` de la partie, **jamais deux fois de suite**, convoi avec `convoi.probabilite` à partir de `manche_min` (jamais deux manches de suite) ; multiplicateurs = `paliers` (`Donnees.palier`) × accélérations dont `temps_s ≤ temps_ecoule`, au-delà du dernier palier `apres_table` appliqué par manche supplémentaire (borné par `resistance_plancher`) ; `manche_boss` = 31 → boss sur chaque arène vivante ; boss mort → `VICTOIRE` (arène figée, en attente de `continuer`/`quitter`). Fin : plus aucun joueur « en jeu » (vivant et non vainqueur parti). Classement : manche atteinte puis dégâts infligés, égalités par id ; `dernier_rempart` = le dernier éliminé s'il y a eu des éliminés avant lui et qu'il l'était à la fin, sinon −1. Graine d'une arène = `config.graine + 7919 × rang d'arrivée`.

- **Tests :** **1 à 8 joueurs en boucle** (démarrage, 600 pas, vues globales cohérentes) ; 9e joueur refusé ; id dupliqué refusé ; ajout après démarrage refusé ; **zéro joueur** : `demarrer()` faux, `avancer` sans effet, pas d'exception ; **tous déconnectés pendant la préparation** : `partie_terminee` émis une fois, classement vide ; déconnexion en cours de partie : éliminé, arène retirée, les autres continuent ; **reproductibilité** : même graine + mêmes intentions horodatées au pas → mêmes `VueGlobale` et vues d'arène au pas 3 000 ; **vitesse** : facteur 0,5 atteint le même état que le facteur 1 en simulant deux fois moins de temps réel (même nombre de pas) ; `dt` énorme (60 s) : boucle bornée, pas de gel ; manche N : familles jamais identiques deux fois de suite (200 manches, boucle sur 20 graines), convoi jamais deux fois de suite ; paliers de difficulté exacts aux manches 1, 5, 31, 40 et aux temps 299/300/600/900 s ; boss uniquement à la manche 31 ; victoire → phase `VICTOIRE`, `intention_quitter` → joueur terminé (le mode sans fin n'est pas testé ici : son test vient avec T4.3, aucun test ne fige le `NON_DISPONIBLE` provisoire) ; classement : manche puis dégâts puis id ; mention « Dernier rempart » seulement si pertinente ; **observation** : demandeur mort peut voir n'importe quelle arène existante, vivant seulement la sienne, cible inconnue → `null` ; intentions d'un id inconnu / mort : refus sans exception.
- **Vérif :** `T --filtre test_partie`, puis `tools/verifier.sh`. **Terminé :** vert ; la simulation complète (1 joueur, bot d'achat simple) joue une partie entière, jusqu'à la défaite ou au-delà de la manche du boss, sans erreur ni avertissement.

---

# Lot 2 — Rendu et interface d'une arène en solo, jouable

**Parallélisme :** vague A (en parallèle) : T2.1, T2.2, T2.3, T2.5, T2.6. Vague B : T2.4 (après 2.2, 2.3). Vague C : T2.7 (assemblage, après toutes). Les tests de ce lot instancient des nœuds via `arbre.root.add_child` (rendu factice de `--headless`).

### Task 2.1 : `SourceVue` et `SourceLocale` — `sonnet`

- [x] **Objectif :** l'interface unique entre simulation et présentation, et son implémentation solo.
- **Fichiers (crée) :** `app/source_vue.gd`, `app/source_locale.gd`, `tests/unitaires/test_source_locale.gd`.
- **Lire :** « Source de vue » de ce plan ; `sim/partie.gd`, `sim/vue_arene.gd`.
- **Interfaces :** `SourceVue` exactement comme la section figée. `SourceLocale extends SourceVue` : `func demarrer(donnees: Donnees, graine: int, facteur_duree: float, nom: String) -> bool` (une `Partie` en processus, 1 joueur d'id 1) ; `_process(delta)` appelle `Partie.avancer`, émet `vue_arene_recue` à 15 Hz et `vue_globale_recue` à 2 Hz, **en passant par `to_dict()`/`from_dict()`** (garantit que le solo exerce le même chemin de sérialisation que le réseau) ; chaque intention renvoie son code par `resultat_intention`. Aucune API navigateur ; `Donnees` injectée (pas de `load` dans le composant).
- **Tests :** cadence d'émission (15 Hz ± 1 sur 2 s simulées par `_process` manuel, 2 Hz) ; la vue reçue est un `VueArene` valide et **égale** à `from_dict(to_dict())` ; achat d'une offre → `resultat_intention("acheter", OK)` et argent débité dans la vue suivante ; indice invalide → code d'erreur, rien ne change ; `observer()` refusé pour un joueur vivant ; `demarrer` avec données `null` → faux sans exception.
- **Vérif :** `T --filtre test_source_locale`. **Terminé :** vert.

### Task 2.2 : Apparence (entité → primitive) — `haiku`

- [x] **Objectif :** l'unique endroit qui connaît les formes et couleurs.
- **Fichiers (crée) :** `visuels/apparence.gd`, `tests/unitaires/test_apparence.gd`.
- **Lire :** spec §2, §6 ; `data/ennemis.json`, `data/armes.json`.
- **Interfaces :**

```gdscript
class_name Apparence extends RefCounted
const ECHELLE: float = 0.02                                        # mètres par unité de jeu
static func position_monde(p: Vector2, hauteur: float = 0.0) -> Vector3   # (x·ECHELLE, hauteur, y·ECHELLE)
static func maillage_famille(index: int) -> Mesh                   # une primitive Godot par famille, taille proportionnelle à son rôle
static func materiau_famille(index: int) -> StandardMaterial3D
static func maillage_tour() -> Mesh; static func materiau_tour() -> StandardMaterial3D
static func couleur_type(type_degats: int) -> Color                # projectiles et impacts
static func forme_projectile(type_degats: int) -> Mesh
static func couleur_rarete(r: int) -> Color; static func symbole_rarete(r: int) -> String   # la couleur n'est jamais seule : symbole et texte
static func couleur_armure(a: int) -> Color; static func symbole_armure(a: int) -> String
```

Familles inconnues : primitive de repli visible (jamais `null`).

- **Tests :** **chaque** famille, type de dégâts, rareté et armure (boucle) a un maillage/une couleur non nuls ; deux raretés n'ont ni le même symbole ni la même couleur ; contraste de chaque couleur de texte de rareté ≥ 4,5:1 sur le fond d'interface (fonction de luminance relative écrite dans le test) ; index hors bornes → repli ; `position_monde` : `(1300, 0)` → x = 26 m.
- **Vérif :** `T --filtre test_apparence`. **Terminé :** vert.

### Task 2.3 : Interpolation des états — `sonnet`

- [x] **Objectif :** lisser entre deux vues reçues, quelle que soit la source.
- **Fichiers (crée) :** `visuels/interpolation.gd`, `tests/unitaires/test_interpolation.gd`.
- **Lire :** spec §4, §6 ; `sim/vue_arene.gd`.
- **Interfaces :**

```gdscript
class_name Interpolation extends RefCounted
const DELAI_S: float = 0.12                                        # ~2 intervalles à 15 Hz
func pousser(vue: VueArene, temps_reception: float) -> void        # ignore une vue de tick ≤ au dernier reçu
func echantillon(temps_rendu: float) -> Dictionary                 # {vue: VueArene (la plus récente des deux), ids: PackedInt32Array, pos: PackedVector2Array}
func reinitialiser() -> void
```

Pseudo : garder `a` (précédente) et `b` (courante) ; `t = temps_rendu − DELAI_S` ; `alpha = clamp((t − a.t) / (b.t − a.t), 0, 1)` ; index de `a` par `Dictionary id → indice` construit une seule fois par `pousser` ; pour chaque id de `b` : si présent dans `a` et distance < 200 unités → `lerp`, sinon position de `b` (apparition ou saut) ; les ids seulement dans `a` disparaissent. Pas d'extrapolation : au-delà de `b`, `alpha = 1`.

- **Tests :** `alpha` 0, 0,5, 1 et > 1 (aucune extrapolation) ; une seule vue reçue → renvoie ses positions ; **zéro ennemi** ; ennemi apparu / disparu entre les deux vues ; saut > 200 unités non interpolé ; ids qui changent d'indice entre deux vues (purge) : chaque ennemi suit **son** id ; vues dans le désordre ou dupliquées ignorées ; `temps_rendu` antérieur à `a` ; 300 ennemis en moins de 2 ms.
- **Vérif :** `T --filtre test_interpolation`. **Terminé :** vert.

### Task 2.4 : Arène 3D et caméra — `sonnet`

- [x] **Objectif :** sol en damier, tour, `MultiMeshInstance3D` par famille, projectiles et impacts, caméra fixe inclinée avec zoom.
- **Fichiers (crée) :** `visuels/arene_3d.gd`, `visuels/camera_arene.gd`, `visuels/effets.gd`, `scenes/arene_3d.tscn`, `tests/unitaires/test_arene_3d.gd`.
- **Lire :** spec §6 ; `visuels/apparence.gd`, `visuels/interpolation.gd`, `app/source_vue.gd`.
- **Interfaces :**

```gdscript
class_name Arene3D extends Node3D
func lier(source: SourceVue) -> void                               # s'abonne à vue_arene_recue ; ne lit rien d'autre que VueArene
func afficher(vue: VueArene, temps_rendu: float) -> void           # testable sans source
func nombre_instances_visibles(famille: int) -> int
class_name CameraArene extends Camera3D
func zoomer(delta: float) -> void                                  # bornes min/max ; clamp
```

Chaque famille : un `MultiMeshInstance3D` dont `instance_count` suit le maximum vu (jamais réalloué à chaque vue) et `visible_instance_count` = nombre d'ennemis ; événements `tir` → projectile léger de durée de vie courte ; `impact` → anneau de rayon `rayon × ECHELLE` ; effets en pool (pas de `queue_free` par événement). Aucun accès à `Partie`.

- **Tests :** 0, 1, 300, 1 000 ennemis (compteurs exacts par famille) ; passage de 300 à 0 ennemi ; une famille inconnue n'échoue pas ; événements : 100 impacts dans une vue n'agrandissent pas le pool au-delà d'une borne ; `zoomer` aux bornes ; la tour est à l'origine ; **le même `VueArene` reconstruit par `from_dict(to_dict())` produit le même affichage** (comparer les compteurs et les transformations).
- **Vérif :** `T --filtre test_arene_3d`. **Terminé :** vert.

### Task 2.5 : HUD et tableau des scores — `haiku`

- [x] **Objectif :** PV, or et revenu, manche et temps, prochaine famille et armure, armes ; tableau des scores (Tab).
- **Fichiers (crée) :** `ui/hud.gd`, `ui/scores.gd`, `scenes/hud.tscn`, `scenes/scores.tscn`, `i18n/textes_hud.csv`, `tests/unitaires/test_hud.gd`.
- **Lire :** spec §6 ; `sim/vue_arene.gd`, `sim/vue_globale.gd`, `visuels/apparence.gd`.
- **Interfaces :** `class_name Hud extends Control` : `func afficher(vue: VueArene) -> void` ; `class_name TableauScores extends Control` : `func afficher(vue: VueGlobale, id_local: int) -> void`, visible tant que Tab est maintenu. Clés CSV `HUD_*` et `SCORES_*` (colonne `fr`). Armure annoncée **en texte et symbole**, pas en couleur seule ; chaque contrôle ≥ 48 px de haut ; texte ≥ 16 px.
- **Tests :** formatage de 0 / 1 / 999 999 d'or, PV à 0 et pleins, manche 0 (« Préparation »), temps restant 0, armure des six valeurs en boucle, 0 / 8 armes ; tableau à 1 et 8 joueurs, joueur éliminé marqué en **texte**, noms les plus longs sans débordement (largeur du contrôle) ; chaque clé `HUD_*` / `SCORES_*` utilisée dans le code existe dans le CSV.
- **Vérif :** `T --filtre test_hud`. **Terminé :** vert.

### Task 2.6 : Panneau de boutique — `sonnet`

- [x] **Objectif :** 4 cartes, achat, relance, raccourcis 1 à 4 et R, marché noir.
- **Fichiers (crée) :** `ui/boutique_ui.gd`, `scenes/boutique.tscn`, `i18n/textes_boutique.csv`, `tests/unitaires/test_boutique_ui.gd`.
- **Lire :** spec §6 ; `app/source_vue.gd`, `sim/vue_arene.gd`, `visuels/apparence.gd`, `data/armes.json` (noms et descriptions via `Donnees`).
- **Interfaces :** `class_name BoutiqueUi extends Control` : `func configurer(donnees: Donnees, source: SourceVue) -> void` ; `func afficher(vue: VueArene) -> void` ; chaque carte : nom, rareté (couleur **et** texte), prix, type de dégâts, description courte ; boutons « Acheter » et « Relancer (coût) » ; un bouton désactivé reste focalisable (`aria`-équivalent : texte « or insuffisant »). Touches 1 à 4 / R **uniquement** si aucun champ de saisie n'a le focus et si la boutique est visible. Une offre vendue est grisée avec le mot « Vendu ».
- **Tests :** 4 cartes toujours ; carte vendue ; or insuffisant (désactivée, motif affiché) ; 8 armes pleines (message « emplacements pleins » sur une arme, pas sur une amélioration) ; relance à 0 or ; relance gratuite affichée « gratuite » ; touches 1 à 4 et R émettent la bonne intention **en boucle**, touche 5 / 0 / Tab ignorées ; touche pendant la saisie d'un champ : ignorée ; marché noir ouvert : liste des choix ; rareté en texte pour les 4 raretés.
- **Vérif :** `T --filtre test_boutique_ui`. **Terminé :** vert.

### Task 2.7 : Assemblage solo : menu, partie, boucle jouable — `sonnet`

- [x] **Objectif :** `godot --path .` ouvre un menu, « Jouer seul » lance une partie jouable.
- **À reprendre des tâches précédentes :** déclarer dans `project.godot` (`[input]`) l'action `afficher_scores` liée à Tab, lue par `TableauScores` ; enregistrer tous les `i18n/*.csv` (dont `textes_communs.csv`) ; appeler `Hud.configurer(donnees)` ; dans la scène 3D, poser les maillages d'`Apparence` à une demi-hauteur au-dessus du sol (leur centre est à l'origine du nœud).
- **Fichiers (crée) :** `app/jeu.gd`, `app/menu_principal.gd`, `app/arguments.gd`, `scenes/principal.tscn`, `scenes/jeu.tscn`, `i18n/textes_menu.csv` ; **modifie** `project.godot` (scène principale, liste des CSV de traduction), `tests/integration/test_solo.gd` (crée).
- **Lire :** toutes les interfaces du lot 2 ; spec §1, §6.
- **Interfaces :** `class_name Jeu extends Node` : `func demarrer_solo(donnees: Donnees, graine: int, facteur_duree: float) -> void` (instancie `SourceLocale`, `Arene3D`, `CameraArene`, `Hud`, `BoutiqueUi`, `TableauScores` et les câble) ; `class_name Arguments`, `static func lire(args: PackedStringArray) -> Dictionary` (`--serveur`, `--port N` défaut 7777, `--graine N`, `--acceleration N`, `--vitesse 1|0.66|0.5`, `--quitter-a-la-fin`) : valeur invalide → clé d'erreur, jamais d'exception. Menu : « Jouer seul », options de vitesse et de graine, « Quitter » ; données invalides → écran d'erreur lisible.
- **Tests :** `Arguments.lire` : aucun argument, port 0 / 65536 / « abc », graine négative, argument inconnu, valeurs répétées ; **partie solo de bout en bout** (`tests/integration/test_solo.gd`) : un robot achète à chaque manche pendant 3 manches à ×0,5 ; aucune erreur dans les journaux, argent et armes cohérents dans le HUD ; reconstruction du `Jeu` après données invalides.
- **Vérif :** `T`, puis `tools/verifier.sh`. **Terminé :** vert ; à la main (si l'écran est disponible) : une capture d'écran de l'arène **ou** la mention « non vérifié visuellement » dans le rapport.

---

# Lot 3 — Réseau

**Parallélisme :** vague A (en parallèle) : T3.1, T3.2. Vague B (en parallèle) : T3.3, T3.4, T3.6. Vague C : T3.5 (après 3.3). Vague D : T3.7. `reseau/` n'importe **que** `Partie`, `VueArene`, `VueGlobale`, `Donnees`, `Types`.

### Task 3.1 : Protocole binaire — `sonnet`

- [x] **Objectif :** encodage compact et décodage défensif de tous les messages.
- **Fichiers (crée) :** `reseau/protocole.gd`, `tests/unitaires/test_protocole.gd`.
- **Lire :** spec §4 ; `sim/vue_arene.gd`, `sim/vue_globale.gd`, `sim/donnees.gd` (`ids_catalogue`, `empreinte`).
- **Interfaces :** `class_name Protocole extends RefCounted` ; `const VERSION: int = 1`, `const MAX_ENNEMIS: int = 2000`, `const MAX_EVENEMENTS: int = 64`, `const MAX_TAILLE: int = 65536`.

```gdscript
enum Msg { BONJOUR = 1, ETAT_ARENE, ETAT_GLOBAL, INTENTION, SALON, REFUS }
static func encoder_bonjour(nom: String, empreinte: int) -> PackedByteArray
static func decoder_bonjour(b: PackedByteArray) -> Dictionary                    # {version, nom, empreinte} ; {} si invalide ; nom tronqué à 24 caractères
static func encoder_etat_arene(v: VueArene, catalogue: PackedStringArray) -> PackedByteArray
static func decoder_etat_arene(b: PackedByteArray, catalogue: PackedStringArray) -> VueArene   # null si invalide
static func encoder_etat_global(v: VueGlobale) -> PackedByteArray
static func decoder_etat_global(b: PackedByteArray) -> VueGlobale                # null si invalide
static func encoder_intention(genre: int, arg: int, texte: String = "") -> PackedByteArray
static func decoder_intention(b: PackedByteArray) -> Dictionary                  # {genre, arg, texte} ; {} si invalide
enum Intention { ACHETER = 1, RELANCER, VENDRE, MARCHE_NOIR, OBSERVER, SANS_FIN, QUITTER, PRET, OPTIONS }
static func encoder_refus(motif: String) -> PackedByteArray; static func decoder_refus(b: PackedByteArray) -> String
```

**Encodage de `ETAT_ARENE`** (little-endian, `PackedByteArray.encode_*`) : `u8 type` · `u32 tick` · `u8 phase` · `u16 manche` · `u16 temps_restant × 10` · `u8 flags (sans_fin, marche_noir_ouvert)` · `f32 tour_pv` · `f32 tour_pv_max` · `f32 tour_armure` · `i32 argent` · `i32 revenu` · `u16 revenu_dans × 10` · `u16 cout_relance` · `u8 relances_gratuites` · `i8 prochaine_famille` · `u8 prochaine_armure` · `u8 n_offres` + n × `[u8 genre|rarete<<1|vendu<<4, u16 idx_catalogue, u16 prix]` · `u8 n_armes` + n × `[u16 idx_catalogue, u8 recharge_ratio×255]` · `u16 n_amel` + n × `[u16 idx, u8 compte]` · `u16 n_ennemis` + n × `[u16 id (modulo 65 536), i16 x×16, i16 y×16, u8 famille, u8 pv, u8 statuts]` (**9 octets**) · `u8 n_evt` + n × `[u8 genre, u8 type_degats, i16 x1×16, i16 y1×16, i16 x2×16, i16 y2×16, u8 rayon/8]` · `u16 eliminations` · `f32 degats_infliges` · `u16 manche_max`. Précision de position : 1/16 d'unité (rayon max ≈ 1 400 → ±22 400 dans un `i16`).

- **Tests :** aller-retour pour chaque message ; erreur de position ≤ 1/32 unité sur 1 000 positions aléatoires (graine fixe) dont les bornes (±1 400) ; **300 ennemis × 15 Hz ≤ 50 Ko/s** (taille d'un message × 15 < 50 000, chaîne de 8 armes, 4 offres, 64 événements) ; 0 ennemi ; 2 000 ennemis (borne) accepté, 2 001 refusé à l'encodage ; **décodage défensif** : paquet vide, tronqué à chaque longueur possible (boucle sur toute la longueur d'un message valide), type inconnu, version fausse, compteur annonçant plus que les octets restants, octets en trop, 65 536 octets de bruit aléatoire (graine fixe) → toujours `null`/`{}`, jamais d'erreur ; id d'objet absent du catalogue → `null` ; nom Unicode de 24 caractères et de 1 000 caractères ; `VERSION` différente → motif dans le refus.
- **Vérif :** `T --filtre test_protocole`. **Terminé :** vert.

### Task 3.2 : Salon et canal RPC — `sonnet`

- [x] **Objectif :** état du salon pur (testable sans réseau) et déclaration unique des RPC.
- **Fichiers (crée) :** `reseau/salon.gd`, `reseau/canal.gd`, `tests/unitaires/test_salon.gd`.
- **Lire :** spec §5.1 (salon), §4 (réseau) ; `reseau/protocole.gd` (interfaces ci-dessus).
- **Interfaces :**

```gdscript
class_name Salon extends RefCounted
var joueurs: Dictionary                                            # id → {nom: String, pret: bool}
var vitesse: float = 1.0; var graine: int = 0; var graine_fixe: bool = false
func ajouter(id: int, nom: String) -> bool                         # faux au-delà de 8, id déjà présent ; nom vide → « Joueur N » ; noms dupliqués suffixés
func retirer(id: int) -> void; func marquer_pret(id: int, pret: bool) -> void
func regler(id_hote: int, id: int, vitesse: float, graine: int, graine_fixe: bool) -> bool   # seul l'hôte, vitesse ∈ {1,0.66,0.5}
func peut_demarrer() -> bool                                       # ≥ 1 joueur et tous prêts
func vers_octets() -> PackedByteArray; static func depuis_octets(b: PackedByteArray) -> Salon   # null si invalide
class_name Canal extends Node
signal bonjour_recu(pair: int, octets: PackedByteArray); signal intention_recue(pair: int, octets: PackedByteArray)
signal etat_arene_recu(octets: PackedByteArray); signal etat_global_recu(octets: PackedByteArray); signal salon_recu(octets: PackedByteArray); signal refus_recu(octets: PackedByteArray)
@rpc("any_peer", "reliable") func rpc_bonjour(octets: PackedByteArray) -> void
@rpc("any_peer", "reliable") func rpc_intention(octets: PackedByteArray) -> void
@rpc("authority", "unreliable") func rpc_etat_arene(octets: PackedByteArray) -> void
@rpc("authority", "reliable") func rpc_etat_global(octets: PackedByteArray) -> void
@rpc("authority", "reliable") func rpc_salon(octets: PackedByteArray) -> void
@rpc("authority", "reliable") func rpc_refus(octets: PackedByteArray) -> void
```

`Canal` est un nœud nommé `Canal` à la racine ; `Serveur` et `Client` en sont des enfants au même chemin des deux côtés (même nom de nœud → mêmes RPC). Corps des RPC : émettre le signal (avec `multiplayer.get_remote_sender_id()` pour les `any_peer`), rien d'autre.

- **Tests :** 1 à 8 joueurs en boucle, 9e refusé ; id dupliqué ; retrait d'un absent ; prêt d'un inconnu ; `peut_demarrer` avec 0 joueur, un non prêt, tous prêts ; `regler` par un non-hôte refusé, vitesse hors {1, 0,66, 0,5} refusée, graine fixe / aléatoire ; sérialisation aller-retour et décodage défensif (tronqué, bruit) → `null`.
- **Vérif :** `T --filtre test_salon`. **Terminé :** vert.

### Task 3.3 : Serveur autoritaire — `sonnet`

- [x] **Objectif :** ENet, boucle à pas fixe, intentions validées, états envoyés à 15 Hz et 2 Hz.
- **Débit adaptatif (décision de l'agent principal, mesures de T3.1) :** un état d'arène pèse ~9 octets par ennemi (300 ennemis ≈ 2,8 à 3,5 Ko ; 1 000 ≈ 9 à 10 Ko). Par client, la fréquence d'envoi de l'état d'arène s'adapte à la taille du dernier paquet pour tenir `reseau.budget_octets_s` (nouvelle clé de `data/partie.json`, 50 000, validée par `Donnees`) : `hz = clamp(budget / taille, hz_min, hz_arene)` avec `hz_min = 5` (nouvelle clé `reseau.hz_min`). Le combat est automatique, l'interpolation lisse : la fréquence plus basse ne gêne pas le joueur. Tests : 300 ennemis → 15 Hz ; 1 000 ennemis → ≤ 5,6 Hz et ≥ 5 Hz ; débit mesuré sur 10 s simulées ≤ budget + un paquet.
- **Fichiers (crée) :** `reseau/serveur.gd`, `tests/unitaires/test_serveur.gd` ; **modifie** `data/partie.json` et `sim/donnees.gd` (deux clés `reseau.budget_octets_s` et `reseau.hz_min`, avec leur validation et leurs tests dans `test_donnees.gd`).
- **Lire :** spec §3, §4 ; `reseau/canal.gd`, `reseau/protocole.gd`, `reseau/salon.gd`, `sim/partie.gd` (API publique uniquement).
- **Interfaces :**

```gdscript
class_name Serveur extends Node
signal partie_terminee_serveur
func demarrer(donnees: Donnees, port: int, acceleration: int = 1) -> Error   # 1..65535 ; ENetMultiplayerPeer.create_server(port, 8) ; ERR_* si port invalide ou occupé
func arreter() -> void
func traiter_intention(pair: int, octets: PackedByteArray) -> int  # public pour les tests, renvoie un Types.Resultat ou NON_DISPONIBLE
func joueur_de(pair: int) -> int                                    # id de joueur ou -1
```

Règles : poignée de main `BONJOUR` obligatoire avant toute autre message (sinon ignoré), refus avec motif si `version` ou `empreinte` diffèrent ou salon plein ou partie déjà démarrée ; l'hôte = premier pair connecté ; dans le salon, intentions `PRET`, `OPTIONS` (hôte seul) ; partie démarrée quand `Salon.peut_demarrer()` ; chaque `_physics_process` appelle `Partie.avancer(delta)` `acceleration` fois ; **par pair** : `Partie.vue_arene(joueur, cible_observee)` → `Protocole.encoder_etat_arene` → `rpc_id(pair, "rpc_etat_arene", …)` à 15 Hz (accumulateur indépendant du pas) ; état global à 2 Hz fiable ; **limite de débit** par pair : 30 intentions/s (le surplus ignoré, compté) ; indices et ids validés par `Partie` ; `OBSERVER` mémorisé seulement si `Partie` renvoie une vue non nulle ; déconnexion → `Partie.retirer_joueur` ; si plus aucun pair et partie démarrée → `partie_terminee_serveur`. **Jamais** de logique de jeu ici : uniquement `Partie`.

- **Tests (sans socket : appeler directement `traiter_intention` avec des `PackedByteArray`)** : intention avant `BONJOUR` ignorée ; intention de type inconnu, tronquée, bruit, genre valide mais argument hors bornes (−1, 4, 255) → refus sans exception ; rafale de 1 000 intentions en une seconde : au plus 30 traitées ; acheter après la mort → `ARENE_MORTE` ; observer sa propre arène vivant OK, celle d'un autre vivant refusé, après la mort OK, cible inconnue refusée ; deux pairs même nom ; 9e pair refusé ; **tous déconnectés pendant la préparation** → fin propre ; pair déconnecté en pleine partie → joueur éliminé et les autres continuent ; version ou empreinte différente → refus avec motif ; port 0, 70 000 et déjà occupé → code d'erreur (le port occupé est ouvert par le test lui-même).
- **Vérif :** `T --filtre test_serveur`. **Terminé :** vert.

### Task 3.4 : Client réseau — `sonnet`

- [x] **Objectif :** `SourceVue` réseau : connexion, intentions, réception, interpolation, perte de connexion.
- **Fichiers (crée) :** `reseau/client.gd`, `tests/unitaires/test_client.gd`.
- **Lire :** `app/source_vue.gd`, `reseau/canal.gd`, `reseau/protocole.gd`, `reseau/salon.gd`.
- **Interfaces :**

```gdscript
class_name Client extends SourceVue
signal salon_mis_a_jour(salon: Salon); signal partie_demarree()
func connecter(donnees: Donnees, adresse: String, port: int, nom: String) -> Error   # adresse vide ou port invalide → ERR_INVALID_PARAMETER sans connexion
func deconnecter() -> void
func envoyer_pret(pret: bool) -> void; func envoyer_options(vitesse: float, graine: int, graine_fixe: bool) -> void
```

Toutes les méthodes de `SourceVue` envoient `Protocole.encoder_intention` ; les messages reçus sont décodés par `Protocole`, **un message invalide est ignoré et compté** (jamais d'exception) ; `vue_arene_recue` n'est émis que pour un tick **strictement croissant** (les paquets non fiables arrivent dans le désordre) ; refus du serveur → `connexion_perdue(motif)` avec le texte du refus ; coupure ou délai > 5 s sans état → `connexion_perdue("Connexion perdue")`. Aucune règle de jeu.

- **Tests (en injectant des octets dans les signaux du `Canal`, sans socket)** : états dans l'ordre, dupliqués, anciens, **dans le désordre** (seul le plus récent compte) ; message tronqué ou bruit ignoré ; état global valide ; refus de version → motif relayé ; silence de 5 s (horloge injectée) → perte ; `connecter` avec adresse vide, port 0, port 70 000 ; `acheter(-1)` n'envoie rien (ou refus local) ; **le `VueArene` reçu égale celui encodé** à la quantification près (comparaison à 1/32).
- **Vérif :** `T --filtre test_client`. **Terminé :** vert.

### Task 3.5 : Serveur dédié et lancement — `haiku`

- [x] **Objectif :** `godot --headless -- --serveur --port 7777` fait tourner une partie.
- **Fichiers (crée) :** `reseau/serveur_dedie.gd`, `scenes/serveur.tscn`, `tests/unitaires/test_serveur_dedie.gd` ; **modifie** `app/jeu.gd` (une ligne : si `Arguments` contient `serveur`, charger `scenes/serveur.tscn`) — fichier propriété du lot 2, seul changement autorisé ici.
- **Lire :** `reseau/serveur.gd`, `app/arguments.gd`.
- **Interfaces :** `class_name ServeurDedie extends Node` : `func lancer(args: Dictionary, donnees: Donnees) -> int` (code de sortie ; 0 normal, 2 données invalides, 3 port impossible) ; journal une ligne par évènement (`connexion`, `salon`, `manche N`, `fin`) sur la sortie standard ; si `--quitter-a-la-fin`, sort avec 0 quand `partie_terminee_serveur` est émis ; `--acceleration N` borné 1..60.
- **Tests :** arguments invalides → codes de sortie attendus (données absentes : 2 ; port 0 : 3) ; accélération 0 et 1 000 bornées ; démarrage et arrêt sans erreur sur un port libre choisi par le test.
- **Vérif :** `T --filtre test_serveur_dedie` puis `godot --headless --path . -- --serveur --port 17777 --quitter-a-la-fin` interrompu au bout de 5 s sans erreur dans la sortie. **Terminé :** vert.

### Task 3.6 : Interface de salon et connexion — `haiku`

- [x] **Objectif :** héberger, rejoindre, prêt, options de l’hôte. **Revu par Phil (25/11/2026)** : le menu principal propose « Créer une partie » et « Rejoindre une partie » ; « Rejoindre » liste les salons du réseau local (découverte UDP, `reseau/decouverte.gd`) et accepte une adresse IP et un port ; un seul réglage de salon, la vitesse ×1, ×2 ou ×4 (`vitesses_partie` = `[1.0, 0.5, 0.25]`). Regroupée avec le branchement réseau de T4.6 (en cours).
- **Fichiers (crée) :** `ui/salon_ui.gd`, `ui/connexion_ui.gd`, `scenes/salon.tscn`, `scenes/connexion.tscn`, `i18n/textes_salon.csv`, `tests/unitaires/test_salon_ui.gd`.
- **Lire :** spec §5.1, §6 ; `reseau/salon.gd`, `reseau/client.gd` (interfaces ci-dessus), `app/arguments.gd`.
- **Interfaces :** `class_name SalonUi extends Control` : `func afficher(salon: Salon, id_local: int) -> void` ; signaux `pret_change(pret: bool)`, `options_changees(vitesse: float, graine: int, graine_fixe: bool)`, `quitter()` ; options **actives seulement pour l'hôte** ; `class_name ConnexionUi extends Control` : champs adresse (défaut `127.0.0.1`), port (défaut 7777), nom ; `signal rejoindre(adresse: String, port: int, nom: String)` ; validation locale avec message en français (port hors 1..65535, adresse vide, nom > 24 caractères) ; libellés visibles, cibles ≥ 48 px.
- **Tests :** 1 à 8 joueurs affichés ; options désactivées chez un non-hôte ; port invalide / adresse vide / nom trop long → message, aucun signal ; état prêt en **texte** (pas la couleur seule) ; clés CSV existantes.
- **Vérif :** `T --filtre test_salon_ui`. **Terminé :** vert.

### Task 3.7 : Test d'intégration serveur + 2 robots — `sonnet`

- [x] **Objectif :** un vrai serveur sans interface et deux clients robots jouent une partie accélérée jusqu'au bout.
- **Fichiers (crée) :** `tools/integration.sh`, `tests/integration/robot.gd`, `tests/integration/test_reseau_complet.gd` (test unitaire du protocole bout en bout sur boucle locale, dans le même processus).
- **Lire :** `reseau/serveur.gd`, `reseau/client.gd`, `reseau/serveur_dedie.gd`, `tools/verifier.sh`.
- **Interfaces :** `tools/integration.sh` : choisit un port libre, lance `godot --headless --path . -- --serveur --port P --graine 42 --acceleration 30 --quitter-a-la-fin` en arrière-plan, lance deux fois `godot --headless --path . --script res://tests/integration/robot.gd -- --port P --nom A|B --strategie achat|passif`, attend jusqu'à 120 s ; code 0 **si et seulement si** les trois processus sortent à 0, le journal ne contient ni `ERROR` ni `SCRIPT ERROR` ni `WARNING: ... leaked`, et le journal du serveur contient `fin` ; tue les processus restants à la sortie (`trap`) et affiche les journaux en cas d'échec. `robot.gd` : `extends SceneTree`, se connecte, se met prêt, **achète tout ce qu'il peut** (A) ou **ne fait rien** (B, éliminé tôt) et, une fois mort, observe l'arène de l'autre (exerce `OBSERVER`) ; sort 0 à la fin de partie, 1 sur perte de connexion inattendue.
- **Tests :** `test_reseau_complet.gd` : serveur et client dans le même processus, boucle locale sur port libre, une manche jouée : le client reçoit des états de tick croissant, son achat est débité, le client B coupé brutalement n'arrête pas A ; `tools/integration.sh` donne 0 trois fois de suite (graine fixe) ; **contrôle négatif** : lancer le script avec un serveur arrêté de force à mi-partie → code ≠ 0 (une fois, à la main, résultat noté dans le rapport).
- **Vérif :** `tools/integration.sh && tools/verifier.sh`. **Terminé :** vert ; l'étape `integration` de la CI est active.

---

# Lot 4 — Finitions

**Parallélisme :** vague A (en parallèle) : T4.1, T4.2, T4.3, T4.4, T4.5. Vague B : T4.6 (câblage, après 4.1, 4.2, 4.4).

### Task 4.1 : Observation après la mort — `haiku`

- [x] **Objectif :** après sa défaite, le joueur choisit l'arène à regarder.
- **Fichiers (crée) :** `ui/observation_ui.gd`, `scenes/observation.tscn`, `i18n/textes_observation.csv`, `tests/unitaires/test_observation_ui.gd`.
- **Lire :** spec §5.1 ; `app/source_vue.gd`, `sim/vue_globale.gd`.
- **Interfaces :** `class_name ObservationUi extends Control` : `func afficher(vue: VueGlobale, id_local: int, cible: int) -> void` ; liste des joueurs **vivants** à observer (flèches gauche/droite pour passer au suivant), visible **seulement** si le joueur local est éliminé ; appelle `SourceVue.observer(id)` ; texte « Vous observez : {nom} ».
- **Tests :** invisible tant que le joueur vit ; 0 vivant (liste vide, message, pas d'erreur) ; 1 à 8 joueurs ; passer au suivant boucle sur les vivants ; cible morte entre deux vues → saut au suivant ; touches gauche/droite ignorées si un champ a le focus.
- **Vérif :** `T --filtre test_observation_ui`. **Terminé :** vert.

### Task 4.2 : Écran de fin — `haiku`

- [x] **Objectif :** récapitulatif de défaite ou de victoire, classement, « Dernier rempart », choix sans fin / quitter.
- **Fichiers (crée) :** `ui/fin_ui.gd`, `scenes/fin.tscn`, `i18n/textes_fin.csv`, `tests/unitaires/test_fin_ui.gd`.
- **Lire :** spec §5.1 ; `sim/vue_globale.gd`, `sim/vue_arene.gd`.
- **Interfaces :** `class_name FinUi extends Control` : `func afficher_defaite(vue: VueArene, globale: VueGlobale) -> void`, `func afficher_victoire(vue: VueArene, globale: VueGlobale) -> void`, `func afficher_classement(globale: VueGlobale, id_local: int) -> void` ; signaux `continuer_sans_fin()`, `quitter()`, `observer()` ; le bouton « Continuer sans fin » n'existe qu'en victoire ; mention « Dernier rempart » si `dernier_rempart` = joueur concerné.
- **Tests :** défaite et victoire (boutons attendus) ; classement à 1 et 8 joueurs, égalités ; « Dernier rempart » présent / absent ; manche 0 et 0 dégât ; noms longs ; textes en français avec insécables.
- **Vérif :** `T --filtre test_fin_ui`. **Terminé :** vert.

### Task 4.3 : Mode sans fin (simulation) — `sonnet`

- [x] **Objectif :** après la victoire, les manches reprennent et la difficulté continue de monter.
- **Fichiers (modifie) :** `sim/partie.gd`, `tests/unitaires/test_partie.gd` (ajouts de cas) ; **ajoute** `tests/unitaires/test_partie_sans_fin.gd`.
- **Lire :** `sim/partie.gd`, `data/difficulte.json` (`apres_table`), spec §5.1.
- **Interfaces :** `intention_continuer_sans_fin(id) -> int` devient effective : `OK` si la phase est `VICTOIRE`, sinon `MAUVAISE_PHASE` ; l'arène repart en manches (numérotation continue 32, 33…, famille tirée comme avant, **plus de boss**), `VueArene.sans_fin = true` ; multiplicateurs au-delà de la table : produit de `apres_table` par manche supplémentaire, résistance bornée par `resistance_plancher` ; un joueur en sans fin qui meurt a pour classement sa manche atteinte.
- **Tests :** continuer hors victoire → `MAUVAISE_PHASE` ; après victoire → manches 32+ ; le boss n'apparaît plus ; PV, dégâts, vitesse **strictement croissants** manche après manche (boucle 32 à 80) ; résistance jamais sous le plancher ; joueur A en sans fin pendant que B est encore au boss : indépendants ; quitter après victoire toujours possible ; classement : le joueur en sans fin passe devant celui tombé avant ; reproductibilité conservée.
- **Vérif :** `T --filtre test_partie` ; `tools/verifier.sh`. **Terminé :** vert (les tests de T1.10 qui attendaient `NON_DISPONIBLE` sont **inversés**, pas supprimés).

### Task 4.4 : Réglages — `haiku`

- [x] **Objectif :** réglages locaux persistants et leur écran.
- **Fichiers (crée) :** `app/reglages.gd`, `ui/reglages_ui.gd`, `scenes/reglages.tscn`, `i18n/textes_reglages.csv`, `tests/unitaires/test_reglages.gd`.
- **Lire :** spec §6 (lisibilité) ; doc Godot `ConfigFile`.
- **Interfaces :** `class_name Reglages extends RefCounted` : `var echelle_ui: float = 1.0` (1,0 / 1,25 / 1,5), `var plein_ecran: bool`, `var sensibilite_zoom: float = 1.0` (0,5..2,0), `var nom_joueur: String` ; `static func charger(chemin: String = "user://reglages.cfg") -> Reglages` (fichier absent, corrompu ou valeurs hors bornes → valeurs par défaut, **jamais d'exception**) ; `func sauver(chemin: String = "user://reglages.cfg") -> bool` ; `class_name ReglagesUi extends Control` : `signal modifies(r: Reglages)`.
- **Tests :** aller-retour ; fichier absent ; fichier de bruit ; échelle 0, 99, négative ; sensibilité aux bornes exactes ; nom > 24 caractères tronqué ; chemin non inscriptible → `sauver` renvoie faux.
- **Vérif :** `T --filtre test_reglages`. **Terminé :** vert.

### Task 4.5 : Crédits et documentation — `haiku`

- [x] **Objectif :** `CREDITS.md` à jour et `README.md` utilisable.
- **Fichiers (modifie) :** `CREDITS.md`, `README.md`.
- **Lire :** spec §2, §7, §8 ; `tools/verifier.sh`, `.github/workflows/ci.yml`.
- **Interfaces :** `README.md` : présentation, prérequis (Godot 4.7.2, gdtoolkit 4), commandes `tools/verifier.sh`, lancement solo, hébergement, serveur dédié (`--serveur --port`), pare-feu UDP 7777, redirection de port. `CREDITS.md` : Godot (MIT), gdtoolkit (MIT), aucune autre ressource tierce.
- **Tests :** `bash -n tools/*.sh` ; chaque commande citée dans le README existe (grep des scripts et options d'`Arguments`).
- **Vérif :** `tools/verifier.sh`. **Terminé :** vert.

### Task 4.6 : Câblage final (observation, fin, sans fin, réglages) — `sonnet`

- [x] **Objectif :** le parcours complet depuis le menu : solo ou réseau, mort, observation, fin, sans fin.
- **Fichiers (modifie) :** `app/jeu.gd`, `app/menu_principal.gd`, `scenes/jeu.tscn`, `scenes/principal.tscn`, `tests/integration/test_solo.gd`.
- **Lire :** toutes les interfaces des lots 2 à 4.
- **Interfaces :** `Jeu` choisit `SourceLocale` ou `Client` ; sur `vue_arene_recue` avec `phase == DEFAITE` affiche `FinUi.afficher_defaite` puis `ObservationUi` ; `VICTOIRE` → `afficher_victoire` ; `partie_terminee` → classement ; les réglages (`Reglages.charger()`) s'appliquent au démarrage (échelle d'interface, plein écran, zoom) ; le menu ajoute « Héberger », « Rejoindre » (→ `ConnexionUi`, `SalonUi`) et « Réglages ».
- **Tests :** solo : défaite → écran de défaite puis observation (0 autre joueur : message sans erreur) ; victoire → bouton « Continuer sans fin » → manche 32 ; quitter revient au menu et libère les nœuds (aucune fuite signalée à la sortie du lanceur) ; perte de connexion en réseau → retour au menu avec le motif ; réglages invalides ignorés.
- **Vérif :** `tools/verifier.sh` complet (incluant `tools/integration.sh`). **Terminé :** vert ; rapport final de lot avec la rétro.

---

# Lot 5 — Habillage 2D pixel art avec Tiny Swords CC0 (décisions de Phil du 25/11/2026)

**Direction :** le jeu passe en **2D pixel art vue de dessus**, avec l’**ancienne version CC0** du
pack « Tiny Swords » de Pixel Frog. La version actuelle et le pack d’ennemis interdisent la
redistribution et ne peuvent pas entrer dans ce dépôt public. L’essai 3D réaliste (Blender, Poly
Haven) a été écarté par Phil. La simulation (déjà un plan 2D), le réseau, la boutique et le HUD ne
changent pas : seule la couche `visuels/` passe de la 3D à la 2D. Le pack est téléchargé par Phil
(itch.io passe par un navigateur), puis versionné dans `assets/tiny_swords/` avec sa licence, et
crédité dans `CREDITS.md` (le crédit est facultatif en CC0, mais on cite toujours la source).

**Parallélisme :** T5.0, puis T5.1, puis {T5.2, T5.3, T5.4, T5.6, T5.7} en parallèle, puis T5.5.

### Task 5.0 : Inventaire du pack et correspondance — `sonnet`

- [x] **Objectif :** inventaire de l’archive CC0 (unités, couleurs, animations et leurs images,
      bâtiments, terrain, effets, éléments d’interface, tailles en pixels) dans `docs/tiny_swords.md`,
      et proposition de correspondance : la tour du joueur, les 8 familles (une armure chacune, avec
      une volante et deux à distance), le convoi, le boss. Ce qui manque est comblé par des variantes
      de couleur ou d’échelle, ou des sprites faits par nous dans le même style, signalés comme tels.
      Planche de captures pour validation par Phil **avant** T5.1.
      **Fait, validé par Phil le 25/11/2026** : `docs/tiny_swords.md` (décisions en tête). Les
      quatre renommages sont appliqués dans `data/ennemis.json`, identifiants compris.

### Task 5.1 : Arène 2D — `sonnet`

- [x] **Objectif :** `visuels/arene_2d.gd` remplace l’arène 3D : terrain, tour au centre, ennemis
      animés (marche, attaque, mort), tri en profondeur, `Camera2D` avec zoom borné, même contrat
      (`SourceVue`, interpolation). Performance : 1 000 ennemis visibles sans chute sous 60 images/s
      (pool de sprites ou `MultiMeshInstance2D` avec atlas animé par nuanceur), mesurée. Captures de
      contrôle aux trois résolutions.
      **Fait, fusionné par la PR #7** : unités à ×1,9, tour à ×2,1, ennemi translucide devant la tour,
      images recadrées. Reste la preuve des 60 images/s : 22,6 images/s en rendu logiciel sous Xvfb,
      à mesurer sur une vraie carte graphique.
      **60 images/s constants mesurés par Phil le 25/11/2026** (banc à 1 000 ennemis, T5.1b).

### Task 5.1b : Compteur d’images par seconde et banc d’essai — `sonnet`

- [x] **Objectif :** permettre à Phil de vérifier T5.1 sur son PC (demande du 25/11/2026). Compteur
      (F3, case des Réglages désactivée par défaut) : images/s, minimum sur 5 s, ennemis visibles.
      Banc `-- --banc-ips [N]` (1 000 par défaut) : arène et décor, N ennemis répartis qui avancent,
      vues synthétiques sans partie ni réseau, résumé après 30 s. Marche à suivre dans le `README.md`.

### Task 5.2 : Terrain et décor — `sonnet`

- [x] **Objectif :** sol en tuiles (herbe, chemins, rochers, eau en bordure), décor qui ne gêne pas
      la lecture des ennemis ; le cercle d’apparition reste visible.
      **Fait (25/11/2026)** : sol en tuiles de `Tilemap_Flat` et rivage tirés d’une graine par arène,
      composés en une seule image ; sapins, moutons et rochers d’eau animés ; aucun objet haut dans la
      zone de marche.

### Task 5.3 : Effets — `haiku`

- [x] **Objectif :** tirs, impacts, morts et explosions avec les effets du pack, par type de dégâts,
      plafond d’effets conservé.
      **Fait, fusionné par la PR #7**, en `sonnet` (rendu à juger). Les événements ne portaient ni le genre
      d’arme ni le statut : voir T5.3b.

### Task 5.3b : Genre d’arme et statut dans les événements de tir — `sonnet`

- [x] **Objectif :** `sim/tir.gd` ajoute à chaque événement le genre de l’effet d’arme et le statut
      posé ; `SCHEMA_EVENEMENT` et le protocole binaire les transportent (version augmentée) ;
      `Effets2D` les lit au lieu de deviner. Sans cela, mines, pièges et statuts ne s’affichent pas en
      partie.
      **Fait (25/11/2026)** : protocole en version 3, un octet de plus par événement (genre et statut
      sur 4 bits chacun), champs facultatifs (une mort n’a pas d’arme).

### Task 5.4 : Interface aux couleurs du pack — `sonnet`

- [x] **Objectif :** le thème de l’interface reprend les éléments du pack (bannières, boutons,
      rubans) s’ils sont dans la version CC0, avec une police libre (OFL) ; contrastes AA et tests de
      mise en page conservés.
      **Fait, fusionné par la PR #7** : boutons, bannières et rubans du pack, police Tiny5 (OFL) avec
      repli DejaVu Sans pour les symboles.

### Task 5.5 : Bascule et nettoyage — `sonnet`

- [x] **Objectif :** `visuels/apparence.gd` devient la correspondance entité → sprites ; le test de
      garde vérifie que seuls `apparence.gd` et `assets/tiny_swords/` portent les ressources
      graphiques ; l’arène 3D est retirée ; `CREDITS.md` à jour ; captures finales relues.
      **Fait (25/11/2026)** : arène 3D, caméra, effets, matériaux et primitives retirés ;
      `apparence_2d.gd` devient `apparence.gd` (avec symboles et couleurs de rareté et d’armure), et
      `effets`, `camera_arene`, `decor`, `plan_decor`, `recadrages` perdent leur suffixe (`Arene2D`
      le garde : `Arene` existe dans `sim/`). Garde : `tests/unitaires/test_garde_ressources.gd`.

### Task 5.6 : Sons — `haiku`

- [x] **Objectif :** sons CC0 d’une autre source (le pack n’en a pas) : tirs, impacts, achat,
      relance, PV bas, début de manche, boss, victoire, défaite, musique d’ambiance ; volume des
      réglages appliqué.
      **Fait (25/11/2026)** : dix sons du « 400+ Sounds Pack » (CC0) dans `assets/sons/`, origine
      dans `assets/sons/SOURCES.md` ; musique d’ambiance reportée par Phil le 25/11/2026 (le pack n’a
      pas de boucle), elle reste un silence de substitution.

### Task 5.7 : Sprite maison de l’unité volante — `sonnet`

- [x] **Objectif :** les « Mites de laiton » n’ont aucun sprite dans le pack. Dessiner, par un
      script versionné (`tools/`), une feuille de vol (6 images) et de mort dans le style du pack :
      contour, palette du pack, ombre détachée du corps. Publiée sous CC0 avec le jeu et listée dans
      `CREDITS.md` comme faite par nous. Elle remplace le gobelin violet ×0,7 de T5.1. Planche relue
      par Phil.
      **Fait (25/11/2026)** : `tools/dessiner_guepe.gd` et `assets/maison/guepe_de_laiton.png`. Le
      dessin se lit comme une guêpe : Phil a renommé la famille « Guêpes de laiton ».

### Task 5.8 : Images des offres — `sonnet`

Conception : `docs/superpowers/specs/2026-11-25-boutique-decor-design.md`, section 1 (demande de Phil du
25/11/2026).

- [x] **T5.8a, objectif :** une image peinte par offre, dans une case colorée par type « comme sur
      Warcraft », depuis les packs Ravenmore (CC BY 3.0) et LudicArts (CC BY 3.0), composée par
      `tools/composer_images_offres.gd`, correspondance dans `visuels/images_offres.gd`. **Fait** :
      planche validée par Phil, 17 images approchantes (voir les suivis).
- [x] **T5.8b, objectif :** afficher ces images dans la carte de la boutique, les armes équipées et
      le marché noir, sans casser la mise en page.
      **Fait (25/11/2026)** : image de 64 à 96 px en tête de carte, 32 px devant chaque arme équipée,
      40 px dans le marché noir ; décoratives (ni souris ni focus).

### Task 5.9 : Descriptions des offres — `sonnet`

- [x] **Objectif :** chaque offre affiche une ligne d’effet générée depuis `data/` (chiffres exacts,
      `ui/description_offre.gd`) puis une phrase d’ambiance originale. Les 70 phrases sont réécrites.
      **Fait (25/11/2026)** : le ciblage par défaut (le plus proche) n’est pas écrit ; sous 700 px
      de haut, l’ambiance passe dans l’infobulle.

---

# Lot 6 — Publication (piste, non planifiée)

Si le jeu sort sur Steam : salons et relais réseau Steam par GodotSteam (module libre, SDK
Steamworks gratuit mais propriétaire) à la place de la découverte locale et de l'IP directe. Le
réseau passe déjà par un `MultiplayerPeer` unique (`reseau/canal.gd`). Décision à prendre par un
ADR dédié, avec Phil. Exports Windows et Linux par la CI avant cela.

---

# Lot 7 — Annuaire des parties en ligne et UPnP (décisions de Phil du 25/11/2026 : lancé en parallèle du lot 5)

**Principe :** l'hôte héberge toujours la partie sur sa machine. Un petit service sur le VPS de
Phil ne fait que tenir **l'annuaire des salons ouverts** : nom, nombre de joueurs, version, et
l'adresse IP **vue par le VPS** (jamais une adresse déclarée par le client) et le port **déclaré par
l'hôte** (ADR 001, décision 1). Une entrée
disparaît 30 s après la dernière annonce. Aucune donnée de jeu ne passe par le VPS. L'hôte ouvre
son port par **UPnP** (classe `UPNP` intégrée à Godot), avec un message clair si sa box refuse.

**Parallélisme :** T7.0, validée par Phil le 25/11/2026. Puis {T7.1, T7.2b}, puis T7.2, puis T7.4, puis
T7.3 en dernier (décision de Phil du 25/11/2026, pour laisser le lot 5 poser le thème de l'interface
avant l'écran « Rejoindre »).

### Task 7.0 : ADR de l'annuaire — `sonnet`

- [x] **Objectif :** `docs/adr-001-annuaire.md`. Il décrit le protocole (annonce et liste, bornés en
      taille, version), l'expiration, la limite de débit par IP, la vérification de joignabilité (le
      VPS tente une connexion vers le port annoncé avant de lister le salon), la vie privée (une IP
      publique est une donnée personnelle : gardée seulement tant que le salon est ouvert, aucun
      journal, notice dans le jeu), le langage du service (de préférence Godot sans interface, pour
      garder une seule pile et le même lanceur de tests), le déploiement (image Docker sur le VPS,
      sous-domaine déclaré dans le dépôt `infra`) et le repli si l'annuaire est injoignable (le réseau
      local et l'IP saisie marchent toujours). **Aucun code avant la validation de Phil.**
- **Fait :** `docs/adr-001-annuaire.md`, accepté par Phil le 25/11/2026 avec ses 20 décisions.

### Task 7.1 : Service d'annuaire — `sonnet`

- [x] **Objectif :** le service et ses tests (décodage défensif avec fuzz, expiration, limite de
      débit, IP vue et non déclarée, vérification de joignabilité simulée), plus son `Dockerfile`.
- **Lire :** `docs/adr-001-annuaire.md` (Protocole, Joignabilité, Limites de débit et de mémoire, Ordre
  des contrôles, Déploiement, Fichiers et tâches).
- **Relevé à la relecture de l'ADR :** écouter explicitement sur `0.0.0.0` et traiter les adresses IPv4
  mappées `::ffff:a.b.c.d` ; fermer la connexion seulement après l'écriture complète de la réponse,
  sans RST qui la perde ; la saturation possible de l'annuaire à 34 IP est une limite connue et acceptée.

### Task 7.2b : Jeton d'hôte — `sonnet`

- [x] **Objectif :** réserver le rôle d'hôte au client local. `SessionReseau.heberger` tire un jeton de
      8 octets (`Crypto.generate_random_bytes`) et le remet au `Serveur` et au `Client` local ; le
      bonjour du client local le porte ; quand un jeton est configuré, `Salon.ajouter` ne donne le rôle
      d'hôte qu'à un pair dont le jeton correspond. Sans jeton (serveur dédié, inchangé), l'ancienne
      règle du premier pair et le repli de `Salon.retirer` restent. Pour le salon hébergé, le repli
      est supprimé. `Protocole.VERSION` passe à 4 (la 3 est prise par T5.3b). « Retour au salon » crée une session neuve, donc un
      nouveau jeton.
- **Fichiers (modifie) :** `reseau/protocole.gd`, `reseau/salon.gd`, `reseau/serveur.gd`,
  `reseau/client.gd`, `app/session_reseau.gd`.
- **Tests :** `tests/unitaires/test_protocole.gd`, `test_salon.gd`, `test_serveur.gd`, `test_client.gd`
  mis à jour ; `test_serveur_dedie.gd` doit rester vert.
- **Lire :** `docs/adr-001-annuaire.md` (Rôle d'hôte, point 1 ; Fichiers et tâches).
- **Relevé à la relecture de l'ADR :** nommer les fichiers `tests/unitaires/test_*.gd` de bonjour et de
  salon touchés (ceux ci-dessus).

### Task 7.2 : UPnP chez l'hôte — `sonnet`

- [x] **Objectif :** à « Créer une partie », découverte UPnP et ouverture du port du jeu, fermée en
      quittant le salon et à la fermeture du jeu. Un échec n'empêche jamais de jouer en réseau local :
      il affiche « Votre box n'a pas ouvert le port : les joueurs extérieurs ne pourront pas vous
      rejoindre ». Tests avec un double de `UPNP`.
- **Lire :** `docs/adr-001-annuaire.md` (Cycle de vie de l'hôte, UPnP chez l'hôte).

### Task 7.3 : Annonce et liste dans le jeu — `sonnet`

- [x] **Objectif :** l'hôte annonce son salon à l'annuaire tant qu'il est ouvert (s'il l'a rendu
      public, case cochée par défaut) ; « Rejoindre une partie » affiche les salons du réseau local et
      ceux de l'annuaire, sans doublon, avec leur origine en texte. Adresse de l'annuaire dans les
      réglages, avec une valeur par défaut.
- **Lire :** `docs/adr-001-annuaire.md` (Cycle de vie de l'hôte, Rôle d'hôte point 2, Sécurité et vie
  privée, Repli, Fichiers et tâches).
- **Relevé à la relecture de l'ADR :** un salon d'Internet de même nom et de même port qu'un salon local
  est masqué (décision 13 validée).

### Task 7.4 : Déploiement — `haiku`

- [x] **Objectif :** `docker compose` pour le VPS, sous-domaine ajouté par une PR au dépôt `infra`,
      vérification de bout en bout depuis le conteneur (annonce, liste, expiration). Ce qui reste à
      faire sur le VPS lui-même (ports, pare-feu) est donné à Phil en liste numérotée.
- **Lire :** `docs/adr-001-annuaire.md` (Déploiement, Repli, Sécurité et vie privée, Fichiers et tâches).

---

# Lot 8 — Retours de la première partie de Phil (conception validée le 25/11/2026)

**Conception :** `docs/superpowers/specs/2026-11-25-retours-partie-design.md` (à lire en entier ; décisions D1 à D17 de Phil, elles ne se discutent pas, une objection se dit dans la PR ; les « (proposition) » sont acceptées). Elle complète la spec du jeu et l'emporte là où elles diffèrent. **Les noms de fichiers et de classes sont ceux de `main` après T5.5** (PR #24) : `visuels/apparence.gd` (`Apparence`), `camera_arene.gd` (`CameraArene`), `effets.gd` (`Effets`), `decor.gd`, `plan_decor.gd`, `recadrages.gd` ; `visuels/arene_2d.gd` garde `Arene2D`.

**Intention :** lire la partie (texte net, boutique compacte, icônes, PV de la tour sur la tour, un effet et un son par arme, revenu et dégâts par seconde au tableau), démarrer plus vite (portées 500 / 750 / 1 000 / 1 250, ennemis ×1,5), et se rapprocher de « Tower Survivors » (armes illimitées, vagues mêlées, mana en bouclier, seulement les 24 ennemis du pack). Un jeu « beaucoup trop simple » (D16, D17) devient un jeu où la difficulté monte à chaque manche.

**Décisions de Phil reprises par les tâches :** D1 icônes · D2 armes sans plafond · D3 dézoom · D4 mini-carte avec les arènes des autres · D5 un effet par arme · D6 portées et vitesse · D7 24 ennemis du pack, plusieurs par vague · D8 trois classes de portée · D9 police Metamorphous · D10 revenu et dégâts par seconde au tableau · D11 PV sur la tour · D12 mana en bouclier et armes de mana · D13 boutique trop grande · D14 catégories arme, amélioration, revenu · D15 un son de tir par arme · D16 sans achat, la tour tombe au plus tard à la fin de la manche 3 · D17 PV et dégâts ennemis strictement croissants à chaque manche. Phil, le 25/11/2026 : « Ennemis corps à corps trop lents, portée des ennemis et de la tour trop courte. »

**Parallélisme :** trois sessions, chacune sur ses fichiers, plus une passe finale.

- **Simulation** (`sim/`, `data/`, `reseau/`, `app/source_vue.gd`, `app/source_locale.gd`), à lancer tout de suite, tâches à la suite : T8.1, T8.2, T8.3, T8.4 **avec T8.11** (décision de pilotage, pour le couplage ci-dessous), T8.5, T8.6, T8.7, T8.8, T8.9, T8.10. Un fichier (`sim/donnees.gd`, `sim/arene.gd`, `sim/tir.gd`, `data/ennemis.json`…) passe d'une tâche à la suivante ; entre sessions, chaque fichier n'a qu'une tâche propriétaire par moment.
- **Rendu** (`visuels/`, `sons/`, `assets/sons/`, `project.godot`) : T8.14 (attend Phil) et T8.15 (indépendante de la planche) dès que T8.1 est fusionnée, puis T8.12 et T8.13 dès que T8.4 et T8.11 sont fusionnées, puis T8.16 (après la validation de Phil). T8.11 est faite par la session Simulation.
- **Interface** (`ui/`, `i18n/`, `assets/polices/`, `app/reglages.gd`, `app/jeu.gd`) : T8.17, T8.18, T8.19, T8.20. Démarre quand T8.1 est fusionnée ; T8.20 attend T8.10 et T8.13.
- **Passe finale** : T8.21, quand tout est fusionné.
- **Dépendances :** T8.1 aucune · T8.2 T8.1 · T8.3 T8.1 · T8.4 T8.1 · T8.5 T8.4 · T8.6 T8.4 · T8.7 T8.1, T8.4 · T8.8 T8.4 à T8.7 · T8.9 T8.1 · T8.10 T8.2, T8.9 · T8.11 T8.1, T8.4 (PR commune avec T8.4) · T8.12 T8.1, T8.11 · T8.13 T8.1, T8.12 · T8.14 T8.1 (**attend Phil**) · T8.15 T8.1, T8.3 · T8.16 T8.3, T8.13, T8.14 validée par Phil · T8.17 aucune · T8.18 T8.1, T8.6, T8.9, T8.17 · T8.19 T8.1, T8.3, T8.13, T8.17, T8.18 · T8.20 T8.9, T8.10, T8.13, T8.17, T8.18, T8.19 · T8.21 toutes.
- **Couplage à respecter :** T8.4 change les identifiants des familles (24 au lieu de 8) et casse `Apparence.ENTITES` et `Effets.FAMILLES_EXPLOSIVES` tant que T8.11 n'est pas faite. Les deux ne vont vers `main` **qu'ensemble** : dans une seule PR de la session Simulation, qui touche alors `visuels/apparence.gd`, `visuels/effets.gd` et `assets/maison/` le temps de T8.11. Même règle pour T8.3 et T8.19 au sujet de `emplacements_armes` : T8.3 cesse de l'exiger mais laisse la clé dans `data/partie.json`, T8.18 et T8.19 cessent de la lire, T8.21 la supprime.
- **Fichiers partagés, un seul propriétaire :** `CREDITS.md` appartient à T8.21 (les autres tâches y écrivent leurs lignes dans leur rapport) ; `project.godot` (actions de touches) à T8.13 ; `ui/theme.gd` à l'Interface, `i18n/*.csv` à l'Interface (les textes visibles des autres sessions y passent par les clés existantes ou sont demandés à l'Interface dans le rapport).

**Choix du plan faute d'information dans la conception** (à relire par Phil) :

1. Les familles à venir sont portées par `VueArene.prochaines_familles` (par arène, donc juste en mode sans fin) et non par la vue globale ; `prochaine_famille` et `prochaine_armure` restent la majoritaire.
2. `Resultat.EMPLACEMENTS_PLEINS` reste dans l'énumération, inutilisé, pour ne pas renuméroter les codes du réseau ; `Resultat.ARMES_AU_MAXIMUM` s'ajoute à la fin (255 armes).
3. Les familles dérivent de 6 modèles × 4 paliers dans `data/ennemis.json` ; elles ont 4 noms originaux par modèle écrits dans les données (et non dans `i18n/`, comme les 8 familles d'aujourd'hui).
4. Les événements de tir et d'impact portent l'arme (`arme`, index du catalogue) : sans cela, ni l'effet ni le son propres à une arme ne sont possibles. Nouveau genre d'événement `absorption` pour l'éclat de mana.
5. Les 4 armes de mana sont 4 armes magiques existantes modifiées : il reste 30 armes, donc 30 signatures et 30 sons. La vitesse ×1,5 vaut aussi pour le convoi et le boss.
6. Les cartes de densité voyagent dans l'état global, une diffusion sur deux (1 Hz) ; l'arène regardée a son propre message et sa propre fréquence, calculée sur le budget restant (plancher 1 Hz).
7. Touches de caméra : flèches et touches physiques W A S D (Z Q S D sur un clavier AZERTY) ; dézoom au niveau 2,0 ; décalage de la vue limité à deux rayons d'apparition.
8. Le « robot de référence » de la passe d'équilibrage est le robot `bonne` de `tests/outils/strategies_joueur.gd`.

## Interfaces figées du lot 8 (créées par T8.1, T8.2, T8.9, T8.10, T8.13 ; citées partout)

```gdscript
# sim/types.gd — ajouts
enum Categorie { ARME, AMELIORATION, REVENU }
const NOMS_CATEGORIES: Array[String] = ["arme", "amelioration", "revenu"]  # clés JSON sans accent
enum ClassePortee { CORPS_A_CORPS, MOYENNE, LONGUE }
const NOMS_CLASSES_PORTEE: Array[String] = ["corps_a_corps", "moyenne", "longue"]
# Resultat : ARMES_AU_MAXIMUM ajouté à la fin ; EMPLACEMENTS_PLEINS reste, jamais renvoyé.
# sim/stats_tour.gd — ajouts
var mana_max_bonus: float = 0.0   # somme des améliorations « mana_max »
var mana_regen: float = 0.0       # points par seconde, somme des améliorations « mana_regen »
```

**`VueArene` (champs ajoutés, `SCHEMA` et `from_dict` à jour ; types stricts comme les autres) :**

```gdscript
var tour_mana: float; var tour_mana_max: float
var prochaines_familles: PackedInt32Array   # 0 à 3 index de Donnees.familles, majoritaire en premier ;
                                            # [index_convoi] pour le convoi ; vide si aucune
var prochaines_armures: PackedByteArray     # Types.Armure, même taille que prochaines_familles
# prochaine_famille == prochaines_familles[0] (ou -1), prochaine_armure == prochaines_armures[0]
# armes: Array[Dictionary] — jusqu'à 255 entrées (Protocole.MAX_ARMES)
# evenements : k ∈ "tir" | "impact" | "mort" | "absorption" ; champs facultatifs de tir et d'impact :
#   genre: int, statut: int (inchangés) et arme: int (index dans Donnees.ids_catalogue)
# absorption : {k, t, de: Vector2.ZERO, vers: Vector2.ZERO, type_degats: 0, rayon: 0.0}
```

**`VueGlobale` :** `joueurs[i]` gagne `dps: float` ; `var densites: Dictionary` (id de joueur `int` → `PackedByteArray` de 256 octets, 16 × 16 cases, ligne par ligne, une case = nombre d'ennemis saturé à 255, couvrant le carré de côté `2 × rayon_spawn` centré sur la tour) ; vide si non diffusée à ce tour.

**`Donnees` :** `familles: Array[Dictionary]` — 24 entrées, ordre modèle puis palier (`index = 4 × modèle + palier`), chacune `{id: "<modele>_<palier>", modele: String, palier: String, indice_palier: int, nom: String, armure: int, classe_portee: int, pv: float, vitesse: float, degats: float, portee_attaque: float, cadence_attaque: float, prime: int, manche_min: int, manche_entree: int, explose: bool}` ; le convoi est l'index 24 (`familles.size()`), le boss 25. `func categorie_de(id: String) -> int` (`Types.Categorie`). `Donnees.PORTEES = [500, 750, 1000, 1250]`.

**Schémas de données ajoutés ou changés :**

- `ennemis.json` : `{"modeles":[{"id":"torche","noms":["…","…","…","…"],"armure":"légère","classe_portee":"corps_a_corps","pv":45,"vitesse":75,"degats":4,"portee_attaque":40,"cadence_attaque":1.0,"prime":2,"manche_min":1,"explose":false,"raison_lenteur":""}],"paliers":[{"id":"jaune","manche_entree":1,"pv":1.0,"degats":1.0,"prime":1.0}],"convoi":{…},"boss":{…}}` ; modèles `torche, paysan, guerrier, tonneau, dynamite, archer` ; paliers `jaune, rouge, violet, bleu` (`manche_entree` strictement croissante, le premier à 1). Plus de champ `volant`.
- `armes.json` : `portee` ∈ {500, 750, 1000, 1250} ; champ facultatif `degats_par_mana_max` (ratio ≥ 0, 0 par défaut).
- `ameliorations.json` : champ obligatoire `categorie` ∈ `amelioration | revenu` ; `stat` ∈ + `mana_max`, `mana_regen`. Une arme est toujours de catégorie `arme`.
- `partie.json` : `tour.mana_max` (0) et `tour.mana_regen` (points par seconde, valeur de départ 1,0) ; `vagues: {"part_majoritaire": 0.6, "familles_min": 2, "familles_max": 3}` ; `reseau.hz_arene_regardee` (5), `reseau.hz_min_regardee` (1) ; `emplacements_armes` devient facultatif et ignoré (supprimé par T8.21).

**Réseau, protocole version 5 (T8.2) :** `Protocole.VERSION = 5` ; `MAX_ARMES = 255` ; octets d'un événement 12 → 14 (index de l'arme sur 2 octets, `0xFFFF` = aucune) ; état d'arène : mana, famille(s) suivante(s) ; état global : `dps` par joueur et densités facultatives ; `Msg.ETAT_ARENE_REGARDEE = 8` ; `Intention.REGARDER = 10` (arg : id du joueur, `-1` pour cesser).

```gdscript
static func encoder_etat_arene_regardee(id_joueur: int, v: VueArene, catalogue: PackedStringArray) -> PackedByteArray
static func decoder_etat_arene_regardee(b: PackedByteArray, catalogue: PackedStringArray) -> Dictionary  # {id: int, vue: VueArene} ou {}
```

**`SourceVue` (stubs en T8.1, réels en T8.10) :**

```gdscript
signal vue_regardee_recue(id_joueur: int, vue: VueArene)   # arène d'un autre, de son vivant
func regarder(id_joueur: int) -> void   # -1 : cesser ; sans effet en solo
func id_regarde() -> int                # -1 si aucune
# observer(id) reste réservé au joueur mort ; vue_arene_recue reste l'arène du joueur (ou observée)
```

**Simulation (T8.7, T8.9) :** `Arene.mana: float`, `Arene.mana_max() -> float`, `Arene.dps() -> float` (`FENETRE_DPS_S = 10.0`), `Arene.carte_densite() -> PackedByteArray` (256 octets, `DENSITE_COTE = 16`) ; `Partie.vue_globale(avec_densites: bool = false) -> VueGlobale` ; `Partie.observation_permise(id: int) -> bool` (faux tant que le joueur est en jeu) ; `Partie.vue_arene(demandeur, cible)` rend désormais toute arène existante, y compris à un joueur vivant. `Composition` (T8.6) : `sim/composition.gd`, `familles: PackedInt32Array`, `poids: PackedFloat32Array` (somme 1), `static func unique(famille: int) -> Composition`, `func majoritaire() -> int`, `func tirer(rng: RandomNumberGenerator) -> int` ; `Planning.tirer(manche: int) -> Composition` ; `Arene.demarrer_manche(numero: int, composition: Composition, mult: Dictionary) -> void`. `Serveur.frequence_arene_regardee(budget: float, reserve: float, octets_propre: int, hz_propre: float, octets_regardee: int, hz_max: float, hz_min: float) -> float`.

**Caméra (T8.13) :** `CameraArene` : `ZOOM_MIN = 0.25`, `ZOOM_DEFAUT = 1.0` (cercle d'apparition entier), `ZOOM_MAX = 2.0` (deux fois le cercle) ; `DEPLACEMENT_MAX_UNITES = 2600.0` ; `var decalage_unites: Vector2` (centre de la vue par rapport à la tour, unités de jeu) ; `var vitesse_relative: float = 1.0` ; `func deplacer(delta_unites: Vector2) -> void` ; `func centrer_sur(point_unites: Vector2) -> void` ; `func recentrer() -> void` (existante : remet aussi le décalage à zéro, garde le zoom) ; `func cadre_visible() -> Rect2` (zone libre vue par la caméra, unités de jeu). `Arene2D` : `func camera() -> CameraArene` ; `func montrer_arene(id_joueur: int, nom: String, numero: int) -> void` (`-1` : revenir à la sienne). Actions de touches dans `project.godot` : `camera_gauche`, `camera_droite`, `camera_haut`, `camera_bas`, `camera_recentrer` (Espace), `boutique_replier` (B).

**Signature d'arme (T8.14) :** `visuels/signatures_armes.gd`, `class_name SignaturesArmes` : `static func ids() -> PackedStringArray` (les 30 armes) ; `static func de(id_arme: String) -> Dictionary` `{projectile: String, couleur: Color, trainee: String, impact: String, statut: String, son: String}` (`{}` si inconnue) ; `son == "tir_" + id_arme`.

**Sons (T8.15) :** `CatalogueSons.id_tir(id_arme: String) -> String` (`"tir_<id>"`), `CatalogueSons.id_impact(type_degats: int) -> String` (`"impact_tranchant"`, `"impact_percant"`, `"impact_magique"`, `"impact_siege"`, `"impact_chaos"`), repli sur `tir` et `impact`.

## Points de vigilance du lot 8 (« Review Focus »), chacun pinglé par un test dans la tâche indiquée

1. Regarder un joueur qui n'existe pas, soi-même, un joueur parti ou qui quitte pendant qu'on le regarde, ou une partie à un seul joueur : arrêt propre, retour à sa propre arène, aucune erreur (T8.10).
2. Barres et chiffres avec `tour_pv_max` ou `tour_mana_max` à 0, PV au-dessus du maximum, valeurs non finies : ratio borné, jamais de division par zéro, barre de mana cachée sans mana (T8.12).
3. Paquets v5 forgés : plus de 3 familles suivantes, densité qui n'a pas 256 octets, index d'arme hors catalogue, type d'événement inconnu, 256 armes, tous tronqués à chaque longueur : `null` ou `{}`, jamais d'exception (T8.2).
4. Réglages d'un ancien fichier (échelle 1,25 ou 1,5 de l'ancienne liste), et les plus longs libellés réels (24 noms de familles, noms d'armes) à 75 % et à 125 % aux trois résolutions : rien ne déborde ni ne se coupe (T8.17).
5. Clic de mini-carte hors de la carte, à une coordonnée non finie, ou sur la vignette d'un joueur qui vient de partir : la vue ne bouge pas ; Espace revient toujours à sa tour (T8.20).

---

## Session « Simulation »

### Task 8.1 : Types, vues et schémas de données — `sonnet`

- [x] **Objectif :** figer en code les interfaces de simulation du lot : énumérations, `StatsTour`, champs de `VueArene` et de `VueGlobale`, schémas validés de `data/` (catégorie, mana, armes de mana, classes de portée, familles), stubs de `SourceVue`. Aucun comportement de jeu ne change encore : les données du jeu restent valides (les 8 familles et leurs portées actuelles sont migrées par T8.4 et T8.5, pas ici ; ici, seules les nouvelles clés facultatives et la catégorie des améliorations entrent).
- **Conception :** §6.3, §6.4, §6.7 (catégories), §6.8, §6.11, §7.
- **Fichiers :** `sim/types.gd`, `sim/stats_tour.gd`, `sim/vue_arene.gd`, `sim/vue_globale.gd`, `sim/donnees.gd` (catégorie, `degats_par_mana_max`, `mana_max`, `mana_regen`, clés `tour` et `vagues` et `reseau` ci-dessus, `emplacements_armes` facultatif), `data/ameliorations.json` (champ `categorie` des 40 améliorations), `data/partie.json`, `app/source_vue.gd` (stubs `regarder`, `id_regarde`, signal), `tests/outils/source_factice.gd` (même API, appels notés).
- **Lire :** `sim/vue_arene.gd` et `sim/vue_globale.gd` en entier ; `sim/donnees.gd` par `grep -n '_valider_\|_normaliser_'`.
- **Interfaces :** produit tout ce qui est sous « Interfaces figées » pour `Types`, `StatsTour`, `VueArene`, `VueGlobale`, `Donnees.categorie_de`, `SourceVue`. Les schémas d'`ennemis.json` et de `PORTEES` sont écrits par T8.4 et T8.5.
- **Tests :** `tests/unitaires/test_vues.gd`, `test_donnees.gd`, `test_contenu_donnees.gd`.
  - `test_vue_arene_aller_retour_avec_mana_et_prochaines_familles` : en boucle sur 0, 1, 2 et 3 familles, `from_dict(to_dict())` rend les mêmes `tour_mana`, `tour_mana_max`, `prochaines_familles`, `prochaines_armures`.
  - `test_vue_arene_refuse_plus_de_trois_familles_ou_des_armures_de_taille_differente` : `from_dict` rend `null` pour 4 familles, et pour 2 familles avec 3 armures.
  - `test_vue_arene_accepte_255_armes_et_les_evenements_absorption_et_arme` : 255 armes, un événement `absorption`, un tir avec `arme`.
  - `test_vue_globale_porte_dps_et_densites` : aller-retour ; une densité de 255 ou 257 octets, ou un id non entier, donne `null`.
  - `test_chaque_amelioration_a_une_categorie_valide` et `test_la_categorie_revenu_regroupe_exactement_les_stats_economiques` : en boucle sur les améliorations, `revenu` si et seulement si tous ses effets sont `revenu_fixe`, `revenu_croissant`, `revenu_mult`, `prime_mult` ou `bonus_elim` ; `relance_gratuite` et `marche_noir` sont `amelioration`.
  - `test_categorie_absente_ou_inconnue_est_refusee_en_nommant_le_fichier_et_le_champ` ; `test_categorie_de_rend_arme_pour_chaque_arme_et_la_categorie_des_donnees_sinon`.
  - `test_degats_par_mana_max_negatif_est_refuse` ; `test_le_mana_de_depart_est_zero_dans_les_donnees` (`tour.mana_max == 0`).
  - `test_la_source_factice_note_regarder_et_id_regarde`.
- **Vérif :** `T --filtre test_vues`, `test_donnees`, `test_contenu_donnees`, puis `tools/verifier.sh`.

### Task 8.2 : Protocole version 5 — `sonnet`

- [x] **Objectif :** une seule montée de version pour toutes les nouveautés réseau du lot : 255 armes, mana, familles suivantes, événements `absorption` et `arme`, `dps` et densités dans l'état global, état d'arène regardée, intention `REGARDER`. Décodage défensif et fuzz comme les versions précédentes.
- **Conception :** §6.3, §6.4, §6.8, §6.10, §6.11.
- **Fichiers :** `reseau/protocole.gd` ; tests `test_protocole.gd`, `test_protocole_resultat.gd`, `test_protocole_jeton.gd` (version).
- **Lire :** `reseau/protocole.gd` : `grep -n 'static func\|^const'`, puis `encoder_etat_arene` et `decoder_etat_arene` par plage.
- **Interfaces :** consomme `VueArene`, `VueGlobale` (T8.1). Produit `VERSION = 5`, `MAX_ARMES = 255`, `Msg.ETAT_ARENE_REGARDEE`, `Intention.REGARDER`, `encoder_etat_arene_regardee`, `decoder_etat_arene_regardee`, `TAILLE_FIXE` recalculée (un état vide a exactement cette taille). `Protocole.MAX_ARMES` doit égaler `Inventaire.ARMES_MAX` (T8.3).
- **Tests :**
  - `test_la_version_est_5_et_un_bonjour_de_version_4_est_refuse_avec_un_motif`.
  - `test_mana_et_prochaines_familles_traversent_le_protocole` : en boucle sur 0 à 3 familles.
  - `test_255_armes_s_encodent_et_256_sont_refusees` : l'encodeur rend un paquet vide pour 256.
  - `test_un_evenement_absorption_traverse_et_un_type_inconnu_est_refuse` ; `test_un_evenement_porte_l_arme_et_sans_arme_il_n_a_pas_la_cle` (index du catalogue, `0xFFFF` à l'encodage de l'absence).
  - `test_l_etat_global_porte_dps_et_densites` ; `test_un_etat_global_sans_densites_les_decode_vides`.
  - `test_etat_arene_regardee_aller_retour` et `test_intention_regarder_aller_retour_avec_moins_un`.
  - `test_un_etat_de_mille_ennemis_255_armes_et_40_ameliorations_tient_sous_max_taille`.
  - **Review Focus 3 :** `test_aucun_paquet_v5_forge_ne_leve_d_exception` : pour chaque décodeur de v5, tous les préfixes d'un paquet valide, puis 2 000 tableaux d'octets tirés d'une graine fixe, rendent `null` ou `{}` ; plus de 3 familles, densité de 255 octets, index d'arme hors catalogue, type d'événement inconnu, id de joueur regardé hors 0 à 255.
- **Vérif :** `T --filtre test_protocole`, puis `tools/verifier.sh`.

### Task 8.3 : Armes illimitées et arme dans les événements — `sonnet`

- [x] **Objectif :** plus de plafond de huit armes (D2) : `Inventaire.ajouter` n'échoue plus pour cette raison, la boutique non plus ; au-delà de 255 armes l'achat est refusé proprement sans débit (`ARMES_AU_MAXIMUM`). Les événements de tir et d'impact portent l'arme. Le pas reste sous 5 ms avec 40 armes face à 1 000 ennemis. Les tests qui figeaient « la 9e arme refusée » sont inversés, pas supprimés.
- **Conception :** §6.3, §6.5 (l'arme dans l'événement), §6.5 bis.
- **Fichiers :** `sim/inventaire.gd`, `sim/boutique.gd`, `sim/tir.gd`, `sim/arene.gd`, `tests/outils/strategies_joueur.gd` si un robot suppose huit armes ; tests `test_inventaire.gd`, `test_boutique.gd`, `test_arene_boutique.gd`, `test_arene_charge.gd`, `test_tir.gd`, `test_evenements_genre.gd`.
- **Lire :** `sim/inventaire.gd` (134 lignes), `sim/boutique.gd` `acheter`, `sim/tir.gd` `_evenement` et `_choisir` ; les trois tests cités par `grep -n 'EMPLACEMENTS_PLEINS\|huit'`.
- **Interfaces :** produit `Inventaire.ARMES_MAX: int = 255` ; plus aucun renvoi de `EMPLACEMENTS_PLEINS` ; événements `tir` et `impact` avec `arme: int` (index dans `Donnees.ids_catalogue`) ; `emplacements_armes` n'est plus lu par `sim/`.
- **Tests :**
  - `test_la_neuvieme_et_la_quarantieme_arme_sont_acceptees` (inverse `test_inventaire.gd:69`, `test_boutique.gd:267`, `test_arene_boutique.gd:173` et `:181`).
  - `test_la_256e_arme_est_refusee_sans_debit_avec_armes_au_maximum` : l'or est intact, l'inventaire a 255 armes.
  - `test_emplacements_pleins_n_est_jamais_renvoye` : 1 à 40 achats d'armes.
  - `test_la_vente_de_la_40e_arme_rend_50_pour_cent_de_son_prix`.
  - `test_la_vue_porte_les_40_armes_avec_leur_recharge`.
  - `test_chaque_tir_et_chaque_impact_portent_l_index_de_leur_arme` : en boucle sur les 30 armes, un ennemi à portée ; une mort n'a pas de clé `arme`.
  - `test_quarante_armes_contre_mille_ennemis_sous_5_ms_par_pas` (dans `test_arene_charge.gd`) : 40 armes (les 30 en boucle, puis 10 de plus), 1 000 ennemis, moyenne sur 200 pas sous 5 ms. Si le seuil n'est pas tenu, optimiser la recherche de cible de `sim/tir.gd` (grille) plutôt que relever le seuil.
- **Vérif :** `T --filtre test_inventaire`, `test_arene_charge`, puis `tools/verifier.sh`.

### Task 8.4 : Les 24 ennemis du pack, classes de portée, explosion du Tonneau, retrait du vol — `sonnet`

- [x] **Objectif :** `data/ennemis.json` passe à 6 modèles × 4 paliers de couleur (24 familles) ; la classe de portée suit le modèle (corps à corps ≤ 60 ; Dynamite 350 ; Archer 650) ; le Tonneau explose au contact (dégâts sur la tour puis disparaît, sans prime) ; le vol (`volant`, mines et pièges qui l'ignorent) disparaît des données et de `sim/`. Vitesses : **les valeurs d'aujourd'hui** (Torche 75, Paysan 60, Guerrier 35, Tonneau 25, Dynamite 65, Archer 50 ; convoi 45, boss 35), T8.5 les multiplie. Valeurs de départ des autres champs : reprendre celles des familles actuelles (Torche ← rôdeur de suie, Paysan ← pillard de brume, Guerrier ← heaume d'argile, Tonneau, Dynamite ← artificier, Archer) ; paliers de départ pv ×1 / 2,5 / 6 / 15, dégâts ×1 / 1,5 / 2,2 / 3, prime ×1 / 1,6 / 2,5 / 4, entrées aux manches 1 / 8 / 16 / 24, Archer `manche_min` 5, les autres 1 : T8.8 et T8.21 les règlent. La brute de forge disparaît (second guerrier).
- **Conception :** §6.1 (tableau modèle → rôle), §6.2, §6.12 (leviers).
- **Fichiers :** `data/ennemis.json`, `sim/donnees.gd` (`_valider_ennemis`, construction de `familles`), `sim/ennemis.gd` (`volant` retiré, `explose`), `sim/arene.gd` (`_apparaitre`, explosion), `sim/tir.gd` (plus d'argument `au_sol` ni `volants`) ; tests `test_donnees.gd`, `test_ennemis.gd`, `test_ennemis_statuts.gd`, `test_tir.gd`, `test_tir_effets.gd`, `test_arene.gd`, `test_vues.gd` (familles `% 24`), nouveau `test_ennemis_portee.gd`.
- **Lire :** `sim/donnees.gd` `_valider_ennemis` et `_normaliser_famille` ; `sim/ennemis.gd` `ajouter`, `avancer` ; `sim/arene.gd` `_apparaitre`, `_pas_tour_et_ennemis` ; `grep -n volant -r sim tests`.
- **Interfaces :** consomme T8.1. Produit les 24 familles (schéma figé ci-dessus) ; `Ennemis.ajouter(famille: int, position: Vector2, pv: float, vitesse: float, degats: float, portee: float, cadence: float, prime: int, armure: int, explose: bool = false) -> int` ; `Ennemis.avancer(...)` rend en plus `"explosions": PackedInt32Array` (indices).
- **Tests :**
  - `test_vingt_quatre_familles_six_modeles_quatre_paliers` : `familles.size() == 24`, ids `<modele>_<palier>` uniques, ordre modèle puis palier, `indice_palier` ; convoi = index 24, boss = 25.
  - `test_les_noms_des_24_familles_sont_distincts_et_non_vides`.
  - `test_chaque_modele_a_son_role` : en boucle, Torche légère, Paysan moyenne, Guerrier lourde, Tonneau fortifiée, tous corps à corps ; Dynamite sans armure, moyenne ; Archer moyenne, longue.
  - `test_la_classe_de_portee_est_coherente_avec_la_portee_d_attaque` : corps à corps ⇒ `portee_attaque ≤ 60` ; moyenne ⇒ 350 ; longue ⇒ 650 (en boucle sur les 24).
  - `test_la_force_croit_avec_le_palier` : par modèle, pv, dégâts et prime strictement croissants jaune → rouge → violet → bleu ; vitesse identique ; `manche_entree` strictement croissante.
  - `test_aucun_champ_volant_dans_les_donnees_ni_la_simulation` : absent de `ennemis.json` et de `Ennemis` ; `test_les_mines_et_les_pieges_touchent_tous_les_ennemis` (inverse le test des volants de `test_tir_effets.gd`).
  - `test_les_donnees_refusent_un_modele_ou_un_palier_invalide` : classe de portée inconnue, palier en double, `manche_entree` non croissante, nombre de noms différent de 4 ; message nommant `ennemis.json` et le champ.
  - `test_la_dynamite_s_arrete_a_350_et_l_archer_a_650` : distance à la tour égale à la portée à `TOLERANCE_ARRET` près après assez de pas.
  - `test_le_tonneau_explose_au_contact` : dégâts à la tour = dégâts × multiplicateur après armure, une seule fois ; ennemi retiré ; or et éliminations inchangés ; événement `mort` à sa position.
  - `test_un_tonneau_tue_avant_le_contact_rapporte_sa_prime` ; `test_l_explosion_peut_etre_esquivee_mais_le_tonneau_disparait_quand_meme` ; `test_l_explosion_ne_declenche_pas_les_epines`.
  - `test_mille_tonneaux_au_contact_sous_5_ms_par_pas`.
- **Vérif :** `T --filtre test_donnees`, `test_ennemis`, `test_tir`, puis `tools/verifier.sh`. À fusionner avec T8.11.

### Task 8.5 : Portées des armes et vitesse des ennemis ×1,5 — `sonnet`

- [x] **Objectif :** paliers de portée des armes 500 / 750 / 1 000 / 1 250 (correspondance position à position avec 300 / 600 / 900 / 1 200), vitesse de toutes les familles ×1,5 (convoi et boss compris). Phil, le 25/11/2026 : « Ennemis corps à corps trop lents, portée des ennemis et de la tour trop courte. » Le test des vitesses est écrit d'abord et échoue sur les valeurs de T8.4.
- **Conception :** §6.2, §6.1 (portées), §6.12 (valeurs interdites).
- **Fichiers :** `data/armes.json`, `data/ennemis.json`, `sim/donnees.gd` (`PORTEES`) ; tests `test_donnees.gd`, `test_contenu.gd`, nouveau `test_vitesses_ennemis.gd`.
- **Lire :** `grep -n '"portee"' data/armes.json`, `grep -n 'PORTEES' -r sim tests`.
- **Interfaces :** produit `Donnees.PORTEES = [500, 750, 1000, 1250]`. Vitesses finales : Torche 112,5 · Paysan 90 · Guerrier ≥ 52,5 · Tonneau ≥ 52,5 · Dynamite 97,5 · Archer 75 · convoi 67,5 · boss 52,5 (le Guerrier à 52,5 exactement, le Tonneau égal ou plus rapide).
- **Tests :**
  - `test_les_portees_d_armes_sont_500_750_1000_1250` : en boucle sur les 30 armes ; chacune des 4 valeurs est utilisée ; `test_une_ancienne_portee_est_refusee_en_nommant_armes_json_et_portee`.
  - `test_chaque_famille_au_corps_a_corps_va_au_moins_aussi_vite_qu_avant_fois_1_5` : constante `VITESSES_AVANT` du test (Torche 75, Paysan 60, Guerrier 35, Tonneau 25), en boucle sur les 24 familles.
  - `test_toute_famille_le_convoi_et_le_boss_vont_au_moins_1_5_fois_plus_vite_qu_avant` (Dynamite 65, Archer 50, convoi 45, boss 35).
  - `test_le_guerrier_reste_lent_mais_plus_rapide_qu_avant` : plus rapide que 35, plus lent que les trois autres modèles au corps à corps.
  - `test_aucune_famille_n_est_la_plus_lente_sans_raison_ecrite` : parmi les 6 modèles et le convoi, le plus lent est le seul à porter une `raison_lenteur` non vide (le Guerrier) ; le Tonneau n'est pas plus lent que lui.
  - `test_un_ennemi_avance_de_vitesse_fois_multiplicateur_par_seconde` (sim inchangée).
- **Vérif :** `T --filtre test_vitesses_ennemis`, `test_contenu`, puis `tools/verifier.sh`.

### Task 8.6 : Vagues mêlées — `sonnet`

- [x] **Objectif :** `Planning` tire pour chaque manche 2 ou 3 familles dont une majoritaire (60 % des apparitions, le reste partagé), parmi celles qu'autorisent les paliers de couleur et l'Archer (manche 5). Le budget (nombre d'apparitions, cadence) ne change pas, seule la composition. Même tirage pour tous les joueurs (graine de partie), jamais la même famille majoritaire deux manches de suite. La vue annonce les familles et leurs armures. Mode sans fin : tous les paliers restent dans le tirage.
- **Conception :** §6.1 (vagues mêlées, budget, annonce), §6.11.
- **Fichiers :** `sim/composition.gd` (nouveau), `sim/planning.gd`, `sim/arene.gd` (`demarrer_manche`, `_apparaitre`), `sim/partie.gd`, `sim/joueur_partie.gd`, `sim/donnees.gd` (clé `vagues`) ; tests `test_planning.gd`, `test_partie.gd`, `test_partie_sans_fin.gd`, `test_arene.gd`, `test_equilibrage.gd`.
- **Lire :** `sim/planning.gd` (69 lignes), `sim/partie.gd` `_commencer_manche`, `_famille_annoncee`, `vue_arene` ; `sim/arene.gd` `demarrer_manche`, `_apparaitre`.
- **Interfaces :** `Composition`, `Planning.tirer(manche) -> Composition`, `Arene.demarrer_manche(numero, composition, mult)` (figées plus haut) ; `VueArene.prochaines_familles` et `prochaines_armures` remplis (vides après le boss et en victoire).
- **Tests :**
  - `test_chaque_manche_a_deux_ou_trois_familles_distinctes_dont_une_majoritaire` : manches 1 à 60 × graines 1 à 20.
  - `test_les_poids_valent_60_pour_la_majoritaire_et_le_reste_est_partage` (somme 1 à 1e-6 près).
  - `test_jamais_la_meme_majoritaire_deux_manches_de_suite`, convoi intercalé compris.
  - `test_l_archer_n_apparait_qu_a_partir_de_la_manche_5` : aucune composition des manches 1 à 4 ne le contient ; il apparaît au moins une fois ensuite sur 20 graines.
  - `test_un_palier_n_entre_qu_a_sa_manche_d_entree` : en boucle sur les 4 paliers.
  - `test_le_tirage_est_le_meme_pour_tous_les_joueurs` : 3 joueurs, mêmes `prochaines_familles` à chaque manche.
  - `test_le_tirage_est_reproductible_avec_la_meme_graine`.
  - `test_les_apparitions_suivent_les_poids_en_melange_et_non_par_blocs` : 600 apparitions d'une composition 0,6 / 0,4, graine fixe : part de la majoritaire dans 0,6 ± 0,06 et plus de 100 changements de famille.
  - `test_le_budget_de_la_manche_est_inchange` : même nombre d'apparitions sur 30 s qu'avec `spawn_intervalle_depart − spawn_baisse_par_manche × (manche − 1)` (plancher 0,1 s).
  - `test_le_convoi_garde_sa_composition_unique_et_le_boss_n_en_a_pas`.
  - `test_le_mode_sans_fin_garde_les_24_familles_possibles_et_les_multiplicateurs_continuent` : manche 40.
  - `test_la_vue_annonce_les_familles_et_leurs_armures` : pendant `PREPARATION` et `MANCHE`, 1 à 3 entrées, `prochaine_famille` égale à la première.
- **Vérif :** `T --filtre test_planning`, `test_partie`, puis `tools/verifier.sh`.

### Task 8.7 : Mana, bouclier de la tour — `sonnet`

- [ ] **Objectif :** la mana absorbe les coups à la place des PV (ordre : esquive, armure, mana, PV ; 1 point absorbe 1 point) et se régénère chaque seconde ; la tour démarre à 0 de mana maximale ; nouvelles améliorations de mana ; 4 armes magiques font des dégâts selon la mana maximale.
- **Conception :** §6.4.
- **Fichiers :** `sim/arene.gd`, `sim/inventaire.gd`, `sim/tir.gd`, `data/ameliorations.json` (au moins 2 `mana_max`, 1 `mana_regen`, catégorie `amelioration`), `data/armes.json` (`degats_par_mana_max` sur 4 armes magiques existantes), `data/partie.json` (`tour.mana_regen`) ; tests `test_arene_tour.gd`, `test_inventaire.gd`, `test_tir.gd`, `test_contenu.gd`.
- **Lire :** `sim/arene.gd` `_pas_tour_et_ennemis`, `synchroniser`, `vue` ; le test de rendement par rareté de `test_contenu.gd` (`grep -n 'rendement'`).
- **Interfaces :** produit `Arene.mana`, `Arene.mana_max()`, l'événement `absorption`, `VueArene.tour_mana` et `tour_mana_max`. Un maximum qui monte soigne du même montant en mana (comme les PV), sinon la mana reste à 0 et ne sert à rien.
- **Tests :**
  - `test_la_tour_demarre_a_zero_de_mana_et_de_mana_maximale`.
  - `test_la_mana_absorbe_un_pour_un_apres_l_esquive_et_l_armure` : armure 10 (réduction 1/3), coup de 30 → 20 après armure ; mana 15 → PV −5, mana 0 ; esquive certaine → mana et PV intacts.
  - `test_la_mana_ne_descend_pas_sous_zero_et_le_reste_va_aux_pv`.
  - `test_la_mana_se_regenere_chaque_seconde_jusqu_au_maximum`.
  - `test_une_amelioration_de_mana_maximale_ajoute_la_meme_quantite_de_mana`.
  - `test_les_epines_se_declenchent_meme_quand_la_mana_absorbe_tout` ; `test_l_explosion_du_tonneau_est_absorbee_par_la_mana`.
  - `test_chaque_absorption_emet_un_evenement_et_la_vue_porte_la_mana` : en boucle sur les valeurs de coup.
  - `test_une_arme_de_mana_ajoute_ratio_fois_mana_maximale_aux_degats_de_base` : dégâts 100, ratio 0,5, mana maximale 40, ennemi sans armure → 120 avant critique ; sans mana, 100.
  - `test_au_moins_quatre_armes_de_mana_toutes_magiques_et_il_reste_30_armes`.
  - `test_le_rendement_par_piece_d_or_croit_avec_la_rarete_mana_comprise` : le test existant, avec une mana maximale de référence de 100 écrite dans le test.
  - `test_la_mana_est_propre_a_chaque_arene`.
- **Vérif :** `T --filtre test_arene_tour`, `test_contenu`, puis `tools/verifier.sh`.

### Task 8.8 : Rampe de difficulté — sans achat, la tour tombe avant la fin de la manche 3 (D16), montée continue (D17) — `sonnet`

- [ ] **Objectif :** relever la rampe de `data/difficulte.json` (aujourd'hui dégâts ×0,03 aux manches 1 à 4 et PV à ×1 des manches 1 à 10) pour que, **sans aucun achat, la tour tombe au plus tard à la fin de la manche 3**, et pour que **PV et dégâts des ennemis croissent strictement d'une manche à la suivante**, de la manche 1 à la 30 puis en mode sans fin (`apres_table`). Les paliers de couleur s'y ajoutent sans la remplacer. À régler **après** T8.4 à T8.7 (portées, vitesse ×1,5, 24 familles, vagues mêlées, mana), sur les données finales de ces tâches. Leviers : la rampe de `difficulte.json`, puis les paliers (`manche_entree`, multiplicateurs), les poids de familles ; jamais les valeurs interdites de §6.12. L'autre borne reste gardée par la passe finale : un robot qui achète ne meurt pas avant la manche 20.
- **Conception :** §6.12 (« Seuil bas », « Montée continue »), D16, D17.
- **Fichiers :** `data/difficulte.json`, `data/ennemis.json` (paliers, si la rampe seule ne suffit pas), `tests/unitaires/test_equilibrage_partie.gd`, `test_planning.gd`.
- **Lire :** `docs/equilibrage.md` (cibles et réglages d'avant), `tests/outils/simulation_equilibrage.gd` `jouer`, `Planning.multiplicateurs`.
- **Interfaces :** consomme `SimulationEquilibrage.jouer(d, graine, strategie, manche_arret) -> Dictionary` (`manche`, `victoire`, `duree_s`) et `Planning.multiplicateurs(donnees, manche, temps) -> Dictionary` (`pv`, `degats`, …).
- **Tests :**
  - `test_sans_achat_la_tour_tombe_avant_la_fin_de_la_manche_3` : robot `passive`, graines fixes 1 à 10 en boucle, `r["manche"] <= 3` et pas de victoire. Remplace `test_un_joueur_passif_tombe_avant_la_manche_huit_sur_chaque_graine`.
  - `test_pv_et_degats_des_ennemis_augmentent_a_chaque_manche` : en boucle sur les manches 1 à 40 (le mode sans fin sur 10 manches au-delà de 30), `pv(n + 1) > pv(n)` et `degats(n + 1) > degats(n)` avec `Planning.multiplicateurs`, au temps 0 puis au temps de début de chaque manche.
  - `test_la_force_d_une_meme_famille_augmente_a_chaque_manche` : pour chacune des 24 familles, pv et dégâts effectifs (famille × palier × difficulté) strictement croissants sur les manches où elle est autorisée.
  - `test_un_robot_qui_achete_ne_tombe_pas_avant_la_manche_6` : robots `raisonnable` et `bonne`, graines 1 à 10 (garde contre une rampe trop dure ; seuil à régler avec la passe finale).
  - Les tests existants `test_un_joueur_raisonnable_atteint_au_moins_la_manche_douze_en_mediane` restent verts.
- **Vérif :** `T --filtre test_equilibrage_partie`, `test_planning`, puis `tools/verifier.sh`. Rapporter les manches atteintes par robot et par graine.

### Task 8.9 : DPS, carte de densité et observation d'une autre arène de son vivant — `sonnet`

- [ ] **Objectif :** côté simulation, les trois données dont l'interface a besoin : dégâts par seconde (moyenne glissante des 10 dernières secondes, épines comprises), carte de densité 16 × 16 des ennemis, et accès à toute arène existante pour un joueur vivant (mais `observer`, qui remplace sa propre vue, reste réservé aux morts).
- **Conception :** §6.8, §6.10.
- **Fichiers :** `sim/arene.gd`, `sim/partie.gd`, `sim/joueur_partie.gd` ; tests `test_arene.gd`, `test_partie.gd`, `test_vues.gd`, nouveaux `test_dps.gd` et `test_densite.gd`.
- **Lire :** `sim/arene.gd` (attributs et `avancer`), `sim/partie.gd` `vue_arene`, `vue_globale`, `_enregistrer`.
- **Interfaces :** produit `Arene.dps()`, `Arene.carte_densite()`, `Partie.vue_globale(avec_densites)`, `Partie.observation_permise(id)`, `VueGlobale.joueurs[i].dps`.
- **Tests :**
  - `test_le_dps_est_la_moyenne_glissante_des_10_dernieres_secondes` : une arme de 10 dégâts toutes les 1,0 s sur un ennemi de PV énormes sans armure : 10 ± 1 après 10 s ; avant 10 s on divise par le temps écoulé.
  - `test_les_degats_hors_de_la_fenetre_ne_comptent_plus` : un coup à t = 0, plus rien ensuite, `dps() == 0` à t = 10,5 s.
  - `test_les_epines_comptent_dans_le_dps` ; `test_le_dps_vaut_zero_au_depart_et_n_est_jamais_nan`.
  - `test_la_vue_globale_porte_le_dps_de_chaque_joueur` (2 joueurs).
  - `test_la_carte_de_densite_fait_256_octets_une_case_par_16_sur_16` : un ennemi → une seule case non nulle, valeur 1 ; ennemi en (0, 0) → case du centre ; positions à ± `rayon_spawn` → cases de bord.
  - `test_une_case_sature_a_255` (300 ennemis dans la même case) ; `test_la_somme_des_cases_egale_le_nombre_d_ennemis_sans_saturation` (1 000 ennemis, graine fixe).
  - `test_un_joueur_vivant_voit_une_autre_arene_mais_ne_peut_pas_l_observer` : inverse le refus de `Partie.vue_arene` ; `observation_permise` faux en jeu, vrai après élimination, victoire ou départ.
  - `test_la_vue_globale_ne_calcule_les_densites_que_sur_demande`.
- **Vérif :** `T --filtre test_dps`, `test_densite`, `test_partie`, puis `tools/verifier.sh`.

### Task 8.10 : Réseau : arène regardée, densités, `SourceVue` réelle, budget — `sonnet`

- [ ] **Objectif :** le serveur envoie, sur demande (`REGARDER`), l'arène d'un autre joueur à 5 Hz en plus de la sienne (15 Hz), et les densités à 1 Hz ; le client et la source locale exposent `regarder`, `id_regarde` et `vue_regardee_recue` ; la mesure de T3.3 est refaite à 8 clients et 1 000 ennemis, en regardant : **50 000 o/s par client** tenus, sinon la fréquence de l'arène regardée baisse (plancher 1 Hz).
- **Conception :** §6.10 (réseau), §6.11, §3 (budget).
- **Fichiers :** `reseau/serveur.gd`, `reseau/client.gd`, `reseau/canal.gd` (RPC `rpc_etat_arene_regardee`, non fiable), `app/source_locale.gd`, `tests/outils/source_factice.gd` ; tests `test_serveur.gd`, `test_client.gd`, `test_serveur_debit.gd`, `test_source_locale.gd`, `tests/integration/test_multijoueur.gd`.
- **Lire :** `reseau/serveur.gd` `_envoyer_etats`, `_frequence`, `_observer`, `frequence_arene` ; `reseau/client.gd` réception des états ; `tests/unitaires/test_serveur_debit.gd`.
- **Interfaces :** consomme T8.2 et T8.9. Produit `Serveur.frequence_arene_regardee(...)` (fonction pure), `Client.regarder`, `Client.id_regarde`, le cache des dernières densités du client (une `VueGlobale` reçue sans densités porte les dernières).
- **Tests :**
  - `test_regarder_une_autre_arene_envoie_ses_etats_a_5_hz_en_plus_des_siens` : 2 clients, A vivant regarde B, 2 s de pas : environ 30 états propres et 10 de B (± 1), l'arène propre inchangée.
  - `test_regarder_soi_meme_ou_un_inconnu_est_refuse_et_moins_un_arrete` : `INDICE_INVALIDE` ; après `-1` plus aucun envoi.
  - **Review Focus 1 :** `test_regarder_un_joueur_qui_quitte_ramene_a_sa_propre_arene` : le serveur remet `regarde` à −1 sans erreur, le client reçoit un `vue_regardee_recue` jamais obsolète ; partie à un seul joueur : `regarder` n'a rien à regarder, sans erreur.
  - `test_les_densites_arrivent_a_1_hz_dans_la_vue_globale` et `test_le_client_garde_les_dernieres_densites_entre_deux_envois`.
  - `test_frequence_arene_regardee_en_boucle_sur_les_budgets` : budget large → `hz_max` ; budget nul → `hz_min` ; monotone croissante avec le budget restant.
  - `test_le_budget_de_50000_octets_par_seconde_tient_a_8_clients_et_1000_ennemis_en_regardant` : octets par client sur 10 s, états propres, arène regardée, états globaux et densités compris, ≤ 50 000 ; la fréquence regardée mesurée est écrite en commentaire du test.
  - `test_un_etat_d_arene_regardee_recu_sans_l_avoir_demande_est_ignore` ; `test_solo_regarder_est_sans_effet`.
  - `test_l_intention_regarder_est_encodee_avec_l_id_ou_moins_un`.
- **Vérif :** `T --filtre test_serveur`, `test_client`, `test_serveur_debit`, puis `tools/verifier.sh` (étape `integration` comprise).

---

## Session « Rendu »

### Task 8.11 : Sprites des 24 ennemis et retrait de la guêpe — `sonnet`

- [x] **Objectif :** `Apparence.ENTITES` couvre les 24 familles (modèle du pack, couleur du palier : jaune → `Yellow`, rouge → `Red`, violet → `Purple`, bleu → `Blue` ; Torche `torch`, Paysan `pawn`, Guerrier `warrior`, Tonneau `barrel` ×1,5, Dynamite `tnt`, Archer `archer`), le convoi et le boss gardent leurs sprites ; la guêpe maison et tout ce qui vole disparaissent. L'explosion des familles à explosion suit le modèle, plus la liste de 2 ids.
- **Conception :** §6.1, §4 (aucun sprite d'ennemi dessiné par nous).
- **Fichiers :** `visuels/apparence.gd` (`MODELES`, `ENTITES`), `visuels/recadrages.gd` (régénéré par `tools/generer_recadrages.gd`), `tools/generer_recadrages.gd`, `visuels/arene_2d.gd` (`VITESSE_VOL`, flottement), `visuels/effets.gd` (`FAMILLES_EXPLOSIVES` dérivée des modèles `barrel` et `tnt`), suppression de `assets/maison/` et de `tools/dessiner_guepe.gd` ; tests `test_apparence.gd`, `test_arene_2d.gd`, `test_effets.gd`, `test_recadrages.gd`, `test_garde_ressources.gd`, suppression de `test_sprite_guepe.gd`. `CREDITS.md` : voir T8.21 (la ligne de la guêpe y est retirée).
- **Lire :** `grep -n 'guepe\|volant\|flottement' -r visuels tools tests`, `visuels/apparence.gd` `ENTITES` et `entree`.
- **Interfaces :** consomme les 24 familles de T8.4 (`Donnees.familles[i].modele`, `.palier`).
- **Tests :**
  - `test_chaque_famille_le_convoi_et_le_boss_ont_une_entree_dans_l_ordre_des_index` : 24 + convoi + boss.
  - `test_les_24_entrees_se_distinguent_par_modele_et_couleur` ; `test_la_couleur_de_l_entree_suit_le_palier` (en boucle sur les 24).
  - `test_chaque_entree_designe_une_feuille_qui_existe_et_se_decoupe_juste` (en boucle sur les 24) ; `test_chaque_feuille_a_ses_boites_de_recadrage`.
  - `test_aucune_trace_de_la_guepe` : pas de `guepe` dans `visuels/`, `tools/`, `assets/maison/` (dossier absent), aucune entité n'a `volant` ni `flottement`.
  - `test_chaque_famille_s_affiche_dans_une_vue_a_25_familles` : une vue avec une instance de chaque famille, convoi et boss compris, sans erreur ; `nombre_instances_visibles` par famille.
  - `test_un_tonneau_qui_explose_au_contact_declenche_l_explosion_et_une_dynamite_aussi` (événement `mort` aux positions voulues).
- **Vérif :** `T --filtre test_apparence`, `test_arene_2d`, `test_garde_ressources`, puis `tools/verifier.sh`. À fusionner avec T8.4.

### Task 8.12 : Barres de PV et de mana au-dessus de la tour, barre du boss, éclat d'absorption — `sonnet`

- [ ] **Objectif :** une barre de PV (vert, rouge sous 30 %) avec « x / y » au-dessus de la tour, une barre de mana bleue dessous (cachée tant que la mana maximale est nulle), une barre de PV au-dessus du boss, un éclat bleu sur la tour quand la mana absorbe un coup. Lisibles au zoom le plus lointain.
- **Conception :** §6.4 (rendu), §6.7 (barres), D11.
- **Fichiers :** `visuels/barres.gd` (nouveau, `class_name BarresArene`, dessin par code, aucune image), `visuels/arene_2d.gd`, `visuels/effets.gd` (effet `absorption`) ; tests nouveau `test_barres.gd`, `test_arene_2d.gd`, `test_effets.gd`.
- **Lire :** `visuels/arene_2d.gd` `_assurer_construite`, `afficher`, `_afficher_echantillon` (par plage) ; `visuels/effets.gd` `ajouter`, `_statut`.
- **Interfaces :** consomme `VueArene.tour_pv`, `tour_pv_max`, `tour_mana`, `tour_mana_max`, l'événement `absorption`. Produit `BarresArene` : `static func couleur_pv(ratio: float) -> Color` (`ThemeJeu.JAUGE_PLEINE` au-dessus de `SEUIL_PV_BAS = 0.3`, `ThemeJeu.JAUGE_BASSE` en dessous), `func afficher(vue: VueArene) -> void`, `ratio_pv()`, `ratio_mana()`, `texte_pv() -> String`, `barre_mana_visible() -> bool`, `barre_boss_visible() -> bool`, `ratio_boss() -> float`.
- **Tests :**
  - `test_la_barre_de_pv_est_verte_au_dessus_de_30_pour_cent_et_rouge_en_dessous` : 1,0 · 0,31 vert ; 0,30 · 0,1 rouge.
  - `test_les_chiffres_sont_x_sur_y_avec_les_separateurs_de_milliers` : 1 234 / 1 500 par `Nombres.groupe`.
  - **Review Focus 2 :** `test_les_ratios_sont_bornes_et_sans_division_par_zero` : en boucle sur `tour_pv_max` ∈ {0, 1, 1000}, PV ∈ {−5, 0, 500, 2000, NaN, INF} et la même grille pour la mana : ratio dans [0, 1], jamais NaN ; barre de mana cachée si `tour_mana_max == 0`.
  - `test_les_barres_suivent_la_vue_a_chaque_pas`.
  - `test_la_taille_a_l_ecran_reste_lisible_du_zoom_le_plus_proche_au_plus_lointain` : largeur de la barre entre 60 et 400 px aux niveaux 0,25, 1,0 et 2,0.
  - `test_la_barre_du_boss_apparait_avec_le_boss_suit_ses_pv_et_disparait_avec_lui` : ratio 0,5 ± 1/255.
  - `test_un_evenement_absorption_cree_un_eclat_bleu_dans_le_plafond` : une forme vivante, durée ≤ `DUREE_MAX`, plafond de 200 tenu avec 300 absorptions.
- **Vérif :** `T --filtre test_barres`, `test_effets`, `test_arene_2d`, puis `tools/verifier.sh`.

### Task 8.13 : Caméra libre, dézoom et arène regardée — `sonnet`

- [ ] **Objectif :** déplacement de la vue aux flèches et aux touches physiques W A S D (Z Q S D en AZERTY), **Espace** recentre sur la tour, dézoom jusqu'à deux fois le cercle d'apparition, décalage limité à deux rayons ; `Arene2D` sait afficher l'arène d'un autre joueur (vue regardée), `Espace` y met fin. Déclare aussi l'action `boutique_replier` (B) pour T8.19.
- **Conception :** §6.9, §6.10, D3.
- **Fichiers :** `visuels/camera_arene.gd`, `visuels/arene_2d.gd`, `project.godot` (six actions) ; tests `test_camera_arene.gd`, `test_arene_2d.gd`, `test_configuration_projet.gd`.
- **Lire :** `visuels/camera_arene.gd` (128 lignes), `visuels/arene_2d.gd` `lier`, `afficher`, `definir_joueur`.
- **Interfaces :** produit les interfaces « Caméra » ci-dessus ; consomme `SourceVue.vue_regardee_recue` (T8.1). Vitesse de base `VITESSE_BASE = 900.0` unités par seconde, multipliée par `vitesse_relative` (réglage ajouté par T8.17, câblé par T8.20).
- **Tests :**
  - `test_le_zoom_maximal_montre_deux_fois_le_cercle_d_apparition` : `cadre_visible().size.y / 2 >= 2 × RAYON_APPARITION` ; au zoom par défaut le cercle entier est visible (test existant).
  - `test_le_decalage_est_limite_a_deux_rayons_dans_les_huit_directions` ; `test_deplacer_ignore_les_valeurs_non_finies`.
  - `test_les_fleches_et_wasd_deplacent_la_vue` : en boucle sur les quatre actions et leurs touches, `Input.action_press` puis un pas de une seconde, décalage de `VITESSE_BASE` ; `test_la_diagonale_n_est_pas_plus_rapide`.
  - `test_espace_recentre_sur_la_tour_et_garde_le_zoom`.
  - `test_centrer_sur_place_le_point_au_centre_de_la_zone_libre_et_borne_les_points_trop_loin`.
  - `test_le_cadre_visible_suit_le_zoom_et_le_decalage` : zoom ×2, taille ÷2, centre = décalage.
  - `test_les_six_actions_existent_avec_leurs_touches` : en boucle, y compris B et Espace.
  - `test_montrer_une_arene_affiche_la_vue_regardee_et_moins_un_revient_a_la_sienne` : avec `SourceFactice`, 3 ennemis regardés, puis la vue propre ignorée tant qu'on regarde ; nom et teinte de tour du joueur regardé.
- **Vérif :** `T --filtre test_camera_arene`, `test_arene_2d`, `test_configuration_projet`, puis `tools/verifier.sh`.

### Task 8.14 : Planche des 30 signatures d'armes — `sonnet` — **attend Phil**

- [ ] **Objectif :** proposer une signature visuelle par arme (forme du projectile, couleur, traînée, impact, statut) dans `visuels/signatures_armes.gd` (table, sans l'intégrer en jeu), et la montrer sur une planche : `docs/planche_signatures.png`, composée par un script de `tools/` avec `Image`, sans fenêtre, sur le modèle de `tools/composer_images_offres.gd`. Sources : effets du pack d'abord, puis formes dessinées par code aux couleurs du pack. Chaque carte nomme l'arme. **Aucune intégration avant la validation de Phil** : l'agent principal met la ligne du tableau d'avancement à `a_valider` avec `attend` renseigné.
- **Conception :** §6.5, D5, §7 (planche avant intégration).
- **Fichiers :** `visuels/signatures_armes.gd`, `tools/planche_signatures.gd`, `docs/planche_signatures.png` ; tests nouveau `test_signatures_armes.gd` ; `test_garde_ressources.gd` si le script cite une image du pack.
- **Lire :** `visuels/effets.gd` `PROJECTILES`, `IMPACTS`, `TRAITS`, `COULEURS`, `_dessiner` ; `data/armes.json` (id, type, statuts de chacune, par script `jq`-équivalent, pas en entier).
- **Interfaces :** produit `SignaturesArmes` (figée ci-dessus).
- **Tests :**
  - `test_chaque_arme_a_une_signature_et_il_n_y_en_a_pas_d_autre` : les 30 ids de `Donnees.armes`, ni plus ni moins.
  - `test_deux_armes_n_ont_jamais_la_meme_signature` : les 435 paires, sur projectile, couleur, traînée et impact.
  - `test_deux_armes_ne_partagent_jamais_la_forme_et_la_couleur_du_projectile` : les 435 paires (reconnaissance d'un coup d'œil).
  - `test_les_signatures_restent_lisibles_au_zoom_le_plus_lointain` : couleur de saturation et de valeur suffisantes (valeur ≥ 0,6), opacité ≥ 0,8.
  - `test_le_statut_de_la_signature_est_celui_de_l_arme_vol_de_vie_compris` : en boucle sur les 30.
  - `test_une_arme_inconnue_n_a_pas_de_signature` (`{}`).
- **Vérif :** `T --filtre test_signatures_armes`, `godot --headless --path . --script res://tools/planche_signatures.gd`, puis `tools/verifier.sh`. Rapport : lien vers la planche.

### Task 8.15 : Sons de tir par arme et d'impact par type de dégâts — `sonnet`

- [x] **Objectif :** D15. Un son de tir propre à chacune des 30 armes et un son d'impact par type de dégâts (5), pris dans le « 400+ Sounds Pack » (CC0, déjà cité dans `CREDITS.md`), surtout dans ses dossiers Weapons et Combat and Gore, puis dans tout dossier adapté (Magic, Explosions…) s'il n'y a pas 30 sons distincts ; jamais le même fichier d'origine deux fois. Dossier du pack : https://drive.google.com/drive/folders/10Owjc3qqK0tWUJANwKOYmKsidLofonc0 (liste par `https://drive.google.com/embeddedfolderview?id=<id du dossier>`, téléchargement par `https://drive.google.com/uc?export=download&id=<id>`). Même conversion que T5.6 : Ogg Vorbis par ffmpeg, silence de tête coupé, `loudnorm` à −18 LUFS. Indépendante de la planche.
- **Conception :** §6.5 bis, D15.
- **Fichiers :** `sons/catalogue_sons.gd`, `sons/detecteur_sons.gd`, `sons/lecteur_sons.gd`, `assets/sons/tir_<id>.ogg` (30) et `assets/sons/impact_<type>.ogg` (5) avec leurs `.import`, `assets/sons/SOURCES.md` (une ligne par son : identifiant, sous-dossier, fichier d'origine) ; tests `test_catalogue_sons.gd`, `test_detecteur_sons.gd`, `test_lecteur_sons.gd`. `CREDITS.md` : voir T8.21 (la ligne du pack existe déjà, son nombre de sons y est mis à jour).
- **Lire :** `sons/*.gd` (les trois), `assets/sons/SOURCES.md`, `tests/unitaires/test_catalogue_sons.gd`.
- **Interfaces :** produit `CatalogueSons.id_tir`, `CatalogueSons.id_impact`, repli sur `tir` / `impact` ; `DetecteurSons.sons_du_pas(precedente: VueArene, courante: VueArene, catalogue: PackedStringArray = PackedStringArray()) -> Array[String]` (le catalogue de `Donnees.ids_catalogue` traduit l'index `arme` d'un événement en son) ; le lecteur varie la hauteur de ± 5 % à chaque tir (graine réglable pour les tests).
- **Tests :**
  - `test_chaque_arme_a_son_fichier_de_tir` : en boucle sur les 30 armes, le fichier existe et n'est pas un silence de substitution.
  - `test_deux_armes_n_ont_jamais_le_meme_fichier` : les 435 paires sur l'empreinte du fichier **et** sur le fichier d'origine lu dans `SOURCES.md`.
  - `test_chaque_son_est_liste_dans_sources_md` : les 30 tirs et les 5 impacts.
  - `test_chaque_type_de_degats_a_son_impact_et_les_cinq_sont_distincts`.
  - `test_un_tir_d_arme_inconnue_retombe_sur_le_son_tir`.
  - `test_le_detecteur_choisit_le_son_de_l_arme_de_l_evenement` : en boucle sur les 30 ; `test_un_evenement_sans_arme_donne_le_son_tir` ; `test_l_impact_depend_du_type_de_degats` (5).
  - `test_la_hauteur_varie_dans_5_pour_cent_et_prend_plusieurs_valeurs` : 20 tirs, graine fixe.
  - `test_chaque_fichier_de_son_pese_moins_de_80_ko`.
  - `test_la_liste_des_ids_d_armes_du_catalogue_suit_les_donnees` (anti-dérive).
- **Vérif :** `T --filtre test_catalogue_sons`, `test_detecteur_sons`, puis `tools/verifier.sh`.

### Task 8.16 : Signatures d'armes en jeu et statuts visibles — `sonnet`

- [ ] **Objectif :** après la validation de Phil de la planche (T8.14), l'effet de tir et d'impact suit la signature de l'arme de l'événement ; les cinq statuts sont tous visibles, **vol de vie compris** (un soin vert qui remonte de l'ennemi vers la tour) ; plafond d'effets simultanés conservé ; taille et luminosité suffisantes au zoom le plus lointain.
- **Conception :** §6.5, D5.
- **Fichiers :** `visuels/effets.gd`, `visuels/arene_2d.gd` (catalogue, teinte des ennemis à statut) ; tests `test_effets.gd`, `test_evenements_genre.gd`, `test_arene_2d.gd`.
- **Lire :** `visuels/effets.gd` `rendu`, `_tir`, `_impact`, `_statut` ; `visuels/signatures_armes.gd` ; la planche validée.
- **Interfaces :** consomme `SignaturesArmes.de` (T8.14), l'index `arme` des événements (T8.3), `Donnees.ids_catalogue`. Produit `Effets.catalogue: PackedStringArray` (posé par `Arene2D`), `Arene2D.teinte_instance(famille: int, i: int) -> Color`, `Effets.COULEUR_SOIN`.
- **Tests :**
  - `test_chaque_arme_produit_un_tir_aux_formes_et_a_la_couleur_de_sa_signature` : en boucle sur les 30.
  - `test_deux_armes_ne_produisent_jamais_le_meme_rendu` : les 435 paires sur formes vivantes, couleur du premier effet et taille.
  - `test_l_impact_suit_la_signature_de_l_arme`.
  - `test_un_evenement_sans_arme_garde_le_rendu_par_type_de_degats` (`Effets.rendu` inchangé).
  - `test_chaque_statut_a_un_visuel_distinct` : en boucle sur les 5 statuts (poison, brûlure, givre, étourdissement, vol de vie), forme et couleur distinctes deux à deux.
  - `test_le_vol_de_vie_remonte_vers_la_tour_en_vert` : l'effet part de l'ennemi, finit à la tour, de couleur `COULEUR_SOIN`.
  - `test_un_ennemi_a_statut_est_teinte_et_cinq_statuts_donnent_cinq_teintes` : sans statut, `Color.WHITE`.
  - `test_le_plafond_de_200_effets_tient_avec_40_armes_qui_tirent`.
- **Vérif :** `T --filtre test_effets`, `test_evenements_genre`, puis `tools/verifier.sh`. Captures de contrôle aux trois résolutions relues.

---

## Session « Interface »

### Task 8.17 : Police Metamorphous, tailles du thème et taille de l'interface — `sonnet`

- [x] **Objectif :** Metamorphous (SIL OFL 1.1) remplace Tiny5 partout, DejaVu Sans reste en repli pour les symboles ; les tailles de texte passent par un seul réglage de `ThemeJeu` au lieu des surcharges locales ; réglage « Taille de l'interface » de 75 à 125 % (défaut 100 %), persistant, appliqué à tout l'ATH. **Décision de pilotage du 25/11/2026 :** Metamorphous à 16 px élargit la boutique au-delà de la part permise ; la PR embarque donc la partie « cartes compactes » de T8.19 (image, nom, prix, rareté ; effet entier et description en infobulle, texte à 16 px minimum, bandeau à 45 % au plus) et le test de surface.
- **Conception :** §6.6, §6.7 (taille), D9, D13.
- **Fichiers :** `assets/polices/metamorphous/` (fichier woff2 latin du paquet npm `@fontsource/metamorphous`, `OFL.txt`, `.import`), `ui/theme.gd`, `ui/hud.gd`, `ui/boutique_ui.gd`, `ui/scores.gd`, `ui/reglages_ui.gd`, `app/reglages.gd`, `i18n/textes_reglages.csv` ; tests `test_theme_pack.gd`, `test_mise_en_page.gd`, `test_reglages.gd`, `test_reglages_mise_en_page.gd`, `test_garde_ressources.gd` (liste fermée : la police est citée par `ui/theme.gd` seul). `CREDITS.md` : voir T8.21.
- **Lire :** `ui/theme.gd` (constantes, `_construire`), `app/reglages.gd` en entier, `grep -n 'font_size\|TAILLE_' ui/*.gd`.
- **Interfaces :** produit `ThemeJeu.taille(role: String) -> int` (rôles `"texte"`, `"petit"`, `"titre"`) multiplié par l'échelle ; `Reglages.ECHELLES = [0.75, 0.875, 1.0, 1.125, 1.25]` (réglage : cinq crans, défaut 1,0), `Reglages.echelle_valide(valeur)` ramène à un cran ; `Reglages.vitesse_camera: float` (0,5 à 2,0, défaut 1,0, lue par T8.20).
- **Tests :**
  - `test_metamorphous_couvre_les_caracteres_du_francais` : `FontFile.has_char` en boucle sur é è ê à ç œ « » espace insécable ; l'espace fine tombe sur le repli sans erreur.
  - `test_la_police_du_theme_est_metamorphous_avec_dejavu_en_repli` ; `test_tiny5_n_est_plus_cite`.
  - `test_aucune_taille_de_texte_en_dur_dans_ui` : aucun `font_size` ni `TAILLE_*` local ne subsiste hors de `ThemeJeu`.
  - `test_les_cinq_crans_d_echelle_sont_acceptes_et_les_autres_ramenes_au_plus_proche` : en boucle.
  - **Review Focus 4 :** `test_un_ancien_fichier_de_reglages_garde_une_echelle_valide` (1,25 ancien reste 1,25 ; 1,5 ancien devient 1,25) et `test_aucun_texte_ne_deborde_ni_ne_se_coupe_a_75_et_125_pour_cent` : les plus longs libellés réels (24 noms de familles, noms d'armes, descriptions) aux 3 résolutions de `test_mise_en_page.gd`, aux échelles 0,75 et 1,25.
  - `test_la_vitesse_de_camera_est_bornee_et_persistante`.
  - Cartes compactes (décision de pilotage) : `test_l_infobulle_de_chaque_offre_donne_l_effet_entier_puis_l_ambiance` (toutes les offres des données, en boucle), `test_l_infobulle_se_lit_a_16_px_au_moins`, `test_les_cartes_les_plus_chargees_tiennent_a_chaque_resolution_et_a_75_et_125_pour_cent` et `test_la_boutique_est_au_moins_30_pour_cent_plus_petite_qu_avant` (`SURFACE_AVANT` mesurée sur `c4f37ef`).
- **Vérif :** `T --filtre test_theme_pack`, `test_reglages`, `test_mise_en_page`, puis `tools/verifier.sh`.

### Task 8.18 : Barre du haut à icônes et tableau des scores — `sonnet`

- [ ] **Objectif :** la barre du haut montre une icône par information (or, revenu, manche, temps avec un sablier, armures de la prochaine manche, nombre d'armes), sans PV, d'environ 40 px de haut ; l'annonce de la manche suivante montre les armures de ses 2 ou 3 familles (texte en infobulle) ; le tableau des scores ajoute « Revenu / 10 s », « Dégâts par seconde » et dégâts totaux. Sablier sous licence libre (CC0 ou CC BY) à trouver dans les packs déjà utilisés ou sur OpenGameArt ; **à défaut, le demander à Phil** (le rapport le dit, la tâche attend).
- **Conception :** §6.7 (barre du haut), §6.8, D1, D10, D11.
- **Fichiers :** `ui/hud.gd`, `ui/scores.gd`, `ui/theme.gd` (icônes citées ici : `ICONES`, `TEXTURES`), `assets/icones/…` (sablier et sa `LICENCE.md`), `i18n/textes_hud.csv`, `i18n/textes_communs.csv` si besoin ; tests `test_hud.gd`, `test_fin_ui.gd`, `test_garde_ressources.gd`, `test_contraste.gd`. `emplacements_armes` n'est plus lu (le nombre d'armes est un compte, sans capacité). `CREDITS.md` : voir T8.21.
- **Lire :** `ui/hud.gd` (215 lignes), `ui/scores.gd`, `ui/theme.gd` `ICONES`.
- **Interfaces :** consomme `VueArene.prochaines_familles`, `prochaines_armures`, `armes` (jusqu'à 255), `VueGlobale.joueurs[i].dps`, `.revenu`, `.degats`. Produit `Hud.hauteur_barre() -> float` (≈ 40) et `Scores.COLONNES` à 8.
- **Tests :**
  - `test_la_barre_n_affiche_plus_les_pv_et_montre_six_informations_avec_icone`.
  - `test_chaque_icone_a_un_nom_accessible_et_une_infobulle` : l'information ne repose jamais sur l'icône ou la couleur seule.
  - `test_la_barre_fait_au_plus_44_px_de_haut_aux_trois_resolutions`.
  - `test_l_annonce_montre_les_armures_de_chaque_famille_suivante` : en boucle sur 0 à 3 familles ; vide sans famille.
  - `test_le_nombre_d_armes_tient_pour_0_8_40_et_255_armes`.
  - `test_le_tableau_montre_revenu_dps_et_degats_totaux_pour_huit_joueurs` : valeurs formatées par `Nombres`, intitulé exact « Revenu / 10 s ».
  - `test_les_textes_de_la_barre_et_du_tableau_gardent_un_contraste_aa`.
- **Vérif :** `T --filtre test_hud`, `test_garde_ressources`, `test_contraste`, puis `tools/verifier.sh`.

### Task 8.19 : Boutique compacte et repliable, catégories, grille des armes — `sonnet`

- [ ] **Objectif :** _(cartes compactes déjà livrées par T8.17, décision de pilotage du 25/11/2026 : image, nom, prix, rareté, effet et description en infobulle)_ panneau qui se replie et se déplie (touche B et bouton), raccourcis 1 à 4 et R conservés ; chaque carte porte en tête un ruban du pack de la couleur de sa catégorie (rouge « Arme », bleu « Amélioration », jaune « Revenu »), avec icône et mot écrit ; les mêmes repères dans la grille des armes équipées, la liste des améliorations achetées et le marché noir ; la liste des armes équipées devient une grille compacte d'icônes qui défile (jusqu'à 255), détail en infobulle.
- **Conception :** §6.3 (interface), §6.7 (boutique, catégories), D13, D14.
- **Fichiers :** `ui/boutique_ui.gd`, `ui/categorie_offre.gd` (nouveau : ruban, icône, mot), `ui/theme.gd` (rubans cités ici), `ui/description_offre.gd` si l'infobulle l'exige, `i18n/textes_boutique.csv` ; tests `test_boutique_ui.gd`, `test_boutique_images.gd`, `test_boutique_description.gd`, `test_mise_en_page.gd`, nouveau `test_categorie_offre.gd`. `emplacements_armes` n'est plus lu (`_capacite` supprimée).
- **Lire :** `ui/boutique_ui.gd` par plage (`_construire_carte`, `_construire_cote`, `_afficher_armes`), `Donnees.categorie_de`, `ui/theme.gd` (`TEX_RUBAN`).
- **Interfaces :** consomme `Donnees.categorie_de`, `ACTION_REPLIER = "boutique_replier"` (T8.13), `SourceVue.vendre`. Produit `CategorieOffre.rubrique(categorie: int) -> Dictionary` `{ruban: String, icone: String, mot_cle: String}`.
- **Tests :**
  - `test_chaque_categorie_a_un_ruban_une_icone_et_un_mot_et_les_trois_se_distinguent` : couleur, icône et mot distincts deux à deux, en boucle sur `Types.Categorie`.
  - `test_chaque_offre_affiche_sa_categorie_d_apres_les_donnees` : en boucle sur les 70 offres, le mot écrit est « Arme », « Amélioration » ou « Revenu ».
  - `test_le_panneau_se_replie_et_se_deplie_a_la_touche_b_et_au_bouton` ; `test_replie_le_panneau_laisse_le_bouton_pour_le_deplier_et_libere_la_zone` ; `test_les_raccourcis_1_a_4_et_r_restent`.
  - `test_la_grille_des_armes_defile_et_tient_255_armes_sans_deborder` ; `test_chaque_arme_de_la_grille_a_une_infobulle_et_son_repere_de_categorie`.
  - `test_aucun_libelle_ne_se_coupe_avec_les_plus_longs_noms_reels_a_75_et_125_pour_cent`.
  - `test_la_vente_a_50_pour_cent_depuis_la_grille_envoie_le_bon_index`.
  - `test_le_marche_noir_et_les_ameliorations_achetees_portent_leurs_reperes`.
- **Vérif :** `T --filtre test_boutique_ui`, `test_categorie_offre`, `test_mise_en_page`, puis `tools/verifier.sh`. Captures de contrôle relues aux trois résolutions.

### Task 8.20 : Mini-carte et câblage de la partie — `sonnet`

- [ ] **Objectif :** mini-carte en bas à droite : sa propre arène (tour, ennemis en points de la couleur de leur palier, cercle d'apparition, cadre de la vue), un clic y déplace la vue ; les arènes des autres joueurs en vignettes (nom, barre de PV, densité), un clic sur une vignette affiche cette arène dans la vue principale, **Espace** revient à la sienne (le HUD et la boutique restent ceux du joueur) ; pas de vignette en solo. Câble dans `app/jeu.gd` tout ce que le lot ajoute : caméra, mini-carte, taille de l'interface, vitesse de caméra, barre du haut, boutique repliable, `regarder`.
- **Conception :** §6.9, §6.10, D4.
- **Fichiers :** `ui/minicarte.gd` (nouveau), `app/jeu.gd`, `i18n/textes_minicarte.csv` (nouveau) ; tests nouveau `test_minicarte.gd`, `test_observation_ui.gd`, `tests/integration/test_solo.gd`, `test_mise_en_page.gd`.
- **Lire :** `app/jeu.gd` (`_monter`, `_sur_arene`, `_sur_globale`, `_unhandled_input`, `placer_dans`), `ui/observation_ui.gd`, `visuels/camera_arene.gd`.
- **Interfaces :** consomme `Arene2D.camera() -> CameraArene` (`cadre_visible`, `centrer_sur`, `recentrer`), `Arene2D.montrer_arene`, `SourceVue.regarder`, `id_regarde`, `vue_regardee_recue`, `VueGlobale.densites` et `joueurs`. Produit `Minicarte` : `func afficher(vue: VueArene, globale: VueGlobale, id_local: int, cadre: Rect2) -> void`, `func case_vers_unites(position_locale: Vector2) -> Vector2`, `func joueur_sous(position_locale: Vector2) -> int` (−1 si aucun), signaux `demande_centrage(point_unites: Vector2)` et `demande_regarder(id_joueur: int)`.
- **Tests :**
  - `test_un_clic_sur_la_carte_demande_le_centrage_au_bon_point_du_monde` : en boucle sur les quatre coins et le centre.
  - **Review Focus 5 :** `test_un_clic_hors_de_la_carte_ou_non_fini_ne_deplace_pas_la_vue_et_espace_revient_toujours` : coordonnées hors carte, NaN, INF ; clic sur la vignette d'un joueur qui vient de partir ; après chaque cas, `camera_recentrer` remet la tour au centre et `montrer_arene(-1)`.
  - `test_les_ennemis_ont_la_couleur_de_leur_palier` : en boucle sur les 4 paliers, 1 000 ennemis sans dépasser le budget d'affichage.
  - `test_le_cadre_de_la_vue_suit_le_zoom_et_le_decalage`.
  - `test_une_vignette_par_autre_joueur_avec_son_nom_et_sa_barre_de_pv` : 2 à 8 joueurs ; aucune en solo.
  - `test_un_clic_sur_une_vignette_regarde_cette_arene_et_espace_revient_a_la_sienne` (avec `SourceFactice`).
  - `test_la_minicarte_ne_couvre_ni_la_boutique_ni_la_barre_du_haut_aux_trois_resolutions_et_aux_cinq_echelles`.
  - `test_le_hud_et_la_boutique_restent_ceux_du_joueur_pendant_qu_il_regarde`.
  - `test_la_taille_de_l_interface_et_la_vitesse_de_camera_des_reglages_sont_appliquees`.
  - Tests d'intégration solo (`test_solo.gd`) et réseau (`test_multijoueur.gd`) toujours verts.
- **Vérif :** `T --filtre test_minicarte`, `test_observation_ui`, puis `tools/verifier.sh` (étape `integration` comprise). Captures de contrôle relues.

---

## Passe finale

### Task 8.21 : Passe d'équilibrage et clôture du lot — `sonnet`

- [ ] **Objectif :** rejouer l'outil d'équilibrage (`tools/equilibrage.gd`) avec toutes les données du lot, vérifier que la partie reste gagnable et que la difficulté monte sans mur, consigner les chiffres dans `docs/equilibrage.md`, revoir les suivis ouverts (rampe de dégâts, mur de PV après la manche 20). **Critère :** les cibles du robot consignées restent atteintes, le robot de référence (`bonne`) n'est pas éliminé avant la manche 20, un robot qui n'achète rien tombe au plus tard à la fin de la manche 3 (T8.8) et les PV et dégâts croissent à chaque manche. **Leviers autorisés sans revenir à Phil :** manches d'entrée des paliers et de l'Archer, PV, dégâts et primes par palier, poids des familles, chiffres de la mana et des armes de mana, poids de rareté de la boutique, rampe de dégâts et de PV de `data/difficulte.json`. **Non modifiables sans Phil :** paliers de portée des armes (500 / 750 / 1 000 / 1 250), vitesse ×1,5, portées d'ennemis 350 et 650. Clôture : suppression d'`emplacements_armes` de `data/partie.json` (avec un test garde qu'aucun fichier ne le lit), `CREDITS.md` à jour pour tout le lot (retrait de la guêpe, Metamorphous, sablier, nombre de sons du pack), `docs/jouer.md` (caméra, mini-carte, catégories, mana, taille de l'interface), `CLAUDE.md` (pièges rencontrés, rétros des tâches), suivis fermés dans « Suivis relevés en cours de route ».
- **Conception :** §6.12, §6.1 (Archer, paliers).
- **Fichiers :** `data/difficulte.json`, `data/ennemis.json`, `data/armes.json`, `data/ameliorations.json`, `data/boutique.json`, `data/partie.json`, `docs/equilibrage.md`, `docs/jouer.md`, `CREDITS.md`, `CLAUDE.md`, ce plan (suivis), `tests/unitaires/test_equilibrage_partie.gd`, `test_donnees.gd`.
- **Lire :** `docs/equilibrage.md` en entier ; les rapports et rétros des tâches 8.1 à 8.20.
- **Interfaces :** consomme tout le lot ; ne change aucune interface.
- **Tests :**
  - `test_le_robot_de_reference_n_est_pas_elimine_avant_la_manche_20` : robot `bonne`, graines 1 à 10.
  - `test_un_joueur_raisonnable_atteint_au_moins_la_manche_douze_en_mediane` (seuil du test existant, relevé si les mesures le permettent).
  - `test_emplacements_armes_n_est_plus_lu_nulle_part` : aucune occurrence dans `sim/`, `ui/`, `app/`, `reseau/`, ni dans `data/partie.json`.
  - Tests de T8.8 (seuil bas et montée continue) toujours verts.
- **Vérif :** `godot --headless --path . --script res://tools/equilibrage.gd -- --graines 50 --strategie toutes`, `npx -y prettier@3.9.10 --check` sur les Markdown touchés, puis `tools/verifier.sh` complet.

---

# Suivis relevés en cours de route

- **Équilibrage** (rapport de la passe du 25/11/2026, `docs/equilibrage.md`) : rampe de dégâts
  ennemis très raide (×0,03 à ×1 entre les manches 1 et 10) ; mur de PV après la manche 20 (×2 000
  à la manche 31), car la puissance du joueur croît sans plafond (améliorations multiplicatives,
  or inutilisé) ; boss retenu par les gels ; archers (portée 450) hors de portée des armes à 300.
- **Caméra** : vue lointaine pour cadrer le cercle d'apparition ; régler le zoom par défaut à
  l'usage.
- **Réglages** : vérifier sous Windows que le renommage écrase bien l'ancien fichier.
- **Tests** : avertissement « ObjectDB instances were leaked » à la sortie (tests réseau).
- **Multijoueur** : le rôle d'hôte revient au premier qui dit bonjour ; si un joueur du réseau
  arrive avant le client local de l'hôte, il devient hôte. Réserver ce rôle au client local
  (jeton tiré à la création du salon) : traité par T7.2b (ADR 001, décision 5). « Retour au salon » recrée le salon et fait revenir les
  autres par la liste ; un vrai retour sans reconnexion demande `Client.retourner_au_salon()`.
- **Annuaire** : lot 7 terminé le 25/11/2026 (T7.0 à T7.4, T7.3 en dernier, décision de Phil). Reste
  à Phil le lancement du service sur le VPS (liste dans la PR de T7.4). Aucun délai global sur la
  tentative UPnP : une box qui répond à la découverte puis se fige retarderait l'annonce sans message
  (délai maximal avant d'annoncer le port local, à décider).
- **Images des offres** : 17 offres sur 70 ont une image approchante (Ravenmore et LudicArts n’ont
  pas leur objet : sablier, tirelire, trébuchet…), validée telle quelle par Phil le 25/11/2026. Liste
  dans `ImagesOffres.RAPPROCHEMENTS_FAIBLES` ; à reprendre si un pack peint gratuit les a.
- **Règles de la simulation à vérifier** (relevées en écrivant les descriptions, T5.9) : le givre ne
  gèle qu’au 8e coup, donc son plafond de 60 % est inatteignable ; les épines ne renvoient que le corps
  à corps ; les morts par poison ou brûlure ne soignent pas ; `revenu_mult` ne multiplie pas le revenu
  de base ; l’aura ignore `portee` et `recharge`.
- **Lots 3 et 4** : terminés (T3.7, T4.3, T4.5 et T4.6 fusionnés par la PR #2).

---

# Lot 9 — Catalogue aligné sur Tower Survivors (D18)

**Conception :** `docs/superpowers/specs/2026-11-25-retours-partie-design.md` §6.13 (décision D18 de Phil du 25/11/2026, complétée le 26/11/2026 : les trois améliorations sans homologue **restent**, soit **87** améliorations en tout, aucune retirée). Comparatif : `docs/tower_survivors.md` (§1, §3, §6 et §7 pour les écarts ; §4.1 et §4.2 **pour le garde-fou seulement** : ses noms, prix, dégâts et durées ne se recopient jamais, ni dans les données, ni dans ce plan). Elle complète la spec du jeu et celle du lot 8 et l'emporte là où elles diffèrent.

**Intention :** passer de 30 armes et 40 améliorations à **75 armes** (15 par type de dégâts, réparties 1 commune, 6 peu communes, 6 rares, 2 épiques) et **87 améliorations**, avec les **dix mécaniques** qui manquent (M1 à M10 ci-dessous). Noms, textes, chiffres et prix restent originaux et calés par notre test d'équilibrage (spec du jeu §5.6) ; nos pièges (`chausse_trape`, `sablier_fele`), absents de la map, restent.

**Les dix mécaniques** (citées par les tâches sous ces numéros) :

- **M1** vulnérabilité cumulable par type de dégâts, plafonnée ;
- **M2** malédiction, en deux statuts (dégâts de l'ennemi réduits, chances de toucher réduites) ;
- **M3** repoussement ;
- **M4** siphon de mana et mana au coup (le siphon vaut aussi pour la vie : même code, deux ressources) ;
- **M5** dégâts selon les PV maximum de la tour, le nombre d'exemplaires ou les améliorations possédées ;
- **M6** invocation d'alliés temporaires ;
- **M7** tir tournant ;
- **M8** zone posée qui inflige ses dégâts dans la durée, et **M9** bombe à retardement ;
- **M10** épines comme second type de dégâts d'une arme.

**Parallélisme :** six sessions, chacune sur ses fichiers.

- **Garde-fou** : T9.1, tout de suite (tests et document seulement), **avant tout nom d'arme**.
- **Simulation** (`sim/`, `reseau/`, `app/source_vue.gd`, `app/source_locale.gd`, `data/partie.json`, `data/unites.json`) : T9.2 dès que T8.3, T8.5 et T8.7 sont fusionnées, puis T9.3, T9.4, T9.5, T9.6, T9.7, T9.8 et T9.9 à la suite.
- **Améliorations** (`sim/inventaire.gd`, `sim/stats_tour.gd`, `sim/arene.gd` pour consommer les stats, `data/ameliorations.json`) : T9.10, T9.11, T9.12, **après T9.8** (dernière tâche à toucher `sim/arene.gd` et `sim/tir.gd`), donc en parallèle de T9.9, qui ne touche que `reseau/`.
- **Armes** (`data/armes.json`, `tests/unitaires/test_catalogue_armes.gd`) : T9.13 à T9.17, une tâche par type dans l'ordre tranchant, perçant, magique, siège, chaos, chacune dès que les mécaniques qu'elle impose sont fusionnées. `data/armes.json` n'a **qu'un propriétaire à la fois** : les cinq tâches s'enchaînent. On ne découpe pas le fichier : le chargeur lit `armes.json` et `ameliorations.json` d'un bloc (`FICHIERS_LISTE` de `sim/donnees.gd`) et une douzaine de tests les citent par leur nom.
- **Rendu** (`visuels/`, `sons/`, `assets/sons/`, `tools/planche_signatures.gd`, `docs/planche_signatures.png`) : T9.18 (**attend Phil**) quand T9.13 à T9.17 sont fusionnées ; T9.19 après la validation de T9.18 ; T9.20 (sons) dès que T9.17 est fusionnée.
- **Interface** (`ui/description_offre.gd`, `i18n/textes_boutique.csv`) : T9.21, **dès T9.2 et avant T9.10 et T9.13** : les descriptions refusent un genre, un statut ou une stat qu'elles ne connaissent pas (`test_un_genre_un_statut_ou_une_statistique_inconnus_ne_passent_pas_en_silence`), donc aucune donnée nouvelle n'entre avant leurs modèles de ligne.
- **Passe finale** : T9.22, quand tout est fusionné.

**Dépendances :** T9.1 aucune (le comparatif est sur `main`) · T9.2 T8.3, T8.5, T8.7 · T9.3 T9.2 · T9.4 T9.3, T8.7 · T9.5 T9.4 · T9.6 T9.5 · T9.7 T9.6 · T9.8 T9.7 · T9.9 T9.8, T8.2 · T9.10 T9.8, T9.21 · T9.11 T9.10 · T9.12 T9.11 · T9.13 T9.1, T9.3, T9.5, T9.6, T9.21 · T9.14 T9.13 · T9.15 T9.14, T9.4, T9.7, T9.9 · T9.16 T9.15, T9.5 · T9.17 T9.16, T9.8 · T9.18 T9.13 à T9.17, T8.14 (planche des 30, validée) · T9.19 T9.7, T9.8, T9.9, T9.18 validée par Phil · T9.20 T9.17, T8.15 · T9.21 T9.2 · T9.22 toutes. T9.3 à T9.8 s'enchaînent parce qu'elles touchent toutes `sim/arene.gd`, `sim/tir.gd` ou `sim/ennemis.gd`.

**Couplages à respecter :**

- T9.2 ajoute des genres d'événement, des statuts et des stats que ni le protocole, ni le rendu, ni les descriptions ne gèrent encore : il n'ajoute **aucune donnée de jeu** qui les utilise. Une arme ou une amélioration qui cite une nouveauté n'entre dans `data/` que quand la tâche qui la code, T9.9 (réseau des alliés, zones et bombes) et T9.21 (descriptions) sont fusionnées : c'est ce que la liste des dépendances impose (T9.15, T9.16 et T9.17 attendent T9.9). Le rendu en jeu, lui, vient après (T9.19) : jusque-là un genre ou un statut nouveau retombe sur le rendu par type de dégâts.
- **Images de la boutique** : chaque offre a une image dans `ImagesOffres.OFFRES` (`visuels/images_offres.gd`, icônes des packs déjà crédités sous `assets/icones/`), et `test_boutique_images.gd` exige aujourd'hui exactement 70 offres. T9.2 remplace cette constante, et celle de `test_description_offre.gd` (même nombre en dur), par la taille des données (seule retouche permise hors de ses fichiers) ; ensuite **chaque tâche de contenu (T9.10 à T9.17) ajoute les images de ses offres**, `OFFRES` étant rangée par sections (type d'arme, famille d'amélioration) pour que les deux sessions ne touchent jamais la même section. Une image qui ne représente pas l'objet va dans `RAPPROCHEMENTS_FAIBLES`.
- `Protocole.VERSION` : **relire celle de `main` avant de l'incrémenter** (piège de `CLAUDE.md`). Aujourd'hui `main` est à 4 et la PR #28 (T8.2) la porte à 5 : T9.9 prend 6 si T8.2 est fusionnée seule, sinon le numéro qui suit celui de `main` à ce moment-là, et garde tous les formats précédents refusés par un test en boucle.
- Les index d'armes du réseau sont ceux de `Donnees.ids_catalogue` (ids triés) : ajouter 45 armes et 47 améliorations déplace des index. Cela ne coûte rien (les deux côtés lisent les mêmes données, l'empreinte des données est vérifiée à la connexion) mais aucun test ne doit figer un index.

**Fichiers partagés, un seul propriétaire :** `CREDITS.md`, `docs/equilibrage.md`, `docs/jouer.md` et `CLAUDE.md` appartiennent à T9.22 (les autres tâches y écrivent leurs lignes dans leur rapport) ; `sim/donnees.gd`, `sim/types.gd`, `sim/vue_arene.gd`, `data/partie.json`, `data/unites.json` à T9.2 (puis à la tâche de mécanique qui y ajoute une valeur, dans l'ordre) ; `sim/equilibrage.gd` à la tâche de mécanique qui y ajoute son estimation ; `tests/unitaires/test_contenu.gd` et `test_contenu_donnees.gd` à T9.2 seule (les tests de catalogue vont dans de nouveaux fichiers : `test_catalogue_armes.gd`, `test_catalogue_ameliorations.gd`, `test_noms_origine.gd`).

## Effectifs cibles du catalogue

**Armes, par type de dégâts** (cinq types, tous identiques) : 1 commune, 6 peu communes, 6 rares, 2 épiques, soit 15. Aujourd'hui : 2 / 2 / 1 / 1. Dans chaque type : la commune **la plus rentable** (dégâts par seconde par pièce d'or, `Equilibrage.rendement` **aux prix d'aujourd'hui**) devient peu commune et son prix suit son palier ; on ajoute 3 peu communes, 5 rares et 1 épique. Soit 9 nouvelles armes par type, 45 en tout.

**Améliorations, par famille** (champ `famille` de `ameliorations.json`, créé par T9.2). La cible est l'effectif de la map, **plus** nos trois sans homologue ; un test exige « au moins » la cible par famille et exactement 87 au total (décision de Phil du 26/11/2026) :

| Famille (`famille`)         | Cible  | Dont T8.7  | Nous aujourd'hui | À ajouter | Tâche |
| --------------------------- | ------ | ---------- | ---------------- | --------- | ----- |
| `degats_type`               | 15     |            | 10               | 5         | T9.10 |
| `degats_global`             | 3      |            | 2                | 1         | T9.10 |
| `degats_classe`             | 7      |            | 3                | 4         | T9.10 |
| `cadence`                   | 2      |            | 2 (1 de plus)    | 0         |       |
| `etats`                     | 8      |            | 0                | 8         | T9.10 |
| `epines`                    | 11     |            | 2                | 9         | T9.11 |
| `pv_max`                    | 7      |            | 2                | 5         | T9.11 |
| `regeneration`              | 6      |            | 4                | 2         | T9.11 |
| `armure`                    | 5      |            | 2                | 3         | T9.11 |
| `esquive`                   | 1      |            | 1                | 0         |       |
| `mana`                      | 7      | au moins 3 | 0                | 4 au plus | T9.12 |
| `revenu`                    | 9      |            | 8                | 1         | T9.12 |
| `boutique`                  | 3      |            | 2                | 1         | T9.12 |
| `aura_mixte`                | 1      |            | 0                | 1         | T9.12 |
| `critique` (sans homologue) | 2      |            | 2                | 0         |       |
| **Total**                   | **87** |            | **40**           | **47**    |       |

Les 47 à ajouter sont les 3 améliorations de mana de T8.7 (déjà comptées dans `mana`) et les **44** de T9.10 à T9.12 ; si T8.7 en a livré plus de trois, T9.12 en ajoute d'autant moins (le total reste 87).

**Répartition imposée des mécaniques sur les 45 nouvelles armes** (minimum par type ; le reste est laissé à la tâche) : chaque mécanique est portée par au moins une arme du catalogue, et par type :

| Type      | Mécaniques imposées parmi les 9 nouvelles                                                                                                |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| tranchant | M1 (vulnérabilité tranchante), M2 (`malediction_toucher`), M7 (tir tournant), M10 (épines)                                               |
| perçant   | M1 (vulnérabilité perçante), M3 (repoussement), M10 (épines)                                                                             |
| magique   | M1 (vulnérabilité magique), M4 (`mana_au_coup`, siphon de mana), M7 (tir tournant), M8 (zone posée)                                      |
| siège     | M1 (vulnérabilité de siège), M5 (PV maximum de la tour ; améliorations possédées), M8 (zone posée, deux armes), M9 (bombe à retardement) |
| chaos     | M1 (vulnérabilité de chaos), M2 (`malediction_degats`), M4 (siphon de vie), M5 (exemplaires), M6 (invocation, deux armes)                |

## Choix du plan faute d'information dans la conception (à relire par Phil)

1. **PV maximum** (M5) : ceux de **la tour**, comme la mana maximale du lot 8 (`degats_par_mana_max`) ; pas ceux de la cible (confirmé par Phil le 26/11/2026).
2. **Alliés** (M6) : durée limitée, **sans PV**, ignorés par les ennemis ; ils marchent vers l'ennemi le plus proche dans un rayon de garde et l'attaquent avec un ratio des dégâts de l'arme invocatrice (types de dégâts, bonus et efficacité de cette arme). Plafond global par arène. Les 6 modèles du pack servent déjà aux 24 ennemis (4 couleurs chacun) : les alliés prennent le guerrier ou l'archer **avec une teinte et un anneau au sol** qu'aucun ennemi n'a (T9.19).
3. **Fin de manche** : alliés, zones posées et bombes à retardement **disparaissent** avec la manche ; mines et pièges gardent leur règle actuelle.
4. **Siphon** (M4) : un seul statut `siphon` à deux ressources (`mana`, `vie`), plutôt que deux statuts ; il compte dans les 12 statuts d'événement sur 16 possibles.
5. **Cumul des améliorations nouvelles** : chaque nouvelle stat de dégâts est **son propre facteur** (additive à l'intérieur de la stat, multiplicative entre stats, comme les catégories A, B, C d'aujourd'hui) ; le produit total des facteurs de dégâts est borné par `partie.json` `ameliorations.facteur_degats_max`.
6. **Épines comme second type** (M10) : les dégâts de l'arme portent toujours son type principal (efficacité contre l'armure inchangée) ; le second type « épines » les fait **aussi** bénéficier des améliorations d'épines. Pas de sixième ligne dans `data/efficacite.json`.
7. **Noms et descriptions** : les noms d'armes et d'améliorations restent dans `data/armes.json` et `data/ameliorations.json` (champ `nom`), comme aujourd'hui ; `i18n/` ne porte que les modèles de ligne d'effet des descriptions (T9.21). La demande de mettre les noms dans `i18n/` demanderait de déplacer les 117 noms déjà dans `data/` : à décider.
8. **Boutique** : elle tire d'abord la rareté, puis uniformément dans la rareté (`Boutique._tirer_un`). Avec 75 armes et 87 améliorations, la **part d'armes** parmi les offres des premières manches baisse (aujourd'hui 10 armes sur 21 offres communes possibles, demain 5 sur 18 au moins). T9.22 mesure cette part et dispose d'un levier : `poids_genre` dans `data/boutique.json`.
9. **Commune promue** : le critère du §6.13 peut garder `chausse_trape` (perçant) ou `sablier_fele` (chaos) comme **seule commune** de leur type. C'est conforme à la décision de Phil ; T9.14 et T9.17 le disent dans leur rapport pour qu'il juge s'il veut une autre règle.
10. **Malédiction de toucher** (M2) : une **réduction moyenne** des dégâts de l'ennemi (`× (1 − chance)`), sans tirage : le hasard de l'arène reste consommé par la seule esquive de la tour, comme aujourd'hui, donc la suite des tirages ne bouge pas et les parties de référence de l'équilibrage restent comparables avant et après le lot (un tirage à graine fixe serait lui aussi reproductible ; c'est la comparabilité qui décide).

## Interfaces figées du lot 9 (créées par T9.2 ; citées partout)

```gdscript
# sim/types.gd — ajouts (bits de Ennemis.statuts ; un octet : 8 sur 8 utilisés)
const STATUT_VULNERABLE := 32
const STATUT_MAUDIT := 64          # l'une ou l'autre des deux malédictions
const STATUT_SIPHONNE := 128
```

**`VueArene`** (`SCHEMA`, `from_dict` et `to_dict` à jour ; l'ordre des listes est figé, on n'ajoute qu'à la fin ; le protocole en transporte l'index et tient sur 4 bits) :

```gdscript
const GENRES_ARME  # + "tournant", "zone_posee", "bombe", "invocation"  → 13 sur 16
const STATUTS_ARME # + "vulnerabilite", "malediction_degats", "malediction_toucher",
                   #   "repoussement", "siphon", "mana_au_coup"          → 12 sur 16
var allies: Array[Dictionary]   # {id: int, pos: Vector2, unite: int (index dans Donnees.ids_unites)}
var zones: Array[Dictionary]    # {pos: Vector2, rayon: float, reste: float (s), arme: int}
var bombes: Array[Dictionary]   # {pos: Vector2, rayon: float, reste: float (s)}
```

**`Donnees`** : `unites: Dictionary` (id → fiche), `ids_unites: PackedStringArray` (triés) ; `FICHIERS_LISTE` gagne `"unites.json"` (facultatif en dossier de test, comme `armes.json`).

**Schémas ajoutés** (validés au chargement : message nommant le fichier, le chemin et la raison, comme T8.1) :

```text
armes.json — nouveaux « kind » d'effet (Donnees._kinds_effets)
  tournant      {branches: entier 1 à 8, pas_deg: > 0 et ≤ 180, largeur: > 0, sens: "horaire" | "antihoraire"}
  zone_posee    {rayon: > 0, duree: > 0, periode: > 0, ratio: > 0, max_actives: entier ≥ 1}
  bombe         {delai: > 0 et ≤ 5, rayon: > 0, ratio: > 0, max_actives: entier ≥ 1}
  invocation    {unite: id de unites.json, duree: > 0, ratio_degats: > 0, max_actives: entier ≥ 1}   # la recharge de l'arme fait la période
armes.json — nouveaux « kind » de statut (Donnees._kinds_statuts)
  vulnerabilite       {ratio: > 0, duree: > 0, type_degats: facultatif, celui de l'arme par défaut}
  malediction_degats  {ratio: ]0 ; 1], duree: > 0}      # dégâts de l'ennemi × (1 − ratio)
  malediction_toucher {ratio: ]0 ; 1], duree: > 0}      # chance que l'attaque de l'ennemi échoue
  repoussement        {distance: > 0}                   # recul immédiat, loin de la tour
  siphon              {ressource: "mana" | "vie", par_seconde: > 0, duree: > 0}
  mana_au_coup        {valeur: > 0}                     # mana rendue à la tour à chaque coup qui touche
armes.json — champs facultatifs d'une arme
  degats_par_pv_max: ratio ≥ 0                          # dégâts de base + ratio × PV maximum de la tour
  degats_par_exemplaire: ratio ≥ 0                      # + ratio × dégâts de base par exemplaire de plus
  degats_par_amelioration: {stat: une stat d'amélioration, ratio ≥ 0}   # + ratio × dégâts de base par amélioration possédée ayant cette stat
  type_secondaire: "epines"
unites.json — liste de {id, nom, modele: "guerrier" | "archer" | "paysan", vitesse > 0, portee > 0, cadence > 0, rayon_garde > 0}
ameliorations.json — champ obligatoire « famille » (Types.FAMILLES_AMELIORATION, les quinze noms du tableau ci-dessus) ;
  stats ajoutées (T9.10 à T9.12), nom → paramètres de l'effet {stat, valeur, …} :
  degats_type, degats_global : + facultatifs croissance (ratio par tranche de partie.json ameliorations.croissance_pas_s, avec max obligatoire) et par_arme_commune (ratio par arme commune possédée)
  toute stat « croissante » (epines_croissantes, regen_croissante, armure_croissante) porte aussi un max obligatoire
  degats_classe {classe: "onde" | "portee_courte" | "portee_longue" | "commune"}
  etat_degats {etat: "poison" | "brulure"} · etat_duree {etat: "poison" | "brulure" | "etourdissement"}
  degats_contre_etat {etat: "etourdi" | "empoisonne" | "ralenti"}
  epines_degats · epines_croissantes · epines_premier_coup · epines_soin · epines_reduction
  epines_statut {statut: "poison" | "brulure" | "givre" | "etourdissement"}
  pv_max_mult · soin_pv_manquants · degats_par_pv_max (par tranche de 1 000 PV maximum) · resurrection
  regen_croissante · soin_periodique {tous_les, ratio}
  armure_croissante · riposte_statut {statut: "givre" | "poison"}
  mana_max_mult · mana_rupture_etourdit {rayon, duree} · degats_tant_que_mana · reduction_tant_que_mana
  revenu_contre_pv {pv, or} · copie_prochaine_offre {raretes_max} · aura_mixte {rayon, poison, regen}
```

**`partie.json`** (valeurs de départ, réglées par T9.22) : `vulnerabilite: {plafond: 0.5, duree_max: 10.0}` (somme maximale du bonus de dégâts subis, par type et par ennemi) ; `malediction: {plafond: 0.75}` ; `repoussement: {distance_max: 400.0, facteur_boss: 0.0}` ; `limites: {allies: 64, zones: 32, bombes: 32}` ; `armes: {bonus_selon_stat_max: 4.0}` (borne de M5, en multiple des dégâts de base) ; `ameliorations: {facteur_degats_max: 20.0, croissance_pas_s: 30.0}`.

**`StatsTour`** : un champ par stat d'amélioration ajoutée, **valeur neutre au départ** (0,0 pour une somme, 1,0 pour un facteur), de même nom que la stat (`degats_classe`, `etat_degats`, `degats_contre_etat` : `Dictionary` clé → valeur ; `epines_statut`, `riposte_statut` : `Dictionary` statut → valeur). `Inventaire._appliquer` accepte et accumule chaque stat dès T9.2 ; les tâches T9.10 à T9.12 les consomment.

**Simulation** (créées par T9.3 à T9.8) : `Ennemis.vulnerabilite: PackedFloat32Array` (5 valeurs par ennemi, une par type, rangées à plat), `Ennemis.vulnerabiliser(i: int, type_degats: int, ratio: float, duree: float) -> void`, `Ennemis.maudire_degats(i, ratio, duree)`, `Ennemis.maudire_toucher(i, ratio, duree)`, `Ennemis.repousser(i: int, distance: float, depuis: Vector2, facteur: float) -> void`, `Ennemis.siphonner(i, ressource: int, par_seconde, duree)` ; `Tir.Bilan.mana: float` (mana gagnée par le pas) ; `Arene.mana_gagnee(montant: float) -> void` ; `class Poses` (`sim/poses.gd`, zones et bombes) : `ajouter_zone(…)`, `ajouter_bombe(…)`, `avancer(dt: float, ennemis: Ennemis, …) -> Tir.Bilan`, `vider() -> void`, `vers_vue(vue: VueArene) -> void` ; `class Allies` (`sim/allies.gd`) : `invoquer(unite: int, pos: Vector2, duree: float, degats: float, type_degats: int, arme: int) -> int`, `avancer(dt, ennemis, …) -> Tir.Bilan`, `vider() -> void`, `vers_vue(vue: VueArene) -> void` ; `ArmeEquipee.phase_deg: float` (état du tir tournant) ; `Equilibrage.REFERENCE_PV_MAX_TOUR = 1000.0`, `REFERENCE_EXEMPLAIRES = 3`, `REFERENCE_AMELIORATIONS = 3` (valeurs écrites dans le calcul du rendement, comme la mana de référence de T8.7).

**Réseau, protocole version suivante (T9.9)** : `Protocole.MAX_ALLIES`, `MAX_ZONES`, `MAX_BOMBES` égaux à `partie.json` `limites` ; octets d'un allié 5 (position et index d'unité), d'une zone 7, d'une bombe 6 ; le tout dans l'état d'arène et dans l'état d'arène regardée.

**Signatures et sons (T9.18, T9.20)** : `SignaturesArmes.ids()` rend les **75** armes ; `CatalogueSons.id_tir` couvre les 75 (même règle qu'au lot 8).

## Points de vigilance du lot 9 (« Review Focus »), chacun pinglé par un test dans la tâche indiquée

1. Cumul de statuts : cent coups de vingt armes sur les mêmes ennemis, deux malédictions sur un ennemi, vulnérabilités de types différents, siphon et vol de vie ensemble : plafonds exacts, jamais de valeur non finie, jamais un dégât négatif, la durée se rafraîchit au lieu de s'additionner (T9.3, T9.4).
2. Alliés, zones et bombes : disparus à la fin de la manche, à la mort de la tour et à la fin de la partie ; plafonds globaux tenus quand 255 armes invoquent ; aucune fuite sur cent manches ; une zone ou une bombe dont les ennemis sont tous morts ou purgés ne plante pas (T9.7, T9.8).
3. Déterminisme à 20 Hz : deux parties de même graine, avec tir tournant, zones, bombes et invocations, donnent la même empreinte de vue sur 600 pas ; les alliés agissent dans l'ordre de leur identifiant, les ex æquo de cible départagés par l'identifiant (T9.6, T9.7, T9.8).
4. Réseau avec 255 armes dont des invocatrices : un état de mille ennemis, 64 alliés, 32 zones et 32 bombes tient sous `Protocole.MAX_TAILLE` et sous le budget de 50 000 octets par seconde et par client ; tous les paquets forgés ou tronqués rendent `null` ou `{}` (T9.9).
5. Plafonds d'amélioration : le produit des facteurs de dégâts reste sous `facteur_degats_max` avec les 87 améliorations achetées ; une croissance dans le temps reste bornée en mode sans fin ; la résurrection ne joue qu'une fois par partie ; un maximum de mana ou de PV qui monte ne soigne pas deux fois (T9.10, T9.11, T9.12).
6. Lisibilité : 75 signatures distinctes deux à deux sur forme **et** couleur du projectile, toujours lisibles au zoom le plus lointain ; avec 255 armes qui tirent, le plafond de 200 effets simultanés tient et les alliés restent distincts des ennemis (T9.18, T9.19).
7. Boutique : la part d'armes parmi les offres de la manche 1 ne tombe pas sous celle d'avant le lot moins dix points, et chaque arme et chaque amélioration reste proposable à une manche (T9.22).
8. Noms d'origine : un nom d'un seul mot qui est aussi un mot courant (français ou anglais), ou un chemin de fichier du pack d'images, ne fait pas échouer le garde-fou à tort, et un vrai nom d'origine glissé dans `data/`, `i18n/` ou le code le fait échouer (T9.1).
9. Performance : 75 armes équipées en une partie, 1 000 ennemis, 64 alliés, 32 zones et 32 bombes, moins de 5 ms par pas en moyenne (T9.8).

---

## Session « Garde-fou »

### Task 9.1 : Garde-fou des noms d'origine — `sonnet`

- [ ] **Objectif :** un test lit les noms d'armes et d'améliorations de `docs/tower_survivors.md` (§4.1 et §4.2) et échoue si l'un d'eux apparaît dans `data/`, `i18n/`, `sim/`, `ui/`, `visuels/` (et, par prudence, `app/`, `reseau/`, `sons/`). Il vient **avant** les 45 armes et les 44 améliorations, pour que chaque nom écrit ensuite soit contrôlé. Il complète `test_aucun_nom_de_la_map_d_origine` de `test_contenu.gd`, qui ne regarde que quelques noms et seulement les champs des données : il reste, ce nouveau test est le filet complet.
- **Conception :** §6.13 (garde-fou), spec du jeu ligne 10 (noms originaux).
- **Fichiers :** `tests/outils/noms_origine.gd` (nouveau, `class_name NomsOrigine`), `tests/unitaires/test_noms_origine.gd` (nouveau), `docs/tower_survivors.md` (une seule modification : ajouter un §4.3 « Noms hors boutique » en liste à puces, pour que les noms que le document ne range pas dans un tableau soient lisibles par la machine).
- **Lire :** `docs/tower_survivors.md` §4.1 et §4.2 (le **format** des tableaux : première colonne, ligne d'en-tête, ligne de séparation ; les phrases « Hors pool » sous les tableaux) ; `tests/unitaires/test_contenu.gd` `INTERDITS` et `test_aucun_nom_de_la_map_d_origine`.
- **Interfaces :** produit `NomsOrigine.lire(chemin: String = "res://docs/tower_survivors.md") -> PackedStringArray` (noms bruts, dans l'ordre du document, sans doublon) ; `NomsOrigine.normaliser(texte: String) -> String` (minuscules, sans accents par `TextServer.strip_diacritics`, apostrophes typographiques ramenées à `'`, espaces insécables et fines ramenées à l'espace simple) ; `NomsOrigine.trouver(texte: String, noms: PackedStringArray) -> PackedStringArray` (les noms contenus dans le texte) ; `NomsOrigine.HOMOGRAPHES_FRANCAIS: Array[String]` (liste **fermée**, voir ci-dessous) ; `NomsOrigine.sans_chemins_d_images(source: String) -> String`.
- **Règles de recherche (sans liste d'exceptions large) :**
  - nom de plusieurs mots : sa forme normalisée se cherche **entière**, entre deux limites de mots (lookarounds Unicode `(?<![\p{L}\p{N}])` et `(?![\p{L}\p{N}])`, drapeau `u`, jamais `\b`) ;
  - nom d'un seul mot : mot entier, même limites ;
  - **homographes** : un nom d'un seul mot qui est aussi un mot courant du français (le cas existe : un nom d'amélioration d'origine est la clé de données `recharge`) n'est cherché **que comme nom entier** d'un objet (`nom` d'une arme, d'une amélioration, d'une famille, d'une unité), jamais comme mot d'un texte ou d'un code. `HOMOGRAPHES_FRANCAIS` est écrite dans le test, **au plus 3 entrées**, chacune avec un commentaire qui dit pourquoi ; un test vérifie que chaque entrée est bien l'un des noms lus (anti-dérive) et que la liste ne dépasse pas 3 ;
  - **chemins d'images du pack** : dans les fichiers `.gd`, tout littéral entre guillemets qui contient `/` est retiré avant la recherche (le pack nomme ses dossiers et fichiers avec des mots anglais ordinaires : un nom d'origine apparaît aujourd'hui dans deux chemins de `visuels/`), puis la recherche porte sur le reste ;
  - on lit : tous les `.gd`, `.json`, `.csv`, `.tres`, `.tscn` des dossiers cités, hors `tests/` et `docs/` ; pour les JSON, les clés **et** les valeurs.
- **Tests :** `tests/unitaires/test_noms_origine.gd`.
  - `test_la_liste_lue_compte_exactement_les_noms_du_document` : 75 noms d'armes et 84 d'améliorations (159), plus le §4.3 ; un fichier absent ou vide fait **échouer** le test, il ne le saute pas.
  - `test_aucun_nom_d_origine_dans_les_donnees_les_textes_et_le_code` : boucle sur tous les noms et tous les fichiers ; le message cite le nom, le fichier et la ligne.
  - `test_un_nom_d_origine_dans_un_texte_est_detecte` : pour chaque nom de la liste (en boucle), un texte français qui le contient entre deux mots est trouvé, y compris avec une majuscule, des accents autour, une espace insécable ou une apostrophe typographique à la place d'une apostrophe droite.
  - `test_un_nom_d_origine_collé_a_d_autres_lettres_n_est_pas_un_faux_positif` : le nom précédé ou suivi d'une lettre ou d'un chiffre n'est pas trouvé (cas adverses : accent, point final, tiret).
  - `test_un_homographe_n_est_refuse_que_comme_nom_entier` : « recharge réduite » passe ; un objet nommé exactement comme lui échoue (le test construit le dictionnaire, il ne touche pas aux données).
  - `test_un_chemin_d_image_du_pack_ne_declenche_pas_le_garde_fou` : `sans_chemins_d_images` retire `"A/B + C/d.png"` et garde `var x := "<un nom de la liste>"` hors chemin.
  - `test_la_liste_des_homographes_est_fermee_et_justifiee` (au plus 3, chaque entrée est un nom lu).
  - **Mutation à faire à la main avant de rendre :** glisser un nom d'origine dans `data/armes.json` et dans un `.gd` de `sim/`, voir le test échouer, annuler (`git checkout -- fichier`).
- **Vérif :** `T --filtre test_noms_origine`, puis `tools/verifier.sh`. Rapport : la liste des homographes retenue et les fichiers qui ont demandé le retrait de chemins.

## Session « Simulation »

### Task 9.2 : Interfaces et schémas des mécaniques, familles d'améliorations — `sonnet`

- [ ] **Objectif :** figer en code les interfaces du lot, sans aucun changement de comportement ni aucune donnée de jeu nouvelle : bits de statut, genres et statuts d'événement, champs de vue, schémas validés (nouveaux `kind` d'effet et de statut, champs facultatifs d'arme, stats d'amélioration, `unites.json`, nouvelles clés de `partie.json`), champs neutres de `StatsTour`, champ `famille` des améliorations. Les tests qui figent 70 offres, 30 armes ou 40 améliorations deviennent pilotés par les données.
- **Conception :** §6.13, §6.11, « Interfaces figées du lot 9 ».
- **Fichiers :** `sim/types.gd` (bits, `FAMILLES_AMELIORATION`), `sim/stats_tour.gd`, `sim/inventaire.gd` (`_appliquer` : accepte et accumule chaque stat), `sim/vue_arene.gd`, `sim/donnees.gd` (`_kinds_effets`, `_kinds_statuts`, `STATS_AMELIORATION`, `_valider_armes`, `_valider_ameliorations`, `FICHIERS_LISTE`, `unites`, `ids_unites`, clés de `partie.json`), `data/partie.json`, `data/unites.json` (`[]`), `data/ameliorations.json` (champ `famille` des améliorations existantes, y compris celles de T8.7), `tests/unitaires/test_donnees.gd`, `test_donnees_categories.gd`, `test_contenu.gd`, `test_contenu_donnees.gd`, `test_vues.gd`, `test_inventaire.gd`, et **seulement** les deux constantes de 70 offres de `test_boutique_images.gd` et `test_description_offre.gd`.
- **Lire :** `sim/donnees.gd` par `grep -n '_kinds_\|STATS_AMELIORATION\|_valider_\|_normaliser_'` ; `sim/vue_arene.gd` `GENRES_ARME`, `STATUTS_ARME`, `SCHEMA` ; `sim/inventaire.gd` `_appliquer` ; `grep -n '70\|== 30\|== 40' tests/unitaires/test_contenu*.gd`.
- **Interfaces :** produit tout ce qui est sous « Interfaces figées du lot 9 », plus `StatsTour.facteur_epines(temps_s: float) -> float` (`1 + epines_degats + epines_croissantes × tranches de croissance_pas_s écoulées`) et `Donnees.famille_de(id: String) -> String` (« » pour une arme ou un id inconnu).
- **Tests :**
  - `test_chaque_amelioration_a_une_famille_valide` et `test_famille_absente_ou_inconnue_est_refusee_en_nommant_le_fichier_et_le_champ`.
  - `test_la_famille_de_chaque_amelioration_existante_suit_ses_stats` : en boucle, table stat → famille écrite dans le test (`focalisation`, `eclaboussure`, `tirs_multiples` → `degats_classe` ; `regen`, `vol_de_vie_*` → `regeneration` ; `mana_max`, `mana_regen` → `mana` ; `relance_gratuite`, `marche_noir` → `boutique` ; `critique_chance` → `critique` ; les autres, même nom ou même famille évidente).
  - `test_chaque_nouveau_kind_d_effet_et_de_statut_est_accepte_et_chaque_champ_invalide_est_refuse` : en boucle sur les 4 effets et les 6 statuts, fiche valide acceptée, puis chaque champ à 0, négatif, `NAN`, `INF`, texte, absent : refusé avec `armes.json`, le chemin et la raison.
  - `test_les_champs_facultatifs_d_arme_sont_valides` : `degats_par_pv_max` négatif refusé, `degats_par_amelioration` avec une stat inconnue refusée, `type_secondaire: "feu"` refusé.
  - `test_une_invocation_d_une_unite_inconnue_est_refusee` ; `test_unites_json_refuse_un_modele_un_id_en_double_ou_une_vitesse_nulle`.
  - `test_chaque_nouvelle_stat_est_acceptee_et_chaque_valeur_ou_parametre_invalide_est_refuse` : en boucle sur les stats ajoutées.
  - `test_partie_json_refuse_un_plafond_hors_bornes` : `vulnerabilite.plafond` hors `]0 ; 5]`, `malediction.plafond` hors `]0 ; 1]`, limites non entières ou nulles, `facteur_degats_max` < 1.
  - `test_les_genres_et_les_statuts_d_evenement_tiennent_sur_quatre_bits` : `GENRES_ARME.size() <= 16` et `STATUTS_ARME.size() <= 16` ; chaque nouveau nom a son index d'aller-retour (`genre_depuis_nom`, `statut_depuis_nom`) et l'ordre ajoute **à la fin**.
  - `test_les_bits_de_statut_sont_distincts_et_tiennent_dans_un_octet` (1, 2, 4, 8, 16, 32, 64, 128).
  - `test_vue_arene_aller_retour_avec_allies_zones_et_bombes` : en boucle sur 0, 1, 2 et 3 entrées de chaque liste ; `from_dict` rend `null` pour un allié sans position, une zone au `reste` négatif ou non fini, plus d'entrées que `limites`.
  - `test_les_stats_neutres_au_depart` et `test_l_inventaire_accumule_chaque_nouvelle_stat` : en boucle sur les nouvelles stats, une amélioration factice change exactement le champ de même nom.
  - `test_la_table_d_images_et_les_descriptions_suivent_la_taille_des_donnees` (les deux constantes remplacées).
  - `test_aucune_arme_n_utilise_encore_les_nouveautes_des_donnees_du_lot_9` n'existe **pas** : ce serait figer un état transitoire.
- **Vérif :** `T --filtre test_donnees`, `test_vues`, `test_inventaire`, `test_contenu`, puis `tools/verifier.sh`. Rapport : `Protocole.VERSION` de `main` au moment de la tâche.

### Task 9.3 : Vulnérabilité cumulable, malédiction et repoussement (M1, M2, M3) — `sonnet`

- [ ] **Objectif :** trois statuts d'ennemi posés par les armes. **Vulnérabilité** : chaque application ajoute `ratio` aux dégâts subis du type, **cumulable entre armes et entre coups**, la somme **plafonnée** par `vulnerabilite.plafond` (par type et par ennemi), la durée rafraîchie jusqu'à `duree_max` ; elle multiplie le montant **avant** l'efficacité contre l'armure (`Ennemis.infliger`), jamais le poison ni la brûlure. **Malédiction** : deux statuts distincts, chacun non cumulable (le plus fort l'emporte, la durée se rafraîchit), plafonnés par `malediction.plafond` ; la réduction de dégâts s'applique **avant** l'esquive, l'armure et la mana de la tour ; la réduction de chances de toucher est une **réduction moyenne** des dégâts (`× (1 − chance)`, sans tirage : le déterminisme n'en dépend pas) appliquée au même endroit. **Repoussement** : l'ennemi recule de `distance` loin de la tour, jamais au-delà de `distance_max`, multiplié par `facteur_boss` pour le boss.
- **Conception :** §6.13, « Choix du plan » 10.
- **Fichiers :** `sim/ennemis.gd` (tableaux et durées, `_recalculer_bits`, `infliger`, `avancer`), `sim/tir.gd` (`_frapper` : les trois `kind`), `sim/arene.gd` si la tour doit lire les dégâts réduits ; tests nouveaux `test_ennemis_vulnerabilite.gd`, `test_ennemis_malediction.gd`, `test_repoussement.gd`, plus `test_tir.gd`.
- **Lire :** `sim/ennemis.gd` `infliger`, `etourdir`, `_avancer_statuts`, `avancer` ; `sim/tir.gd` `_frapper` ; `sim/arene.gd` `_pas_tour_et_ennemis`.
- **Interfaces :** produit `Ennemis.vulnerabiliser`, `maudire_degats`, `maudire_toucher`, `repousser` (figées plus haut) ; bits `STATUT_VULNERABLE` et `STATUT_MAUDIT` tenus à jour ; `Ennemis.avancer` applique la malédiction à `degats_tour` et à `attaquants_cac`.
- **Tests :**
  - `test_la_vulnerabilite_multiplie_les_degats_du_type_et_pas_les_autres` : en boucle sur les 5 types, ennemi sans armure, +20 % : le type touché subit 120 %, les quatre autres 100 %.
  - `test_la_vulnerabilite_se_cumule_entre_coups_et_entre_armes_jusqu_au_plafond` : 100 applications de deux armes, somme exactement `plafond`, jamais au-dessus ; **Review Focus 1**.
  - `test_la_vulnerabilite_se_rafraichit_et_expire_sans_s_additionner_dans_le_temps` : après `duree`, retour à 0 ; une réapplication à mi-durée repart de `duree`, pas de `duree + reste`.
  - `test_la_vulnerabilite_ne_change_ni_le_poison_ni_la_brulure` ; `test_la_vulnerabilite_passe_avant_l_efficacite_d_armure` (valeur exacte pour une armure lourde et un type efficace).
  - `test_un_ennemi_mort_ou_un_indice_inconnu_ne_plante_pas` pour les quatre appels ; `test_un_ratio_non_fini_ou_negatif_est_ignore`.
  - `test_deux_maledictions_sur_un_ennemi_sont_independantes_et_non_cumulables` : le plus fort l'emporte, plafond tenu, jamais un multiplicateur négatif ; **Review Focus 1**.
  - `test_la_malediction_de_degats_reduit_les_attaques_au_corps_a_corps_et_a_distance` : en boucle sur un Guerrier et un Archer ; `test_la_malediction_de_toucher_reduit_en_moyenne_sans_consommer_le_hasard` (le tirage de l'arène est identique avec et sans malédiction).
  - `test_la_malediction_passe_avant_l_esquive_l_armure_et_la_mana` : valeurs exactes, ordre figé.
  - `test_le_repoussement_eloigne_de_la_tour_de_la_distance_demandee` ; `test_il_est_borne_par_distance_max_et_nul_pour_le_boss` ; `test_un_ennemi_deja_loin_n_est_pas_repousse_hors_du_cercle_d_apparition` ; `test_un_ennemi_sur_la_tour_est_repousse_dans_une_direction_definie` (pas de division par zéro).
  - `test_chaque_nouveau_kind_de_statut_est_pose_par_le_tir` : en boucle sur les trois, une arme factice.
  - `test_le_pas_reste_sous_5_ms_avec_mille_ennemis_maudits_et_vulnerables`.
- **Vérif :** `T --filtre test_ennemis_`, `test_repoussement`, `test_tir`, puis `tools/verifier.sh`.

### Task 9.4 : Siphon de mana et de vie, mana au coup (M4) — `haiku`

- [ ] **Objectif :** `siphon` : pendant `duree` après avoir été touché, l'ennemi verse `par_seconde` à la tour (mana ou PV selon `ressource`), tant qu'il est vivant ; un nouveau siphon de même ressource rafraîchit la durée et garde le plus fort débit. `mana_au_coup` : chaque coup qui touche rend `valeur` de mana. La mana ne dépasse jamais `Arene.mana_max()` (T8.7), les PV jamais le maximum ; sans mana maximale, rien n'est gagné et rien ne plante.
- **Conception :** §6.13, §6.4 (mana en bouclier).
- **Fichiers :** `sim/ennemis.gd` (tableaux de siphon, bit `STATUT_SIPHONNE`, `avancer` rend `"siphon_mana"` et `"siphon_vie"`), `sim/tir.gd` (`_frapper`, `Bilan.mana`), `sim/arene.gd` (`mana_gagnee`, fusion des bilans) ; tests nouveaux `test_siphon.gd`, plus `test_arene_tour.gd`, `test_tir.gd`.
- **Lire :** `sim/arene.gd` `_pas_armes`, `synchroniser` et la mana de T8.7 ; `sim/ennemis.gd` `avancer`.
- **Interfaces :** produit `Ennemis.siphonner(i, ressource, par_seconde, duree)` (`ressource` : 0 mana, 1 vie), `Tir.Bilan.mana`, `Arene.mana_gagnee(montant)`.
- **Tests :**
  - `test_un_ennemi_siphonne_verse_son_debit_chaque_seconde_a_la_tour` : mana et PV, 4 s, somme exacte.
  - `test_le_siphon_s_arrete_a_la_mort_de_l_ennemi_et_a_la_fin_de_sa_duree`.
  - `test_deux_ennemis_siphonnes_versent_chacun_leur_debit` ; `test_un_siphon_plus_faible_ne_remplace_pas_un_plus_fort_mais_rafraichit_la_duree`.
  - `test_la_mana_gagnee_ne_depasse_pas_le_maximum_et_sans_maximum_rien_n_est_gagne` : maximum 0, 40, ratio 100 ; **Review Focus 5** (aucun double gain à la hausse du maximum).
  - `test_les_pv_siphonnes_ne_depassent_pas_le_maximum`.
  - `test_chaque_coup_qui_touche_rend_la_mana_au_coup_et_un_coup_sans_degats_n_en_rend_pas` ; `test_un_tir_multiple_rend_la_mana_de_chaque_coup`.
  - `test_la_mana_rendue_sert_de_bouclier_au_coup_suivant` (intégration avec l'absorption de T8.7).
  - `test_la_mana_gagnee_est_propre_a_chaque_arene`.
- **Vérif :** `T --filtre test_siphon`, `test_arene_tour`, puis `tools/verifier.sh`.

### Task 9.5 : Dégâts selon PV maximum, exemplaires, améliorations possédées ; épines en second type (M5, M10) — `sonnet`

- [ ] **Objectif :** trois champs d'arme qui ajoutent aux dégâts de base (`degats_par_pv_max × PV maximum de la tour` ; `degats_par_exemplaire × (exemplaires − 1) × dégâts de base` ; `ratio × nombre d'améliorations possédées portant la stat × dégâts de base`, une amélioration achetée n fois compte n fois), **le bonus total borné** par `partie.json` `armes.bonus_selon_stat_max` (multiple des dégâts de base), les trois s'ajoutant à `degats_par_mana_max` de T8.7 avant critique et bonus de type. `type_secondaire: "epines"` : les dégâts de l'arme sont multipliés par `StatsTour.facteur_epines(temps)` (T9.2). L'estimation de rendement de `sim/equilibrage.gd` lit ces champs avec les valeurs de référence.
- **Conception :** §6.13, « Choix du plan » 1 et 6.
- **Fichiers :** `sim/tir.gd` (`degats_de_base`), `sim/inventaire.gd` (`exemplaires(id)`, `compter_stat(stat)`), `sim/arene.gd` (passe PV maximum et temps au contexte), `sim/equilibrage.gd` (`REFERENCE_*`, `dps_estime`) ; tests `test_tir_degats_selon.gd` (nouveau), `test_inventaire.gd`, `test_equilibrage.gd`.
- **Lire :** `sim/tir.gd` `avancer_arme`, `_creer` et l'usage de `degats_par_mana_max` (T8.7) ; `sim/inventaire.gd` ; `sim/equilibrage.gd` en entier (52 lignes).
- **Interfaces :** produit `Tir.degats_de_base(arme: Dictionary, stats: StatsTour, pv_max_tour: float, exemplaires: int, ameliorations_par_stat: Dictionary, temps_s: float) -> float` (fonction pure, testée seule), `Inventaire.exemplaires(id_arme: String) -> int`, `Inventaire.compter_stat(stat: String) -> int`, `Contexte.pv_max_tour`.
- **Tests :**
  - `test_degats_par_pv_max_ajoute_ratio_fois_les_pv_maximum_de_la_tour` : 100 de base, ratio 0,01, PV maximum 1 000 → 110.
  - `test_degats_par_exemplaire_croit_avec_chaque_copie` : 1, 2, 5 copies ; une seule copie : aucun bonus.
  - `test_degats_par_amelioration_compte_chaque_exemplaire_acheté` : 0, 1, 3 améliorations portant la stat ; une amélioration d'une autre stat ne compte pas.
  - `test_le_bonus_total_est_borne_meme_avec_255_exemplaires_et_toutes_les_ameliorations` ; **Review Focus 5**.
  - `test_les_trois_bonus_et_la_mana_s_additionnent_avant_le_critique` ; `test_un_champ_absent_ou_nul_ne_change_rien` (toutes les armes d'aujourd'hui gardent leurs dégâts, en boucle).
  - `test_le_type_secondaire_epines_multiplie_les_degats_par_le_facteur_d_epines` : sans amélioration d'épines, aucun changement ; avec, le facteur exact ; l'efficacité contre l'armure reste celle du type principal.
  - `test_l_estimation_de_rendement_lit_les_champs_avec_les_valeurs_de_reference` ; `test_une_arme_sans_champ_garde_son_rendement` (boucle sur les armes existantes, valeurs identiques à avant).
- **Vérif :** `T --filtre test_tir_degats_selon`, `test_equilibrage`, `test_contenu`, puis `tools/verifier.sh`.

### Task 9.6 : Tir tournant (M7) — `sonnet`

- [ ] **Objectif :** effet `tournant` : à chaque tir, `branches` rayons partent de la tour à des angles régulièrement répartis, décalés de `phase_deg` ; chaque rayon touche tout ennemi à portée dont la distance au segment (tour → portée de l'arme) est au plus `largeur` ; la phase avance de `pas_deg` dans le sens de l'arme, modulo 360. Aucun hasard : l'angle ne dépend que du nombre de tirs de **cette** arme (deux exemplaires ont chacun leur phase, départ 0). Un ennemi n'est touché qu'une fois par tir. Les coups passent par `Tir._frapper` (critique, statuts, mana au coup). Un événement `tir` par rayon, genre `tournant`, `de` la tour, `vers` le bout du rayon, `rayon` la largeur.
- **Conception :** §6.13, comparatif §7.1 (« motif tournant »).
- **Fichiers :** `sim/tir.gd` (`_tournant`, aiguillage de `_effet`), `sim/arme_equipee.gd` (`phase_deg`), `sim/equilibrage.gd` (estimation : `branches × 1,0` cibles) ; tests `test_tir_tournant.gd` (nouveau), `test_equilibrage.gd`.
- **Lire :** `sim/tir.gd` `_effet`, `_zone`, `_lancer_onde` ; `sim/arme_equipee.gd`.
- **Interfaces :** produit `Tir._tournant(ctx, effet) -> bool`, `ArmeEquipee.phase_deg`.
- **Tests :**
  - `test_la_phase_avance_de_pas_deg_dans_le_bon_sens_et_boucle_a_360` : en boucle sur `horaire` et `antihoraire`.
  - `test_un_ennemi_dans_le_rayon_est_touche_et_un_ennemi_hors_portee_ou_hors_largeur_ne_l_est_pas`.
  - `test_sur_un_tour_complet_chaque_ennemi_a_portee_est_touche_au_moins_une_fois` (largeur et pas choisis pour couvrir) ; `test_un_ennemi_n_est_touche_qu_une_fois_par_tir_meme_avec_plusieurs_rayons`.
  - `test_les_branches_sont_regulierement_reparties` : 1, 2, 3, 4, 8 branches.
  - `test_deux_exemplaires_de_la_meme_arme_ont_chacun_leur_phase`.
  - `test_le_tir_tournant_ne_consomme_pas_le_hasard_hors_critique` ; `test_deux_parties_de_meme_graine_donnent_les_memes_evenements_sur_600_pas` ; **Review Focus 3**.
  - `test_un_evenement_par_rayon_porte_le_genre_tournant_et_l_arme`.
  - `test_le_tir_tournant_declenche_les_statuts_et_la_mana_au_coup_de_l_arme`.
- **Vérif :** `T --filtre test_tir_tournant`, `test_tir`, puis `tools/verifier.sh`.

### Task 9.7 : Zones posées et bombes à retardement (M8, M9) — `sonnet`

- [ ] **Objectif :** `sim/poses.gd` (`Poses`) tient les zones et les bombes de l'arène. **Zone posée** : posée sur la cible choisie par le ciblage de l'arme, elle inflige `ratio × dégâts` à tous les ennemis de son rayon toutes les `periode` secondes pendant `duree`, statuts de l'arme compris ; au-delà de `max_actives` par arme, la plus ancienne disparaît. **Bombe** : posée sur la position de la cible (elle ne la suit pas), elle explose après `delai` en infligeant `ratio × dégâts` dans le rayon, statuts compris, puis disparaît. Les dégâts, le critique et les bonus sont **figés à la pose**. Plafonds globaux `limites.zones` et `limites.bombes` (la plus ancienne cède). Tout disparaît à la fin de la manche, à la mort de la tour et sur `vider()`. Les vues portent `zones` et `bombes` ; l'explosion émet un `impact` de genre `bombe`, chaque impulsion un `impact` de genre `zone_posee`.
- **Conception :** §6.13, « Choix du plan » 3.
- **Fichiers :** `sim/poses.gd` (nouveau), `sim/tir.gd` (effets `zone_posee` et `bombe` : ils posent, ne frappent pas), `sim/arene.gd` (`poses`, pas, purge, `vue`), `sim/equilibrage.gd` (zone : `3 × duree / periode × ratio` cibles ; bombe : `3 × ratio`) ; tests `test_poses.gd` (nouveau), `test_arene.gd`, `test_equilibrage.gd`.
- **Lire :** `sim/arene.gd` `_pas_armes`, `demarrer_manche`, `est_detruite`, `vue` ; `sim/tir.gd` `_poser_mine` et `_declencher_mines`, le modèle le plus proche.
- **Interfaces :** produit `Poses` (figée plus haut) ; `Arene.poses: Poses`.
- **Tests :**
  - `test_une_zone_inflige_ses_degats_a_chaque_periode_pendant_sa_duree_et_pas_apres` : nombre exact d'impulsions.
  - `test_une_zone_touche_tous_les_ennemis_du_rayon_et_aucun_en_dehors` ; `test_une_zone_pose_les_statuts_de_l_arme`.
  - `test_la_zone_la_plus_ancienne_cede_au_dela_de_max_actives_et_de_la_limite_globale`.
  - `test_une_bombe_explose_apres_son_delai_a_l_endroit_ou_elle_a_ete_posee` : la cible a bougé, la bombe non ; `test_une_bombe_sans_ennemi_dans_le_rayon_disparait_sans_erreur`.
  - `test_les_degats_sont_figes_a_la_pose` : une amélioration achetée après n'y change rien.
  - **Review Focus 2 :** `test_tout_disparait_a_la_fin_de_la_manche_a_la_mort_de_la_tour_et_sur_vider` ; `test_aucune_fuite_sur_cent_manches` (le nombre d'entrées de `Poses` revient à 0 à chaque manche) ; `test_une_zone_dont_tous_les_ennemis_sont_morts_ou_purges_ne_plante_pas`.
  - `test_la_vue_porte_les_zones_et_les_bombes_avec_leur_temps_restant` ; `test_l_explosion_et_les_impulsions_emettent_un_impact_du_bon_genre`.
  - `test_deux_parties_de_meme_graine_donnent_la_meme_empreinte_de_vue_sur_600_pas` ; **Review Focus 3**.
  - `test_trente_deux_zones_et_trente_deux_bombes_contre_mille_ennemis_sous_5_ms_par_pas`.
- **Vérif :** `T --filtre test_poses`, `test_arene`, puis `tools/verifier.sh`.

### Task 9.8 : Invocation d'alliés temporaires (M6) — `sonnet`

- [ ] **Objectif :** effet `invocation` : à chaque tir de l'arme (sa recharge fait la période), une unité de `data/unites.json` apparaît près de la tour pour `duree` secondes. Elle marche à sa `vitesse` vers l'ennemi le plus proche situé à moins de `rayon_garde` de la tour (départage : plus petit identifiant), l'attaque à sa `portee` toutes les `cadence` secondes avec `ratio_degats × dégâts de base de l'arme figés à l'invocation` (type, efficacité, critique et bonus de l'arme ; pas de statuts), puis revient près de la tour s'il n'y a plus de cible. Pas de PV : les ennemis l'ignorent. `max_actives` par arme et `limites.allies` global : la plus proche de sa fin cède. Les alliés agissent dans l'ordre de leur identifiant et **cherchent leur cible toutes les 0,25 s** (échelonnées par identifiant) pour tenir le budget de temps. Ils disparaissent à la fin de la manche, à la mort de la tour et sur `vider()`. Données : au moins deux unités (une par modèle `guerrier` et `archer`, noms originaux en français).
- **Conception :** §6.13, comparatif §7.1 (invocation), « Choix du plan » 2 et 3.
- **Fichiers :** `sim/allies.gd` (nouveau, `class_name Allies`, tableaux compacts), `sim/tir.gd` (effet `invocation`), `sim/arene.gd` (`allies`, pas, purge, `vue`), `sim/equilibrage.gd` (estimation : un allié compte `duree / cadence × ratio_degats` coups, borné par `max_actives`), `data/unites.json` ; tests `test_allies.gd` (nouveau), `test_arene.gd`, `test_arene_charge.gd`, `test_equilibrage.gd`.
- **Lire :** `sim/ennemis.gd` `choisir` (même départage) ; `sim/arene.gd` comme T9.7 ; `docs/tiny_swords.md` « Unités » (le guerrier et l'archer existent en 4 couleurs, tous déjà pris par les 24 ennemis).
- **Interfaces :** produit `Allies` (figée plus haut) ; `Arene.allies: Allies`.
- **Tests :**
  - `test_une_invocation_cree_une_unite_pour_sa_duree_et_la_retire_ensuite`.
  - `test_l_allie_marche_vers_l_ennemi_le_plus_proche_dans_le_rayon_de_garde_et_ignore_les_autres` ; `test_deux_ennemis_a_egale_distance_sont_departages_par_l_identifiant`.
  - `test_l_allie_attaque_a_sa_portee_a_sa_cadence_avec_le_ratio_des_degats_figes` : valeur exacte, efficacité d'armure comprise.
  - `test_l_allie_revient_vers_la_tour_sans_cible`.
  - `test_les_ennemis_ignorent_les_allies` (la tour reçoit les mêmes dégâts avec et sans alliés).
  - `test_la_plus_proche_de_sa_fin_cede_au_dela_de_max_actives_et_de_la_limite_globale` : 255 armes invocatrices (en boucle sur des exemplaires), jamais plus de `limites.allies` ; **Review Focus 2**.
  - **Review Focus 2 :** `test_les_allies_disparaissent_a_la_fin_de_la_manche_a_la_mort_de_la_tour_et_sur_vider` ; `test_aucune_fuite_sur_cent_manches`.
  - `test_les_allies_agissent_dans_l_ordre_de_leur_identifiant_et_deux_parties_de_meme_graine_ont_la_meme_empreinte_sur_600_pas` ; **Review Focus 3**.
  - `test_chaque_coup_d_un_allie_emet_un_evenement_du_genre_invocation_et_l_arme`.
  - `test_la_vue_porte_les_allies_avec_l_index_de_leur_unite`.
  - **Review Focus 9 :** `test_soixante_quinze_armes_equipees_mille_ennemis_soixante_quatre_allies_zones_et_bombes_sous_5_ms_par_pas` : les 75 armes du catalogue en boucle si elles existent, sinon les armes d'aujourd'hui répétées jusqu'à 75 ; si le seuil n'est pas tenu, allonger l'intervalle de recherche des alliés ou chercher par grille avant de relever le seuil.
- **Vérif :** `T --filtre test_allies`, `test_arene_charge`, puis `tools/verifier.sh`.

### Task 9.9 : Protocole : alliés, zones et bombes — `sonnet`

- [ ] **Objectif :** transporter `allies`, `zones` et `bombes` dans l'état d'arène et dans l'état d'arène regardée, avec la montée de version du lot. Décodage défensif et fuzz comme les versions précédentes ; les nouveaux genres et statuts d'événement (4 bits) ne changent pas le format mais l'ancien client ne sait pas les lire : c'est ce qui motive la version.
- **Conception :** §6.11 de la conception du lot 8, §6.13.
- **Fichiers :** `reseau/protocole.gd` ; tests `test_protocole.gd`, `test_protocole_resultat.gd`, `test_protocole_jeton.gd` (version), `test_serveur_debit.gd`.
- **Lire :** `reseau/protocole.gd` : `grep -n 'static func\|^const'`, puis `encoder_etat_arene` et `decoder_etat_arene` par plage ; `git log origin/main -3 -- reseau/protocole.gd` et `grep -n 'const VERSION' reseau/protocole.gd` **sur `origin/main` au moment de la tâche**.
- **Interfaces :** consomme T9.2, T9.7, T9.8. Produit `Protocole.VERSION` = celle de `main` + 1, `MAX_ALLIES`, `MAX_ZONES`, `MAX_BOMBES` (lus dans `partie.json`), `TAILLE_FIXE` recalculée.
- **Tests :**
  - `test_la_version_a_ete_incrementee_et_toutes_les_precedentes_sont_refusees` : en boucle de 1 à `VERSION − 1`, un bonjour est refusé avec un motif.
  - `test_allies_zones_et_bombes_traversent_le_protocole` : en boucle sur 0, 1, 2, 3 et la limite de chaque liste.
  - `test_plus_que_la_limite_est_refuse_a_l_encodage_et_au_decodage`.
  - `test_chaque_genre_et_chaque_statut_d_evenement_traverse_le_protocole` : en boucle sur `GENRES_ARME` et `STATUTS_ARME`.
  - `test_l_etat_d_arene_regardee_porte_aussi_allies_zones_et_bombes`.
  - **Review Focus 4 :** `test_un_etat_de_mille_ennemis_255_armes_64_allies_32_zones_et_32_bombes_tient_sous_max_taille` et `test_le_debit_de_l_arene_la_plus_chargee_reste_sous_50_000_octets_par_seconde` (hors densités, mesure comme T8.10).
  - **Review Focus 4 :** `test_aucun_paquet_forge_ne_leve_d_exception` : tous les préfixes d'un état valide, puis 2 000 tableaux d'octets tirés d'une graine fixe, un index d'unité hors catalogue, un `reste` non fini : `null` ou `{}`.
  - `test_la_position_d_un_allie_garde_l_erreur_de_quantification_du_protocole`.
- **Vérif :** `T --filtre test_protocole`, `test_serveur_debit`, puis `tools/verifier.sh`.

## Session « Améliorations »

Règle commune aux trois tâches : **chaque nouvelle stat est son propre facteur** (voir « Choix du plan » 5). Les effets qui croissent avec le temps portent un champ `max` (obligatoire, validé par T9.2 : une croissance sans borne est refusée) et lisent le temps de partie, jamais l'horloge ; le produit des facteurs de dégâts est borné par `ameliorations.facteur_degats_max` au seul endroit où il se calcule, `Tir.facteur_degats(ctx, bits_ennemi) -> float` (créé par T9.10, étendu par T9.11 et T9.12). Chaque tâche de contenu écrit `famille`, `categorie`, `rarete`, `prix`, `nom` et `description` (français, original, mêmes règles de typographie que les existantes), ajoute les images de ses offres, et étend `tests/unitaires/test_catalogue_ameliorations.gd` (créé par T9.10 : constante `FAMILLES_TERMINEES`, `CIBLES` des quinze familles ; `test_les_familles_terminees_atteignent_leur_cible` lit l'effectif **dans les données**, « au moins la cible »). Les prix suivent la hiérarchie de rareté des tests existants (`test_le_prix_moyen_croit_avec_la_rarete…`, `test_une_epique_coute_plusieurs_minutes_de_revenu`).

### Task 9.10 : Améliorations de dégâts, d'états et de classe d'arme (18) — `sonnet`

- [ ] **Objectif :** consommer `croissance` et `par_arme_commune` (`degats_type`, `degats_global`), `degats_classe`, `etat_degats`, `etat_duree` et `degats_contre_etat`, puis écrire **18 améliorations** : `degats_type` +5 (un palier épique par type de dégâts, avec `par_arme_commune`), `degats_global` +1 (avec `croissance`), `degats_classe` +4 (une par classe : onde, portée courte, portée longue, arme commune), `etats` +8 (poison dégâts, brûlure dégâts, poison durée, brûlure durée, étourdissement durée, contre étourdi, contre empoisonné, contre ralenti). Classes : `onde` = l'arme a un effet `onde` ; `portee_courte` = portée ≤ 750 ; `portee_longue` = portée ≥ 1 000 ; `commune` = rareté commune. États : `etourdi`, `empoisonne`, `ralenti` sont les bits `STATUT_*` de l'ennemi visé.
- **Conception :** §6.13, comparatif §6.2 et §7.2 (familles « dégâts », « classe », « états »).
- **Fichiers :** `sim/inventaire.gd` (`_appliquer`, `recalculer`), `sim/stats_tour.gd`, `sim/tir.gd` (`facteur_degats`, durée et dégâts des états), `sim/ennemis.gd` (durée du poison et de la brûlure, de l'étourdissement), `data/ameliorations.json`, `visuels/images_offres.gd` (section des améliorations de dégâts, d'états et de classe), `tests/unitaires/test_catalogue_ameliorations.gd` (nouveau), `test_inventaire.gd`, `test_tir.gd`, `test_ennemis_statuts.gd`.
- **Lire :** `sim/inventaire.gd` en entier (134 lignes) ; `sim/tir.gd` `_frapper` et `_creer` ; `sim/stats_tour.gd`.
- **Interfaces :** produit `Tir.facteur_degats(ctx: Contexte, bits_ennemi: int) -> float` (type × global × classe × contre-état, borné), `StatsTour.facteur_classe(arme: Dictionary) -> float`, `StatsTour.facteur_contre_etat(bits: int) -> float`.
- **Tests :**
  - `test_la_croissance_ajoute_sa_valeur_a_chaque_tranche_de_temps_et_s_arrete_a_son_max` : 0, 1, 10 tranches, mode sans fin à la manche 60 ; **Review Focus 5**.
  - `test_par_arme_commune_compte_les_armes_communes_du_type_possedees` ; pour le global, tous types.
  - `test_chaque_classe_ne_boost_que_les_armes_de_sa_classe` : en boucle sur les 4 classes et sur toutes les armes de `data/`.
  - `test_chaque_etat_boost_seulement_ce_qu_il_dit` : dégâts de poison ×(1 + valeur), durée de brûlure, durée d'étourdissement (boucle sur les trois) ; sans le statut sur l'arme, aucun effet.
  - `test_les_degats_contre_un_etat_ne_valent_que_si_l_ennemi_a_cet_etat` : en boucle sur les 3 états.
  - `test_le_produit_des_facteurs_reste_sous_le_plafond_avec_les_87_ameliorations` (toutes achetées, une arme de chaque classe) ; **Review Focus 5**.
  - `test_chaque_famille_terminee_atteint_sa_cible` (familles de cette tâche) ; `test_chaque_nouvelle_amelioration_a_une_image_et_une_famille` ; `test_la_categorie_des_nouvelles_ameliorations_est_amelioration` (aucune n'est économique).
- **Vérif :** `T --filtre test_catalogue_ameliorations`, `test_inventaire`, `test_contenu`, `test_description_offre`, `test_boutique_images`, `test_noms_origine`, puis `tools/verifier.sh`.

### Task 9.11 : Améliorations d'épines, de PV, de régénération et d'armure (19) — `sonnet`

- [ ] **Objectif :** consommer les stats d'épines, de PV, de régénération et d'armure, puis écrire **19 améliorations** : `epines` +9 (`epines_degats` ×2, `epines_croissantes`, `epines_premier_coup`, `epines_soin`, `epines_reduction`, `epines_statut` pour poison, brûlure, givre, étourdissement), `pv_max` +5 (`pv_max_mult` ×2, `soin_pv_manquants`, `degats_par_pv_max`, `resurrection`), `regeneration` +2 (`regen_croissante`, `soin_periodique`), `armure` +3 (`armure_croissante`, `riposte_statut` givre et poison).
      Règles : les épines renvoient `facteur_epines(temps)` × le coup reçu (au corps à corps seulement, comme aujourd'hui) ; `epines_premier_coup` ajoute son ratio au **premier** renvoi sur chaque ennemi ; `epines_soin` rend à la tour ce ratio des dégâts renvoyés ; `epines_reduction` réduit les dégâts de corps à corps reçus **avant** l'armure et la mana (plafond 0,5) ; `epines_statut` et `riposte_statut` posent le statut sur l'attaquant qui touche ; `pv_max_mult` multiplie le maximum (un maximum qui monte soigne du même montant) ; `soin_pv_manquants` rend ce ratio des PV manquants au début de chaque manche ; `degats_par_pv_max` est un facteur de `Tir.facteur_degats` par tranche de 1 000 PV maximum ; `resurrection` relève la tour à ce ratio de son maximum **une fois par partie** ; `regen_croissante` et `armure_croissante` suivent la règle de croissance bornée ; `soin_periodique` rend `ratio × PV maximum` tous les `tous_les` secondes.
- **Conception :** §6.13, comparatif §7.2 (familles « épines », « PV », « régénération », « armure »).
- **Fichiers :** `sim/arene.gd` (`_pas_tour_et_ennemis`, `_pv_max`, résurrection, début de manche), `sim/ennemis.gd` (drapeau « déjà renvoyé » par ennemi), `sim/tir.gd` (`facteur_degats`), `sim/inventaire.gd`, `sim/stats_tour.gd`, `data/ameliorations.json`, `visuels/images_offres.gd` (section des améliorations de survie), `tests/unitaires/test_catalogue_ameliorations.gd`, `test_arene_tour.gd`, `test_ennemis_statuts.gd`.
- **Lire :** `sim/arene.gd` `_pas_tour_et_ennemis`, `_pv_borne`, `est_detruite` ; la règle des épines dans `ui/description_offre.gd` (`grep -n epines`).
- **Tests :**
  - `test_les_epines_renvoient_le_facteur_d_epines_et_toujours_seulement_le_corps_a_corps` ; `test_epines_premier_coup_ne_joue_qu_une_fois_par_ennemi` ; `test_epines_soin_rend_le_ratio_des_degats_renvoyes_sans_depasser_le_maximum`.
  - `test_epines_reduction_passe_avant_l_armure_et_la_mana_et_est_plafonnee` ; `test_chaque_statut_d_epines_et_de_riposte_est_pose_sur_l_attaquant` : en boucle sur les 4 et les 2.
  - `test_pv_max_mult_soigne_du_montant_gagne_et_un_maximum_qui_baisse_ne_tue_pas` ; `test_soin_pv_manquants_joue_au_debut_de_chaque_manche`.
  - `test_degats_par_pv_max_ajoute_son_ratio_par_tranche_de_mille_pv`.
  - **Review Focus 5 :** `test_la_resurrection_ne_joue_qu_une_fois_par_partie_meme_avec_deux_exemplaires` et `test_la_resurrection_ne_joue_pas_quand_la_tour_survit` ; `test_regen_croissante_et_armure_croissante_s_arretent_a_leur_max`.
  - `test_soin_periodique_rend_le_ratio_du_maximum_a_chaque_periode` ; `test_toute_nouvelle_stat_de_survie_est_neutre_sans_amelioration` (parties identiques à avant, empreinte de vue égale).
  - `test_chaque_famille_terminee_atteint_sa_cible` ; images et familles comme T9.10.
- **Vérif :** `T --filtre test_catalogue_ameliorations`, `test_arene_tour`, `test_contenu`, `test_description_offre`, `test_boutique_images`, `test_noms_origine`, puis `tools/verifier.sh`.

### Task 9.12 : Améliorations de mana, de revenu, de boutique et d'aura mixte (au plus 7) ; effectif final — `sonnet`

- [ ] **Objectif :** consommer `mana_max_mult`, `mana_rupture_etourdit` (quand le bouclier de mana tombe à 0 sous un coup, les ennemis du `rayon` sont étourdis `duree`, une fois par chute), `degats_tant_que_mana` et `reduction_tant_que_mana` (facteur de `Tir.facteur_degats` et réduction des coups reçus tant que la mana est au-dessus de 0), `revenu_contre_pv` (revenu fixe en plus, PV maximum en moins, jamais sous 1), `copie_prochaine_offre` (le prochain achat d'une offre de rareté au plus `raretes_max` donne un second exemplaire gratuit, **une seule fois par exemplaire de l'amélioration**) et `aura_mixte` (dans le `rayon`, dégâts de chaos par seconde aux ennemis et PV par seconde à la tour tant qu'un ennemi s'y trouve), puis écrire les améliorations qui manquent à la cible : `mana` jusqu'à 7 (au plus 4, T8.7 en a livré au moins 3), `revenu` +1, `boutique` +1, `aura_mixte` +1. **Effectif final :** les quinze familles atteignent leur cible et le total vaut **exactement 87**.
- **Conception :** §6.13, §6.4 (mana), comparatif §7.2.
- **Fichiers :** `sim/arene.gd`, `sim/boutique.gd` (`acheter`), `sim/inventaire.gd`, `sim/stats_tour.gd`, `sim/tir.gd` (`facteur_degats`), `data/ameliorations.json`, `visuels/images_offres.gd` (section mana, revenu, boutique, aura), `tests/unitaires/test_catalogue_ameliorations.gd`, `test_arene_tour.gd`, `test_boutique.gd`, `test_donnees_categories.gd`.
- **Lire :** `sim/boutique.gd` `acheter` ; `sim/arene.gd` (la mana de T8.7) ; `test_donnees_categories.gd` (la règle « `revenu` si et seulement si tous les effets sont économiques »).
- **Tests :**
  - `test_la_chute_du_bouclier_etourdit_les_ennemis_du_rayon_une_seule_fois_par_chute`.
  - `test_degats_et_reduction_tant_que_mana_ne_valent_que_mana_au_dessus_de_zero`.
  - `test_revenu_contre_pv_ajoute_l_or_retire_les_pv_et_ne_descend_pas_sous_un_pv_maximum` ; **Review Focus 5**.
  - `test_copie_prochaine_offre_double_le_prochain_achat_eligible_une_fois_et_pas_une_offre_plus_rare` : en boucle sur les 4 raretés.
  - `test_l_aura_mixte_inflige_et_soigne_tant_qu_un_ennemi_est_dans_le_rayon`.
  - `test_les_nouvelles_stats_economiques_sont_dans_la_categorie_revenu` (liste économique de `test_donnees_categories.gd` étendue à `revenu_contre_pv`).
  - **Effectif :** `test_chaque_famille_atteint_sa_cible_et_le_total_est_87` : les quinze `CIBLES`, au moins la cible par famille, exactement 87 ; `FAMILLES_TERMINEES` doit contenir les quinze (test d'anti-dérive).
  - `test_chaque_stat_du_schema_est_utilisee_par_une_amelioration` (existant, doit rester vert avec les 25 stats ajoutées) ; `test_les_87_ameliorations_ont_un_id_un_nom_une_image_et_une_description_uniques`.
- **Vérif :** `T --filtre test_catalogue_ameliorations`, `test_boutique`, `test_contenu`, puis `tools/verifier.sh`.

## Session « Armes »

Gabarit commun des tâches T9.13 à T9.17 (une par type de dégâts, dans cet ordre). Pour son type, la tâche : **promeut** en peu commune celle de ses deux communes dont le rendement (`Equilibrage.rendement`, **aux prix d'avant**) est le plus haut, ajuste son prix à son palier, puis **ajoute 9 armes** : 3 peu communes, 5 rares, 1 épique. Elle écrit pour chacune `id` (snake_case sans accent), `nom` et `description` en français originaux (aucun nom d'origine : T9.1 le contrôle), `rarete`, `prix`, `type_degats`, `degats`, `recharge`, `portee` (500, 750, 1 000 ou 1 250), `ciblage`, `effets`, `statuts` et les champs de mécaniques de la « Répartition imposée » ; **tous les chiffres sont les nôtres**, calés pour que les tests d'équilibrage existants restent verts (rendement moyen strictement croissant avec la rareté dans chaque type ; aucune arme hors de ¼ à 4 fois la médiane du type ; commune achetable dès l'or de départ ; épique de plusieurs minutes de revenu). Elle ajoute les images de ses 9 armes (`visuels/images_offres.gd`, section du type) et les lignes de sa tâche dans `tests/unitaires/test_catalogue_armes.gd`. Elle **ne touche à aucun autre type** et note dans son rapport le rendement de chaque arme, la commune promue et la forme de chaque nouvelle arme.

Tests du gabarit (écrits par T9.13, étendus par chaque tâche en ajoutant son type à `TYPES_TERMINES`) :

- `test_la_cible_d18_quinze_armes_par_type_reparties_1_6_6_2` : en boucle sur `TYPES_TERMINES`, 15 armes, et par rareté 1, 6, 6, 2.
- `test_la_commune_conservee_est_la_moins_rentable_des_deux_d_origine` : constante `RENDEMENT_AVANT` (les dix communes d'origine, rendement **mesuré par script avant toute modification**, écrite par T9.13 pour les cinq types) ; la commune promue a le rendement avant le plus haut, son prix est au moins le plus petit prix des peu communes du type.
- `test_repartition_imposee_des_mecaniques_du_type` : table de la « Répartition imposée », par type.
- `test_chaque_nouvelle_arme_agit_dans_une_arene` : en boucle sur les armes du type absentes de `RENDEMENT_AVANT`, une arène, des ennemis à portée, 100 pas : des dégâts, ou l'effet propre (une unité, une zone, une bombe, de la mana, un recul) est observé.
- `test_deux_armes_du_type_different_par_forme_statuts_mecanique_ou_portee` : les paires du type ; deux armes de même forme, mêmes statuts et même portée sont refusées (lisibilité des signatures, D5).
- `test_toute_nouvelle_arme_a_une_image_et_un_nom_original` ; les tests de catalogue existants (`test_contenu*.gd`, `test_description_offre.gd`, `test_boutique_images.gd`, `test_noms_origine.gd`) restent verts.

### Task 9.13 : Armes tranchantes — 1 promotion et 9 nouvelles — `sonnet`

- [ ] **Objectif :** gabarit ci-dessus pour `tranchant` ; crée `RENDEMENT_AVANT` pour les cinq types et `test_catalogue_armes.gd`. Mécaniques imposées parmi les 9 : M1 (vulnérabilité tranchante), M2 (`malediction_toucher`), M7 (tir tournant), M10 (`type_secondaire: "epines"`).
- **Conception :** §6.13, comparatif §6.1 et §7.1.
- **Fichiers :** `data/armes.json`, `visuels/images_offres.gd`, `tests/unitaires/test_catalogue_armes.gd` (nouveau).
- **Lire :** `data/armes.json` des armes tranchantes (script, pas en entier) ; `sim/equilibrage.gd` ; les tests `test_contenu.gd` de rendement.
- **Interfaces :** consomme T9.3, T9.5, T9.6 (effets et statuts), T9.1 (garde-fou), T9.21 (descriptions).
- **Tests :** gabarit ci-dessus, `TYPES_TERMINES = ["tranchant"]`.
- **Vérif :** `T --filtre test_catalogue_armes`, `test_contenu`, `test_noms_origine`, `test_description_offre`, puis `tools/verifier.sh`.

### Task 9.14 : Armes perçantes — 1 promotion et 9 nouvelles — `sonnet`

- [ ] **Objectif :** gabarit pour `perçant` (`type_degats` s'écrit « perçant » dans les données). Imposées : M1 (vulnérabilité perçante), M3 (repoussement), M10 (épines). Le rapport dit si la commune conservée est `chausse_trape` (« Choix du plan » 9).
- **Fichiers / Lire / Interfaces :** comme T9.13 ; consomme T9.3 et T9.5. **Tests :** gabarit, `TYPES_TERMINES` + `perçant`. **Vérif :** comme T9.13.

### Task 9.15 : Armes magiques — 1 promotion et 9 nouvelles — `sonnet`

- [ ] **Objectif :** gabarit pour `magique`. Imposées : M1 (vulnérabilité magique), M4 (`mana_au_coup` et siphon de mana), M7 (tir tournant), M8 (zone posée).
- **Fichiers / Lire :** comme T9.13 ; **Interfaces :** consomme T9.4, T9.6, T9.7, T9.9. **Tests :** gabarit, `TYPES_TERMINES` + `magique`, plus `test_les_armes_de_mana_du_lot_8_gardent_leurs_champs` (les 4 armes de `degats_par_mana_max` de T8.7 sont inchangées). **Vérif :** comme T9.13.

### Task 9.16 : Armes de siège — 1 promotion et 9 nouvelles — `sonnet`

- [ ] **Objectif :** gabarit pour `siège`. Imposées : M1 (vulnérabilité de siège), M5 (`degats_par_pv_max` ; `degats_par_amelioration` sur une stat que portent déjà des améliorations existantes, comme la cadence), M8 (zone posée, **deux** armes), M9 (bombe à retardement).
- **Fichiers / Lire :** comme T9.13 ; **Interfaces :** consomme T9.5, T9.7, T9.9. **Tests :** gabarit, `TYPES_TERMINES` + `siège`. **Vérif :** comme T9.13.

### Task 9.17 : Armes de chaos — 1 promotion et 9 nouvelles ; cible D18 complète — `sonnet`

- [ ] **Objectif :** gabarit pour `chaos`. Imposées : M1 (vulnérabilité de chaos), M2 (`malediction_degats`), M4 (siphon de vie), M5 (`degats_par_exemplaire`), M6 (invocation, **deux** armes, unités de `data/unites.json`). Le rapport dit si la commune conservée est `sablier_fele`. **Cible complète :** `TYPES_TERMINES` est supprimée, le test de cible boucle sur `Types.NOMS_TYPES` (les cinq) et exige **75** armes, 15 par type, 1 / 6 / 6 / 2 ; un test vérifie que chaque mécanique M1 à M10 est portée par au moins une arme du catalogue (boucle sur les dix).
- **Fichiers / Lire :** comme T9.13 ; **Interfaces :** consomme T9.4, T9.5, T9.8, T9.9. **Tests :** gabarit complet, `test_la_cible_d18_est_75_armes_quinze_par_type_1_6_6_2_en_boucle_sur_les_cinq_types`, `test_chaque_mecanique_est_portee_par_au_moins_une_arme`, `test_les_pieges_d_origine_du_jeu_sont_toujours_la`. **Vérif :** comme T9.13, plus `T` en entier.

## Session « Rendu »

### Task 9.18 : Planche des 45 nouvelles signatures d'armes — `sonnet` — **attend Phil**

- [ ] **Objectif :** proposer une signature visuelle (D5) pour chacune des 45 nouvelles armes dans `visuels/signatures_armes.gd` (table, sans l'intégrer en jeu) et la montrer sur une planche, `docs/planche_signatures.png` (sections par type, les 30 signatures validées au lot 8 en vignettes de rappel), composée par `tools/planche_signatures.gd` comme celle de T8.14. Les armes à mécanique propre ont une **marque** qui se voit d'un coup d'œil : rayon tournant, disque au sol d'une zone posée, bombe à mèche, allié invoqué, marqueur de vulnérabilité. Sources : effets du pack d'abord, puis formes dessinées par code aux couleurs du pack. Chaque carte nomme l'arme. **Aucune intégration avant la validation de Phil** : l'agent principal met la ligne du tableau d'avancement à `a_valider` avec `attend` renseigné.
- **Conception :** §6.5 et D5 de la conception du lot 8, §6.13.
- **Fichiers :** `visuels/signatures_armes.gd`, `tools/planche_signatures.gd`, `docs/planche_signatures.png`, `tests/unitaires/test_signatures_armes.gd`, `test_garde_ressources.gd` si le script cite une image du pack.
- **Lire :** `visuels/signatures_armes.gd` et `docs/planche_signatures.png` (T8.14) ; `visuels/effets.gd` `PROJECTILES`, `IMPACTS`, `TRAITS`, `COULEURS` ; `data/armes.json` des 45 nouvelles (par script).
- **Interfaces :** étend `SignaturesArmes` : `ids()` rend les **75** armes ; `de(id_arme)` gagne la clé `marque: String` (`""`, `"rayon_tournant"`, `"disque_au_sol"`, `"bombe"`, `"allie"`, `"vulnerabilite"`) ; le reste du dictionnaire est inchangé, `son == "tir_" + id_arme`.
- **Tests :**
  - `test_chaque_arme_a_une_signature_et_il_n_y_en_a_pas_d_autre` : les ids de `Donnees.armes`, dans la boucle, ni plus ni moins (75 aujourd'hui, jamais un effectif en dur).
  - `test_deux_armes_n_ont_jamais_la_meme_signature` et `test_deux_armes_ne_partagent_jamais_la_forme_et_la_couleur_du_projectile` : toutes les paires (2 775 pour 75), **Review Focus 6**.
  - `test_les_signatures_restent_lisibles_au_zoom_le_plus_lointain` : valeur ≥ 0,6, opacité ≥ 0,8 (les 75).
  - `test_le_statut_de_la_signature_est_celui_de_l_arme_nouveaux_statuts_compris` ; `test_la_marque_correspond_a_la_mecanique_de_l_arme` : en boucle, une arme à effet `tournant`, `zone_posee`, `bombe` ou `invocation` a la marque correspondante, une arme à statut `vulnerabilite` la marque `vulnerabilite`, les autres `""`.
  - `test_les_signatures_d_avant_le_lot_ne_changent_pas` (les 30 de T8.14, comparées champ à champ).
  - `test_une_arme_inconnue_n_a_pas_de_signature`.
- **Vérif :** `T --filtre test_signatures_armes`, `godot --headless --path . --script res://tools/planche_signatures.gd`, puis `tools/verifier.sh`. Rapport : lien vers la planche.

### Task 9.19 : Mécaniques et signatures en jeu — `sonnet`

- [ ] **Objectif :** après la validation de la planche : (a) les 45 signatures entrent en jeu comme celles du lot 8 (`Effets` lit `SignaturesArmes.de` de l'arme de l'événement) ; (b) les **alliés** se dessinent avec les feuilles du guerrier et de l'archer du pack, une **teinte** et un **anneau au sol** qu'aucun des 24 ennemis n'a, interpolés entre deux états comme les ennemis ; (c) une **zone posée** est un disque au sol pendant son temps restant, une **bombe** grossit et pulse jusqu'à son explosion (feuille d'explosion du pack), un **tir tournant** dessine ses rayons, un **repoussement** un trait de recul ; (d) les trois nouveaux bits de statut (vulnérable, maudit, siphonné) ont chacun une teinte et un petit marqueur, distincts des cinq anciens ; (e) les genres et statuts d'événement nouveaux ont tous un rendu. Le plafond de 200 effets tient.
- **Conception :** §6.5 et D5 du lot 8, §6.13, « Choix du plan » 2.
- **Fichiers :** `visuels/effets.gd`, `visuels/arene_2d.gd`, `visuels/apparence.gd` (modèles des alliés), `visuels/signatures_armes.gd` (rien d'autre que des corrections demandées par Phil), `visuels/teinte_*.gdshader` si la teinte des alliés l'exige, `visuels/interpolation.gd` ; tests `test_effets.gd`, `test_evenements_genre.gd`, `test_arene_2d.gd`, `test_apparence.gd`.
- **Lire :** `visuels/effets.gd` `rendu`, `_tir`, `_impact`, `_statut`, `COULEURS_STATUT`, `FORMES_STATUT` ; `visuels/apparence.gd` `ENTITES` ; `docs/tiny_swords.md` (unités et explosions).
- **Interfaces :** consomme `VueArene.allies`, `zones`, `bombes` (T9.2, T9.7, T9.8), `Protocole` (T9.9), `SignaturesArmes` (T9.18). Produit `Arene2D.teinte_instance` étendue aux trois bits, `Effets.COULEUR_ALLIE`.
- **Tests :**
  - `test_chaque_arme_produit_un_tir_aux_formes_et_a_la_couleur_de_sa_signature` : en boucle sur le catalogue ; `test_deux_armes_ne_produisent_jamais_le_meme_rendu` : toutes les paires.
  - `test_chaque_genre_et_chaque_statut_d_evenement_a_un_rendu` : en boucle sur `GENRES_ARME` et `STATUTS_ARME` ; un index inconnu retombe sur le rendu par type de dégâts sans erreur.
  - **Review Focus 6 :** `test_un_allie_n_a_ni_la_teinte_ni_le_marquage_d_un_ennemi` : en boucle sur les 24 familles, la teinte et l'anneau de l'allié diffèrent de chacune ; `test_le_plafond_de_200_effets_tient_avec_255_armes_qui_tirent` ; `test_les_allies_sont_interpoles_entre_deux_etats_sans_saut`.
  - `test_une_zone_se_dessine_au_sol_pendant_son_temps_restant_et_disparait_avec_la_vue` ; `test_une_bombe_grossit_jusqu_a_son_explosion` ; `test_un_tir_tournant_dessine_un_rayon_par_branche` ; `test_un_repoussement_dessine_un_trait_vers_l_exterieur`.
  - `test_les_trois_nouveaux_statuts_ont_des_teintes_distinctes_entre_elles_et_des_cinq_anciennes`.
  - `test_une_vue_sans_allies_ni_zones_ni_bombes_ne_dessine_rien_de_plus`.
- **Vérif :** `T --filtre test_effets`, `test_arene_2d`, `test_apparence`, puis `tools/verifier.sh`. Captures de contrôle aux trois résolutions relues, avec 64 alliés et 255 armes qui tirent.

### Task 9.20 : Sons de tir des 45 nouvelles armes — `sonnet`

- [ ] **Objectif :** D15 pour les 45 nouvelles armes : un son de tir propre à chacune, pris dans le « 400+ Sounds Pack » (CC0, déjà cité par `CREDITS.md`), **jamais le même fichier d'origine deux fois sur l'ensemble des 75 et des 5 sons d'impact**, même conversion que T8.15 (Ogg Vorbis par ffmpeg, silence de tête coupé, `loudnorm` à −18 LUFS). Le pack n'offre qu'environ 50 sons de tir nettement distincts (relevé de T8.15) : les sons manquants viennent d'**un second pack sous licence CC0** que la session **choisit elle-même, sans attendre Phil** (décision de Phil du 26/11/2026), par exemple un pack de Kenney ; elle vérifie la licence à sa source, la cite dans `assets/sons/SOURCES.md`, et la ligne de `CREDITS.md` passe par T9.22. Une licence douteuse ou non vérifiable écarte le pack. Indépendante de la planche.
- **Conception :** §6.5 bis (D15) du lot 8, §6.13.
- **Fichiers :** `sons/catalogue_sons.gd` (rien si la liste dérive déjà des données), `assets/sons/tir_<id>.ogg` (45) avec leurs `.import`, `assets/sons/SOURCES.md` (une ligne par son) ; tests `test_catalogue_sons.gd`, `test_detecteur_sons.gd`. `CREDITS.md` : voir T9.22.
- **Lire :** `assets/sons/SOURCES.md` (les fichiers d'origine déjà pris), `sons/catalogue_sons.gd`, `tests/unitaires/test_catalogue_sons.gd`.
- **Interfaces :** consomme `CatalogueSons.id_tir` (T8.15), qui couvre déjà toute arme des données.
- **Tests :**
  - `test_chaque_arme_du_catalogue_a_son_fichier_de_tir` : en boucle sur `Donnees.armes`, le fichier existe et n'est pas un silence.
  - `test_deux_armes_n_ont_jamais_le_meme_fichier_ni_le_meme_fichier_d_origine` : toutes les paires (empreinte du fichier et origine lue dans `SOURCES.md`) ; un son d'impact n'est jamais un son de tir.
  - `test_chaque_son_est_liste_dans_sources_md` ; `test_chaque_fichier_de_son_pese_moins_de_80_ko`.
  - `test_le_detecteur_choisit_le_son_de_l_arme_de_l_evenement` : en boucle sur le catalogue.
  - `test_la_liste_des_sons_de_tir_suit_les_donnees` (anti-dérive).
- **Vérif :** `T --filtre test_catalogue_sons`, `test_detecteur_sons`, puis `tools/verifier.sh`.

## Session « Interface »

### Task 9.21 : Descriptions des nouvelles mécaniques — `haiku`

- [ ] **Objectif :** la boutique décrit **chaque** nouvelle mécanique en français, avec ses chiffres : 4 effets, 6 statuts, 4 champs d'arme (`degats_par_pv_max`, `degats_par_exemplaire`, `degats_par_amelioration`, `type_secondaire`) et 25 stats d'amélioration. Le texte dit comment ça se cumule et le plafond (la vulnérabilité « jusqu'à x % », la malédiction, les bonus de M5 « au plus x fois les dégâts de base », les croissances « jusqu'à x »), qui se lisent dans `Donnees.partie`. Fait **avant** T9.10 et T9.13 : les listes fermées de `description_offre.gd` refusent ce qu'elles ne connaissent pas.
- **Conception :** §6.13 ; comparatif §7 (le sens de chaque mécanique).
- **Fichiers :** `ui/description_offre.gd` (`EFFETS`, `STATUTS`, `STATISTIQUES`, modèles), `i18n/textes_boutique.csv` (clés `BOUTIQUE_EFFET_*`, colonne `fr`), `tests/unitaires/test_description_offre.gd`.
- **Lire :** `ui/description_offre.gd` (`grep -n 'EFFETS\|STATUTS\|STATISTIQUES\|_morceaux_\|match'`) ; `i18n/textes_boutique.csv` (les lignes `BOUTIQUE_EFFET_`) ; `tests/unitaires/test_description_offre.gd` `test_chaque_genre_d_effet_chaque_statut_et_chaque_statistique_a_son_modele`.
- **Interfaces :** consomme les noms de T9.2 ; ne produit aucun nom nouveau.
- **Tests :**
  - `test_chaque_nouveau_genre_statut_champ_et_stat_a_son_modele` : en boucle sur les listes de `Donnees` et de `VueArene` (jamais une liste en dur), une fiche factice valide donne une ligne non vide avec ses chiffres.
  - `test_un_genre_un_statut_ou_une_statistique_inconnus_ne_passent_toujours_pas_en_silence` (inchangé).
  - `test_la_ligne_de_chaque_mecanique_dit_son_plafond_ou_sa_borne_quand_elle_en_a_une` : vulnérabilité, malédiction, M5, croissances, valeurs lues dans `partie.json`.
  - `test_typographie_francaise_des_nouvelles_lignes` (espaces insécables, « », apostrophes) ; `test_les_nouvelles_infobulles_tiennent_dans_la_carte_a_75_et_125_pour_cent` (les plus longues, trois résolutions).
  - `test_les_cles_de_textes_boutique_ont_toutes_une_valeur_francaise` (aucune clé vide).
- **Vérif :** `T --filtre test_description_offre`, `test_boutique_ui`, puis `tools/verifier.sh`.

## Passe finale

### Task 9.22 : Passe d'équilibrage du catalogue complet et clôture du lot — `sonnet`

- [ ] **Objectif :** rejouer la passe d'équilibrage de T8.21 (`tools/equilibrage.gd`) avec les 75 armes, les 87 améliorations et les dix mécaniques ; consigner les chiffres dans `docs/equilibrage.md` (rendement de chacune des 75 armes, par type et par rareté ; les cibles du robot ; la part d'armes dans les offres). **Critère** (conception §6.12) : les cibles du robot consignées restent atteintes ; le robot de référence (`bonne`) n'est pas éliminé avant la manche 20 ; un robot qui n'achète rien tombe au plus tard à la fin de la manche 3 ; PV et dégâts ennemis croissent strictement de manche en manche. **Leviers autorisés sans revenir à Phil** : ceux de T8.21, plus les chiffres des 45 armes et des 44 améliorations, les plafonds de `partie.json` (`vulnerabilite`, `malediction`, `repoussement`, `limites`, `armes`, `ameliorations`), et `poids_genre` dans `data/boutique.json` (poids de tirage des armes et des améliorations, **seulement** si la part d'armes de la manche 1 tombe sous le seuil de l'objectif). **Non modifiables sans Phil** : les paliers de portée (500 / 750 / 1 000 / 1 250), la vitesse ×1,5, les portées d'ennemis 350 et 650, **et les effectifs de D18** (75 armes, 15 par type, 1 / 6 / 6 / 2, 87 améliorations). Clôture : `CREDITS.md` (sons ajoutés, nombre de sons du pack utilisés), `docs/jouer.md` (les mécaniques, pour le joueur), `CLAUDE.md` (un piège par difficulté réelle rencontrée), ce plan (suivis).
- **Conception :** §6.12, §6.13.
- **Fichiers :** `data/difficulte.json`, `data/ennemis.json`, `data/armes.json`, `data/ameliorations.json`, `data/boutique.json`, `data/partie.json`, `docs/equilibrage.md`, `docs/jouer.md`, `CREDITS.md`, `CLAUDE.md`, ce plan (suivis), `tests/unitaires/test_equilibrage_partie.gd`, `test_donnees.gd`, `test_catalogue_boutique.gd` (nouveau), `tests/integration/test_multijoueur.gd`.
- **Lire :** `docs/equilibrage.md` en entier ; les rapports et rétros de T9.1 à T9.21 ; `sim/boutique.gd` `_tirer_un`.
- **Interfaces :** consomme tout le lot ; ne change aucune interface (sauf `poids_genre` si le levier est utilisé, avec son schéma validé par `sim/donnees.gd`).
- **Tests :**
  - `test_le_robot_de_reference_n_est_pas_elimine_avant_la_manche_20` : robot `bonne`, graines 1 à 10, catalogue complet.
  - `test_un_joueur_raisonnable_atteint_au_moins_la_manche_douze_en_mediane` ; `test_sans_achat_la_tour_tombe_avant_la_fin_de_la_manche_3` ; `test_pv_et_degats_ennemis_croissent_strictement` (tests de T8.8 et T8.21 toujours verts).
  - **Review Focus 7 :** `test_la_part_d_armes_dans_les_offres_de_la_manche_1_ne_tombe_pas_sous_la_valeur_d_avant_le_lot_moins_dix_points` : constante `PART_ARMES_AVANT` **mesurée par script sur les données d'avant T9.13** (`git show` du commit qui précède, relevée dans le rapport), graines fixes, 1 000 tirages de quatre offres ; `test_chaque_arme_et_chaque_amelioration_reste_proposable_a_une_manche` : en boucle sur tout le catalogue.
  - **Review Focus 3 :** `test_deux_parties_de_meme_graine_avec_le_robot_qui_achete_tout_ont_la_meme_empreinte_de_vue_sur_600_pas`.
  - **Review Focus 4 :** `test_un_client_avec_255_armes_dont_des_invocatrices_recoit_un_etat_valide` (intégration, ENet local, port tiré à l'exécution).
  - `test_le_rendement_des_armes_croit_avec_la_rarete_dans_chaque_type_catalogue_complet` (les tests de `test_contenu.gd`, sur les 75 armes) ; `test_la_cible_d18_est_toujours_tenue` (75 armes, 1 / 6 / 6 / 2 par type, 87 améliorations, en boucle).
  - `test_chaque_arme_du_catalogue_a_une_signature_un_son_une_image_et_une_description` : en boucle, les quatre fichiers existent.
- **Vérif :** `godot --headless --path . --script res://tools/equilibrage.gd -- --graines 50 --strategie toutes`, `npx -y prettier@3.9.10 --check` sur les Markdown touchés, puis `tools/verifier.sh` complet. Rapport : ce qui reste à Phil (planche validée ? sons manquants ? règle de la commune promue ?).
