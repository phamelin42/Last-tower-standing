class_name StatsTour
extends RefCounted
## Agrégat des améliorations d'une tour. Chaque champ est à sa valeur neutre par défaut :
## un multiplicateur à 1.0, un bonus additif ou un compteur à 0.

## Multiplicateur final par `Types.TypeDegats` (1.0 = neutre).
var degats_type: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0]
var degats_global: float = 1.0
var pv_max_bonus: float = 0.0
## Somme des améliorations « mana_max » et « mana_regen » (points par seconde).
var mana_max_bonus: float = 0.0
var mana_regen: float = 0.0
var regen: float = 0.0
var armure: float = 0.0
var esquive: float = 0.0
var epines: float = 0.0
var critique_chance: float = 0.0
var cadence: float = 0.0
var tirs_multiples: int = 0
var eclaboussure: float = 0.0
var focalisation: float = 0.0
var vol_de_vie_coup: float = 0.0
var vol_de_vie_mort: float = 0.0
var revenu_fixe: int = 0
var revenu_croissant: float = 0.0
var revenu_mult: float = 1.0
var prime_mult: float = 1.0
var bonus_elim_tous_les: int = 0
var bonus_elim_or: int = 0
var relances_gratuites: int = 0
var marche_noir: int = 0
