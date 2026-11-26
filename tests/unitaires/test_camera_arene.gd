extends CasDeTest
## Ce que la joueuse obtient avec la caméra 2D : la tour au centre de la zone libre entre le HUD
## et la boutique, tout le cercle d'apparition visible au plus loin, un zoom (molette et
## pincement) qui ne sort jamais de ses bornes.

const RESOLUTIONS: Array[Vector2] = [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080)]
const TOLERANCE_PX: float = 0.01

## Action → touches physiques (flèche et lettre WASD : Z Q S D en AZERTY suivent la position).
const ACTIONS_DEPLACEMENT: Array[String] = [
	"camera_gauche", "camera_droite", "camera_haut", "camera_bas"
]
const TOUCHES: Dictionary = {
	"camera_gauche": [KEY_LEFT, KEY_A],
	"camera_droite": [KEY_RIGHT, KEY_D],
	"camera_haut": [KEY_UP, KEY_W],
	"camera_bas": [KEY_DOWN, KEY_S],
}
const SENS: Dictionary = {
	"camera_gauche": Vector2.LEFT,
	"camera_droite": Vector2.RIGHT,
	"camera_haut": Vector2.UP,
	"camera_bas": Vector2.DOWN,
}

var _camera: CameraArene = null


func avant_chaque() -> void:
	_camera = CameraArene.new()


func apres_chaque() -> void:
	for action: String in ACTIONS_DEPLACEMENT:
		Input.action_release(action)
	_camera.free()


func _libre(zone: Vector2) -> Rect2:
	return Rect2(0.0, zone.y * 0.1, zone.x, zone.y * 0.65)


func test_le_zoom_reste_dans_ses_bornes_a_la_molette() -> void:
	var depart: float = _camera.niveau
	_camera.zoomer(-1000.0)
	var proche: float = _camera.niveau
	_camera.zoomer(1000.0)
	var loin: float = _camera.niveau
	verifier_proche(proche, CameraArene.ZOOM_MIN, 0.0001)
	verifier_proche(loin, CameraArene.ZOOM_MAX, 0.0001)
	verifier(proche < loin and proche > 0.0)
	verifier(depart >= proche and depart <= loin)
	for pas: float in [-0.05, 0.05, -3.0, 0.2, 1e9, -1e9]:
		_camera.zoomer(pas)
		verifier(
			_camera.niveau >= CameraArene.ZOOM_MIN and _camera.niveau <= CameraArene.ZOOM_MAX,
			"pas %f : niveau %f" % [pas, _camera.niveau]
		)


func test_le_zoom_reste_dans_ses_bornes_au_pincement() -> void:
	for facteur: float in [0.01, 0.5, 0.99, 1.0, 1.5, 100.0, 1e9, 0.0, -2.0]:
		_camera.zoomer_facteur(facteur)
		verifier(
			_camera.niveau >= CameraArene.ZOOM_MIN and _camera.niveau <= CameraArene.ZOOM_MAX,
			"facteur %f : niveau %f" % [facteur, _camera.niveau]
		)
	# Écarter les doigts rapproche : le niveau baisse.
	_camera.zoomer(1000.0)
	_camera.zoomer_facteur(2.0)
	verifier(_camera.niveau < CameraArene.ZOOM_MAX, "écarter les doigts rapproche")
	var apres: float = _camera.niveau
	_camera.zoomer_facteur(0.5)
	verifier(_camera.niveau > apres, "pincer éloigne")


func test_la_tour_est_au_centre_de_la_zone_libre_a_chaque_resolution_et_a_chaque_zoom() -> void:
	for zone: Vector2 in RESOLUTIONS:
		_camera.cadrer(_libre(zone), zone)
		for niveau: float in [CameraArene.ZOOM_MIN, 0.5, CameraArene.ZOOM_MAX]:
			_camera.zoomer(niveau - _camera.niveau)
			var centre: Vector2 = _camera.projeter(Vector2.ZERO)
			var attendu: Vector2 = _libre(zone).get_center()
			verifier_proche(centre.x, attendu.x, TOLERANCE_PX, "x à %s, niveau %f" % [zone, niveau])
			verifier_proche(centre.y, attendu.y, TOLERANCE_PX, "y à %s, niveau %f" % [zone, niveau])


func test_tout_le_cercle_d_apparition_tient_dans_la_zone_libre_au_plus_loin() -> void:
	for zone: Vector2 in RESOLUTIONS:
		var libre := _libre(zone)
		_camera.cadrer(libre, zone)
		_camera.zoomer(1000.0)
		for i: int in 64:
			var angle: float = TAU * float(i) / 64.0
			var point := Vector2.from_angle(angle) * CameraArene.RAYON_APPARITION
			var px: Vector2 = _camera.projeter(Apparence.vers_pixels(point))
			verifier(libre.grow(0.5).has_point(px), "point %d hors cadre à %s : %s" % [i, zone, px])


func test_une_position_de_la_vue_tombe_au_bon_endroit_de_l_ecran_au_centre_comme_au_bord() -> void:
	var zone := RESOLUTIONS[0]
	var libre := _libre(zone)
	_camera.cadrer(libre, zone)
	_camera.zoomer(1000.0)
	var echelle: float = _camera.zoom.x
	for p: Vector2 in [Vector2.ZERO, Vector2(300, 0), Vector2(0, -300), Vector2(1300, 0)]:
		var attendu: Vector2 = libre.get_center() + Apparence.vers_pixels(p) * echelle
		var recu: Vector2 = _camera.projeter(Apparence.vers_pixels(p))
		verifier_proche(recu.x, attendu.x, TOLERANCE_PX, "x de %s" % p)
		verifier_proche(recu.y, attendu.y, TOLERANCE_PX, "y de %s" % p)
	# Zoomer grossit : un même point s'éloigne du centre.
	var point := Apparence.vers_pixels(Vector2(300, 0))
	var loin: float = _camera.projeter(point).x - libre.get_center().x
	_camera.zoomer(-0.5)
	var pres: float = _camera.projeter(point).x - libre.get_center().x
	verifier(pres > loin, "le zoom rapproche")


func test_une_zone_inutilisable_est_ignoree() -> void:
	var zone := RESOLUTIONS[0]
	_camera.cadrer(_libre(zone), zone)
	var avant: Vector2 = _camera.projeter(Vector2(100, 100))
	_camera.cadrer(Rect2(0, 0, 0, 0), zone)
	_camera.cadrer(_libre(zone), Vector2.ZERO)
	verifier_egal(_camera.projeter(Vector2(100, 100)), avant)


func test_le_zoom_maximal_montre_deux_fois_le_cercle_d_apparition() -> void:
	for zone: Vector2 in RESOLUTIONS:
		_camera.cadrer(_libre(zone), zone)
		_camera.zoomer(1000.0)
		var cadre: Rect2 = _camera.cadre_visible()
		var plus_petit: float = minf(cadre.size.x, cadre.size.y)
		verifier(
			plus_petit * 0.5 >= 2.0 * CameraArene.RAYON_APPARITION,
			"deux cercles à %s : demi-cadre %.0f" % [zone, plus_petit * 0.5]
		)
		_camera.zoomer(-1000.0 + 0.0)
		_camera.zoomer(CameraArene.ZOOM_DEFAUT - _camera.niveau)
		cadre = _camera.cadre_visible()
		verifier(
			minf(cadre.size.x, cadre.size.y) * 0.5 >= CameraArene.RAYON_APPARITION,
			"le cercle entier au zoom par défaut à %s" % zone
		)


func test_le_zoom_de_depart_montre_le_cercle_entier() -> void:
	verifier_proche(_camera.niveau, CameraArene.ZOOM_DEFAUT, 0.0001)
	verifier_egal(CameraArene.ZOOM_DEFAUT, 1.0)
	verifier_egal(CameraArene.ZOOM_MAX, 2.0)
	verifier_egal(CameraArene.ZOOM_MIN, 0.25)


func test_le_decalage_est_limite_a_deux_rayons_dans_les_huit_directions() -> void:
	var limite: float = 2.0 * CameraArene.RAYON_APPARITION
	verifier_proche(CameraArene.DEPLACEMENT_MAX_UNITES, limite, 0.001)
	for k: int in 8:
		_camera.recentrer()
		_camera.deplacer(Vector2.from_angle(PI * 0.25 * k) * 100000.0)
		verifier(
			_camera.decalage_unites.length() <= limite + 0.01,
			"direction %d : %.1f" % [k, _camera.decalage_unites.length()]
		)
		verifier_proche(_camera.decalage_unites.length(), limite, 0.01, "direction %d atteinte" % k)


func test_deplacer_ignore_les_valeurs_non_finies() -> void:
	_camera.deplacer(Vector2(100.0, 50.0))
	var avant: Vector2 = _camera.decalage_unites
	for mauvais: Vector2 in [Vector2(NAN, 0.0), Vector2(0.0, INF), Vector2(-INF, NAN)]:
		_camera.deplacer(mauvais)
		verifier_egal(_camera.decalage_unites, avant, "%s ignoré" % mauvais)
	_camera.centrer_sur(Vector2(NAN, 3.0))
	verifier_egal(_camera.decalage_unites, avant, "centrer_sur NaN ignoré")


func test_les_fleches_et_wasd_deplacent_la_vue() -> void:
	for action: String in ACTIONS_DEPLACEMENT:
		_camera.recentrer()
		Input.action_press(action)
		_camera.avancer(1.0)
		Input.action_release(action)
		var attendu: Vector2 = SENS[action] * CameraArene.VITESSE_BASE
		verifier_proche(_camera.decalage_unites.x, attendu.x, 0.01, "x de %s" % action)
		verifier_proche(_camera.decalage_unites.y, attendu.y, 0.01, "y de %s" % action)
		for touche: int in TOUCHES[action]:
			verifier(_a_la_touche(action, touche), "%s sans la touche %d" % [action, touche])


func _a_la_touche(action: String, touche: int) -> bool:
	for evenement: InputEvent in InputMap.action_get_events(action):
		var cle := evenement as InputEventKey
		if cle != null and cle.physical_keycode == touche:
			return true
	return false


func test_la_diagonale_n_est_pas_plus_rapide() -> void:
	Input.action_press("camera_droite")
	Input.action_press("camera_bas")
	_camera.avancer(1.0)
	Input.action_release("camera_droite")
	Input.action_release("camera_bas")
	verifier_proche(_camera.decalage_unites.length(), CameraArene.VITESSE_BASE, 1.0)


func test_la_vitesse_relative_multiplie_la_vitesse() -> void:
	_camera.vitesse_relative = 2.0
	Input.action_press("camera_droite")
	_camera.avancer(0.5)
	Input.action_release("camera_droite")
	verifier_proche(_camera.decalage_unites.x, CameraArene.VITESSE_BASE, 0.01)


func test_espace_recentre_sur_la_tour_et_garde_le_zoom() -> void:
	var zone := RESOLUTIONS[0]
	_camera.cadrer(_libre(zone), zone)
	_camera.zoomer(-0.5)
	_camera.deplacer(Vector2(700.0, -400.0))
	var niveau: float = _camera.niveau
	_camera.recentrer()
	verifier_egal(_camera.decalage_unites, Vector2.ZERO)
	verifier_proche(_camera.niveau, niveau, 0.0001, "le zoom reste")
	var centre: Vector2 = _camera.projeter(Vector2.ZERO)
	verifier_proche(centre.x, _libre(zone).get_center().x, TOLERANCE_PX)
	verifier_proche(centre.y, _libre(zone).get_center().y, TOLERANCE_PX)


func test_centrer_sur_place_le_point_au_centre_de_la_zone_libre_et_borne_les_points_trop_loin(
) -> void:
	for zone: Vector2 in RESOLUTIONS:
		var libre := _libre(zone)
		_camera.cadrer(libre, zone)
		var point := Vector2(500.0, -300.0)
		_camera.centrer_sur(point)
		var px: Vector2 = _camera.projeter(Apparence.vers_pixels(point))
		verifier_proche(px.x, libre.get_center().x, TOLERANCE_PX, "x à %s" % zone)
		verifier_proche(px.y, libre.get_center().y, TOLERANCE_PX, "y à %s" % zone)
		_camera.centrer_sur(Vector2(1.0e7, 0.0))
		verifier_proche(
			_camera.decalage_unites.length(), CameraArene.DEPLACEMENT_MAX_UNITES, 0.01, "borné"
		)


func test_le_cadre_visible_suit_le_zoom_et_le_decalage() -> void:
	var zone := RESOLUTIONS[0]
	_camera.cadrer(_libre(zone), zone)
	var cadre: Rect2 = _camera.cadre_visible()
	verifier_proche(cadre.get_center().x, 0.0, 0.01)
	verifier_proche(cadre.get_center().y, 0.0, 0.01)
	_camera.zoomer(-0.5)
	var rapproche: Rect2 = _camera.cadre_visible()
	verifier_proche(rapproche.size.x, cadre.size.x * 0.5, 0.01, "zoom ×2 : largeur ÷ 2")
	verifier_proche(rapproche.size.y, cadre.size.y * 0.5, 0.01, "zoom ×2 : hauteur ÷ 2")
	_camera.deplacer(Vector2(300.0, -120.0))
	var decale: Rect2 = _camera.cadre_visible()
	verifier_proche(decale.get_center().x, 300.0, 0.01, "centre = décalage (x)")
	verifier_proche(decale.get_center().y, -120.0, 0.01, "centre = décalage (y)")
	verifier_proche(decale.size.x, rapproche.size.x, 0.01, "le décalage ne change pas la taille")
