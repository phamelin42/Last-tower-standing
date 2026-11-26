extends RefCounted
## Sprites d'effets d'attaques, armes de siège (pétard, trébuchet, mine de forge) : style et
## palette de Tiny Swords (voir `tools/dessiner_effets_attaques.gd`). La grande bombarde reprend
## la bombe et l'explosion du pack.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.BLANC
const JAUNE := Commun.JAUNE
const ROUGE := Commun.PLUME
const ROUGE_SOMBRE := Commun.ROUGE_SOMBRE
const ENCRE := Commun.ENCRE
const MECHE := Commun.BOMBE_MECHE
const ROCHE_CLAIRE := Commun.ROCHE_CLAIRE
const ROCHE := Commun.ROCHE
const ROCHE_CONTOUR := Commun.ROCHE_CONTOUR
const FER := Commun.BOMBE_CORPS
const FER_CLAIR := Commun.BOMBE_REFLET
const FER_CONTOUR := Commun.BOMBE_CONTOUR
const RUNE := Commun.RUNE_FORGE
const RUNE_VIVE := Commun.AMBRE_CLAIR

const NOMS: PackedStringArray = ["petard", "pop_petard", "rocher", "cratere", "mine_forge"]
## Rayon (px de planche) du cratère de poussière, image par image.
const RAYONS_CRATERE: Array[float] = [4.0, 8.0, 11.5, 14.0, 15.0]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"petard":
			return _petard()
		"pop_petard":
			return _pop_petard()
		"rocher":
			return _rocher()
		"cratere":
			return _cratere()
		"mine_forge":
			return _mine_forge()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Un pétard dressé : un tube rouge à deux bandes jaunes, la mèche qui crépite (deux images).
static func _petard() -> Image:
	var img: Image = Commun.vierge("petard")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "petard", i)
		for y: int in range(6, 15):
			for x: int in range(2, 8):
				t.p(x, y, ROUGE if x < 6 else ROUGE_SOMBRE)
		for y: int in [8, 12]:
			for x: int in range(2, 8):
				t.p(x, y, JAUNE)
		t.entourer(ENCRE)
		t.p(5, 5, MECHE)
		t.p(5, 4, MECHE)
		t.p(6, 3, MECHE)
		if i == 0:
			for v: Vector2i in [Vector2i(6, 1), Vector2i(8, 1), Vector2i(7, 2), Vector2i(7, 0)]:
				t.p(v.x, v.y, JAUNE)
			t.p(7, 1, BLANC)
		else:
			for v: Vector2i in [Vector2i(5, 1), Vector2i(8, 2), Vector2i(8, 0), Vector2i(6, 0)]:
				t.p(v.x, v.y, JAUNE)
			t.p(7, 1, BLANC)
	return img


## Le pop : une étoile d'étincelles qui part du centre, puis des points qui retombent.
static func _pop_petard() -> Image:
	var img: Image = Commun.vierge("pop_petard")
	var rng: RandomNumberGenerator = Commun.hasard()
	var f1: Commun.Toile = Commun.toile(img, "pop_petard", 0)
	f1.disque(16.0, 16.0, 4.0, BLANC)
	f1.disque(16.0, 16.0, 6.0, JAUNE)
	f1.disque(16.0, 16.0, 3.0, BLANC)
	f1.entourer(ROUGE_SOMBRE)
	var etapes: Array = [[5.0, 9.0], [9.0, 13.0], [12.0, 15.0]]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "pop_petard", i + 1)
		for k: int in 10:
			var a: float = TAU * k / 10.0 + 0.15
			var de: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * etapes[i][0]
			var vers: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * etapes[i][1]
			t.ligne(
				roundi(de.x),
				roundi(de.y),
				roundi(vers.x),
				roundi(vers.y),
				JAUNE if k % 2 == 0 else ROUGE
			)
			t.p(roundi(vers.x), roundi(vers.y), BLANC)
		t.entourer(ROUGE_SOMBRE)
	var f5: Commun.Toile = Commun.toile(img, "pop_petard", 4)
	for k: int in 12:
		var c: Vector2 = (
			Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, 15.0)
		)
		f5.p(roundi(c.x), roundi(c.y), JAUNE if k % 2 == 0 else ROUGE)
	var f6: Commun.Toile = Commun.toile(img, "pop_petard", 5)
	for k: int in 6:
		var c: Vector2 = (
			Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, 15.0)
		)
		f6.p(roundi(c.x), roundi(c.y), ROUGE)
	return img


## Un rocher anguleux, plus large que haut, la face haute claire et le dessous sombre.
static func _rocher() -> Image:
	var img: Image = Commun.vierge("rocher")
	var t: Commun.Toile = Commun.toile(img, "rocher", 0)
	var pts := PackedVector2Array(
		[
			Vector2(1, 8),
			Vector2(2, 3),
			Vector2(5, 1),
			Vector2(9, 1.5),
			Vector2(12, 3),
			Vector2(13, 7),
			Vector2(11, 11),
			Vector2(4, 11),
		]
	)
	for y: int in t.h:
		for x: int in t.w:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				t.p(x, y, ROCHE_CLAIRE if y < 5 and x < 9 else ROCHE)
	for v: Vector2i in [Vector2i(7, 3), Vector2i(7, 4), Vector2i(8, 5), Vector2i(8, 6)]:
		t.p(v.x, v.y, ROCHE_CONTOUR)
	t.entourer(ROCHE_CONTOUR)
	return img


## Un cratère de poussière : un anneau de boules qui s'écartent (rayon `RAYONS_CRATERE`), puis un
## nuage tramé qui se dissipe.
static func _cratere() -> Image:
	var img: Image = Commun.vierge("cratere")
	for i: int in 5:
		var t: Commun.Toile = Commun.toile(img, "cratere", i)
		var r: float = RAYONS_CRATERE[i]
		var boules: int = 12
		for k: int in boules:
			var a: float = TAU * k / boules + 0.2
			var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * (r - 2.0)
			var taille: float = 2.6 if i < 3 else 2.0
			t.disque(c.x, c.y, taille, ROCHE_CLAIRE if k % 2 == 0 else ROCHE)
		if i < 3:
			t.disque(16.0, 16.0, r * 0.45, ROCHE)
			for k: int in 5:
				var a: float = TAU * k / 5.0 + 0.7
				var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * (r * 0.6)
				t.p(roundi(c.x), roundi(c.y), ROCHE_CONTOUR)
		t.entourer(ROCHE_CONTOUR)
	var f6: Commun.Toile = Commun.toile(img, "cratere", 5)
	for y: int in f6.h:
		for x: int in f6.w:
			var d: float = Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length()
			if d <= 15.0 and d >= 9.0 and (x + y) % 3 == 0:
				f6.p(x, y, ROCHE_CLAIRE)
	return img


## Une mine de forge : un disque de fer aplati, rivets, rune qui rougeoie (deux images).
static func _mine_forge() -> Image:
	var img: Image = Commun.vierge("mine_forge")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "mine_forge", i)
		t.ellipse(8.0, 6.5, 7.0, 4.4, FER)
		t.ellipse(8.0, 5.5, 6.0, 3.2, FER_CLAIR)
		t.ellipse(8.0, 6.0, 4.4, 2.6, FER)
		t.entourer(FER_CONTOUR)
		var rune: Color = RUNE if i == 0 else RUNE_VIVE
		for v: Vector2i in [
			Vector2i(8, 4), Vector2i(7, 5), Vector2i(8, 6), Vector2i(9, 7), Vector2i(8, 8)
		]:
			t.p(v.x, v.y, rune)
		if i == 1:
			t.p(6, 6, RUNE)
			t.p(10, 5, RUNE)
		for v: Vector2i in [Vector2i(2, 6), Vector2i(14, 6), Vector2i(8, 1)]:
			t.p(v.x, v.y, FER_CONTOUR)
	return img
