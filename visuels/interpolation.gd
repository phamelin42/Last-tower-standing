class_name Interpolation
extends RefCounted
## Lisse les positions d'ennemis entre les deux dernières vues d'arène reçues, quelle que
## soit la source (solo ou réseau). Ne lit que `VueArene`.

## Le temps affiché a un intervalle entre vues de retard, mesuré à la réception : quand la vue b
## arrive, on affiche encore la position de a, puis on glisse vers b en l'atteignant pile quand
## la vue suivante tombe. À cadence régulière (20, 15 ou 5 Hz), la position ne saute donc pas à
## une arrivée : le pas affiché reste le pas idéal. En cadence irrégulière, deux garanties
## seulement : le retard ne bouge que d'un tiers de l'écart (`LISSAGE_RETARD`), et deux vues
## reçues dans la même image de rendu se fondent en un seul glissement. Une vue très en retard ou
## en avance déplace quand même l'ennemi : un rejeu à 20 Hz avec ±40 ms de gigue a mesuré 6 à 8 fois
## le pas idéal, une perte de 200 ms 8 fois ; seul un tampon de plusieurs vues y remédierait.
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
## Deux vues reçues à moins de cela l'une de l'autre l'ont été dans la même image de rendu.
const MEME_IMAGE_S: float = 0.001

var _a: VueArene = null
var _b: VueArene = null
var _t_a: float = 0.0
var _t_b: float = 0.0
## Retard d'affichage courant (secondes) ; `_retard_mesure` vaut faux avant le premier intervalle.
var _retard: float = RETARD_MAX_S
var _retard_mesure: bool = false
## Le retard d'avant la dernière vue, pour le rendre quand une vue arrive dans la même image.
var _retard_avant: float = RETARD_MAX_S
var _retard_mesure_avant: bool = false
## id → indice dans `_a`, construit une seule fois par `pousser`.
var _index_a: Dictionary = {}
## Même chose pour les alliés : identifiant → indice dans `_a.allies`.
var _index_allies_a: Dictionary = {}


## Une vue de tick inférieur ou égal au dernier reçu est ignorée : réseau non fiable,
## doublon ou arrivée tardive.
func pousser(vue: VueArene, temps_reception: float) -> void:
	if vue == null or (_b != null and vue.tick <= _b.tick):
		return
	if _b != null and _a != null and temps_reception - _t_b < MEME_IMAGE_S:
		_fondre_dans_la_meme_image(vue, temps_reception)
		return
	_retard_avant = _retard
	_retard_mesure_avant = _retard_mesure
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


## `vue` arrive dans la même image que `_b` : en faire la nouvelle paire (a, b) mettrait deux vues
## au même temps, et l'ennemi sauterait d'un coup à la dernière (`_alpha` rendrait 1). Elle remplace
## donc `_b`. Le retard d'avant reprend sa valeur : la vue précédente, tardive, l'avait allongé d'un
## intervalle que les deux vues réunies annulent. Le glissement part de ce qui est affiché à cet
## instant (la vue a, ou plus loin si l'affichage avait déjà avancé) et atteint `_b` à l'heure : il
## rattrape l'attente en au plus deux fois la vitesse normale, sans saut.
func _fondre_dans_la_meme_image(vue: VueArene, temps_reception: float) -> void:
	_b = vue
	_retard = _retard_avant
	_retard_mesure = _retard_mesure_avant
	_t_a = maxf(_t_a, temps_reception - _retard)


func reinitialiser() -> void:
	_a = null
	_b = null
	_t_a = 0.0
	_t_b = 0.0
	_retard = RETARD_MAX_S
	_retard_mesure = false
	_retard_avant = RETARD_MAX_S
	_retard_mesure_avant = false
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
