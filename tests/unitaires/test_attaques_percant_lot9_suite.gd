extends CasAttaquesPercant
## Les armes percantes du lot 9 (D22), seconde moitié : lance épineuse, carquois en rafale, mur de
## pointes, couronne de pointes. Mêmes phases et mêmes bornes que le carreau du lot 8.

var _impacts_visibles: int = 0

# --- Lance épineuse : cible unique, poison, épines ---------------------------------------------


func test_la_lance_est_une_cible_unique_qui_empoisonne_et_pique_en_retour() -> void:
	_verifier_arme("lance_epineuse", "lance_epineuse", "cible_unique")
	verifier_egal(_statut("lance_epineuse"), "poison")
	verifier_egal(String(_donnees.armes["lance_epineuse"]["type_secondaire"]), "epines")


func test_la_lance_dure_dix_images_et_laisse_une_trainee_verte() -> void:
	verifier_proche(_a.tirer("lance_epineuse", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
	var lance: Dictionary = _a.etats("lance_epineuse")[0]
	verifier(lance["visible"], "elle vole")
	verifier_proche(lance["position"].y, CIBLE.y, 1.0, "droite")
	verifier(_a.particules_actives() >= 1, "une traînée de venin")


func test_la_lance_mord_lourd_reste_plantee_et_jette_epines_et_venin() -> void:
	_a.impacter("lance_epineuse", CIBLE, 0.0)
	verifier(_a.etats("gerbe")[0]["diametre"] > AttaquesElementaires.DIAMETRE_PETIT, "lourde")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier_egal(_a.etats("plante").size(), 1, "elle reste plantée")
	verifier_egal(_a.particules_actives(), 2, "épines vertes et gouttes de venin")
	_avancer(12)
	verifier_egal(_a.etats("plante").size(), 1, "plantée plus longtemps que le carreau")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_mouvement_reduit_la_lance_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("lance_epineuse", TOUR, CIBLE)
	_a.impacter("lance_epineuse", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("plante").size(), 1, "la lance reste plantée")


# --- Carquois en rafale : barrage de huit, vulnérabilité ---------------------------------------


func test_le_carquois_est_un_barrage_de_huit_traits_qui_rend_vulnerable() -> void:
	_verifier_arme("carquois_en_rafale", "carquois", "barrage")
	verifier_egal(int(_effet("carquois_en_rafale")["projectiles"]), 8, "huit traits")
	verifier_egal(_statut("carquois_en_rafale"), "vulnerabilite")


func test_les_traits_du_carquois_partent_a_deux_images_l_un_de_l_autre() -> void:
	var retard: float = AttaquesElementaires.retard_barrage("carquois")
	var fin: float = 0.0
	for k: int in 8:
		fin = _a.tirer("carquois", TOUR, CIBLE, k * retard)
	verifier_proche(fin / IMAGE, 10.0 + 7.0 * 2.0, 0.01, "le huitième part à l'image 14")
	verifier_egal(_a.etats("aiguille").size(), 8, "huit traits")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	var chaud: Color = _a.etats("aiguille")[0]["teinte"]
	verifier(chaud.r > chaud.b, "chauds")


func test_un_seul_anneau_au_rayon_reel_pour_tout_le_carquois() -> void:
	var rayon: float = _rayon_px("carquois_en_rafale")
	for k: int in 8:
		_a.impacter_en_groupe("carquois", CIBLE + Vector2(0.0, k * 4.0), rayon)
	verifier_egal(_a.etats("").size(), 0, "aucun anneau par trait")
	_a.zone("carquois", CIBLE, rayon)
	verifier_egal(_a.etats("").size(), 1, "un anneau pour le tir")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1, "au rayon réel")


func test_chaque_trait_du_carquois_est_petit_et_la_rafale_tient_le_plafond() -> void:
	_a.impacter_en_groupe("carquois", CIBLE, 22.0)
	verifier(_a.diametre_max() <= 60.0, "petit")
	verifier_egal(_a.etats("plante").size(), 1, "le trait se plante")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	for _tir: int in 40:
		for k: int in 8:
			_a.impacter_en_groupe("carquois", CIBLE, 22.0)
	verifier(_a.nombre_vivants() <= _a.place, "plafond respecté")


func test_le_carquois_dans_effets_lance_un_trait_par_impact_et_un_seul_anneau() -> void:
	var effets: Effets = _effets_de("carquois_en_rafale")
	verifier(effets.elementaires().etats("aiguille").size() >= 4, "un trait par impact")
	var anneaux: int = 0
	for _i: int in 60:
		effets.avancer(IMAGE)
		anneaux = maxi(anneaux, effets.elementaires().etats("").size())
	verifier_egal(anneaux, 1, "un seul anneau")
	effets.free()


# --- Mur de pointes : zone, repoussement -------------------------------------------------------


func test_le_mur_de_pointes_est_une_zone_qui_repousse() -> void:
	_verifier_arme("mur_de_pointes", "mur_pointes", "zone")
	verifier_egal(_statut("mur_de_pointes"), "repoussement")


func test_le_pieu_du_mur_dure_dix_images_et_file_droit() -> void:
	verifier_proche(_a.tirer("mur_pointes", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
	verifier_proche(_a.etats("pique")[0]["position"].y, CIBLE.y, 1.0, "droit")
	verifier(_a.etats("pique")[0]["teinte"].g > _a.etats("pique")[0]["teinte"].r, "teinté de vert")


func test_la_haie_se_dresse_jusqu_au_rayon_reel_de_la_zone() -> void:
	var rayon: float = _rayon_px("mur_de_pointes")
	verifier(_a.impacter("mur_pointes", CIBLE, rayon))
	verifier_egal(_a.etats("pique").size(), AttaqueMurPointes.PIQUES, "une haie de pieux")
	_avancer(AttaqueMurPointes.IMAGES_SURGISSEMENT - 1)
	var portee_max: float = 0.0
	for pique: Dictionary in _a.etats("pique"):
		var bout: float = (
			(pique["position"] as Vector2).distance_to(CIBLE) + pique["taille"].x * 0.5
		)
		portee_max = maxf(portee_max, bout)
		verifier(bout <= rayon + 1.0, "la pointe ne dépasse pas la zone")
	verifier(portee_max > rayon * 0.6, "la haie est déjà bien sortie")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1, "un anneau au rayon réel")
	verifier_egal(_a.etats("").size(), 1, "un anneau fin")


func test_les_pointes_du_mur_se_dressent_au_bord_de_la_zone_quand_la_haie_est_sortie() -> void:
	var rayon: float = _rayon_px("mur_de_pointes")
	_a.impacter("mur_pointes", CIBLE, rayon)
	_avancer(AttaqueMurPointes.IMAGES_SURGISSEMENT + 2)
	var sol: Array[Dictionary] = _a.etats("pointes_sol")
	verifier_egal(sol.size(), AttaqueMurPointes.TOUFFES, "une touffe par pieu")
	for pointes: Dictionary in sol:
		verifier(pointes["visible"], "elles sont sorties")
		var bord: float = (pointes["position"] as Vector2).distance_to(CIBLE)
		verifier(
			bord + pointes["diametre"] * 0.5 <= rayon + 1.0, "les pointes restent dans la zone"
		)
		verifier(bord + pointes["diametre"] * 0.5 >= rayon - 3.0, "au bord de la zone")


func test_le_mur_s_efface_et_rend_le_pool() -> void:
	_a.impacter("mur_pointes", CIBLE, 75.0)
	_avancer(80)
	verifier_egal(_a.nombre_vivants(), 0)
	verifier_egal(_a.particules_actives(), 0)


func test_le_mur_dans_effets_se_dessine_une_fois_et_emet_un_impact_comme_la_simulation() -> void:
	var effets: Effets = _effets_de("mur_de_pointes")
	verifier(_pic_de(effets, "pique", 40) > 0, "la haie se dresse")
	effets.free()


func test_mouvement_reduit_le_mur_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.impacter("mur_pointes", CIBLE, 75.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier(_a.etats("pique").size() > 0, "la haie reste")


# --- Couronne de pointes : aura, repoussement et vulnérabilité ---------------------------------


func test_la_couronne_de_pointes_est_une_aura() -> void:
	_verifier_arme("couronne_de_pointes", "couronne_pointes", "aura")
	verifier_egal(_statut("couronne_de_pointes"), "repoussement")
	verifier_egal(AttaquesElementaires.planche_projectile("couronne_pointes"), "", "rien ne part")


func test_les_pointes_de_la_couronne_atteignent_le_rayon_reel_de_l_aura() -> void:
	var rayon: float = _rayon_px("couronne_de_pointes")
	verifier(_a.aura("couronne_pointes", TOUR, rayon))
	verifier_egal(_a.etats("chausse_trape").size(), AttaqueCouronnePointes.POINTES, "la couronne")
	_avancer(AttaquesElementaires.IMAGES_COURONNE_OUVERTURE)
	var portee_max: float = 0.0
	for pointe: Dictionary in _a.etats("chausse_trape"):
		var d: float = (pointe["position"] as Vector2).distance_to(TOUR)
		portee_max = maxf(portee_max, d + pointe["taille"].y * 0.5)
		verifier(d < rayon, "le centre de la pointe est dans la zone")
	verifier_proche(portee_max, rayon, rayon * 0.1, "le bord extérieur est au rayon")
	verifier(_a.diametre_max() <= rayon * 2.0 * 1.1, "rien au-delà de la zone")
	verifier_egal(_a.etats("").size(), 1, "un anneau fin au rayon exact")


func test_des_pointes_jaillissent_du_sol_au_rayon_de_l_aura() -> void:
	var rayon: float = _rayon_px("couronne_de_pointes")
	_a.aura("couronne_pointes", TOUR, rayon)
	_avancer(AttaqueCouronnePointes.IMAGES_RETARD_POINTES + 1)
	var sol: Array[Dictionary] = _a.etats("pointes_sol")
	verifier_egal(sol.size(), AttaqueCouronnePointes.POINTES, "une touffe par pointe")
	for touffe: Dictionary in sol:
		var d: float = (touffe["position"] as Vector2).distance_to(TOUR)
		verifier(d + touffe["diametre"] * 0.5 <= rayon + 1.0, "dans la zone")


func test_la_couronne_s_efface_et_rend_le_pool() -> void:
	_a.aura("couronne_pointes", TOUR, 175.0)
	_avancer(AttaquesElementaires.IMAGES_COURONNE + 20)
	verifier_egal(_a.nombre_vivants(), 0)
	verifier_egal(_a.particules_actives(), 0)


func test_la_couronne_dans_effets_se_dessine_a_chaque_coup_de_l_aura() -> void:
	var effets: Effets = _effets_de("couronne_de_pointes")
	verifier_egal(
		effets.elementaires().etats("chausse_trape").size(), AttaqueCouronnePointes.POINTES
	)
	verifier_egal(effets.formes_vivantes().has("anneau"), false, "plus d'anneau générique")
	effets.free()


func test_mouvement_reduit_la_couronne_garde_ses_pointes_sans_tourner() -> void:
	_a.mouvement_reduit = true
	_a.aura("couronne_pointes", TOUR, 175.0)
	_avancer(3)
	var avant: Array[Dictionary] = _a.etats("chausse_trape")
	_avancer(3)
	var apres: Array[Dictionary] = _a.etats("chausse_trape")
	verifier_egal(apres.size(), AttaqueCouronnePointes.POINTES, "les pointes restent")
	verifier_proche(
		((avant[0]["position"] as Vector2) - TOUR).angle(),
		((apres[0]["position"] as Vector2) - TOUR).angle(),
		0.0001,
		"elles ne tournent pas"
	)


# --- Les neuf armes : en jeu, plafond, impacts -------------------------------------------------


func test_les_neuf_armes_percantes_ont_chacune_leur_element_et_leurs_planches() -> void:
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


## Un impact visible n'est émis que pour un coup que la simulation émet : l'impact décoratif (le
## mur, la couronne, le front de pieux) n'ajoute rien à ceux des événements de la vitrine.
func test_une_arme_percante_n_emet_un_impact_visible_que_par_evenement_d_impact() -> void:
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


func test_aucun_effet_percant_ne_depasse_le_plafond_ni_l_opacite_maximale() -> void:
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
