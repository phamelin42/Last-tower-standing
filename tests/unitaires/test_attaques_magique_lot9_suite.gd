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
	var vol: int = PlanchesEffets.images_vol("couronne_etoiles")
	verifier(vol > 0, "durée de vol propre à la couronne, lue dans les données")
	verifier_proche(
		_a.tirer("couronne_etoiles", TOUR, bout) / IMAGE,
		float(AttaquesElementaires.IMAGES_ANTICIPATION + vol),
		0.01,
		"anticipation + vol des données"
	)
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


# --- Nuée d'étincelles : barrage de six, mana au coup --------------------------------------------


func test_la_nuee_d_etincelles_est_un_barrage_de_six_qui_donne_de_la_mana() -> void:
	_verifier_arme("nuee_d_etincelles", "nuee", "barrage")
	verifier_egal(int(_effet("nuee_d_etincelles")["projectiles"]), 6, "six étincelles")
	verifier_egal(_statut("nuee_d_etincelles"), "mana_au_coup")


func test_les_etincelles_partent_a_deux_images_l_une_de_l_autre_et_filent_droit() -> void:
	var retard: float = AttaquesElementaires.retard_barrage("nuee")
	var fin: float = 0.0
	for k: int in 6:
		fin = _a.tirer("nuee", TOUR, CIBLE, k * retard)
	verifier_proche(fin / IMAGE, 10.0 + 5.0 * 2.0, 0.01, "la sixième part à l'image 10")
	verifier_egal(_a.etats("etincelle").size(), 6, "six étincelles")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	verifier_proche(_a.etats("etincelle")[0]["position"].y, CIBLE.y, 1.0, "droit")


func test_un_seul_anneau_au_rayon_reel_pour_toute_la_nuee() -> void:
	var rayon: float = _rayon_px("nuee_d_etincelles")
	for k: int in 6:
		_a.impacter_en_groupe("nuee", CIBLE + Vector2(0.0, k * 3.0), rayon)
	verifier_egal(_a.etats("").size(), 0, "aucun anneau par étincelle")
	_a.zone("nuee", CIBLE, rayon)
	verifier_egal(_a.etats("").size(), 1, "un anneau pour le tir")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1, "au rayon réel")


func test_chaque_etincelle_eclate_petit_au_pic_dans_le_premier_quart_et_la_nuee_tient_le_plafond(
) -> void:
	_a.impacter_en_groupe("nuee", CIBLE, 25.0)
	verifier(_a.diametre_max() <= 60.0, "petit")
	var total: int = AttaqueNuee.SEQ_ECLAT.size()
	var rang: int = _rang_du_pic("eclat_rune", AttaqueNuee.IMAGE_PIC, total)
	verifier(rang >= 0 and rang <= total / 4, "pic à l'image %d sur %d" % [rang, total])
	_avancer(total + 30)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	for _tir: int in 40:
		for k: int in 6:
			_a.impacter_en_groupe("nuee", CIBLE, 25.0)
	verifier(_a.nombre_vivants() <= _a.place, "plafond respecté")


func test_la_nuee_dans_effets_lance_une_etincelle_par_impact_et_un_seul_anneau() -> void:
	var effets: Effets = _effets_de("nuee_d_etincelles")
	verifier(effets.elementaires().etats("etincelle").size() >= 4, "une étincelle par impact")
	var anneaux: int = 0
	for _i: int in 60:
		effets.avancer(IMAGE)
		anneaux = maxi(anneaux, effets.elementaires().etats("").size())
	verifier_egal(anneaux, 1, "un seul anneau")
	effets.free()


func test_mouvement_reduit_la_nuee_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.impacter_en_groupe("nuee", CIBLE, 25.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier(_a.etats("eclat_rune").size() > 0, "l'éclat reste")


# --- Nova céleste : onde, vulnérabilité et siphon ------------------------------------------------


func test_la_nova_celeste_est_une_onde_qui_rend_vulnerable_et_siphonne() -> void:
	_verifier_arme("nova_celeste", "nova_celeste", "onde")
	verifier_egal(_statut("nova_celeste"), "vulnerabilite")
	verifier_egal(AttaquesElementaires.planche_projectile("nova_celeste"), "", "rien ne part")


func test_l_onde_celeste_a_le_rayon_et_la_vitesse_des_donnees() -> void:
	var rayon: float = _rayon_px("nova_celeste", "rayon_max")
	var vitesse: float = _rayon_px("nova_celeste", "vitesse")
	verifier_proche(AttaqueNovaCeleste.RAYON_PX, rayon, 0.001, "rayon de data/armes.json")
	verifier_proche(AttaqueNovaCeleste.VITESSE_PX, vitesse, 0.001, "vitesse de data/armes.json")


func test_les_croissants_avancent_a_la_vitesse_de_l_onde_jusqu_au_rayon() -> void:
	verifier(_a.onde("nova_celeste", TOUR))
	verifier_egal(_a.etats("vague_celeste").size(), AttaqueNovaCeleste.CROISSANTS, "un front")
	_avancer(15)
	var attendu: float = AttaqueNovaCeleste.VITESSE_PX * 15.0 * IMAGE
	for lame: Dictionary in _a.etats("vague_celeste"):
		verifier_proche((lame["position"] as Vector2).distance_to(TOUR), attendu, 1.0, "vitesse")
	_avancer(80)
	for lame: Dictionary in _a.etats("vague_celeste"):
		verifier(
			(lame["position"] as Vector2).distance_to(TOUR) <= AttaqueNovaCeleste.RAYON_PX + 0.5,
			"jamais au-delà du rayon"
		)


func test_des_eclats_etoiles_naissent_quand_le_front_passe_et_restent_dans_le_rayon() -> void:
	_a.onde("nova_celeste", TOUR)
	var visibles: int = 0
	for eclat: Dictionary in _a.etats("eclat_astral"):
		visibles += 1 if eclat["visible"] else 0
	verifier_egal(visibles, 0, "rien avant le passage du front")
	var passage: float = AttaqueNovaCeleste.RAYON_PX / AttaqueNovaCeleste.VITESSE_PX / IMAGE
	_avancer(int(passage * AttaqueNovaCeleste.COURONNES_ECLATS[0]) + 3)
	visibles = 0
	for eclat: Dictionary in _a.etats("eclat_astral"):
		if not eclat["visible"]:
			continue
		visibles += 1
		var d: float = (eclat["position"] as Vector2).distance_to(TOUR)
		verifier(d + eclat["diametre"] * 0.5 <= AttaqueNovaCeleste.RAYON_PX + 1.0, "dans le rayon")
	verifier(visibles > 0, "les éclats sont sortis")
	var total: int = AttaqueNovaCeleste.SEQ_ECLAT.size()
	_a.vider()
	_a.onde("nova_celeste", TOUR)
	_avancer(int(passage * AttaqueNovaCeleste.COURONNES_ECLATS[0]))
	var rang: int = _rang_du_pic("eclat_astral", AttaqueNovaCeleste.IMAGE_PIC, total)
	verifier(rang >= 0 and rang <= total / 4, "pic à %d images après le passage" % rang)


func test_l_onde_celeste_s_efface_et_rend_le_pool() -> void:
	_a.onde("nova_celeste", TOUR)
	_avancer(150)
	verifier_egal(_a.nombre_vivants(), 0)
	verifier_egal(_a.particules_actives(), 0)


func test_la_nova_celeste_dans_effets_se_dessine_au_depart_de_l_onde() -> void:
	var effets: Effets = _effets_de("nova_celeste")
	verifier_egal(
		effets.elementaires().etats("vague_celeste").size(),
		AttaqueNovaCeleste.CROISSANTS,
		"un front"
	)
	verifier_faux(effets.formes_vivantes().has("anneau"), "plus d'anneau générique")
	effets.free()


# --- Les neuf armes : en jeu, plafond, impacts -------------------------------------------------


func test_les_neuf_armes_magiques_ont_chacune_leur_element_et_leurs_planches() -> void:
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
				ResourceLoader.exists("%s%s.png" % [PlanchesEffets.dossier(), planche]),
				"%s : planche %s" % [id, planche]
			)
	verifier_egal(vus.size(), 9, "neuf armes")


func _noter_impact(_ou: Vector2, _rayon: float, _fort: bool) -> void:
	_impacts_visibles += 1


## Un impact visible n'est émis que pour un coup que la simulation émet : l'impact décoratif
## (le bout d'un rayon tournant) n'ajoute rien à ceux des événements de la vitrine.
func test_une_arme_magique_n_emet_un_impact_visible_que_par_evenement_d_impact() -> void:
	for id: String in ARMES:
		_impacts_visibles = 0
		var effets: Effets = Effets.new()
		effets.catalogue = _donnees.ids_catalogue
		effets.impact_visible.connect(_noter_impact)
		arbre.root.add_child(effets)
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


func test_aucun_effet_magique_ne_depasse_le_plafond_ni_l_opacite_maximale() -> void:
	for id: String in ARMES:
		var element: String = String(ARMES[id])
		var rayon: float = _rayon_px(id) if _effet(id).has("rayon") else 0.0
		for _tour: int in 30:
			_a.tirer(element, TOUR, CIBLE)
			_a.impacter(element, CIBLE, rayon)
			_a.impacter_en_groupe(element, CIBLE, rayon)
			_a.zone(element, CIBLE, rayon)
			_a.aura(element, TOUR, rayon)
			_a.onde(element, TOUR)
		_avancer(4)
		verifier(_a.nombre_vivants() <= _a.place, "%s : plafond" % id)
		verifier(_a.opacite_max() <= AttaquesElementaires.ALPHA_MAX + 0.0001, "%s : opacité" % id)
		_a.vider()
