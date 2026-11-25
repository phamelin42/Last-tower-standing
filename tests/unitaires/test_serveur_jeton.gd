extends CasDeTest
## Le rôle d'hôte d'un salon hébergé : réservé au porteur du jeton, sans repli ; le serveur sans
## jeton garde la règle du premier pair. Sans socket : on présente des pairs et des octets.

const JETON := [11, 12, 13, 14, 15, 16, 17, 18]

var d: Donnees
var courant: Donnees
var sorties: Array[Dictionary] = []
var crees: Array[Serveur] = []


func avant_chaque() -> void:
	d = Donnees.charger()
	courant = d
	sorties = []
	crees = []


func apres_chaque() -> void:
	for s: Serveur in crees:
		s.free()


func _serveur() -> Serveur:
	var s := Serveur.new()
	crees.append(s)
	s.emetteur = func(pair: int, rpc: String, octets: PackedByteArray) -> void:
		sorties.append({"pair": pair, "rpc": rpc, "octets": octets})
	s.preparer(d, 1)
	return s


func _bonjour(nom: String) -> PackedByteArray:
	return Protocole.encoder_bonjour(nom, d.empreinte)


func _intention(s: Serveur, pair: int, genre: int, arg: int = 0) -> int:
	return s.traiter_intention(pair, Protocole.encoder_intention(genre, arg, ""))


func _refus(pair: int) -> Array[String]:
	var textes: Array[String] = []
	for sortie: Dictionary in sorties:
		if int(sortie["pair"]) == pair and sortie["rpc"] == "rpc_refus":
			textes.append(Protocole.decoder_refus(sortie["octets"] as PackedByteArray))
	return textes


func _serveur_a_jeton() -> Serveur:
	var s := _serveur()
	s.jeton_hote = PackedByteArray(JETON)
	s.preparer(courant)
	return s


func _connecter_avec(s: Serveur, pair: int, jeton: PackedByteArray) -> bool:
	s.pair_connecte(pair)
	var b := Protocole.encoder_bonjour("Joueur %d" % pair, courant.empreinte, jeton)
	return s.traiter_bonjour(pair, b)


func test_avec_jeton_un_autre_pair_arrive_avant_le_client_local_et_n_est_pas_hote() -> void:
	var s := _serveur_a_jeton()
	verifier(_connecter_avec(s, 7, PackedByteArray()), "l'autre est admis comme joueur")
	verifier_egal(s.salon.hote, -1)
	verifier_egal(_intention(s, 7, Protocole.Intention.PRET, 1), 0)
	verifier_egal(s.traiter_intention(7, Serveur.encoder_options(0.5, 1, false)) != 0, true)
	verifier(_connecter_avec(s, 1, PackedByteArray(JETON)), "le client local")
	verifier_egal(s.salon.hote, 1)
	verifier_egal(s.traiter_intention(1, Serveur.encoder_options(0.5, 1, false)), 0)


func test_avec_jeton_un_jeton_faux_ou_de_mauvaise_taille_n_est_jamais_hote() -> void:
	var faux: Array[PackedByteArray] = [
		PackedByteArray(),
		PackedByteArray(JETON).slice(0, 7),
		PackedByteArray(JETON) + PackedByteArray([0]),
		PackedByteArray([11, 12, 13, 14, 15, 16, 17, 19]),
	]
	for i: int in faux.size():
		var s := _serveur_a_jeton()
		_connecter_avec(s, 2, faux[i])
		verifier_egal(s.salon.hote, -1, "cas %d" % i)


func test_le_jeton_ne_survit_pas_a_la_reouverture_du_salon_et_reste_exige() -> void:
	var s := _serveur_a_jeton()
	_connecter_avec(s, 1, PackedByteArray(JETON))
	s.rouvrir_salon()
	_connecter_avec(s, 2, PackedByteArray())
	verifier_egal(s.salon.hote, -1, "le salon rouvert exige toujours le jeton")
	s.traiter_bonjour(
		1, Protocole.encoder_bonjour("Local", courant.empreinte, PackedByteArray(JETON))
	)
	verifier_egal(s.salon.hote, 1)


func test_le_client_local_parti_ne_laisse_le_role_a_personne() -> void:
	var s := _serveur_a_jeton()
	_connecter_avec(s, 1, PackedByteArray(JETON))
	_connecter_avec(s, 2, PackedByteArray())
	s.pair_deconnecte(1)
	verifier_egal(s.salon.hote, -1)
	_connecter_avec(s, 3, PackedByteArray(JETON))
	verifier_egal(s.salon.hote, 3, "revenu avec le même jeton")


func test_sans_jeton_configure_la_regle_du_premier_pair_reste() -> void:
	var s := _serveur()
	_connecter_avec(s, 5, PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]))
	verifier_egal(s.salon.hote, 5)


func test_un_bonjour_de_version_2_ou_3_est_refuse_avec_le_motif_de_version() -> void:
	for ancienne: int in [2, 3]:
		sorties = []
		var s := _serveur()
		var vieux := _bonjour("Aki")
		vieux[1] = ancienne
		s.pair_connecte(5)
		verifier_faux(s.traiter_bonjour(5, vieux), "version %d" % ancienne)
		verifier_egal(_refus(5), [Protocole.motif_version(ancienne)] as Array[String])
