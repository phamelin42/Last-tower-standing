extends CasDeTest
## Le bilan de fin de partie par de vrais sockets ENet (boucle locale, port tiré à l'exécution) :
## chaque joueur présent reçoit son propre bilan, et seulement le sien.

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
	var salons: Array[PackedByteArray] = []
	var arenes: Array[PackedByteArray] = []
	var globaux: Array[PackedByteArray] = []
	var refus: Array[PackedByteArray] = []
	var bilans: Array[PackedByteArray] = []
	var _id: int = 0

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
	c.canal.bilan_recu.connect(func(o: PackedByteArray) -> void: c.bilans.append(o))
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


func _finir_la_partie() -> void:
	var pas := 0
	while not serveur.partie.est_terminee() and pas < 60000:
		serveur.partie.avancer(0.05)
		pas += 1
	verifier(serveur.partie.est_terminee(), "la partie de deux joueurs passifs finit")
	# Le serveur constate la fin à son prochain tour de boucle.
	for _i: int in 10:
		serveur.tick(1.0 / 60.0)


func test_un_joueur_recoit_son_bilan_a_la_fin_de_la_partie_et_pas_celui_d_un_autre() -> void:
	var deux := await _partie_a_deux()
	var a: Cli = deux[0]
	var b: Cli = deux[1]
	# Un achat pour A seulement : leurs bilans diffèrent.
	var v := serveur.partie.vue_arene(a.id(), a.id())
	var achete := false
	for i: int in v.offres.size():
		if serveur.partie.intention_acheter(a.id(), i) == Types.Resultat.OK:
			achete = true
			break
	verifier(achete, "A achète une offre")
	_finir_la_partie()
	verifier(
		await _jusqua(func() -> bool: return not a.bilans.is_empty() and not b.bilans.is_empty()),
		"chaque joueur reçoit un bilan"
	)
	verifier_egal(a.bilans.size(), 1, "une seule fois pour A")
	verifier_egal(b.bilans.size(), 1, "une seule fois pour B")
	var bilan_a := Protocole.decoder_bilan(a.bilans[0])
	var bilan_b := Protocole.decoder_bilan(b.bilans[0])
	verifier_faux(bilan_a.is_empty() or bilan_b.is_empty())
	var attendu_a := serveur.partie.bilan_joueur(a.id())
	var attendu_b := serveur.partie.bilan_joueur(b.id())
	for nom: String in BilanPartie.noms():
		verifier_egal(float(bilan_a[nom]), float(attendu_a[nom]), "A : %s" % nom)
		verifier_egal(float(bilan_b[nom]), float(attendu_b[nom]), "B : %s" % nom)
	verifier(float(bilan_a["or_depense"]) > 0.0, "le bilan de A porte son achat")
	verifier_egal(bilan_b["or_depense"], 0.0, "et pas celui de B")


func test_un_joueur_parti_ne_recoit_pas_de_bilan() -> void:
	var deux := await _partie_a_deux()
	var a: Cli = deux[0]
	var b: Cli = deux[1]
	_intention(b, Protocole.Intention.QUITTER, 0)
	verifier(
		await _jusqua(func() -> bool: return serveur.partie.bilan_joueur(b.id()).is_empty()),
		"B a quitté la partie"
	)
	_finir_la_partie()
	verifier(await _jusqua(func() -> bool: return not a.bilans.is_empty()), "A reçoit son bilan")
	for _i: int in 30:
		await arbre.process_frame
	verifier_egal(b.bilans.size(), 0, "B, parti, n'en reçoit pas")
	verifier_egal(a.bilans.size(), 1)
