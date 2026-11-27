class_name MarquesStatut
extends Node2D
## Le petit marqueur posé au-dessus d'un ennemi qui porte l'un des trois statuts du lot 9
## (vulnérable, maudit, siphonné) : une forme propre à chacun sur un fond sombre, côte à côte s'il
## en porte plusieurs. Les cinq statuts plus anciens ne se lisent que par leur teinte. Les
## marqueurs viennent d'un pool plafonné : au-delà, les ennemis suivants n'en ont pas.

## Marqueurs affichés en même temps au plus, et réserve gardée au-delà du besoin.
const PLAFOND: int = 256
const RESERVE: int = 16
## Côté du marqueur à l'écran (pixels), écart entre deux marqueurs et au-dessus de la tête.
const TAILLE: float = 22.0
const ECART: float = 2.0
const MARGE_TETE: float = 6.0
const FOND := Color(0.1, 0.07, 0.15, 0.8)
## Forme (`FormesSignatures`) et statut d'arme dont elle reprend la couleur, par bit d'octet.
const MARQUES: Array[Dictionary] = [
	{"bit": Types.STATUT_VULNERABLE, "forme": "cible_brisee", "statut": "vulnerabilite"},
	{"bit": Types.STATUT_MAUDIT, "forme": "voile", "statut": "malediction_toucher"},
	{"bit": Types.STATUT_SIPHONNE, "forme": "siphon", "statut": "siphon"},
]

var _tex: TexturesEffets = TexturesEffets.new()
var _pool: Array[Node2D] = []
var _formes: PackedStringArray = PackedStringArray()
var _positions: PackedVector2Array = PackedVector2Array()
var _rang: int = 0


## Nombre de marqueurs posés à la dernière image.
func nombre() -> int:
	return _rang


## Nœuds du pool (visibles ou non).
func noeuds() -> int:
	return _pool.size()


func position_de(i: int) -> Vector2:
	return _positions[i] if i >= 0 and i < _rang else Vector2.ZERO


func forme_de(i: int) -> String:
	return _formes[i] if i >= 0 and i < _rang else ""


## À appeler avant de poser les marqueurs d'une image.
func debut() -> void:
	_rang = 0
	_formes.clear()
	_positions.clear()


## Pose les marqueurs des bits de `octet` au-dessus de la tête d'un ennemi dont les pieds sont à
## `pieds` (pixels) et qui mesure `hauteur` pixels.
func poser(pieds: Vector2, hauteur: float, octet: int) -> void:
	var porte: Array[Dictionary] = []
	for marque: Dictionary in MARQUES:
		if octet & int(marque["bit"]) != 0:
			porte.append(marque)
	if porte.is_empty():
		return
	var pas: float = TAILLE + ECART
	var depart: float = -pas * float(porte.size() - 1) * 0.5
	for k: int in porte.size():
		if _rang >= PLAFOND:
			return
		var centre := Vector2(pieds.x + depart + pas * float(k), pieds.y - hauteur - MARGE_TETE)
		_poser_un(porte[k], centre)


## Cache ce qui n'a pas été posé et libère le surplus : à appeler après la dernière pose.
func fin() -> void:
	for k: int in range(_rang, _pool.size()):
		_pool[k].visible = false
	var garder: int = 0 if _rang == 0 else _rang + RESERVE
	while _pool.size() > garder:
		var surplus: Node2D = _pool.pop_back()
		remove_child(surplus)
		surplus.free()


func _poser_un(marque: Dictionary, centre: Vector2) -> void:
	while _pool.size() <= _rang:
		_pool.append(_creer())
	var noeud: Node2D = _pool[_rang]
	noeud.position = centre
	noeud.visible = true
	var forme: String = marque["forme"]
	var dessin: Sprite2D = noeud.get_child(1)
	if dessin.get_meta("forme", "") != forme:
		dessin.set_meta("forme", forme)
		dessin.texture = _tex.forme_dessinee(forme)
		dessin.scale = Vector2.ONE * TAILLE / float(dessin.texture.get_width())
		dessin.modulate = Effets.couleur_statut(String(marque["statut"]))
	_formes.append(forme)
	_positions.append(centre)
	_rang += 1


func _creer() -> Node2D:
	var noeud := Node2D.new()
	noeud.name = "Marque"
	var fond := Sprite2D.new()
	fond.texture = _tex.forme_dessinee("disque")
	fond.scale = Vector2.ONE * (TAILLE + ECART * 2.0) / float(fond.texture.get_width())
	fond.modulate = FOND
	noeud.add_child(fond)
	var dessin := Sprite2D.new()
	noeud.add_child(dessin)
	add_child(noeud)
	return noeud
