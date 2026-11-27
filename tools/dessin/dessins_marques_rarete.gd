extends RefCounted
## Les marques de rareté des armes de fin de partie et le tapis de la couronne du vide : des formes
## neutres (blanc, gris, encre) que la teinte de la rareté colore dans le jeu, lisibles sans elle.
## Ancestrale : une traînée de tirets derrière le tir, des braises qui montent à l'impact.
## Souveraine : une petite étoile à quatre branches qui scintille derrière le tir, puis à l'impact.
## Les projectiles regardent vers +x : la traînée et l'étoile sont à gauche du centre de la case.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.BLANC
const CLAIR := Commun.GRIS_CLAIR
const GRIS := Commun.VAPEUR
const ENCRE := Commun.ACIER_CONTOUR
const VIOLET := Commun.CHAOS_VIOLET
const MAGENTA := Commun.CHAOS_MAGENTA
const NUIT := Commun.CHAOS_NUIT
const OR := Commun.CHAOS_OR

const NOMS: PackedStringArray = [
	"marque_traine", "marque_braises", "marque_etoile", "marque_eclat", "disque_vide"
]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"marque_traine":
			return _traine()
		"marque_braises":
			return _braises()
		"marque_etoile":
			return _etoile()
		"marque_eclat":
			return _eclat()
		"disque_vide":
			return _disque_vide()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Trois tirets qui s'amincissent, du centre de la case vers la gauche.
static func _traine() -> Image:
	var img: Image = Commun.vierge("marque_traine")
	var t: Commun.Toile = Commun.toile(img, "marque_traine", 0)
	for x: int in range(7, 12):
		t.p(x, 4, CLAIR)
		t.p(x, 5, BLANC)
		t.p(x, 6, BLANC)
		t.p(x, 7, CLAIR)
	for x: int in range(3, 6):
		t.p(x, 5, CLAIR)
		t.p(x, 6, GRIS)
	for x: int in range(0, 2):
		t.p(x, 5, GRIS)
	t.entourer(ENCRE)
	return img


## Trois traits qui montent d'un cran à chaque image, puis rétrécissent et s'effacent.
static func _braises() -> Image:
	var img: Image = Commun.vierge("marque_braises")
	var hauteurs: Array[int] = [4, 5, 4, 3]
	var bas: Array[int] = [16, 13, 10, 7]
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "marque_braises", i)
		for k: int in 3:
			var x: int = 4 + k * 6
			var h: int = hauteurs[i] + (2 if k == 1 else 0)
			for y: int in h:
				var haut: int = bas[i] - y - (3 if k != 1 else 0)
				t.p(x, haut, BLANC if y == h - 1 else CLAIR)
				t.p(x + 1, haut, CLAIR if y == h - 1 else GRIS)
		t.entourer(ENCRE)
	return img


## Une étoile à quatre branches (un cœur blanc, des branches claires) qui s'allonge puis rentre.
static func _etoile() -> Image:
	var img: Image = Commun.vierge("marque_etoile")
	var longueurs: Array[int] = [3, 4, 2]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "marque_etoile", i)
		_branches(t, 5, 6, longueurs[i])
		t.entourer(ENCRE)
	return img


## Un éclat d'étoile, plus grand, en haut à droite du point d'impact : naît, grandit, se disperse.
static func _eclat() -> Image:
	var img: Image = Commun.vierge("marque_eclat")
	var longueurs: Array[int] = [2, 4, 5, 3]
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "marque_eclat", i)
		_branches(t, 14, 6, longueurs[i])
		if i == 2:
			for v: Vector2i in [Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(3, 3)]:
				t.p(14 + v.x, 6 + v.y, GRIS)
		t.entourer(ENCRE)
	return img


static func _branches(t: Commun.Toile, cx: int, cy: int, longueur: int) -> void:
	t.p(cx, cy, BLANC)
	for k: int in range(1, longueur + 1):
		var c: Color = CLAIR if k < longueur else GRIS
		t.p(cx - k, cy, c)
		t.p(cx + k, cy, c)
		t.p(cx, cy - k, c)
		t.p(cx, cy + k, c)


## Le tapis de la couronne du vide : deux anneaux nus qui laissent voir le sol, une étoile qui
## pulse en son centre et quatre éclats sur le bord. Aucun gravat : il ne ressemble pas aux ruines.
static func _disque_vide() -> Image:
	var img: Image = Commun.vierge("disque_vide")
	var branches: Array[int] = [4, 6, 5]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "disque_vide", i)
		for y: int in t.h:
			for x: int in t.w:
				var u: float = (x + 0.5 - 16.0) / 15.2
				var v: float = (y + 0.5 - 8.0) / 7.2
				var d: float = sqrt(u * u + v * v)
				if d > 1.0:
					continue
				if d > 0.9:
					t.p(x, y, NUIT)
				elif d > 0.78:
					t.p(x, y, MAGENTA if x % 4 < 3 else VIOLET)
				elif d > 0.7:
					t.p(x, y, NUIT)
				elif d > 0.42 and d < 0.56:
					t.p(x, y, VIOLET)
		for k: int in range(-branches[i], branches[i] + 1):
			t.p(16 + k, 8, OR if absi(k) > 1 else BLANC)
		for k: int in range(-branches[i] / 2, branches[i] / 2 + 1):
			t.p(16, 8 + k, OR if absi(k) > 1 else BLANC)
		for v: Vector2i in [Vector2i(-11, 0), Vector2i(11, 0), Vector2i(0, -5), Vector2i(0, 5)]:
			t.p(16 + v.x, 8 + v.y, BLANC if i == 2 else OR)
	return img
