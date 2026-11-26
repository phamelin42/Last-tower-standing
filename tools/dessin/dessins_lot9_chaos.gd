extends RefCounted
## Sprites d'effets d'attaques des armes de chaos du lot 9 (T9.18) : urne, goutte de sang, engrenages
## jumeaux, sceau brisé, flèche spectrale, éclat de discorde, coupe, cendre, maléfice, et la marque
## d'un allié invoqué (silhouette claire dans un anneau au sol, que le jeu teinte). Style et
## palette de Tiny Swords ; les projectiles regardent vers +x.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const Outils := preload("res://tools/dessin/dessin_outils_lot9.gd")
const BLANC := Commun.BLANC
const JAUNE := Commun.JAUNE
const ORANGE := Commun.ORANGE
const FUMEE := Commun.FUMEE
const GRIS_CLAIR := Commun.GRIS_CLAIR
const ACIER := Commun.ACIER
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

const NOMS: PackedStringArray = [
	"urne",
	"goutte_sang",
	"engrenage_double",
	"serment",
	"fleche_spectre",
	"eclat_discorde",
	"coupe",
	"cendre",
	"malefice",
	"allie",
]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"urne":
			return _urne()
		"goutte_sang":
			return _goutte_sang()
		"engrenage_double":
			return _engrenage_double()
		"serment":
			return _serment()
		"fleche_spectre":
			return _fleche_spectre()
		"eclat_discorde":
			return _eclat_discorde()
		"coupe":
			return _coupe()
		"cendre":
			return _cendre()
		"malefice":
			return _malefice()
		"allie":
			return _allie()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Une urne sombre, deux fentes de braise pour yeux, de la braise qui monte du col.
static func _urne() -> Image:
	var img: Image = Commun.vierge("urne")
	var t: Commun.Toile = Commun.toile(img, "urne", 0)
	t.ellipse(6.0, 9.0, 4.4, 4.6, VIOLET)
	for y: int in range(10, 14):
		for x: int in range(0, 12):
			if t.opaque(x, y):
				t.p(x, y, NUIT)
	for y: int in range(4, 6):
		for x: int in range(5, 8):
			t.p(x, y, VIOLET)
	t.ligne(3, 3, 8, 3, OR)
	t.ligne(4, 4, 7, 4, OR)
	t.ligne(1, 7, 1, 9, VIOLET)
	t.ligne(10, 7, 10, 9, VIOLET)
	t.ligne(4, 12, 7, 12, OR)
	t.p(4, 8, ORANGE)
	t.p(5, 8, JAUNE)
	t.p(7, 8, ORANGE)
	t.p(8, 8, JAUNE)
	t.entourer(ENCRE)
	t.p(5, 1, JAUNE)
	t.p(7, 0, ORANGE)
	t.p(6, 2, ORANGE)
	return img


## Une goutte de sang, la pointe en haut, un reflet blanc.
static func _goutte_sang() -> Image:
	var img: Image = Commun.vierge("goutte_sang")
	var t: Commun.Toile = Commun.toile(img, "goutte_sang", 0)
	var pointe: Array[Vector2] = [Vector2(5.0, 0.6), Vector2(8.6, 6.0), Vector2(1.4, 6.0)]
	Outils.polygone(t, pointe, ROUGE)
	t.disque(5.0, 7.2, 4.2, ROUGE)
	for y: int in range(7, 12):
		for x: int in range(5, 10):
			if t.opaque(x, y):
				t.p(x, y, ROUGE_SOMBRE)
	t.p(3, 6, BLANC)
	t.p(3, 7, BLANC)
	t.p(4, 4, Commun.CUIVRE_CLAIR)
	t.entourer(NUIT)
	return img


## Deux petits engrenages qui s'engrènent, tournés d'un demi-cran d'une image à l'autre.
static func _engrenage_double() -> Image:
	var img: Image = Commun.vierge("engrenage_double")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "engrenage_double", i)
		for c: Vector2 in [Vector2(5.0, 6.0), Vector2(11.0, 6.0)]:
			var sens: float = 1.0 if c.x < 8.0 else -1.0
			for k: int in 6:
				var a: float = k * TAU / 6.0 + sens * i * 0.5
				var d: Vector2 = c + Vector2.from_angle(a) * 3.6
				t.disque(d.x, d.y, 1.1, OR)
			t.disque(c.x, c.y, 3.2, OR)
			t.disque(c.x, c.y + 0.6, 2.0, OR_BRUN)
			t.disque(c.x, c.y, 1.0, NUIT)
		t.p(4, 4, BLANC)
		t.p(10, 4, BLANC)
		t.entourer(NUIT)
	return img


## Un sceau d'or fendu en deux : la moitié basse a glissé d'un cran.
static func _serment() -> Image:
	var img: Image = Commun.vierge("serment")
	var t: Commun.Toile = Commun.toile(img, "serment", 0)
	for y: int in t.h:
		for x: int in t.w:
			var d: float = Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0).length()
			if d < 3.0 or d > 5.4:
				continue
			var cote: float = (x + 0.5 - 6.0) + (y + 0.5 - 6.0)
			if absf(cote) < 1.3:
				continue
			if cote < 0.0:
				t.p(x - 1, y - 1, OR)
			else:
				t.p(x + 1, y + 1, OR_BRUN)
	t.p(6, 6, VIOLET)
	t.p(5, 6, MAGENTA)
	t.p(6, 5, MAGENTA)
	t.p(3, 3, BLANC)
	t.entourer(NUIT)
	return img


## Une flèche d'archère fantôme : pâle, une queue qui s'effiloche en pointillé.
static func _fleche_spectre() -> Image:
	var img: Image = Commun.vierge("fleche_spectre")
	var t: Commun.Toile = Commun.toile(img, "fleche_spectre", 0)
	t.ligne(4, 3, 15, 3, VERRE_PALE)
	t.ligne(4, 4, 15, 4, VERRE_BLEU)
	var fer: Array[Vector2] = [Vector2(14, 0.8), Vector2(19.4, 4.0), Vector2(14, 7.2)]
	Outils.polygone(t, fer, VERRE_PALE)
	t.ligne(15, 4, 18, 4, BLANC)
	for v: Vector2i in [Vector2i(3, 2), Vector2i(4, 1), Vector2i(3, 5), Vector2i(4, 6)]:
		t.p(v.x, v.y, VIOLET)
	t.entourer(NUIT)
	for x: int in [0, 2]:
		t.p(x, 3, VERRE_BLEU)
		t.p(x + 1, 4, VERRE_BLEU)
	return img


## Un éclat de miroir fendu en deux moitiés qui se décalent, un éclair d'or entre elles.
static func _eclat_discorde() -> Image:
	var img: Image = Commun.vierge("eclat_discorde")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "eclat_discorde", i)
		var gauche: Array[Vector2] = [
			Vector2(1, 2 - i), Vector2(5.4, 0.5 - i), Vector2(5.0, 10 - i), Vector2(1, 8 - i)
		]
		var droite: Array[Vector2] = [
			Vector2(6.6, 2 + i), Vector2(11, 3 + i), Vector2(10.6, 11.4 + i), Vector2(6.2, 9.6 + i)
		]
		Outils.polygone(t, gauche, MAGENTA)
		Outils.polygone(t, droite, VIOLET)
		t.ligne(2, 3 - i, 2, 6 - i, VERRE_PALE)
		t.ligne(8, 4 + i, 9, 7 + i, VERRE_BLEU)
		t.p(6, 3 + i, OR)
		t.p(5, 5, OR)
		t.p(6, 7, OR)
		t.entourer(NUIT)
	return img


## Une coupe d'oubli : un calice violet, la surface du breuvage magenta, un pied d'or terni.
static func _coupe() -> Image:
	var img: Image = Commun.vierge("coupe")
	var t: Commun.Toile = Commun.toile(img, "coupe", 0)
	var bol: Array[Vector2] = [
		Vector2(1, 1),
		Vector2(13, 1),
		Vector2(11.4, 5.6),
		Vector2(8.2, 7.8),
		Vector2(5.8, 7.8),
		Vector2(2.6, 5.6)
	]
	Outils.polygone(t, bol, VIOLET)
	t.ligne(2, 1, 12, 1, MAGENTA)
	t.ligne(2, 2, 12, 2, MAGENTA)
	t.ligne(3, 5, 10, 5, NUIT)
	t.ligne(4, 6, 9, 6, NUIT)
	t.ligne(2, 0, 12, 0, OR)
	t.ligne(7, 8, 7, 9, OR_BRUN)
	t.ligne(6, 8, 6, 9, OR)
	t.ellipse(6.8, 10.4, 4.2, 1.4, OR_BRUN)
	t.p(3, 3, BLANC)
	t.entourer(NUIT)
	return img


## Une motte de cendre grise, des braises dedans qui s'éteignent et se rallument (deux images).
static func _cendre() -> Image:
	var img: Image = Commun.vierge("cendre")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "cendre", i)
		t.ellipse(6.0, 6.4, 5.0, 4.4, FUMEE)
		for y: int in range(1, 7):
			for x: int in range(1, 11):
				if t.opaque(x, y) and (x + y) % 2 == 0:
					t.p(x, y, GRIS_CLAIR)
		t.p(4, 6 + i, ORANGE)
		t.p(8, 5 - i, JAUNE)
		t.p(6, 8, ORANGE if i == 0 else FUMEE)
		t.entourer(ENCRE)
		t.p(10 + i, 1, FUMEE)
		t.p(1, 10 - i, FUMEE)
	return img


## Un maléfice : un orbe violet au regard d'or, quatre pointes magenta qui tournent d'une image à
## l'autre.
static func _malefice() -> Image:
	var img: Image = Commun.vierge("malefice")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "malefice", i)
		t.disque(6.0, 6.0, 4.4, VIOLET)
		for y: int in t.h:
			for x: int in t.w:
				var d: float = Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0).length()
				if d <= 4.4 and d > 3.4:
					t.p(x, y, MAGENTA)
		t.ellipse(6.0, 6.0, 2.8, 1.5, NUIT)
		t.p(6, 6, OR)
		t.p(5, 6, OR)
		for k: int in 4:
			var a: float = k * PI / 2.0 + PI / 4.0 * i
			var p: Vector2 = Vector2(6.0, 6.0) + Vector2.from_angle(a) * 5.4
			t.p(roundi(p.x - 0.5), roundi(p.y - 0.5), MAGENTA)
		t.entourer(ENCRE)
	return img


## La marque d'un allié invoqué : une silhouette à capuche, un fanion au-dessus de la tête, dans
## un anneau double au sol dont les tirets tournent (deux images). Tout est clair : le jeu y pose
## la teinte de l'allié, qu'aucun ennemi ne porte.
static func _allie() -> Image:
	var img: Image = Commun.vierge("allie")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "allie", i)
		for y: int in t.h:
			for x: int in t.w:
				var u: float = (x + 0.5 - 16.0) / 14.5
				var v: float = (y + 0.5 - 25.0) / 5.4
				var d: float = u * u + v * v
				if d > 1.0:
					continue
				var angle: float = atan2(v, u) + i * PI / 12.0
				var segment: int = int(floorf(fposmod(angle, TAU) / (TAU / 12.0)))
				if d > 0.8 and segment % 2 == 0:
					t.p(x, y, BLANC)
				elif d > 0.45 and d <= 0.55:
					t.p(x, y, GRIS_CLAIR)
				elif d <= 0.45 and (x + y) % 2 == 0:
					t.p(x, y, ACIER)
		var corps: Array[Vector2] = [
			Vector2(11, 25), Vector2(12.5, 15), Vector2(19.5, 15), Vector2(21, 25)
		]
		Outils.polygone(t, corps, GRIS_CLAIR)
		t.disque(16.0, 11.5, 3.6, GRIS_CLAIR)
		for y: int in range(20, 25):
			t.p(15, y, ACIER)
			t.p(16, y, ACIER)
		t.disque(16.0, 12.0, 1.6, ACIER)
		t.ligne(16, 1, 16, 6, ACIER)
		var fanion: Array[Vector2] = [Vector2(17, 1), Vector2(22, 2.5), Vector2(17, 4)]
		Outils.polygone(t, fanion, BLANC)
		t.entourer(ENCRE)
	return img
