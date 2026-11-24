class_name Equilibrage
extends RefCounted
## Estimations de puissance d'une arme à partir de son seul dictionnaire de données, pour
## comparer les armes entre elles. Ce n'est pas la simulation : un ordre de grandeur.

## Planchers qui évitent une division par zéro sur une donnée aberrante.
const RECHARGE_MIN := 0.01
const PRIX_MIN := 1


static func tirs_par_seconde(arme: Dictionary) -> float:
	var recharge: float = arme.get("recharge", 1.0)
	return 1.0 / maxf(recharge, RECHARGE_MIN)


static func cibles_estimees(arme: Dictionary) -> float:
	var effets: Array = arme.get("effets", [])
	if effets.is_empty():
		return 1.0
	var meilleur := 0.0
	for effet: Dictionary in effets:
		meilleur = maxf(meilleur, _cibles_effet(effet))
	return meilleur


static func dps_estime(arme: Dictionary) -> float:
	var degats: float = arme.get("degats", 0.0)
	return degats * tirs_par_seconde(arme) * cibles_estimees(arme)


static func rendement(arme: Dictionary) -> float:
	var prix: int = arme.get("prix", PRIX_MIN)
	return dps_estime(arme) / float(maxi(prix, PRIX_MIN))


static func _cibles_effet(effet: Dictionary) -> float:
	var kind: String = effet.get("kind", "cible_unique")
	match kind:
		"zone", "aura":
			return 3.0
		"rebond":
			var cibles: float = effet.get("cibles", 4)
			return cibles * 0.6
		"onde":
			return 4.0
		"barrage":
			var projectiles: float = effet.get("projectiles", 2)
			return projectiles * 0.5
		"mine", "piege":
			return 2.0
		_:
			return 1.0
