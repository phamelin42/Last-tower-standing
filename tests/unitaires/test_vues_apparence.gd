extends CasDeTest
## Les statistiques d'apparence de la tour dans `VueArene` : épines, esquive, régénération et
## vol de vie s'ajoutent aux PV, à l'armure et à la mana déjà transmis. Ce sont les valeurs
## effectives de `StatsTour`. Les tests bouclent sur toutes les améliorations des données.

const GRAINE := 20261126
const COPIES := 5
## Champ de la vue que porte chaque statistique d'amélioration directe.
const CHAMP_DE_STAT: Dictionary = {
	"pv_max": "tour_pv_max",
	"mana_max": "tour_mana_max",
	"armure": "tour_armure",
	"epines": "tour_epines",
	"esquive": "tour_esquive",
	"regen": "tour_regen",
	"vol_de_vie_coup": "tour_vol_de_vie",
	"vol_de_vie_mort": "tour_vol_de_vie",
}
## Statistique d'apparence (clé de `data/apparence_tour.json`) → champ de la vue.
const CHAMP_DE_APPARENCE: Dictionary = {
	"epines": "tour_epines",
	"pv_max": "tour_pv_max",
	"mana": "tour_mana_max",
	"armure": "tour_armure",
	"esquive": "tour_esquive",
	"regen": "tour_regen",
	"vol_de_vie": "tour_vol_de_vie",
}
const CHAMPS_APPARENCE: Array[String] = [
	"tour_epines",
	"tour_esquive",
	"tour_regen",
	"tour_vol_de_vie",
	"tour_pv_max",
	"tour_mana_max",
	"tour_armure",
]

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _vue(a: Arene) -> VueArene:
	return a.vue(Types.Phase.MANCHE, 10.0, -1, false)


func _avec(id: String, n: int) -> VueArene:
	var a := Arene.new(d, GRAINE)
	a.inventaire.ameliorations[id] = n
	a.synchroniser()
	return _vue(a)


func _champs_directs(id: String) -> Array[String]:
	var champs: Array[String] = []
	var amelio: Dictionary = d.ameliorations[id]
	for e: Dictionary in amelio["effets"] as Array:
		var champ: String = CHAMP_DE_STAT.get(e["stat"], "")
		if champ != "" and not champs.has(champ):
			champs.append(champ)
	return champs


func test_la_vue_porte_chaque_statistique_d_apparence() -> void:
	var neutre := _vue(Arene.new(d, GRAINE))
	var vus := 0
	for id: String in d.ameliorations:
		var attendus := _champs_directs(id)
		if attendus.is_empty():
			continue
		vus += 1
		var vue := _avec(id, 1)
		for champ: String in CHAMPS_APPARENCE:
			var avant: float = neutre.get(champ)
			var apres: float = vue.get(champ)
			if attendus.has(champ):
				verifier(apres > avant, "%s : %s augmente" % [id, champ])
			else:
				verifier_egal(apres, avant, "%s : %s inchangé" % [id, champ])
	verifier(vus >= 7, "au moins une amélioration par statistique (%d)" % vus)


func test_une_tour_sans_amelioration_a_des_statistiques_d_apparence_neutres() -> void:
	var vue := _vue(Arene.new(d, GRAINE))
	for champ: String in ["tour_epines", "tour_esquive", "tour_regen", "tour_vol_de_vie"]:
		verifier_egal(float(vue.get(champ)), 0.0, champ)
	verifier_egal(vue.tour_armure, 0.0)
	verifier_egal(vue.tour_mana_max, 0.0)


func test_la_simulation_ne_depend_pas_de_l_apparence() -> void:
	var neutre := Arene.new(d, GRAINE)
	var equipee := Arene.new(d, GRAINE)
	equipee.inventaire.ameliorations["herisson_de_fer"] = 1
	equipee.synchroniser()
	var a := _vue(neutre).to_dict()
	var b := _vue(equipee).to_dict()
	for champ: String in CHAMPS_APPARENCE:
		a.erase(champ)
		b.erase(champ)
	a.erase("ameliorations")
	b.erase("ameliorations")
	verifier_egal(a, b, "hors apparence, deux arènes de même graine ont la même vue")


func test_chaque_palier_est_atteignable() -> void:
	var stats: Dictionary = d.apparence_tour["stats"]
	for nom: String in stats:
		var champ: String = CHAMP_DE_APPARENCE[nom]
		var a := Arene.new(d, GRAINE)
		var achetees := 0
		for id: String in d.ameliorations:
			if _champs_directs(id).has(champ):
				a.inventaire.ameliorations[id] = COPIES
				achetees += 1
		verifier(achetees > 0, "%s : au moins une amélioration" % nom)
		a.synchroniser()
		var seuils: Array = stats[nom]
		var valeur: float = _vue(a).get(champ)
		verifier(
			valeur >= float(seuils[2]), "%s : %s atteint le 3e seuil %s" % [nom, valeur, seuils[2]]
		)


func test_les_champs_d_apparence_font_l_aller_retour_du_dictionnaire() -> void:
	var vue := VueArene.new()
	vue.tour_epines = 1.5
	vue.tour_esquive = 0.25
	vue.tour_regen = 4.0
	vue.tour_vol_de_vie = 8.02
	var relue := VueArene.from_dict(vue.to_dict())
	verifier_non_nul(relue)
	for champ: String in ["tour_epines", "tour_esquive", "tour_regen", "tour_vol_de_vie"]:
		verifier_egal(float(relue.get(champ)), float(vue.get(champ)), champ)
		var d_vue := vue.to_dict()
		d_vue.erase(champ)
		verifier_nul(VueArene.from_dict(d_vue), "%s manquant" % champ)
		var d_entier := vue.to_dict()
		d_entier[champ] = 1
		verifier_nul(VueArene.from_dict(d_entier), "%s entier" % champ)
