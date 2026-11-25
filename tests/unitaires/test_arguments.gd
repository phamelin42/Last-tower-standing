extends CasDeTest
## Arguments de la ligne de commande : une valeur invalide donne la valeur par défaut et un
## message, jamais un plantage.


func _lire(args: Array[String]) -> Dictionary:
	return Arguments.lire(PackedStringArray(args))


func _messages(r: Dictionary) -> Array:
	return r["messages"]


func test_sans_argument_tout_vaut_le_defaut() -> void:
	var r := _lire([])
	verifier_faux(r["serveur"])
	verifier_egal(r["port"], 7777)
	verifier_egal(r["graine"], -1)
	verifier_egal(r["vitesse"], 1.0)
	verifier_faux(r["solo_auto"])
	verifier_egal(_messages(r).size(), 0)


func test_des_valeurs_valides_sont_lues() -> void:
	var r := _lire(
		["--serveur", "--port", "8123", "--graine", "42", "--vitesse", "0.5", "--solo-auto"]
	)
	verifier(r["serveur"])
	verifier_egal(r["port"], 8123)
	verifier_egal(r["graine"], 42)
	verifier_egal(r["vitesse"], 0.5)
	verifier(r["solo_auto"])
	verifier_egal(_messages(r).size(), 0)


func test_la_forme_avec_egal_est_acceptee() -> void:
	var r := _lire(["--port=9000", "--graine=0", "--vitesse=0.66"])
	verifier_egal(r["port"], 9000)
	verifier_egal(r["graine"], 0)
	verifier_egal(r["vitesse"], 0.66)


func test_chaque_port_invalide_donne_7777_et_un_message() -> void:
	for brut: String in ["0", "65536", "abc", "-1", "", "80.5", "99999999999999999999"]:
		var r := _lire(["--port", brut])
		verifier_egal(r["port"], 7777, "port « %s »" % brut)
		verifier_egal(_messages(r).size(), 1, "message pour « %s »" % brut)


func test_les_bornes_du_port_sont_valides() -> void:
	for brut: String in ["1", "65535"]:
		var r := _lire(["--port", brut])
		verifier_egal(r["port"], int(brut))
		verifier_egal(_messages(r).size(), 0)


func test_graine_negative_ou_illisible_donne_le_defaut() -> void:
	for brut: String in ["-5", "x", "1.5"]:
		var r := _lire(["--graine", brut])
		verifier_egal(r["graine"], -1, "graine « %s »" % brut)
		verifier_egal(_messages(r).size(), 1)


func test_seules_les_trois_vitesses_sont_acceptees() -> void:
	for brut: String in ["1", "0.66", "0.5"]:
		verifier_egal(_lire(["--vitesse", brut])["vitesse"], float(brut))
	for brut: String in ["2", "0", "0.7", "vite", "-1", "nan"]:
		var r := _lire(["--vitesse", brut])
		verifier_egal(r["vitesse"], 1.0, "vitesse « %s »" % brut)
		verifier_egal(_messages(r).size(), 1)


func test_une_valeur_manquante_en_fin_de_ligne_donne_le_defaut() -> void:
	for option: String in ["--port", "--graine", "--vitesse"]:
		var r := _lire([option])
		verifier_egal(_messages(r).size(), 1, option)
	verifier_egal(_lire(["--port"])["port"], 7777)


func test_un_argument_inconnu_est_signale_et_ignore() -> void:
	var r := _lire(["--bidule", "--port", "8001", "pas-une-option"])
	verifier_egal(r["port"], 8001)
	verifier_egal(_messages(r).size(), 2)


func test_une_valeur_repetee_garde_la_derniere() -> void:
	var r := _lire(["--port", "8001", "--port", "8002", "--graine", "1", "--graine", "2"])
	verifier_egal(r["port"], 8002)
	verifier_egal(r["graine"], 2)


func test_une_valeur_invalide_apres_une_valide_ne_la_ecrase_pas() -> void:
	var r := _lire(["--port", "8001", "--port", "abc"])
	verifier_egal(r["port"], 7777)
