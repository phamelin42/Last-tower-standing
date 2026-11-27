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
