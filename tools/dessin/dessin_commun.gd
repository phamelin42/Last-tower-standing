extends RefCounted
## Ce que partagent les dessins des sprites d'effets d'attaques (`tools/dessiner_effets_attaques.gd`
## et un fichier `dessins_<élément>.gd` par élément) : la palette, la liste des planches, la toile
## de dessin en pixels, une bande vierge et le hasard à graine fixe.

const GRAINE: int = 22
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
## Acier, cuivre, vapeur.
const ACIER_BLANC := Color("ffffff")
const ACIER_CLAIR := Color("cfd8e6")
const ACIER := Color("8896ad")
const ACIER_CONTOUR := Color("1c2233")
const CUIVRE_CLAIR := Color("f0b070")
const CUIVRE := Color("d9843b")
const CUIVRE_BRUN := Color("7a431f")
const VAPEUR_CLAIR := Color("f2f4f8")
const VAPEUR := Color("aab2c0")
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
	"lame_croissant": {"taille": Vector2i(16, 16), "images": 4},
	"entaille": {"taille": Vector2i(24, 24), "images": 4},
	"faucille": {"taille": Vector2i(16, 16), "images": 1},
	"balayage": {"taille": Vector2i(32, 32), "images": 6},
	"disque_scie": {"taille": Vector2i(14, 14), "images": 2},
	"lame_cuivre": {"taille": Vector2i(16, 8), "images": 1},
	"lame_tournante": {"taille": Vector2i(12, 12), "images": 2},
	"arc_lame": {"taille": Vector2i(12, 32), "images": 1},
	"vapeur": {"taille": Vector2i(16, 16), "images": 3},
	"eclat_acier": {"taille": Vector2i(24, 24), "images": 4},
}


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


## Une bande vierge, transparente, de la planche `nom`.
static func vierge(nom: String) -> Image:
	var taille: Vector2i = PLANCHES[nom]["taille"]
	var n: int = PLANCHES[nom]["images"]
	var img: Image = Image.create_empty(taille.x * n, taille.y, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	return img


## L'image `i` de la bande `img` de la planche `nom`.
static func toile(img: Image, nom: String, i: int) -> Toile:
	var taille: Vector2i = PLANCHES[nom]["taille"]
	return Toile.new(img, i * taille.x, taille.x, taille.y)


static func hasard() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = GRAINE
	return rng
