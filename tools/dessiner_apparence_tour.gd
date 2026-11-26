extends SceneTree
## Dessine les 18 superpositions de la tour (6 statistiques × 3 paliers, D19) dans le style de Tiny
## Swords : aplats, gros pixels, contour sombre. Code Godot seul (`Image`), sans hasard ni outil
## propriétaire : la même exécution écrit les mêmes octets. Les images sont créées pour le jeu et
## mises en CC0 (`assets/tour_apparence/SOURCES.md`).
##   godot --headless --path . --script res://tools/dessiner_apparence_tour.gd
## Chaque image est centrée sur l'ancrage de `data/skins_tour.json` ; la tour qui grandit n'a pas
## d'image. Les images d'une statistique ont toutes le même cadre sauf la bulle de mana, qui
## grandit avec son palier.

const SORTIE := "res://assets/tour_apparence"
const TOUR := "res://assets/tiny_swords/Factions/Knights/Buildings/Tower/Tower_Blue.png"
const VIDE := Color(0, 0, 0, 0)
const ENCRE := Color("161c2e")
const FER := Color("9aa3b5")
const FER_OMBRE := Color("5a6480")
const FER_CLAIR := Color("e6ebf5")
const OR := Color("e8b04a")
const BLEU := Color("4a8cff")
const BLEU_CLAIR := Color("9fd0ff")
const VERT := Color("5be37a")
const VERT_CLAIR := Color("d8ffd0")
const SANG := Color("d1303a")
const SANG_FONCE := Color("7a1020")
const SPECTRE := Color("cfe8ff")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE))
	var tour := Image.load_from_file(ProjectSettings.globalize_path(TOUR))
	tour.convert(Image.FORMAT_RGBA8)
	for p: int in range(1, 4):
		_ecrire("epines", p, _epines(p))
		_ecrire("mana", p, _mana(p))
		_ecrire("armure", p, _armure(p))
		_ecrire("esquive", p, _esquive(p, tour))
		_ecrire("regen", p, _regen(p))
		_ecrire("vol_de_vie", p, _vol_de_vie(p))
	quit(0)


func _ecrire(stat: String, palier: int, img: Image) -> void:
	var chemin := ProjectSettings.globalize_path("%s/%s_%d.png" % [SORTIE, stat, palier])
	if img.save_png(chemin) != OK:
		printerr("Écriture impossible : %s" % chemin)


func _toile(l: int, h: int) -> Image:
	var img := Image.create(l, h, false, Image.FORMAT_RGBA8)
	img.fill(VIDE)
	return img


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _rect(img: Image, x: int, y: int, l: int, h: int, c: Color) -> void:
	for j: int in h:
		for i: int in l:
			_px(img, x + i, y + j, c)


## Contour sombre d'un pixel autour de tout ce qui est opaque, comme les sprites du pack.
func _contour(img: Image) -> void:
	var copie := img.duplicate() as Image
	for y: int in img.get_height():
		for x: int in img.get_width():
			if copie.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < img.get_width() and ny < img.get_height():
					if copie.get_pixel(nx, ny).a > 0.5:
						img.set_pixel(x, y, ENCRE)
						break


## Triangle plein (pointes de piques), par balayage.
func _triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, couleur: Color) -> void:
	var x0 := int(floorf(minf(a.x, minf(b.x, c.x))))
	var x1 := int(ceilf(maxf(a.x, maxf(b.x, c.x))))
	var y0 := int(floorf(minf(a.y, minf(b.y, c.y))))
	var y1 := int(ceilf(maxf(a.y, maxf(b.y, c.y))))
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
			var d2 := (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
			var d3 := (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
			var neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
			var pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
			if not (neg and pos):
				_px(img, x, y, couleur)


## Piques de fer sur le mur : une rangée (palier 1), deux (2 et 3), de plus en plus longues.
func _epines(palier: int) -> Image:
	var img := _toile(120, 44)
	var nombre: int = [5, 7, 9][palier - 1]
	var longueur: float = [10.0, 13.0, 16.0][palier - 1]
	var rangees: int = 1 if palier == 1 else 2
	for r: int in rangees:
		var n := nombre - r
		for i: int in n:
			var t := (float(i) + 0.5) / float(n)
			var dx := (t - 0.5) * 2.0
			var x := 10.0 + t * 100.0
			var y := 8.0 + 6.0 * (1.0 - dx * dx) + 10.0 * r
			var l := longueur - 3.0 * r
			var pointe := Vector2(x + dx * 4.0, y + l)
			_triangle(img, Vector2(x - 4.5, y), Vector2(x + 4.5, y), pointe, FER)
			_triangle(img, Vector2(x, y), Vector2(x + 4.5, y), pointe, FER_OMBRE)
			_px(img, int(pointe.x), int(pointe.y) - 1, FER_CLAIR)
			_rect(img, int(x) - 5, int(y) - 2, 10, 3, FER_OMBRE)
	_contour(img)
	return img


## Bulle bleue : plus large et plus opaque à chaque palier.
func _mana(palier: int) -> Image:
	var tailles: Array[Vector2i] = [Vector2i(84, 104), Vector2i(104, 136), Vector2i(124, 176)]
	var alpha: float = [0.24, 0.34, 0.46][palier - 1]
	var t: Vector2i = tailles[palier - 1]
	var img := _toile(t.x, t.y)
	var c := Vector2(t.x / 2.0, t.y / 2.0)
	var rx := t.x / 2.0 - 1.0
	var ry := t.y / 2.0 - 1.0
	for y: int in t.y:
		for x: int in t.x:
			var u := (x + 0.5 - c.x) / rx
			var v := (y + 0.5 - c.y) / ry
			var r2 := u * u + v * v
			if r2 > 1.0:
				continue
			var a := alpha
			if r2 > 0.78:
				a = minf(alpha + 0.4, 0.9)
			img.set_pixel(x, y, Color(BLEU.r, BLEU.g, BLEU.b, a))
	# Reflet : un arc clair en haut à gauche et deux points.
	for k: int in 14:
		var ang := PI * (1.12 + 0.28 * float(k) / 13.0)
		_px(img, int(c.x + cos(ang) * rx * 0.72), int(c.y + sin(ang) * ry * 0.72), BLEU_CLAIR)
		_px(img, int(c.x + cos(ang) * rx * 0.72), int(c.y + sin(ang) * ry * 0.72) + 1, BLEU_CLAIR)
	_rect(img, int(c.x - rx * 0.45), int(c.y - ry * 0.35), 3, 3, Color.WHITE)
	return img


## Couches de plaques d'acier : une rangée, deux, trois, rivets dorés au dernier palier.
func _armure(palier: int) -> Image:
	var img := _toile(100, 56)
	for r: int in palier:
		var decalage := 0 if r % 2 == 0 else 12
		var n := 4 if r % 2 == 0 else 3
		for i: int in n:
			var x := 2 + decalage + 24 * i
			var y := 2 + 14 * r
			_rect(img, x, y, 23, 16, FER)
			_rect(img, x, y + 11, 23, 5, FER_OMBRE)
			_rect(img, x + 2, y + 1, 17, 2, FER_CLAIR)
			for coin: Vector2i in [
				Vector2i(0, 0), Vector2i(22, 0), Vector2i(0, 15), Vector2i(22, 15)
			]:
				_px(img, x + coin.x, y + coin.y, VIDE)
			if palier == 3:
				_px(img, x + 3, y + 5, OR)
				_px(img, x + 19, y + 5, OR)
	_contour(img)
	return img


## Images rémanentes : la silhouette de la tour décalée à gauche et à droite, sans ses pixels déjà
## couverts par la tour (la superposition ne dépend pas de l'ordre de dessin).
func _esquive(palier: int, tour: Image) -> Image:
	var decalages: Array = [[7], [8, -8], [7, -7, 15, -15]][palier - 1]
	var alphas: Array = [[0.55], [0.5, 0.5], [0.5, 0.5, 0.3, 0.3]][palier - 1]
	var img := _toile(128, 256)
	for k: int in decalages.size():
		var dx: int = decalages[k]
		var a: float = alphas[k]
		for y: int in 256:
			for x: int in 128:
				var sx := x - dx
				if sx < 0 or sx >= 128 or tour.get_pixel(sx, y).a < 0.5:
					continue
				if tour.get_pixel(x, y).a >= 0.5 or img.get_pixel(x, y).a >= a:
					continue
				img.set_pixel(x, y, Color(SPECTRE.r, SPECTRE.g, SPECTRE.b, a))
	return img


## Lueur verte autour du mur, et des étincelles en croix : 3, 6 puis 9.
func _regen(palier: int) -> Image:
	var img := _toile(128, 110)
	var alpha: float = [0.22, 0.32, 0.42][palier - 1]
	for y: int in 110:
		for x: int in 128:
			var u := (x + 0.5 - 64.0) / 63.0
			var v := (y + 0.5 - 55.0) / 54.0
			var r2 := u * u + v * v
			if r2 <= 1.0:
				var a := alpha * (1.0 - r2 * 0.6) if r2 < 0.9 else alpha * 0.4
				img.set_pixel(x, y, Color(VERT.r, VERT.g, VERT.b, a))
	var nombre: int = [3, 6, 9][palier - 1]
	for i: int in nombre:
		var ang := TAU * float(i) / float(nombre) + 0.4
		var rayon := 30.0 + 16.0 * float(i % 3)
		var cx := int(64.0 + cos(ang) * rayon * 1.5)
		var cy := int(55.0 + sin(ang) * rayon * 0.8)
		_rect(img, cx - 1, cy - 3, 3, 7, VERT_CLAIR)
		_rect(img, cx - 3, cy - 1, 7, 3, VERT_CLAIR)
		_px(img, cx, cy, Color.WHITE)
	return img


## Filets rouges aspirés vers la tour : 2, 4 ou 6 courbes, avec des gouttes sur leur trajet.
func _vol_de_vie(palier: int) -> Image:
	var img := _toile(128, 130)
	var nombre: int = [2, 4, 6][palier - 1]
	var cible := Vector2(64.0, 62.0)
	for i: int in nombre:
		var cote := -1.0 if i % 2 == 0 else 1.0
		var depart := Vector2(64.0 + cote * 60.0, 14.0 + 20.0 * float(i / 2) + 6.0 * float(i % 2))
		var controle := Vector2(64.0 + cote * 30.0, depart.y + 46.0)
		for k: int in 41:
			var t := float(k) / 40.0
			var p := (1 - t) * (1 - t) * depart + 2 * (1 - t) * t * controle + t * t * cible
			var epaisseur := 2 if t < 0.8 else 1
			_rect(img, int(p.x), int(p.y), epaisseur + 1, epaisseur + 1, SANG)
			if k % 10 == 5:
				_rect(img, int(p.x) - 1, int(p.y) - 1, 4, 4, SANG_FONCE)
				_px(img, int(p.x), int(p.y), SANG)
	_contour(img)
	return img
