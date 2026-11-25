class_name BotAchat
extends RefCounted
## Bot d'achat simple, pour les tests : il achète tout ce qu'il peut payer et relance la boutique
## tant que l'or le permet et qu'il a moins d'armes que `armes_visees`. Il n'existe que dans les
## tests : la simulation n'a aucun joueur automatique.

const TOURS_MAX := 40


static func jouer(p: Partie, id: int, armes_visees: int = 4) -> void:
	for _tour: int in TOURS_MAX:
		var v := p.vue_arene(id, id)
		if v == null:
			return
		var achete := false
		for i: int in v.offres.size():
			var offre: Dictionary = v.offres[i]
			if not bool(offre["vendu"]) and int(offre["prix"]) <= v.argent:
				if p.intention_acheter(id, i) == Types.Resultat.OK:
					achete = true
					break
		if achete:
			continue
		var gratuites := v.relances_gratuites > 0
		if v.armes.size() < armes_visees and (gratuites or v.argent >= v.cout_relance):
			if p.intention_relancer(id) == Types.Resultat.OK:
				continue
		return
