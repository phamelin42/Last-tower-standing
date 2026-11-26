extends CasDeTest
## Les ennemis au corps à corps étaient trop lents (Phil, 25/11/2026) : chaque vitesse vaut au
## moins une fois et demie celle d'avant. Les valeurs viennent de `data/ennemis.json` ; seules les
## vitesses d'avant (la référence de ce test) sont écrites ici.

const FACTEUR := 1.5
const EPSILON := 0.0001
const VITESSES_AVANT: Dictionary = {
	"torche": 75.0,
	"paysan": 60.0,
	"guerrier": 35.0,
	"tonneau": 25.0,
	"dynamite": 65.0,
	"archer": 50.0
}
const MODELES_AU_CORPS_A_CORPS: Array[String] = ["torche", "paysan", "guerrier", "tonneau"]
const VITESSE_CONVOI_AVANT := 45.0
const VITESSE_BOSS_AVANT := 35.0

var d: Donnees
var brut: Dictionary


func avant_chaque() -> void:
	d = Donnees.charger()
	brut = JSON.parse_string(FileAccess.get_file_as_string("res://data/ennemis.json"))


func _modeles() -> Dictionary:
	var par_id: Dictionary = {}
	for m: Dictionary in brut["modeles"]:
		par_id[String(m["id"])] = m
	return par_id


func test_chaque_famille_au_corps_a_corps_va_au_moins_aussi_vite_qu_avant_fois_1_5() -> void:
	verifier(d.familles.size() > 0, "des familles sont chargées")
	for famille: Dictionary in d.familles:
		var modele := String(famille["modele"])
		if not modele in MODELES_AU_CORPS_A_CORPS:
			continue
		var minimum: float = float(VITESSES_AVANT[modele]) * FACTEUR
		verifier(
			float(famille["vitesse"]) >= minimum - EPSILON,
			"%s : %s sous %s" % [famille["id"], famille["vitesse"], minimum]
		)


func test_toute_famille_le_convoi_et_le_boss_vont_au_moins_1_5_fois_plus_vite_qu_avant() -> void:
	for famille: Dictionary in d.familles:
		var minimum: float = float(VITESSES_AVANT[String(famille["modele"])]) * FACTEUR
		verifier(
			float(famille["vitesse"]) >= minimum - EPSILON,
			"%s : %s sous %s" % [famille["id"], famille["vitesse"], minimum]
		)
	verifier(float(d.convoi["vitesse"]) >= VITESSE_CONVOI_AVANT * FACTEUR - EPSILON, "convoi")
	verifier(float(d.boss["vitesse"]) >= VITESSE_BOSS_AVANT * FACTEUR - EPSILON, "boss")


func test_le_guerrier_reste_lent_mais_plus_rapide_qu_avant() -> void:
	var modeles := _modeles()
	var guerrier := float((modeles["guerrier"] as Dictionary)["vitesse"])
	verifier(guerrier > float(VITESSES_AVANT["guerrier"]), "plus rapide qu'avant")
	for id: String in MODELES_AU_CORPS_A_CORPS:
		if id == "guerrier":
			continue
		var autre := float((modeles[id] as Dictionary)["vitesse"])
		verifier(
			guerrier < autre, "le Guerrier (%s) est plus lent que %s (%s)" % [guerrier, id, autre]
		)


func test_aucune_famille_n_est_la_plus_lente_sans_raison_ecrite() -> void:
	# Les six modèles et le convoi : le plus lent est le seul à porter une raison de lenteur.
	var vitesses: Dictionary = {}
	var raisons: Dictionary = {}
	for id: String in _modeles():
		var m: Dictionary = _modeles()[id]
		vitesses[id] = float(m["vitesse"])
		raisons[id] = String(m["raison_lenteur"])
	vitesses["convoi"] = float(d.convoi["vitesse"])
	raisons["convoi"] = ""
	var plus_lent := ""
	for id: String in vitesses:
		if plus_lent == "" or float(vitesses[id]) < float(vitesses[plus_lent]):
			plus_lent = id
	verifier_egal(plus_lent, "guerrier", "le plus lent")
	for id: String in raisons:
		var attendu_vide := id != plus_lent
		verifier_egal(String(raisons[id]).is_empty(), attendu_vide, "raison de lenteur de %s" % id)
	var modeles := _modeles()
	verifier(
		(
			float((modeles["tonneau"] as Dictionary)["vitesse"])
			>= float((modeles["guerrier"] as Dictionary)["vitesse"])
		),
		"le Tonneau n'est pas plus lent que le Guerrier"
	)


func test_un_ennemi_avance_de_vitesse_fois_multiplicateur_par_seconde() -> void:
	for multiplicateur: float in [0.5, 1.0, 1.5, 2.0]:
		var e := Ennemis.new(d)
		var id := e.ajouter(0, Vector2(1000.0, 0.0), 100.0, 80.0, 0.0, 40.0, 1.0, 0, 0)
		for _pas: int in 20:
			e.avancer(0.05, Vector2.ZERO, 60.0, multiplicateur, 1.0)
		var parcouru := 1000.0 - e.pos[e.indice_de(id)].x
		verifier_proche(parcouru, 80.0 * multiplicateur, 0.01, "multiplicateur %s" % multiplicateur)
