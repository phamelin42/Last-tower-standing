extends CasDeTest
## Ce que le canal doit garantir de bout en bout : un client et un serveur ENet du même processus,
## sur la boucle locale et un port libre tiré à l'exécution, s'échangent chaque type de message
## avec les bons octets et le bon expéditeur.
##
## Le lanceur tourne avec l'arbre actif : chaque côté reçoit sa propre `SceneMultiplayer`, liée à
## son sous-arbre, et le test attend les paquets image par image sous un délai borné.

const ESSAIS_PORT: int = 40
const DELAI_ATTENTE_MS: int = 5000
const NOMS_SIGNAUX: Array[String] = [
	"bonjour_recu",
	"intention_recue",
	"etat_arene_recu",
	"etat_global_recu",
	"salon_recu",
	"refus_recu"
]

var _api_serveur: SceneMultiplayer
var _api_client: SceneMultiplayer
var _canal_serveur: Canal
var _canal_client: Canal
var _recus: Dictionary = {}
var _serveur_voit_client: bool = false


func apres_chaque() -> void:
	for api: SceneMultiplayer in [_api_serveur, _api_client]:
		if api != null and api.multiplayer_peer != null:
			api.multiplayer_peer.close()
			api.multiplayer_peer = null
	for canal: Canal in [_canal_serveur, _canal_client]:
		if canal != null:
			canal.get_parent().free()


func _poser(nom: String, api: SceneMultiplayer) -> Canal:
	var racine := Node.new()
	racine.name = nom
	arbre.root.add_child(racine)
	arbre.set_multiplayer(api, racine.get_path())
	var canal := Canal.new()
	canal.name = "Canal"
	racine.add_child(canal)
	return canal


func _ecouter(canal: Canal, cote: String) -> void:
	for nom: String in NOMS_SIGNAUX:
		var cle := cote + "." + nom
		_recus[cle] = []
		var s: Signal = canal.get(nom)
		s.connect(
			func(a: Variant = null, b: Variant = null) -> void:
				(_recus[cle] as Array).append([a, b])
		)


## Monte le serveur sur un port libre tiré à l'exécution ; faux si aucun des essais n'aboutit.
func _monter() -> bool:
	_api_serveur = SceneMultiplayer.new()
	_api_client = SceneMultiplayer.new()
	_canal_serveur = _poser("RacineServeur", _api_serveur)
	_canal_client = _poser("RacineClient", _api_client)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var port := -1
	for i: int in ESSAIS_PORT:
		var essai := rng.randi_range(20000, 60000)
		var pair := ENetMultiplayerPeer.new()
		if pair.create_server(essai, 8) == OK:
			_api_serveur.multiplayer_peer = pair
			port = essai
			break
	if port < 0:
		return false
	_api_serveur.peer_connected.connect(func(_id: int) -> void: _serveur_voit_client = true)
	var client := ENetMultiplayerPeer.new()
	if client.create_client("127.0.0.1", port) != OK:
		return false
	_api_client.multiplayer_peer = client
	_ecouter(_canal_serveur, "serveur")
	_ecouter(_canal_client, "client")
	return true


func _attendre(condition: Callable) -> bool:
	var fin := Time.get_ticks_msec() + DELAI_ATTENTE_MS
	while not condition.call() and Time.get_ticks_msec() < fin:
		await attendre_images(1)
	return condition.call()


func _manquants(attendus: Dictionary) -> PackedStringArray:
	var manquants: PackedStringArray = []
	for cle: String in attendus:
		if (_recus[cle] as Array).is_empty():
			manquants.append(cle)
	return manquants


func test_chaque_message_traverse_le_canal_avec_ses_octets_et_son_expediteur() -> void:
	verifier(_monter(), "un port libre a été trouvé et le client créé")
	var connecte: bool = await _attendre(
		func() -> bool:
			return (
				(
					_api_client.multiplayer_peer.get_connection_status()
					== MultiplayerPeer.CONNECTION_CONNECTED
				)
				and _serveur_voit_client
			)
	)
	verifier(connecte, "le client se connecte au serveur avant le délai")
	if not connecte:
		return
	var pair_client := _api_client.get_unique_id()
	var salon := Salon.new()
	salon.ajouter(pair_client, "Zoë")
	var attendus: Dictionary = {
		"serveur.bonjour_recu": Protocole.encoder_bonjour("Éloïse", 42),
		"serveur.intention_recue": Protocole.encoder_intention(Protocole.Intention.PRET, 1),
		"client.salon_recu": salon.vers_octets(),
		"client.refus_recu": Protocole.encoder_refus(Protocole.motif_version(9)),
		"client.etat_global_recu": Protocole.encoder_etat_global(VueGlobale.new()),
		"client.etat_arene_recu": PackedByteArray([1, 2, 3, 4]),
	}
	_canal_client.rpc_id(1, "rpc_bonjour", attendus["serveur.bonjour_recu"])
	_canal_client.rpc_id(1, "rpc_intention", attendus["serveur.intention_recue"])
	_canal_serveur.rpc_id(pair_client, "rpc_salon", attendus["client.salon_recu"])
	_canal_serveur.rpc_id(pair_client, "rpc_refus", attendus["client.refus_recu"])
	_canal_serveur.rpc_id(pair_client, "rpc_etat_global", attendus["client.etat_global_recu"])
	_canal_serveur.rpc_id(pair_client, "rpc_etat_arene", attendus["client.etat_arene_recu"])
	var tout_arrive: bool = await _attendre(func() -> bool: return _manquants(attendus).is_empty())
	verifier(tout_arrive, "chaque message arrive avant le délai : %s" % [_manquants(attendus)])
	for cle: String in attendus:
		var recus: Array = _recus[cle]
		verifier_egal(recus.size(), 1, "%s reçu exactement une fois" % cle)
		if recus.is_empty():
			continue
		var premier: Array = recus[0]
		var octets: PackedByteArray = premier[0] if cle.begins_with("client") else premier[1]
		verifier_egal(octets, attendus[cle], "%s garde ses octets" % cle)
	for cle: String in ["serveur.bonjour_recu", "serveur.intention_recue"]:
		var recus: Array = _recus[cle]
		if recus.is_empty():
			continue
		var pair: int = (recus[0] as Array)[0]
		verifier_egal(pair, pair_client, "l'expéditeur de %s est le client" % cle)
		verifier(pair > 1, "l'expéditeur n'est pas le serveur")
	var recus_salon: Array = _recus["client.salon_recu"]
	if not recus_salon.is_empty():
		var decode := Salon.depuis_octets((recus_salon[0] as Array)[0])
		verifier_non_nul(decode, "le salon reçu se décode")
		if decode != null:
			verifier(decode.joueurs.has(pair_client), "le salon reçu contient le client")
