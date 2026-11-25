extends CasDeTest
## Les sons qu'on entend à chaque pas de l'arène, lus seulement dans la vue : un tir ou un impact
## ne se joue qu'une fois par vue, un franchissement de seuil ou de phase se joue une seule fois,
## et rien ne se joue sans changement.


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
	v.evenements.append(_evenement("impact"))
	var sons := DetecteurSons.sons_du_pas(null, v)
	verifier_egal(sons, [CatalogueSons.IMPACT], "sans vue précédente, ni boss ni manche ne jouent")


func test_un_tir_ne_se_joue_qu_une_fois_par_vue_meme_en_rafale() -> void:
	var v := _vue()
	for i: int in 40:
		v.evenements.append(_evenement("tir"))
	var sons := DetecteurSons.sons_du_pas(null, v)
	verifier_egal(sons.count(CatalogueSons.TIR), 1, "quarante tirs ne font qu'un son de tir")


func test_tir_impact_et_mort_ont_chacun_leur_son() -> void:
	var v := _vue()
	v.evenements.append(_evenement("tir"))
	v.evenements.append(_evenement("impact"))
	v.evenements.append(_evenement("mort"))
	var sons := DetecteurSons.sons_du_pas(null, v)
	verifier_contient(sons, CatalogueSons.TIR)
	verifier_contient(sons, CatalogueSons.IMPACT)
	verifier_contient(sons, CatalogueSons.MORT)


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
