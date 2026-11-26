extends RefCounted
## Sprites d'effets d'attaques, armes du chaos (dé pipé, sablier fêlé, miroir brisé, vortex de
## verre, horloge folle) : style de Tiny Swords (voir `tools/dessiner_effets_attaques.gd`),
## palette violet, magenta, verre bleuté et or. La cornue instable garde les planches du poison.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.BLANC
const VIOLET := Commun.CHAOS_VIOLET
const LAVANDE := Commun.FOUDRE_LAVANDE
const MAGENTA := Commun.CHAOS_MAGENTA
const NUIT := Commun.CHAOS_NUIT
const OR := Commun.CHAOS_OR
const BRUN := Commun.CHAOS_OR_BRUN
const PALE := Commun.VERRE_PALE
const BLEU := Commun.VERRE_BLEU

const NOMS: PackedStringArray = [
	"de_pipe",
	"eclat_des",
	"sablier",
	"tourbillon_sable",
	"eclat_miroir",
	"gerbe_verre",
	"vague_verre",
	"eclat_verre",
	"engrenage",
	"eclat_engrenage",
]
## Rayon (px de planche) du tourbillon de sable, image par image.
const RAYONS_TOURBILLON: Array[float] = [5.0, 9.0, 12.5, 15.0, 15.0, 15.0]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"de_pipe":
			return _de_pipe()
		"eclat_des":
			return _eclat_des()
		"sablier":
			return _sablier()
		"tourbillon_sable":
			return _tourbillon_sable()
		"eclat_miroir":
			return _eclat_miroir()
		"gerbe_verre":
			return _gerbe_verre()
		"vague_verre":
			return _vague_verre()
		"eclat_verre":
			return _eclat_verre()
		"engrenage":
			return _engrenage()
		"eclat_engrenage":
			return _eclat_engrenage()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Un dé violet, arêtes lavande, points d'or : une face de 1 à 4 points par image, qui tourne d'un
## huitième de tour d'image en image.
static func _de_pipe() -> Image:
	var img: Image = Commun.vierge("de_pipe")
	var points: Array = [
		[Vector2(0.0, 0.0)],
		[Vector2(-1.9, -1.9), Vector2(1.9, 1.9)],
		[Vector2(-1.9, -1.9), Vector2(0.0, 0.0), Vector2(1.9, 1.9)],
		[Vector2(-1.9, -1.9), Vector2(1.9, -1.9), Vector2(-1.9, 1.9), Vector2(1.9, 1.9)],
	]
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "de_pipe", i)
		var angle: float = PI / 4.0 + i * PI / 8.0
		var demi: float = minf(4.7, 5.0 / (absf(cos(angle)) + absf(sin(angle))))
		for y: int in t.h:
			for x: int in t.w:
				var v: Vector2 = Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0).rotated(-angle)
				if absf(v.x) > demi or absf(v.y) > demi:
					continue
				t.p(x, y, LAVANDE if maxf(absf(v.x), absf(v.y)) > demi - 1.1 else VIOLET)
		for pt: Vector2 in points[i]:
			var c: Vector2 = Vector2(6.0, 6.0) + pt.rotated(angle)
			t.disque(c.x, c.y, 0.95, OR)
		t.entourer(NUIT)
	return img


## L'impact : un éclat violet entouré de points d'or qui s'écartent, puis se perdent.
static func _eclat_des() -> Image:
	var img: Image = Commun.vierge("eclat_des")
	var etapes: Array = [[7.0, 1.4, 3.5], [9.0, 1.1, 2.0], [10.5, 0.9, 0.0], [11.2, 0.5, 0.0]]
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "eclat_des", i)
		var e: Array = etapes[i]
		if float(e[2]) > 0.0:
			t.disque(12.0, 12.0, float(e[2]), VIOLET)
			t.disque(12.0, 12.0, float(e[2]) * 0.45, MAGENTA)
		for k: int in 6:
			var c: Vector2 = (
				Vector2(12.0, 12.0) + Vector2.from_angle(TAU * k / 6.0 + 0.2) * float(e[0])
			)
			t.disque(c.x, c.y, float(e[1]), OR)
		if i < 3:
			t.entourer(NUIT)
	return img


## Un sablier posé : verre bleuté, socles d'or brun, le sable coule d'une image à l'autre.
static func _sablier() -> Image:
	var img: Image = Commun.vierge("sablier")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "sablier", i)
		for y: int in range(2, 14):
			var demi: float = clampf(0.7 + absf(y + 0.5 - 8.0) * 0.62, 0.0, 3.8)
			for x: int in t.w:
				var dx: float = absf(x + 0.5 - 5.0)
				if dx <= demi:
					t.p(x, y, BLEU if dx > demi - 1.0 else PALE)
		# Le sable : le haut baisse et le tas du bas monte, un filet les relie.
		var haut: int = 4 + i
		var bas: int = 12 - i
		for y: int in range(haut, 8):
			var demi: float = clampf(0.7 + absf(y + 0.5 - 8.0) * 0.62, 0.0, 3.8) - 1.0
			for x: int in t.w:
				if absf(x + 0.5 - 5.0) <= demi:
					t.p(x, y, OR)
		for y: int in range(bas, 14):
			var demi: float = clampf(0.7 + absf(y + 0.5 - 8.0) * 0.62, 0.0, 3.8) - 1.0
			for x: int in t.w:
				if absf(x + 0.5 - 5.0) <= demi:
					t.p(x, y, OR)
		for y: int in range(8, bas - i):
			t.p(4 + (y + i) % 2, y, OR)
		for x: int in range(1, 9):
			t.p(x, 0, OR)
			t.p(x, 1, BRUN)
			t.p(x, 14, BRUN)
			t.p(x, 15, OR if x % 2 == 0 else BRUN)
		t.entourer(NUIT)
	return img


## Le tourbillon : trois bras de sable d'or en spirale, qui grandissent jusqu'au rayon puis
## s'effilochent (tramage) ; un grain violet ou magenta entre les bras.
static func _tourbillon_sable() -> Image:
	var img: Image = Commun.vierge("tourbillon_sable")
	var rng: RandomNumberGenerator = Commun.hasard()
	for i: int in 6:
		var t: Commun.Toile = Commun.toile(img, "tourbillon_sable", i)
		var rayon: float = RAYONS_TOURBILLON[i]
		for k: int in 3:
			var theta: float = 0.0
			while theta <= 3.2:
				var angle: float = theta + k * TAU / 3.0 + i * 0.55
				var r: float = rayon * theta / 3.2
				var c: Vector2 = Vector2(16.0, 16.0) + Vector2.from_angle(angle) * r
				var ombre: Vector2 = Vector2(16.0, 16.0) + Vector2.from_angle(angle - 0.3) * r
				t.disque(ombre.x, ombre.y, 0.7 + 0.5 * theta / 3.2, VIOLET)
				theta += 0.05
			theta = 0.0
			while theta <= 3.2:
				var angle: float = theta + k * TAU / 3.0 + i * 0.55
				var c: Vector2 = (
					Vector2(16.0, 16.0) + Vector2.from_angle(angle) * rayon * theta / 3.2
				)
				t.disque(c.x, c.y, 0.8 + 0.9 * theta / 3.2, OR if theta > 1.0 else BRUN)
				theta += 0.05
		for g: int in 5:
			var c: Vector2 = (
				Vector2(16.0, 16.0)
				+ Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 1.0) * rayon
			)
			t.p(roundi(c.x - 0.5), roundi(c.y - 0.5), MAGENTA if g % 2 == 0 else VIOLET)
		if i < 4:
			t.entourer(NUIT)
		else:
			# Le tourbillon retombe : un pixel sur deux (puis sur quatre) s'en va.
			for y: int in t.h:
				for x: int in t.w:
					var garde: bool = (x + y) % 2 == 0 if i == 4 else (x + 2 * y) % 4 == 0
					if not garde:
						t.p(x, y, Commun.TRANSPARENT)
	return img


## Un éclat de miroir : un long triangle de verre pâle à facette bleue, un reflet blanc qui
## traverse d'une image à l'autre.
static func _eclat_miroir() -> Image:
	var img: Image = Commun.vierge("eclat_miroir")
	var forme := PackedVector2Array([Vector2(1.5, 10.5), Vector2(5.0, 1.0), Vector2(10.5, 5.5)])
	var facette := PackedVector2Array([Vector2(1.5, 10.5), Vector2(5.0, 1.0), Vector2(6.0, 6.5)])
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "eclat_miroir", i)
		for y: int in t.h:
			for x: int in t.w:
				var p: Vector2 = Vector2(x + 0.5, y + 0.5)
				if Geometry2D.is_point_in_polygon(p, forme):
					t.p(x, y, BLEU if Geometry2D.is_point_in_polygon(p, facette) else PALE)
		# Le reflet : une diagonale blanche qui glisse du bas gauche vers le haut droit.
		for k: int in 3:
			t.p(2 + i * 2 + k, 8 - i * 2 - k, BLANC)
		t.entourer(NUIT)
	return img


## Un triangle effilé (un éclat) de longueur `taille`, pointe dans la direction `angle`.
static func _eclat(
	t: Commun.Toile, c: Vector2, angle: float, taille: float, couleur: Color
) -> void:
	var sens: Vector2 = Vector2.from_angle(angle)
	var cote: Vector2 = sens.orthogonal()
	var pts := PackedVector2Array(
		[
			c + sens * taille,
			c - sens * taille * 0.4 + cote * taille * 0.5,
			c - sens * taille * 0.4 - cote * taille * 0.5
		]
	)
	for y: int in t.h:
		for x: int in t.w:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				t.p(x, y, couleur)


## L'impact du miroir : un flash blanc hérissé de pointes, puis sept éclats de verre qui partent.
static func _gerbe_verre() -> Image:
	var img: Image = Commun.vierge("gerbe_verre")
	var f0: Commun.Toile = Commun.toile(img, "gerbe_verre", 0)
	for k: int in 8:
		_eclat(f0, Vector2(12.0, 12.0), TAU * k / 8.0, 10.5 if k % 2 == 0 else 6.5, PALE)
	f0.disque(12.0, 12.0, 3.0, BLANC)
	f0.entourer(NUIT)
	var etapes: Array = [[6.0, 4.2], [8.5, 3.6], [10.5, 3.0]]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "gerbe_verre", i + 1)
		for k: int in 7:
			var a: float = TAU * k / 7.0 + 0.4
			var c: Vector2 = Vector2(12.0, 12.0) + Vector2.from_angle(a) * float(etapes[i][0])
			_eclat(t, c, a, float(etapes[i][1]), BLEU if k % 3 == 1 else PALE)
		t.entourer(NUIT)
	var f4: Commun.Toile = Commun.toile(img, "gerbe_verre", 4)
	for k: int in 7:
		var c: Vector2 = Vector2(12.0, 12.0) + Vector2.from_angle(TAU * k / 7.0 + 0.4) * 11.0
		f4.p(roundi(c.x - 0.5), roundi(c.y - 0.5), MAGENTA if k % 2 == 0 else PALE)
	return img


## Un bras de la spirale de verre : un croissant hérissé de pointes (le bord d'attaque, blanc)
## qui bombe vers +x et dont la queue s'enroule d'un côté ; le verre se bleuit vers l'arrière.
static func _vague_verre() -> Image:
	var img: Image = Commun.vierge("vague_verre")
	var t: Commun.Toile = Commun.toile(img, "vague_verre", 0)
	for y: int in t.h:
		var u: float = (y + 0.5 - 16.0) / 15.5
		var front: float = 12.5 - 9.0 * u * u - 3.0 * u + (1.5 if y % 4 < 2 else 0.0)
		var epaisseur: float = 1.5 + 6.0 * (1.0 - u * u)
		for x: int in t.w:
			var d: float = front - (x + 0.5)
			if d < 0.0 or d > epaisseur:
				continue
			var part: float = 1.0 - d / epaisseur
			if part > 0.8:
				t.p(x, y, BLANC)
			elif part > 0.4:
				t.p(x, y, PALE)
			else:
				t.p(x, y, BLEU)
		if y % 6 == 0:
			t.p_si_vide(roundi(front - epaisseur) - 1, y, MAGENTA)
	t.entourer(NUIT)
	return img


## Un éclat de verre laissé derrière l'onde : quatre pixels, pâle puis bleu.
static func _eclat_verre() -> Image:
	var img: Image = Commun.vierge("eclat_verre")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "eclat_verre", i)
		var c: Color = PALE if i == 0 else BLEU
		t.p(1, 0, c)
		t.p(0, 1, c)
		t.p(1, 1, BLANC if i == 0 else c)
		t.p(2, 1, c)
		t.p(1, 2, c)
		t.p(3, 3, c)
	return img


## Un rouage d'or : huit dents, un trou magenta ; la deuxième image décale les dents d'un cran.
static func _engrenage() -> Image:
	var img: Image = Commun.vierge("engrenage")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "engrenage", i)
		for y: int in t.h:
			for x: int in t.w:
				var v: Vector2 = Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0)
				var cran: int = int(floorf((v.angle() + PI) / (TAU / 12.0))) + i
				var dehors: float = 5.6 if cran % 2 == 0 else 3.7
				if v.length() <= dehors:
					t.p(x, y, BRUN if v.x + v.y > 3.0 else OR)
		t.disque(6.0, 6.0, 1.5, MAGENTA)
		t.entourer(NUIT)
	return img


## Les rouages qui éclatent : une étoile de dents blanche et or, puis cinq petits rouages qui
## s'écartent en tournant, puis des grains.
static func _eclat_engrenage() -> Image:
	var img: Image = Commun.vierge("eclat_engrenage")
	var f0: Commun.Toile = Commun.toile(img, "eclat_engrenage", 0)
	for y: int in f0.h:
		for x: int in f0.w:
			var v: Vector2 = Vector2(x + 0.5 - 12.0, y + 0.5 - 12.0)
			var cran: int = int(floorf((v.angle() + PI) / (TAU / 20.0)))
			if v.length() <= (10.5 if cran % 2 == 0 else 7.0):
				f0.p(x, y, OR)
	f0.disque(12.0, 12.0, 3.4, BLANC)
	f0.disque(12.0, 12.0, 1.6, MAGENTA)
	f0.entourer(NUIT)
	var etapes: Array = [[6.5, 2], [9.0, 2], [11.0, 1]]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "eclat_engrenage", i + 1)
		for k: int in 5:
			var c: Vector2 = (
				Vector2(12.0, 12.0)
				+ Vector2.from_angle(TAU * k / 5.0 + 0.5 + i * 0.3) * float(etapes[i][0])
			)
			var cx: int = roundi(c.x - 0.5)
			var cy: int = roundi(c.y - 0.5)
			if i < 2:
				_rouage(t, cx, cy)
			else:
				t.p(cx, cy, OR)
				t.p(cx + 1, cy, MAGENTA)
		if i < 2:
			t.entourer(NUIT)
	return img


## Un petit rouage de 5 pixels de côté : un carré plein de 3 pixels, une dent au milieu de chaque
## côté, un trou magenta.
static func _rouage(t: Commun.Toile, cx: int, cy: int) -> void:
	for y: int in range(-2, 3):
		for x: int in range(-2, 3):
			if maxi(absi(x), absi(y)) <= 1 or (absi(x) + absi(y) == 2 and (x == 0 or y == 0)):
				t.p(cx + x, cy + y, OR)
	t.p(cx, cy, MAGENTA)
