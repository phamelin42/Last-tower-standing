extends RefCounted
## Sprites d'effets d'attaques, élément glace (éclat, brisure, givre) : style et palette
## de Tiny Swords (voir `tools/dessiner_effets_attaques.gd`).

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.BLANC
const GLACE_CYAN := Commun.GLACE_CYAN
const GLACE_PALE := Commun.GLACE_PALE
const GLACE_PROFOND := Commun.GLACE_PROFOND

const NOMS: PackedStringArray = ["eclat_glace", "brisure_glace", "givre_sol"]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"eclat_glace":
			return _eclat_glace()
		"brisure_glace":
			return _brisure_glace()
		"givre_sol":
			return _givre_sol()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Éclat de cristal : un cerf-volant dont la face haute est claire, la face basse cyan, la
## pointe devant. `angle` en radians, `longueur` et `largeur` en pixels.
static func _cristal(
	t: Commun.Toile, cx: float, cy: float, angle: float, longueur: float, largeur: float
) -> void:
	var dir: Vector2 = Vector2.from_angle(angle)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	if perp.dot(Vector2(-1, -1)) < 0.0:
		perp = -perp
	var c: Vector2 = Vector2(cx, cy)
	var pts: PackedVector2Array = PackedVector2Array(
		[
			c + dir * longueur * 0.5,
			c + perp * largeur * 0.5 - dir * longueur * 0.15,
			c - dir * longueur * 0.5,
			c - perp * largeur * 0.5 - dir * longueur * 0.15,
		]
	)
	for y: int in t.h:
		for x: int in t.w:
			var q: Vector2 = Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(q, pts):
				continue
			var s: float = (q - c).dot(perp) / (largeur * 0.5)
			t.p(x, y, GLACE_PALE if s > 0.35 else (GLACE_PALE if s > -0.2 else GLACE_CYAN))
	t.p(roundi(cx), roundi(cy), GLACE_PALE)


static func _eclat_glace() -> Image:
	var img: Image = Commun.vierge("eclat_glace")
	var t: Commun.Toile = Commun.toile(img, "eclat_glace", 0)
	for x: int in range(3, 19):
		var u: float = (x - 3) / 15.0
		var demi: float = 2.6 * (1.0 - u * u) + 0.4
		for y: int in t.h:
			var d: float = y + 0.5 - 4.0
			if absf(d) > demi:
				continue
			if d < 0.0 and d > -demi + 1.0:
				t.p(x, y, GLACE_PALE)
			elif d < 0.0:
				t.p(x, y, BLANC)
			else:
				t.p(x, y, GLACE_CYAN)
	for y: int in range(2, 6):
		t.p(3, y, GLACE_CYAN)
	t.entourer(GLACE_PROFOND)
	return img


static func _brisure_glace() -> Image:
	var img: Image = Commun.vierge("brisure_glace")
	var rng: RandomNumberGenerator = Commun.hasard()
	var f1: Commun.Toile = Commun.toile(img, "brisure_glace", 0)
	for a: int in 4:
		var v: Vector2 = Vector2.from_angle(a * PI / 2.0)
		f1.ligne(16, 16, 16 + roundi(v.x * 8), 16 + roundi(v.y * 8), BLANC)
		var w: Vector2 = Vector2.from_angle(a * PI / 2.0 + PI / 4.0)
		f1.ligne(16, 16, 16 + roundi(w.x * 5), 16 + roundi(w.y * 5), GLACE_PALE)
	f1.disque(16.0, 16.0, 2.2, BLANC)
	f1.entourer(GLACE_PROFOND)
	var etapes: Array = [[6.0, 7.0, 3.0], [10.0, 6.0, 3.0], [13.0, 5.0, 2.5]]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "brisure_glace", i + 1)
		var nombre: int = 6 + i % 2 * 2
		for k: int in nombre:
			var a: float = TAU * k / nombre + 0.4 + rng.randf_range(-0.2, 0.2)
			var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * etapes[i][0]
			_cristal(t, c.x, c.y, a, etapes[i][1], etapes[i][2])
		t.entourer(GLACE_PROFOND)
	var f5: Commun.Toile = Commun.toile(img, "brisure_glace", 4)
	for k: int in 8:
		var a: float = TAU * k / 8.0 + 0.2
		var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * 13.0
		_cristal(f5, c.x, c.y, a, 3.0, 2.0)
	f5.entourer(GLACE_PROFOND)
	for k: int in 8:
		var c: Vector2 = (
			Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 14.0)
		)
		f5.p_si_vide(roundi(c.x), roundi(c.y), GLACE_PALE)
	var f6: Commun.Toile = Commun.toile(img, "brisure_glace", 5)
	for k: int in 7:
		var c: Vector2 = (
			Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, 15.0)
		)
		f6.p(roundi(c.x), roundi(c.y), GLACE_PALE if k % 2 == 0 else GLACE_CYAN)
	return img


static func _givre_sol() -> Image:
	var img: Image = Commun.vierge("givre_sol")
	var t: Commun.Toile = Commun.toile(img, "givre_sol", 0)
	for k: int in 14:
		var a: float = TAU * k / 14.0 + 0.2
		var base: Vector2 = Vector2(16.0 + cos(a) * 11.5, 8.0 + sin(a) * 5.0)
		var pointe: Vector2 = Vector2(16.0 + cos(a) * 14.0, 8.0 + sin(a) * 6.4)
		t.ligne(roundi(base.x), roundi(base.y), roundi(pointe.x), roundi(pointe.y), GLACE_CYAN)
		t.p(roundi(pointe.x), roundi(pointe.y), BLANC)
		t.p(roundi(base.x), roundi(base.y), GLACE_PALE)
	for centre: Vector2i in [Vector2i(11, 6), Vector2i(21, 10), Vector2i(16, 8), Vector2i(8, 10)]:
		t.p(centre.x, centre.y, BLANC)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			t.p(centre.x + d.x, centre.y + d.y, GLACE_PALE)
	t.entourer(GLACE_PROFOND)
	for y: int in t.h:
		for x: int in t.w:
			var u: float = (x + 0.5 - 16.0) / 12.0
			var v: float = (y + 0.5 - 8.0) / 4.6
			if u * u + v * v <= 1.0 and (x + y) % 2 == 0:
				t.p_si_vide(x, y, GLACE_PALE)
	return img
