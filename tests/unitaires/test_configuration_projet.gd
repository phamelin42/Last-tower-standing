extends CasDeTest
## `project.godot` : chaque action d'entrée que l'interface réclame existe, chaque fichier de
## textes est enregistré, le français sert de langue par défaut, et l'import reste sur un thread.

const DOSSIER_UI := "res://ui"
const DOSSIER_I18N := "res://i18n"
const REPLI := "internationalization/locale/fallback"
const TRADUCTIONS := "internationalization/locale/translations"
const IMPORT_MULTITHREAD := "editor/import/use_multiple_threads"
## Les actions de `fin_ui.gd` sont des identifiants de boutons, pas des actions d'entrée.
const FICHIERS_SANS_ACTIONS := ["fin_ui.gd"]
const ACTIONS_ATTENDUES: Array[String] = [
	"afficher_scores",
	"boutique_offre_1",
	"boutique_offre_2",
	"boutique_offre_3",
	"boutique_offre_4",
	"boutique_relancer",
	"boutique_tout_acheter",
	"observation_suivant",
	"observation_precedent",
	"menu_jeu",
]
## Actions de la caméra libre (T8.13) et de la boutique repliable (T8.19) : action → touches.
const TOUCHES_CAMERA: Dictionary = {
	"camera_gauche": [KEY_LEFT, KEY_A],
	"camera_droite": [KEY_RIGHT, KEY_D],
	"camera_haut": [KEY_UP, KEY_W],
	"camera_bas": [KEY_DOWN, KEY_S],
	"camera_recentrer": [KEY_SPACE],
	"boutique_replier": [KEY_B],
	"boutique_tout_acheter": [KEY_T],
}


func _fichiers(dossier: String, suffixe: String) -> Array[String]:
	var sortie: Array[String] = []
	for nom: String in DirAccess.get_files_at(dossier):
		if nom.ends_with(suffixe):
			sortie.append(nom)
	sortie.sort()
	return sortie


## Les actions déclarées par `const ACTION_… := "x"` et `const ACTIONS_…: Array[String] = [...]`.
func _actions_reclamees() -> Array[String]:
	var sortie: Array[String] = []
	var simple := RegEx.create_from_string('const ACTION_\\w+\\s*:?=\\s*"(\\w+)"')
	var liste := RegEx.create_from_string("const ACTIONS_\\w+[^=]*=\\s*\\[([^\\]]*)\\]")
	var chaine := RegEx.create_from_string('"(\\w+)"')
	for nom: String in _fichiers(DOSSIER_UI, ".gd"):
		if nom in FICHIERS_SANS_ACTIONS:
			continue
		var source := FileAccess.get_file_as_string(DOSSIER_UI.path_join(nom))
		for m: RegExMatch in simple.search_all(source):
			sortie.append(m.get_string(1))
		for m: RegExMatch in liste.search_all(source):
			for c: RegExMatch in chaine.search_all(m.get_string(1)):
				sortie.append(c.get_string(1))
	return sortie


func test_les_actions_reclamees_par_ui_sont_trouvees_par_le_test() -> void:
	var reclamees := _actions_reclamees()
	for action: String in ACTIONS_ATTENDUES:
		if action != "menu_jeu":
			verifier_contient(reclamees, action, "le test ne voit pas " + action)


func test_chaque_action_reclamee_par_ui_existe_dans_la_carte_des_entrees() -> void:
	for action: String in _actions_reclamees() + ACTIONS_ATTENDUES:
		verifier(InputMap.has_action(action), "action absente de project.godot : " + action)


func test_chaque_action_a_au_moins_une_touche() -> void:
	for action: String in ACTIONS_ATTENDUES:
		verifier(
			InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),
			"sans touche : " + action
		)


func test_chaque_fichier_de_textes_est_enregistre() -> void:
	var enregistres: PackedStringArray = ProjectSettings.get_setting(
		TRADUCTIONS, PackedStringArray()
	)
	var csv := _fichiers(DOSSIER_I18N, ".csv")
	verifier(not csv.is_empty(), "aucun CSV trouvé")
	for nom: String in csv:
		var attendu := "%s/%s.fr.translation" % [DOSSIER_I18N, nom.get_basename()]
		verifier_contient(enregistres, attendu, nom + " n'est pas enregistré")


## Godot 4.7.2 importe les CSV de traduction en parallèle, et chaque import inscrit son
## `.translation` dans l'arbre de l'éditeur sans verrou (`EditorFileSystem::update_files`) :
## l'import à froid de la CI mourait sur « double free or corruption » (godot#125712).
func test_l_import_a_froid_ne_lance_pas_les_csv_en_parallele() -> void:
	verifier_egal(
		ProjectSettings.get_setting(IMPORT_MULTITHREAD, true),
		false,
		IMPORT_MULTITHREAD + " doit rester à false : voir les pièges de CLAUDE.md"
	)


func test_le_francais_est_la_langue_par_defaut() -> void:
	verifier_egal(ProjectSettings.get_setting(REPLI, ""), "fr")


func test_chaque_cle_des_csv_est_traduite_en_francais() -> void:
	var locale_avant := TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	for nom: String in _fichiers(DOSSIER_I18N, ".csv"):
		var textes := CsvTextes.lire(DOSSIER_I18N.path_join(nom))
		for cle: String in textes:
			var attendu: String = textes[cle]
			verifier_egal(String(TranslationServer.translate(cle)), attendu, "%s : %s" % [nom, cle])
	TranslationServer.set_locale(locale_avant)


func test_les_six_actions_existent_avec_leurs_touches() -> void:
	for action: String in TOUCHES_CAMERA:
		verifier(InputMap.has_action(action), "action absente : " + action)
		var presentes: Array[int] = []
		for evenement: InputEvent in InputMap.action_get_events(action):
			var cle := evenement as InputEventKey
			if cle != null:
				presentes.append(cle.physical_keycode)
		var attendues: Array = TOUCHES_CAMERA[action]
		for touche: int in attendues:
			verifier(presentes.has(touche), "%s : touche %d absente" % [action, touche])
		verifier_egal(presentes.size(), attendues.size(), "%s : touches en trop" % action)
