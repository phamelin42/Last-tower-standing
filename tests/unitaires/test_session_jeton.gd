extends CasDeTest
## Le jeton d'hôte vu de la session : tiré à chaque salon hébergé, remis au serveur et au client
## local (qui devient hôte), jamais gardé après la fermeture ni repris par « Retour au salon ».

const ADRESSE := "127.0.0.1"
const DELAI_MS := 6000

var _donnees: Donnees
var _sessions: Array[SessionReseau] = []
var _tirages: int = 0


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_sessions = []
	_tirages = 0
	delai_max = 30.0


func apres_chaque() -> void:
	for s: SessionReseau in _sessions:
		if is_instance_valid(s):
			s.fermer()
			s.get_parent().remove_child(s)
			s.queue_free()
	_sessions = []


func _session() -> SessionReseau:
	var s := SessionReseau.new()
	# Source maîtrisée : chaque tirage donne 8 octets différents et connus.
	s.source_octets = func(n: int) -> PackedByteArray:
		_tirages += 1
		var b := PackedByteArray()
		for i: int in n:
			b.append(_tirages * 10 + i)
		return b
	arbre.root.add_child(s)
	_sessions.append(s)
	return s


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
	return false


func _heberger(s: SessionReseau) -> Error:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7002 + OS.get_process_id() + _tirages
	return s.heberger(_donnees, _port_libre(rng), "Salon", "Mina", _port_libre(rng), [ADRESSE])


func test_le_jeton_par_defaut_a_huit_octets() -> void:
	var s := SessionReseau.new()
	var b: PackedByteArray = s.source_octets.call(Protocole.JETON_OCTETS)
	verifier_egal(b.size(), Protocole.JETON_OCTETS)
	s.free()


func test_le_client_local_du_salon_heberge_est_l_hote_grace_au_jeton() -> void:
	var s := _session()
	verifier_egal(_heberger(s), OK)
	verifier_egal(s.jeton_hote.size(), 8)
	verifier_egal(s.serveur.jeton_hote, s.jeton_hote, "le serveur reçoit le même jeton")
	verifier(
		await _jusqua(func() -> bool: return s.client.salon != null),
		"le client local reçoit le salon"
	)
	verifier(s.client.est_hote(), "le client local est l'hôte")
	verifier_egal(s.serveur.salon.hote, s.client.id_local())


func test_chaque_salon_a_un_jeton_neuf_et_la_fermeture_l_efface() -> void:
	var s := _session()
	verifier_egal(_heberger(s), OK)
	var premier := s.jeton_hote.duplicate()
	s.fermer()
	verifier_egal(s.jeton_hote, PackedByteArray(), "plus de jeton après la fermeture")
	verifier_egal(_heberger(s), OK)
	verifier_egal(s.jeton_hote.size(), 8)
	verifier(s.jeton_hote != premier, "le « Retour au salon » tire un nouveau jeton")
	verifier_egal(_tirages, 2)


func test_rejoindre_ne_porte_aucun_jeton() -> void:
	var s := _session()
	verifier_egal(s.rejoindre(_donnees, ADRESSE, 9, "Bo"), OK)
	verifier_egal(s.jeton_hote, PackedByteArray())
	verifier_egal(_tirages, 0)
