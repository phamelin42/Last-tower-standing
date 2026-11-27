extends CasDeTest
## Malédictions (M2) : deux statuts distincts, non cumulables, qui réduisent ce que la tour subit.

const DT := 0.05
const RAYON_TOUR := 60.0

var e: Ennemis
var d: Donnees
var plafond: float


func avant_chaque() -> void:
	d = AidesPartie.donnees()
	e = Ennemis.new(d)
	plafond = float((d.partie["malediction"] as Dictionary)["plafond"])


## Un attaquant déjà à portée : corps à corps (portée 40) ou à distance (portée 300).
func _attaquant(a_distance: bool, degats: float = 10.0) -> int:
	var portee := 300.0 if a_distance else 40.0
	var arret := portee if a_distance else RAYON_TOUR + portee
	return e.ajouter(0, Vector2(arret, 0), 1000.0, 0.0, degats, portee, 1.0, 1, Types.Armure.AUCUNE)


func _degats_du_premier_pas() -> float:
	var r := e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
	return float(r["degats_tour"])


func test_deux_maledictions_sur_un_ennemi_sont_independantes_et_non_cumulables() -> void:
	var i := e.indice_de(_attaquant(false))
	for _k: int in 100:
		e.maudire_degats(i, 0.1, 3.0)
		e.maudire_degats(i, 0.4, 3.0)
		e.maudire_degats(i, 0.2, 3.0)
		e.maudire_toucher(i, 0.3, 3.0)
	verifier_proche(e.maudit_degats[i], 0.4, 0.00001, "le plus fort l'emporte, sans cumul")
	verifier_proche(e.maudit_toucher[i], 0.3, 0.00001, "l'autre statut est indépendant")
	e.maudire_degats(i, 5.0, 3.0)
	e.maudire_toucher(i, 5.0, 3.0)
	verifier_proche(e.maudit_degats[i], plafond, 0.00001, "plafond exact")
	verifier_proche(e.maudit_toucher[i], plafond, 0.00001)
	verifier((e.statuts[i] & Types.STATUT_MAUDIT) != 0, "le bit est posé")
	var facteur := _degats_du_premier_pas() / 10.0
	verifier(facteur >= 0.0 and is_finite(facteur), "jamais un multiplicateur négatif")
	verifier_proche(facteur, (1.0 - plafond) * (1.0 - plafond), 0.0001)


func test_une_malediction_plus_faible_ne_remplace_pas_la_plus_forte_mais_rafraichit_la_duree(
) -> void:
	var i := e.indice_de(_attaquant(false))
	e.maudire_degats(i, 0.5, 1.0)
	e.maudire_degats(i, 0.1, 4.0)
	verifier_proche(e.maudit_degats[i], 0.5, 0.00001)
	verifier_proche(e.maudit_degats_t[i], 4.0, 0.00001, "la durée se rafraîchit au plus long")


func test_la_malediction_expire_et_retire_son_bit() -> void:
	var i := e.indice_de(e.ajouter(0, Vector2(900, 0), 1000.0, 0.0, 4.0, 40.0, 1.0, 1, 0))
	e.maudire_degats(i, 0.4, 1.0)
	e.maudire_toucher(i, 0.4, 2.0)
	for _k: int in 22:
		e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
	verifier_egal(e.maudit_degats[i], 0.0, "dégâts expirée à 1 s")
	verifier((e.statuts[i] & Types.STATUT_MAUDIT) != 0, "le toucher dure encore")
	for _k: int in 30:
		e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
	verifier_egal(e.maudit_toucher[i], 0.0)
	verifier_egal(int(e.statuts[i]) & Types.STATUT_MAUDIT, 0)


func test_la_malediction_de_degats_reduit_les_attaques_au_corps_a_corps_et_a_distance() -> void:
	for a_distance: bool in [false, true]:
		e = Ennemis.new(d)
		var i := e.indice_de(_attaquant(a_distance, 10.0))
		e.maudire_degats(i, 0.4, 5.0)
		var recu := _degats_du_premier_pas()
		verifier_proche(recu, 6.0, 0.001, "à distance : %s" % a_distance)
		var attaquants: PackedInt32Array = (
			e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)["attaquants_cac"]
		)
		verifier(attaquants.size() <= 1)


func test_la_malediction_de_toucher_reduit_en_moyenne() -> void:
	var i := e.indice_de(_attaquant(false, 10.0))
	e.maudire_toucher(i, 0.25, 5.0)
	verifier_proche(_degats_du_premier_pas(), 7.5, 0.001, "× (1 − chance), sans tirage")


## Une arène dont la tour est seule face à un attaquant déjà à portée.
func _arene_avec_attaquant(maudit: bool, a_distance: bool = false) -> Arene:
	var a := Arene.new(d, 4242)
	a.demarrer_manche(
		1,
		Composition.unique(0),
		{"pv": 1.0, "degats": 1.0, "vitesse": 0.0, "resistance_controle": 1.0}
	)
	var portee := 300.0 if a_distance else 40.0
	var arret := portee if a_distance else RAYON_TOUR + portee
	var id := a.ennemis.ajouter(
		0, Vector2(arret, 0), 1.0e6, 0.0, 10.0, portee, 1.0, 1, Types.Armure.AUCUNE
	)
	if maudit:
		var i := a.ennemis.indice_de(id)
		a.ennemis.maudire_degats(i, 0.5, 30.0)
	return a


func test_la_tour_subit_les_degats_reduits_au_corps_a_corps_et_a_distance() -> void:
	for a_distance: bool in [false, true]:
		var nue := _arene_avec_attaquant(false, a_distance)
		var maudite := _arene_avec_attaquant(true, a_distance)
		nue.avancer(DT)
		maudite.avancer(DT)
		var perdus_nue := float((d.partie["tour"] as Dictionary)["pv"]) - nue.pv
		var perdus := float((d.partie["tour"] as Dictionary)["pv"]) - maudite.pv
		verifier_proche(perdus_nue, 10.0, 0.001, "sans malédiction")
		verifier_proche(perdus, 5.0, 0.001, "avec malédiction, à distance : %s" % a_distance)


func test_la_malediction_passe_avant_la_mana() -> void:
	var a := _arene_avec_attaquant(true)
	(d.partie["tour"] as Dictionary)["mana_cout_par_pv"] = 1.0
	a._stats.mana_max_bonus = 200.0
	a.mana = 100.0
	var mana_avant := a.mana
	var pv_avant := a.pv
	a.avancer(DT)
	verifier_proche(pv_avant - a.pv, 0.0, 0.001, "la mana absorbe tout")
	var regen := float((d.partie["tour"] as Dictionary)["mana_regen"]) * DT
	verifier_proche(mana_avant + regen - a.mana, 5.0, 0.01, "la mana n'absorbe que les 5 restants")


func test_une_arene_maudite_suit_la_meme_suite_de_tirages() -> void:
	# Le hasard n'est tiré que par l'esquive de la tour : la malédiction n'y touche pas.
	var nue := _arene_avec_attaquant(false)
	var maudite := _arene_avec_attaquant(true)
	for a: Arene in [nue, maudite]:
		a._stats.esquive = 0.5
	for _k: int in 200:
		nue.avancer(DT)
		maudite.avancer(DT)
	verifier_egal(nue._rng.randi(), maudite._rng.randi(), "la suite des tirages est la même")


func test_la_malediction_passe_avant_les_multiplicateurs_de_degats_de_la_tour() -> void:
	var i := e.indice_de(_attaquant(true, 10.0))
	e.maudire_degats(i, 0.5, 5.0)
	e.maudire_toucher(i, 0.5, 5.0)
	var r := e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 2.0)
	verifier_proche(float(r["degats_tour"]), 10.0 * 2.0 * 0.5 * 0.5, 0.001, "valeur exacte")


func test_une_explosion_au_contact_est_maudite_aussi() -> void:
	var id := e.ajouter(0, Vector2(RAYON_TOUR + 40.0, 0), 50.0, 0.0, 20.0, 40.0, 1.0, 1, 0, true)
	e.maudire_degats(e.indice_de(id), 0.5, 5.0)
	var r := e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
	verifier_proche(float(r["degats_tour"]), 10.0, 0.001)
