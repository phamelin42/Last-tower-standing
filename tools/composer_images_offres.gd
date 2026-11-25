extends SceneTree
## Compose les 70 cases des offres de la boutique : l'icône peinte de Ravenmore, lissée et non
## pixelisée, posée sur une case carrée de 128 px au fond en dégradé radial de la couleur de
## l'offre, au cadre biseauté sombre et à l'ombre portée (allure de l'essai validé par Phil). La
## correspondance est dans `visuels/images_offres.gd`. Aucune source de hasard : la même exécution
## sort toujours les mêmes octets.
##   godot --headless --path . --script res://tools/composer_images_offres.gd
##     [-- --sortie <dossier>]

const TAILLE: int = 128
const TAILLE_ICONE: int = 100
const SORTIE_DEFAUT := "res://assets/icones/cases"

const ENCRE := Color("161c2e")
const RAYON_EXTERIEUR: float = 6.0
const BORD: float = 4.0
const BISEAU: float = 2.0
const OMBRE_DECALAGE := Vector2i(3, 4)
const OMBRE_OPACITE: float = 0.55


func _initialize() -> void:
	quit(_lancer(OS.get_cmdline_user_args()))


func _lancer(args: PackedStringArray) -> int:
	var sortie: String = ProjectSettings.globalize_path(SORTIE_DEFAUT)
	var i: int = 0
	while i < args.size():
		if args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
			i += 2
		else:
			printerr("Argument inconnu : %s" % args[i])
			return 1
	DirAccess.make_dir_recursive_absolute(sortie)
	var fonds: Dictionary = {}
	var icones: Dictionary = {}
	for id: String in ImagesOffres.ids():
		var e: Dictionary = ImagesOffres.entree(id)
		var couleur: String = e["couleur"]
		var icone: String = e["icone"]
		if not fonds.has(couleur):
			fonds[couleur] = _fond(ImagesOffres.COULEURS[couleur])
		if not icones.has(icone):
			var charge: Image = _icone(icone)
			if charge == null:
				printerr("Icône illisible : %s" % icone)
				return 1
			icones[icone] = charge
		var img: Image = (fonds[couleur] as Image).duplicate()
		_poser_icone(img, icones[icone])
		var erreur: int = img.save_png(sortie.path_join(id + ".png"))
		if erreur != OK:
			printerr("Écriture impossible : %s (%d)" % [id, erreur])
			return 1
	print("Cases écrites : %s" % sortie)
	return 0


func _icone(nom: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(ImagesOffres.chemin_icone(nom)))
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TAILLE_ICONE, TAILLE_ICONE, Image.INTERPOLATE_LANCZOS)
	return img


## Icône centrée, précédée de son ombre portée (sa silhouette en encre, décalée).
func _poser_icone(case_img: Image, icone: Image) -> void:
	var origine := Vector2i((TAILLE - TAILLE_ICONE) / 2, (TAILLE - TAILLE_ICONE) / 2 - 2)
	var ombre: Image = icone.duplicate()
	for y: int in ombre.get_height():
		for x: int in ombre.get_width():
			var a: float = ombre.get_pixel(x, y).a * OMBRE_OPACITE
			ombre.set_pixel(x, y, Color(ENCRE, a))
	var plein := Rect2i(0, 0, TAILLE_ICONE, TAILLE_ICONE)
	case_img.blend_rect(ombre, plein, origine + OMBRE_DECALAGE)
	case_img.blend_rect(icone, plein, origine)


## Distance signée au rectangle arrondi [marge, TAILLE - marge] : négative dedans.
func _distance(p: Vector2, marge: float, rayon: float) -> float:
	var demi: float = TAILLE / 2.0 - marge
	var q: Vector2 = (
		(p - Vector2(TAILLE / 2.0, TAILLE / 2.0)).abs() - Vector2(demi - rayon, demi - rayon)
	)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - rayon


func _fond(couleurs: Array) -> Image:
	var centre: Color = couleurs[0]
	var bord: Color = couleurs[1]
	var img := Image.create(TAILLE, TAILLE, false, Image.FORMAT_RGBA8)
	var interieur: float = TAILLE - 2.0 * BORD
	var foyer := Vector2(BORD + 0.4 * interieur, BORD + 0.35 * interieur)
	var rayon_degrade: float = 0.85 * interieur
	for y: int in TAILLE:
		for x: int in TAILLE:
			var p := Vector2(x + 0.5, y + 0.5)
			var couverture: float = clampf(0.5 - _distance(p, 0.0, RAYON_EXTERIEUR), 0.0, 1.0)
			if couverture <= 0.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var dans: float = clampf(0.5 - _distance(p, BORD, 2.0), 0.0, 1.0)
			var t: float = clampf(p.distance_to(foyer) / rayon_degrade, 0.0, 1.0)
			var c: Color = centre.lerp(bord, t)
			var v: float = clampf((p.y - BORD) / interieur, 0.0, 1.0)
			if v < 0.5:
				c = c.lerp(Color.WHITE, 0.18 * (1.0 - v * 2.0))
			else:
				c = c.lerp(Color.BLACK, 0.25 * (v - 0.5) * 2.0)
			var d: float = _distance(p, BORD, 2.0)
			if d > -BISEAU:
				var clair: bool = p.x < TAILLE / 2.0 and p.y < TAILLE / 2.0
				if p.x > TAILLE - BORD - BISEAU or p.y > TAILLE - BORD - BISEAU:
					clair = false
				elif p.x < BORD + BISEAU or p.y < BORD + BISEAU:
					clair = true
				c = c.lerp(Color.WHITE if clair else Color.BLACK, 0.45)
			c = ENCRE.lerp(c, dans)
			c.a = couverture
			img.set_pixel(x, y, c)
	return img
