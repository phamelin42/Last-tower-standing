extends RefCounted
## Sprites d'effets d'attaques, élément partagés (étincelle, départ) : style et palette de Tiny
## Swords (voir `tools/dessiner_effets_attaques.gd`).

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.BLANC
const FOUDRE_LAVANDE := Commun.FOUDRE_LAVANDE
const FOUDRE_SOMBRE := Commun.FOUDRE_SOMBRE
const FOUDRE_VIOLET := Commun.FOUDRE_VIOLET
const GRIS_CLAIR := Commun.GRIS_CLAIR

const NOMS: PackedStringArray = ["etincelle", "depart"]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"etincelle":
			return _etincelle()
		"depart":
			return _depart()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


static func _etincelle() -> Image:
	var img: Image = Commun.vierge("etincelle")
	var f1: Commun.Toile = Commun.toile(img, "etincelle", 0)
	f1.disque(4.0, 4.0, 1.4, BLANC)
	for v: Vector2i in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 5), Vector2i(4, 5)]:
		f1.p(v.x, v.y, FOUDRE_LAVANDE)
		f1.p(v.y, v.x, FOUDRE_LAVANDE)
	for v: Vector2i in [Vector2i(3, 1), Vector2i(4, 1), Vector2i(3, 6), Vector2i(4, 6)]:
		f1.p(v.x, v.y, FOUDRE_VIOLET)
		f1.p(v.y, v.x, FOUDRE_VIOLET)
	f1.entourer(FOUDRE_SOMBRE)
	var f2: Commun.Toile = Commun.toile(img, "etincelle", 1)
	f2.disque(4.0, 4.0, 1.4, BLANC)
	for v: Vector2i in [Vector2i(2, 2), Vector2i(5, 5), Vector2i(2, 5), Vector2i(5, 2)]:
		f2.p(v.x, v.y, FOUDRE_LAVANDE)
	for v: Vector2i in [Vector2i(1, 1), Vector2i(6, 6), Vector2i(1, 6), Vector2i(6, 1)]:
		f2.p(v.x, v.y, FOUDRE_VIOLET)
	f2.entourer(FOUDRE_SOMBRE)
	var f3: Commun.Toile = Commun.toile(img, "etincelle", 2)
	f3.p(3, 3, BLANC)
	f3.p(4, 4, BLANC)
	f3.p(3, 4, FOUDRE_LAVANDE)
	f3.p(4, 3, FOUDRE_LAVANDE)
	for v: Vector2i in [Vector2i(2, 3), Vector2i(5, 4), Vector2i(3, 2), Vector2i(4, 5)]:
		f3.p(v.x, v.y, FOUDRE_VIOLET)
	f3.entourer(FOUDRE_SOMBRE)
	var f4: Commun.Toile = Commun.toile(img, "etincelle", 3)
	for v: Vector2i in [
		Vector2i(1, 1), Vector2i(6, 1), Vector2i(1, 6), Vector2i(6, 6), Vector2i(3, 0)
	]:
		f4.p(v.x, v.y, FOUDRE_VIOLET)
	f4.p(2, 5, FOUDRE_LAVANDE)
	f4.p(5, 2, FOUDRE_LAVANDE)
	f4.p(4, 4, BLANC)
	return img


static func _depart() -> Image:
	var img: Image = Commun.vierge("depart")
	var f1: Commun.Toile = Commun.toile(img, "depart", 0)
	f1.disque(6.0, 6.0, 1.2, BLANC)
	var f2: Commun.Toile = Commun.toile(img, "depart", 1)
	for a: int in 4:
		var v: Vector2 = Vector2.from_angle(a * PI / 2.0)
		f2.ligne(6, 6, 6 + roundi(v.x * 3), 6 + roundi(v.y * 3), BLANC)
		f2.p(6 + roundi(v.x * 4), 6 + roundi(v.y * 4), GRIS_CLAIR)
		var w: Vector2 = Vector2.from_angle(a * PI / 2.0 + PI / 4.0)
		f2.p(6 + roundi(w.x * 2), 6 + roundi(w.y * 2), GRIS_CLAIR)
	f2.disque(6.0, 6.0, 1.5, BLANC)
	var f3: Commun.Toile = Commun.toile(img, "depart", 2)
	for y: int in f3.h:
		for x: int in f3.w:
			var d: float = Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0).length()
			if absf(d - 4.6) <= 0.7 and (x + y) % 2 == 0:
				f3.p(x, y, GRIS_CLAIR)
	for a: int in 4:
		var v: Vector2 = Vector2.from_angle(a * PI / 2.0) * 4.5
		f3.p(6 + roundi(v.x - 0.5), 6 + roundi(v.y - 0.5), BLANC)
	return img
