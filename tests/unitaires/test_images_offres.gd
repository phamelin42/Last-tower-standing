extends CasDeTest
## Chaque offre de la boutique (30 armes, 40 améliorations) a son objet dessiné sur une case : une
## icône du pack Ravenmore qui existe, une couleur de case connue, et une case composée de 128 px.
## Les listes viennent de `data/` : une offre ajoutée sans image fait échouer ce test.

const DOSSIER_CASES := "res://assets/icones/cases/"
const TAILLE_CASE: int = 128

var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func _ids_offres() -> PackedStringArray:
	var ids: PackedStringArray = []
	for id: Variant in _donnees.armes:
		ids.append(String(id))
	for id: Variant in _donnees.ameliorations:
		ids.append(String(id))
	return ids


func test_il_y_a_trente_armes_et_quarante_ameliorations() -> void:
	verifier_egal(_donnees.armes.size(), 30)
	verifier_egal(_donnees.ameliorations.size(), 40)
	verifier_egal(ImagesOffres.ids().size(), 70)


func test_chaque_offre_de_data_a_une_entree_et_aucune_entree_n_est_orpheline() -> void:
	var attendus: PackedStringArray = _ids_offres()
	for id: String in attendus:
		verifier(not ImagesOffres.entree(id).is_empty(), "entrée de %s" % id)
	for id: String in ImagesOffres.ids():
		verifier(attendus.has(id), "%s n'est pas une offre de data/" % id)


func test_chaque_icone_citee_existe_et_chaque_couleur_est_connue() -> void:
	for id: String in ImagesOffres.ids():
		var e: Dictionary = ImagesOffres.entree(id)
		var chemin: String = ImagesOffres.chemin_icone(String(e["icone"]))
		verifier(FileAccess.file_exists(chemin), "%s : icône %s" % [id, chemin])
		verifier(ImagesOffres.COULEURS.has(e["couleur"]), "%s : couleur %s" % [id, e["couleur"]])


func test_les_armes_prennent_la_couleur_de_leur_type_de_degats() -> void:
	var attendu: Dictionary = {
		"tranchant": "brique",
		"perçant": "vert",
		"magique": "violet",
		"siège": "brun",
		"chaos": "pourpre",
	}
	for id: Variant in _donnees.armes:
		var arme: Dictionary = _donnees.armes[id]
		var type_degats: String = Types.NOMS_TYPES[int(arme["type_degats"])]
		verifier(attendu.has(type_degats), "type %s connu" % type_degats)
		verifier_egal(
			ImagesOffres.entree(String(id))["couleur"], attendu.get(type_degats, ""), String(id)
		)


func test_un_bonus_de_degats_d_un_type_prend_la_couleur_de_ce_type() -> void:
	var attendu: Dictionary = {
		"tranchant": "brique",
		"perçant": "vert",
		"magique": "violet",
		"siège": "brun",
		"chaos": "pourpre",
	}
	var vus: int = 0
	for id: Variant in _donnees.ameliorations:
		var amelioration: Dictionary = _donnees.ameliorations[id]
		for effet: Variant in amelioration["effets"]:
			var e: Dictionary = effet
			if e["stat"] == "degats_type":
				vus += 1
				verifier_egal(
					ImagesOffres.entree(String(id))["couleur"],
					attendu.get(Types.NOMS_TYPES[int(e["type_degats"])], ""),
					String(id)
				)
			elif e["stat"] == "degats_global":
				verifier_egal(ImagesOffres.entree(String(id))["couleur"], "dore", String(id))
	verifier_egal(vus, 10)


func test_deux_offres_n_ont_jamais_la_meme_icone_avec_la_meme_couleur() -> void:
	var vues: Dictionary = {}
	for id: String in ImagesOffres.ids():
		var e: Dictionary = ImagesOffres.entree(id)
		var cle: String = "%s/%s" % [e["icone"], e["couleur"]]
		verifier(not vues.has(cle), "%s et %s : même case (%s)" % [id, vues.get(cle, ""), cle])
		vues[cle] = id


func test_les_rapprochements_faibles_sont_des_offres_connues() -> void:
	var ids: PackedStringArray = ImagesOffres.ids()
	for id: String in ImagesOffres.RAPPROCHEMENTS_FAIBLES:
		verifier(ids.has(id), "%s est une offre" % id)


func test_chaque_case_composee_existe_et_fait_128_sur_128() -> void:
	for id: String in ImagesOffres.ids():
		var chemin: String = ImagesOffres.chemin_case(id)
		var img := Image.load_from_file(ProjectSettings.globalize_path(chemin))
		verifier_non_nul(img, "case de %s lisible" % id)
		if img != null:
			verifier_egal(img.get_width(), TAILLE_CASE, "largeur de %s" % id)
			verifier_egal(img.get_height(), TAILLE_CASE, "hauteur de %s" % id)


func test_le_script_regenere_les_soixante_dix_cases_au_octet_pres() -> void:
	var sortie: String = dossier_temporaire()
	var args := PackedStringArray(
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			"res://tools/composer_images_offres.gd",
			"--",
			"--sortie",
			sortie,
		]
	)
	var journal: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, journal, true)
	verifier_egal(code, 0, "le script réussit : %s" % str(journal))
	for id: String in ImagesOffres.ids():
		var neuf: PackedByteArray = FileAccess.get_file_as_bytes(sortie.path_join(id + ".png"))
		var versionne: PackedByteArray = FileAccess.get_file_as_bytes(
			ProjectSettings.globalize_path(ImagesOffres.chemin_case(id))
		)
		verifier(neuf.size() > 0, "%s : case regénérée non vide" % id)
		verifier(neuf == versionne, "%s : mêmes octets que la case versionnée" % id)
