extends CasDeTest
## Découverte des salons du réseau local : annonce UDP bornée, décodage défensif, liste qui
## expire, et un vrai échange UDP sur la boucle locale (émission directe vers 127.0.0.1 : la
## diffusion 255.255.255.255 dépend du conteneur, elle n'est donc pas testée ici).

const GRAINE := 20261125

var _horloge: Array[float] = [0.0]


func _chercheur() -> Decouverte:
	var c := Decouverte.new()
	c.horloge = func() -> float: return _horloge[0]
	_horloge[0] = 100.0
	return c


# --- Encodage et décodage ----------------------------------------------------------------------


func test_une_annonce_fait_l_aller_retour() -> void:
	for m: int in range(1, Salon.MAX_JOUEURS + 1):
		for n: int in range(0, m + 1):
			var d := Decouverte.decoder(Decouverte.encoder("Salon é « 日本 »", n, m, 7777))
			verifier_egal(d.get("nom"), "Salon é « 日本 »")
			verifier_egal(d.get("joueurs"), n)
			verifier_egal(d.get("max"), m)
			verifier_egal(d.get("port"), 7777)


func test_une_annonce_reste_petite_meme_avec_le_nom_le_plus_long() -> void:
	var octets := Decouverte.encoder("😀".repeat(100), 8, 8, 65535)
	verifier(octets.size() <= Decouverte.MAX_TAILLE, "taille %d" % octets.size())
	var d := Decouverte.decoder(octets)
	verifier_egal(String(d.get("nom")).length(), Protocole.MAX_NOM, "nom tronqué à 24 caractères")


func test_une_annonce_d_une_autre_version_est_ignoree() -> void:
	var octets := Decouverte.encoder("Salon", 1, 8, 7777)
	octets[1] = Protocole.VERSION + 1
	verifier_egal(Decouverte.decoder(octets), {})


func test_chaque_annonce_incoherente_est_ignoree() -> void:
	verifier_egal(Decouverte.decoder(PackedByteArray()), {}, "vide")
	var port_nul := Decouverte.encoder("Salon", 1, 8, 7777)
	port_nul.encode_u16(4, 0)
	verifier_egal(Decouverte.decoder(port_nul), {}, "port 0")
	var plus_que_max := Decouverte.encoder("Salon", 1, 8, 7777)
	plus_que_max[2] = 9
	verifier_egal(Decouverte.decoder(plus_que_max), {}, "9 joueurs sur 8")
	var max_zero := Decouverte.encoder("Salon", 0, 8, 7777)
	max_zero[3] = 0
	verifier_egal(Decouverte.decoder(max_zero), {}, "maximum nul")
	var max_trop_grand := Decouverte.encoder("Salon", 1, 8, 7777)
	max_trop_grand[3] = Salon.MAX_JOUEURS + 1
	verifier_egal(Decouverte.decoder(max_trop_grand), {}, "maximum au-delà de 8")
	verifier_egal(Decouverte.decoder(Decouverte.encoder("", 1, 8, 7777)), {}, "nom vide")
	var controle := Decouverte.encoder("Salon", 1, 8, 7777)
	controle[7] = 7
	verifier_egal(Decouverte.decoder(controle), {}, "caractère de contrôle")
	var trop := Decouverte.encoder("Salon", 1, 8, 7777)
	trop.append(65)
	verifier_egal(Decouverte.decoder(trop), {}, "octet en trop")


func test_chaque_troncature_et_chaque_octet_altere_ne_plante_jamais() -> void:
	var valide := Decouverte.encoder("Salon de Mina", 3, 8, 7777)
	for longueur: int in valide.size():
		verifier_egal(Decouverte.decoder(valide.slice(0, longueur)), {}, "tronqué à %d" % longueur)
	for i: int in valide.size():
		for valeur: int in [0, 1, 0x7F, 0x80, 0xC0, 0xFF]:
			var o := valide.duplicate()
			o[i] = valeur
			var d := Decouverte.decoder(o)
			if not d.is_empty():
				_verifier_bornes(d)


func test_du_bruit_aleatoire_est_toujours_ignore_ou_borne() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	for k: int in 3000:
		var o := PackedByteArray()
		o.resize(rng.randi_range(0, 300))
		for i: int in o.size():
			o[i] = rng.randi_range(0, 255)
		# Un en-tête plausible une fois sur deux, pour aller plus loin dans le décodeur.
		if k % 2 == 0 and o.size() > 2:
			o[0] = Decouverte.MAGIE
			o[1] = Protocole.VERSION
		var d := Decouverte.decoder(o)
		if not d.is_empty():
			_verifier_bornes(d)
	var gros := PackedByteArray()
	gros.resize(65536)
	verifier_egal(Decouverte.decoder(gros), {}, "65 536 octets")


func _verifier_bornes(d: Dictionary) -> void:
	var nom: String = d["nom"]
	var joueurs: int = d["joueurs"]
	var maxi: int = d["max"]
	var port: int = d["port"]
	verifier(not nom.is_empty() and nom.length() <= Protocole.MAX_NOM, "nom borné")
	verifier(maxi >= 1 and maxi <= Salon.MAX_JOUEURS, "maximum borné")
	verifier(joueurs >= 0 and joueurs <= maxi, "joueurs bornés")
	verifier(port >= 1 and port <= 65535, "port borné")


# --- Liste et expiration -----------------------------------------------------------------------


func test_un_salon_annonce_apparait_avec_son_adresse_et_son_port_de_jeu() -> void:
	var c := _chercheur()
	verifier(c.recevoir(Decouverte.encoder("Salon de Mina", 2, 8, 7790), "192.168.1.20"))
	var liste := c.salons()
	verifier_egal(liste.size(), 1)
	verifier_egal(liste[0]["nom"], "Salon de Mina")
	verifier_egal(liste[0]["joueurs"], 2)
	verifier_egal(liste[0]["max"], 8)
	verifier_egal(liste[0]["adresse"], "192.168.1.20")
	verifier_egal(liste[0]["port"], 7790)
	c.free()


func test_une_annonce_invalide_n_ajoute_rien() -> void:
	var c := _chercheur()
	verifier_faux(c.recevoir(PackedByteArray([1, 2, 3]), "10.0.0.1"))
	var autre := Decouverte.encoder("Salon", 1, 8, 7777)
	autre[1] = 99
	verifier_faux(c.recevoir(autre, "10.0.0.1"))
	verifier_egal(c.salons().size(), 0)
	c.free()


func test_un_salon_disparait_apres_trois_secondes_sans_annonce() -> void:
	var c := _chercheur()
	c.recevoir(Decouverte.encoder("Salon", 2, 8, 7777), "10.0.0.5")
	_horloge[0] += 2.9
	verifier_egal(c.salons().size(), 1, "encore là à 2,9 s")
	_horloge[0] += 0.2
	verifier_egal(c.salons().size(), 0, "disparu après 3 s")
	c.free()


func test_une_nouvelle_annonce_prolonge_et_met_a_jour_le_salon() -> void:
	var c := _chercheur()
	c.recevoir(Decouverte.encoder("Salon", 1, 8, 7777), "10.0.0.5")
	_horloge[0] += 2.0
	c.recevoir(Decouverte.encoder("Salon", 3, 8, 7777), "10.0.0.5")
	_horloge[0] += 2.0
	var liste := c.salons()
	verifier_egal(liste.size(), 1, "un seul salon, pas deux")
	verifier_egal(liste[0]["joueurs"], 3, "le nombre de joueurs est à jour")
	c.free()


func test_trois_salons_donnent_trois_lignes_triees_par_nom() -> void:
	var c := _chercheur()
	c.recevoir(Decouverte.encoder("Zéphyr", 1, 8, 7777), "10.0.0.5")
	c.recevoir(Decouverte.encoder("Alba", 1, 8, 7777), "10.0.0.6")
	c.recevoir(Decouverte.encoder("Alba", 1, 8, 7778), "10.0.0.6")
	var liste := c.salons()
	verifier_egal(liste.size(), 3, "même adresse, deux ports : deux salons")
	verifier_egal(liste[0]["nom"], "Alba")
	verifier_egal(liste[2]["nom"], "Zéphyr")
	c.free()


func test_la_liste_est_bornee_face_a_une_inondation() -> void:
	var c := _chercheur()
	for i: int in Decouverte.MAX_SALONS + 50:
		c.recevoir(Decouverte.encoder("S%d" % i, 1, 8, 7777), "10.1.%d.%d" % [i / 250, i % 250])
	verifier(c.salons().size() <= Decouverte.MAX_SALONS, "liste bornée")
	c.free()


func test_le_signal_ne_part_que_si_la_liste_change() -> void:
	var c := _chercheur()
	var compte: Array[int] = [0]
	c.liste_changee.connect(func() -> void: compte[0] += 1)
	var a := Decouverte.encoder("Salon", 1, 8, 7777)
	c.recevoir(a, "10.0.0.5")
	verifier_egal(compte[0], 1, "nouveau salon")
	c.recevoir(a, "10.0.0.5")
	verifier_egal(compte[0], 1, "même annonce : rien")
	c.recevoir(Decouverte.encoder("Salon", 2, 8, 7777), "10.0.0.5")
	verifier_egal(compte[0], 2, "joueurs changés")
	_horloge[0] += 4.0
	c.purger()
	verifier_egal(compte[0], 3, "expiration")
	c.free()


# --- Émission ----------------------------------------------------------------------------------


func test_l_annonceur_emet_chaque_seconde_et_pas_plus() -> void:
	var a := Decouverte.new()
	var envois: Array[int] = [0]
	a.fournisseur = func() -> Dictionary:
		envois[0] += 1
		return {"nom": "Salon", "joueurs": 1, "max": 8, "port": 7777}
	verifier_egal(a.annoncer(_port_libre(), ["127.0.0.1"]), OK)
	verifier_egal(envois[0], 1, "une annonce tout de suite")
	a.avancer(0.4)
	verifier_egal(envois[0], 1, "pas encore")
	a.avancer(0.7)
	verifier_egal(envois[0], 2, "après 1,1 s")
	a.avancer(0.5)
	verifier_egal(envois[0], 2, "pas de rafale")
	a.avancer(0.6)
	verifier_egal(envois[0], 3, "après 2,2 s")
	a.avancer(30.0)
	verifier_egal(envois[0], 4, "un grand pas ne donne qu'une annonce")
	a.free()


# --- Vrai UDP sur la boucle locale -------------------------------------------------------------


func _port_libre() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE + OS.get_process_id()
	for i: int in 40:
		var p := rng.randi_range(20000, 60000)
		var essai := PacketPeerUDP.new()
		var ok := essai.bind(p, "127.0.0.1") == OK
		essai.close()
		if ok:
			return p
	return 0


func test_une_annonce_traverse_vraiment_l_udp_de_la_boucle_locale() -> void:
	var port_udp := _port_libre()
	verifier(port_udp > 0, "un port UDP libre")
	var chercheur := Decouverte.new()
	arbre.root.add_child(chercheur)
	verifier_egal(chercheur.chercher(port_udp, "127.0.0.1"), OK)
	var hote := Decouverte.new()
	arbre.root.add_child(hote)
	hote.fournisseur = func() -> Dictionary:
		return {"nom": "Salon réel", "joueurs": 1, "max": 8, "port": 7777}
	verifier_egal(hote.annoncer(port_udp, ["127.0.0.1"]), OK)
	var fin := Time.get_ticks_msec() + 5000
	while chercheur.salons().is_empty() and Time.get_ticks_msec() < fin:
		hote.emettre()
		await arbre.process_frame
	var liste := chercheur.salons()
	verifier_egal(liste.size(), 1, "le salon est découvert")
	if not liste.is_empty():
		verifier_egal(liste[0]["nom"], "Salon réel")
		verifier_egal(liste[0]["adresse"], "127.0.0.1")
		verifier_egal(liste[0]["port"], 7777)
	hote.arreter()
	chercheur.arreter()


func test_des_paquets_de_bruit_envoyes_en_udp_n_ajoutent_rien() -> void:
	var port_udp := _port_libre()
	verifier(port_udp > 0)
	var chercheur := Decouverte.new()
	arbre.root.add_child(chercheur)
	verifier_egal(chercheur.chercher(port_udp, "127.0.0.1"), OK)
	var envoi := PacketPeerUDP.new()
	envoi.set_dest_address("127.0.0.1", port_udp)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	for i: int in 20:
		var o := PackedByteArray()
		o.resize(rng.randi_range(1, 2000))
		for k: int in o.size():
			o[k] = rng.randi_range(0, 255)
		envoi.put_packet(o)
	await attendre_images(10)
	verifier_egal(chercheur.salons().size(), 0)
	envoi.close()
	chercheur.arreter()


func test_un_port_de_decouverte_deja_pris_donne_une_erreur_sans_planter() -> void:
	var port_udp := _port_libre()
	var occupe := PacketPeerUDP.new()
	verifier_egal(occupe.bind(port_udp, "127.0.0.1"), OK)
	var chercheur := Decouverte.new()
	verifier_different(chercheur.chercher(port_udp, "127.0.0.1"), OK)
	chercheur.free()
	occupe.close()
