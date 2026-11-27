extends CasAttaquesPercant
## Les armes perçantes du lot 9 (D22), première moitié : javeline de jet, trait en gerbe, flèche
## marquante, arc de remparts, herse de pieux. Mêmes phases et mêmes bornes que le carreau du
## lot 8 (anticipation 3 images, vol direct 7, impact au pic dans le premier quart, zone au rayon
## réel lu dans `data/armes.json`). Durées en images à 60 i/s.

# --- Javeline de jet : cible unique, repoussement ----------------------------------------------


func test_la_javeline_est_une_cible_unique_qui_repousse() -> void:
	_verifier_arme("javeline_de_jet", "javeline", "cible_unique")
	verifier_egal(_statut("javeline_de_jet"), "repoussement")


func test_la_javeline_dure_dix_images_et_file_droit_sans_tourner() -> void:
	verifier_proche(_a.tirer("javeline", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
	var javeline: Dictionary = _a.etats("javeline")[0]
	verifier(javeline["visible"], "elle vole")
	verifier_proche(javeline["position"].y, CIBLE.y, 1.0, "droit, sans arc")
	verifier_proche(javeline["rotation"], 0.0, 0.01, "la pointe regarde la cible")
	verifier(_a.particules_actives() >= 1, "une traînée fine")
	verifier_egal(_a.etats("ombre").size(), 0, "pas d'ombre : elle ne passe pas en cloche")


func test_la_javeline_mord_lourd_et_reste_plantee_huit_images() -> void:
	_a.impacter("javeline", CIBLE, 0.0)
	verifier_egal(_a.etats("gerbe").size(), 1, "une gerbe")
	verifier(_a.etats("gerbe")[0]["diametre"] > AttaquesElementaires.DIAMETRE_PETIT, "plus lourde")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier_egal(_a.etats("plante").size(), 1, "elle reste plantée")
	verifier_egal(_a.particules_actives(), 1, "des éclats d'acier")
	_avancer(7)
	verifier_egal(_a.etats("plante").size(), 1, "encore là à la septième image")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_mouvement_reduit_la_javeline_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("javeline", TOUR, CIBLE)
	_a.impacter("javeline", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("gerbe").size(), 1, "la gerbe reste")


# --- Trait en gerbe : barrage de trois, épines -------------------------------------------------


func test_le_trait_en_gerbe_est_un_barrage_de_trois_traits() -> void:
	_verifier_arme("trait_en_gerbe", "trait_gerbe", "barrage")
	verifier_egal(int(_effet("trait_en_gerbe")["projectiles"]), 3, "trois traits")
	verifier_egal(String(_donnees.armes["trait_en_gerbe"]["type_secondaire"]), "epines")


func test_chaque_trait_part_deux_images_apres_le_precedent_et_file_droit() -> void:
	var retard: float = AttaquesElementaires.retard_barrage("trait_gerbe")
	var premier: float = _a.tirer("trait_gerbe", TOUR, CIBLE, 0.0)
	var second: float = _a.tirer("trait_gerbe", TOUR, CIBLE, retard)
	verifier_proche(premier / IMAGE, 10.0, 0.01, "anticipation + vol direct")
	verifier_proche((second - premier) / IMAGE, 2.0, 0.01, "décalés de 2 images")
	verifier_egal(_a.etats("aiguille").size(), 2, "un trait par tir")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
	verifier_proche(_a.etats("aiguille")[0]["position"].y, CIBLE.y, 1.0, "droit")


func test_un_seul_anneau_au_rayon_reel_pour_tout_le_trait_en_gerbe() -> void:
	var rayon: float = _rayon_px("trait_en_gerbe")
	for k: int in 3:
		_a.impacter_en_groupe("trait_gerbe", CIBLE + Vector2(0.0, k * 10.0), rayon)
	verifier_egal(_a.etats("").size(), 0, "aucun anneau par trait")
	_a.zone("trait_gerbe", CIBLE, rayon)
	verifier_egal(_a.etats("").size(), 1, "un anneau pour le tir")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1, "au rayon réel")


func test_chaque_trait_se_plante_un_instant_avec_des_epines() -> void:
	_a.impacter_en_groupe("trait_gerbe", CIBLE, 22.0)
	verifier_egal(_a.etats("gerbe").size(), 1, "une gerbe")
	verifier_egal(_a.etats("plante").size(), 1, "le trait reste planté")
	verifier(_a.diametre_max() <= 60.0, "petit")
	verifier_egal(_a.particules_actives(), 2, "éclats de bois et épines")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_le_trait_en_gerbe_dans_effets_lance_un_trait_par_impact_et_un_seul_anneau() -> void:
	var effets: Effets = _effets_de("trait_en_gerbe")
	verifier_egal(effets.elementaires().etats("aiguille").size(), 4, "quatre traits à la vitrine")
	var anneaux: int = 0
	for _i: int in 60:
		effets.avancer(IMAGE)
		anneaux = maxi(anneaux, effets.elementaires().etats("").size())
	verifier_egal(anneaux, 1, "un seul anneau")
	effets.free()


func test_mouvement_reduit_le_trait_en_gerbe_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.impacter_en_groupe("trait_gerbe", CIBLE, 22.0)
	verifier_egal(_a.particules_actives(), 0)


# --- Flèche marquante : cible unique, vulnérabilité --------------------------------------------


func test_la_fleche_marquante_est_une_cible_unique_qui_rend_vulnerable() -> void:
	_verifier_arme("fleche_marquante", "fleche_marquante", "cible_unique")
	verifier_egal(_statut("fleche_marquante"), "vulnerabilite")


func test_la_fleche_dure_dix_images_et_laisse_une_trainee_orange() -> void:
	verifier_proche(_a.tirer("fleche_marquante", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
	verifier(_a.etats("fleche_marquante")[0]["visible"], "elle vole")
	verifier_proche(_a.etats("fleche_marquante")[0]["position"].y, CIBLE.y, 1.0, "droite")
	verifier(_a.particules_actives() >= 1, "une traînée")


func test_la_fleche_se_plante_et_jette_des_eclats_orange_sans_dessiner_la_marque() -> void:
	_a.impacter("fleche_marquante", CIBLE, 0.0)
	verifier_egal(_a.etats("gerbe").size(), 1, "une gerbe")
	verifier_egal(_a.etats("plante").size(), 1, "elle reste plantée")
	verifier_egal(_a.etats("").size(), 0, "la marque reste celle d'Effets : pas d'anneau ici")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier_egal(_a.particules_actives(), 1, "des éclats")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0)
	verifier_egal(_a.particules_actives(), 0)


func test_mouvement_reduit_la_fleche_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("fleche_marquante", TOUR, CIBLE)
	_a.impacter("fleche_marquante", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)
