extends CasDeTest
## Logique de l'annuaire (ADR 001) : entrées et expiration, IP vue et non déclarée, filtre
## d'adresses, seaux à jetons, quotas, sondes simulées, ordre des contrôles. Horloge et résultats de
## sonde sont injectés : aucun réseau. Les valeurs attendues viennent de l'ADR, pas du code testé.

const GRAINE: int = 20261125
const A: String = "8.8.8.8"
const B: String = "8.8.4.4"

## Première et dernière adresse de chaque plage non publique (ADR : boucle locale, privée, lien
## local, CGNAT, multicast, non spécifiée, et assimilées), puis les voisines publiques.
const PLAGES_NON_PUBLIQUES: Array[Array] = [
	["0.0.0.0", "0.255.255.255", "plage 0/8"],
	["10.0.0.0", "10.255.255.255", "privée 10/8"],
	["100.64.0.0", "100.127.255.255", "CGNAT 100.64/10"],
	["127.0.0.0", "127.255.255.255", "boucle locale"],
	["169.254.0.0", "169.254.255.255", "lien local"],
	["172.16.0.0", "172.31.255.255", "privée 172.16/12"],
	["192.0.0.0", "192.0.0.255", "192.0.0/24"],
	["192.0.2.0", "192.0.2.255", "documentation 192.0.2/24"],
	["192.168.0.0", "192.168.255.255", "privée 192.168/16"],
	["198.18.0.0", "198.19.255.255", "198.18/15"],
	["198.51.100.0", "198.51.100.255", "documentation 198.51.100/24"],
	["203.0.113.0", "203.0.113.255", "documentation 203.0.113/24"],
	["224.0.0.0", "239.255.255.255", "multicast"],
	["240.0.0.0", "255.255.255.255", "réservée et diffusion"],
]
const VOISINES_PUBLIQUES: Array[String] = [
	"1.0.0.0",
	"9.255.255.255",
	"11.0.0.0",
	"100.63.255.255",
	"100.128.0.0",
	"126.255.255.255",
	"128.0.0.0",
	"169.253.255.255",
	"169.255.0.0",
	"172.15.255.255",
	"172.32.0.0",
	"192.0.1.0",
	"192.0.3.0",
	"192.167.255.255",
	"192.169.0.0",
	"198.17.255.255",
	"198.20.0.0",
	"198.51.99.255",
	"198.51.101.0",
	"203.0.112.255",
	"203.0.114.0",
	"223.255.255.255",
	"8.8.8.8",
	"93.184.216.34",
]

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


# --- IP vue, jamais déclarée ---------------------------------------------------------------------


func test_une_annonce_est_listee_avec_l_ip_de_la_connexion_et_le_port_declare() -> void:
	var s := _service()
	verifier_egal(_annoncer(s, A, 7801, "Mon salon é", true, 3), 0)
	var salons := s.salons()
	verifier_egal(salons.size(), 1)
	verifier_egal(salons[0]["ip"], A)
	verifier_egal(salons[0]["port"], 7801)
	verifier_egal(salons[0]["nom"], "Mon salon é")
	verifier_egal(salons[0]["joueurs"], 3)
	verifier_egal(salons[0]["max"], 8)
	verifier_egal(salons[0]["version_jeu"], 2)


func test_la_liste_renvoyee_a_un_client_contient_l_ip_vue() -> void:
	var s := _service()
	_annoncer(s, "93.184.216.9", 7801, "Salon")
	var r := s.evaluer(B, AnnuaireProtocole.encoder_liste())
	verifier_egal(r["action"], AnnuaireService.Action.REPONDRE)
	var d := AnnuaireProtocole.decoder_salons(r["octets"])
	verifier_egal((d["salons"] as Array).size(), 1)
	verifier_egal(d["salons"][0]["ip"], "93.184.216.9")


func test_deux_ip_avec_le_meme_port_font_deux_entrees_et_un_retrait_ne_vise_que_la_sienne() -> void:
	var s := _service()
	_annoncer(s, A)
	_annoncer(s, B)
	verifier_egal(s.nb_entrees(), 2)
	verifier_egal(_retirer(s, A), 0)
	verifier_egal(_liste_ip_port(s), ["8.8.4.4:7777"])


func test_une_annonce_repetee_met_a_jour_le_nom_et_les_joueurs_sans_dupliquer() -> void:
	var s := _service()
	_annoncer(s, A, 7777, "Avant", true, 1)
	_avancer(10_000)
	verifier_egal(_annoncer(s, A, 7777, "Après", true, 4), 0)
	verifier_egal(s.nb_entrees(), 1)
	verifier_egal(s.salons()[0]["nom"], "Après")
	verifier_egal(s.salons()[0]["joueurs"], 4)


# --- Expiration --------------------------------------------------------------------------------


func test_une_entree_expire_a_trente_secondes_pile() -> void:
	var s := _service()
	_annoncer(s, A)
	_avancer(29_999)
	verifier_egal(s.salons().size(), 1, "présente à 29,999 s")
	_avancer(1)
	verifier_egal(s.salons().size(), 0, "absente à 30 s")
	s.purger()
	verifier_egal(s.nb_entrees(), 0)


func test_une_annonce_repousse_l_expiration_de_trente_secondes() -> void:
	var s := _service()
	_annoncer(s, A)
	for i: int in 5:
		_avancer(10_000)
		verifier_egal(_annoncer(s, A), 0)
	verifier_egal(s.salons().size(), 1, "annonces toutes les 10 s : jamais expirée")
	_avancer(29_999)
	verifier_egal(s.salons().size(), 1)
	_avancer(1)
	verifier_egal(s.salons().size(), 0)


func test_un_retrait_supprime_l_entree_de_la_cle() -> void:
	var s := _service()
	_annoncer(s, A, 7777)
	_annoncer(s, A, 7778)
	verifier_egal(_retirer(s, A, 7777), 0)
	verifier_egal(_liste_ip_port(s), ["8.8.8.8:7778"])


func test_un_retrait_d_une_entree_inconnue_repond_0_sans_rien_changer() -> void:
	var s := _service()
	_annoncer(s, A, 7777)
	verifier_egal(_retirer(s, B, 7777), 0, "autre IP")
	verifier_egal(_retirer(s, A, 9999), 0, "autre port")
	verifier_egal(s.nb_entrees(), 1)


func test_la_liste_ne_renvoie_que_les_entrees_non_expirees() -> void:
	var s := _service()
	_annoncer(s, A)
	_avancer(20_000)
	_annoncer(s, B)
	_avancer(10_000)
	verifier_egal(_liste_ip_port(s), ["8.8.4.4:7777"])


# --- Sonde de joignabilité ---------------------------------------------------------------------


func test_une_annonce_n_est_listee_qu_apres_la_sonde() -> void:
	var s := _service()
	var r := s.evaluer(A, _annonce())
	verifier_egal(r["action"], AnnuaireService.Action.SONDER)
	verifier_egal(r["ip"], A)
	verifier_egal(r["port"], 7777)
	verifier_egal(s.salons().size(), 0, "pas listée avant la sonde")
	verifier_egal(s.nb_sondes(), 1)
	var rep := AnnuaireProtocole.decoder_reponse(s.sonde_terminee(r["ticket"], true))
	verifier_egal(rep["statut"], 0)
	verifier_egal(s.salons().size(), 1)
	verifier_egal(s.nb_sondes(), 0)


func test_une_sonde_en_echec_donne_la_reponse_2_et_aucune_entree() -> void:
	var s := _service()
	verifier_egal(_annoncer(s, A, 7777, "Salon", false), 2)
	verifier_egal(s.salons().size(), 0)


func test_un_echec_reste_valable_30_secondes_sans_nouvelle_sonde() -> void:
	var s := _service()
	_annoncer(s, A, 7777, "Salon", false)
	_avancer(10_000)
	var r := s.evaluer(A, _annonce())
	verifier_egal(r["action"], AnnuaireService.Action.REPONDRE, "pas de sonde")
	verifier_egal(_statut(r), 2)
	_avancer(19_999)
	verifier_egal(_statut(s.evaluer(A, _annonce())), 2, "encore 2 à 29,999 s")
	_avancer(1)
	verifier_egal(s.evaluer(A, _annonce())["action"], AnnuaireService.Action.SONDER, "30 s : sonde")


func test_un_succes_reste_valable_120_secondes_puis_on_reverifie() -> void:
	var s := _service()
	_annoncer(s, A)
	for i: int in 11:
		_avancer(10_000)
		var r := s.evaluer(A, _annonce())
		verifier_egal(
			r["action"], AnnuaireService.Action.REPONDRE, "t = %d s : pas de sonde" % ((i + 1) * 10)
		)
		verifier_egal(_statut(r), 0)
	_avancer(9_999)
	verifier_egal(_statut(s.evaluer(A, _annonce())), 0, "à 119,999 s")
	_avancer(1)
	var r120 := s.evaluer(A, _annonce())
	verifier_egal(r120["action"], AnnuaireService.Action.SONDER, "à 120 s : re-vérification")


func test_une_re_verification_en_echec_supprime_l_entree() -> void:
	var s := _service()
	_annoncer(s, A)
	for i: int in 11:
		_avancer(10_000)
		_annoncer(s, A)
	_avancer(10_000)
	verifier_egal(_annoncer(s, A, 7777, "Salon", false), 2)
	verifier_egal(s.nb_entrees(), 0)


func test_la_cinquieme_sonde_simultanee_recoit_la_reponse_7_sans_file() -> void:
	var s := _service()
	var tickets: Array[int] = []
	for i: int in 4:
		var r := s.evaluer("8.8.%d.1" % i, _annonce())
		verifier_egal(r["action"], AnnuaireService.Action.SONDER)
		tickets.append(r["ticket"])
	verifier_egal(s.nb_sondes(), 4)
	var cinq := s.evaluer("8.8.9.1", _annonce())
	verifier_egal(_statut(cinq), 7)
	verifier_egal(s.nb_sondes(), 4, "pas de file d'attente")
	s.sonde_terminee(tickets[0], true)
	verifier_egal(s.evaluer("8.8.9.1", _annonce())["action"], AnnuaireService.Action.SONDER)


func test_une_seconde_annonce_de_la_meme_cle_pendant_sa_sonde_recoit_7() -> void:
	var s := _service()
	verifier_egal(s.evaluer(A, _annonce())["action"], AnnuaireService.Action.SONDER)
	verifier_egal(_statut(s.evaluer(A, _annonce())), 7, "une sonde par couple")
	verifier_egal(s.nb_sondes(), 1)


## `A` est annoncée toutes les 10 s pendant 110 s, puis 4 sondes sont occupées par d'autres IP à
## 120 s, au moment où `A` doit se re-vérifier. Renvoie les tickets des 4 sondes.
func _saturer_a_120_s(s: AnnuaireService, prefixe: String = "8.8") -> Array[int]:
	_annoncer(s, A, 7777, "Avant")
	for i: int in 11:
		_avancer(10_000)
		_annoncer(s, A, 7777, "Avant")
	_avancer(10_000)
	return _occuper_4_sondes(s, prefixe)


func _occuper_4_sondes(s: AnnuaireService, prefixe: String) -> Array[int]:
	var tickets: Array[int] = []
	for i: int in 4:
		var r := s.evaluer("%s.%d.1" % [prefixe, i], _annonce())
		verifier_egal(r["action"], AnnuaireService.Action.SONDER)
		tickets.append(r["ticket"])
	return tickets


func test_une_entree_existante_est_prolongee_une_seule_fois_par_la_reponse_7() -> void:
	var s := _service()
	_saturer_a_120_s(s)
	var debut := _t[0]
	verifier_egal(_statut(s.evaluer(A, _annonce(7777, "Après", 5))), 7)
	verifier_egal(s.nb_entrees(), 1, "la réponse 7 ne supprime pas l'entrée")
	verifier_egal(s.salons()[0]["nom"], "Avant", "nom non mis à jour sans sonde")
	verifier_egal(s.salons()[0]["joueurs"], 1)
	_avancer(10_000)
	verifier_egal(_statut(s.evaluer(A, _annonce())), 7, "deuxième 7 de suite")
	_avancer(19_999)
	verifier_egal(s.salons().size(), 1, "prolongée une fois : 30 s après la première 7")
	_t[0] = debut + 30_000
	verifier_egal(s.salons().size(), 0, "la deuxième 7 n'a pas prolongé")


func test_une_sonde_reussie_remet_a_zero_le_compte_des_reponses_7() -> void:
	var s := _service()
	var tickets := _saturer_a_120_s(s)
	verifier_egal(_statut(s.evaluer(A, _annonce())), 7)
	for ticket: int in tickets:
		s.sonde_terminee(ticket, true)
	_avancer(10_000)
	verifier_egal(_annoncer(s, A, 7777, "Nouveau"), 0, "la re-vérification aboutit")
	verifier_egal(s.salons()[0]["nom"], "Nouveau")
	for i: int in 11:
		_avancer(10_000)
		_annoncer(s, A)
	_avancer(10_000)
	_occuper_4_sondes(s, "9.9")
	verifier_egal(_statut(s.evaluer(A, _annonce())), 7)
	var premiere_7 := _t[0]
	_avancer(29_999)
	verifier(
		_liste_ip_port(s).has("8.8.8.8:7777"), "prolongée de nouveau : le compte était remis à zéro"
	)
	_t[0] = premiere_7 + 30_000
	verifier_faux(_liste_ip_port(s).has("8.8.8.8:7777"))


func test_une_annonce_invalide_ou_refusee_par_le_debit_ne_lance_aucune_sonde() -> void:
	var s := _service()
	var mauvais_port := PackedByteArray([0x41, 1, 0x01, 2, 1, 8, 0x00, 0x00, 1, 0x61])
	var cadre := PackedByteArray([mauvais_port.size(), 0])
	cadre.append_array(mauvais_port)
	verifier_egal(_statut(s.evaluer(A, cadre)), 4)
	verifier_egal(s.nb_sondes(), 0)
	for i: int in 3:
		_retirer(s, B)
	verifier_egal(_statut(s.evaluer(B, _annonce())), 3, "débit épuisé")
	verifier_egal(s.nb_sondes(), 0)


func test_un_resultat_de_sonde_inconnu_est_ignore() -> void:
	var s := _service()
	verifier(s.sonde_terminee(12345, true).is_empty())


# --- Adresses publiques ------------------------------------------------------------------------


func test_chaque_plage_non_publique_est_refusee_avec_la_reponse_6() -> void:
	for plage: Array in PLAGES_NON_PUBLIQUES:
		for extremite: int in [0, 1]:
			var ip := plage[extremite] as String
			var s := _service()
			verifier_egal(_statut(s.evaluer(ip, _annonce())), 6, "%s (%s)" % [ip, plage[2]])
			verifier_egal(s.nb_sondes(), 0)
			verifier_faux(AnnuaireService.est_publique(ip), ip)


func test_les_adresses_voisines_des_plages_non_publiques_sont_acceptees() -> void:
	for ip: String in VOISINES_PUBLIQUES:
		verifier(AnnuaireService.est_publique(ip), ip)
		var s := _service()
		verifier_egal(s.evaluer(ip, _annonce())["action"], AnnuaireService.Action.SONDER, ip)


func test_une_adresse_mal_formee_n_est_pas_publique() -> void:
	var mauvaises: Array[String] = [
		"", "8.8.8", "8.8.8.8.8", "256.1.1.1", "a.b.c.d", "::1", "2001:db8::1", "8.8.8.-1"
	]
	for ip: String in mauvaises:
		verifier_faux(AnnuaireService.est_publique(ip), "« %s »" % ip)


func test_les_adresses_ipv4_mappees_en_ipv6_sont_ramenees_a_l_ipv4() -> void:
	var formes := {
		"::ffff:8.8.8.8": "8.8.8.8",
		"::FFFF:8.8.8.8": "8.8.8.8",
		"::ffff:808:808": "8.8.8.8",
		"0:0:0:0:0:ffff:8.8.8.8": "8.8.8.8",
		"::ffff:10.0.0.1": "10.0.0.1",
		"8.8.8.8": "8.8.8.8",
		"::1": "::1",
		"2001:db8::1": "2001:db8::1",
	}
	for forme: String in formes:
		verifier_egal(AnnuaireService.normaliser_ip(forme), formes[forme], forme)


func test_une_annonce_d_une_ip_mappee_est_listee_sous_son_ipv4() -> void:
	var s := _service()
	verifier_egal(_annoncer(s, "::ffff:8.8.8.8"), 0)
	verifier_egal(_liste_ip_port(s), ["8.8.8.8:7777"])
	# Même clé que l'IPv4 directe : une seule entrée.
	_avancer(5_000)
	verifier_egal(_annoncer(s, "8.8.8.8"), 0)
	verifier_egal(s.nb_entrees(), 1)


func test_une_ip_mappee_privee_ou_une_ipv6_pure_recoit_la_reponse_6() -> void:
	var s := _service()
	verifier_egal(_statut(s.evaluer("::ffff:10.0.0.1", _annonce())), 6)
	verifier_egal(_statut(s.evaluer("::ffff:127.0.0.1", _annonce())), 6)
	verifier_egal(_statut(s.evaluer("2001:db8::1", _annonce())), 6)


func test_l_option_autoriser_prive_desactive_le_seul_rejet_d_adresse() -> void:
	for plage: Array in PLAGES_NON_PUBLIQUES:
		var s := _service(true)
		var ip := plage[0] as String
		verifier_egal(s.evaluer(ip, _annonce())["action"], AnnuaireService.Action.SONDER, ip)
	var s2 := _service(true)
	verifier_egal(_annoncer(s2, "127.0.0.1"), 0)
	verifier_egal(_liste_ip_port(s2), ["127.0.0.1:7777"])
