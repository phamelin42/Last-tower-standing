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

- [ ] **Objectif :** `visuels/arene_2d.gd` remplace l’arène 3D : terrain, tour au centre, ennemis
      animés (marche, attaque, mort), tri en profondeur, `Camera2D` avec zoom borné, même contrat
      (`SourceVue`, interpolation). Performance : 1 000 ennemis visibles sans chute sous 60 images/s
      (pool de sprites ou `MultiMeshInstance2D` avec atlas animé par nuanceur), mesurée. Captures de
      contrôle aux trois résolutions.
      **Fait, fusionné par la PR #7** : unités à ×1,9, tour à ×2,1, ennemi translucide devant la tour,
      images recadrées. Reste la preuve des 60 images/s : 22,6 images/s en rendu logiciel sous Xvfb,
      à mesurer sur une vraie carte graphique.

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

- [ ] **Objectif :** `visuels/apparence.gd` devient la correspondance entité → sprites ; le test de
      garde vérifie que seuls `apparence.gd` et `assets/tiny_swords/` portent les ressources
      graphiques ; l’arène 3D est retirée ; `CREDITS.md` à jour ; captures finales relues.

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

- [ ] **Objectif :** l'hôte annonce son salon à l'annuaire tant qu'il est ouvert (s'il l'a rendu
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
- **Annuaire** : lot 7, lancé le 25/11/2026 en parallèle du lot 5 ; ADR validé le 25/11/2026, T7.3 en
  dernier (décision de Phil).
- **Images des offres** : 17 offres sur 70 ont une image approchante (Ravenmore et LudicArts n’ont
  pas leur objet : sablier, tirelire, trébuchet…), validée telle quelle par Phil le 25/11/2026. Liste
  dans `ImagesOffres.RAPPROCHEMENTS_FAIBLES` ; à reprendre si un pack peint gratuit les a.
- **Règles de la simulation à vérifier** (relevées en écrivant les descriptions, T5.9) : le givre ne
  gèle qu’au 8e coup, donc son plafond de 60 % est inatteignable ; les épines ne renvoient que le corps
  à corps ; les morts par poison ou brûlure ne soignent pas ; `revenu_mult` ne multiplie pas le revenu
  de base ; l’aura ignore `portee` et `recharge`.
- **Lots 3 et 4** : terminés (T3.7, T4.3, T4.5 et T4.6 fusionnés par la PR #2).
