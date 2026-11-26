class_name Economie
extends RefCounted
## Or d'une tour : départ, versements périodiques, primes et bonus d'éliminations.
## Les montants sont des entiers ; un gain est plafonné à `OR_MAX` pour qu'aucune somme
## ne déborde, même après des gains énormes.

## Plafond de l'or : 2^53, plus grand entier que les flottants représentent exactement.
const OR_MAX := 9007199254740992
## Tolérance sur le temps : 200 pas de 0,05 s n'accumulent pas exactement 10,0 s.
const EPSILON_TEMPS := 1e-9
## Au-delà, un seul appel ne verse plus : un dt absurde ne fige pas la simulation.
const PERIODES_MAX_PAR_APPEL := 100000

var argent: int = 0
## Pour le bilan de partie : or gagné (revenu, primes, bonus ; pas les ventes), dont les primes, et
## or dépensé (achats et relances).
var or_gagne_total: int = 0
var or_gagne_primes: int = 0
var or_depense: int = 0

var _donnees: Donnees
var _periode: float
var _temps_avant: float
var _eliminations: int = 0


func _init(donnees: Donnees) -> void:
	_donnees = donnees
	argent = int(donnees.economie["or_depart"])
	_periode = float(donnees.economie["revenu_periode_s"])
	_temps_avant = _periode


## Revenu d'une période : le revenu de base n'est pas multiplié, seule la part achetée l'est.
func revenu_par_periode(manche: int, stats: StatsTour, temps_ecoule: float) -> int:
	var table: Array = _donnees.economie["revenu_base"]
	var base := _donnees.palier(table, manche, "valeur")
	var achete := (
		(float(stats.revenu_fixe) + stats.revenu_croissant * temps_ecoule / 60.0)
		* stats.revenu_mult
	)
	return _entier_borne(base + achete)


## Verse une période pour chaque période de 10 s écoulée. Renvoie l'or effectivement reçu.
func avancer(dt: float, manche: int, stats: StatsTour, temps_ecoule: float) -> int:
	if not is_finite(dt) or dt <= 0.0:
		return 0
	var restant := _temps_avant - dt
	if restant > EPSILON_TEMPS:
		_temps_avant = restant
		return 0
	var periodes := mini(floori(-restant / _periode + EPSILON_TEMPS) + 1, PERIODES_MAX_PAR_APPEL)
	_temps_avant = restant + periodes * _periode
	var par_periode := revenu_par_periode(manche, stats, temps_ecoule)
	var avant := argent
	gagner(roundi(minf(float(par_periode) * periodes, float(OR_MAX))))
	or_gagne_total += argent - avant
	return argent - avant


func temps_avant_versement() -> float:
	return _temps_avant


## Prime d'un ennemi : valeur × palier de `prime_mult` × multiplicateur des objets, arrondie.
func prime(famille_prime: int, manche: int, stats: StatsTour) -> int:
	var table: Array = _donnees.economie["prime_mult"]
	var palier_mult := _donnees.palier(table, manche, "valeur")
	var valeur := float(famille_prime) * palier_mult * stats.prime_mult
	return roundi(clampf(valeur, 0.0, float(OR_MAX)))


## Compte l'élimination. Renvoie l'or du bonus « tous les n » (0 hors de ces éliminations).
func enregistrer_elimination(stats: StatsTour) -> int:
	_eliminations += 1
	var n := stats.bonus_elim_tous_les
	if n <= 0 or stats.bonus_elim_or <= 0:
		return 0
	if _eliminations % n == 0:
		return stats.bonus_elim_or
	return 0


func peut_payer(montant: int) -> bool:
	return montant >= 0 and montant <= argent


func payer(montant: int) -> bool:
	if not peut_payer(montant):
		return false
	argent -= montant
	or_depense += montant
	return true


## Or d'une prime ou d'un bonus d'élimination : comme `gagner`, et compté dans le bilan.
func gagner_prime(montant: int) -> void:
	var avant := argent
	gagner(montant)
	or_gagne_primes += argent - avant
	or_gagne_total += argent - avant


## Ignore les montants nuls ou négatifs ; le total est plafonné à `OR_MAX`.
func gagner(montant: int) -> void:
	if montant <= 0:
		return
	argent = mini(argent + mini(montant, OR_MAX), OR_MAX)


static func _entier_borne(valeur: float) -> int:
	if is_nan(valeur):
		return 0
	return roundi(clampf(valeur, 0.0, float(OR_MAX)))
