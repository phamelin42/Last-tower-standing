extends CasDeTest
## Le client de l'annuaire (ADR 001) : annoncer un salon, le retirer, lister ceux des autres, et
## ne jamais gêner le jeu quand l'annuaire se tait, ment ou est d'une autre version. Le service
## réel (T7.1) tourne sur la boucle locale, sur un port tiré à l'exécution, avec une sonde
## simulée ; les réponses fautives viennent d'un faux annuaire qui sert des octets choisis.

const TestServeur := preload("res://tests/unitaires/test_annuaire_serveur.gd")
const LOCAL := "127.0.0.1"
const GRAINE_PORT := 20271125
const DELAI_MS := 5000
const NOM_24 := "ÉàüîÉàüîÉàüîÉàüîÉàüîÉàüî"

var _noeud: AnnuaireServeur = null
var _fausse: TestServeur.FausseSonde = null
var _port: int = 0
var _clients: Array[AnnuaireClient] = []
var _faux: FauxAnnuaire = null
var _resultats: Array = []


## Un annuaire qui accepte une connexion, lit ce qu'on lui envoie, puis sert `octets` tels quels et
## ferme (sauf `muet` : il ne répond jamais et garde la connexion).
class FauxAnnuaire:
	extends Node
	var serveur := TCPServer.new()
	var octets := PackedByteArray()
	var muet: bool = false
	var recus: Array[PackedByteArray] = []
	var _pairs: Array[StreamPeerTCP] = []
	var _servis: Dictionary = {}

	func ouvrir(port: int) -> Error:
		return serveur.listen(port, "127.0.0.1")

	func _process(_delta: float) -> void:
		if serveur.is_connection_available():
			_pairs.append(serveur.take_connection())
		for pair: StreamPeerTCP in _pairs:
			pair.poll()
			if pair.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				continue
			var n := pair.get_available_bytes()
			if n <= 0 or _servis.has(pair):
				continue
			recus.append(pair.get_data(n)[1])
			_servis[pair] = true
			if muet:
				continue
			pair.put_data(octets)
			pair.disconnect_from_host()

	func _exit_tree() -> void:
		for pair: StreamPeerTCP in _pairs:
			pair.disconnect_from_host()
		serveur.stop()


func avant_chaque() -> void:
	_noeud = null
	_fausse = null
	_faux = null
	_clients = []
	_resultats = []
	_port = 0
	delai_max = 30.0


func apres_chaque() -> void:
	for c: AnnuaireClient in _clients:
		if is_instance_valid(c):
			if c.get_parent() != null:
				c.get_parent().remove_child(c)
			c.free()
	_clients = []
	if _faux != null:
		_faux.get_parent().remove_child(_faux)
		_faux.free()
		_faux = null
	if _noeud != null:
		_noeud.arreter()
		_noeud.free()
		_noeud = null


# --- Aides -------------------------------------------------------------------------------------


func _annuaire() -> int:
	_fausse = TestServeur.FausseSonde.new()
	_noeud = AnnuaireServeur.new()
	_noeud.sonde = _fausse
	_noeud.journal = func(_t: String) -> void: pass
	_noeud.service.autoriser_prive = true
	arbre.root.add_child(_noeud)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE_PORT + OS.get_process_id()
	for i: int in 60:
		var port := rng.randi_range(20000, 60000)
		if _noeud.demarrer(port) == OK:
			_port = port
			return port
	return -1


func _faux_annuaire(octets: PackedByteArray, muet: bool = false) -> int:
	_faux = FauxAnnuaire.new()
	_faux.octets = octets
	_faux.muet = muet
	arbre.root.add_child(_faux)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE_PORT + OS.get_process_id() + 7
	for i: int in 60:
		var port := rng.randi_range(20000, 60000)
		if _faux.ouvrir(port) == OK:
			_port = port
			return port
	return -1


func _client(port: int) -> AnnuaireClient:
	var c := AnnuaireClient.new()
	c.adresse = "%s:%d" % [LOCAL, port]
	arbre.root.add_child(c)
	_clients.append(c)
	return c


func _jusqua(condition: Callable, delai_ms: int = DELAI_MS) -> bool:
	var fin := Time.get_ticks_msec() + delai_ms
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await arbre.process_frame
	return condition.call()


## Liste ce que voit un joueur, avec un client neuf. Renvoie `{etat, salons}`.
func _lister(c: AnnuaireClient) -> Dictionary:
	var recu: Array = []
	c.liste_terminee.connect(
		func(etat: int, salons: Array[Dictionary]) -> void: recu.append([etat, salons])
	)
	c.lister()
	if not await _jusqua(func() -> bool: return not recu.is_empty(), 12000):
		return {}
	return {"etat": recu[0][0], "salons": recu[0][1]}


func _joueurs_listes() -> int:
	var salons := _noeud.service.salons()
	return int(salons[0]["joueurs"]) if not salons.is_empty() else -1


func _fournisseur(nom: String, joueurs: int, port: int) -> Callable:
	return func() -> Dictionary: return {"nom": nom, "joueurs": joueurs, "max": 8, "port": port}


func _version_autre() -> PackedByteArray:
	# Le cadre d'une REPONSE d'une autre version d'annuaire, tel que le sert le service.
	return PackedByteArray(
		[5, 0, AnnuaireProtocole.MAGIE, AnnuaireProtocole.VERSION + 1, 0x81, 1, 2]
	)


# --- Adresse -----------------------------------------------------------------------------------


func test_adresse_valide_et_invalide_en_boucle() -> void:
	var bonnes := {
		"annuaire-lts.phamelin.fr:7779": ["annuaire-lts.phamelin.fr", 7779],
		"1.2.3.4:1": ["1.2.3.4", 1],
		"hote:65535": ["hote", 65535],
		"hote": ["hote", 7779],
		"  hote:80  ": ["hote", 80],
	}
	for brut: String in bonnes:
		var a := AnnuaireClient.analyser_adresse(brut)
		verifier_egal(a.get("hote"), bonnes[brut][0], brut)
		verifier_egal(a.get("port"), bonnes[brut][1], brut)
	var mauvaises: Array[String] = [
		"",
		"   ",
		":80",
		"hote:0",
		"hote:65536",
		"hote:abc",
		"a:b:c",
		"ho te:80",
		"hote:",
		"hote:-1",
		"hote:+80",
		"h\no:80",
		"ho" + char(1) + "te:80",
		"x".repeat(300) + ":80",
	]
	for brut: String in mauvaises:
		verifier(AnnuaireClient.analyser_adresse(brut).is_empty(), "« %s » refusée" % brut)


# --- Liste -------------------------------------------------------------------------------------


func test_liste_vide_d_un_annuaire_vide() -> void:
	var port := _annuaire()
	verifier(port > 0)
	var r := await _lister(_client(port))
	verifier_egal(r.get("etat"), AnnuaireClient.Etat.OK)
	verifier_egal((r["salons"] as Array).size(), 0)


func test_un_salon_annonce_apparait_dans_la_liste_avec_tous_ses_champs() -> void:
	var port := _annuaire()
	var hote := _client(port)
	hote.demarrer_annonce(_fournisseur(NOM_24, 3, 7777))
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	var r := await _lister(_client(port))
	verifier_egal(r.get("etat"), AnnuaireClient.Etat.OK)
	var salons: Array = r["salons"]
	verifier_egal(salons.size(), 1)
	var s: Dictionary = salons[0]
	verifier_egal(s["nom"], NOM_24)
	verifier_egal(NOM_24.length(), 24, "le nom d'essai fait 24 caractères")
	verifier_egal(s["joueurs"], 3)
	verifier_egal(s["max"], 8)
	verifier_egal(s["port"], 7777)
	verifier_egal(s["ip"], LOCAL)
	verifier_egal(s["version_jeu"], Protocole.VERSION)
	# La sonde vise l'adresse vue par le service et le port déclaré, rien d'autre.
	verifier_egal(_fausse.lancees[0]["port"], 7777)


func test_la_liste_au_maximum_de_cent_salons_arrive_en_entier() -> void:
	var salons: Array[Dictionary] = []
	for i: int in AnnuaireProtocole.MAX_SALONS:
		(
			salons
			. append(
				{
					"ip": "203.0.113.%d" % (i + 1),
					"port": 7777 + i,
					"version_jeu": Protocole.VERSION,
					"joueurs": i % 9 if i % 9 <= 8 else 0,
					"max": 8,
					"nom": "Salon %d" % i,
				}
			)
		)
	var port := _faux_annuaire(AnnuaireProtocole.encoder_salons(salons))
	var r := await _lister(_client(port))
	verifier_egal(r.get("etat"), AnnuaireClient.Etat.OK)
	verifier_egal((r["salons"] as Array).size(), 100)
	verifier_egal((r["salons"] as Array)[99]["nom"], "Salon 99")


# --- Liste : réponses fautives -----------------------------------------------------------------


func test_chaque_reponse_fautive_donne_indisponible_sans_exception() -> void:
	var valide := AnnuaireProtocole.encoder_salons(
		(
			[
				{
					"ip": "203.0.113.5",
					"port": 7777,
					"version_jeu": 4,
					"joueurs": 1,
					"max": 8,
					"nom": "Un"
				}
			]
			as Array[Dictionary]
		)
	)
	var grande := PackedByteArray(
		[0xFF, 0xFF, AnnuaireProtocole.MAGIE, AnnuaireProtocole.VERSION, 0x83]
	)
	grande.resize(20000)
	var cas := {
		"vide": PackedByteArray(),
		"tronquée en plein préfixe": valide.slice(0, 1),
		"tronquée dans l'en-tête": valide.slice(0, 4),
		"tronquée dans le corps": valide.slice(0, valide.size() - 3),
		"octets en trop": valide + PackedByteArray([1, 2, 3]),
		"magie fausse": PackedByteArray([5, 0, 0x42, 1, 0x81, 0, 1]),
		"taille annoncée trop grande": grande,
		"taille nulle": PackedByteArray([0, 0]),
		"type inconnu": PackedByteArray([3, 0, AnnuaireProtocole.MAGIE, 1, 0x55]),
		"du bruit": PackedByteArray([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x11, 0x22]),
	}
	for nom: String in cas:
		var port := _faux_annuaire(cas[nom])
		var c := _client(port)
		var r := await _lister(c)
		verifier_egal(r.get("etat"), AnnuaireClient.Etat.INDISPONIBLE, nom)
		verifier_egal((r.get("salons", [1]) as Array).size(), 0, nom)
		arbre.root.remove_child(_faux)
		_faux.free()
		_faux = null


func test_une_autre_version_d_annuaire_donne_incompatible() -> void:
	var port := _faux_annuaire(_version_autre())
	var r := await _lister(_client(port))
	verifier_egal(r.get("etat"), AnnuaireClient.Etat.INCOMPATIBLE)
	verifier_egal((r["salons"] as Array).size(), 0)


func test_une_autre_version_annoncee_en_grand_cadre_reste_incompatible() -> void:
	# Une version future peut changer la taille : la version se lit avant la taille.
	var cadre := PackedByteArray(
		[0xFF, 0xFF, AnnuaireProtocole.MAGIE, AnnuaireProtocole.VERSION + 1, 0x83]
	)
	var port := _faux_annuaire(cadre)
	var r := await _lister(_client(port))
	verifier_egal(r.get("etat"), AnnuaireClient.Etat.INCOMPATIBLE)


func test_un_annuaire_qui_ne_repond_jamais_est_abandonne_dans_le_delai() -> void:
	var port := _faux_annuaire(PackedByteArray(), true)
	var c := _client(port)
	c.delai_reponse_liste_ms = 400
	var debut := Time.get_ticks_msec()
	var r := await _lister(c)
	var duree := Time.get_ticks_msec() - debut
	verifier_egal(r.get("etat"), AnnuaireClient.Etat.INDISPONIBLE)
	verifier(duree >= 380 and duree < 3000, "abandonné après le délai (%d ms)" % duree)


func test_les_delais_par_defaut_sont_ceux_de_l_adr() -> void:
	var c := AnnuaireClient.new()
	verifier_egal(c.delai_connexion_ms, 3000)
	verifier_egal(c.delai_reponse_annonce_ms, 8000)
	verifier_egal(c.delai_reponse_liste_ms, 3000)
	verifier_egal(c.periode_ms, 10000)
	c.free()


func test_un_annuaire_injoignable_donne_indisponible() -> void:
	var port := _annuaire()
	_noeud.arreter()
	var r := await _lister(_client(port))
	verifier_egal(r.get("etat"), AnnuaireClient.Etat.INDISPONIBLE)


func test_un_annuaire_vide_ou_invalide_ne_connecte_rien() -> void:
	var port := _faux_annuaire(PackedByteArray())
	for adresse: String in ["", "   "]:
		var c := _client(port)
		c.adresse = adresse
		var r := await _lister(c)
		verifier_egal(r.get("etat"), AnnuaireClient.Etat.DESACTIVE, "« %s »" % adresse)
		c.demarrer_annonce(_fournisseur("Salon", 1, 7777))
	for adresse: String in ["hote:0", "a:b:c", ":"]:
		var c := _client(port)
		c.adresse = adresse
		var r := await _lister(c)
		verifier_egal(r.get("etat"), AnnuaireClient.Etat.INDISPONIBLE, adresse)
		c.demarrer_annonce(_fournisseur("Salon", 1, 7777))
	await attendre_images(10)
	verifier_egal(_faux.recus.size(), 0, "rien n'est parti vers l'annuaire")


func test_une_nouvelle_demande_remplace_la_precedente() -> void:
	var port := _faux_annuaire(PackedByteArray(), true)
	var c := _client(port)
	c.delai_reponse_liste_ms = 300
	c.intervalle_liste_ms = 0
	var recu: Array = []
	c.liste_terminee.connect(func(etat: int, _s: Array[Dictionary]) -> void: recu.append(etat))
	c.lister()
	await attendre_images(3)
	c.lister()
	verifier(await _jusqua(func() -> bool: return not recu.is_empty()))
	await attendre_images(5)
	verifier_egal(recu.size(), 1, "une seule réponse pour la dernière demande")


# --- Annonce -----------------------------------------------------------------------------------


func test_l_annonce_se_repete_et_suit_le_nombre_de_joueurs() -> void:
	var port := _annuaire()
	var etat: Array[int] = [1]
	var hote := _client(port)
	hote.periode_ms = 150
	hote.intervalle_min_ms = 0
	hote.demarrer_annonce(
		func() -> Dictionary: return {"nom": "Salon", "joueurs": etat[0], "max": 8, "port": 7777}
	)
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() >= 1))
	var avant := _fausse.lancees.size()
	verifier(await _jusqua(func() -> bool: return _joueurs_listes() == 1), "annoncé avec 1 joueur")
	etat[0] = 4
	verifier(
		await _jusqua(func() -> bool: return _joueurs_listes() == 4),
		"le changement arrive sans attendre la période suivante"
	)
	verifier(await _jusqua(func() -> bool: return hote.annonces_envoyees >= 3), "elle se répète")
	verifier_egal(_noeud.service.salons().size(), 1, "jamais de doublon")
	verifier(avant >= 1)


func test_pas_de_nouvelle_annonce_tant_que_la_precedente_attend_sa_reponse() -> void:
	var port := _faux_annuaire(PackedByteArray(), true)
	var hote := _client(port)
	hote.periode_ms = 50
	hote.intervalle_min_ms = 0
	hote.delai_reponse_annonce_ms = 600
	hote.demarrer_annonce(_fournisseur("Salon", 1, 7777))
	await attendre_images(20)
	verifier_egal(hote.annonces_envoyees, 1, "une seule annonce en attente")
	verifier(
		await _jusqua(func() -> bool: return hote.annonces_envoyees >= 2),
		"la suivante part après l'abandon de la première"
	)


func test_le_changement_de_joueurs_respecte_l_intervalle_minimal() -> void:
	var port := _annuaire()
	var etat: Array[int] = [1]
	var hote := _client(port)
	hote.intervalle_min_ms = 700
	hote.demarrer_annonce(
		func() -> Dictionary: return {"nom": "Salon", "joueurs": etat[0], "max": 8, "port": 7777}
	)
	verifier(await _jusqua(func() -> bool: return hote.annonces_envoyees == 1))
	etat[0] = 2
	await attendre_images(10)
	verifier_egal(hote.annonces_envoyees, 1, "pas plus vite que la limite de débit")
	verifier(await _jusqua(func() -> bool: return hote.annonces_envoyees == 2))


func test_une_annonce_sans_reponse_ou_invalide_ne_gele_rien_et_se_retente_a_la_periode() -> void:
	var cas: Array[Array] = [
		[PackedByteArray(), AnnuaireClient.Etat.INDISPONIBLE],
		[PackedByteArray([9, 9, 9]), AnnuaireClient.Etat.INDISPONIBLE],
		[_version_autre(), AnnuaireClient.Etat.INCOMPATIBLE],
	]
	for un_cas: Array in cas:
		var octets: PackedByteArray = un_cas[0]
		var attendu: int = un_cas[1]
		var port := _faux_annuaire(octets)
		var hote := _client(port)
		hote.periode_ms = 300
		hote.intervalle_min_ms = 0
		var etats: Array[int] = []
		hote.annonce_terminee.connect(func(e: int, _s: int) -> void: etats.append(e))
		hote.demarrer_annonce(_fournisseur("Salon", 1, 7777))
		verifier(await _jusqua(func() -> bool: return etats.size() >= 2), "retentée")
		for etat: int in etats:
			verifier_egal(etat, attendu, "chaque tentative donne le même état, jamais OK")
		arbre.root.remove_child(_faux)
		_faux.free()
		_faux = null


func test_une_autre_version_d_annuaire_se_signale_a_l_annonce() -> void:
	var port := _faux_annuaire(_version_autre())
	var hote := _client(port)
	var etats: Array[int] = []
	hote.annonce_terminee.connect(func(e: int, _s: int) -> void: etats.append(e))
	hote.demarrer_annonce(_fournisseur("Salon", 1, 7777))
	verifier(await _jusqua(func() -> bool: return not etats.is_empty()))
	verifier_egal(etats[0], AnnuaireClient.Etat.INCOMPATIBLE)


func test_le_statut_de_l_annuaire_est_rendu_a_l_hote() -> void:
	var port := _annuaire()
	_fausse.reussite = false
	var hote := _client(port)
	var recus: Array = []
	hote.annonce_terminee.connect(func(e: int, s: int) -> void: recus.append([e, s]))
	hote.demarrer_annonce(_fournisseur("Salon", 1, 7777))
	verifier(await _jusqua(func() -> bool: return not recus.is_empty()))
	verifier_egal(recus[0], [AnnuaireClient.Etat.OK, AnnuaireProtocole.Statut.INJOIGNABLE])
	verifier_egal(_noeud.service.salons().size(), 0, "un salon injoignable n'est pas listé")


func test_un_salon_hors_bornes_n_est_pas_envoye_et_ne_leve_rien() -> void:
	var port := _faux_annuaire(PackedByteArray())
	var hote := _client(port)
	hote.periode_ms = 100
	var fautifs: Array[Dictionary] = [
		{"nom": "", "joueurs": 1, "max": 8, "port": 7777},
		{"nom": "x".repeat(25), "joueurs": 1, "max": 8, "port": 7777},
		{"nom": "Salon", "joueurs": 9, "max": 8, "port": 7777},
		{"nom": "Salon", "joueurs": 1, "max": 8, "port": 80},
		{"nom": "Salon", "joueurs": 1, "max": 8, "port": 0},
		{"nom": "Salon", "joueurs": 1, "max": 8},
		{"nom": 12},
	]
	for f: Dictionary in fautifs:
		hote.demarrer_annonce(func() -> Dictionary: return f)
		await attendre_images(8)
	verifier_egal(_faux.recus.size(), 0, "rien d'invalide ne part")
	verifier_egal(hote.annonces_envoyees, 0)


# --- Retrait -----------------------------------------------------------------------------------


func test_retirer_et_quitter_envoie_le_retrait_puis_se_libere() -> void:
	var port := _annuaire()
	var hote := _client(port)
	hote.demarrer_annonce(_fournisseur("Salon", 2, 7777))
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	var ref: WeakRef = weakref(hote)
	hote.retirer_et_quitter()
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().is_empty()))
	verifier(await _jusqua(func() -> bool: return ref.get_ref() == null), "le client se libère")


func test_retirer_sans_avoir_annonce_ne_contacte_personne() -> void:
	var port := _faux_annuaire(PackedByteArray())
	var hote := _client(port)
	hote.retirer_et_quitter()
	await attendre_images(10)
	verifier_egal(_faux.recus.size(), 0)


func test_fermer_pendant_une_annonce_en_cours_retire_le_salon() -> void:
	var port := _annuaire()
	_fausse.automatique = false
	var hote := _client(port)
	hote.demarrer_annonce(_fournisseur("Salon", 2, 7777))
	verifier(await _jusqua(func() -> bool: return _fausse.lancees.size() == 1), "sonde lancée")
	hote.retirer_et_quitter()
	await attendre_images(10)
	_fausse.finir(1, true)
	await attendre_images(10)
	var r := await _lister(_client(port))
	verifier_egal(r.get("etat"), AnnuaireClient.Etat.OK)
	verifier_egal((r["salons"] as Array).size(), 0, "aucun salon fantôme après la fermeture")


func test_une_partie_lancee_retire_l_annonce_une_seule_fois() -> void:
	var port := _annuaire()
	var actif: Array[bool] = [true]
	var hote := _client(port)
	hote.periode_ms = 100
	hote.intervalle_min_ms = 0
	hote.demarrer_annonce(
		func() -> Dictionary:
			return {"nom": "Salon", "joueurs": 2, "max": 8, "port": 7777} if actif[0] else {}
	)
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	actif[0] = false
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().is_empty()))
	var n := hote.annonces_envoyees
	await attendre_images(30)
	verifier_egal(hote.annonces_envoyees, n, "plus d'annonce une fois la partie lancée")
	verifier_egal(_noeud.service.salons().size(), 0)


# --- Garde-fou d'actualisation ----------------------------------------------------------------


func test_deux_listes_a_moins_de_2_secondes_n_en_font_qu_une() -> void:
	var c := AnnuaireClient.new()
	verifier_egal(c.intervalle_liste_ms, 2000, "la limite du service est 1 liste par 2 s")
	c.free()
	var port := _annuaire()
	var client := _client(port)
	var recus: Array[int] = []
	client.liste_terminee.connect(
		func(etat: int, _s: Array[Dictionary]) -> void: recus.append(etat)
	)
	verifier(client.lister(), "la première demande part")
	for i: int in 6:
		verifier_faux(client.lister(), "la demande %d, trop proche, est ignorée" % (i + 2))
	verifier(await _jusqua(func() -> bool: return recus.size() == 1))
	await attendre_images(10)
	verifier_egal(recus, [AnnuaireClient.Etat.OK], "une seule réponse, aucune limite de débit")
	verifier_egal(_noeud.nb_connexions(), 0)


func test_une_liste_est_de_nouveau_permise_apres_l_intervalle() -> void:
	var port := _annuaire()
	var client := _client(port)
	client.intervalle_liste_ms = 250
	var recus: Array[int] = []
	client.liste_terminee.connect(
		func(etat: int, _s: Array[Dictionary]) -> void: recus.append(etat)
	)
	verifier(client.lister())
	verifier(await _jusqua(func() -> bool: return recus.size() == 1))
	verifier(await _jusqua(func() -> bool: return client.lister()), "permise après 250 ms")
	verifier(await _jusqua(func() -> bool: return recus.size() == 2))


func test_une_reponse_de_debit_a_une_liste_est_une_limite_pas_une_panne() -> void:
	var port := _faux_annuaire(AnnuaireProtocole.encoder_reponse(AnnuaireProtocole.Statut.DEBIT))
	var r := await _lister(_client(port))
	verifier_egal(r.get("etat"), AnnuaireClient.Etat.LIMITE)
	verifier_egal((r.get("salons", [1]) as Array).size(), 0)
