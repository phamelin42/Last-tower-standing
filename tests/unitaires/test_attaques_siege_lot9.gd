extends CasAttaquesSiegeLot9
## Les armes de siège du lot 9 (D22), première moitié : baril à retardement, maillet de rempart,
## catapulte à contrepoids, obusier de brèche, braise de siège. Mêmes phases et mêmes bornes que
## les armes de siège du lot 8 (anticipation 3 images, vol direct 7 ou en cloche 11 avec ombre,
## impact au pic dans le premier quart, zone au rayon réel lu dans `data/armes.json`, gel du coup de
## siège). Durées en images à 60 i/s.

# --- Baril à retardement : bombe ------------------------------------------------------------------


func test_le_baril_est_une_bombe_de_siege_sans_statut() -> void:
	_verifier_arme("baril_a_retardement", "baril", "bombe")
	verifier_egal(_statut("baril_a_retardement"), "", "aucun statut")


func test_le_baril_est_lance_en_cloche_avec_son_ombre_et_arrive_en_quatorze_images() -> void:
	verifier_proche(_a.tirer("baril", TOUR, CIBLE) / IMAGE, 14.0, 0.01, "3 + 11 images")
	verifier_egal(_a.etats("ombre").size(), 1, "l'ombre suit la cloche")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 6)
	var baril: Dictionary = _a.etats("baril")[0]
	verifier(baril["visible"], "il vole")
	verifier(baril["position"].y < CIBLE.y - 10.0, "il passe au-dessus de la ligne de tir")
	_avancer(10)
	verifier_egal(_a.etats("baril").size(), 0, "arrivé, il disparaît : la vue pose la bombe")


func test_le_baril_n_explose_pas_a_la_pose_et_explose_une_seule_fois_a_l_impact() -> void:
	var effets: Effets = _effets_neuf()
	effets.ajouter(_evenement("baril_a_retardement", "tir"))
	for _i: int in 40:
		effets.avancer(IMAGE)
	verifier_egal(effets.elementaires().etats("explosion_feu").size(), 0, "rien à la pose")
	verifier_faux(effets.formes_vivantes().has("explosion"), "pas d'explosion du pack à la pose")
	effets.ajouter(_evenement("baril_a_retardement", "impact"))
	verifier_egal(effets.elementaires().etats("explosion_feu").size(), 1, "une explosion de baril")
	verifier_faux(effets.formes_vivantes().has("explosion"), "jamais deux explosions")
	verifier_faux(AttaquesElementaires.explosion_du_pack("baril"), "l'élément porte l'explosion")
	effets.free()


func test_l_explosion_du_baril_est_au_rayon_reel_avec_le_gel_d_un_coup_de_siege() -> void:
	var rayon: float = _rayon_px("baril_a_retardement")
	verifier(_a.impacter("baril", CIBLE, rayon, true))
	verifier_proche(_a.etats("explosion_feu")[0]["diametre"], rayon * 2.0, rayon * 0.2, "au rayon")
	verifier(_a.gel_restant() > 0.0, "coup de siège : le gel visuel")
	verifier(_a.particules_actives() >= 1, "des débris")
	var total: int = 12
	var rang: int = _rang_du_pic("explosion_feu", int(PIC["explosion_feu"]), total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])


func test_le_baril_s_efface_et_mouvement_reduit_sans_particule_ni_gel_ni_rotation() -> void:
	_a.impacter("baril", CIBLE, 70.0, true)
	_avancer(120)
	verifier_egal(_a.nombre_vivants(), 0)
	verifier_egal(_a.particules_actives(), 0)
	_a.mouvement_reduit = true
	_a.tirer("baril", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
	verifier_egal(_a.etats("baril")[0]["rotation"], 0.0, "il ne tourne pas")
	_a.impacter("baril", CIBLE, 70.0, true)
	verifier_egal(_a.particules_actives(), 0, "sans particule")
	verifier_egal(_a.gel_restant(), 0.0, "sans gel")
	verifier(_a.etats("explosion_feu").size() > 0, "l'explosion reste")


# --- Maillet de rempart : zone --------------------------------------------------------------------


func test_le_maillet_est_une_zone_de_siege_sans_statut() -> void:
	_verifier_arme("maillet_de_rempart", "maillet", "zone")
	verifier_egal(_statut("maillet_de_rempart"), "", "aucun statut")


func test_le_maillet_est_lance_en_cloche_en_tournant_et_arrive_en_quatorze_images() -> void:
	verifier_proche(_a.tirer("maillet", TOUR, CIBLE) / IMAGE, 14.0, 0.01, "3 + 11 images")
	verifier_egal(_a.etats("ombre").size(), 1, "l'ombre suit la cloche")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
	var maillet: Dictionary = _a.etats("maillet")[0]
	verifier(maillet["visible"], "il vole")
	verifier(absf(maillet["rotation"]) > 0.05, "il tourne sur lui-même")
	verifier(maillet["position"].y < CIBLE.y - 10.0, "il passe au-dessus de la ligne de tir")


func test_l_onde_de_choc_du_maillet_est_au_rayon_reel_avec_un_gel_d_impact() -> void:
	var rayon: float = _rayon_px("maillet_de_rempart")
	verifier(_a.impacter("maillet", CIBLE, rayon, true))
	verifier_proche(_a.etats("onde_choc")[0]["diametre"], rayon * 2.0, rayon * 0.2, "au rayon")
	verifier_egal(_a.etats("").size(), 1, "un anneau fin")
	verifier_proche(_a.etats("")[0]["diametre"], rayon * 2.0, 0.5, "anneau au rayon exact")
	verifier(_a.gel_restant() > 0.0, "coup de siège : le gel visuel")
	verifier(_a.particules_actives() >= 1, "de la poussière")
	var total: int = 12
	var rang: int = _rang_du_pic("onde_choc", int(PIC["onde_choc"]), total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])


func test_le_maillet_dans_effets_ne_dessine_que_son_onde() -> void:
	var effets: Effets = _effets_neuf()
	effets.ajouter(_evenement("maillet_de_rempart", "tir"))
	effets.ajouter(_evenement("maillet_de_rempart", "impact"))
	for _i: int in 20:
		effets.avancer(IMAGE)
	verifier(_pic_de(effets, "onde_choc", 30) > 0, "l'onde de choc du maillet")
	verifier_faux(effets.formes_vivantes().has("explosion"), "pas d'explosion du pack en plus")
	effets.free()


func test_mouvement_reduit_le_maillet_sans_particule_ni_gel_ni_rotation() -> void:
	_a.mouvement_reduit = true
	_a.tirer("maillet", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
	verifier_egal(_a.etats("maillet")[0]["rotation"], 0.0, "il ne tourne pas")
	_a.impacter("maillet", CIBLE, 60.0, true)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.gel_restant(), 0.0)
	verifier(_a.etats("onde_choc").size() > 0, "l'onde reste")
	_avancer(120)
	verifier_egal(_a.nombre_vivants(), 0)


# --- Catapulte à contrepoids : cible unique -------------------------------------------------------


func test_la_catapulte_est_une_cible_unique_de_siege_sans_statut() -> void:
	_verifier_arme("catapulte_a_contrepoids", "catapulte", "cible_unique")
	verifier_egal(_statut("catapulte_a_contrepoids"), "", "aucun statut")


func test_la_pierre_lestee_est_lancee_en_cloche_et_arrive_en_quatorze_images() -> void:
	verifier_proche(_a.tirer("catapulte", TOUR, CIBLE) / IMAGE, 14.0, 0.01, "3 + 11 images")
	verifier_egal(_a.etats("ombre").size(), 1, "l'ombre suit la cloche")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 6)
	var pierre: Dictionary = _a.etats("pierre_lestee")[0]
	verifier(pierre["visible"], "elle vole")
	verifier(pierre["position"].y < CIBLE.y - 10.0, "elle passe au-dessus de la ligne de tir")
	_avancer(10)
	verifier_egal(_a.etats("pierre_lestee").size(), 0, "arrivée, elle disparaît")


func test_le_cratere_de_la_catapulte_reste_petit_sur_une_cible_seule_et_gele() -> void:
	verifier(_a.impacter("catapulte", CIBLE, 0.0, true))
	var cratere: Dictionary = _a.etats("cratere")[0]
	verifier(cratere["diametre"] <= DIAMETRE_MAX_CIBLE_UNIQUE, "au plus 60 px sur une cible seule")
	verifier_egal(_a.etats("").size(), 0, "pas d'anneau : la zone est la cible")
	verifier(_a.gel_restant() > 0.0, "coup de siège : le gel visuel")
	verifier(_a.particules_actives() >= 1, "des éclats de pierre")
	var total: int = 12
	var rang: int = _rang_du_pic("cratere", int(PIC["cratere"]), total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])


func test_la_catapulte_dans_effets_attend_la_pierre_puis_frappe_sans_explosion_du_pack() -> void:
	var effets: Effets = _effets_neuf()
	effets.ajouter(_evenement("catapulte_a_contrepoids", "tir"))
	effets.ajouter(_evenement("catapulte_a_contrepoids", "impact"))
	verifier_egal(effets.elementaires().etats("cratere").size(), 0, "le cratère attend la pierre")
	verifier(_pic_de(effets, "cratere", 30) > 0, "le cratère à l'arrivée")
	verifier_faux(effets.formes_vivantes().has("explosion"), "pas d'explosion du pack")
	effets.free()


func test_mouvement_reduit_la_catapulte_sans_particule_ni_gel() -> void:
	_a.mouvement_reduit = true
	_a.tirer("catapulte", TOUR, CIBLE)
	_a.impacter("catapulte", CIBLE, 0.0, true)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.gel_restant(), 0.0)
	verifier(_a.etats("cratere").size() > 0, "le cratère reste")
	_avancer(120)
	verifier_egal(_a.nombre_vivants(), 0)
