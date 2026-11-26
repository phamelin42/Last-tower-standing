extends SceneTree
## Dessine par script les sprites d'effets des attaques (boule de feu, éclat de glace, bombe, fiole,
## rune, étincelle…), dans le style et la palette de Tiny Swords : aplats de 3 à 4 teintes, gros
## pixels, contour sombre d'1 px, alpha 0 ou 1 seulement (une fumée se fait par tramage). Chaque
## planche est une bande horizontale d'images côte à côte, à la résolution native basse : le jeu les
## affiche à l'échelle 3 en `TEXTURE_FILTER_NEAREST`. Le hasard a une graine fixe : la même
## exécution sort toujours les mêmes octets, et le test compare le disque à `planche(nom)`.
##   godot --headless --path . --script res://tools/dessiner_effets_attaques.gd
##     [-- --sortie <dossier>]
##   ... -- --planche-contact <png absolu>        toutes les planches ×4 sur le vert de l'arène
##   ... -- --planche-projectiles <png absolu>    les projectiles seuls ×8

const SORTIE_DEFAUT := "res://assets/maison/effets_attaques"
const GRAINE: int = 22
const ECHELLE_CONTACT: int = 4
const ECHELLE_PROJECTILES: int = 8
const ECART: int = 4

const VERT_ARENE := Color(0.24, 0.38, 0.27)
const VERT_CASE := Color(0.2, 0.32, 0.23)
const TRANSPARENT := Color(0, 0, 0, 0)

## Feu, fumée (relevés sur Fire.png et Explosions.png).
const BLANC := Color("ffffff")
const JAUNE := Color("ffe325")
const ORANGE := Color("d08c41")
const ROUGE_SOMBRE := Color("8b4a4a")
const FUMEE := Color("846357")
const ENCRE := Color("161c2e")
## Glace.
const GLACE_PALE := Color("c8f4ff")
const GLACE_CYAN := Color("4cc9f0")
const GLACE_PROFOND := Color("1b3a8a")
## Poison.
const POISON_PALE := Color("b6f28a")
const POISON := Color("4cb84a")
const POISON_FONCE := Color("1f6b34")
const VERRE := Color("a9d4e8")
const POISON_CONTOUR := Color("10231c")
const BOUCHON := Color("8b5a2b")
## Arcane.
const ARCANE_CLAIR := Color("9fe8ff")
const ARCANE_BLEU := Color("3a78e8")
const ARCANE_NUIT := Color("14205a")
## Foudre.
const FOUDRE_LAVANDE := Color("cdbcff")
const FOUDRE_VIOLET := Color("7c4fd6")
const FOUDRE_SOMBRE := Color("2b1859")
## Bombe.
const BOMBE_CORPS := Color("3b404d")
const BOMBE_REFLET := Color("7d8599")
const BOMBE_CONTOUR := Color("0f1117")
const BOMBE_MECHE := Color("8b5a2b")
## Éclair de départ, teinté par élément dans le jeu.
const GRIS_CLAIR := Color("d5dae3")

## Nom de la planche : taille d'une image et nombre d'images.
const PLANCHES: Dictionary = {
	"boule_feu": {"taille": Vector2i(16, 16), "images": 4},
	"braise": {"taille": Vector2i(4, 4), "images": 2},
	"explosion_feu": {"taille": Vector2i(32, 32), "images": 6},
	"eclat_glace": {"taille": Vector2i(20, 8), "images": 1},
	"brisure_glace": {"taille": Vector2i(32, 32), "images": 6},
	"givre_sol": {"taille": Vector2i(32, 16), "images": 1},
	"bombe": {"taille": Vector2i(12, 12), "images": 2},
	"ombre": {"taille": Vector2i(12, 6), "images": 1},
	"fiole": {"taille": Vector2i(10, 14), "images": 1},
	"eclaboussure_poison": {"taille": Vector2i(32, 32), "images": 6},
	"nuage_poison": {"taille": Vector2i(16, 16), "images": 3},
	"rune": {"taille": Vector2i(12, 12), "images": 4},
	"eclat_rune": {"taille": Vector2i(24, 24), "images": 5},
	"etincelle": {"taille": Vector2i(8, 8), "images": 4},
	"depart": {"taille": Vector2i(12, 12), "images": 3},
}

const PROJECTILES: PackedStringArray = ["boule_feu", "eclat_glace", "bombe", "fiole", "rune"]

## Trois langues de flamme qui partent de la tête vers la gauche, pointues, orange cernées de
## rouge et jaunes au cœur ; leur longueur change d'une image à l'autre : le scintillement.
## Chaque ligne : ordonnée du milieu, longueur, épaisseur à la base.
const LANGUES: Array = [
	[[5.2, 4.0, 1.7], [10.8, 3.0, 1.5], [8.0, 6.0, 2.7]],
	[[5.0, 3.0, 1.5], [11.0, 5.0, 1.8], [7.6, 5.0, 2.6]],
	[[5.0, 5.0, 1.8], [11.2, 2.5, 1.4], [8.4, 6.0, 2.6]],
	[[5.4, 3.5, 1.6], [10.6, 4.0, 1.6], [8.0, 4.5, 2.7]],
]

const FLAQUES: Array = [
	[Vector2(16, 16), 6.0, 3.0],
	[Vector2(7, 10), 3.0, 1.7],
	[Vector2(25, 11), 3.5, 1.8],
	[Vector2(9, 23), 3.5, 1.8],
	[Vector2(24, 22), 3.0, 1.7],
]


## Une image de la bande, avec les outils de dessin en pixels de l'image.
class Toile:
	extends RefCounted
	var img: Image
	var ox: int
	var w: int
	var h: int

	func _init(image: Image, decalage: int, largeur: int, hauteur: int) -> void:
		img = image
		ox = decalage
		w = largeur
		h = hauteur

	func dedans(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h

	func p(x: int, y: int, c: Color) -> void:
		if dedans(x, y):
			img.set_pixel(ox + x, y, c)

	func opaque(x: int, y: int) -> bool:
		return dedans(x, y) and img.get_pixel(ox + x, y).a > 0.0

	func p_si_vide(x: int, y: int, c: Color) -> void:
		if dedans(x, y) and not opaque(x, y):
			img.set_pixel(ox + x, y, c)

	func disque(cx: float, cy: float, r: float, c: Color) -> void:
		for y: int in h:
			for x: int in w:
				if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
					p(x, y, c)

	func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
		for y: int in h:
			for x: int in w:
				var u: float = (x + 0.5 - cx) / rx
				var v: float = (y + 0.5 - cy) / ry
				if u * u + v * v <= 1.0:
					p(x, y, c)

	func ligne(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		var n: int = maxi(absi(x1 - x0), absi(y1 - y0))
		for i: int in n + 1:
			var t: float = 0.0 if n == 0 else float(i) / n
			p(roundi(lerpf(x0, x1, t)), roundi(lerpf(y0, y1, t)), c)

	## Contour d'1 px autour de tout ce qui est déjà dessiné.
	func entourer(c: Color) -> void:
		var a_poser: Array[Vector2i] = []
		for y: int in h:
			for x: int in w:
				if opaque(x, y):
					continue
				if opaque(x - 1, y) or opaque(x + 1, y) or opaque(x, y - 1) or opaque(x, y + 1):
					a_poser.append(Vector2i(x, y))
		for v: Vector2i in a_poser:
			p(v.x, v.y, c)

	func nombre_opaque() -> int:
		var n: int = 0
		for y: int in h:
			for x: int in w:
				if opaque(x, y):
					n += 1
		return n


func _initialize() -> void:
	quit(_lancer(OS.get_cmdline_user_args()))


func _lancer(args: PackedStringArray) -> int:
	var options: Dictionary = _lire_options(args)
	if options.is_empty():
		return 1
	var contact: String = options["contact"]
	var projectiles: String = options["projectiles"]
	var ok: bool = true
	if contact != "" or projectiles != "":
		if contact != "":
			ok = _ecrire(contacts(PLANCHES.keys(), ECHELLE_CONTACT), contact)
		if ok and projectiles != "":
			ok = _ecrire(contacts(PROJECTILES, ECHELLE_PROJECTILES), projectiles)
		return 0 if ok else 1
	var sortie: String = options["sortie"]
	DirAccess.make_dir_recursive_absolute(sortie)
	for nom: String in PLANCHES:
		ok = ok and _ecrire(planche(nom), sortie.path_join(nom + ".png"))
	if ok:
		print("Planches écrites : %s" % sortie)
	return 0 if ok else 1


## Les options de la ligne de commande ; vide si l'une est inconnue ou sans valeur.
func _lire_options(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {
		"sortie": ProjectSettings.globalize_path(SORTIE_DEFAUT), "contact": "", "projectiles": ""
	}
	var cles: Dictionary = {
		"--sortie": "sortie", "--planche-contact": "contact", "--planche-projectiles": "projectiles"
	}
	var i: int = 0
	while i < args.size():
		if not cles.has(args[i]) or i + 1 >= args.size():
			printerr("Argument inconnu ou sans valeur : %s" % args[i])
			return {}
		options[cles[args[i]]] = args[i + 1]
		i += 2
	return options


func _ecrire(img: Image, chemin: String) -> bool:
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var erreur: int = img.save_png(chemin)
	if erreur != OK:
		printerr("Écriture impossible : %s (%d)" % [chemin, erreur])
		return false
	return true


## Une ligne par planche, chaque image agrandie sur le vert de l'arène, pour la relecture.
static func contacts(noms: Array, echelle: int) -> Image:
	var largeur: int = 0
	var hauteur: int = ECART
	var lignes: Array[Image] = []
	for nom: Variant in noms:
		var ligne: Image = _ligne_contact(planche(String(nom)), String(nom), echelle)
		lignes.append(ligne)
		largeur = maxi(largeur, ligne.get_width())
		hauteur += ligne.get_height() + ECART
	var feuille: Image = Image.create_empty(largeur + 2 * ECART, hauteur, false, Image.FORMAT_RGBA8)
	feuille.fill(VERT_ARENE)
	var y: int = ECART
	for ligne: Image in lignes:
		feuille.blit_rect(ligne, Rect2i(Vector2i.ZERO, ligne.get_size()), Vector2i(ECART, y))
		y += ligne.get_height() + ECART
	return feuille


static func _ligne_contact(bande: Image, nom: String, echelle: int) -> Image:
	var taille: Vector2i = PLANCHES[nom]["taille"]
	var n: int = PLANCHES[nom]["images"]
	var pas: int = taille.x * echelle + ECART
	var ligne: Image = Image.create_empty(
		pas * n - ECART, taille.y * echelle, false, Image.FORMAT_RGBA8
	)
	ligne.fill(VERT_ARENE)
	for k: int in n:
		var cadre: Image = Image.create_empty(taille.x, taille.y, false, Image.FORMAT_RGBA8)
		cadre.blit_rect(bande, Rect2i(k * taille.x, 0, taille.x, taille.y), Vector2i.ZERO)
		cadre.resize(taille.x * echelle, taille.y * echelle, Image.INTERPOLATE_NEAREST)
		var zone: Rect2i = Rect2i(Vector2i(k * pas, 0), cadre.get_size())
		ligne.fill_rect(zone, VERT_CASE)
		ligne.blend_rect(cadre, Rect2i(Vector2i.ZERO, cadre.get_size()), zone.position)
	return ligne


## La bande d'images de la planche `nom`, rendue en mémoire (le script fait foi).
static func planche(nom: String) -> Image:
	match nom:
		"boule_feu":
			return _boule_feu()
		"braise":
			return _braise()
		"explosion_feu":
			return _explosion_feu()
		"eclat_glace":
			return _eclat_glace()
		"brisure_glace":
			return _brisure_glace()
		"givre_sol":
			return _givre_sol()
		"bombe":
			return _bombe()
		"ombre":
			return _ombre()
		"fiole":
			return _fiole()
		"eclaboussure_poison":
			return _eclaboussure_poison()
		"nuage_poison":
			return _nuage_poison()
		"rune":
			return _rune()
		"eclat_rune":
			return _eclat_rune()
		"etincelle":
			return _etincelle()
		"depart":
			return _depart()
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


static func _vierge(nom: String) -> Image:
	var taille: Vector2i = PLANCHES[nom]["taille"]
	var n: int = PLANCHES[nom]["images"]
	var img: Image = Image.create_empty(taille.x * n, taille.y, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	return img


static func _toile(img: Image, nom: String, i: int) -> Toile:
	var taille: Vector2i = PLANCHES[nom]["taille"]
	return Toile.new(img, i * taille.x, taille.x, taille.y)


static func _hasard() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = GRAINE
	return rng


# ----------------------------------------------------------------------------- feu


static func _boule_feu() -> Image:
	var img: Image = _vierge("boule_feu")
	var rng: RandomNumberGenerator = _hasard()
	for i: int in 4:
		var t: Toile = _toile(img, "boule_feu", i)
		_queue_de_flammes(t, rng, i)
		_tete_de_comete(t)
	return img


static func _queue_de_flammes(t: Toile, _rng: RandomNumberGenerator, i: int) -> void:
	for langue: Array in LANGUES[i]:
		var longueur: float = langue[1]
		var pointe: int = 6 - roundi(longueur)
		for x: int in range(pointe, 7):
			var u: float = (x - pointe + 0.5) / longueur
			var demi: float = 0.45 + float(langue[2]) * u
			for y: int in t.h:
				var d: float = absf(y + 0.5 - float(langue[0]))
				if d > demi:
					continue
				if d > demi - 0.9 or x == pointe:
					t.p(x, y, ROUGE_SOMBRE)
				elif d > demi * 0.5:
					t.p(x, y, ORANGE)
				else:
					t.p(x, y, JAUNE)


static func _tete_de_comete(t: Toile) -> void:
	for y: int in t.h:
		for x: int in t.w:
			var d: float = Vector2(x + 0.5 - 10.5, y + 0.5 - 8.0).length()
			if d > 5.0:
				continue
			if d > 4.0:
				t.p(x, y, ROUGE_SOMBRE)
			elif d > 2.8:
				t.p(x, y, ORANGE)
			elif d > 1.5:
				t.p(x, y, JAUNE)
			else:
				t.p(x, y, BLANC)


static func _braise() -> Image:
	var img: Image = _vierge("braise")
	var rouges: Array = [
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(3, 2), Vector2i(2, 3)],
		[Vector2i(2, 0), Vector2i(3, 1), Vector2i(0, 2), Vector2i(1, 3)],
	]
	for i: int in 2:
		var t: Toile = _toile(img, "braise", i)
		for dy: int in 2:
			for dx: int in 2:
				t.p(1 + dx, 1 + dy, ORANGE)
		for v: Vector2i in rouges[i]:
			t.p(v.x, v.y, ROUGE_SOMBRE)
		t.p(1 + i, 1 + i, JAUNE)
	return img


## Boule de flamme au bord déchiré : `seuils` donne la profondeur (0 au cœur, 1 au bord) où l'on
## passe du rouge à l'orange, de l'orange au jaune, du jaune au blanc.
static func _boule_de_flamme(
	t: Toile, rng: RandomNumberGenerator, rayon: float, amplitude: float, seuils: Array[float]
) -> void:
	var n: int = 14
	var bruit: PackedFloat32Array = PackedFloat32Array()
	for k: int in n:
		bruit.append(rng.randf_range(-amplitude, amplitude))
	var c: Vector2 = Vector2(t.w / 2.0, t.h / 2.0)
	for y: int in t.h:
		for x: int in t.w:
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - c
			var u: float = fposmod(d.angle(), TAU) / TAU * n
			var k0: int = int(u) % n
			var bord: float = rayon + lerpf(bruit[k0], bruit[(k0 + 1) % n], u - floorf(u))
			if d.length() > bord:
				continue
			var prof: float = d.length() / bord
			if prof > seuils[0]:
				t.p(x, y, ROUGE_SOMBRE)
			elif prof > seuils[1]:
				t.p(x, y, ORANGE)
			elif prof > seuils[2]:
				t.p(x, y, JAUNE)
			else:
				t.p(x, y, BLANC)


## Gouttelettes de feu ou de fumée en couronne autour du centre.
static func _bouffees(
	t: Toile, rng: RandomNumberGenerator, nombre: int, dist: Vector2, rayon: Vector2, couleur: Color
) -> void:
	for k: int in nombre:
		var a: float = TAU * k / nombre + rng.randf_range(-0.25, 0.25)
		var d: float = rng.randf_range(dist.x, dist.y)
		var r: float = rng.randf_range(rayon.x, rayon.y)
		var c: Vector2 = Vector2(t.w / 2.0, t.h / 2.0) + Vector2.from_angle(a) * d
		t.disque(c.x, c.y, r, couleur)


static func _explosion_feu() -> Image:
	var img: Image = _vierge("explosion_feu")
	var rng: RandomNumberGenerator = _hasard()
	var seuils_1: Array[float] = [0.7, 0.45, 0.0]
	var seuils_2: Array[float] = [0.85, 0.6, 0.3]
	var seuils_3: Array[float] = [0.85, 0.45, 0.2]
	_boule_de_flamme(_toile(img, "explosion_feu", 0), rng, 6.0, 0.6, seuils_1)
	_boule_de_flamme(_toile(img, "explosion_feu", 1), rng, 10.0, 2.5, seuils_2)
	_boule_de_flamme(_toile(img, "explosion_feu", 2), rng, 13.0, 3.0, seuils_3)
	var f4: Toile = _toile(img, "explosion_feu", 3)
	f4.disque(16.0, 16.0, 5.5, ROUGE_SOMBRE)
	f4.disque(15.5, 15.5, 3.5, ORANGE)
	for k: int in 11:
		var a: float = TAU * k / 11.0 + rng.randf_range(-0.2, 0.2)
		var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * rng.randf_range(8.5, 13.0)
		var r: float = rng.randf_range(1.8, 3.0)
		f4.disque(c.x, c.y, r, ROUGE_SOMBRE)
		f4.disque(c.x - 0.5, c.y - 0.5, r - 0.8, ORANGE)
	for k: int in 5:
		var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * 7.0
		f4.p(roundi(c.x), roundi(c.y), JAUNE)
	var f5: Toile = _toile(img, "explosion_feu", 4)
	_bouffees(f5, rng, 7, Vector2(6.5, 11.0), Vector2(2.8, 4.0), FUMEE)
	f5.entourer(ENCRE)
	for k: int in 6:
		var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * 13.0
		var x: int = roundi(c.x)
		var y: int = roundi(c.y)
		f5.p(x, y, ORANGE)
		f5.p(x + 1, y, JAUNE)
	var f6: Toile = _toile(img, "explosion_feu", 5)
	for k: int in 9:
		var c: Vector2 = (
			Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(7.0, 14.0)
		)
		f6.p(roundi(c.x), roundi(c.y), FUMEE if k % 3 != 2 else ENCRE)
		if k % 2 == 0:
			f6.p(roundi(c.x) + 1, roundi(c.y), FUMEE)
	return img


# ----------------------------------------------------------------------------- glace


## Éclat de cristal : un cerf-volant dont la face haute est claire, la face basse cyan, la
## pointe devant. `angle` en radians, `longueur` et `largeur` en pixels.
static func _cristal(
	t: Toile, cx: float, cy: float, angle: float, longueur: float, largeur: float
) -> void:
	var dir: Vector2 = Vector2.from_angle(angle)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	if perp.dot(Vector2(-1, -1)) < 0.0:
		perp = -perp
	var c: Vector2 = Vector2(cx, cy)
	var pts: PackedVector2Array = PackedVector2Array(
		[
			c + dir * longueur * 0.5,
			c + perp * largeur * 0.5 - dir * longueur * 0.15,
			c - dir * longueur * 0.5,
			c - perp * largeur * 0.5 - dir * longueur * 0.15,
		]
	)
	for y: int in t.h:
		for x: int in t.w:
			var q: Vector2 = Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(q, pts):
				continue
			var s: float = (q - c).dot(perp) / (largeur * 0.5)
			t.p(x, y, GLACE_PALE if s > 0.35 else (GLACE_PALE if s > -0.2 else GLACE_CYAN))
	t.p(roundi(cx), roundi(cy), GLACE_PALE)


static func _eclat_glace() -> Image:
	var img: Image = _vierge("eclat_glace")
	var t: Toile = _toile(img, "eclat_glace", 0)
	for x: int in range(3, 19):
		var u: float = (x - 3) / 15.0
		var demi: float = 2.6 * (1.0 - u * u) + 0.4
		for y: int in t.h:
			var d: float = y + 0.5 - 4.0
			if absf(d) > demi:
				continue
			if d < 0.0 and d > -demi + 1.0:
				t.p(x, y, GLACE_PALE)
			elif d < 0.0:
				t.p(x, y, BLANC)
			else:
				t.p(x, y, GLACE_CYAN)
	for y: int in range(2, 6):
		t.p(3, y, GLACE_CYAN)
	t.entourer(GLACE_PROFOND)
	return img


static func _brisure_glace() -> Image:
	var img: Image = _vierge("brisure_glace")
	var rng: RandomNumberGenerator = _hasard()
	var f1: Toile = _toile(img, "brisure_glace", 0)
	for a: int in 4:
		var v: Vector2 = Vector2.from_angle(a * PI / 2.0)
		f1.ligne(16, 16, 16 + roundi(v.x * 8), 16 + roundi(v.y * 8), BLANC)
		var w: Vector2 = Vector2.from_angle(a * PI / 2.0 + PI / 4.0)
		f1.ligne(16, 16, 16 + roundi(w.x * 5), 16 + roundi(w.y * 5), GLACE_PALE)
	f1.disque(16.0, 16.0, 2.2, BLANC)
	f1.entourer(GLACE_PROFOND)
	var etapes: Array = [[6.0, 7.0, 3.0], [10.0, 6.0, 3.0], [13.0, 5.0, 2.5]]
	for i: int in 3:
		var t: Toile = _toile(img, "brisure_glace", i + 1)
		var nombre: int = 6 + i % 2 * 2
		for k: int in nombre:
			var a: float = TAU * k / nombre + 0.4 + rng.randf_range(-0.2, 0.2)
			var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * etapes[i][0]
			_cristal(t, c.x, c.y, a, etapes[i][1], etapes[i][2])
		t.entourer(GLACE_PROFOND)
	var f5: Toile = _toile(img, "brisure_glace", 4)
	for k: int in 8:
		var a: float = TAU * k / 8.0 + 0.2
		var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * 13.0
		_cristal(f5, c.x, c.y, a, 3.0, 2.0)
	f5.entourer(GLACE_PROFOND)
	for k: int in 8:
		var c: Vector2 = (
			Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 14.0)
		)
		f5.p_si_vide(roundi(c.x), roundi(c.y), GLACE_PALE)
	var f6: Toile = _toile(img, "brisure_glace", 5)
	for k: int in 7:
		var c: Vector2 = (
			Vector2(16, 16) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, 15.0)
		)
		f6.p(roundi(c.x), roundi(c.y), GLACE_PALE if k % 2 == 0 else GLACE_CYAN)
	return img


static func _givre_sol() -> Image:
	var img: Image = _vierge("givre_sol")
	var t: Toile = _toile(img, "givre_sol", 0)
	for k: int in 14:
		var a: float = TAU * k / 14.0 + 0.2
		var base: Vector2 = Vector2(16.0 + cos(a) * 11.5, 8.0 + sin(a) * 5.0)
		var pointe: Vector2 = Vector2(16.0 + cos(a) * 14.0, 8.0 + sin(a) * 6.4)
		t.ligne(roundi(base.x), roundi(base.y), roundi(pointe.x), roundi(pointe.y), GLACE_CYAN)
		t.p(roundi(pointe.x), roundi(pointe.y), BLANC)
		t.p(roundi(base.x), roundi(base.y), GLACE_PALE)
	for centre: Vector2i in [Vector2i(11, 6), Vector2i(21, 10), Vector2i(16, 8), Vector2i(8, 10)]:
		t.p(centre.x, centre.y, BLANC)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			t.p(centre.x + d.x, centre.y + d.y, GLACE_PALE)
	t.entourer(GLACE_PROFOND)
	for y: int in t.h:
		for x: int in t.w:
			var u: float = (x + 0.5 - 16.0) / 12.0
			var v: float = (y + 0.5 - 8.0) / 4.6
			if u * u + v * v <= 1.0 and (x + y) % 2 == 0:
				t.p_si_vide(x, y, GLACE_PALE)
	return img


# ----------------------------------------------------------------------------- bombe


static func _bombe() -> Image:
	var img: Image = _vierge("bombe")
	for i: int in 2:
		var t: Toile = _toile(img, "bombe", i)
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
	var img: Image = _vierge("ombre")
	_toile(img, "ombre", 0).ellipse(6.0, 3.0, 5.8, 2.8, ENCRE)
	return img


# ----------------------------------------------------------------------------- poison


static func _fiole() -> Image:
	var img: Image = _vierge("fiole")
	var t: Toile = _toile(img, "fiole", 0)
	for y: int in range(1, 3):
		for x: int in range(3, 7):
			t.p(x, y, BOUCHON)
	for y: int in range(3, 5):
		t.p(4, y, VERRE)
		t.p(5, y, VERRE)
	for y: int in t.h:
		for x: int in t.w:
			var dx: float = x + 0.5 - 5.0
			var dy: float = y + 0.5 - 8.5
			if Vector2(dx, dy).length() > 3.9:
				continue
			if y < 8:
				t.p(x, y, VERRE)
			elif dx + dy > 3.0:
				t.p(x, y, POISON_FONCE)
			else:
				t.p(x, y, POISON)
	t.p(2, 6, BLANC)
	t.p(2, 7, BLANC)
	t.p(3, 5, BLANC)
	t.entourer(POISON_CONTOUR)
	return img


## Tache irrégulière : un disque au bord déchiré, ombré en bas à droite, clair en haut à gauche.
static func _tache(
	t: Toile, rng: RandomNumberGenerator, c: Vector2, rayon: float, amp: float
) -> void:
	var n: int = 10
	var bruit: PackedFloat32Array = PackedFloat32Array()
	for k: int in n:
		bruit.append(rng.randf_range(-amp, amp))
	for y: int in t.h:
		for x: int in t.w:
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - c
			var u: float = fposmod(d.angle(), TAU) / TAU * n
			var k0: int = int(u) % n
			var bord: float = rayon + lerpf(bruit[k0], bruit[(k0 + 1) % n], u - floorf(u))
			if d.length() > bord:
				continue
			if d.x + d.y > bord * 0.45:
				t.p(x, y, POISON_FONCE)
			elif d.x + d.y < -bord * 0.6:
				t.p(x, y, POISON_PALE)
			else:
				t.p(x, y, POISON)


static func _goutte(t: Toile, c: Vector2, r: float) -> void:
	t.disque(c.x, c.y, r, POISON)
	t.p(roundi(c.x - 0.5) - 1, roundi(c.y - 0.5) - 1, POISON_PALE)
	t.p(roundi(c.x + 0.5), roundi(c.y + 0.5), POISON_FONCE)


static func _eclaboussure_poison() -> Image:
	var img: Image = _vierge("eclaboussure_poison")
	var rng: RandomNumberGenerator = _hasard()
	var f1: Toile = _toile(img, "eclaboussure_poison", 0)
	_tache(f1, rng, Vector2(16, 16), 7.0, 3.0)
	for k: int in 5:
		var a: float = TAU * k / 5.0 + 0.5
		var c: Vector2 = Vector2(16, 16) + Vector2.from_angle(a) * 4.5
		var dir: Vector2 = Vector2.from_angle(a)
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var pts: PackedVector2Array = PackedVector2Array(
			[c + dir * 2.8, c + perp * 1.4, c - dir * 2.8, c - perp * 1.4]
		)
		for y: int in f1.h:
			for x: int in f1.w:
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
					f1.p(x, y, BLANC if (x + y) % 2 == 0 else VERRE)
	f1.entourer(POISON_CONTOUR)
	var etapes: Array = [[8.0, 2.2, 5.0], [11.5, 1.8, 3.8], [14.5, 1.3, 2.6]]
	for i: int in 3:
		var t: Toile = _toile(img, "eclaboussure_poison", i + 1)
		_tache(t, rng, Vector2(16, 16), etapes[i][2], 1.2)
		for k: int in 8:
			var a: float = TAU * k / 8.0 + 0.3 + rng.randf_range(-0.15, 0.15)
			var d: float = etapes[i][0] + rng.randf_range(-1.0, 1.0)
			_goutte(t, Vector2(16, 16) + Vector2.from_angle(a) * d, etapes[i][1])
		t.entourer(POISON_CONTOUR)
	var f5: Toile = _toile(img, "eclaboussure_poison", 4)
	for f: Array in FLAQUES:
		var c: Vector2 = f[0]
		f5.ellipse(c.x, c.y, f[1], f[2], POISON_FONCE)
		f5.ellipse(c.x - 0.5, c.y - 0.6, f[1] - 1.0, f[2] - 0.8, POISON)
		f5.p(roundi(c.x) - 1, roundi(c.y) - 1, POISON_PALE)
	f5.entourer(POISON_CONTOUR)
	var f6: Toile = _toile(img, "eclaboussure_poison", 5)
	for f: Array in FLAQUES:
		var c: Vector2 = f[0]
		for y: int in f6.h:
			for x: int in f6.w:
				var u: float = (x + 0.5 - c.x) / (f[1] * 0.8)
				var v: float = (y + 0.5 - c.y) / (f[2] * 0.8)
				if u * u + v * v <= 1.0 and (x + y) % 2 == 0:
					f6.p(x, y, POISON_FONCE if u + v > 0.0 else POISON)
	return img


static func _nuage_poison() -> Image:
	var img: Image = _vierge("nuage_poison")
	var lobes: Array = [
		[Vector2(5.5, 9.5), 3.5],
		[Vector2(10.5, 9.5), 3.5],
		[Vector2(8.0, 6.5), 3.3],
		[Vector2(8.0, 10.5), 3.5],
	]
	var bulles: Array = [
		[Vector2i(5, 8), Vector2i(10, 6)],
		[Vector2i(6, 9), Vector2i(10, 10)],
		[Vector2i(9, 7), Vector2i(5, 10)],
	]
	for i: int in 3:
		var t: Toile = _toile(img, "nuage_poison", i)
		for k: int in lobes.size():
			var c: Vector2 = lobes[k][0]
			var decalage: Vector2 = Vector2(sin(i * 2.1 + k * 1.3), cos(i * 1.7 + k * 2.3)) * 0.7
			t.disque(c.x + decalage.x, c.y + decalage.y, float(lobes[k][1]) + 0.2 * (i % 2), POISON)
		for y: int in t.h:
			for x: int in t.w:
				if not t.opaque(x, y):
					continue
				var s: float = x + 0.5 + y + 0.5 - 16.0
				if s > 3.5:
					t.p(x, y, POISON_FONCE)
				elif s < -3.5:
					t.p(x, y, POISON_PALE)
		for b: Vector2i in bulles[i]:
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				t.p(b.x + d.x, b.y + d.y, POISON_PALE)
			t.p(b.x, b.y, POISON)
		t.entourer(POISON_FONCE)
	return img


# ----------------------------------------------------------------------------- arcane


static func _rune() -> Image:
	var img: Image = _vierge("rune")
	var pulsations: Array = [[2.6, 1.0], [3.2, 1.6], [3.6, 2.2], [3.2, 1.6]]
	for i: int in 4:
		var t: Toile = _toile(img, "rune", i)
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
	var img: Image = _vierge("eclat_rune")
	var rng: RandomNumberGenerator = _hasard()
	var f1: Toile = _toile(img, "eclat_rune", 0)
	f1.disque(12.0, 12.0, 2.2, BLANC)
	for a: int in 4:
		var v: Vector2 = Vector2.from_angle(a * PI / 2.0)
		f1.ligne(12, 12, 12 + roundi(v.x * 5), 12 + roundi(v.y * 5), ARCANE_CLAIR)
	f1.entourer(ARCANE_NUIT)
	var rayons: Array = [5.0, 8.0, 10.0]
	for i: int in 3:
		var t: Toile = _toile(img, "eclat_rune", i + 1)
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
	var f5: Toile = _toile(img, "eclat_rune", 4)
	var teintes: Array[Color] = [BLANC, ARCANE_CLAIR, ARCANE_BLEU]
	for k: int in 13:
		var c: Vector2 = (
			Vector2(12, 12) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 10.5)
		)
		f5.p(roundi(c.x), roundi(c.y), teintes[k % 3])
	return img


# ----------------------------------------------------------------------------- foudre, départ


static func _etincelle() -> Image:
	var img: Image = _vierge("etincelle")
	var f1: Toile = _toile(img, "etincelle", 0)
	f1.disque(4.0, 4.0, 1.4, BLANC)
	for v: Vector2i in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 5), Vector2i(4, 5)]:
		f1.p(v.x, v.y, FOUDRE_LAVANDE)
		f1.p(v.y, v.x, FOUDRE_LAVANDE)
	for v: Vector2i in [Vector2i(3, 1), Vector2i(4, 1), Vector2i(3, 6), Vector2i(4, 6)]:
		f1.p(v.x, v.y, FOUDRE_VIOLET)
		f1.p(v.y, v.x, FOUDRE_VIOLET)
	f1.entourer(FOUDRE_SOMBRE)
	var f2: Toile = _toile(img, "etincelle", 1)
	f2.disque(4.0, 4.0, 1.4, BLANC)
	for v: Vector2i in [Vector2i(2, 2), Vector2i(5, 5), Vector2i(2, 5), Vector2i(5, 2)]:
		f2.p(v.x, v.y, FOUDRE_LAVANDE)
	for v: Vector2i in [Vector2i(1, 1), Vector2i(6, 6), Vector2i(1, 6), Vector2i(6, 1)]:
		f2.p(v.x, v.y, FOUDRE_VIOLET)
	f2.entourer(FOUDRE_SOMBRE)
	var f3: Toile = _toile(img, "etincelle", 2)
	f3.p(3, 3, BLANC)
	f3.p(4, 4, BLANC)
	f3.p(3, 4, FOUDRE_LAVANDE)
	f3.p(4, 3, FOUDRE_LAVANDE)
	for v: Vector2i in [Vector2i(2, 3), Vector2i(5, 4), Vector2i(3, 2), Vector2i(4, 5)]:
		f3.p(v.x, v.y, FOUDRE_VIOLET)
	f3.entourer(FOUDRE_SOMBRE)
	var f4: Toile = _toile(img, "etincelle", 3)
	for v: Vector2i in [
		Vector2i(1, 1), Vector2i(6, 1), Vector2i(1, 6), Vector2i(6, 6), Vector2i(3, 0)
	]:
		f4.p(v.x, v.y, FOUDRE_VIOLET)
	f4.p(2, 5, FOUDRE_LAVANDE)
	f4.p(5, 2, FOUDRE_LAVANDE)
	f4.p(4, 4, BLANC)
	return img


static func _depart() -> Image:
	var img: Image = _vierge("depart")
	var f1: Toile = _toile(img, "depart", 0)
	f1.disque(6.0, 6.0, 1.2, BLANC)
	var f2: Toile = _toile(img, "depart", 1)
	for a: int in 4:
		var v: Vector2 = Vector2.from_angle(a * PI / 2.0)
		f2.ligne(6, 6, 6 + roundi(v.x * 3), 6 + roundi(v.y * 3), BLANC)
		f2.p(6 + roundi(v.x * 4), 6 + roundi(v.y * 4), GRIS_CLAIR)
		var w: Vector2 = Vector2.from_angle(a * PI / 2.0 + PI / 4.0)
		f2.p(6 + roundi(w.x * 2), 6 + roundi(w.y * 2), GRIS_CLAIR)
	f2.disque(6.0, 6.0, 1.5, BLANC)
	var f3: Toile = _toile(img, "depart", 2)
	for y: int in f3.h:
		for x: int in f3.w:
			var d: float = Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0).length()
			if absf(d - 4.6) <= 0.7 and (x + y) % 2 == 0:
				f3.p(x, y, GRIS_CLAIR)
	for a: int in 4:
		var v: Vector2 = Vector2.from_angle(a * PI / 2.0) * 4.5
		f3.p(6 + roundi(v.x - 0.5), 6 + roundi(v.y - 0.5), BLANC)
	return img
