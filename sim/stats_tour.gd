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

# --- Lot 9 : une valeur neutre par stat d'amélioration, de même nom que la stat ---------------

## Durée d'une tranche de croissance (`partie.json` `ameliorations.croissance_pas_s`), posée par
## `Inventaire.stats()`.
var pas_croissance_s: float = 30.0
## Classe (`onde`, `portee_courte`, `portee_longue`, `commune`) → bonus de dégâts.
var degats_classe: Dictionary = {}
## État (`poison`, `brulure`) → bonus de dégâts ; état → bonus de durée ; état → bonus de dégâts
## contre une cible dans cet état.
var etat_degats: Dictionary = {}
var etat_duree: Dictionary = {}
var degats_contre_etat: Dictionary = {}
var epines_degats: float = 0.0
## Ratio par tranche de `pas_croissance_s`, borné par `epines_croissantes_max`.
var epines_croissantes: float = 0.0
var epines_croissantes_max: float = 0.0
var epines_premier_coup: float = 0.0
var epines_soin: float = 0.0
var epines_reduction: float = 0.0
## Statut → valeur appliquée par les épines ; statut → valeur appliquée par la riposte.
var epines_statut: Dictionary = {}
var riposte_statut: Dictionary = {}
var pv_max_mult: float = 1.0
var soin_pv_manquants: float = 0.0
var degats_par_pv_max: float = 0.0
var resurrection: int = 0
var regen_croissante: float = 0.0
var regen_croissante_max: float = 0.0
var armure_croissante: float = 0.0
var armure_croissante_max: float = 0.0
## `tous_les` : plus petit intervalle (s) ; `ratio` : somme.
var soin_periodique: Dictionary = {"tous_les": 0.0, "ratio": 0.0}
var mana_max_mult: float = 1.0
var mana_rupture_etourdit: Dictionary = {"rayon": 0.0, "duree": 0.0}
var degats_tant_que_mana: float = 0.0
var reduction_tant_que_mana: float = 0.0
## `pv` : plus petit seuil ; `or` : somme.
var revenu_contre_pv: Dictionary = {"pv": 0.0, "or": 0}
## Plus haute rareté copiable (`Types.Rarete`), -1 : aucune.
var copie_prochaine_offre: int = -1
var aura_mixte: Dictionary = {"rayon": 0.0, "poison": 0.0, "regen": 0.0}


## Multiplicateur des dégâts d'épines au temps `temps_s` de la partie :
## `1 + epines_degats + epines_croissantes × tranches écoulées`, la part croissante bornée.
func facteur_epines(temps_s: float) -> float:
	var tranches := floorf(maxf(temps_s, 0.0) / maxf(pas_croissance_s, 0.001))
	var croissance := minf(epines_croissantes * tranches, epines_croissantes_max)
	return 1.0 + epines_degats + croissance
