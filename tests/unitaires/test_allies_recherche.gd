extends CasDeTest
## La recherche de cible des alliés (S27) passe par une grille : elle doit trouver exactement le
## même ennemi que le parcours complet, au même identifiant à égalité, quelles que soient les
## positions (dans la grille, au bord, hors d'elle), les gardes et les morts.

const GRAINE := 20261127
const SCENES := 300
const ENNEMIS := 160
const ALLIES := 12


func _hasard() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	return rng


func _scene(rng: RandomNumberGenerator, reseau: bool) -> Array:
	var d := Donnees.charger()
	var e := Ennemis.new(d)
	for n: int in ENNEMIS:
		var p: Vector2
		if reseau:
			# Réseau de 10 px : des distances exactement égales entre candidats.
			p = Vector2(float(rng.randi_range(-80, 80)), float(rng.randi_range(-80, 80))) * 10.0
		else:
			p = Vector2(rng.randf_range(-900.0, 900.0), rng.randf_range(-900.0, 900.0))
		e.ajouter(0, p, 1.0e9, 0.0, 1.0, 45.0, 1.0, 1, Types.Armure.LEGERE)
	for i: int in ENNEMIS:
		if rng.randf() < 0.2:
			e.mort[i] = 1
	var al := Allies.new(d)
	for k: int in ALLIES:
		al.invoquer(k % 2, Vector2.ZERO, 1000.0, 1.0, 0, 0, 1, 0)
		if reseau:
			al.pos[k] = (
				Vector2(float(rng.randi_range(-70, 70)), float(rng.randi_range(-70, 70))) * 10.0
			)
		else:
			al.pos[k] = Vector2(rng.randf_range(-1100.0, 1100.0), rng.randf_range(-1100.0, 1100.0))
		al.garde[k] = rng.randf_range(100.0, 750.0)
	return [e, al]


func _comparer(reseau: bool) -> void:
	var rng := _hasard()
	var trouves := 0
	for s: int in SCENES:
		var scene := _scene(rng, reseau)
		var e: Ennemis = scene[0]
		var al: Allies = scene[1]
		al._candidats_prets = false
		for k: int in ALLIES:
			var grille := al._chercher(k, e, Vector2.ZERO)
			var direct := al._chercher_directe(k, e)
			trouves += 1 if direct >= 0 else 0
			if grille != direct:
				verifier_egal(grille, direct, "scène %d, allié %d" % [s, k])
				return
	verifier(
		trouves > SCENES * ALLIES / 4, "la comparaison trouve souvent une cible (%d)" % trouves
	)


func test_la_grille_trouve_le_meme_ennemi_que_le_parcours_complet() -> void:
	_comparer(false)


func test_a_distance_egale_la_grille_prend_le_plus_petit_identifiant() -> void:
	_comparer(true)


func test_un_ennemi_mort_n_est_jamais_choisi() -> void:
	var d := Donnees.charger()
	var e := Ennemis.new(d)
	var mort := e.indice_de(e.ajouter(0, Vector2(100, 0), 1.0e9, 0.0, 1.0, 45.0, 1.0, 1, 0))
	var vivant := e.indice_de(e.ajouter(0, Vector2(300, 0), 1.0e9, 0.0, 1.0, 45.0, 1.0, 1, 0))
	e.mort[mort] = 1
	var al := Allies.new(d)
	al.invoquer(0, Vector2.ZERO, 1000.0, 1.0, 0, 0, 1, 0)
	al.pos[0] = Vector2(80, 0)
	al.garde[0] = 700.0
	al._candidats_prets = false
	verifier_egal(al._chercher(0, e, Vector2.ZERO), vivant)
