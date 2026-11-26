extends SceneTree
## Dessine les superpositions de la tour (6 statistiques × 3 paliers, D19) dans le style de Tiny
## Swords : aplats, gros pixels, contour sombre. Chaque effet fait le tour de la tour : il a
## deux couches : `arriere` (derrière le sprite de la tour) et `avant` (devant), de même taille et
## posées au même ancrage de `data/skins_tour.json`. Les formes sont des ellipses vues en
## perspective, plus sombres et plus étroites sur les côtés et à l'arrière. Les tailles, longueurs
## et angles varient (graine fixe) : la même exécution écrit les mêmes octets. Code Godot seul
## (`Image`), sans outil propriétaire ni IA ; images en CC0 (`assets/tour_apparence/SOURCES.md`).
##   godot --headless --path . --script res://tools/dessiner_apparence_tour.gd
## Les ceintures de piques et les filets du palier 3 ont en plus des images d'un tour lent (`*_a1` à
## `*_a3`, l'image de base étant la première) pour la rangée « vue animée » de la planche.

const SORTIE := "res://assets/tour_apparence"
const TOUR := "res://assets/tiny_swords/Factions/Knights/Buildings/Tower/Tower_Blue.png"
const VIDE := Color(0, 0, 0, 0)
const ENCRE := Color("161c2e")
const FER := Color("9aa3b5")
const FER_OMBRE := Color("4a5268")
const FER_CLAIR := Color("e6ebf5")
const OR := Color("e8b04a")
const BLEU := Color("4a8cff")
const BLEU_CLAIR := Color("9fd0ff")
const VERT := Color("5be37a")
const VERT_CLAIR := Color("d8ffd0")
const SANG := Color("d1303a")
const SANG_FONCE := Color("6a0e1c")
const SPECTRE := Color("cfe8ff")
const GRAINE := 24
const IMAGES_ANIMEES := 4

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE))
	var tour := Image.load_from_file(ProjectSettings.globalize_path(TOUR))
	tour.convert(Image.FORMAT_RGBA8)
	for p: int in range(1, 4):
		_ecrire("epines", p, "", _epines(p, 0))
		_ecrire("mana", p, "", _mana(p))
		_ecrire("armure", p, "", _armure(p))
		_ecrire("esquive", p, "", _esquive(p, tour))
		_ecrire("regen", p, "", _regen(p))
		_ecrire("vol_de_vie", p, "", _vol_de_vie(p, 0))
	for k: int in range(1, IMAGES_ANIMEES):
		_ecrire("epines", 3, "_a%d" % k, _epines(3, k))
		_ecrire("vol_de_vie", 3, "_a%d" % k, _vol_de_vie(3, k))
	quit(0)


func _ecrire(stat: String, palier: int, suffixe: String, couches: Dictionary) -> void:
	for couche: String in ["arriere", "avant"]:
		var img: Image = couches[couche]
		var nom := "%s/%s_%d_%s%s.png" % [SORTIE, stat, palier, couche, suffixe]
		if img.save_png(ProjectSettings.globalize_path(nom)) != OK:
			printerr("Écriture impossible : %s" % nom)


func _couches(l: int, h: int) -> Dictionary:
	var a := Image.create(l, h, false, Image.FORMAT_RGBA8)
	var b := Image.create(l, h, false, Image.FORMAT_RGBA8)
	a.fill(VIDE)
	b.fill(VIDE)
	return {"arriere": a, "avant": b}


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


func _quad(img: Image, a: Vector2, b: Vector2, c: Vector2, d: Vector2, couleur: Color) -> void:
	_triangle(img, a, b, c, couleur)
	_triangle(img, a, c, d, couleur)


## Couleur de fer à l'éclairage `lumiere` (0 sombre, 1 clair).
func _fer(lumiere: float) -> Color:
	if lumiere < 0.5:
		return FER_OMBRE.lerp(FER, lumiere * 2.0)
	return FER.lerp(FER_CLAIR, (lumiere - 0.5) * 1.4)


## Ceinture de piques autour du bas de la cuvette : longueurs, épaisseurs et angles varient ; plus
## courtes et plus pentues sur les côtés, à peine visibles derrière. `tour` : quart de pas tourné.
func _epines(palier: int, tour: int) -> Dictionary:
	var c := _couches(128, 84)
	_rng.seed = GRAINE + palier
	var nombre: int = [9, 13, 17][palier - 1]
	var base: float = [13.0, 17.0, 21.0][palier - 1]
	var rangees: int = 1 if palier == 1 else 2
	for r: int in rangees:
		var n := nombre - 3 * r
		var pas := TAU / float(n)
		var cy := 32.0 + 13.0 * r
		for i: int in n:
			var theta := pas * (float(i) + _rng.randf_range(-0.25, 0.25) + 0.5 * r)
			theta += pas * float(tour) / float(IMAGES_ANIMEES)
			var s := sin(theta)
			var co := cos(theta)
			var longueur := base * _rng.randf_range(0.65, 1.35) * (1.0 - 0.3 * absf(co))
			var demi := _rng.randf_range(2.6, 5.0)
			var inclinaison := _rng.randf_range(-0.25, 0.25)
			var pied := Vector2(64.0 + 42.0 * co, cy + 12.0 * s)
			var dir := Vector2(co * 0.9, s * 0.35 + 0.4 + 0.35 * absf(co))
			if s <= 0.0:
				longueur *= 0.6
				dir = Vector2(co, s * 0.6 - 0.1)
			dir = dir.normalized().rotated(inclinaison)
			var normale := Vector2(-dir.y, dir.x)
			var pointe := pied + dir * longueur
			var lumiere := 0.35 + 0.5 * maxf(s, 0.0) if s > 0.0 else 0.2
			var cible: Image = c["avant"] if s > 0.0 else c["arriere"]
			_triangle(cible, pied - normale * demi, pied + normale * demi, pointe, _fer(lumiere))
			_triangle(cible, pied, pied + normale * demi, pointe, _fer(lumiere * 0.6))
			_px(cible, int(pointe.x), int(pointe.y), FER_CLAIR if s > 0.0 else FER)
	_contour(c["arriere"])
	_contour(c["avant"])
	return c


## Bulle bleue autour de la tour : le film arrière est pâle et léger, le film avant porte le reflet
## et l'équateur. Plus large et plus opaque à chaque palier.
func _mana(palier: int) -> Dictionary:
	var tailles: Array[Vector2i] = [Vector2i(84, 104), Vector2i(104, 136), Vector2i(124, 176)]
	var alpha: float = [0.16, 0.22, 0.28][palier - 1]
	var t: Vector2i = tailles[palier - 1]
	var c := _couches(t.x, t.y)
	var centre := Vector2(t.x / 2.0, t.y / 2.0)
	var rx := t.x / 2.0 - 1.0
	var ry := t.y / 2.0 - 1.0
	var avant: Image = c["avant"]
	var arriere: Image = c["arriere"]
	for y: int in t.y:
		for x: int in t.x:
			var u := (x + 0.5 - centre.x) / rx
			var v := (y + 0.5 - centre.y) / ry
			var r2 := u * u + v * v
			if r2 > 1.0:
				continue
			var bord := 0.3 + 0.7 * r2 * r2
			var rim := 0.5 if r2 > 0.8 else 0.0
			arriere.set_pixel(
				x, y, Color(BLEU_CLAIR, (alpha * 0.55 + rim * 0.5) * (0.5 + 0.5 * r2))
			)
			avant.set_pixel(x, y, Color(BLEU, minf(alpha * bord + rim, 0.8)))
	# Reflet en arc clair en haut à gauche, équateur en ellipse (moitié avant) et point brillant.
	for k: int in 16:
		var ang := PI * (1.1 + 0.3 * float(k) / 15.0)
		_rect(
			avant,
			int(centre.x + cos(ang) * rx * 0.74),
			int(centre.y + sin(ang) * ry * 0.74),
			2,
			2,
			BLEU_CLAIR
		)
	if palier >= 2:
		for k: int in 40:
			var ang := PI * float(k) / 39.0
			_px(
				avant,
				int(centre.x + cos(ang) * rx * 0.97),
				int(centre.y + sin(ang) * rx * 0.22),
				Color(BLEU_CLAIR, 0.7)
			)
	_rect(avant, int(centre.x - rx * 0.45), int(centre.y - ry * 0.35), 3, 3, Color.WHITE)
	return c


## Plaques d'acier qui suivent la courbure du fût : des blocs de largeurs, de hauteurs et de
## travers variés aux joints irréguliers, plus étroits et plus sombres sur les bords.
func _armure(palier: int) -> Dictionary:
	var c := _couches(96, 72)
	_rng.seed = GRAINE + 10 + palier
	var rayon := 38.0
	for r: int in palier:
		var yc := 18.0 + 15.0 * r
		var ry := 9.0
		var phi := _rng.randf_range(-PI, -PI + 0.5)
		var fin := phi + TAU
		while phi < fin - 0.2:
			var delta := minf(_rng.randf_range(0.4, 0.95), fin - phi)
			var haut := _rng.randf_range(8.0, 13.0)
			var travers := _rng.randf_range(-2.0, 2.0)
			var jeu := _rng.randf_range(0.03, 0.09)
			var p1 := phi + jeu
			var p2 := phi + delta - jeu
			var mi := (p1 + p2) / 2.0
			var devant := cos(mi) > 0.0
			var lumiere := 0.25 + 0.6 * cos(mi) if devant else 0.15
			var cible: Image = c["avant"] if devant else c["arriere"]
			var g := Vector2(48.0 + rayon * sin(p1), yc + ry * cos(p1))
			var d := Vector2(48.0 + rayon * sin(p2), yc + ry * cos(p2))
			var moitie := haut / 2.0
			_quad(
				cible,
				g + Vector2(0, -moitie + travers),
				d + Vector2(0, -moitie - travers),
				d + Vector2(0, moitie - travers),
				g + Vector2(0, moitie + travers),
				_fer(lumiere)
			)
			if devant and absf(d.x - g.x) > 4.0:
				_rect(
					cible,
					int(g.x) + 1,
					int(g.y - moitie + travers) + 1,
					int(absf(d.x - g.x)) - 2,
					1,
					_fer(lumiere + 0.3)
				)
				if palier == 3:
					_px(cible, int((g.x + d.x) / 2.0), int((g.y + d.y) / 2.0), OR)
			phi += delta
	_contour(c["arriere"])
	_contour(c["avant"])
	return c


## Images rémanentes : des copies pâles de la tour décalées de part et d'autre (derrière elle),
## et des traînées de vitesse sur les côtés (devant). Image de 208 de large, tour à (40, 0).
func _esquive(palier: int, tour: Image) -> Dictionary:
	var c := _couches(208, 256)
	var arriere: Image = c["arriere"]
	var avant: Image = c["avant"]
	var decalages: Array[int] = []
	for k: int in palier:
		decalages.append(14 * (k + 1))
	for k: int in range(palier - 1, -1, -1):
		var alpha: float = [0.34, 0.24, 0.15][k]
		for signe: int in [-1, 1]:
			var dx: int = decalages[k] * signe
			for y: int in 256:
				for x: int in 128:
					var p := tour.get_pixel(x, y)
					if p.a < 0.5:
						continue
					var teinte := Color(p.r, p.g, p.b).lerp(SPECTRE, 0.55)
					var dest := Vector2i(40 + x + dx, y)
					if dest.x >= 0 and dest.x < 208 and arriere.get_pixel(dest.x, dest.y).a < alpha:
						arriere.set_pixel(dest.x, dest.y, Color(teinte, alpha))
	_rng.seed = GRAINE + 20 + palier
	for cote: int in [-1, 1]:
		for k: int in palier + 1:
			var y := _rng.randi_range(95, 205)
			var longueur := _rng.randi_range(8, 22)
			var x0 := 104 + cote * _rng.randi_range(52, 60)
			var x1 := x0 + cote * longueur
			_rect(avant, mini(x0, x1), y, longueur, 1, Color(SPECTRE, 0.7))
	return c


## Lueur verte : un halo pâle derrière la tour, une lueur douce devant, et des étincelles en croix
## de tailles variées (3, 6 puis 9), plus petites derrière.
func _regen(palier: int) -> Dictionary:
	var c := _couches(128, 110)
	_rng.seed = GRAINE + 30 + palier
	var alpha: float = [0.2, 0.3, 0.4][palier - 1]
	var arriere: Image = c["arriere"]
	var avant: Image = c["avant"]
	for y: int in 110:
		for x: int in 128:
			var u := (x + 0.5 - 64.0) / 63.0
			var v := (y + 0.5 - 55.0) / 54.0
			var r2 := u * u + v * v
			if r2 > 1.0:
				continue
			arriere.set_pixel(x, y, Color(VERT_CLAIR, alpha * (0.4 + 0.6 * r2)))
			avant.set_pixel(x, y, Color(VERT, alpha * 0.6 * (1.0 - r2 * 0.7)))
	var nombre: int = [3, 6, 9][palier - 1]
	for i: int in nombre:
		var ang := TAU * float(i) / float(nombre) + _rng.randf_range(0.0, 0.6)
		var rayon := _rng.randf_range(28.0, 58.0)
		var cx := int(64.0 + cos(ang) * rayon * 1.05)
		var cy := int(55.0 + sin(ang) * rayon * 0.8)
		var bras := _rng.randi_range(2, 4)
		var devant := sin(ang) > 0.0
		var cible: Image = avant if devant else arriere
		if not devant:
			bras = maxi(bras - 1, 1)
		_rect(cible, cx - 1, cy - bras, 3, 2 * bras + 1, VERT_CLAIR)
		_rect(cible, cx - bras, cy - 1, 2 * bras + 1, 3, VERT_CLAIR)
		_px(cible, cx, cy, Color.WHITE)
	return c


## Filets rouges aspirés en spirale autour de la tour : chacun passe derrière puis revient devant,
## d'épaisseur variée, plus fin en s'approchant. `tour` : quart de pas tourné.
func _vol_de_vie(palier: int, tour: int) -> Dictionary:
	var c := _couches(128, 140)
	_rng.seed = GRAINE + 40 + palier
	var nombre: int = [2, 4, 6][palier - 1]
	for i: int in nombre:
		var phi0 := TAU * float(i) / float(nombre) + _rng.randf_range(-0.2, 0.2)
		phi0 += TAU / float(nombre) * float(tour) / float(IMAGES_ANIMEES)
		var epaisseur := _rng.randf_range(2.0, 4.2)
		var tours := _rng.randf_range(1.2, 1.7)
		var depart := _rng.randf_range(10.0, 22.0)
		for k: int in 360:
			var t := float(k) / 359.0
			var phi := phi0 + TAU * tours * t
			var rayon := 60.0 - 20.0 * t
			var x := 64.0 + rayon * sin(phi)
			var y := depart + 95.0 * t + 0.28 * rayon * cos(phi)
			var devant := cos(phi) > 0.0
			var cible: Image = c["avant"] if devant else c["arriere"]
			var e := maxi(1, roundi(epaisseur * (1.0 - 0.45 * t)))
			_rect(cible, int(x), int(y), e, e, SANG if devant else SANG_FONCE)
			if k % 90 == 45:
				_rect(cible, int(x) - 2, int(y) - 2, 5, 5, SANG_FONCE)
				_px(cible, int(x), int(y), SANG)
	_contour(c["arriere"])
	_contour(c["avant"])
	return c
