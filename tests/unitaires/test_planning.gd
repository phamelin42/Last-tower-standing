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

## La difficulté réglée dans `data/difficulte.json` change à chaque passe d'équilibrage : ces tests
## vérifient la mécanique (paliers, croissance par manche, accélérations) sur une table uniforme
## fixe, pas les chiffres du jeu.
const TABLE_UNIFORME: Array = [
	{"manche": 1, "pv": 1.0, "degats": 1.0, "vitesse": 1.0, "resistance_controle": 1.0}
]
const APRES_TABLE: Dictionary = {
	"pv": PV_PAR_MANCHE,
	"degats": DEGATS_PAR_MANCHE,
	"vitesse": VITESSE_PAR_MANCHE,
	"resistance_controle": RESISTANCE_PAR_MANCHE,
}

var d: Donnees


func avant_chaque() -> void:
	d = AidesPartie.donnees(
		{
			"difficulte.json":
			[
				[["paliers"], TABLE_UNIFORME.duplicate(true)],
				[["apres_table"], APRES_TABLE.duplicate()]
			]
		}
	)


func _tirages(graine: int, manches: int) -> Array[int]:
	var p := Planning.new(d, graine)
	var out: Array[int] = []
	for m: int in range(1, manches + 1):
		out.append(p.tirer(m).majoritaire())
	return out


func test_famille_majoritaire_jamais_deux_fois_de_suite_sur_20_graines() -> void:
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


func test_le_convoi_ne_vient_qu_aux_manches_multiples_de_tous_les_des_donnees() -> void:
	# Retour de partie de Phil (27/11) : « le round gold bonus devrait être à manche fixe (toutes
	# les 10 manches) » : le convoi n'est plus un tirage au sort.
	var n := d.familles.size()
	var tous_les: int = int((d.partie["convoi"] as Dictionary)["tous_les"])
	verifier_egal(tous_les, 10, "décision de Phil : toutes les 10 manches")
	for g: int in GRAINES:
		var t := _tirages(g, 100)
		verifier_egal(t.size(), 100)
		for i: int in t.size():
			var manche := i + 1
			verifier_egal(
				t[i] == n,
				manche % tous_les == 0,
				"graine %d, manche %d : convoi %s" % [g, manche, t[i] == n]
			)


func test_le_convoi_vient_a_la_manche_10_20_30_et_jamais_deux_manches_de_suite() -> void:
	var n := d.familles.size()
	for g: int in GRAINES:
		var t := _tirages(g, MANCHES)
		var manches: Array[int] = []
		for i: int in t.size():
			if t[i] == n:
				manches.append(i + 1)
		verifier_egal(manches.size(), MANCHES / 10, "graine %d : un convoi par dizaine" % g)
		for k: int in manches.size():
			verifier_egal(manches[k], 10 * (k + 1), "graine %d : convoi n° %d" % [g, k + 1])


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
