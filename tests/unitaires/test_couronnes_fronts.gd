extends CasDeTest
## Les deux formes sans projectile des attaques élémentaires (D22) : la couronne d'une aura et le
## front d'une onde. Le joueur voit des lames qui s'écartent de la tour jusqu'au rayon réel, puis
## disparaissent ; un front qui avance à la vitesse de l'onde. Planche de test : `depart`.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(100.0, 200.0)
const BLANC := Color.WHITE

var _a: AttaquesElementaires = null


func avant_chaque() -> void:
	_a = AttaquesElementaires.new()
	arbre.root.add_child(_a)


func apres_chaque() -> void:
	if is_instance_valid(_a):
		_a.free()
	_a = null


func _avancer(images: int) -> void:
	for i: int in images:
		_a.avancer(IMAGE)


func _distances(planche: String) -> Array[float]:
	var liste: Array[float] = []
	for e: Dictionary in _a.etats(planche):
		liste.append((e["position"] as Vector2).distance_to(TOUR))
	return liste


func test_la_couronne_a_ses_lames_et_atteint_le_rayon_en_sept_images() -> void:
	verifier(_a.couronne("depart", TOUR, 140.0, 6, 0.0, BLANC))
	verifier_egal(_a.etats("depart").size(), 6, "six lames")
	for d: float in _distances("depart"):
		verifier(d < 140.0 * 0.5, "elle naît près de la tour")
	_avancer(AttaquesElementaires.IMAGES_COURONNE_OUVERTURE)
	for d: float in _distances("depart"):
		verifier_proche(d, 140.0, 0.5, "au rayon réel")


func test_les_lames_de_la_couronne_sont_reparties_et_ne_depassent_jamais_le_rayon() -> void:
	_a.couronne("depart", TOUR, 140.0, 6, 0.0, BLANC)
	var angles: Dictionary = {}
	for i: int in AttaquesElementaires.IMAGES_COURONNE - 1:
		_avancer(1)
		for d: float in _distances("depart"):
			verifier(d <= 140.0 + 0.01, "jamais au-delà du rayon")
		if i == 3:
			for e: Dictionary in _a.etats("depart"):
				angles[snappedf(fposmod(((e["position"] as Vector2) - TOUR).angle(), TAU), 0.001)] = true
	verifier_egal(angles.size(), 6, "six directions distinctes")


func test_la_couronne_tourne_puis_s_efface_et_rend_le_pool() -> void:
	_a.couronne("depart", TOUR, 140.0, 6, 0.0, BLANC)
	var avant: float = (_a.etats("depart")[0]["position"] as Vector2).angle_to_point(TOUR)
	_avancer(10)
	var apres: float = (_a.etats("depart")[0]["position"] as Vector2).angle_to_point(TOUR)
	verifier(absf(avant - apres) > 0.1, "elle tourne")
	verifier(_a.opacite_max() <= AttaquesElementaires.ALPHA_MAX + 0.0001, "jamais opaque")
	_avancer(AttaquesElementaires.IMAGES_COURONNE)
	verifier_egal(_a.nombre_vivants(), 0, "plus rien")


func test_mouvement_reduit_la_couronne_ne_tourne_pas_mais_reste_visible() -> void:
	_a.mouvement_reduit = true
	_a.couronne("depart", TOUR, 140.0, 6, 0.0, BLANC)
	var avant: Vector2 = _a.etats("depart")[0]["position"]
	_avancer(AttaquesElementaires.IMAGES_COURONNE_OUVERTURE)
	var apres: Vector2 = _a.etats("depart")[0]["position"]
	verifier_proche(
		(avant - TOUR).angle(), (apres - TOUR).angle(), 0.0001, "même direction : pas de rotation"
	)
	verifier(_a.etats("depart")[0]["visible"], "les sprites restent")


func test_le_front_avance_a_la_vitesse_de_l_onde_jusqu_au_rayon() -> void:
	_a.front("depart", TOUR, 250.0, 300.0, 8, 0.0, BLANC)
	verifier_egal(_a.etats("depart").size(), 8)
	_avancer(15)
	for d: float in _distances("depart"):
		verifier_proche(d, 300.0 * 15.0 * IMAGE, 0.5, "15 images à 300 px/s")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0, "le front disparaît après son rayon")


func test_le_front_ne_depasse_jamais_le_rayon_et_s_efface_a_la_fin() -> void:
	_a.front("depart", TOUR, 250.0, 300.0, 8, 0.0, BLANC)
	var fin: int = int(250.0 / 300.0 / IMAGE)
	_avancer(fin - 1)
	for d: float in _distances("depart"):
		verifier(d <= 250.0 + 0.01, "jamais au-delà du rayon")
	verifier(_a.opacite_max() < AttaquesElementaires.ALPHA_MAX * 0.8, "il s'efface sur la fin")
