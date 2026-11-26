extends RefCounted
## Les marques des mécaniques propres du lot 9 (T9.18), faites pour se lire d'un coup d'œil :
## rayons d'un tir tournant, disques au sol d'une zone posée, marqueur de vulnérabilité. Style et
## palette de Tiny Swords (voir `tools/dessiner_effets_attaques.gd`). Les rayons sont gris clair :
## le jeu les teinte de la couleur de l'arme.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const Outils := preload("res://tools/dessin/dessin_outils_lot9.gd")
const BLANC := Commun.BLANC
const CLAIR := Commun.ACIER_CLAIR
const ACIER := Commun.ACIER
const ENCRE := Commun.ACIER_CONTOUR
const RUNE_CLAIR := Commun.ARCANE_CLAIR
const RUNE_BLEU := Commun.ARCANE_BLEU
const RUNE_NUIT := Commun.ARCANE_NUIT
const ORAGE_LAVANDE := Commun.FOUDRE_LAVANDE
const ORAGE_VIOLET := Commun.FOUDRE_VIOLET
const ORAGE_SOMBRE := Commun.FOUDRE_SOMBRE
const JAUNE := Commun.JAUNE
const ORANGE := Commun.ORANGE
const FISSURE := Commun.ROUGE_SOMBRE

const NOMS: PackedStringArray = ["rayons", "disque_rune", "disque_orage", "vulnerable"]
## Un tir tournant a de 2 à 6 branches : une image par nombre de branches.
const BRANCHES_MIN: int = 2
const RAYON_RAYONS: float = 14.0


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"rayons":
			return _rayons()
		"disque_rune":
			return _disque_rune()
		"disque_orage":
			return _disque_orage()
		"vulnerable":
			return _vulnerable()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Image `n - 2` : `n` rayons à égale distance, un moyeu au centre, la pointe de chaque rayon
## blanche. La première branche monte (−90 degrés).
static func _rayons() -> Image:
	var img: Image = Commun.vierge("rayons")
	for i: int in Commun.PLANCHES["rayons"]["images"]:
		var t: Commun.Toile = Commun.toile(img, "rayons", i)
		var n: int = BRANCHES_MIN + i
		var centre: Vector2 = Vector2(16.0, 16.0)
		for k: int in n:
			var v: Vector2 = Vector2.from_angle(-PI / 2.0 + k * TAU / n)
			Outils.trait_epais(t, centre + v * 3.0, centre + v * RAYON_RAYONS, 3.0, CLAIR)
			Outils.trait_epais(t, centre + v * 8.0, centre + v * RAYON_RAYONS, 2.0, ACIER)
			var pointe: Vector2 = centre + v * (RAYON_RAYONS - 1.0)
			t.disque(pointe.x, pointe.y, 1.6, BLANC)
		t.disque(16.0, 16.0, 3.4, ACIER)
		t.disque(16.0, 16.0, 2.0, BLANC)
		t.entourer(ENCRE)
	return img


## Le disque au sol d'une rune de veille : une bague bleue sur l'herbe, des repères en croix, un
## sol tramé. Il s'ouvre (image 1), se pose (image 2) et pulse (image 3).
static func _disque_rune() -> Image:
	var img: Image = Commun.vierge("disque_rune")
	var rayons: Array[float] = [0.7, 1.0, 1.0]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "disque_rune", i)
		var f: float = rayons[i]
		for y: int in t.h:
			for x: int in t.w:
				var u: float = (x + 0.5 - 16.0) / (15.2 * f)
				var v: float = (y + 0.5 - 8.0) / (7.2 * f)
				var d: float = u * u + v * v
				if d > 1.0:
					continue
				if d > 0.78:
					t.p(x, y, RUNE_CLAIR if i == 2 else RUNE_BLEU)
				elif d > 0.62:
					t.p(x, y, RUNE_NUIT)
				elif (x + y) % 2 == 0:
					t.p(x, y, RUNE_NUIT)
		for a: int in 4:
			var dir: Vector2 = Vector2.from_angle(a * PI / 2.0 + PI / 4.0)
			t.p(roundi(16.0 + dir.x * 11.0 * f), roundi(8.0 + dir.y * 5.0 * f), RUNE_CLAIR)
		t.p(16, 8, BLANC if i == 2 else RUNE_CLAIR)
	return img


## Le disque d'une cage d'orage : une bague violette, quatre barreaux d'éclairs debout.
static func _disque_orage() -> Image:
	var img: Image = Commun.vierge("disque_orage")
	var hauteurs: Array[int] = [3, 6, 7]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "disque_orage", i)
		for y: int in t.h:
			for x: int in t.w:
				var u: float = (x + 0.5 - 16.0) / 15.2
				var v: float = (y + 0.5 - 8.0) / 7.2
				var d: float = u * u + v * v
				if d > 1.0:
					continue
				if d > 0.76:
					t.p(x, y, ORAGE_LAVANDE if i == 2 else ORAGE_VIOLET)
				elif d > 0.6:
					t.p(x, y, ORAGE_SOMBRE)
				elif (x + y) % 3 == 0:
					t.p(x, y, ORAGE_SOMBRE)
		for bx: int in [7, 13, 19, 25]:
			var by: int = 8 + (1 if bx % 12 == 7 else -1) * 0
			for k: int in hauteurs[i]:
				var decale: int = bx + (1 if k % 2 == 0 else 0)
				t.p(decale, by - k, ORAGE_LAVANDE if k % 2 == 0 else JAUNE)
			t.p(bx, by + 1, ORAGE_SOMBRE)
	return img


## Le marqueur d'une vulnérabilité : une cible fêlée au-dessus de l'ennemi, deux pulsations.
static func _vulnerable() -> Image:
	var img: Image = Commun.vierge("vulnerable")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "vulnerable", i)
		var r: float = 4.8 + i * 0.8
		for y: int in t.h:
			for x: int in t.w:
				var d: float = Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0).length()
				if absf(d - r) <= 0.8:
					t.p(x, y, ORANGE)
		t.disque(6.0, 6.0, 1.6, JAUNE)
		t.ligne(6, 6, 9, 3, FISSURE)
		t.ligne(6, 6, 3, 9, FISSURE)
		t.ligne(9, 3, 11, 3, FISSURE)
		t.p(5, 5, BLANC)
		t.entourer(ENCRE)
	return img
