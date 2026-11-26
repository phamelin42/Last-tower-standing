extends CasDeTest
## Repoussement (M3) : le recul immédiat, loin de la tour, borné et sans effet sur le boss.

const RAYON_TOUR := 60.0

var e: Ennemis
var d: Donnees
var distance_max: float
var rayon_spawn: float


func avant_chaque() -> void:
	d = AidesPartie.donnees()
	e = Ennemis.new(d)
	distance_max = float((d.partie["repoussement"] as Dictionary)["distance_max"])
	rayon_spawn = float(d.partie["rayon_spawn"])


func _a(pos: Vector2) -> int:
	return e.indice_de(e.ajouter(0, pos, 1000.0, 60.0, 4.0, 40.0, 1.0, 1, 0))


func test_le_repoussement_eloigne_de_la_tour_de_la_distance_demandee() -> void:
	for angle_deg: int in range(0, 360, 45):
		var depart := Vector2(300.0, 0.0).rotated(deg_to_rad(float(angle_deg)))
		var i := _a(depart)
		e.repousser(i, 100.0, Vector2.ZERO, 1.0)
		verifier_proche(e.pos[i].length(), 400.0, 0.01, "angle %d" % angle_deg)
		verifier_proche(e.pos[i].angle_to(depart), 0.0, 0.0001, "toujours sur la même demi-droite")
		e.purger()


func test_le_recul_part_de_la_tour_donnee_pas_de_l_origine() -> void:
	var i := _a(Vector2(500, 100))
	e.repousser(i, 50.0, Vector2(500, 0), 1.0)
	verifier_proche(e.pos[i].x, 500.0, 0.001)
	verifier_proche(e.pos[i].y, 150.0, 0.001)


func test_il_est_borne_par_distance_max_et_nul_pour_le_boss() -> void:
	var i := _a(Vector2(200, 0))
	e.repousser(i, distance_max * 10.0, Vector2.ZERO, 1.0)
	verifier_proche(e.pos[i].x, 200.0 + minf(distance_max, rayon_spawn - 200.0), 0.01)
	var facteur_boss: float = float((d.partie["repoussement"] as Dictionary)["facteur_boss"])
	var boss := _a(Vector2(200, 0))
	e.repousser(boss, 100.0, Vector2.ZERO, facteur_boss)
	verifier_proche(
		e.pos[boss].x, 200.0 + 100.0 * facteur_boss, 0.001, "le boss recule de facteur_boss"
	)
	var moitie := _a(Vector2(200, 0))
	e.repousser(moitie, 100.0, Vector2.ZERO, 0.5)
	verifier_proche(e.pos[moitie].x, 250.0, 0.001)


func test_un_ennemi_deja_loin_n_est_pas_repousse_hors_du_cercle_d_apparition() -> void:
	var tout_pres := _a(Vector2(rayon_spawn - 10.0, 0))
	e.repousser(tout_pres, 100.0, Vector2.ZERO, 1.0)
	verifier_proche(e.pos[tout_pres].length(), rayon_spawn, 0.01, "arrêté au cercle")
	var dehors := _a(Vector2(rayon_spawn + 50.0, 0))
	e.repousser(dehors, 100.0, Vector2.ZERO, 1.0)
	verifier_proche(e.pos[dehors].x, rayon_spawn + 50.0, 0.001, "ne bouge pas")


func test_un_ennemi_sur_la_tour_est_repousse_dans_une_direction_definie() -> void:
	var i := _a(Vector2.ZERO)
	e.repousser(i, 80.0, Vector2.ZERO, 1.0)
	verifier(is_finite(e.pos[i].x) and is_finite(e.pos[i].y), "pas de division par zéro")
	verifier_proche(e.pos[i].length(), 80.0, 0.001)


func test_le_repoussement_invalide_la_distance_minimale_en_cache() -> void:
	var i := _a(Vector2(100, 0))
	verifier_proche(e.distance2_minimale(Vector2.ZERO), 10000.0, 0.01)
	e.repousser(i, 100.0, Vector2.ZERO, 1.0)
	verifier_proche(e.distance2_minimale(Vector2.ZERO), 40000.0, 0.01, "le cache suit le recul")
