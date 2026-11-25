extends CasDeTest
## L'ouverture du port par UPnP chez l'hôte, avec un double de la passerelle : jamais le vrai
## réseau. Le joueur doit obtenir un port ouvert quand la box l'accepte, un échec muet sinon,
## et un port refermé en partant.

const PORT_JEU := 7777
const IP_PUBLIQUE := "203.0.113.7"

var _hotes: Array[UpnpHote] = []
var _terminees: Array[int] = []


## Double de la box : les réponses d'`ajouter` sont jouées dans l'ordre, puis OK.
class Double:
	extends UpnpHote.Passerelle
	var resultat_decouverte: int = OK
	var ip: String = "203.0.113.7"
	var reponses_ajout: Array[int] = []
	var appels_decouverte: Array[int] = []
	var appels_ajout: Array[Dictionary] = []
	var appels_suppression: Array[int] = []
	## Si renseigné, `ajouter` attend ce sémaphore : une box qui répond lentement.
	var barrage: Semaphore = null
	## Posté dès que le fil est entré dans `ajouter` : le test sait que la box est « occupée ».
	var entree: Semaphore = Semaphore.new()
	## Si renseigné, `decouvrir` attend ce sémaphore : une box qui met du temps à répondre.
	var barrage_decouverte: Semaphore = null

	func decouvrir(delai_ms: int) -> int:
		appels_decouverte.append(delai_ms)
		if barrage_decouverte != null:
			entree.post()
			barrage_decouverte.wait()
		return resultat_decouverte

	func adresse_externe() -> String:
		return ip

	func ajouter(port_externe: int, port_interne: int, bail_s: int) -> int:
		if barrage != null:
			entree.post()
			barrage.wait()
		appels_ajout.append({"externe": port_externe, "interne": port_interne, "bail": bail_s})
		if reponses_ajout.is_empty():
			return OK
		return reponses_ajout.pop_front()

	func supprimer(port_externe: int) -> int:
		appels_suppression.append(port_externe)
		return OK


func avant_chaque() -> void:
	_hotes = []
	_terminees = []
	delai_max = 20.0


func apres_chaque() -> void:
	for h: UpnpHote in _hotes:
		if is_instance_valid(h):
			h.fermer()
			if h.get_parent() != null:
				h.get_parent().remove_child(h)
			h.queue_free()
	_hotes = []


func _hote(double: Double) -> UpnpHote:
	var h := UpnpHote.new()
	h.passerelle = double
	h.rng.seed = 42
	h.tentative_terminee.connect(func(p: int) -> void: _terminees.append(p))
	arbre.root.add_child(h)
	_hotes.append(h)
	return h


func _jusqua(condition: Callable, secondes: float = 5.0) -> bool:
	var fin := Time.get_ticks_msec() + int(secondes * 1000.0)
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await arbre.process_frame
	return false


func test_une_box_accommodante_ouvre_le_port_de_jeu_en_udp_avec_bail_fini() -> void:
	var box := Double.new()
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	verifier(await _jusqua(func() -> bool: return not _terminees.is_empty()))
	verifier_egal(_terminees, [PORT_JEU])
	verifier_egal(box.appels_decouverte, [2000])
	verifier_egal(box.appels_ajout, [{"externe": PORT_JEU, "interne": PORT_JEU, "bail": 3600}])
	verifier_egal(h.port_externe, PORT_JEU)


func _attendre_fin() -> bool:
	return await _jusqua(func() -> bool: return not _terminees.is_empty())


func test_aucune_passerelle_ne_bloque_pas_et_dit_zero() -> void:
	var box := Double.new()
	box.resultat_decouverte = UPNP.UPNP_RESULT_NO_GATEWAY
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	verifier_egal(_terminees, [0])
	verifier_egal(box.appels_ajout.size(), 0, "rien n'est ouvert sans passerelle")


func test_decouverte_sans_reponse_dans_les_2_s_est_un_echec() -> void:
	var box := Double.new()
	box.resultat_decouverte = UPNP.UPNP_RESULT_NO_DEVICES
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	verifier_egal(_terminees, [0])
	verifier_egal(box.appels_decouverte, [UpnpHote.DELAI_DECOUVERTE_MS])


func test_demarrer_rend_la_main_avant_la_fin_de_la_box() -> void:
	var box := Double.new()
	box.barrage = Semaphore.new()
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	verifier_egal(_terminees.size(), 0, "la tentative est encore en cours")
	await attendre_images(3)
	verifier_egal(_terminees.size(), 0, "l'interface a continué de tourner")
	box.barrage.post()
	verifier(await _attendre_fin())
	verifier_egal(_terminees, [PORT_JEU])


func test_adresse_externe_non_publique_est_un_echec_sans_rien_ouvrir() -> void:
	var privees: Array[String] = [
		"10.0.0.2",
		"192.168.1.20",
		"172.16.0.9",
		"172.31.255.1",
		"100.64.0.1",
		"100.127.1.1",
		"169.254.3.3",
		"127.0.0.1",
		"0.0.0.0",
		"0.1.2.3",
		"224.0.0.1",
		"255.255.255.255",
	]
	for ip: String in privees:
		var box := Double.new()
		box.ip = ip
		_terminees = []
		var h := _hote(box)
		h.demarrer(PORT_JEU)
		verifier(await _attendre_fin(), ip)
		verifier_egal(_terminees, [0], ip)
		verifier_egal(box.appels_ajout.size(), 0, ip)
		h.fermer()
	for ip: String in ["203.0.113.7", "172.15.0.1", "172.32.0.1", "100.63.0.1", "100.128.0.1"]:
		verifier_faux(UpnpHote.adresse_privee(ip), ip + " est publique")


func test_bail_refuse_repli_sur_bail_zero_qui_reussit() -> void:
	var box := Double.new()
	box.reponses_ajout = [UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED]
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	verifier_egal(_terminees, [PORT_JEU])
	verifier_egal(box.appels_ajout.map(func(a: Dictionary) -> int: return a["bail"]), [3600, 0])


func test_bail_refuse_puis_bail_zero_refuse_est_un_echec() -> void:
	var box := Double.new()
	box.reponses_ajout = [
		UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED, UPNP.UPNP_RESULT_ACTION_FAILED
	]
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	verifier_egal(_terminees, [0])
	h.fermer()
	verifier_egal(box.appels_suppression.size(), 0, "rien d'ouvert, rien à fermer")


func test_conflit_de_port_puis_second_essai_sur_port_aleatoire_reussit() -> void:
	var box := Double.new()
	box.reponses_ajout = [UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING]
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	verifier_egal(box.appels_ajout.size(), 2, "pas de repli bail 0 sur un conflit")
	var second: int = box.appels_ajout[1]["externe"]
	verifier(second >= 49152 and second <= 65535, "port aléatoire dans la plage : %d" % second)
	verifier_different(second, PORT_JEU)
	verifier_egal(box.appels_ajout[1]["interne"], PORT_JEU, "le port interne reste celui du jeu")
	verifier_egal(_terminees, [second], "l'annonce reçoit le port obtenu")
	h.fermer()
	verifier_egal(box.appels_suppression, [second])


func test_conflit_puis_second_conflit_est_un_echec_apres_deux_essais_seulement() -> void:
	var box := Double.new()
	box.reponses_ajout = [
		UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING,
		UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MECHANISM,
	]
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	verifier_egal(_terminees, [0])
	verifier_egal(box.appels_ajout.size(), 2)


func test_le_port_est_referme_en_partant_et_une_seule_fois() -> void:
	var box := Double.new()
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	h.fermer()
	h.fermer()
	verifier_egal(box.appels_suppression, [PORT_JEU])
	verifier_faux(h.fil_actif(), "aucun fil laissé ouvert")
	verifier_egal(h.port_externe, 0)
	verifier_egal(_terminees, [PORT_JEU], "pas de seconde émission à la fermeture")


func test_sortie_de_l_arbre_referme_le_port() -> void:
	var box := Double.new()
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	arbre.root.remove_child(h)
	verifier_egal(box.appels_suppression, [PORT_JEU])
	verifier_faux(h.fil_actif())


func test_fermeture_avant_la_fin_de_la_tentative_ne_laisse_aucun_port_ouvert() -> void:
	var box := Double.new()
	box.barrage = Semaphore.new()
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	box.entree.wait()
	# La box répond après la demande de fermeture : le fil termine, puis referme ce qu'il a ouvert.
	var liberateur := Thread.new()
	liberateur.start(
		func() -> void:
			OS.delay_msec(100)
			box.barrage.post()
	)
	h.fermer()
	liberateur.wait_to_finish()
	verifier_faux(h.fil_actif())
	verifier_egal(UpnpHote.fils_abandonnes(), 0)
	verifier_egal(box.appels_ajout.size(), 1)
	verifier_egal(
		box.appels_suppression,
		box.appels_ajout.map(func(a: Dictionary) -> int: return a["externe"]),
		"tout ce qui a été ouvert est refermé"
	)
	verifier_egal(_terminees, [0], "la tentative coupée dit 0, une seule fois")


func test_fermeture_pendant_la_decouverte_n_ouvre_aucun_port() -> void:
	var box := Double.new()
	box.barrage_decouverte = Semaphore.new()
	var h := _hote(box)
	h.demarrer(PORT_JEU)
	box.entree.wait()
	var liberateur := Thread.new()
	liberateur.start(
		func() -> void:
			OS.delay_msec(100)
			box.barrage_decouverte.post()
	)
	h.fermer()
	liberateur.wait_to_finish()
	verifier_egal(box.appels_ajout.size(), 0, "la box a répondu trop tard : rien n'est ouvert")
	verifier_egal(box.appels_suppression.size(), 0)
	verifier_egal(_terminees, [0])
	verifier_faux(h.fil_actif())


func test_fermeture_avant_le_premier_pas_du_fil_n_ouvre_rien() -> void:
	var box := Double.new()
	var h := _hote(box)
	h.fermer()
	h.demarrer(PORT_JEU)
	await attendre_images(2)
	verifier_egal(box.appels_ajout.size(), 0)
	verifier_faux(h.fil_actif())
	verifier_egal(_terminees, [0])


func test_une_box_qui_ne_repond_plus_a_la_fermeture_est_abandonnee_apres_le_delai() -> void:
	var box := Double.new()
	box.barrage = Semaphore.new()
	var h := _hote(box)
	h.delai_fermeture = 0.2
	h.demarrer(PORT_JEU)
	box.entree.wait()
	var debut := Time.get_ticks_msec()
	h.fermer()
	verifier(Time.get_ticks_msec() - debut < 1500, "la fermeture ne bloque pas indéfiniment")
	verifier_egal(UpnpHote.fils_abandonnes(), 1)
	box.barrage.post()
	var fini := await _jusqua(func() -> bool: return UpnpHote.fils_abandonnes() == 0)
	verifier(fini, "le fil abandonné finit seul une fois la box revenue")
	verifier_egal(_terminees, [0])


func test_le_bail_est_renouvele_y_compris_pendant_la_partie() -> void:
	var box := Double.new()
	var h := _hote(box)
	h.periode_renouvellement = 0.05
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	var assez := await _jusqua(func() -> bool: return box.appels_ajout.size() >= 3)
	verifier(assez, "au moins deux renouvellements")
	for appel: Dictionary in box.appels_ajout:
		verifier_egal(appel, {"externe": PORT_JEU, "interne": PORT_JEU, "bail": 3600})
	verifier_egal(
		_terminees, [PORT_JEU], "les renouvellements n'émettent pas de nouvelle tentative"
	)


func test_periode_de_renouvellement_par_defaut_est_de_1800_s_pour_un_bail_de_3600_s() -> void:
	verifier_egal(UpnpHote.PERIODE_RENOUVELLEMENT_S, 1800.0)
	verifier_egal(UpnpHote.BAIL_S, 3600)
	var h := UpnpHote.new()
	verifier_egal(h.periode_renouvellement, 1800.0)
	h.free()


func test_bail_permanent_n_est_pas_renouvele() -> void:
	var box := Double.new()
	box.reponses_ajout = [UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED]
	var h := _hote(box)
	h.periode_renouvellement = 0.02
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	await attendre_images(20)
	verifier_egal(box.appels_ajout.size(), 2, "bail 0 : rien à renouveler")


func test_renouvellement_qui_echoue_en_pleine_partie_laisse_le_jeu_continuer() -> void:
	var box := Double.new()
	var h := _hote(box)
	var echecs: Array[int] = [0]
	h.renouvellement_echoue.connect(func() -> void: echecs[0] += 1)
	h.periode_renouvellement = 0.05
	h.demarrer(PORT_JEU)
	verifier(await _attendre_fin())
	box.reponses_ajout = [UPNP.UPNP_RESULT_ACTION_FAILED]
	verifier(await _jusqua(func() -> bool: return echecs[0] >= 1))
	verifier_egal(_terminees, [PORT_JEU], "aucune nouvelle émission")
	verifier(h.fil_actif(), "le fil reste là pour la fermeture")
	h.fermer()
	verifier_egal(box.appels_suppression, [PORT_JEU], "la fermeture referme quand même")


func test_chaque_tentative_emet_une_seule_fois_en_boucle_sur_tous_les_scenarios() -> void:
	var scenarios: Array[Dictionary] = [
		{"nom": "succès", "ajouts": [], "decouverte": OK, "attendu": PORT_JEU},
		{
			"nom": "aucune box",
			"ajouts": [],
			"decouverte": UPNP.UPNP_RESULT_NO_GATEWAY,
			"attendu": 0
		},
		{
			"nom": "bail 0",
			"ajouts": [UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED],
			"decouverte": OK,
			"attendu": PORT_JEU,
		},
		{
			"nom": "refus total",
			"ajouts": [UPNP.UPNP_RESULT_ACTION_FAILED, UPNP.UPNP_RESULT_ACTION_FAILED],
			"decouverte": OK,
			"attendu": 0,
		},
	]
	for sc: Dictionary in scenarios:
		var box := Double.new()
		box.resultat_decouverte = sc["decouverte"]
		var ajouts: Array[int] = []
		ajouts.assign(sc["ajouts"])
		box.reponses_ajout = ajouts
		_terminees = []
		var h := _hote(box)
		h.demarrer(PORT_JEU)
		verifier(await _attendre_fin(), sc["nom"])
		await attendre_images(5)
		h.fermer()
		await attendre_images(2)
		verifier_egal(_terminees, [sc["attendu"]], sc["nom"])
		verifier_faux(h.fil_actif(), sc["nom"])


func test_noeud_libere_apres_l_abandon_le_fil_finit_et_referme_ce_qu_il_a_ouvert() -> void:
	var box := Double.new()
	box.barrage = Semaphore.new()
	var h := _hote(box)
	h.delai_fermeture = 0.1
	h.demarrer(PORT_JEU)
	box.entree.wait()
	h.fermer()
	verifier_egal(UpnpHote.fils_abandonnes(), 1, "le fil est abandonné, la box est lente")
	# Ce que fait la session juste après `fermer` : le nœud disparaît, le fil tourne encore.
	arbre.root.remove_child(h)
	h.free()
	box.barrage.post()
	var fini := await _jusqua(func() -> bool: return UpnpHote.fils_abandonnes() == 0)
	verifier(fini, "le fil abandonné se termine proprement")
	verifier_egal(box.appels_suppression, [PORT_JEU], "la redirection ouverte tard est refermée")
