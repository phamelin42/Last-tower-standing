extends CasDeTest
## Les réglages du joueur : ce qu'il retrouve après un redémarrage, et ce que devient l'écran
## quand le fichier est absent, abîmé ou trop gros. Aucune valeur n'écrase la bonne copie sans
## qu'une écriture réussie l'ait confirmé.

const CSV_REGLAGES := "res://i18n/textes_reglages.csv"
const TAILLE_MAX_FICHIER := 65536
const NOM_MAX := 24
const ADRESSE_MAX := 255
const SCENE := "res://scenes/reglages.tscn"
const TAILLE_MIN_TEXTE := 16
const HAUTEUR_MIN_CONTROLE := 48.0


func _chemin() -> String:
	return dossier_temporaire().path_join("reglages.cfg")


func _ecrire_brut(chemin: String, contenu: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(contenu)
	f.close()


func _reglages(
	volume: float, echelle: float, plein: bool, zoom: float, nom: String, adresse: String
) -> Reglages:
	var r := Reglages.new()
	r.volume_general = volume
	r.echelle_ui = echelle
	r.plein_ecran = plein
	r.sensibilite_zoom = zoom
	r.nom_joueur = nom
	r.derniere_adresse = adresse
	return r


func _egal_reglages(a: Reglages, b: Reglages) -> bool:
	return (
		is_equal_approx(a.volume_general, b.volume_general)
		and is_equal_approx(a.echelle_ui, b.echelle_ui)
		and a.plein_ecran == b.plein_ecran
		and is_equal_approx(a.sensibilite_zoom, b.sensibilite_zoom)
		and a.nom_joueur == b.nom_joueur
		and a.derniere_adresse == b.derniere_adresse
	)


func _par_defaut() -> Reglages:
	return Reglages.new()


func _ui_dans_arbre() -> ReglagesUi:
	var scene: PackedScene = load(SCENE)
	var ui: ReglagesUi = scene.instantiate()
	ui.chemin = _chemin()
	arbre.root.add_child(ui)
	return ui


# --- Aller-retour -------------------------------------------------------------------------


func test_chaque_reglage_revient_identique_apres_sauvegarde() -> void:
	var volumes: Array[float] = [0.0, 0.25, 0.8, 1.0]
	var echelles: Array[float] = Reglages.ECHELLES
	var zooms: Array[float] = [0.5, 0.75, 2.0]
	var noms: Array[String] = ["Anne", "Éloïse-Marie", "Ω", "a".repeat(NOM_MAX)]
	var adresses: Array[String] = ["", "192.168.1.20:7777", "partie.exemple.org"]
	var nb := 0
	for volume: float in volumes:
		for echelle: float in echelles:
			for plein: bool in [true, false]:
				for zoom: float in zooms:
					for nom: String in noms:
						for adresse: String in adresses:
							var voulu := _reglages(volume, echelle, plein, zoom, nom, adresse)
							verifier(voulu.sauver(_chemin()), "sauvegarde refusée")
							var relu := Reglages.charger(_chemin())
							verifier(
								_egal_reglages(relu, voulu),
								"aller-retour différent pour %s / %s / %s" % [volume, nom, adresse]
							)
							nb += 1
	verifier_egal(
		nb, volumes.size() * echelles.size() * 2 * zooms.size() * noms.size() * adresses.size()
	)


func test_le_nom_et_l_adresse_gardent_leurs_caracteres_visibles() -> void:
	var voulu := _reglages(1.0, 1.0, false, 1.0, "Zoé Ω", "[::1]:7777")
	verifier(voulu.sauver(_chemin()))
	verifier_egal(Reglages.charger(_chemin()).nom_joueur, "Zoé Ω")
	verifier_egal(Reglages.charger(_chemin()).derniere_adresse, "[::1]:7777")


# --- Fichier absent, abîmé, trop gros ----------------------------------------------------


func test_fichier_absent_donne_les_valeurs_par_defaut() -> void:
	var r := Reglages.charger(dossier_temporaire().path_join("inexistant.cfg"))
	verifier(_egal_reglages(r, _par_defaut()), "valeurs par défaut attendues")


func test_fichier_de_bruit_donne_les_valeurs_par_defaut() -> void:
	var generateur := RandomNumberGenerator.new()
	generateur.seed = 4242
	var octets := PackedByteArray()
	for i: int in 4000:
		octets.append(generateur.randi_range(0, 255))
	var f := FileAccess.open(_chemin(), FileAccess.WRITE)
	f.store_buffer(octets)
	f.close()
	verifier(_egal_reglages(Reglages.charger(_chemin()), _par_defaut()), "bruit ignoré")


func test_fichier_vide_donne_les_valeurs_par_defaut() -> void:
	_ecrire_brut(_chemin(), "")
	verifier(_egal_reglages(Reglages.charger(_chemin()), _par_defaut()), "vide ignoré")


func test_fichier_tronque_donne_les_valeurs_par_defaut_a_chaque_coupure() -> void:
	var voulu := _reglages(0.5, 1.5, true, 1.75, "Anne-Lise", "192.168.0.9:7777")
	verifier(voulu.sauver(_chemin()))
	var complet := FileAccess.get_file_as_string(_chemin())
	var defaut := _par_defaut()
	# Chaque coupure, y compris au milieu d'un nombre (« 0. ») : rien de coupé n'est lu.
	for longueur: int in range(0, complet.length()):
		_ecrire_brut(_chemin(), complet.substr(0, longueur))
		verifier(
			_egal_reglages(Reglages.charger(_chemin()), defaut),
			"coupure à %d lue au lieu du défaut" % longueur
		)
	_ecrire_brut(_chemin(), complet)
	verifier(_egal_reglages(Reglages.charger(_chemin()), voulu), "le fichier complet est lu")


func test_fichier_de_types_faux_donne_le_defaut_de_chaque_valeur() -> void:
	_ecrire_brut(
		_chemin(),
		(
			'[reglages]\nvolume_general="fort"\nplein_ecran=3\n'
			+ "echelle_ui=[1.5]\nsensibilite_zoom=null\nnom_joueur=12\nderniere_adresse=true\n"
			+ "; fin\n"
		)
	)
	verifier(_egal_reglages(Reglages.charger(_chemin()), _par_defaut()), "types faux ignorés")


func _fichier_de_taille(taille: int) -> String:
	var entete := "[reglages]\nvolume_general=0.5\n; "
	var fin := "\n; fin\n"
	return entete + "x".repeat(taille - entete.length() - fin.length()) + fin


func test_fichier_de_plus_de_64_kio_donne_les_valeurs_par_defaut() -> void:
	_ecrire_brut(_chemin(), _fichier_de_taille(TAILLE_MAX_FICHIER + 1))
	verifier(_egal_reglages(Reglages.charger(_chemin()), _par_defaut()), "fichier trop gros")


func test_fichier_de_64_kio_pile_est_lu() -> void:
	_ecrire_brut(_chemin(), _fichier_de_taille(TAILLE_MAX_FICHIER))
	verifier_proche(Reglages.charger(_chemin()).volume_general, 0.5, 0.0001)


# --- Bornes --------------------------------------------------------------------------------


func test_l_echelle_hors_bornes_est_ramenee_au_niveau_valide_le_plus_proche() -> void:
	var cas: Array[Array] = [
		[0.0, 1.0],
		[-3.0, 1.0],
		[0.9, 1.0],
		[1.0, 1.0],
		[1.2, 1.25],
		[1.3, 1.25],
		[1.25, 1.25],
		[1.4, 1.5],
		[1.5, 1.5],
		[99.0, 1.5],
		[1.5000001, 1.5],
	]  # fmt: skip
	for c: Array in cas:
		var r := _reglages(1.0, c[0], false, 1.0, "", "")
		r.normaliser()
		verifier_proche(r.echelle_ui, c[1], 0.0001, "échelle %s" % c[0])


func test_chaque_niveau_d_echelle_est_conserve() -> void:
	for niveau: float in Reglages.ECHELLES:
		var r := _reglages(1.0, niveau, false, 1.0, "", "")
		r.normaliser()
		verifier_proche(r.echelle_ui, niveau, 0.0001)
	verifier_egal(Reglages.ECHELLES.size(), 3, "trois niveaux au moins")


func test_le_volume_est_borne_entre_zero_et_un() -> void:
	var cas: Array[Array] = [[-1.0, 0.0], [0.0, 0.0], [0.37, 0.37], [1.0, 1.0], [7.0, 1.0]]
	for c: Array in cas:
		var r := _reglages(c[0], 1.0, false, 1.0, "", "")
		r.normaliser()
		verifier_proche(r.volume_general, c[1], 0.0001, "volume %s" % c[0])


func test_la_sensibilite_est_bornee_aux_valeurs_exactes() -> void:
	var cas: Array[Array] = [
		[0.0, 0.5],
		[0.49, 0.5],
		[0.5, 0.5],
		[2.0, 2.0],
		[2.01, 2.0],
		[9.0, 2.0],
	]  # fmt: skip
	for c: Array in cas:
		var r := _reglages(1.0, 1.0, false, c[0], "", "")
		r.normaliser()
		verifier_proche(r.sensibilite_zoom, c[1], 0.0001, "zoom %s" % c[0])


func test_le_nom_est_tronque_a_24_caracteres() -> void:
	var r := _reglages(1.0, 1.0, false, 1.0, "b".repeat(30), "")
	r.normaliser()
	verifier_egal(r.nom_joueur.length(), NOM_MAX)
	verifier_egal(r.nom_joueur, "b".repeat(NOM_MAX))


func test_le_nom_perd_ses_caracteres_de_controle() -> void:
	var sales := ["Ann\ne", "\tCécile", "Lou\u007fise", "  Mat  ", "\u0085Adam"]
	var propres := ["Anne", "Cécile", "Louise", "Mat", "Adam"]
	for i: int in sales.size():
		var r := _reglages(1.0, 1.0, false, 1.0, sales[i], "")
		r.normaliser()
		verifier_egal(r.nom_joueur, propres[i], "nettoyage de %s" % sales[i])


func test_l_adresse_est_bornee_et_sans_caractere_de_controle() -> void:
	var r := _reglages(1.0, 1.0, false, 1.0, "", "h".repeat(400) + "\n")
	r.normaliser()
	verifier_egal(r.derniere_adresse.length(), ADRESSE_MAX)
	verifier(not r.derniere_adresse.contains("\n"), "pas de saut de ligne")


func test_sauver_ecrit_des_valeurs_bornees() -> void:
	var r := _reglages(9.0, 0.0, true, 99.0, "c".repeat(40), "")
	verifier(r.sauver(_chemin()))
	var relu := Reglages.charger(_chemin())
	verifier_proche(relu.volume_general, 1.0, 0.0001)
	verifier_proche(relu.echelle_ui, 1.0, 0.0001)
	verifier_proche(relu.sensibilite_zoom, 2.0, 0.0001)
	verifier_egal(relu.nom_joueur.length(), NOM_MAX)


# --- Écriture atomique ---------------------------------------------------------------------


func test_un_echec_d_ecriture_garde_l_ancien_fichier() -> void:
	var ancien := _reglages(0.2, 1.25, false, 1.0, "Ancien", "ancien:7777")
	verifier(ancien.sauver(_chemin()))
	# Le temporaire ne peut pas être écrit : on y pose un dossier.
	DirAccess.make_dir_recursive_absolute(_chemin() + ".tmp")
	var nouveau := _reglages(0.9, 1.5, true, 2.0, "Nouveau", "nouveau:7777")
	verifier_faux(nouveau.sauver(_chemin()), "l'écriture doit échouer")
	verifier(_egal_reglages(Reglages.charger(_chemin()), ancien), "l'ancien réglage est intact")
	DirAccess.remove_absolute(_chemin() + ".tmp")


func test_un_echec_ne_touche_ni_au_dossier_gene_ni_a_l_ancien_fichier() -> void:
	var ancien := _reglages(0.2, 1.0, false, 1.0, "Ancien", "")
	verifier(ancien.sauver(_chemin()))
	DirAccess.make_dir_recursive_absolute(_chemin() + ".tmp")
	verifier_faux(_reglages(0.1, 1.0, true, 1.0, "X", "").sauver(_chemin()))
	verifier(DirAccess.dir_exists_absolute(_chemin() + ".tmp"), "le dossier n'est pas touché")
	DirAccess.remove_absolute(_chemin() + ".tmp")
	verifier_egal(Reglages.charger(_chemin()).nom_joueur, "Ancien")


func test_une_sauvegarde_reussie_remplace_le_fichier() -> void:
	verifier(_reglages(0.2, 1.0, false, 1.0, "Ancien", "").sauver(_chemin()))
	verifier(_reglages(0.7, 1.25, true, 1.0, "Nouveau", "").sauver(_chemin()))
	verifier_egal(Reglages.charger(_chemin()).nom_joueur, "Nouveau")
	verifier(not FileAccess.file_exists(_chemin() + ".tmp"), "pas de temporaire restant")


func test_un_chemin_non_inscriptible_fait_renvoyer_faux() -> void:
	var impossible := dossier_temporaire().path_join("absent").path_join("reglages.cfg")
	verifier_faux(_par_defaut().sauver(impossible), "dossier inexistant")


# --- Textes et interface -------------------------------------------------------------------


func test_chaque_cle_de_texte_utilisee_par_l_interface_existe_dans_le_csv() -> void:
	var source := FileAccess.get_file_as_string("res://ui/reglages_ui.gd")
	verifier(not source.is_empty(), "source de l'interface lisible")
	var textes := CsvTextes.lire(CSV_REGLAGES)
	verifier(not textes.is_empty(), "CSV lisible")
	var regex := RegEx.new()
	regex.compile('"(REGLAGES_[A-Z0-9_]+)"')
	var trouvees := 0
	for m: RegExMatch in regex.search_all(source):
		var cle := m.get_string(1)
		trouvees += 1
		verifier(textes.has(cle), "clé absente du CSV : %s" % cle)
		verifier(not String(textes.get(cle, "")).is_empty(), "texte vide : %s" % cle)
	verifier(trouvees > 0, "l'interface utilise des clés")


func test_l_interface_respecte_les_minimums_a_chaque_niveau() -> void:
	var ui := _ui_dans_arbre()
	for niveau: float in Reglages.ECHELLES:
		ui.appliquer_echelle(niveau)
		verifier(ui.taille_texte() >= TAILLE_MIN_TEXTE, "texte < 16 px au niveau %s" % niveau)
		for controle: Control in ui.controles():
			verifier(
				controle.custom_minimum_size.y >= HAUTEUR_MIN_CONTROLE,
				"%s sous 48 px au niveau %s" % [controle.get_class(), niveau]
			)
			verifier(
				controle.get_theme_font_size("font_size") >= TAILLE_MIN_TEXTE,
				"police < 16 px au niveau %s" % niveau
			)
	arbre.root.remove_child(ui)
	ui.free()


func test_le_texte_grandit_avec_l_echelle_sans_jamais_passer_sous_16() -> void:
	verifier_egal(Reglages.taille_texte_pour(1.0), 16)
	verifier_egal(Reglages.taille_texte_pour(1.25), 20)
	verifier_egal(Reglages.taille_texte_pour(1.5), 24)


func test_chaque_modification_est_sauvee_et_annoncee() -> void:
	var ui := _ui_dans_arbre()
	var annonces: Array[Reglages] = []
	ui.modifies.connect(func(r: Reglages) -> void: annonces.append(r))
	ui.volume.value_changed.emit(0.3)
	verifier_proche(Reglages.charger(_chemin()).volume_general, 0.3, 0.0001, "volume sauvé")
	ui.taille.item_selected.emit(2)
	verifier_proche(Reglages.charger(_chemin()).echelle_ui, 1.5, 0.0001, "échelle sauvée")
	ui.plein_ecran.toggled.emit(true)
	verifier(Reglages.charger(_chemin()).plein_ecran, "plein écran sauvé")
	ui.zoom.value_changed.emit(1.5)
	verifier_proche(Reglages.charger(_chemin()).sensibilite_zoom, 1.5, 0.0001, "zoom sauvé")
	ui.nom.text = "Véronique " + "é".repeat(30)
	ui.nom.text_submitted.emit(ui.nom.text)
	verifier_egal(Reglages.charger(_chemin()).nom_joueur.length(), NOM_MAX, "nom sauvé borné")
	ui.adresse.text = "exemple:7777"
	ui.adresse.text_submitted.emit(ui.adresse.text)
	verifier_egal(Reglages.charger(_chemin()).derniere_adresse, "exemple:7777", "adresse sauvée")
	verifier_egal(annonces.size(), 6, "une annonce par modification")
	arbre.root.remove_child(ui)
	ui.free()


func test_l_interface_affiche_les_reglages_relus() -> void:
	var voulu := _reglages(0.4, 1.25, true, 0.75, "Anne", "hote:7777")
	var ui := _ui_dans_arbre()
	ui.configurer(voulu)
	verifier_proche(ui.volume.value, 0.4, 0.0001)
	verifier_egal(ui.taille.selected, 1)
	verifier(ui.plein_ecran.button_pressed, "plein écran coché")
	verifier_proche(ui.zoom.value, 0.75, 0.0001)
	verifier_egal(ui.nom.text, "Anne")
	verifier_egal(ui.adresse.text, "hote:7777")
	arbre.root.remove_child(ui)
	ui.free()
