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
	verifier_proche(_a.tirer("couronne_etoiles", TOUR, bout) / IMAGE, 10.0, 0.01, "3 + 7 images")
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
