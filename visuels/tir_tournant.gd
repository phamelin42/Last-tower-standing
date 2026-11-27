class_name TirTournant
extends RefCounted
## Le rendu d'un rayon de tir tournant (D22 et lot 9) : le trait de la marque, toujours ; une arme
## à élément y ajoute son projectile, qui file jusqu'au bout du rayon, et un impact décoratif à
## l'arrivée, à la largeur du rayon. La simulation n'émet aucun impact à cet endroit : cet impact
## ne dit donc pas « touché » et ne fait réagir aucun ennemi (`Effets` n'émet pas `impact_visible`
## pour le genre `tournant`). Il se sert du pool d'`Effets`, dont il partage le plafond.

const GENRE: String = "tournant"

var _effets: Effets = null
var _rayons: RayonsReculs = null


func _init(effets: Effets, rayons: RayonsReculs) -> void:
	_effets = effets
	_rayons = rayons


## Le rayon `de` → `vers` (unités de jeu), `largeur` unités de jeu de large. Vrai si un effet a
## été créé.
func rayon(
	type_degats: int, de: Vector2, vers: Vector2, largeur: float, signature: Dictionary, arme: int
) -> bool:
	var cree: bool = _rayons.rayon(
		Apparence.vers_pixels(de),
		Apparence.vers_pixels(vers),
		largeur,
		Effets.COULEURS[type_degats]
	)
	if _effets.element_de(arme) == "":
		return cree
	cree = _effets.tirer_arme(type_degats, GENRE, de, vers, signature, arme) or cree
	return _effets.impacter_arme(type_degats, GENRE, de, vers, largeur, "", signature, arme) or cree
