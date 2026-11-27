class_name CranesArene
extends RefCounted
## Les crânes des ennemis morts (`Apparence.mort`) : une courte animation posée là où l'ennemi est
## tombé, qui disparaît à sa dernière image. Les sprites vont dans le nœud des ennemis, pour se
## trier en profondeur avec eux, et sont réutilisés d'une mort à l'autre.

## Crânes affichés en même temps au plus ; les suivants de la même vue sont ignorés.
const PLAFOND: int = 64

var _parent: Node2D = null
var _texture: Texture2D = null
var _regions: Array[Rect2] = []
var _decalages: PackedVector2Array = PackedVector2Array()
var _sprites: Array[Sprite2D] = []
var _debuts: PackedFloat64Array = PackedFloat64Array()
## Image affichée par chaque crâne (-1 : pas encore posée), pour ne reposer sa région qu'au besoin.
var _images: PackedInt32Array = PackedInt32Array()


func _init(parent: Node2D) -> void:
	_parent = parent
	var mort: Dictionary = Apparence.mort
	_texture = load(String(mort["feuille"])) as Texture2D
	for image: int in int(mort["images"]):
		var p: Dictionary = Apparence.placement(
			String(mort["cle_boites"]),
			image,
			mort["case"],
			int(mort["colonnes"]),
			float(mort["pieds"]),
			true
		)
		_regions.append(p["region"])
		_decalages.append(p["offset"])


## Pose un crâne en `ou` (unités de jeu) à l'instant `horloge`, sauf si `PLAFOND` sont visibles ;
## rend vrai s'il est posé (une mort qu'on ne montre pas ne fait pas de bruit).
func ajouter(ou: Vector2, horloge: float) -> bool:
	var index: int = -1
	for i: int in _sprites.size():
		if not _sprites[i].visible:
			index = i
			break
	if index < 0:
		if _sprites.size() >= PLAFOND:
			return false
		_sprites.append(_creer())
		_debuts.append(0.0)
		_images.append(-1)
		index = _sprites.size() - 1
	var sprite: Sprite2D = _sprites[index]
	_debuts[index] = horloge
	_images[index] = -1
	sprite.position = Apparence.vers_pixels(ou)
	sprite.visible = true
	return true


## Avance l'animation de chaque crâne visible ; il disparaît après sa dernière image.
func animer(horloge: float) -> void:
	var images: int = Apparence.mort["images"]
	var par_seconde: float = Apparence.mort["images_par_seconde"]
	for i: int in _sprites.size():
		var sprite: Sprite2D = _sprites[i]
		if not sprite.visible:
			continue
		var image: int = int((horloge - _debuts[i]) * par_seconde)
		if image >= images or image < 0:
			sprite.visible = false
		elif image != _images[i]:
			_images[i] = image
			sprite.region_rect = _regions[image]
			sprite.offset = _decalages[image]


func nombre_visibles() -> int:
	var n: int = 0
	for sprite: Sprite2D in _sprites:
		if sprite.visible:
			n += 1
	return n


func sprite(i: int) -> Sprite2D:
	return _sprites[i] if i >= 0 and i < _sprites.size() else null


func _creer() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Mort"
	sprite.texture = _texture
	sprite.region_enabled = true
	sprite.scale = Vector2.ONE * float(Apparence.mort["echelle"]) * Apparence.echelle_unites
	sprite.visible = false
	_parent.add_child(sprite)
	return sprite
