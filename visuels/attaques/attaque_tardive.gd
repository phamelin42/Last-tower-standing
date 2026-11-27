class_name AttaqueTardive
extends AttaqueElement
## Un élément de fin de partie (T12.8, Q5) : la famille d'une arme existante (`_base` : son
## geste, ses planches, sa fiche) teintée de la teinte de la rareté de l'arme (`data/assets.json`).
## Il ne dessine rien lui-même : chaque méthode passe à la famille, et `AttaquesElementaires`
## applique `teinte()` à tout ce que l'élément crée.

var _id: String = ""
var _base: AttaqueElement = null
var _teinte: Color = Color.WHITE


## `id` : l'élément (celui de l'arme) ; `base` : l'élément de la famille ; `teinte` : celle de la
## rareté.
static func creer(id_arme: String, base: AttaqueElement, teinte: Color) -> AttaqueTardive:
	var e := AttaqueTardive.new()
	e._id = id_arme
	e._base = base
	e._teinte = teinte
	return e


func id() -> String:
	return _id


func teinte() -> Color:
	return _teinte


func conf() -> Dictionary:
	return _base.conf()


func planches() -> Dictionary:
	return _base.planches()


func visibles() -> Dictionary:
	return _base.visibles()


func suivre_vol(m: AttaquesElementaires, vol: Dictionary, attente: float, duree_vol: float) -> void:
	_base.suivre_vol(m, vol, attente, duree_vol)


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, de: Vector2, age: float
) -> bool:
	return _base.impacter(m, ou, rayon_px, fort, de, age)


func impacter_en_groupe(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, de: Vector2, age: float
) -> bool:
	return _base.impacter_en_groupe(m, ou, rayon_px, fort, de, age)


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return _base.zone(m, centre, rayon_px, age)


func aura(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return _base.aura(m, centre, rayon_px, age)


func onde(m: AttaquesElementaires, centre: Vector2, age: float) -> bool:
	return _base.onde(m, centre, age)


func piege(m: AttaquesElementaires, depart: Vector2, arrivee: Vector2) -> bool:
	return _base.piege(m, depart, arrivee)
