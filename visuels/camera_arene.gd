class_name CameraArene
extends Camera3D
## Caméra fixe en plongée inclinée au-dessus de la tour. Seul le zoom varie, entre deux bornes.
## À `ZOOM_MAX`, tout le cercle d'apparition tient dans l'image ; zoomer ne fait que rapprocher.

const RAYON_APPARITION: float = 1300.0
const INCLINAISON_DEG: float = 55.0
const CHAMP_VERTICAL_DEG: float = 45.0
## Marge autour du cercle, pour qu'un ennemi qui apparaît ne soit pas collé au bord.
const MARGE: float = 1.15
const ZOOM_MIN: float = 0.35
const ZOOM_MAX: float = 1.0

var zoom: float = ZOOM_MAX


## Réglée dans `_init` : le lanceur de tests n'appelle pas `_ready`.
func _init() -> void:
	fov = CHAMP_VERTICAL_DEG
	keep_aspect = Camera3D.KEEP_HEIGHT
	rotation_degrees = Vector3(-INCLINAISON_DEG, 0.0, 0.0)
	_actualiser()


## `delta` positif éloigne, négatif rapproche ; le résultat reste dans les bornes.
func zoomer(delta: float) -> void:
	zoom = clampf(zoom + delta, ZOOM_MIN, ZOOM_MAX)
	_actualiser()


## Distance entre la caméra et la tour.
func distance() -> float:
	return _distance_cadrage() * zoom


func _distance_cadrage() -> float:
	var rayon: float = RAYON_APPARITION * Apparence.ECHELLE * MARGE
	return rayon / sin(deg_to_rad(CHAMP_VERTICAL_DEG) * 0.5)


func _actualiser() -> void:
	var angle: float = deg_to_rad(INCLINAISON_DEG)
	position = Vector3(0.0, sin(angle), cos(angle)) * distance()
