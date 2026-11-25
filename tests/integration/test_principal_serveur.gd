extends CasDeTest
## `--serveur` : le processus lance le serveur dédié à la place du menu, et sort avec le code du
## serveur quand il ne peut pas s'ouvrir.

var _principal: Principal = null
var _codes: Array[int] = []


func apres_chaque() -> void:
	if _principal != null and is_instance_valid(_principal):
		for enfant: Node in _principal.get_children():
			if enfant is ServeurDedie:
				(enfant as ServeurDedie).arreter()
		_principal.get_parent().remove_child(_principal)
		_principal.queue_free()
	_principal = null


func _lancer(args: PackedStringArray, dossier: String = Donnees.DOSSIER_REEL) -> Principal:
	_codes = []
	var p := (load("res://scenes/principal.tscn") as PackedScene).instantiate() as Principal
	p.arguments = ServeurDedie.lire_options(args)
	p.dossier_donnees = dossier
	p.sortie = func(code: int) -> void: _codes.append(code)
	arbre.root.add_child(p)
	_principal = p
	return p


func _serveur_de(p: Principal) -> ServeurDedie:
	for enfant: Node in p.get_children():
		if enfant is ServeurDedie:
			return enfant as ServeurDedie
	return null


func test_avec_serveur_le_serveur_dedie_ecoute_et_le_menu_n_est_pas_charge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + OS.get_process_id()
	var port := rng.randi_range(20000, 40000)
	var p := _lancer(PackedStringArray(["--serveur", "--port", str(port)]))
	var s := _serveur_de(p)
	verifier(s != null, "la scène du serveur dédié est ajoutée")
	if s == null:
		return
	verifier(s.est_actif(), "le serveur écoute")
	verifier_nul(p.menu(), "le menu n'est pas chargé")
	verifier_egal(_codes.size(), 0, "aucune sortie tant que le serveur tourne")


func test_un_port_pris_fait_sortir_avec_le_code_3() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + OS.get_process_id()
	var port := rng.randi_range(20000, 40000)
	var occupant := ENetMultiplayerPeer.new()
	verifier_egal(occupant.create_server(port, 4), OK)
	attendre_erreur("Couldn't create an ENet host")
	var p := _lancer(PackedStringArray(["--serveur", "--port", str(port)]))
	occupant.close()
	verifier(p != null)
	verifier_egal(_codes, [3] as Array[int], "sortie avec le code du serveur")


func test_des_donnees_absentes_font_sortir_avec_le_code_2() -> void:
	for _fichier: int in 5:
		attendre_erreur("absent")
	_lancer(PackedStringArray(["--serveur"]), "res://data_inexistant")
	verifier_egal(_codes, [2] as Array[int])
