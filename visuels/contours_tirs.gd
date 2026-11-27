class_name ContoursTirs
extends RefCounted
## Le contour clair des tirs fins à cible unique (`data/assets.json`, `effets.contour_tirs`) : une
## liste de planches de projectile, la couleur et l'épaisseur du contour en pixels de planche. Il
## est calculé au chargement sur l'alpha de la planche, jamais dessiné dans le fichier : remplacer
## l'image ne demande que de changer le fichier. `eclairs` donne le même liseré au trait tracé de la
## chaîne d'arcanes.

static var _version: int = -1
static var _donnees: Dictionary = {}


## Les planches de projectile contourées.
static func planches() -> PackedStringArray:
	_lire()
	var noms := PackedStringArray()
	for nom: Variant in _donnees.get("planches", []):
		noms.append(String(nom))
	return noms


## Épaisseur du contour, en pixels de planche.
static func epaisseur() -> int:
	_lire()
	return int(_donnees.get("epaisseur", 0))


static func couleur() -> Color:
	_lire()
	return _donnees.get("contour", Color.WHITE)


## Vrai si le trait de la chaîne d'arcanes a son liseré.
static func eclairs() -> bool:
	_lire()
	return bool(_donnees.get("eclairs", false))


## Le nombre de pixels dont chaque image de `planche` est élargie de chaque côté : l'épaisseur du
## contour pour une planche de la liste, 0 sinon.
static func marge(planche: String) -> int:
	return epaisseur() if planches().has(planche) else 0


## `source` (une rangée d'images de `cellule` pixels) habillée d'un contour de `marge` pixels de
## `couleur` : chaque image gagne `marge` pixels transparents de chaque côté, et tout pixel vide à
## `marge` pixels ou moins d'un pixel opaque prend `couleur`. Le contour passe donc hors de
## l'ancienne case, pour un dessin qui touche son bord.
static func habiller(source: Image, cellule: Vector2i, marge: int, couleur: Color) -> Image:
	var depart: Image = source.duplicate()
	depart.convert(Image.FORMAT_RGBA8)
	var colonnes: int = depart.get_width() / cellule.x
	var rangees: int = depart.get_height() / cellule.y
	if colonnes < 1 or rangees < 1:
		return source
	var large: Vector2i = cellule + Vector2i.ONE * 2 * marge
	var sortie: Image = Image.create(
		colonnes * large.x, rangees * large.y, false, Image.FORMAT_RGBA8
	)
	for rangee: int in rangees:
		for colonne: int in colonnes:
			var origine := Vector2i(colonne * cellule.x, rangee * cellule.y)
			for y: int in large.y:
				for x: int in large.x:
					var local := Vector2i(x - marge, y - marge)
					var pixel: Color = _pixel(depart, origine, cellule, local)
					if pixel.a <= 0.0 and _voisin_opaque(depart, origine, cellule, local, marge):
						pixel = couleur
					sortie.set_pixel(colonne * large.x + x, rangee * large.y + y, pixel)
	return sortie


## Le pixel `local` de la cellule d'origine `origine`, transparent hors de la cellule.
static func _pixel(image: Image, origine: Vector2i, cellule: Vector2i, local: Vector2i) -> Color:
	if local.x < 0 or local.y < 0 or local.x >= cellule.x or local.y >= cellule.y:
		return Color(0.0, 0.0, 0.0, 0.0)
	return image.get_pixelv(origine + local)


static func _voisin_opaque(
	image: Image, origine: Vector2i, cellule: Vector2i, local: Vector2i, marge: int
) -> bool:
	for dy: int in range(-marge, marge + 1):
		for dx: int in range(-marge, marge + 1):
			if _pixel(image, origine, cellule, local + Vector2i(dx, dy)).a > 0.0:
				return true
	return false


static func _lire() -> void:
	if _version == Assets.version:
		return
	_version = Assets.version
	_donnees = (Assets.typee("effets") as Dictionary).get("contour_tirs", {})
