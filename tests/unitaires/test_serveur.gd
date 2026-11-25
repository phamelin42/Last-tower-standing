extends CasDeTest
## Ce que le serveur doit garantir sans aucun socket : on lui présente des pairs et des octets,
## il ne croit que le numéro du pair, refuse proprement tout ce qui est faux ou en trop, et la
## partie continue pour les autres quand un joueur part. Les envois sont captés par `emetteur`.

const PORT_MAUVAIS: Array[int] = [-1, 0, 65536, 70000]

var d: Donnees
var courant: Donnees
var sorties: Array[Dictionary] = []
var crees: Array[Serveur] = []
var termine: Array[int] = []


func avant_chaque() -> void:
	d = Donnees.charger()
	courant = d
	sorties = []
	termine = []
	crees = []


func apres_chaque() -> void:
	for s: Serveur in crees:
		s.free()


# --- Aides -----------------------------------------------------------------------------------


func _serveur(donnees: Donnees = null, acceleration: int = 1) -> Serveur:
	var s := Serveur.new()
	crees.append(s)
	s.emetteur = func(pair: int, rpc: String, octets: PackedByteArray) -> void:
		sorties.append({"pair": pair, "rpc": rpc, "octets": octets})
	s.partie_terminee_serveur.connect(func() -> void: termine.append(1))
	courant = donnees if donnees != null else d
	s.preparer(courant, acceleration)
	return s


func _bonjour(nom: String, ecart_empreinte: int = 0) -> PackedByteArray:
	return Protocole.encoder_bonjour(nom, courant.empreinte + ecart_empreinte)


func _connecter(s: Serveur, pair: int, nom: String = "") -> bool:
	s.pair_connecte(pair)
	return s.traiter_bonjour(pair, _bonjour(nom if not nom.is_empty() else "Joueur %d" % pair))


func _intention(s: Serveur, pair: int, genre: int, arg: int = 0, texte: String = "") -> int:
	return s.traiter_intention(pair, Protocole.encoder_intention(genre, arg, texte))


func _attendre(s: Serveur, secondes: float) -> void:
	var t := 0.0
	while t < secondes:
		s.tick(0.25)
		t += 0.25


## `n` pairs 11, 12… prêts : la partie démarre au dernier.
func _lancer(s: Serveur, n: int) -> Array[int]:
	var ids: Array[int] = []
	for i: int in n:
		ids.append(11 + i)
		_connecter(s, 11 + i)
	# Graine fixe : les offres de boutique sont les mêmes à chaque exécution.
	verifier_egal(s.traiter_intention(ids[0], Serveur.encoder_options(1.0, 777, true)), 0)
	for pair: int in ids:
		verifier_egal(_intention(s, pair, Protocole.Intention.PRET, 1), Types.Resultat.OK)
	return ids


func _etats(pair: int) -> Array[VueArene]:
	var out: Array[VueArene] = []
	for e: Dictionary in sorties:
		if int(e["pair"]) == pair and String(e["rpc"]) == "rpc_etat_arene":
			var v := Protocole.decoder_etat_arene(e["octets"], d.ids_catalogue)
			verifier_non_nul(v, "tout état émis se décode")
			out.append(v)
	return out


func _refus(pair: int) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in sorties:
		if int(e["pair"]) == pair and String(e["rpc"]) == "rpc_refus":
			out.append(Protocole.decoder_refus(e["octets"]))
	return out


func _resultats(pair: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in sorties:
		if int(e["pair"]) == pair and String(e["rpc"]) == "rpc_resultat":
			var r := Protocole.decoder_resultat(e["octets"])
			verifier_faux(r.is_empty(), "tout résultat émis se décode")
			out.append(r)
	return out


func _vivant(s: Serveur, joueur: int) -> bool:
	for j: Dictionary in s.partie.vue_globale().joueurs:
		if int(j["id"]) == joueur:
			return bool(j["vivant"])
	return false


# --- Poignée de main -------------------------------------------------------------------------


func test_aucune_intention_n_est_prise_avant_le_bonjour() -> void:
	var s := _serveur()
	var valide := Protocole.encoder_intention(Protocole.Intention.PRET, 1)
	verifier_egal(s.traiter_intention(5, valide), Types.Resultat.NON_DISPONIBLE, "pair inconnu")
	s.pair_connecte(5)
	verifier_egal(s.traiter_intention(5, valide), Types.Resultat.NON_DISPONIBLE, "connecté, muet")
	verifier_egal(s.joueur_de(5), -1)
	verifier_faux(s.salon.joueurs.has(5), "le salon ne connaît pas un pair sans bonjour")
	verifier_egal(_intention(s, 5, Protocole.Intention.PRET, 1), Types.Resultat.NON_DISPONIBLE)
	verifier(s.traiter_bonjour(5, _bonjour("Aki")))
	verifier_egal(s.joueur_de(5), 5, "après le bonjour, le joueur porte le numéro de son pair")
	verifier_egal(_intention(s, 5, Protocole.Intention.PRET, 1), Types.Resultat.OK)


func test_un_pair_qui_ne_dit_jamais_bonjour_est_coupe() -> void:
	var s := _serveur()
	s.pair_connecte(7)
	verifier_egal(s.nb_pairs(), 1)
	_attendre(s, Serveur.DELAI_BONJOUR_S + 1.0)
	verifier_egal(s.nb_pairs(), 0, "le pair muet est retiré")


func test_des_bonjours_invalides_repetes_coupent_le_pair() -> void:
	var s := _serveur()
	s.pair_connecte(7)
	for i: int in Serveur.BONJOURS_INVALIDES_MAX:
		verifier_faux(s.traiter_bonjour(7, PackedByteArray([1, 1, 200, 3])), "bonjour %d" % i)
	verifier_egal(s.nb_pairs(), 0)
	verifier_faux(s.traiter_bonjour(7, PackedByteArray()), "le pair coupé n'est pas ressuscité")


func test_un_second_bonjour_n_ecrase_pas_le_premier() -> void:
	var s := _serveur()
	_connecter(s, 5, "Aki")
	verifier_faux(s.traiter_bonjour(5, _bonjour("Autre")), "bonjour répété ignoré")
	verifier_egal(s.salon.joueurs[5]["nom"], "Aki")
	verifier_egal(s.salon.joueurs.size(), 1)


func test_version_et_empreinte_differentes_sont_refusees_avec_un_motif() -> void:
	var s := _serveur()
	var vieux := _bonjour("Aki")
	vieux[1] = Protocole.VERSION + 41
	s.pair_connecte(5)
	verifier_faux(s.traiter_bonjour(5, vieux))
	verifier_egal(_refus(5), [Protocole.motif_version(Protocole.VERSION + 41)] as Array[String])
	verifier_egal(s.joueur_de(5), -1)
	s.pair_connecte(6)
	verifier_faux(s.traiter_bonjour(6, _bonjour("Bo", 1)))
	var motifs := _refus(6)
	verifier_egal(motifs.size(), 1, "un refus pour l'empreinte")
	verifier(not motifs[0].is_empty() and not motifs[0].begins_with("Version"), motifs[0])
	verifier_faux(s.salon.joueurs.has(5) or s.salon.joueurs.has(6))
	verifier_egal(s.nb_pairs(), 0, "les pairs refusés sont retirés")


func test_deux_pairs_de_meme_nom_restent_distincts() -> void:
	var s := _serveur()
	_connecter(s, 5, "Aki")
	_connecter(s, 6, "Aki")
	verifier_different(s.salon.joueurs[5]["nom"], s.salon.joueurs[6]["nom"])
	verifier_egal(s.joueur_de(6), 6)


func test_le_neuvieme_pair_est_refuse_et_les_huit_premiers_gardent_leur_place() -> void:
	var s := _serveur()
	for i: int in range(1, 9):
		verifier(_connecter(s, 100 + i), "pair %d admis" % i)
	s.pair_connecte(109)
	verifier_faux(s.traiter_bonjour(109, _bonjour("Neuf")))
	verifier_egal(_refus(109).size(), 1)
	verifier_egal(s.joueur_de(109), -1)
	verifier_egal(s.salon.joueurs.size(), 8)


func test_un_bonjour_apres_le_depart_de_la_partie_est_refuse() -> void:
	var s := _serveur()
	_lancer(s, 2)
	s.pair_connecte(99)
	verifier_faux(s.traiter_bonjour(99, _bonjour("Retard")))
	verifier_egal(_refus(99).size(), 1)
	verifier_egal(s.partie.vue_globale().joueurs.size(), 2, "la partie n'a pas changé")


# --- Intentions du salon ---------------------------------------------------------------------


func test_la_partie_demarre_quand_tous_sont_prets_et_pas_avant() -> void:
	var s := _serveur()
	_connecter(s, 5)
	_connecter(s, 6)
	verifier_egal(_intention(s, 5, Protocole.Intention.PRET, 1), Types.Resultat.OK)
	verifier_nul(s.partie, "un seul joueur sur deux est prêt")
	verifier_egal(_intention(s, 5, Protocole.Intention.PRET, 0), Types.Resultat.OK)
	verifier_egal(_intention(s, 5, Protocole.Intention.PRET, 1), Types.Resultat.OK)
	verifier_egal(_intention(s, 6, Protocole.Intention.PRET, 1), Types.Resultat.OK)
	verifier_non_nul(s.partie, "tous prêts : la partie démarre")
	verifier_egal(s.partie.vue_globale().joueurs.size(), 2)
	verifier_egal(_intention(s, 5, Protocole.Intention.PRET, 1), Types.Resultat.MAUVAISE_PHASE)


func test_les_options_sont_reservees_a_l_hote_et_bornees() -> void:
	var s := _serveur()
	_connecter(s, 5)
	_connecter(s, 6)
	var opts := Serveur.encoder_options(0.5, 1234, true)
	verifier_egal(s.traiter_intention(6, opts), Types.Resultat.NON_DISPONIBLE, "non-hôte")
	verifier_egal(s.salon.vitesse, 1.0)
	verifier_egal(s.traiter_intention(5, opts), Types.Resultat.OK, "hôte = premier pair")
	verifier_proche(s.salon.vitesse, 0.5, 1e-6)
	verifier_egal(s.salon.graine, 1234)
	verifier(s.salon.graine_fixe)
	for mauvais: Array in [[0.7, 1, true], [1.0, -5, true], [NAN, 1, false]]:
		var v: float = mauvais[0]
		var g: int = mauvais[1]
		var f: bool = mauvais[2]
		verifier_egal(
			s.traiter_intention(5, Serveur.encoder_options(v, g, f)),
			Types.Resultat.NON_DISPONIBLE,
			"options %s" % [mauvais]
		)
	verifier_proche(s.salon.vitesse, 0.5, 1e-6, "les options refusées ne changent rien")
	verifier_egal(_intention(s, 5, Protocole.Intention.OPTIONS, 3, "pas des options"), 8)
	verifier_egal(_intention(s, 5, Protocole.Intention.OPTIONS, 3, ""), 8)


func test_les_options_refusees_une_fois_la_partie_lancee() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	verifier_egal(
		s.traiter_intention(ids[0], Serveur.encoder_options(0.5, 1, true)),
		Types.Resultat.MAUVAISE_PHASE
	)


func test_un_pret_hors_zero_un_est_refuse() -> void:
	var s := _serveur()
	_connecter(s, 5)
	for arg: int in [-1, 2, 255, 1 << 30]:
		verifier_egal(
			_intention(s, 5, Protocole.Intention.PRET, arg), Types.Resultat.NON_DISPONIBLE
		)
	verifier_faux(bool(s.salon.joueurs[5]["pret"]))


func test_hote_qui_part_passe_la_main_au_suivant() -> void:
	var s := _serveur()
	_connecter(s, 5)
	_connecter(s, 6)
	s.pair_deconnecte(5)
	verifier_egal(s.salon.hote, 6)
	verifier_egal(s.traiter_intention(6, Serveur.encoder_options(0.66, 1, false)), 0)


# --- Intentions de jeu et robustesse ---------------------------------------------------------


func test_une_intention_deformee_est_refusee_sans_exception_ni_effet() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	var valide := Protocole.encoder_intention(Protocole.Intention.ACHETER, 0)
	var paquets: Array[PackedByteArray] = [
		PackedByteArray(),
		PackedByteArray([0]),
		PackedByteArray([99, 1, 2, 3, 4, 5, 6, 7]),
		_bonjour("Pas une intention"),
	]
	for n: int in valide.size():
		paquets.append(valide.slice(0, n))
	var trop_long := valide.duplicate()
	trop_long.append(0)
	paquets.append(trop_long)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261125
	var bruit := PackedByteArray()
	for i: int in Protocole.MAX_TAILLE:
		bruit.append(rng.randi() & 0xFF)
	paquets.append(bruit)
	var enorme := PackedByteArray()
	enorme.resize(Protocole.MAX_TAILLE * 4)
	paquets.append(enorme)
	for i: int in paquets.size():
		_attendre(s, 1.0)
		verifier_egal(
			s.traiter_intention(ids[0], paquets[i]),
			Types.Resultat.NON_DISPONIBLE,
			"paquet déformé %d refusé" % i
		)
	var apres := s.partie.vue_arene(ids[0], ids[0])
	verifier_egal(apres.armes.size(), 0, "aucun achat")
	for offre: Dictionary in apres.offres:
		verifier_faux(bool(offre["vendu"]), "aucune offre vendue")
	verifier(_vivant(s, ids[0]) and _vivant(s, ids[1]))


func test_un_argument_hors_bornes_est_refuse_pour_chaque_genre_a_indice() -> void:
	var s := _serveur()
	var ids := _lancer(s, 1)
	for genre: int in [Protocole.Intention.ACHETER, Protocole.Intention.VENDRE]:
		for arg: int in [-1, 4, 8, 255, 1 << 30, -(1 << 30)]:
			_attendre(s, 1.0)
			var r := _intention(s, ids[0], genre, arg)
			verifier(r != Types.Resultat.OK, "genre %d, argument %d refusé (%d)" % [genre, arg, r])
	_attendre(s, 1.0)
	var inconnue := _intention(s, ids[0], Protocole.Intention.MARCHE_NOIR, 0, "n'existe pas")
	verifier(inconnue != Types.Resultat.OK, "amélioration inconnue refusée")
	verifier(_vivant(s, ids[0]))


func test_un_achat_valide_est_debite_pour_son_seul_auteur() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	var avant_b := s.partie.vue_arene(ids[1], ids[1]).argent
	var vue_a := s.partie.vue_arene(ids[0], ids[0])
	var cher := 0
	for i: int in vue_a.offres.size():
		if int((vue_a.offres[i] as Dictionary)["prix"]) <= vue_a.argent:
			cher = i
			break
	verifier_egal(_intention(s, ids[0], Protocole.Intention.ACHETER, cher), Types.Resultat.OK)
	verifier(s.partie.vue_arene(ids[0], ids[0]).argent < vue_a.argent, "A est débité")
	verifier_egal(s.partie.vue_arene(ids[1], ids[1]).argent, avant_b, "B ne l'est pas")


func test_une_rafale_est_bornee_par_pas_et_par_seconde_sans_geler_la_boucle() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	var rafale := Protocole.encoder_intention(Protocole.Intention.RELANCER, 0)
	var base := s.admises(ids[0])
	var debut := Time.get_ticks_msec()
	for i: int in 1000:
		s.traiter_intention(ids[0], rafale)
	verifier(Time.get_ticks_msec() - debut < 2000, "1 000 intentions ne gèlent pas la boucle")
	verifier(
		s.admises(ids[0]) - base <= Serveur.INTENTIONS_PAR_PAS,
		"au plus %d par pas : %d" % [Serveur.INTENTIONS_PAR_PAS, s.admises(ids[0]) - base]
	)
	verifier_egal(s.admises(ids[0]) + s.limitees(ids[0]) - base, 1000, "le surplus est compté")
	verifier_egal(_intention(s, ids[1], Protocole.Intention.RELANCER), Types.Resultat.OK, "B libre")
	# Une seconde de rafales de 17 intentions par pas de 1/60 s : jamais plus de 30 admises.
	var t := _serveur()
	t.pair_connecte(1)
	t.traiter_bonjour(1, _bonjour("R"))
	t.traiter_intention(1, Protocole.encoder_intention(Protocole.Intention.PRET, 1))
	var avant := t.admises(1)
	for pas: int in 59:
		t.tick(1.0 / 60.0)
		for k: int in 17:
			t.traiter_intention(1, rafale)
	verifier(
		t.admises(1) - avant <= Serveur.INTENTIONS_PAR_SECONDE,
		"débit d'intentions borné : %d" % (t.admises(1) - avant)
	)
	# Après un silence, le pair est de nouveau servi.
	_attendre(s, 1.5)
	var avant_silence := s.admises(ids[0])
	_intention(s, ids[0], Protocole.Intention.RELANCER)
	verifier_egal(s.admises(ids[0]), avant_silence + 1, "après un silence, le pair est servi")


func test_acheter_apres_la_mort_donne_arene_morte() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	verifier_egal(_intention(s, ids[0], Protocole.Intention.QUITTER), Types.Resultat.OK)
	_attendre(s, 1.0)
	verifier_egal(_intention(s, ids[0], Protocole.Intention.ACHETER, 0), Types.Resultat.ARENE_MORTE)
	_attendre(s, 1.0)
	verifier_egal(_intention(s, ids[0], Protocole.Intention.RELANCER), Types.Resultat.ARENE_MORTE)
	verifier_faux(_vivant(s, ids[0]))
	verifier(_vivant(s, ids[1]), "l'autre joueur continue")


func test_une_tour_tombee_en_vrai_donne_arene_morte_et_clot_la_partie() -> void:
	delai_max = 60.0
	var faible := AidesPartie.donnees({"partie.json": [[["tour", "pv"], 1.0]]})
	var s := _serveur(faible, 60)
	var ids := _lancer(s, 1)
	var essais := 0
	while _vivant(s, ids[0]) and essais < 400:
		s.tick(0.25)
		essais += 1
	verifier_faux(_vivant(s, ids[0]), "la tour à 1 PV tombe")
	verifier_egal(_intention(s, ids[0], Protocole.Intention.ACHETER, 0), Types.Resultat.ARENE_MORTE)
	verifier_egal(termine.size(), 1, "la partie est signalée terminée")


func test_observer_suit_les_regles_de_la_partie() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	var a := ids[0]
	var b := ids[1]
	var obs := Protocole.Intention.OBSERVER
	verifier_egal(_intention(s, a, obs, a), Types.Resultat.OK, "sa propre arène, vivant")
	_attendre(s, 1.0)
	verifier_egal(_intention(s, a, obs, b), Types.Resultat.INDICE_INVALIDE, "celle d'un autre")
	_attendre(s, 1.0)
	verifier_egal(_intention(s, a, obs, 9999), Types.Resultat.INDICE_INVALIDE, "cible inconnue")
	_attendre(s, 1.0)
	verifier_egal(_intention(s, a, obs, -3), Types.Resultat.INDICE_INVALIDE)
	# B achète une arme : l'arène de B se reconnaît à ses armes.
	var vue_b := s.partie.vue_arene(b, b)
	var choix := -1
	for i: int in vue_b.offres.size():
		var offre: Dictionary = vue_b.offres[i]
		if int(offre["genre"]) == Types.Genre.ARME and int(offre["prix"]) <= vue_b.argent:
			choix = i
			break
	verifier(choix >= 0, "une arme abordable est proposée")
	_attendre(s, 1.0)
	verifier_egal(_intention(s, b, Protocole.Intention.ACHETER, choix), Types.Resultat.OK)
	_attendre(s, 1.0)
	verifier_egal(_intention(s, a, Protocole.Intention.QUITTER), Types.Resultat.OK)
	_attendre(s, 1.0)
	verifier_egal(_intention(s, a, obs, b), Types.Resultat.OK, "après la mort, l'arène de B")
	sorties.clear()
	_attendre(s, 1.0)
	var etats := _etats(a)
	verifier(not etats.is_empty(), "A reçoit des états")
	verifier_egal(etats[etats.size() - 1].armes.size(), 1, "l'état reçu est celui de B")


func test_observer_une_arene_disparue_revient_a_la_sienne() -> void:
	var s := _serveur()
	var ids := _lancer(s, 3)
	_intention(s, ids[0], Protocole.Intention.QUITTER)
	_attendre(s, 1.0)
	verifier_egal(_intention(s, ids[0], Protocole.Intention.OBSERVER, ids[1]), Types.Resultat.OK)
	s.pair_deconnecte(ids[1])
	sorties.clear()
	_attendre(s, 1.0)
	verifier(termine.is_empty(), "la partie continue pour C")
	verifier(_etats(ids[2]).size() > 0, "C reçoit toujours ses états")


# --- Déconnexions ----------------------------------------------------------------------------


func test_tous_deconnectes_pendant_la_preparation_terminent_proprement() -> void:
	var s := _serveur()
	var ids := _lancer(s, 3)
	verifier_egal(s.partie.vue_arene(ids[0], ids[0]).phase, Types.Phase.PREPARATION)
	for pair: int in ids:
		s.pair_deconnecte(pair)
	verifier_egal(termine.size(), 1, "fin signalée une seule fois")
	verifier(s.partie.est_terminee(), "la partie est close")
	_attendre(s, 2.0)
	s.pair_deconnecte(ids[0])
	verifier_egal(termine.size(), 1, "pas de second signal")


func test_salon_vide_avant_le_depart_ne_termine_rien_et_ne_plante_pas() -> void:
	var s := _serveur()
	_connecter(s, 5)
	s.pair_deconnecte(5)
	_attendre(s, 2.0)
	verifier(termine.is_empty())
	verifier_egal(s.nb_pairs(), 0)
	verifier_nul(s.partie)


func test_un_pair_qui_part_en_pleine_partie_est_elimine_et_les_autres_continuent() -> void:
	var s := _serveur(null, 4)
	var ids := _lancer(s, 3)
	_attendre(s, 3.0)
	s.pair_deconnecte(ids[1])
	verifier_faux(_vivant(s, ids[1]), "le parti est éliminé")
	verifier(_vivant(s, ids[0]) and _vivant(s, ids[2]), "les autres vivent")
	var avant: int = s.partie.vue_arene(ids[0], ids[0]).tick
	sorties.clear()
	_attendre(s, 3.0)
	verifier(s.partie.vue_arene(ids[0], ids[0]).tick > avant, "la simulation avance")
	verifier(_etats(ids[0]).size() > 0 and _etats(ids[2]).size() > 0, "états envoyés aux restants")
	verifier_egal(_etats(ids[1]).size(), 0, "plus rien pour le parti")
	verifier(termine.is_empty())
	s.pair_deconnecte(ids[1])
	s.pair_deconnecte(ids[0])
	s.pair_deconnecte(ids[2])
	verifier_egal(termine.size(), 1)


# --- Boucle ----------------------------------------------------------------------------------


func test_la_simulation_avance_a_pas_fixe_quel_que_soit_le_decoupage_du_temps() -> void:
	var a := _serveur()
	var b := _serveur()
	var ia := _lancer(a, 1)
	var ib := _lancer(b, 1)
	for i: int in 120:
		a.tick(1.0 / 60.0)
	for i: int in 10:
		b.tick(0.2)
	verifier_egal(
		a.partie.vue_arene(ia[0], ia[0]).tick,
		b.partie.vue_arene(ib[0], ib[0]).tick,
		"2 s simulées, quel que soit le pas de la boucle"
	)
	verifier_egal(a.partie.vue_arene(ia[0], ia[0]).tick, 40)


func test_l_acceleration_multiplie_le_temps_simule() -> void:
	for facteur: int in [1, 2, 5]:
		var s := _serveur(null, facteur)
		var ids := _lancer(s, 1)
		for i: int in 20:
			s.tick(0.1)
		verifier_egal(
			s.partie.vue_arene(ids[0], ids[0]).tick, 40 * facteur, "accélération %d" % facteur
		)


func test_l_envoi_de_l_arene_est_a_15_hz_et_l_etat_global_a_2_hz() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	sorties.clear()
	for i: int in 600:
		s.tick(1.0 / 60.0)
	var arenes := _etats(ids[0]).size()
	verifier(arenes >= 148 and arenes <= 152, "15 Hz sur 10 s : %d états" % arenes)
	var globaux := 0
	for e: Dictionary in sorties:
		if int(e["pair"]) == ids[0] and String(e["rpc"]) == "rpc_etat_global":
			globaux += 1
			verifier_non_nul(Protocole.decoder_etat_global(e["octets"]))
	verifier(globaux >= 19 and globaux <= 21, "2 Hz sur 10 s : %d états globaux" % globaux)
	var ticks: Array[int] = []
	for v: VueArene in _etats(ids[0]):
		ticks.append(v.tick)
	var croissant := true
	for i: int in range(1, ticks.size()):
		croissant = croissant and ticks[i] > ticks[i - 1]
	verifier(croissant, "les ticks envoyés croissent")


func test_une_boucle_a_20_hz_garde_le_meme_debit_qu_une_boucle_a_60_hz() -> void:
	var s := _serveur()
	var ids := _lancer(s, 1)
	sorties.clear()
	for i: int in 200:
		s.tick(0.05)
	var arenes := _etats(ids[0]).size()
	verifier(arenes >= 145 and arenes <= 152, "15 Hz même par pas de 0,05 s : %d" % arenes)


# --- Démarrage réseau ------------------------------------------------------------------------


func test_un_port_invalide_donne_une_erreur_sans_rien_ouvrir() -> void:
	for port: int in PORT_MAUVAIS:
		var s := Serveur.new()
		verifier_egal(s.demarrer(d, port), ERR_INVALID_PARAMETER, "port %d" % port)
		verifier_faux(s.est_actif())
		s.free()


func test_un_port_deja_occupe_donne_une_erreur() -> void:
	var occupant := ENetMultiplayerPeer.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261125 + OS.get_process_id()
	var port := -1
	for i: int in 40:
		var essai := rng.randi_range(20000, 60000)
		if occupant.create_server(essai, 2) == OK:
			port = essai
			break
	verifier(port > 0, "un port libre pour l'occupant")
	var s := Serveur.new()
	attendre_erreur("ENet host")
	var code := s.demarrer(d, port)
	verifier(code != OK, "port occupé : code %d" % code)
	verifier_faux(s.est_actif())
	occupant.close()
	s.free()


func test_demarrer_hors_arbre_ou_sans_canal_est_refuse_et_libere_le_port() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42 + OS.get_process_id()
	var port := rng.randi_range(20000, 60000)
	var s := Serveur.new()
	var code := s.demarrer(d, port)
	verifier_egal(code, ERR_UNCONFIGURED, "pas de canal parent")
	verifier_faux(s.est_actif())
	# Le port n'est pas resté pris par l'essai raté.
	var peer := ENetMultiplayerPeer.new()
	verifier_egal(peer.create_server(port, 2), OK, "le port est libre")
	peer.close()
	s.free()


func test_l_acceleration_est_bornee() -> void:
	for brut: int in [-5, 0, 1, 60, 61, 100000]:
		var s := Serveur.new()
		s.preparer(d, brut)
		verifier_egal(s.acceleration, clampi(brut, 1, Serveur.ACCELERATION_MAX))
		s.free()


func test_arreter_sans_demarrer_est_sans_effet() -> void:
	var s := Serveur.new()
	s.arreter()
	s.arreter()
	verifier_faux(s.est_actif())
	s.free()


# --- Résultat des intentions -----------------------------------------------------------------


func test_chaque_genre_d_intention_renvoie_son_code_au_seul_expediteur() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	var genres: Array[int] = []
	for g: int in range(Protocole.Intention.ACHETER, Protocole.Intention.OPTIONS + 1):
		if g != Protocole.Intention.QUITTER:
			genres.append(g)
	var attendus := {
		Protocole.Intention.RELANCER: Types.Resultat.OK,
		Protocole.Intention.OBSERVER: Types.Resultat.INDICE_INVALIDE,
		Protocole.Intention.PRET: Types.Resultat.MAUVAISE_PHASE,
		Protocole.Intention.OPTIONS: Types.Resultat.MAUVAISE_PHASE,
		Protocole.Intention.SANS_FIN: Types.Resultat.NON_DISPONIBLE,
	}
	for genre: int in genres:
		for k: int in 2:
			var expediteur := ids[k]
			var autre := ids[1 - k]
			_attendre(s, 1.0)
			sorties.clear()
			var arg := autre if genre == Protocole.Intention.OBSERVER else 99
			var texte := "inconnue" if genre == Protocole.Intention.MARCHE_NOIR else ""
			var retour := _intention(s, expediteur, genre, arg, texte)
			var recus := _resultats(expediteur)
			verifier_egal(recus.size(), 1, "genre %d : un résultat" % genre)
			if recus.size() == 1:
				verifier_egal(recus[0], {"genre": genre, "code": retour}, "genre %d" % genre)
			verifier_egal(_resultats(autre).size(), 0, "genre %d : rien pour l'autre" % genre)
			if attendus.has(genre) and genre != Protocole.Intention.RELANCER:
				verifier_egal(retour, attendus[genre], "code du genre %d" % genre)


func test_resultats_ok_refus_de_boutique_et_mort_arrivent_au_bon_client() -> void:
	var s := _serveur()
	_connecter(s, 5)
	sorties.clear()
	_intention(s, 5, Protocole.Intention.ACHETER, 0)
	_attendre(s, 1.0)
	verifier_egal(
		_resultats(5),
		(
			[{"genre": Protocole.Intention.ACHETER, "code": Types.Resultat.MAUVAISE_PHASE}]
			as Array[Dictionary]
		),
		"avant la partie"
	)
	sorties.clear()
	_intention(s, 5, Protocole.Intention.PRET, 1)
	verifier_egal(_resultats(5)[0]["code"], Types.Resultat.OK, "prêt accepté")
	_attendre(s, 1.0)
	sorties.clear()
	_intention(s, 5, Protocole.Intention.QUITTER)
	verifier_egal(_resultats(5)[0], {"genre": Protocole.Intention.QUITTER, "code": 0})
	_attendre(s, 1.0)
	sorties.clear()
	_intention(s, 5, Protocole.Intention.ACHETER, 0)
	verifier_egal(_resultats(5)[0]["code"], Types.Resultat.ARENE_MORTE, "après la mort")


func test_une_intention_ignoree_limitee_ou_deformee_n_a_pas_de_resultat() -> void:
	var s := _serveur()
	var ids := _lancer(s, 1)
	sorties.clear()
	s.traiter_intention(999, Protocole.encoder_intention(Protocole.Intention.RELANCER, 0))
	s.traiter_intention(ids[0], PackedByteArray([1, 2, 3]))
	var rafale := Protocole.encoder_intention(Protocole.Intention.RELANCER, 0)
	for i: int in 100:
		s.traiter_intention(ids[0], rafale)
	var n := _resultats(ids[0]).size()
	verify_borne(n)
	verifier_egal(_resultats(999).size(), 0)


func verify_borne(n: int) -> void:
	verifier(
		n <= Serveur.INTENTIONS_PAR_PAS, "les intentions limitées n'ont pas de réponse : %d" % n
	)


func test_un_ancien_client_de_version_precedente_est_refuse_avec_un_motif() -> void:
	var s := _serveur()
	var ancien := _bonjour("Aki")
	ancien[1] = Protocole.VERSION - 1
	s.pair_connecte(5)
	verifier_faux(s.traiter_bonjour(5, ancien))
	verifier_egal(_refus(5), [Protocole.motif_version(Protocole.VERSION - 1)] as Array[String])
	verifier_egal(s.joueur_de(5), -1)
