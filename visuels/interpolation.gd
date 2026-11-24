class_name Interpolation
extends RefCounted
## Lisse les positions d'ennemis entre les deux dernières vues d'arène reçues, quelle que
## soit la source (solo ou réseau). Ne lit que `VueArene`.

## Retard d'affichage : ~2 intervalles à 15 Hz, pour toujours avoir une vue d'avance.
const DELAI_S: float = 0.12
## Au-delà, un ennemi n'a pas « glissé » : il est apparu ailleurs (téléportation, nouvel ennemi).
const SAUT_MAX: float = 200.0

var _a: VueArene = null
var _b: VueArene = null
var _t_a: float = 0.0
var _t_b: float = 0.0
## id → indice dans `_a`, construit une seule fois par `pousser`.
var _index_a: Dictionary = {}


## Une vue de tick inférieur ou égal au dernier reçu est ignorée : réseau non fiable,
## doublon ou arrivée tardive.
func pousser(vue: VueArene, temps_reception: float) -> void:
	if vue == null or (_b != null and vue.tick <= _b.tick):
		return
	_a = _b
	_t_a = _t_b
	_b = vue
	_t_b = temps_reception
	_index_a.clear()
	if _a != null:
		var ids: PackedInt32Array = _a.ennemis_id
		for i: int in ids.size():
			_index_a[ids[i]] = i


func reinitialiser() -> void:
	_a = null
	_b = null
	_t_a = 0.0
	_t_b = 0.0
	_index_a.clear()


## `{vue, ids, pos}` ; `vue` vaut `null` tant qu'aucune vue n'est reçue. Jamais d'extrapolation :
## sans nouvelle vue, les ennemis restent à leur dernière position connue.
func echantillon(temps_rendu: float) -> Dictionary:
	if _b == null:
		return {"vue": null, "ids": PackedInt32Array(), "pos": PackedVector2Array()}
	var ids_b: PackedInt32Array = _b.ennemis_id
	var pos_b: PackedVector2Array = _b.ennemis_pos
	if _a == null:
		return {"vue": _b, "ids": ids_b.duplicate(), "pos": pos_b.duplicate()}
	var duree: float = _t_b - _t_a
	var alpha: float = 1.0
	if duree > 0.0:
		alpha = clampf((temps_rendu - DELAI_S - _t_a) / duree, 0.0, 1.0)
	var pos_a: PackedVector2Array = _a.ennemis_pos
	var familles_a: PackedByteArray = _a.ennemis_famille
	var familles_b: PackedByteArray = _b.ennemis_famille
	var sortie: PackedVector2Array = pos_b.duplicate()
	for i: int in ids_b.size():
		var j: int = _index_a.get(ids_b[i], -1)
		# Même id mais autre famille : un autre ennemi, on ne les mélange pas.
		if j < 0 or familles_a[j] != familles_b[i]:
			continue
		var depart: Vector2 = pos_a[j]
		if depart.distance_to(pos_b[i]) < SAUT_MAX:
			sortie[i] = depart.lerp(pos_b[i], alpha)
	return {"vue": _b, "ids": ids_b.duplicate(), "pos": sortie}
