extends CasDeTest
## Le poids de genre règle la part d'armes dans la boutique, sans changer les raretés : un poids
## d'arme élevé donne presque que des armes, un poids nul n'en donne aucune tant qu'une
## amélioration reste tirable.

const GRAINE := 20261126
const TIRAGES := 300


func _part_d_armes(poids_arme: float) -> float:
	var d := Donnees.charger()
	d.boutique["poids_genre"] = [
		{"manche": 1, "arme": poids_arme, "amelioration": 1.0},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var boutique := Boutique.new(d, rng)
	var armes := 0
	var total := 0
	for i: int in TIRAGES:
		boutique.tirer(1 + i % 30)
		for offre: Dictionary in boutique.offres:
			total += 1
			if int(offre["genre"]) == Types.Genre.ARME:
				armes += 1
	return float(armes) / float(total)


func test_un_poids_d_arme_eleve_donne_surtout_des_armes() -> void:
	verifier(_part_d_armes(1000.0) > 0.9, "part d'armes %s" % _part_d_armes(1000.0))


func test_un_poids_d_arme_nul_ne_donne_presque_aucune_arme() -> void:
	verifier(_part_d_armes(0.0) < 0.05, "part d'armes %s" % _part_d_armes(0.0))


func test_la_part_d_armes_augmente_avec_leur_poids() -> void:
	var avant := -1.0
	for poids: float in [0.25, 1.0, 4.0, 16.0]:
		var part := _part_d_armes(poids)
		verifier(part > avant, "poids %s : part %s pas au-dessus de %s" % [poids, part, avant])
		avant = part


func test_sans_poids_de_genre_la_boutique_tire_comme_avant() -> void:
	var d := Donnees.charger()
	d.boutique.erase("poids_genre")
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var boutique := Boutique.new(d, rng)
	boutique.tirer(1)
	verifier_egal(boutique.offres.size(), int(d.partie["nb_offres"]))
