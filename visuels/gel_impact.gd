class_name GelImpact
extends RefCounted
## Le gel d'impact (hit-stop) des ennemis touchés par un coup fort, purement visuel : pendant
## `DUREE_GEL` l'ennemi garde sa position et son image d'animation affichées, puis il rejoint sa
## position interpolée en `IMAGES_REPRISE` images. Ni la simulation à 20 Hz, ni le réseau, ni
## `Engine.time_scale` n'y participent : seul l'affichage retient l'ennemi. L'état suit l'id de
## l'ennemi, car l'arène réattribue les sprites à chaque image. Position et image sont relevées au
## premier affichage du gel, qui a lieu dans l'image même du coup.

const IMAGE: float = 1.0 / 60.0
## Cinq images à 60 i/s, soit environ 0,083 s (palier des coups forts : 100 à 150 ms au plus).
const DUREE_GEL: float = 5.0 * IMAGE
## La reprise est linéaire : trois pas égaux, donc jamais plus d'un tiers de l'écart d'un coup.
const IMAGES_REPRISE: int = 3
const DUREE_REPRISE: float = IMAGES_REPRISE * IMAGE
const EPSILON: float = 0.000001

## Par id d'ennemi : `{reste, reprise, pos, image, a_pos}`. `reprise` vaut -1 pendant le gel ; à
## sa fin elle part d'une image (celle où le gel s'achève compte déjà) jusqu'à `DUREE_REPRISE`.
var _etats: Dictionary = {}


## Retient l'ennemi `id`. Un ennemi déjà retenu ne l'est pas deux fois : les gels ne s'additionnent
## pas.
func geler(id: int) -> void:
	if _etats.has(id):
		return
	_etats[id] = {"reste": DUREE_GEL, "reprise": -1.0, "pos": Vector2.ZERO, "image": -1}


## Fait avancer le gel de `id` de `delta` secondes et rend la part de `delta` qui n'est pas passée
## à l'arrêt (`delta` entier pour un ennemi non retenu ou en reprise).
func consommer(id: int, delta: float) -> float:
	if not _etats.has(id):
		return delta
	var etat: Dictionary = _etats[id]
	var libre: float = delta
	if float(etat["reprise"]) < 0.0:
		var passe: float = minf(float(etat["reste"]), delta)
		etat["reste"] = float(etat["reste"]) - passe
		libre = delta - passe
		if float(etat["reste"]) > EPSILON:
			return 0.0
		etat["reprise"] = IMAGE + libre
	else:
		etat["reprise"] = float(etat["reprise"]) + delta
	if float(etat["reprise"]) >= DUREE_REPRISE - EPSILON:
		_etats.erase(id)
	return libre


## Vrai tant que `id` est retenu (la reprise n'est plus un gel).
func est_gele(id: int) -> bool:
	return _etats.has(id) and float(_etats[id]["reprise"]) < 0.0


## Position à afficher (pixels, sans recul) de `id`, dont la position interpolée est `pos_px`.
func position_affichee(id: int, pos_px: Vector2) -> Vector2:
	if not _etats.has(id):
		return pos_px
	var etat: Dictionary = _etats[id]
	if not bool(etat.get("a_pos", false)):
		etat["a_pos"] = true
		etat["pos"] = pos_px
	var tenue: Vector2 = etat["pos"]
	var reprise: float = float(etat["reprise"])
	if reprise < 0.0:
		return tenue
	return tenue.lerp(pos_px, clampf(reprise / DUREE_REPRISE, 0.0, 1.0))


## Image d'animation à afficher pour `id` : celle du premier affichage pendant le gel, `image`
## ensuite.
func image_animation(id: int, image: int) -> int:
	if not est_gele(id):
		return image
	var etat: Dictionary = _etats[id]
	if int(etat["image"]) < 0:
		etat["image"] = image
	return int(etat["image"])


func nombre() -> int:
	return _etats.size()


func retirer(id: int) -> void:
	_etats.erase(id)


func vider() -> void:
	_etats.clear()
