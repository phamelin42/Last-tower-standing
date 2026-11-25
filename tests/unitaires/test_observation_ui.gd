extends CasDeTest
## Ce que le joueur vaincu voit et peut faire : l'écran d'observation n'apparaît que pour lui,
## liste les arènes encore en jeu, passe de l'une à l'autre au clic et au clavier, et ne laisse
## jamais affichée une arène dont le joueur est mort. Les intentions sont notées par
## `SourceFactice`.

const CSV := "res://i18n/textes_observation.csv"
const SCENE := "res://scenes/observation.tscn"
const SCRIPT := "res://ui/observation_ui.gd"
const HAUTEUR_MIN := 48.0
const TAILLE_MIN := 16
const LARGEUR_MAX := 360.0
const LOCAL := 1
## 24 caractères sans espace : le cas le plus dur à retourner dans un bouton.
const NOM_LONG := "Wolfgang-Amadeus-Chantal"

var _ui: ObservationUi
var _source: SourceFactice
var _traduction: Translation
var _locale_avant: String = "en"
var _champ: LineEdit = null


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	_traduction = Translation.new()
	_traduction.locale = "fr"
	var textes := CsvTextes.lire(CSV)
	for cle: String in textes:
		var texte: String = textes[cle]
		_traduction.add_message(cle, texte)
	TranslationServer.add_translation(_traduction)
	TranslationServer.set_locale("fr")
	_lier_action(ObservationUi.ACTION_SUIVANT, KEY_RIGHT)
	_lier_action(ObservationUi.ACTION_PRECEDENT, KEY_LEFT)
	_source = SourceFactice.new()
	arbre.root.add_child(_source)
	_ui = (load(SCENE) as PackedScene).instantiate() as ObservationUi
	arbre.root.add_child(_ui)
	_ui.configurer(_source)


func apres_chaque() -> void:
	for noeud: Node in [_champ, _ui, _source]:
		if is_instance_valid(noeud):
			noeud.get_parent().remove_child(noeud)
			noeud.free()
	_champ = null
	for action: String in [ObservationUi.ACTION_SUIVANT, ObservationUi.ACTION_PRECEDENT]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	TranslationServer.remove_translation(_traduction)
	TranslationServer.set_locale(_locale_avant)


# --- Aides ---------------------------------------------------------------------------------


func _lier_action(action: String, touche: Key) -> void:
	InputMap.add_action(action)
	var evenement := InputEventKey.new()
	evenement.keycode = touche
	InputMap.action_add_event(action, evenement)


func _touche(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _toucher(code: Key) -> void:
	_ui._unhandled_input(_touche(code))


func _nom(id: int) -> String:
	return "Joueur %d" % id


## Joueurs 1 à `n` ; seuls ceux de `vivants` le sont.
func _vue(n: int, vivants: Array[int]) -> VueGlobale:
	var vue := VueGlobale.new()
	for id: int in range(1, n + 1):
		(
			vue
			. joueurs
			. append(
				{
					"id": id,
					"nom": _nom(id),
					"manche": 3,
					"eliminations": 0,
					"degats": 0.0,
					"revenu": 20,
					"vivant": vivants.has(id),
					"victorieux": false,
				}
			)
		)
	vue.en_cours = true
	return vue


## Les ids 2 à `n` : tout le monde vit sauf le joueur local, qui vient de perdre.
func _vivants_hors_local(n: int) -> Array[int]:
	var ids: Array[int] = []
	for id: int in range(2, n + 1):
		ids.append(id)
	return ids


## Les ids passés à `SourceVue.observer`, dans l'ordre des appels.
func _observations() -> Array[int]:
	var ids: Array[int] = []
	for appel: Dictionary in _source.appels:
		if appel["nom"] == "observer":
			ids.append(int(appel["args"][0]))
	return ids


func _arene(id: int) -> Button:
	return _ui.find_child("Arene%d" % id, true, false) as Button


func _nb_arenes() -> int:
	return _ui.find_children("Arene*", "Button", true, false).size()


func _label(nom: String) -> Label:
	return _ui.find_child(nom, true, false) as Label


# --- Visibilité ----------------------------------------------------------------------------


func test_invisible_tant_que_le_joueur_local_vit() -> void:
	for n: int in range(1, 9):
		var vivants: Array[int] = []
		for id: int in range(1, n + 1):
			vivants.append(id)
		_ui.afficher(_vue(n, vivants), LOCAL, -1)
		verifier(not _ui.visible, "%d joueurs : rien ne s'affiche tant que la joueuse vit" % n)
	verifier(_source.appels.is_empty(), "aucune intention tant que le joueur local vit")


func test_visible_quand_le_joueur_local_est_mort_pour_chaque_taille() -> void:
	for n: int in range(1, 9):
		_ui.afficher(_vue(n, _vivants_hors_local(n)), LOCAL, -1)
		verifier(_ui.visible, "%d joueurs : l'écran s'affiche après la défaite" % n)
		verifier(
			_nb_arenes() == n - 1,
			"%d joueurs : une entrée par arène vivante, pas %d" % [n, _nb_arenes()]
		)


func test_joueur_local_inconnu_reste_invisible() -> void:
	_ui.afficher(_vue(3, [2, 3]), 99, -1)
	verifier(not _ui.visible, "un identifiant absent de la partie ne déclenche pas l'écran")
	verifier(_source.appels.is_empty(), "aucune intention pour un identifiant absent")


# --- Liste et clic -------------------------------------------------------------------------


func test_liste_les_arenes_vivantes_et_elles_seules() -> void:
	var vivants: Array[int] = [2, 4, 5, 8]
	_ui.afficher(_vue(8, vivants), LOCAL, 2)
	for id: int in range(1, 9):
		var attendue := vivants.has(id)
		verifier(
			(_arene(id) != null) == attendue, "joueur %d : entrée attendue = %s" % [id, attendue]
		)


func test_clic_sur_une_arene_appelle_observer() -> void:
	_ui.afficher(_vue(4, [3, 4]), LOCAL, 3)
	_source.appels.clear()
	_arene(4).pressed.emit()
	verifier(_observations() == [4], "le clic demande l'arène 4, reçu %s" % str(_observations()))


func test_arene_observee_est_nommee_en_texte() -> void:
	for cible: int in range(2, 9):
		_ui.afficher(_vue(8, _vivants_hors_local(8)), LOCAL, cible)
		var texte := _label("Observe").text
		verifier(texte.begins_with("Vous observez"), "texte d'observation : %s" % texte)
		verifier(texte.contains(_nom(cible)), "le nom du joueur observé figure dans : %s" % texte)


# --- Changement d'arène --------------------------------------------------------------------


func test_cible_morte_passe_au_suivant_vivant() -> void:
	for n: int in range(3, 9):
		for cible: int in range(2, n + 1):
			_source.appels.clear()
			var vivants := _vivants_hors_local(n)
			vivants.erase(cible)
			_ui.afficher(_vue(n, vivants), LOCAL, cible)
			var attendu := cible + 1 if cible < n else 2
			verifier(
				_observations() == [attendu],
				(
					"%d joueurs, cible %d morte : attendu %d, reçu %s"
					% [n, cible, attendu, str(_observations())]
				)
			)


func test_cible_vivante_ne_change_pas() -> void:
	_ui.afficher(_vue(5, _vivants_hors_local(5)), LOCAL, 3)
	verifier(_observations().is_empty(), "une arène encore vivante reste observée")


func test_sans_cible_choisie_observe_le_premier_vivant() -> void:
	_ui.afficher(_vue(5, _vivants_hors_local(5)), LOCAL, -1)
	verifier(_observations() == [2], "sans cible, le premier vivant est observé")


func test_suivant_et_precedent_bouclent_sur_les_vivants() -> void:
	var vivants: Array[int] = [2, 4, 5, 8]
	_ui.afficher(_vue(8, vivants), LOCAL, 2)
	_source.appels.clear()
	for i: int in 4:
		_toucher(KEY_RIGHT)
	verifier(_observations() == [4, 5, 8, 2], "suivant : reçu %s" % str(_observations()))
	_source.appels.clear()
	for i: int in 4:
		_toucher(KEY_LEFT)
	verifier(_observations() == [8, 5, 4, 2], "précédent : reçu %s" % str(_observations()))


func test_boutons_suivant_et_precedent_passent_aussi_par_la_souris() -> void:
	_ui.afficher(_vue(4, [2, 3, 4]), LOCAL, 2)
	_source.appels.clear()
	(_ui.find_child("NavSuivant", true, false) as Button).pressed.emit()
	verifier(_observations() == [3], "le bouton suivant demande l'arène 3")


func test_touches_ignorees_si_un_champ_a_le_focus() -> void:
	_ui.afficher(_vue(4, [2, 3, 4]), LOCAL, 2)
	_source.appels.clear()
	_champ = LineEdit.new()
	arbre.root.add_child(_champ)
	_ui.lecteur_focus = func() -> Control: return _champ
	_toucher(KEY_RIGHT)
	verifier(_observations().is_empty(), "une saisie dans un champ ne change pas d'arène")
	_ui.lecteur_focus = func() -> Control: return null
	_toucher(KEY_RIGHT)
	verifier(_observations() == [3], "sans champ focalisé, la touche fonctionne")


func test_touches_ignorees_tant_que_le_joueur_local_vit() -> void:
	_ui.afficher(_vue(4, [1, 2, 3, 4]), LOCAL, 2)
	_toucher(KEY_RIGHT)
	_toucher(KEY_LEFT)
	verifier(_source.appels.is_empty(), "aucune navigation pendant que la joueuse vit")


# --- Cas extrêmes --------------------------------------------------------------------------


func test_tout_le_monde_elimine_le_dit_en_texte_sans_erreur() -> void:
	for n: int in range(1, 9):
		_source.appels.clear()
		_ui.afficher(_vue(n, []), LOCAL, -1)
		verifier(_ui.visible, "%d joueurs éliminés : le message s'affiche" % n)
		verifier(_nb_arenes() == 0, "%d joueurs éliminés : aucune arène à observer" % n)
		var message := (_ui.find_child("Message", true, false) as Label).text
		verifier(
			message == TranslationServer.translate("OBSERVATION_PERSONNE"),
			"%d joueurs éliminés : message attendu, reçu « %s »" % [n, message]
		)
		_toucher(KEY_RIGHT)
		_toucher(KEY_LEFT)
		verifier(_source.appels.is_empty(), "%d joueurs éliminés : pas d'intention" % n)


func test_noms_les_plus_longs_restent_dans_la_largeur() -> void:
	var vue := _vue(3, [2, 3])
	vue.joueurs[1]["nom"] = NOM_LONG
	vue.joueurs[2]["nom"] = NOM_LONG
	_ui.afficher(vue, LOCAL, 2)
	var largeur := _ui.get_combined_minimum_size().x
	verifier(largeur <= LARGEUR_MAX, "nom long : largeur minimale %.0f px" % largeur)


func test_controles_a_48_px_au_moins() -> void:
	_ui.afficher(_vue(8, _vivants_hors_local(8)), LOCAL, 2)
	verifier(
		not _ui.find_children("*", "Button", true, false).is_empty(), "des contrôles à mesurer"
	)
	for bouton: Node in _ui.find_children("*", "Button", true, false):
		var b := bouton as Button
		verifier(
			b.custom_minimum_size.y >= HAUTEUR_MIN,
			"%s : %.0f px, 48 px attendus" % [b.name, b.custom_minimum_size.y]
		)


func test_textes_d_au_moins_16_px() -> void:
	_ui.afficher(_vue(8, _vivants_hors_local(8)), LOCAL, 2)
	verifier(not _ui.find_children("*", "Label", true, false).is_empty(), "des textes à mesurer")
	for libelle: Node in _ui.find_children("*", "Label", true, false):
		var l := libelle as Label
		verifier(l.get_theme_font_size("font_size") >= TAILLE_MIN, "%s : texte sous 16 px" % l.name)
	for bouton: Node in _ui.find_children("*", "Button", true, false):
		var b := bouton as Button
		verifier(b.get_theme_font_size("font_size") >= TAILLE_MIN, "%s : texte sous 16 px" % b.name)


# --- Textes --------------------------------------------------------------------------------


func test_chaque_cle_utilisee_existe_dans_le_csv() -> void:
	var textes := CsvTextes.lire(CSV)
	var source := FileAccess.get_file_as_string(SCRIPT)
	var regex := RegEx.create_from_string('"(OBSERVATION_[A-Z_]+)"')
	var trouvees: Array[RegExMatch] = regex.search_all(source)
	verifier(not trouvees.is_empty(), "le script doit utiliser des clés de texte")
	for m: RegExMatch in trouvees:
		var cle := m.get_string(1)
		verifier(textes.has(cle), "clé absente du CSV : %s" % cle)
		verifier(not String(textes.get(cle, "")).is_empty(), "texte vide pour %s" % cle)


func test_chaque_cle_du_csv_est_utilisee() -> void:
	var textes := CsvTextes.lire(CSV)
	var source := FileAccess.get_file_as_string(SCRIPT)
	for cle: String in textes:
		verifier(source.contains('"%s"' % cle), "clé orpheline dans le CSV : %s" % cle)


func test_espace_insecable_avant_les_deux_points() -> void:
	var textes := CsvTextes.lire(CSV)
	for cle: String in textes:
		var texte: String = textes[cle]
		verifier(not texte.contains(" :"), "espace ordinaire avant « : » dans %s" % cle)
