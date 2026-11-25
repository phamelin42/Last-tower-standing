extends CasDeTest
## Compteur d'images par seconde (T5.1b) : ce que la joueuse lit, la touche F3 et le réglage.

const NBSP := " "
const CSV_HUD := "res://i18n/textes_hud.csv"
const SCENE_REGLAGES := "res://scenes/reglages.tscn"

var _compteur: CompteurIps = null


func apres_chaque() -> void:
	if _compteur != null and is_instance_valid(_compteur):
		if _compteur.get_parent() != null:
			_compteur.get_parent().remove_child(_compteur)
		_compteur.free()
	_compteur = null


func _creer() -> CompteurIps:
	_compteur = CompteurIps.new()
	arbre.root.add_child(_compteur)
	return _compteur


func _touche(code: Key, appuyee: bool = true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = appuyee
	return e


# --- La fenêtre de 5 secondes -----------------------------------------------------------------


func test_le_minimum_couvre_les_cinq_dernieres_secondes() -> void:
	var c := _creer()
	c.mesurer(0.0, 30.0)
	c.mesurer(1.0, 60.0)
	c.mesurer(2.0, 58.0)
	verifier_proche(c.minimum(), 30.0, 0.001, "la chute à 30 est encore dans la fenêtre")
	verifier_proche(c.ips_courant(), 58.0, 0.001, "le courant est la dernière mesure")


func test_une_vieille_mesure_sort_de_la_fenetre() -> void:
	var c := _creer()
	c.mesurer(0.0, 30.0)
	c.mesurer(1.0, 60.0)
	c.mesurer(2.0, 58.0)
	c.mesurer(5.1, 59.0)
	verifier_proche(c.minimum(), 58.0, 0.001, "la mesure de 0 s a plus de 5 s : elle sort")
	c.mesurer(7.1, 61.0)
	verifier_proche(c.minimum(), 59.0, 0.001, "celle de 2 s sort à son tour")


func test_une_chute_recente_reste_visible_jusqu_a_cinq_secondes() -> void:
	var c := _creer()
	for i: int in 31:
		var t := float(i) * 0.25
		c.mesurer(t, 20.0 if i == 10 else 60.0)
	# La chute date de 2,5 s ; la dernière mesure est à 7,5 s : 5,0 s plus tard, elle sort à peine.
	c.mesurer(7.4, 60.0)
	verifier_proche(c.minimum(), 20.0, 0.001, "7,4 s - 2,5 s = 4,9 s : encore dans la fenêtre")
	c.mesurer(7.6, 60.0)
	verifier_proche(c.minimum(), 60.0, 0.001, "7,6 s - 2,5 s = 5,1 s : sortie")


func test_la_mise_a_jour_se_fait_environ_quatre_fois_par_seconde() -> void:
	var c := _creer()
	# Le compteur du moteur n'est fiable qu'après une seconde : rien n'est retenu avant.
	for i: int in 19:
		c._process(0.05)
	verifier_egal(c.nombre_mesures(), 0, "pas de mesure pendant la première seconde")
	for i: int in 41:
		c._process(0.05)
	# 2 s de mesures, une tous les 0,25 s.
	verifier(c.nombre_mesures() >= 7 and c.nombre_mesures() <= 9, "%d mesures" % c.nombre_mesures())


# --- Le texte -----------------------------------------------------------------------------------


func test_le_texte_donne_images_minimum_et_ennemis() -> void:
	var c := _creer()
	c.fournisseur_ennemis = func() -> int: return 1000
	c.mesurer(0.0, 58.0)
	c.mesurer(1.0, 60.0)
	var attendu := (
		"60"
		+ NBSP
		+ "img/s · min."
		+ NBSP
		+ "5"
		+ NBSP
		+ "s"
		+ NBSP
		+ ": 58 · ennemis"
		+ NBSP
		+ ": 1"
		+ Nombres.SEPARATEUR_MILLIERS
		+ "000"
	)
	verifier_egal(c.texte(), attendu)


func test_le_texte_suit_les_mesures_injectees() -> void:
	var c := _creer()
	var valeurs: Array[int] = [1, 59, 60, 144, 240]
	var ennemis: Array[int] = [0, 7, 999, 1000, 5000]
	for i: int in valeurs.size():
		var n := ennemis[i]
		c.fournisseur_ennemis = func() -> int: return n
		c.mesurer(float(i) * 10.0, float(valeurs[i]))
		verifier(c.texte().begins_with("%d%simg/s" % [valeurs[i], NBSP]), c.texte())
		verifier(c.texte().ends_with(Nombres.groupe(n)), c.texte())


func test_sans_fournisseur_le_compteur_ne_plante_pas_et_compte_zero_ennemi() -> void:
	var c := _creer()
	c.mesurer(0.0, 60.0)
	verifier(c.texte().ends_with(" 0"), c.texte())


func test_le_texte_respecte_la_typographie_francaise() -> void:
	var textes := CsvTextes.lire(CSV_HUD)
	for cle: String in ["IPS_COMPTEUR", "IPS_BANC_EN_COURS", "IPS_BANC_RESUME"]:
		var ligne := String(textes.get(cle, ""))
		verifier(not ligne.is_empty(), "clé absente : %s" % cle)
		for signe: String in [":", ";", "?", "!"]:
			verifier(
				not ligne.contains(" " + signe),
				"espace ordinaire avant « %s » : %s" % [signe, ligne]
			)
		verifier(
			not ligne.contains("img/s".insert(0, " ")),
			"« img/s » doit suivre un nombre insécable : %s" % ligne
		)
	var compteur := String(textes.get("IPS_COMPTEUR", ""))
	verifier(compteur.contains("5" + NBSP + "s" + NBSP + ":"), compteur)
	verifier(compteur.contains("ennemis" + NBSP + ":"), compteur)


# --- Touche F3 ----------------------------------------------------------------------------------


func test_l_action_f3_est_declaree_dans_la_carte_des_touches() -> void:
	verifier(InputMap.has_action(CompteurIps.ACTION), "action absente de project.godot")
	var trouvee := false
	for e: InputEvent in InputMap.action_get_events(CompteurIps.ACTION):
		var k := e as InputEventKey
		if k != null and k.physical_keycode == KEY_F3:
			trouvee = true
	verifier(trouvee, "F3 n'est pas liée à l'action")


func test_le_compteur_est_masque_par_defaut() -> void:
	var c := _creer()
	verifier_faux(c.visible)


func test_f3_affiche_puis_masque_le_compteur() -> void:
	var c := _creer()
	Input.parse_input_event(_touche(KEY_F3))
	await attendre_images(2)
	verifier(c.visible, "F3 affiche")
	Input.parse_input_event(_touche(KEY_F3, false))
	await attendre_images(1)
	Input.parse_input_event(_touche(KEY_F3))
	await attendre_images(2)
	verifier_faux(c.visible, "un second F3 masque")


func test_une_autre_touche_ne_change_rien() -> void:
	var c := _creer()
	for code: Key in [KEY_F2, KEY_F4, KEY_A, KEY_SPACE, KEY_ESCAPE, KEY_3]:
		c._unhandled_input(_touche(code))
		verifier_faux(c.visible, "la touche %d ne doit pas afficher le compteur" % code)


func test_le_lacher_de_la_touche_et_la_repetition_ne_basculent_pas() -> void:
	var c := _creer()
	c._unhandled_input(_touche(KEY_F3, false))
	verifier_faux(c.visible, "relâcher n'affiche pas")
	var repete := _touche(KEY_F3)
	repete.echo = true
	c._unhandled_input(repete)
	verifier_faux(c.visible, "la répétition automatique n'affiche pas")


func test_le_compteur_affiche_son_texte_une_fois_visible() -> void:
	var c := _creer()
	c.mesurer(0.0, 55.0)
	c.definir_visible(true)
	verifier(c.etiquette().text.begins_with("55" + NBSP + "img/s"), c.etiquette().text)


func test_le_texte_est_lisible_a_seize_pixels_au_moins() -> void:
	var c := _creer()
	verifier(c.etiquette().get_theme_font_size("font_size") >= 16)


# --- Réglage ------------------------------------------------------------------------------------


func _chemin() -> String:
	return dossier_temporaire().path_join("reglages.cfg")


func test_le_reglage_est_desactive_par_defaut() -> void:
	verifier_faux(Reglages.new().afficher_ips)
	verifier_faux(Reglages.charger(dossier_temporaire().path_join("absent.cfg")).afficher_ips)


func test_le_reglage_survit_a_l_ecriture_et_a_la_relecture() -> void:
	var r := Reglages.new()
	r.afficher_ips = true
	r.nom_joueur = "Ada"
	verifier(r.sauver(_chemin()))
	var lu := Reglages.charger(_chemin())
	verifier(lu.afficher_ips, "activé relu")
	verifier_egal(lu.nom_joueur, "Ada", "les autres réglages sont intacts")
	lu.afficher_ips = false
	verifier(lu.sauver(_chemin()))
	verifier_faux(Reglages.charger(_chemin()).afficher_ips, "désactivé relu")


func test_une_valeur_invalide_est_ramenee_au_defaut() -> void:
	for brut: String in ['"oui"', "3", "1.5", "[true]", "null"]:
		var f := FileAccess.open(_chemin(), FileAccess.WRITE)
		f.store_string("[reglages]\nafficher_ips=%s\n%s" % [brut, Reglages.FIN])
		f.close()
		verifier_faux(Reglages.charger(_chemin()).afficher_ips, "valeur %s" % brut)


func test_la_case_des_reglages_est_lue_et_ecrite() -> void:
	var ui := (load(SCENE_REGLAGES) as PackedScene).instantiate() as ReglagesUi
	ui.chemin = _chemin()
	arbre.root.add_child(ui)
	var r := Reglages.new()
	r.afficher_ips = true
	ui.configurer(r)
	verifier(ui.afficher_ips.button_pressed, "la case reflète le réglage")
	verifier_faux(FileAccess.file_exists(_chemin()), "afficher ne sauvegarde rien")
	ui.afficher_ips.button_pressed = false
	verifier_faux(Reglages.charger(_chemin()).afficher_ips, "décocher enregistre")
	ui.afficher_ips.button_pressed = true
	verifier(Reglages.charger(_chemin()).afficher_ips, "cocher enregistre")
	verifier(ui.controles().has(ui.afficher_ips), "la case fait partie des commandes mesurées")
	verifier(ui.afficher_ips.custom_minimum_size.y >= 48.0, "48 px de haut")
	arbre.root.remove_child(ui)
	ui.free()
