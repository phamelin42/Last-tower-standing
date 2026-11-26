extends SceneTree
## Génère `visuels/recadrages.gd` : pour chaque image de chaque feuille du pack, le plus petit
## rectangle qui contient tous ses pixels visibles (union sur les quatre couleurs du pack, dont la
## silhouette est la même). Le rendu ne remplit ainsi que le contenu, pas les cases transparentes.
##   godot --headless --path . --script res://tools/generer_recadrages.gd
##   gdformat visuels/recadrages.gd
## À relancer si une feuille change ; `tests/unitaires/test_recadrages.gd` détecte une table
## périmée.

const SORTIE := "res://visuels/recadrages.gd"
const COULEURS: Array[String] = ["Blue", "Red", "Yellow", "Purple"]

var _erreur: bool = false


func _init() -> void:
	var lignes: Array[String] = [
		"class_name Recadrages",
		"extends RefCounted",
		"## Boîte de contenu de chaque image des feuilles de `Apparence`, par modèle : « x,y,l,h »",
		"## dans la case, une chaîne par image, dans l'ordre ligne puis colonne.",
		"## GÉNÉRÉ par `tools/generer_recadrages.gd` : ne pas modifier à la main.",
		"",
		"const BOITES: Dictionary = {",
	]
	var cles: Array[String] = []
	for cle: String in Apparence.MODELES:
		cles.append(cle)
	for cle: String in cles:
		var modele: Dictionary = Apparence.MODELES[cle]
		var chemin: String = modele["chemin"]
		var fichiers: Array[String] = []
		if chemin.contains("%s"):
			for couleur: String in COULEURS:
				fichiers.append(Apparence.chemin_feuille(cle, couleur))
		else:
			fichiers.append(chemin if chemin.begins_with("res://") else Apparence.RACINE + chemin)
		lignes.append(_entree(cle, fichiers, modele))
	var mort: Dictionary = Apparence.MORT
	lignes.append(_entree("mort", [String(mort["feuille"])], mort))
	lignes.append("}")
	lignes.append("")
	lignes.append("static var _cache: Dictionary = {}")
	lignes.append("")
	lignes.append("")
	lignes.append("## Boîte de l'image `image` du modèle `cle` (vide si inconnue).")
	lignes.append("static func boite(cle: String, image: int) -> Rect2i:")
	lignes.append("\tif not BOITES.has(cle):")
	lignes.append("\t\treturn Rect2i()")
	lignes.append("\tvar boites: Array = BOITES[cle]")
	lignes.append("\tif image < 0 or image >= boites.size():")
	lignes.append("\t\treturn Rect2i()")
	lignes.append("\tvar texte: String = boites[image]")
	lignes.append("\tif not _cache.has(texte):")
	lignes.append('\t\tvar v: PackedFloat64Array = texte.split_floats(",")')
	lignes.append("\t\t_cache[texte] = Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3]))")
	lignes.append("\treturn _cache[texte]")
	if _erreur:
		quit(1)
		return
	var f := FileAccess.open(SORTIE, FileAccess.WRITE)
	f.store_string("\n".join(lignes) + "\n")
	f.close()
	print("écrit : ", SORTIE)
	quit()


func _entree(cle: String, fichiers: Array[String], modele: Dictionary) -> String:
	var case_px: Vector2i = modele["case"]
	var colonnes: int = modele["colonnes"]
	var nb: int = colonnes * int(modele["lignes"])
	var images: Array[Image] = []
	for fichier: String in fichiers:
		# Une feuille manquante est une erreur : sans elle, la boîte ne couvrirait pas sa couleur.
		if not FileAccess.file_exists(fichier):
			push_error("feuille introuvable : %s" % fichier)
			_erreur = true
			return ""
		images.append(Image.load_from_file(ProjectSettings.globalize_path(fichier)))
	var valeurs: PackedStringArray = PackedStringArray()
	for image: int in nb:
		var cellule := Rect2i(
			(image % colonnes) * case_px.x, (image / colonnes) * case_px.y, case_px.x, case_px.y
		)
		var union := Rect2i()
		var vide: bool = true
		for img: Image in images:
			var utile: Rect2i = img.get_region(cellule).get_used_rect()
			if utile.size == Vector2i.ZERO:
				continue
			union = utile if vide else union.merge(utile)
			vide = false
		if vide:
			union = Rect2i(0, 0, 1, 1)
		valeurs.append(
			'"%d,%d,%d,%d"' % [union.position.x, union.position.y, union.size.x, union.size.y]
		)
	return '\t"%s": [%s],' % [cle, ", ".join(valeurs)]
