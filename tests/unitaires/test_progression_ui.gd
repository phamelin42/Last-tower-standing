extends CasDeTest
## L'écran « Progression » : ce que la joueuse a réussi, ce que ça débloque, et ses statistiques.
## Il lit un `Profil` et les données ; il ne calcule aucun défi. Les textes passent par `tr()`.

const CSV := "res://i18n/textes_progression.csv"
const SOURCE := "res://ui/progression_ui.gd"
const RESOLUTIONS: Array[Vector2] = [
	Vector2(1152.0, 648.0), Vector2(1366.0, 768.0), Vector2(1920.0, 1080.0)
]
const ECHELLES: Array[float] = [0.75, 1.0, 1.25]
const HAUTEUR_MIN := 48.0

var _ecran: ProgressionUi
var _donnees: Donnees
var _locale_avant: String = "en"


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	_donnees = Donnees.charger()
	_ecran = ProgressionUi.new()
	arbre.root.add_child(_ecran)


func apres_chaque() -> void:
	if is_instance_valid(_ecran):
		_ecran.get_parent().remove_child(_ecran)
		_ecran.free()
	TranslationServer.set_locale(_locale_avant)


func _t(cle: String) -> String:
	return TranslationServer.translate(cle)


func _profil(reussis: Array[String]) -> Profil:
	var p := Profil.new()
	for id: String in reussis:
		p.defis_reussis.append(id)
		p.skins_debloques.append(String((_donnees.defis[id] as Dictionary)["skin"]))
	p.parties = 12
	p.meilleure_manche = 23
	return p


func test_l_ecran_liste_chaque_defi_de_data_avec_son_etat() -> void:
	var ids: Array[String] = []
	for id: String in _donnees.defis:
		ids.append(id)
	# Un défi sur deux est réussi : les deux états se voient dans la même liste.
	var reussis: Array[String] = []
	for i: int in ids.size():
		if i % 2 == 0:
			reussis.append(ids[i])
	_ecran.configurer(_profil(reussis), _donnees)
	verifier_egal(_ecran.boutons_defis.size(), ids.size(), "une ligne par défi")
	for bouton: Button in _ecran.boutons_defis:
		var id: String = bouton.get_meta("defi")
		var defi: Dictionary = _donnees.defis[id]
		var attendu := _t("PROGRESSION_REUSSI") if reussis.has(id) else _t("PROGRESSION_A_FAIRE")
		verifier(bouton.text.contains(String(defi["nom"])), "%s : le nom" % id)
		verifier(bouton.text.contains(String(defi["texte"])), "%s : le texte" % id)
		verifier(bouton.text.contains(attendu), "%s : l'état en texte (%s)" % [id, attendu])
		var autre := _t("PROGRESSION_A_FAIRE") if reussis.has(id) else _t("PROGRESSION_REUSSI")
		verifier_faux(bouton.text.contains(autre), "%s : un seul état" % id)
		var skin := _t(ProgressionUi.cle_skin(String(defi["skin"])))
		verifier(bouton.text.contains(skin), "%s : le skin qu'il débloque (%s)" % [id, skin])


func test_l_ecran_montre_les_statistiques_du_profil() -> void:
	_ecran.configurer(_profil([]), _donnees)
	var textes := _ecran.textes()
	verifier(
		textes.has(_t("PROGRESSION_PARTIES") % Nombres.groupe(12)), "parties jouées : %s" % [textes]
	)
	verifier(
		textes.has(_t("PROGRESSION_MEILLEURE_MANCHE") % Nombres.groupe(23)), "meilleure manche"
	)


func test_un_profil_neuf_ne_montre_aucun_defi_reussi() -> void:
	_ecran.configurer(Profil.new(), _donnees)
	for bouton: Button in _ecran.boutons_defis:
		verifier(bouton.text.contains(_t("PROGRESSION_A_FAIRE")), "%s" % bouton.get_meta("defi"))
		verifier_faux(bouton.text.contains(_t("PROGRESSION_REUSSI")))


func test_tout_se_navigue_au_clavier_et_le_focus_est_visible() -> void:
	_ecran.configurer(_profil([]), _donnees)
	await attendre_images(1)
	var cibles: Array[Control] = []
	for bouton: Button in _ecran.boutons_defis:
		cibles.append(bouton)
	cibles.append(_ecran.bouton_retour)
	for cible: Control in cibles:
		verifier(cible.focus_mode == Control.FOCUS_ALL, "%s prend le focus" % cible.name)
		var style := cible.get_theme_stylebox("focus")
		verifier(style != null and not style is StyleBoxEmpty, "%s : focus visible" % cible.name)
		cible.grab_focus()
		verifier(cible.has_focus(), "%s a le focus" % cible.name)
	var retours: Array[bool] = []
	_ecran.retour.connect(func() -> void: retours.append(true))
	_ecran.bouton_retour.pressed.emit()
	verifier_egal(retours.size(), 1, "« Retour » annonce la sortie")


func test_les_ecrans_tiennent_a_75_et_125_pour_cent_sur_les_trois_resolutions() -> void:
	var tous: Array[String] = []
	for id: String in _donnees.defis:
		tous.append(id)
	_ecran.configurer(_profil(tous), _donnees)
	var minimum := _ecran.get_combined_minimum_size()
	for echelle: float in ECHELLES:
		for resolution: Vector2 in RESOLUTIONS:
			var zone := resolution / echelle
			verifier(
				minimum.x <= zone.x - 2.0 * MiseEnPage.MARGE and minimum.y <= zone.y,
				"%s à %s : %s ne tient pas" % [resolution, echelle, minimum]
			)
	for bouton: Button in _ecran.boutons_defis:
		verifier(bouton.custom_minimum_size.y >= HAUTEUR_MIN, "ligne de 48 px au moins")
	verifier(_ecran.bouton_retour.custom_minimum_size.y >= HAUTEUR_MIN, "« Retour » de 48 px")


func test_aucune_information_ne_repose_sur_la_couleur_seule() -> void:
	var ids: Array[String] = []
	for id: String in _donnees.defis:
		ids.append(id)
	_ecran.configurer(_profil([ids[0]]), _donnees)
	for bouton: Button in _ecran.boutons_defis:
		var etat := _t("PROGRESSION_REUSSI") if bouton.get_meta("defi") == ids[0] else ""
		var texte_etat := etat if not etat.is_empty() else _t("PROGRESSION_A_FAIRE")
		verifier(bouton.text.contains(texte_etat), "l'état est écrit : %s" % bouton.text)


func test_les_cles_de_textes_de_progression_ont_toutes_une_valeur_francaise_typographiee() -> void:
	var textes := CsvTextes.lire(CSV)
	verifier(textes.size() > 0, "le CSV se lit")
	for cle: String in textes:
		var texte: String = textes[cle]
		verifier(not texte.strip_edges().is_empty(), "%s est vide" % cle)
		_verifier_typographie(cle, texte)
	var requises: Array[String] = [
		"MENU_PROGRESSION",
		"PROGRESSION_TITRE",
		"PROGRESSION_REUSSI",
		"PROGRESSION_A_FAIRE",
		"PROGRESSION_DEBLOQUE",
		"PROGRESSION_PARTIES",
		"PROGRESSION_MEILLEURE_MANCHE",
		"PROGRESSION_RETOUR",
	]
	for id: String in _donnees.ids_skins():
		requises.append(ProgressionUi.cle_skin(id))
	# Un défi peut désigner un skin que `skins_tour.json` n'a pas encore : son nom s'écrit quand même.
	for id: String in _donnees.defis:
		requises.append(ProgressionUi.cle_skin(String((_donnees.defis[id] as Dictionary)["skin"])))
	for cle: String in requises:
		verifier(textes.has(cle), "clé absente : %s" % cle)


func test_chaque_texte_de_l_ecran_est_traduit() -> void:
	_ecran.configurer(_profil([]), _donnees)
	for texte: String in _ecran.textes():
		verifier_faux(texte.begins_with("PROGRESSION_"), "clé brute affichée : %s" % texte)
		verifier_faux(texte.begins_with("SKIN_"), "clé brute affichée : %s" % texte)


## Espace insécable avant « : ; ? ! » et à l'intérieur des « », jamais une espace ordinaire.
func _verifier_typographie(cle: String, texte: String) -> void:
	for signe: String in [":", ";", "?", "!"]:
		verifier_faux(
			texte.contains(" " + signe), "%s : espace ordinaire avant « %s »" % [cle, signe]
		)
	verifier_faux(texte.contains("« "), "%s : espace ordinaire après «" % cle)
	verifier_faux(texte.contains(" »"), "%s : espace ordinaire avant »" % cle)
	verifier_faux(texte.contains("'"), "%s : apostrophe droite" % cle)


func test_le_menu_principal_ouvre_la_progression_et_en_revient_au_clavier() -> void:
	var menu := MenuPrincipal.new()
	menu.chemin_progression = dossier_temporaire().path_join("progression.json")
	arbre.root.add_child(menu)
	verifier_egal(menu.bouton_progression.text, _t("MENU_PROGRESSION"))
	verifier(menu.bouton_progression.custom_minimum_size.y >= HAUTEUR_MIN, "48 px au moins")
	verifier_faux(menu.page_progression_visible())
	menu.bouton_progression.pressed.emit()
	verifier(menu.page_progression_visible(), "la page s'ouvre")
	var retour := menu.find_child("Retour", true, false) as Button
	verifier(retour != null and retour.has_focus(), "le focus est sur « Retour »")
	retour.pressed.emit()
	verifier_faux(menu.page_progression_visible(), "la page se ferme")
	verifier(menu.bouton_progression.has_focus(), "le focus revient sur « Progression »")
	arbre.root.remove_child(menu)
	menu.free()
