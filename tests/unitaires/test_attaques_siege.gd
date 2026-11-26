extends CasDeTest
## Les quatre armes de siège de la famille D22, arme par arme : le pétard de rempart et la mine de
## forge (mines posées au sol), le trébuchet de chambre et la grande bombarde (zones lancées en
## cloche). Le coup de siège gèle l'image comme celui de la bombe et s'arrête au rayon réel lu dans
## `data/armes.json`. Durées en images à 60 i/s.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(400.0, 300.0)
const ARMES: Dictionary = {
	"petard_de_rempart": ["petard", "mine"],
	"mine_de_forge": ["mine_forge", "mine"],
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


func _visibles(planche: String) -> int:
	var n: int = 0
	for e: Dictionary in _a.etats(planche):
		n += 1 if e["visible"] else 0
	return n


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


func test_les_armes_de_siege_ont_leur_element_et_leur_genre() -> void:
	for id: String in ARMES:
		var element: String = ARMES[id][0]
		verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
		verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
		verifier_egal(String(_effet(id)["kind"]), ARMES[id][1], "genre de %s" % id)
		verifier_egal(
			int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.SIEGE, "type de %s" % id
		)


# --- Pétard de rempart : mine ------------------------------------------------------------------


func test_le_petard_est_lance_puis_reste_pose_au_sol_visible() -> void:
	verifier(_a.piege("petard", TOUR, CIBLE))
	verifier_egal(_a.etats("petard").size(), 2, "un lancé et un pour le sol")
	_avancer(5)
	verifier_egal(_visibles("petard"), 1, "il vole, il n'est pas encore au sol")
	_avancer(80)
	var pose: Array[Dictionary] = _a.etats("petard")
	verifier_egal(pose.size(), 1, "il reste tant que la mine n'a pas servi")
	verifier((pose[0]["position"] as Vector2).distance_to(CIBLE) <= 1.0, "sur le chemin visé")
	_avancer(60 * 20)
	verifier_egal(_a.etats("petard").size(), 1, "toujours là après vingt secondes")
	verifier_proche(_a.etats("petard")[0]["alpha"], AttaquesElementaires.ALPHA_MAX, 0.001)


func test_la_meche_du_petard_crepite_sauf_en_mouvement_reduit() -> void:
	_a.piege("petard", TOUR, CIBLE)
	_avancer(80)
	var images: Dictionary = {}
	for i: int in 12:
		_avancer(1)
		images[int(_a.etats("petard")[0]["image"])] = true
	verifier_egal(images.size(), 2, "deux images de mèche en alternance")
	_a.vider()
	_a.mouvement_reduit = true
	_a.piege("petard", TOUR, CIBLE)
	_avancer(80)
	images.clear()
	for i: int in 12:
		_avancer(1)
		images[int(_a.etats("petard")[0]["image"])] = true
	verifier_egal(images.size(), 1, "figée en mouvement réduit")


func test_le_declenchement_retire_le_petard_et_pas_celui_d_une_autre_mine() -> void:
	_a.piege("petard", TOUR, CIBLE)
	_a.piege("petard", TOUR, CIBLE + Vector2(0.0, 200.0))
	_avancer(80)
	verifier_egal(_a.etats("petard").size(), 2)
	_a.retirer_pieges(CIBLE)
	verifier_egal(_a.etats("petard").size(), 1, "seule la mine déclenchée est retirée")


func test_le_pop_du_petard_est_dessine_au_rayon_reel_avec_un_gel_d_impact() -> void:
	var rayon: float = _rayon_px("petard_de_rempart")
	verifier(_a.impacter("petard", CIBLE, rayon, true))
	verifier_egal(_a.etats("pop_petard").size(), 1, "le pop d'étincelles")
	verifier_proche(_a.etats("pop_petard")[0]["diametre"], rayon * 2.0, rayon * 0.2, "au rayon")
	verifier_egal(_a.etats("").size(), 1, "un anneau")
	verifier_proche(_a.etats("")[0]["diametre"], rayon * 2.0, 0.5, "anneau au rayon exact")
	verifier(_a.gel_restant() > 0.0, "coup de siège : le gel visuel")
	verifier(_a.particules_actives() <= 12, "au plus douze particules")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0)


func test_mouvement_reduit_le_pop_ne_gele_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.piege("petard", TOUR, CIBLE)
	_a.impacter("petard", CIBLE, _rayon_px("petard_de_rempart"), true)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.gel_restant(), 0.0)
	verifier_egal(_a.etats("pop_petard").size(), 1, "le pop reste")


func test_le_petard_dans_effets_se_pose_au_tir_et_part_au_declenchement() -> void:
	var effets: Effets = _effets()
	var evenements: Array[Dictionary] = _evenements("petard_de_rempart")
	effets.ajouter(evenements[0])
	verifier_egal(effets.elementaires().etats("petard").size(), 2, "lancé au tir")
	verifier_egal(effets.formes_vivantes().has("mine"), false, "plus de forme générique")
	for _i: int in 80:
		effets.avancer(IMAGE)
	verifier_egal(effets.elementaires().etats("petard").size(), 1, "il attend")
	effets.ajouter(evenements[1])
	verifier_egal(effets.elementaires().etats("petard").size(), 0, "retiré au déclenchement")
	verifier_egal(effets.elementaires().etats("pop_petard").size(), 1, "le pop")
	effets.free()


# --- Mine de forge : mine ----------------------------------------------------------------------


func test_la_mine_de_forge_est_lancee_puis_reste_posee_et_sa_rune_rougeoie() -> void:
	verifier(_a.piege("mine_forge", TOUR, CIBLE))
	verifier_egal(_a.etats("mine_forge").size(), 2, "une lancée et une pour le sol")
	_avancer(80)
	var pose: Array[Dictionary] = _a.etats("mine_forge")
	verifier_egal(pose.size(), 1, "elle reste tant qu'elle n'a pas servi")
	verifier((pose[0]["position"] as Vector2).distance_to(CIBLE) <= 1.0, "sur le chemin visé")
	var images: Dictionary = {}
	for i: int in 30:
		_avancer(1)
		images[int(_a.etats("mine_forge")[0]["image"])] = true
	verifier_egal(images.size(), 2, "la rune pulse sur deux images")
	_a.retirer_pieges(CIBLE)
	verifier_egal(_a.etats("mine_forge").size(), 0, "retirée au déclenchement")


func test_la_forge_explose_comme_le_pack_et_la_bombe_mais_pas_le_petard() -> void:
	for element: String in ["mine_forge", "bombe"]:
		verifier(
			AttaquesElementaires.explosion_du_pack(element), "%s : explosion du pack" % element
		)
	for element: String in ["petard", "trebuchet", "feu", "inconnu"]:
		verifier(not AttaquesElementaires.explosion_du_pack(element), "%s : la sienne" % element)


func test_l_explosion_de_la_mine_de_forge_est_celle_du_pack_au_rayon_exact() -> void:
	var effets: Effets = _effets()
	var evenements: Array[Dictionary] = _evenements("mine_de_forge")
	effets.ajouter(evenements[0])
	for _i: int in 80:
		effets.avancer(IMAGE)
	effets.ajouter(evenements[1])
	verifier_contient(effets.formes_vivantes(), "explosion")
	var rayon: float = _rayon_px("mine_de_forge")
	var diametre: float = effets.echelle_de("explosion") * Effets.DIAMETRE_EXPLOSION
	verifier_proche(diametre, rayon * 2.0, rayon * 0.2, "diamètre = 2 × rayon")
	verifier_egal(effets.elementaires().etats("mine_forge").size(), 0, "la mine a servi")
	verifier_egal(effets.elementaires().etats("").size(), 1, "un anneau au rayon")
	verifier(effets.elementaires().particules_actives() <= 12, "au plus douze débris")
	verifier(effets.gel_restant() > 0.0, "gel d'un coup de siège")
	effets.free()
