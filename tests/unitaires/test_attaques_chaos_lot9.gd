extends CasAttaquesChaosLot9
## Les neuf armes de chaos du lot 9 (D22) : urne des ombres, pacte de sang, engrenage jumeau,
## serment brisé, archère fantôme, miroir de discorde, coupe d'oubli, légion de cendre, tempête de
## maléfices. Mêmes phases et mêmes bornes que les autres armes : anticipation de 3 images, vol
## direct de 7 images ou en cloche de 11, impact au pic dans le premier quart, zone au rayon réel
## lu dans `data/armes.json`, cible unique de 60 px au plus, plafond d'effets, mouvement réduit.
## Durées en images à 60 i/s. Les genres (aura, rebond, barrage, invocation) sont à la suite.

const SCRIPTS: Array[String] = [
	"attaque_chaos",
	"attaque_urne",
	"attaque_pacte",
	"attaque_jumeau",
	"attaque_serment",
	"attaque_archere",
	"attaque_discorde",
	"attaque_coupe",
	"attaque_legion",
	"attaque_malefices",
]


func test_chaque_arme_de_chaos_a_son_element_son_genre_et_est_en_jeu() -> void:
	var vus: Dictionary = {}
	for id: String in ARMES:
		var element: String = _element(id)
		verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
		verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
		verifier_egal(String(_effet(id)["kind"]), String(ARMES[id]["genre"]), "genre de %s" % id)
		verifier_egal(int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.CHAOS, "type")
		verifier(SignaturesArmes.en_jeu(id), "%s : en jeu" % id)
		verifier_faux(vus.has(element), "%s : élément partagé" % id)
		vus[element] = true
	verifier_egal(vus.size(), 9, "neuf armes")


func test_chaque_projectile_a_sa_planche_et_aucune_arme_n_en_partage() -> void:
	var autres: Dictionary = {}
	for element: String in AttaquesElementaires.registre():
		var el: AttaqueElement = AttaquesElementaires.registre()[element]
		var planche: String = String(el.conf()["projectile"])
		if planche != "":
			autres[planche] = autres.get(planche, []) + [element]
	for id: String in ARMES:
		var planche: String = String(ARMES[id]["projectile"])
		verifier_egal(AttaquesElementaires.planche_projectile(_element(id)), planche, id)
		if planche == "":
			continue
		verifier(
			ResourceLoader.exists("%s%s.png" % [PlanchesEffets.dossier(), planche]),
			"%s : planche %s" % [id, planche]
		)
		verifier_egal((autres[planche] as Array).size(), 1, "%s : projectile partagé" % id)


func test_la_geometrie_des_planches_d_impact_se_lit_sur_les_fichiers() -> void:
	for id: String in ARMES:
		var planche: String = _impact(id)
		var img: Image = (
			(load(PlanchesEffets.dossier() + planche + ".png") as Texture2D).get_image()
		)
		var el: AttaqueElement = AttaquesElementaires.registre()[_element(id)]
		verifier_egal(
			el.planches()[planche],
			Vector2i(img.get_height(), img.get_height()),
			"case de %s" % planche
		)
		verifier_egal(
			AttaquesElementaires.visible_de(planche),
			float(_pic_de_planche(planche).y),
			"diamètre visible de %s" % planche
		)


func test_l_anticipation_dure_trois_images_et_le_vol_sept_en_direct_ou_onze_en_cloche() -> void:
	for id: String in ARMES:
		var vol: int = int(ARMES[id]["vol"])
		if vol == 0:
			continue
		_a.vider()
		verifier_proche(
			_a.tirer(_element(id), TOUR, CIBLE) / IMAGE, 3.0 + vol, 0.01, "%s : 3 + %d" % [id, vol]
		)
		verifier_egal(_a.etats("ombre").size(), 1 if vol == 11 else 0, "%s : ombre" % id)
		_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
		var projectile: Dictionary = _a.etats(String(ARMES[id]["projectile"]))[0]
		verifier(projectile["visible"], "%s : il vole" % id)
		_avancer(vol)
		verifier_egal(_a.etats(String(ARMES[id]["projectile"])).size(), 0, "%s : arrivé" % id)


func test_l_impact_attend_la_fin_du_vol_a_une_image_pres() -> void:
	for id: String in ARMES:
		var vol: int = int(ARMES[id]["vol"])
		if vol == 0:
			continue
		var effets: Effets = _effets_neuf()
		for evenement: Dictionary in _cycle(id):
			effets.ajouter(evenement)
		var rang: int = _premiere_apparition(effets, _impact(id), 60)
		var attendu: int = AttaquesElementaires.IMAGES_ANTICIPATION + vol
		verifier(
			rang >= attendu - 1 and rang <= attendu + 1,
			"%s : impact à l'image %d, vol fini à %d" % [id, rang, attendu]
		)
		effets.free()


func _dessiner(id: String) -> bool:
	var element: String = _element(id)
	if String(ARMES[id]["genre"]) == "aura":
		return _a.aura(element, CIBLE, _zone_px(id))
	return _a.impacter(element, CIBLE, _zone_px(id), false)


func test_l_impact_est_au_pic_dans_le_premier_quart_de_sa_duree() -> void:
	for id: String in ARMES:
		_a.vider()
		verifier(_dessiner(id), "%s : un effet est créé" % id)
		var total: int = int(ARMES[id]["total"])
		var rang: int = _rang_du_pic(_impact(id), _image_du_pic(_impact(id)), total)
		verifier(
			rang >= 0 and rang <= total / 4, "%s : pic à l'image %d sur %d" % [id, rang, total]
		)


func test_la_zone_de_la_legion_est_dessinee_au_rayon_reel() -> void:
	var rayon: float = _rayon_px("legion_de_cendre")
	verifier(_a.impacter("legion", CIBLE, rayon, false))
	verifier_proche(_a.etats("nuage_cendre")[0]["diametre"], rayon * 2.0, rayon * 0.2, "nuage")
	verifier_egal(_a.etats("").size(), 1, "un anneau fin")
	verifier_proche(_a.etats("")[0]["diametre"], rayon * 2.0, 0.5, "anneau au rayon exact")


func test_le_barrage_de_la_tempete_ne_dessine_qu_un_anneau_au_rayon_reel() -> void:
	var rayon: float = _rayon_px("tempete_de_malefices")
	for _i: int in 4:
		_a.impacter_en_groupe("malefices", CIBLE, rayon, false)
	verifier_egal(_a.etats("").size(), 0, "pas d'anneau par impact")
	verifier(_a.zone("malefices", CIBLE, rayon))
	verifier_egal(_a.etats("").size(), 1, "un seul anneau pour tout le tir")
	verifier_proche(_a.etats("")[0]["diametre"], rayon * 2.0, 0.5, "au rayon exact")


func test_l_aura_de_la_coupe_s_etend_jusqu_au_rayon_reel() -> void:
	var rayon: float = _rayon_px("coupe_d_oubli")
	verifier(_a.aura("coupe", TOUR, rayon))
	verifier_egal(_a.etats("").size(), 1, "un anneau fin")
	verifier_proche(_a.etats("")[0]["diametre"], rayon * 2.0, 0.5, "anneau au rayon exact")
	_avancer(AttaquesElementaires.IMAGES_COURONNE_OUVERTURE)
	var loin: float = 0.0
	for coupe: Dictionary in _a.etats("coupe"):
		loin = maxf(loin, (coupe["position"] as Vector2).distance_to(TOUR))
	verifier(
		loin >= rayon * 0.8 and loin <= rayon * 1.05, "les coupes atteignent le rayon : %f" % loin
	)
	verifier_egal(_a.etats("coupe").size(), 5, "cinq coupes")


func test_un_coup_sur_une_cible_seule_reste_petit_et_ne_lance_presque_rien() -> void:
	for id: String in ARMES:
		var genre: String = String(ARMES[id]["genre"])
		if genre in ["aura", "zone"]:
			continue
		_a.vider()
		verifier(_a.impacter(_element(id), CIBLE, 0.0, false), id)
		verifier(_a.diametre_max() <= DIAMETRE_MAX_CIBLE_UNIQUE, "%s : au plus 60 px" % id)
		verifier(_a.particules_actives() <= PARTICULES_MAX, "%s : au plus 8 particules" % id)
		verifier_egal(_a.gel_restant(), 0.0, "%s : pas un coup de siège, pas de gel" % id)
		verifier_egal(_a.etats("").size(), 0, "%s : pas d'anneau : la cible est la zone" % id)


func test_aucun_effet_de_chaos_ne_depasse_le_plafond_ni_l_opacite_maximale() -> void:
	for id: String in ARMES:
		var element: String = _element(id)
		for _tour: int in 30:
			_a.tirer(element, TOUR, CIBLE)
			_a.impacter(element, CIBLE, _zone_px(id), false)
			_a.impacter_en_groupe(element, CIBLE, _zone_px(id), false)
			_a.zone(element, CIBLE, _zone_px(id))
			_a.aura(element, TOUR, _zone_px(id))
		_avancer(4)
		verifier(_a.nombre_vivants() <= _a.place, "%s : plafond" % id)
		verifier(_a.opacite_max() <= AttaquesElementaires.ALPHA_MAX + 0.0001, "%s : opacité" % id)
		_a.vider()


func test_en_mouvement_reduit_ni_particule_ni_rotation_ni_gel_et_les_sprites_restent() -> void:
	for id: String in ARMES:
		_a.vider()
		_a.mouvement_reduit = true
		var element: String = _element(id)
		var planche: String = String(ARMES[id]["projectile"])
		if planche != "":
			_a.tirer(element, TOUR, CIBLE)
			_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 4)
			verifier_egal(_a.etats(planche)[0]["rotation"], 0.0, "%s : ne tourne pas" % id)
		verifier(_dessiner(id), "%s : l'impact reste" % id)
		verifier_egal(_a.particules_actives(), 0, "%s : sans particule" % id)
		verifier_egal(_a.gel_restant(), 0.0, "%s : sans gel" % id)
		verifier(_visibles(_impact(id)) > 0, "%s : le sprite d'impact reste" % id)
		_avancer(200)
		verifier_egal(_a.nombre_vivants(), 0, "%s : tout s'efface" % id)
		_a.mouvement_reduit = false


func test_les_projectiles_qui_tournent_tournent_hors_mouvement_reduit() -> void:
	for element: String in ["serment", "discorde", "legion"]:
		_a.vider()
		_a.tirer(element, TOUR, CIBLE)
		_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
		var planche: String = AttaquesElementaires.planche_projectile(element)
		verifier(absf(_a.etats(planche)[0]["rotation"]) > 0.05, "%s : il tourne" % element)


func test_chaque_projectile_en_cloche_passe_au_dessus_de_la_ligne_de_tir() -> void:
	for id: String in ARMES:
		if int(ARMES[id]["vol"]) != 11:
			continue
		_a.vider()
		_a.tirer(_element(id), TOUR, CIBLE)
		_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 6)
		var etat: Dictionary = _a.etats(String(ARMES[id]["projectile"]))[0]
		verifier(etat["position"].y < CIBLE.y - 10.0, "%s : en cloche" % id)


func test_dans_effets_aucune_arme_de_chaos_ne_gele_ni_ne_fait_reculer() -> void:
	for id: String in ARMES:
		var effets: Effets = _effets_neuf()
		var forts: Array[bool] = []
		effets.impact_visible.connect(
			func(_ou: Vector2, _r: float, fort: bool) -> void: forts.append(fort)
		)
		for evenement: Dictionary in _cycle(id):
			effets.ajouter(evenement)
		for _i: int in 80:
			effets.avancer(IMAGE)
			verifier_egal(effets.gel_restant(), 0.0, "%s : pas de gel" % id)
			verifier(effets.nombre_vivants() <= Effets.PLAFOND, "%s : plafond" % id)
		for fort: bool in forts:
			verifier_faux(fort, "%s : pas un coup de siège" % id)
		verifier_faux(
			effets.formes_vivantes().has("explosion"), "%s : pas d'explosion du pack" % id
		)
		effets.free()


func test_aucun_script_de_chaos_ne_touche_au_temps_du_moteur() -> void:
	for nom: String in SCRIPTS:
		var texte: String = FileAccess.get_file_as_string("res://visuels/attaques/%s.gd" % nom)
		verifier(texte != "", "%s lisible" % nom)
		verifier_faux(texte.contains("time_scale"), "%s : jamais Engine.time_scale" % nom)
		verifier_faux(texte.contains("camera"), "%s : aucune secousse de caméra" % nom)
