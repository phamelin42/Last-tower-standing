extends CasDeTest
## Armes à effets durables : ondes, mines, pièges, aura, et le coût d'un pas.

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


func _placer(
	pos: Vector2, pv: float = PV, volant: bool = false, armure: int = Types.Armure.AUCUNE
) -> int:
	return e.ajouter(0, pos, pv, 0.0, 0.0, 40.0, 1.0, 1, volant, armure)


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


func _ligne(n: int, ecart: float = 100.0) -> Array[int]:
	var ids: Array[int] = []
	for k: int in n:
		ids.append(_placer(Vector2(ecart * (k + 1), 0)))
	return ids


# --- Onde --------------------------------------------------------------------------------------


func test_onde_touche_chaque_ennemi_une_seule_fois() -> void:
	var effet := {"kind": "onde", "rayon_max": 500.0, "vitesse": 600.0}
	var arme := ArmeEquipee.new(_def(effet, [], 76.4, 1000.0, 600))
	var dedans: Array[int] = [
		_placer(Vector2(60, 0)), _placer(Vector2(250, 0)), _placer(Vector2(0, 480))
	]
	var dehors := _placer(Vector2(0, 520))
	var volant := _placer(Vector2(300, 0), PV, true)
	for _k: int in 60:
		_pas(arme)
	for id: int in dedans:
		_p(PV - _pv(id), 76.4, "touché une seule fois", 0.01)
	_p(PV - _pv(volant), 76.4, "volant touché aussi", 0.01)
	_p(_pv(dehors), PV, "au-delà de rayon_max : jamais")
	verifier_egal(arme.ondes.size(), 0, "onde retirée à rayon_max")


func test_onde_avec_un_grand_pas_est_plafonnee_a_rayon_max() -> void:
	var effet := {"kind": "onde", "rayon_max": 500.0, "vitesse": 600.0}
	var arme := ArmeEquipee.new(_def(effet, [], 50.0, 1000.0, 600))
	var a := _placer(Vector2(100, 0))
	var b := _placer(Vector2(400, 0))
	var c := _placer(Vector2(600, 0))
	_pas(arme)
	verifier_egal(arme.ondes.size(), 1)
	_pas(arme, 10.0)
	_p(PV - _pv(a), 50.0)
	_p(PV - _pv(b), 50.0)
	_p(_pv(c), PV, "6 000 unités de course, mais plafonné à 500")
	verifier_egal(arme.ondes.size(), 0)


func test_onde_garde_ses_touches_par_identifiant_malgre_les_purges() -> void:
	var effet := {"kind": "onde", "rayon_max": 500.0, "vitesse": 100.0}
	var arme := ArmeEquipee.new(_def(effet, [], 10.0, 1000.0, 600))
	var ids := _ligne(5, 50.0)
	_pas(arme)
	for _k: int in 10:
		_pas(arme)
	e.infliger(e.indice_de(ids[0]), 1e9, Types.TypeDegats.CHAOS)
	e.purger()
	for _k: int in 80:
		_pas(arme)
	for k: int in range(1, 5):
		_p(PV - _pv(ids[k]), 10.0, "ennemi %d touché une fois malgré le swap" % k)


# --- Mines et pièges ---------------------------------------------------------------------------


func test_mine_se_pose_sur_un_fantassin_et_se_declenche_pour_lui() -> void:
	for kind: String in ["mine", "piege"]:
		avant_chaque()
		var arme := ArmeEquipee.new(_def({"kind": kind, "rayon": 100.0, "max_actives": 3}))
		var sol := _placer(Vector2(200, 0))
		_pas(arme)
		verifier_egal(arme.mines.size(), 1, "%s posée" % kind)
		verifier_egal(arme.mines[0], Vector2(200, 0))
		_p(_pv(sol), PV, "pas encore déclenchée")
		var bilan := _pas(arme)
		_p(_pv(sol), PV - 10.0, "%s déclenchée" % kind)
		verifier_egal(arme.mines.size(), 0, "mine consommée")
		verifier(bilan.degats > 0.0)


func test_mine_ignore_un_volant() -> void:
	for kind: String in ["mine", "piege"]:
		avant_chaque()
		var arme := ArmeEquipee.new(_def({"kind": kind, "rayon": 100.0, "max_actives": 3}))
		var air := _placer(Vector2(200, 0), PV, true)
		var bilan := _pas(arme)
		verifier_egal(arme.mines.size(), 0, "%s : rien à poser sous un volant" % kind)
		_p(bilan.degats, 0.0)
		arme.mines.append(Vector2(200, 0))
		for _k: int in 5:
			_pas(arme)
		verifier_egal(arme.mines.size(), 1, "%s : le volant ne la déclenche pas" % kind)
		_p(_pv(air), PV)


func test_mine_n_atteint_pas_les_volants_de_son_explosion() -> void:
	var arme := ArmeEquipee.new(_def({"kind": "mine", "rayon": 100.0, "max_actives": 3}))
	var sol := _placer(Vector2(200, 0))
	var air := _placer(Vector2(230, 0), PV, true)
	_pas(arme)
	_pas(arme)
	_p(_pv(sol), PV - 10.0)
	_p(_pv(air), PV, "volant dans le rayon de l'explosion : épargné")


func test_mines_max_actives_respecte() -> void:
	var arme := ArmeEquipee.new(
		_def({"kind": "mine", "rayon": 50.0, "max_actives": 3}, [], 10, 0.05)
	)
	for _k: int in 3:
		arme.mines.append(Vector2(-1000, 0))
	_placer(Vector2(200, 0))
	for _k: int in 20:
		_pas(arme)
	verifier_egal(arme.mines.size(), 3, "pleine : aucune pose de plus")
	arme.mines.remove_at(0)
	_pas(arme)
	verifier_egal(arme.mines.size(), 3, "une place libre : une pose")


func test_mine_posee_sur_un_ennemi_qui_meurt_avant_le_declenchement() -> void:
	var arme := ArmeEquipee.new(_def({"kind": "mine", "rayon": 100.0, "max_actives": 3}))
	var a := _placer(Vector2(200, 0))
	_pas(arme)
	verifier_egal(arme.mines.size(), 1)
	e.infliger(e.indice_de(a), 1e9, Types.TypeDegats.CHAOS)
	var bilan := _pas(arme)
	verifier_egal(arme.mines.size(), 1, "la mine reste posée")
	_p(bilan.degats, 0.0)
	var b := _placer(Vector2(240, 0))
	_pas(arme)
	_p(_pv(b), PV - 10.0, "un autre fantassin la déclenche")
	verifier_egal(arme.mines.size(), 0)


# --- Aura --------------------------------------------------------------------------------------


func test_aura_frappe_des_le_premier_pas_puis_a_chaque_periode() -> void:
	var arme := ArmeEquipee.new(_def({"kind": "aura", "rayon": 280.0, "periode": 0.5}))
	var proche := _placer(Vector2(200, 0))
	var air := _placer(Vector2(0, 250), PV, true)
	var loin := _placer(Vector2(0, 300))
	var premier := _pas(arme)
	_p(premier.degats, 20.0, "premier pas : les deux à portée")
	_p(_pv(proche), PV - 10.0)
	_p(_pv(air), PV - 10.0, "volant inclus")
	_p(_pv(loin), PV, "hors rayon")
	for _k: int in 5:
		_p(_pas(arme).degats, 0.0, "entre deux périodes")
	var coups := 0
	for _k: int in 10:
		if _pas(arme).degats > 0.0:
			coups += 1
	verifier(coups >= 1 and coups <= 2, "un coup par demi-seconde : %d en 0,5 s" % coups)


func test_aura_sans_ennemi_reste_prete() -> void:
	var arme := ArmeEquipee.new(_def({"kind": "aura", "rayon": 280.0, "periode": 0.5}))
	for _k: int in 30:
		_p(_pas(arme).degats, 0.0)
	var id := _placer(Vector2(100, 0))
	_pas(arme)
	_p(_pv(id), PV - 10.0, "frappe aussitôt")


# --- Performance -------------------------------------------------------------------------------


func test_performance_huit_armes_mille_ennemis() -> void:
	var armes: Array[ArmeEquipee] = []
	for kind: String in KINDS:
		armes.append(ArmeEquipee.new(_def_reelle(kind)))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 5
	for k: int in 1000:
		var pos := Vector2(hasard.randf_range(80.0, 1250.0), 0.0).rotated(hasard.randf() * TAU)
		_placer(pos, 1e9, k % 5 == 0)
	var debut := Time.get_ticks_usec()
	for _k: int in 100:
		for arme: ArmeEquipee in armes:
			_pas(arme)
	var ms := (Time.get_ticks_usec() - debut) / 1000.0 / 100.0
	print("PERF tir : 8 armes x 1000 ennemis = %.3f ms par pas" % ms)
	verifier(ms < 3.0, "coût d'un pas : %.3f ms (limite 3)" % ms)
