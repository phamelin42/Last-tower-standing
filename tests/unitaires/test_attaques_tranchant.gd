extends CasDeTest
## Les neuf armes tranchantes du lot 9 (D22), arme par arme : mêmes phases et mêmes bornes que
## l'acier du lot 8 (anticipation 3 images, vol direct 7 ou en cloche 11, impact au pic dans le
## premier quart, zone au rayon réel lu dans `data/armes.json`). Durées en images à 60 i/s.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(360.0, 300.0)

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


func _rayon_px(id: String, cle: String = "rayon") -> float:
	return float(_effet(id)[cle]) * Apparence.PX_PAR_UNITE


## Vérifie que l'arme `id` est de ce genre, tranchante, et rendue par cet élément.
func _verifier_arme(id: String, element: String, genre: String) -> void:
	verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
	verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
	verifier_egal(String(_effet(id)["kind"]), genre, "genre de %s" % id)
	verifier_egal(
		int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.TRANCHANT, "type de %s" % id
	)


## Un `Effets` qui rend les événements de la vitrine pour l'arme `id`.
func _effets_de(id: String) -> Effets:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = [id] as Array[String]
	for evenement: Dictionary in vitrine.evenements_du_cycle(id):
		effets.ajouter(evenement)
	vitrine.free()
	return effets


# --- Serpe de vigne : zone, vulnérabilité ------------------------------------------------------


func test_la_serpe_est_une_zone() -> void:
	_verifier_arme("serpe_de_vigne", "serpe", "zone")


func test_la_serpe_dure_quatorze_images_et_passe_au_dessus_de_la_ligne() -> void:
	verifier_proche(_a.tirer("serpe", TOUR, CIBLE) / IMAGE, 14.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
	var serpe: Dictionary = _a.etats("serpe")[0]
	verifier(serpe["visible"], "elle vole")
	verifier(serpe["position"].y < CIBLE.y - 10.0, "en léger arc, au-dessus de la ligne")
	var avant: float = serpe["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("serpe")[0]["rotation"] - avant) > 0.1, "elle tourne en volant")
	verifier_egal(_a.etats("ombre").size(), 1, "son ombre reste au sol")


func test_le_balayage_de_la_serpe_a_le_rayon_reel_de_la_zone() -> void:
	var rayon: float = _rayon_px("serpe_de_vigne")
	_a.impacter("serpe", CIBLE, rayon)
	var balayage: Array[Dictionary] = _a.etats("balayage")
	verifier_egal(balayage.size(), 1, "un seul arc")
	verifier_proche(balayage[0]["diametre"], rayon * 2.0, rayon * 2.0 * 0.1, "au rayon réel")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1)
	verifier_egal(_a.particules_actives(), 2, "éclats d'acier et feuilles de vigne")
	_avancer(80)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_mouvement_reduit_la_serpe_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("serpe", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
	verifier_proche(_a.etats("serpe")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_a.impacter("serpe", CIBLE, 55.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("balayage").size(), 1, "l'arc reste")
