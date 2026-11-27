extends CasDeTest
## Ce que la joueuse doit voir des mécaniques posées du lot 9 : un disque au sol pour une zone, une
## bombe qui grossit et pulse jusqu'à son explosion, un rayon par branche d'un tir tournant, un
## trait de recul vers l'extérieur pour un repoussement.

const SCENE := "res://scenes/arene_2d.tscn"

var _arene: Arene2D = null
var _effets: Effets = null
var _tick: int = 0


func avant_chaque() -> void:
	_arene = (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(_arene)
	_arene.reinitialiser()
	_effets = Effets.new()
	arbre.root.add_child(_effets)
	_tick = 0


func apres_chaque() -> void:
	for noeud: Node in [_arene, _effets]:
		if is_instance_valid(noeud):
			if noeud.get_parent() != null:
				noeud.get_parent().remove_child(noeud)
			noeud.free()
	_arene = null
	_effets = null


func _vue(zones: Array[Dictionary] = [], bombes: Array[Dictionary] = []) -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	vue.zones = zones
	vue.bombes = bombes
	return vue


func _zone(pos: Vector2, rayon: float, reste: float) -> Dictionary:
	return {"pos": pos, "rayon": rayon, "reste": reste, "arme": 0}


func _bombe(pos: Vector2, rayon: float, reste: float) -> Dictionary:
	return {"pos": pos, "rayon": rayon, "reste": reste}


func test_une_zone_se_dessine_au_sol_pendant_son_temps_restant_et_disparait_avec_la_vue() -> void:
	_arene.afficher(_vue([_zone(Vector2(200, 100), 120.0, 3.0)]), 1.0)
	var poses: ZonesBombes2D = _arene.zones_bombes()
	verifier_egal(poses.nombre_zones(), 1)
	verifier_egal(poses.rayon_zone(0), 120.0 * Apparence.PX_PAR_UNITE, "le disque est la zone")
	verifier_egal(poses.position_zone(0), Apparence.vers_pixels(Vector2(200, 100)))
	verifier(poses.opacite_zone(0) > 0.0, "visible tant qu'il reste du temps")
	poses.avancer(1.0)
	verifier(poses.opacite_zone(0) > 0.0, "encore là à 2 s de la fin")
	poses.avancer(2.5)
	verifier_egal(poses.opacite_zone(0), 0.0, "le temps restant écoulé, plus rien")
	_arene.afficher(_vue(), 1.1)
	verifier_egal(poses.nombre_zones(), 0, "la zone disparaît avec la vue")


func test_une_zone_qui_se_termine_s_estompe_au_lieu_de_disparaitre_d_un_coup() -> void:
	_arene.afficher(_vue([_zone(Vector2.ZERO, 100.0, 0.3)]), 1.0)
	var poses: ZonesBombes2D = _arene.zones_bombes()
	var pleine: float = poses.opacite_zone(0)
	poses.avancer(0.15)
	var moitie: float = poses.opacite_zone(0)
	verifier(moitie > 0.0 and moitie < pleine, "elle s'estompe sur la fin")


func test_une_bombe_grossit_jusqu_a_son_explosion() -> void:
	var poses: ZonesBombes2D = _arene.zones_bombes()
	_arene.afficher(_vue([], [_bombe(Vector2(50, 50), 90.0, 2.0)]), 1.0)
	verifier_egal(poses.nombre_bombes(), 1)
	verifier_egal(poses.rayon_bombe(0), 90.0 * Apparence.PX_PAR_UNITE, "l'anneau est le souffle")
	var debut: float = poses.echelle_bombe_moyenne(0)
	_arene.afficher(_vue([], [_bombe(Vector2(50, 50), 90.0, 1.0)]), 1.1)
	var milieu: float = poses.echelle_bombe_moyenne(0)
	_arene.afficher(_vue([], [_bombe(Vector2(50, 50), 90.0, 0.1)]), 1.2)
	var fin: float = poses.echelle_bombe_moyenne(0)
	verifier(
		debut < milieu and milieu < fin,
		"plus grosse à chaque vue : %f %f %f" % [debut, milieu, fin]
	)
	_arene.afficher(_vue(), 1.3)
	verifier_egal(poses.nombre_bombes(), 0, "elle a explosé : plus de bombe")


func test_une_bombe_pulse_et_pulse_plus_vite_en_approchant_de_la_fin() -> void:
	var poses: ZonesBombes2D = _arene.zones_bombes()
	_arene.afficher(_vue([], [_bombe(Vector2.ZERO, 90.0, 2.0)]), 1.0)
	var vues: Array[float] = []
	for k: int in 12:
		poses.avancer(0.03)
		vues.append(poses.echelle_bombe(0))
	var monte: bool = false
	var descend: bool = false
	for k: int in range(1, vues.size()):
		monte = monte or vues[k] > vues[k - 1] + 0.0001
		descend = descend or vues[k] < vues[k - 1] - 0.0001
	verifier(monte and descend, "l'échelle bat : elle monte et redescend")


func test_une_explosion_de_bombe_est_l_explosion_du_pack() -> void:
	var impact := {
		"k": "impact",
		"t": 1,
		"de": Vector2.ZERO,
		"vers": Vector2(200, 0),
		"type_degats": Types.TypeDegats.SIEGE,
		"rayon": 90.0,
		"genre": VueArene.GENRES_ARME.find("bombe"),
	}
	verifier(_effets.ajouter(impact))
	verifier_contient(_effets.formes_vivantes(), "explosion")


func _tir_tournant(vers: Vector2, largeur: float) -> Dictionary:
	return {
		"k": "tir",
		"t": 1,
		"de": Vector2.ZERO,
		"vers": vers,
		"type_degats": Types.TypeDegats.TRANCHANT,
		"rayon": largeur,
		"genre": VueArene.GENRES_ARME.find("tournant"),
	}


func test_un_tir_tournant_dessine_un_rayon_par_branche() -> void:
	for branches: int in range(1, 9):
		_effets.vider()
		for k: int in branches:
			var bout: Vector2 = Vector2.from_angle(TAU * float(k) / float(branches)) * 400.0
			verifier(_effets.ajouter(_tir_tournant(bout, 20.0)), "rayon %d/%d" % [k, branches])
		var rayons: int = 0
		for forme: String in _effets.formes_vivantes():
			if forme == "trait_rayon":
				rayons += 1
		verifier_egal(rayons, branches, "%d branches, %d rayons" % [branches, branches])
	_effets.vider()
	_effets.ajouter(_tir_tournant(Vector2(0, -400), 20.0))
	var trajet: Array[Vector2] = _effets.trajet_de("trait_rayon")
	verifier_egal(trajet.size(), 2)
	if trajet.size() == 2:
		verifier_egal(trajet[0], Vector2.ZERO, "le rayon part de la tour")
		verifier_egal(
			trajet[1], Apparence.vers_pixels(Vector2(0, -400)), "et va au bout de la portée"
		)


func test_un_rayon_s_eteint_vite_et_ne_laisse_rien() -> void:
	_effets.ajouter(_tir_tournant(Vector2(400, 0), 20.0))
	_effets.avancer(Effets.DUREE_MAX + 0.1)
	verifier_egal(_effets.nombre_vivants(), 0)


func _impact_repoussement(ou: Vector2) -> Dictionary:
	return {
		"k": "impact",
		"t": 1,
		"de": Vector2.ZERO,
		"vers": ou,
		"type_degats": Types.TypeDegats.PERCANT,
		"rayon": 0.0,
		"statut": VueArene.STATUTS_ARME.find("repoussement"),
	}


func test_un_repoussement_dessine_un_trait_vers_l_exterieur() -> void:
	for ou: Vector2 in [Vector2(300, -200), Vector2(-250, 40), Vector2(0, 180), Vector2.ZERO]:
		_effets.vider()
		verifier(_effets.ajouter(_impact_repoussement(ou)), "repoussement en %s" % ou)
		var trajet: Array[Vector2] = _effets.trajet_de("recul")
		verifier_egal(trajet.size(), 2, "un trait de recul")
		if trajet.size() != 2:
			continue
		var depart: Vector2 = Apparence.vers_pixels(ou)
		verifier_egal(trajet[0], depart, "il part de l'ennemi")
		verifier(trajet[1].length() > depart.length(), "il s'éloigne de la tour")
		if ou != Vector2.ZERO:
			verifier_proche((trajet[1] - depart).normalized().dot(ou.normalized()), 1.0, 0.001)
