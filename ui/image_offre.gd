class_name ImageOffre
extends RefCounted
## Image d'une offre (case peinte de `ImagesOffres`) posée dans l'interface. Elle est décorative :
## le nom et le type sont écrits à côté, elle ne reçoit ni la souris ni le focus. Le filtrage est
## lisse, car ces cases sont peintes et non du pixel art.

static var _cache: Dictionary = {}


## Texture de la case de l'offre, ou `null` si l'identifiant est inconnu.
static func texture(id: String) -> Texture2D:
	if not ImagesOffres.OFFRES.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load(ImagesOffres.chemin_case(id)) as Texture2D
	return _cache[id] as Texture2D


## Case vide, carrée, à la taille donnée ; `poser` y met l'image d'une offre.
static func creer(nom: String, taille: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = nom
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.focus_mode = Control.FOCUS_NONE
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	regler_taille(rect, taille)
	return rect


static func poser(rect: TextureRect, id: String) -> void:
	rect.texture = texture(id)


static func regler_taille(rect: TextureRect, taille: float) -> void:
	rect.custom_minimum_size = Vector2(taille, taille)
