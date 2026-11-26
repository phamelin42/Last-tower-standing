extends CasDeTest
## Tir tournant (M7) : des rayons qui balaient autour de la tour, sans hasard.

const CENTRE := Vector2.ZERO
const PORTEE := 600

var d: Donnees
var e: Ennemis
var rng: RandomNumberGenerator


func avant_chaque() -> void:
	d = AidesPartie.donnees()
	e = Ennemis.new(d)
	rng = RandomNumberGenerator.new()
	rng.seed = 77


func _effet(
	branches: int = 1, pas: float = 30.0, largeur: float = 20.0, sens: String = "horaire"
) -> Dictionary:
	return {
		"kind": "tournant", "branches": branches, "pas_deg": pas, "largeur": largeur, "sens": sens
	}


func _def(effet: Dictionary, statuts: Array = []) -> Dictionary:
	# Une vraie arme du catalogue (son index d'événement existe), avec l'effet à tester.
	var id: String = d.armes.keys()[0]
	var def: Dictionary = (d.armes[id] as Dictionary).duplicate(true)
	def["effets"] = [effet]
	def["statuts"] = statuts
	def["type_degats"] = Types.TypeDegats.CHAOS
	def["degats"] = 10.0
	def["recharge"] = 1.0
	def["portee"] = PORTEE
	def["degats_par_mana_max"] = 0.0
	return def


func _ennemi(pos: Vector2, pv: float = 1.0e6) -> int:
	return e.indice_de(e.ajouter(0, pos, pv, 0.0, 0.0, 40.0, 1.0, 1, Types.Armure.AUCUNE))


## Un tir de l'arme (le pas dure une recharge entière : l'arme tire à chaque appel).
func _tirer(arme: ArmeEquipee, stats: StatsTour = StatsTour.new()) -> Tir.Bilan:
	var bilan := Tir.Bilan.new()
	Tir.avancer_arme(arme, 1.0, stats, e, CENTRE, d, rng, 1.0, bilan)
	return bilan


func test_la_phase_avance_de_pas_deg_dans_le_bon_sens_et_boucle_a_360() -> void:
	for sens: String in ["horaire", "antihoraire"]:
		avant_chaque()
		_ennemi(Vector2(300, 0))
		var arme := ArmeEquipee.new(_def(_effet(1, 100.0, 20.0, sens)))
		verifier_egal(arme.phase_deg, 0.0, "départ à 0")
		var attendu := 0.0
		for tir: int in 10:
			_tirer(arme)
			attendu = fposmod(attendu + (100.0 if sens == "horaire" else -100.0), 360.0)
			verifier_proche(arme.phase_deg, attendu, 0.0001, "%s, tir %d" % [sens, tir + 1])
			verifier(arme.phase_deg >= 0.0 and arme.phase_deg < 360.0)


func test_un_ennemi_dans_le_rayon_est_touche_et_un_ennemi_hors_portee_ou_hors_largeur_ne_l_est_pas(
) -> void:
	var dedans := _ennemi(Vector2(300, 5))
	var hors_largeur := _ennemi(Vector2(300, 50))
	var hors_portee := _ennemi(Vector2(PORTEE + 100, 0))
	var derriere := _ennemi(Vector2(-300, 0))
	var arme := ArmeEquipee.new(_def(_effet(1, 30.0, 20.0)))
	_tirer(arme)
	verifier(e.pv[dedans] < 1.0e6, "dans la largeur")
	verifier_egal(e.pv[hors_largeur], 1.0e6, "hors largeur")
	verifier_egal(e.pv[hors_portee], 1.0e6, "au-delà de la portée")
	verifier_egal(e.pv[derriere], 1.0e6, "dans le dos du rayon")


func test_sur_un_tour_complet_chaque_ennemi_a_portee_est_touche_au_moins_une_fois() -> void:
	var cibles: Array[int] = []
	for k: int in 8:
		cibles.append(_ennemi(Vector2(400, 0).rotated(deg_to_rad(45.0 * k + 7.0))))
	var arme := ArmeEquipee.new(_def(_effet(1, 10.0, 60.0)))
	for _tir: int in 36:
		_tirer(arme)
	for i: int in cibles:
		verifier(e.pv[i] < 1.0e6, "ennemi %d touché au moins une fois" % i)


func test_un_ennemi_n_est_touche_qu_une_fois_par_tir_meme_avec_plusieurs_rayons() -> void:
	# Deux rayons très larges recouvrent le même ennemi : un seul coup.
	var i := _ennemi(Vector2(200, 0))
	var arme := ArmeEquipee.new(_def(_effet(2, 30.0, 400.0)))
	_tirer(arme)
	verifier_proche(1.0e6 - e.pv[i], 10.0, 0.01, "un seul coup de 10")


func test_les_branches_sont_regulierement_reparties() -> void:
	for branches: int in [1, 2, 3, 4, 8]:
		avant_chaque()
		_ennemi(Vector2(300, 0))
		var arme := ArmeEquipee.new(_def(_effet(branches, 0.0001, 10.0)))
		var bilan := _tirer(arme)
		var angles: Array[float] = []
		for ev: Dictionary in bilan.evenements:
			if ev["k"] == "tir":
				angles.append(rad_to_deg((ev["vers"] as Vector2).angle()))
		verifier_egal(angles.size(), branches, "un événement par rayon")
		angles.sort()
		for k: int in angles.size() - 1:
			var ecart := angles[k + 1] - angles[k]
			verifier_proche(ecart, 360.0 / float(branches), 0.01, "%d branches" % branches)


func test_deux_exemplaires_de_la_meme_arme_ont_chacun_leur_phase() -> void:
	_ennemi(Vector2(300, 0))
	var a := ArmeEquipee.new(_def(_effet(1, 40.0)))
	var b := ArmeEquipee.new(_def(_effet(1, 40.0)))
	_tirer(a)
	_tirer(a)
	_tirer(b)
	verifier_proche(a.phase_deg, 80.0, 0.0001)
	verifier_proche(b.phase_deg, 40.0, 0.0001, "le second exemplaire n'a tiré qu'une fois")


func test_sans_ennemi_a_portee_il_n_y_a_pas_de_tir_et_la_phase_ne_bouge_pas() -> void:
	var arme := ArmeEquipee.new(_def(_effet(1, 40.0)))
	var bilan := _tirer(arme)
	verifier(bilan.evenements.is_empty())
	verifier_egal(arme.phase_deg, 0.0)
	verifier_egal(arme.recharge_restante, 0.0, "l'arme reste prête")


func test_le_tir_tournant_ne_consomme_pas_le_hasard_hors_critique() -> void:
	_ennemi(Vector2(300, 0))
	var arme := ArmeEquipee.new(_def(_effet(4, 30.0, 50.0)))
	var avant := RandomNumberGenerator.new()
	avant.seed = 77
	for _k: int in 5:
		_tirer(arme)
	verifier_egal(rng.randi(), avant.randi(), "aucun tirage sans chance de critique")


func test_un_evenement_par_rayon_porte_le_genre_tournant_et_l_arme() -> void:
	_ennemi(Vector2(300, 0))
	var arme := ArmeEquipee.new(_def(_effet(3, 30.0, 25.0)))
	var bilan := _tirer(arme)
	var genre := VueArene.genre_depuis_nom("tournant")
	verifier(genre > 0)
	var tirs := 0
	for ev: Dictionary in bilan.evenements:
		verifier_egal(int(ev["genre"]), genre)
		verifier_egal(int(ev["arme"]), d.ids_catalogue.find(arme.id), "l'arme est nommée")
		if ev["k"] == "tir":
			tirs += 1
			verifier_proche(float(ev["rayon"]), 25.0, 0.0001, "le rayon porte la largeur")
			verifier_egal(ev["de"], CENTRE)
			verifier_proche((ev["vers"] as Vector2).length(), float(PORTEE), 0.01)
	verifier_egal(tirs, 3)


func test_le_tir_tournant_declenche_les_statuts_et_la_mana_au_coup_de_l_arme() -> void:
	var cible := _ennemi(Vector2(300, 0))
	var statuts: Array = [
		{"kind": "vulnerabilite", "ratio": 0.2, "duree": 4.0},
		{"kind": "mana_au_coup", "valeur": 3.0},
	]
	var arme := ArmeEquipee.new(_def(_effet(1, 30.0, 20.0), statuts))
	var bilan := _tirer(arme)
	verifier_proche(bilan.mana, 3.0, 0.0001)
	verifier_proche(e.vulnerabilite[cible * 5 + Types.TypeDegats.CHAOS], 0.2, 0.0001)


func test_le_critique_vaut_pour_chaque_rayon() -> void:
	_ennemi(Vector2(300, 0))
	_ennemi(Vector2(-300, 0))
	var stats := StatsTour.new()
	stats.critique_chance = 10.0
	var arme := ArmeEquipee.new(_def(_effet(2, 30.0, 20.0)))
	var bilan := _tirer(arme, stats)
	verifier(bilan.degats > 20.0, "les deux coups sont critiques")


# --- Reproductibilité --------------------------------------------------------------------------


func _donnees_avec_tournant() -> Donnees:
	var brut := AidesPartie.brut()
	var armes: Array = brut["armes.json"]
	var arme: Dictionary = (armes[0] as Dictionary).duplicate(true)
	arme["id"] = "tourniquet_d_essai"
	arme["nom"] = "Tourniquet d’essai"
	arme["effets"] = [_effet(3, 25.0, 40.0)]
	arme["statuts"] = []
	armes.append(arme)
	return Donnees.depuis_brut(brut)


func _empreinte_de_partie(graine: int) -> int:
	var donnees := _donnees_avec_tournant()
	var a := Arene.new(donnees, graine)
	a.demarrer_manche(
		3,
		Composition.unique(0),
		{"pv": 1.0, "degats": 1.0, "vitesse": 1.0, "resistance_controle": 1.0}
	)
	a.inventaire.ajouter("tourniquet_d_essai")
	a.inventaire.ajouter("tourniquet_d_essai")
	a.synchroniser()
	var cumul := 0
	for _pas: int in 600:
		a.avancer(0.05)
		var v := a.vue(Types.Phase.MANCHE, 10.0, -1, false)
		cumul = hash([cumul, str(v.ennemis_pos), str(v.ennemis_pv), str(v.evenements), v.tour_pv])
	verifier(a.armes.size() == 2, "les deux exemplaires sont équipés")
	return cumul


func test_deux_parties_de_meme_graine_donnent_les_memes_evenements_sur_600_pas() -> void:
	var premiere := _empreinte_de_partie(2026)
	var seconde := _empreinte_de_partie(2026)
	verifier_egal(premiere, seconde)
	verifier_different(premiere, _empreinte_de_partie(2027), "une autre graine change la partie")
