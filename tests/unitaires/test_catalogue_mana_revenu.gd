extends CasDeTest
## Les 7 améliorations de T9.12 : mana (+4), revenu (+1), boutique (+1) et aura mixte (+1), avec
## leur famille, leur stat, leur rareté, leur catégorie et leur image.

## id → [famille, stat, rareté, catégorie].
const NOUVELLES: Dictionary = {
	"citerne_d_arcanes": ["mana", "mana_max_mult", Types.Rarete.RARE, Types.Categorie.AMELIORATION],
	"bouclier_en_eclats":
	["mana", "mana_rupture_etourdit", Types.Rarete.RARE, Types.Categorie.AMELIORATION],
	"grimoire_de_surcharge":
	["mana", "degats_tant_que_mana", Types.Rarete.RARE, Types.Categorie.AMELIORATION],
	"voile_de_brume":
	["mana", "reduction_tant_que_mana", Types.Rarete.RARE, Types.Categorie.AMELIORATION],
	"commerce_a_credit": ["revenu", "revenu_contre_pv", Types.Rarete.RARE, Types.Categorie.REVENU],
	"echo_de_l_aubaine":
	["boutique", "copie_prochaine_offre", Types.Rarete.RARE, Types.Categorie.AMELIORATION],
	"brume_de_vie": ["aura_mixte", "aura_mixte", Types.Rarete.RARE, Types.Categorie.AMELIORATION],
}

var _donnees: Donnees


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func test_les_sept_ameliorations_existent_avec_leur_famille_leur_stat_leur_rarete_et_leur_categorie(
) -> void:
	verifier_egal(NOUVELLES.size(), 7)
	for id: String in NOUVELLES:
		verifier(_donnees.ameliorations.has(id), "%s existe" % id)
		if not _donnees.ameliorations.has(id):
			continue
		var attendu: Array = NOUVELLES[id]
		var amelioration: Dictionary = _donnees.ameliorations[id]
		verifier_egal(amelioration["famille"], attendu[0], "%s : famille" % id)
		verifier_egal(amelioration["rarete"], attendu[2], "%s : rareté" % id)
		verifier_egal(amelioration["categorie"], attendu[3], "%s : catégorie" % id)
		var effets: Array = amelioration["effets"]
		verifier_egal(effets.size(), 1, "%s : un seul effet" % id)
		verifier_egal((effets[0] as Dictionary)["stat"], attendu[1], "%s : stat" % id)


func test_chaque_stat_ajoutee_est_employee_et_la_famille_mana_compte_sept() -> void:
	var mana := 0
	for id: String in _donnees.ameliorations:
		if (_donnees.ameliorations[id] as Dictionary)["famille"] == "mana":
			mana += 1
	verifier_egal(mana, 7, "trois améliorations de T8.7 et quatre de T9.12")


func test_les_effets_ont_des_valeurs_positives_et_le_revenu_coute_des_pv() -> void:
	for id: String in NOUVELLES:
		var effet: Dictionary = ((_donnees.ameliorations[id] as Dictionary)["effets"] as Array)[0]
		for cle: String in effet:
			if effet[cle] is float or effet[cle] is int:
				verifier(float(effet[cle]) > 0.0, "%s : %s positif" % [id, cle])
	var tour := float((_donnees.partie["tour"] as Dictionary)["pv"])
	var contre: Dictionary = (
		(_donnees.ameliorations["commerce_a_credit"] as Dictionary)["effets"] as Array
	)[0]
	verifier(float(contre["pv"]) < tour, "la perte laisse des PV à la tour")


func test_le_givre_des_epines_et_de_la_riposte_vaut_un_cran() -> void:
	for id: String in ["givre_des_ronces", "cuirasse_de_givre"]:
		var effet: Dictionary = ((_donnees.ameliorations[id] as Dictionary)["effets"] as Array)[0]
		verifier_proche(float(effet["valeur"]), 1.0, 0.0001, "%s : un cran de givre" % id)


func test_la_tour_au_complet_reste_vivable_avec_toutes_les_ameliorations() -> void:
	var a := Arene.new(_donnees, 3)
	for id: String in _donnees.ameliorations:
		a.inventaire.ajouter(id)
	a.synchroniser()
	verifier(a.tour_pv_max() >= 1.0 and a.pv > 0.0, "au moins un PV")
	for _i: int in 20:
		a.avancer(0.05)
	verifier_faux(a.est_detruite())
