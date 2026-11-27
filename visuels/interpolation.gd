class_name Interpolation
extends RefCounted
## Lisse les positions d'ennemis entre les deux dernières vues d'arène reçues, quelle que
## soit la source (solo ou réseau). Ne lit que `VueArene`.

## Le temps affiché a un intervalle entre vues de retard, mesuré à la réception : quand la vue b
## arrive, on affiche encore la position de a, puis on glisse vers b en l'atteignant pile quand
## la vue suivante tombe (cadence régulière). La position ne saute donc jamais à une arrivée, que
## les vues viennent à 15 Hz (réseau) ou à 5 Hz (arène regardée).
## Bornes du retard : pas moins de 1/30 s (deux vues presque simultanées ne doivent pas figer le
## calcul), pas plus de 0,25 s (une longue pause ne doit pas geler l'ennemi, ni l'affichage
## traîner d'un quart de seconde derrière la partie).
const RETARD_MIN_S: float = 1.0 / 30.0
const RETARD_MAX_S: float = 0.25
## Part du nouvel intervalle dans le retard (moyenne glissante) : la gigue du réseau (une vue
## tardive suivie d'une vue rapprochée) ne fait varier le retard que d'un tiers de l'écart, donc
## l'ennemi ne saute pas d'un pas entier quand le rythme se perturbe.
const LISSAGE_RETARD: float = 0.3
## Au-delà, un ennemi n'a pas « glissé » : il est apparu ailleurs (téléportation, nouvel ennemi).
const SAUT_MAX: float = 200.0

var _a: VueArene = null
var _b: VueArene = null
var _t_a: float = 0.0
var _t_b: float = 0.0
## Retard d'affichage courant (secondes) ; `_retard_mesure` vaut faux avant le premier intervalle.
var _retard: float = RETARD_MAX_S
var _retard_mesure: bool = false
## id → indice dans `_a`, construit une seule fois par `pousser`.
var _index_a: Dictionary = {}
## Même chose pour les alliés : identifiant → indice dans `_a.allies`.
var _index_allies_a: Dictionary = {}


## Une vue de tick inférieur ou égal au dernier reçu est ignorée : réseau non fiable,
## doublon ou arrivée tardive.
func pousser(vue: VueArene, temps_reception: float) -> void:
	if vue == null or (_b != null and vue.tick <= _b.tick):
		return
	if _b != null:
		var intervalle: float = clampf(temps_reception - _t_b, RETARD_MIN_S, RETARD_MAX_S)
		_retard = lerpf(_retard, intervalle, LISSAGE_RETARD) if _retard_mesure else intervalle
		_retard_mesure = true
	_a = _b
	_t_a = _t_b
	_b = vue
	_t_b = temps_reception
	_index_a.clear()
	_index_allies_a.clear()
	if _a != null:
		var ids: PackedInt32Array = _a.ennemis_id
		for i: int in ids.size():
			_index_a[ids[i]] = i
		for j: int in _a.allies.size():
			_index_allies_a[int((_a.allies[j] as Dictionary)["id"])] = j


func reinitialiser() -> void:
	_a = null
	_b = null
	_t_a = 0.0
	_t_b = 0.0
	_retard = RETARD_MAX_S
	_retard_mesure = false
	_index_a.clear()
	_index_allies_a.clear()


## `{vue, ids, pos}` ; `vue` vaut `null` tant qu'aucune vue n'est reçue. `temps_rendu` est
## l'horloge de rendu, sur la même échelle que `temps_reception` : le retard est appliqué ici.
## Jamais d'extrapolation : sans nouvelle vue, les ennemis restent à leur dernière position connue.
func echantillon(temps_rendu: float) -> Dictionary:
	if _b == null:
		return {"vue": null, "ids": PackedInt32Array(), "pos": PackedVector2Array()}
	var ids_b: PackedInt32Array = _b.ennemis_id
	var pos_b: PackedVector2Array = _b.ennemis_pos
	if _a == null:
		return {"vue": _b, "ids": ids_b.duplicate(), "pos": pos_b.duplicate()}
	var alpha: float = _alpha(temps_rendu)
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


## Les alliés à l'instant `temps_rendu`, glissés comme les ennemis : `{ids, pos, unite, deplace}`
## (`deplace` : 1 si l'allié a bougé entre les deux vues, pour choisir marche ou repos). Un allié
## qui n'était pas dans la vue précédente, ou qui a changé d'unité, ou qui a « sauté » plus loin
## que `SAUT_MAX`, apparaît à sa position sans glisser.
func echantillon_allies(temps_rendu: float) -> Dictionary:
	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var unites := PackedInt32Array()
	var deplaces := PackedByteArray()
	if _b != null:
		var alpha: float = _alpha(temps_rendu)
		for allie: Dictionary in _b.allies:
			var pos_b: Vector2 = allie["pos"]
			var pos: Vector2 = pos_b
			var bouge: int = 0
			var j: int = _index_allies_a.get(int(allie["id"]), -1) if _a != null else -1
			if j >= 0:
				var avant: Dictionary = _a.allies[j]
				var depart: Vector2 = avant["pos"]
				var meme: bool = int(avant["unite"]) == int(allie["unite"])
				if meme and depart.distance_to(pos_b) < SAUT_MAX:
					pos = depart.lerp(pos_b, alpha)
					bouge = 1 if depart != pos_b else 0
			ids.append(int(allie["id"]))
			positions.append(pos)
			unites.append(int(allie["unite"]))
			deplaces.append(bouge)
	return {"ids": ids, "pos": positions, "unite": unites, "deplace": deplaces}


## Avancement entre la vue a et la vue b, de 0 à 1 (1 quand il n'y a pas d'intervalle).
func _alpha(temps_rendu: float) -> float:
	var duree: float = _t_b - _t_a
	if duree > 0.0:
		return clampf((temps_rendu - _retard - _t_a) / duree, 0.0, 1.0)
	return 1.0
