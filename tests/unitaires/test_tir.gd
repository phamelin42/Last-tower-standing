extends CasDeTest
## Armes équipées : ce que la joueuse obtient d'une arme qui recharge, vise et frappe.

const DT := 0.05
## PV des cibles : assez bas pour que la précision 32 bits des PV reste sous le centième.
const PV := 5000.0
const CENTRE := Vector2.ZERO
const KINDS: Array[String] = [
	"cible_unique", "zone", "rebond", "onde", "barrage", "mine", "piege", "aura"
]

var d: Donnees
var e: Ennemis
var rng: RandomNumberGenerator
var stats: StatsTour


func avant_chaque() -> void:
	d = Donnees.charger()
	e = Ennemis.new(d)
	rng = RandomNumberGenerator.new()
	rng.seed = 12345
	stats = StatsTour.new()


# --- Aides -------------------------------------------------------------------------------------


func _p(recu: float, attendu: float, message: String = "", tolerance: float = 0.01) -> void:
	verifier_proche(recu, attendu, tolerance, message)


## Arme de test : un seul effet, tout le reste neutre (chaos ×1 contre toute armure).
func _def(
	effet: Dictionary,
	statuts: Array = [],
	degats: float = 10.0,
	recharge: float = 1.0,
	portee: int = 600,
	type_degats: int = Types.TypeDegats.CHAOS,
	ciblage: int = Types.Ciblage.PLUS_PROCHE
) -> Dictionary:
	return {
		"id": "arme_de_test",
		"nom": "Arme de test",
		"description": "Pour les tests.",
		"rarete": 0,
		"prix": 1,
		"type_degats": type_degats,
		"degats": degats,
		"recharge": recharge,
		"portee": portee,
		"ciblage": ciblage,
		"effets": [effet],
		"statuts": statuts,
	}


func _def_reelle(kind: String) -> Dictionary:
	for id: String in d.armes:
		var def: Dictionary = d.armes[id]
		var effets: Array = def["effets"]
		for effet: Variant in effets:
			var ligne: Dictionary = effet
			if ligne["kind"] == kind:
				return def.duplicate(true)
	return {}


func _placer(pos: Vector2, pv: float = PV, armure: int = Types.Armure.AUCUNE) -> int:
	return e.ajouter(0, pos, pv, 0.0, 0.0, 40.0, 1.0, 1, armure)


func _pv(id: int) -> float:
	return e.pv[e.indice_de(id)]


func _pas(arme: ArmeEquipee, dt: float = DT, resistance: float = 1.0) -> Tir.Bilan:
	var bilan := Tir.Bilan.new()
	Tir.avancer_arme(arme, dt, stats, e, CENTRE, d, rng, resistance, bilan)
	return bilan


func _evenements_sains(bilan: Tir.Bilan, message: String) -> void:
	for ev: Dictionary in bilan.evenements:
		var k: String = ev["k"]
		verifier(k == "tir" or k == "impact", "%s : genre %s" % [message, k])
		var de: Vector2 = ev["de"]
		var vers: Vector2 = ev["vers"]
		verifier(is_finite(de.x) and is_finite(de.y), "%s : de fini" % message)
		verifier(is_finite(vers.x) and is_finite(vers.y), "%s : vers fini" % message)
		verifier(is_finite(float(ev["rayon"])), "%s : rayon fini" % message)
		verifier(int(ev["type_degats"]) >= 0 and int(ev["type_degats"]) < 5, "%s : type" % message)


# --- Les huit kinds réels ----------------------------------------------------------------------


func test_les_huit_kinds_existent_dans_les_donnees_reelles() -> void:
	for kind: String in KINDS:
		verifier(not _def_reelle(kind).is_empty(), "aucune arme réelle de kind %s" % kind)


func test_chaque_kind_reel_blesse_et_emet_des_evenements_sains() -> void:
	for kind: String in KINDS:
		avant_chaque()
		var arme := ArmeEquipee.new(_def_reelle(kind))
		var ids: Array[int] = []
		for k: int in 12:
			ids.append(_placer(Vector2(120.0 + 12.0 * k, 0).rotated(k * 0.5)))
		var degats := 0.0
		var evenements := 0
		for _k: int in 80:
			var bilan := _pas(arme)
			degats += bilan.degats
			evenements += bilan.evenements.size()
			_evenements_sains(bilan, kind)
		verifier(degats > 0.0, "%s : aucun dégât" % kind)
		verifier(evenements > 0, "%s : aucun événement" % kind)
		var blesses := 0
		for id: int in ids:
			if _pv(id) < PV:
				blesses += 1
		verifier(blesses > 0, "%s : aucun ennemi blessé" % kind)


func test_les_evenements_tir_et_impact_portent_positions_et_type() -> void:
	var def := _def({"kind": "cible_unique"}, [], 10.0, 1.0, 600, Types.TypeDegats.MAGIQUE)
	var arme := ArmeEquipee.new(def)
	_placer(Vector2(200, 0))
	var bilan := _pas(arme)
	var genres: Array[String] = []
	for ev: Dictionary in bilan.evenements:
		genres.append(ev["k"])
		verifier_egal(int(ev["type_degats"]), Types.TypeDegats.MAGIQUE)
	verifier_contient(genres, "tir")
	verifier_contient(genres, "impact")
	for ev: Dictionary in bilan.evenements:
		if ev["k"] == "tir":
			verifier_egal(ev["de"], CENTRE)
			verifier_egal(ev["vers"], Vector2(200, 0))


# --- Recharge, portée, ciblage -----------------------------------------------------------------


func test_un_seul_tir_par_recharge_malgre_un_grand_pas() -> void:
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	var id := _placer(Vector2(200, 0))
	_pas(arme, 100.0)
	_p(_pv(id), PV - 10.0, "un seul tir malgré dt = 100")
	_pas(arme, 0.5)
	_p(_pv(id), PV - 10.0, "pas de tir avant la fin de la recharge")
	_pas(arme, 0.5)
	_p(_pv(id), PV - 20.0, "tir à la fin de la recharge")


func test_cadence_double_double_le_nombre_de_tirs() -> void:
	var tirs: Array[int] = []
	for cadence: float in [0.0, 1.0]:
		avant_chaque()
		stats.cadence = cadence
		var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
		var id := _placer(Vector2(200, 0))
		for _k: int in 200:
			_pas(arme)
		tirs.append(roundi((PV - _pv(id)) / 10.0))
	verifier(tirs[0] >= 9 and tirs[0] <= 11, "10 s à 1 tir/s : %d" % tirs[0])
	verifier(tirs[1] >= 19 and tirs[1] <= 21, "cadence ×2 : %d" % tirs[1])


func test_recharge_ratio_zero_prete_un_vient_de_tirer() -> void:
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	_p(arme.recharge_ratio(stats), 0.0)
	_placer(Vector2(200, 0))
	_pas(arme)
	_p(arme.recharge_ratio(stats), 1.0)
	_pas(arme, 0.5)
	_p(arme.recharge_ratio(stats), 0.5)
	stats.cadence = 1.0
	_p(arme.recharge_ratio(stats), 1.0, "cadence ×2 : recharge de 0,5 s, il reste 0,5 s")


func test_zero_ennemi_aucun_tir_consomme_et_recharge_prete() -> void:
	for kind: String in KINDS:
		avant_chaque()
		var arme := ArmeEquipee.new(_def_reelle(kind))
		for _k: int in 20:
			var bilan := _pas(arme)
			verifier_egal(bilan.evenements.size(), 0, kind)
			_p(bilan.degats, 0.0)
		_p(arme.recharge_restante, 0.0, "%s : recharge prête" % kind)
		verifier_egal(arme.mines.size(), 0, kind)
		verifier_egal(arme.ondes.size(), 0, kind)
	# Dès qu'une cible apparaît, le tir part sans attendre.
	avant_chaque()
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	for _k: int in 20:
		_pas(arme)
	var id := _placer(Vector2(200, 0))
	_pas(arme)
	_p(_pv(id), PV - 10.0)


func test_pas_invalide_ne_change_rien() -> void:
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	var id := _placer(Vector2(200, 0))
	for dt: float in [0.0, -1.0, NAN, INF]:
		var bilan := _pas(arme, dt)
		verifier_egal(bilan.evenements.size(), 0)
	_p(_pv(id), PV)
	_p(arme.recharge_restante, 0.0)


func test_portee_aux_quatre_paliers() -> void:
	for portee: int in [300, 600, 900, 1200]:
		var cas := {portee + 1.0: false, float(portee): true, portee - 1.0: true}
		for distance: float in cas:
			avant_chaque()
			var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}, [], 10.0, 1.0, portee))
			var id := _placer(Vector2(0, distance))
			_pas(arme)
			var touche := _pv(id) < PV
			verifier_egal(touche, cas[distance], "portée %d, distance %s" % [portee, distance])


func test_ciblage_de_l_arme_est_respecte() -> void:
	var cas := {
		Types.Ciblage.PLUS_PROCHE: 1,
		Types.Ciblage.PLUS_FORT: 2,
		Types.Ciblage.PLUS_FAIBLE: 0,
	}
	for mode: int in cas:
		avant_chaque()
		var a := _placer(Vector2(300, 0), 50.0)
		var b := _placer(Vector2(100, 0), 500.0)
		var c := _placer(Vector2(200, 0), 900.0)
		var arme := ArmeEquipee.new(
			_def({"kind": "cible_unique"}, [], 10.0, 1.0, 600, Types.TypeDegats.CHAOS, mode)
		)
		_pas(arme)
		var ids := [a, b, c]
		var attendu: int = ids[cas[mode]]
		for id: int in ids:
			var touche := _pv(id) < (50.0 if id == a else (500.0 if id == b else 900.0))
			verifier_egal(touche, id == attendu, "mode %d, ennemi %d" % [mode, id])


# --- Cible unique : tirs multiples, focalisation, éclaboussure ---------------------------------


func test_tirs_multiples_visent_des_cibles_distinctes() -> void:
	stats.tirs_multiples = 2
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	var ids: Array[int] = [
		_placer(Vector2(100, 0)), _placer(Vector2(150, 0)), _placer(Vector2(200, 0))
	]
	var bilan := _pas(arme)
	for id: int in ids:
		_p(_pv(id), PV - 10.0, "chaque cible touchée une fois")
	var tirs := 0
	for ev: Dictionary in bilan.evenements:
		if ev["k"] == "tir":
			tirs += 1
	verifier_egal(tirs, 3)


func test_tirs_multiples_sans_assez_de_cibles_retombent_sur_la_meme() -> void:
	stats.tirs_multiples = 2
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	var a := _placer(Vector2(100, 0))
	var b := _placer(Vector2(150, 0))
	var bilan := _pas(arme)
	_p(_pv(a), PV - 20.0, "la plus proche reçoit le troisième tir")
	_p(_pv(b), PV - 10.0)
	_p(bilan.degats, 30.0)


func test_cible_morte_entre_deux_tirs_le_tir_suivant_vise_un_vivant() -> void:
	stats.tirs_multiples = 1
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	var a := _placer(Vector2(100, 0), 5.0)
	var b := _placer(Vector2(150, 0), PV)
	var bilan := _pas(arme)
	verifier_egal(e.indice_de(a) >= 0 and e.mort[e.indice_de(a)] == 1, true)
	_p(_pv(b), PV - 10.0, "le second tir n'est pas perdu sur un mort")
	_p(bilan.degats, 15.0, "5 réellement retirés au premier, 10 au second")
	verifier_egal(bilan.tues_directs, 1)


func test_seule_cible_morte_au_premier_tir_le_second_ne_fait_rien() -> void:
	stats.tirs_multiples = 2
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	_placer(Vector2(100, 0), 5.0)
	var bilan := _pas(arme)
	_p(bilan.degats, 5.0)
	verifier_egal(bilan.tues_directs, 1)
	var tirs := 0
	for ev: Dictionary in bilan.evenements:
		if ev["k"] == "tir":
			tirs += 1
	verifier_egal(tirs, 1, "pas de tir dans le vide")


func test_eclaboussure_tue_la_cible_suivante_le_tir_d_apres_vise_un_vivant() -> void:
	stats.tirs_multiples = 1
	stats.eclaboussure = 5.0
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	var a := _placer(Vector2(100, 0))
	var b := _placer(Vector2(150, 0), 3.0)
	var c := _placer(Vector2(260, 0))
	var bilan := _pas(arme)
	verifier_egal(e.mort[e.indice_de(b)], 1, "tué par l'éclaboussure du premier tir")
	verifier_egal(bilan.tues_directs, 1)
	_p(_pv(c), PV - 10.0, "le second tir va au vivant suivant")
	verifier(_pv(a) < PV)


func test_eclaboussure_autour_de_la_cible_dans_80_unites() -> void:
	stats.eclaboussure = 0.5
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	var a := _placer(Vector2(100, 0))
	var proche := _placer(Vector2(170, 0))
	var loin := _placer(Vector2(190, 0))
	_placer(Vector2(100, 90))
	_pas(arme)
	_p(_pv(a), PV - 10.0, "la cible une seule fois")
	_p(_pv(proche), PV - 5.0, "à 70 : la moitié")
	_p(_pv(loin), PV, "à 90 : rien")


func test_focalisation_seulement_en_cible_unique() -> void:
	stats.focalisation = 0.5
	var unique := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	var a := _placer(Vector2(100, 0))
	_pas(unique)
	_p(_pv(a), PV - 15.0)
	avant_chaque()
	stats.focalisation = 0.5
	var zone := ArmeEquipee.new(_def({"kind": "zone", "rayon": 50.0}))
	var b := _placer(Vector2(100, 0))
	_pas(zone)
	_p(_pv(b), PV - 10.0, "la zone ignore la focalisation")


# --- Critique, efficacité ----------------------------------------------------------------------


func _degats_par_tir(chance: float, graine: int, tirs: int) -> Array[float]:
	avant_chaque()
	rng.seed = graine
	stats.critique_chance = chance
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	_placer(Vector2(100, 0), 1e9)
	var sortie: Array[float] = []
	for _k: int in tirs:
		sortie.append(_pas(arme, 1.0).degats)
	return sortie


func test_critique_zero_jamais_cent_toujours_deux_cents_plus_puissant() -> void:
	for x: float in _degats_par_tir(0.0, 7, 100):
		_p(x, 10.0)
	for x: float in _degats_par_tir(1.0, 7, 100):
		_p(x, 20.0)
	for x: float in _degats_par_tir(2.0, 7, 100):
		_p(x, 30.0, "200 % : 2,0 + 1,0 × (2 − 1) = ×3")
	# Cinq pour cent sous un palier ne compte pas.
	for x: float in _degats_par_tir(0.04, 7, 100):
		_p(x, 10.0)


func test_critique_partiel_melange_et_graine_fixe_reproductible() -> void:
	var premier := _degats_par_tir(0.5, 99, 200)
	var second := _degats_par_tir(0.5, 99, 200)
	verifier_egal(premier, second, "même graine, mêmes tirages")
	var critiques := 0
	for x: float in premier:
		verifier(absf(x - 10.0) < 0.001 or absf(x - 20.0) < 0.001, "10 ou 20, pas %s" % x)
		if x > 15.0:
			critiques += 1
	verifier(critiques > 60 and critiques < 140, "environ la moitié : %d" % critiques)


func test_efficacite_x2_aux_quatre_couples_x1_ailleurs_jamais_x4() -> void:
	var doubles := {
		Types.TypeDegats.TRANCHANT: Types.Armure.MOYENNE,
		Types.TypeDegats.PERCANT: Types.Armure.LEGERE,
		Types.TypeDegats.MAGIQUE: Types.Armure.LOURDE,
		Types.TypeDegats.SIEGE: Types.Armure.FORTIFIEE,
	}
	for t: int in range(5):
		for a: int in range(6):
			avant_chaque()
			var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}, [], 10.0, 1.0, 600, t))
			var id := _placer(Vector2(100, 0), PV, a)
			var bilan := _pas(arme)
			var attendu := 20.0 if doubles.get(t, -1) == a else 10.0
			_p(bilan.degats, attendu, "type %d armure %d" % [t, a])
			_p(PV - _pv(id), attendu, "PV retirés, type %d armure %d" % [t, a])


func test_bonus_de_degats_par_type_et_global_se_multiplient() -> void:
	stats.degats_type[Types.TypeDegats.MAGIQUE] = 1.5
	stats.degats_global = 2.0
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}, [], 10.0, 1.0, 600, 2))
	var id := _placer(Vector2(100, 0), PV, Types.Armure.AUCUNE)
	_pas(arme)
	_p(PV - _pv(id), 30.0)


# --- Statuts et vol de vie ---------------------------------------------------------------------


func test_plusieurs_statuts_sur_le_meme_ennemi_par_le_meme_tir() -> void:
	var statuts: Array = [
		{"kind": "givre"},
		{"kind": "poison", "total_ratio": 0.5, "duree": 2.0},
		{"kind": "brulure", "ratio": 0.2, "duree": 2.0},
		{"kind": "etourdissement", "duree": 1.0},
	]
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}, statuts))
	var id := _placer(Vector2(100, 0))
	_pas(arme)
	var i := e.indice_de(id)
	var attendu := (
		Types.STATUT_RALENTI | Types.STATUT_EMPOISONNE | Types.STATUT_BRULE | Types.STATUT_ETOURDI
	)
	verifier_egal(int(e.statuts[i]), attendu)
	_p(e.poison_reste[i], 5.0, "50 % du coup de 10")
	_p(e.brule_reste[i], 2.0, "20 % du coup de 10")
	_p(e.etourdi[i], 1.0)


func test_resistance_nulle_aucun_etourdissement_ni_gel_par_un_tir() -> void:
	var statuts: Array = [{"kind": "givre"}, {"kind": "etourdissement", "duree": 1.0}]
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}, statuts, 10.0, 0.05))
	var id := _placer(Vector2(100, 0))
	for _k: int in 40:
		_pas(arme, DT, 0.0)
	var i := e.indice_de(id)
	verifier_egal(int(e.statuts[i]) & (Types.STATUT_ETOURDI | Types.STATUT_GELE), 0)
	verifier(is_finite(e.etourdi[i]) and is_finite(e.gel[i]))


func test_statuts_sur_chaque_cible_touchee_d_une_zone() -> void:
	var arme := ArmeEquipee.new(
		_def({"kind": "zone", "rayon": 100.0}, [{"kind": "etourdissement", "duree": 1.0}])
	)
	var ids: Array[int] = [_placer(Vector2(100, 0)), _placer(Vector2(150, 0))]
	_pas(arme)
	for id: int in ids:
		verifier_egal(int(e.statuts[e.indice_de(id)]), Types.STATUT_ETOURDI)


func test_vol_de_vie_au_coup_par_les_ameliorations_et_par_l_arme() -> void:
	stats.vol_de_vie_coup = 0.1
	var statuts: Array = [{"kind": "vol_de_vie", "ratio": 0.05, "a_la_mort": false}]
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}, statuts))
	_placer(Vector2(100, 0))
	var bilan := _pas(arme)
	_p(bilan.soin, 1.0 + 0.5, "10 de dégâts : 10 % + 5 %")


func test_vol_de_vie_ne_compte_que_les_degats_reellement_infliges() -> void:
	stats.vol_de_vie_coup = 0.1
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}, [], 100.0))
	_placer(Vector2(100, 0), 4.0)
	var bilan := _pas(arme)
	_p(bilan.degats, 4.0)
	_p(bilan.soin, 0.4, "pas de soin sur le surplus")


func test_vol_de_vie_a_la_mort_par_les_ameliorations_et_par_l_arme() -> void:
	stats.vol_de_vie_mort = 8.0
	var arme := ArmeEquipee.new(_def({"kind": "cible_unique"}))
	_placer(Vector2(100, 0), 4.0)
	var bilan := _pas(arme)
	verifier_egal(bilan.tues_directs, 1)
	_p(bilan.soin, 8.0, "soin fixe par ennemi tué, rien pour un simple coup")
	avant_chaque()
	var statuts: Array = [{"kind": "vol_de_vie", "ratio": 0.5, "a_la_mort": true}]
	var arme2 := ArmeEquipee.new(_def({"kind": "cible_unique"}, statuts))
	_placer(Vector2(100, 0), PV)
	_placer(Vector2(900, 0), 4.0)
	var coup := _pas(arme2)
	_p(coup.soin, 0.0, "un coup qui ne tue pas ne soigne pas")
	_p(coup.degats, 10.0)
	var arme3 := ArmeEquipee.new(_def({"kind": "cible_unique"}, statuts, 10.0, 1.0, 1200))
	e.infliger(0, 1e9, Types.TypeDegats.CHAOS)
	var tue := _pas(arme3)
	verifier_egal(tue.tues_directs, 1)
	_p(tue.soin, 2.0, "50 % des PV max de l'ennemi tué (4)")


# --- Zone, rebond, barrage ---------------------------------------------------------------------


func test_zone_touche_tous_les_ennemis_dans_le_rayon_seulement() -> void:
	var arme := ArmeEquipee.new(_def({"kind": "zone", "rayon": 110.0}))
	var proche := _placer(Vector2(200, 0))
	var autre := _placer(Vector2(280, 0))
	var loin := _placer(Vector2(200, 130))
	_pas(arme)
	_p(_pv(proche), PV - 10.0)
	_p(_pv(autre), PV - 10.0, "tout ennemi du rayon est touché")
	_p(_pv(loin), PV, "hors du rayon")


func _ligne(n: int, ecart: float = 100.0) -> Array[int]:
	var ids: Array[int] = []
	for k: int in n:
		ids.append(_placer(Vector2(ecart * (k + 1), 0)))
	return ids


func test_rebond_avec_1_3_et_8_ennemis_jamais_deux_fois_le_meme() -> void:
	for n: int in [1, 3, 8]:
		avant_chaque()
		var effet := {"kind": "rebond", "cibles": 8, "portee_saut": 220.0, "decroissance": 0.9}
		var arme := ArmeEquipee.new(_def(effet, [], 100.0, 1.0, 1200))
		var ids := _ligne(n)
		var bilan := _pas(arme)
		var total := 0.0
		for k: int in n:
			var attendu := 100.0 * pow(0.9, k)
			_p(PV - _pv(ids[k]), attendu, "%d ennemis, rang %d" % [n, k], 0.01)
			total += attendu
		_p(bilan.degats, total, "total pour %d ennemis" % n, 0.05)


func test_rebond_ne_depasse_pas_le_nombre_de_cibles_et_respecte_la_decroissance() -> void:
	var effet := {"kind": "rebond", "cibles": 4, "portee_saut": 220.0, "decroissance": 0.9}
	var arme := ArmeEquipee.new(_def(effet, [], 100.0, 1.0, 1200))
	var ids := _ligne(7)
	_pas(arme)
	var touches := 0
	for k: int in 7:
		if _pv(ids[k]) < PV:
			touches += 1
	verifier_egal(touches, 4)
	_p(PV - _pv(ids[3]), 72.9, "quatrième : 100 × 0,9³", 0.01)
	_p(_pv(ids[4]), PV)


func test_rebond_quand_tous_les_voisins_sont_deja_touches_s_arrete() -> void:
	var effet := {"kind": "rebond", "cibles": 8, "portee_saut": 220.0, "decroissance": 1.0}
	var arme := ArmeEquipee.new(_def(effet, [], 10.0, 1.0, 1200))
	var ids: Array[int] = [
		_placer(Vector2(100, 0)), _placer(Vector2(130, 40)), _placer(Vector2(130, -40))
	]
	var bilan := _pas(arme)
	for id: int in ids:
		_p(PV - _pv(id), 10.0, "touché exactement une fois")
	_p(bilan.degats, 30.0)


func test_rebond_saute_les_morts_et_ne_compte_que_les_vivants() -> void:
	var effet := {"kind": "rebond", "cibles": 8, "portee_saut": 220.0, "decroissance": 1.0}
	var arme := ArmeEquipee.new(_def(effet, [], 10.0, 1.0, 1200))
	var ids := _ligne(3)
	e.infliger(e.indice_de(ids[1]), 1e9, Types.TypeDegats.CHAOS)
	_pas(arme)
	_p(PV - _pv(ids[0]), 10.0)
	_p(PV - _pv(ids[2]), 10.0, "saute le mort, 200 d'écart")


func test_barrage_frappe_autour_de_la_cible_avec_dispersion_tiree_par_le_rng() -> void:
	var effet := {"kind": "barrage", "projectiles": 8, "dispersion_deg": 40.0, "rayon": 150.0}
	var arme := ArmeEquipee.new(_def(effet, [], 10.0, 1.0, 900))
	var cible := _placer(Vector2(300, 0))
	var bilan := _pas(arme)
	var impacts := 0
	for ev: Dictionary in bilan.evenements:
		if ev["k"] == "impact":
			impacts += 1
			var vers: Vector2 = ev["vers"]
			_p(vers.length(), 300.0, "même distance que la cible", 0.01)
			verifier(absf(rad_to_deg(vers.angle())) <= 20.01, "dans le cône")
	verifier_egal(impacts, 8)
	verifier(PV - _pv(cible) >= 10.0, "au moins un projectile touche")
	# Même graine : mêmes impacts.
	avant_chaque()
	var arme2 := ArmeEquipee.new(_def(effet, [], 10.0, 1.0, 900))
	_placer(Vector2(300, 0))
	var bilan2 := _pas(arme2)
	rng.seed = 12345
	var arme3 := ArmeEquipee.new(_def(effet, [], 10.0, 1.0, 900))
	avant_chaque()
	_placer(Vector2(300, 0))
	var bilan3 := _pas(arme3)
	verifier_egal(bilan2.evenements, bilan3.evenements, "reproductible")
