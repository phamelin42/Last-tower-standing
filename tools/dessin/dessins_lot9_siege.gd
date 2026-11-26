extends RefCounted
## Sprites d'effets d'attaques des armes de siège du lot 9 (T9.18) : baril, maillet, pierres,
## obus, brasero, disques au sol (braises, ruines), onde de choc et la marque d'une bombe à mèche.
## Style et palette de Tiny Swords ; les projectiles regardent vers +x.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const Outils := preload("res://tools/dessin/dessin_outils_lot9.gd")
const BLANC := Commun.BLANC
const JAUNE := Commun.JAUNE
const ORANGE := Commun.ORANGE
const ROUGE := Commun.PLUME
const ROUGE_SOMBRE := Commun.ROUGE_SOMBRE
const FUMEE := Commun.FUMEE
const ENCRE := Commun.ACIER_CONTOUR
const ACIER := Commun.ACIER
const BOIS := Commun.BOIS
const BOIS_SOMBRE := Commun.BOIS_SOMBRE
const CUIVRE := Commun.CUIVRE
const ROCHE_CLAIRE := Commun.ROCHE_CLAIRE
const ROCHE := Commun.ROCHE
const ROCHE_CONTOUR := Commun.ROCHE_CONTOUR
const CORPS := Commun.BOMBE_CORPS
const REFLET := Commun.BOMBE_REFLET
const RUNE_FORGE := Commun.RUNE_FORGE

const NOMS: PackedStringArray = [
	"baril",
	"maillet",
	"pierre_lestee",
	"obus",
	"brasero",
	"creneau",
	"gravats",
	"bloc_colosse",
	"disque_braise",
	"disque_ruines",
	"onde_choc",
	"bombe_meche",
]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"baril":
			return _baril()
		"maillet":
			return _maillet()
		"pierre_lestee":
			return _pierre_lestee()
		"obus":
			return _obus()
		"brasero":
			return _brasero()
		"creneau":
			return _creneau()
		"gravats":
			return _gravats()
		"bloc_colosse":
			return _bloc_colosse()
		"disque_braise":
			return _disque_braise()
		"disque_ruines":
			return _disque_ruines()
		"onde_choc":
			return _onde_choc()
		"bombe_meche":
			return _bombe_meche()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Un baril de poudre cerclé de fer, une mèche qui crache une étincelle (deux images).
static func _baril() -> Image:
	var img: Image = Commun.vierge("baril")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "baril", i)
		t.ellipse(6.0, 8.6, 5.4, 5.4, BOIS)
		for y: int in range(4, 13):
			t.p(3, y, BOIS_SOMBRE)
			t.p(9, y, BOIS_SOMBRE)
		for y: int in [5, 6, 11, 12]:
			for x: int in range(1, 11):
				if t.opaque(x, y):
					t.p(x, y, ACIER)
		t.disque(6.2, 8.8, 1.5, ROUGE)
		t.ligne(6, 3, 7, 2, BOIS_SOMBRE)
		t.p(8, 1, JAUNE)
		t.p(8 + i, 0, JAUNE)
		t.entourer(ENCRE)
	return img


## Un maillet de rempart : une masse de pierre cerclée de fer au bout d'un manche court.
static func _maillet() -> Image:
	var img: Image = Commun.vierge("maillet")
	var t: Commun.Toile = Commun.toile(img, "maillet", 0)
	t.ligne(1, 6, 9, 6, BOIS)
	t.ligne(1, 7, 9, 7, BOIS)
	for y: int in range(1, 13):
		for x: int in range(8, 15):
			t.p(x, y, ROCHE_CLAIRE if y < 7 else ROCHE)
	for y: int in range(1, 13):
		t.p(9, y, ACIER)
		t.p(13, y, ACIER)
	t.ligne(10, 2, 12, 2, BLANC)
	t.entourer(ENCRE)
	return img


## Une pierre cerclée d'une bande de fer, un lest de plomb pendu dessous.
static func _pierre_lestee() -> Image:
	var img: Image = Commun.vierge("pierre_lestee")
	var t: Commun.Toile = Commun.toile(img, "pierre_lestee", 0)
	t.ellipse(7.0, 5.2, 6.2, 4.6, ROCHE_CLAIRE)
	for y: int in range(6, 9):
		for x: int in range(1, 13):
			if t.opaque(x, y):
				t.p(x, y, ROCHE)
	for y: int in range(1, 9):
		t.p(6, y, ACIER)
		t.p(7, y, ACIER)
	t.p(6, 2, BLANC)
	for y: int in range(8, 11):
		for x: int in range(4, 10):
			t.p(x, y, ACIER if y > 8 else CORPS)
	t.entourer(ROCHE_CONTOUR)
	return img


## Un obus long, le nez de cuivre vers +x, une étincelle à la queue (deux images).
static func _obus() -> Image:
	var img: Image = Commun.vierge("obus")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "obus", i)
		for y: int in range(1, 7):
			for x: int in range(2, 11):
				t.p(x, y, CORPS)
		var nez: Array[Vector2] = [Vector2(10, 0.8), Vector2(15.6, 4.0), Vector2(10, 7.2)]
		Outils.polygone(t, nez, CUIVRE)
		t.ligne(11, 3, 14, 3, JAUNE)
		t.ligne(3, 2, 9, 2, REFLET)
		for y: int in range(1, 7):
			t.p(4, y, CUIVRE)
		t.p(1, 3, JAUNE if i == 0 else ORANGE)
		t.p(1, 4, ORANGE if i == 0 else JAUNE)
		t.p(0, 4 - i, JAUNE)
		t.entourer(ENCRE)
	return img


## Un brasero de fer plein de braises : la flamme change de forme d'une image à l'autre.
static func _brasero() -> Image:
	var img: Image = Commun.vierge("brasero")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "brasero", i)
		var flamme: Array[Vector2] = [
			Vector2(2.5, 6.5),
			Vector2(4.0 + i, 2.5 - i),
			Vector2(6.0, 5.0),
			Vector2(7.5 - i, 1.5),
			Vector2(9.5, 6.5)
		]
		Outils.polygone(t, flamme, ORANGE)
		var coeur: Array[Vector2] = [Vector2(4.5, 6.5), Vector2(6.0, 3.8 + i), Vector2(7.5, 6.5)]
		Outils.polygone(t, coeur, JAUNE)
		for y: int in range(7, 11):
			t.ligne(y - 6, y, 11 - (y - 6), y, CORPS)
		t.ligne(1, 7, 10, 7, REFLET)
		t.p(4, 11, CORPS)
		t.p(7, 11, CORPS)
		t.p(4, 7, RUNE_FORGE)
		t.p(7, 7, JAUNE)
		t.entourer(ENCRE)
	return img


## Un morceau de créneau arraché au rempart : deux merlons sur un bloc maçonné.
static func _creneau() -> Image:
	var img: Image = Commun.vierge("creneau")
	var t: Commun.Toile = Commun.toile(img, "creneau", 0)
	for y: int in range(5, 13):
		for x: int in range(1, 13):
			t.p(x, y, ROCHE_CLAIRE if y < 9 else ROCHE)
	for x: int in [1, 2, 3, 4, 8, 9, 10, 11]:
		for y: int in range(1, 5):
			t.p(x, y, ROCHE_CLAIRE)
	for y: int in range(1, 13):
		t.p(12 if y > 4 else 11, y, ROCHE)
	t.ligne(1, 8, 12, 8, ROCHE)
	t.ligne(6, 5, 6, 8, ROCHE)
	t.ligne(3, 9, 3, 12, ROCHE_CONTOUR)
	t.ligne(9, 9, 9, 12, ROCHE_CONTOUR)
	t.ligne(2, 2, 3, 2, BLANC)
	t.entourer(ROCHE_CONTOUR)
	return img


## Un tas de gravats : trois pierres entassées et un peu de poussière.
static func _gravats() -> Image:
	var img: Image = Commun.vierge("gravats")
	var t: Commun.Toile = Commun.toile(img, "gravats", 0)
	t.ellipse(3.6, 6.6, 3.0, 2.6, ROCHE)
	t.ellipse(8.2, 6.2, 3.4, 3.0, ROCHE_CLAIRE)
	t.ellipse(6.0, 3.6, 2.8, 2.4, ROCHE_CLAIRE)
	for v: Vector2i in [Vector2i(7, 5), Vector2i(5, 3), Vector2i(2, 6)]:
		t.p(v.x, v.y, BLANC)
	t.ligne(7, 8, 10, 8, ROCHE)
	t.entourer(ROCHE_CONTOUR)
	t.p(0, 1, FUMEE)
	t.p(11, 2, FUMEE)
	return img


## Le bloc du colosse de pierre : un rocher énorme, fendu, deux yeux de forge allumés.
static func _bloc_colosse() -> Image:
	var img: Image = Commun.vierge("bloc_colosse")
	var t: Commun.Toile = Commun.toile(img, "bloc_colosse", 0)
	t.ellipse(9.0, 8.0, 8.4, 7.2, ROCHE_CLAIRE)
	for y: int in range(9, 16):
		for x: int in range(0, 18):
			if t.opaque(x, y):
				t.p(x, y, ROCHE)
	t.ligne(9, 1, 8, 3, ROCHE_CONTOUR)
	t.ligne(8, 3, 10, 5, ROCHE_CONTOUR)
	t.ligne(5, 11, 8, 13, ROCHE_CONTOUR)
	t.p(5, 5, RUNE_FORGE)
	t.p(6, 5, JAUNE)
	t.p(11, 6, RUNE_FORGE)
	t.p(12, 6, JAUNE)
	t.ligne(7, 10, 11, 10, ROCHE_CONTOUR)
	t.ligne(3, 3, 5, 2, BLANC)
	t.entourer(ROCHE_CONTOUR)
	return img


## Le disque au sol des braises : une bague de feu sur un sol noirci, des braises qui pulsent.
static func _disque_braise() -> Image:
	var img: Image = Commun.vierge("disque_braise")
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "disque_braise", i)
		var f: float = 0.7 if i == 0 else 1.0
		for y: int in t.h:
			for x: int in t.w:
				var u: float = (x + 0.5 - 16.0) / (15.2 * f)
				var v: float = (y + 0.5 - 8.0) / (7.2 * f)
				var d: float = u * u + v * v
				if d > 1.0:
					continue
				if d > 0.78:
					t.p(x, y, JAUNE if i == 2 else ORANGE)
				elif d > 0.62:
					t.p(x, y, ROUGE_SOMBRE)
				elif (x + y) % 2 == 0:
					t.p(x, y, ENCRE)
				elif (x * 7 + y * 13 + i * 5) % 9 == 0:
					t.p(x, y, ORANGE if i != 1 else JAUNE)
		t.p(16, 8, BLANC if i == 2 else JAUNE)
	return img


## Le disque au sol des ruines : une bague de gravats, un sol tramé, des pierres qui se détachent.
static func _disque_ruines() -> Image:
	var img: Image = Commun.vierge("disque_ruines")
	var pierres: Array[Vector2i] = [
		Vector2i(8, 6),
		Vector2i(23, 5),
		Vector2i(12, 10),
		Vector2i(20, 11),
		Vector2i(16, 4),
		Vector2i(27, 8),
	]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "disque_ruines", i)
		var f: float = 0.7 if i == 0 else 1.0
		for y: int in t.h:
			for x: int in t.w:
				var u: float = (x + 0.5 - 16.0) / (15.2 * f)
				var v: float = (y + 0.5 - 8.0) / (7.2 * f)
				var d: float = u * u + v * v
				if d > 1.0:
					continue
				if d > 0.8:
					t.p(x, y, ROCHE_CLAIRE if (x / 2) % 2 == 0 else ROCHE)
				elif d > 0.64:
					t.p(x, y, ROCHE_CONTOUR)
				elif (x + y) % 2 == 0:
					t.p(x, y, ROCHE_CONTOUR)
		for k: int in pierres.size():
			if k > i * 2 + 1:
				continue
			var c: Vector2i = pierres[k]
			t.p(c.x, c.y, ROCHE_CLAIRE)
			t.p(c.x + 1, c.y, ROCHE_CLAIRE)
			t.p(c.x, c.y + 1, ROCHE)
			t.p(c.x + 1, c.y + 1, ROCHE)
		t.p(16, 8, BLANC if i == 2 else ROCHE_CLAIRE)
	return img


## Une onde de choc : un anneau de poussière qui s'élargit, des éclats qui fuient, puis la
## poussière qui retombe (cinq images).
static func _onde_choc() -> Image:
	var img: Image = Commun.vierge("onde_choc")
	var rayons: Array[float] = [4.0, 8.0, 12.0, 14.5, 15.0]
	for i: int in 5:
		var t: Commun.Toile = Commun.toile(img, "onde_choc", i)
		var r: float = rayons[i]
		for y: int in t.h:
			for x: int in t.w:
				var d: float = Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length()
				var ecart: float = absf(d - r)
				if ecart > (1.9 if i < 3 else 1.3):
					continue
				if i >= 3 and (x + y) % 2 == 1:
					continue
				t.p(x, y, ROCHE_CLAIRE if d >= r else ROCHE)
		if i < 4:
			for k: int in 8:
				var dir: Vector2 = Vector2.from_angle(k * PI / 4.0 + PI / 8.0)
				var p: Vector2 = Vector2(16.0, 16.0) + dir * r * 0.6
				t.p(roundi(p.x), roundi(p.y), BLANC if i == 0 else FUMEE)
				t.p(roundi(p.x) + 1, roundi(p.y), ROCHE_CONTOUR)
	return img


## La marque d'une bombe : une bombe ronde, une mèche allumée et un anneau rouge qui se resserre
## (trois images : l'anneau, d'abord en tirets, se ferme et la mèche raccourcit).
static func _bombe_meche() -> Image:
	var img: Image = Commun.vierge("bombe_meche")
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "bombe_meche", i)
		t.disque(9.0, 11.0, 5.2, CORPS)
		t.ellipse(7.4, 9.0, 2.2, 1.6, REFLET)
		t.p(6, 8, REFLET)
		var bout: Vector2i = Vector2i(11, 5 - i)
		t.ligne(9, 6, bout.x, bout.y, REFLET)
		var etincelle: Color = JAUNE if i % 2 == 0 else ORANGE
		t.p(bout.x + 1, bout.y - 1, etincelle)
		t.p(bout.x + 1, bout.y, JAUNE)
		t.p(bout.x, bout.y - 1, ORANGE)
		t.entourer(ENCRE)
		for k: int in 48:
			if i == 0 and k % 2 == 0 or i == 1 and k % 3 == 0:
				continue
			var p: Vector2 = Vector2(9.0, 10.0) + Vector2.from_angle(k * TAU / 48.0) * 7.8
			t.p(roundi(p.x - 0.5), roundi(p.y - 0.5), ROUGE)
	return img
