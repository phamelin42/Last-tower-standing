extends CasAttaquesTranchant
## Les armes tranchantes du lot 9 (D22), seconde moitié : fléau de rasoirs, hache de garde, scie à
## ruban, moissonneuse d'acier. Mêmes phases et mêmes bornes que l'acier du lot 8.

# --- Fléau de rasoirs : rebond, vulnérabilité --------------------------------------------------


func test_le_fleau_est_un_rebond_qui_rend_vulnerable() -> void:
	_verifier_arme("fleau_de_rasoirs", "fleau", "rebond")
	verifier_egal(String(_donnees.armes["fleau_de_rasoirs"]["statuts"][0]["kind"]), "vulnerabilite")


func test_le_fleau_dure_dix_images_et_ses_rasoirs_tournent() -> void:
	verifier_proche(_a.tirer("fleau", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var avant: float = _a.etats("rasoir")[0]["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("rasoir")[0]["rotation"] - avant) > 0.3, "il tourne en volant")


func test_un_saut_du_fleau_est_un_vol_de_sept_images_sans_anticipation() -> void:
	var fin: float = _a.saut("fleau", CIBLE, CIBLE + Vector2(90.0, 20.0), 4.0 * IMAGE)
	verifier_proche(fin / IMAGE, 4.0 + AttaquesElementaires.IMAGES_VOL_DIRECT, 0.01)
	verifier_egal(_a.etats("depart").size(), 0, "pas d'anticipation à chaque saut")
	verifier_faux(_a.etats("rasoir")[0]["visible"], "il attend la fin du saut précédent")
	_avancer(5)
	verifier(_a.etats("rasoir")[0]["visible"], "il vole")
	_avancer(10)
	verifier_egal(_a.nombre_vivants(), 0, "arrivé, il disparaît")


func test_chaque_saut_du_fleau_mord_petit_avec_un_eclat_d_acier() -> void:
	_a.impacter("fleau", CIBLE, 0.0)
	verifier_egal(_a.etats("eclat_acier").size(), 1, "un éclat d'acier")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier_egal(_a.particules_actives(), 1, "des étincelles")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")


func test_le_fleau_dans_effets_envoie_un_rasoir_par_saut() -> void:
	var effets: Effets = _effets_de("fleau_de_rasoirs")
	verifier_egal(effets.elementaires().etats("rasoir").size(), 3, "un tir puis deux sauts")
	effets.free()


func test_mouvement_reduit_le_fleau_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("fleau", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var avant: int = _a.etats("rasoir")[0]["image"]
	verifier_proche(_a.etats("rasoir")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_avancer(2)
	verifier_egal(_a.etats("rasoir")[0]["image"], avant, "image fixe")
	_a.impacter("fleau", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)


# --- Hache de garde : aura, malédiction --------------------------------------------------------


func test_la_hache_est_une_aura() -> void:
	_verifier_arme("hache_de_garde", "hache", "aura")


func test_la_hache_n_a_pas_de_projectile() -> void:
	verifier_egal(AttaquesElementaires.planche_projectile("hache"), "", "rien ne part de la tour")


func test_quatre_haches_atteignent_le_rayon_reel_de_l_aura() -> void:
	var rayon: float = _rayon_px("hache_de_garde")
	verifier(_a.aura("hache", TOUR, rayon))
	verifier_egal(_a.etats("hache").size(), 4, "quatre haches")
	_avancer(AttaquesElementaires.IMAGES_COURONNE_OUVERTURE)
	var portee_max: float = 0.0
	for fer: Dictionary in _a.etats("hache"):
		var d: float = (fer["position"] as Vector2).distance_to(TOUR)
		portee_max = maxf(portee_max, d + fer["taille"].y * 0.5)
		verifier(d < rayon, "le centre de la hache est dans la zone")
	verifier_proche(portee_max, rayon, rayon * 0.1, "le bord extérieur est au rayon")
	verifier(_a.diametre_max() <= rayon * 2.0 * 1.1, "rien au-delà de la zone")
	verifier_egal(_a.etats("").size(), 1, "un anneau fin au rayon exact")


func test_la_hache_s_efface_et_rend_le_pool() -> void:
	_a.aura("hache", TOUR, 140.0)
	_avancer(AttaquesElementaires.IMAGES_COURONNE + 1)
	verifier_egal(_a.nombre_vivants(), 0)
	verifier_egal(_a.particules_actives(), 0)


func test_la_hache_dans_effets_se_dessine_a_chaque_coup_de_l_aura() -> void:
	var effets: Effets = _effets_de("hache_de_garde")
	verifier_egal(effets.elementaires().etats("hache").size(), 4, "quatre haches")
	verifier_egal(effets.formes_vivantes().has("anneau"), false, "plus d'anneau générique")
	effets.free()


func test_mouvement_reduit_la_hache_garde_ses_fers_sans_tourner() -> void:
	_a.mouvement_reduit = true
	_a.aura("hache", TOUR, 140.0)
	_avancer(3)
	var avant: Array[Dictionary] = _a.etats("hache")
	_avancer(3)
	var apres: Array[Dictionary] = _a.etats("hache")
	verifier_egal(apres.size(), 4, "les haches restent")
	verifier_proche(
		((avant[0]["position"] as Vector2) - TOUR).angle(),
		((apres[0]["position"] as Vector2) - TOUR).angle(),
		0.0001,
		"elles ne tournent pas"
	)


# --- Scie à ruban : barrage, poison ------------------------------------------------------------


func test_la_scie_est_un_barrage_qui_empoisonne() -> void:
	_verifier_arme("scie_a_ruban", "scie", "barrage")
	verifier_egal(String(_donnees.armes["scie_a_ruban"]["statuts"][0]["kind"]), "poison")
	verifier_egal(int(_effet("scie_a_ruban")["projectiles"]), 6, "six projectiles")


func test_chaque_disque_de_la_scie_part_deux_images_apres_le_precedent() -> void:
	var retard: float = AttaquesElementaires.RETARD_BARRAGE
	var premiere: float = _a.tirer("scie", TOUR, CIBLE, 0.0)
	var seconde: float = _a.tirer("scie", TOUR, CIBLE, retard)
	verifier_proche(premiere / IMAGE, 10.0, 0.01, "anticipation + vol")
	verifier_proche((seconde - premiere) / IMAGE, 2.0, 0.01, "décalés de 2 images")
	verifier_egal(_a.etats("disque_scie").size(), 2, "un disque par tir")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	var avant: float = _a.etats("disque_scie")[0]["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("disque_scie")[0]["rotation"] - avant) > 0.5, "il tourne vite")


func test_un_seul_anneau_au_rayon_reel_pour_tout_le_barrage_de_la_scie() -> void:
	var rayon: float = _rayon_px("scie_a_ruban")
	for k: int in 6:
		_a.impacter_en_groupe("scie", CIBLE + Vector2(0.0, k * 6.0), rayon)
	verifier_egal(_a.etats("").size(), 0, "aucun anneau par disque")
	_a.zone("scie", CIBLE, rayon)
	verifier_egal(_a.etats("").size(), 1, "un anneau pour le tir")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1, "au rayon réel")


func test_chaque_impact_de_la_scie_est_petit_avec_etincelles_et_gouttes() -> void:
	_a.impacter_en_groupe("scie", CIBLE, 30.0)
	verifier_egal(_a.etats("eclat_acier").size(), 1, "un éclat d'acier")
	verifier(_a.etats("eclat_acier")[0]["diametre"] <= 60.0, "reste petit")
	verifier_egal(_a.particules_actives(), 2, "étincelles grises et gouttes vertes")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_la_scie_dans_effets_lance_un_disque_par_impact_et_un_seul_anneau() -> void:
	var effets: Effets = _effets_de("scie_a_ruban")
	verifier_egal(effets.elementaires().etats("disque_scie").size(), 4, "quatre disques")
	var anneaux: int = 0
	for _i: int in 40:
		effets.avancer(IMAGE)
		anneaux = maxi(anneaux, effets.elementaires().etats("").size())
	verifier_egal(anneaux, 1, "un seul anneau")
	effets.free()


func test_mouvement_reduit_la_scie_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("scie", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	verifier_proche(_a.etats("disque_scie")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_a.impacter_en_groupe("scie", CIBLE, 30.0)
	verifier_egal(_a.particules_actives(), 0)


# --- Moissonneuse d'acier : tir tournant à six branches ----------------------------------------


func test_la_moissonneuse_est_un_tir_tournant_a_six_branches() -> void:
	_verifier_arme("moissonneuse_d_acier", "moissonneuse", "tournant")
	verifier_egal(int(_effet("moissonneuse_d_acier")["branches"]), 6, "six branches")


func test_la_moissonneuse_dure_dix_images_et_ses_faucilles_tournent() -> void:
	verifier_proche(_a.tirer("moissonneuse", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var faucille: Dictionary = _a.etats("faucille")[0]
	verifier(faucille["visible"], "la faucille vole")
	var avant: float = faucille["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("faucille")[0]["rotation"] - avant) > 0.3, "elle tourne en volant")


func test_le_balayage_de_la_moissonneuse_a_la_largeur_reelle_du_rayon() -> void:
	var largeur: float = _rayon_px("moissonneuse_d_acier", "largeur")
	_a.impacter("moissonneuse", CIBLE, largeur)
	var balayage: Array[Dictionary] = _a.etats("balayage")
	verifier_egal(balayage.size(), 1, "un seul arc")
	verifier_proche(balayage[0]["diametre"], largeur * 2.0, largeur * 2.0 * 0.1, "à la largeur")
	verifier_proche(_a.diametre_max(), largeur * 2.0, largeur * 2.0 * 0.1)
	verifier_egal(_a.particules_actives(), 1, "des éclats d'acier")
	_avancer(80)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_la_moissonneuse_dans_effets_file_sur_ses_six_rayons_et_balaye_au_bout() -> void:
	_verifier_tournant_dans_effets("moissonneuse_d_acier", "faucille", "balayage")


func test_mouvement_reduit_la_moissonneuse_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("moissonneuse", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	verifier_proche(_a.etats("faucille")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_a.impacter("moissonneuse", CIBLE, 30.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("balayage").size(), 1, "l'arc reste")
