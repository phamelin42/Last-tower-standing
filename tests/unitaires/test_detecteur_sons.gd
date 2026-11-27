extends CasDeTest
## Les sons qu'on entend à chaque pas de l'arène, lus seulement dans la vue : un tir ne se joue
## qu'une fois par vue, l'impact jamais (il suit l'effet : `LecteurSons.jouer_impact`), un
## franchissement de seuil ou de phase se joue une seule fois, et rien ne se joue sans changement.


func _vue(manche: int = 1, phase: int = Types.Phase.MANCHE, pv: float = 100.0) -> VueArene:
	var v := VueArene.new()
	v.manche = manche
	v.phase = phase
	v.tour_pv = pv
	v.tour_pv_max = 100.0
	return v


func _evenement(genre: String) -> Dictionary:
	return {
		"k": genre,
		"t": 0,
		"de": Vector2.ZERO,
		"vers": Vector2.ZERO,
		"type_degats": 0,
		"rayon": 0.0,
	}


func test_une_vue_identique_ne_joue_aucun_son() -> void:
	var v := _vue()
	verifier_egal(DetecteurSons.sons_du_pas(v, v).size(), 0, "rien ne change, rien ne se joue")


func test_la_premiere_vue_ne_joue_que_ses_evenements() -> void:
	var v := _vue(1, Types.Phase.BOSS)
	v.evenements.append(_evenement("tir"))
	var sons := DetecteurSons.sons_du_pas(null, v)
	verifier_egal(sons, [CatalogueSons.TIR], "sans vue précédente, ni boss ni manche ne jouent")


func test_un_tir_ne_se_joue_qu_une_fois_par_vue_meme_en_rafale() -> void:
	var v := _vue()
	for i: int in 40:
		v.evenements.append(_evenement("tir"))
	var sons := DetecteurSons.sons_du_pas(null, v)
	verifier_egal(sons.count(CatalogueSons.TIR), 1, "quarante tirs ne font qu'un son de tir")


func test_tir_et_mort_ont_chacun_leur_son_et_l_impact_attend_son_effet() -> void:
	var v := _vue()
	v.evenements.append(_evenement("tir"))
	v.evenements.append(_evenement("impact"))
	v.evenements.append(_evenement("mort"))
	var sons := DetecteurSons.sons_du_pas(null, v)
	verifier_contient(sons, CatalogueSons.TIR)
	verifier_contient(sons, CatalogueSons.MORT)
	verifier_egal(sons.size(), 2, "l'événement d'impact ne joue rien : le son part à l'effet")


func test_la_pv_basse_se_joue_au_passage_du_seuil_seulement() -> void:
	var seuil: float = DetecteurSons.SEUIL_PV_BAS
	var sous: float = (seuil - 0.01) * 100.0
	var dessus: float = (seuil + 0.01) * 100.0
	verifier_contient(
		DetecteurSons.sons_du_pas(
			_vue(1, Types.Phase.MANCHE, dessus), _vue(1, Types.Phase.MANCHE, sous)
		),
		CatalogueSons.PV_BAS,
		"franchissement vers le bas"
	)
	verifier_faux(
		(
			DetecteurSons
			. sons_du_pas(
				_vue(1, Types.Phase.MANCHE, sous), _vue(1, Types.Phase.MANCHE, sous - 10.0)
			)
			. has(CatalogueSons.PV_BAS)
		),
		"déjà sous le seuil"
	)
	verifier_faux(
		(
			DetecteurSons
			. sons_du_pas(
				_vue(1, Types.Phase.MANCHE, dessus), _vue(1, Types.Phase.MANCHE, dessus + 10.0)
			)
			. has(CatalogueSons.PV_BAS)
		),
		"remontée sans chute"
	)


func test_une_tour_sans_pv_max_ne_joue_pas_la_pv_basse() -> void:
	var avant := _vue(1, Types.Phase.MANCHE, 100.0)
	var apres := _vue(1, Types.Phase.MANCHE, 0.0)
	avant.tour_pv_max = 0.0
	apres.tour_pv_max = 0.0
	verifier_faux(
		DetecteurSons.sons_du_pas(avant, apres).has(CatalogueSons.PV_BAS),
		"division par zéro évitée"
	)


func test_le_debut_de_manche_se_joue_quand_la_manche_avance() -> void:
	verifier_contient(DetecteurSons.sons_du_pas(_vue(1), _vue(2)), CatalogueSons.DEBUT_MANCHE)
	verifier_faux(
		DetecteurSons.sons_du_pas(_vue(2), _vue(2)).has(CatalogueSons.DEBUT_MANCHE), "même manche"
	)


func test_le_boss_se_joue_une_seule_fois_au_passage_en_phase_boss() -> void:
	for avant: int in Types.Phase.values():
		for apres: int in Types.Phase.values():
			var sons := DetecteurSons.sons_du_pas(_vue(1, avant), _vue(1, apres))
			var attendu := avant != Types.Phase.BOSS and apres == Types.Phase.BOSS
			verifier_egal(
				sons.has(CatalogueSons.BOSS),
				attendu,
				"boss joué de la phase %d à la phase %d" % [avant, apres],
			)


func test_victoire_et_defaite_se_jouent_au_passage_de_phase() -> void:
	verifier_contient(
		DetecteurSons.sons_du_pas(_vue(1, Types.Phase.BOSS), _vue(1, Types.Phase.VICTOIRE)),
		CatalogueSons.VICTOIRE,
	)
	verifier_contient(
		DetecteurSons.sons_du_pas(_vue(1, Types.Phase.MANCHE), _vue(1, Types.Phase.DEFAITE)),
		CatalogueSons.DEFAITE,
	)
	verifier_faux(
		DetecteurSons.sons_du_pas(_vue(1, Types.Phase.VICTOIRE), _vue(1, Types.Phase.VICTOIRE)).has(
			CatalogueSons.VICTOIRE
		),
		"la victoire ne se rejoue pas à chaque pas",
	)


func test_un_objet_qui_entre_dans_l_inventaire_fait_un_achat() -> void:
	var avant := _vue()
	var apres := _vue()
	apres.armes.append({"id": "arme_test"})
	verifier_contient(DetecteurSons.sons_du_pas(avant, apres), CatalogueSons.ACHAT)


func test_une_amelioration_achetee_fait_un_achat() -> void:
	var avant := _vue()
	var apres := _vue()
	apres.ameliorations["amelioration_test"] = 1
	verifier_contient(DetecteurSons.sons_du_pas(avant, apres), CatalogueSons.ACHAT)


func test_des_offres_neuves_sans_achat_font_une_relance() -> void:
	var avant := _vue()
	var apres := _vue()
	apres.offres.append({"id": "offre_neuve"})
	var sons := DetecteurSons.sons_du_pas(avant, apres)
	verifier_contient(sons, CatalogueSons.RELANCE)
	verifier_faux(sons.has(CatalogueSons.ACHAT), "aucun objet n'a été acheté")


func _evenement_arme(genre: String, index_arme: int, type_degats: int = 0) -> Dictionary:
	var e: Dictionary = _evenement(genre)
	e["type_degats"] = type_degats
	if index_arme >= 0:
		e["arme"] = index_arme
	return e


func test_le_detecteur_choisit_le_son_de_l_arme_de_l_evenement() -> void:
	var donnees: Donnees = Donnees.charger()
	var catalogue: PackedStringArray = donnees.ids_catalogue
	for id: Variant in donnees.armes:
		var v := _vue()
		v.evenements.append(_evenement_arme("tir", catalogue.find(String(id))))
		var sons: Array[String] = DetecteurSons.sons_du_pas(null, v, catalogue)
		verifier_egal(sons, ["tir_" + String(id)] as Array[String], "tir de %s" % id)


func test_un_evenement_sans_arme_donne_le_son_tir() -> void:
	var catalogue: PackedStringArray = Donnees.charger().ids_catalogue
	var v := _vue()
	v.evenements.append(_evenement_arme("tir", -1))
	verifier_egal(
		DetecteurSons.sons_du_pas(null, v, catalogue), [CatalogueSons.TIR] as Array[String]
	)
	verifier_egal(DetecteurSons.sons_du_pas(null, v), [CatalogueSons.TIR] as Array[String])


func test_un_index_d_arme_hors_catalogue_donne_le_son_tir() -> void:
	var catalogue: PackedStringArray = Donnees.charger().ids_catalogue
	for index: int in [-5, catalogue.size(), 70000]:
		var v := _vue()
		v.evenements.append(_evenement_arme("tir", index))
		verifier_egal(
			DetecteurSons.sons_du_pas(null, v, catalogue), [CatalogueSons.TIR] as Array[String]
		)


func test_aucun_type_de_degats_ne_joue_son_impact_a_l_evenement() -> void:
	for type: int in 5:
		var v := _vue()
		v.evenements.append(_evenement_arme("impact", -1, type))
		verifier_egal(DetecteurSons.sons_du_pas(null, v).size(), 0, "type %d" % type)


func test_des_tirs_de_deux_armes_jouent_deux_sons_sans_doublon() -> void:
	var donnees := Donnees.charger()
	var catalogue: PackedStringArray = donnees.ids_catalogue
	# Deux armes (le catalogue mêle armes et améliorations, triées) qui n'ont pas le même son.
	var premiere := -1
	var seconde := -1
	for index: int in catalogue.size():
		if not donnees.armes.has(catalogue[index]):
			continue
		if premiere < 0:
			premiere = index
		elif CatalogueSons.id_tir(catalogue[index]) != CatalogueSons.id_tir(catalogue[premiere]):
			seconde = index
			break
	verifier(premiere >= 0 and seconde >= 0, "deux armes de sons différents existent")
	var v := _vue()
	for index: int in [premiere, premiere, seconde]:
		v.evenements.append(_evenement_arme("tir", index))
	verifier_egal(DetecteurSons.sons_du_pas(null, v, catalogue).size(), 2)
