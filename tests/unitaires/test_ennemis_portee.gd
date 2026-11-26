extends CasDeTest
## Portée des ennemis, explosion du Tonneau au contact et familles qui n'entrent qu'à leur manche.
## Les valeurs viennent de `Donnees.familles` : un réglage de `data/ennemis.json` ne casse rien
## ici tant que les rôles (qui s'arrête où, qui explose) restent les mêmes.

const DT := 0.05
const GRAINE := 77
const CENTRE := Vector2.ZERO
const PORTEE_DYNAMITE := 350.0
const PORTEE_ARCHER := 650.0
## Budget du pas d'une arène sous 1 000 Tonneaux au contact (spec du lot 8).
const BUDGET_PAS_MS := 5.0

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


# --- Aides -------------------------------------------------------------------------------------


func _mult() -> Dictionary:
	return {"pv": 1.0, "degats": 1.0, "vitesse": 0.0, "resistance_controle": 1.0}


func _indice_famille(id: String) -> int:
	for i: int in d.familles.size():
		if d.familles[i]["id"] == id:
			return i
	return -1


## Ajoute à `e` un ennemi de la famille `indice`, avec toutes ses valeurs de données ; `vitesse`
## remplace la vitesse de la famille (0 : il reste où on le pose).
func _ajouter_famille(e: Ennemis, indice: int, position: Vector2, vitesse: float = -1.0) -> int:
	var f: Dictionary = d.familles[indice]
	return e.ajouter(
		indice,
		position,
		float(f["pv"]),
		float(f["vitesse"]) if vitesse < 0.0 else vitesse,
		float(f["degats"]),
		float(f["portee_attaque"]),
		float(f["cadence_attaque"]),
		int(f["prime"]),
		int(f["armure"]),
		bool(f["explose"])
	)


func _vue(a: Arene) -> VueArene:
	return a.vue(Types.Phase.MANCHE, 10.0, -1, false)


func _avec_amelioration(a: Arene, id: String, nombre: int) -> void:
	a.inventaire.ameliorations[id] = nombre
	a.synchroniser()


func _rayon_tour() -> float:
	return float(d.partie["tour"]["rayon"])


## Une arène immobile avec un Tonneau déjà au contact de la tour.
func _arene_avec_tonneau() -> Arene:
	var a := Arene.new(d, GRAINE)
	var i := _indice_famille("tonneau_jaune")
	_ajouter_famille(a.ennemis, i, _au_contact_arene(i), 0.0)
	return a


## Position où un ennemi de la famille `indice` est déjà au contact de la tour.
func _au_contact_arene(indice: int) -> Vector2:
	return Vector2(_rayon_tour() + float(d.familles[indice]["portee_attaque"]), 0.0)


# --- Où chaque famille s'arrête ----------------------------------------------------------------


func test_la_dynamite_s_arrete_a_350_et_l_archer_a_650() -> void:
	for cas: Array in [["dynamite_jaune", PORTEE_DYNAMITE], ["archer_jaune", PORTEE_ARCHER]]:
		var e := Ennemis.new(d)
		var i := _indice_famille(cas[0])
		verifier(i >= 0, "famille %s présente" % cas[0])
		_ajouter_famille(e, i, Vector2(1300.0, 0.0))
		for _k: int in 800:
			e.avancer(DT, CENTRE, _rayon_tour(), 1.0, 1.0)
		var distance := e.pos[0].distance_to(CENTRE)
		verifier_proche(distance, cas[1], Ennemis.TOLERANCE_ARRET, "%s : distance" % cas[0])


func test_chaque_famille_s_arrete_a_sa_portee_d_attaque() -> void:
	for i: int in d.familles.size():
		var f: Dictionary = d.familles[i]
		var e := Ennemis.new(d)
		_ajouter_famille(e, i, Vector2(1300.0, 0.0))
		# Accélérés : on ne teste pas la vitesse mais l'endroit où ils s'arrêtent.
		for _k: int in 600:
			e.avancer(DT, CENTRE, _rayon_tour(), 8.0, 1.0)
		var portee: float = f["portee_attaque"]
		var attendu := _rayon_tour() + portee if portee <= Ennemis.PORTEE_CORPS_A_CORPS else portee
		if e.taille == 0:
			# Un Tonneau a explosé au contact : il est arrivé là.
			verifier(bool(f["explose"]), "%s a disparu sans exploser" % f["id"])
			continue
		verifier_proche(
			e.pos[0].distance_to(CENTRE), attendu, Ennemis.TOLERANCE_ARRET, "%s" % f["id"]
		)


# --- Explosion du Tonneau ----------------------------------------------------------------------


func test_le_tonneau_explose_au_contact() -> void:
	var a := _arene_avec_tonneau()
	var f: Dictionary = d.familles[_indice_famille("tonneau_jaune")]
	var pv_avant := a.pv
	var argent := a.economie.argent
	a.avancer(DT)
	var attendu := Combat.degats_subis(float(f["degats"]), float(d.partie["tour"]["armure"]))
	verifier_proche(pv_avant - a.pv, attendu, 0.01, "dégâts du Tonneau, armure déduite")
	verifier(attendu > 0.0, "contrôle : le Tonneau fait des dégâts")
	verifier_egal(a.nombre_ennemis(), 0, "le Tonneau a disparu")
	var vue := _vue(a)
	verifier_egal(vue.eliminations, 0, "une explosion n'est pas une élimination")
	verifier_egal(a.economie.argent, argent, "et ne rapporte aucune prime")
	var morts := vue.evenements.filter(func(ev: Dictionary) -> bool: return ev["k"] == "mort")
	verifier_egal(morts.size(), 1, "un événement de mort pour le faire disparaître à l'écran")
	if not morts.is_empty():
		verifier_egal(morts[0]["de"], _au_contact_arene(_indice_famille("tonneau_jaune")))
	# Une seule fois : les pas suivants ne coûtent plus rien.
	var pv_apres := a.pv
	for _k: int in 40:
		a.avancer(DT)
	verifier_proche(a.pv, pv_apres, 0.0001, "une explosion, pas une attaque répétée")


func test_l_explosion_est_multipliee_par_le_multiplicateur_de_degats() -> void:
	for mult: float in [0.5, 1.0, 2.5]:
		var e := Ennemis.new(d)
		var i := _indice_famille("tonneau_jaune")
		_ajouter_famille(e, i, _au_contact_arene(i), 0.0)
		var r := e.avancer(DT, CENTRE, _rayon_tour(), 1.0, mult)
		var attendu := float(d.familles[i]["degats"]) * mult
		verifier_proche(float(r["degats_tour"]), attendu, 0.01, "multiplicateur %s" % mult)
		verifier_egal((r["explosions"] as PackedInt32Array).size(), 1)
		verifier_egal((r["attaquants_cac"] as PackedInt32Array).size(), 0, "pas un attaquant")
		var retires := e.purger()
		verifier_egal(retires.size(), 1)
		verifier(bool(retires[0]["sans_prime"]), "mort sans prime")


func test_un_tonneau_tue_avant_le_contact_rapporte_sa_prime() -> void:
	var gains: Array[int] = []
	var eliminations: Array[int] = []
	var degats_tour: Array[float] = []
	# Le même ennemi, avec puis sans explosion : tué de loin, il rapporte exactement la même prime.
	for explose: bool in [true, false]:
		var a := Arene.new(d, GRAINE)
		var i := _indice_famille("tonneau_jaune")
		var f: Dictionary = d.familles[i]
		var id := a.ennemis.ajouter(
			i,
			Vector2(900.0, 0.0),
			float(f["pv"]),
			0.0,
			float(f["degats"]),
			float(f["portee_attaque"]),
			float(f["cadence_attaque"]),
			int(f["prime"]),
			int(f["armure"]),
			explose
		)
		var argent := a.economie.argent
		var pv := a.pv
		a.ennemis.infliger(a.ennemis.indice_de(id), 1e9, Types.TypeDegats.CHAOS)
		a.avancer(DT)
		gains.append(a.economie.argent - argent)
		eliminations.append(_vue(a).eliminations)
		degats_tour.append(pv - a.pv)
	verifier(gains[0] > 0, "une prime est versée")
	verifier_egal(gains[0], gains[1], "la prime ne dépend pas de la capacité d'exploser")
	verifier_egal(eliminations[0], 1, "et l'élimination est comptée")
	verifier_proche(degats_tour[0], 0.0, 0.0001, "mort de loin : aucun dégât à la tour")


func test_l_explosion_peut_etre_esquivee_mais_le_tonneau_disparait_quand_meme() -> void:
	# Contrôle : sans esquive la tour encaisse ; avec une esquive écrasante, elle ne perd rien.
	var sans := _arene_avec_tonneau()
	var pv_sans := sans.pv
	sans.avancer(DT)
	verifier(pv_sans - sans.pv > 0.0, "contrôle : sans esquive, la tour est touchée")
	var a := _arene_avec_tonneau()
	_avec_amelioration(a, "meurtrieres_biaisees", 100000)
	var pv_avant := a.pv
	var argent := a.economie.argent
	a.avancer(DT)
	verifier_proche(a.pv, pv_avant, 0.0001, "coup esquivé")
	verifier_egal(a.nombre_ennemis(), 0, "le Tonneau disparaît quand même")
	verifier_egal(a.economie.argent, argent, "sans prime")
	var vue := _vue(a)
	verifier_egal(vue.eliminations, 0)
	var morts := vue.evenements.filter(func(ev: Dictionary) -> bool: return ev["k"] == "mort")
	verifier_egal(morts.size(), 1, "il disparaît aussi à l'écran")


func test_l_explosion_ne_declenche_pas_les_epines() -> void:
	# Contrôle : un attaquant au corps à corps ordinaire subit les épines.
	var temoin := Arene.new(d, GRAINE)
	_avec_amelioration(temoin, "couronne_d_epines", 1)
	var t := _indice_famille("torche_jaune")
	_ajouter_famille(temoin.ennemis, t, _au_contact_arene(t), 0.0)
	for _k: int in 20:
		temoin.avancer(DT)
	verifier(_vue(temoin).degats_infliges > 0.0, "contrôle : les épines frappent un attaquant")
	var a := _arene_avec_tonneau()
	_avec_amelioration(a, "couronne_d_epines", 1)
	var pv_avant := a.pv
	a.avancer(DT)
	verifier(a.pv < pv_avant, "le Tonneau a bien explosé")
	verifier_proche(_vue(a).degats_infliges, 0.0, 0.0001, "aucun dégât d'épines")


func test_mille_tonneaux_au_contact_sous_5_ms_par_pas() -> void:
	# Armure démesurée : la tour survit aux 1 000 explosions de chaque pas.
	d.partie["tour"]["armure"] = 1e9
	var a := Arene.new(d, GRAINE)
	var i := _indice_famille("tonneau_jaune")
	var durees := PackedInt32Array()
	var pas := 200
	for _k: int in pas:
		for n: int in 1000:
			_ajouter_famille(a.ennemis, i, _au_contact_arene(i).rotated(n * 0.00628), 0.0)
		verifier_egal(a.nombre_ennemis(), 1000)
		var debut := Time.get_ticks_usec()
		a.avancer(DT)
		durees.append(Time.get_ticks_usec() - debut)
		verifier_egal(a.nombre_ennemis(), 0, "les 1 000 Tonneaux ont explosé")
		_vue(a)
	# La médiane d'un pas : un ramasse-miettes ou une machine chargée ne fait pas échouer le test.
	var triees := durees.duplicate()
	triees.sort()
	var mediane_ms := float(triees[pas / 2]) / 1000.0
	var total := 0
	for duree: int in durees:
		total += duree
	var moyenne_ms := float(total) / 1000.0 / float(pas)
	print(
		(
			"PERF 1 000 Tonneaux au contact : médiane %.3f ms, moyenne %.3f ms par pas"
			% [mediane_ms, moyenne_ms]
		)
	)
	verifier(
		mediane_ms < BUDGET_PAS_MS, "%.2f ms par pas (budget %s)" % [mediane_ms, BUDGET_PAS_MS]
	)
	verifier_faux(a.est_detruite(), "la tour est restée debout")


# --- Planning ----------------------------------------------------------------------------------


func test_planning_ne_sort_que_des_familles_entrees() -> void:
	var paliers_vus: Dictionary = {}
	for graine: int in range(1, 21):
		var planning := Planning.new(d, graine)
		for manche: int in range(1, 41):
			var famille := planning.tirer(manche)
			if famille >= d.familles.size():
				continue
			verifier(famille >= 0, "une famille est toujours tirée")
			var f: Dictionary = d.familles[famille]
			var nom := "%s à la manche %d (graine %d)" % [f["id"], manche, graine]
			verifier(manche >= int(f["manche_entree"]), "%s : palier pas encore entré" % nom)
			verifier(manche >= int(f["manche_min"]), "%s : modèle pas encore arrivé" % nom)
			paliers_vus[f["indice_palier"]] = true
	# Contrôle : le filtre n'est pas vide de sens, chaque palier finit par sortir.
	var nb_paliers: int = (
		(
			JSON.parse_string(FileAccess.get_file_as_string("res://data/ennemis.json"))["paliers"]
			as Array
		)
		. size()
	)
	for p: int in nb_paliers:
		verifier(paliers_vus.has(p), "le palier %d ne sort jamais" % p)
