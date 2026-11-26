extends CasDeTest
## Deux clients ENet voient le skin de tour l'un de l'autre (T11.5) : chacun le choisit au salon,
## le serveur le range avec le joueur au lancement et le diffuse dans l'état global.

const DELAI_MS := 6000
const ADRESSE := "127.0.0.1"
const GRAINE := 20261126

var _donnees: Donnees
var _sessions: Array[SessionReseau] = []


func avant_chaque() -> void:
	var brut := AidesPartie.brut()
	var skins: Dictionary = brut["skins_tour.json"]
	skins["essai_1"] = (skins["defaut"] as Dictionary).duplicate(true)
	skins["essai_2"] = (skins["defaut"] as Dictionary).duplicate(true)
	_donnees = Donnees.depuis_brut(brut)
	_sessions = []


func apres_chaque() -> void:
	for s: SessionReseau in _sessions:
		if is_instance_valid(s):
			s.fermer()
			s.get_parent().remove_child(s)
			s.queue_free()
	_sessions = []


func _port_libre(rng: RandomNumberGenerator) -> int:
	for i: int in 40:
		var p := rng.randi_range(20000, 60000)
		var essai := PacketPeerUDP.new()
		var ok := essai.bind(p, ADRESSE) == OK
		essai.close()
		if ok:
			return p
	return 0


func _jusqua(condition: Callable) -> bool:
	var fin := Time.get_ticks_msec() + DELAI_MS
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await arbre.process_frame
	return condition.call()


func _skin_vu(globales: Array[VueGlobale], id: int) -> int:
	if globales.is_empty():
		return -99
	for j: Dictionary in globales[globales.size() - 1].joueurs:
		if int(j["id"]) == id:
			return int(j["skin"])
	return -99


func _chacun_voit_l_autre(
	globales_h: Array[VueGlobale], globales_b: Array[VueGlobale], id_h: int, id_b: int
) -> bool:
	return _skin_vu(globales_h, id_b) == 2 and _skin_vu(globales_b, id_h) == 1


func test_deux_clients_voient_le_skin_l_un_de_l_autre() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE + OS.get_process_id()
	var port_jeu := _port_libre(rng)
	var port_udp := _port_libre(rng)
	verifier(port_jeu > 0 and port_udp > 0, "des ports libres")
	var hote := SessionReseau.new()
	arbre.root.add_child(hote)
	_sessions.append(hote)
	verifier_egal(hote.heberger(_donnees, port_jeu, "Salon", "Mina", port_udp, [ADRESSE]), OK)
	var autre := SessionReseau.new()
	arbre.root.add_child(autre)
	_sessions.append(autre)
	verifier_egal(autre.rejoindre(_donnees, ADRESSE, port_jeu, "Bo"), OK)
	var globales_h: Array[VueGlobale] = []
	var globales_b: Array[VueGlobale] = []
	hote.client.vue_globale_recue.connect(func(v: VueGlobale) -> void: globales_h.append(v))
	autre.client.vue_globale_recue.connect(func(v: VueGlobale) -> void: globales_b.append(v))
	verifier(
		await _jusqua(
			func() -> bool: return hote.client.id_local() > 0 and autre.client.id_local() > 0
		),
		"les deux ont un identifiant"
	)
	var id_h := hote.client.id_local()
	var id_b := autre.client.id_local()
	hote.client.definir_skin(1)
	autre.client.definir_skin(2)
	autre.client.pret(true)
	hote.client.regler_options(Salon.VITESSES[2], 0, false)
	await attendre_images(10)
	hote.client.lancer()
	var vus := _chacun_voit_l_autre.bind(globales_h, globales_b, id_h, id_b)
	verifier(await _jusqua(vus), "chacun voit le skin de l'autre")
	verifier_egal(_skin_vu(globales_h, id_h), 1, "l'hôte voit le sien")
	verifier_egal(_skin_vu(globales_b, id_b), 2, "la joueuse voit le sien")
