extends CasDeTest
## Vagues mêlées : chaque manche mêle deux ou trois familles dont une majoritaire. Le tirage vient
## de la partie (même graine, donc même annonce pour tous les joueurs) ; chaque apparition tire sa
## famille selon les poids. Les valeurs (poids, nombre de familles, manches d'entrée) viennent de
## `data/` ; le test d'une règle ne fige pas un chiffre d'équilibrage.

const GRAINES := 20
const MANCHES := 60
const DT := 0.05
const EPSILON_POIDS := 1e-6

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _est_convoi(c: Composition) -> bool:
	return c.familles.size() == 1 and c.familles[0] == d.familles.size()


func _mult(vitesse: float) -> Dictionary:
	return {"pv": 1.0, "degats": 1.0, "vitesse": vitesse, "resistance_controle": 1.0}


func _indices_modele(modele: String) -> Array[int]:
	var indices: Array[int] = []
	for i: int in d.familles.size():
		if String(d.familles[i]["modele"]) == modele:
			indices.append(i)
	return indices


func test_chaque_manche_a_deux_ou_trois_familles_distinctes_dont_une_majoritaire() -> void:
	var vagues: Dictionary = d.partie["vagues"]
	var mini := int(vagues["familles_min"])
	var maxi := int(vagues["familles_max"])
	for graine: int in range(1, GRAINES + 1):
		var planning := Planning.new(d, graine)
		for manche: int in range(1, MANCHES + 1):
			var c := planning.tirer(manche)
			if _est_convoi(c):
				continue
			var contexte := "graine %d manche %d" % [graine, manche]
			verifier(c.familles.size() >= mini and c.familles.size() <= maxi, contexte)
			var distinctes: Dictionary = {}
			for f: int in c.familles:
				distinctes[f] = true
				verifier(f >= 0 and f < d.familles.size(), "%s : famille %d" % [contexte, f])
			verifier_egal(distinctes.size(), c.familles.size(), "%s : doublon" % contexte)
			verifier_egal(c.majoritaire(), c.familles[0], contexte)
			verifier_egal(c.poids.size(), c.familles.size(), contexte)


func test_les_poids_valent_60_pour_la_majoritaire_et_le_reste_est_partage() -> void:
	var part := float((d.partie["vagues"] as Dictionary)["part_majoritaire"])
	verifier_proche(part, 0.6, EPSILON_POIDS, "la donnée de départ est 60 %")
	for graine: int in range(1, GRAINES + 1):
		var planning := Planning.new(d, graine)
		for manche: int in range(1, MANCHES + 1):
			var c := planning.tirer(manche)
			var somme := 0.0
			for p: float in c.poids:
				somme += p
			verifier_proche(
				somme, 1.0, EPSILON_POIDS, "somme, graine %d manche %d" % [graine, manche]
			)
			if _est_convoi(c):
				continue
			verifier_proche(c.poids[0], part, EPSILON_POIDS, "majoritaire")
			for i: int in range(1, c.poids.size()):
				var attendu := (1.0 - part) / float(c.poids.size() - 1)
				verifier_proche(c.poids[i], attendu, EPSILON_POIDS, "part de la famille %d" % i)


func test_jamais_la_meme_majoritaire_deux_manches_de_suite() -> void:
	for graine: int in range(1, GRAINES + 1):
		var planning := Planning.new(d, graine)
		var derniere := -1
		for manche: int in range(1, MANCHES + 1):
			var c := planning.tirer(manche)
			if _est_convoi(c):
				continue
			verifier_different(c.majoritaire(), derniere, "graine %d manche %d" % [graine, manche])
			derniere = c.majoritaire()


func test_l_archer_n_apparait_qu_a_partir_de_la_manche_5() -> void:
	var archers := _indices_modele("archer")
	verifier(not archers.is_empty(), "l'Archer est dans les données")
	var manche_min := int((d.familles[archers[0]] as Dictionary)["manche_min"])
	verifier(
		manche_min >= 5, "l'Archer n'entre jamais avant la manche 5 (donnée : %d)" % manche_min
	)
	var apres := false
	for graine: int in range(1, GRAINES + 1):
		var planning := Planning.new(d, graine)
		for manche: int in range(1, MANCHES + 1):
			for f: int in planning.tirer(manche).familles:
				if archers.has(f):
					verifier(manche >= manche_min, "archer manche %d, graine %d" % [manche, graine])
					apres = true
	verifier(apres, "l'Archer apparaît au moins une fois ensuite sur 20 graines")


func test_un_palier_n_entre_qu_a_sa_manche_d_entree() -> void:
	var paliers: Dictionary = {}
	for famille: Dictionary in d.familles:
		paliers[String(famille["palier"])] = int(famille["manche_entree"])
	verifier(paliers.size() >= 2, "plusieurs paliers")
	for palier: String in paliers:
		var entree: int = paliers[palier]
		var vu_des_l_entree := false
		for graine: int in range(1, GRAINES + 1):
			var planning := Planning.new(d, graine)
			for manche: int in range(1, MANCHES + 1):
				for f: int in planning.tirer(manche).familles:
					if f >= d.familles.size() or String(d.familles[f]["palier"]) != palier:
						continue
					verifier(
						manche >= entree,
						"palier %s à la manche %d (entrée %d)" % [palier, manche, entree]
					)
					vu_des_l_entree = true
		verifier(vu_des_l_entree, "le palier %s sort après son entrée" % palier)


func test_le_tirage_est_reproductible_avec_la_meme_graine() -> void:
	for graine: int in [1, 7, 99]:
		var a := Planning.new(d, graine)
		var b := Planning.new(d, graine)
		for manche: int in range(1, MANCHES + 1):
			var ca := a.tirer(manche)
			var cb := b.tirer(manche)
			verifier_egal(ca.familles, cb.familles, "familles, manche %d" % manche)
			verifier_egal(ca.poids, cb.poids, "poids, manche %d" % manche)
	var autre := Planning.new(d, 2)
	var meme := Planning.new(d, 1)
	var differe := false
	for manche: int in range(1, MANCHES + 1):
		if autre.tirer(manche).familles != meme.tirer(manche).familles:
			differe = true
	verifier(differe, "deux graines ne donnent pas le même planning")


func test_les_apparitions_suivent_les_poids_en_melange_et_non_par_blocs() -> void:
	var c := Composition.new()
	c.familles = PackedInt32Array([3, 7])
	c.poids = PackedFloat32Array([0.6, 0.4])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261126
	var majoritaires := 0
	var changements := 0
	var precedente := -1
	for _i: int in 600:
		var f := c.tirer(rng)
		verifier(f == 3 or f == 7, "famille %d" % f)
		majoritaires += 1 if f == 3 else 0
		if precedente >= 0 and f != precedente:
			changements += 1
		precedente = f
	verifier_proche(float(majoritaires) / 600.0, 0.6, 0.06, "part de la majoritaire")
	verifier(
		changements > 100, "%d changements de famille : un mélange, pas des blocs" % changements
	)


func test_une_composition_unique_ne_tire_pas_au_hasard() -> void:
	var c := Composition.unique(5)
	verifier_egal(c.familles, PackedInt32Array([5]))
	verifier_egal(c.majoritaire(), 5)
	verifier_proche(c.poids[0], 1.0, EPSILON_POIDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var etat := rng.state
	verifier_egal(c.tirer(rng), 5)
	verifier_egal(rng.state, etat, "le hasard n'est consommé que s'il y a un choix")


func test_le_budget_de_la_manche_est_inchange() -> void:
	d.partie["tour"]["pv"] = 1e12
	var plancher := float(d.partie["spawn_plancher"])
	var depart := float(d.partie["spawn_intervalle_depart"])
	var baisse := float(d.partie["spawn_baisse_par_manche"])
	var melee := Composition.new()
	melee.familles = PackedInt32Array([0, 1, 2])
	melee.poids = PackedFloat32Array([0.6, 0.2, 0.2])
	for manche: int in [1, 5, 10, 30]:
		var intervalle := maxf(plancher, depart - baisse * float(manche - 1))
		var attendu := int(floor(30.0 / intervalle + 1e-9))
		for composition: Composition in [Composition.unique(0), melee]:
			var a := Arene.new(d, 11)
			a.demarrer_manche(manche, composition, _mult(0.0))
			for _pas: int in 600:
				a.avancer(DT)
			verifier_egal(
				a.nombre_ennemis(),
				attendu,
				"manche %d, %d famille(s)" % [manche, composition.familles.size()]
			)


func test_le_convoi_garde_sa_composition_unique_et_le_boss_n_en_a_pas() -> void:
	var vu := false
	for graine: int in range(1, GRAINES + 1):
		var planning := Planning.new(d, graine)
		for manche: int in range(1, MANCHES + 1):
			var c := planning.tirer(manche)
			if not _est_convoi(c):
				continue
			vu = true
			verifier_egal(c.familles.size(), 1)
			verifier_proche(c.poids[0], 1.0, EPSILON_POIDS)
	verifier(vu, "un convoi sort")
	d.partie["tour"]["pv"] = 1e12
	var a := Arene.new(d, 3)
	a.demarrer_boss(_mult(1.0))
	var v := a.vue(Types.Phase.BOSS, 10.0, -1, false)
	verifier(v.prochaines_familles.is_empty(), "le boss n'annonce aucune famille")
	verifier(v.prochaines_armures.is_empty())
	verifier_egal(v.prochaine_famille, -1)


func test_le_mode_sans_fin_garde_toutes_les_familles_possibles_et_les_multiplicateurs_continuent(
) -> void:
	var vues: Dictionary = {}
	for graine: int in range(1, GRAINES + 1):
		var planning := Planning.new(d, graine)
		for manche: int in range(40, 140):
			for f: int in planning.tirer(manche).familles:
				vues[f] = true
	for f: int in d.familles.size():
		verifier(vues.has(f), "la famille %d (%s) sort en sans fin" % [f, d.familles[f]["id"]])
	for manche: int in range(40, 60):
		var avant := Planning.multiplicateurs(d, manche, 0.0)
		var apres := Planning.multiplicateurs(d, manche + 1, 0.0)
		verifier(float(apres["pv"]) > float(avant["pv"]), "PV manche %d" % (manche + 1))
		verifier(float(apres["degats"]) > float(avant["degats"]), "dégâts manche %d" % (manche + 1))


func test_la_vue_annonce_les_familles_et_leurs_armures() -> void:
	var donnees := AidesPartie.donnees({"partie.json": [[["tour", "pv"], 1e12]]})
	var p := AidesPartie.partie(donnees, 17, 1, 0.05)
	var phases_vues: Dictionary = {}
	for _i: int in 600:
		p.avancer(DT)
		var v := p.vue_arene(1, 1)
		if v == null or (v.phase != Types.Phase.PREPARATION and v.phase != Types.Phase.MANCHE):
			continue
		phases_vues[v.phase] = true
		verifier(
			v.prochaines_familles.size() >= 1 and v.prochaines_familles.size() <= 3,
			"1 à 3 familles"
		)
		verifier_egal(v.prochaines_armures.size(), v.prochaines_familles.size())
		verifier_egal(v.prochaine_famille, v.prochaines_familles[0])
		verifier_egal(v.prochaine_armure, v.prochaines_armures[0])
		for i: int in v.prochaines_familles.size():
			var f := v.prochaines_familles[i]
			var armure := (
				Types.Armure.AUCUNE
				if f >= donnees.familles.size()
				else int(donnees.familles[f]["armure"])
			)
			verifier_egal(int(v.prochaines_armures[i]), armure, "armure de la famille %d" % f)
	verifier(
		phases_vues.has(Types.Phase.PREPARATION) and phases_vues.has(Types.Phase.MANCHE),
		"préparation et manche vues"
	)


func test_le_tirage_est_le_meme_pour_tous_les_joueurs() -> void:
	var donnees := AidesPartie.donnees({"partie.json": [[["tour", "pv"], 1e12]]})
	var p := AidesPartie.partie(donnees, 23, 3, 0.05)
	var manches_vues: Dictionary = {}
	for _i: int in 600:
		p.avancer(DT)
		var v1 := p.vue_arene(1, 1)
		var v2 := p.vue_arene(2, 2)
		var v3 := p.vue_arene(3, 3)
		if v1 == null or v2 == null or v3 == null:
			continue
		verifier_egal(
			v2.prochaines_familles, v1.prochaines_familles, "joueur 2, manche %d" % v1.manche
		)
		verifier_egal(
			v3.prochaines_familles, v1.prochaines_familles, "joueur 3, manche %d" % v1.manche
		)
		verifier_egal(v2.prochaines_armures, v1.prochaines_armures)
		manches_vues[v1.manche] = true
	verifier(manches_vues.size() >= 4, "plusieurs manches comparées (%d)" % manches_vues.size())


func test_tous_les_joueurs_affrontent_les_memes_familles_dans_le_meme_ordre() -> void:
	d.partie["tour"]["pv"] = 1e12
	var melee := Composition.new()
	melee.familles = PackedInt32Array([0, 1, 2])
	melee.poids = PackedFloat32Array([0.6, 0.2, 0.2])
	melee.graine = 4242
	var suites: Array[PackedInt32Array] = []
	for graine_arene: int in [11, 12, 13]:
		var a := Arene.new(d, graine_arene)
		a.demarrer_manche(3, melee, _mult(0.0))
		for _pas: int in 600:
			a.avancer(DT)
		var suite := PackedInt32Array()
		for i: int in a.ennemis.ids.size():
			suite.append(int(a.ennemis.famille[i]))
		suites.append(suite)
	verifier(suites[0].size() > 5, "des ennemis sont apparus")
	verifier_egal(suites[1], suites[0], "joueur 2 comme joueur 1")
	verifier_egal(suites[2], suites[0], "joueur 3 comme joueur 1")
