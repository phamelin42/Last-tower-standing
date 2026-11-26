class_name CameraArene
extends Camera2D
## Caméra de l'arène 2D. Au niveau `ZOOM_DEFAUT`, tout le cercle d'apparition tient dans la zone
## libre de l'écran (celle qui reste entre le HUD et la boutique) et la tour en occupe le centre ;
## zoomer rapproche (jusqu'à `ZOOM_MIN`) ou éloigne (jusqu'à `ZOOM_MAX` : deux fois le cercle), à
## la molette ou au pincement. La vue se déplace aux flèches et à WASD, d'au plus deux rayons de
## la tour ; le recentrage sur la tour se refait à chaque changement de mise en page (`cadrer`).

const RAYON_APPARITION: float = 1300.0
## Marge autour du cercle, pour qu'un ennemi qui apparaît ne soit pas collé au bord.
const MARGE: float = 1.05
## 1 = tout le cercle visible ; 0,25 = quatre fois plus près ; 2 = deux fois le cercle.
const ZOOM_MIN: float = 0.25
const ZOOM_DEFAUT: float = 1.0
const ZOOM_MAX: float = 2.0
## Plus grand écart du centre de la vue à la tour : deux rayons d'apparition, en unités de jeu.
const DEPLACEMENT_MAX_UNITES: float = 2.0 * RAYON_APPARITION
## Vitesse de déplacement de la vue, en unités de jeu par seconde, avant `vitesse_relative`.
const VITESSE_BASE: float = 900.0

var niveau: float = ZOOM_DEFAUT
## Centre de la vue par rapport à la tour, en unités de jeu.
var decalage_unites: Vector2 = Vector2.ZERO
## Réglage de la joueuse : multiplie `VITESSE_BASE` (l'Interface le câble).
var vitesse_relative: float = 1.0

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


## Déplace le centre de la vue de `delta_unites` (unités de jeu), sans sortir de deux rayons de la
## tour. Une valeur non finie est ignorée.
func deplacer(delta_unites: Vector2) -> void:
	if not delta_unites.is_finite():
		return
	decalage_unites = (decalage_unites + delta_unites).limit_length(DEPLACEMENT_MAX_UNITES)
	_actualiser()


## Place `point_unites` (unités de jeu, repère de la tour) au centre de la zone libre ; un point
## trop loin est ramené à deux rayons dans sa direction.
func centrer_sur(point_unites: Vector2) -> void:
	if not point_unites.is_finite():
		return
	decalage_unites = point_unites.limit_length(DEPLACEMENT_MAX_UNITES)
	_actualiser()


## Remet la tour au centre de la zone libre : le décalage retombe à zéro, le zoom reste.
func recentrer() -> void:
	decalage_unites = Vector2.ZERO
	_actualiser()


## La zone libre telle que la caméra la voit, en unités de jeu (repère de la tour).
func cadre_visible() -> Rect2:
	var taille_unites: Vector2 = _libre.size / zoom.x / Apparence.PX_PAR_UNITE
	return Rect2(decalage_unites - taille_unites * 0.5, taille_unites)


## Fait avancer la vue selon les flèches et WASD tenues pendant `delta` secondes. Le vecteur
## d'entrée est de longueur 1 au plus : la diagonale n'est pas plus rapide.
func avancer(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var sens: Vector2 = Input.get_vector(
		"camera_gauche", "camera_droite", "camera_haut", "camera_bas"
	)
	if sens != Vector2.ZERO:
		deplacer(sens * VITESSE_BASE * vitesse_relative * delta)


func _process(delta: float) -> void:
	avancer(delta)


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
	position = (
		(_taille * 0.5 - _libre.get_center()) / grossissement
		+ Apparence.vers_pixels(decalage_unites)
	)
