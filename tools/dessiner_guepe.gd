extends SceneTree
## Dessine la feuille de la Guêpe de laiton (unité volante), image par image, à partir de formes
## et de la palette du pack Tiny Swords (couleurs mesurées dans les PNG des gobelins). Aucune image
## tierce : la même exécution sort toujours les mêmes octets.
##   godot --headless --path . --script res://tools/dessiner_guepe.gd [-- --sortie <chemin.png>]
## Feuille de 6 × 2 cases de 192 px : ligne 0 = vol (6 images), ligne 1 = coup (4 images).
## La mort réutilise `Dead.png` du pack.

const CASE := 192
const COLONNES := 6
const LIGNES := 2
const SORTIE_DEFAUT := "res://assets/maison/guepe_de_laiton.png"

const CONTOUR := Color("161c2e")
const OMBRE := Color("161c2e50")
# Tons ordonnés [sombre, moyen, clair].
const LAITON: Array[Color] = [Color("6f5a48"), Color("b3a645"), Color("dcdf71")]
const CUIVRE: Array[Color] = [Color("9e7466"), Color("d9945f"), Color("d5b583")]
const AILE_PROCHE: Array[Color] = [Color("efe1ab"), Color("ffffff"), Color("ffffff")]
const AILE_LOINTAINE: Array[Color] = [Color("d5b583"), Color("efe1ab"), Color("efe1ab")]
const BLANC := Color("ffffff")
const LUMIERE := Vector2(-0.508, -0.861)

const CENTRE_Y := 96
const SOL_Y := 152
const BALANCE: Array[int] = [0, -2, -3, -2, 0, 2]
const ANGLES_VOL: Array[float] = [8.0, 32.0, 58.0, 80.0, 56.0, 30.0]
# Coup : recul, détente, pleine extension, retour.
const COUP_DX: Array[int] = [-6, 6, 16, 4]
const COUP_LONGUEUR: Array[int] = [4, 22, 32, 10]
const ANGLES_COUP: Array[float] = [30.0, 14.0, 6.0, 24.0]


func _initialize() -> void:
	quit(_lancer(OS.get_cmdline_user_args()))


func _lancer(args: PackedStringArray) -> int:
	var sortie := ProjectSettings.globalize_path(SORTIE_DEFAUT)
	var i := 0
	while i < args.size():
		if args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
			i += 2
		else:
			printerr("Argument inconnu : %s" % args[i])
			return 1
	var feuille := Image.create(COLONNES * CASE, LIGNES * CASE, false, Image.FORMAT_RGBA8)
	feuille.fill(Color(0.0, 0.0, 0.0, 0.0))
	for n: int in 6:
		_poser(feuille, _image_de_vol(n), n, 0)
	for n: int in 4:
		_poser(feuille, _image_de_coup(n), n, 1)
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	var erreur := feuille.save_png(sortie)
	if erreur != OK:
		printerr("Écriture impossible : %s (%d)" % [sortie, erreur])
		return 1
	print("Feuille écrite : %s" % sortie)
	return 0


func _image_de_vol(n: int) -> Image:
	return _dessiner_guepe(0, BALANCE[n], ANGLES_VOL[n], 8)


func _image_de_coup(n: int) -> Image:
	return _dessiner_guepe(COUP_DX[n], 0, ANGLES_COUP[n], COUP_LONGUEUR[n])


## Une case : ombre au sol, puis la guêpe (chaque partie a son propre contour d'un pixel).
func _dessiner_guepe(dx: int, dy: int, angle_ailes: float, longueur_dard: int) -> Image:
	var case_img := _couche()
	_dessiner_ombre(case_img, 96 + dx / 2)
	var fig := _couche()
	var y := CENTRE_Y + dy
	var attache := Vector2(100 + dx, y - 10)
	_aile(fig, attache, angle_ailes + 14.0, AILE_LOINTAINE)
	for k: int in 3:
		var patte := _couche()
		_remplir_rect(patte, Rect2i(92 + dx + k * 7, y + 6, 2, 13), LAITON[0])
		_contourer(patte)
		_superposer(fig, patte)
	_ellipse(fig, Vector2(61 + dx, y + 5), Vector2(8, 3), 20.0, LAITON, [])
	_ellipse(fig, Vector2(80 + dx, y + 3), Vector2(17, 12), 0.0, LAITON, [-8, 0, 8])
	_ellipse(fig, Vector2(98 + dx, y - 1), Vector2(11, 11), 0.0, LAITON, [])
	var demi := float(longueur_dard) / 2.0
	_ellipse(fig, Vector2(124 + dx + demi - 2.0, y + 1), Vector2(demi + 2.0, 2), 0.0, LAITON, [])
	_ellipse(fig, Vector2(115 + dx, y), Vector2(9, 9), 0.0, CUIVRE, [])
	_aile(fig, attache, angle_ailes, AILE_PROCHE)
	# Œil : un blanc de 3 × 3 avec une pupille de 2 × 2, comme les gobelins du pack.
	_remplir_rect(fig, Rect2i(118 + dx, y - 4, 3, 3), BLANC)
	_remplir_rect(fig, Rect2i(119 + dx, y - 3, 2, 2), CONTOUR)
	_superposer(case_img, fig)
	return case_img


func _couche() -> Image:
	var img := Image.create(CASE, CASE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return img


func _dessiner_ombre(img: Image, cx: int) -> void:
	for y: int in range(SOL_Y - 8, SOL_Y + 9):
		for x: int in range(cx - 32, cx + 33):
			var u := (float(x - cx) + 0.5) / 30.0
			var v := (float(y - SOL_Y) + 0.5) / 7.0
			if u * u + v * v <= 1.0:
				img.set_pixel(x, y, OMBRE)


func _aile(fig: Image, attache: Vector2, t_deg: float, tons: Array[Color]) -> void:
	var t := deg_to_rad(t_deg)
	var dir := Vector2(-sin(t), -cos(t))
	var longueur := 36.0
	_ellipse(
		fig,
		attache + dir * (longueur / 2.0),
		Vector2(longueur / 2.0, 9),
		rad_to_deg(dir.angle()),
		tons,
		[]
	)


## Ellipse ombrée en trois tons (lumière en haut à gauche), contourée, posée sur `fig`.
func _ellipse(
	fig: Image,
	centre: Vector2,
	rayons: Vector2,
	angle_deg: float,
	tons: Array[Color],
	bandes: Array[int]
) -> void:
	var couche := _couche()
	var a := deg_to_rad(angle_deg)
	var ca := cos(a)
	var sa := sin(a)
	var grand := maxf(rayons.x, rayons.y)
	var marge := int(grand) + 2
	for y: int in range(int(centre.y) - marge, int(centre.y) + marge + 1):
		for x: int in range(int(centre.x) - marge, int(centre.x) + marge + 1):
			if x < 0 or y < 0 or x >= CASE or y >= CASE:
				continue
			var d := Vector2(float(x) + 0.5, float(y) + 0.5) - centre
			var lx := d.x * ca + d.y * sa
			var ly := -d.x * sa + d.y * ca
			var u := Vector2(lx / rayons.x, ly / rayons.y)
			if u.length_squared() > 1.0:
				continue
			var s := (d / grand).dot(LUMIERE)
			var ton := tons[1]
			if s > 0.3:
				ton = tons[2]
			elif s < -0.3:
				ton = tons[0]
			for b: int in bandes:
				if absf(d.x - float(b)) <= 1.5:
					ton = tons[0]
			couche.set_pixel(x, y, ton)
	_contourer(couche)
	_superposer(fig, couche)


func _remplir_rect(img: Image, zone: Rect2i, couleur: Color) -> void:
	for y: int in range(zone.position.y, zone.end.y):
		for x: int in range(zone.position.x, zone.end.x):
			img.set_pixel(x, y, couleur)


## Pose un pixel de contour sur chaque case vide voisine (4 voisins) d'un pixel opaque.
func _contourer(img: Image) -> void:
	var a_poser: Array[Vector2i] = []
	for y: int in CASE:
		for x: int in CASE:
			if img.get_pixel(x, y).a > 0.5:
				continue
			for v: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + v.x
				var ny := y + v.y
				if nx >= 0 and ny >= 0 and nx < CASE and ny < CASE:
					if img.get_pixel(nx, ny).a > 0.5:
						a_poser.append(Vector2i(x, y))
						break
	for p: Vector2i in a_poser:
		img.set_pixel(p.x, p.y, CONTOUR)


## Pose les pixels opaques de `couche` sur `fond`.
func _superposer(fond: Image, couche: Image) -> void:
	for y: int in CASE:
		for x: int in CASE:
			var c := couche.get_pixel(x, y)
			if c.a > 0.5:
				fond.set_pixel(x, y, c)


func _poser(feuille: Image, case_img: Image, colonne: int, ligne: int) -> void:
	feuille.blit_rect(case_img, Rect2i(0, 0, CASE, CASE), Vector2i(colonne * CASE, ligne * CASE))
