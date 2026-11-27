class_name RayonsReculs
extends RefCounted
## Deux effets du lot 9 qui naissent d'un événement d'arène et vivent dans le pool d'`Effets` (ils
## comptent donc dans son plafond) : le rayon d'une branche de tir tournant, trait effilé qui part
## de la tour et s'éteint vite, et le trait de recul d'un repoussement, deux chevrons qui
## s'éloignent de la tour depuis l'ennemi repoussé.

## Un rayon dure moins que l'intervalle entre deux tirs : le suivant, tourné, prend le relais.
const DUREE_RAYON: float = 0.25
const DUREE_RECUL: float = 0.4
## Distance (pixels) dont les chevrons s'éloignent, et leur taille.
const DISTANCE_RECUL: float = 48.0
const TAILLE_RECUL: float = 44.0
## Épaisseur d'un rayon, en multiple de celle d'un trait ordinaire : il suit la largeur du tir
## (unités de jeu) entre ces bornes.
const EPAISSEUR_MIN: float = 1.0
const EPAISSEUR_MAX: float = 3.0
## Une forme dessinée de huit pixels de haut : une largeur de 8 unités fait un trait ordinaire.
const HAUTEUR_FORME: float = 8.0

var _effets: Effets = null


func _init(effets: Effets) -> void:
	_effets = effets


## Un rayon de la tour (`depart`) à `arrivee` (pixels), de `largeur` unités de jeu.
func rayon(depart: Vector2, arrivee: Vector2, largeur: float, couleur: Color) -> bool:
	var effet: Dictionary = _effets.creer("trait_rayon", "trait", DUREE_RAYON, couleur)
	if effet.is_empty():
		return false
	effet["depart"] = depart
	effet["arrivee"] = arrivee
	effet["epaisseur"] = clampf(largeur / HAUTEUR_FORME, EPAISSEUR_MIN, EPAISSEUR_MAX)
	PoseEffets.poser(effet)
	return true


## Le recul d'un ennemi repoussé depuis `ou` (pixels) : les chevrons partent vers l'extérieur,
## à l'opposé de la tour (à droite quand l'ennemi est sur la tour).
func recul(ou: Vector2, couleur: Color) -> bool:
	var effet: Dictionary = _effets.creer("recul", "recul", DUREE_RECUL, couleur)
	if effet.is_empty():
		return false
	var sens: Vector2 = ou.normalized() if ou.length() > 0.001 else Vector2.RIGHT
	effet["depart"] = ou
	effet["arrivee"] = ou + sens * DISTANCE_RECUL
	effet["taille"] = TAILLE_RECUL
	PoseEffets.poser(effet)
	return true
