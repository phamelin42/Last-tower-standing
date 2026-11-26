class_name StatsTour
extends RefCounted
## Agrégat des améliorations d'une tour. Chaque champ est à sa valeur neutre par défaut :
## un multiplicateur à 1.0, un bonus additif ou un compteur à 0.

## Portée d'une arme « à courte portée » (au plus) et « à longue portée » (au moins).
const PORTEE_COURTE_MAX := 750.0
const PORTEE_LONGUE_MIN := 1000.0
## État que lit `degats_contre_etat` → bit de `Ennemis.statuts`.
const BITS_ETATS: Dictionary = {
	"etourdi": Types.STATUT_ETOURDI,
	"empoisonne": Types.STATUT_EMPOISONNE,
	"ralenti": Types.STATUT_RALENTI,
}

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
## Catégorie → somme des bonus fixes de dégâts, par type de dégâts puis pour le global : ce que
## `degats_type` et `degats_global` multiplient entre catégories, gardé ouvert pour que la
## croissance et les armes communes s'ajoutent à l'intérieur de leur catégorie.
var sommes_type: Array[Dictionary] = [{}, {}, {}, {}, {}]
var sommes_global: Dictionary = {}
## Les bonus de dégâts qui dépendent de la partie : `{type (-1 : global), categorie, croissance,
## croissance_max, par_arme_commune, n}` ; `n` est le nombre d'exemplaires achetés.
var degats_dynamiques: Array[Dictionary] = []
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


## Multiplicateur de dégâts du type `type_degats` à l'instant `temps_s` de la partie, avec
## `communes_du_type` armes communes de ce type équipées : Π sur les catégories de (1 + somme).
## La croissance ajoute `croissance` par tranche entière de `pas_croissance_s` écoulée, chaque
## exemplaire borné à `croissance_max` ; le temps est celui de la partie, jamais l'horloge.
func facteur_degats_type(type_degats: int, temps_s: float, communes_du_type: int) -> float:
	if type_degats < 0 or type_degats >= degats_type.size():
		return 1.0
	if not _a_des_dynamiques(type_degats):
		return degats_type[type_degats]
	return _produit_dynamique(sommes_type[type_degats], type_degats, temps_s, communes_du_type)


## Comme `facteur_degats_type`, pour le bonus global ; `communes` compte celles de tous les types.
func facteur_degats_global(temps_s: float, communes: int) -> float:
	if not _a_des_dynamiques(-1):
		return degats_global
	return _produit_dynamique(sommes_global, -1, temps_s, communes)


## Vrai si au moins un bonus de dégâts suit la partie (temps ou armes communes) : sans cela le
## tir n'a pas à compter ses armes communes.
func a_des_degats_dynamiques() -> bool:
	return not degats_dynamiques.is_empty()


func _a_des_dynamiques(type_degats: int) -> bool:
	for entree: Dictionary in degats_dynamiques:
		if int(entree["type"]) == type_degats:
			return true
	return false


func _produit_dynamique(
	fixes: Dictionary, type_degats: int, temps_s: float, communes: int
) -> float:
	var tranches := floorf(maxf(temps_s, 0.0) / maxf(pas_croissance_s, 0.001))
	var cumul: Dictionary = fixes.duplicate()
	for entree: Dictionary in degats_dynamiques:
		if int(entree["type"]) != type_degats:
			continue
		var categorie: String = entree["categorie"]
		var par_exemplaire := minf(
			float(entree["croissance"]) * tranches, float(entree["croissance_max"])
		)
		par_exemplaire += float(entree["par_arme_commune"]) * float(maxi(communes, 0))
		cumul[categorie] = float(cumul.get(categorie, 0.0)) + par_exemplaire * float(entree["n"])
	var produit := 1.0
	for categorie: String in cumul:
		produit *= 1.0 + float(cumul[categorie])
	return produit


## Multiplicateur de dégâts d'une arme selon ses classes : Π de (1 + bonus) sur les classes dont
## elle est (`onde` : un effet onde ; `portee_courte` : portée ≤ 750 ; `portee_longue` : portée
## ≥ 1 000 ; `commune` : rareté commune). Une arme de plusieurs classes les cumule.
func facteur_classe(arme: Dictionary) -> float:
	if degats_classe.is_empty():
		return 1.0
	var facteur := 1.0
	var portee := float(arme.get("portee", 0.0))
	var est: Dictionary = {
		"portee_courte": portee <= PORTEE_COURTE_MAX,
		"portee_longue": portee >= PORTEE_LONGUE_MIN,
		"commune": int(arme.get("rarete", -1)) == Types.Rarete.COMMUNE,
		"onde": false,
	}
	for effet: Dictionary in arme.get("effets", []):
		if effet.get("kind", "") == "onde":
			est["onde"] = true
	for classe: String in degats_classe:
		if est.get(classe, false):
			facteur *= 1.0 + float(degats_classe[classe])
	return facteur


## Multiplicateur de dégâts contre un ennemi dont `Ennemis.statuts` vaut `bits` : Π de (1 + bonus)
## sur les états qu'il a (`etourdi`, `empoisonne`, `ralenti`).
func facteur_contre_etat(bits: int) -> float:
	if degats_contre_etat.is_empty():
		return 1.0
	var facteur := 1.0
	for etat: String in degats_contre_etat:
		if bits & int(BITS_ETATS.get(etat, 0)) != 0:
			facteur *= 1.0 + float(degats_contre_etat[etat])
	return facteur
