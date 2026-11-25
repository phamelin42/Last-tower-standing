extends CasDeTest
## Ce que le joueur voit pendant une manche : la tour, l'or, la manche, le temps, la prochaine
## armure (en texte et en symbole) et le tableau des scores. Les textes passent par `tr()` : on
## enregistre les CSV comme le fera T2.7, puis on lit ce qui est affiché.

const CSV_HUD := "res://i18n/textes_hud.csv"
const CSV_COMMUNS := "res://i18n/textes_communs.csv"
const SCENE_HUD := "res://scenes/hud.tscn"
const SCENE_SCORES := "res://scenes/scores.tscn"
const HAUTEUR_MIN := 48.0
const TAILLE_MIN := 16
const ESPACE_MILLIERS := " "
const NB_EMPLACEMENTS_TEST := 8

var _hud: Hud
var _scores: TableauScores
var _traduction: Translation
var _locale_avant: String = "en"


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	_traduction = Translation.new()
	_traduction.locale = "fr"
	for chemin: String in [CSV_HUD, CSV_COMMUNS]:
		var textes := CsvTextes.lire(chemin)
		for cle: String in textes:
			var texte: String = textes[cle]
			_traduction.add_message(cle, texte)
	TranslationServer.add_translation(_traduction)
	TranslationServer.set_locale("fr")
	_hud = (load(SCENE_HUD) as PackedScene).instantiate() as Hud
	_scores = (load(SCENE_SCORES) as PackedScene).instantiate() as TableauScores
	arbre.root.add_child(_hud)
	arbre.root.add_child(_scores)


func apres_chaque() -> void:
	# Libérés tout de suite : un nœud en attente de `queue_free` ne l'est jamais dans le lanceur.
	for noeud: Node in [_hud, _scores]:
		if is_instance_valid(noeud):
			noeud.get_parent().remove_child(noeud)
			noeud.free()
	if InputMap.has_action(TableauScores.ACTION_SCORES):
		InputMap.erase_action(TableauScores.ACTION_SCORES)
	InputMap.load_from_project_settings()
	TranslationServer.remove_translation(_traduction)
	TranslationServer.set_locale(_locale_avant)


# --- Aides ---------------------------------------------------------------------------------


func _vue(manche: int, argent: int, pv: float, pv_max: float) -> VueArene:
	var vue := VueArene.new()
	vue.manche = manche
	vue.argent = argent
	vue.tour_pv = pv
	vue.tour_pv_max = pv_max
	vue.temps_restant = 30.0
	vue.prochaine_famille = 0
	vue.prochaine_armure = Types.Armure.LEGERE
	return vue


func _armes(nombre_armes: int) -> Array[Dictionary]:
	var armes: Array[Dictionary] = []
	for i: int in nombre_armes:
		armes.append({"id": "arme_%d" % i, "recharge_ratio": 1.0})
	return armes


func _joueur(id: int, nom: String, vivant: bool) -> Dictionary:
	return {
		"id": id,
		"nom": nom,
		"manche": 3,
		"eliminations": 2,
		"degats": 1234.0,
		"revenu": 40,
		"vivant": vivant,
		"victorieux": false,
	}


func _vue_globale(joueurs: Array[Dictionary]) -> VueGlobale:
	var vue := VueGlobale.new()
	vue.joueurs = joueurs
	vue.en_cours = true
	return vue


func _textes(noeud: Node) -> PackedStringArray:
	var sortie := PackedStringArray()
	for enfant: Node in noeud.find_children("*", "Label", true, false):
		sortie.append((enfant as Label).text)
	return sortie


func _affiche(noeud: Node, texte: String, message: String) -> void:
	verifier(_textes(noeud).has(texte), "%s (attendu « %s »)" % [message, texte])


## Vrai si un libellé contient `fragment` ; sert quand le texte porte aussi un symbole.
func _affiche_partie(noeud: Node, fragment: String, message: String) -> void:
	var trouve := false
	for texte: String in _textes(noeud):
		trouve = trouve or texte.contains(fragment)
	verifier(trouve, "%s (attendu un libellé contenant « %s »)" % [message, fragment])


func _tous_les_libelles(noeud: Node) -> Array[Label]:
	var sortie: Array[Label] = []
	for enfant: Node in noeud.find_children("*", "Label", true, false):
		sortie.append(enfant as Label)
	return sortie


# --- Formatage des nombres (la fonction elle-même est testée dans test_nombres.gd) --------


func test_or_a_999_999_est_affiche_groupe() -> void:
	_hud.afficher(_vue(4, 999999, 1000.0, 1000.0))
	_affiche(_hud, "999" + ESPACE_MILLIERS + "999", "l'or doit être lisible d'un coup d'œil")


# --- HUD -------------------------------------------------------------------------------------


func test_pv_pleins_et_a_zero_sont_affiches() -> void:
	_hud.afficher(_vue(2, 0, 1000.0, 1000.0))
	_affiche(_hud, "1" + ESPACE_MILLIERS + "000 / 1" + ESPACE_MILLIERS + "000", "PV pleins")
	_hud.afficher(_vue(2, 0, 0.0, 1000.0))
	_affiche(_hud, "0 / 1" + ESPACE_MILLIERS + "000", "PV à zéro")


func test_manche_zero_affiche_preparation() -> void:
	_hud.afficher(_vue(0, 500, 1000.0, 1000.0))
	_affiche(_hud, "Préparation", "avant la première manche")
	_hud.afficher(_vue(7, 500, 1000.0, 1000.0))
	_affiche(_hud, "7", "une manche numérotée")


func test_le_mode_sans_fin_se_voit_dans_la_manche() -> void:
	var vue := _vue(32, 500, 1000.0, 1000.0)
	vue.sans_fin = true
	_hud.afficher(vue)
	_affiche(_hud, "32 ∞", "manche au-delà du boss")
	vue.sans_fin = false
	_hud.afficher(vue)
	_affiche(_hud, "32", "sans le mode, pas de symbole")


func test_temps_restant_a_zero_ne_plante_pas_et_affiche_zero_seconde() -> void:
	var vue := _vue(3, 0, 1000.0, 1000.0)
	vue.temps_restant = 0.0
	_hud.afficher(vue)
	_affiche(_hud, "0 s", "temps écoulé")


func test_temps_restant_arrondi_a_la_seconde_superieure() -> void:
	var vue := _vue(3, 0, 1000.0, 1000.0)
	vue.temps_restant = 12.2
	_hud.afficher(vue)
	_affiche(_hud, "13 s", "un décompte ne montre pas la seconde déjà passée")


func test_armure_annoncee_en_texte_et_en_symbole_pour_les_six_valeurs() -> void:
	for a: int in Types.Armure.size():
		var vue := _vue(3, 0, 1000.0, 1000.0)
		vue.prochaine_armure = a
		_hud.afficher(vue)
		var attendu := Hud.libelle_armure(a)
		verifier(
			attendu.contains(Apparence.symbole_armure(a)), "l'armure %d doit porter son symbole" % a
		)
		verifier(attendu.length() > 2, "l'armure %d doit porter son libellé" % a)
		_affiche(_hud, attendu, "l'armure %d est affichée en texte et symbole" % a)


func test_aucune_famille_a_venir_affiche_aucune() -> void:
	var vue := _vue(3, 0, 1000.0, 1000.0)
	vue.prochaine_famille = -1
	_hud.afficher(vue)
	_affiche(_hud, "Aucune", "pas de prochaine famille")


func test_armes_equipees_de_zero_a_huit() -> void:
	for n: int in range(0, NB_EMPLACEMENTS_TEST + 1):
		var vue := _vue(3, 0, 1000.0, 1000.0)
		vue.armes = _armes(n)
		_hud.afficher(vue)
		_affiche(_hud, str(n), "%d arme(s) équipée(s)" % n)


func test_chaque_controle_du_hud_fait_48_px_et_16_px_au_moins() -> void:
	var vue := _vue(3, 1500, 800.0, 1000.0)
	vue.armes = _armes(2)
	_hud.afficher(vue)
	var libelles := _tous_les_libelles(_hud)
	verifier(libelles.size() >= 7, "le HUD doit afficher ses lignes")
	for libelle: Label in libelles:
		verifier(
			libelle.get_combined_minimum_size().y >= HAUTEUR_MIN,
			"« %s » fait moins de 48 px de haut" % libelle.text
		)
		verifier(
			libelle.get_theme_font_size("font_size") >= TAILLE_MIN,
			"« %s » s'écrit en moins de 16 px" % libelle.text
		)


# --- Tableau des scores ----------------------------------------------------------------------


func test_tableau_affiche_chaque_joueur_a_un_et_huit_joueurs() -> void:
	for n: int in [1, 8]:
		var joueurs: Array[Dictionary] = []
		for i: int in n:
			joueurs.append(_joueur(i + 1, "Joueur %d" % (i + 1), true))
		_scores.afficher(_vue_globale(joueurs), 1)
		for i: int in n:
			var attendu := "Joueur %d" % (i + 1)
			if i == 0:
				attendu += " (vous)"
			_affiche(_scores, attendu, "%d joueur(s), ligne %d" % [n, i + 1])


func test_joueur_elimine_est_marque_en_texte() -> void:
	var joueurs: Array[Dictionary] = [
		_joueur(1, "Anne", true),
		_joueur(2, "Basile", false),
	]
	_scores.afficher(_vue_globale(joueurs), 1)
	_affiche_partie(_scores, "Éliminé", "le joueur éliminé porte un libellé")
	_affiche_partie(_scores, "En vie", "le joueur vivant porte aussi son état en texte")


func test_noms_les_plus_longs_ne_debordent_pas() -> void:
	var nom_long := "Sélène-Marie-Hortense de la Roche-Fontaine des Trois Chênes"
	var joueurs: Array[Dictionary] = []
	for i: int in 8:
		joueurs.append(_joueur(i + 1, nom_long, i % 2 == 0))
	_scores.afficher(_vue_globale(joueurs), 2)
	var noms := 0
	for libelle: Label in _tous_les_libelles(_scores):
		if libelle.text.begins_with("Sélène"):
			noms += 1
			verifier(libelle.clip_text, "le nom doit être tronqué, pas dépasser")
			verifier(
				libelle.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
				"le nom long doit finir par des points de suite"
			)
	verifier_egal(noms, 8, "chaque joueur garde son nom")
	verifier(
		_scores.get_combined_minimum_size().x <= TableauScores.LARGEUR_MAX,
		"le tableau ne doit pas déborder de sa largeur"
	)


func test_action_scores_maintenue_affiche_le_tableau() -> void:
	# Les actions existent déjà dans project.godot : le test pose les siennes.
	if InputMap.has_action(TableauScores.ACTION_SCORES):
		InputMap.erase_action(TableauScores.ACTION_SCORES)
	InputMap.add_action(TableauScores.ACTION_SCORES)
	verifier_faux(_scores.visible, "caché au départ")
	Input.action_press(TableauScores.ACTION_SCORES)
	_scores._process(0.0)
	verifier(_scores.visible, "visible tant que l'action est maintenue")
	Input.action_release(TableauScores.ACTION_SCORES)
	_scores._process(0.0)
	verifier_faux(_scores.visible, "caché dès que l'action est relâchée")


func test_sans_action_declaree_le_tableau_reste_cache_sans_erreur() -> void:
	# project.godot déclare l'action ; ce test simule son absence.
	InputMap.erase_action(TableauScores.ACTION_SCORES)
	verifier_faux(InputMap.has_action(TableauScores.ACTION_SCORES), "action absente au départ")
	_scores._process(0.0)
	verifier_faux(_scores.visible, "sans action, rien ne s'affiche")


func test_chaque_famille_convoi_et_boss_sont_nommes_en_boucle() -> void:
	var donnees := Donnees.charger()
	verifier_non_nul(donnees, "les données réelles doivent se charger")
	if donnees == null:
		return
	_hud.configurer(donnees)
	var nb := donnees.familles.size()
	for index: int in range(0, nb + 2):
		var vue := _vue(3, 0, 1000.0, 1000.0)
		vue.prochaine_famille = index
		vue.prochaine_armure = Types.Armure.LEGERE
		_hud.afficher(vue)
		var nom := ""
		if index < nb:
			var famille: Dictionary = donnees.familles[index]
			nom = famille["nom"]
		elif index == nb:
			nom = donnees.convoi["nom"]
		else:
			nom = donnees.boss["nom"]
		verifier(not nom.is_empty(), "l'index %d doit avoir un nom" % index)
		_affiche_partie(_hud, nom, "la prochaine entité d'index %d est nommée" % index)
		_affiche_partie(_hud, Hud.libelle_armure(Types.Armure.LEGERE), "son armure reste annoncée")


func test_armes_sur_la_capacite_zero_trois_huit() -> void:
	var donnees := Donnees.charger()
	verifier_non_nul(donnees, "les données réelles doivent se charger")
	if donnees == null:
		return
	verifier_egal(int(donnees.partie["emplacements_armes"]), NB_EMPLACEMENTS_TEST)
	_hud.configurer(donnees)
	for n: int in [0, 3, NB_EMPLACEMENTS_TEST]:
		var vue := _vue(3, 0, 1000.0, 1000.0)
		vue.armes = _armes(n)
		_hud.afficher(vue)
		_affiche(_hud, "%d / %d" % [n, NB_EMPLACEMENTS_TEST], "%d arme(s) sur la capacité" % n)


func test_sans_configuration_le_hud_reste_lisible_sans_erreur() -> void:
	var vue := _vue(3, 0, 1000.0, 1000.0)
	vue.prochaine_famille = 2
	vue.prochaine_armure = Types.Armure.LEGERE
	vue.armes = _armes(2)
	_hud.afficher(vue)
	_affiche(_hud, Hud.libelle_armure(Types.Armure.LEGERE), "l'armure seule, sans nom")
	_affiche(_hud, "2", "le nombre d'armes, sans capacité")


# --- Textes ----------------------------------------------------------------------------------


func test_chaque_cle_hud_et_scores_du_code_existe_dans_le_csv() -> void:
	var textes := CsvTextes.lire(CSV_HUD)
	verifier(not textes.is_empty(), "le CSV des textes HUD doit se lire")
	var motif := RegEx.create_from_string('"((HUD|SCORES)_[A-Z_]+)"')
	var cles_trouvees := 0
	for fichier: String in ["res://ui/hud.gd", "res://ui/scores.gd"]:
		var source := FileAccess.get_file_as_string(fichier)
		verifier(not source.is_empty(), "%s doit exister" % fichier)
		for resultat: RegExMatch in motif.search_all(source):
			var cle := resultat.get_string(1)
			cles_trouvees += 1
			verifier(textes.has(cle), "clé absente du CSV : %s (dans %s)" % [cle, fichier])
	verifier(cles_trouvees >= 10, "le code doit référencer ses libellés par clé")
