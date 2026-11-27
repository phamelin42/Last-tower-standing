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
