class_name ArmeEquipee
extends RefCounted
## Une arme montée sur la tour : sa définition (celle de `Donnees.armes`) et l'état qui survit
## d'un pas à l'autre (recharge, mines posées, ondes en route, minuteur d'aura).

var id: String
var def: Dictionary
## Secondes avant le prochain tir ; 0 = prête. Reste à 0 tant qu'aucune cible n'est à portée.
var recharge_restante: float = 0.0
## Secondes avant la prochaine frappe de l'aura ; 0 = prête.
var aura_restante: float = 0.0
## Positions des mines et pièges posés (le rayon vient de la définition).
var mines: PackedVector2Array = PackedVector2Array()
## Ondes en route : {rayon: float, deja_touches: PackedInt32Array (identifiants, triés),
## degats: float (critique déjà tiré au lancement)}.
var ondes: Array[Dictionary] = []
## Angle (degrés, dans [0 ; 360[) où le prochain tir tournant lance sa première branche : propre à
## cette arme, départ 0, avance de `pas_deg` à chaque tir.
var phase_deg: float = 0.0


func _init(definition: Dictionary) -> void:
	def = definition
	id = String(definition["id"])


## 0 = prête, 1 = vient de tirer ; tient compte de la cadence.
func recharge_ratio(stats: StatsTour) -> float:
	var duree := recharge_effective(stats)
	if not duree > 0.0:
		return 0.0
	return clampf(recharge_restante / duree, 0.0, 1.0)


func recharge_effective(stats: StatsTour) -> float:
	return float(def["recharge"]) / (1.0 + maxf(stats.cadence, 0.0))
