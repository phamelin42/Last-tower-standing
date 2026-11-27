class_name AttaqueTardive
extends AttaqueElement
## Un élément de fin de partie (T12.8, Q5) : la famille d'une arme existante (`_base` : son
## geste, ses planches, sa fiche) teintée de la teinte de la rareté de l'arme (`data/assets.json`).
## Il ne dessine rien lui-même : chaque méthode passe à la famille, et `AttaquesElementaires`
## applique `teinte()` à tout ce que l'élément crée. Il y ajoute la marque de sa rareté
## (`MarquesRarete`) : une forme non colorée, qui distingue l'arme de sa base sans la couleur ; et,
## si `data/assets.json` lui en donne un (`familles_tardives.<arme>.disque`), son propre tapis.

var _id: String = ""
var _base: AttaqueElement = null
var _teinte: Color = Color.WHITE
var _rarete: String = ""
var _conf: Dictionary = {}


## `id` : l'élément (celui de l'arme) ; `base` : l'élément de la famille ; `teinte` : celle de la
## rareté ; `rarete` : son nom (la marque en dépend) ; `disque` : le tapis propre de l'arme, `""`
## pour garder celui de la famille.
static func creer(
	id_arme: String, base: AttaqueElement, teinte: Color, rarete: String = "", disque: String = ""
) -> AttaqueTardive:
	var e := AttaqueTardive.new()
	e._id = id_arme
	e._base = base
	e._teinte = teinte
	e._rarete = rarete
	e._conf = base.conf()
	if disque != "":
		e._conf = e._conf.duplicate()
		e._conf["disque"] = disque
	return e


func id() -> String:
	return _id


func teinte() -> Color:
	return _teinte


func conf() -> Dictionary:
	return _conf


## Les planches de la famille, plus celles que `data/assets.json` attribue à l'arme (son tapis).
func planches() -> Dictionary:
	var sortie: Dictionary = _base.planches().duplicate()
	sortie.merge(PlanchesEffets.cases_de(_id))
	return sortie


func visibles() -> Dictionary:
	var sortie: Dictionary = _base.visibles().duplicate()
	sortie.merge(PlanchesEffets.visibles_de(_id))
	return sortie


func suivre_vol(m: AttaquesElementaires, vol: Dictionary, attente: float, duree_vol: float) -> void:
	_base.suivre_vol(m, vol, attente, duree_vol)
	MarquesRarete.suivre_vol(m, _rarete, vol, attente, duree_vol)


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, de: Vector2, age: float
) -> bool:
	var cree: bool = _base.impacter(m, ou, rayon_px, fort, de, age)
	return _marquer(m, cree, ou, age)


func impacter_en_groupe(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, de: Vector2, age: float
) -> bool:
	var cree: bool = _base.impacter_en_groupe(m, ou, rayon_px, fort, de, age)
	return _marquer(m, cree, ou, age)


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return _base.zone(m, centre, rayon_px, age)


func aura(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return _marquer(m, _base.aura(m, centre, rayon_px, age), centre, age)


func onde(m: AttaquesElementaires, centre: Vector2, age: float) -> bool:
	return _marquer(m, _base.onde(m, centre, age), centre, age)


func piege(m: AttaquesElementaires, depart: Vector2, arrivee: Vector2) -> bool:
	return _marquer(m, _base.piege(m, depart, arrivee), arrivee, 0.0)


## Pose la marque de rareté en `ou` quand la famille a créé son effet (`cree`) ; rend `cree`.
func _marquer(m: AttaquesElementaires, cree: bool, ou: Vector2, age: float) -> bool:
	if cree:
		MarquesRarete.a_l_impact(m, _rarete, ou, age)
	return cree
