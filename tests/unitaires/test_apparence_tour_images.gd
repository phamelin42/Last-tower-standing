extends CasDeTest
## Les 18 superpositions de la tour (D19, T9.24) : chacune existe, se voit, tient dans le cadre de
## la tour, ne ressemble à aucune autre, reste lisible au zoom le plus lointain, a sa licence
## citée ; la planche avant/après existe et montre chaque statistique.

const DOSSIER := "res://assets/tour_apparence/"
const CADRE := Vector2i(128, 256)
## Au zoom le plus lointain de la caméra, au moins ce nombre de pixels doit trancher sur la pierre.
const PIXELS_MIN := 6
const CONTRASTE_MIN := 0.12
const PIERRE := Color("3f9fa8")

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _nom(stat: String, palier: int) -> String:
	return "%s_%d" % [stat, palier]


func _image(stat: String, palier: int) -> Image:
	var img := Image.load_from_file(
		ProjectSettings.globalize_path("%s%s.png" % [DOSSIER, _nom(stat, palier)])
	)
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _paliers() -> int:
	var stats: Dictionary = d.apparence_tour["stats"]
	var seuils: Array = stats["epines"]
	return seuils.size()


func test_chaque_statistique_a_ses_trois_superpositions() -> void:
	verifier_egal(ApparenceTour.SUPERPOSITIONS.size(), 6)
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		var seuils_connus: Dictionary = d.apparence_tour["stats"]
		verifier(seuils_connus.has(stat), "%s a des seuils" % stat)
		for p: int in range(1, _paliers() + 1):
			var img := _image(stat, p)
			verifier_non_nul(img, "image %s" % _nom(stat, p))
			if img == null:
				continue
			var opaques := 0
			for y: int in img.get_height():
				for x: int in img.get_width():
					if img.get_pixel(x, y).a >= 0.25:
						opaques += 1
			verifier(opaques > 40, "%s : pixels visibles (%d)" % [_nom(stat, p), opaques])
			verifier(
				img.get_width() <= CADRE.x and img.get_height() <= CADRE.y,
				"%s tient dans le cadre de la tour" % _nom(stat, p)
			)
			var skin: Dictionary = d.skins_tour["defaut"]
			var ancrages: Dictionary = skin["ancrages"]
			var a: Dictionary = ancrages[stat]
			var centre := Vector2(float(a["x"]), float(a["y"]))
			var moitie := Vector2(img.get_size()) / 2.0
			verifier(
				centre.x - moitie.x >= 0.0 and centre.y - moitie.y >= 0.0, "%s : haut gauche" % stat
			)
			verifier(
				centre.x + moitie.x <= CADRE.x and centre.y + moitie.y <= CADRE.y,
				"%s : bas droit dans le cadre" % _nom(stat, p)
			)


func test_deux_superpositions_ne_se_confondent_jamais() -> void:
	var empreintes: Array[String] = []
	var noms: Array[String] = []
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		for p: int in range(1, _paliers() + 1):
			var img := _image(stat, p)
			if img == null:
				continue
			empreintes.append("%s|%d" % [img.get_size(), hash(img.get_data())])
			noms.append(_nom(stat, p))
	for i: int in empreintes.size():
		for j: int in range(i + 1, empreintes.size()):
			verifier(empreintes[i] != empreintes[j], "%s ≠ %s" % [noms[i], noms[j]])


func test_chaque_superposition_reste_lisible_au_zoom_le_plus_lointain() -> void:
	var zoom := CameraArene.ZOOM_MIN
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		for p: int in range(1, _paliers() + 1):
			var img := _image(stat, p)
			if img == null:
				continue
			img.resize(
				maxi(1, roundi(img.get_width() * zoom)),
				maxi(1, roundi(img.get_height() * zoom)),
				Image.INTERPOLATE_LANCZOS
			)
			var visibles := 0
			for y: int in img.get_height():
				for x: int in img.get_width():
					var c := img.get_pixel(x, y)
					var sur_pierre := PIERRE.lerp(Color(c, 1.0), c.a)
					var ecart := Vector3(
						sur_pierre.r - PIERRE.r, sur_pierre.g - PIERRE.g, sur_pierre.b - PIERRE.b
					)
					if ecart.length() >= CONTRASTE_MIN:
						visibles += 1
			verifier(
				visibles >= PIXELS_MIN,
				"%s au zoom %s : %d pixels" % [_nom(stat, p), zoom, visibles]
			)


func test_chaque_image_est_listee_dans_sources_md_avec_une_licence_libre() -> void:
	var texte := FileAccess.get_file_as_string(DOSSIER + "SOURCES.md")
	verifier(not texte.is_empty(), "SOURCES.md existe")
	var lignes := texte.split("\n")
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		for p: int in range(1, _paliers() + 1):
			var cle := "`%s.png`" % _nom(stat, p)
			var ligne := ""
			for l: String in lignes:
				if l.contains(cle):
					ligne = l
			verifier(not ligne.is_empty(), "%s listée" % cle)
			verifier(ligne.contains("CC0 1.0"), "%s : licence CC0" % cle)
			verifier(not ligne.to_lower().contains("aseprite"), "%s : aucun outil exclu" % cle)
	# Aucune image du dossier n'échappe à la liste.
	var acces := DirAccess.open(DOSSIER)
	verifier_non_nul(acces)
	if acces != null:
		for f: String in acces.get_files():
			if f.get_extension() == "png":
				verifier(texte.contains("`%s`" % f), "%s est citée" % f)


func test_la_planche_existe_et_montre_chaque_statistique() -> void:
	var img := Image.load_from_file(
		ProjectSettings.globalize_path("res://docs/planche_apparence_tour.png")
	)
	verifier_non_nul(img, "docs/planche_apparence_tour.png")
	if img == null:
		return
	var planche: GDScript = load("res://tools/planche_apparence_tour.gd")
	var colonnes: Array = planche.get_script_constant_map()["COLONNES"]
	var cellule: Vector2i = planche.get_script_constant_map()["CELLULE"]
	verifier_egal(colonnes.size(), ApparenceTour.STATS.size(), "une colonne par statistique")
	for c: int in colonnes.size():
		var nue := _cellule(img, planche, c, 0, cellule)
		for r: int in range(1, 4):
			var apres := _cellule(img, planche, c, r, cellule)
			verifier(
				nue.get_data() != apres.get_data(),
				"%s palier %d diffère de la tour nue" % [colonnes[c], r]
			)
			if r > 1:
				var avant := _cellule(img, planche, c, r - 1, cellule)
				verifier(
					avant.get_data() != apres.get_data(),
					"%s : palier %d ≠ %d" % [colonnes[c], r - 1, r]
				)


func _cellule(img: Image, planche: GDScript, c: int, r: int, taille: Vector2i) -> Image:
	var origine: Vector2i = planche.call("origine_cellule", c, r)
	return img.get_region(Rect2i(origine, taille))
