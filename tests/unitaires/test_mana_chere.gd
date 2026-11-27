extends CasDeTest
## Fin de partie, mana (Phil, 27/11/2026 : « le mana ça semble trop fort ») : le siphon rend au plus
## un plafond de mana par seconde à toute la tour, quelle que soit la foule, un point de dégât
## absorbé coûte plus d'un point de mana (D12 : le bouclier absorbe toujours tout), et la rampe de
## dégâts après la table monte à chaque manche.

const DT := 0.05
const FOULES: Array[int] = [10, 50, 200, 1000, 2000]
const DEBIT_PAR_ENNEMI := 10.0
const COUTS: Array[float] = [1.0, 2.0, 3.0, 5.0]

var d: Donnees


func avant_chaque() -> void:
	d = AidesPartie.donnees()


func _arene(donnees: Donnees, mana_max_bonus: float) -> Arene:
	var a := Arene.new(donnees, 99)
	a.demarrer_manche(
		1,
		Composition.unique(0),
		{"pv": 1.0, "degats": 1.0, "vitesse": 0.0, "resistance_controle": 1.0}
	)
	a._stats.mana_max_bonus = mana_max_bonus
	return a


func _plafond() -> float:
	return float((d.partie["tour"] as Dictionary)["siphon_mana_max_par_s"])


func _cout() -> float:
	return float((d.partie["tour"] as Dictionary)["mana_cout_par_pv"])


func test_le_cout_et_le_plafond_sont_des_valeurs_qui_pesent() -> void:
	verifier(_plafond() > 0.0 and _plafond() <= 1000.0, "plafond du siphon : %s" % _plafond())
	verifier(_cout() > 1.0, "un point de dégât coûte plus d'un point de mana : %s" % _cout())


func test_le_siphon_de_toute_la_tour_ne_depasse_jamais_le_plafond_quelle_que_soit_la_foule(
) -> void:
	for foule: int in FOULES:
		var a := _arene(d, 1.0e7)
		a.mana = 0.0
		for _k: int in foule:
			var id := a.ennemis.ajouter(0, Vector2(900, 0), 1.0e9, 0.0, 0.0, 40.0, 1.0, 1, 0)
			a.ennemis.siphonner(a.ennemis.indice_de(id), 0, DEBIT_PAR_ENNEMI, 3.0)
		var regen := float((d.partie["tour"] as Dictionary)["mana_regen"])
		for _t: int in 20:
			a.avancer(DT)
		# Une seconde : le siphon plafonné plus la régénération de base, jamais plus.
		var attendu := minf(float(foule) * DEBIT_PAR_ENNEMI, _plafond()) + regen
		verifier_proche(a.mana, attendu, 1.0, "%d ennemis siphonnés" % foule)
		verifier(a.mana <= _plafond() + regen + 1.0, "%d ennemis : plafond tenu" % foule)


func test_un_petit_siphon_sous_le_plafond_n_est_pas_rogne() -> void:
	var a := _arene(d, 1.0e5)
	a.mana = 0.0
	var id := a.ennemis.ajouter(0, Vector2(900, 0), 1.0e9, 0.0, 0.0, 40.0, 1.0, 1, 0)
	a.ennemis.siphonner(a.ennemis.indice_de(id), 0, DEBIT_PAR_ENNEMI, 3.0)
	for _t: int in 20:
		a.avancer(DT)
	var regen := float((d.partie["tour"] as Dictionary)["mana_regen"])
	verifier_proche(a.mana, DEBIT_PAR_ENNEMI + regen, 0.2, "un ennemi : son débit entier")


## Mana perdue par la tour sur un pas où un ennemi au corps à corps l'attaque, et PV perdus.
func _un_coup(cout: float, mana_depart: float) -> Vector2:
	var donnees := AidesPartie.donnees({"partie.json": [[["tour", "mana_cout_par_pv"], cout]]})
	var a := _arene(donnees, 1000.0)
	a.mana = mana_depart
	a.ennemis.ajouter(0, Vector2(100, 0), 1.0e6, 0.0, 10.0, 40.0, 1.0, 1, 0)
	var pv_avant := a.pv
	var regen := float((donnees.partie["tour"] as Dictionary)["mana_regen"])
	a.avancer(DT)
	return Vector2(mana_depart + regen * DT - a.mana, pv_avant - a.pv)


func test_un_point_de_degat_absorbe_coute_le_cout_en_mana() -> void:
	var de_reference := _un_coup(1.0, 500.0)
	verifier(de_reference.x > 0.0, "le coup absorbe de la mana")
	verifier_proche(de_reference.y, 0.0, 0.001, "tout est absorbé")
	for cout: float in COUTS:
		var r := _un_coup(cout, 500.0)
		verifier_proche(r.x, de_reference.x * cout, 0.001, "mana perdue au coût %s" % cout)
		verifier_proche(r.y, 0.0, 0.001, "toujours absorbé en entier au coût %s" % cout)


func test_une_mana_qui_ne_couvre_plus_le_coup_laisse_passer_le_reste_et_plus_cher_plus_il_passe(
) -> void:
	var precedent := -1.0
	for cout: float in COUTS:
		var r := _un_coup(cout, 4.0)
		verifier(r.y >= precedent - 0.0001, "PV perdus au coût %s : %s" % [cout, r.y])
		precedent = r.y
	verifier(_un_coup(5.0, 4.0).y > _un_coup(1.0, 4.0).y, "un coût plus haut laisse passer plus")


func test_la_rampe_de_degats_apres_la_table_monte_strictement_a_chaque_manche() -> void:
	var apres: Dictionary = d.difficulte["apres_table"]
	verifier(float(apres["degats"]) >= 1.14, "rampe de dégâts : %s" % apres["degats"])
	var derniere_manche := int((d.difficulte["paliers"] as Array).back()["manche"])
	var precedent := Planning.multiplicateurs(d, 1, 0.0)
	for manche: int in range(2, derniere_manche + 40):
		var m := Planning.multiplicateurs(d, manche, 0.0)
		verifier(
			float(m["degats"]) > float(precedent["degats"]),
			"dégâts strictement croissants, manche %d" % manche
		)
		verifier(
			float(m["pv"]) > float(precedent["pv"]), "PV strictement croissants, manche %d" % manche
		)
		if manche > derniere_manche:
			verifier_proche(
				float(m["degats"]) / float(precedent["degats"]), float(apres["degats"]), 0.0001
			)
		precedent = m
