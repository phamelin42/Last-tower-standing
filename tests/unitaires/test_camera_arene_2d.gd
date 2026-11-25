extends CasDeTest
## Ce que la joueuse obtient avec la caméra 2D : la tour au centre de la zone libre entre le HUD
## et la boutique, tout le cercle d'apparition visible au plus loin, un zoom (molette et
## pincement) qui ne sort jamais de ses bornes.

const RESOLUTIONS: Array[Vector2] = [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080)]
const TOLERANCE_PX: float = 0.01

var _camera: CameraArene2D = null


func avant_chaque() -> void:
	_camera = CameraArene2D.new()


func apres_chaque() -> void:
	_camera.free()


func _libre(zone: Vector2) -> Rect2:
	return Rect2(0.0, zone.y * 0.1, zone.x, zone.y * 0.65)


func test_le_zoom_reste_dans_ses_bornes_a_la_molette() -> void:
	var depart: float = _camera.niveau
	_camera.zoomer(-1000.0)
	var proche: float = _camera.niveau
	_camera.zoomer(1000.0)
	var loin: float = _camera.niveau
	verifier_proche(proche, CameraArene2D.ZOOM_MIN, 0.0001)
	verifier_proche(loin, CameraArene2D.ZOOM_MAX, 0.0001)
	verifier(proche < loin and proche > 0.0)
	verifier(depart >= proche and depart <= loin)
	for pas: float in [-0.05, 0.05, -3.0, 0.2, 1e9, -1e9]:
		_camera.zoomer(pas)
		verifier(
			_camera.niveau >= CameraArene2D.ZOOM_MIN and _camera.niveau <= CameraArene2D.ZOOM_MAX,
			"pas %f : niveau %f" % [pas, _camera.niveau]
		)


func test_le_zoom_reste_dans_ses_bornes_au_pincement() -> void:
	for facteur: float in [0.01, 0.5, 0.99, 1.0, 1.5, 100.0, 1e9, 0.0, -2.0]:
		_camera.zoomer_facteur(facteur)
		verifier(
			_camera.niveau >= CameraArene2D.ZOOM_MIN and _camera.niveau <= CameraArene2D.ZOOM_MAX,
			"facteur %f : niveau %f" % [facteur, _camera.niveau]
		)
	# Écarter les doigts rapproche : le niveau baisse.
	_camera.zoomer(1000.0)
	_camera.zoomer_facteur(2.0)
	verifier(_camera.niveau < CameraArene2D.ZOOM_MAX, "écarter les doigts rapproche")
	var apres: float = _camera.niveau
	_camera.zoomer_facteur(0.5)
	verifier(_camera.niveau > apres, "pincer éloigne")


func test_la_tour_est_au_centre_de_la_zone_libre_a_chaque_resolution_et_a_chaque_zoom() -> void:
	for zone: Vector2 in RESOLUTIONS:
		_camera.cadrer(_libre(zone), zone)
		for niveau: float in [CameraArene2D.ZOOM_MIN, 0.5, CameraArene2D.ZOOM_MAX]:
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
			var point := Vector2.from_angle(angle) * CameraArene2D.RAYON_APPARITION
			var px: Vector2 = _camera.projeter(Apparence2D.vers_pixels(point))
			verifier(libre.grow(0.5).has_point(px), "point %d hors cadre à %s : %s" % [i, zone, px])


func test_une_position_de_la_vue_tombe_au_bon_endroit_de_l_ecran_au_centre_comme_au_bord() -> void:
	var zone := RESOLUTIONS[0]
	var libre := _libre(zone)
	_camera.cadrer(libre, zone)
	_camera.zoomer(1000.0)
	var echelle: float = _camera.zoom.x
	for p: Vector2 in [Vector2.ZERO, Vector2(300, 0), Vector2(0, -300), Vector2(1300, 0)]:
		var attendu: Vector2 = libre.get_center() + Apparence2D.vers_pixels(p) * echelle
		var recu: Vector2 = _camera.projeter(Apparence2D.vers_pixels(p))
		verifier_proche(recu.x, attendu.x, TOLERANCE_PX, "x de %s" % p)
		verifier_proche(recu.y, attendu.y, TOLERANCE_PX, "y de %s" % p)
	# Zoomer grossit : un même point s'éloigne du centre.
	var point := Apparence2D.vers_pixels(Vector2(300, 0))
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
