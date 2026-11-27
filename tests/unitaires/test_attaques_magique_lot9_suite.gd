extends CasAttaquesMagique
## Les armes magiques du lot 9 (D22), seconde moitié : couronne d'étoiles, vasque d'arcanes, nuée
## d'étincelles, nova céleste, puis les neuf ensemble. Mêmes phases et mêmes bornes que les armes
## du lot 8. Durées en images à 60 i/s.

var _impacts_visibles: int = 0

# --- Couronne d'étoiles : tir tournant de cinq branches ------------------------------------------


func test_la_couronne_d_etoiles_est_un_tir_tournant_de_cinq_branches() -> void:
	_verifier_arme("couronne_d_etoiles", "couronne_etoiles", "tournant")
	verifier_egal(int(_effet("couronne_d_etoiles")["branches"]), 5, "cinq branches")
	verifier_egal(_statut("couronne_d_etoiles"), "mana_au_coup")


func test_chaque_etoile_file_droit_le_long_de_son_rayon_en_tournant_sur_elle_meme() -> void:
	var bout: Vector2 = TOUR + Vector2.from_angle(deg_to_rad(72.0)) * 250.0
	verifier_proche(_a.tirer("couronne_etoiles", TOUR, bout) / IMAGE, 10.0, 0.01, "3 + 7 images")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
	var etoile: Dictionary = _a.etats("etoile_astrale")[0]
	verifier(etoile["visible"], "elle vole")
	verifier(absf(etoile["rotation"] - deg_to_rad(72.0)) > 0.01, "elle tourne sur elle-même")
	verifier(_a.particules_actives() >= 1, "une traînée")


func test_le_bout_du_rayon_etoile_a_la_largeur_du_rayon_et_ne_dit_pas_touche() -> void:
	var largeur: float = _rayon_px("couronne_d_etoiles", "largeur")
	verifier(_a.impacter("couronne_etoiles", CIBLE, largeur))
	verifier_proche(_a.etats("eclat_astral")[0]["diametre"], largeur * 2.0, 0.01, "à la largeur")
	verifier(_a.diametre_max() <= 60.0, "petit")
	verifier_egal(_a.etats("").size(), 0, "pas d'anneau : les rayons sont ceux d'Effets")
	var total: int = AttaqueCouronneEtoiles.SEQ_ECLAT.size()
	var rang: int = _rang_du_pic("eclat_astral", AttaqueCouronneEtoiles.IMAGE_PIC, total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])
	_avancer(total + 30)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_la_couronne_dans_effets_envoie_une_etoile_par_branche() -> void:
	var effets: Effets = _effets_de("couronne_d_etoiles")
	verifier_egal(effets.elementaires().etats("etoile_astrale").size(), 5, "cinq étoiles")
	effets.free()


func test_mouvement_reduit_la_couronne_sans_particule_ni_rotation() -> void:
	_a.mouvement_reduit = true
	_a.tirer("couronne_etoiles", TOUR, CIBLE)
	_a.impacter("couronne_etoiles", CIBLE, 27.0)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
	verifier_egal(_a.particules_actives(), 0)
	verifier_proche(_a.etats("etoile_astrale")[0]["rotation"], 0.0, 0.0001, "elle ne tourne pas")


# --- Vasque d'arcanes : aura, siphon -------------------------------------------------------------


func test_la_vasque_d_arcanes_est_une_aura_qui_siphonne() -> void:
	_verifier_arme("vasque_d_arcanes", "vasque", "aura")
	verifier_egal(_statut("vasque_d_arcanes"), "siphon")
	verifier_egal(AttaquesElementaires.planche_projectile("vasque"), "", "rien ne part")


func test_les_vasques_atteignent_le_rayon_reel_de_l_aura_en_sept_images() -> void:
	var rayon: float = _rayon_px("vasque_d_arcanes")
	verifier(_a.aura("vasque", TOUR, rayon))
	verifier_egal(_a.etats("vasque").size(), AttaqueVasque.VASQUES, "la couronne")
	_avancer(AttaquesElementaires.IMAGES_COURONNE_OUVERTURE)
	var portee_max: float = 0.0
	for vasque: Dictionary in _a.etats("vasque"):
		var d: float = (vasque["position"] as Vector2).distance_to(TOUR)
		portee_max = maxf(portee_max, d + vasque["taille"].y * 0.5)
		verifier(d < rayon, "le centre de la vasque est dans la zone")
	verifier_proche(portee_max, rayon, rayon * 0.1, "le bord extérieur est au rayon")
	verifier(_a.diametre_max() <= rayon * 2.0 * 1.1, "rien au-delà de la zone")
	verifier_egal(_a.etats("").size(), 1, "un anneau fin au rayon exact")


func test_des_volutes_de_siphon_se_posent_dans_la_zone_au_pic_dans_le_premier_quart() -> void:
	var rayon: float = _rayon_px("vasque_d_arcanes")
	_a.aura("vasque", TOUR, rayon)
	var volutes: Array[Dictionary] = _a.etats("eclat_siphon")
	verifier_egal(volutes.size(), AttaqueVasque.VOLUTES, "des volutes")
	for volute: Dictionary in volutes:
		var d: float = (volute["position"] as Vector2).distance_to(TOUR)
		verifier(d + volute["diametre"] * 0.5 <= rayon + 1.0, "dans la zone")
		verifier(volute["diametre"] <= 60.0, "petite")
	var total: int = AttaqueVasque.SEQ_VOLUTE.size()
	var rang: int = _rang_du_pic("eclat_siphon", AttaqueVasque.IMAGE_PIC, total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])


func test_la_vasque_s_efface_et_rend_le_pool() -> void:
	_a.aura("vasque", TOUR, 160.0)
	_avancer(90)
	verifier_egal(_a.nombre_vivants(), 0)
	verifier_egal(_a.particules_actives(), 0)


func test_la_vasque_dans_effets_se_dessine_a_chaque_impulsion_de_l_aura() -> void:
	var effets: Effets = _effets_de("vasque_d_arcanes")
	verifier_egal(effets.elementaires().etats("vasque").size(), AttaqueVasque.VASQUES)
	verifier_faux(effets.formes_vivantes().has("anneau"), "plus d'anneau générique")
	effets.free()


func test_mouvement_reduit_la_vasque_sans_particule_et_sans_rotation() -> void:
	_a.mouvement_reduit = true
	_a.aura("vasque", TOUR, 160.0)
	var avant: Array[Dictionary] = _a.etats("vasque")
	_avancer(4)
	var apres: Array[Dictionary] = _a.etats("vasque")
	verifier_egal(_a.particules_actives(), 0)
	verifier_proche(
		((avant[0]["position"] as Vector2) - TOUR).angle(),
		((apres[0]["position"] as Vector2) - TOUR).angle(),
		0.0001,
		"elles ne tournent pas"
	)
