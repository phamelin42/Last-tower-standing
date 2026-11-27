extends CasAttaquesSiegeLot9
## Les armes de siège du lot 9 (D22), seconde moitié : écrasement de tour, champ de ruines, salve du
## rempart, colosse de pierre, puis les neuf ensemble. Mêmes phases et mêmes bornes que les armes de
## siège du lot 8. Durées en images à 60 i/s.

var _impacts_visibles: int = 0

# --- Écrasement de tour : cible unique, étourdissement --------------------------------------------


func test_l_ecrasement_est_une_cible_unique_de_siege_qui_etourdit() -> void:
	_verifier_arme("ecrasement_de_tour", "ecrasement", "cible_unique")
	verifier_egal(_statut("ecrasement_de_tour"), "etourdissement")


func test_le_creneau_est_lance_en_cloche_et_arrive_en_quatorze_images() -> void:
	verifier_proche(_a.tirer("ecrasement", TOUR, CIBLE) / IMAGE, 14.0, 0.01, "3 + 11 images")
	verifier_egal(_a.etats("ombre").size(), 1, "l'ombre suit la cloche")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 6)
	var creneau: Dictionary = _a.etats("creneau")[0]
	verifier(creneau["visible"], "il vole")
	verifier(creneau["position"].y < CIBLE.y - 10.0, "il passe au-dessus de la ligne de tir")
	_avancer(10)
	verifier_egal(_a.etats("creneau").size(), 0, "arrivé, il disparaît")


func test_l_onde_de_l_ecrasement_reste_petite_sur_une_cible_seule_et_gele() -> void:
	verifier(_a.impacter("ecrasement", CIBLE, 0.0, true))
	var onde: Dictionary = _a.etats("onde_choc")[0]
	verifier(onde["diametre"] <= DIAMETRE_MAX_CIBLE_UNIQUE, "au plus 60 px sur une cible seule")
	verifier_egal(_a.etats("").size(), 0, "pas d'anneau : la zone est la cible")
	verifier(_a.gel_restant() > 0.0, "coup de siège : le gel visuel")
	verifier(_a.particules_actives() >= 1, "des gravats")
	var total: int = 12
	var rang: int = _rang_du_pic("onde_choc", int(PIC["onde_choc"]), total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])


func test_mouvement_reduit_l_ecrasement_sans_particule_ni_gel() -> void:
	_a.mouvement_reduit = true
	_a.tirer("ecrasement", TOUR, CIBLE)
	_a.impacter("ecrasement", CIBLE, 0.0, true)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.gel_restant(), 0.0)
	verifier(_a.etats("onde_choc").size() > 0, "l'onde reste")
	_avancer(120)
	verifier_egal(_a.nombre_vivants(), 0)


# --- Colosse de pierre : cible unique, vulnérabilité et étourdissement ----------------------------


func test_le_colosse_est_une_cible_unique_de_siege_qui_rend_vulnerable_puis_etourdit() -> void:
	_verifier_arme("colosse_de_pierre", "colosse", "cible_unique")
	var statuts: Array = _donnees.armes["colosse_de_pierre"]["statuts"]
	verifier_egal(String(statuts[0]["kind"]), "vulnerabilite")
	verifier_egal(String(statuts[1]["kind"]), "etourdissement")


func test_le_bloc_du_colosse_est_le_plus_gros_projectile_et_arrive_en_quatorze_images() -> void:
	verifier_proche(_a.tirer("colosse", TOUR, CIBLE) / IMAGE, 14.0, 0.01, "3 + 11 images")
	verifier_egal(_a.etats("ombre").size(), 1, "l'ombre suit la cloche")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 6)
	var bloc: Dictionary = _a.etats("bloc_colosse")[0]
	verifier(bloc["visible"], "il vole")
	verifier(bloc["position"].y < CIBLE.y - 10.0, "il passe au-dessus de la ligne de tir")
	_a.vider()
	_a.tirer("catapulte", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 6)
	verifier(
		bloc["taille"].x > _a.etats("pierre_lestee")[0]["taille"].x,
		"plus gros que la pierre lestée"
	)


func test_l_impact_du_colosse_est_un_cratere_et_une_onde_petits_avec_le_gel_de_siege() -> void:
	verifier(_a.impacter("colosse", CIBLE, 0.0, true))
	verifier_egal(_a.etats("cratere").size(), 1, "un cratère")
	verifier_egal(_a.etats("onde_choc").size(), 1, "et une onde de choc")
	verifier(_a.diametre_max() <= DIAMETRE_MAX_CIBLE_UNIQUE, "au plus 60 px sur une cible seule")
	verifier(_a.gel_restant() > 0.0, "coup de siège : le gel visuel")
	verifier(_a.particules_actives() >= 1, "des éclats de pierre")
	var total: int = 12
	var rang: int = _rang_du_pic("cratere", int(PIC["cratere"]), total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])


func test_mouvement_reduit_le_colosse_sans_particule_ni_gel_ni_rotation() -> void:
	_a.mouvement_reduit = true
	_a.tirer("colosse", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
	verifier_egal(_a.etats("bloc_colosse")[0]["rotation"], 0.0, "il ne tourne pas")
	_a.impacter("colosse", CIBLE, 0.0, true)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.gel_restant(), 0.0)
	_avancer(120)
	verifier_egal(_a.nombre_vivants(), 0)


# --- Champ de ruines : zone posée, vulnérabilité --------------------------------------------------


func test_le_champ_de_ruines_est_une_zone_posee_de_siege_qui_rend_vulnerable() -> void:
	_verifier_arme("champ_de_ruines", "ruines", "zone_posee")
	verifier_egal(_statut("champ_de_ruines"), "vulnerabilite")


func test_le_tas_de_gravats_est_lance_en_cloche_et_arrive_en_quatorze_images() -> void:
	verifier_proche(_a.tirer("ruines", TOUR, CIBLE) / IMAGE, 14.0, 0.01, "3 + 11 images")
	verifier_egal(_a.etats("ombre").size(), 1, "l'ombre suit la cloche")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 6)
	var gravats: Dictionary = _a.etats("gravats")[0]
	verifier(gravats["visible"], "il vole")
	verifier(gravats["position"].y < CIBLE.y - 10.0, "il passe au-dessus de la ligne de tir")
	verifier(_a.particules_actives() >= 1, "de la poussière dans le sillage")


func test_chaque_impulsion_des_ruines_est_petite_au_rayon_reel_et_ne_gele_pas() -> void:
	var rayon: float = _rayon_px("champ_de_ruines")
	verifier(_a.impacter("ruines", CIBLE, rayon, true))
	verifier(_a.etats("cratere")[0]["diametre"] <= 70.0, "le cœur reste petit")
	verifier_egal(_a.etats("").size(), 1, "un anneau fin")
	verifier_proche(_a.etats("")[0]["diametre"], rayon * 2.0, 0.5, "anneau au rayon exact")
	verifier_egal(_a.gel_restant(), 0.0, "une impulsion est un tic, pas un coup")
	verifier(_a.particules_actives() >= 1, "des gravats")
	var total: int = 12
	var rang: int = _rang_du_pic("cratere", int(PIC["cratere"]), total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])


func test_le_disque_au_sol_des_ruines_est_dans_sa_fiche() -> void:
	var el: AttaqueElement = AttaquesElementaires.registre()["ruines"]
	verifier_egal(String(el.conf()["disque"]), "disque_ruines")
	verifier(AttaquesElementaires.planches().has("disque_ruines"), "planche déclarée")
	verifier(AttaquesElementaires.visible_de("disque_ruines") > 0.0, "diamètre visible connu")


func test_les_ruines_dans_effets_pulsent_sans_gel_ni_recul() -> void:
	var effets: Effets = _effets_neuf()
	var forts: Array[bool] = []
	effets.impact_visible.connect(
		func(_ou: Vector2, _r: float, fort: bool) -> void: forts.append(fort)
	)
	effets.ajouter(_evenement("champ_de_ruines", "tir"))
	effets.ajouter(_evenement("champ_de_ruines", "impact"))
	verifier(_pic_de(effets, "cratere", 40) > 0, "le cœur de gravats de l'impulsion")
	verifier_egal(forts.size(), 1, "une impulsion, un impact visible")
	verifier_faux(forts[0], "pas un coup fort")
	verifier_egal(effets.gel_restant(), 0.0, "pas de gel")
	effets.free()


func test_mouvement_reduit_les_ruines_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("ruines", TOUR, CIBLE)
	_a.impacter("ruines", CIBLE, 130.0, false)
	verifier_egal(_a.particules_actives(), 0)
	verifier(_a.etats("cratere").size() > 0, "le cœur reste")
	_avancer(120)
	verifier_egal(_a.nombre_vivants(), 0)
