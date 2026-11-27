extends CasDeTest
## D23 (§6.17.3) : une arme achetée une seconde fois monte de niveau au lieu d'être ajoutée. Le
## niveau n donne +30 % de dégâts de base et +20 % de cadence par niveau au-dessus du premier
## (`partie.json` `niveaux`), la cadence totale restant bornée. Les valeurs attendues sont écrites
## ici de tête, pas relues dans le code.

const DT := 0.05
var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _niveaux() -> Dictionary:
	return d.partie["niveaux"]


func _arme_synthetique() -> Dictionary:
	return {
		"id": "synthese",
		"degats": 100.0,
		"recharge": 2.0,
		"type_degats": Types.TypeDegats.TRANCHANT,
		"effets": [{"kind": "cible_unique"}],
		"statuts": [],
	}


func test_acheter_deux_fois_la_meme_arme_monte_son_niveau_sans_ajouter_d_arme() -> void:
	for id: String in d.armes:
		var inv := Inventaire.new(d)
		verifier_egal(inv.ajouter(id), Types.Resultat.OK)
		verifier_egal(inv.niveau(id), 1, id)
		verifier_egal(inv.ajouter(id), Types.Resultat.OK)
		verifier_egal(inv.ajouter(id), Types.Resultat.OK)
		verifier_egal(inv.armes.size(), 1, id + " : une seule arme portée")
		verifier_egal(inv.niveau(id), 3, id)


func test_le_niveau_d_une_arme_non_portee_est_zero() -> void:
	var inv := Inventaire.new(d)
	verifier_egal(inv.niveau(d.armes.keys()[0]), 0)
	verifier_egal(inv.niveau("inconnue"), 0)


func test_les_armes_portees_gardent_l_ordre_du_premier_achat() -> void:
	var ids: Array = d.armes.keys().slice(0, 3)
	var inv := Inventaire.new(d)
	for id: String in [ids[1], ids[0], ids[1], ids[2], ids[0]]:
		inv.ajouter(id)
	verifier_egal(inv.armes, [ids[1], ids[0], ids[2]] as Array[String])
	verifier_egal(inv.niveau(ids[1]), 2)
	verifier_egal(inv.niveau(ids[0]), 2)


func test_la_256e_arme_n_est_plus_refusee_car_une_arme_n_est_portee_qu_une_fois() -> void:
	var inv := Inventaire.new(d)
	var id: String = d.armes.keys()[0]
	for i: int in 300:
		verifier_egal(inv.ajouter(id), Types.Resultat.OK, "achat %d" % i)
	verifier_egal(inv.niveau(id), 300)


func test_les_degats_du_niveau_n_valent_la_base_plus_30_pour_cent_par_niveau() -> void:
	var arme := _arme_synthetique()
	var gain := float(_niveaux()["gain_degats"])
	verifier_proche(gain, 0.30, 0.0001, "gain de Phil (D23, Q1)")
	for n: int in range(1, 21):
		var recu := Tir.degats_de_base(arme, StatsTour.new(), 0.0, n, {}, 0.0, 0.0, 4.0, gain)
		verifier_proche(recu, 100.0 * (1.0 + 0.30 * float(n - 1)), 0.001, "niveau %d" % n)


## Jusqu'au niveau 15 : au niveau 16, le plafond de cadence (+300 %) est atteint.
func test_la_cadence_du_niveau_n_ajoute_20_pour_cent_par_niveau() -> void:
	var gain := float(_niveaux()["gain_cadence"])
	verifier_proche(
		gain, 0.20, 0.0001, "gain de cadence retenu par la mesure (voir docs/equilibrage.md)"
	)
	var arme := ArmeEquipee.new(_arme_synthetique())
	var stats := StatsTour.new()
	for n: int in range(1, 16):
		arme.definir_niveau(n, gain, 3.0)
		verifier_proche(
			arme.recharge_effective(stats),
			2.0 / (1.0 + 0.20 * float(n - 1)),
			0.001,
			"niveau %d" % n
		)


func test_la_cadence_totale_ne_depasse_jamais_le_plafond() -> void:
	var cadence_max := float(_niveaux()["cadence_max"])
	verifier_proche(cadence_max, 3.0, 0.0001)
	var arme := ArmeEquipee.new(_arme_synthetique())
	var stats := StatsTour.new()
	stats.cadence = 5.0
	arme.definir_niveau(255, 0.20, cadence_max)
	verifier_proche(arme.recharge_effective(stats), 2.0 / (1.0 + cadence_max), 0.0001, "plafonnée")


func test_la_cadence_des_ameliorations_et_celle_des_niveaux_s_additionnent() -> void:
	var arme := ArmeEquipee.new(_arme_synthetique())
	var stats := StatsTour.new()
	stats.cadence = 0.5
	arme.definir_niveau(3, 0.20, 3.0)
	verifier_proche(arme.recharge_effective(stats), 2.0 / (1.0 + 0.5 + 0.4), 0.001)


func test_l_arene_monte_une_seule_arme_equipee_par_arme_distincte_et_lui_donne_son_niveau() -> void:
	var a := Arene.new(d, 31)
	var id: String = d.armes.keys()[0]
	for i: int in 4:
		a.inventaire.ajouter(id)
	a.synchroniser()
	verifier_egal(a.armes.size(), 1)
	verifier_egal(a.armes[0].niveau, 4)
	var vue := a.vue(Types.Phase.PREPARATION, 10.0, -1, false)
	verifier_egal(vue.armes.size(), 1, "la vue montre une arme")


func test_un_niveau_de_plus_inflige_plus_de_degats_par_tir() -> void:
	var degats: Array[float] = []
	var id := "lame_de_fil"
	for niveaux: int in [1, 5]:
		var a := Arene.new(d, 31)
		for i: int in niveaux:
			a.inventaire.ajouter(id)
		a.synchroniser()
		a.ennemis.ajouter(1, Vector2(100.0, 0.0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, 4)
		for i: int in 40:
			a.avancer(DT)
		degats.append(1.0e6 - a.ennemis.pv[0])
	verifier(degats[0] > 0.0, "le niveau 1 touche")
	verifier(degats[1] > degats[0] * 1.5, "niveau 5 : %s, niveau 1 : %s" % [degats[1], degats[0]])


func test_les_gains_par_niveau_negatifs_ou_non_finis_sont_refuses() -> void:
	for cle: String in ["gain_degats", "gain_cadence", "cadence_max"]:
		for mauvais: float in [-0.1, INF, NAN]:
			var brut := AidesPartie.brut()
			var partie: Dictionary = (brut["partie.json"] as Dictionary).duplicate(true)
			(partie["niveaux"] as Dictionary)[cle] = mauvais
			brut["partie.json"] = partie
			verifier_faux(Donnees.valider(brut).is_empty(), "%s = %s refusé" % [cle, mauvais])


func test_une_clef_de_niveau_manquante_est_refusee() -> void:
	for cle: String in ["gain_degats", "gain_cadence", "cadence_max"]:
		var brut := AidesPartie.brut()
		var partie: Dictionary = (brut["partie.json"] as Dictionary).duplicate(true)
		(partie["niveaux"] as Dictionary).erase(cle)
		brut["partie.json"] = partie
		verifier_faux(Donnees.valider(brut).is_empty(), cle + " manquante")


func test_aucune_arme_ne_porte_encore_l_ancien_champ_par_exemplaire() -> void:
	var ancien := "degats_par_" + "exemplaire"
	for id: String in d.armes:
		verifier_faux((d.armes[id] as Dictionary).has(ancien), id)
	var avec_niveau := 0
	for id: String in d.armes:
		if float((d.armes[id] as Dictionary).get("degats_par_niveau", 0.0)) > 0.0:
			avec_niveau += 1
	verify_count(avec_niveau)


func verify_count(n: int) -> void:
	verifier_egal(n, 2, "deux armes lisent le niveau (M5)")
