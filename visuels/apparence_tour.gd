class_name ApparenceTour
extends RefCounted
## Logique pure de l'apparence de la tour (D19) : quel palier (0 à 3) montre chaque statistique,
## de combien la tour grandit et à quel point la bulle de mana est pleine. Ne dessine rien et ne
## touche pas à `sim/` : elle lit une `VueArene` et les seuils de `data/apparence_tour.json`.

## Les sept statistiques qui se voient (l'ordre des données), puis celles qui ont une image : la
## tour qui grandit (`pv_max`) n'a qu'un facteur.
const STATS: Array[String] = DonneesApparence.STATS
const SUPERPOSITIONS: Array[String] = DonneesApparence.SUPERPOSITIONS
const PALIERS_MAX := 3
## Agrandissement maximal, même si les données en demandaient plus (A3).
const ECHELLE_MAX := 1.25
## Champ de la vue qui porte chaque statistique.
const CHAMPS: Dictionary = {
	"epines": "tour_epines",
	"pv_max": "tour_pv_max",
	"mana": "tour_mana_max",
	"armure": "tour_armure",
	"esquive": "tour_esquive",
	"regen": "tour_regen",
	"vol_de_vie": "tour_vol_de_vie",
}


## `{statistique: 0 à 3}` : le nombre de seuils atteints. Une valeur non finie ou négative donne 0.
static func paliers(vue: VueArene, donnees: Donnees) -> Dictionary:
	var sortie: Dictionary = {}
	var seuils_par_stat: Dictionary = donnees.apparence_tour.get("stats", {})
	for stat: String in seuils_par_stat:
		var valeur: float = vue.get(CHAMPS[stat])
		var seuils: Array = seuils_par_stat[stat]
		var palier := 0
		if is_finite(valeur) and valeur > 0.0:
			for seuil: float in seuils:
				if valeur >= seuil:
					palier += 1
		sortie[stat] = mini(palier, PALIERS_MAX)
	return sortie


## Facteur d'agrandissement du sprite, de 1,0 (neutre) à 1,25. Seul le palier de `pv_max` compte.
static func echelle(paliers_tour: Dictionary, donnees: Donnees) -> float:
	var palier := clampi(int(paliers_tour.get("pv_max", 0)), 0, PALIERS_MAX)
	if palier == 0:
		return 1.0
	var tailles: Array = donnees.apparence_tour.get("agrandissement", [])
	if tailles.size() < palier:
		return 1.0
	return 1.0 + minf(float(tailles[palier - 1]), ECHELLE_MAX - 1.0)


## Part pleine de la bulle de mana : mana / mana maximale, de 0 à 1 ; 0 sans mana maximale ou si
## une valeur n'est pas finie.
static func remplissage_mana(vue: VueArene) -> float:
	if not is_finite(vue.tour_mana) or not is_finite(vue.tour_mana_max):
		return 0.0
	if vue.tour_mana_max <= 0.0:
		return 0.0
	return clampf(vue.tour_mana / vue.tour_mana_max, 0.0, 1.0)
