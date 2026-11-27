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
## Vrai si l'arme porte une aura (sa frappe a son propre minuteur).
var a_aura: bool = false
## Niveau de l'arme (D23), 1 au premier achat ; posé par `definir_niveau`.
var niveau: int = 1
## Cadence gagnée par les niveaux au-dessus du premier, qui s'ajoute à celle des améliorations.
var cadence_niveau: float = 0.0
## Plafond de la cadence totale de l'arme (améliorations et niveaux) : `partie.json`
## `niveaux.cadence_max`. Infini tant qu'on ne l'a pas posé (les tests de tir).
var cadence_max: float = INF


func _init(definition: Dictionary) -> void:
	def = definition
	id = String(definition["id"])
	for effet: Dictionary in definition["effets"]:
		if effet["kind"] == "aura":
			a_aura = true


## 0 = prête, 1 = vient de tirer ; tient compte de la cadence.
func recharge_ratio(stats: StatsTour) -> float:
	var duree := recharge_effective(stats)
	if not duree > 0.0:
		return 0.0
	return clampf(recharge_restante / duree, 0.0, 1.0)


## Pose le niveau et la cadence qu'il apporte : `gain_cadence` par niveau au-dessus du premier,
## bornée avec celle des améliorations par `plafond` (`cadence_max`).
func definir_niveau(nouveau_niveau: int, gain_cadence: float, plafond: float) -> void:
	niveau = maxi(nouveau_niveau, 1)
	cadence_niveau = maxf(gain_cadence, 0.0) * float(niveau - 1)
	cadence_max = plafond


## Cadence totale : celle des améliorations plus celle des niveaux, bornée par `cadence_max`.
func cadence_totale(stats: StatsTour) -> float:
	return minf(maxf(stats.cadence, 0.0) + cadence_niveau, cadence_max)


func recharge_effective(stats: StatsTour) -> float:
	return float(def["recharge"]) / (1.0 + cadence_totale(stats))
