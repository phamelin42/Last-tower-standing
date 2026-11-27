extends CasDeTest
## Le son d'impact part quand l'impact devient visible, pas quand l'événement arrive : un projectile
## en vol (tir direct, bombe en cloche) retarde l'effet, donc le son. Un impact que le plafond
## n'a pas dessiné, ou le rayon décoratif d'un tir tournant, ne fait aucun bruit.

const IMAGE: float = 1.0 / 60.0
const IMAGES_MAX: int = 90
const ARRIVEE := Vector2(300, -200)

var _effets: Effets = null
var _image: int = 0
var _visibles: Array[int] = []
var _sons: Array[int] = []
var _types: Array[int] = []


func avant_chaque() -> void:
	_effets = Effets.new()
	arbre.root.add_child(_effets)
	_image = 0
	_visibles.clear()
	_sons.clear()
	_types.clear()
	_effets.impact_visible.connect(
		func(_ou: Vector2, _r: float, _f: bool) -> void: _visibles.append(_image)
	)
	_effets.impact_visible_de_type.connect(
		func(type_degats: int) -> void:
			_sons.append(_image)
			_types.append(type_degats)
	)


func apres_chaque() -> void:
	if is_instance_valid(_effets):
		if _effets.get_parent() != null:
			_effets.get_parent().remove_child(_effets)
		_effets.free()
	_effets = null


func _evenement(k: String, type_degats: int, genre: String, rayon: float = 0.0) -> Dictionary:
	return {
		"k": k,
		"t": 1,
		"de": Vector2.ZERO,
		"vers": ARRIVEE,
		"type_degats": type_degats,
		"rayon": rayon,
		"genre": genre,
	}


func _jouer(evenements: Array[Dictionary]) -> void:
	for evenement: Dictionary in evenements:
		_effets.ajouter(evenement)
	for i: int in IMAGES_MAX:
		_image += 1
		_effets.avancer(IMAGE)


## Les événements de tir et d'impact que la simulation émet pour l'arme `id` du catalogue.
func _evenements_de(id: String) -> Array[Dictionary]:
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = [id] as Array[String]
	var liste: Array[Dictionary] = [
		vitrine.evenement_de(id, "tir"), vitrine.evenement_de(id, "impact")
	]
	vitrine.free()
	return liste


func _verifier_suit_l_effet(evenements: Array[Dictionary], genre: String, type_degats: int) -> void:
	_jouer(evenements)
	verifier(_visibles.size() >= 1, "%s : l'impact devient visible" % genre)
	verifier_egal(_sons.size(), _visibles.size(), "%s : un son par impact visible" % genre)
	if _visibles.is_empty() or _sons.size() != _visibles.size():
		return
	for i: int in _visibles.size():
		verifier(
			absi(_sons[i] - _visibles[i]) <= 1,
			"%s : son image %d, impact visible image %d" % [genre, _sons[i], _visibles[i]]
		)
		verifier_egal(_types[i], type_degats, "%s : le type de dégâts accompagne le son" % genre)
	verifier(_visibles[0] > 0, "%s : l'impact attend son projectile" % genre)


func test_un_tir_direct_sonne_a_l_image_de_l_impact_visible() -> void:
	_verifier_suit_l_effet(
		[
			_evenement("tir", Types.TypeDegats.PERCANT, ""),
			_evenement("impact", Types.TypeDegats.PERCANT, "")
		],
		"direct",
		Types.TypeDegats.PERCANT
	)


func test_une_bombe_en_cloche_sonne_a_l_image_de_l_impact_visible() -> void:
	_effets.catalogue = Donnees.charger().ids_catalogue
	_verifier_suit_l_effet(_evenements_de("obusier_de_breche"), "bombe", Types.TypeDegats.SIEGE)


func test_aucun_son_avant_l_arrivee_du_projectile() -> void:
	_effets.catalogue = Donnees.charger().ids_catalogue
	for evenement: Dictionary in _evenements_de("obusier_de_breche"):
		_effets.ajouter(evenement)
	verifier_egal(_sons.size(), 0, "l'événement seul ne fait aucun bruit")


func test_un_impact_que_le_plafond_n_a_pas_dessine_ne_sonne_pas() -> void:
	var i: int = 0
	while _effets.nombre_vivants() < Effets.PLAFOND and i < 4 * Effets.PLAFOND:
		var mine: Dictionary = _evenement("tir", Types.TypeDegats.MAGIQUE, "mine", 150.0)
		mine["de"] = Vector2(5000 + i, 0)
		mine["vers"] = Vector2(5000 + i, 100)
		_effets.ajouter(mine)
		i += 1
	_sons.clear()
	_visibles.clear()
	_effets.ajouter(_evenement("impact", Types.TypeDegats.SIEGE, "", 120.0))
	for k: int in 30:
		_effets.avancer(IMAGE)
	verifier_egal(_visibles.size(), 0, "le plafond empêche de dessiner l'impact")
	verifier_egal(_visibles.size(), _sons.size(), "autant de sons que d'impacts visibles")
