class_name GeometriePlanches
extends RefCounted
## La géométrie des planches carrées d'effets, lue sur l'image elle-même (T10.4, assets
## remplaçables) : la case est un carré de la hauteur de la planche, le diamètre visible est celui
## de la plus grande image (la boîte des pixels opaques). Remplacer une planche ne demande que
## de remplacer le fichier : aucun nombre à recopier dans le code.

static var _cases: Dictionary = {}
static var _visibles: Dictionary = {}


## La taille d'une image de la planche carrée `nom` (chargée par `AttaquesElementaires`, qui garde
## la liste fermée des images), ou 1×1 si la texture est vide.
static func case_de(nom: String) -> Vector2i:
	_mesurer(nom)
	return _cases[nom]


## Le plus grand côté, en pixels de planche, de la boîte des pixels opaques d'une image ; 0 si la
## texture est vide.
static func visible_de(nom: String) -> float:
	_mesurer(nom)
	return _visibles[nom]


static func _mesurer(nom: String) -> void:
	if _cases.has(nom):
		return
	_cases[nom] = Vector2i.ONE
	_visibles[nom] = 0.0
	var texture: Texture2D = AttaquesElementaires.texture_de(nom)
	if texture == null:
		return
	var img: Image = texture.get_image()
	var cote: int = img.get_height()
	_cases[nom] = Vector2i(cote, cote)
	var plus_grand: int = 0
	for rang: int in img.get_width() / cote:
		var haut: int = cote
		var bas: int = -1
		var gauche: int = cote
		var droite: int = -1
		for y: int in cote:
			for x: int in cote:
				if img.get_pixel(rang * cote + x, y).a > 0.0:
					haut = mini(haut, y)
					bas = maxi(bas, y)
					gauche = mini(gauche, x)
					droite = maxi(droite, x)
		if bas >= 0:
			plus_grand = maxi(plus_grand, maxi(bas - haut + 1, droite - gauche + 1))
	_visibles[nom] = float(plus_grand)
