extends CasDeTest
## Les six armes perçantes (D22, famille du carreau), arme par arme : ce que le joueur voit part
## d'une anticipation, suit le genre de l'arme (cible unique, piège, rebond, barrage) et s'arrête au
## rayon réel lu dans `data/armes.json`. Durées en images à 60 i/s.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(360.0, 300.0)
const ARMES: Dictionary = {
	"arbalete_de_bureau": ["arbalete", "cible_unique"],
	"chausse_trape": ["chausse_trape", "piege"],
	"carreau_ricochet": ["ricochet", "rebond"],
	"herse_de_ressorts": ["herse", "barrage"],
}

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


func test_les_six_armes_percantes_ont_leur_element_et_leur_genre() -> void:
	for id: String in ARMES:
		var element: String = ARMES[id][0]
		verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
		verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
		verifier_egal(String(_effet(id)["kind"]), ARMES[id][1], "genre de %s" % id)
		verifier_egal(
			int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.PERCANT, "type de %s" % id
		)


# --- Arbalète de bureau : cible unique ---------------------------------------------------------


func test_le_carreau_de_l_arbalete_dure_dix_images_et_vise_la_cible() -> void:
	verifier_proche(_a.tirer("arbalete", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	var carreau: Dictionary = _a.etats("carreau")[0]
	verifier(carreau["visible"], "le carreau vole")
	verifier_proche(carreau["rotation"], 0.0, 0.01, "il pointe vers la cible")


func test_l_impact_de_l_arbalete_est_une_petite_gerbe_et_un_carreau_plante_six_images() -> void:
	_a.impacter("arbalete", CIBLE, 0.0)
	verifier_egal(_a.etats("gerbe").size(), 1, "une gerbe d'éclats")
	verifier_egal(_a.etats("plante").size(), 1, "un carreau planté")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	_avancer(4)
	verifier_egal(_a.etats("plante").size(), 1, "encore planté à 4 images")
	_avancer(6)
	verifier_egal(_a.etats("plante").size(), 0, "retiré après 6 images")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")


func test_mouvement_reduit_l_arbalete_garde_ses_sprites_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("arbalete", TOUR, CIBLE)
	_a.impacter("arbalete", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("plante").size(), 1, "le carreau planté reste")


# --- Chausse-trape : piège ---------------------------------------------------------------------


func test_trois_chausse_trapes_sont_lancees_en_eventail_puis_restent_au_sol() -> void:
	verifier(_a.piege("chausse_trape", TOUR, CIBLE))
	verifier_egal(_a.etats("chausse_trape").size(), 6, "trois lancées et trois pour le sol")
	_avancer(6)
	var en_vol: Array[Dictionary] = _a.etats("chausse_trape")
	var visibles: int = 0
	for c: Dictionary in en_vol:
		if c["visible"]:
			visibles += 1
	verifier(visibles >= 1, "au moins une est en l'air")
	_avancer(80)
	var posees: Array[Dictionary] = _a.etats("chausse_trape")
	verifier_egal(posees.size(), 3, "elles restent tant que le piège n'a pas servi")
	var ecart_y: float = 0.0
	for c: Dictionary in posees:
		verifier(c["visible"], "posée et visible")
		verifier((c["position"] as Vector2).distance_to(CIBLE) <= 40.0, "autour de la cible")
		ecart_y = maxf(ecart_y, absf((c["position"] as Vector2).y - CIBLE.y))
	verifier(ecart_y >= 8.0, "en éventail, pas empilées")


func test_les_chausse_trapes_posees_ne_s_effacent_pas_avant_le_declenchement() -> void:
	_a.piege("chausse_trape", TOUR, CIBLE)
	_avancer(60 * 20)
	verifier_egal(_a.etats("chausse_trape").size(), 3, "toujours là après vingt secondes")
	verifier_proche(_a.etats("chausse_trape")[0]["alpha"], AttaquesElementaires.ALPHA_MAX, 0.001)


func test_le_declenchement_retire_les_pointes_du_piege_et_pas_celles_d_un_autre() -> void:
	_a.piege("chausse_trape", TOUR, CIBLE)
	var ailleurs: Vector2 = CIBLE + Vector2(0.0, 200.0)
	_a.piege("chausse_trape", TOUR, ailleurs)
	_avancer(60)
	verifier_egal(_a.etats("chausse_trape").size(), 6, "trois posées par piège, plus les lancées")
	_a.retirer_pieges(CIBLE)
	verifier_egal(_a.etats("chausse_trape").size(), 3, "seul le piège déclenché est retiré")


func test_le_declenchement_dessine_les_pointes_et_l_anneau_au_rayon_reel() -> void:
	var rayon: float = _rayon_px("chausse_trape")
	_a.impacter("chausse_trape", CIBLE, rayon)
	verifier_egal(_a.etats("pointes_sol").size(), 1, "les pointes jaillissent")
	verifier_proche(_a.etats("pointes_sol")[0]["diametre"], rayon * 2.0, rayon * 0.2, "au rayon")
	verifier_egal(_a.etats("").size(), 1, "un anneau")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1, "rien au-delà de la zone")
	verifier(_a.particules_actives() <= 8, "au plus huit particules")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0)


func test_chausse_trape_dans_effets_pose_au_tir_et_retire_au_declenchement() -> void:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = ["chausse_trape"] as Array[String]
	var evenements: Array[Dictionary] = vitrine.evenements_du_cycle("chausse_trape")
	effets.ajouter(evenements[0])
	verifier_egal(effets.elementaires().etats("chausse_trape").size(), 6, "lancée au tir")
	verifier_egal(effets.formes_vivantes().has("piege"), false, "plus de croix générique")
	for _i: int in 80:
		effets.avancer(IMAGE)
	verifier_egal(effets.elementaires().etats("chausse_trape").size(), 3, "elle attend")
	effets.ajouter(evenements[1])
	verifier_egal(effets.elementaires().etats("chausse_trape").size(), 0, "retirée au déclenchement")
	verifier_egal(effets.elementaires().etats("pointes_sol").size(), 1, "les pointes jaillissent")
	vitrine.free()
	effets.free()


func test_mouvement_reduit_les_chausse_trapes_ne_tournent_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.piege("chausse_trape", TOUR, CIBLE)
	_avancer(5)
	for c: Dictionary in _a.etats("chausse_trape"):
		verifier_proche(c["rotation"], c["rotation"], 0.0)
	_a.impacter("chausse_trape", CIBLE, 45.0)
	verifier_egal(_a.particules_actives(), 0)


# --- Carreau ricochet : rebond -----------------------------------------------------------------


func test_un_saut_du_carreau_est_un_vol_de_sept_images_sans_anticipation() -> void:
	var fin: float = _a.saut("ricochet", CIBLE, CIBLE + Vector2(90.0, 20.0), 4.0 * IMAGE)
	verifier_proche(fin / IMAGE, 4.0 + AttaquesElementaires.IMAGES_VOL_DIRECT, 0.01)
	verifier_egal(_a.etats("depart").size(), 0, "pas d'anticipation à chaque saut")
	verifier_egal(_a.etats("carreau").size(), 1, "un carreau par saut")


func test_chaque_rebond_du_carreau_jette_des_etincelles_sans_planter() -> void:
	_a.impacter("ricochet", CIBLE, 0.0)
	verifier_egal(_a.etats("gerbe").size(), 1, "une gerbe à chaque rebond")
	verifier_egal(_a.etats("plante").size(), 0, "il ne se plante pas : il repart")
	verifier(_a.diametre_max() <= 60.0)
	verifier(_a.particules_actives() >= 1, "des étincelles")


# --- Herse de ressorts : barrage et étourdissement ---------------------------------------------


func test_chaque_pique_de_la_herse_part_deux_images_apres_le_precedent() -> void:
	var retard: float = AttaquesElementaires.RETARD_BARRAGE
	var premiere: float = _a.tirer("herse", TOUR, CIBLE, 0.0)
	var seconde: float = _a.tirer("herse", TOUR, CIBLE, retard)
	verifier_proche((seconde - premiere) / IMAGE, 2.0, 0.01, "décalés de 2 images")
	verifier_egal(_a.etats("pique").size(), 2, "un pique par tir")


func test_un_seul_anneau_au_rayon_reel_pour_toute_la_herse() -> void:
	var rayon: float = _rayon_px("herse_de_ressorts")
	for k: int in 5:
		_a.impacter_en_groupe("herse", CIBLE + Vector2(0.0, k * 6.0), rayon)
	verifier_egal(_a.etats("").size(), 0, "aucun anneau par pique")
	_a.zone("herse", CIBLE, rayon)
	verifier_egal(_a.etats("").size(), 1, "un anneau pour le tir")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1, "au rayon réel")


