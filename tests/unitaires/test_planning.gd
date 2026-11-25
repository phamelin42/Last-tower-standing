extends CasDeTest
## Planning de la partie : familles tirées, convoi, multiplicateurs de difficulté.

const MANCHES := 200
const GRAINES := 20
const PV_PAR_MANCHE := 1.08
const DEGATS_PAR_MANCHE := 1.06
const VITESSE_PAR_MANCHE := 1.01
const RESISTANCE_PAR_MANCHE := 0.97
const ACC_PV := 1.3
const ACC_DEGATS := 1.2
const ACC_VITESSE := 1.05

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _tirages(graine: int, manches: int) -> Array[int]:
	var p := Planning.new(d, graine)
	var out: Array[int] = []
	for m: int in range(1, manches + 1):
		out.append(p.tirer(m))
	return out


func test_famille_jamais_deux_fois_de_suite_sur_20_graines() -> void:
	var n := d.familles.size()
	for g: int in GRAINES:
		var t := _tirages(g, MANCHES)
		var derniere := -1
		for i: int in t.size():
			if t[i] == n:
				continue
			verifier_different(
				t[i], derniere, "graine %d manche %d : même famille deux fois" % [g, i + 1]
			)
			derniere = t[i]


func test_convoi_jamais_deux_manches_de_suite_ni_avant_sa_manche_min() -> void:
	var n := d.familles.size()
	var manche_min: int = d.partie["convoi"]["manche_min"]
	var vus := 0
	for g: int in GRAINES:
		var t := _tirages(g, MANCHES)
		for i: int in t.size():
			if t[i] != n:
				continue
			vus += 1
			verifier(i + 1 >= manche_min, "convoi trop tôt, manche %d" % (i + 1))
			if i > 0:
				verifier_different(t[i - 1], n, "deux convois de suite, graine %d" % g)
	verifier(vus > 0, "le convoi apparaît au moins une fois sur 4 000 manches")


func test_chaque_famille_et_le_convoi_sortent() -> void:
	var vus := {}
	for g: int in GRAINES:
		for f: int in _tirages(g, MANCHES):
			vus[f] = true
	for f: int in d.familles.size() + 1:
		verifier(vus.has(f), "la famille %d ne sort jamais" % f)


func test_meme_graine_meme_planning() -> void:
	verifier_egal(_tirages(5, 60), _tirages(5, 60))
	verifier_different(_tirages(5, 60), _tirages(6, 60))


func test_paliers_de_difficulte_aux_manches_1_5_31_40() -> void:
	var cas := {1: 0, 5: 4, 31: 30, 40: 39}
	for manche: int in cas:
		var k: int = cas[manche]
		var m := Planning.multiplicateurs(d, manche, 0.0)
		verifier_proche(m["pv"], pow(PV_PAR_MANCHE, k), 1e-9, "pv manche %d" % manche)
		verifier_proche(m["degats"], pow(DEGATS_PAR_MANCHE, k), 1e-9, "degats manche %d" % manche)
		verifier_proche(
			m["vitesse"], pow(VITESSE_PAR_MANCHE, k), 1e-9, "vitesse manche %d" % manche
		)
		var attendu := maxf(0.1, pow(RESISTANCE_PAR_MANCHE, k))
		verifier_proche(m["resistance_controle"], attendu, 1e-9, "resistance manche %d" % manche)


func test_la_resistance_aux_controles_ne_passe_jamais_sous_le_plancher() -> void:
	for manche: int in [80, 100, 500]:
		var m := Planning.multiplicateurs(d, manche, 0.0)
		verifier_proche(m["resistance_controle"], 0.1, 1e-12, "plancher manche %d" % manche)


func test_accelerations_aux_temps_299_300_600_900() -> void:
	var attendus := {299.0: 0, 300.0: 1, 599.95: 1, 600.0: 2, 899.0: 2, 900.0: 3, 5000.0: 3}
	for t: float in attendus:
		var k: int = attendus[t]
		var m := Planning.multiplicateurs(d, 1, t)
		verifier_proche(m["pv"], pow(ACC_PV, k), 1e-9, "pv à %s s" % t)
		verifier_proche(m["degats"], pow(ACC_DEGATS, k), 1e-9, "degats à %s s" % t)
		verifier_proche(m["vitesse"], pow(ACC_VITESSE, k), 1e-9, "vitesse à %s s" % t)
		verifier_proche(m["resistance_controle"], 1.0, 1e-12, "resistance à %s s" % t)


func test_accelerations_et_manches_se_combinent() -> void:
	var m := Planning.multiplicateurs(d, 11, 600.0)
	verifier_proche(m["pv"], pow(PV_PAR_MANCHE, 10) * ACC_PV * ACC_PV, 1e-9)
