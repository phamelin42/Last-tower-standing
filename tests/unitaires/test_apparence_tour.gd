extends CasDeTest
## Logique pure de l'apparence de la tour (D19, T9.24) : paliers, agrandissement, remplissage de
## la bulle de mana, skin par défaut et ses ancrages (seuils de `data/apparence_tour.json`).

const CHAMP: Dictionary = {
	"epines": "tour_epines",
	"pv_max": "tour_pv_max",
	"mana": "tour_mana_max",
	"armure": "tour_armure",
	"esquive": "tour_esquive",
	"regen": "tour_regen",
	"vol_de_vie": "tour_vol_de_vie",
}

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _vue_neutre() -> VueArene:
	var v := VueArene.new()
	for stat: String in CHAMP:
		v.set(CHAMP[stat], 0.0)
	return v


func _paliers(vue: VueArene) -> Dictionary:
	return ApparenceTour.paliers(vue, d)


func test_les_paliers_suivent_les_seuils() -> void:
	var stats: Dictionary = d.apparence_tour["stats"]
	for stat: String in stats:
		var seuils: Array = stats[stat]
		for k: int in seuils.size():
			var s := float(seuils[k])
			var vue := _vue_neutre()
			vue.set(CHAMP[stat], s - 0.001)
			verifier_egal(_paliers(vue)[stat], k, "%s juste sous le seuil %d" % [stat, k + 1])
			vue.set(CHAMP[stat], s)
			verifier_egal(_paliers(vue)[stat], k + 1, "%s au seuil %d" % [stat, k + 1])
			vue.set(CHAMP[stat], s + 0.001)
			verifier_egal(_paliers(vue)[stat], k + 1, "%s au-dessus du seuil %d" % [stat, k + 1])
		var tout := _vue_neutre()
		tout.set(CHAMP[stat], 1.0e9)
		verifier_egal(_paliers(tout)[stat], 3, "%s : jamais plus de 3" % stat)
		var rien := _vue_neutre()
		rien.set(CHAMP[stat], float(seuils[0]) / 2.0)
		verifier_egal(_paliers(rien)[stat], 0, "%s : 0 sous le premier seuil" % stat)
	verifier_egal(_paliers(_vue_neutre()).size(), stats.size(), "une clé par statistique")


func test_un_champ_non_fini_ou_negatif_donne_le_palier_zero() -> void:
	for stat: String in CHAMP:
		for forge: float in [NAN, INF, -INF, -5.0]:
			var vue := _vue_neutre()
			vue.set(CHAMP[stat], forge)
			verifier_egal(_paliers(vue)[stat], 0, "%s %s" % [stat, forge])


func test_l_echelle_ne_depasse_jamais_1_25_et_croit_avec_le_palier_de_pv_max() -> void:
	verifier_egal(ApparenceTour.echelle({}, d), 1.0, "sans palier : neutre")
	verifier_egal(ApparenceTour.echelle({"pv_max": 0}, d), 1.0, "palier 0 : neutre")
	var precedente := 1.0
	for palier: int in range(1, 4):
		var e := ApparenceTour.echelle({"pv_max": palier}, d)
		verifier(e > precedente, "palier %d agrandit" % palier)
		verifier(e <= 1.25, "palier %d : au plus 1,25 (%s)" % [palier, e])
		precedente = e
	verifier_egal(ApparenceTour.echelle({"pv_max": 99}, d), precedente, "palier hors bornes")
	verifier_egal(ApparenceTour.echelle({"pv_max": -4}, d), 1.0, "palier négatif")
	var autres := {"epines": 3, "mana": 3, "armure": 3, "esquive": 3, "regen": 3, "vol_de_vie": 3}
	verifier_egal(ApparenceTour.echelle(autres, d), 1.0, "seul pv_max agrandit")


func test_le_remplissage_de_la_mana_suit_le_ratio_et_disparait_a_zero() -> void:
	var vue := VueArene.new()
	vue.tour_mana_max = 0.0
	vue.tour_mana = 10.0
	verifier_egal(ApparenceTour.remplissage_mana(vue), 0.0, "mana maximale 0")
	vue.tour_mana_max = 100.0
	vue.tour_mana = 0.0
	verifier_egal(ApparenceTour.remplissage_mana(vue), 0.0, "mana 0")
	vue.tour_mana = 50.0
	verifier_proche(ApparenceTour.remplissage_mana(vue), 0.5)
	vue.tour_mana = 100.0
	verifier_proche(ApparenceTour.remplissage_mana(vue), 1.0)
	vue.tour_mana = 400.0
	verifier_proche(ApparenceTour.remplissage_mana(vue), 1.0, 0.0001, "ratio borné à 1")
	for forge: float in [NAN, INF, -INF]:
		vue.tour_mana = forge
		verifier_egal(ApparenceTour.remplissage_mana(vue), 0.0, "mana %s" % forge)
		vue.tour_mana = 50.0
		vue.tour_mana_max = forge
		verifier_egal(ApparenceTour.remplissage_mana(vue), 0.0, "maximale %s" % forge)
		vue.tour_mana_max = 100.0


func test_le_skin_par_defaut_a_un_ancrage_pour_chaque_superposition() -> void:
	verifier(d.skins_tour.has("defaut"), "skin défaut")
	var skin: Dictionary = d.skins_tour["defaut"]
	verifier(FileAccess.file_exists(String(skin["sprite"])), "sprite de la tour")
	var ancrages: Dictionary = skin["ancrages"]
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		verifier(ancrages.has(stat), "ancrage de %s" % stat)
		var a: Dictionary = ancrages[stat]
		verifier(is_finite(float(a["x"])) and is_finite(float(a["y"])), "ancrage fini : %s" % stat)


func test_un_skin_sans_ancrage_pour_une_superposition_est_refuse() -> void:
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		var brut := AidesPartie.brut()
		var skins: Dictionary = brut["skins_tour.json"]
		var defaut: Dictionary = skins["defaut"]
		var ancrages: Dictionary = defaut["ancrages"]
		ancrages.erase(stat)
		verifier(not Donnees.valider(brut).is_empty(), "%s sans ancrage refusé" % stat)
	var mauvais := AidesPartie.brut()
	var s2: Dictionary = mauvais["skins_tour.json"]
	var d2: Dictionary = s2["defaut"]
	var a2: Dictionary = d2["ancrages"]
	a2["armure"] = {"x": NAN, "y": 0.0}
	verifier(not Donnees.valider(mauvais).is_empty(), "ancrage non fini refusé")
	var sans_sprite := AidesPartie.brut()
	var s3: Dictionary = sans_sprite["skins_tour.json"]
	var d3: Dictionary = s3["defaut"]
	d3.erase("sprite")
	verifier(not Donnees.valider(sans_sprite).is_empty(), "skin sans sprite refusé")
	var sans_defaut := AidesPartie.brut()
	var s4: Dictionary = sans_defaut["skins_tour.json"]
	s4["autre"] = s4["defaut"]
	s4.erase("defaut")
	verifier(not Donnees.valider(sans_defaut).is_empty(), "le skin « defaut » est obligatoire")
