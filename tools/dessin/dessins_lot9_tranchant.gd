extends RefCounted
## Sprites d'effets d'attaques des armes tranchantes du lot 9 (T9.18) : couperet, rasoir, serpe de
## vigne et hache de garde. Style et palette de Tiny Swords (voir
## `tools/dessiner_effets_attaques.gd`) ; les lames regardent vers +x, le jeu les oriente.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const Outils := preload("res://tools/dessin/dessin_outils_lot9.gd")
const BLANC := Commun.ACIER_BLANC
const CLAIR := Commun.ACIER_CLAIR
const ACIER := Commun.ACIER
const ENCRE := Commun.ACIER_CONTOUR
const BOIS := Commun.BOIS
const BOIS_SOMBRE := Commun.BOIS_SOMBRE
const FEUILLE := Commun.POISON

const NOMS: PackedStringArray = ["couperet", "rasoir", "serpe", "hache"]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"couperet":
			return _couperet()
		"rasoir":
			return _rasoir()
		"serpe":
			return _serpe()
		"hache":
			return _hache()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Un couperet à dos de pointes : une lame carrée, trois épines sur le dos, un manche court. Il
## culbute : la seconde image est tournée de 40 degrés.
static func _couperet() -> Image:
	var img: Image = Commun.vierge("couperet")
	var lame: Array[Vector2] = [
		Vector2(5, 3), Vector2(12.5, 3), Vector2(12.5, 9.5), Vector2(5, 9.5)
	]
	var epines: Array[Array] = [
		[Vector2(6, 3), Vector2(7, 0.5), Vector2(8, 3)],
		[Vector2(8.5, 3), Vector2(9.5, 0.5), Vector2(10.5, 3)],
		[Vector2(11, 3), Vector2(12, 0.5), Vector2(13, 3)],
	]
	var manche: Array[Vector2] = [
		Vector2(0.5, 5.5), Vector2(5, 5.5), Vector2(5, 7.5), Vector2(0.5, 7.5)
	]
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "couperet", i)
		var angle: float = deg_to_rad(40.0) * i
		var centre: Vector2 = Vector2(7.0, 6.5)
		Outils.polygone(t, Outils.pivoter(manche, angle, centre), BOIS)
		Outils.polygone(t, Outils.pivoter(lame, angle, centre), CLAIR)
		var bas: Array[Vector2] = [
			Vector2(5, 7.5), Vector2(12.5, 7.5), Vector2(12.5, 9.5), Vector2(5, 9.5)
		]
		Outils.polygone(t, Outils.pivoter(bas, angle, centre), ACIER)
		var tranchant: Array[Vector2] = [
			Vector2(12, 3), Vector2(12.5, 3), Vector2(12.5, 9.5), Vector2(12, 9.5)
		]
		Outils.polygone(t, Outils.pivoter(tranchant, angle, centre), BLANC)
		for e: Array in epines:
			var pts: Array[Vector2] = []
			for v: Vector2 in e:
				pts.append(v)
			Outils.polygone(t, Outils.pivoter(pts, angle, centre), ACIER)
		t.entourer(ENCRE)
	return img


## Un rasoir droit : un manche gris, une lame large au dos épais et au fil blanc, qui tourne
## (horizontal, puis incliné de 45 degrés).
static func _rasoir() -> Image:
	var img: Image = Commun.vierge("rasoir")
	var manche: Array[Vector2] = [
		Vector2(0.6, 5.2), Vector2(4.4, 5.2), Vector2(4.4, 7.4), Vector2(0.6, 7.4)
	]
	var lame: Array[Vector2] = [
		Vector2(4.4, 3.6), Vector2(10.4, 3.6), Vector2(11.4, 7.6), Vector2(4.4, 7.6)
	]
	var fil: Array[Vector2] = [
		Vector2(4.4, 6.6), Vector2(11.2, 6.6), Vector2(11.4, 7.6), Vector2(4.4, 7.6)
	]
	var dos: Array[Vector2] = [
		Vector2(4.4, 3.6), Vector2(10.4, 3.6), Vector2(10.6, 4.8), Vector2(4.4, 4.8)
	]
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "rasoir", i)
		var angle: float = deg_to_rad(45.0) * i
		var centre: Vector2 = Vector2(6.0, 5.6)
		Outils.polygone(t, Outils.pivoter(manche, angle, centre), ACIER)
		Outils.polygone(t, Outils.pivoter(lame, angle, centre), CLAIR)
		Outils.polygone(t, Outils.pivoter(dos, angle, centre), ACIER)
		Outils.polygone(t, Outils.pivoter(fil, angle, centre), BLANC)
		var rivet: Vector2 = (Vector2(2.4, 6.3) - centre).rotated(angle) + centre
		t.p(int(rivet.x), int(rivet.y), ENCRE)
		t.entourer(ENCRE)
	return img


## Une serpe : un croissant d'acier au creux tourné vers le haut gauche, un manche, une vigne verte
## qui s'enroule autour et deux feuilles.
static func _serpe() -> Image:
	var img: Image = Commun.vierge("serpe")
	var t: Commun.Toile = Commun.toile(img, "serpe", 0)
	var centre: Vector2 = Vector2(9.5, 6.5)
	var creux: Vector2 = Vector2(7.2, 8.8)
	for y: int in t.h:
		for x: int in t.w:
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var d: float = p.distance_to(centre)
			if d > 6.0 or p.distance_to(creux) <= 5.0:
				continue
			if d > 4.9 and p.x > centre.x:
				t.p(x, y, BLANC)
			elif p.distance_to(creux) <= 6.1:
				t.p(x, y, ACIER)
			else:
				t.p(x, y, CLAIR)
	Outils.trait_epais(t, Vector2(2.0, 14.0), Vector2(6.5, 9.5), 2.0, BOIS)
	for v: Vector2i in [Vector2i(3, 12), Vector2i(5, 11), Vector2i(4, 13), Vector2i(6, 10)]:
		t.p(v.x, v.y, FEUILLE)
	t.ligne(4, 13, 6, 10, FEUILLE)
	for v: Vector2i in [Vector2i(1, 10), Vector2i(2, 10), Vector2i(2, 9)]:
		t.p(v.x, v.y, FEUILLE)
	for v: Vector2i in [Vector2i(7, 14), Vector2i(8, 14), Vector2i(8, 13)]:
		t.p(v.x, v.y, FEUILLE)
	t.entourer(ENCRE)
	return img


## Une hache de garde : un fer en demi-lune, un manche en diagonale.
static func _hache() -> Image:
	var img: Image = Commun.vierge("hache")
	var t: Commun.Toile = Commun.toile(img, "hache", 0)
	Outils.trait_epais(t, Vector2(2.0, 12.0), Vector2(9.0, 5.0), 2.2, BOIS)
	t.ligne(2, 13, 9, 6, BOIS_SOMBRE)
	var centre: Vector2 = Vector2(9.0, 5.0)
	for y: int in t.h:
		for x: int in t.w:
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var d: float = p.distance_to(centre)
			if d > 5.4 or (p.x - centre.x) + (p.y - centre.y) < -1.5:
				continue
			if d > 4.4:
				t.p(x, y, BLANC)
			elif d > 2.4:
				t.p(x, y, CLAIR)
			else:
				t.p(x, y, ACIER)
	t.entourer(ENCRE)
	return img
