extends RefCounted
## Sprites d'effets d'attaques, élément bombe (bombe, ombre) : style et palette de Tiny
## Swords (voir `tools/dessiner_effets_attaques.gd`).

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.BLANC
const BOMBE_CONTOUR := Commun.BOMBE_CONTOUR
const BOMBE_CORPS := Commun.BOMBE_CORPS
const BOMBE_MECHE := Commun.BOMBE_MECHE
const BOMBE_REFLET := Commun.BOMBE_REFLET
const ENCRE := Commun.ENCRE
const JAUNE := Commun.JAUNE

const NOMS: PackedStringArray = ["bombe", "ombre"]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"bombe":
			return _bombe()
		"ombre":
			return _ombre()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


static func _bombe() -> Image:
	var img: Image = Commun.vierge("bombe")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "bombe", i)
		t.disque(5.5, 7.5, 3.6, BOMBE_CORPS)
		for v: Vector2i in [Vector2i(3, 5), Vector2i(4, 5), Vector2i(3, 6)]:
			t.p(v.x, v.y, BOMBE_REFLET)
		t.entourer(BOMBE_CONTOUR)
		for v: Vector2i in [Vector2i(5, 2), Vector2i(6, 2), Vector2i(6, 1)]:
			t.p(v.x, v.y, BOMBE_MECHE)
		if i == 0:
			for v: Vector2i in [Vector2i(6, 0), Vector2i(8, 0), Vector2i(7, 1)]:
				t.p(v.x, v.y, JAUNE)
			t.p(7, 0, BLANC)
		else:
			for v: Vector2i in [Vector2i(7, 0), Vector2i(9, 0), Vector2i(7, 2), Vector2i(9, 2)]:
				t.p(v.x, v.y, JAUNE)
			t.p(8, 1, BLANC)
	return img


static func _ombre() -> Image:
	var img: Image = Commun.vierge("ombre")
	Commun.toile(img, "ombre", 0).ellipse(6.0, 3.0, 5.8, 2.8, ENCRE)
	return img
