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
