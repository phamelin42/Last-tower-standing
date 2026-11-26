extends RefCounted
## Sprites d'effets d'attaques, armes magiques (nova d'ambre, tempête astrale) : style et palette
## de Tiny Swords (voir `tools/dessiner_effets_attaques.gd`). Le cercle de givre reprend les
## planches de la glace.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.BLANC
const CLAIR := Commun.AMBRE_CLAIR
const AMBRE := Commun.AMBRE
const BRUN := Commun.AMBRE_BRUN
const OR := Commun.ASTRAL_OR
const VIOLET := Commun.FOUDRE_VIOLET
const NUIT := Commun.FOUDRE_SOMBRE

const NOMS: PackedStringArray = ["vague_ambre", "etoile_astrale", "eclat_astral"]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"vague_ambre":
			return _vague_ambre()
		"etoile_astrale":
			return _etoile_astrale()
		"eclat_astral":
			return _eclat_astral()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Un croissant de feu ambré qui bombe vers +x : le bord d'attaque est clair, le corps ambre, la
## queue brune et tramée qui s'effile derrière.
static func _vague_ambre() -> Image:
	var img: Image = Commun.vierge("vague_ambre")
	var t: Commun.Toile = Commun.toile(img, "vague_ambre", 0)
	for y: int in t.h:
		var u: float = (y + 0.5 - 16.0) / 15.5
		var front: float = 10.5 - 8.0 * u * u
		var epaisseur: float = 1.0 + 6.0 * (1.0 - u * u)
		for x: int in t.w:
			var d: float = front - (x + 0.5)
			if d < 0.0 or d > epaisseur:
				continue
			var part: float = 1.0 - d / epaisseur
			if part > 0.8:
				t.p(x, y, CLAIR)
			elif part > 0.4:
				t.p(x, y, AMBRE)
			else:
				t.p(x, y, BRUN)
		# La queue : un tramage brun derrière le croissant.
		var arriere: int = int(floorf(front - epaisseur))
		for x: int in range(arriere - 2, arriere + 1):
			if (x + y) % 2 == 0:
				t.p_si_vide(x, y, BRUN)
	t.entourer(Commun.AMBRE_BRUN.darkened(0.55))
	return img


## Une étoile à `branches` pointes centrée en (`cx`, `cy`), de rayon `exterieur` et `interieur`.
static func _etoile(
	t: Commun.Toile,
	cx: float,
	cy: float,
	exterieur: float,
	interieur: float,
	angle: float,
	c: Color,
	branches: int = 4
) -> void:
	var pts := PackedVector2Array()
	for k: int in branches * 2:
		var r: float = exterieur if k % 2 == 0 else interieur
		pts.append(Vector2(cx, cy) + Vector2.from_angle(angle + PI * k / branches) * r)
	for y: int in t.h:
		for x: int in t.w:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				t.p(x, y, c)


## Une étoile filante : quatre pointes d'or, cœur blanc, qui tourne d'un huitième de tour par image.
static func _etoile_astrale() -> Image:
	var img: Image = Commun.vierge("etoile_astrale")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "etoile_astrale", i)
		_etoile(t, 6.0, 6.0, 4.9, 1.7, i * PI / 8.0, OR)
		t.disque(6.0, 6.0, 1.3, BLANC)
		t.entourer(NUIT)
		# Deux étincelles violettes qui tournent avec l'étoile.
		for s: int in 2:
			var v: Vector2 = (
				Vector2(6.0, 6.0) + Vector2.from_angle(i * PI / 4.0 + s * PI + 0.8) * 4.6
			)
			t.p_si_vide(roundi(v.x - 0.5), roundi(v.y - 0.5), VIOLET)
	return img


## L'impact : une grande étoile, puis un anneau de petites étoiles qui s'écartent et se perdent.
static func _eclat_astral() -> Image:
	var img: Image = Commun.vierge("eclat_astral")
	var rng: RandomNumberGenerator = Commun.hasard()
	var f1: Commun.Toile = Commun.toile(img, "eclat_astral", 0)
	_etoile(f1, 12.0, 12.0, 10.5, 2.4, 0.0, OR)
	_etoile(f1, 12.0, 12.0, 6.5, 2.2, PI / 4.0, BLANC)
	f1.disque(12.0, 12.0, 2.0, BLANC)
	f1.entourer(NUIT)
	var etapes: Array = [[6.0, 3.6], [8.5, 3.2], [10.5, 2.6]]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "eclat_astral", i + 1)
		for k: int in 6:
			var a: float = TAU * k / 6.0 + 0.3 + i * 0.2
			var c: Vector2 = Vector2(12.0, 12.0) + Vector2.from_angle(a) * etapes[i][0]
			_etoile(t, c.x, c.y, etapes[i][1], 1.2, a, OR if k % 2 == 0 else VIOLET)
		t.entourer(NUIT)
	var f5: Commun.Toile = Commun.toile(img, "eclat_astral", 4)
	for k: int in 8:
		var c: Vector2 = (
			Vector2(12.0, 12.0) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 11.0)
		)
		f5.p(roundi(c.x), roundi(c.y), OR if k % 2 == 0 else VIOLET)
	return img
