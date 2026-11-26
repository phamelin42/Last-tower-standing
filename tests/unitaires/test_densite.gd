extends CasDeTest
## Carte de densité d'une arène : 16 × 16 cases couvrant le carré de côté 2 × rayon d'apparition
## centré sur la tour, une case = nombre d'ennemis saturé à 255.

const GRAINE := 5
const PV := 100.0

var d: Donnees
var rayon: float


func avant_chaque() -> void:
	d = Donnees.charger()
	rayon = float(d.partie["rayon_spawn"])


func _ajouter(a: Arene, position: Vector2) -> void:
	a.ennemis.ajouter(0, position, PV, 0.0, 0.0, 0.0, 0.0, 0, Types.Armure.AUCUNE)


func _non_nulles(carte: PackedByteArray) -> Array[int]:
	var out: Array[int] = []
	for i: int in carte.size():
		if carte[i] > 0:
			out.append(i)
	return out


func test_la_carte_de_densite_fait_256_octets_une_case_par_16_sur_16() -> void:
	var a := Arene.new(d, GRAINE)
	verifier_egal(a.carte_densite().size(), Arene.DENSITE_COTE * Arene.DENSITE_COTE)
	verifier_egal(a.carte_densite().size(), 256)
	verifier_egal(_non_nulles(a.carte_densite()).size(), 0, "arène vide : carte vide")
	_ajouter(a, Vector2.ZERO)
	var carte := a.carte_densite()
	verifier_egal(_non_nulles(carte), [8 * 16 + 8] as Array[int], "le centre : case (8, 8)")
	verifier_egal(carte[8 * 16 + 8], 1)


func test_les_positions_de_bord_tombent_dans_les_cases_de_bord() -> void:
	var cas := {
		Vector2(-rayon, -rayon): 0,
		Vector2(rayon, -rayon): 15,
		Vector2(-rayon, rayon): 15 * 16,
		Vector2(rayon, rayon): 15 * 16 + 15,
	}
	for position: Vector2 in cas:
		var a := Arene.new(d, GRAINE)
		_ajouter(a, position)
		verifier_egal(_non_nulles(a.carte_densite()), [cas[position]] as Array[int], str(position))


func test_une_case_sature_a_255() -> void:
	var a := Arene.new(d, GRAINE)
	for _i: int in 300:
		_ajouter(a, Vector2(10, 10))
	var carte := a.carte_densite()
	verifier_egal(_non_nulles(carte).size(), 1)
	verifier_egal(carte[_non_nulles(carte)[0]], 255)


func test_la_somme_des_cases_egale_le_nombre_d_ennemis_sans_saturation() -> void:
	var a := Arene.new(d, GRAINE)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	for _i: int in 1000:
		_ajouter(a, Vector2.from_angle(rng.randf() * TAU) * rng.randf() * rayon)
	var somme := 0
	for o: int in a.carte_densite():
		somme += o
	verifier_egal(somme, 1000)


func test_un_ennemi_mort_ne_compte_plus() -> void:
	var a := Arene.new(d, GRAINE)
	_ajouter(a, Vector2.ZERO)
	_ajouter(a, Vector2(300, 300))
	a.ennemis.infliger(0, 1.0e9, Types.TypeDegats.CHAOS)
	var somme := 0
	for o: int in a.carte_densite():
		somme += o
	verifier_egal(somme, 1)


func test_la_vue_globale_ne_calcule_les_densites_que_sur_demande() -> void:
	var p := AidesPartie.partie(d, GRAINE, 2)
	verifier(p.vue_globale().densites.is_empty(), "sans demande : vide")
	verifier(p.vue_globale(false).densites.is_empty(), "false : vide")
	var g := p.vue_globale(true)
	verifier_egal(g.densites.size(), 2, "une carte par arène")
	for id: int in [1, 2]:
		verifier_egal((g.densites[id] as PackedByteArray).size(), 256)
