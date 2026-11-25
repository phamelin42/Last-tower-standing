extends CasDeTest
## Limites de l'annuaire (ADR 001, § Limites de débit et de mémoire) : seaux à jetons, plafonds,
## messages invalides, ordre des contrôles, mémoire bornée, compteurs, flux aléatoire à graine
## fixe. Horloge et sondes injectées. Suite de `test_annuaire_service.gd`, scindée pour tenir sous
## la limite de méthodes publiques de gdlint.

const GRAINE: int = 20261125
const A: String = "8.8.8.8"
const B: String = "8.8.4.4"

var _t: Array[int] = [1_000_000]


func avant_chaque() -> void:
	_t[0] = 1_000_000


func _service(autoriser_prive: bool = false) -> AnnuaireService:
	var s := AnnuaireService.new()
	s.horloge = func() -> int: return _t[0]
	s.autoriser_prive = autoriser_prive
	return s


func _avancer(ms: int) -> void:
	_t[0] += ms


func _envoyer(s: AnnuaireService, ip: String, cadre: PackedByteArray) -> Dictionary:
	return s.evaluer(ip, cadre)


## Statut de la REPONSE d'un résultat, -1 si ce n'est pas une REPONSE, -2 si c'est une liste.
func _statut(r: Dictionary) -> int:
	if r["action"] != AnnuaireService.Action.REPONDRE:
		return -1
	var d := AnnuaireProtocole.decoder_reponse(r["octets"])
	if d.is_empty():
		return -2
	return d["statut"]


func _annonce(port: int = 7777, nom: String = "Salon", joueurs: int = 1) -> PackedByteArray:
	return AnnuaireProtocole.encoder_annonce(2, joueurs, 8, port, nom)


## Annonce dont la sonde réussit (ou échoue) aussitôt ; renvoie le statut final.
func _annoncer(
	s: AnnuaireService,
	ip: String,
	port: int = 7777,
	nom: String = "Salon",
	sonde_ok: bool = true,
	joueurs: int = 1
) -> int:
	var r := s.evaluer(ip, _annonce(port, nom, joueurs))
	if r["action"] == AnnuaireService.Action.SONDER:
		r = {
			"action": AnnuaireService.Action.REPONDRE,
			"octets": s.sonde_terminee(r["ticket"], sonde_ok),
		}
	return _statut(r)


func _retirer(s: AnnuaireService, ip: String, port: int = 7777) -> int:
	return _statut(s.evaluer(ip, AnnuaireProtocole.encoder_retrait(port)))


func _liste_ip_port(s: AnnuaireService) -> Array[String]:
	var sortie: Array[String] = []
	for e: Dictionary in s.salons():
		sortie.append("%s:%d" % [e["ip"], e["port"]])
	return sortie


# --- Débit ---------------------------------------------------------------------------------------


func test_annonce_et_retrait_partagent_un_seau_de_3_qui_se_recharge_d_un_par_5_secondes() -> void:
	var s := _service()
	verifier_egal(_retirer(s, A), 0)
	verifier_egal(_retirer(s, A), 0)
	verifier_egal(_retirer(s, A), 0)
	verifier_egal(_retirer(s, A), 3, "quatrième à la limite exacte")
	verifier_egal(_statut(s.evaluer(A, _annonce())), 3, "une annonce aussi")
	_avancer(4_999)
	verifier_egal(_retirer(s, A), 3, "à 4,999 s")
	_avancer(1)
	verifier_egal(_retirer(s, A), 0, "un jeton à 5 s")
	verifier_egal(_retirer(s, A), 3)
	_avancer(15_000)
	for i: int in 3:
		verifier_egal(_retirer(s, A), 0, "recharge plafonnée à 3, essai %d" % i)
	verifier_egal(_retirer(s, A), 3)
	_avancer(60_000)
	for i: int in 3:
		verifier_egal(_retirer(s, A), 0, "pas plus de 3 après une longue pause")
	verifier_egal(_retirer(s, A), 3)


func test_liste_a_un_seau_de_5_qui_se_recharge_d_un_par_2_secondes() -> void:
	var s := _service()
	for i: int in 5:
		var r := s.evaluer(A, AnnuaireProtocole.encoder_liste())
		verifier_egal(r["action"], AnnuaireService.Action.REPONDRE)
		verifier_egal(_statut(r), -2, "liste %d : un cadre SALONS" % (i + 1))
	verifier_egal(_statut(s.evaluer(A, AnnuaireProtocole.encoder_liste())), 3, "sixième liste")
	_avancer(1_999)
	verifier_egal(_statut(s.evaluer(A, AnnuaireProtocole.encoder_liste())), 3)
	_avancer(1)
	verifier_egal(_statut(s.evaluer(A, AnnuaireProtocole.encoder_liste())), -2, "un jeton à 2 s")
	verifier_egal(_statut(s.evaluer(A, AnnuaireProtocole.encoder_liste())), 3)


func test_les_seaux_sont_independants_par_ip_et_par_type() -> void:
	var s := _service()
	for i: int in 3:
		_retirer(s, A)
	verifier_egal(_retirer(s, A), 3)
	verifier_egal(_retirer(s, B), 0, "une autre IP")
	verifier_egal(_statut(s.evaluer(A, AnnuaireProtocole.encoder_liste())), -2, "liste non touchée")


# --- Plafonds ----------------------------------------------------------------------------------


func test_la_quatrieme_entree_d_une_meme_ip_recoit_la_reponse_5() -> void:
	var s := _service()
	for port: int in [7777, 7778, 7779]:
		verifier_egal(_annoncer(s, A, port), 0)
	_avancer(5_000)
	verifier_egal(_statut(s.evaluer(A, _annonce(7780))), 5)
	verifier_egal(s.nb_sondes(), 0, "pas de sonde sur un refus de quota")
	_avancer(5_000)
	verifier_egal(_annoncer(s, A, 7778), 0, "une mise à jour est exemptée du quota")
	verifier_egal(s.nb_entrees(), 3)


func test_la_cent_unieme_entree_recoit_la_reponse_5() -> void:
	var s := _service()
	for i: int in 33:
		for port: int in [7777, 7778, 7779]:
			verifier_egal(_annoncer(s, "8.9.%d.1" % i, port), 0)
	verifier_egal(_annoncer(s, "8.10.0.1"), 0)
	verifier_egal(s.nb_entrees(), 100)
	verifier_egal(_statut(s.evaluer("8.10.1.1", _annonce())), 5, "101e entrée")
	verifier_egal(s.nb_entrees(), 100)
	# Saturation à 34 IP : limite connue et acceptée (ADR). Une mise à jour reste admise.
	_avancer(10_000)
	verifier_egal(_annoncer(s, "8.10.0.1"), 0, "mise à jour d'une entrée existante, annuaire plein")
	verifier_egal(s.salons().size(), 100)


func test_la_liste_ne_renvoie_jamais_plus_de_cent_entrees() -> void:
	var s := _service()
	for i: int in 34:
		for port: int in [7777, 7778, 7779]:
			_annoncer(s, "8.9.%d.1" % i, port)
	verifier(s.salons().size() <= 100)
	var r := s.evaluer(B, AnnuaireProtocole.encoder_liste())
	verifier(not AnnuaireProtocole.decoder_salons(r["octets"]).is_empty())


func test_des_sondes_simultanees_ne_depassent_pas_le_quota_par_ip_a_la_fin() -> void:
	var s := _service()
	var tickets: Array[int] = []
	for i: int in 3:
		var r := s.evaluer(A, _annonce(7777 + i))
		tickets.append(r["ticket"])
	_avancer(5_000)
	var quatrieme := s.evaluer(A, _annonce(7780))
	verifier_egal(quatrieme["action"], AnnuaireService.Action.SONDER, "aucune entrée encore")
	tickets.append(quatrieme["ticket"])
	var statuts: Array[int] = []
	for ticket: int in tickets:
		statuts.append(AnnuaireProtocole.decoder_reponse(s.sonde_terminee(ticket, true))["statut"])
	verifier_egal(statuts, [0, 0, 0, 5], "le quota est revérifié à la fin de la sonde")
	verifier_egal(s.nb_entrees(), 3)


func test_64_connexions_dont_4_par_ip_au_plus() -> void:
	var s := _service()
	for i: int in 4:
		verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.OK)
	verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.PLAFOND, "5e de la même IP")
	verifier_egal(s.connexion_ouverte(B), AnnuaireService.Accueil.OK)
	s.connexion_fermee(A)
	verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.OK, "une place libérée")
	for i: int in range(2, 17):
		for k: int in 4:
			if s.nb_connexions() < 64:
				s.connexion_ouverte("8.20.%d.1" % i)
	verifier_egal(s.nb_connexions(), 64)
	verifier_egal(s.connexion_ouverte("8.30.0.1"), AnnuaireService.Accueil.PLAFOND, "65e connexion")
	s.connexion_fermee("8.20.2.1")
	verifier_egal(s.connexion_ouverte("8.30.0.1"), AnnuaireService.Accueil.OK)


func test_une_fermeture_sans_ouverture_ne_fait_pas_descendre_les_compteurs_sous_zero() -> void:
	var s := _service()
	s.connexion_fermee(A)
	verifier_egal(s.nb_connexions(), 0)
	for i: int in 4:
		verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.OK)
	verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.PLAFOND)


# --- Messages invalides --------------------------------------------------------------------------


func _invalide() -> PackedByteArray:
	return PackedByteArray([2, 0])


func test_la_sixieme_erreur_en_60_secondes_met_l_ip_de_cote_5_minutes() -> void:
	var s := _service()
	for i: int in 5:
		verifier_egal(s.evaluer(A, _invalide())["action"], AnnuaireService.Action.FERMER)
		verifier_egal(
			s.connexion_ouverte(A), AnnuaireService.Accueil.OK, "après %d erreurs" % (i + 1)
		)
		s.connexion_fermee(A)
		_avancer(10_000)
	# Les 5 premières erreurs datent de 10 à 50 s : la sixième est la 6e dans la fenêtre de 60 s.
	s.evaluer(A, _invalide())
	verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.ECARTEE)
	_avancer(299_999)
	verifier_egal(
		s.connexion_ouverte(A), AnnuaireService.Accueil.ECARTEE, "encore à 4 min 59,999 s"
	)
	_avancer(1)
	verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.OK, "libérée à 5 min")
	verifier_egal(
		s.connexion_ouverte(B), AnnuaireService.Accueil.OK, "les autres IP ne sont pas touchées"
	)


func test_des_erreurs_espacees_de_plus_de_60_secondes_ne_mettent_pas_l_ip_de_cote() -> void:
	var s := _service()
	for i: int in 20:
		s.evaluer(A, _invalide())
		_avancer(12_000)
	verifier_egal(
		s.connexion_ouverte(A), AnnuaireService.Accueil.OK, "5 erreurs par minute au plus"
	)


func test_une_erreur_est_comptee_pour_chaque_cause_d_invalidite() -> void:
	var causes: Array[PackedByteArray] = [
		PackedByteArray([2, 0]),
		PackedByteArray([3, 0, 0x42, 1, 3]),
		PackedByteArray([129, 0, 0x41, 1, 0x01]),
		PackedByteArray([3, 0, 0x41, 1, 0x09]),
		PackedByteArray([5, 0, 0x41, 1, 0x02, 0x00, 0x00]),
	]
	for cadre: PackedByteArray in causes:
		var s := _service()
		for i: int in 6:
			_avancer(5_000)
			s.evaluer(A, cadre)
		verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.ECARTEE, str(cadre))


func test_une_version_differente_ne_compte_pas_comme_invalide() -> void:
	var s := _service()
	for i: int in 50:
		var r := s.evaluer(A, PackedByteArray([200, 0, 0x41, 2, 0x01]))
		verifier_egal(_statut(r), 1)
	verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.OK)


func test_la_reponse_de_version_a_les_octets_de_l_adr() -> void:
	var s := _service()
	var r := s.evaluer(A, PackedByteArray([77, 1, 0x41, 9, 0x42, 1, 2, 3]))
	verifier_egal(r["octets"], PackedByteArray([5, 0, 0x41, 1, 0x81, 1, 1]))


func test_un_delai_depasse_compte_comme_message_invalide_sauf_connexion_vide_fermee() -> void:
	var s := _service()
	for i: int in 5:
		s.delai_depasse(A, PackedByteArray())
	verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.OK)
	s.delai_depasse(A, PackedByteArray([3, 0]))
	verifier_egal(s.connexion_ouverte(A), AnnuaireService.Accueil.ECARTEE)
	var t := _service()
	for i: int in 20:
		t.fermeture_prematuree(B, PackedByteArray())
	verifier_egal(
		t.connexion_ouverte(B), AnnuaireService.Accueil.OK, "ouvrir puis fermer sans rien dire"
	)


# --- Ordre des contrôles -----------------------------------------------------------------------


func test_le_debit_est_controle_avant_le_decodage() -> void:
	var s := _service()
	for i: int in 3:
		_retirer(s, A)
	var mauvais := PackedByteArray([5, 0, 0x41, 1, 0x02, 0x00, 0x00])
	for i: int in 10:
		verifier_egal(_statut(s.evaluer(A, mauvais)), 3, "débit avant décodage")
	verifier_egal(
		s.connexion_ouverte(A), AnnuaireService.Accueil.OK, "le refus de débit n'est pas une erreur"
	)


func test_le_type_inconnu_est_refuse_avant_le_debit() -> void:
	var s := _service()
	for i: int in 3:
		_retirer(s, A)
	verifier_egal(_statut(s.evaluer(A, PackedByteArray([3, 0, 0x41, 1, 0x09]))), 4)


func test_l_adresse_non_publique_est_refusee_avant_le_quota_et_le_quota_avant_la_sonde() -> void:
	var s := _service(true)
	for port: int in [7777, 7778, 7779]:
		_annoncer(s, A, port)
	_avancer(5_000)
	s.autoriser_prive = false
	verifier_egal(_statut(s.evaluer("10.0.0.1", _annonce())), 6)
	verifier_egal(_statut(s.evaluer(A, _annonce(7780))), 5)
	verifier_egal(s.nb_sondes(), 0)


func test_le_decodage_est_refuse_avant_le_filtre_d_adresse() -> void:
	var s := _service()
	var mauvais_port := PackedByteArray([0x41, 1, 0x01, 2, 1, 8, 0x00, 0x00, 1, 0x61])
	var cadre := PackedByteArray([mauvais_port.size(), 0])
	cadre.append_array(mauvais_port)
	verifier_egal(_statut(s.evaluer("10.0.0.1", cadre)), 4, "décodage avant adresse")


func test_les_requetes_tronquees_attendent_chaque_octet() -> void:
	var s := _service()
	var cadre := _annonce(7777, "Salon é")
	for n: int in range(0, cadre.size()):
		verifier_egal(
			s.evaluer(A, cadre.slice(0, n))["action"], AnnuaireService.Action.ATTENTE, "n = %d" % n
		)
	verifier_egal(
		s.connexion_ouverte(A), AnnuaireService.Accueil.OK, "attendre n'est pas une erreur"
	)


# --- Mémoire bornée ----------------------------------------------------------------------------


func test_la_table_de_debit_suit_au_plus_1024_ip_et_oublie_apres_60_secondes() -> void:
	var s := _service()
	for i: int in 1030:
		s.evaluer("9.%d.%d.1" % [i / 256, i % 256], AnnuaireProtocole.encoder_liste())
	verifier_egal(s.nb_ip_suivies(), 1024)
	_avancer(59_999)
	s.purger()
	verifier_egal(s.nb_ip_suivies(), 1024, "pas encore oubliées à 59,999 s")
	_avancer(1)
	s.purger()
	verifier_egal(s.nb_ip_suivies(), 0, "oubliées 60 s après leur dernière requête")


func test_une_ip_mise_de_cote_n_est_oubliee_qu_apres_5_minutes() -> void:
	var s := _service()
	for i: int in 6:
		s.evaluer(A, _invalide())
	_avancer(299_999)
	s.purger()
	verifier_egal(s.nb_ip_suivies(), 1)
	_avancer(1)
	s.purger()
	verifier_egal(s.nb_ip_suivies(), 0)


func test_une_ip_oubliee_retrouve_un_seau_plein() -> void:
	var s := _service()
	for i: int in 3:
		_retirer(s, A)
	verifier_egal(_retirer(s, A), 3)
	_avancer(60_000)
	s.purger()
	for i: int in 3:
		verifier_egal(_retirer(s, A), 0)


# --- Compteurs, sans IP ------------------------------------------------------------------------


func test_les_compteurs_agreges_comptent_les_reponses_par_statut() -> void:
	var s := _service()
	_annoncer(s, A)
	_annoncer(s, B, 7777, "Salon", false)
	s.evaluer(A, _invalide())
	s.evaluer("10.0.0.1", _annonce())
	var c := s.compteurs()
	verifier_egal(c.get(0, 0), 1)
	verifier_egal(c.get(2, 0), 1)
	verifier_egal(c.get(6, 0), 1)
	verifier_egal(s.salons_listes(), 1)
	for cle: Variant in c:
		verifier(cle is int, "des statuts seulement : aucune IP")
	s.reinitialiser_compteurs()
	verifier_egal(s.compteurs().size(), 0)


# --- Fuzz à graine fixe ------------------------------------------------------------------------


func test_un_flux_aleatoire_garde_tous_les_plafonds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var s := _service()
	var en_cours: Array[int] = []
	for i: int in 4000:
		_avancer(rng.randi_range(0, 3_000))
		var ip := (
			"8.%d.%d.%d" % [rng.randi_range(0, 3), rng.randi_range(0, 5), rng.randi_range(1, 3)]
		)
		var cadre := PackedByteArray()
		match rng.randi_range(0, 5):
			0, 1:
				cadre = _annonce(rng.randi_range(7770, 7776), "S%d" % i)
			2:
				cadre = AnnuaireProtocole.encoder_retrait(rng.randi_range(7770, 7776))
			3:
				cadre = AnnuaireProtocole.encoder_liste()
			_:
				cadre.resize(rng.randi_range(0, 140))
				for k: int in cadre.size():
					cadre[k] = rng.randi_range(0, 255)
		var r := s.evaluer(ip, cadre)
		if r["action"] == AnnuaireService.Action.SONDER:
			en_cours.append(r["ticket"])
		if not en_cours.is_empty() and rng.randi_range(0, 2) == 0:
			var k := rng.randi_range(0, en_cours.size() - 1)
			s.sonde_terminee(en_cours[k], rng.randi_range(0, 3) != 0)
			en_cours.remove_at(k)
		if i % 50 == 0:
			s.purger()
		verifier(s.nb_entrees() <= 100, "au plus 100 entrées")
		verifier(s.nb_sondes() <= 4, "au plus 4 sondes")
		verifier(s.nb_ip_suivies() <= 1024, "au plus 1 024 IP")
		verifier(s.salons().size() <= 100)
	var par_ip: Dictionary = {}
	for e: Dictionary in s.salons():
		par_ip[e["ip"]] = int(par_ip.get(e["ip"], 0)) + 1
	for ip: Variant in par_ip:
		verifier(int(par_ip[ip]) <= 3, "au plus 3 entrées par IP")
