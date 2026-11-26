class_name MesurePas
extends RefCounted
## Coût d'un pas de simulation, robuste à la charge de la machine (S16). Une machine occupée
## (tests des autres sessions, CI sur peu de cœurs) ralentit presque tous les pas d'un même
## processus, mais jamais tous : le 10e centile des mesures donne le coût du code, alors que la
## médiane ou la moyenne suivent la charge. Une vraie régression ralentit chaque mesure, le
## 10e centile compris : le budget garde son sens.


## Durée du 10e centile des `durees_us` (microsecondes), en ms par pas : chaque mesure couvre
## `pas_par_mesure` pas consécutifs. 0,0 sans mesure.
static func centile_bas_ms(durees_us: PackedInt32Array, pas_par_mesure: int = 1) -> float:
	if durees_us.is_empty() or pas_par_mesure < 1:
		return 0.0
	var triees := durees_us.duplicate()
	triees.sort()
	return float(triees[triees.size() / 10]) / 1000.0 / float(pas_par_mesure)
