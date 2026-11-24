class_name Combat
extends RefCounted
## Formules de combat pures (spec §5.4). Aucune ne lit d'état : une entrée absurde (négative,
## hors bornes) donne la valeur neutre, jamais une exception ni une division par zéro.


## Multiplicateur de dégâts d'un type contre une armure ; 1.0 si le couple est hors de la table.
static func efficacite(table: Array, type_degats: int, armure: int) -> float:
	if type_degats < 0 or type_degats >= table.size():
		return 1.0
	var ligne: Array = table[type_degats]
	if armure < 0 or armure >= ligne.size():
		return 1.0
	return float(ligne[armure])


## 0,05·a / (1 + 0,05·a) ; une armure négative ne réduit rien.
static func reduction_armure(armure: float) -> float:
	if not armure > 0.0:
		return 0.0
	var brut := 0.05 * armure
	return brut / (1.0 + brut)


static func degats_subis(degats: float, armure: float) -> float:
	return degats * (1.0 - reduction_armure(armure))


## Chance arrondie au palier inférieur, plafonnée à 1,0. La petite marge absorbe l'erreur
## flottante : 0,15 / 0,05 vaut 2,9999999999999996.
static func chance_critique_effective(chance: float, palier: float) -> float:
	if not chance > 0.0:
		return 0.0
	if not palier > 0.0:
		return minf(chance, 1.0)
	var paliers := floorf(chance / palier + 1e-9)
	return minf(paliers * palier, 1.0)


## `chance` est la chance brute : seul l'excédent au-delà de 100 % augmente la puissance.
static func puissance_critique(chance: float, base: float, coef_exces: float) -> float:
	return base + coef_exces * maxf(0.0, chance - 1.0)


## points / (points + k) : toujours < 1, chaque point rapporte moins que le précédent.
static func chance_esquive(points: float, k: float) -> float:
	if not points > 0.0:
		return 0.0
	return points / (points + maxf(k, 0.0))


static func duree_etourdissement(base: float, resistance: float) -> float:
	return maxf(base, 0.0) * maxf(resistance, 0.0)


static func ralentissement(cumuls: int, par_cumul: float, plafond: float) -> float:
	if cumuls <= 0:
		return 0.0
	return minf(cumuls * par_cumul, plafond)


static func duree_gel(base: float, resistance: float, gel_max: float) -> float:
	return minf(maxf(base, 0.0) * maxf(resistance, 0.0), gel_max)


## Dégâts d'un pas de `dt` secondes pour un total étalé sur `duree`.
static func repartir_dot(total: float, duree: float, dt: float) -> float:
	if not duree > 0.0:
		return 0.0
	return total * dt / duree


static func soin_vol_de_vie(degats: float, ratio: float) -> float:
	return maxf(degats, 0.0) * maxf(ratio, 0.0)
