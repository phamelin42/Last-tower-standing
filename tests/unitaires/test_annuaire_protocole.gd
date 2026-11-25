extends CasDeTest
## Codec de l'annuaire : cadre `u16 taille · corps`, cinq messages, bornes de champ, décodage
## défensif. Les octets attendus sont écrits à la main (ADR 001, § Protocole), pas recalculés par
## le code testé. Le fuzz a une graine fixe.

const GRAINE: int = 20261125
const TYPES_REQUETE: Array[int] = [0x01, 0x02, 0x03]


func _annonce(
	nom: String = "Salon", joueurs: int = 1, maximum: int = 8, port: int = 7777, v_jeu: int = 2
) -> PackedByteArray:
	return AnnuaireProtocole.encoder_annonce(v_jeu, joueurs, maximum, port, nom)


## Corps d'une annonce écrit octet par octet, hors du codec.
func _corps_annonce(
	nom_octets: PackedByteArray, joueurs: int, maximum: int, port: int
) -> PackedByteArray:
	var b := PackedByteArray([0x41, 1, 0x01, 2, joueurs, maximum, port & 0xFF, port >> 8])
	b.append(nom_octets.size())
	b.append_array(nom_octets)
	return b


func _cadre(corps: PackedByteArray) -> PackedByteArray:
	var b := PackedByteArray([corps.size() & 0xFF, corps.size() >> 8])
	b.append_array(corps)
	return b


# --- Constantes et octets exacts -----------------------------------------------------------------


func test_les_constantes_sont_celles_de_l_adr() -> void:
	verifier_egal(AnnuaireProtocole.MAGIE, 0x41)
	verifier_egal(AnnuaireProtocole.VERSION, 1)
	verifier_egal(AnnuaireProtocole.PORT_DEFAUT, 7779)
	verifier_egal(AnnuaireProtocole.MAX_CORPS_REQUETE, 128)
	verifier_egal(AnnuaireProtocole.MAX_CADRE_CLIENT, 16384)
	verifier_egal(AnnuaireProtocole.MAX_SALONS, 100)


func test_une_annonce_a_les_octets_attendus() -> void:
	var attendu := _cadre(_corps_annonce("Ab".to_utf8_buffer(), 3, 8, 0x1E61))
	verifier_egal(_annonce("Ab", 3, 8, 0x1E61), attendu)
	# 2 (taille) + 3 (en-tête) + 1 + 1 + 1 + 2 + 1 + 2 octets de nom.
	verifier_egal(attendu.size(), 13)
	verifier_egal(attendu[0], 11, "taille du corps, petit-boutiste")
	verifier_egal(attendu[1], 0)


func test_un_retrait_une_liste_et_une_reponse_ont_les_octets_attendus() -> void:
	verifier_egal(
		AnnuaireProtocole.encoder_retrait(7777), PackedByteArray([5, 0, 0x41, 1, 0x02, 0x61, 0x1E])
	)
	verifier_egal(AnnuaireProtocole.encoder_liste(), PackedByteArray([3, 0, 0x41, 1, 0x03]))
	verifier_egal(
		AnnuaireProtocole.encoder_reponse(2), PackedByteArray([5, 0, 0x41, 1, 0x81, 2, 1])
	)


func test_la_liste_de_salons_a_les_octets_attendus() -> void:
	var salons: Array[Dictionary] = [
		{"ip": "8.8.4.4", "port": 7777, "version_jeu": 2, "joueurs": 1, "max": 4, "nom": "é"},
	]
	var attendu := PackedByteArray(
		[0x41, 1, 0x83, 1, 8, 8, 4, 4, 0x61, 0x1E, 2, 1, 4, 2, 0xC3, 0xA9]
	)
	verifier_egal(AnnuaireProtocole.encoder_salons(salons), _cadre(attendu))


# --- Aller-retour ----------------------------------------------------------------------------


func test_une_annonce_fait_l_aller_retour_pour_chaque_effectif() -> void:
	for maximum: int in range(1, Salon.MAX_JOUEURS + 1):
		for joueurs: int in range(0, maximum + 1):
			var cadre := _annonce("Salon é « 日本 »", joueurs, maximum, 65535, 9)
			var analyse := AnnuaireProtocole.analyser(cadre)
			verifier_egal(analyse["etat"], AnnuaireProtocole.Analyse.COMPLET)
			var d := AnnuaireProtocole.decoder_annonce(analyse["corps"])
			verifier_egal(d.get("nom"), "Salon é « 日本 »")
			verifier_egal(d.get("joueurs"), joueurs)
			verifier_egal(d.get("max"), maximum)
			verifier_egal(d.get("port"), 65535)
			verifier_egal(d.get("version_jeu"), 9)


func test_un_retrait_fait_l_aller_retour() -> void:
	for port: int in [1024, 7777, 65535]:
		var analyse := AnnuaireProtocole.analyser(AnnuaireProtocole.encoder_retrait(port))
		verifier_egal(AnnuaireProtocole.type_de(analyse["corps"]), AnnuaireProtocole.Type.RETRAIT)
		verifier_egal(AnnuaireProtocole.decoder_retrait(analyse["corps"]).get("port"), port)


func test_une_liste_fait_l_aller_retour() -> void:
	var analyse := AnnuaireProtocole.analyser(AnnuaireProtocole.encoder_liste())
	verifier_egal(AnnuaireProtocole.type_de(analyse["corps"]), AnnuaireProtocole.Type.LISTE)
	verifier(AnnuaireProtocole.decoder_liste(analyse["corps"]))


func test_chaque_statut_de_reponse_fait_l_aller_retour() -> void:
	for statut: int in range(0, 8):
		var d := AnnuaireProtocole.decoder_reponse(AnnuaireProtocole.encoder_reponse(statut))
		verifier_egal(d.get("statut"), statut)
		verifier_egal(d.get("version_service"), AnnuaireProtocole.VERSION)


func test_un_statut_inconnu_n_est_ni_encode_ni_decode() -> void:
	verifier(AnnuaireProtocole.encoder_reponse(8).is_empty())
	verifier(AnnuaireProtocole.encoder_reponse(-1).is_empty())
	verifier(
		AnnuaireProtocole.decoder_reponse(PackedByteArray([5, 0, 0x41, 1, 0x81, 8, 1])).is_empty()
	)


func _salon(i: int) -> Dictionary:
	return {
		"ip": "8.8.%d.%d" % [i / 256, i % 256],
		"port": 1024 + i,
		"version_jeu": i % 256,
		"joueurs": i % 5,
		"max": 4 + i % 5,
		"nom": "Salon %d é" % i,
	}


func test_une_liste_de_zero_a_cent_salons_fait_l_aller_retour() -> void:
	for n: int in range(0, 101):
		var salons: Array[Dictionary] = []
		for i: int in n:
			salons.append(_salon(i))
		var cadre := AnnuaireProtocole.encoder_salons(salons)
		var d := AnnuaireProtocole.decoder_salons(cadre)
		verifier_egal(d.get("salons"), salons, "%d salons" % n)


func test_cent_salons_aux_noms_les_plus_longs_tiennent_dans_la_taille_de_l_adr() -> void:
	var salons: Array[Dictionary] = []
	for i: int in 100:
		var s := _salon(i)
		s["nom"] = "😀".repeat(24)
		salons.append(s)
	var cadre := AnnuaireProtocole.encoder_salons(salons)
	verifier_egal(cadre.size(), 2 + 10604, "le plus grand cadre légitime")
	verifier(cadre.size() - 2 <= AnnuaireProtocole.MAX_CADRE_CLIENT)
	verifier_egal(AnnuaireProtocole.decoder_salons(cadre).get("salons"), salons)


func test_cent_un_salons_ne_s_encodent_pas() -> void:
	var salons: Array[Dictionary] = []
	for i: int in 101:
		salons.append(_salon(i))
	verifier(AnnuaireProtocole.encoder_salons(salons).is_empty())


# --- Bornes de champ ---------------------------------------------------------------------------


func test_le_nom_de_24_caracteres_passe_et_celui_de_25_est_refuse() -> void:
	var nom24 := "é".repeat(24)
	verifier_egal(
		AnnuaireProtocole.decoder_annonce(AnnuaireProtocole.analyser(_annonce(nom24))["corps"]).get(
			"nom"
		),
		nom24
	)
	verifier(_annonce("é".repeat(25)).is_empty(), "l'encodeur refuse 25 caractères")
	var corps := _corps_annonce(("é".repeat(25)).to_utf8_buffer(), 1, 8, 7777)
	verifier(AnnuaireProtocole.decoder_annonce(corps).is_empty(), "le décodeur aussi (50 octets)")
	var corps_ascii := _corps_annonce(("a".repeat(25)).to_utf8_buffer(), 1, 8, 7777)
	verifier(AnnuaireProtocole.decoder_annonce(corps_ascii).is_empty())
	var corps24 := _corps_annonce(("a".repeat(24)).to_utf8_buffer(), 1, 8, 7777)
	verifier_egal(AnnuaireProtocole.decoder_annonce(corps24).get("nom"), "a".repeat(24))


func test_un_nom_vide_est_refuse() -> void:
	verifier(_annonce("").is_empty())
	verifier(
		AnnuaireProtocole.decoder_annonce(_corps_annonce(PackedByteArray(), 1, 8, 7777)).is_empty()
	)


func test_un_nom_avec_un_caractere_de_controle_est_refuse() -> void:
	for c: int in range(0, 32):
		var octets := PackedByteArray([0x61, c, 0x62])
		verifier(
			AnnuaireProtocole.decoder_annonce(_corps_annonce(octets, 1, 8, 7777)).is_empty(),
			"contrôle %d" % c
		)
		if c != 0:
			verifier(_annonce("a" + char(c) + "b").is_empty(), "encodeur, contrôle %d" % c)
	var del := PackedByteArray([0x61, 127])
	verifier(AnnuaireProtocole.decoder_annonce(_corps_annonce(del, 1, 8, 7777)).is_empty())


func test_un_nom_en_utf8_invalide_est_refuse() -> void:
	var invalides: Array[PackedByteArray] = [
		PackedByteArray([0xFF]),
		PackedByteArray([0xC3]),
		PackedByteArray([0xC0, 0x80]),
		PackedByteArray([0xE2, 0x82]),
		PackedByteArray([0xED, 0xA0, 0x80]),
		PackedByteArray([0xF4, 0x90, 0x80, 0x80]),
		PackedByteArray([0x61, 0x80]),
	]
	for octets: PackedByteArray in invalides:
		verifier(
			AnnuaireProtocole.decoder_annonce(_corps_annonce(octets, 1, 8, 7777)).is_empty(),
			"octets %s" % str(octets)
		)


func test_le_port_est_borne_entre_1024_et_65535() -> void:
	for port: int in [0, 1, 1023, 65536, -1]:
		verifier(_annonce("Salon", 1, 8, port).is_empty(), "encodeur, port %d" % port)
		verifier(AnnuaireProtocole.encoder_retrait(port).is_empty(), "retrait, port %d" % port)
	for port: int in [0, 1, 1023]:
		var corps := _corps_annonce("S".to_utf8_buffer(), 1, 8, port)
		verifier(AnnuaireProtocole.decoder_annonce(corps).is_empty(), "annonce, port %d" % port)
		var retrait := PackedByteArray([0x41, 1, 0x02, port & 0xFF, port >> 8])
		verifier(AnnuaireProtocole.decoder_retrait(retrait).is_empty(), "retrait, port %d" % port)
	for port: int in [1024, 1025, 65535]:
		var corps := _corps_annonce("S".to_utf8_buffer(), 1, 8, port)
		verifier_egal(AnnuaireProtocole.decoder_annonce(corps).get("port"), port)
		var retrait := PackedByteArray([0x41, 1, 0x02, port & 0xFF, port >> 8])
		verifier_egal(AnnuaireProtocole.decoder_retrait(retrait).get("port"), port)


func test_les_effectifs_hors_bornes_sont_refuses() -> void:
	for maximum: int in [0, 9, 255]:
		verifier(_annonce("S", 0, maximum).is_empty(), "encodeur, max %d" % maximum)
		var corps := _corps_annonce("S".to_utf8_buffer(), 0, maximum, 7777)
		verifier(AnnuaireProtocole.decoder_annonce(corps).is_empty(), "décodeur, max %d" % maximum)
	for maximum: int in range(1, 9):
		var trop := _corps_annonce("S".to_utf8_buffer(), maximum + 1, maximum, 7777)
		verifier(AnnuaireProtocole.decoder_annonce(trop).is_empty(), "joueurs > max %d" % maximum)
		verifier(_annonce("S", maximum + 1, maximum).is_empty())
	verifier(_annonce("S", -1, 4).is_empty())


func test_un_reste_non_nul_dans_le_corps_est_refuse() -> void:
	var corps := _corps_annonce("Salon".to_utf8_buffer(), 1, 8, 7777)
	corps.append(0)
	verifier(AnnuaireProtocole.decoder_annonce(corps).is_empty())
	var retrait := PackedByteArray([0x41, 1, 0x02, 0x61, 0x1E, 0])
	verifier(AnnuaireProtocole.decoder_retrait(retrait).is_empty())
	verifier_faux(AnnuaireProtocole.decoder_liste(PackedByteArray([0x41, 1, 0x03, 0])))


func test_un_corps_tronque_a_chaque_octet_est_refuse_sans_exception() -> void:
	var corps := AnnuaireProtocole.analyser(_annonce("Salon é"))["corps"] as PackedByteArray
	for n: int in range(0, corps.size()):
		verifier(
			AnnuaireProtocole.decoder_annonce(corps.slice(0, n)).is_empty(),
			"annonce tronquée à %d" % n
		)
	var retrait := (
		AnnuaireProtocole.analyser(AnnuaireProtocole.encoder_retrait(7777))["corps"]
		as PackedByteArray
	)
	for n: int in range(0, retrait.size()):
		verifier(AnnuaireProtocole.decoder_retrait(retrait.slice(0, n)).is_empty())
	var liste := (
		AnnuaireProtocole.analyser(AnnuaireProtocole.encoder_liste())["corps"] as PackedByteArray
	)
	for n: int in range(0, liste.size()):
		verifier_faux(AnnuaireProtocole.decoder_liste(liste.slice(0, n)))


func test_un_en_tete_faux_est_refuse_par_chaque_decodeur() -> void:
	var corps := AnnuaireProtocole.analyser(_annonce())["corps"] as PackedByteArray
	for position: int in range(0, 3):
		var casse := corps.duplicate()
		casse[position] = casse[position] ^ 0x10
		verifier(AnnuaireProtocole.decoder_annonce(casse).is_empty(), "octet %d" % position)
	verifier_egal(AnnuaireProtocole.type_de(PackedByteArray([0x41, 1, 0x04])), -1)
	verifier_egal(AnnuaireProtocole.type_de(PackedByteArray([0x42, 1, 0x01])), -1)
	verifier_egal(AnnuaireProtocole.type_de(PackedByteArray([0x41, 2, 0x01])), -1)
	verifier_egal(AnnuaireProtocole.type_de(PackedByteArray([0x41, 1])), -1)
	for type: int in TYPES_REQUETE:
		verifier_egal(AnnuaireProtocole.type_de(PackedByteArray([0x41, 1, type])), type)
	# Les types de réponse ne sont pas des requêtes.
	verifier_egal(AnnuaireProtocole.type_de(PackedByteArray([0x41, 1, 0x81])), -1)
	verifier_egal(AnnuaireProtocole.type_de(PackedByteArray([0x41, 1, 0x83])), -1)


# --- Analyse du flux entrant ---------------------------------------------------------------------


func test_un_message_vide_attend() -> void:
	verifier_egal(
		AnnuaireProtocole.analyser(PackedByteArray())["etat"], AnnuaireProtocole.Analyse.ATTENTE
	)


func test_une_annonce_tronquee_a_chaque_octet_attend_puis_est_complete() -> void:
	var cadre := _annonce("Salon é")
	for n: int in range(0, cadre.size()):
		var etat := AnnuaireProtocole.analyser(cadre.slice(0, n))["etat"] as int
		verifier_egal(etat, AnnuaireProtocole.Analyse.ATTENTE, "tronquée à %d octets" % n)
	verifier_egal(AnnuaireProtocole.analyser(cadre)["etat"], AnnuaireProtocole.Analyse.COMPLET)


func test_un_octet_de_trop_apres_le_cadre_est_ignore() -> void:
	var cadre := AnnuaireProtocole.encoder_liste()
	cadre.append(0xAA)
	var analyse := AnnuaireProtocole.analyser(cadre)
	verifier_egal(analyse["etat"], AnnuaireProtocole.Analyse.COMPLET)
	verifier_egal((analyse["corps"] as PackedByteArray).size(), 3)


func test_une_taille_inferieure_a_3_ferme_des_le_prefixe() -> void:
	for taille: int in [0, 1, 2]:
		var etat := AnnuaireProtocole.analyser(PackedByteArray([taille, 0]))["etat"] as int
		verifier_egal(etat, AnnuaireProtocole.Analyse.FERMER, "taille %d" % taille)


func test_une_mauvaise_magie_ferme_des_les_trois_octets_d_en_tete() -> void:
	verifier_egal(
		AnnuaireProtocole.analyser(PackedByteArray([3, 0, 0x42, 1, 3]))["etat"],
		AnnuaireProtocole.Analyse.FERMER
	)
	# L'en-tête incomplet attend, même si l'on sait déjà que la magie est fausse.
	verifier_egal(
		AnnuaireProtocole.analyser(PackedByteArray([3, 0, 0x42]))["etat"],
		AnnuaireProtocole.Analyse.ATTENTE
	)


func test_une_autre_version_est_reconnue_quelle_que_soit_la_taille() -> void:
	for taille: int in [3, 5, 128, 129, 1000, 65535]:
		var octets := PackedByteArray([taille & 0xFF, taille >> 8, 0x41, 2, 0x01])
		verifier_egal(
			AnnuaireProtocole.analyser(octets)["etat"],
			AnnuaireProtocole.Analyse.VERSION_DIFFERENTE,
			"taille %d" % taille
		)


func test_le_corps_de_128_octets_passe_et_celui_de_129_est_trop_grand() -> void:
	var tout := PackedByteArray([128, 0, 0x41, 1, 0x01])
	tout.resize(2 + 128)
	verifier_egal(AnnuaireProtocole.analyser(tout)["etat"], AnnuaireProtocole.Analyse.COMPLET)
	# Au-delà de 128, rien de plus n'est lu : l'en-tête suffit pour trancher.
	var trop := PackedByteArray([129, 0, 0x41, 1, 0x01])
	verifier_egal(AnnuaireProtocole.analyser(trop)["etat"], AnnuaireProtocole.Analyse.TROP_GRAND)
	var enorme := PackedByteArray([0xFF, 0xFF, 0x41, 1, 0x01])
	verifier_egal(AnnuaireProtocole.analyser(enorme)["etat"], AnnuaireProtocole.Analyse.TROP_GRAND)


func test_un_corps_incomplet_de_128_octets_attend() -> void:
	var octets := PackedByteArray([128, 0, 0x41, 1, 0x01, 0, 0])
	verifier_egal(AnnuaireProtocole.analyser(octets)["etat"], AnnuaireProtocole.Analyse.ATTENTE)


# --- Côté client ---------------------------------------------------------------------------------


func test_le_client_reconnait_une_version_de_service_differente() -> void:
	var cadre := AnnuaireProtocole.encoder_reponse(1)
	verifier_egal(AnnuaireProtocole.version_du_cadre(cadre), AnnuaireProtocole.VERSION)
	cadre[3] = 2
	verifier_egal(AnnuaireProtocole.version_du_cadre(cadre), 2)
	verify_decoder_refuse_version(cadre)
	verifier_egal(
		AnnuaireProtocole.version_du_cadre(PackedByteArray([5, 0, 0x42, 1, 0x81, 1, 1])), -1
	)
	verifier_egal(AnnuaireProtocole.version_du_cadre(PackedByteArray([5, 0, 0x41])), -1)


func verify_decoder_refuse_version(cadre: PackedByteArray) -> void:
	verifier(AnnuaireProtocole.decoder_reponse(cadre).is_empty())
	verifier(AnnuaireProtocole.decoder_salons(cadre).is_empty())


func test_le_client_refuse_un_cadre_dont_la_taille_ment() -> void:
	var cadre := AnnuaireProtocole.encoder_reponse(0)
	cadre.append(0)
	verifier(AnnuaireProtocole.decoder_reponse(cadre).is_empty(), "octet en trop")
	verifier(
		AnnuaireProtocole.decoder_reponse(cadre.slice(0, cadre.size() - 2)).is_empty(), "tronqué"
	)
	verifier(AnnuaireProtocole.decoder_reponse(PackedByteArray()).is_empty())
	var long := PackedByteArray([0x01, 0x40, 0x41, 1, 0x83, 0])
	long.resize(2 + 16385)
	verifier(AnnuaireProtocole.decoder_salons(long).is_empty(), "plus de 16 384 octets de corps")


func test_les_salons_hors_bornes_sont_refuses_par_le_client() -> void:
	var base: Array[Dictionary] = [_salon(0)]
	var cadre := AnnuaireProtocole.encoder_salons(base)
	verifier_egal(AnnuaireProtocole.decoder_salons(cadre).get("salons"), base)
	# n = 101
	var trop := PackedByteArray(cadre)
	trop[5] = 101
	verifier(AnnuaireProtocole.decoder_salons(trop).is_empty())
	# n annoncé supérieur au contenu
	var vide := _cadre(PackedByteArray([0x41, 1, 0x83, 2]))
	verifier(AnnuaireProtocole.decoder_salons(vide).is_empty())
	# port 1 023, joueurs > max, nom de contrôle
	var modifs: Array[Dictionary] = [
		{"port": 1023}, {"joueurs": 9, "max": 8}, {"max": 0}, {"nom": "a\tb"}, {"nom": ""}
	]
	for m: Dictionary in modifs:
		var s := _salon(0)
		s.merge(m, true)
		var octets := _octets_salon_brut(s)
		verifier(AnnuaireProtocole.decoder_salons(octets).is_empty(), "salon %s" % str(m))


## Un cadre SALONS d'un salon, écrit hors du codec pour passer des champs que l'encodeur refuse.
func _octets_salon_brut(s: Dictionary) -> PackedByteArray:
	var nom := (s["nom"] as String).to_utf8_buffer()
	var corps := PackedByteArray([0x41, 1, 0x83, 1, 8, 8, 8, 8])
	corps.append(int(s["port"]) & 0xFF)
	corps.append(int(s["port"]) >> 8)
	corps.append_array(
		PackedByteArray([int(s["version_jeu"]), int(s["joueurs"]), int(s["max"]), nom.size()])
	)
	corps.append_array(nom)
	return _cadre(corps)


func test_une_ip_de_salon_est_ecrite_sur_quatre_octets() -> void:
	var s := _salon(0)
	s["ip"] = "203.0.113.200"
	var cadre := AnnuaireProtocole.encoder_salons([s])
	verifier_egal(cadre.slice(6, 10), PackedByteArray([203, 0, 113, 200]))
	var mauvaises: Array[String] = [
		"", "1.2.3", "1.2.3.4.5", "256.1.1.1", "a.b.c.d", "1.2.3.-4", "::1"
	]
	for ip: String in mauvaises:
		s["ip"] = ip
		verifier(AnnuaireProtocole.encoder_salons([s]).is_empty(), "ip « %s »" % ip)


# --- Fuzz à graine fixe --------------------------------------------------------------------------


func test_des_octets_aleatoires_ne_provoquent_aucune_exception() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var modele := _annonce("Salon é")
	for i: int in 2000:
		var taille := rng.randi_range(0, 140)
		var octets := PackedByteArray()
		octets.resize(taille)
		for k: int in taille:
			octets[k] = rng.randi_range(0, 255)
		if i % 2 == 0 and taille >= 5:
			# Un en-tête plausible pour pousser l'octet aléatoire jusqu'aux décodeurs de champ.
			octets[0] = (taille - 2) & 0xFF
			octets[1] = 0
			octets[2] = 0x41
			octets[3] = 1
			octets[4] = TYPES_REQUETE[rng.randi_range(0, 2)]
		var analyse := AnnuaireProtocole.analyser(octets)
		if analyse["etat"] == AnnuaireProtocole.Analyse.COMPLET:
			var corps := analyse["corps"] as PackedByteArray
			AnnuaireProtocole.decoder_annonce(corps)
			AnnuaireProtocole.decoder_retrait(corps)
			AnnuaireProtocole.decoder_liste(corps)
			AnnuaireProtocole.type_de(corps)
		AnnuaireProtocole.decoder_reponse(octets)
		AnnuaireProtocole.decoder_salons(octets)
		# Mutation d'un cadre valide : un octet change, le décodeur répond sans exception.
		var mute := modele.duplicate()
		mute[rng.randi_range(0, mute.size() - 1)] = rng.randi_range(0, 255)
		var a2 := AnnuaireProtocole.analyser(mute)
		if a2["etat"] == AnnuaireProtocole.Analyse.COMPLET:
			AnnuaireProtocole.decoder_annonce(a2["corps"])
	verifier(true, "aucune exception")
