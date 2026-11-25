class_name SimulationEquilibrage
extends RefCounted
## Une partie complète d'un joueur seul, menée par une stratégie de `StrategiesJoueur`, à pleine
## vitesse et sans rendu. Sert à l'outil `tools/equilibrage.gd` et au test de garde.

## Une seconde de jeu entre deux décisions de la stratégie.
const PAS_S := 1.0
## Garde-fou : une partie qui ne se termine pas (boss jamais vaincu) s'arrête.
const DUREE_MAX_S := 4000.0
const JOUEUR := 1


## `manche_arret` > 0 : la partie s’arrête dès cette manche atteinte (garde rapide).
## Résultat : {manche, victoire, duree_s, degats_par_manche, famille_par_manche, achats,
## eliminations}.
static func jouer(d: Donnees, graine: int, strategie: String, manche_arret: int = 0) -> Dictionary:
	var p := Partie.new(d, AidesPartie.config(graine))
	p.ajouter_joueur(JOUEUR, "Robot")
	p.demarrer()
	var degats_par_manche := {}
	var famille_par_manche := {}
	var achats := {}
	var manche_max := 0
	var victoire := false
	var temps := 0.0
	var derniere_manche := -1
	var pv_avant := 0.0
	var eliminations := 0
	while temps < DUREE_MAX_S and not p.est_terminee():
		var v := p.vue_arene(JOUEUR, JOUEUR)
		if v == null:
			break
		var fin_de_manche := v.temps_restant <= PAS_S * 2.0 and v.phase == Types.Phase.MANCHE
		for ach: String in StrategiesJoueur.jouer(strategie, p, d, JOUEUR, fin_de_manche):
			achats[ach] = int(achats.get(ach, 0)) + 1
		manche_max = maxi(manche_max, v.manche_max)
		eliminations = v.eliminations
		if v.manche != derniere_manche:
			derniere_manche = v.manche
			pv_avant = v.tour_pv
		if v.manche >= 1 and v.tour_pv < pv_avant:
			var deja: float = float(degats_par_manche.get(v.manche, 0.0))
			degats_par_manche[v.manche] = deja + pv_avant - v.tour_pv
		pv_avant = v.tour_pv
		famille_par_manche[v.manche + 1] = v.prochaine_famille
		if manche_arret > 0 and manche_max >= manche_arret:
			break
		if v.phase == Types.Phase.VICTOIRE:
			victoire = true
			break
		p.avancer(PAS_S)
		temps += PAS_S
	var fin := p.vue_globale()
	for entree: Dictionary in fin.joueurs:
		manche_max = maxi(manche_max, int(entree["manche"]))
		victoire = victoire or bool(entree["victorieux"])
	return {
		"manche": manche_max,
		"victoire": victoire,
		"duree_s": temps,
		"degats_par_manche": degats_par_manche,
		"famille_par_manche": famille_par_manche,
		"achats": achats,
		"eliminations": eliminations,
	}
