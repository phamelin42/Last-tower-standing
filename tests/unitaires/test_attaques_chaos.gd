extends CasDeTest
## Les cinq armes du chaos (D22), arme par arme : le dé pipé (cible unique), le sablier fêlé
## (piège), le miroir brisé (rebond), le vortex de verre (onde) et l'horloge folle (barrage). Ce que
## le joueur voit suit le genre de l'arme et s'arrête au rayon réel lu dans `data/armes.json`.
## La cornue instable garde l'élément du poison. Durées en images à 60 i/s.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(100.0, 300.0)
const CIBLE := Vector2(420.0, 300.0)

var _a: AttaquesElementaires = null
var _donnees: Donnees = Donnees.charger()


func avant_chaque() -> void:
	_a = AttaquesElementaires.new()
	arbre.root.add_child(_a)


func apres_chaque() -> void:
	if is_instance_valid(_a):
		_a.free()
	_a = null


func _avancer(images: int) -> void:
	for i: int in images:
		_a.avancer(IMAGE)


func _effet(id: String) -> Dictionary:
	return (_donnees.armes[id]["effets"] as Array)[0]


func _rayon_px(id: String) -> float:
	return float(_effet(id)["rayon"]) * Apparence.PX_PAR_UNITE


## Vérifie que l'arme `id` est de ce genre, du type chaos, et rendue par cet élément.
func _verifier_arme(id: String, element: String, genre: String) -> void:
	verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
	verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
	verifier_egal(String(_effet(id)["kind"]), genre, "genre de %s" % id)
	verifier_egal(int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.CHAOS, "type de %s" % id)


## Les événements d'un tir de `id` dans un `Effets` neuf, comme la simulation les émet.
func _evenements(id: String) -> Array[Dictionary]:
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = [id] as Array[String]
	var liste: Array[Dictionary] = vitrine.evenements_du_cycle(id)
	vitrine.free()
	return liste


func _effets() -> Effets:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	return effets


# --- Dé pipé : cible unique et vol de vie ------------------------------------------------------


func test_le_de_pipe_est_une_cible_unique_qui_soigne() -> void:
	_verifier_arme("de_pipe", "de_pipe", "cible_unique")
	verifier_egal(String(_donnees.armes["de_pipe"]["statuts"][0]["kind"]), "vol_de_vie")


func test_le_de_part_apres_trois_images_d_anticipation_et_roule_sept_images() -> void:
	verifier_proche(_a.tirer("de_pipe", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	verifier_egal(_a.etats("depart").size(), 1, "l'anticipation")
	verifier_egal(_a.etats("de_pipe").size(), 1, "le dé")


func test_le_de_tourne_en_volant_et_montre_une_autre_face_sauf_en_mouvement_reduit() -> void:
	_a.tirer("de_pipe", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var rotation: float = _a.etats("de_pipe")[0]["rotation"]
	var image: int = _a.etats("de_pipe")[0]["image"]
	_avancer(5)
	verifier(absf(_a.etats("de_pipe")[0]["rotation"] - rotation) > 0.5, "il tourne")
	verifier(_a.etats("de_pipe")[0]["image"] != image, "une autre face")
	_a.vider()
	_a.mouvement_reduit = true
	_a.tirer("de_pipe", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	rotation = _a.etats("de_pipe")[0]["rotation"]
	image = _a.etats("de_pipe")[0]["image"]
	_avancer(5)
	verifier_proche(_a.etats("de_pipe")[0]["rotation"], rotation, 0.0001, "pas de rotation")
	verifier_egal(_a.etats("de_pipe")[0]["image"], image, "face figée")


func test_l_impact_du_de_est_un_eclat_de_points_petit_et_discret() -> void:
	verifier(_a.impacter("de_pipe", CIBLE, 0.0, false, TOUR))
	verifier_egal(_a.etats("eclat_des").size(), 1, "un éclat de points")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier(_a.particules_actives() >= 1 and _a.particules_actives() <= 8, "de 1 à 8 particules")
	verifier_egal(_a.gel_restant(), 0.0, "coup courant : pas de gel")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")


func test_mouvement_reduit_le_de_garde_ses_sprites_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("de_pipe", TOUR, CIBLE)
	_a.impacter("de_pipe", CIBLE, 0.0, false, TOUR)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("eclat_des").size(), 1, "l'éclat reste")


func test_le_de_dans_effets_roule_puis_laisse_le_soin_d_aujourd_hui() -> void:
	var effets: Effets = _effets()
	for evenement: Dictionary in _evenements("de_pipe"):
		effets.ajouter(evenement)
	verifier_egal(effets.elementaires().etats("de_pipe").size(), 1, "un dé")
	for _i: int in 10:
		effets.avancer(IMAGE)
	verifier_egal(effets.elementaires().etats("eclat_des").size(), 1, "l'impact à l'arrivée")
	effets.free()


func _visibles(planche: String) -> int:
	var n: int = 0
	for e: Dictionary in _a.etats(planche):
		n += 1 if e["visible"] else 0
	return n


# --- Sablier fêlé : piège ----------------------------------------------------------------------


func test_le_sablier_est_un_piege() -> void:
	_verifier_arme("sablier_fele", "sablier", "piege")


func test_le_sablier_est_lance_puis_reste_pose_au_sol_visible() -> void:
	verifier(_a.piege("sablier", TOUR, CIBLE))
	verifier_egal(_a.etats("sablier").size(), 2, "un lancé et un pour le sol")
	_avancer(5)
	verifier_egal(_visibles("sablier"), 1, "il vole, il n'est pas encore au sol")
	_avancer(80)
	var pose: Array[Dictionary] = _a.etats("sablier")
	verifier_egal(pose.size(), 1, "il reste tant que le piège n'a pas servi")
	verifier((pose[0]["position"] as Vector2).distance_to(CIBLE) <= 1.0, "sur le chemin visé")
	_avancer(60 * 20)
	verifier_egal(_a.etats("sablier").size(), 1, "toujours là après vingt secondes")


func test_le_sable_coule_dans_le_sablier_pose_sauf_en_mouvement_reduit() -> void:
	_a.piege("sablier", TOUR, CIBLE)
	_avancer(80)
	var images: Dictionary = {}
	for i: int in 30:
		_avancer(1)
		images[int(_a.etats("sablier")[0]["image"])] = true
	verifier_egal(images.size(), 2, "deux images de sable en alternance")
	_a.vider()
	_a.mouvement_reduit = true
	_a.piege("sablier", TOUR, CIBLE)
	_avancer(80)
	images.clear()
	for i: int in 30:
		_avancer(1)
		images[int(_a.etats("sablier")[0]["image"])] = true
	verifier_egal(images.size(), 1, "figé en mouvement réduit")


func test_le_declenchement_retire_le_sablier_et_pas_celui_d_un_autre_piege() -> void:
	_a.piege("sablier", TOUR, CIBLE)
	_a.piege("sablier", TOUR, CIBLE + Vector2(0.0, 200.0))
	_avancer(80)
	verifier_egal(_a.etats("sablier").size(), 2)
	_a.retirer_pieges(CIBLE)
	verifier_egal(_a.etats("sablier").size(), 1, "seul le piège déclenché est retiré")


func test_le_tourbillon_de_sable_est_dessine_au_rayon_reel_sans_gel() -> void:
	var rayon: float = _rayon_px("sablier_fele")
	verifier(_a.impacter("sablier", CIBLE, rayon, false))
	verifier_egal(_a.etats("tourbillon_sable").size(), 1, "le tourbillon")
	verifier_proche(
		_a.etats("tourbillon_sable")[0]["diametre"], rayon * 2.0, rayon * 0.2, "au rayon"
	)
	verifier_egal(_a.etats("").size(), 1, "un anneau")
	verifier_proche(_a.etats("")[0]["diametre"], rayon * 2.0, 0.5, "anneau au rayon exact")
	verifier_egal(_a.gel_restant(), 0.0, "coup courant : pas de gel")
	verifier(_a.particules_actives() <= 8, "au plus huit particules")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0)


func test_mouvement_reduit_le_tourbillon_de_sable_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.piege("sablier", TOUR, CIBLE)
	_a.impacter("sablier", CIBLE, _rayon_px("sablier_fele"), false)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("tourbillon_sable").size(), 1, "le tourbillon reste")


func test_le_sablier_dans_effets_se_pose_au_tir_et_part_au_declenchement() -> void:
	var effets: Effets = _effets()
	var evenements: Array[Dictionary] = _evenements("sablier_fele")
	effets.ajouter(evenements[0])
	verifier_egal(effets.elementaires().etats("sablier").size(), 2, "lancé au tir")
	for _i: int in 80:
		effets.avancer(IMAGE)
	verifier_egal(effets.elementaires().etats("sablier").size(), 1, "il attend")
	effets.ajouter(evenements[1])
	verifier_egal(effets.elementaires().etats("sablier").size(), 0, "retiré au déclenchement")
	verifier_egal(effets.elementaires().etats("tourbillon_sable").size(), 1, "le tourbillon")
	effets.free()


# --- Miroir brisé : rebond ---------------------------------------------------------------------


func test_le_miroir_est_un_rebond() -> void:
	_verifier_arme("miroir_brise", "miroir", "rebond")


func test_le_premier_eclat_part_apres_trois_images_d_anticipation() -> void:
	verifier_proche(_a.tirer("miroir", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	verifier_egal(_a.etats("depart").size(), 1, "l'anticipation")
	verifier_egal(_a.etats("eclat_miroir").size(), 1, "l'éclat")


func test_un_saut_du_miroir_est_un_eclat_de_sept_images_sans_anticipation() -> void:
	var fin: float = _a.saut("miroir", CIBLE, CIBLE + Vector2(90.0, 20.0), 4.0 * IMAGE)
	verifier_proche(fin / IMAGE, 4.0 + AttaquesElementaires.IMAGES_VOL_DIRECT, 0.01)
	verifier_egal(_a.etats("depart").size(), 0, "pas d'anticipation à chaque saut")
	verifier_egal(_a.etats("eclat_miroir").size(), 1, "un éclat par saut")


func test_l_eclat_tourne_et_son_reflet_passe_sauf_en_mouvement_reduit() -> void:
	_a.saut("miroir", TOUR, CIBLE, 0.0)
	_avancer(1)
	var rotation: float = _a.etats("eclat_miroir")[0]["rotation"]
	var image: int = _a.etats("eclat_miroir")[0]["image"]
	_avancer(5)
	verifier(absf(_a.etats("eclat_miroir")[0]["rotation"] - rotation) > 0.3, "il tourne")
	verifier(_a.etats("eclat_miroir")[0]["image"] != image, "le reflet a bougé")
	_a.vider()
	_a.mouvement_reduit = true
	_a.saut("miroir", TOUR, CIBLE, 0.0)
	_avancer(1)
	rotation = _a.etats("eclat_miroir")[0]["rotation"]
	image = _a.etats("eclat_miroir")[0]["image"]
	_avancer(5)
	verifier_proche(_a.etats("eclat_miroir")[0]["rotation"], rotation, 0.0001, "pas de rotation")
	verifier_egal(_a.etats("eclat_miroir")[0]["image"], image, "reflet figé")


func test_l_impact_du_miroir_est_une_gerbe_de_verre_petite_avec_quelques_eclats() -> void:
	verifier(_a.impacter("miroir", CIBLE, 0.0, false, TOUR))
	verifier_egal(_a.etats("gerbe_verre").size(), 1, "une gerbe de verre")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier(_a.particules_actives() >= 1 and _a.particules_actives() <= 8, "de 1 à 8 particules")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")


func test_mouvement_reduit_le_miroir_garde_ses_sprites_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("miroir", TOUR, CIBLE)
	_a.impacter("miroir", CIBLE, 0.0, false, TOUR)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("gerbe_verre").size(), 1, "la gerbe reste")


func test_le_miroir_dans_effets_envoie_un_eclat_par_saut() -> void:
	var effets: Effets = _effets()
	for evenement: Dictionary in _evenements("miroir_brise"):
		effets.ajouter(evenement)
	verifier_egal(
		effets.elementaires().etats("eclat_miroir").size(),
		1 + VitrineArmes.SAUTS_REBOND,
		"un éclat pour le tir et un pour chaque saut"
	)
	effets.free()
