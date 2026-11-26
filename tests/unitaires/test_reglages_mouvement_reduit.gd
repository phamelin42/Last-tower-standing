extends CasDeTest
## La case « Mouvement réduit » (D21, partie 2) : décochée par défaut, gardée comme les autres
## réglages, et appliquée à l'arène au début d'une partie comme au milieu de celle-ci.

const CSV_REGLAGES := "res://i18n/textes_reglages.csv"
const SCENE_REGLAGES := "res://scenes/reglages.tscn"
const GRAINE := 2024

var _locale_avant: String = ""


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")


func apres_chaque() -> void:
	TranslationServer.set_locale(_locale_avant)


func _chemin() -> String:
	return dossier_temporaire().path_join("reglages.cfg")


func _ecrire_brut(contenu: String) -> void:
	var f := FileAccess.open(_chemin(), FileAccess.WRITE)
	f.store_string(contenu)
	f.close()


func _ui() -> ReglagesUi:
	var ui: ReglagesUi = (load(SCENE_REGLAGES) as PackedScene).instantiate()
	ui.chemin = _chemin()
	arbre.root.add_child(ui)
	return ui


func _liberer(noeud: Node) -> void:
	if is_instance_valid(noeud):
		noeud.get_parent().remove_child(noeud)
		noeud.free()


# --- Le réglage et sa persistance --------------------------------------------------------------


func test_le_mouvement_reduit_est_decoche_par_defaut() -> void:
	verifier_faux(Reglages.new().mouvement_reduit, "valeur par défaut")
	verifier_faux(Reglages.charger(_chemin()).mouvement_reduit, "fichier absent")
	var r := Reglages.new()
	verifier(r.sauver(_chemin()))
	verifier_faux(Reglages.charger(_chemin()).mouvement_reduit, "un fichier sans choix")


func test_le_mouvement_reduit_survit_a_un_redemarrage() -> void:
	var r := Reglages.new()
	r.mouvement_reduit = true
	verifier(r.sauver(_chemin()))
	verifier(Reglages.charger(_chemin()).mouvement_reduit, "relu coché")
	r.mouvement_reduit = false
	verifier(r.sauver(_chemin()))
	verifier_faux(Reglages.charger(_chemin()).mouvement_reduit, "relu décoché")


func test_une_valeur_de_mauvais_type_donne_le_defaut() -> void:
	var r := Reglages.new()
	verifier(r.sauver(_chemin()))
	var texte := FileAccess.get_file_as_string(_chemin()).replace(
		"afficher_ips=false", 'afficher_ips=false\nmouvement_reduit="oui"'
	)
	_ecrire_brut(texte)
	verifier_faux(Reglages.charger(_chemin()).mouvement_reduit, "un texte n'est pas un booléen")


# --- La case ------------------------------------------------------------------------------------


func test_la_case_reflete_et_change_le_reglage() -> void:
	var ui := _ui()
	ui.configurer(Reglages.new())
	verifier_non_nul(ui.mouvement_reduit, "la case existe")
	verifier_faux(ui.mouvement_reduit.button_pressed, "décochée par défaut")
	var annonces: Array[Reglages] = []
	ui.modifies.connect(func(r: Reglages) -> void: annonces.append(r))
	ui.mouvement_reduit.toggled.emit(true)
	verifier(Reglages.charger(_chemin()).mouvement_reduit, "coché : enregistré")
	verifier_egal(annonces.size(), 1, "annoncé")
	verifier(annonces[0].mouvement_reduit, "l'annonce porte le choix")
	ui.mouvement_reduit.toggled.emit(false)
	verifier_faux(Reglages.charger(_chemin()).mouvement_reduit, "décoché : enregistré")
	var relu := Reglages.new()
	relu.mouvement_reduit = true
	ui.configurer(relu)
	verifier(ui.mouvement_reduit.button_pressed, "la case montre le réglage relu")
	verifier(ui.controles().has(ui.mouvement_reduit), "elle est dans la liste des contrôles")
	_liberer(ui)


func test_le_libelle_existe_avec_ses_accents() -> void:
	var textes := CsvTextes.lire(CSV_REGLAGES)
	verifier_egal(textes.get("REGLAGES_MOUVEMENT_REDUIT", ""), "Mouvement réduit")
	var ui := _ui()
	verifier_egal(ui.mouvement_reduit.text, "Mouvement réduit", "le libellé est affiché")
	_liberer(ui)


# --- L'arène -------------------------------------------------------------------------------------


func _principal(mouvement_reduit: bool) -> Principal:
	var r := Reglages.new()
	r.mouvement_reduit = mouvement_reduit
	verifier(r.sauver(_chemin()))
	var principal := (load("res://scenes/principal.tscn") as PackedScene).instantiate() as Principal
	principal.arguments = Arguments.lire(PackedStringArray())
	principal.arguments["graine"] = GRAINE
	principal.arguments["vitesse"] = 0.5
	principal.donnees = AidesPartie.donnees()
	principal.chemin_reglages = _chemin()
	arbre.root.add_child(principal)
	return principal


func test_l_arene_est_reduite_des_le_debut_d_une_partie_si_le_reglage_est_coche() -> void:
	for coche: bool in [false, true]:
		var principal := _principal(coche)
		principal.menu().bouton_solo.pressed.emit()
		var jeu := principal.jeu()
		verifier_non_nul(jeu, "la partie est ouverte")
		verifier_egal(jeu.arene.mouvement_reduit, coche, "arène au début (case %s)" % coche)
		_liberer(principal)


func test_changer_le_reglage_en_cours_de_partie_change_l_arene_tout_de_suite() -> void:
	var principal := _principal(false)
	principal.menu().bouton_solo.pressed.emit()
	var jeu := principal.jeu()
	var menu: MenuPrincipal = principal.menu()
	verifier_faux(jeu.arene.mouvement_reduit, "au début : normal")
	var r := Reglages.new()
	r.mouvement_reduit = true
	menu.reglages_modifies.emit(r)
	verifier(jeu.arene.mouvement_reduit, "coché : l'arène est réduite aussitôt")
	r.mouvement_reduit = false
	menu.reglages_modifies.emit(r)
	verifier_faux(jeu.arene.mouvement_reduit, "décoché : elle redevient normale")
	_liberer(principal)


func test_une_nouvelle_partie_reprend_le_reglage() -> void:
	var principal := _principal(true)
	principal.menu().bouton_solo.pressed.emit()
	var jeu := principal.jeu()
	jeu.arene.mouvement_reduit = false
	jeu.demarrer_solo(AidesPartie.donnees(), GRAINE, 0.5)
	verifier(jeu.arene.mouvement_reduit, "rejouer relit le réglage")
	_liberer(principal)
