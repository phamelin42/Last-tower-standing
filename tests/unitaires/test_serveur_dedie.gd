extends CasDeTest
## Le serveur dédié : codes de sortie, bornes des options, démarrage et arrêt sur un port libre,
## réouverture du salon après une partie, sortie du processus avec `--quitter-a-la-fin`.
## Le port est tiré à l'exécution : d'autres agents lancent leurs tests en même temps.

const ESSAIS_PORT: int = 40
const PORT_OCCUPE_ALEATOIRE_SEED: int = 20261125

var d: Donnees = null
var api: SceneMultiplayer = null
var noeud: ServeurDedie = null
var bloquant: ENetMultiplayerPeer = null


func avant_chaque() -> void:
	d = Donnees.charger()
	api = null
	noeud = null
	bloquant = null


func apres_chaque() -> void:
	if noeud != null:
		noeud.arreter()
	if bloquant != null:
		bloquant.close()
	if api != null:
		api.multiplayer_peer = null


# --- Aides -----------------------------------------------------------------------------------


## Le serveur dédié dans l'arbre, avec sa propre `SceneMultiplayer` (comme les tests ENet).
func _monter() -> ServeurDedie:
	api = SceneMultiplayer.new()
	var racine := Node.new()
	racine.name = "RacineDedie"
	arbre.root.add_child(racine)
	noeud = (load("res://scenes/serveur.tscn") as PackedScene).instantiate() as ServeurDedie
	racine.add_child(noeud)
	arbre.set_multiplayer(api, racine.get_path())
	return noeud


func _args(port: int, acceleration: int = 1, quitter: bool = false) -> Dictionary:
	return {
		"port": port,
		"graine": -1,
		"vitesse": 1.0,
		"acceleration": acceleration,
		"quitter_a_la_fin": quitter,
	}


## Un port libre à l'instant où on le tire : essais jusqu'à ce que le démarrage réussisse.
func _lancer_sur_port_libre(n: ServeurDedie, quitter: bool = false) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = PORT_OCCUPE_ALEATOIRE_SEED + OS.get_process_id()
	for i: int in ESSAIS_PORT:
		var port := rng.randi_range(20000, 60000)
		if n.lancer(_args(port, 1, quitter), d) == 0:
			return port
	return -1


func _bonjour(nom: String) -> PackedByteArray:
	return Protocole.encoder_bonjour(nom, d.empreinte)


# --- Codes de sortie -------------------------------------------------------------------------


func test_des_donnees_absentes_donnent_le_code_2() -> void:
	var n := _monter()
	verifier_egal(n.lancer(_args(7777), null), 2)
	verifier(not n.est_actif(), "rien ne s'ouvre sans données")


func test_un_port_zero_donne_le_code_3() -> void:
	var n := _monter()
	verifier_egal(n.lancer(_args(0), d), 3)
	verifier(not n.est_actif())


func test_un_port_occupe_donne_le_code_3() -> void:
	var n := _monter()
	var rng := RandomNumberGenerator.new()
	rng.seed = PORT_OCCUPE_ALEATOIRE_SEED + OS.get_process_id()
	var port := -1
	bloquant = ENetMultiplayerPeer.new()
	for i: int in ESSAIS_PORT:
		var essai := rng.randi_range(20000, 60000)
		if bloquant.create_server(essai, 1) == OK:
			port = essai
			break
	verifier(port > 0, "le test tient un port")
	# ENet refuse la seconde ouverture et le dit sur stderr : c'est l'erreur voulue.
	attendre_erreur("Couldn't create an ENet host")
	verifier_egal(n.lancer(_args(port), d), 3, "le port %d est pris" % port)
	verifier(not n.est_actif())


# --- Options ---------------------------------------------------------------------------------


func test_l_acceleration_est_bornee_entre_1_et_60() -> void:
	verifier_egal(
		ServeurDedie.lire_options(PackedStringArray(["--acceleration", "0"]))["acceleration"], 1
	)
	verifier_egal(
		ServeurDedie.lire_options(PackedStringArray(["--acceleration", "1000"]))["acceleration"], 60
	)
	verifier_egal(
		ServeurDedie.lire_options(PackedStringArray(["--acceleration", "1"]))["acceleration"], 1
	)
	verifier_egal(
		ServeurDedie.lire_options(PackedStringArray(["--acceleration", "60"]))["acceleration"], 60
	)
	verifier_egal(ServeurDedie.lire_options(PackedStringArray([]))["acceleration"], 1, "défaut")


func test_quitter_a_la_fin_est_lu_sans_toucher_aux_autres_options() -> void:
	var o := ServeurDedie.lire_options(
		PackedStringArray(["--serveur", "--port", "17777", "--quitter-a-la-fin"])
	)
	verifier(bool(o["quitter_a_la_fin"]), "drapeau lu")
	verifier(bool(o["serveur"]), "--serveur gardé")
	verifier_egal(int(o["port"]), 17777, "port gardé")
	verifier_egal((o["messages"] as Array).size(), 0, "aucun message pour une option connue")


# --- Démarrage et arrêt ----------------------------------------------------------------------


func test_demarrage_et_arret_sans_erreur_sur_un_port_libre() -> void:
	var n := _monter()
	var port := _lancer_sur_port_libre(n)
	verifier(port > 0, "un port libre est trouvé")
	verifier(n.est_actif(), "le serveur écoute")
	n.arreter()
	verifier(not n.est_actif(), "arrêté")


# --- Fin de partie --------------------------------------------------------------------------


func test_la_fin_de_partie_rouvre_le_salon_sans_redemarrer() -> void:
	var n := _monter()
	verifier(_lancer_sur_port_libre(n) > 0, "port libre")
	var s := n.serveur
	s.emetteur = func(_p: int, _r: String, _o: PackedByteArray) -> void: pass
	s.pair_connecte(1)
	verifier(s.traiter_bonjour(1, _bonjour("Aki")), "un joueur entre")
	s.partie_terminee_serveur.emit()
	verifier(n.est_actif(), "le processus continue")
	verifier_egal(s.joueur_de(1), -1, "l'ancien joueur doit se réinscrire")
	verifier_egal(s.salon.joueurs.size(), 0, "salon vide")
	s.pair_connecte(2)
	verifier(s.traiter_bonjour(2, _bonjour("Bo")), "un nouveau joueur entre dans le nouveau salon")
	verifier_egal(s.salon.joueurs.size(), 1)


func test_avec_quitter_a_la_fin_le_processus_sort_avec_le_code_0() -> void:
	var n := _monter()
	var sorties: Array[int] = []
	n.sortie = func(code: int) -> void: sorties.append(code)
	verifier(_lancer_sur_port_libre(n, true) > 0, "port libre")
	n.serveur.partie_terminee_serveur.emit()
	verifier_egal(sorties.size(), 1, "une seule sortie")
	verifier_egal(sorties[0], 0)


func test_sans_quitter_a_la_fin_le_processus_reste_en_vie() -> void:
	var n := _monter()
	var sorties: Array[int] = []
	n.sortie = func(code: int) -> void: sorties.append(code)
	verifier(_lancer_sur_port_libre(n, false) > 0, "port libre")
	n.serveur.partie_terminee_serveur.emit()
	verifier_egal(sorties.size(), 0, "aucune sortie")
