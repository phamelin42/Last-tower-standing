class_name Planning
extends RefCounted
## Ce que la partie décide pour toutes les arènes à la fois : la composition de chaque manche et la
## difficulté. Séparé de `Partie` pour se tester sans simuler une seule manche.

## Tolérance sur la comparaison d'un temps à un palier : le temps vient d'un compte de pas.
const EPSILON_TEMPS := 1e-9

var _donnees: Donnees
var _rng: RandomNumberGenerator
var _derniere_famille: int = -1


func _init(donnees: Donnees, graine: int) -> void:
	_donnees = donnees
	_rng = RandomNumberGenerator.new()
	_rng.seed = graine


## Composition de la manche `manche` : deux ou trois familles (`vagues` de `data/partie.json`)
## dont une majoritaire (`part_majoritaire` des apparitions, le reste partagé), tirées parmi celles
## que leur palier et leur modèle autorisent ; ou le convoi (composition unique d'index
## `familles.size()`). À appeler une fois par manche, dans l'ordre. La majoritaire n'est jamais
## celle de la dernière manche normale, convoi intercalé compris ; le convoi vient aux manches
## multiples de `convoi.tous_les` (10, 20, 30…), sans tirage au sort (retour de Phil, 27/11).
func tirer(manche: int) -> Composition:
	var n := _donnees.familles.size()
	if n == 0:
		return Composition.unique(-1)
	var convoi: Dictionary = _donnees.partie["convoi"]
	if manche >= 1 and manche % int(convoi["tous_les"]) == 0:
		return Composition.unique(n)
	var candidates := _familles_disponibles(manche)
	var pool: Array[int] = []
	for i: int in candidates:
		if i != _derniere_famille:
			pool.append(i)
	if pool.is_empty():
		pool = candidates.duplicate()
	var majoritaire := pool[_rng.randi_range(0, pool.size() - 1)]
	_derniere_famille = majoritaire
	var vagues: Dictionary = _donnees.partie["vagues"]
	var nombre := _rng.randi_range(int(vagues["familles_min"]), int(vagues["familles_max"]))
	var autres: Array[int] = []
	for i: int in candidates:
		if i != majoritaire:
			autres.append(i)
	nombre = mini(nombre, autres.size() + 1)
	var composition := Composition.new()
	composition.graine = _rng.randi()
	composition.familles.append(majoritaire)
	for _k: int in range(1, nombre):
		var tiree := _rng.randi_range(0, autres.size() - 1)
		composition.familles.append(autres[tiree])
		autres.remove_at(tiree)
	var part := float(vagues["part_majoritaire"])
	if composition.familles.size() == 1:
		composition.poids.append(1.0)
	else:
		composition.poids.append(part)
		var reste := (1.0 - part) / float(composition.familles.size() - 1)
		for _k: int in range(1, composition.familles.size()):
			composition.poids.append(reste)
	return composition


## Index des familles qui peuvent sortir à la manche `manche` : leur palier est entré
## (`manche_entree`) et leur modèle est arrivé (`manche_min`). Jamais vide : à défaut, la première
## famille, pour qu'une manche ait toujours des ennemis.
func _familles_disponibles(manche: int) -> Array[int]:
	var disponibles: Array[int] = []
	for i in _donnees.familles.size():
		var famille: Dictionary = _donnees.familles[i]
		if manche >= int(famille["manche_entree"]) and manche >= int(famille["manche_min"]):
			disponibles.append(i)
	if disponibles.is_empty():
		disponibles.append(0)
	return disponibles


## {pv, degats, vitesse, resistance_controle} d'une manche commencée au temps `temps` (s de jeu).
## Au-delà du dernier palier de la table, `apres_table` s'applique une fois par manche de plus ;
## chaque accélération dont le temps est atteint multiplie pv, dégâts et vitesse.
static func multiplicateurs(donnees: Donnees, manche: int, temps: float) -> Dictionary:
	var diff: Dictionary = donnees.difficulte
	var paliers: Array = diff["paliers"]
	var dernier: Dictionary = paliers[paliers.size() - 1]
	var en_plus := maxi(manche - int(dernier["manche"]), 0)
	var apres: Dictionary = diff["apres_table"]
	var m := {}
	for cle: String in ["pv", "degats", "vitesse", "resistance_controle"]:
		var base := donnees.palier(paliers, manche, cle)
		m[cle] = base * pow(float(apres.get(cle, 1.0)), en_plus)
	var accelerations: Array = diff["accelerations"]
	for entree: Variant in accelerations:
		var a: Dictionary = entree
		if float(a["temps_s"]) <= temps + EPSILON_TEMPS:
			for cle: String in ["pv", "degats", "vitesse"]:
				m[cle] = float(m[cle]) * float(a.get(cle, 1.0))
	m["resistance_controle"] = maxf(
		float(m["resistance_controle"]), float(diff["resistance_plancher"])
	)
	return m
