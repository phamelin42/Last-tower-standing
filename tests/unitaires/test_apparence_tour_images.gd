extends CasDeTest
## Les 18 superpositions de la tour (D19, T9.24) : chacune existe, se voit, tient dans le cadre de
## la tour, ne ressemble à aucune autre, reste lisible au zoom le plus lointain, a sa licence
## citée ; la planche avant/après existe et montre chaque statistique.

const DOSSIER := "res://assets/tour_apparence/"
const CADRE := Vector2i(128, 256)
## Au zoom le plus lointain de la caméra, au moins ce nombre de pixels doit trancher sur la pierre.
const PIXELS_MIN := 6
const CONTRASTE_MIN := 0.1
const COUCHES: Array[String] = ["arriere", "avant"]
## Cadre de pose : l'esquive déborde de la tour de chaque côté (images rémanentes).
const CADRE_ESQUIVE := Vector2i(208, 256)
const TOUR_DECALEE := Vector2i(64, 0)

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _nom(stat: String, palier: int, couche: String, suffixe: String = "") -> String:
	return "%s_%d_%s%s" % [stat, palier, couche, suffixe]


func _image(nom: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path("%s%s.png" % [DOSSIER, nom]))
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _paliers() -> int:
	var stats: Dictionary = d.apparence_tour["stats"]
	var seuils: Array = stats["epines"]
	return seuils.size()


## Tous les noms d'image du dossier, sans l'extension.
func _noms_du_dossier() -> Array[String]:
	var noms: Array[String] = []
	var acces := DirAccess.open(DOSSIER)
	verifier_non_nul(acces)
	if acces != null:
		for f: String in acces.get_files():
			if f.get_extension() == "png":
				noms.append(f.get_basename())
	return noms


func _opaques(img: Image, seuil: float) -> int:
	var n := 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a >= seuil:
				n += 1
	return n


func test_chaque_statistique_a_ses_trois_superpositions_sur_deux_couches() -> void:
	verifier_egal(ApparenceTour.SUPERPOSITIONS.size(), 6)
	var skin: Dictionary = d.skins_tour["defaut"]
	var ancrages: Dictionary = skin["ancrages"]
	var seuils_connus: Dictionary = d.apparence_tour["stats"]
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		verifier(seuils_connus.has(stat), "%s a des seuils" % stat)
		for p: int in range(1, _paliers() + 1):
			var tailles: Array[Vector2i] = []
			for couche: String in COUCHES:
				var nom := _nom(stat, p, couche)
				var img := _image(nom)
				verifier_non_nul(img, "image %s" % nom)
				if img == null:
					continue
				tailles.append(img.get_size())
				verifier(_opaques(img, 0.25) > 20, "%s : pixels visibles" % nom)
				var cadre := CADRE_ESQUIVE if stat == "esquive" else CADRE
				verifier(
					img.get_width() <= cadre.x and img.get_height() <= cadre.y,
					"%s tient dans son cadre de pose" % nom
				)
				var a: Dictionary = ancrages[stat]
				var centre := Vector2(float(a["x"]), float(a["y"]))
				var moitie := Vector2(img.get_size()) / 2.0
				if stat != "esquive":
					verifier(
						centre.x - moitie.x >= 0.0 and centre.y - moitie.y >= 0.0,
						"%s : haut gauche dans la tour" % nom
					)
					verifier(
						centre.x + moitie.x <= CADRE.x and centre.y + moitie.y <= CADRE.y,
						"%s : bas droit dans la tour" % nom
					)
			if tailles.size() == 2:
				verifier_egal(
					tailles[0], tailles[1], "%s palier %d : deux couches de même taille" % [stat, p]
				)


func test_les_images_du_tour_lent_existent_et_different() -> void:
	for stat: String in ["epines", "vol_de_vie"]:
		for couche: String in COUCHES:
			var vues: Array[String] = []
			for k: int in range(0, 4):
				var suffixe := "" if k == 0 else "_a%d" % k
				var img := _image(_nom(stat, 3, couche, suffixe))
				verifier_non_nul(img, "%s %s image %d" % [stat, couche, k + 1])
				if img != null:
					vues.append(str(hash(img.get_data())))
			for i: int in vues.size():
				for j: int in range(i + 1, vues.size()):
					verifier(
						vues[i] != vues[j], "%s %s : image %d ≠ %d" % [stat, couche, i + 1, j + 1]
					)


func test_deux_superpositions_ne_se_confondent_jamais() -> void:
	var empreintes: Array[String] = []
	var noms := _noms_du_dossier()
	for nom: String in noms:
		var img := _image(nom)
		empreintes.append("%s|%d" % [img.get_size(), hash(img.get_data())])
	verifier(noms.size() >= 36, "au moins 36 images (%d)" % noms.size())
	for i: int in empreintes.size():
		for j: int in range(i + 1, empreintes.size()):
			verifier(empreintes[i] != empreintes[j], "%s ≠ %s" % [noms[i], noms[j]])


## La tour seule, ou la tour entre la couche arrière et la couche avant, sur un fond de 256 × 256.
func _composer(stat: String, palier: int) -> Image:
	var skin: Dictionary = d.skins_tour["defaut"]
	var tour := Image.load_from_file(ProjectSettings.globalize_path(String(skin["sprite"])))
	tour.convert(Image.FORMAT_RGBA8)
	var toile := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	toile.fill(Color(0, 0, 0, 0))
	var a: Dictionary = (skin["ancrages"] as Dictionary)[stat] if palier > 0 else {}
	for etape: int in 3:
		var img: Image = tour
		var origine := TOUR_DECALEE
		if etape != 1:
			if palier == 0:
				continue
			img = _image(_nom(stat, palier, COUCHES[0] if etape == 0 else COUCHES[1]))
			origine = (
				TOUR_DECALEE
				+ Vector2i(
					roundi(float(a["x"])) - img.get_width() / 2,
					roundi(float(a["y"])) - img.get_height() / 2
				)
			)
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c := img.get_pixel(x, y)
				var p := origine + Vector2i(x, y)
				if c.a > 0.0 and p.x >= 0 and p.y >= 0 and p.x < 256 and p.y < 256:
					toile.set_pixelv(p, toile.get_pixelv(p).blend(c))
	return toile


func test_chaque_superposition_reste_lisible_au_zoom_le_plus_lointain() -> void:
	var zoom := CameraArene.ZOOM_MIN
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		var nue := _composer(stat, 0)
		nue.resize(roundi(256.0 * zoom), roundi(256.0 * zoom), Image.INTERPOLATE_LANCZOS)
		for p: int in range(1, _paliers() + 1):
			var avec := _composer(stat, p)
			avec.resize(roundi(256.0 * zoom), roundi(256.0 * zoom), Image.INTERPOLATE_LANCZOS)
			var visibles := 0
			for y: int in avec.get_height():
				for x: int in avec.get_width():
					var a := avec.get_pixel(x, y)
					var b := nue.get_pixel(x, y)
					var ecart := Vector4(a.r - b.r, a.g - b.g, a.b - b.b, a.a - b.a)
					if ecart.length() >= CONTRASTE_MIN:
						visibles += 1
			verifier(
				visibles >= PIXELS_MIN,
				"%s palier %d au zoom %s : %d pixels changent" % [stat, p, zoom, visibles]
			)


func test_chaque_image_est_listee_dans_sources_md_avec_une_licence_libre() -> void:
	var texte := FileAccess.get_file_as_string(DOSSIER + "SOURCES.md")
	verifier(not texte.is_empty(), "SOURCES.md existe")
	var lignes := texte.split("\n")
	for nom: String in _noms_du_dossier():
		var cle := "`%s.png`" % nom
		var ligne := ""
		for l: String in lignes:
			if l.contains(cle):
				ligne = l
		verifier(not ligne.is_empty(), "%s listée" % cle)
		verifier(ligne.contains("CC0 1.0"), "%s : licence CC0" % cle)
		verifier(not ligne.to_lower().contains("aseprite"), "%s : aucun outil exclu" % cle)


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
