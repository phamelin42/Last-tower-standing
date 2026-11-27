extends CasDeTest
## L'arène 2D et l'apparence de la tour (T9.25) : la tour du joueur et celle de l'arène regardée
## montrent chacune leurs propres statistiques, et rien de l'apparence ne déplace un ennemi.

const SCENE := "res://scenes/arene_2d.tscn"

var _arene: Arene2D = null
var _donnees: Donnees = null
var _tick: int = 0


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_arene = (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(_arene)
	_arene.reinitialiser()
	_tick = 0


func apres_chaque() -> void:
	if is_instance_valid(_arene):
		if _arene.get_parent() != null:
			_arene.get_parent().remove_child(_arene)
		_arene.free()
	_arene = null


func _vue(epines: float, armure: float = 0.0) -> VueArene:
	var v := VueArene.new()
	_tick += 1
	v.tick = _tick
	v.tour_epines = epines
	v.tour_armure = armure
	return v


func _seuil(stat: String, palier: int) -> float:
	var stats: Dictionary = _donnees.apparence_tour["stats"]
	return float((stats[stat] as Array)[palier - 1])


func test_la_tour_regardee_montre_les_statistiques_de_son_joueur() -> void:
	var propres := _vue(_seuil("epines", 3))
	_arene.afficher(propres, 0.0)
	var sup := _arene.superpositions()
	verifier(sup.sprite("epines", "avant").visible, "ma tour montre ses piques")
	verifier_faux(sup.sprite("armure", "avant").visible, "et pas d'armure")
	_arene.montrer_arene(77, "Autre", 2)
	verifier_faux(sup.sprite("epines", "avant").visible, "la tour regardée n'a pas mes piques")
	var autre := _vue(0.0, _seuil("armure", 2))
	_arene.afficher(autre, 0.0)
	verifier(sup.sprite("armure", "avant").visible, "elle montre l'armure de son joueur")
	verifier_faux(sup.sprite("epines", "avant").visible, "sans mes piques")
	_arene.montrer_arene(-1, "", 0)
	verifier_faux(sup.sprite("armure", "avant").visible, "retour : plus l'armure de l'autre")


func test_l_apparence_ne_deplace_aucun_ennemi() -> void:
	var vue := _vue(0.0)
	for i: int in 5:
		vue.ennemis_id.append(i + 1)
		vue.ennemis_pos.append(Vector2(120.0 * i + 300.0, -80.0 * i))
		vue.ennemis_famille.append(0)
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	_arene.afficher(vue, 0.0)
	var avant: Array[Vector2] = []
	for i: int in _arene.nombre_instances_visibles(0):
		avant.append(_arene.position_instance(0, i))
	var maximum := _vue(_seuil("epines", 3), _seuil("armure", 3))
	maximum.tour_pv_max = _seuil("pv_max", 3)
	maximum.ennemis_id = vue.ennemis_id
	maximum.ennemis_pos = vue.ennemis_pos
	maximum.ennemis_famille = vue.ennemis_famille
	maximum.ennemis_pv = vue.ennemis_pv
	maximum.ennemis_statuts = vue.ennemis_statuts
	_arene.afficher(maximum, 0.0)
	var apres: Array[Vector2] = []
	for i: int in _arene.nombre_instances_visibles(0):
		apres.append(_arene.position_instance(0, i))
	verifier(not avant.is_empty(), "des ennemis sont dessinés")
	verifier_egal(apres, avant, "les ennemis sont aux mêmes places")
