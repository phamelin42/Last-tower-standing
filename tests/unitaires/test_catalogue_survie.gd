extends CasDeTest
## Les 19 améliorations de survie de T9.11 : épines (+9), PV maximum (+5), régénération (+2) et
## armure (+3), avec leurs effets, leurs bornes, leurs images et leur place dans la hiérarchie.

## id → [famille, stat, clé du paramètre (statut), rareté attendue].
const NOUVELLES: Dictionary = {
	"piquants_affutes": ["epines", "epines_degats", "", Types.Rarete.RARE],
	"ronce_vorace": ["epines", "epines_croissantes", "", Types.Rarete.RARE],
	"piege_d_accueil": ["epines", "epines_premier_coup", "", Types.Rarete.RARE],
	"rosee_des_ronces": ["epines", "epines_soin", "", Types.Rarete.RARE],
	"gambison_hirsute": ["epines", "epines_reduction", "", Types.Rarete.RARE],
	"epines_venimeuses": ["epines", "epines_statut", "poison", Types.Rarete.RARE],
	"piquants_incandescents": ["epines", "epines_statut", "brulure", Types.Rarete.RARE],
	"givre_des_ronces": ["epines", "epines_statut", "givre", Types.Rarete.RARE],
	"pointes_assommantes": ["epines", "epines_statut", "etourdissement", Types.Rarete.RARE],
	"armature_massive": ["pv_max", "pv_max_mult", "", Types.Rarete.RARE],
	"rempart_colossal": ["pv_max", "pv_max_mult", "", Types.Rarete.EPIQUE],
	"onguent_de_manche": ["pv_max", "soin_pv_manquants", "", Types.Rarete.RARE],
	"puissance_de_la_pierre": ["pv_max", "degats_par_pv_max", "", Types.Rarete.RARE],
	"braise_de_phenix": ["pv_max", "resurrection", "", Types.Rarete.EPIQUE],
	"racines_patientes": ["regeneration", "regen_croissante", "", Types.Rarete.RARE],
	"pouls_du_rempart": ["regeneration", "soin_periodique", "", Types.Rarete.RARE],
	"patine_du_temps": ["armure", "armure_croissante", "", Types.Rarete.RARE],
	"cuirasse_de_givre": ["armure", "riposte_statut", "givre", Types.Rarete.RARE],
	"cotte_de_venin": ["armure", "riposte_statut", "poison", Types.Rarete.RARE],
}
const AJOUTS: Dictionary = {"epines": 9, "pv_max": 5, "regeneration": 2, "armure": 3}
const CIBLES: Dictionary = {"epines": 11, "pv_max": 7, "regeneration": 6, "armure": 5}

var _donnees: Donnees


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func _effet(id: String) -> Dictionary:
	return ((_donnees.ameliorations[id] as Dictionary)["effets"] as Array)[0]


func test_les_dix_neuf_ameliorations_existent_avec_leur_famille_leur_stat_et_leur_rarete() -> void:
	verifier_egal(NOUVELLES.size(), 19)
	for id: String in NOUVELLES:
		verifier(_donnees.ameliorations.has(id), "%s existe" % id)
		if not _donnees.ameliorations.has(id):
			continue
		var attendu: Array = NOUVELLES[id]
		var amelioration: Dictionary = _donnees.ameliorations[id]
		verifier_egal(amelioration["famille"], attendu[0], "%s : famille" % id)
		verifier_egal(
			amelioration["categorie"], Types.Categorie.AMELIORATION, "%s : catégorie" % id
		)
		verifier_egal(amelioration["rarete"], attendu[3], "%s : rareté" % id)
		verifier_egal(_effet(id)["stat"], attendu[1], "%s : stat" % id)
		if attendu[2] != "":
			verifier_egal(_effet(id)["statut"], attendu[2], "%s : statut" % id)


func test_chaque_famille_de_survie_gagne_ses_ameliorations_et_atteint_sa_cible() -> void:
	var comptes: Dictionary = {}
	for id: String in NOUVELLES:
		var famille: String = (NOUVELLES[id] as Array)[0]
		comptes[famille] = int(comptes.get(famille, 0)) + 1
	for famille: String in AJOUTS:
		verifier_egal(comptes.get(famille, 0), AJOUTS[famille], "%s : ajouts" % famille)
	var effectifs: Dictionary = {}
	for id: String in _donnees.ameliorations:
		var famille: String = (_donnees.ameliorations[id] as Dictionary)["famille"]
		effectifs[famille] = int(effectifs.get(famille, 0)) + 1
	for famille: String in CIBLES:
		verifier_egal(effectifs.get(famille, 0), CIBLES[famille], "%s : effectif" % famille)


func test_les_quatre_statuts_d_epines_et_les_deux_de_riposte_sont_proposes() -> void:
	var epines: Array[String] = []
	var riposte: Array[String] = []
	for id: String in NOUVELLES:
		var effet := _effet(id)
		if effet["stat"] == "epines_statut":
			epines.append(String(effet["statut"]))
		if effet["stat"] == "riposte_statut":
			riposte.append(String(effet["statut"]))
	epines.sort()
	riposte.sort()
	verifier_egal(epines, ["brulure", "etourdissement", "givre", "poison"] as Array[String])
	verifier_egal(riposte, ["givre", "poison"] as Array[String])


func test_les_croissances_ont_un_maximum_et_les_valeurs_sont_sensees() -> void:
	for id: String in ["ronce_vorace", "racines_patientes", "patine_du_temps"]:
		var effet := _effet(id)
		verifier(float(effet["max"]) >= float(effet["valeur"]), "%s : max ≥ un pas" % id)
	var resurrection := _effet("braise_de_phenix")
	verifier_egal(typeof(resurrection["valeur"]), TYPE_INT, "un pourcentage entier")
	verifier(int(resurrection["valeur"]) >= 1 and int(resurrection["valeur"]) <= 100)
	var soin := _effet("pouls_du_rempart")
	verifier(float(soin["ratio"]) > 0.0 and float(soin["tous_les"]) > 0.0)
	verifier(float(_effet("gambison_hirsute")["valeur"]) <= 0.5, "sous le plafond de réduction")
	for id: String in ["epines_venimeuses", "piquants_incandescents", "pointes_assommantes"]:
		verifier(float(_effet(id)["valeur"]) > 0.0, "%s : une durée" % id)


func test_une_epique_de_survie_coute_plus_cher_qu_une_rare_de_sa_famille() -> void:
	var plus_chere_rare := 0
	for id: String in NOUVELLES:
		if (NOUVELLES[id] as Array)[3] == Types.Rarete.RARE:
			plus_chere_rare = maxi(
				plus_chere_rare, int((_donnees.ameliorations[id] as Dictionary)["prix"])
			)
	for id: String in NOUVELLES:
		if (NOUVELLES[id] as Array)[3] == Types.Rarete.EPIQUE:
			verifier(int((_donnees.ameliorations[id] as Dictionary)["prix"]) > plus_chere_rare, id)


func test_chaque_amelioration_de_survie_a_une_image_une_case_et_un_nom_unique() -> void:
	var noms: Dictionary = {}
	for id: String in NOUVELLES:
		verifier(not ImagesOffres.entree(id).is_empty(), "%s : image" % id)
		verifier(FileAccess.file_exists(ImagesOffres.chemin_case(id)), "%s : case" % id)
		var amelioration: Dictionary = _donnees.ameliorations[id]
		var nom: String = amelioration["nom"]
		verifier(not noms.has(nom), "nom en double : %s" % nom)
		noms[nom] = id
		var texte: String = amelioration["description"]
		verifier(texte.ends_with("."), "%s : une phrase" % id)


func test_la_description_de_la_resurrection_donne_un_pourcentage_de_pv_max() -> void:
	var fiche: Dictionary = _donnees.ameliorations["braise_de_phenix"]
	var ligne := DescriptionOffre.ligne_effet(fiche, Types.Genre.AMELIORATION, _donnees)
	verifier(ligne.contains("50 %"), ligne)
	verifier_faux(ligne.contains("5000") or ligne.contains("5 000"), ligne)
