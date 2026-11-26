extends CasDeTest
## L'annonce du salon public à l'annuaire, vue de la session de l'hôte (ADR 001, décisions 19 et
## 20) : elle ne part qu'une fois le client local enregistré comme hôte et la tentative UPnP
## terminée, déclare le port externe (sinon le port local), se répète, et se retire à la
## fermeture. Le service réel tourne sur la boucle locale avec une sonde simulée.

const TestServeur := preload("res://tests/unitaires/test_annuaire_serveur.gd")
const TestUpnp := preload("res://tests/unitaires/test_upnp_hote.gd")
const LOCAL := "127.0.0.1"
const DELAI_MS := 8000
const GRAINE := 20281125

var _donnees: Donnees
var _noeud: AnnuaireServeur = null
var _fausse: TestServeur.FausseSonde = null
var _port_annuaire: int = 0
var _sessions: Array[SessionReseau] = []


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_sessions = []
	delai_max = 30.0
	_fausse = TestServeur.FausseSonde.new()
	_noeud = AnnuaireServeur.new()
	_noeud.sonde = _fausse
	_noeud.journal = func(_t: String) -> void: pass
	_noeud.service.autoriser_prive = true
	arbre.root.add_child(_noeud)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE + OS.get_process_id()
	for i: int in 60:
		var p := rng.randi_range(20000, 60000)
		if _noeud.demarrer(p) == OK:
			_port_annuaire = p
			break


func apres_chaque() -> void:
	for s: SessionReseau in _sessions:
		if is_instance_valid(s):
			s.fermer()
			s.get_parent().remove_child(s)
			s.queue_free()
	_sessions = []
	if _noeud != null:
		_noeud.arreter()
		_noeud.free()
		_noeud = null


func _session(box: UpnpHote.Passerelle, publique: bool = true) -> SessionReseau:
	var s := SessionReseau.new()
	s.fabrique_passerelle = func() -> UpnpHote.Passerelle: return box
	s.annuaire_adresse = "%s:%d" % [LOCAL, _port_annuaire]
	s.salon_public = publique
	arbre.root.add_child(s)
	_sessions.append(s)
	return s


func _port_libre(autre_que: int = 0) -> int:
	var rng := RandomNumberGenerator.new()
	# Le numéro de processus change d'un lancement à l'autre : deux agents qui testent en même temps
	# ne visent pas les mêmes ports, et un échec se rejoue avec le même numéro.
	rng.seed = GRAINE + OS.get_process_id() + autre_que
	for i: int in 40:
		var p := rng.randi_range(20000, 60000)
		var essai := PacketPeerUDP.new()
		var ok := p != autre_que and essai.bind(p, LOCAL) == OK
		essai.close()
		if ok:
			return p
	return 0


func _jusqua(condition: Callable, delai_ms: int = DELAI_MS) -> bool:
	var fin := Time.get_ticks_msec() + delai_ms
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await arbre.process_frame
	return condition.call()


func _seul_salon(nom: String) -> bool:
	var salons := _noeud.service.salons()
	return salons.size() == 1 and salons[0]["nom"] == nom


func _heberger(s: SessionReseau, port: int, nom: String = "Salon") -> Error:
	var cibles: Array[String] = []
	return s.heberger(_donnees, port, nom, "Alix", _port_libre(port), cibles)


func test_l_annonce_attend_l_hote_et_la_fin_d_upnp_puis_declare_le_port_externe() -> void:
	var box := TestUpnp.Double.new()
	box.barrage = Semaphore.new()
	var s := _session(box)
	var enregistres: Array[int] = [0]
	s.hote_enregistre.connect(func() -> void: enregistres[0] += 1)
	var port := _port_libre()
	verifier_egal(_heberger(s, port), OK)
	verifier(await _jusqua(func() -> bool: return enregistres[0] == 1), "l'hôte est enregistré")
	await attendre_images(20)
	verifier_egal(_fausse.lancees.size(), 0, "rien ne part tant que la box n'a pas répondu")
	verifier_nul(s.annuaire, "aucun annonceur avant la fin d'UPnP")
	box.barrage.post()
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() == 1))
	verifier_egal(_fausse.lancees[0]["port"], s.port_externe)
	verifier_egal(s.port_externe, port, "la box a donné le port demandé")
	verifier_egal(enregistres[0], 1, "hote_enregistre n'est émis qu'une fois")


func test_un_port_externe_different_est_celui_que_l_on_declare() -> void:
	var box := TestUpnp.Double.new()
	box.reponses_ajout = [UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING]
	var s := _session(box)
	_heberger(s, _port_libre())
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() >= 1))
	verifier(s.port_externe >= 49152, "la box a donné un autre port")
	verifier_egal(_fausse.lancees[0]["port"], s.port_externe)
	verifier_different(_fausse.lancees[0]["port"], s.port)


func test_sans_upnp_on_declare_le_port_local() -> void:
	var box := TestUpnp.Double.new()
	box.resultat_decouverte = UPNP.UPNP_RESULT_NO_GATEWAY
	var s := _session(box)
	var port := _port_libre()
	_heberger(s, port)
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() >= 1))
	verifier_egal(s.port_externe, 0)
	verifier_egal(_fausse.lancees[0]["port"], port, "port local quand UPnP échoue")


func test_sans_passerelle_du_tout_l_annonce_part_quand_meme() -> void:
	var s := SessionReseau.new()
	s.fabrique_passerelle = func() -> UpnpHote.Passerelle: return null
	s.annuaire_adresse = "%s:%d" % [LOCAL, _port_annuaire]
	s.salon_public = true
	arbre.root.add_child(s)
	_sessions.append(s)
	var enregistres: Array[int] = [0]
	s.hote_enregistre.connect(func() -> void: enregistres[0] += 1)
	var port := _port_libre()
	_heberger(s, port)
	# Sans box, UPnP est « terminée » d'emblée : seule l'absence d'hôte enregistré retient encore
	# l'annonce (ADR, Rôle d'hôte, point 2), tant que le client local n'a pas dit bonjour.
	verifier_egal(enregistres[0], 0, "l'hôte n'est pas encore enregistré")
	verifier_nul(s.annuaire, "aucun annonceur avant l'hôte enregistré")
	verifier_egal(_fausse.lancees.size(), 0, "aucune annonce avant l'hôte enregistré")
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() >= 1))
	verifier_egal(enregistres[0], 1, "l'annonce n'est partie qu'une fois l'hôte enregistré")
	verifier_egal(_fausse.lancees[0]["port"], port)


func test_une_partie_non_publique_n_envoie_rien() -> void:
	var s := _session(TestUpnp.Double.new(), false)
	_heberger(s, _port_libre())
	verifier(await _jusqua(func() -> bool: return s.port_externe > 0))
	await attendre_images(30)
	verifier_egal(_fausse.lancees.size(), 0)
	verifier_egal(_noeud.nb_connexions(), 0)
	verifier_nul(s.annuaire)
	verifier_egal(_noeud.service.salons().size(), 0)


func test_un_annuaire_vide_dans_les_reglages_n_envoie_rien() -> void:
	var s := _session(TestUpnp.Double.new())
	s.annuaire_adresse = ""
	verifier_egal(_heberger(s, _port_libre()), OK)
	verifier(await _jusqua(func() -> bool: return s.port_externe > 0))
	await attendre_images(30)
	verifier_nul(s.annuaire)
	verifier_egal(_fausse.lancees.size(), 0)


func test_un_annuaire_invalide_dans_les_reglages_ne_gene_pas_le_salon() -> void:
	var s := _session(TestUpnp.Double.new())
	s.annuaire_adresse = "a:b:c"
	verifier_egal(_heberger(s, _port_libre()), OK)
	await attendre_images(30)
	verifier(s.est_hote() and s.est_ouverte())
	verifier_egal(_fausse.lancees.size(), 0)


func test_le_nombre_de_joueurs_annonce_suit_le_salon() -> void:
	var s := _session(TestUpnp.Double.new())
	_heberger(s, _port_libre())
	verifier(await _jusqua(func() -> bool: return s.annuaire != null))
	s.annuaire.periode_ms = 200
	s.annuaire.intervalle_min_ms = 0
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	var salon := _noeud.service.salons()[0]
	verifier_egal(salon["nom"], "Salon")
	verifier_egal(salon["joueurs"], 1)
	verifier_egal(salon["version_jeu"], Protocole.VERSION)
	verifier_egal(salon["max"], Salon.MAX_JOUEURS)


func test_le_serveur_nu_sans_client_local_n_annonce_jamais() -> void:
	# Une session qui rejoint un salon n'est pas hôte : aucun annonceur, même publique.
	var box := TestUpnp.Double.new()
	var hote := _session(box, false)
	var port := _port_libre()
	_heberger(hote, port)
	var invite := _session(box)
	var code := invite.rejoindre(_donnees, LOCAL, port, "Zoé")
	verifier_egal(code, OK)
	await attendre_images(30)
	verifier_nul(invite.annuaire)
	verifier_egal(_fausse.lancees.size(), 0)


func test_fermer_retire_le_salon_de_l_annuaire() -> void:
	var s := _session(TestUpnp.Double.new())
	_heberger(s, _port_libre())
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	s.fermer()
	verifier_nul(s.annuaire)
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().is_empty()))


func test_fermer_avant_la_fin_d_upnp_n_annonce_jamais() -> void:
	var box := TestUpnp.Double.new()
	box.barrage = Semaphore.new()
	var s := _session(box)
	_heberger(s, _port_libre())
	await attendre_images(10)
	s.fermer()
	box.barrage.post()
	await attendre_images(30)
	verifier_egal(_fausse.lancees.size(), 0)
	verifier_egal(_noeud.service.salons().size(), 0)


func test_retour_au_salon_nouvelle_session_nouvelle_annonce_sans_doublon() -> void:
	var port := _port_libre()
	var premiere := _session(TestUpnp.Double.new())
	_heberger(premiere, port)
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	premiere.fermer()
	var seconde := _session(TestUpnp.Double.new())
	_heberger(seconde, port, "Salon bis")
	verifier(
		await _jusqua(func() -> bool: return _seul_salon("Salon bis")), "un seul salon, le neuf"
	)
	await attendre_images(40)
	verifier_egal(_noeud.service.salons().size(), 1, "pas de doublon")
	verifier_non_nul(seconde.annuaire, "la seconde session a son propre annonceur")
	verifier_nul(premiere.annuaire, "la première n'annonce plus")


func test_fermer_pendant_une_annonce_en_cours_ne_laisse_aucun_salon() -> void:
	_fausse.automatique = false
	var s := _session(TestUpnp.Double.new())
	_heberger(s, _port_libre())
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() == 1))
	s.fermer()
	await attendre_images(10)
	_fausse.finir(1, true)
	await attendre_images(20)
	verifier_egal(_noeud.service.salons().size(), 0, "aucun salon fantôme")


## Les émissions de `tentative_upnp_terminee` d'une session, dans l'ordre.
func _ecouter_upnp(s: SessionReseau) -> Array[int]:
	var emis: Array[int] = []
	s.tentative_upnp_terminee.connect(func(p: int) -> void: emis.append(p))
	return emis


func _a_ete_annonce(port_annonce: int) -> bool:
	for lancee: Dictionary in _fausse.lancees:
		if lancee["port"] == port_annonce:
			return true
	return false


func _attendre_s(secondes: float) -> void:
	await arbre.create_timer(secondes).timeout


func test_le_delai_par_defaut_est_celui_de_phil() -> void:
	# Décision 21 (26/11/2026) : 10 s, ni plus ni moins.
	verifier_egal(SessionReseau.DELAI_UPNP_MAX_S, 10.0)
	var neuve := SessionReseau.new()
	verifier_egal(neuve.delai_upnp_max, 10.0, "une session neuve a le délai de Phil")
	neuve.free()


func test_une_box_qui_se_fige_n_empeche_pas_l_annonce_du_port_local() -> void:
	var box := TestUpnp.Double.new()
	box.barrage = Semaphore.new()
	var s := _session(box)
	s.delai_upnp_max = 0.5
	var emis := _ecouter_upnp(s)
	var port := _port_libre()
	_heberger(s, port)
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() >= 1))
	verifier_egal(_fausse.lancees[0]["port"], port, "port local : la box n'a pas répondu")
	verifier_egal(s.port_externe, 0)
	verifier_egal(emis, [0] as Array[int], "l'hôte est prévenu une fois que la box n'a rien ouvert")
	box.barrage.post()


func test_une_box_qui_repond_avant_le_delai_ne_change_rien() -> void:
	var box := TestUpnp.Double.new()
	box.barrage = Semaphore.new()
	var s := _session(box)
	s.delai_upnp_max = 1.0
	var emis := _ecouter_upnp(s)
	var port := _port_libre()
	_heberger(s, port)
	await attendre_images(20)
	verifier_egal(emis.size(), 0, "aucun échec annoncé avant la réponse de la box")
	box.barrage.post()
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() >= 1))
	verifier_egal(emis, [port] as Array[int], "seul le port obtenu est émis")
	verifier_egal(_fausse.lancees[0]["port"], port)
	await _attendre_s(1.3)
	verifier_egal(emis, [port] as Array[int], "l'échéance passée ne dit plus rien")


func test_fermer_avant_l_echeance_n_annonce_ni_n_emet_rien() -> void:
	var box := TestUpnp.Double.new()
	box.barrage = Semaphore.new()
	var s := _session(box)
	s.delai_upnp_max = 1.0
	var emis := _ecouter_upnp(s)
	_heberger(s, _port_libre())
	s.fermer()
	await _attendre_s(1.4)
	verifier_egal(emis.size(), 0, "aucun 0 émis après la fermeture")
	verifier_egal(_fausse.lancees.size(), 0, "rien n'est annoncé après la fermeture")
	box.barrage.post()


func test_heberger_a_nouveau_avant_l_echeance_ne_laisse_pas_le_decompte_de_la_premiere() -> void:
	var premiere := TestUpnp.Double.new()
	premiere.barrage = Semaphore.new()
	var seconde := TestUpnp.Double.new()
	seconde.barrage = Semaphore.new()
	var boites: Array[UpnpHote.Passerelle] = [premiere, seconde]
	var s := _session(premiere)
	s.fabrique_passerelle = func() -> UpnpHote.Passerelle:
		var b: UpnpHote.Passerelle = boites.pop_front()
		return b
	s.delai_upnp_max = 1.0
	var emis := _ecouter_upnp(s)
	_heberger(s, _port_libre())
	await _attendre_s(0.6)
	_heberger(s, _port_libre(), "Second")
	await _attendre_s(0.7)
	verifier_egal(emis.size(), 0, "l'échéance de la première tentative est morte avec elle")
	verifier_egal(_fausse.lancees.size(), 0, "rien n'est annoncé avant l'échéance de la seconde")
	verifier(await _jusqua(func() -> bool: return emis.size() == 1), "la seconde a son échéance")
	premiere.barrage.post()
	seconde.barrage.post()


func test_une_reussite_tardive_de_la_box_met_le_port_externe_dans_les_annonces_suivantes() -> void:
	var box := TestUpnp.Double.new()
	box.barrage = Semaphore.new()
	box.reponses_ajout = [UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING]
	var s := _session(box)
	s.delai_upnp_max = 0.5
	var emis := _ecouter_upnp(s)
	var port := _port_libre()
	_heberger(s, port)
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() == 1))
	verifier_egal(_fausse.lancees[0]["port"], port, "la première annonce part avec le port local")
	verifier_egal(emis, [0] as Array[int])
	# Deux appels à `ajouter` : le port demandé (conflit), puis un port tiré à l'exécution.
	box.barrage.post()
	box.barrage.post()
	verifier(await _jusqua(func() -> bool: return s.port_externe >= 49152))
	verifier_egal(emis.size(), 2, "la réussite tardive est dite à l'hôte")
	verifier_egal(emis[1], s.port_externe)
	s.annuaire.periode_ms = 200
	s.annuaire.intervalle_min_ms = 0
	verifier(
		await _jusqua(func() -> bool: return _a_ete_annonce(s.port_externe)),
		"une annonce suivante déclare le port externe obtenu en retard"
	)


func test_un_echec_tardif_ne_repete_pas_le_zero() -> void:
	var box := TestUpnp.Double.new()
	box.resultat_decouverte = UPNP.UPNP_RESULT_NO_GATEWAY
	box.barrage_decouverte = Semaphore.new()
	var s := _session(box)
	s.delai_upnp_max = 0.5
	var emis := _ecouter_upnp(s)
	_heberger(s, _port_libre())
	verifier(await _jusqua(func() -> bool: return emis.size() == 1))
	verifier_egal(emis, [0] as Array[int])
	box.barrage_decouverte.post()
	await _attendre_s(0.5)
	verifier_egal(emis, [0] as Array[int], "l'échec de la box n'émet pas un second 0")


func test_l_echeance_avant_l_enregistrement_de_l_hote_attend_l_hote_puis_annonce_le_port_local(
) -> void:
	var box := TestUpnp.Double.new()
	box.barrage = Semaphore.new()
	var s := _session(box)
	# Une échéance de 20 ms sonne bien avant l'aller-retour du client local vers le serveur.
	s.delai_upnp_max = 0.02
	var ordre: Array[String] = []
	s.tentative_upnp_terminee.connect(func(_p: int) -> void: ordre.append("upnp"))
	s.hote_enregistre.connect(func() -> void: ordre.append("hote"))
	var port := _port_libre()
	_heberger(s, port)
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() >= 1))
	verifier_egal(ordre, ["upnp", "hote"] as Array[String], "l'échéance a sonné avant l'hôte")
	verifier_egal(_fausse.lancees[0]["port"], port, "port local une fois l'hôte enregistré")
	box.barrage.post()


func test_une_partie_non_publique_dit_quand_meme_a_l_hote_que_la_box_n_a_pas_repondu() -> void:
	var box := TestUpnp.Double.new()
	box.barrage = Semaphore.new()
	var s := _session(box, false)
	s.delai_upnp_max = 0.3
	var emis := _ecouter_upnp(s)
	_heberger(s, _port_libre())
	verifier(await _jusqua(func() -> bool: return emis.size() == 1))
	verifier_egal(emis, [0] as Array[int])
	await attendre_images(30)
	verifier_nul(s.annuaire, "rien n'est annoncé pour une partie non publique")
	verifier_egal(_fausse.lancees.size(), 0)
	box.barrage.post()


func test_sans_passerelle_aucun_decompte_n_est_lance() -> void:
	var s := SessionReseau.new()
	s.fabrique_passerelle = func() -> UpnpHote.Passerelle: return null
	arbre.root.add_child(s)
	_sessions.append(s)
	_heberger(s, _port_libre())
	var timers: Array[Timer] = []
	for enfant: Node in s.get_children():
		if enfant is Timer:
			timers.append(enfant as Timer)
	verifier_egal(timers.size(), 0, "pas de box, pas d'échéance")
