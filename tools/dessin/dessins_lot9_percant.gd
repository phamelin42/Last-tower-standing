extends RefCounted
## Sprites d'effets d'attaques des armes perçantes du lot 9 (T9.18) : javeline, flèche marquante,
## lance épineuse. Style et palette de Tiny Swords ; les pointes regardent vers +x.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const Outils := preload("res://tools/dessin/dessin_outils_lot9.gd")
const BLANC := Commun.ACIER_BLANC
const CLAIR := Commun.ACIER_CLAIR
const ENCRE := Commun.ACIER_CONTOUR
const BOIS := Commun.BOIS
const BOIS_SOMBRE := Commun.BOIS_SOMBRE
const PLUME := Commun.PLUME
const JAUNE := Commun.JAUNE
const ORANGE := Commun.ORANGE
const EPINE := Commun.POISON

const NOMS: PackedStringArray = ["javeline", "fleche_marquante", "lance_epineuse"]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"javeline":
			return _javeline()
		"fleche_marquante":
			return _fleche_marquante()
		"lance_epineuse":
			return _lance_epineuse()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Une javeline : longue hampe, fer en feuille, deux plumes rouges à l'arrière.
static func _javeline() -> Image:
	var img: Image = Commun.vierge("javeline")
	var t: Commun.Toile = Commun.toile(img, "javeline", 0)
	t.ligne(4, 3, 17, 3, BOIS)
	t.ligne(4, 4, 17, 4, BOIS_SOMBRE)
	var fer: Array[Vector2] = [
		Vector2(16, 3.5), Vector2(19, 1.2), Vector2(23.2, 3.9), Vector2(19, 6.8)
	]
	Outils.polygone(t, fer, CLAIR)
	t.ligne(18, 3, 22, 3, BLANC)
	for v: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)]:
		t.p(v.x, v.y, PLUME)
		t.p(v.x, 6 - v.y, PLUME)
	t.entourer(ENCRE)
	return img


## Une flèche dont le fer brille d'un cercle de cible : on la reconnaît à son éclat orange, qui
## annonce la marque posée sur l'ennemi touché.
static func _fleche_marquante() -> Image:
	var img: Image = Commun.vierge("fleche_marquante")
	var t: Commun.Toile = Commun.toile(img, "fleche_marquante", 0)
	t.ligne(3, 3, 13, 3, BOIS)
	t.ligne(3, 4, 13, 4, BOIS_SOMBRE)
	var fer: Array[Vector2] = [Vector2(12, 0.6), Vector2(19.4, 4.0), Vector2(12, 7.4)]
	Outils.polygone(t, fer, ORANGE)
	t.ligne(13, 4, 18, 4, JAUNE)
	t.p(14, 2, JAUNE)
	t.p(14, 6, JAUNE)
	for v: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		t.p(v.x, v.y, PLUME)
		t.p(v.x, 7 - v.y, PLUME)
	t.entourer(ENCRE)
	return img


## Une lance épaisse, hérissée de trois épines vertes de chaque côté de la hampe.
static func _lance_epineuse() -> Image:
	var img: Image = Commun.vierge("lance_epineuse")
	var t: Commun.Toile = Commun.toile(img, "lance_epineuse", 0)
	Outils.trait_epais(t, Vector2(1.5, 4.0), Vector2(14.0, 4.0), 2.2, BOIS)
	t.ligne(2, 4, 14, 4, BOIS_SOMBRE)
	for x: int in [4, 7, 10]:
		t.p(x, 1, EPINE)
		t.p(x + 1, 2, EPINE)
		t.p(x, 7, EPINE)
		t.p(x + 1, 6, EPINE)
	var fer: Array[Vector2] = [Vector2(13, 1.8), Vector2(21.8, 4.0), Vector2(13, 6.2)]
	Outils.polygone(t, fer, CLAIR)
	t.ligne(14, 4, 20, 4, BLANC)
	t.entourer(ENCRE)
	return img
