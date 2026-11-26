extends RefCounted
## Sprites d'effets d'attaques, élément arcane (rune, éclat de rune) : style et palette de Tiny
## Swords (voir `tools/dessiner_effets_attaques.gd`).

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const ARCANE_BLEU := Commun.ARCANE_BLEU
const ARCANE_CLAIR := Commun.ARCANE_CLAIR
const ARCANE_NUIT := Commun.ARCANE_NUIT
const BLANC := Commun.BLANC

const NOMS: PackedStringArray = ["rune", "eclat_rune"]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"rune":
			return _rune()
		"eclat_rune":
			return _eclat_rune()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


static func _rune() -> Image:
	var img: Image = Commun.vierge("rune")
	var pulsations: Array = [[2.6, 1.0], [3.2, 1.6], [3.6, 2.2], [3.2, 1.6]]
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "rune", i)
		var interieur: float = pulsations[i][0]
		var coeur: float = pulsations[i][1]
		for y: int in t.h:
			for x: int in t.w:
				var dx: float = x + 0.5 - 6.0
				var dy: float = y + 0.5 - 6.0
				var m: float = absf(dx) + absf(dy)
				if m > 5.6:
					continue
				if m > 4.6:
					t.p(x, y, ARCANE_NUIT)
				elif m > interieur:
					var gravure: bool = minf(absf(dx), absf(dy)) < 1.0
					t.p(x, y, ARCANE_NUIT if gravure else ARCANE_BLEU)
				elif m > coeur:
					t.p(x, y, ARCANE_CLAIR)
				else:
					t.p(x, y, BLANC)
	return img


static func _eclat_rune() -> Image:
	var img: Image = Commun.vierge("eclat_rune")
	var rng: RandomNumberGenerator = Commun.hasard()
	var f1: Commun.Toile = Commun.toile(img, "eclat_rune", 0)
	f1.disque(12.0, 12.0, 2.2, BLANC)
	for a: int in 4:
		var v: Vector2 = Vector2.from_angle(a * PI / 2.0)
		f1.ligne(12, 12, 12 + roundi(v.x * 5), 12 + roundi(v.y * 5), ARCANE_CLAIR)
	f1.entourer(ARCANE_NUIT)
	var rayons: Array = [5.0, 8.0, 10.0]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "eclat_rune", i + 1)
		var r: float = rayons[i]
		for y: int in t.h:
			for x: int in t.w:
				var d: float = Vector2(x + 0.5 - 12.0, y + 0.5 - 12.0).length()
				if absf(d - r) <= 0.6:
					t.p(x, y, ARCANE_CLAIR)
				elif absf(d - (r - 2.0)) <= 0.5 and i > 0:
					t.p(x, y, ARCANE_BLEU)
		for a: int in 4:
			var v: Vector2 = Vector2.from_angle(a * PI / 2.0) * r
			var gx: int = 12 + roundi(v.x)
			var gy: int = 12 + roundi(v.y)
			t.p(gx, gy, BLANC)
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				t.p(gx + d.x, gy + d.y, BLANC)
			var w: Vector2 = Vector2.from_angle(a * PI / 2.0 + PI / 4.0) * r
			t.p(12 + roundi(w.x), 12 + roundi(w.y), ARCANE_BLEU)
		t.entourer(ARCANE_NUIT)
	var f5: Commun.Toile = Commun.toile(img, "eclat_rune", 4)
	var teintes: Array[Color] = [BLANC, ARCANE_CLAIR, ARCANE_BLEU]
	for k: int in 13:
		var c: Vector2 = (
			Vector2(12, 12) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 10.5)
		)
		f5.p(roundi(c.x), roundi(c.y), teintes[k % 3])
	return img
