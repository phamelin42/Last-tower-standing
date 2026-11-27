class_name TexturesEffets
extends RefCounted
## Les textures des effets : images du pack (en cache) et formes simples dessinées une fois pour
## toutes. `Effets` s'en sert pour habiller ses nœuds du pool.

## Textures de formes simples, dessinées une fois pour toutes (blanches : `modulate` les teinte).
static var _formes: Dictionary = {}

var _feuilles: Dictionary = {}


## Texture, région et ancrage d'une forme. Les images du pack restent nettes, les formes dessinées
## sont lissées.
func habiller(noeud: Sprite2D, forme: String) -> void:
	noeud.rotation = 0.0
	noeud.offset = Vector2.ZERO
	noeud.region_enabled = false
	noeud.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	match forme:
		"fleche":
			var fleche: Dictionary = PlanchesEffets.pack("fleche")
			noeud.texture = feuille(PlanchesEffets.chemin_pack("fleche"))
			noeud.region_enabled = true
			noeud.region_rect = fleche["region"]
		"dynamite", "mine":
			var dynamite: Dictionary = PlanchesEffets.pack("dynamite")
			noeud.texture = feuille(PlanchesEffets.chemin_pack("dynamite"))
			noeud.region_enabled = true
			noeud.region_rect = dynamite["region"]
		"explosion":
			var explosion: Dictionary = PlanchesEffets.pack("explosion")
			noeud.texture = feuille(PlanchesEffets.chemin_pack("explosion"))
			noeud.region_enabled = true
			noeud.region_rect = Rect2(Vector2.ZERO, Vector2(explosion["case"] as Vector2i))
			noeud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		"feu":
			var feu: Dictionary = PlanchesEffets.pack("feu")
			var case_px: Vector2i = feu["case"]
			noeud.texture = feuille(PlanchesEffets.chemin_pack("feu"))
			noeud.region_enabled = true
			noeud.region_rect = Rect2(Vector2.ZERO, Vector2(case_px))
			noeud.offset = Vector2(0.0, case_px.y * 0.5 - float(feu["pieds"]))
			noeud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_:
			noeud.texture = forme_dessinee(forme)


func feuille(chemin: String) -> Texture2D:
	if not _feuilles.has(chemin):
		_feuilles[chemin] = load(chemin) as Texture2D
	return _feuilles[chemin]


func forme_dessinee(nom: String) -> Texture2D:
	if not _formes.has(nom):
		var image: Image = (
			FormesEffets.image(nom)
			if Effets.FORMES_PROPRES.has(nom)
			else FormesSignatures.image(nom)
		)
		_formes[nom] = ImageTexture.create_from_image(image)
	return _formes[nom]
