extends SceneTree
## Processus d'aide de `test_canal.gd` : un serveur et un client ENet dans CE processus, sur la
## boucle locale et un port libre trouvé à l'exécution. Le lanceur de tests tourne dans
## `_initialize`, où l'arbre n'est pas encore actif : les RPC exigent un nœud dans l'arbre, donc
## le scénario se déroule ici, image par image. Code de sortie 0 si tout est arrivé, 2 au délai
## maximal, 1 sur tout autre écart ; chaque écart est écrit sur la sortie standard.

const DELAI_MAX_MS: int = 5000
const ESSAIS_PORT: int = 40

var _etape: int = 0
var _fin: int = 0
var _api_serveur: SceneMultiplayer
var _api_client: SceneMultiplayer
var _canal_serveur: Canal
var _canal_client: Canal
var _recus: Dictionary = {}
var _attendus: Dictionary = {}
var _pair_client: int = 0
var _serveur_voit_client: bool = false


func _process(_delta: float) -> bool:
	if _fin == 0:
		_fin = Time.get_ticks_msec() + DELAI_MAX_MS
	if Time.get_ticks_msec() > _fin:
		var manquants: PackedStringArray = []
		for cle: String in _attendus:
			if (_recus[cle] as Array).is_empty():
				manquants.append(cle)
		return _sortir(
			2, "délai maximal dépassé à l'étape %d, manquants : %s" % [_etape, manquants]
		)
	match _etape:
		0:
			if not _monter():
				return _sortir(1, "aucun port libre")
			_etape = 1
		1:
			if _api_client.multiplayer_peer.get_connection_status() == 2 and _serveur_voit_client:
				_etape = 2
		2:
			_envoyer()
			_etape = 3
		3:
			if _tout_recu():
				return _sortir(_verifier(), "")
	return false


func _sortir(code: int, message: String) -> bool:
	if not message.is_empty():
		print("ECART : " + message)
	for api: SceneMultiplayer in [_api_serveur, _api_client]:
		if api != null and api.multiplayer_peer != null:
			api.multiplayer_peer.close()
	quit(code)
	return true


func _poser(nom: String, api: SceneMultiplayer) -> Canal:
	var racine := Node.new()
	racine.name = nom
	root.add_child(racine)
	set_multiplayer(api, racine.get_path())
	var canal := Canal.new()
	canal.name = "Canal"
	racine.add_child(canal)
	return canal


func _monter() -> bool:
	_api_serveur = SceneMultiplayer.new()
	_api_client = SceneMultiplayer.new()
	_canal_serveur = _poser("RacineServeur", _api_serveur)
	_canal_client = _poser("RacineClient", _api_client)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261125 + OS.get_process_id()
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
	for canal: Canal in [_canal_serveur, _canal_client]:
		var cote := "serveur" if canal == _canal_serveur else "client"
		for nom: String in [
			"bonjour_recu",
			"intention_recue",
			"etat_arene_recu",
			"etat_global_recu",
			"salon_recu",
			"refus_recu"
		]:
			var cle := cote + "." + nom
			_recus[cle] = []
			var s: Signal = canal.get(nom)
			s.connect(
				func(a: Variant = null, b: Variant = null) -> void:
					(_recus[cle] as Array).append([a, b])
			)
	return true


func _envoyer() -> void:
	_pair_client = _api_client.get_unique_id()
	var salon := Salon.new()
	salon.ajouter(_pair_client, "Zoë")
	_attendus = {
		"serveur.bonjour_recu": Protocole.encoder_bonjour("Éloïse", 42),
		"serveur.intention_recue": Protocole.encoder_intention(Protocole.Intention.PRET, 1),
		"client.salon_recu": salon.vers_octets(),
		"client.refus_recu": Protocole.encoder_refus(Protocole.motif_version(9)),
		"client.etat_global_recu": Protocole.encoder_etat_global(VueGlobale.new()),
		"client.etat_arene_recu": PackedByteArray([1, 2, 3, 4]),
	}
	_canal_client.rpc_id(1, "rpc_bonjour", _attendus["serveur.bonjour_recu"])
	_canal_client.rpc_id(1, "rpc_intention", _attendus["serveur.intention_recue"])
	_canal_serveur.rpc_id(_pair_client, "rpc_salon", _attendus["client.salon_recu"])
	_canal_serveur.rpc_id(_pair_client, "rpc_refus", _attendus["client.refus_recu"])
	_canal_serveur.rpc_id(_pair_client, "rpc_etat_global", _attendus["client.etat_global_recu"])
	_canal_serveur.rpc_id(_pair_client, "rpc_etat_arene", _attendus["client.etat_arene_recu"])


func _tout_recu() -> bool:
	for cle: String in _attendus:
		if (_recus[cle] as Array).is_empty():
			return false
	return true


func _verifier() -> int:
	var code := 0
	for cle: String in _attendus:
		var recus: Array = _recus[cle]
		var premier: Array = recus[0]
		var octets: PackedByteArray = premier[0] if cle.begins_with("client") else premier[1]
		if recus.size() != 1 or octets != _attendus[cle]:
			print("ECART : %s reçu %d fois ou octets altérés" % [cle, recus.size()])
			code = 1
	for cle: String in ["serveur.bonjour_recu", "serveur.intention_recue"]:
		var pair: int = (_recus[cle] as Array)[0][0]
		if pair != _pair_client or pair <= 1:
			print("ECART : expéditeur %d au lieu de %d pour %s" % [pair, _pair_client, cle])
			code = 1
	var salon := Salon.depuis_octets((_recus["client.salon_recu"] as Array)[0][0])
	if salon == null or not salon.joueurs.has(_pair_client):
		print("ECART : le salon reçu ne se décode pas")
		code = 1
	if code == 0:
		print("OK")
	return code
