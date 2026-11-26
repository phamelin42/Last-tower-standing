extends RefCounted
## Petits outils de dessin que partagent les fichiers de dessins du lot 9 (polygones pleins,
## rotation d'un contour) : les `Toile` de `dessin_commun.gd` ne savent que les disques, les
## ellipses et les lignes.

const Commun := preload("res://tools/dessin/dessin_commun.gd")


## Remplit le polygone `points` (règle pair-impair) en testant le centre de chaque pixel.
static func polygone(t: Commun.Toile, points: Array[Vector2], c: Color) -> void:
	for y: int in t.h:
		for x: int in t.w:
			if _dans(points, Vector2(x + 0.5, y + 0.5)):
				t.p(x, y, c)


## Le contour `points` tourné de `angle` radians autour de `centre`, puis décalé de `vers`.
static func pivoter(
	points: Array[Vector2], angle: float, centre: Vector2, vers: Vector2 = Vector2.ZERO
) -> Array[Vector2]:
	var rendu: Array[Vector2] = []
	for p: Vector2 in points:
		rendu.append((p - centre).rotated(angle) + centre + vers)
	return rendu


## Un trait épais de `epaisseur` pixels de `a` à `b` (disques de proche en proche).
static func trait_epais(
	t: Commun.Toile, a: Vector2, b: Vector2, epaisseur: float, c: Color
) -> void:
	var n: int = maxi(1, ceili(a.distance_to(b)))
	for i: int in n + 1:
		var p: Vector2 = a.lerp(b, float(i) / n)
		t.disque(p.x, p.y, epaisseur * 0.5, c)


static func _dans(points: Array[Vector2], p: Vector2) -> bool:
	var dedans: bool = false
	var j: int = points.size() - 1
	for i: int in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[j]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			dedans = not dedans
		j = i
	return dedans
