extends CasDeTest
## Le réseau de bout en bout dans ce processus, sur la boucle locale : un serveur dédié accéléré
## (`ServeurDedie`, qui ouvre sa propre racine multijoueur comme dans `--serveur`) et deux clients
## (`SessionReseau`, le chemin du vrai jeu). Le pendant à deux processus est `tools/integration.sh`.

const DELAI_MS := 8000
const ADRESSE := "127.0.0.1"
const GRAINE := 7
const ACCELERATION := 20

var _donnees: Donnees
var _dedie: ServeurDedie = null
var _sessions: Array[SessionReseau] = []
var _codes: Array[int] = []
var _port: int = 0


class Ecoute:
	extends RefCounted
	var session: SessionReseau
	var arenes: Array[VueArene] = []
	var globales: Array[VueGlobale] = []
	var perte: String = ""

	func _init(s: SessionReseau) -> void:
		session = s
		s.connexion_perdue.connect(func(motif: String) -> void: perte = motif)
		s.client.vue_arene_recue.connect(func(v: VueArene) -> void: arenes.append(v))
		s.client.vue_globale_recue.connect(func(v: VueGlobale) -> void: globales.append(v))

	func arene() -> VueArene:
		return arenes[arenes.size() - 1] if not arenes.is_empty() else null

	func globale() -> VueGlobale:
		return globales[globales.size() - 1] if not globales.is_empty() else null


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_sessions = []
	_codes = []
	_dedie = null
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE + OS.get_process_id()
	_port = _port_libre(rng)


func apres_chaque() -> void:
	for s: SessionReseau in _sessions:
		if is_instance_valid(s):
			s.fermer()
			s.get_parent().remove_child(s)
			s.queue_free()
	_sessions = []
	if _dedie != null and is_instance_valid(_dedie):
		_dedie.arreter()
		_dedie.get_parent().remove_child(_dedie)
		_dedie.queue_free()
	_dedie = null


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


## Serveur dédié sous la racine par défaut, comme `Principal` le pose : c'est le cas du vrai
## `--serveur`, où le chemin du `Canal` ne doit pas dépendre de l'emplacement du serveur.
func _serveur() -> void:
	_dedie = (load("res://scenes/serveur.tscn") as PackedScene).instantiate() as ServeurDedie
	_dedie.sortie = func(code: int) -> void: _codes.append(code)
	arbre.root.add_child(_dedie)
	var args := {
		"port": _port,
		"graine": GRAINE,
		"vitesse": Salon.VITESSES[2],
		"acceleration": ACCELERATION,
		"quitter_a_la_fin": true,
	}
	verifier_egal(_dedie.lancer(args, _donnees), ServeurDedie.CODE_OK, "le serveur s'ouvre")


func _client(nom: String) -> Ecoute:
	var s := SessionReseau.new()
	arbre.root.add_child(s)
	_sessions.append(s)
	verifier_egal(s.rejoindre(_donnees, ADRESSE, _port, nom), OK, "%s rejoint" % nom)
	return Ecoute.new(s)


## Deux joueurs dans le salon, tous prêts, ×4 réglé par l'hôte, partie lancée.
func _lancer_a_deux() -> Array[Ecoute]:
	_serveur()
	var a := _client("Aya")
	var ok := await _jusqua(func() -> bool: return a.session.client.id_local() > 0)
	var b := _client("Bo")
	verifier(ok and await _jusqua(func() -> bool: return b.session.client.id_local() > 0))
	verifier(await _jusqua(_salon_a_deux.bind(a)), "le salon montre les deux joueurs")
	verifier(a.session.client.est_hote(), "le premier connecté est l'hôte")
	b.session.client.pret(true)
	a.session.client.regler_options(Salon.VITESSES[2], GRAINE, true)
	a.session.client.lancer()
	verifier(
		await _jusqua(func() -> bool: return a.arene() != null and b.arene() != null),
		"chacun reçoit sa vue d'arène"
	)
	return [a, b]


func _salon_a_deux(e: Ecoute) -> bool:
	var salon := e.session.client.salon
	return salon != null and salon.joueurs.size() == 2


func _offre_abordable(v: VueArene) -> int:
	for i: int in v.offres.size():
		var offre: Dictionary = v.offres[i]
		if not bool(offre["vendu"]) and int(offre["prix"]) <= v.argent:
			return i
	return -1


func test_une_partie_accelere_se_termine_pour_les_deux_clients_et_le_serveur() -> void:
	var joueurs := await _lancer_a_deux()
	# Personne n'achète : les deux tombent, la partie se termine d'elle-même.
	for e: Ecoute in joueurs:
		verifier(
			await _jusqua(func() -> bool: return e.globale() != null and e.globale().termine),
			"l'état global « terminé » arrive"
		)
		verifier_egal(e.globale().classement.size(), 2, "le classement nomme les deux joueurs")
		verifier_egal(e.perte, "", "aucune connexion perdue")
	var ids: Array[int] = [
		joueurs[0].session.client.id_local(), joueurs[1].session.client.id_local()
	]
	for id: int in ids:
		verifier_contient(joueurs[0].globale().classement, id)
	verifier(await _jusqua(func() -> bool: return not _codes.is_empty()), "le serveur sort")
	verifier_egal(_codes, [ServeurDedie.CODE_OK] as Array[int], "avec le code 0, une seule fois")


func test_un_achat_est_debite_et_les_etats_arrivent_dans_l_ordre() -> void:
	var joueurs := await _lancer_a_deux()
	var a: Ecoute = joueurs[0]
	var b: Ecoute = joueurs[1]
	var offre := _offre_abordable(a.arene())
	verifier(offre >= 0, "une offre abordable")
	var prix := int((a.arene().offres[offre] as Dictionary)["prix"])
	var argent := a.arene().argent
	a.session.client.acheter(offre)
	verifier(
		await _jusqua(
			func() -> bool: return a.arene().armes.size() + a.arene().ameliorations.size() >= 1
		),
		"l'achat apparaît dans la vue"
	)
	verifier(a.arene().argent <= argent - prix + a.arene().revenu, "le prix est débité")
	var vb := b.arene()
	verifier_egal(vb.armes.size() + vb.ameliorations.size(), 0, "rien n'arrive chez l'autre")
	for i: int in range(1, a.arenes.size()):
		verifier(a.arenes[i].tick > a.arenes[i - 1].tick, "les ticks reçus croissent")


func test_un_client_coupe_brutalement_n_arrete_pas_l_autre() -> void:
	var joueurs := await _lancer_a_deux()
	var a: Ecoute = joueurs[0]
	var b: Ecoute = joueurs[1]
	var id_b := b.session.client.id_local()
	# Coupure sans préavis : ni `quitter_partie`, juste la connexion qui tombe.
	b.session.client.deconnecter()
	var tick := a.arene().tick
	verifier(
		await _jusqua(func() -> bool: return a.arene().tick > tick + 10),
		"la partie continue pour le premier"
	)
	verifier(
		await _jusqua(func() -> bool: return _dedie.serveur.joueur_de(id_b) == -1),
		"le serveur retire le joueur coupé"
	)
	verifier_egal(a.perte, "", "le premier n'a rien perdu")
