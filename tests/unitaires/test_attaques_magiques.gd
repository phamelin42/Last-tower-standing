extends CasDeTest
## Les armes magiques de la famille D22, arme par arme : le cercle de givre (aura), la nova
## d'ambre (onde) et la tempête astrale (rebond). Ce que le joueur voit part de la tour ou saute de
## cible en cible, et s'arrête au rayon réel lu dans `data/armes.json`. Durées en images à 60 i/s.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(100.0, 300.0)
const CIBLE := Vector2(420.0, 300.0)
const ARMES: Dictionary = {
	"cercle_de_givre": ["cercle_givre", "aura"],
	"nova_d_ambre": ["nova", "onde"],
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


func _distances(planche: String, centre: Vector2) -> Array[float]:
	var liste: Array[float] = []
	for e: Dictionary in _a.etats(planche):
		liste.append((e["position"] as Vector2).distance_to(centre))
	return liste


func test_les_armes_magiques_ont_leur_element_et_leur_genre() -> void:
	for id: String in ARMES:
		var element: String = ARMES[id][0]
		verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
		verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
		verifier_egal(String(_effet(id)["kind"]), ARMES[id][1], "genre de %s" % id)
		verifier_egal(
			int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.MAGIQUE, "type de %s" % id
		)


# --- Cercle de givre : aura --------------------------------------------------------------------


func test_le_cercle_de_givre_est_une_couronne_de_cristaux_au_rayon_reel() -> void:
	var rayon: float = float(_effet("cercle_de_givre")["rayon"]) * Apparence.PX_PAR_UNITE
	verifier(_a.aura("cercle_givre", TOUR, rayon))
	verifier_egal(_a.etats("eclat_glace").size(), 8, "huit cristaux")
	for d: float in _distances("eclat_glace", TOUR):
		verifier(d < rayon * 0.5, "ils naissent près de la tour")
	_avancer(AttaquesElementaires.IMAGES_COURONNE_OUVERTURE)
	for d: float in _distances("eclat_glace", TOUR):
		verifier(d <= rayon + 0.01, "jamais au-delà du rayon")
		verifier(d >= rayon - 14.0, "le cristal affleure le rayon")
	verifier_egal(_a.etats("").size(), 1, "un anneau au rayon exact")
	verifier_proche(_a.etats("")[0]["diametre"], rayon * 2.0, 0.5, "anneau au rayon réel")


func test_le_cercle_de_givre_laisse_du_givre_au_sol_au_rayon_puis_tout_s_efface() -> void:
	var rayon: float = float(_effet("cercle_de_givre")["rayon"]) * Apparence.PX_PAR_UNITE
	_a.aura("cercle_givre", TOUR, rayon)
	verifier_egal(_a.etats("givre_sol").size(), 1, "du givre au sol")
	verifier_proche(_a.etats("givre_sol")[0]["diametre"], rayon * 2.0, rayon * 0.1)
	verifier(_a.particules_actives() <= 8, "au plus huit particules")
	verifier(_a.opacite_max() <= AttaquesElementaires.ALPHA_MAX + 0.0001, "jamais opaque")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "plus rien")


func test_mouvement_reduit_le_cercle_de_givre_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.aura("cercle_givre", TOUR, 125.0)
	_avancer(3)
	var avant: Array[float] = []
	for e: Dictionary in _a.etats("eclat_glace"):
		avant.append(e["rotation"])
	_avancer(3)
	var apres: Array[float] = []
	for e: Dictionary in _a.etats("eclat_glace"):
		apres.append(e["rotation"])
	for i: int in avant.size():
		verifier_proche(avant[i], apres[i], 0.0001, "pas de rotation")
	verifier_egal(_a.particules_actives(), 0)


func test_le_cercle_de_givre_dans_effets_dessine_la_couronne_a_chaque_coup() -> void:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = ["cercle_de_givre"] as Array[String]
	var evenements: Array[Dictionary] = vitrine.evenements_du_cycle("cercle_de_givre")
	for evenement: Dictionary in evenements:
		effets.ajouter(evenement)
	verifier_egal(effets.elementaires().etats("eclat_glace").size(), 8, "la couronne")
	verifier_egal(effets.formes_vivantes().has("anneau"), false, "plus d'anneau générique")
	vitrine.free()
	effets.free()


# --- Nova d'ambre : onde -----------------------------------------------------------------------


func test_la_nova_va_aussi_vite_et_aussi_loin_que_l_onde_des_donnees() -> void:
	var effet: Dictionary = _effet("nova_d_ambre")
	verifier_proche(AttaqueNova.RAYON_PX, float(effet["rayon_max"]) * Apparence.PX_PAR_UNITE, 0.01)
	verifier_proche(AttaqueNova.VITESSE_PX, float(effet["vitesse"]) * Apparence.PX_PAR_UNITE, 0.01)


func test_le_front_ambre_part_de_la_tour_et_avance_a_la_vitesse_de_l_onde() -> void:
	verifier(_a.onde("nova", TOUR))
	verifier_egal(_a.etats("vague_ambre").size(), AttaqueNova.LAMES, "un front de croissants")
	_avancer(10)
	for d: float in _distances("vague_ambre", TOUR):
		verifier_proche(
			d, AttaqueNova.VITESSE_PX * 10.0 * IMAGE, 0.5, "10 images à la vitesse réelle"
		)
	verifier_egal(_a.etats("vague_ambre")[0]["diametre"], 0.0, "le front n'est pas une zone pleine")


func test_la_nova_ne_depasse_jamais_son_rayon_et_s_efface_a_la_fin() -> void:
	_a.onde("nova", TOUR)
	var fin: int = int(AttaqueNova.RAYON_PX / AttaqueNova.VITESSE_PX / IMAGE)
	_avancer(fin - 1)
	for d: float in _distances("vague_ambre", TOUR):
		verifier(d <= AttaqueNova.RAYON_PX + 0.01, "jamais au-delà du rayon")
	for lame: Dictionary in _a.etats("vague_ambre"):
		verifier(lame["alpha"] < AttaquesElementaires.ALPHA_MAX * 0.8, "elle s'efface sur la fin")
	_avancer(80)
	verifier_egal(_a.nombre_vivants(), 0, "plus rien")


func test_des_braises_naissent_quand_le_front_passe_et_pas_avant() -> void:
	_a.onde("nova", TOUR)
	verifier_egal(
		_a.etats("braise").size(), AttaqueNova.COURONNES_BRAISES.size() * AttaqueNova.BRAISES
	)
	var visibles: int = 0
	for b: Dictionary in _a.etats("braise"):
		visibles += 1 if b["visible"] else 0
	verifier_egal(visibles, 0, "aucune braise tant que le front n'est pas passé")
	_avancer(int(AttaqueNova.RAYON_PX / AttaqueNova.VITESSE_PX / IMAGE))
	visibles = 0
	for b: Dictionary in _a.etats("braise"):
		visibles += 1 if b["visible"] else 0
	verifier(visibles > 0, "les braises restent derrière le front")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0)


func test_la_nova_dans_effets_est_dessinee_une_fois_au_depart() -> void:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = ["nova_d_ambre"] as Array[String]
	var evenements: Array[Dictionary] = vitrine.evenements_du_cycle("nova_d_ambre")
	effets.ajouter(evenements[0])
	verifier_egal(effets.elementaires().etats("vague_ambre").size(), AttaqueNova.LAMES, "le front")
	effets.ajouter(evenements[1])
	verifier_egal(
		effets.elementaires().etats("vague_ambre").size(),
		AttaqueNova.LAMES,
		"l'impact n'en ajoute pas"
	)
	vitrine.free()
	effets.free()
