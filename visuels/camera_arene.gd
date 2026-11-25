class_name CameraArene
extends Camera2D
## Caméra de l'arène 2D. Au niveau `ZOOM_MAX`, tout le cercle d'apparition tient dans la zone libre
## de l'écran (celle qui reste entre le HUD et la boutique) et la tour en occupe le centre ;
## zoomer rapproche, entre deux bornes, à la molette ou au pincement. Le recentrage sur la tour se
## refait à chaque changement de mise en page (`cadrer`).

const RAYON_APPARITION: float = 1300.0
## Marge autour du cercle, pour qu'un ennemi qui apparaît ne soit pas collé au bord.
const MARGE: float = 1.05
## 1 = tout le cercle visible ; 0,25 = quatre fois plus près.
const ZOOM_MIN: float = 0.25
const ZOOM_MAX: float = 1.0

var niveau: float = ZOOM_MAX

var _libre: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
var _taille: Vector2 = Vector2(1280.0, 720.0)


## Réglée dans `_init` : une caméra doit être cadrée dès sa création, `_ready` ou non.
func _init() -> void:
	position_smoothing_enabled = false
	_actualiser()


## Centre la tour dans `libre` (rectangle en pixels de la fenêtre de taille `taille`) et ajuste
## le grossissement pour que le cercle d'apparition y tienne au plus loin.
func cadrer(libre: Rect2, taille: Vector2) -> void:
	if taille.x <= 0.0 or taille.y <= 0.0 or libre.size.x <= 0.0 or libre.size.y <= 0.0:
		return
	_libre = libre
	_taille = taille
	_actualiser()


## `delta` positif éloigne, négatif rapproche ; le résultat reste dans les bornes.
func zoomer(delta: float) -> void:
	if not is_finite(delta):
		return
	niveau = clampf(niveau + delta, ZOOM_MIN, ZOOM_MAX)
	_actualiser()


## Pincement : un facteur supérieur à 1 (doigts qui s'écartent) rapproche. Un facteur nul,
## négatif ou infini est ignoré.
func zoomer_facteur(facteur: float) -> void:
	if not is_finite(facteur) or facteur <= 0.0:
		return
	niveau = clampf(niveau / facteur, ZOOM_MIN, ZOOM_MAX)
	_actualiser()


## Remet la tour au centre de la zone libre sans toucher au zoom.
func recentrer() -> void:
	_actualiser()


## Où un point du monde (en pixels du monde) tombe à l'écran, en pixels de la fenêtre.
func projeter(point: Vector2) -> Vector2:
	return (point - position) * zoom + _taille * 0.5


## Grossissement à `niveau` 1 : le cercle d'apparition, marge comprise, tient dans la zone libre.
func _grossissement_loin() -> float:
	var rayon: float = Apparence.vers_pixels(Vector2(RAYON_APPARITION, 0.0)).x * MARGE
	return minf(_libre.size.x, _libre.size.y) / (2.0 * rayon)


func _actualiser() -> void:
	var grossissement: float = _grossissement_loin() / niveau
	zoom = Vector2(grossissement, grossissement)
	# La tour (origine du monde) doit tomber au centre de la zone libre : l'écran est centré sur
	# la position de la caméra.
	position = (_taille * 0.5 - _libre.get_center()) / grossissement
