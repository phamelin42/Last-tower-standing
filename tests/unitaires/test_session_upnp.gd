extends CasDeTest
## La redirection UPnP vue de la session : tentée à la création du salon sans jamais gêner le
## jeu en réseau local, refermée en quittant, refaite par « Retour au salon » (nouvelle session).

const TestUpnp := preload("res://tests/unitaires/test_upnp_hote.gd")
const DELAI_MS := 6000
const PORT_JEU := 7790

var _donnees: Donnees
var _sessions: Array[SessionReseau] = []
var _terminees: Array[int] = []


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_sessions = []
	_terminees = []
	delai_max = 30.0


func apres_chaque() -> void:
	for s: SessionReseau in _sessions:
		if is_instance_valid(s):
			s.fermer()
			s.get_parent().remove_child(s)
			s.queue_free()
	_sessions = []


func _session(box: UpnpHote.Passerelle) -> SessionReseau:
	var s := SessionReseau.new()
	s.fabrique_passerelle = func() -> UpnpHote.Passerelle: return box
	s.tentative_upnp_terminee.connect(func(p: int) -> void: _terminees.append(p))
	arbre.root.add_child(s)
	_sessions.append(s)
	return s


func _port_libre() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 40:
		var p := rng.randi_range(20000, 60000)
		var essai := PacketPeerUDP.new()
		var ok := essai.bind(p, SessionReseau.ADRESSE_LOCALE) == OK
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


func _heberger(s: SessionReseau, port: int) -> Error:
	# Découverte sur un port et une cible sans effet : le test ne diffuse rien sur le réseau.
	var cibles: Array[String] = []
	return s.heberger(_donnees, port, "Salon", "Alix", _port_libre(), cibles)


func test_creer_un_salon_ouvre_le_port_de_jeu_sans_attendre_la_box() -> void:
	var box := TestUpnp.Double.new()
	box.barrage = Semaphore.new()
	var s := _session(box)
	var port := _port_libre()
	verifier_egal(_heberger(s, port), OK, "le salon s'ouvre tout de suite")
	verifier(s.est_hote())
	verifier_egal(_terminees.size(), 0, "la box n'a pas encore répondu")
	box.barrage.post()
	verifier(await _jusqua(func() -> bool: return not _terminees.is_empty()))
	verifier_egal(_terminees, [port])
	verifier_egal(s.port_externe, port)


func test_echec_d_ouverture_laisse_le_salon_jouable_et_dit_zero() -> void:
	var box := TestUpnp.Double.new()
	box.resultat_decouverte = UPNP.UPNP_RESULT_NO_GATEWAY
	var s := _session(box)
	verifier_egal(_heberger(s, _port_libre()), OK)
	verifier(await _jusqua(func() -> bool: return not _terminees.is_empty()))
	verifier_egal(_terminees, [0])
	verifier_egal(s.port_externe, 0)
	verifier(s.est_hote() and s.est_ouverte(), "le salon local fonctionne toujours")


func test_fermer_la_session_referme_le_port_sans_fausse_alerte() -> void:
	var box := TestUpnp.Double.new()
	var s := _session(box)
	var port := _port_libre()
	_heberger(s, port)
	verifier(await _jusqua(func() -> bool: return not _terminees.is_empty()))
	s.fermer()
	s.fermer()
	verifier_egal(box.appels_suppression, [port])
	verifier_nul(s.upnp)
	verifier_egal(s.port_externe, 0)
	await attendre_images(3)
	verifier_egal(_terminees, [port], "quitter n'émet pas un échec")


func test_quitter_pendant_la_tentative_ne_laisse_rien_d_ouvert_ni_d_alerte() -> void:
	var box := TestUpnp.Double.new()
	box.barrage = Semaphore.new()
	var s := _session(box)
	_heberger(s, _port_libre())
	box.entree.wait()
	var liberateur := Thread.new()
	liberateur.start(
		func() -> void:
			OS.delay_msec(100)
			box.barrage.post()
	)
	s.fermer()
	liberateur.wait_to_finish()
	verifier_egal(box.appels_suppression.size(), box.appels_ajout.size())
	await attendre_images(3)
	verifier_egal(_terminees.size(), 0, "pas d'alerte d'échec pour un départ voulu")


func test_retour_au_salon_refait_la_redirection_avec_la_nouvelle_session() -> void:
	var port := _port_libre()
	var box_a := TestUpnp.Double.new()
	var a := _session(box_a)
	_heberger(a, port)
	verifier(await _jusqua(func() -> bool: return _terminees.size() == 1))
	# Ce que fait `Principal` : fermer la session, en créer une neuve, héberger de nouveau.
	a.fermer()
	var box_b := TestUpnp.Double.new()
	var b := _session(box_b)
	_heberger(b, port)
	verifier(await _jusqua(func() -> bool: return _terminees.size() == 2))
	verifier_egal(box_a.appels_suppression, [port], "l'ancienne redirection est fermée")
	verifier_egal(box_b.appels_ajout.size(), 1, "la nouvelle est ouverte")
	verifier_egal(_terminees, [port, port])


func test_heberger_deux_fois_dans_la_meme_session_ferme_l_ancienne_redirection() -> void:
	var box := TestUpnp.Double.new()
	var s := _session(box)
	var port := _port_libre()
	_heberger(s, port)
	verifier(await _jusqua(func() -> bool: return _terminees.size() == 1))
	_heberger(s, port)
	verifier(await _jusqua(func() -> bool: return _terminees.size() == 2))
	verifier_egal(box.appels_suppression, [port])


func test_rejoindre_ne_redirige_rien() -> void:
	var box := TestUpnp.Double.new()
	var s := _session(box)
	s.rejoindre(_donnees, "127.0.0.1", _port_libre(), "Alix")
	await attendre_images(3)
	verifier_nul(s.upnp)
	verifier_egal(box.appels_decouverte.size(), 0)


func test_salon_non_ouvert_ne_demande_rien_a_la_box() -> void:
	var box := TestUpnp.Double.new()
	var s := _session(box)
	var occupe := PacketPeerUDP.new()
	var port := _port_libre()
	verifier_egal(occupe.bind(port, "0.0.0.0"), OK)
	attendre_erreur("ENet host")
	var code := _heberger(s, port)
	occupe.close()
	verifier(code != OK, "le port est pris, le salon n'ouvre pas")
	await attendre_images(3)
	verifier_nul(s.upnp)
	verifier_egal(box.appels_decouverte.size(), 0)


func test_sans_passerelle_fournie_aucune_redirection_n_est_tentee() -> void:
	var s := SessionReseau.new()
	s.fabrique_passerelle = func() -> UpnpHote.Passerelle: return null
	arbre.root.add_child(s)
	_sessions.append(s)
	verifier_egal(_heberger(s, _port_libre()), OK)
	verifier_nul(s.upnp)
