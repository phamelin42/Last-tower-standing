class_name Equilibrage
extends RefCounted
## Estimations de puissance d'une arme à partir de son seul dictionnaire de données, pour
## comparer les armes entre elles. Ce n'est pas la simulation : un ordre de grandeur.

## Planchers qui évitent une division par zéro sur une donnée aberrante.
const RECHARGE_MIN := 0.01
const PRIX_MIN := 1
## Valeurs de référence des armes « selon » : PV maximum de la tour, exemplaires équipés et
## améliorations possédées qu'une partie type a à mi-course (comme la mana de référence du lot 8).
const REFERENCE_PV_MAX_TOUR := 1000.0
const REFERENCE_EXEMPLAIRES := 3
const REFERENCE_AMELIORATIONS := 3
## Plafond des bonus « selon », en multiple des dégâts de base (`partie.json` `armes`).
const BONUS_SELON_STAT_MAX := 4.0


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


## `mana_max` : la mana maximale de la tour, dont les armes de mana (`degats_par_mana_max`) tirent
## des dégâts en plus.
static func dps_estime(arme: Dictionary, mana_max: float = 0.0) -> float:
	var base: float = arme.get("degats", 0.0)
	var degats := base + float(arme.get("degats_par_mana_max", 0.0)) * maxf(mana_max, 0.0)
	degats += minf(_bonus_selon(arme, base), BONUS_SELON_STAT_MAX * base)
	return degats * tirs_par_seconde(arme) * cibles_estimees(arme)


static func rendement(arme: Dictionary, mana_max: float = 0.0) -> float:
	var prix: int = arme.get("prix", PRIX_MIN)
	return dps_estime(arme, mana_max) / float(maxi(prix, PRIX_MIN))


## Les trois bonus « selon » aux valeurs de référence ; zéro pour une arme qui n'en a pas.
static func _bonus_selon(arme: Dictionary, base: float) -> float:
	var selon := maxf(float(arme.get("degats_par_pv_max", 0.0)), 0.0) * REFERENCE_PV_MAX_TOUR
	selon += (
		maxf(float(arme.get("degats_par_exemplaire", 0.0)), 0.0)
		* float(REFERENCE_EXEMPLAIRES - 1)
		* base
	)
	var par_amelioration: Dictionary = arme.get("degats_par_amelioration", {})
	if not par_amelioration.is_empty():
		var ratio := maxf(float(par_amelioration.get("ratio", 0.0)), 0.0)
		selon += ratio * float(REFERENCE_AMELIORATIONS) * base
	return selon


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
