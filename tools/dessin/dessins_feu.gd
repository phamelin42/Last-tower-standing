extends RefCounted
## Sprites d'effets d'attaques, élément feu (boule, braise, explosion) : style et palette de Tiny
## Swords (voir `tools/dessiner_effets_attaques.gd`).

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.BLANC
const ENCRE := Commun.ENCRE
const FUMEE := Commun.FUMEE
const JAUNE := Commun.JAUNE
const ORANGE := Commun.ORANGE
const ROUGE_SOMBRE := Commun.ROUGE_SOMBRE

const NOMS: PackedStringArray = ["boule_feu", "braise", "explosion_feu"]

## Trois langues de flamme qui partent de la tête vers la gauche, pointues, orange cernées de
## rouge et jaunes au cœur ; leur longueur change d'une image à l'autre : le scintillement.
## Chaque ligne : ordonnée du milieu, longueur, épaisseur à la base.
const LANGUES: Array = [
	[[5.2, 4.0, 1.7], [10.8, 3.0, 1.5], [8.0, 6.0, 2.7]],
	[[5.0, 3.0, 1.5], [11.0, 5.0, 1.8], [7.6, 5.0, 2.6]],
	[[5.0, 5.0, 1.8], [11.2, 2.5, 1.4], [8.4, 6.0, 2.6]],
	[[5.4, 3.5, 1.6], [10.6, 4.0, 1.6], [8.0, 4.5, 2.7]],
]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"boule_feu":
			return _boule_feu()
		"braise":
			return _braise()
		"explosion_feu":
			return _explosion_feu()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


static func _boule_feu() -> Image:
	var img: Image = Commun.vierge("boule_feu")
	var rng: RandomNumberGenerator = Commun.hasard()
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "boule_feu", i)
		_queue_de_flammes(t, rng, i)
		_tete_de_comete(t)
	return img


static func _queue_de_flammes(t: Commun.Toile, _rng: RandomNumberGenerator, i: int) -> void:
	for langue: Array in LANGUES[i]:
		var longueur: float = langue[1]
		var pointe: int = 6 - roundi(longueur)
		for x: int in range(pointe, 7):
			var u: float = (x - pointe + 0.5) / longueur
			var demi: float = 0.45 + float(langue[2]) * u
			for y: int in t.h:
				var d: float = absf(y + 0.5 - float(langue[0]))
				if d > demi:
					continue
				if d > demi - 0.9 or x == pointe:
					t.p(x, y, ROUGE_SOMBRE)
				elif d > demi * 0.5:
					t.p(x, y, ORANGE)
				else:
					t.p(x, y, JAUNE)


static func _tete_de_comete(t: Commun.Toile) -> void:
	for y: int in t.h:
		for x: int in t.w:
			var d: float = Vector2(x + 0.5 - 10.5, y + 0.5 - 8.0).length()
			if d > 5.0:
				continue
			if d > 4.0:
				t.p(x, y, ROUGE_SOMBRE)
			elif d > 2.8:
				t.p(x, y, ORANGE)
			elif d > 1.5:
				t.p(x, y, JAUNE)
			else:
				t.p(x, y, BLANC)


static func _braise() -> Image:
	var img: Image = Commun.vierge("braise")
	var rouges: Array = [
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(3, 2), Vector2i(2, 3)],
		[Vector2i(2, 0), Vector2i(3, 1), Vector2i(0, 2), Vector2i(1, 3)],
	]
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "braise", i)
		for dy: int in 2:
			for dx: int in 2:
				t.p(1 + dx, 1 + dy, ORANGE)
		for v: Vector2i in rouges[i]:
			t.p(v.x, v.y, ROUGE_SOMBRE)
		t.p(1 + i, 1 + i, JAUNE)
	return img


## Boule de flamme au bord déchiré : `seuils` donne la profondeur (0 au cœur, 1 au bord) où l'on
## passe du rouge à l'orange, de l'orange au jaune, du jaune au blanc.
static func _boule_de_flamme(
	t: Commun.Toile,
	rng: RandomNumberGenerator,
	rayon: float,
	amplitude: float,
	seuils: Array[float]
) -> void:
	var n: int = 14
	var bruit: PackedFloat32Array = PackedFloat32Array()
	for k: int in n:
		bruit.append(rng.randf_range(-amplitude, amplitude))
	var c: Vector2 = Vector2(t.w / 2.0, t.h / 2.0)
	for y: int in t.h:
		for x: int in t.w:
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - c
			var u: float = fposmod(d.angle(), TAU) / TAU * n
			var k0: int = int(u) % n
			var bord: float = rayon + lerpf(bruit[k0], bruit[(k0 + 1) % n], u - floorf(u))
			if d.length() > bord:
				continue
			var prof: float = d.length() / bord
			if prof > seuils[0]:
				t.p(x, y, ROUGE_SOMBRE)
			elif prof > seuils[1]:
				t.p(x, y, ORANGE)
			elif prof > seuils[2]:
				t.p(x, y, JAUNE)
			else:
				t.p(x, y, BLANC)


## Gouttelettes de feu ou de fumée en couronne autour du centre.
static func _bouffees(
	t: Commun.Toile,
	rng: RandomNumberGenerator,
	nombre: int,
	dist: Vector2,
	rayon: Vector2,
	couleur: Color
) -> void:
	for k: int in nombre:
		var a: float = TAU * k / nombre + rng.randf_range(-0.25, 0.25)
		var d: float = rng.randf_range(dist.x, dist.y)
		var r: float = rng.randf_range(rayon.x, rayon.y)
		var c: Vector2 = Vector2(t.w / 2.0, t.h / 2.0) + Vector2.from_angle(a) * d
		t.disque(c.x, c.y, r, couleur)


static func _explosion_feu() -> Image:
	var img: Image = Commun.vierge("explosion_feu")
	var rng: RandomNumberGenerator = Commun.hasard()
	var seuils_1: Array[float] = [0.7, 0.45, 0.0]
	var seuils_2: Array[float] = [0.85, 0.6, 0.3]
	var seuils_3: Array[float] = [0.85, 0.45, 0.2]
	_boule_de_flamme(Commun.toile(img, "explosion_feu", 0), rng, 6.0, 0.6, seuils_1)
	_boule_de_flamme(Commun.toile(img, "explosion_feu", 1), rng, 10.0, 2.5, seuils_2)
	_boule_de_flamme(Commun.toile(img, "explosion_feu", 2), rng, 13.0, 3.0, seuils_3)
	var f4: Commun.Toile = Commun.toile(img, "explosion_feu", 3)
	f4.disque(16.0, 16.0, 5.5, ROUGE_SOMBRE)
	f4.disque(15.5, 15.5, 3.5, ORANGE)
	for k: int in 11:
		var a: float = TAU * k / 11.0 + rng.randf_range(-0.2, 0.2)
		var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * rng.randf_range(8.5, 13.0)
		var r: float = rng.randf_range(1.8, 3.0)
		f4.disque(c.x, c.y, r, ROUGE_SOMBRE)
		f4.disque(c.x - 0.5, c.y - 0.5, r - 0.8, ORANGE)
	for k: int in 5:
		var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * 7.0
		f4.p(roundi(c.x), roundi(c.y), JAUNE)
	var f5: Commun.Toile = Commun.toile(img, "explosion_feu", 4)
	_bouffees(f5, rng, 7, Vector2(6.5, 11.0), Vector2(2.8, 4.0), FUMEE)
	f5.entourer(ENCRE)
	for k: int in 6:
		var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * 13.0
		var x: int = roundi(c.x)
		var y: int = roundi(c.y)
		f5.p(x, y, ORANGE)
		f5.p(x + 1, y, JAUNE)
	var f6: Commun.Toile = Commun.toile(img, "explosion_feu", 5)
	for k: int in 9:
		var c: Vector2 = (
			Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(7.0, 14.0)
		)
		f6.p(roundi(c.x), roundi(c.y), FUMEE if k % 3 != 2 else ENCRE)
		if k % 2 == 0:
			f6.p(roundi(c.x) + 1, roundi(c.y), FUMEE)
	return img
