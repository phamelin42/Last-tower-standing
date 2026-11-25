extends CasDeTest
## Sonde de joignabilité réelle sur la boucle locale (un vrai `ENetMultiplayerPeer` répond), puis
## le nœud TCP de l'annuaire sur de vraies connexions de la boucle locale (la sonde est alors un
## double, sauf mention contraire). Chaque port est tiré à l'exécution : d'autres agents lancent
## leurs tests en même temps.

const GRAINE_PORT: int = 20261125
const ESSAIS_PORT: int = 60
const LOCAL: String = "127.0.0.1"
const SCENE_PRINCIPAL: String = "res://scenes/principal.tscn"

var _hote_enet: ENetMultiplayerPeer = null
var _t: Array[int] = [0]
var _noeud: AnnuaireServeur = null
var _fausse: FausseSonde = null
var _clients: Array[StreamPeerTCP] = []
var _sorties_journal: Array[String] = []
var _ip_source: Array[String] = [""]


## Sonde remplaçante : rend ses résultats quand le test le décide.
class FausseSonde:
	extends AnnuaireSonde
	var lancees: Array[Dictionary] = []
	var prets: Array[Dictionary] = []
	## Si vrai, chaque sonde aboutit (ou échoue selon `reussite`) dès son lancement.
	var automatique: bool = true
	var reussite: bool = true
	var _n: int = 0

	func _init() -> void:
		pass

	func demarrer(ip: String, port: int) -> int:
		_n += 1
		lancees.append({"ticket": _n, "ip": ip, "port": port})
		if automatique:
			prets.append({"ticket": _n, "ok": reussite})
		return _n

	func finir(ticket: int, ok: bool) -> void:
		prets.append({"ticket": ticket, "ok": ok})

	func sondes_finies() -> Array[Dictionary]:
		var rendu := prets.duplicate()
		prets.clear()
		var sortie: Array[Dictionary] = []
		for r: Dictionary in rendu:
			sortie.append(r)
		return sortie

	func nb_en_cours() -> int:
		return lancees.size()

	func annuler_tout() -> void:
		prets.clear()


func avant_chaque() -> void:
	_hote_enet = null
	_t[0] = 0


func apres_chaque() -> void:
	if _hote_enet != null:
		_hote_enet.close()
	_nettoyer_noeud()


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


# --- Nœud TCP ------------------------------------------------------------------------------------


func _monter(autoriser_prive: bool = true) -> AnnuaireServeur:
	_fausse = FausseSonde.new()
	_noeud = AnnuaireServeur.new()
	_noeud.horloge = func() -> int: return _t[0]
	_noeud.sonde = _fausse
	_noeud.journal = func(texte: String) -> void: _sorties_journal.append(texte)
	_noeud.service.autoriser_prive = autoriser_prive
	arbre.root.add_child(_noeud)
	return _noeud


## Ouvre le nœud sur un port libre de la boucle locale ; renvoie le port, -1 si aucun.
func _ouvrir_noeud() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE_PORT + OS.get_process_id() + 1
	for i: int in ESSAIS_PORT:
		var port := rng.randi_range(20000, 60000)
		if _noeud.demarrer(port) == OK:
			return port
	return -1


func _nettoyer_noeud() -> void:
	for c: StreamPeerTCP in _clients:
		c.disconnect_from_host()
	_clients.clear()
	if _noeud != null:
		_noeud.arreter()
		_noeud.free()
		_noeud = null


func _connecter(port: int) -> StreamPeerTCP:
	var c := StreamPeerTCP.new()
	_clients.append(c)
	c.connect_to_host(LOCAL, port)
	# Un délai réel, pas un nombre d'images : en tête de file d'attente du système, une connexion
	# peut mettre plus d'une seconde à s'établir.
	var limite := Time.get_ticks_msec() + 5_000
	while Time.get_ticks_msec() < limite:
		c.poll()
		if c.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		await arbre.process_frame
	return c


## Lit ce que le serveur envoie jusqu'à sa fermeture, ou `images` images. Avec `cadre_complet`,
## s'arrête dès qu'un cadre entier est là, comme le fait un vrai client (« lit, puis ferme »).
func _lire(c: StreamPeerTCP, images: int = 60, cadre_complet: bool = false) -> PackedByteArray:
	var tampon := PackedByteArray()
	for i: int in images:
		c.poll()
		if c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var n := c.get_available_bytes()
		if n > 0:
			tampon.append_array(c.get_data(n)[1])
		if (
			cadre_complet
			and tampon.size() >= 2
			and tampon.size() >= 2 + (tampon[0] | tampon[1] << 8)
		):
			break
		await arbre.process_frame
	return tampon


## Une connexion, un envoi, la lecture de la réponse complète.
func _requete(port: int, octets: PackedByteArray, images: int = 60) -> PackedByteArray:
	var c := await _connecter(port)
	c.put_data(octets)
	var tampon := await _lire(c, images, true)
	c.disconnect_from_host()
	return tampon


func _statut_de(octets: PackedByteArray) -> int:
	var d := AnnuaireProtocole.decoder_reponse(octets)
	return -1 if d.is_empty() else int(d["statut"])


func _annonce(port_jeu: int = 7777, nom: String = "Salon") -> PackedByteArray:
	return AnnuaireProtocole.encoder_annonce(2, 1, 8, port_jeu, nom)


func test_le_service_ecoute_explicitement_sur_0_0_0_0() -> void:
	verifier_egal(AnnuaireServeur.ADRESSE_ECOUTE, "0.0.0.0")
	_monter()
	var port := _ouvrir_noeud()
	verifier(port > 0, "un port libre")
	verifier(_noeud.est_actif())
	verifier_egal(_noeud.port_ecoute(), port)
	var c := await _connecter(port)
	verifier_egal(c.get_status(), StreamPeerTCP.STATUS_CONNECTED, "joignable par la boucle locale")
	_nettoyer_noeud()
	var jamais_ouvert := AnnuaireServeur.new()
	verifier_faux(jamais_ouvert.est_actif(), "un nœud neuf n'écoute pas")
	jamais_ouvert.free()


func test_une_annonce_acceptee_puis_une_liste_donnent_le_salon_avec_l_ip_vue() -> void:
	_monter()
	_ip_source[0] = "8.8.8.8"
	_noeud.source_adresse = func(_p: StreamPeerTCP) -> String: return _ip_source[0]
	var port := _ouvrir_noeud()
	var rep := await _requete(port, _annonce(7801, "Chez Aki"))
	verifier_egal(_statut_de(rep), 0)
	verifier_egal(_fausse.lancees.size(), 1, "une sonde")
	verifier_egal(_fausse.lancees[0]["ip"], "8.8.8.8", "la sonde vise l'IP vue, pas 127.0.0.1")
	verifier_egal(_fausse.lancees[0]["port"], 7801, "et le port déclaré")
	var liste := await _requete(port, AnnuaireProtocole.encoder_liste())
	var d := AnnuaireProtocole.decoder_salons(liste)
	verifier_egal((d["salons"] as Array).size(), 1)
	verifier_egal(d["salons"][0]["ip"], "8.8.8.8")
	verifier_egal(d["salons"][0]["port"], 7801)
	verifier_egal(d["salons"][0]["nom"], "Chez Aki")
	_nettoyer_noeud()


func test_une_ip_ipv4_mappee_est_listee_sous_son_ipv4() -> void:
	_monter(false)
	_noeud.source_adresse = func(_p: StreamPeerTCP) -> String: return "::ffff:93.184.216.34"
	var port := _ouvrir_noeud()
	verifier_egal(_statut_de(await _requete(port, _annonce())), 0)
	var d := AnnuaireProtocole.decoder_salons(
		await _requete(port, AnnuaireProtocole.encoder_liste())
	)
	verifier_egal(d["salons"][0]["ip"], "93.184.216.34")
	_nettoyer_noeud()


func test_une_adresse_de_boucle_locale_recoit_la_reponse_6_sans_option() -> void:
	_monter(false)
	var port := _ouvrir_noeud()
	verifier_egal(_statut_de(await _requete(port, _annonce())), 6)
	verifier(_fausse.lancees.is_empty(), "aucune sonde vers une adresse non publique")
	_nettoyer_noeud()


func test_la_reponse_attend_le_resultat_de_la_sonde() -> void:
	_monter()
	_fausse.automatique = false
	var port := _ouvrir_noeud()
	var c := await _connecter(port)
	c.put_data(_annonce())
	var tampon := await _lire(c, 15)
	verifier(tampon.is_empty(), "pas de réponse tant que la sonde court")
	verifier_egal(c.get_status(), StreamPeerTCP.STATUS_CONNECTED, "connexion tenue ouverte")
	_fausse.finir(1, false)
	tampon = await _lire(c, 60, true)
	verifier_egal(_statut_de(tampon), 2, "salon injoignable")
	_nettoyer_noeud()


func test_un_salon_joignable_apres_attente_est_liste() -> void:
	_monter()
	_fausse.automatique = false
	var port := _ouvrir_noeud()
	var c := await _connecter(port)
	c.put_data(_annonce(7802, "Tardif"))
	await _lire(c, 5)
	_fausse.finir(1, true)
	verifier_egal(_statut_de(await _lire(c, 60, true)), 0)
	var d := AnnuaireProtocole.decoder_salons(
		await _requete(port, AnnuaireProtocole.encoder_liste())
	)
	verifier_egal(d["salons"][0]["nom"], "Tardif")
	_nettoyer_noeud()


func test_une_autre_version_recoit_la_reponse_1_meme_avec_beaucoup_d_octets_en_trop() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var requete := PackedByteArray([0xE8, 0x03, 0x41, 2, 0x01])
	var reste := PackedByteArray()
	reste.resize(3000)
	requete.append_array(reste)
	var rep := await _requete(port, requete)
	verifier_egal(rep, PackedByteArray([5, 0, 0x41, 1, 0x81, 1, 1]), "réponse reçue en entier")
	_nettoyer_noeud()


func test_le_serveur_ferme_sans_rst_quand_le_client_n_a_pas_encore_lu() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var c := await _connecter(port)
	var requete := PackedByteArray([0xE8, 0x03, 0x41, 2, 0x01])
	var reste := PackedByteArray()
	reste.resize(3000)
	requete.append_array(reste)
	c.put_data(requete)
	for i: int in 10:
		await arbre.process_frame
	# Le délai de grâce passe pendant que le client ne lit pas : le serveur ferme le premier, avec
	# des octets du client encore non lus. Sans les avoir vidés, le RST ferait perdre la réponse.
	_t[0] += 1_000
	for i: int in 10:
		await arbre.process_frame
	var rep := await _lire(c, 30, true)
	verifier_egal(rep, PackedByteArray([5, 0, 0x41, 1, 0x81, 1, 1]), "réponse intacte")
	_nettoyer_noeud()


func test_une_liste_de_cent_salons_arrive_en_entier_chez_un_lecteur_lent() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var n := 0
	for i: int in 34:
		for k: int in 3:
			if n >= 100:
				break
			var ip := "8.9.%d.1" % i
			_noeud.source_adresse = func(_p: StreamPeerTCP) -> String: return ip
			verifier_egal(_statut_de(await _requete(port, _annonce(7000 + k, "😀".repeat(24)))), 0)
			n += 1
	_noeud.service.purger()
	var c := await _connecter(port)
	_noeud.source_adresse = func(_p: StreamPeerTCP) -> String: return "9.9.9.9"
	c.put_data(AnnuaireProtocole.encoder_liste())
	# Le lecteur ne lit qu'après plusieurs images : le serveur doit avoir tout écrit avant de fermer.
	for i: int in 20:
		await arbre.process_frame
	var tampon := await _lire(c, 60, true)
	var d := AnnuaireProtocole.decoder_salons(tampon)
	verifier_egal(tampon.size(), 2 + 10604, "cadre le plus grand")
	verifier_egal((d["salons"] as Array).size(), 100)
	_nettoyer_noeud()


func test_apres_la_reponse_le_serveur_ferme_une_connexion_qui_ne_part_pas() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var c := await _connecter(port)
	c.put_data(AnnuaireProtocole.encoder_liste())
	for i: int in 10:
		await arbre.process_frame
	verifier_egal(c.get_status(), StreamPeerTCP.STATUS_CONNECTED, "pas fermée avant la grâce")
	_t[0] += 1_000
	var tampon := await _lire(c, 30)
	verifier_egal(c.get_status(), StreamPeerTCP.STATUS_NONE, "fermée après 1 s de grâce")
	verifier(tampon.size() > 0)
	_nettoyer_noeud()


func test_une_connexion_muette_est_fermee_apres_3_secondes_sans_reponse() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var c := await _connecter(port)
	await arbre.process_frame
	await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 1)
	_t[0] += 2_999
	await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 1, "encore ouverte à 2,999 s")
	_t[0] += 1
	var tampon := await _lire(c, 30)
	verifier(tampon.is_empty(), "fermée sans réponse")
	verifier_egal(c.get_status(), StreamPeerTCP.STATUS_NONE)
	verifier_egal(_noeud.nb_connexions(), 0)
	_nettoyer_noeud()


func test_un_cadre_incomplet_est_ferme_a_3_secondes_sans_reponse() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var c := await _connecter(port)
	var cadre := _annonce()
	c.put_data(cadre.slice(0, cadre.size() - 1))
	await arbre.process_frame
	await arbre.process_frame
	_t[0] += 3_000
	var tampon := await _lire(c, 30)
	verifier(tampon.is_empty())
	verifier_egal(c.get_status(), StreamPeerTCP.STATUS_NONE)
	_nettoyer_noeud()


func test_la_cinquieme_connexion_d_une_meme_ip_est_fermee_sans_reponse() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var ouvertes: Array[StreamPeerTCP] = []
	for i: int in 4:
		ouvertes.append(await _connecter(port))
	for i: int in 5:
		await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 4)
	var cinq := await _connecter(port)
	cinq.put_data(AnnuaireProtocole.encoder_liste())
	var tampon := await _lire(cinq, 30)
	verifier(tampon.is_empty(), "aucune réponse")
	verifier(cinq.get_status() != StreamPeerTCP.STATUS_CONNECTED, "fermée par le service")
	verifier_egal(_noeud.nb_connexions(), 4)
	_nettoyer_noeud()


func test_un_flux_aleatoire_sur_de_vraies_connexions_laisse_le_service_intact() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE_PORT
	var compteur: Array[int] = [0]
	_noeud.source_adresse = func(_p: StreamPeerTCP) -> String:
		compteur[0] += 1
		return "8.%d.%d.1" % [compteur[0] / 200, compteur[0] % 200]
	for i: int in 60:
		var octets := PackedByteArray()
		octets.resize(rng.randi_range(0, 200))
		for k: int in octets.size():
			octets[k] = rng.randi_range(0, 255)
		var c := await _connecter(port)
		c.put_data(octets)
		await _lire(c, 4)
		c.disconnect_from_host()
	_t[0] += 10_000
	_noeud.source_adresse = func(_p: StreamPeerTCP) -> String: return "9.9.9.9"
	var d := AnnuaireProtocole.decoder_salons(
		await _requete(port, AnnuaireProtocole.encoder_liste())
	)
	verifier(not d.is_empty(), "le service répond encore à une liste valide")
	_nettoyer_noeud()


func test_le_journal_ne_donne_que_des_compteurs_agreges_sans_ip() -> void:
	_monter()
	_noeud.source_adresse = func(_p: StreamPeerTCP) -> String: return "93.184.216.34"
	var port := _ouvrir_noeud()
	await _requete(port, _annonce())
	await _requete(port, AnnuaireProtocole.encoder_liste())
	verifier(_sorties_journal.filter(func(l: String) -> bool: return "93.184" in l).is_empty())
	_t[0] += 59_999
	await _requete(port, _annonce())
	var avant := _sorties_journal.size()
	_t[0] += 1
	await arbre.process_frame
	verifier_egal(_sorties_journal.size(), avant + 1, "une ligne par minute")
	var ligne := _sorties_journal[_sorties_journal.size() - 1]
	verifier("1 salon" in ligne, ligne)
	verifier_faux("93.184" in ligne, "aucune IP : " + ligne)
	verifier_faux("127.0.0.1" in ligne)
	_nettoyer_noeud()


func test_arreter_libere_le_port_et_les_connexions() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var c := await _connecter(port)
	await arbre.process_frame
	await arbre.process_frame
	_noeud.arreter()
	verifier_faux(_noeud.est_actif())
	verifier_egal(_noeud.nb_connexions(), 0)
	var tampon := await _lire(c, 30)
	verifier(tampon.is_empty())
	verifier_egal(c.get_status(), StreamPeerTCP.STATUS_NONE)
	verifier_egal(_noeud.demarrer(port), OK, "le port est de nouveau libre")
	_nettoyer_noeud()


func test_un_port_occupe_ou_invalide_est_refuse_sans_exception() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var second := AnnuaireServeur.new()
	verifier(second.demarrer(port) != OK, "port occupé")
	verifier(second.demarrer(0) != OK, "port 0")
	verifier(second.demarrer(70000) != OK, "port hors bornes")
	second.free()
	_nettoyer_noeud()


# --- Bornes de ressources du nœud ----------------------------------------------------------------


func test_une_connexion_en_attente_de_sonde_est_fermee_a_7_secondes_sans_reponse() -> void:
	_monter()
	_fausse.automatique = false
	var port := _ouvrir_noeud()
	var c := await _connecter(port)
	c.put_data(_annonce())
	for i: int in 5:
		await arbre.process_frame
	_t[0] += 6_999
	await arbre.process_frame
	await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 1, "encore ouverte à 6,999 s")
	_t[0] += 1
	var tampon := await _lire(c, 30)
	verifier(tampon.is_empty(), "fermée sans réponse")
	verifier(c.get_status() != StreamPeerTCP.STATUS_CONNECTED)
	verifier_egal(_noeud.nb_connexions(), 0, "la place est rendue")
	_nettoyer_noeud()


func test_un_client_qui_ferme_pendant_la_sonde_rend_sa_place_et_l_entree_est_quand_meme_creee(
) -> void:
	_monter()
	_fausse.automatique = false
	var port := _ouvrir_noeud()
	var c := await _connecter(port)
	c.put_data(_annonce(7803, "Parti"))
	for i: int in 5:
		await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 1)
	c.disconnect_from_host()
	for i: int in 10:
		await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 0, "connexion fermée sans attendre la sonde")
	verifier_egal(_noeud.service.nb_sondes(), 1, "la sonde court toujours")
	_fausse.finir(1, true)
	for i: int in 3:
		await arbre.process_frame
	verifier_egal(_noeud.service.nb_sondes(), 0, "le résultat est reçu")
	verifier_egal(_noeud.service.nb_entrees(), 1, "l'entrée est créée, la réponse est perdue")
	_nettoyer_noeud()


func test_un_client_qui_ne_lit_pas_une_liste_ni_ne_ferme_rend_sa_place_apres_la_grace() -> void:
	_monter()
	var port := _ouvrir_noeud()
	for i: int in 34:
		for k: int in 3:
			if _noeud.service.nb_entrees() >= 100:
				break
			var ip := "8.9.%d.1" % i
			_noeud.source_adresse = func(_p: StreamPeerTCP) -> String: return ip
			await _requete(port, _annonce(7000 + k, "😀".repeat(24)))
	_noeud.source_adresse = func(_p: StreamPeerTCP) -> String: return "9.9.9.9"
	var c := await _connecter(port)
	c.put_data(AnnuaireProtocole.encoder_liste())
	for i: int in 10:
		await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 1, "ni lue ni fermée par le client")
	_t[0] += 7_000
	for i: int in 5:
		await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 0, "fermée par le service, sans attendre le client")
	_nettoyer_noeud()


func test_une_reponse_qui_ne_peut_pas_partir_est_abandonnee_a_7_secondes() -> void:
	_monter()
	# Le tampon d'envoi du pair est plein : aucun octet ne part (en boucle locale, le noyau
	# absorberait la réponse et l'état d'écriture ne durerait pas).
	_noeud.ecriture = func(_pair: StreamPeerTCP, _octets: PackedByteArray) -> Array: return [OK, 0]
	var port := _ouvrir_noeud()
	var c := await _connecter(port)
	c.put_data(AnnuaireProtocole.encoder_liste())
	for i: int in 10:
		await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 1, "réponse bloquée, connexion tenue")
	_t[0] += 1_000
	await arbre.process_frame
	await arbre.process_frame
	verifier_egal(
		_noeud.nb_connexions(), 1, "la grâce ne s'applique pas avant la fin de l'écriture"
	)
	_t[0] += 5_999
	await arbre.process_frame
	await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 1, "encore ouverte à 6,999 s")
	_t[0] += 1
	var tampon := await _lire(c, 30)
	verifier(tampon.is_empty(), "rien n'a pu être écrit")
	verifier(c.get_status() != StreamPeerTCP.STATUS_CONNECTED, "fermée par le service")
	verifier_egal(_noeud.nb_connexions(), 0, "la place est rendue à 7 s")
	_nettoyer_noeud()


func test_la_soixante_cinquieme_connexion_est_fermee_sans_reponse() -> void:
	_monter()
	var port := _ouvrir_noeud()
	var compteur: Array[int] = [0]
	_noeud.source_adresse = func(_p: StreamPeerTCP) -> String:
		compteur[0] += 1
		# 16 adresses, 4 connexions chacune : le plafond par IP n'est pas atteint.
		return "8.40.%d.1" % ((compteur[0] - 1) / 4)
	var ouvertes: Array[StreamPeerTCP] = []
	for i: int in 64:
		ouvertes.append(await _connecter(port))
	for i: int in 10:
		await arbre.process_frame
	verifier_egal(_noeud.nb_connexions(), 64, "64 connexions simultanées")
	var de_trop := await _connecter(port)
	de_trop.put_data(AnnuaireProtocole.encoder_liste())
	var tampon := await _lire(de_trop, 30)
	verifier(tampon.is_empty(), "aucune réponse")
	verifier(de_trop.get_status() != StreamPeerTCP.STATUS_CONNECTED, "fermée par le service")
	verifier_egal(_noeud.nb_connexions(), 64)
	_nettoyer_noeud()


# --- Lancement `--annuaire` ----------------------------------------------------------------------


func _port_libre_tcp() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE_PORT + OS.get_process_id() + 2
	for i: int in ESSAIS_PORT:
		var port := rng.randi_range(20000, 60000)
		var essai := TCPServer.new()
		if essai.listen(port, LOCAL) == OK:
			essai.stop()
			return port
	return -1


func test_les_options_de_l_annuaire_sont_lues_sans_message() -> void:
	var o := AnnuaireDedie.lire_options(PackedStringArray(["--annuaire"]))
	verifier(bool(o["annuaire"]))
	verifier_faux(bool(o["autoriser_prive"]))
	verifier_egal(int(o["port"]), 7779, "7779 par défaut, pas 7777")
	verifier_egal((o["messages"] as Array).size(), 0)
	var o2 := AnnuaireDedie.lire_options(
		PackedStringArray(["--annuaire", "--port", "8123", "--autoriser-prive"])
	)
	verifier_egal(int(o2["port"]), 8123)
	verifier(bool(o2["autoriser_prive"]))
	verifier((o2["messages"] as Array).is_empty())
	var o3 := AnnuaireDedie.lire_options(PackedStringArray(["--annuaire", "--port=8124"]))
	verifier_egal(int(o3["port"]), 8124)


func test_un_port_invalide_donne_le_defaut_de_l_annuaire_et_un_message() -> void:
	for valeur: String in ["0", "70000", "abc", "-5", ""]:
		var o := AnnuaireDedie.lire_options(PackedStringArray(["--annuaire", "--port", valeur]))
		verifier_egal(int(o["port"]), 7779, "port « %s »" % valeur)
		verifier_faux((o["messages"] as Array).is_empty(), "message pour « %s »" % valeur)


func test_sans_annuaire_les_options_du_jeu_sont_inchangees() -> void:
	var o := Arguments.lire(PackedStringArray(["--serveur", "--port", "8000"]))
	verifier_faux(bool(o["annuaire"]))
	verifier_faux(bool(o["autoriser_prive"]))
	verifier_egal(int(o["port"]), 8000)
	verifier_egal(int(Arguments.lire(PackedStringArray([]))["port"]), 7777)


func test_la_scene_de_demarrage_aiguille_chaque_mode() -> void:
	verifier_egal(Principal.scene_de_demarrage({"annuaire": true}), "res://scenes/annuaire.tscn")
	verifier_egal(Principal.scene_de_demarrage({"serveur": true}), "res://scenes/serveur.tscn")
	verifier_egal(Principal.scene_de_demarrage({}), "")
	verifier_egal(Principal.scene_de_demarrage({"annuaire": false, "serveur": false}), "")


func _lancer_dedie(args: PackedStringArray) -> Dictionary:
	var dedie := (load("res://scenes/annuaire.tscn") as PackedScene).instantiate() as AnnuaireDedie
	var sorties: Array[int] = []
	dedie.sortie = func(code: int) -> void: sorties.append(code)
	arbre.root.add_child(dedie)
	var code := dedie.lancer(AnnuaireDedie.lire_options(args))
	return {"dedie": dedie, "code": code, "sorties": sorties}


func test_l_annuaire_dedie_ecoute_sur_le_port_demande_et_s_arrete_proprement() -> void:
	var port := _port_libre_tcp()
	var r := _lancer_dedie(PackedStringArray(["--annuaire", "--port", str(port)]))
	var dedie := r["dedie"] as AnnuaireDedie
	verifier_egal(r["code"], 0)
	verifier(dedie.est_actif())
	var c := await _connecter(port)
	verifier_egal(c.get_status(), StreamPeerTCP.STATUS_CONNECTED)
	dedie.arreter()
	verifier_faux(dedie.est_actif())
	dedie.queue_free()


func test_un_port_pris_donne_le_code_3() -> void:
	var port := _port_libre_tcp()
	var occupant := TCPServer.new()
	verifier_egal(occupant.listen(port, LOCAL), OK)
	var r := _lancer_dedie(PackedStringArray(["--annuaire", "--port", str(port)]))
	verifier_egal(r["code"], 3, "port pris")
	verifier_faux((r["dedie"] as AnnuaireDedie).est_actif())
	occupant.stop()
	(r["dedie"] as AnnuaireDedie).queue_free()


func test_l_option_autoriser_prive_est_transmise_au_service() -> void:
	var port := _port_libre_tcp()
	var r := _lancer_dedie(PackedStringArray(["--annuaire", "--port", str(port)]))
	verifier_faux((r["dedie"] as AnnuaireDedie).serveur.service.autoriser_prive)
	(r["dedie"] as AnnuaireDedie).arreter()
	(r["dedie"] as AnnuaireDedie).queue_free()
	var port2 := _port_libre_tcp()
	var r2 := _lancer_dedie(
		PackedStringArray(["--annuaire", "--port", str(port2), "--autoriser-prive"])
	)
	verifier((r2["dedie"] as AnnuaireDedie).serveur.service.autoriser_prive)
	(r2["dedie"] as AnnuaireDedie).arreter()
	(r2["dedie"] as AnnuaireDedie).queue_free()


func _nouveau_principal() -> Principal:
	return (load(SCENE_PRINCIPAL) as PackedScene).instantiate() as Principal


func test_principal_avec_annuaire_lance_l_annuaire_a_la_place_du_menu() -> void:
	var port := _port_libre_tcp()
	var codes: Array[int] = []
	var p := _nouveau_principal()
	p.arguments = AnnuaireDedie.lire_options(PackedStringArray(["--annuaire", "--port", str(port)]))
	p.sortie = func(code: int) -> void: codes.append(code)
	arbre.root.add_child(p)
	var dedie: AnnuaireDedie = null
	for enfant: Node in p.get_children():
		if enfant is AnnuaireDedie:
			dedie = enfant as AnnuaireDedie
	verifier(dedie != null, "la scène de l'annuaire est ajoutée")
	if dedie != null:
		verifier(dedie.est_actif())
		dedie.arreter()
	verifier_nul(p.menu(), "le menu n'est pas chargé")
	verifier_egal(codes.size(), 0, "aucune sortie tant que l'annuaire tourne")
	p.get_parent().remove_child(p)
	p.queue_free()


func test_principal_sort_avec_le_code_3_quand_le_port_de_l_annuaire_est_pris() -> void:
	var port := _port_libre_tcp()
	var occupant := TCPServer.new()
	verifier_egal(occupant.listen(port, LOCAL), OK)
	var codes: Array[int] = []
	var p := _nouveau_principal()
	p.arguments = AnnuaireDedie.lire_options(PackedStringArray(["--annuaire", "--port", str(port)]))
	p.sortie = func(code: int) -> void: codes.append(code)
	arbre.root.add_child(p)
	verifier_egal(codes, [3] as Array[int])
	occupant.stop()
	p.get_parent().remove_child(p)
	p.queue_free()
