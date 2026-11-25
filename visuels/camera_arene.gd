class_name CameraArene
extends Camera3D
## Caméra fixe en plongée inclinée au-dessus de la tour. Seul le zoom varie, entre deux bornes.
## À `ZOOM_MAX`, tout le cercle d'apparition tient dans la zone libre de l'écran (celle qui reste
## entre le HUD et la boutique) et la tour en occupe le centre ; zoomer ne fait que rapprocher.

const RAYON_APPARITION: float = 1300.0
const INCLINAISON_DEG: float = 55.0
const CHAMP_VERTICAL_DEG: float = 45.0
## Marge autour du cercle, pour qu'un ennemi qui apparaît ne soit pas collé au bord.
const MARGE: float = 1.05
const ZOOM_MIN: float = 0.35
const ZOOM_MAX: float = 1.0
const ITERATIONS_CADRAGE: int = 40

var zoom: float = ZOOM_MAX

## Zone libre en fractions de la fenêtre (0 à 1) et rapport largeur/hauteur de la fenêtre. Par
## défaut : toute la fenêtre, en 16/9.
var _libre: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
var _aspect: float = 16.0 / 9.0
var _distance_ajustee: float = 0.0


## Réglée dans `_init` : le lanceur de tests n'appelle pas `_ready`.
func _init() -> void:
	fov = CHAMP_VERTICAL_DEG
	keep_aspect = Camera3D.KEEP_HEIGHT
	rotation_degrees = Vector3(-INCLINAISON_DEG, 0.0, 0.0)
	_recadrer()
	_actualiser()


## Centre la tour dans `libre` (rectangle en pixels de la fenêtre de taille `taille`) et ajuste
## le recul pour que le cercle d'apparition y tienne. Appelée à chaque changement de mise en page.
func cadrer(libre: Rect2, taille: Vector2) -> void:
	if taille.x <= 0.0 or taille.y <= 0.0 or libre.size.x <= 0.0 or libre.size.y <= 0.0:
		return
	_libre = Rect2(libre.position / taille, libre.size / taille)
	_aspect = taille.x / taille.y
	_recadrer()
	_actualiser()


## `delta` positif éloigne, négatif rapproche ; le résultat reste dans les bornes.
func zoomer(delta: float) -> void:
	zoom = clampf(zoom + delta, ZOOM_MIN, ZOOM_MAX)
	_actualiser()


## Distance entre la caméra et la tour.
func distance() -> float:
	return _distance_ajustee * zoom


## Projette un point du monde dans le repère de l'écran, de -1 à 1 (y vers le haut), tel que la
## caméra le verra dans une fenêtre de rapport `aspect`. Sert aux tests de mise en page.
func projeter(point: Vector3, aspect: float) -> Vector2:
	return _projeter(point, distance(), aspect)


## Zone libre en repère d'écran (-1 à 1) : centre et demi-étendues.
func _zone_ecran() -> Rect2:
	var x_min := -1.0 + 2.0 * _libre.position.x
	var x_max := -1.0 + 2.0 * _libre.end.x
	var y_max := 1.0 - 2.0 * _libre.position.y
	var y_min := 1.0 - 2.0 * _libre.end.y
	return Rect2(x_min, y_min, x_max - x_min, y_max - y_min)


func _base() -> Basis:
	return Basis.from_euler(Vector3(-deg_to_rad(INCLINAISON_DEG), 0.0, 0.0))


## Position de la caméra à la distance `d`, décalée pour que la tour tombe au centre de la zone.
func _position_pour(d: float, aspect: float) -> Vector3:
	var base := _base()
	var angle := deg_to_rad(INCLINAISON_DEG)
	var demi := tan(deg_to_rad(CHAMP_VERTICAL_DEG) * 0.5)
	var zone := _zone_ecran()
	var centre := zone.get_center()
	var axe := Vector3(0.0, sin(angle), cos(angle)) * d
	return axe - base.y * (centre.y * d * demi) - base.x * (centre.x * d * demi * aspect)


func _projeter(point: Vector3, d: float, aspect: float) -> Vector2:
	var base := _base()
	var v := point - _position_pour(d, aspect)
	var profondeur := -v.dot(base.z)
	if profondeur <= 0.001:
		return Vector2(INF, INF)
	var demi := tan(deg_to_rad(CHAMP_VERTICAL_DEG) * 0.5)
	return Vector2(
		v.dot(base.x) / (profondeur * demi * aspect), v.dot(base.y) / (profondeur * demi)
	)


## Plus petite distance pour laquelle le cercle d'apparition tient dans la zone libre.
func _recadrer() -> void:
	var rayon: float = RAYON_APPARITION * Apparence.ECHELLE * MARGE
	var bas := rayon
	var haut := rayon * 200.0
	for _i: int in ITERATIONS_CADRAGE:
		var milieu := (bas + haut) * 0.5
		if _cercle_tient(rayon, milieu):
			haut = milieu
		else:
			bas = milieu
	_distance_ajustee = haut


func _cercle_tient(rayon: float, d: float) -> bool:
	var zone := _zone_ecran()
	for i: int in 64:
		var angle := TAU * float(i) / 64.0
		var p := _projeter(Vector3(cos(angle) * rayon, 0.0, sin(angle) * rayon), d, _aspect)
		if not is_finite(p.x) or not zone.has_point(p):
			return false
	return true


func _actualiser() -> void:
	position = _position_pour(distance(), _aspect)
