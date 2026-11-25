extends CasDeTest
## Le serveur avec de vrais sockets ENet sur la boucle locale, serveur et clients dans CE
## processus (un `SceneMultiplayer` par côté, sur un port tiré à l'exécution) : une partie réelle
## de bout en bout, puis l'usurpation, qu'un client ne doit pas pouvoir réussir : parler au nom d'un
## autre, appeler un RPC réservé au serveur, en forger un vers un autre client.

const DELAI_MS: int = 8000

var d: Donnees
var serveur: Serveur
var api_serveur: SceneMultiplayer
var clients: Array[Cli] = []
var port: int = 0


class Cli:
	extends RefCounted
	var api: SceneMultiplayer
	var canal: Canal
	var pair: ENetMultiplayerPeer
	var _id: int = 0
	var salons: Array[PackedByteArray] = []
	var arenes: Array[PackedByteArray] = []
	var globaux: Array[PackedByteArray] = []
	var refus: Array[PackedByteArray] = []

	func id() -> int:
		if _id == 0 and pair.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_id = api.get_unique_id()
		return _id

	func connecte() -> bool:
		return pair.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

	func dernier_salon() -> Salon:
		return Salon.depuis_octets(salons[salons.size() - 1]) if not salons.is_empty() else null


func avant_chaque() -> void:
	d = Donnees.charger()
	clients = []
	serveur = null
	delai_max = 25.0


func apres_chaque() -> void:
	for c: Cli in clients:
		c.pair.close()
	if serveur != null:
		serveur.arreter()
	if api_serveur != null:
		api_serveur.multiplayer_peer = null


# --- Aides -----------------------------------------------------------------------------------


func _racine(nom: String, api: SceneMultiplayer) -> Canal:
	var racine := Node.new()
	racine.name = nom
	arbre.root.add_child(racine)
	arbre.set_multiplayer(api, racine.get_path())
	var canal := Canal.new()
	canal.name = "Canal"
	racine.add_child(canal)
	return canal


func _monter_serveur() -> bool:
	api_serveur = SceneMultiplayer.new()
	var canal := _racine("RacineServeur", api_serveur)
	serveur = Serveur.new()
	serveur.name = "Serveur"
	canal.add_child(serveur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261125 + OS.get_process_id()
	for i: int in 40:
		port = rng.randi_range(20000, 60000)
		if serveur.demarrer(d, port) == OK:
			return true
	return false


func _ajouter_client(nom: String) -> Cli:
	var c := Cli.new()
	c.api = SceneMultiplayer.new()
	c.canal = _racine("Racine" + nom, c.api)
	c.canal.salon_recu.connect(func(o: PackedByteArray) -> void: c.salons.append(o))
	c.canal.etat_arene_recu.connect(func(o: PackedByteArray) -> void: c.arenes.append(o))
	c.canal.etat_global_recu.connect(func(o: PackedByteArray) -> void: c.globaux.append(o))
	c.canal.refus_recu.connect(func(o: PackedByteArray) -> void: c.refus.append(o))
	c.pair = ENetMultiplayerPeer.new()
	c.pair.create_client("127.0.0.1", port)
	c.api.multiplayer_peer = c.pair
	clients.append(c)
	return c


func _jusqua(condition: Callable) -> bool:
	var fin := Time.get_ticks_msec() + DELAI_MS
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await arbre.process_frame
	return false


func _dire_bonjour(c: Cli, nom: String) -> void:
	c.canal.rpc_id(1, "rpc_bonjour", Protocole.encoder_bonjour(nom, d.empreinte))


func _intention(c: Cli, genre: int, arg: int = 0, texte: String = "") -> void:
	c.canal.rpc_id(1, "rpc_intention", Protocole.encoder_intention(genre, arg, texte))


## Deux clients connectés, annoncés, prêts, partie démarrée.
func _partie_a_deux() -> Array[Cli]:
	verifier(_monter_serveur(), "un port libre pour le serveur")
	var a := _ajouter_client("A")
	var b := _ajouter_client("B")
	verifier(await _jusqua(func() -> bool: return a.connecte() and b.connecte()), "connexion")
	_dire_bonjour(a, "Aki")
	await _jusqua(func() -> bool: return serveur.joueur_de(a.id()) == a.id())
	_dire_bonjour(b, "Bo")
	verifier(
		await _jusqua(func() -> bool: return serveur.joueur_de(b.id()) == b.id()), "deux joueurs"
	)
	a.canal.rpc_id(1, "rpc_intention", Serveur.encoder_options(1.0, 777, true))
	_intention(a, Protocole.Intention.PRET, 1)
	_intention(b, Protocole.Intention.PRET, 1)
	verifier(await _jusqua(func() -> bool: return serveur.partie != null), "la partie démarre")
	return [a, b]


func _argent(joueur: int) -> int:
	return serveur.partie.vue_arene(joueur, joueur).argent


func _salon_lance(c: Cli) -> bool:
	var s := c.dernier_salon()
	return s != null and s.lancee and s.joueurs.size() == 2


func _achat_visible(c: Cli) -> bool:
	var v := _arene_recue(c, c.arenes.size() - 1)
	return v != null and v.armes.size() + v.ameliorations.size() >= 1


func _arene_recue(c: Cli, i: int) -> VueArene:
	return Protocole.decoder_etat_arene(c.arenes[i], d.ids_catalogue)


# --- Une partie réelle -----------------------------------------------------------------------


func test_une_partie_reelle_salon_etats_achat_et_depart_brutal() -> void:
	var cs := await _partie_a_deux()
	var a := cs[0]
	var b := cs[1]
	verifier(await _jusqua(_salon_lance.bind(a)), "A reçoit le salon complet puis lancé")
	verifier(
		await _jusqua(func() -> bool: return a.arenes.size() >= 4 and a.globaux.size() >= 1),
		"A reçoit des états d'arène et un état global"
	)
	var ticks: Array[int] = []
	for i: int in a.arenes.size():
		var v := _arene_recue(a, i)
		verifier_non_nul(v, "état %d décodable" % i)
		ticks.append(v.tick)
	for i: int in range(1, ticks.size()):
		verifier(ticks[i] > ticks[i - 1], "ticks croissants : %s" % [ticks])
	verifier_non_nul(Protocole.decoder_etat_global(a.globaux[0]))
	# A achète : seul A est débité, et l'état reçu par A le montre.
	var avant_a := _argent(a.id())
	var avant_b := _argent(b.id())
	var offres := _arene_recue(a, a.arenes.size() - 1).offres
	var cible := -1
	for i: int in offres.size():
		if int((offres[i] as Dictionary)["prix"]) <= avant_a:
			cible = i
			break
	verifier(cible >= 0, "une offre abordable")
	_intention(a, Protocole.Intention.ACHETER, cible)
	verifier(await _jusqua(_achat_visible.bind(a)), "A voit son achat dans l'état reçu")
	verifier(_argent(a.id()) < avant_a + 100, "A a payé (revenu mis à part)")
	verifier(_argent(b.id()) >= avant_b, "B n'a rien payé")
	# B part sans prévenir : éliminé, A continue de recevoir des états à tick croissant.
	b.pair.close()
	verifier(
		await _jusqua(func() -> bool: return serveur.joueur_de(b.id()) == -1),
		"le serveur voit le départ de B"
	)
	var tick_a := _arene_recue(a, a.arenes.size() - 1).tick
	verifier(
		await _jusqua(
			func() -> bool: return _arene_recue(a, a.arenes.size() - 1).tick > tick_a + 10
		),
		"la partie continue pour A"
	)
	var joueurs: Array = serveur.partie.vue_globale().joueurs
	for j: Dictionary in joueurs:
		verifier_egal(bool(j["vivant"]), int(j["id"]) == a.id(), "seul A vit encore")


func test_un_client_de_mauvaise_version_recoit_son_motif_et_est_coupe() -> void:
	verifier(_monter_serveur())
	var a := _ajouter_client("A")
	verifier(await _jusqua(func() -> bool: return a.connecte()))
	var bonjour := Protocole.encoder_bonjour("Aki", d.empreinte)
	bonjour[1] = Protocole.VERSION + 1
	a.canal.rpc_id(1, "rpc_bonjour", bonjour)
	verifier(await _jusqua(func() -> bool: return a.refus.size() == 1), "un refus arrive")
	verifier_egal(
		Protocole.decoder_refus(a.refus[0]), Protocole.motif_version(Protocole.VERSION + 1)
	)
	verifier(await _jusqua(func() -> bool: return not a.connecte()), "puis la connexion est coupée")
	verifier_egal(serveur.nb_pairs(), 0)


# --- Usurpation ------------------------------------------------------------------------------


func test_un_client_ne_peut_ni_parler_au_nom_d_un_autre_ni_appeler_un_rpc_d_autorite() -> void:
	var cs := await _partie_a_deux()
	var a := cs[0]
	var b := cs[1]
	var intrus: Array[int] = [0, 0, 0, 0]
	serveur.canal.etat_arene_recu.connect(func(_o: PackedByteArray) -> void: intrus[0] += 1)
	serveur.canal.etat_global_recu.connect(func(_o: PackedByteArray) -> void: intrus[1] += 1)
	serveur.canal.salon_recu.connect(func(_o: PackedByteArray) -> void: intrus[2] += 1)
	serveur.canal.refus_recu.connect(func(_o: PackedByteArray) -> void: intrus[3] += 1)
	var avant_a := _argent(a.id())
	var vitesse := serveur.salon.vitesse
	var refus_a := a.refus.size()
	var salons_a := a.salons.size()
	var globaux_a := a.globaux.size()

	# 1. Les RPC réservés au serveur, appelés par B vers le serveur puis vers A (relais coupé).
	var forge := PackedByteArray([1, 2, 3, 4, 5])
	# Le moteur journalise chaque refus : quatre côté serveur, quatre côté intrus (pair inconnu).
	for i: int in 4:
		attendre_erreur("is not allowed on node")
		attendre_erreur("unknown peer ID")
	for rpc: String in ["rpc_etat_arene", "rpc_etat_global", "rpc_salon", "rpc_refus"]:
		b.canal.rpc_id(1, rpc, forge)
		b.canal.rpc_id(a.id(), rpc, forge)
	await attendre_images(30)
	verifier_egal(intrus, [0, 0, 0, 0] as Array[int], "le serveur n'a rien reçu en autorité")
	verifier_egal(a.refus.size(), refus_a, "A n'a reçu aucun refus forgé")
	verifier(a.salons.size() == salons_a or a.dernier_salon() != null, "le salon de A reste valide")
	for i: int in range(globaux_a, a.globaux.size()):
		verifier_non_nul(Protocole.decoder_etat_global(a.globaux[i]), "A ne reçoit que du vrai")

	# 2. Les intentions de B n'agissent que sur B ; l'option de l'hôte lui est fermée.
	_intention(b, Protocole.Intention.OPTIONS, 7, "0.5;1")
	_intention(b, Protocole.Intention.OBSERVER, a.id())
	var offres := _arene_recue(b, b.arenes.size() - 1).offres
	var cible := -1
	for i: int in offres.size():
		if int((offres[i] as Dictionary)["prix"]) <= _argent(b.id()):
			cible = i
			break
	var avant_b := _argent(b.id())
	_intention(b, Protocole.Intention.ACHETER, cible)
	await attendre_images(30)
	verifier_proche(serveur.salon.vitesse, vitesse, 1e-6, "B n'a pas réglé les options")
	verifier(_argent(b.id()) < avant_b + 100, "B a bien payé son achat")
	verifier(_argent(a.id()) >= avant_a, "A n'a pas été débité par B")
	var vue_b := serveur.partie.vue_arene(b.id(), b.id())
	verifier_egal(vue_b.armes.size() + vue_b.ameliorations.size(), 1, "l'achat est chez B")
	var vue_a := serveur.partie.vue_arene(a.id(), a.id())
	verifier_egal(vue_a.armes.size() + vue_a.ameliorations.size(), 0, "rien n'est arrivé chez A")

	# 3. Un bonjour qui se fait passer pour A ne vole rien et un second bonjour est ignoré.
	_dire_bonjour(b, "Aki")
	await attendre_images(10)
	verifier_egal(serveur.joueur_de(b.id()), b.id())
	verifier_different(
		(serveur.salon.joueurs[b.id()] as Dictionary)["nom"], "Aki", "B garde son nom"
	)

	# 4. Rien n'a planté : A reçoit encore des états.
	var n := a.arenes.size()
	verifier(
		await _jusqua(func() -> bool: return a.arenes.size() > n + 3), "le serveur sert toujours A"
	)
