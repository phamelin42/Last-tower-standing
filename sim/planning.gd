class_name Planning
extends RefCounted
## Ce que la partie décide pour toutes les arènes à la fois : la famille de chaque manche et la
## difficulté. Séparé de `Partie` pour se tester sans simuler une seule manche.

## Tolérance sur la comparaison d'un temps à un palier : le temps vient d'un compte de pas.
const EPSILON_TEMPS := 1e-9

var _donnees: Donnees
var _rng: RandomNumberGenerator
var _derniere_famille: int = -1
var _dernier_etait_convoi: bool = false


func _init(donnees: Donnees, graine: int) -> void:
	_donnees = donnees
	_rng = RandomNumberGenerator.new()
	_rng.seed = graine


## Famille de la manche `manche` : un index de `Donnees.familles`, ou `familles.size()` pour le
## convoi. À appeler une fois par manche, dans l'ordre. La famille n'est jamais celle de la
## dernière manche normale, convoi intercalé compris ; le convoi ne vient jamais deux manches de
## suite et pas avant `convoi.manche_min`.
func tirer(manche: int) -> int:
	var n := _donnees.familles.size()
	if n == 0:
		return -1
	var convoi: Dictionary = _donnees.partie["convoi"]
	var possible := manche >= int(convoi["manche_min"]) and not _dernier_etait_convoi
	if possible and _rng.randf() < float(convoi["probabilite"]):
		_dernier_etait_convoi = true
		return n
	_dernier_etait_convoi = false
	var choix := 0
	if n > 1:
		if _derniere_famille < 0:
			choix = _rng.randi_range(0, n - 1)
		else:
			choix = _rng.randi_range(0, n - 2)
			if choix >= _derniere_famille:
				choix += 1
	_derniere_famille = choix
	return choix


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
