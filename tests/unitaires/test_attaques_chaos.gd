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


func _distances(planche: String, centre: Vector2) -> Array[float]:
	var liste: Array[float] = []
	for e: Dictionary in _a.etats(planche):
		liste.append((e["position"] as Vector2).distance_to(centre))
	return liste


# --- Vortex de verre : onde et vol de vie ------------------------------------------------------


func test_le_vortex_est_une_onde_qui_soigne() -> void:
	_verifier_arme("vortex_de_verre", "vortex", "onde")
	verifier_egal(String(_donnees.armes["vortex_de_verre"]["statuts"][0]["kind"]), "vol_de_vie")


func test_le_vortex_va_aussi_vite_et_aussi_loin_que_l_onde_des_donnees() -> void:
	var effet: Dictionary = _effet("vortex_de_verre")
	verifier_proche(
		AttaqueVortex.RAYON_PX, float(effet["rayon_max"]) * Apparence.PX_PAR_UNITE, 0.01
	)
	verifier_proche(
		AttaqueVortex.VITESSE_PX, float(effet["vitesse"]) * Apparence.PX_PAR_UNITE, 0.01
	)


func test_les_bras_de_verre_partent_de_la_tour_a_la_vitesse_de_l_onde() -> void:
	verifier(_a.onde("vortex", TOUR))
	verifier_egal(_a.etats("vague_verre").size(), AttaqueVortex.BRAS, "une spirale de bras")
	_avancer(10)
	for d: float in _distances("vague_verre", TOUR):
		verifier_proche(
			d, AttaqueVortex.VITESSE_PX * 10.0 * IMAGE, 0.5, "10 images à la vitesse réelle"
		)
	verifier_egal(_a.etats("vague_verre")[0]["diametre"], 0.0, "ce n'est pas une zone pleine")


func test_le_vortex_ne_depasse_jamais_son_rayon_et_s_efface_a_la_fin() -> void:
	_a.onde("vortex", TOUR)
	var fin: int = int(AttaqueVortex.RAYON_PX / AttaqueVortex.VITESSE_PX / IMAGE)
	_avancer(fin - 1)
	for d: float in _distances("vague_verre", TOUR):
		verifier(d <= AttaqueVortex.RAYON_PX + 0.01, "jamais au-delà du rayon")
	for bras: Dictionary in _a.etats("vague_verre"):
		verifier(bras["alpha"] < AttaquesElementaires.ALPHA_MAX * 0.8, "il s'efface sur la fin")
	_avancer(80)
	verifier_egal(_a.nombre_vivants(), 0, "plus rien")


func test_des_eclats_restent_derriere_le_front_et_pas_avant() -> void:
	_a.onde("vortex", TOUR)
	var attendus: int = AttaqueVortex.COURONNES_ECLATS.size() * AttaqueVortex.ECLATS
	verifier_egal(_a.etats("eclat_verre").size(), attendus)
	verifier_egal(_visibles("eclat_verre"), 0, "aucun éclat tant que le front n'est pas passé")
	_avancer(int(AttaqueVortex.RAYON_PX / AttaqueVortex.VITESSE_PX / IMAGE))
	verifier(_visibles("eclat_verre") > 0, "les éclats restent derrière le front")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0)


func test_le_vortex_dans_effets_est_dessine_une_fois_au_depart() -> void:
	var effets: Effets = _effets()
	var evenements: Array[Dictionary] = _evenements("vortex_de_verre")
	effets.ajouter(evenements[0])
	verifier_egal(effets.elementaires().etats("vague_verre").size(), AttaqueVortex.BRAS, "le front")
	effets.ajouter(evenements[1])
	verifier_egal(
		effets.elementaires().etats("vague_verre").size(),
		AttaqueVortex.BRAS,
		"l'impact n'en ajoute pas"
	)
	effets.free()


# --- Horloge folle : barrage et brûlure --------------------------------------------------------


func test_l_horloge_est_un_barrage_qui_brule() -> void:
	_verifier_arme("horloge_folle", "horloge", "barrage")
	verifier_egal(String(_donnees.armes["horloge_folle"]["statuts"][0]["kind"]), "brulure")


func test_chaque_rouage_part_deux_images_apres_le_precedent_et_tourne() -> void:
	var retard: float = AttaquesElementaires.retard_barrage("horloge")
	var premiere: float = _a.tirer("horloge", TOUR, CIBLE, 0.0)
	var seconde: float = _a.tirer("horloge", TOUR, CIBLE, retard)
	verifier_proche(premiere / IMAGE, 10.0, 0.01, "anticipation + vol")
	verifier_proche((seconde - premiere) / IMAGE, 2.0, 0.01, "décalés de 2 images")
	verifier_egal(_a.etats("engrenage").size(), 2, "un rouage par tir")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	var avant: float = _a.etats("engrenage")[0]["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("engrenage")[0]["rotation"] - avant) > 0.5, "il tourne")


func test_un_seul_anneau_au_rayon_reel_pour_tout_le_barrage_de_l_horloge() -> void:
	var rayon: float = _rayon_px("horloge_folle")
	for k: int in 7:
		_a.impacter_en_groupe("horloge", CIBLE + Vector2(0.0, k * 6.0), rayon)
	verifier_egal(_a.etats("").size(), 0, "aucun anneau par rouage")
	_a.zone("horloge", CIBLE, rayon)
	verifier_egal(_a.etats("").size(), 1, "un anneau pour le tir")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1, "au rayon réel")


func test_chaque_impact_de_l_horloge_est_petit_avec_peu_d_eclats() -> void:
	_a.impacter_en_groupe("horloge", CIBLE, 30.0)
	verifier_egal(_a.etats("eclat_engrenage").size(), 1, "un éclat de rouages")
	verifier(_a.etats("eclat_engrenage")[0]["diametre"] <= 60.0, "reste petit")
	verifier(_a.particules_actives() <= 8, "au plus huit particules par impact")
	verifier_egal(_a.gel_restant(), 0.0, "coup courant : pas de gel")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")


func test_l_horloge_dans_effets_lance_un_rouage_par_impact_et_un_seul_anneau() -> void:
	var effets: Effets = _effets()
	var evenements: Array[Dictionary] = _evenements("horloge_folle")
	for evenement: Dictionary in evenements:
		effets.ajouter(evenement)
	var impacts: int = 0
	for evenement: Dictionary in evenements:
		impacts += 1 if evenement["k"] == "impact" else 0
	verifier_egal(
		effets.elementaires().etats("engrenage").size(), impacts, "un rouage par impact du barrage"
	)
	var anneaux: int = 0
	for _i: int in 40:
		effets.avancer(IMAGE)
		anneaux = maxi(anneaux, effets.elementaires().etats("").size())
	verifier_egal(anneaux, 1, "un seul anneau")
	effets.free()


func test_mouvement_reduit_l_horloge_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("horloge", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	verifier_proche(_a.etats("engrenage")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	var image: int = _a.etats("engrenage")[0]["image"]
	_avancer(3)
	verifier_egal(_a.etats("engrenage")[0]["image"], image, "dents figées")
	_a.impacter_en_groupe("horloge", CIBLE, 30.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("eclat_engrenage").size(), 1, "l'éclat reste")
