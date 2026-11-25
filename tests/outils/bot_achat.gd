class_name BotAchat
extends RefCounted
## Bot d'achat simple, pour les tests : il achète d'abord des armes (la moins chère qu'il peut
## payer), puis, une fois `armes_visees` montées, des améliorations ; il relance la boutique tant
## que l'or le permet. Il n'existe que dans les tests : la simulation n'a aucun joueur automatique.

const TOURS_MAX := 40


static func jouer(p: Partie, id: int, armes_visees: int = 4) -> void:
	for _tour: int in TOURS_MAX:
		var v := p.vue_arene(id, id)
		if v == null:
			return
		var index := _meilleur_achat(v, v.armes.size() < armes_visees)
		if index >= 0:
			if p.intention_acheter(id, index) == Types.Resultat.OK:
				continue
			return
		var gratuites := v.relances_gratuites > 0
		if v.armes.size() < armes_visees and (gratuites or v.argent >= v.cout_relance):
			if p.intention_relancer(id) == Types.Resultat.OK:
				continue
		return


## Index de l'offre à acheter, ou −1. Armes seules tant qu'il en manque ; sinon tout.
static func _meilleur_achat(v: VueArene, armes_seules: bool) -> int:
	var choix := -1
	var prix_choix := 0
	for i: int in v.offres.size():
		var offre: Dictionary = v.offres[i]
		var prix := int(offre["prix"])
		if bool(offre["vendu"]) or prix > v.argent:
			continue
		if armes_seules and int(offre["genre"]) != Types.Genre.ARME:
			continue
		if choix < 0 or prix < prix_choix:
			choix = i
			prix_choix = prix
	return choix
