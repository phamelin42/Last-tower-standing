extends CasDeTest
## Retour de partie de Phil (27/11) : « 700 ennemis qui tapaient ma tour et mes hp qui ne
## descendaient pas ». Esquive, réduction des épines, armure et réduction tant que la mana se
## multiplient sans plancher : au bout, 5 % des dégâts passaient. Quelle que soit la construction,
## au moins `1 − partie.json reduction_degats_max` (15 %) des dégâts bruts de la manche
## atteignent la tour, appliqués une fois après toutes les couches ; la mana qu'elle porte les
## absorbe ensuite.

const DT := 0.05
const GRAINE := 7
const PV := 1.0e9
## Une attaque tous les deux pas de 0,05 s.
const CADENCE_TEST := 16.0
const PAS := 200
const DEGATS := 100.0
## Les quatre couches, chacune poussée à son maximum.
const COUCHES: Array[String] = ["esquive", "epines_reduction", "armure", "reduction_mana"]

var d: Donnees
var _compte: int = 0


func avant_chaque() -> void:
	d = Donnees.charger()
	# Ce test vérifie l'ordre des couches, pas le prix de la mana : un point de mana par point de dégât.
	(d.partie["tour"] as Dictionary)["mana_cout_par_pv"] = 1.0
	_compte = 0


func _plancher() -> float:
	return 1.0 - float(d.partie["reduction_degats_max"])


func _donner(a: Arene, stat: String, valeur: float) -> void:
	_compte += 1
	var id := "essai_%d" % _compte
	d.ameliorations[id] = {
		"id": id,
		"nom": id,
		"description": id,
		"rarete": Types.Rarete.COMMUNE,
		"prix": 1,
		"categorie": Types.Categorie.AMELIORATION,
		"famille": "epines",
		"effets": [{"stat": stat, "valeur": valeur}],
	}
	a.inventaire.ameliorations[id] = 1
	a.synchroniser()


## Une tour dont les couches de `couches` sont au maximum, face à un ennemi qui frappe `DEGATS`
## tous les deux pas. Rend ce qui l'atteint : les PV perdus plus la mana absorbée. Une réserve de
## mana énorme garde la réduction « tant que la mana » active, sans régénération.
func _perdu_avec(couches: Array[String], cac: bool = true) -> float:
	d.partie["tour"]["mana_max"] = 1.0e9
	d.partie["tour"]["mana_regen"] = 0.0
	d.partie["tour"]["pv"] = PV
	var a := Arene.new(d, GRAINE)
	for couche: String in couches:
		match couche:
			"esquive":
				_donner(a, "esquive", 1.0e6)
			"epines_reduction":
				_donner(a, "epines_reduction", 10.0)
			"armure":
				_donner(a, "armure", 1.0e6)
			"reduction_mana":
				_donner(a, "reduction_tant_que_mana", 10.0)
	var portee := 40.0 if cac else 450.0
	a.ennemis.ajouter(0, Vector2(100, 0), PV, 0.0, DEGATS, portee, CADENCE_TEST, 0, 4)
	var avant := a.pv + a.mana
	for _i: int in PAS:
		a.avancer(DT)
	return avant - a.pv - a.mana


func _brut() -> float:
	return DEGATS * float(PAS) / 2.0


func test_la_donnee_est_un_ratio_strictement_inferieur_a_un() -> void:
	var r := float(d.partie["reduction_degats_max"])
	verifier(r > 0.0 and r < 1.0, "reduction_degats_max = %s" % r)
	verifier_proche(r, 0.85, 0.0001, "15 % minimum, décision de Phil du 27/11")


func test_toutes_les_combinaisons_de_couches_au_maximum_laissent_passer_au_moins_15_pour_cent(
) -> void:
	for masque: int in range(1 << COUCHES.size()):
		var couches: Array[String] = []
		for k: int in COUCHES.size():
			if (masque >> k) & 1 == 1:
				couches.append(COUCHES[k])
		for cac: bool in [true, false]:
			var perdu := _perdu_avec(couches, cac)
			verifier(
				perdu >= _plancher() * _brut() - 0.001,
				"%s (cac=%s) : %.1f perdus sur %.0f bruts" % [couches, cac, perdu, _brut()]
			)


func test_sans_couche_la_tour_subit_tout_et_le_plancher_ne_la_soigne_pas() -> void:
	var perdu := _perdu_avec([])
	verifier_proche(perdu, _brut(), 0.01, "sans défense, 100 % des dégâts")


func test_une_defense_modeste_au_dessus_du_plancher_n_est_pas_touchee() -> void:
	# Réduction des épines de 20 % (corps à corps) : 80 % passent, au-dessus de 15 %.
	d.partie["tour"]["mana_max"] = 0.0
	d.partie["tour"]["pv"] = PV
	var a := Arene.new(d, GRAINE)
	_donner(a, "epines_reduction", 0.2)
	a.ennemis.ajouter(0, Vector2(100, 0), PV, 0.0, DEGATS, 40.0, CADENCE_TEST, 0, 4)
	var avant := a.pv
	for _i: int in PAS:
		a.avancer(DT)
	verifier_proche(avant - a.pv, _brut() * 0.8, 0.01, "le plancher ne change rien à 80 %")


func test_la_mana_absorbe_apres_le_plancher() -> void:
	# Une réserve de mana de 30 absorbe les premiers points : le plancher s'applique d'abord.
	d.partie["tour"]["mana_max"] = 30.0
	d.partie["tour"]["pv"] = PV
	var a := Arene.new(d, GRAINE)
	_donner(a, "esquive", 1.0e6)
	_donner(a, "armure", 1.0e6)
	a.ennemis.ajouter(0, Vector2(100, 0), PV, 0.0, DEGATS, 40.0, CADENCE_TEST, 0, 4)
	var avant_pv := a.pv
	var avant_mana := a.mana
	for _i: int in 2:
		a.avancer(DT)
	# Premier pas : une attaque de 100 → plancher 15 → absorbés par la mana (30 disponibles).
	verifier_proche(avant_mana - a.mana, 15.0, 0.1, "la mana absorbe le plancher")
	verifier_proche(avant_pv - a.pv, 0.0, 0.01, "aucun PV perdu tant que la mana tient")
