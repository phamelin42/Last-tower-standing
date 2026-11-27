extends RefCounted
## Sprites d'impact et d'apparition des armes de chaos du lot 9 (T9.19, D22) : sang, engrenages,
## sceau, éclaboussure spectrale, pointes de discorde, volutes d'oubli, nuage de cendre, maléfice,
## et l'apparition d'un allié (colonne de braise, volutes spectrales). Style et palette de Tiny
## Swords ; chaque planche est carrée et compte quatre images (flash, montée, pic, dissipation) ;
## une volute se resserre : sa plus grande image est la première. La forme se lit sans la couleur :
## croix, étoile, anneau fendu, gouttes, pointes, anneau qui rétrécit, nuage, orbe à quatre pointes.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const Outils := preload("res://tools/dessin/dessin_outils_lot9.gd")
const BLANC := Commun.BLANC
const JAUNE := Commun.JAUNE
const ORANGE := Commun.ORANGE
const CENDRE := Commun.BOMBE_REFLET
const FUMEE := Commun.FUMEE
const GRIS_CLAIR := Commun.GRIS_CLAIR
const ENCRE := Commun.ACIER_CONTOUR
const ROUGE := Commun.PLUME
const ROUGE_SOMBRE := Commun.ROUGE_SOMBRE
const VIOLET := Commun.CHAOS_VIOLET
const MAGENTA := Commun.CHAOS_MAGENTA
const NUIT := Commun.CHAOS_NUIT
const OR := Commun.CHAOS_OR
const OR_BRUN := Commun.CHAOS_OR_BRUN
const VERRE_PALE := Commun.VERRE_PALE
const VERRE_BLEU := Commun.VERRE_BLEU

## Part du rayon maximal à chaque image d'une planche qui grandit : flash, montée, pic, dissipation.
const CROISSANCE: Array[float] = [0.38, 0.7, 1.0, 0.95]
const CENTRE_24 := Vector2(12.0, 12.0)
const CENTRE_32 := Vector2(16.0, 16.0)

const NOMS: PackedStringArray = [
	"eclat_sang",
	"eclat_jumeau",
	"eclat_serment",
	"eclat_spectre",
	"pointes_discorde",
	"volute_oubli",
	"nuage_cendre",
	"eclat_malefice",
	"apparition_ombre",
	"apparition_spectre",
	"eclat_ombre",
]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"eclat_sang":
			return _sang()
		"eclat_jumeau":
			return _jumeau()
		"eclat_serment":
			return _serment()
		"eclat_spectre":
			return _spectre()
		"pointes_discorde":
			return _pointes()
		"volute_oubli":
			return _volute()
		"nuage_cendre":
			return _nuage()
		"eclat_malefice":
			return _malefice()
		"apparition_ombre":
			return _apparition_ombre()
		"apparition_spectre":
			return _apparition_spectre()
		"eclat_ombre":
			return _eclat_ombre()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Une croix de sang : quatre bras qui se terminent en goutte, des gouttes en diagonale, puis
## qui se détachent.
static func _sang() -> Image:
	var img: Image = Commun.vierge("eclat_sang")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "eclat_sang", i)
		var r: float = 8.6 * CROISSANCE[i]
		var ep: float = [2.0, 2.6, 3.0, 2.0][i]
		for k: int in 4:
			var dir: Vector2 = Vector2.from_angle(k * PI / 2.0)
			if i < 3:
				Outils.trait_epais(t, CENTRE_24 + dir * r * 0.25, CENTRE_24 + dir * r, ep, ROUGE)
				var bout: Vector2 = CENTRE_24 + dir * r
				t.disque(bout.x, bout.y, ep * 0.7, ROUGE_SOMBRE)
			else:
				var a: Vector2 = CENTRE_24 + dir * r * 0.55
				var b: Vector2 = CENTRE_24 + dir * r
				t.disque(a.x, a.y, 1.4, ROUGE)
				t.disque(b.x, b.y, 1.1, ROUGE_SOMBRE)
		if i >= 1:
			for k: int in 4:
				var p: Vector2 = CENTRE_24 + Vector2.from_angle(PI / 4.0 + k * PI / 2.0) * r * 0.66
				t.disque(p.x, p.y, 1.0, MAGENTA)
		t.disque(CENTRE_24.x, CENTRE_24.y, [1.6, 2.6, 3.2, 1.5][i], ROUGE_SOMBRE)
		if i == 1 or i == 2:
			t.p(11, 11, BLANC)
		t.entourer(NUIT)
	return img


## Une étoile d'or à huit branches, deux engrenages qui s'engrènent en son centre.
static func _jumeau() -> Image:
	var img: Image = Commun.vierge("eclat_jumeau")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "eclat_jumeau", i)
		var r: float = 9.0 * CROISSANCE[i]
		for k: int in 8:
			var dir: Vector2 = Vector2.from_angle(k * PI / 4.0)
			var longueur: float = r if k % 2 == 0 else r * 0.62
			var ep: float = 2.2 if k % 2 == 0 else 1.7
			if i == 3:
				ep = 1.4
			Outils.trait_epais(t, CENTRE_24 + dir * r * 0.2, CENTRE_24 + dir * longueur, ep, OR)
		var rd: float = [1.4, 2.4, 3.0, 2.2][i]
		t.disque(CENTRE_24.x - rd * 0.6, CENTRE_24.y, rd, OR_BRUN)
		t.disque(CENTRE_24.x + rd * 0.6, CENTRE_24.y, rd, OR)
		if i >= 1:
			t.disque(CENTRE_24.x - rd * 0.6, CENTRE_24.y, 0.9, NUIT)
			t.disque(CENTRE_24.x + rd * 0.6, CENTRE_24.y, 0.9, NUIT)
		if i == 0 or i == 2:
			t.p(11, 10, BLANC)
		t.entourer(NUIT)
	return img


## Un sceau d'or qui se fend en deux moitiés décalées, des éclats violets autour.
static func _serment() -> Image:
	var img: Image = Commun.vierge("eclat_serment")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "eclat_serment", i)
		var r: float = 8.2 * CROISSANCE[i]
		if i == 0:
			t.disque(CENTRE_24.x, CENTRE_24.y, 2.4, OR)
			t.p(11, 11, BLANC)
			t.entourer(NUIT)
			continue
		var decalage: int = 0 if i == 1 else 1
		for y: int in t.h:
			for x: int in t.w:
				var d: float = Vector2(x + 0.5 - CENTRE_24.x, y + 0.5 - CENTRE_24.y).length()
				if d > r + 0.2 or d < r - 1.9:
					continue
				var cote: float = (x + 0.5 - CENTRE_24.x) + (y + 0.5 - CENTRE_24.y)
				if absf(cote) < 1.1:
					continue
				if cote < 0.0:
					t.p(x - decalage, y - decalage, OR)
				else:
					t.p(x + decalage, y + decalage, OR_BRUN)
		for k: int in 6:
			var angle: float = k * TAU / 6.0 + 0.3
			var p: Vector2 = CENTRE_24 + Vector2.from_angle(angle) * (r + 2.4)
			if i >= 2:
				t.disque(p.x, p.y, 1.0, VIOLET)
		t.disque(CENTRE_24.x, CENTRE_24.y, 1.4, MAGENTA)
		t.p(10, 10, BLANC)
		t.entourer(NUIT)
	return img


## Une éclaboussure de gouttes pâles autour d'une bouffée, quelques points violets.
static func _spectre() -> Image:
	var img: Image = Commun.vierge("eclat_spectre")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "eclat_spectre", i)
		var r: float = 9.4 * CROISSANCE[i]
		for k: int in 10:
			var angle: float = k * TAU / 10.0 + 0.15 * (k % 2)
			var rang: int = k % 3
			var p: Vector2 = CENTRE_24 + Vector2.from_angle(angle) * r * (0.55 + 0.225 * rang)
			var taille: float = 1.7 - 0.25 * rang
			if i == 3:
				taille *= 0.7
			t.disque(p.x, p.y, taille, VERRE_PALE if k % 2 == 0 else VERRE_BLEU)
		for k: int in 4:
			var dir: Vector2 = Vector2.from_angle(PI / 4.0 + k * PI / 2.0)
			Outils.trait_epais(t, CENTRE_24 + dir * r * 0.2, CENTRE_24 + dir * r * 0.5, 1.5, VERRE_BLEU)
		var rc: float = [1.8, 3.2, 4.0, 2.6][i]
		t.disque(CENTRE_24.x, CENTRE_24.y, rc, VERRE_PALE)
		t.disque(CENTRE_24.x, CENTRE_24.y, rc * 0.45, BLANC)
		if i >= 1:
			for v: Vector2i in [Vector2i(5, 8), Vector2i(18, 15), Vector2i(10, 19)]:
				t.p_si_vide(v.x, v.y, VIOLET)
		t.entourer(NUIT)
	return img


## Huit pointes de verre, magenta et violettes, une étincelle d'or au centre.
static func _pointes() -> Image:
	var img: Image = Commun.vierge("pointes_discorde")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "pointes_discorde", i)
		var r: float = 10.2 * [0.38, 0.7, 1.0, 0.76][i]
		for k: int in 8:
			var angle: float = k * TAU / 8.0
			var longueur: float = r if k % 2 == 0 else r * 0.7
			var dir: Vector2 = Vector2.from_angle(angle)
			var flanc: Vector2 = dir.orthogonal()
			var base: Vector2 = CENTRE_24 + dir * r * 0.18
			var pointe: Array[Vector2] = [
				base + flanc * 1.9, CENTRE_24 + dir * longueur, base - flanc * 1.9
			]
			Outils.polygone(t, pointe, MAGENTA if k % 2 == 0 else VIOLET)
			if i >= 1:
				var bout: Vector2 = CENTRE_24 + dir * (longueur - 0.7)
				t.p(floori(bout.x), floori(bout.y), VERRE_PALE)
		t.disque(CENTRE_24.x, CENTRE_24.y, [1.2, 2.0, 2.4, 1.6][i], OR)
		t.p(11, 11, BLANC)
		t.entourer(NUIT)
	return img


## Un anneau violet qui se resserre (la plus grande image est la première), des gouttes magenta
## qui tournent sur lui et un filet qui monte du centre : la vigueur quitte la zone.
static func _volute() -> Image:
	var img: Image = Commun.vierge("volute_oubli")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "volute_oubli", i)
		var r: float = 10.0 * [1.0, 0.85, 0.68, 0.45][i]
		for y: int in t.h:
			for x: int in t.w:
				var d: float = Vector2(x + 0.5 - CENTRE_24.x, y + 0.5 - CENTRE_24.y).length()
				if d <= r and d > r - 1.9:
					t.p(x, y, VIOLET)
		for k: int in 4:
			var angle: float = k * PI / 2.0 + i * 0.6
			var p: Vector2 = CENTRE_24 + Vector2.from_angle(angle) * r
			t.disque(p.x, p.y, 1.5, MAGENTA)
		for j: int in i + 1:
			t.disque(12.0 + (j % 2) * 1.5 - 0.7, 10.0 - j * 3.0, 1.0, MAGENTA)
		t.p(12, 12, OR)
		t.entourer(NUIT)
	return img


## Un nuage de cendre : des mottes grises qui s'étalent sur tout le disque, des braises qui
## s'éteignent. Le jeu l'étire jusqu'au rayon réel.
static func _nuage() -> Image:
	var img: Image = Commun.vierge("nuage_cendre")
	var rng: RandomNumberGenerator = Commun.hasard()
	var mottes: Array[Vector3] = []
	for k: int in 18:
		var angle: float = rng.randf() * TAU
		var dist: float = sqrt(rng.randf()) * 11.5
		mottes.append(Vector3(angle, dist, 2.0 + rng.randf() * 1.4))
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "nuage_cendre", i)
		var k_c: float = CROISSANCE[i]
		for m: int in mottes.size():
			if i == 3 and m % 2 == 1:
				continue
			var motte: Vector3 = mottes[m]
			var p: Vector2 = CENTRE_32 + Vector2.from_angle(motte.x) * motte.y * 1.2 * k_c
			var rayon: float = motte.z * k_c * (0.8 if i == 3 else 1.0)
			t.disque(p.x, p.y, rayon, CENDRE)
			for y: int in t.h:
				for x: int in t.w:
					var d: Vector2 = Vector2(x + 0.5, y + 0.5) - p + Vector2(0.9, 0.9)
					if d.length() <= rayon * 0.7 and (x + y) % 2 == 0 and t.opaque(x, y):
						t.p(x, y, GRIS_CLAIR)
					elif d.length() > rayon * 0.9 and (x + y) % 3 == 0 and t.opaque(x, y):
						t.p(x, y, FUMEE)
		var braises: int = [3, 6, 6, 2][i]
		for b: int in braises:
			var p: Vector2 = (
				CENTRE_32 + Vector2.from_angle(b * 2.4 + 0.5) * (3.0 + b * 1.9) * k_c
			)
			t.p(floori(p.x), floori(p.y), ORANGE if b % 2 == 0 else JAUNE)
		t.entourer(ENCRE)
	return img


## Un orbe violet cerclé de magenta, quatre pointes en croix et un œil d'or.
static func _malefice() -> Image:
	var img: Image = Commun.vierge("eclat_malefice")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "eclat_malefice", i)
		var r: float = 10.0 * CROISSANCE[i]
		if i >= 1:
			for k: int in 4:
				var dir: Vector2 = Vector2.from_angle(PI / 4.0 + k * PI / 2.0)
				var flanc: Vector2 = dir.orthogonal()
				var pointe: Array[Vector2] = [
					CENTRE_24 + flanc * 2.0, CENTRE_24 + dir * r, CENTRE_24 - flanc * 2.0
				]
				Outils.polygone(t, pointe, MAGENTA)
				var haut: Vector2 = Vector2.from_angle(k * PI / 2.0)
				var courte: Array[Vector2] = [
					CENTRE_24 + haut.orthogonal() * 1.5,
					CENTRE_24 + haut * r * 0.78,
					CENTRE_24 - haut.orthogonal() * 1.5
				]
				Outils.polygone(t, courte, VIOLET)
		var coeur: float = [2.4, 3.8, 4.6, 3.0][i]
		t.disque(CENTRE_24.x, CENTRE_24.y, coeur + 1.0, MAGENTA)
		t.disque(CENTRE_24.x, CENTRE_24.y, coeur, VIOLET)
		if i >= 1:
			t.ellipse(CENTRE_24.x, CENTRE_24.y, coeur * 0.62, coeur * 0.34, NUIT)
			t.p(12, 12, OR)
			t.p(11, 12, OR)
		else:
			t.p(11, 11, BLANC)
		t.entourer(NUIT)
	return img


## L'apparition d'une sentinelle : un anneau violet à plat au sol et une colonne de braise qui
## monte, des volutes de fumée violette à son sommet.
static func _apparition_ombre() -> Image:
	var img: Image = Commun.vierge("apparition_ombre")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "apparition_ombre", i)
		var rx: float = 13.0 * [0.45, 0.8, 1.0, 0.95][i]
		var haut: float = [4.0, 9.0, 14.0, 10.0][i]
		for y: int in t.h:
			for x: int in t.w:
				var u: float = (x + 0.5 - CENTRE_32.x) / rx
				var v: float = (y + 0.5 - CENTRE_32.y) / (rx * 0.4)
				var d: float = u * u + v * v
				if d <= 1.0 and d > 0.62:
					t.p(x, y, VIOLET)
		for dx: int in range(-4, 5, 2):
			var h: float = haut * (1.0 - absf(dx) / 7.0)
			var pied: Vector2 = Vector2(CENTRE_32.x + dx, CENTRE_32.y)
			var tete: Vector2 = Vector2(CENTRE_32.x + dx * 0.6, CENTRE_32.y - h)
			Outils.trait_epais(t, pied, tete, 3.0, ORANGE)
			Outils.trait_epais(t, pied, pied.lerp(tete, 0.6), 1.4, JAUNE)
		for k: int in 5:
			var p: Vector2 = Vector2(CENTRE_32.x - 5.0 + k * 2.5, CENTRE_32.y - haut - 2.0 - (k % 2) * 2.0)
			t.disque(p.x, p.y, 1.3 + (i % 2) * 0.4, VIOLET)
		t.entourer(NUIT)
	return img


## L'apparition d'une archère : un anneau pâle au sol, trois volutes de verre qui montent et une
## capuche qui se forme au pic.
static func _apparition_spectre() -> Image:
	var img: Image = Commun.vierge("apparition_spectre")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "apparition_spectre", i)
		var rx: float = 12.0 * [0.45, 0.8, 1.0, 0.95][i]
		var haut: int = [4, 9, 14, 10][i]
		for y: int in t.h:
			for x: int in t.w:
				var u: float = (x + 0.5 - CENTRE_32.x) / rx
				var v: float = (y + 0.5 - CENTRE_32.y) / (rx * 0.4)
				var d: float = u * u + v * v
				if d <= 1.0 and d > 0.62:
					t.p(x, y, VERRE_BLEU)
		for k: int in 3:
			for dy: int in haut:
				var x: float = CENTRE_32.x + (k - 1) * 4.0 + sin(dy * 0.55 + k * 2.0 + i) * 1.5
				var y: int = int(CENTRE_32.y) - dy
				t.p(roundi(x), y, VERRE_PALE)
				if dy % 3 == 0:
					t.p(roundi(x) + 1, y, VERRE_BLEU)
		if i >= 2:
			var tete: Vector2 = Vector2(CENTRE_32.x, CENTRE_32.y - haut - 1.0)
			t.disque(tete.x, tete.y, 2.8, VERRE_PALE)
			t.p(int(tete.x) - 1, int(tete.y), VIOLET)
			t.p(int(tete.x) + 1, int(tete.y), VIOLET)
		t.p(int(CENTRE_32.x) + 5, int(CENTRE_32.y) - haut + 2, BLANC)
		t.entourer(NUIT)
	return img


## Le coup d'une sentinelle : une bouffée de fumée violette, des braises qui montent.
static func _eclat_ombre() -> Image:
	var img: Image = Commun.vierge("eclat_ombre")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "eclat_ombre", i)
		var r: float = 9.0 * CROISSANCE[i]
		var fumee: float = [2.0, 4.0, 4.8, 3.2][i]
		t.disque(CENTRE_24.x, CENTRE_24.y + 1.0, fumee, VIOLET)
		t.disque(CENTRE_24.x - 1.0, CENTRE_24.y, fumee * 0.55, MAGENTA)
		for k: int in 7:
			var angle: float = k * TAU / 7.0 - PI / 2.0 + 0.2
			var p: Vector2 = CENTRE_24 + Vector2.from_angle(angle) * r * (0.7 + 0.3 * (k % 2))
			p.y -= 1.0 * i
			t.p(floori(p.x), floori(p.y), ORANGE if k % 2 == 0 else JAUNE)
			if i == 2:
				t.p(floori(p.x) + 1, floori(p.y), ORANGE)
		t.entourer(NUIT)
	return img
