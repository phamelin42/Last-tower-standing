extends CasDeTest
## Débit adaptatif et coût de la boucle : combien d'états d'arène par seconde chaque client reçoit
## selon le nombre d'ennemis, que le débit mesuré tient le budget, et ce que coûte un tour de
## boucle du serveur avec 8 clients en fin de partie. Les foules viennent d'une vraie `Partie`
## (tour quasi invulnérable, apparitions toutes les 0,1 s) ; les envois sont captés, sans socket.

const TAILLES_300: Array[int] = [2806, 3070]
const FOULE_PETITE: int = 300
const FOULE_GRANDE: int = 1000

var foule: Donnees
var s: Serveur
var ids: Array[int] = []
var octets_par_pair: Dictionary = {}
var paquets_par_pair: Dictionary = {}
var regardees_par_pair: Dictionary = {}
var plus_gros: int = 0


func avant_chaque() -> void:
	foule = AidesPartie.donnees(
		{"partie.json": [[["tour", "pv"], 1.0e9], [["spawn_intervalle_depart"], 0.1]]}
	)
	delai_max = 180.0
	s = null
	ids = []
	_vider()


func apres_chaque() -> void:
	if s != null:
		s.free()


func _monter(n: int) -> void:
	s = Serveur.new()
	s.emetteur = func(pair: int, rpc: String, octets: PackedByteArray) -> void:
		octets_par_pair[pair] = int(octets_par_pair.get(pair, 0)) + octets.size()
		if rpc == "rpc_etat_arene_regardee":
			regardees_par_pair[pair] = int(regardees_par_pair.get(pair, 0)) + 1
		if rpc == "rpc_etat_arene":
			paquets_par_pair[pair] = int(paquets_par_pair.get(pair, 0)) + 1
			plus_gros = maxi(plus_gros, octets.size())
	s.preparer(foule, 1)
	for i: int in n:
		ids.append(21 + i)
		s.pair_connecte(21 + i)
		s.traiter_bonjour(21 + i, Protocole.encoder_bonjour("J%d" % i, foule.empreinte))
	s.traiter_intention(ids[0], Serveur.encoder_options(1.0, 5, true))
	for pair: int in ids:
		s.traiter_intention(pair, Protocole.encoder_intention(Protocole.Intention.PRET, 1))


## Fait avancer la partie (sans passer par les envois) jusqu'à `cible` ennemis dans chaque arène.
func _enrichir(cible: int) -> int:
	var plus_petit := 0
	var pas := 0
	while plus_petit < cible and pas < 20000:
		for _i: int in 40:
			s.partie.avancer(0.05)
		pas += 40
		plus_petit = 1 << 30
		for pair: int in ids:
			plus_petit = mini(plus_petit, s.partie.vue_arene(pair, pair).ennemis_id.size())
	return plus_petit


func _vider() -> void:
	octets_par_pair = {}
	paquets_par_pair = {}
	regardees_par_pair = {}
	plus_gros = 0


func _budget() -> int:
	return int((foule.partie["reseau"] as Dictionary)["budget_octets_s"])


# --- Fréquence -------------------------------------------------------------------------------


func test_la_frequence_suit_la_taille_du_paquet_dans_les_bornes_du_jeu() -> void:
	var r: Dictionary = Donnees.charger().partie["reseau"]
	var budget := float(r["budget_octets_s"])
	var hz_min := float(r["hz_min"])
	var hz_max := float(r["hz_arene"])
	for taille: int in TAILLES_300:
		verifier_egal(
			Serveur.frequence_arene(budget, 0.0, taille, hz_min, hz_max),
			hz_max,
			"300 ennemis (%d o) : pleine fréquence" % taille
		)
	var avec_evenements := Serveur.frequence_arene(budget, 0.0, 3510, hz_min, hz_max)
	verifier(
		avec_evenements >= 14.0 and avec_evenements < hz_max,
		"64 événements : %s Hz" % avec_evenements
	)
	for taille: int in [9106, 9370, 9810]:
		var hz := Serveur.frequence_arene(budget, 0.0, taille, hz_min, hz_max)
		verifier(hz >= 5.0 and hz <= 5.6, "1 000 ennemis (%d o) : %s Hz" % [taille, hz])
	for taille: int in [0, 1, 20000, 100000]:
		var hz := Serveur.frequence_arene(budget, 0.0, taille, hz_min, hz_max)
		verifier(hz >= hz_min and hz <= hz_max, "taille %d : %s Hz dans les bornes" % [taille, hz])
	var avec_reserve := Serveur.frequence_arene(budget, 1000.0, 9106, hz_min, hz_max)
	verifier(
		avec_reserve < Serveur.frequence_arene(budget, 0.0, 9106, hz_min, hz_max),
		"la part de l'état global est retirée du budget"
	)


func test_300_ennemis_gardent_15_hz() -> void:
	_monter(1)
	var n := _enrichir(FOULE_PETITE)
	for i: int in 30:
		s.tick(1.0 / 60.0)
	var hz := s.frequence_de(ids[0])
	verifier_egal(hz, 15.0, "%d ennemis, %d o par état : %s Hz" % [n, plus_gros, hz])


func test_1000_ennemis_descendent_entre_5_et_5_6_hz() -> void:
	_monter(1)
	var n := _enrichir(FOULE_GRANDE)
	for i: int in 60:
		s.tick(1.0 / 60.0)
	var hz := s.frequence_de(ids[0])
	verifier(hz >= 5.0 and hz <= 5.6, "%d ennemis : %s Hz" % [n, hz])


func test_le_debit_mesure_sur_10_s_tient_le_budget_a_un_paquet_pres() -> void:
	_monter(1)
	var n := _enrichir(FOULE_GRANDE)
	for i: int in 60:
		s.tick(1.0 / 60.0)
	_vider()
	for i: int in 600:
		s.tick(1.0 / 60.0)
	var total: int = octets_par_pair[ids[0]]
	var paquets: int = paquets_par_pair[ids[0]]
	print(
		(
			(
				"DEBIT T3.3 : %d ennemis, %d paquets en 10 s (%.1f Hz), %d o/s au total "
				+ "(budget %d), plus gros état %d o"
			)
			% [n, paquets, paquets / 10.0, total / 10, _budget(), plus_gros]
		)
	)
	verifier(
		total <= _budget() * 10 + plus_gros,
		"10 s : %d o pour un budget de %d" % [total, _budget() * 10]
	)
	verifier(paquets >= 50 and paquets <= 56, "5 à 5,6 Hz : %d paquets en 10 s" % paquets)
	verifier_egal(s.etats_trop_gros, 0)


func test_le_budget_de_50000_octets_par_seconde_tient_a_8_clients_et_1000_ennemis_en_regardant(
) -> void:
	_monter(8)
	var n := _enrichir(FOULE_GRANDE)
	# Chacun regarde l'arène du suivant : tous les pairs paient l'arène regardée.
	for i: int in ids.size():
		s.traiter_intention(
			ids[i],
			Protocole.encoder_intention(Protocole.Intention.REGARDER, ids[(i + 1) % ids.size()])
		)
	for i: int in 120:
		s.tick(1.0 / 60.0)
	_vider()
	for i: int in 600:
		s.tick(1.0 / 60.0)
	var pire := 0
	for pair: int in ids:
		pire = maxi(pire, int(octets_par_pair[pair]) / 10)
	var hz_propre := s.frequence_de(ids[0])
	var hz_regardee := s.frequence_regardee_de(ids[0])
	print(
		(
			(
				"DEBIT T8.10 : %d ennemis, 8 clients qui regardent : %d o/s au plus par client "
				+ "(budget %d), propre %.1f Hz, regardée %.1f Hz"
			)
			% [n, pire, _budget(), hz_propre, hz_regardee]
		)
	)
	# Mesuré : l'arène propre descend à 3,7 Hz et l'arène regardée à son plancher de 1 Hz, soit
	# 50 000 à 50 075 o/s par client : au paquet près (un état d'arène, ici 10 Ko), comme T3.3.
	for pair: int in ids:
		var total: int = octets_par_pair[pair]
		verifier(
			total <= _budget() * 10 + plus_gros,
			"client %d : %d o en 10 s pour un budget de %d" % [pair, total, _budget() * 10]
		)
		verifier(
			int(regardees_par_pair.get(pair, 0)) > 0, "client %d reçoit l'arène regardée" % pair
		)
	verifier(hz_regardee >= 1.0, "la fréquence regardée respecte son plancher")
	verifier_egal(s.etats_trop_gros, 0, "aucun état refusé par le protocole")


## Remplit chaque arène jusqu'aux plafonds d'alliés, de zones et de bombes : une manche qui
## change vide ces listes, donc la charge est rétablie avant chaque tour de boucle.
func _surcharger() -> void:
	for pair: int in ids:
		var arene: Arene = s.partie._joueur(pair).arene
		while arene.allies.taille < Protocole.MAX_ALLIES:
			arene.allies.invoquer(arene.allies.taille % 2, Vector2.ZERO, 900.0, 1.0, 0, 0)
		var k := 0
		while arene.poses.zones.size() < Protocole.MAX_ZONES:
			var zone: Dictionary = {
				"pos": Vector2(100.0 + float(k), 50.0),
				"rayon": 80.0,
				"duree": 900.0,
				"periode": 5.0,
				"degats": 1.0,
				"type_degats": 0,
				"statuts": [],
				"statut": 0,
				"arme": 0,
				"proprietaire": k
			}
			arene.poses.ajouter_zone(zone, 1)
			k += 1
		while arene.poses.bombes.size() < Protocole.MAX_BOMBES:
			var bombe: Dictionary = {
				"pos": Vector2(-100.0 - float(k), 50.0),
				"rayon": 80.0,
				"delai": 900.0,
				"degats": 1.0,
				"type_degats": 0,
				"statuts": [],
				"statut": 0,
				"arme": 0,
				"proprietaire": 1000 + k
			}
			arene.poses.ajouter_bombe(bombe, 1)
			k += 1


func test_le_debit_de_l_arene_la_plus_chargee_reste_sous_50_000_octets_par_seconde() -> void:
	_monter(8)
	var n := _enrichir(FOULE_GRANDE)
	for i: int in ids.size():
		s.traiter_intention(
			ids[i],
			Protocole.encoder_intention(Protocole.Intention.REGARDER, ids[(i + 1) % ids.size()])
		)
	for i: int in 120:
		_surcharger()
		s.tick(1.0 / 60.0)
	_vider()
	for i: int in 600:
		_surcharger()
		s.tick(1.0 / 60.0)
	var pire := 0
	for pair: int in ids:
		pire = maxi(pire, int(octets_par_pair[pair]) / 10)
	print(
		(
			(
				"DEBIT T9.9 : %d ennemis, 64 alliés, 32 zones, 32 bombes, 8 clients qui regardent : "
				+ "%d o/s au plus par client (budget %d), plus gros état %d o"
			)
			% [n, pire, _budget(), plus_gros]
		)
	)
	for pair: int in ids:
		var total: int = octets_par_pair[pair]
		verifier(
			total <= _budget() * 10 + plus_gros,
			"client %d : %d o en 10 s pour un budget de %d" % [pair, total, _budget() * 10]
		)
	var arene: Arene = s.partie._joueur(ids[0]).arene
	verifier_egal(arene.allies.taille, Protocole.MAX_ALLIES, "les alliés étaient bien là")
	verifier_egal(s.etats_trop_gros, 0, "aucun état refusé par le protocole")


func test_cout_de_la_boucle_avec_8_clients_en_fin_de_partie() -> void:
	_monter(8)
	var n := _enrichir(FOULE_GRANDE)
	for i: int in 120:
		s.tick(1.0 / 60.0)
	_vider()
	s.temps_sim_us = 0
	s.temps_envoi_us = 0
	var pire := 0
	var total_us := 0
	var ticks := 600
	for i: int in ticks:
		var t0 := Time.get_ticks_usec()
		s.tick(1.0 / 60.0)
		var dt := Time.get_ticks_usec() - t0
		total_us += dt
		pire = maxi(pire, dt)
	var moyen := total_us / ticks
	var debit_max := 0
	var hz_min := 1000.0
	for pair: int in ids:
		debit_max = maxi(debit_max, int(octets_par_pair[pair]) / 10)
		hz_min = minf(hz_min, float(int(paquets_par_pair[pair])) / 10.0)
	print(
		(
			(
				"MESURE T3.3 : 8 clients, au moins %d ennemis par arène, 10 s simulées : "
				+ "tour de boucle moyen %d µs (simulation %d µs, envoi %d µs), pire %d µs ; "
				+ "débit par client jusqu'à %d o/s pour un budget de %d, %.1f Hz au plus bas"
			)
			% [
				n,
				moyen,
				s.temps_sim_us / ticks,
				s.temps_envoi_us / ticks,
				pire,
				debit_max,
				_budget(),
				hz_min
			]
		)
	)
	verifier(moyen < 8000, "le tour de boucle moyen reste sous la moitié d'un pas de 60 Hz")
	for pair: int in ids:
		var debit := int(octets_par_pair[pair]) / 10
		verifier(debit <= _budget() + plus_gros, "client %d : %d o/s" % [pair, debit])
	verifier_egal(s.etats_trop_gros, 0, "aucun état refusé par le protocole")
