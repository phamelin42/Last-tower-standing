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
	for section: String in ["unites", "tour", "decor", "signatures", "ui", "sons", "effets"]:
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


func _maison(a: Dictionary) -> Dictionary:
	return (a["effets"] as Dictionary)["maison"]


func test_une_planche_citee_par_un_element_mais_non_decrite_est_refusee() -> void:
	var a := _donnees()
	var elements: Dictionary = _maison(a)["elements"]
	var id: String = elements.keys()[0]
	(elements[id] as Array).append("planche_fantome")
	verifier(_a_une_erreur(_erreurs(a), "planche_fantome"))


func test_une_planche_decrite_que_personne_ne_cite_est_refusee() -> void:
	var a := _donnees()
	(_maison(a)["planches"] as Dictionary)["orpheline"] = {"case": {"largeur": 8, "hauteur": 8}}
	verifier(_a_une_erreur(_erreurs(a), "orpheline"))


func test_une_planche_sans_case_ou_a_la_case_nulle_est_refusee() -> void:
	var a := _donnees()
	var planches: Dictionary = _maison(a)["planches"]
	var nom: String = planches.keys()[0]
	(planches[nom] as Dictionary).erase("case")
	verifier(_a_une_erreur(_erreurs(a), nom + ".case"), "sans case")
	a = _donnees()
	planches = _maison(a)["planches"]
	((planches[nom] as Dictionary)["case"] as Dictionary)["largeur"] = 0
	verifier(_a_une_erreur(_erreurs(a), nom + ".case"), "case nulle")


func test_le_diametre_visible_et_la_cadence_sont_facultatifs_mais_valides() -> void:
	var a := _donnees()
	var planches: Dictionary = _maison(a)["planches"]
	var nom: String = planches.keys()[0]
	(planches[nom] as Dictionary).erase("visible")
	(planches[nom] as Dictionary).erase("images_par_seconde")
	verifier_egal(_erreurs(a), [] as Array[String], "absents")
	(planches[nom] as Dictionary)["visible"] = -3.0
	verifier(_a_une_erreur(_erreurs(a), nom + ".visible"), "négatif")


func test_une_image_du_pack_sans_chemin_ou_sans_region_est_refusee() -> void:
	for cle: String in ["feu", "explosion", "fleche", "dynamite"]:
		var a := _donnees()
		var pack: Dictionary = ((a["effets"] as Dictionary)["pack"] as Dictionary)[cle]
		pack.erase("chemin")
		verifier(_a_une_erreur(_erreurs(a), cle + ".chemin"), cle)
	var a := _donnees()
	var fleche: Dictionary = ((a["effets"] as Dictionary)["pack"] as Dictionary)["fleche"]
	(fleche["region"] as Dictionary)["largeur"] = 0
	verifier(_a_une_erreur(_erreurs(a), "fleche.region"))


func test_une_combinaison_de_voisines_du_terrain_sans_tuile_est_refusee() -> void:
	var a := _donnees()
	((a["decor"] as Dictionary)["tuiles_herbe"] as Dictionary).erase("1010")
	verifier(_a_une_erreur(_erreurs(a), "1010"))
