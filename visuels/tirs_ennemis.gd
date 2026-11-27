class_name TirsEnnemis
extends Node2D
## Les tirs des ennemis à distance : un Archer ou une Dynamite arrêtés à leur portée envoient un
## projectile visible vers la tour, une fois par `cadence_attaque` de leurs données. Purement
## visuel : la simulation n'émet aucun événement de tir ennemi, l'image se déduit de la vue (un
## ennemi à distance posé à son arrêt tire). Sans état par ennemi : la phase du tir se lit sur
## l'horloge d'affichage, décalée par l'identifiant pour que les tireurs ne tirent pas ensemble.
## Durées et tailles ci-dessous : constantes d'affichage, à signaler à l'audit T10.4.

## Projectiles visibles au plus : avec des centaines de tireurs, le surplus n'est pas dessiné.
const PLAFOND: int = 96
## Durée d'un vol, en secondes ; inférieure à la plus courte cadence des données.
const VOL_S: float = 0.4
const DECALAGE_ID_S: float = 0.37
## Tolérance sur l'arrêt, en unités de jeu : l'ennemi s'arrête à `TOLERANCE_ARRET` près.
const MARGE_ARRET: float = 2.0
## Hauteur de l'arc d'une bombe lancée (classe de portée « moyenne »), en pixels.
const ARC_PX: float = 36.0
const LONGUEUR_FLECHE_PX: float = 22.0
const EPAISSEUR_PX: float = 3.0
const RAYON_BOMBE_PX: float = 6.0
## Contour sombre : le projectile se lit sur l'herbe comme sur la pierre.
const COULEUR_CONTOUR := Color(0.1, 0.12, 0.14)
const CONTOUR_PX: float = 2.0
const COULEUR_FLECHE := Color(0.96, 0.9, 0.7)
const COULEUR_BOMBE := Color(0.95, 0.55, 0.2)
const COULEUR_MECHE := Color(1.0, 0.95, 0.6)

## Par famille : secondes entre deux tirs (0 : ne tire pas), arrêt en unités de jeu, lancer en arc.
var _periodes: PackedFloat32Array = PackedFloat32Array()
var _arrets: PackedFloat32Array = PackedFloat32Array()
var _en_arc: PackedByteArray = PackedByteArray()
## `{pos, depart, vers, t, arc}` des projectiles en vol, positions en pixels.
var _tirs: Array[Dictionary] = []


## Lit les familles des données : celles dont la portée dépasse le corps à corps tirent, la classe
## « moyenne » en arc (bombe), les autres en ligne droite (flèche).
func configurer(donnees: Donnees) -> void:
	_periodes.clear()
	_arrets.clear()
	_en_arc.clear()
	var rayon_tour: float = float((donnees.partie["tour"] as Dictionary)["rayon"])
	for f: int in donnees.familles.size():
		var famille: Dictionary = donnees.familles[f]
		var portee: float = float(famille["portee_attaque"])
		var tire: bool = portee > Apparence.PORTEE_CORPS_A_CORPS
		var cadence: float = float(famille["cadence_attaque"])
		_periodes.append(1.0 / cadence if tire and cadence > 0.0 else 0.0)
		_arrets.append(Apparence.distance_arret(portee, rayon_tour))
		_en_arc.append(1 if int(famille["classe_portee"]) == Types.ClassePortee.MOYENNE else 0)


## Recalcule les projectiles à l'instant `horloge`. `positions` en unités de jeu.
func mettre_a_jour(
	horloge: float, ids: PackedInt32Array, positions: PackedVector2Array, familles: PackedByteArray
) -> void:
	var avant: int = _tirs.size()
	_tirs.clear()
	var total: int = mini(ids.size(), mini(positions.size(), familles.size()))
	for i: int in total:
		if _tirs.size() >= PLAFOND:
			break
		var f: int = familles[i]
		if f >= _periodes.size() or _periodes[f] <= 0.0:
			continue
		var p: Vector2 = positions[i]
		if p.length() > _arrets[f] + MARGE_ARRET:
			continue
		var phase: float = fposmod(horloge + float(ids[i]) * DECALAGE_ID_S, _periodes[f])
		if phase >= VOL_S:
			continue
		var depart: Vector2 = Apparence.vers_pixels(p)
		var t: float = phase / VOL_S
		(
			_tirs
			. append(
				{
					"pos": depart.lerp(Vector2.ZERO, t),
					"depart": depart,
					"vers": Vector2.ZERO,
					"t": t,
					"arc": _en_arc[f] != 0,
				}
			)
		)
	if avant > 0 or not _tirs.is_empty():
		queue_redraw()


func tirs() -> Array[Dictionary]:
	return _tirs


func _draw() -> void:
	for tir: Dictionary in _tirs:
		var pos: Vector2 = tir["pos"]
		if bool(tir["arc"]):
			var t: float = tir["t"]
			var haut: Vector2 = pos + Vector2(0.0, -ARC_PX * 4.0 * t * (1.0 - t))
			draw_circle(haut, RAYON_BOMBE_PX + CONTOUR_PX, COULEUR_CONTOUR)
			draw_circle(haut, RAYON_BOMBE_PX, COULEUR_BOMBE)
			draw_circle(haut + Vector2(0.0, -RAYON_BOMBE_PX), EPAISSEUR_PX, COULEUR_MECHE)
		else:
			var sens: Vector2 = (tir["vers"] as Vector2) - (tir["depart"] as Vector2)
			var dir: Vector2 = sens.normalized() if sens.length() > 0.0 else Vector2.RIGHT
			var queue: Vector2 = pos - dir * LONGUEUR_FLECHE_PX
			draw_line(queue, pos, COULEUR_CONTOUR, EPAISSEUR_PX + 2.0 * CONTOUR_PX)
			draw_line(queue, pos, COULEUR_FLECHE, EPAISSEUR_PX)
