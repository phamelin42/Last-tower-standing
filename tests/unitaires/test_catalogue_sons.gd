extends CasDeTest
## Le catalogue de sons : chaque identifiant a un fichier attendu sous `assets/sons/`, et un
## fichier absent devient un silence de substitution : le jeu reste jouable sans le son.


func test_chaque_son_a_un_identifiant_distinct() -> void:
	var vus: Dictionary = {}
	for identifiant: String in CatalogueSons.tous():
		verifier(not vus.has(identifiant), "identifiant en double : %s" % identifiant)
		vus[identifiant] = true
	verifier_egal(vus.size(), CatalogueSons.tous().size())


func test_chaque_son_pointe_vers_un_fichier_du_dossier_des_sons() -> void:
	for identifiant: String in CatalogueSons.tous():
		var chemin := CatalogueSons.chemin(identifiant)
		verifier(
			chemin.begins_with("res://assets/sons/"),
			"%s hors de assets/sons : %s" % [identifiant, chemin],
		)
		verifier(chemin.ends_with(".ogg"), "%s n'est pas un .ogg" % identifiant)


func test_un_son_absent_devient_un_silence_de_substitution() -> void:
	for identifiant: String in CatalogueSons.tous():
		var flux := CatalogueSons.flux(identifiant)
		verifier_non_nul(flux, "flux présent pour %s" % identifiant)


func test_un_identifiant_inconnu_donne_le_silence_sans_erreur() -> void:
	verifier_non_nul(CatalogueSons.flux("son_qui_n_existe_pas"), "silence de repli")
	verifier(CatalogueSons.est_substitution("son_qui_n_existe_pas"), "marqué comme substitution")
