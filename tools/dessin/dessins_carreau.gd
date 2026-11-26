extends RefCounted
## Sprites d'effets d'attaques, famille du carreau (arbalète, chausse-trape, ricochet, herse,
## baliste, pluie d'aiguilles) : style et palette de Tiny Swords (voir
## `tools/dessiner_effets_attaques.gd`). Bois brun, acier, plume rouge. Les projectiles regardent
## vers +x ; le jeu les oriente.

const Commun := preload("res://tools/dessin/dessin_commun.gd")
const BLANC := Commun.ACIER_BLANC
const CLAIR := Commun.ACIER_CLAIR
const ACIER := Commun.ACIER
const ENCRE := Commun.ACIER_CONTOUR
const BOIS := Commun.BOIS
const SOMBRE := Commun.BOIS_SOMBRE
const PLUME := Commun.PLUME

const NOMS: PackedStringArray = [
	"carreau",
	"carreau_baliste",
	"chausse_trape",
	"pique",
	"aiguille",
	"plante",
	"gerbe",
	"pointes_sol",
]
## Hauteur des pointes qui jaillissent du sol, image par image.
const HAUTEURS_POINTES: Array[int] = [3, 7, 11, 11, 8, 4]
const RAYONS_GERBE: Array[float] = [3.0, 6.5, 9.0, 11.0]


## La bande d'images de la planche `nom`, rendue en mémoire.
static func dessiner(nom: String) -> Image:
	match nom:
		"carreau":
			return _carreau()
		"carreau_baliste":
			return _baliste()
		"chausse_trape":
			return _chausse_trape()
		"pique":
			return _pique()
		"aiguille":
			return _aiguille()
		"plante":
			return _plante()
		"gerbe":
			return _gerbe()
		"pointes_sol":
			return _pointes_sol()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## Une pointe qui s'effile vers +x entre `x0` et `x1`, centrée sur la ligne `yc`, de demi-hauteur
## `demi` à la base : clair au-dessus de l'axe, plus sombre dessous (on lit le volume).
static func _pointe(t: Commun.Toile, x0: int, x1: int, yc: float, demi: float) -> void:
	for x: int in range(x0, x1 + 1):
		var u: float = float(x - x0) / maxf(x1 - x0, 1.0)
		var h: float = lerpf(demi, 0.5, u)
		for y: int in t.h:
			var d: float = y + 0.5 - yc
			if absf(d) <= h:
				t.p(x, y, CLAIR if d < 0.0 else ACIER)


## Les plumes : deux rangs rouges qui s'écartent en queue.
static func _plumes(t: Commun.Toile, x0: int, x1: int, yc: float, demi: float) -> void:
	for x: int in range(x0, x1 + 1):
		var u: float = float(x - x0) / maxf(x1 - x0, 1.0)
		var h: float = lerpf(demi, demi * 0.45, u)
		for y: int in t.h:
			if absf(y + 0.5 - yc) <= h and not (x == x0 + 1 and absf(y + 0.5 - yc) < 0.6):
				t.p(x, y, PLUME)


static func _carreau() -> Image:
	var img: Image = Commun.vierge("carreau")
	var t: Commun.Toile = Commun.toile(img, "carreau", 0)
	for x: int in range(2, 12):
		t.p(x, 3, BOIS)
		t.p(x, 4, BOIS)
	_plumes(t, 0, 3, 4.0, 3.0)
	_pointe(t, 11, 15, 4.0, 2.5)
	t.entourer(ENCRE)
	return img


static func _baliste() -> Image:
	var img: Image = Commun.vierge("carreau_baliste")
	var t: Commun.Toile = Commun.toile(img, "carreau_baliste", 0)
	for x: int in range(3, 17):
		for y: int in range(3, 7):
			t.p(x, y, BOIS if y < 5 else SOMBRE)
	for x: int in [8, 9]:
		for y: int in range(3, 7):
			t.p(x, y, ACIER)
	_plumes(t, 0, 5, 5.0, 4.0)
	_pointe(t, 15, 22, 5.0, 4.0)
	# Deux ardillons de chaque côté de la pointe.
	for v: Vector2i in [Vector2i(14, 1), Vector2i(14, 8), Vector2i(15, 1), Vector2i(15, 8)]:
		t.p(v.x, v.y, ACIER)
	t.entourer(ENCRE)
	return img


static func _chausse_trape() -> Image:
	var img: Image = Commun.vierge("chausse_trape")
	var t: Commun.Toile = Commun.toile(img, "chausse_trape", 0)
	for bout: Vector2i in [Vector2i(6, 1), Vector2i(1, 9), Vector2i(10, 9)]:
		t.ligne(6, 6, bout.x, bout.y, CLAIR)
		t.ligne(7, 6, bout.x + 1, bout.y, ACIER)
	t.disque(6.5, 6.5, 1.8, ACIER)
	t.p(6, 5, CLAIR)
	t.entourer(ENCRE)
	return img


static func _pique() -> Image:
	var img: Image = Commun.vierge("pique")
	var t: Commun.Toile = Commun.toile(img, "pique", 0)
	for x: int in range(0, 4):
		for y: int in range(2, 8):
			t.p(x, y, BOIS if y < 5 else SOMBRE)
	_pointe(t, 4, 11, 5.0, 3.0)
	t.entourer(ENCRE)
	return img


static func _aiguille() -> Image:
	var img: Image = Commun.vierge("aiguille")
	var t: Commun.Toile = Commun.toile(img, "aiguille", 0)
	for x: int in range(2, 13):
		t.p(x, 1, CLAIR)
		t.p(x, 2, ACIER)
	t.p(13, 1, CLAIR)
	t.p(0, 1, PLUME)
	t.p(1, 1, PLUME)
	t.p(0, 2, PLUME)
	t.entourer(ENCRE)
	return img


## Un carreau planté à la verticale dans un petit tertre ; la deuxième image est l'oscillation
## qui se calme.
static func _plante() -> Image:
	var img: Image = Commun.vierge("plante")
	for i: int in 2:
		var t: Commun.Toile = Commun.toile(img, "plante", i)
		var penche: int = 1 if i == 0 else 0
		for y: int in range(3, 9):
			t.p(6 + penche * (1 if y < 6 else 0), y, BOIS)
			t.p(5 + penche * (1 if y < 6 else 0), y, BOIS)
		for y: int in range(1, 4):
			t.p(4 + penche * 2, y, PLUME)
			t.p(7 + penche * 2, y, PLUME)
		t.ellipse(5.5, 9.0, 4.0, 1.6, SOMBRE)
		t.p(5, 8, SOMBRE)
		t.p(6, 8, SOMBRE)
		t.entourer(ENCRE)
	return img


## Des éclats de bois et d'acier qui partent en étoile ; le cœur est blanc à la première image.
static func _gerbe() -> Image:
	var img: Image = Commun.vierge("gerbe")
	for i: int in 4:
		var t: Commun.Toile = Commun.toile(img, "gerbe", i)
		var r: float = RAYONS_GERBE[i]
		for k: int in 8:
			var a: float = TAU * k / 8.0 + (0.2 if k % 2 == 1 else 0.0)
			var p: Vector2 = Vector2(12.0, 12.0) + Vector2.from_angle(a) * r * (1.0 if k % 2 == 0 else 0.75)
			var c: Color = BOIS if k % 2 == 0 else CLAIR
			if i == 3:
				if k % 2 == 1:
					continue
				c = ACIER
			t.p(int(p.x), int(p.y), c)
			if i < 3:
				t.p(int(p.x) + 1, int(p.y), c)
				t.p(int(p.x), int(p.y) + 1, c)
		if i == 0:
			t.disque(12.0, 12.0, 2.4, BLANC)
		elif i == 1:
			t.disque(12.0, 12.0, 1.4, CLAIR)
		if i < 2:
			t.entourer(ENCRE)
	return img


## Huit pointes qui jaillissent du sol en anneau puis rentrent, dans un peu de poussière.
static func _pointes_sol() -> Image:
	var img: Image = Commun.vierge("pointes_sol")
	for i: int in 6:
		var t: Commun.Toile = Commun.toile(img, "pointes_sol", i)
		var h: int = HAUTEURS_POINTES[i]
		for k: int in 8:
			var a: float = TAU * k / 8.0 + PI / 8.0
			var bx: int = roundi(16.0 + cos(a) * 12.0)
			var by: int = roundi(20.0 + sin(a) * 8.0)
			t.p(bx - 2, by, BOIS)
			t.p(bx + 2, by, BOIS)
			for dy: int in h:
				var demi: float = 1.6 * (1.0 - float(dy) / h)
				for dx: int in range(-2, 3):
					if absf(dx) <= demi:
						t.p(bx + dx, by - dy, CLAIR if dx <= 0 else ACIER)
		t.entourer(ENCRE)
	return img
