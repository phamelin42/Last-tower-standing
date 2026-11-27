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


# --- Salve du rempart : bombe, brûlure ------------------------------------------------------------


func test_la_salve_est_une_bombe_de_siege_qui_brule() -> void:
	_verifier_arme("salve_du_rempart", "salve", "bombe")
	verifier_egal(_statut("salve_du_rempart"), "brulure")


func test_la_bombe_de_la_salve_est_lancee_en_cloche_teintee_et_arrive_en_quatorze_images() -> void:
	verifier_proche(_a.tirer("salve", TOUR, CIBLE) / IMAGE, 14.0, 0.01, "3 + 11 images")
	verifier_egal(_a.etats("ombre").size(), 1, "l'ombre suit la cloche")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 6)
	var bombe: Dictionary = _a.etats("bombe")[0]
	verifier(bombe["visible"], "elle vole")
	verifier(bombe["teinte"] != Color.WHITE, "teintée : on ne la prend pas pour une autre bombe")
	verifier(bombe["position"].y < CIBLE.y - 10.0, "elle passe au-dessus de la ligne de tir")


func test_la_salve_n_explose_pas_a_la_pose_et_explose_une_seule_fois_a_l_impact() -> void:
	var effets: Effets = _effets_neuf()
	effets.ajouter(_evenement("salve_du_rempart", "tir"))
	for _i: int in 40:
		effets.avancer(IMAGE)
	verifier_egal(effets.elementaires().etats("pop_petard").size(), 0, "rien à la pose")
	verifier_faux(effets.formes_vivantes().has("explosion"), "pas d'explosion du pack à la pose")
	effets.ajouter(_evenement("salve_du_rempart", "impact"))
	verifier(effets.elementaires().etats("pop_petard").size() > 0, "la salve de pops")
	verifier_faux(effets.formes_vivantes().has("explosion"), "jamais deux explosions")
	verifier_faux(AttaquesElementaires.explosion_du_pack("salve"), "l'élément porte l'explosion")
	effets.free()


func test_la_salve_eclate_en_pops_dont_aucun_ne_depasse_le_rayon_reel_et_gele() -> void:
	var rayon: float = _rayon_px("salve_du_rempart")
	verifier(_a.impacter("salve", CIBLE, rayon, true))
	verifier(_a.etats("pop_petard").size() > 1, "plusieurs pops : une salve")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 0.2, "le plus grand est au rayon")
	verifier(_a.gel_restant() > 0.0, "coup de siège : le gel visuel")
	_avancer(10)
	var visibles: int = 0
	for pop: Dictionary in _a.etats("pop_petard"):
		if not pop["visible"]:
			continue
		visibles += 1
		var d: float = (pop["position"] as Vector2).distance_to(CIBLE) + pop["diametre"] * 0.5
		verifier(d <= rayon + 1.0, "tout reste dans le rayon réel")
	verifier(visibles > 1, "la salve est sortie")


func test_le_grand_pop_de_la_salve_est_au_pic_dans_le_premier_quart() -> void:
	_a.impacter("salve", CIBLE, 100.0, true)
	var total: int = 12
	var rang: int = _rang_du_pic("pop_petard", int(PIC["pop_petard"]), total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])


func test_mouvement_reduit_la_salve_sans_particule_ni_gel() -> void:
	_a.mouvement_reduit = true
	_a.tirer("salve", TOUR, CIBLE)
	_a.impacter("salve", CIBLE, 100.0, true)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.gel_restant(), 0.0)
	verifier(_a.etats("pop_petard").size() > 0, "les pops restent")
	_avancer(120)
	verifier_egal(_a.nombre_vivants(), 0)


# --- Les neuf armes : en jeu, plafond, impacts, bombes et vue -------------------------------------


func test_les_neuf_armes_de_siege_ont_chacune_leur_element_et_leurs_planches() -> void:
	var vus: Dictionary = {}
	for id: String in ARMES:
		var element: String = String(ARMES[id])
		verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
		verifier_faux(vus.has(element), "%s : élément partagé" % id)
		vus[element] = true
		verifier(SignaturesArmes.en_jeu(id), "%s : en jeu" % id)
		var el: AttaqueElement = AttaquesElementaires.registre()[element]
		for planche: String in el.planches():
			verifier(
				ResourceLoader.exists("%s%s.png" % [AttaquesElementaires.DOSSIER, planche]),
				"%s : planche %s" % [id, planche]
			)
	verifier_egal(vus.size(), 9, "neuf armes")


func test_deux_armes_de_siege_ne_produisent_jamais_le_meme_rendu() -> void:
	var ids: Array = ARMES.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: Dictionary = _fiche(String(ARMES[ids[i]]))
			var b: Dictionary = _fiche(String(ARMES[ids[j]]))
			var meme: bool = (
				a["projectile"] == b["projectile"]
				and a.get("teinte", Color.WHITE) == b.get("teinte", Color.WHITE)
				and a["cloche"] == b["cloche"]
			)
			verifier_faux(meme, "%s et %s : même projectile" % [ids[i], ids[j]])


func _fiche(element: String) -> Dictionary:
	var el: AttaqueElement = AttaquesElementaires.registre()[element]
	return el.conf()


func _noter_impact(_ou: Vector2, _rayon: float, _fort: bool) -> void:
	_impacts_visibles += 1


## Un impact visible n'est émis que pour un coup que la simulation émet : un tir de bombe ou de zone
## posée (la pose) n'en émet aucun, l'explosion ou l'impulsion en émet un.
func test_une_arme_de_siege_n_emet_un_impact_visible_que_par_evenement_d_impact() -> void:
	for id: String in ARMES:
		_impacts_visibles = 0
		var effets: Effets = _effets_neuf()
		effets.impact_visible.connect(_noter_impact)
		var vitrine: VitrineArmes = VitrineArmes.new()
		vitrine.armes = [id] as Array[String]
		var attendus: int = 0
		for evenement: Dictionary in vitrine.evenements_du_cycle(id):
			attendus += 1 if String(evenement["k"]) == "impact" else 0
			effets.ajouter(evenement)
		vitrine.free()
		for _i: int in 60:
			effets.avancer(IMAGE)
		verifier_egal(_impacts_visibles, attendus, "%s : un impact par événement d'impact" % id)
		effets.free()


func test_aucun_effet_de_siege_ne_depasse_le_plafond_ni_l_opacite_maximale() -> void:
	for id: String in ARMES:
		var element: String = String(ARMES[id])
		var rayon: float = _rayon_px(id) if _effet(id).has("rayon") else 0.0
		for _tour: int in 30:
			_a.tirer(element, TOUR, CIBLE)
			_a.impacter(element, CIBLE, rayon, true)
			_a.impacter_en_groupe(element, CIBLE, rayon, true)
			_a.zone(element, CIBLE, rayon)
		_avancer(4)
		verifier(_a.nombre_vivants() <= _a.place, "%s : plafond" % id)
		verifier(_a.opacite_max() <= AttaquesElementaires.ALPHA_MAX + 0.0001, "%s : opacité" % id)
		_a.vider()


## La bombe se pose là où le projectile retombe : la vue la dessine à la position de l'événement.
func test_le_projectile_d_une_bombe_retombe_ou_la_vue_pose_la_bombe() -> void:
	for id: String in ["baril_a_retardement", "obusier_de_breche", "salve_du_rempart"]:
		var effets: Effets = _effets_neuf()
		var tir: Dictionary = _evenement(id, "tir")
		effets.ajouter(tir)
		var planche: String = AttaquesElementaires.planche_projectile(String(ARMES[id]))
		var duree: float = float(AttaquesElementaires.IMAGES_ANTICIPATION + 11) * IMAGE
		var depart: float = AttaquesElementaires.IMAGES_ANTICIPATION * IMAGE
		var avance: float = 0.0
		var dernier: Vector2 = Vector2.ZERO
		while avance < duree - IMAGE:
			effets.avancer(IMAGE)
			avance += IMAGE
			var etats: Array[Dictionary] = effets.elementaires().etats(planche)
			if avance > depart and not etats.is_empty():
				dernier = etats[0]["position"]
		var vue: VueArene = VueArene.new()
		vue.bombes = [{"pos": tir["vers"], "rayon": float(_effet(id)["rayon"]), "reste": 2.0}]
		var poses: ZonesBombes2D = ZonesBombes2D.new()
		arbre.root.add_child(poses)
		poses.afficher(vue)
		verifier(
			dernier.distance_to(poses.position_bombe(0)) < 40.0,
			"%s : le projectile retombe sur la bombe de la vue" % id
		)
		verifier_egal(effets.elementaires().etats("explosion_feu").size(), 0, "pas d'explosion")
		poses.free()
		effets.free()
