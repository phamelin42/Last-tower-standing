extends CasDeTest
## L'estimation d'une arme ne dépend que de son dictionnaire : la même formule sert à
## comparer toutes les armes du contenu.


func _arme(effet: Dictionary, recharge: float = 1.0, prix: int = 100) -> Dictionary:
	return {"degats": 10.0, "recharge": recharge, "prix": prix, "effets": [effet]}


func test_tirs_par_seconde_est_l_inverse_de_la_recharge() -> void:
	verifier_proche(Equilibrage.tirs_par_seconde(_arme({"kind": "cible_unique"}, 2.0)), 0.5)
	verifier_proche(Equilibrage.tirs_par_seconde(_arme({"kind": "cible_unique"}, 0.25)), 4.0)


func test_chaque_kind_a_son_nombre_de_cibles_estime() -> void:
	var attendus := {
		"cible_unique": [{"kind": "cible_unique"}, 1.0],
		"zone": [{"kind": "zone", "rayon": 100}, 3.0],
		"rebond": [{"kind": "rebond", "cibles": 5}, 3.0],
		"onde": [{"kind": "onde", "rayon_max": 300, "vitesse": 200}, 4.0],
		"barrage": [{"kind": "barrage", "projectiles": 6}, 3.0],
		"mine": [{"kind": "mine", "rayon": 80, "max_actives": 3}, 2.0],
		"piege": [{"kind": "piege", "rayon": 80, "max_actives": 3}, 2.0],
		"aura": [{"kind": "aura", "rayon": 150, "periode": 1.0}, 3.0],
		"tournant": [{"kind": "tournant", "branches": 3, "pas_deg": 20, "largeur": 30}, 3.0],
	}
	for kind: String in attendus:
		var cas: Array = attendus[kind]
		var effet: Dictionary = cas[0]
		var attendu: float = cas[1]
		verifier_proche(Equilibrage.cibles_estimees(_arme(effet)), attendu, 0.0001, kind)


func test_rebond_compte_soixante_pour_cent_des_cibles() -> void:
	for cibles: int in range(4, 9):
		var arme := _arme({"kind": "rebond", "cibles": cibles})
		verifier_proche(Equilibrage.cibles_estimees(arme), cibles * 0.6, 0.0001, str(cibles))


func test_barrage_compte_la_moitie_des_projectiles() -> void:
	for projectiles: int in [2, 5, 9]:
		var arme := _arme({"kind": "barrage", "projectiles": projectiles})
		verifier_proche(Equilibrage.cibles_estimees(arme), projectiles * 0.5, 0.0001)


func test_dps_estime_multiplie_degats_cadence_et_cibles() -> void:
	var arme := _arme({"kind": "zone", "rayon": 100}, 2.0)
	verifier_proche(Equilibrage.dps_estime(arme), 10.0 * 0.5 * 3.0)


func test_rendement_est_le_dps_par_piece_d_or() -> void:
	var arme := _arme({"kind": "cible_unique"}, 1.0, 50)
	verifier_proche(Equilibrage.rendement(arme), 10.0 / 50.0)


func test_recharge_minimale_ne_donne_ni_division_par_zero_ni_infini() -> void:
	for recharge: float in [0.0, -1.0, 0.0001]:
		var arme := _arme({"kind": "cible_unique"}, recharge)
		var tirs := Equilibrage.tirs_par_seconde(arme)
		verifier(is_finite(tirs) and tirs > 0.0, "recharge %s" % recharge)


func test_prix_de_un_ou_moins_reste_fini() -> void:
	for prix: int in [1, 0, -5]:
		var arme := _arme({"kind": "cible_unique"}, 1.0, prix)
		var r := Equilibrage.rendement(arme)
		verifier(is_finite(r) and r > 0.0, "prix %s" % prix)
	verifier_proche(Equilibrage.rendement(_arme({"kind": "cible_unique"}, 1.0, 1)), 10.0)


func test_arme_sans_effet_compte_une_cible() -> void:
	var arme := {"degats": 10.0, "recharge": 1.0, "prix": 10, "effets": []}
	verifier_proche(Equilibrage.cibles_estimees(arme), 1.0)


func test_l_estimation_de_rendement_lit_les_champs_avec_les_valeurs_de_reference() -> void:
	var base := _arme({"kind": "cible_unique"}, 1.0, 100)
	base["degats"] = 10.0
	var pv := base.duplicate(true)
	pv["degats_par_pv_max"] = 0.01
	verifier_proche(
		Equilibrage.dps_estime(pv), 10.0 + 0.01 * Equilibrage.REFERENCE_PV_MAX_TOUR, 0.0001
	)
	var copies := base.duplicate(true)
	copies["degats_par_niveau"] = 0.1
	verifier_proche(
		Equilibrage.dps_estime(copies),
		10.0 + 0.1 * float(Equilibrage.REFERENCE_EXEMPLAIRES - 1) * 10.0,
		0.0001
	)
	var ameliorations := base.duplicate(true)
	ameliorations["degats_par_amelioration"] = {"stat": "cadence", "ratio": 0.1}
	verifier_proche(
		Equilibrage.dps_estime(ameliorations),
		10.0 + 0.1 * float(Equilibrage.REFERENCE_AMELIORATIONS) * 10.0,
		0.0001
	)
	var enorme := base.duplicate(true)
	enorme["degats_par_pv_max"] = 100.0
	verifier_proche(
		Equilibrage.dps_estime(enorme), 10.0 * (1.0 + Equilibrage.BONUS_SELON_STAT_MAX), 0.0001
	)


func test_une_arme_sans_champ_garde_son_rendement() -> void:
	var donnees := AidesPartie.donnees()
	for id: String in donnees.armes:
		var arme: Dictionary = donnees.armes[id]
		if (
			float(arme["degats_par_pv_max"]) != 0.0
			or float(arme["degats_par_niveau"]) != 0.0
			or float((arme["degats_par_amelioration"] as Dictionary)["ratio"]) != 0.0
		):
			continue
		var attendu := (
			(float(arme["degats"]) + float(arme["degats_par_mana_max"]) * 40.0)
			* Equilibrage.tirs_par_seconde(arme)
			* Equilibrage.cibles_estimees(arme)
			/ float(arme["prix"])
		)
		verifier_proche(Equilibrage.rendement(arme, 40.0), attendu, 0.0001, id)
