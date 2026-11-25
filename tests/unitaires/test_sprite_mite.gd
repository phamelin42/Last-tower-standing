extends CasDeTest
## La feuille de la Mite de laiton (dessinée par `tools/dessiner_mite.gd`) : 6 images de vol et
## 4 images de coup, en pixel art net, et regénérable à l'identique.

const CHEMIN := "res://assets/maison/mite_de_laiton.png"
const CASE := 192
const COLONNES := 6
const LIGNES := 2
const IMAGES_PAR_LIGNE: Array[int] = [6, 4]
const ALPHA_OMBRE: int = 80


func _charger() -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(CHEMIN))


func _opaques_dans_case(img: Image, colonne: int, ligne: int) -> int:
	var n := 0
	for y: int in CASE:
		for x: int in CASE:
			if img.get_pixel(colonne * CASE + x, ligne * CASE + y).a8 == 255:
				n += 1
	return n


func test_la_feuille_existe_et_fait_1152_sur_384() -> void:
	var img := _charger()
	verifier_non_nul(img, "la feuille est lisible")
	if img == null:
		return
	verifier_egal(img.get_width(), COLONNES * CASE)
	verifier_egal(img.get_height(), LIGNES * CASE)


func test_chaque_case_attendue_a_une_mite_et_les_autres_sont_vides() -> void:
	var img := _charger()
	if img == null:
		verifier(false, "feuille absente")
		return
	for ligne: int in LIGNES:
		for colonne: int in COLONNES:
			var opaques := _opaques_dans_case(img, colonne, ligne)
			if colonne < IMAGES_PAR_LIGNE[ligne]:
				verifier(opaques > 1200, "case %d/%d dessinée (%d px)" % [ligne, colonne, opaques])
			else:
				var vide := true
				for y: int in CASE:
					for x: int in CASE:
						if img.get_pixel(colonne * CASE + x, ligne * CASE + y).a8 != 0:
							vide = false
				verifier(vide, "case %d/%d vide" % [ligne, colonne])


func test_aucun_pixel_n_est_anticrenele() -> void:
	var img := _charger()
	if img == null:
		verifier(false, "feuille absente")
		return
	for y: int in img.get_height():
		for x: int in img.get_width():
			var a := img.get_pixel(x, y).a8
			if a != 0 and a != 255 and a != ALPHA_OMBRE:
				verifier(false, "alpha %d en (%d, %d)" % [a, x, y])
				return
	verifier(true)


func test_la_mite_est_assez_large_pour_se_voir_a_cote_des_gobelins() -> void:
	var img := _charger()
	if img == null:
		verifier(false, "feuille absente")
		return
	for ligne: int in LIGNES:
		for colonne: int in IMAGES_PAR_LIGNE[ligne]:
			var mini := CASE
			var maxi := -1
			for y: int in CASE:
				for x: int in CASE:
					if img.get_pixel(colonne * CASE + x, ligne * CASE + y).a8 == 255:
						mini = mini if x > mini else x
						maxi = maxi if x < maxi else x
			var largeur := maxi - mini + 1
			verifier(
				largeur >= 56 and largeur <= 110,
				"largeur %d en case %d/%d" % [largeur, ligne, colonne]
			)


func test_l_ombre_est_detachee_du_corps() -> void:
	var img := _charger()
	if img == null:
		verifier(false, "feuille absente")
		return
	for ligne: int in LIGNES:
		for colonne: int in IMAGES_PAR_LIGNE[ligne]:
			var corps_bas := -1
			var ombre_haut := CASE
			for y: int in CASE:
				for x: int in CASE:
					var a := img.get_pixel(colonne * CASE + x, ligne * CASE + y).a8
					if a == 255:
						corps_bas = y
					elif a == ALPHA_OMBRE and y < ombre_haut:
						ombre_haut = y
			verifier(ombre_haut < CASE, "ombre présente en %d/%d" % [ligne, colonne])
			verifier(
				ombre_haut > corps_bas + 4,
				"ombre sous le corps en %d/%d (%d > %d)" % [ligne, colonne, ombre_haut, corps_bas]
			)


func test_le_script_regenere_la_feuille_versionnee_au_octet_pres() -> void:
	var sortie := dossier_temporaire().path_join("mite.png")
	var args := PackedStringArray(
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			"res://tools/dessiner_mite.gd",
			"--",
			"--sortie",
			sortie,
		]
	)
	var journal: Array = []
	var code := OS.execute(OS.get_executable_path(), args, journal, true)
	verifier_egal(code, 0, "le script réussit : %s" % str(journal))
	verifier(FileAccess.file_exists(sortie), "le script écrit la feuille")
	var neuf := FileAccess.get_file_as_bytes(sortie)
	var versionne := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(CHEMIN))
	verifier(neuf.size() > 0, "feuille regénérée non vide")
	verifier(neuf == versionne, "mêmes octets que la feuille versionnée")
