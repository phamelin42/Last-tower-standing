extends CasDeTest
## Les six armes perçantes (D22, famille du carreau), arme par arme : ce que le joueur voit part
## d'une anticipation, suit le genre de l'arme (cible unique, piège, rebond, barrage) et s'arrête au
## rayon réel lu dans `data/armes.json`. Durées en images à 60 i/s.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(360.0, 300.0)
const ARMES: Dictionary = {
	"arbalete_de_bureau": ["arbalete", "cible_unique"],
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


