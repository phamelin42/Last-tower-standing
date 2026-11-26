extends CasDeTest
## Arène sous charge : plus de 1 000 ennemis au plancher d'apparition, durée moyenne d'un pas.

const DT := 0.05
const GRAINE := 5
## Budget du plan : moins de 5 ms par pas (10e centile des mesures, voir `MesurePas`).
const BUDGET_MS := 5.0

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()
	d.partie["tour"]["pv"] = 1e9  # la tour tient : l'arène ne finit pas avant la mesure


func _mult(vitesse: float) -> Dictionary:
	return {"pv": 1.0, "degats": 1.0, "vitesse": vitesse, "resistance_controle": 1.0}


func _equiper(a: Arene) -> void:
	for id: String in ["de_pipe", "orbe_de_brume", "moulinet_de_cuivre", "mine_de_forge"]:
		a.inventaire.ajouter(id)
	a.synchroniser()


## Fait monter l'arène à plus de `seuil` ennemis, puis mesure `pas` pas : coût d'un pas en ms.
func _mesurer(a: Arene, seuil: int, pas: int) -> float:
	var garde := 0
	while a.nombre_ennemis() < seuil and garde < 6000:
		a.avancer(DT)
		garde += 1
	verifier(a.nombre_ennemis() >= seuil, "au moins %d ennemis (%d)" % [seuil, a.nombre_ennemis()])
	# Blocs de quatre pas : chacun contient exactement une lecture de la vue. Le budget se juge au
	# 10e centile des blocs (voir `MesurePas`), pas à la moyenne qui suit la charge de la machine.
	var blocs := PackedInt32Array()
	for _b: int in pas / 4:
		var debut := Time.get_ticks_usec()
		for _i: int in 4:
			a.avancer(DT)
			if a.tick_courant() % 4 == 0:
				a.vue(Types.Phase.MANCHE, 1.0, -1, false)  # le rendu lit la vue à 15 Hz environ
		blocs.append(Time.get_ticks_usec() - debut)
	var rapide := MesurePas.centile_bas_ms(blocs, 4)
	print("  [mesure] %d ennemis, %.3f ms par pas (10e centile)" % [a.nombre_ennemis(), rapide])
	return rapide


func test_mille_ennemis_immobiles_au_plancher_sous_5_ms_par_pas() -> void:
	var a := Arene.new(d, GRAINE)
	_equiper(a)
	a.demarrer_manche(40, Composition.unique(0), _mult(0.0))
	var ms := _mesurer(a, 1000, 200)
	verifier(ms < BUDGET_MS, "%.3f ms par pas (budget %s)" % [ms, BUDGET_MS])


func test_mille_ennemis_en_marche_sous_5_ms_par_pas() -> void:
	var a := Arene.new(d, GRAINE)
	_equiper(a)
	a.demarrer_manche(40, Composition.unique(0), _mult(0.05))
	var ms := _mesurer(a, 1000, 200)
	verifier(ms < BUDGET_MS, "%.3f ms par pas (budget %s)" % [ms, BUDGET_MS])


func test_aucune_fuite_de_tableaux_apres_de_longues_manches() -> void:
	var a := Arene.new(d, GRAINE)
	_equiper(a)
	a.demarrer_manche(40, Composition.unique(0), _mult(3.0))
	for _i: int in 6000:
		a.avancer(DT)
	var n := a.ennemis.taille
	verifier_egal(a.ennemis.ids.size(), n, "aucun mort oublié dans les tableaux après la purge")
	verifier_egal(a.ennemis.pv.size(), n, "tous les tableaux ont la même longueur")
	verifier(a.nombre_ennemis() < 1500, "les armes et la tour tuent : le nombre se stabilise")


func test_mille_attaquants_au_corps_a_corps_avec_epines_sous_5_ms_par_pas() -> void:
	var a := Arene.new(d, GRAINE)
	_equiper(a)
	a.inventaire.ameliorations["couronne_d_epines"] = 1
	a.inventaire.ameliorations["meurtrieres_biaisees"] = 5
	a.synchroniser()
	for k: int in 1200:
		var angle := TAU * float(k) / 1200.0
		var p := Vector2.from_angle(angle) * 100.0
		a.ennemis.ajouter(0, p, 1e7, 0.0, 5.0, 40.0, 4.0, 1, Types.Armure.AUCUNE)
	var durees := PackedInt32Array()
	for _i: int in 200:
		var debut := Time.get_ticks_usec()
		a.avancer(DT)
		durees.append(Time.get_ticks_usec() - debut)
	var ms := MesurePas.centile_bas_ms(durees)
	print("  [mesure] 1200 attaquants au contact, %.3f ms par pas (10e centile)" % ms)
	verifier(ms < BUDGET_MS, "%.3f ms par pas (budget %s)" % [ms, BUDGET_MS])
	verifier(not a.est_detruite(), "la tour tient")


func test_quarante_armes_contre_mille_ennemis_sous_5_ms_par_pas() -> void:
	var a := Arene.new(d, GRAINE)
	var ids: Array = d.armes.keys()
	# Chaque arme du catalogue, puis des doublons jusqu'à quarante.
	for i: int in maxi(ids.size(), 40):
		a.inventaire.ajouter(str(ids[i % ids.size()]))
		if a.inventaire.armes.size() >= maxi(ids.size(), 40):
			break
	a.synchroniser()
	verifier(a.inventaire.armes.size() >= 40, "au moins quarante armes équipées")
	a.demarrer_manche(40, Composition.unique(0), _mult(0.0))
	var ms := _mesurer(a, 1000, 200)
	verifier(ms < BUDGET_MS, "%.3f ms par pas avec %d armes" % [ms, a.inventaire.armes.size()])
