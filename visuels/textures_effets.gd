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
			noeud.texture = feuille(Effets.FEUILLE_FLECHE)
			noeud.region_enabled = true
			noeud.region_rect = Effets.REGION_FLECHE
		"dynamite", "mine":
			noeud.texture = feuille(Effets.FEUILLE_DYNAMITE)
			noeud.region_enabled = true
			noeud.region_rect = Effets.REGION_DYNAMITE
		"explosion":
			noeud.texture = feuille(Effets.FEUILLE_EXPLOSION)
			noeud.region_enabled = true
			noeud.region_rect = Rect2(0.0, 0.0, Effets.CASE_EXPLOSION, Effets.CASE_EXPLOSION)
			noeud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		"feu":
			noeud.texture = feuille(Effets.FEUILLE_FEU)
			noeud.region_enabled = true
			noeud.region_rect = Rect2(0.0, 0.0, Effets.CASE_FEU, Effets.CASE_FEU)
			noeud.offset = Vector2(0.0, Effets.CASE_FEU * 0.5 - Effets.PIED_FEU)
			noeud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_:
			noeud.texture = forme_dessinee(forme)


func feuille(chemin: String) -> Texture2D:
	if not _feuilles.has(chemin):
		_feuilles[chemin] = load(Apparence.RACINE + chemin) as Texture2D
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
