extends RefCounted
## Sprites d'effets d'attaques, élément poison (fiole, éclaboussure, nuage) : style et palette
## de Tiny Swords (voir `tools/dessiner_effets_attaques.gd`).

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.BLANC
const BOUCHON := Commun.BOUCHON
const POISON := Commun.POISON
const POISON_CONTOUR := Commun.POISON_CONTOUR
const POISON_FONCE := Commun.POISON_FONCE
const POISON_PALE := Commun.POISON_PALE
const VERRE := Commun.VERRE

const NOMS: PackedStringArray = ["fiole", "eclaboussure_poison", "nuage_poison"]

const FLAQUES: Array = [
	[Vector2(16, 16), 6.0, 3.0],
	[Vector2(7, 10), 3.0, 1.7],
	[Vector2(25, 11), 3.5, 1.8],
	[Vector2(9, 23), 3.5, 1.8],
	[Vector2(24, 22), 3.0, 1.7],
]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"fiole":
			return _fiole()
		"eclaboussure_poison":
			return _eclaboussure_poison()
		"nuage_poison":
			return _nuage_poison()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


static func _fiole() -> Image:
	var img: Image = Commun.vierge("fiole")
	var t: Commun.Toile = Commun.toile(img, "fiole", 0)
	for y: int in range(1, 3):
		for x: int in range(3, 7):
			t.p(x, y, BOUCHON)
	for y: int in range(3, 5):
		t.p(4, y, VERRE)
		t.p(5, y, VERRE)
	for y: int in t.h:
		for x: int in t.w:
			var dx: float = x + 0.5 - 5.0
			var dy: float = y + 0.5 - 8.5
			if Vector2(dx, dy).length() > 3.9:
				continue
			if y < 8:
				t.p(x, y, VERRE)
			elif dx + dy > 3.0:
				t.p(x, y, POISON_FONCE)
			else:
				t.p(x, y, POISON)
	t.p(2, 6, BLANC)
	t.p(2, 7, BLANC)
	t.p(3, 5, BLANC)
	t.entourer(POISON_CONTOUR)
	return img


## Tache irrégulière : un disque au bord déchiré, ombré en bas à droite, clair en haut à gauche.
static func _tache(
	t: Commun.Toile, rng: RandomNumberGenerator, c: Vector2, rayon: float, amp: float
) -> void:
	var n: int = 10
	var bruit: PackedFloat32Array = PackedFloat32Array()
	for k: int in n:
		bruit.append(rng.randf_range(-amp, amp))
	for y: int in t.h:
		for x: int in t.w:
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - c
			var u: float = fposmod(d.angle(), TAU) / TAU * n
			var k0: int = int(u) % n
			var bord: float = rayon + lerpf(bruit[k0], bruit[(k0 + 1) % n], u - floorf(u))
			if d.length() > bord:
				continue
			if d.x + d.y > bord * 0.45:
				t.p(x, y, POISON_FONCE)
			elif d.x + d.y < -bord * 0.6:
				t.p(x, y, POISON_PALE)
			else:
				t.p(x, y, POISON)


static func _goutte(t: Commun.Toile, c: Vector2, r: float) -> void:
	t.disque(c.x, c.y, r, POISON)
	t.p(roundi(c.x - 0.5) - 1, roundi(c.y - 0.5) - 1, POISON_PALE)
	t.p(roundi(c.x + 0.5), roundi(c.y + 0.5), POISON_FONCE)


static func _eclaboussure_poison() -> Image:
	var img: Image = Commun.vierge("eclaboussure_poison")
	var rng: RandomNumberGenerator = Commun.hasard()
	var f1: Commun.Toile = Commun.toile(img, "eclaboussure_poison", 0)
	_tache(f1, rng, Vector2(16, 16), 7.0, 3.0)
	for k: int in 5:
		var a: float = TAU * k / 5.0 + 0.5
		var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * 4.5
		var dir: Vector2 = Vector2.from_angle(a)
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var pts: PackedVector2Array = PackedVector2Array(
			[c + dir * 2.8, c + perp * 1.4, c - dir * 2.8, c - perp * 1.4]
		)
		for y: int in f1.h:
			for x: int in f1.w:
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
					f1.p(x, y, BLANC if (x + y) % 2 == 0 else VERRE)
	f1.entourer(POISON_CONTOUR)
	var etapes: Array = [[8.0, 2.2, 5.0], [11.5, 1.8, 3.8], [14.5, 1.3, 2.6]]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "eclaboussure_poison", i + 1)
		_tache(t, rng, Vector2(16, 16), etapes[i][2], 1.2)
		for k: int in 8:
			var a: float = TAU * k / 8.0 + 0.3 + rng.randf_range(-0.15, 0.15)
			var d: float = etapes[i][0] + rng.randf_range(-1.0, 1.0)
			_goutte(t, Vector2(16, 16) + Vector2.from_angle(a) * d, etapes[i][1])
		t.entourer(POISON_CONTOUR)
	var f5: Commun.Toile = Commun.toile(img, "eclaboussure_poison", 4)
	for f: Array in FLAQUES:
		var c: Vector2 = f[0]
		f5.ellipse(c.x, c.y, f[1], f[2], POISON_FONCE)
		f5.ellipse(c.x - 0.5, c.y - 0.6, f[1] - 1.0, f[2] - 0.8, POISON)
		f5.p(roundi(c.x) - 1, roundi(c.y) - 1, POISON_PALE)
	f5.entourer(POISON_CONTOUR)
	var f6: Commun.Toile = Commun.toile(img, "eclaboussure_poison", 5)
	for f: Array in FLAQUES:
		var c: Vector2 = f[0]
		for y: int in f6.h:
			for x: int in f6.w:
				var u: float = (x + 0.5 - c.x) / (f[1] * 0.8)
				var v: float = (y + 0.5 - c.y) / (f[2] * 0.8)
				if u * u + v * v <= 1.0 and (x + y) % 2 == 0:
					f6.p(x, y, POISON_FONCE if u + v > 0.0 else POISON)
	return img


static func _nuage_poison() -> Image:
	var img: Image = Commun.vierge("nuage_poison")
	var lobes: Array = [
		[Vector2(5.5, 9.5), 3.5],
		[Vector2(10.5, 9.5), 3.5],
		[Vector2(8.0, 6.5), 3.3],
		[Vector2(8.0, 10.5), 3.5],
	]
	var bulles: Array = [
		[Vector2i(5, 8), Vector2i(10, 6)],
		[Vector2i(6, 9), Vector2i(10, 10)],
		[Vector2i(9, 7), Vector2i(5, 10)],
	]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "nuage_poison", i)
		for k: int in lobes.size():
			var c: Vector2 = lobes[k][0]
			var decalage: Vector2 = Vector2(sin(i * 2.1 + k * 1.3), cos(i * 1.7 + k * 2.3)) * 0.7
			t.disque(c.x + decalage.x, c.y + decalage.y, float(lobes[k][1]) + 0.2 * (i % 2), POISON)
		for y: int in t.h:
			for x: int in t.w:
				if not t.opaque(x, y):
					continue
				var s: float = x + 0.5 + y + 0.5 - 16.0
				if s > 3.5:
					t.p(x, y, POISON_FONCE)
				elif s < -3.5:
					t.p(x, y, POISON_PALE)
		for b: Vector2i in bulles[i]:
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				t.p(b.x + d.x, b.y + d.y, POISON_PALE)
			t.p(b.x, b.y, POISON)
		t.entourer(POISON_FONCE)
	return img
