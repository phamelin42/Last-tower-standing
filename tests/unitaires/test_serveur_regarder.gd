extends CasDeTest
## Regarder l'arène d'un autre joueur de son vivant : le serveur l'envoie à 5 Hz en plus de celle
## du pair (15 Hz), refuse ce qui n'a pas de sens, y renonce proprement quand le joueur part, et
## diffuse les cartes de densité à 1 Hz. Aucun socket : les envois sont captés par `emetteur`.

var d: Donnees
var sorties: Array[Dictionary] = []
var crees: Array[Serveur] = []


func avant_chaque() -> void:
	d = Donnees.charger()
	sorties = []
	crees = []


func apres_chaque() -> void:
	for s: Serveur in crees:
		s.free()


# --- Aides -----------------------------------------------------------------------------------


func _serveur() -> Serveur:
	var s := Serveur.new()
	crees.append(s)
	s.emetteur = func(pair: int, rpc: String, octets: PackedByteArray) -> void:
		sorties.append({"pair": pair, "rpc": rpc, "octets": octets})
	s.preparer(d, 1)
	return s


func _lancer(s: Serveur, n: int) -> Array[int]:
	var ids: Array[int] = []
	for i: int in n:
		ids.append(665857105 + 7 * i)  # des identifiants de pair ENet : bien plus grands que 255
		s.pair_connecte(ids[i])
		s.traiter_bonjour(ids[i], Protocole.encoder_bonjour("J%d" % i, d.empreinte))
	s.traiter_intention(ids[0], Serveur.encoder_options(1.0, 777, true))
	for pair: int in ids:
		s.traiter_intention(pair, Protocole.encoder_intention(Protocole.Intention.PRET, 1))
	return ids


func _regarder(s: Serveur, pair: int, cible: int) -> int:
	return s.traiter_intention(
		pair, Protocole.encoder_intention(Protocole.Intention.REGARDER, cible)
	)


func _avancer(s: Serveur, secondes: float) -> void:
	for _i: int in roundi(secondes * 60.0):
		s.tick(1.0 / 60.0)


func _compter(pair: int, rpc: String) -> int:
	var n := 0
	for e: Dictionary in sorties:
		if int(e["pair"]) == pair and String(e["rpc"]) == rpc:
			n += 1
	return n


func _regardees(pair: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in sorties:
		if int(e["pair"]) == pair and String(e["rpc"]) == "rpc_etat_arene_regardee":
			var r := Protocole.decoder_etat_arene_regardee(e["octets"], d.ids_catalogue)
			verifier_faux(r.is_empty(), "tout état regardé émis se décode")
			out.append(r)
	return out


func _resultats(pair: int, genre: int) -> Array[int]:
	var out: Array[int] = []
	for e: Dictionary in sorties:
		if int(e["pair"]) == pair and String(e["rpc"]) == "rpc_resultat":
			var r := Protocole.decoder_resultat(e["octets"])
			if int(r.get("genre", -1)) == genre:
				out.append(int(r["code"]))
	return out


# --- Arène regardée --------------------------------------------------------------------------


func test_regarder_une_autre_arene_envoie_ses_etats_a_5_hz_en_plus_des_siens() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	verifier_egal(_regarder(s, ids[0], ids[1]), Types.Resultat.OK)
	sorties.clear()
	_avancer(s, 2.0)
	var propres := _compter(ids[0], "rpc_etat_arene")
	var regardes := _regardees(ids[0])
	# Mesuré : 15 Hz pour la sienne, 5 Hz pour celle de B (un premier état part tout de suite).
	verifier(absi(propres - 30) <= 1, "états propres : %d" % propres)
	verifier(absi(regardes.size() - 10) <= 1, "états de B : %d" % regardes.size())
	for r: Dictionary in regardes:
		verifier_egal(r["id"], ids[1], "chaque état dit de quel joueur il vient")
	verifier_egal(s.frequence_de(ids[0]), 15.0, "l'arène propre garde sa fréquence")
	verifier_egal(s.frequence_regardee_de(ids[0]), 5.0)
	verifier_egal(_compter(ids[1], "rpc_etat_arene_regardee"), 0, "B ne regarde personne")


func test_regarder_soi_meme_ou_un_inconnu_est_refuse_et_moins_un_arrete() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	for cible: int in [ids[0], 9999, 0, 255, 1 << 30]:
		verifier_egal(
			_regarder(s, ids[0], cible), Types.Resultat.INDICE_INVALIDE, "cible %d" % cible
		)
	verifier_egal(s.regarde_de(ids[0]), -1, "rien n'est regardé")
	verifier_egal(_regarder(s, ids[0], ids[1]), Types.Resultat.OK)
	verifier_egal(_regarder(s, ids[0], ids[0]), Types.Resultat.INDICE_INVALIDE)
	verifier_egal(s.regarde_de(ids[0]), ids[1], "un refus ne coupe pas ce qu'on regarde déjà")
	_avancer(s, 1.0)
	verifier(_regardees(ids[0]).size() > 0)
	verifier_egal(_regarder(s, ids[0], -1), Types.Resultat.OK)
	sorties.clear()
	_avancer(s, 2.0)
	verifier_egal(_regardees(ids[0]).size(), 0, "après -1, plus aucun envoi")
	verifier(_compter(ids[0], "rpc_etat_arene") > 0, "la sienne continue")


func test_un_joueur_tombe_ne_regarde_pas_il_observe() -> void:
	var s := _serveur()
	var ids := _lancer(s, 3)
	s.traiter_intention(ids[0], Protocole.encoder_intention(Protocole.Intention.QUITTER, 0))
	verifier_egal(_regarder(s, ids[0], ids[1]), Types.Resultat.INDICE_INVALIDE)
	verifier_egal(s.regarde_de(ids[0]), -1)


func test_regarder_un_joueur_qui_quitte_ramene_a_sa_propre_arene() -> void:
	var s := _serveur()
	var ids := _lancer(s, 3)
	verifier_egal(_regarder(s, ids[0], ids[1]), Types.Resultat.OK)
	_avancer(s, 1.0)
	s.pair_deconnecte(ids[1])
	sorties.clear()
	_avancer(s, 2.0)
	verifier_egal(s.regarde_de(ids[0]), -1, "le serveur remet l'arène regardée à -1")
	verifier_egal(
		_resultats(ids[0], Protocole.Intention.REGARDER),
		[Types.Resultat.ARENE_MORTE] as Array[int],
		"le pair apprend qu'il ne regarde plus rien"
	)
	for r: Dictionary in _regardees(ids[0]):
		verifier(false, "aucun état de B après son départ : %s" % r["id"])
	verifier(_compter(ids[0], "rpc_etat_arene") > 0, "sa propre arène continue")
	# Rien à regarder non plus pour le dernier pair.
	s.pair_deconnecte(ids[2])
	verifier_egal(_regarder(s, ids[0], ids[2]), Types.Resultat.INDICE_INVALIDE)


func test_partie_a_un_seul_joueur_n_a_rien_a_regarder() -> void:
	var s := _serveur()
	var ids := _lancer(s, 1)
	for cible: int in [ids[0], 1, 12345]:
		verifier_egal(_regarder(s, ids[0], cible), Types.Resultat.INDICE_INVALIDE)
	verifier_egal(_regarder(s, ids[0], -1), Types.Resultat.OK)
	_avancer(s, 1.0)
	verifier_egal(_regardees(ids[0]).size(), 0)


func test_regarder_avant_la_partie_est_hors_phase() -> void:
	var s := _serveur()
	s.pair_connecte(5)
	s.traiter_bonjour(5, Protocole.encoder_bonjour("J", d.empreinte))
	verifier_egal(_regarder(s, 5, 6), Types.Resultat.MAUVAISE_PHASE)


func test_un_etat_regarde_n_est_envoye_qu_a_celui_qui_le_demande() -> void:
	var s := _serveur()
	var ids := _lancer(s, 3)
	_regarder(s, ids[0], ids[1])
	sorties.clear()
	_avancer(s, 1.0)
	verifier(_regardees(ids[0]).size() > 0)
	verifier_egal(_regardees(ids[1]).size(), 0)
	verifier_egal(_regardees(ids[2]).size(), 0)


# --- Fréquence -------------------------------------------------------------------------------


func test_frequence_arene_regardee_en_boucle_sur_les_budgets() -> void:
	var r: Dictionary = d.partie["reseau"]
	var hz_max := float(r["hz_arene_regardee"])
	var hz_min := float(r["hz_min_regardee"])
	verifier_egal(
		Serveur.frequence_arene_regardee(1.0e9, 0.0, 3000, 15.0, 3000, hz_max, hz_min),
		hz_max,
		"budget large"
	)
	verifier_egal(
		Serveur.frequence_arene_regardee(0.0, 0.0, 3000, 15.0, 3000, hz_max, hz_min),
		hz_min,
		"budget nul"
	)
	var precedent := -1.0
	for budget: int in range(0, 100001, 2500):
		var hz := Serveur.frequence_arene_regardee(
			float(budget), 2000.0, 3000, 5.0, 3000, hz_max, hz_min
		)
		verifier(hz >= hz_min and hz <= hz_max, "budget %d : %s Hz dans les bornes" % [budget, hz])
		verifier(hz >= precedent, "monotone croissante avec le budget (%d)" % budget)
		precedent = hz
	for octets: int in [0, -5]:
		verifier_egal(
			Serveur.frequence_arene_regardee(50000.0, 0.0, 3000, 15.0, octets, hz_max, hz_min),
			hz_max,
			"taille inconnue : pleine fréquence"
		)
	verifier_egal(
		Serveur.frequence_arene_regardee(NAN, 0.0, 3000, 15.0, 3000, hz_max, hz_min),
		hz_min,
		"budget non fini"
	)


# --- Densités --------------------------------------------------------------------------------


func test_les_densites_arrivent_a_1_hz_dans_la_vue_globale() -> void:
	var s := _serveur()
	var ids := _lancer(s, 2)
	sorties.clear()
	_avancer(s, 10.0)
	var globaux := 0
	var avec := 0
	for e: Dictionary in sorties:
		if int(e["pair"]) != ids[0] or String(e["rpc"]) != "rpc_etat_global":
			continue
		var v := Protocole.decoder_etat_global(e["octets"])
		verifier_non_nul(v)
		globaux += 1
		if not v.densites.is_empty():
			avec += 1
			verifier_egal(v.densites.size(), 2, "une carte par arène")
			for id: int in ids:
				verifier_egal((v.densites[id] as PackedByteArray).size(), 256)
	verifier(absi(globaux - 20) <= 1, "états globaux à 2 Hz : %d" % globaux)
	verifier(absi(avec - 10) <= 1, "cartes à 1 Hz : %d sur %d" % [avec, globaux])
