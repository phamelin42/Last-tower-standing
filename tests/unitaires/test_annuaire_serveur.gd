extends CasDeTest
## Sonde de joignabilité réelle sur la boucle locale (un vrai `ENetMultiplayerPeer` répond), puis
## le nœud TCP de l'annuaire (voir plus bas). Chaque port est tiré à l'exécution : d'autres agents
## lancent leurs tests en même temps.

const GRAINE_PORT: int = 20261125
const ESSAIS_PORT: int = 60
const LOCAL: String = "127.0.0.1"

var _hote_enet: ENetMultiplayerPeer = null
var _t: Array[int] = [0]


func avant_chaque() -> void:
	_hote_enet = null
	_t[0] = 0


func apres_chaque() -> void:
	if _hote_enet != null:
		_hote_enet.close()


# --- Aides -------------------------------------------------------------------------------------


## Un serveur ENet (celui du jeu) sur un port libre de la boucle locale ; renvoie son port.
func _ouvrir_serveur_enet() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE_PORT + OS.get_process_id()
	for i: int in ESSAIS_PORT:
		var port := rng.randi_range(20000, 60000)
		var essai := ENetMultiplayerPeer.new()
		if essai.create_server(port, 2) == OK:
			_hote_enet = essai
			return port
	return -1


func _sonde() -> AnnuaireSonde:
	var sonde := AnnuaireSonde.new()
	sonde.horloge = func() -> int: return _t[0]
	return sonde


## Fait avancer la sonde (et le serveur ENet, qui doit répondre à la poignée de main) jusqu'à ce
## qu'elle rende un résultat pour `ticket`, ou `images` images. Renvoie `{ticket, ok}` ou `{}`.
func _attendre(sonde: AnnuaireSonde, ticket: int, images: int = 120) -> Dictionary:
	for i: int in images:
		if _hote_enet != null:
			_hote_enet.poll()
		for fini: Dictionary in sonde.sondes_finies():
			if fini["ticket"] == ticket:
				return fini
		await arbre.process_frame
	return {}


# --- Sonde ENet ----------------------------------------------------------------------------------


func test_la_sonde_reussit_quand_un_serveur_enet_repond() -> void:
	var port := _ouvrir_serveur_enet()
	verifier(port > 0, "un port libre")
	var sonde := _sonde()
	var ticket := sonde.demarrer(LOCAL, port)
	verifier(ticket > 0)
	verifier_egal(sonde.nb_en_cours(), 1)
	var r := await _attendre(sonde, ticket)
	verifier_egal(r.get("ok"), true, "le serveur de jeu répond à la sonde")
	verifier_egal(sonde.nb_en_cours(), 0)


func test_la_sonde_coupe_la_connexion_et_ne_fait_entrer_personne_au_salon() -> void:
	var port := _ouvrir_serveur_enet()
	var connectes: Array[int] = []
	var deconnectes: Array[int] = []
	_hote_enet.peer_connected.connect(func(id: int) -> void: connectes.append(id))
	_hote_enet.peer_disconnected.connect(func(id: int) -> void: deconnectes.append(id))
	var sonde := _sonde()
	var ticket := sonde.demarrer(LOCAL, port)
	var r := await _attendre(sonde, ticket)
	verifier_egal(r.get("ok"), true)
	# Quelques tours pour que le serveur voie la déconnexion de la sonde.
	for i: int in 30:
		_hote_enet.poll()
		await arbre.process_frame
	# Vérifié à la relecture de l'ADR : le serveur d'ENet n'émet ni connexion ni départ pour elle.
	verifier_egal(connectes, [] as Array[int], "aucun pair ne s'est annoncé")
	verifier_egal(deconnectes, [] as Array[int], "aucun départ")


func test_la_sonde_echoue_au_bout_de_4_secondes_sans_reponse() -> void:
	var sonde := _sonde()
	# Aucun serveur n'écoute sur ce port : ENet ignore les erreurs ICMP et attend.
	var port := _ouvrir_serveur_enet()
	_hote_enet.close()
	_hote_enet = null
	var ticket := sonde.demarrer(LOCAL, port)
	verifier(ticket > 0)
	_t[0] = 3_999
	verifier(sonde.sondes_finies().is_empty(), "pas fini à 3,999 s")
	verifier_egal(sonde.nb_en_cours(), 1)
	_t[0] = 4_000
	var finies := sonde.sondes_finies()
	verifier_egal(finies.size(), 1)
	verifier_egal(finies[0]["ticket"], ticket)
	verifier_egal(finies[0]["ok"], false)
	verifier_egal(sonde.nb_en_cours(), 0)
	verifier(sonde.sondes_finies().is_empty(), "un résultat n'est rendu qu'une fois")


func test_quatre_sondes_simultanees_ont_chacune_leur_ticket_et_leur_resultat() -> void:
	var port := _ouvrir_serveur_enet()
	var sonde := _sonde()
	var tickets: Array[int] = []
	for i: int in 4:
		tickets.append(sonde.demarrer(LOCAL, port))
	verifier_egal(sonde.nb_en_cours(), 4)
	var distincts := {}
	for ticket: int in tickets:
		distincts[ticket] = true
	verifier_egal(distincts.size(), 4, "tickets distincts")
	var vus := {}
	for i: int in 200:
		_hote_enet.poll()
		for fini: Dictionary in sonde.sondes_finies():
			vus[fini["ticket"]] = fini["ok"]
		if vus.size() == 4:
			break
		await arbre.process_frame
	for ticket: int in tickets:
		verifier_egal(vus.get(ticket), true, "ticket %d" % ticket)


func test_annuler_tout_libere_les_sondes_sans_rien_rendre() -> void:
	var sonde := _sonde()
	for i: int in 3:
		sonde.demarrer(LOCAL, 20000 + i)
	sonde.annuler_tout()
	verifier_egal(sonde.nb_en_cours(), 0)
	_t[0] = 10_000
	verifier(sonde.sondes_finies().is_empty())


func test_une_cible_invalide_echoue_au_prochain_passage_sans_exception() -> void:
	var sonde := _sonde()
	var cibles: Array[Array] = [
		["pas une ip", 7777], ["", 7777], ["8.8.8.8", 0], ["8.8.8.8", 70000]
	]
	for cible: Array in cibles:
		var ticket := sonde.demarrer(str(cible[0]), int(cible[1]))
		var finies := sonde.sondes_finies()
		verifier_egal(finies.size(), 1, str(cible))
		verifier_egal(finies[0]["ticket"], ticket)
		verifier_egal(finies[0]["ok"], false, str(cible))
