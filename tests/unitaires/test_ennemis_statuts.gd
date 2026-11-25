extends CasDeTest
## Statuts des ennemis : poison, brûlure, givre et étourdissement, et leur résistance.

const DT := 0.05
const CENTRE := Vector2.ZERO
const RAYON_TOUR := 60.0

var e: Ennemis


func avant_chaque() -> void:
	var brut: Dictionary = {}
	for nom: String in [
		"partie.json", "economie.json", "difficulte.json", "efficacite.json", "boutique.json"
	]:
		brut[nom] = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + nom))
	brut["armes.json"] = []
	brut["ameliorations.json"] = []
	brut["ennemis.json"] = {"familles": [], "convoi": {}, "boss": {}}
	e = Ennemis.new(Donnees.depuis_brut(brut))


func _p(recu: float, attendu: float, tolerance: float = 0.01, message: String = "") -> void:
	verifier_proche(recu, attendu, tolerance, message)


func _ajouter(
	pos: Vector2 = Vector2(500, 0),
	pv: float = 100.0,
	armure: int = Types.Armure.LEGERE,
	volant: bool = false,
	portee: float = 40.0,
	degats: float = 4.0,
	cadence: float = 1.0,
	prime: int = 2,
	vitesse: float = 60.0
) -> int:
	return e.ajouter(0, pos, pv, vitesse, degats, portee, cadence, prime, volant, armure)


## Avance de `n` pas et cumule les indices tués par statut, lus avant la purge.
func _pas(n: int, mult_vitesse: float = 1.0) -> Array[int]:
	var tues: Array[int] = []
	for _k: int in n:
		var r := e.avancer(DT, CENTRE, RAYON_TOUR, mult_vitesse, 1.0)
		var par_statut: PackedInt32Array = r["tues_par_statut"]
		for i: int in par_statut:
			tues.append(e.ids[i])
	return tues


func _i(id: int) -> int:
	return e.indice_de(id)


# --- Statuts -----------------------------------------------------------------------------------


func test_poison_seul_la_somme_des_pas_vaut_le_total() -> void:
	var id := _ajouter(Vector2(900, 0), 1000.0)
	e.empoisonner(_i(id), 100.0, 4.0)
	verifier_egal(int(e.statuts[_i(id)]) & Types.STATUT_EMPOISONNE, Types.STATUT_EMPOISONNE)
	_pas(30)
	_p(e.pv[_i(id)], 1000.0 - 100.0 * 1.5 / 4.0, 0.05, "au pas 30 : 37,5 %% retirés")
	_pas(60)
	_p(e.pv[_i(id)], 900.0, 0.05, "la somme vaut le total")
	verifier_egal(int(e.statuts[_i(id)]) & Types.STATUT_EMPOISONNE, 0, "poison terminé")


func test_poison_recommence_cumule_sans_depasser_l_intention() -> void:
	var id := _ajouter(Vector2(900, 0), 1000.0)
	e.empoisonner(_i(id), 100.0, 2.0)
	_pas(20)
	e.empoisonner(_i(id), 100.0, 3.0)
	_pas(100)
	# 50 déjà retirés + (50 restants + 100 ajoutés) = 200, ni plus ni moins.
	_p(e.pv[_i(id)], 800.0, 0.1)
	verifier_egal(int(e.statuts[_i(id)]) & Types.STATUT_EMPOISONNE, 0)


func test_poison_invalide_est_ignore() -> void:
	var id := _ajouter(Vector2(900, 0), 100.0)
	e.empoisonner(_i(id), 0.0, 2.0)
	e.empoisonner(_i(id), -10.0, 2.0)
	e.empoisonner(_i(id), 10.0, 0.0)
	e.empoisonner(_i(id), 10.0, -1.0)
	e.empoisonner(_i(id), NAN, 2.0)
	e.empoisonner(_i(id), 10.0, NAN)
	_pas(10)
	_p(e.pv[_i(id)], 100.0, 0.0001, "aucun soin, aucun dégât")
	verifier_egal(int(e.statuts[_i(id)]), 0)


func test_brulure_seule_retire_ratio_fois_le_coup() -> void:
	var id := _ajouter(Vector2(900, 0), 1000.0)
	e.bruler(_i(id), 0.25, 80.0, 2.0)
	verifier_egal(int(e.statuts[_i(id)]) & Types.STATUT_BRULE, Types.STATUT_BRULE)
	_pas(60)
	_p(e.pv[_i(id)], 980.0, 0.05)
	verifier_egal(int(e.statuts[_i(id)]) & Types.STATUT_BRULE, 0)


func test_brulure_cumule() -> void:
	var id := _ajouter(Vector2(900, 0), 1000.0)
	e.bruler(_i(id), 0.25, 80.0, 2.0)
	e.bruler(_i(id), 0.25, 80.0, 2.0)
	_pas(60)
	_p(e.pv[_i(id)], 960.0, 0.05)


func test_les_quatre_statuts_sur_le_meme_ennemi_agissent_chacun() -> void:
	var id := _ajouter(Vector2(900, 0), 1000.0)
	var i := _i(id)
	for _k: int in 3:
		e.givrer(i, 1.0)
	e.empoisonner(i, 40.0, 2.0)
	e.bruler(i, 0.5, 40.0, 2.0)
	e.etourdir(i, 1.0, 1.0)
	var attendu := (
		Types.STATUT_RALENTI | Types.STATUT_EMPOISONNE | Types.STATUT_BRULE | Types.STATUT_ETOURDI
	)
	verifier_egal(int(e.statuts[i]), attendu)
	var avant := e.pos[i]
	_pas(10)
	verifier_egal(e.pos[i], avant, "étourdi : immobile")
	_p(e.pv[i], 985.0, 0.2, "poison et brûlure ont agi : 10 + 5 en 0,5 s")
	_pas(30)
	var bits := int(e.statuts[i])
	verifier_egal(bits & Types.STATUT_EMPOISONNE, 0)
	verifier_egal(bits & Types.STATUT_BRULE, 0)
	verifier_egal(bits & Types.STATUT_ETOURDI, 0)
	_p(e.pv[i], 940.0, 0.05, "40 de poison + 20 de brûlure")


func test_etourdi_et_givre_ensemble_meurent_une_fois_par_statut() -> void:
	var id := _ajouter(Vector2(900, 0), 3.0)
	var i := _i(id)
	e.etourdir(i, 5.0, 1.0)
	for _k: int in 8:
		e.givrer(i, 1.0)
	e.empoisonner(i, 10.0, 0.2)
	e.bruler(i, 1.0, 10.0, 0.2)
	var tues := _pas(10)
	verifier_egal(tues, [id] as Array[int])


func test_givre_sept_cumuls_ralentissent_sans_geler() -> void:
	var id := _ajouter(Vector2(900, 0), 100.0)
	var i := _i(id)
	for _k: int in 7:
		e.givrer(i, 1.0)
	var bits := int(e.statuts[i])
	verifier_egal(bits & Types.STATUT_RALENTI, Types.STATUT_RALENTI)
	verifier_egal(bits & Types.STATUT_GELE, 0)
	var avant := e.pos[i].x
	_pas(1)
	# 7 cumuls × 0,08 = 56 % de ralentissement : 60 × 0,05 × 0,44 = 1,32 unité.
	_p(avant - e.pos[i].x, 1.32, 0.01)


func test_givre_huitieme_cumul_gele_trois_secondes_au_plus() -> void:
	var id := _ajouter(Vector2(900, 0), 100.0)
	var i := _i(id)
	for _k: int in 8:
		e.givrer(i, 1.0)
	verifier_egal(int(e.statuts[i]) & Types.STATUT_GELE, Types.STATUT_GELE)
	verifier_egal(int(e.statuts[i]) & Types.STATUT_RALENTI, 0, "cumuls remis à 0")
	_p(e.gel[i], 3.0, 0.0001)
	var avant := e.pos[i]
	_pas(55)
	verifier_egal(e.pos[i], avant, "gelé : immobile pendant ~2,75 s")
	_pas(7)
	verifier_egal(int(e.statuts[i]) & Types.STATUT_GELE, 0, "dégel après 3 s")
	verifier(e.pos[i].x < avant.x, "il repart")


func test_givre_sur_un_ennemi_deja_gele_ne_cumule_ni_ne_prolonge() -> void:
	var id := _ajouter(Vector2(900, 0), 100.0)
	var i := _i(id)
	for _k: int in 8:
		e.givrer(i, 1.0)
	_pas(20)
	var reste: float = e.gel[i]
	for _k: int in 20:
		e.givrer(i, 1.0)
	_p(e.gel[i], reste, 0.0001, "pas de prolongation")
	verifier_egal(int(e.statuts[i]) & Types.STATUT_RALENTI, 0, "pas de cumul pendant le gel")
	_pas(40)
	var bits := int(e.statuts[i])
	verifier_egal(bits & Types.STATUT_GELE, 0, "dégelé à l'heure prévue")
	verifier_egal(bits & Types.STATUT_RALENTI, 0, "aucun cumul fantôme après le dégel")


func test_regel_possible_apres_le_degel() -> void:
	var id := _ajouter(Vector2(900, 0), 100.0)
	var i := _i(id)
	for _k: int in 8:
		e.givrer(i, 1.0)
	_pas(70)
	verifier_egal(int(e.statuts[i]) & Types.STATUT_GELE, 0)
	for _k: int in 8:
		e.givrer(i, 1.0)
	verifier_egal(int(e.statuts[i]) & Types.STATUT_GELE, Types.STATUT_GELE)
	_p(e.gel[i], 3.0, 0.0001)


func test_cumuls_de_givre_non_entretenus_retombent_d_un_cran_par_seconde() -> void:
	var id := _ajouter(Vector2(900, 0), 100.0)
	var i := _i(id)
	for _k: int in 3:
		e.givrer(i, 1.0)
	_pas(21)
	# Une seconde et un peu : 3 → 2 cumuls.
	verifier_egal(e.givre_cumuls[i], 2)
	_pas(20)
	verifier_egal(e.givre_cumuls[i], 1)
	_pas(20)
	verifier_egal(e.givre_cumuls[i], 0)
	verifier_egal(int(e.statuts[i]) & Types.STATUT_RALENTI, 0)


func test_resistance_aux_controles_etourdissement() -> void:
	for cas: Array in [[1.0, 2.0], [0.5, 1.0], [0.1, 0.2], [0.0, 0.0]]:
		avant_chaque()
		var id := _ajouter(Vector2(900, 0), 100.0)
		var i := _i(id)
		e.etourdir(i, 2.0, cas[0])
		_p(e.etourdi[i], cas[1], 0.0001, "résistance %s" % cas[0])
		var bit := int(e.statuts[i]) & Types.STATUT_ETOURDI
		verifier_egal(bit != 0, float(cas[1]) > 0.0, "drapeau à résistance %s" % cas[0])


func test_resistance_nulle_aucun_etourdissement_ni_gel_et_pas_de_nan() -> void:
	var id := _ajouter(Vector2(900, 0), 100.0)
	var i := _i(id)
	e.etourdir(i, 2.0, 0.0)
	for _k: int in 20:
		e.givrer(i, 0.0)
	verifier_egal(int(e.statuts[i]) & (Types.STATUT_ETOURDI | Types.STATUT_GELE), 0)
	_p(e.gel[i], 0.0, 0.0)
	_p(e.etourdi[i], 0.0, 0.0)
	var avant := e.pos[i].x
	_pas(5)
	verifier(e.pos[i].x < avant, "il avance librement")
	verifier(is_finite(e.pos[i].x) and is_finite(e.pv[i]))
	# Résistance négative ou NaN : traitée comme nulle.
	e.etourdir(i, 2.0, -1.0)
	e.etourdir(i, 2.0, NAN)
	e.givrer(i, NAN)
	verifier(is_finite(e.etourdi[i]) and is_finite(e.gel[i]))
	verifier_egal(int(e.statuts[i]) & Types.STATUT_ETOURDI, 0)


func test_etourdissement_prolonge_sans_cumuler() -> void:
	var id := _ajouter(Vector2(900, 0), 100.0)
	var i := _i(id)
	e.etourdir(i, 2.0, 1.0)
	e.etourdir(i, 1.0, 1.0)
	_p(e.etourdi[i], 2.0, 0.0001, "une durée plus courte ne raccourcit pas")
	e.etourdir(i, 3.0, 1.0)
	_p(e.etourdi[i], 3.0, 0.0001, "une plus longue prolonge, sans somme")


func test_gel_plafonne_meme_a_resistance_elevee() -> void:
	var id := _ajouter(Vector2(900, 0), 100.0)
	var i := _i(id)
	for _k: int in 8:
		e.givrer(i, 100.0)
	_p(e.gel[i], 3.0, 0.0001)
