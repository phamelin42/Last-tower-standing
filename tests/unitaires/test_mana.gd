extends CasDeTest
## La mana est un bouclier (D12) : un coup reçu par la tour est d'abord esquivé, réduit par
## l'armure, puis absorbé par la mana point pour point ; le reste va aux PV. Elle se régénère,
## monte avec les améliorations, et quelques armes magiques frappent plus fort avec elle.

const DT := 0.05
const GRAINE := 99
const PV := 1000.0
const CADENCE_TEST := 0.01

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()
	# Ce test vérifie l'ordre des couches, pas le prix de la mana : un point de mana par point de dégât.
	(d.partie["tour"] as Dictionary)["mana_cout_par_pv"] = 1.0


# --- Aides -------------------------------------------------------------------------------------


func _vue(a: Arene) -> VueArene:
	return a.vue(Types.Phase.MANCHE, 10.0, -1, false)


## Un attaquant au corps à corps, immobile, qui frappe dès le premier pas.
func _attaquant(a: Arene, degats: float, explose: bool = false) -> int:
	return a.ennemis.ajouter(
		0, Vector2(100, 0), PV, 0.0, degats, 40.0, CADENCE_TEST, 0, Types.Armure.AUCUNE, explose
	)


func _id_amelioration(stat: String) -> String:
	for id: String in d.ameliorations:
		var effets: Array = (d.ameliorations[id] as Dictionary)["effets"]
		for effet: Dictionary in effets:
			if String(effet["stat"]) == stat:
				return id
	return ""


func _valeur_amelioration(id: String) -> float:
	var effets: Array = (d.ameliorations[id] as Dictionary)["effets"]
	return float((effets[0] as Dictionary)["valeur"])


## Une arène dont la mana maximale vaut `mana` et qui la démarre pleine ; sans régénération, pour
## que les montants restent exacts.
func _arene_avec_mana(mana: float, armure: float = 0.0) -> Arene:
	d.partie["tour"]["armure"] = armure
	d.partie["tour"]["mana_max"] = mana
	d.partie["tour"]["mana_regen"] = 0.0
	return Arene.new(d, GRAINE)


func test_la_tour_demarre_a_zero_de_mana_et_de_mana_maximale() -> void:
	var a := Arene.new(d, GRAINE)
	verifier_proche(a.mana, 0.0, 0.0)
	verifier_proche(a.mana_max(), 0.0, 0.0)
	var v := _vue(a)
	verifier_proche(v.tour_mana, 0.0, 0.0)
	verifier_proche(v.tour_mana_max, 0.0, 0.0)


func test_la_mana_absorbe_un_pour_un_apres_l_esquive_et_l_armure() -> void:
	# Armure 10 : un tiers de réduction. Un coup de 30 devient 20 ; 15 de mana absorbent 15, 5 vont
	# aux PV.
	verifier_proche(Combat.degats_subis(30.0, 10.0), 20.0, 0.01, "contrôle : 30 → 20")
	var a := _arene_avec_mana(15.0, 10.0)
	_attaquant(a, 30.0)
	a.avancer(DT)
	var pv_max := float(d.partie["tour"]["pv"])
	verifier_proche(a.pv, pv_max - 5.0, 0.01, "5 points passent aux PV")
	verifier_proche(a.mana, 0.0, 0.01, "la mana est épuisée")
	# Esquive quasi certaine : seul le plancher de la tour (15 % du coup brut) passe, et la mana
	# l'absorbe : les PV ne bougent pas.
	var plancher := 30.0 * (1.0 - float(d.partie["reduction_degats_max"]))
	var b := _arene_avec_mana(15.0, 10.0)
	b.inventaire.ameliorations[_id_amelioration("esquive")] = 1_000_000
	b.synchroniser()
	_attaquant(b, 30.0)
	b.avancer(DT)
	verifier_proche(b.mana, 15.0 - plancher, 0.0001, "esquivé : la mana absorbe le plancher")
	verifier_proche(b.pv, pv_max, 0.0001, "esquivé : les PV ne bougent pas")


func test_la_mana_ne_descend_pas_sous_zero_et_le_reste_va_aux_pv() -> void:
	for mana: float in [0.0, 1.0, 40.0, 99.0]:
		var a := _arene_avec_mana(mana)
		_attaquant(a, 100.0)
		a.avancer(DT)
		var pv_max := float(d.partie["tour"]["pv"])
		verifier(a.mana >= 0.0, "mana %s : jamais négative (%s)" % [mana, a.mana])
		verifier_proche(a.pv, pv_max - (100.0 - mana), 0.01, "mana %s : le reste va aux PV" % mana)


func test_la_mana_se_regenere_chaque_seconde_jusqu_au_maximum() -> void:
	d.partie["tour"]["mana_max"] = 10.0
	d.partie["tour"]["mana_regen"] = 2.0
	var a := Arene.new(d, GRAINE)
	a.mana = 0.0
	for _pas: int in 20:
		a.avancer(DT)
	verifier_proche(a.mana, 2.0, 0.01, "2 points par seconde")
	for _pas: int in 400:
		a.avancer(DT)
	verifier_proche(a.mana, 10.0, 0.0001, "bornée au maximum")


func test_une_amelioration_de_mana_maximale_ajoute_la_meme_quantite_de_mana() -> void:
	var id := _id_amelioration("mana_max")
	verifier(id != "", "une amélioration de mana maximale existe")
	var gain := _valeur_amelioration(id)
	verifier(gain > 0.0, "gain positif")
	var a := Arene.new(d, GRAINE)
	verifier_proche(a.mana, 0.0, 0.0)
	a.inventaire.ameliorations[id] = 1
	a.synchroniser()
	verifier_proche(a.mana_max(), gain, 0.0001, "le maximum monte")
	verifier_proche(a.mana, gain, 0.0001, "la mana monte du même montant")
	a.inventaire.ameliorations[id] = 2
	a.synchroniser()
	verifier_proche(a.mana, 2.0 * gain, 0.0001, "un second exemplaire aussi")


func test_une_amelioration_de_regeneration_de_mana_existe_et_accelere_la_regeneration() -> void:
	var id := _id_amelioration("mana_regen")
	verifier(id != "", "une amélioration de régénération de mana existe")
	var gain := _valeur_amelioration(id)
	d.partie["tour"]["mana_max"] = 1000.0
	d.partie["tour"]["mana_regen"] = 1.0
	var sans := Arene.new(d, GRAINE)
	sans.mana = 0.0
	var avec := Arene.new(d, GRAINE)
	avec.inventaire.ameliorations[id] = 1
	avec.synchroniser()
	avec.mana = 0.0
	for _pas: int in 20:
		sans.avancer(DT)
		avec.avancer(DT)
	verifier_proche(sans.mana, 1.0, 0.01)
	verifier_proche(avec.mana, 1.0 + gain, 0.01)


func test_les_epines_se_declenchent_meme_quand_la_mana_absorbe_tout() -> void:
	var a := _arene_avec_mana(10000.0)
	a.inventaire.ameliorations["couronne_d_epines"] = 1
	a.synchroniser()
	var i := _attaquant(a, 50.0)
	a.avancer(DT)
	var pv_max := float(d.partie["tour"]["pv"])
	verifier_proche(a.pv, pv_max, 0.0001, "la mana a tout absorbé")
	verifier(a.ennemis.pv[a.ennemis.indice_de(i)] < PV, "l'attaquant a pris les épines")


func test_l_explosion_du_tonneau_est_absorbee_par_la_mana() -> void:
	var a := _arene_avec_mana(500.0)
	_attaquant(a, 80.0, true)
	a.avancer(DT)
	var pv_max := float(d.partie["tour"]["pv"])
	verifier_proche(a.pv, pv_max, 0.0001, "les PV sont intacts")
	verifier_proche(a.mana, 420.0, 0.01, "l'explosion a coûté 80 de mana")
	verifier_egal(a.nombre_ennemis(), 0, "le Tonneau a disparu")


func test_chaque_absorption_emet_un_evenement_et_la_vue_porte_la_mana() -> void:
	for coup: float in [5.0, 15.0, 30.0, 99.0]:
		var a := _arene_avec_mana(200.0)
		_attaquant(a, coup)
		a.avancer(DT)
		var v := _vue(a)
		var absorptions := 0
		for evt: Dictionary in v.evenements:
			if evt["k"] == "absorption":
				absorptions += 1
				verifier(
					evt.has("de") and evt.has("vers") and evt.has("rayon"), "champs de l'événement"
				)
		verifier_egal(absorptions, 1, "coup de %s : un événement d'absorption" % coup)
		verifier_proche(v.tour_mana, 200.0 - coup, 0.01, "la vue porte la mana restante")
		verifier_non_nul(VueArene.from_dict(v.to_dict()), "la vue reste valide")
	# Sans mana, aucun événement.
	var b := _arene_avec_mana(0.0)
	_attaquant(b, 30.0)
	b.avancer(DT)
	for evt: Dictionary in _vue(b).evenements:
		verifier(evt["k"] != "absorption", "rien à absorber")


func test_une_arme_de_mana_ajoute_ratio_fois_mana_maximale_aux_degats_de_base() -> void:
	var def: Dictionary = (d.armes["etincelle_runique"] as Dictionary).duplicate(true)
	def["degats"] = 100.0
	def["recharge"] = 1.0
	def["degats_par_mana_max"] = 0.5
	def["effets"] = [{"kind": "cible_unique"}]
	def["statuts"] = []
	def["type_degats"] = Types.TypeDegats.CHAOS
	for mana_max: float in [0.0, 40.0]:
		var ennemis := Ennemis.new(d)
		var id := ennemis.ajouter(
			0, Vector2(100, 0), 5000.0, 0.0, 0.0, 40.0, 1.0, 1, Types.Armure.AUCUNE
		)
		var stats := StatsTour.new()
		stats.mana_max_bonus = mana_max
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var bilan := Tir.Bilan.new()
		Tir.avancer_arme(ArmeEquipee.new(def), DT, stats, ennemis, Vector2.ZERO, d, rng, 1.0, bilan)
		var perdu := 5000.0 - ennemis.pv[ennemis.indice_de(id)]
		verifier_proche(perdu, 100.0 + 0.5 * mana_max, 0.01, "mana maximale %s" % mana_max)


func test_au_moins_quatre_armes_de_mana_toutes_magiques() -> void:
	var nombre := 0
	for id: String in d.armes:
		var ratio := float((d.armes[id] as Dictionary)["degats_par_mana_max"])
		if ratio <= 0.0:
			continue
		nombre += 1
		verifier_egal(
			int((d.armes[id] as Dictionary)["type_degats"]), Types.TypeDegats.MAGIQUE, "%s" % id
		)
	verifier(nombre >= 4, "%d armes de mana" % nombre)


func test_la_mana_est_propre_a_chaque_arene() -> void:
	var a := Arene.new(d, GRAINE)
	var b := Arene.new(d, GRAINE)
	var id := _id_amelioration("mana_max")
	a.inventaire.ameliorations[id] = 1
	a.synchroniser()
	verifier(a.mana > 0.0 and a.mana_max() > 0.0, "l'arène A a de la mana")
	verifier_proche(b.mana, 0.0, 0.0, "l'arène B n'en a pas")
	verifier_proche(b.mana_max(), 0.0, 0.0)
	_attaquant(a, 30.0)
	a.avancer(DT)
	verifier_proche(b.mana, 0.0, 0.0, "les coups reçus par A ne touchent pas B")
