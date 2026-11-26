extends RefCounted
## Sprites d'effets d'attaques, famille acier (lame, faucille, disque, lames de cuivre, front de
## guillotine, vapeur, éclats) : style et palette de Tiny Swords (voir
## `tools/dessiner_effets_attaques.gd`). Les lames regardent vers +x ; le jeu les oriente.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.ACIER_BLANC
const CLAIR := Commun.ACIER_CLAIR
const ACIER := Commun.ACIER
const ENCRE := Commun.ACIER_CONTOUR
const CUIVRE_CLAIR := Commun.CUIVRE_CLAIR
const CUIVRE := Commun.CUIVRE
const BRUN := Commun.CUIVRE_BRUN
const VAPEUR_CLAIR := Commun.VAPEUR_CLAIR
const VAPEUR := Commun.VAPEUR

const NOMS: PackedStringArray = [
	"lame_croissant",
	"entaille",
	"faucille",
	"balayage",
	"disque_scie",
	"lame_cuivre",
	"lame_tournante",
	"arc_lame",
	"vapeur",
	"eclat_acier",
]
## Fin du balayage de la faucille : angle couvert à chaque image, en degrés.
const BALAYAGE: Array[float] = [90.0, 180.0, 300.0, 300.0, 300.0, 300.0]
const ENTAILLE: Array[float] = [70.0, 120.0, 150.0, 150.0]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"lame_croissant":
			return _lame_croissant()
		"entaille":
			return _entaille()
		"faucille":
			return _faucille()
		"balayage":
			return _balayage()
		"disque_scie":
			return _disque_scie()
		"lame_cuivre":
			return _lame_cuivre()
		"lame_tournante":
			return _lame_tournante()
		"arc_lame":
			return _arc_lame()
		"vapeur":
			return _vapeur()
		"eclat_acier":
			return _eclat_acier()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Un croissant : le disque `(cx, cy, r)` privé du disque décalé de `decalage` dans la direction
## `angle`. Le bord de l'extérieur le plus éloigné du creux est blanc, le bord du creux est plus
## sombre : on lit le tranchant.
static func _croissant(
	t: Commun.Toile, cx: float, cy: float, r: float, decalage: float, angle: float, r_creux: float
) -> void:
	var dir: Vector2 = Vector2.from_angle(angle)
	var creux: Vector2 = Vector2(cx, cy) + dir * decalage
	for y: int in t.h:
		for x: int in t.w:
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var d: float = p.distance_to(Vector2(cx, cy))
			if d > r or p.distance_to(creux) <= r_creux:
				continue
			var contre: float = (p - Vector2(cx, cy)).dot(dir)
			if d > r - 1.2 and contre < 0.0:
				t.p(x, y, BLANC)
			elif p.distance_to(creux) <= r_creux + 1.3:
				t.p(x, y, ACIER)
			else:
				t.p(x, y, CLAIR)


static func _lame_croissant() -> Image:
	var img: Image = Commun.vierge("lame_croissant")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "lame_croissant", i)
		_croissant(t, 8.0, 8.0, 6.3, 2.8, i * PI / 2.0, 5.4)
		t.entourer(ENCRE)
	return img


## Un trait en arc de `a0` à `a1` (radians) autour de `(cx, cy)`, au rayon `r`, dont l'épaisseur
## va de `fin` (à `a0`) à `epais` (à `a1`).
static func _arc(
	t: Commun.Toile,
	centre: Vector2,
	r: float,
	a0: float,
	a1: float,
	fin: float,
	epais: float,
	couleur_tete: Color,
	couleur_corps: Color,
	couleur_queue: Color
) -> void:
	for y: int in t.h:
		for x: int in t.w:
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - centre
			var a: float = d.angle()
			var u: float = (fposmod(a - a0, TAU)) / (a1 - a0)
			if u < 0.0 or u > 1.0:
				continue
			var demi: float = lerpf(fin, epais, u) * 0.5
			var ecart: float = absf(d.length() - r)
			if ecart > demi:
				continue
			if u > 0.85 and ecart < demi * 0.8:
				t.p(x, y, couleur_tete)
			elif u > 0.35:
				t.p(x, y, couleur_corps if ecart > demi * 0.35 else couleur_tete)
			else:
				t.p(x, y, couleur_queue)


static func _entaille() -> Image:
	var img: Image = Commun.vierge("entaille")
	var centre: Vector2 = Vector2(12.0, 15.0)
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "entaille", i)
		var etendue: float = deg_to_rad(ENTAILLE[i])
		var a0: float = deg_to_rad(-90.0) - etendue * 0.5
		if i < 3:
			_arc(t, centre, 9.0 + i, a0, a0 + etendue, 1.0, 4.0 - i * 0.6, BLANC, CLAIR, ACIER)
			t.entourer(ENCRE)
		else:
			# Dernière image : l'arc se défait en éclats.
			_arc(t, centre, 11.0, a0, a0 + etendue, 1.0, 2.0, BLANC, CLAIR, ACIER)
			for y: int in t.h:
				for x: int in t.w:
					if (x + y) % 3 != 0:
						t.img.set_pixel(t.ox + x, y, Commun.TRANSPARENT)
	return img


static func _faucille() -> Image:
	var img: Image = Commun.vierge("faucille")
	var t: Commun.Toile = Commun.toile(img, "faucille", 0)
	# Le manche, en bas à gauche, et la lame qui s'enroule en croissant vers le haut.
	_croissant(t, 9.5, 6.5, 6.0, 2.6, deg_to_rad(120.0), 4.8)
	t.ligne(3, 14, 5, 7, BRUN)
	t.ligne(4, 14, 6, 7, BRUN)
	t.entourer(ENCRE)
	return img


static func _balayage() -> Image:
	var img: Image = Commun.vierge("balayage")
	var centre: Vector2 = Vector2(16.0, 16.0)
	for i: int in 6:
		var t: Commun.Toile = Commun.toile(img, "balayage", i)
		var etendue: float = deg_to_rad(BALAYAGE[i])
		var a0: float = deg_to_rad(-150.0)
		var epais: float = 5.0 if i < 3 else (3.0 if i == 3 else 2.0)
		_arc(t, centre, 12.5, a0, a0 + etendue, 1.0, epais, BLANC, CLAIR, ACIER)
		if i >= 4:
			for y: int in t.h:
				for x: int in t.w:
					if (x + y + i) % 3 != 0:
						t.img.set_pixel(t.ox + x, y, Commun.TRANSPARENT)
		if i < 4:
			t.entourer(ENCRE)
	return img


static func _disque_scie() -> Image:
	var img: Image = Commun.vierge("disque_scie")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "disque_scie", i)
		var decalage: float = i * PI / 10.0
		for y: int in t.h:
			for x: int in t.w:
				var d: Vector2 = Vector2(x + 0.5 - 7.0, y + 0.5 - 7.0)
				var longueur: float = d.length()
				var dent: float = fposmod(d.angle() + decalage, TAU / 10.0) / (TAU / 10.0)
				var bord: float = 5.0 + 1.8 * (1.0 - dent)
				if longueur > bord:
					continue
				if longueur <= 1.4:
					t.p(x, y, ENCRE)
				elif longueur <= 2.6:
					t.p(x, y, ACIER)
				elif longueur > 4.6:
					t.p(x, y, BLANC if dent < 0.25 else CLAIR)
				else:
					t.p(x, y, CLAIR)
		t.entourer(ENCRE)
	return img


static func _lame_cuivre() -> Image:
	var img: Image = Commun.vierge("lame_cuivre")
	var t: Commun.Toile = Commun.toile(img, "lame_cuivre", 0)
	for y: int in t.h:
		for x: int in t.w:
			var u: float = (x + 0.5 - 8.0) / 6.5
			var v: float = (y + 0.5 - 4.0) / 2.6
			# Une lame en goutte : large à gauche, pointue à droite, un peu courbée.
			var courbe: float = 0.35 * u * u
			var w: float = (v - courbe) / maxf(0.25, 1.0 - 0.8 * maxf(u, 0.0))
			if absf(u) <= 1.0 and absf(w) <= 1.0:
				if w < -0.45:
					t.p(x, y, CUIVRE_CLAIR)
				elif w < 0.35:
					t.p(x, y, CUIVRE)
				else:
					t.p(x, y, BRUN)
	t.entourer(ENCRE)
	return img


static func _lame_tournante() -> Image:
	var img: Image = Commun.vierge("lame_tournante")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "lame_tournante", i)
		for k: int in 3:
			var a: float = k * TAU / 3.0 + i * PI / 6.0
			var dir: Vector2 = Vector2.from_angle(a)
			var perp: Vector2 = dir.orthogonal()
			for s: int in 14:
				var l: float = s * 0.4
				var largeur: float = 1.5 * (1.0 - s / 14.0) + 0.4
				for w: int in range(-1, 2):
					var p: Vector2 = (
						Vector2(6.0, 6.0) + dir * l + perp * (w * largeur * 0.8 + l * 0.18)
					)
					t.p(floori(p.x), floori(p.y), CLAIR if w < 1 else ACIER)
		t.disque(6.0, 6.0, 1.3, ACIER)
		t.p(6, 6, BLANC)
		t.p(5, 5, BLANC)
		t.entourer(ENCRE)
	return img


static func _arc_lame() -> Image:
	var img: Image = Commun.vierge("arc_lame")
	var t: Commun.Toile = Commun.toile(img, "arc_lame", 0)
	var exterieur: Vector2 = Vector2(-6.0, 16.0)
	var creux: Vector2 = Vector2(-11.5, 16.0)
	for y: int in t.h:
		for x: int in t.w:
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			if p.distance_to(exterieur) > 17.5 or p.distance_to(creux) <= 17.5:
				continue
			if p.distance_to(exterieur) > 16.3:
				t.p(x, y, BLANC)
			elif p.distance_to(creux) <= 19.0:
				t.p(x, y, ACIER)
			else:
				t.p(x, y, CLAIR)
	t.entourer(ENCRE)
	return img


static func _vapeur() -> Image:
	var img: Image = Commun.vierge("vapeur")
	var rayons: Array[float] = [4.5, 6.0, 7.2]
	for i: int in 3:
		var t: Commun.Toile = Commun.toile(img, "vapeur", i)
		var r: float = rayons[i]
		for y: int in t.h:
			for x: int in t.w:
				var d: float = Vector2(x + 0.5 - 8.0, y + 0.5 - 8.0).length()
				var bruit: float = 0.9 * sin(x * 1.7 + i) * cos(y * 1.3 - i)
				if d + bruit > r:
					continue
				var trame: bool = (x + y) % 2 == 0
				if i == 0:
					t.p(x, y, VAPEUR_CLAIR if d < r * 0.6 else (VAPEUR if trame else VAPEUR_CLAIR))
				elif i == 1:
					t.p(x, y, VAPEUR if trame else VAPEUR_CLAIR)
				elif trame:
					t.p(x, y, VAPEUR)
	return img


static func _eclat_acier() -> Image:
	var img: Image = Commun.vierge("eclat_acier")
	var rng: RandomNumberGenerator = Commun.hasard()
	var f1: Commun.Toile = Commun.toile(img, "eclat_acier", 0)
	f1.disque(12.0, 12.0, 2.4, BLANC)
	for a: int in 4:
		var v: Vector2 = Vector2.from_angle(a * PI / 2.0 + PI / 4.0)
		f1.ligne(12, 12, 12 + roundi(v.x * 6), 12 + roundi(v.y * 6), CLAIR)
	f1.entourer(ENCRE)
	var rayons: Array[float] = [5.0, 8.5]
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "eclat_acier", i + 1)
		for a: int in 8:
			var ang: float = a * TAU / 8.0 + 0.2
			var v: Vector2 = Vector2.from_angle(ang)
			var r: float = rayons[i]
			var l: int = 4 - i
			var x0: int = 12 + roundi(v.x * r)
			var y0: int = 12 + roundi(v.y * r)
			var x1: int = 12 + roundi(v.x * (r + l))
			var y1: int = 12 + roundi(v.y * (r + l))
			t.ligne(x0, y0, x1, y1, BLANC if a % 2 == 0 else CLAIR)
		t.entourer(ENCRE)
	var f4: Commun.Toile = Commun.toile(img, "eclat_acier", 3)
	var teintes: Array[Color] = [BLANC, CLAIR, ACIER]
	for k: int in 10:
		var c: Vector2 = (
			Vector2(12, 12) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 11.0)
		)
		f4.p(roundi(c.x), roundi(c.y), teintes[k % 3])
	return img
