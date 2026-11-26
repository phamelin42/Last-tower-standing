class_name ReactionsCoups
extends RefCounted
## La réaction visuelle d'un ennemi touché : il s'éclaircit un instant et recule d'un cheveu à
## l'opposé de la tour, puis revient. Purement visuel : la position simulée ne change pas et le
## temps de jeu non plus. L'état suit l'identifiant de l'ennemi (`ids` de la vue), pas son sprite,
## car l'arène réattribue les sprites à chaque image.
## Positions et rayons en unités de jeu, décalages en pixels d'écran.

const IMAGE: float = 1.0 / 60.0
## Distance de touche d'un coup simple : l'ennemi affiché le plus proche, s'il est à moins de ça.
const RAYON_TOUCHE_PX: float = 40.0
## Une zone fait réagir ceux de son rayon, mais jamais plus de ce nombre.
const MAX_ZONE: int = 12
const DUREE_FLASH: float = 3.0 * IMAGE
## Au plus trois flashs par seconde pour un même ennemi (WCAG 2.3.1) : un peu plus d'un tiers de
## seconde, pour que quatre départs ne tiennent jamais dans la même seconde.
const INTERVALLE_FLASH: float = 0.34
## Couleur de l'ennemi multipliée par ce facteur pendant le flash : elle s'éclaircit vers le blanc.
const FACTEUR_FLASH: float = 2.0
const RECUL_PX: float = 4.0
const DUREE_RECUL_ALLER: float = 2.0 * IMAGE
const DUREE_RECUL_RETOUR: float = 6.0 * IMAGE

## Par identifiant d'ennemi : `{age: float, sens: Vector2}`, `sens` unitaire à l'opposé de la tour.
var _suivis: Dictionary = {}


## Fait réagir les ennemis touchés par un impact en `ou` (rayon `rayon`, 0 pour un coup simple).
## `ids` et `positions` sont ceux de l'échantillon affiché ; `tour` est la tour, dont on recule.
## Rend le nombre d'ennemis qui ont réagi.
func toucher(
	ou: Vector2,
	rayon: float,
	ids: PackedInt32Array,
	positions: PackedVector2Array,
	tour: Vector2 = Vector2.ZERO
) -> int:
	var portee: float = RAYON_TOUCHE_PX / Apparence.PX_PAR_UNITE
	var zone: bool = rayon > 0.0
	if zone:
		portee = rayon
	var portee_carre: float = portee * portee
	var candidats: Array[Vector2] = []
	for i: int in mini(ids.size(), positions.size()):
		var d: float = positions[i].distance_squared_to(ou)
		if d <= portee_carre:
			candidats.append(Vector2(d, i))
	if candidats.is_empty():
		return 0
	candidats.sort_custom(_plus_pres)
	var retenus: int = mini(candidats.size(), MAX_ZONE if zone else 1)
	var reagi: int = 0
	for k: int in retenus:
		var i: int = int(candidats[k].y)
		var id: int = ids[i]
		if _suivis.has(id):
			continue
		var sens: Vector2 = (positions[i] - tour).normalized()
		if sens == Vector2.ZERO:
			sens = Vector2.RIGHT
		_suivis[id] = {"age": 0.0, "sens": sens}
		reagi += 1
	return reagi


static func _plus_pres(a: Vector2, b: Vector2) -> bool:
	return a.x < b.x if a.x != b.x else a.y < b.y


func avancer(delta: float) -> void:
	var finis: Array[int] = []
	for id: int in _suivis:
		var etat: Dictionary = _suivis[id]
		var age: float = float(etat["age"]) + delta
		etat["age"] = age
		if age >= INTERVALLE_FLASH:
			finis.append(id)
	for id: int in finis:
		_suivis.erase(id)


## Facteur de couleur de l'ennemi `id` : 1 au repos, `FACTEUR_FLASH` pendant le flash.
func eclat(id: int) -> float:
	var etat: Dictionary = _suivis.get(id, {})
	if etat.is_empty() or float(etat["age"]) >= DUREE_FLASH - 0.000001:
		return 1.0
	return FACTEUR_FLASH


## Décalage d'affichage de l'ennemi `id`, en pixels : 0 au repos.
func recul(id: int) -> Vector2:
	var etat: Dictionary = _suivis.get(id, {})
	if etat.is_empty():
		return Vector2.ZERO
	var age: float = etat["age"]
	var force: float = 0.0
	if age < DUREE_RECUL_ALLER:
		force = _sortie_amortie(age / DUREE_RECUL_ALLER)
	elif age < DUREE_RECUL_ALLER + DUREE_RECUL_RETOUR - 0.000001:
		force = 1.0 - _sortie_amortie((age - DUREE_RECUL_ALLER) / DUREE_RECUL_RETOUR)
	return (etat["sens"] as Vector2) * RECUL_PX * force


func nombre_suivis() -> int:
	return _suivis.size()


func reinitialiser() -> void:
	_suivis.clear()


static func _sortie_amortie(t: float) -> float:
	var reste: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - reste * reste * reste
