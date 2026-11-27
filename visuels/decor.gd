class_name Decor
extends Node2D
## Le sol et le décor d'une arène 2D, dessinés d'après un `PlanDecor`. Tout ce qui ne bouge pas
## (l'eau, l'écume, la terre en tuiles du pack, le décor plat, les objets hauts immobiles) est
## composé une fois dans une seule image, posée sur un seul sprite : l'écran ne paie qu'un
## remplissage et un tracé, au lieu de plusieurs centaines. Restent des sprites pour ce qui
## s'anime : les sapins et les moutons (triés en profondeur) et les rochers d'eau. Seules leurs
## images changent, et seulement quand l'horloge passe à l'image suivante. Le nœud se pose avant
## les ennemis : rien du décor ne les recouvre.

## Étendue de l'eau autour de l'image composée, en pixels du monde : couvre l'écran le plus large.
const RAYON_EAU: float = 6000.0

static var images_par_seconde: float = float(
	Assets.section("decor").get("images_par_seconde", 10.0)
)
static var taille_tuile: int = int(Assets.section("decor").get("tuile", 64))

var plan: PlanDecor = null

var _temps: float = 0.0
var _image: int = 0
## Par catégorie animée : `Array` d'entrées `[sprite, x0, y0, largeur, hauteur, images, phase, pas]`
## (`x0`, `y0` : coin de la région à la première image ; `pas` : écart entre deux images).
var _animes: Dictionary = {}
var _textures: Dictionary = {}
var _images_sources: Dictionary = {}
var _hauts: Node2D = null
var _fond: Sprite2D = null


## Efface le décor précédent et dessine celui de `nouveau`. L'horloge n'est pas remise à zéro :
## les éléments restent à l'image du moment.
func construire(nouveau: PlanDecor) -> void:
	for enfant: Node in get_children():
		remove_child(enfant)
		enfant.free()
	_animes.clear()
	plan = nouveau
	_poser_les_bords_d_eau()
	_fond = Sprite2D.new()
	_fond.name = "Fond"
	_fond.texture = ImageTexture.create_from_image(_composer())
	_fond.centered = false
	_fond.scale = Vector2.ONE * PlanDecor.echelle
	_fond.position = -Vector2(_demi_image()) * PlanDecor.echelle
	add_child(_fond)
	var rochers := Node2D.new()
	rochers.name = "RochersEau"
	add_child(rochers)
	_hauts = Node2D.new()
	_hauts.name = "Hauts"
	_hauts.y_sort_enabled = true
	add_child(_hauts)
	for objet: Dictionary in plan.objets:
		var type: String = objet["type"]
		if bool(objet["eau"]):
			_ajouter(rochers, type, objet["pieds"], bool(objet["miroir"]), int(objet["phase"]))
		elif PlanDecor.est_anime(type):
			_ajouter(_hauts, type, objet["pieds"], bool(objet["miroir"]), int(objet["phase"]))
	avancer(0.0)


## Fait avancer l'horloge ; ne touche aux sprites que lorsque l'image change.
func avancer(delta: float) -> void:
	_temps += delta
	var image: int = int(_temps * images_par_seconde)
	if image == _image and _temps > 0.0:
		return
	_image = image
	for categorie: String in _animes:
		for entree: Array in _animes[categorie]:
			_poser_image(entree)


## Image courante de la première entrée de chaque catégorie animée.
func images_courantes() -> Dictionary:
	var rendu: Dictionary = {}
	for categorie: String in _animes:
		var entrees: Array = _animes[categorie]
		if not entrees.is_empty():
			rendu[categorie] = _image_de(entrees[0])
	return rendu


## Combien d'images différentes montrent à cet instant les éléments d'une catégorie animée.
func nombre_images_distinctes(categorie: String) -> int:
	var vues: Dictionary = {}
	for entree: Array in _animes.get(categorie, []):
		vues[_image_de(entree)] = true
	return vues.size()


## L'image composée du sol (eau, écume, terre, décor immobile), pour les tests et les captures.
func image_du_sol() -> Image:
	return _fond.texture.get_image() if _fond != null else null


func _image_de(entree: Array) -> int:
	return (_image + int(entree[6])) % int(entree[5])


func _poser_image(entree: Array) -> void:
	var sprite: Sprite2D = entree[0]
	var image: int = _image_de(entree)
	sprite.region_rect = Rect2(
		float(entree[1]) + float(image) * float(entree[7]),
		float(entree[2]),
		float(entree[3]),
		float(entree[4])
	)


func _texture(fichier: String) -> Texture2D:
	if not _textures.has(fichier):
		_textures[fichier] = load(Apparence.RACINE + fichier) as Texture2D
	return _textures[fichier]


## L'image d'une feuille du pack, lue une fois.
func _source(fichier: String) -> Image:
	if not _images_sources.has(fichier):
		var image := _texture(fichier).get_image()
		image.convert(Image.FORMAT_RGBA8)
		_images_sources[fichier] = image
	return _images_sources[fichier]


## Moitié de l'image composée, en pixels de l'image (un pixel de l'image fait `PlanDecor.echelle`
## pixels du monde) : la tour est au centre.
func _demi_image() -> Vector2i:
	return Vector2i(PlanDecor.DEMI_COLONNES * taille_tuile, PlanDecor.DEMI_LIGNES * taille_tuile)


## Pixel de l'image composée sous un point du monde.
func _vers_image(p: Vector2) -> Vector2i:
	return Vector2i((p / PlanDecor.echelle).floor()) + _demi_image()


## Pose une image de la feuille `fichier` (région `source`) sur `dest`, avec miroir au besoin.
func _coller(dest: Image, fichier: String, source: Rect2i, coin: Vector2i, miroir: bool) -> void:
	var morceau := _source(fichier).get_region(source)
	if miroir:
		morceau.flip_x()
	dest.blend_rect(morceau, Rect2i(Vector2i.ZERO, morceau.get_size()), coin)


## Compose l'eau, l'écume (à sa première image), les tuiles de terre, le décor plat puis les objets
## hauts immobiles, du plus au nord au plus au sud (le plus au sud passe devant).
func _composer() -> Image:
	var demi := _demi_image()
	var image := Image.create(demi.x * 2, demi.y * 2, false, Image.FORMAT_RGBA8)
	image.fill(_source(PlanDecor.feuille_eau).get_pixel(0, 0))
	var ecume := PlanDecor.boite_ecume
	for c: Vector2i in plan.ecume:
		var centre := c * taille_tuile + demi + Vector2i(taille_tuile / 2, taille_tuile / 2)
		_coller(
			image,
			PlanDecor.feuille_ecume,
			Rect2i(ecume),
			centre - Vector2i(ecume.size * 0.5),
			false
		)
	var retournees: Dictionary = {}
	for tuile: Dictionary in plan.tuiles:
		var c: Vector2i = tuile["cellule"]
		var atlas: Vector2i = tuile["atlas"]
		var retournement: int = int(tuile["retournement"])
		var cle := Vector2i(atlas.x + 8 * atlas.y, retournement)
		if not retournees.has(cle):
			var morceau := _source(PlanDecor.feuille_terrain).get_region(
				Rect2i(atlas * taille_tuile, Vector2i(taille_tuile, taille_tuile))
			)
			if retournement & 4096 != 0:
				morceau.flip_x()
			if retournement & 8192 != 0:
				morceau.flip_y()
			retournees[cle] = morceau
		var m: Image = retournees[cle]
		image.blend_rect(m, Rect2i(Vector2i.ZERO, m.get_size()), c * taille_tuile + demi)
	var immobiles: Array[Dictionary] = []
	for objet: Dictionary in plan.objets:
		var type: String = objet["type"]
		if not bool(objet["eau"]) and not PlanDecor.est_anime(type):
			immobiles.append(objet)
	# Plats d'abord, puis les hauts par pieds croissants.
	immobiles.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if bool(a["haut"]) != bool(b["haut"]):
				return not bool(a["haut"])
			return (a["pieds"] as Vector2).y < (b["pieds"] as Vector2).y
	)
	for objet: Dictionary in immobiles:
		_coller_objet(image, objet)
	return image


func _coller_objet(image: Image, objet: Dictionary) -> void:
	var type: String = objet["type"]
	var t: Dictionary = PlanDecor.types[type]
	var boite: Rect2 = t["boite"]
	var origine: Vector2i = t["origine"]
	var cellule: Vector2i = t["cellule"]
	var miroir: bool = bool(objet["miroir"])
	var pieds_boite: Vector2 = Vector2(t["pieds"]) - boite.position
	var recul: float = (boite.size.x - pieds_boite.x) if miroir else pieds_boite.x
	var pieds_image := _vers_image(objet["pieds"])
	var coin := pieds_image - Vector2i(int(recul), int(pieds_boite.y))
	var source := Rect2i(
		Vector2i(
			origine.x + int(boite.position.x),
			origine.y + int(t["ligne"]) * cellule.y + int(boite.position.y)
		),
		Vector2i(boite.size)
	)
	_coller(image, String(t["fichier"]), source, coin, miroir)


## Les terres sont bordées d'eau jusqu'aux limites de l'écran le plus large : de grandes bandes
## d'une seule couleur prolongent l'image composée ; elles ne sont tracées que si l'écran y arrive.
func _poser_les_bords_d_eau() -> void:
	var demi := Vector2(_demi_image()) * PlanDecor.echelle
	var grand: float = RAYON_EAU
	# Gauche, droite, haut, bas ; les bandes de gauche et de droite couvrent aussi les coins.
	var bandes: Array[Rect2] = [
		Rect2(-grand, -grand, grand - demi.x, 2.0 * grand),
		Rect2(demi.x, -grand, grand - demi.x, 2.0 * grand),
		Rect2(-demi.x, -grand, 2.0 * demi.x, grand - demi.y),
		Rect2(-demi.x, demi.y, 2.0 * demi.x, grand - demi.y),
	]
	for k: int in bandes.size():
		var bande := Sprite2D.new()
		bande.name = "Eau%d" % k
		bande.texture = _texture(PlanDecor.feuille_eau)
		bande.centered = false
		bande.region_enabled = true
		bande.region_rect = Rect2(0.0, 0.0, float(taille_tuile), float(taille_tuile))
		bande.position = bandes[k].position
		bande.scale = bandes[k].size / float(taille_tuile)
		add_child(bande)


func _ajouter(parent: Node2D, type: String, pieds: Vector2, miroir: bool, phase: int) -> void:
	var t: Dictionary = PlanDecor.types[type]
	var cellule: Vector2i = t["cellule"]
	var origine: Vector2i = t["origine"]
	var sprite := Sprite2D.new()
	sprite.texture = _texture(String(t["fichier"]))
	sprite.centered = false
	sprite.region_enabled = true
	sprite.scale = Vector2.ONE * float(t["echelle"])
	sprite.position = pieds
	sprite.flip_h = miroir
	var boite: Rect2 = t["boite"]
	var pieds_boite: Vector2 = Vector2(t["pieds"]) - boite.position
	# En miroir, le pied de la boîte se retrouve de l'autre côté du sprite.
	sprite.offset = Vector2(
		-(boite.size.x - pieds_boite.x) if miroir else -pieds_boite.x, -pieds_boite.y
	)
	parent.add_child(sprite)
	var images: int = int(t["images"])
	var x0: float = float(origine.x) + boite.position.x
	var y0: float = float(origine.y + int(t["ligne"]) * cellule.y) + boite.position.y
	sprite.region_rect = Rect2(Vector2(x0 + float(phase % images * cellule.x), y0), boite.size)
	var categorie: String = t["categorie"]
	if not _animes.has(categorie):
		_animes[categorie] = []
	var entrees: Array = _animes[categorie]
	entrees.append([sprite, x0, y0, boite.size.x, boite.size.y, images, phase, cellule.x])
	_poser_image(entrees[entrees.size() - 1])
