extends CasDeTest
## Les cases du pack sont surtout transparentes : chaque image est recadrée sur son contenu pour
## que le rastériseur ne remplisse pas du vide. Le recadrage ne doit rien couper, ne doit pas
## déplacer le pied du sprite, et doit vraiment réduire la surface. Table générée par
## `tools/generer_recadrages.gd` ; un sprite repeint ou une table périmée fait échouer ce test.

## Part maximale de la surface des cases que les boîtes ont le droit de garder.
const SURFACE_MAX: float = 0.6

var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func _feuilles() -> Array[Dictionary]:
	var feuilles: Array[Dictionary] = []
	for id: String in Apparence.ids_entites(_donnees):
		feuilles.append(Apparence.entree(id))
	feuilles.append(Apparence.MORT)
	return feuilles


func _image(chemin: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(chemin))


func _nb_images(f: Dictionary) -> int:
	return int(f["colonnes"]) * int(f["lignes"])


func test_chaque_feuille_a_ses_boites_de_recadrage() -> void:
	for f: Dictionary in _feuilles():
		var cle: String = f["cle_boites"]
		verifier(Recadrages.BOITES.has(cle), "%s : table de boîtes" % cle)
		if Recadrages.BOITES.has(cle):
			verifier_egal(
				(Recadrages.BOITES[cle] as Array).size(),
				_nb_images(f),
				"%s : une boîte par image" % cle
			)
	verifier_faux(Recadrages.BOITES.has("guepe"), "plus de boîtes pour la guêpe")


func test_les_boites_d_un_modele_couvrent_ses_quatre_couleurs() -> void:
	for cle: String in Apparence.MODELES:
		var modele: Dictionary = Apparence.MODELES[cle]
		if not String(modele["chemin"]).contains("%s"):
			continue
		for couleur: String in ["Yellow", "Red", "Purple", "Blue"]:
			var chemin: String = Apparence.chemin_feuille(cle, couleur)
			var img := _image(chemin)
			verifier_non_nul(img, "%s : feuille lisible" % chemin)
			if img == null:
				continue
			var case_px: Vector2i = modele["case"]
			var colonnes: int = modele["colonnes"]
			for image: int in colonnes * int(modele["lignes"]):
				var cellule := Rect2i(
					(image % colonnes) * case_px.x,
					(image / colonnes) * case_px.y,
					case_px.x,
					case_px.y
				)
				var utile: Rect2i = img.get_region(cellule).get_used_rect()
				if utile.size != Vector2i.ZERO:
					verifier(
						Recadrages.boite(cle, image).encloses(utile),
						"%s image %d" % [chemin, image]
					)


func test_chaque_boite_contient_tous_les_pixels_visibles_de_son_image() -> void:
	for f: Dictionary in _feuilles():
		var img := _image(String(f["feuille"]))
		verifier_non_nul(img, "feuille lisible : %s" % f["feuille"])
		if img == null:
			continue
		var case_px: Vector2i = f["case"]
		var colonnes: int = f["colonnes"]
		for image: int in _nb_images(f):
			var cellule := Rect2i(
				(image % colonnes) * case_px.x, (image / colonnes) * case_px.y, case_px.x, case_px.y
			)
			var utile: Rect2i = img.get_region(cellule).get_used_rect()
			var boite: Rect2i = Recadrages.boite(String(f["cle_boites"]), image)
			if utile.size == Vector2i.ZERO:
				continue
			verifier(
				boite.encloses(utile),
				"%s image %d : boîte %s ne contient pas %s" % [f["feuille"], image, boite, utile]
			)


func test_les_boites_ne_gardent_qu_une_partie_de_la_surface_des_cases() -> void:
	for f: Dictionary in _feuilles():
		var case_px: Vector2i = f["case"]
		var gardee: float = 0.0
		var total: float = 0.0
		for image: int in _nb_images(f):
			var boite: Rect2i = Recadrages.boite(String(f["cle_boites"]), image)
			gardee += float(boite.size.x * boite.size.y)
			total += float(case_px.x * case_px.y)
		verifier(
			gardee / total <= SURFACE_MAX,
			"%s : %.2f de la surface" % [f["feuille"], gardee / total]
		)


func test_le_pied_ne_bouge_pas_avec_ou_sans_recadrage() -> void:
	for f: Dictionary in _feuilles():
		var case_px: Vector2i = f["case"]
		var colonnes: int = f["colonnes"]
		for image: int in _nb_images(f):
			var pied := Vector2(
				float((image % colonnes) * case_px.x) + float(case_px.x) * 0.5,
				float((image / colonnes) * case_px.y) + float(f["pieds"])
			)
			for recadre: bool in [false, true]:
				var p: Dictionary = Apparence.placement(
					String(f["cle_boites"]), image, case_px, colonnes, float(f["pieds"]), recadre
				)
				var region: Rect2 = p["region"]
				var offset: Vector2 = p["offset"]
				# Où atterrit le pied par rapport à la position du sprite, de face puis en miroir.
				var de_face: Vector2 = offset + (pied - region.get_center())
				var en_miroir := Vector2(-offset.x - (pied.x - region.get_center().x), de_face.y)
				verifier_proche(de_face.x, 0.0, 0.001, "%s %d face x" % [f["feuille"], image])
				verifier_proche(de_face.y, 0.0, 0.001, "%s %d face y" % [f["feuille"], image])
				verifier_proche(en_miroir.x, 0.0, 0.001, "%s %d miroir x" % [f["feuille"], image])
