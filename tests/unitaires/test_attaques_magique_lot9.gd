extends CasAttaquesMagique
## Les armes magiques du lot 9 (D22), première moitié : rune de veille, éclat siphonneur, lueur
## vagabonde, prisme de faille, orage en cage. Mêmes phases et mêmes bornes que les armes du lot 8
## (anticipation 3 images, vol direct 7 ou en cloche 11, impact au pic dans le premier quart, zone
## au rayon réel lu dans `data/armes.json`). Durées en images à 60 i/s.

# --- Rune de veille : zone posée -----------------------------------------------------------------


func test_la_rune_de_veille_est_une_zone_posee_sans_statut() -> void:
	_verifier_arme("rune_de_veille", "rune_veille", "zone_posee")
	verifier_egal(_statut("rune_de_veille"), "", "aucun statut")


func test_la_rune_est_lancee_en_cloche_et_arrive_en_quatorze_images() -> void:
	verifier_proche(_a.tirer("rune_veille", TOUR, CIBLE) / IMAGE, 14.0, 0.01, "3 + 11 images")
	verifier_egal(_a.etats("ombre").size(), 1, "l'ombre suit la cloche")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 6)
	var rune: Dictionary = _a.etats("rune")[0]
	verifier(rune["visible"], "elle vole")
	verifier(rune["position"].y < CIBLE.y - 10.0, "elle passe au-dessus de la ligne de tir")
	verifier(_a.particules_actives() >= 1, "une traînée")
	_avancer(10)
	verifier_egal(_a.etats("rune").size(), 0, "arrivée, elle disparaît")


func test_la_rune_pose_son_eclat_petit_et_un_anneau_au_rayon_reel_de_la_zone() -> void:
	var rayon: float = _rayon_px("rune_de_veille")
	verifier(_a.impacter("rune_veille", CIBLE, rayon))
	var eclat: Dictionary = _a.etats("eclat_rune")[0]
	verifier(eclat["taille"].x <= 60.0, "l'éclat reste petit : le disque est dessiné par la vue")
	verifier_egal(_a.etats("").size(), 1, "un anneau fin")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1, "au rayon réel")
	verifier(_a.particules_actives() >= 1, "quelques éclats")


func test_l_eclat_de_la_rune_est_au_pic_dans_le_premier_quart() -> void:
	_a.impacter("rune_veille", CIBLE, 75.0)
	var total: int = AttaqueRuneVeille.SEQ_ECLAT.size()
	var rang: int = _rang_du_pic("eclat_rune", AttaqueRuneVeille.IMAGE_PIC, total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])


func test_la_rune_s_efface_et_rend_le_pool_et_mouvement_reduit_sans_particule() -> void:
	_a.impacter("rune_veille", CIBLE, 75.0)
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0)
	verifier_egal(_a.particules_actives(), 0)
	_a.mouvement_reduit = true
	_a.tirer("rune_veille", TOUR, CIBLE)
	_a.impacter("rune_veille", CIBLE, 75.0)
	verifier_egal(_a.particules_actives(), 0, "sans particule")
	verifier(_a.etats("eclat_rune").size() > 0, "l'éclat reste")


func test_la_rune_dans_effets_ne_dessine_plus_l_anneau_generique_de_la_zone() -> void:
	var effets: Effets = _effets_de("rune_de_veille")
	verifier_egal(effets.elementaires().etats("rune").size(), 1, "la rune vole")
	verifier(_pic_de(effets, "eclat_rune", 40) > 0, "l'éclat de la rune à l'arrivée")
	verifier_faux(effets.formes_vivantes().has("anneau"), "plus d'anneau générique")
	effets.free()


# --- Éclat siphonneur : cible unique, siphon de mana ---------------------------------------------


func test_l_eclat_siphonneur_est_une_cible_unique_qui_siphonne_la_mana() -> void:
	_verifier_arme("eclat_siphonneur", "siphonneur", "cible_unique")
	verifier_egal(_statut("eclat_siphonneur"), "siphon")


func test_l_eclat_siphonneur_dure_dix_images_et_file_droit_derriere_une_traine_violette() -> void:
	verifier_proche(_a.tirer("siphonneur", TOUR, CIBLE) / IMAGE, 10.0, 0.01, "3 + 7 images")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
	var orbe: Dictionary = _a.etats("siphon")[0]
	verifier(orbe["visible"], "il vole")
	verifier_proche(orbe["position"].y, CIBLE.y, 1.0, "droit, sans arc")
	verifier(_a.particules_actives() >= 1, "une traînée")
	verifier_egal(_a.etats("ombre").size(), 0, "pas d'ombre : pas de cloche")


func test_le_siphon_se_resserre_sur_la_cible_et_garde_la_marque_d_effets() -> void:
	verifier(_a.impacter("siphonneur", CIBLE, 0.0))
	verifier_egal(_a.etats("eclat_siphon").size(), 1, "un éclat")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier_egal(_a.etats("").size(), 0, "pas d'anneau : la marque de siphon est celle d'Effets")
	verifier(_a.particules_actives() >= 1, "des volutes")
	var total: int = AttaqueSiphonneur.SEQ_ECLAT.size()
	var rang: int = _rang_du_pic("eclat_siphon", AttaqueSiphonneur.IMAGE_PIC, total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])
	_avancer(total + 30)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_mouvement_reduit_l_eclat_siphonneur_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("siphonneur", TOUR, CIBLE)
	_a.impacter("siphonneur", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("eclat_siphon").size(), 1, "l'éclat reste")


# --- Lueur vagabonde : tir tournant de trois branches --------------------------------------------


func test_la_lueur_vagabonde_est_un_tir_tournant_de_trois_branches() -> void:
	_verifier_arme("lueur_vagabonde", "lueur", "tournant")
	verifier_egal(int(_effet("lueur_vagabonde")["branches"]), 3, "trois branches")
	verifier_egal(_statut("lueur_vagabonde"), "", "aucun statut")


func test_chaque_lueur_file_droit_le_long_de_son_rayon_en_dix_images() -> void:
	var bout: Vector2 = TOUR + Vector2.from_angle(deg_to_rad(120.0)) * 250.0
	verifier_proche(_a.tirer("lueur", TOUR, bout) / IMAGE, 10.0, 0.01, "3 + 7 images")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 7)
	var lueur: Dictionary = _a.etats("lueur")[0]
	verifier_proche(lueur["rotation"], deg_to_rad(120.0), 0.01, "elle regarde vers le bout")
	verifier_egal(_a.etats("ombre").size(), 0, "pas d'ombre")


func test_le_bout_du_rayon_a_la_largeur_du_rayon_et_ne_dit_pas_touche() -> void:
	var largeur: float = _rayon_px("lueur_vagabonde", "largeur")
	verifier(_a.impacter("lueur", CIBLE, largeur))
	var eclat: Dictionary = _a.etats("eclat_rune")[0]
	verifier_proche(eclat["diametre"], largeur * 2.0, 0.01, "à la largeur du rayon")
	verifier(_a.diametre_max() <= 60.0, "petit")
	verifier_egal(_a.etats("").size(), 0, "pas d'anneau : les rayons sont ceux d'Effets")
	var total: int = AttaqueLueur.SEQ_ECLAT.size()
	var rang: int = _rang_du_pic("eclat_rune", AttaqueLueur.IMAGE_PIC, total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])
	_avancer(total + 30)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_la_lueur_dans_effets_envoie_une_lueur_par_branche() -> void:
	var effets: Effets = _effets_de("lueur_vagabonde")
	verifier_egal(effets.elementaires().etats("lueur").size(), 3, "trois lueurs")
	effets.free()


func test_mouvement_reduit_la_lueur_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("lueur", TOUR, CIBLE)
	_a.impacter("lueur", CIBLE, 25.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("eclat_rune").size(), 1, "l'éclat reste")
