extends CasDeTest
## Formules de combat : ce que le joueur obtient d'un coup, d'un critique, d'un contrôle.

const PALIER := 0.05


func _p(recu: float, attendu: float, message: String = "") -> void:
	verifier_proche(recu, attendu, 0.0001, message)


func _table() -> Array:
	var brut: Dictionary = {}
	for nom: String in ["partie.json", "economie.json", "difficulte.json", "efficacite.json"]:
		brut[nom] = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + nom))
	brut["boutique.json"] = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/boutique.json")
	)
	brut["armes.json"] = []
	brut["ameliorations.json"] = []
	brut["ennemis.json"] = {"familles": [], "convoi": {}, "boss": {}}
	var d := Donnees.depuis_brut(brut)
	return d.efficacite


func test_efficacite_des_trente_couples() -> void:
	var table := _table()
	var doubles := {
		Types.TypeDegats.TRANCHANT: Types.Armure.MOYENNE,
		Types.TypeDegats.PERCANT: Types.Armure.LEGERE,
		Types.TypeDegats.MAGIQUE: Types.Armure.LOURDE,
		Types.TypeDegats.SIEGE: Types.Armure.FORTIFIEE,
	}
	for t: int in range(5):
		for a: int in range(6):
			var attendu := 2.0 if doubles.get(t, -1) == a else 1.0
			_p(Combat.efficacite(table, t, a), attendu, "type %d armure %d" % [t, a])


func test_efficacite_hors_bornes_reste_neutre() -> void:
	var table := _table()
	_p(Combat.efficacite(table, -1, 0), 1.0)
	_p(Combat.efficacite(table, 0, 99), 1.0)
	_p(Combat.efficacite([], 0, 0), 1.0)


func test_reduction_armure() -> void:
	_p(Combat.reduction_armure(0.0), 0.0)
	_p(Combat.reduction_armure(20.0), 0.5)
	_p(Combat.reduction_armure(-5.0), 0.0)
	var precedente := 0.0
	for a: float in [1.0, 10.0, 100.0, 1e4, 1e9]:
		var r := Combat.reduction_armure(a)
		verifier(r > precedente and r < 1.0, "armure %s : %s" % [a, r])
		precedente = r
	_p(Combat.degats_subis(100.0, 20.0), 50.0)
	_p(Combat.degats_subis(100.0, -3.0), 100.0)


func test_chance_critique_par_paliers() -> void:
	var cas := {
		0.0: 0.0, 0.04: 0.0, 0.05: 0.05, 0.99: 0.95, 1.0: 1.0, 1.5: 1.0, 3.0: 1.0, 0.15: 0.15
	}
	for entree: float in cas:
		var attendu: float = cas[entree]
		_p(Combat.chance_critique_effective(entree, PALIER), attendu, "chance %s" % entree)
	# Chaque multiple de palier reste sur lui-même malgré l'arrondi flottant.
	for k: int in range(0, 21):
		var chance := k * PALIER
		_p(Combat.chance_critique_effective(chance, PALIER), chance, "k=%d" % k)
	_p(Combat.chance_critique_effective(-0.2, PALIER), 0.0)


func test_puissance_critique_excedent() -> void:
	_p(Combat.puissance_critique(0.5, 2.0, 1.0), 2.0)
	_p(Combat.puissance_critique(1.0, 2.0, 1.0), 2.0)
	_p(Combat.puissance_critique(1.5, 2.0, 1.0), 2.5)
	_p(Combat.puissance_critique(3.0, 2.0, 1.0), 4.0)
	_p(Combat.puissance_critique(3.0, 2.0, 0.5), 3.0)


func test_esquive_rendement_decroissant() -> void:
	_p(Combat.chance_esquive(0.0, 1.0), 0.0)
	_p(Combat.chance_esquive(-4.0, 1.0), 0.0)
	var precedente := 0.0
	var gain_precedent := 1.0
	for points: int in range(1, 200):
		var e := Combat.chance_esquive(float(points), 1.0)
		verifier(e > precedente and e < 1.0, "points %d" % points)
		verifier(e - precedente < gain_precedent, "rendement croissant à %d" % points)
		gain_precedent = e - precedente
		precedente = e
	_p(Combat.chance_esquive(0.0, 0.0), 0.0, "k nul sans division par zéro")


func test_etourdissement_selon_la_resistance() -> void:
	_p(Combat.duree_etourdissement(2.0, 1.0), 2.0)
	_p(Combat.duree_etourdissement(2.0, 0.5), 1.0)
	_p(Combat.duree_etourdissement(2.0, 0.1), 0.2)
	_p(Combat.duree_etourdissement(2.0, 0.0), 0.0)
	_p(Combat.duree_etourdissement(2.0, -1.0), 0.0)
	_p(Combat.duree_etourdissement(-2.0, 1.0), 0.0)


func test_ralentissement_cumule_et_plafonne() -> void:
	_p(Combat.ralentissement(0, 0.08, 0.6), 0.0)
	_p(Combat.ralentissement(3, 0.08, 0.6), 0.24)
	_p(Combat.ralentissement(8, 0.08, 0.6), 0.6)
	_p(Combat.ralentissement(1000, 0.08, 0.6), 0.6)
	_p(Combat.ralentissement(-2, 0.08, 0.6), 0.0)


func test_gel_jamais_au_dela_du_maximum() -> void:
	_p(Combat.duree_gel(2.0, 1.0, 3.0), 2.0)
	_p(Combat.duree_gel(100.0, 1.0, 3.0), 3.0)
	_p(Combat.duree_gel(3.0, 0.5, 3.0), 1.5)
	_p(Combat.duree_gel(3.0, 0.0, 3.0), 0.0)
	_p(Combat.duree_gel(100.0, 5.0, 3.0), 3.0)


func test_repartition_du_poison_somme_au_total() -> void:
	for duree: float in [0.05, 0.7, 4.0, 10.0]:
		var somme := 0.0
		var restant := duree
		while restant > 0.0001:
			var dt := minf(0.05, restant)
			somme += Combat.repartir_dot(120.0, duree, dt)
			restant -= dt
		verifier_proche(somme, 120.0, 0.01, "durée %s" % duree)
	_p(Combat.repartir_dot(120.0, 0.0, 0.05), 0.0, "durée nulle")
	_p(Combat.repartir_dot(120.0, -1.0, 0.05), 0.0, "durée négative")


func test_vol_de_vie() -> void:
	_p(Combat.soin_vol_de_vie(100.0, 0.05), 5.0)
	_p(Combat.soin_vol_de_vie(100.0, 0.0), 0.0)
	_p(Combat.soin_vol_de_vie(-100.0, 0.05), 0.0)
	_p(Combat.soin_vol_de_vie(100.0, -0.5), 0.0)
