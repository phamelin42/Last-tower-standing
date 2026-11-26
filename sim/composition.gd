class_name Composition
extends RefCounted
## Ce qu'une manche fait apparaître : deux ou trois familles (index de `Donnees.familles`, la
## majoritaire d'abord) et leurs poids, de somme 1. Le convoi a une composition unique : son index
## est `familles.size()`. Chaque apparition tire sa famille selon les poids.

var familles: PackedInt32Array = PackedInt32Array()
var poids: PackedFloat32Array = PackedFloat32Array()


## Une seule famille, de poids 1.
static func unique(famille: int) -> Composition:
	var c := Composition.new()
	c.familles = PackedInt32Array([famille])
	c.poids = PackedFloat32Array([1.0])
	return c


## La famille la plus fréquente (la première) ; -1 si la composition est vide.
func majoritaire() -> int:
	return familles[0] if not familles.is_empty() else -1


## La famille d'une apparition. Le hasard n'est consommé que s'il y a un choix à faire : une
## composition unique ne change pas la suite des tirages.
func tirer(rng: RandomNumberGenerator) -> int:
	if familles.is_empty():
		return -1
	if familles.size() == 1:
		return familles[0]
	var x := rng.randf()
	var cumul := 0.0
	for i: int in familles.size():
		cumul += poids[i]
		if x < cumul:
			return familles[i]
	return familles[familles.size() - 1]
