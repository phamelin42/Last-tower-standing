extends CasDeTest
## `data/assets.json` est validé au chargement : un pack mal décrit se voit à l'ouverture des
## données, pas à l'écran. Chaque mutation ci-dessous casse une règle à la fois.


func _donnees() -> Dictionary:
	return Assets.tout().duplicate(true)


func _erreurs(a: Dictionary) -> Array[String]:
	var err: Array[String] = []
	DonneesAssets.valider(a, err)
	return err


func _a_une_erreur(err: Array[String], morceau: String) -> bool:
	for e: String in err:
		if e.contains(morceau):
			return true
	return false


func test_le_fichier_livre_est_valide_et_se_charge_avec_le_reste_des_donnees() -> void:
	verifier_egal(_erreurs(_donnees()), [] as Array[String])
	verifier(Donnees.valider(AidesPartie.brut()).is_empty())


func test_un_fichier_absent_ou_vide_est_accepte() -> void:
	verifier_egal(_erreurs({}), [] as Array[String])


func test_une_section_manquante_est_refusee() -> void:
	for section: String in ["unites", "tour", "decor", "signatures", "ui", "sons"]:
		var a := _donnees()
		a.erase(section)
		verifier(_a_une_erreur(_erreurs(a), "assets.json"), "sans " + section)


func test_une_entite_qui_cite_un_modele_inconnu_est_refusee() -> void:
	var a := _donnees()
	var entites: Dictionary = (a["unites"] as Dictionary)["entites"]
	var premiere: String = entites.keys()[0]
	(entites[premiere] as Dictionary)["modele"] = "inconnu"
	verifier(_a_une_erreur(_erreurs(a), premiere))


func test_une_animation_hors_de_la_feuille_est_refusee() -> void:
	var a := _donnees()
	var torch: Dictionary = ((a["unites"] as Dictionary)["modeles"] as Dictionary)["torch"]
	(torch["course"] as Dictionary)["ligne"] = int(torch["lignes"])
	verifier(_a_une_erreur(_erreurs(a), "course"))
	a = _donnees()
	torch = ((a["unites"] as Dictionary)["modeles"] as Dictionary)["torch"]
	(torch["repos"] as Dictionary)["images"] = int(torch["colonnes"]) + 1
	verifier(_a_une_erreur(_erreurs(a), "repos"))


func test_une_echelle_nulle_ou_negative_est_refusee() -> void:
	for valeur: float in [0.0, -1.0]:
		var a := _donnees()
		(a["tour"] as Dictionary)["echelle"] = valeur
		verifier(_a_une_erreur(_erreurs(a), "echelle"), "echelle " + str(valeur))


func test_un_chemin_vide_ou_un_nombre_a_la_place_d_un_texte_est_refuse() -> void:
	var a := _donnees()
	(a["sons"] as Dictionary)["dossier"] = ""
	verifier(_a_une_erreur(_erreurs(a), "dossier"))
	a = _donnees()
	(a["sons"] as Dictionary)["extension"] = 3
	verifier(_a_une_erreur(_erreurs(a), "extension"))


func test_une_case_negative_est_refusee() -> void:
	var a := _donnees()
	var torch: Dictionary = ((a["unites"] as Dictionary)["modeles"] as Dictionary)["torch"]
	(torch["case"] as Dictionary)["largeur"] = -192
	verifier(_a_une_erreur(_erreurs(a), "case"))
