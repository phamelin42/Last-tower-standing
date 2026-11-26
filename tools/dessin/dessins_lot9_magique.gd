extends RefCounted
## Sprites d'effets d'attaques des armes magiques du lot 9 (T9.18) : orbe de siphon, prisme, lueur,
## vasque, vague céleste et les éclats d'impact du siphon et du prisme. Style et palette de Tiny
## Swords (voir `tools/dessiner_effets_attaques.gd`).

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const Outils := preload("res://tools/dessin/dessin_outils_lot9.gd")
const BLANC := Commun.BLANC
const CLAIR := Commun.ARCANE_CLAIR
const BLEU := Commun.ARCANE_BLEU
const NUIT := Commun.ARCANE_NUIT
const LAVANDE := Commun.FOUDRE_LAVANDE
const VIOLET := Commun.FOUDRE_VIOLET
const VIOLET_SOMBRE := Commun.FOUDRE_SOMBRE
const OR := Commun.ASTRAL_OR
const ACIER_CLAIR := Commun.ACIER_CLAIR
const ACIER := Commun.ACIER

const NOMS: PackedStringArray = [
	"siphon", "prisme", "lueur", "vasque", "vague_celeste", "eclat_siphon", "eclat_prisme"
]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"siphon":
			return _siphon()
		"prisme":
			return _prisme()
		"lueur":
			return _lueur()
		"vasque":
			return _vasque()
		"vague_celeste":
			return _vague_celeste()
		"eclat_siphon":
			return _eclat_siphon()
		"eclat_prisme":
			return _eclat_prisme()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Un orbe violet qui file en laissant une queue effilée derrière lui, traversé d'un fil clair
## qui s'enroule : le fil tourne d'une image à l'autre.
static func _siphon() -> Image:
	var img: Image = Commun.vierge("siphon")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "siphon", i)
		t.disque(7.0, 6.0, 4.4, VIOLET)
		t.ligne(0, 6, 3, 6, VIOLET)
		t.ligne(2, 5, 3, 5, VIOLET)
		t.ligne(2, 7, 3, 7, VIOLET)
		for k: int in 14:
			var a: float = float(k) * 0.45 + i * PI
			var rayon: float = 4.2 - float(k) * 0.27
			t.p(roundi(6.5 + cos(a) * rayon), roundi(5.5 + sin(a) * rayon), LAVANDE)
		t.p(7, 6, BLANC)
		t.p(6, 5, BLANC)
		t.entourer(VIOLET_SOMBRE)
	return img


## Un prisme : un cristal allongé à trois facettes, l'arête claire à gauche.
static func _prisme() -> Image:
	var img: Image = Commun.vierge("prisme")
	var t: Commun.Toile = Commun.toile(img, "prisme", 0)
	var corps: Array[Vector2] = [
		Vector2(6, 0.8),
		Vector2(10.6, 6.0),
		Vector2(8.6, 12.6),
		Vector2(3.4, 12.6),
		Vector2(1.4, 6.0)
	]
	Outils.polygone(t, corps, BLEU)
	var gauche: Array[Vector2] = [
		Vector2(6, 0.8), Vector2(1.4, 6.0), Vector2(3.4, 12.6), Vector2(6, 7.5)
	]
	Outils.polygone(t, gauche, CLAIR)
	var haut: Array[Vector2] = [
		Vector2(6, 0.8), Vector2(7.2, 3.0), Vector2(6, 4.2), Vector2(4.8, 3.0)
	]
	Outils.polygone(t, haut, BLANC)
	t.ligne(6, 7, 8, 12, NUIT)
	t.entourer(NUIT)
	return img


## Une lueur : une boule vive qui traîne trois flammèches, qui ondulent d'une image à l'autre.
static func _lueur() -> Image:
	var img: Image = Commun.vierge("lueur")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "lueur", i)
		t.disque(6.0, 5.0, 3.4, CLAIR)
		t.disque(6.5, 5.0, 2.0, BLANC)
		for k: int in 3:
			var y: int = 2 + k * 3 + (i if k % 2 == 0 else 1 - i)
			t.ligne(0, mini(y, 9), 3, mini(y, 9), BLEU)
		t.entourer(NUIT)
	return img


## Une vasque : un bassin d'acier plein d'une eau claire qui luit.
static func _vasque() -> Image:
	var img: Image = Commun.vierge("vasque")
	var t: Commun.Toile = Commun.toile(img, "vasque", 0)
	t.ellipse(7.0, 6.5, 6.4, 3.0, ACIER)
	t.ellipse(7.0, 4.2, 5.6, 2.2, CLAIR)
	t.ellipse(7.0, 3.8, 3.4, 1.0, BLANC)
	var pied: Array[Vector2] = [Vector2(4, 8), Vector2(10, 8), Vector2(11, 10), Vector2(3, 10)]
	Outils.polygone(t, pied, ACIER)
	t.p(2, 5, ACIER_CLAIR)
	t.entourer(NUIT)
	return img


## Le front d'une onde céleste : un arc qui s'ouvre vers la gauche, semé d'étoiles d'or.
static func _vague_celeste() -> Image:
	var img: Image = Commun.vierge("vague_celeste")
	var t: Commun.Toile = Commun.toile(img, "vague_celeste", 0)
	var centre: Vector2 = Vector2(-14.0, 16.0)
	for y: int in t.h:
		for x: int in t.w:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(centre)
			var bord: float = 25.5 - absf(y + 0.5 - 16.0) * 0.12
			if d > bord or d < bord - 6.0:
				continue
			if d > bord - 1.5:
				t.p(x, y, BLANC)
			elif d > bord - 3.5:
				t.p(x, y, CLAIR)
			else:
				t.p(x, y, BLEU)
	for v: Vector2i in [
		Vector2i(8, 4), Vector2i(5, 11), Vector2i(9, 18), Vector2i(6, 25), Vector2i(8, 29)
	]:
		t.p(v.x, v.y, OR)
		t.p(v.x - 1, v.y, OR)
		t.p(v.x, v.y - 1, OR)
		t.p(v.x + 1, v.y, OR)
		t.p(v.x, v.y + 1, OR)
	t.entourer(NUIT)
	return img


## L'impact du siphon : quatre pointes tirées vers le centre, qui se resserrent puis se perdent
## en un fil.
static func _eclat_siphon() -> Image:
	var img: Image = Commun.vierge("eclat_siphon")
	var rayons: Array[float] = [10.0, 7.0, 4.0]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "eclat_siphon", i)
		var r: float = rayons[i]
		for y: int in t.h:
			for x: int in t.w:
				var d: float = Vector2(x + 0.5 - 12.0, y + 0.5 - 12.0).length()
				if absf(d - r) <= 0.6:
					t.p(x, y, LAVANDE)
		for a: int in 4:
			var v: Vector2 = Vector2.from_angle(a * PI / 2.0 + PI / 4.0)
			var dehors: Vector2 = Vector2(12, 12) + v * (r + 2.0)
			var dedans: Vector2 = Vector2(12, 12) + v * (r - 3.0)
			Outils.trait_epais(t, dehors, dedans, 2.0, VIOLET)
			t.p(roundi(dedans.x), roundi(dedans.y), BLANC)
		t.disque(12.0, 12.0, 1.2 + (2 - i) * 0.4, BLANC)
		t.entourer(VIOLET_SOMBRE)
	var f4: Commun.Toile = Commun.toile(img, "eclat_siphon", 3)
	for k: int in 8:
		var p: Vector2 = (
			Vector2(12, 12) + Vector2.from_angle(k * PI / 4.0 + 0.4) * (3.0 + (k % 2) * 3.0)
		)
		f4.p(roundi(p.x), roundi(p.y), LAVANDE if k % 2 == 0 else VIOLET)
	f4.p(12, 12, BLANC)
	return img


## L'impact du prisme : la lumière blanche se fend en rayons de couleurs, puis en éclats.
static func _eclat_prisme() -> Image:
	var img: Image = Commun.vierge("eclat_prisme")
	var longueurs: Array[float] = [5.0, 9.0, 11.0]
	var teintes: Array[Color] = [CLAIR, OR, BLEU]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "eclat_prisme", i)
		var n: int = 4 + i * 2
		for k: int in n:
			var v: Vector2 = Vector2.from_angle(k * TAU / n - PI / 2.0)
			var fin: Vector2 = Vector2(12, 12) + v * longueurs[i]
			Outils.trait_epais(
				t, Vector2(12, 12) + v * 2.0, fin, 2.0 if i < 2 else 1.0, teintes[k % 3]
			)
		t.disque(12.0, 12.0, 2.6 - i * 0.6, BLANC)
		t.entourer(NUIT)
	var f4: Commun.Toile = Commun.toile(img, "eclat_prisme", 3)
	for k: int in 12:
		var p: Vector2 = (
			Vector2(12, 12) + Vector2.from_angle(k * TAU / 12.0) * (6.0 + (k % 3) * 2.0)
		)
		f4.p(roundi(p.x), roundi(p.y), teintes[k % 3])
	return img
