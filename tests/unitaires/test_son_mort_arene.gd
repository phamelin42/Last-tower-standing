extends CasDeTest
## Le son de mort part quand la mort devient visible : au crâne, ou à l'explosion d'un tonneau ou
## d'un artificier, jamais à l'événement quand un impact retient l'ennemi. Une mort qu'on ne montre
## pas (plafond de crânes) ne fait pas de bruit. L'arène d'un autre joueur reste muette.

const SCENE := "res://scenes/arene_2d.tscn"
const PAS: float = 1.0 / 60.0
const POSITION := Vector2(200.0, 100.0)
const TYPE_TIR: int = Types.TypeDegats.PERCANT

var _arene: Arene2D = null
var _donnees: Donnees = null
var _tick: int = 0
var _sons: Array[int] = []
var _image: int = 0


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_arene = (load(SCENE) as PackedScene).instantiate() as Arene2D
	_arene.donnees = _donnees
	arbre.root.add_child(_arene)
	_arene.reinitialiser()
	_tick = 0
	_image = 0
	_sons.clear()
	_arene.son_mort_demande.connect(func() -> void: _sons.append(_image))


func apres_chaque() -> void:
	if is_instance_valid(_arene):
		if _arene.get_parent() != null:
			_arene.get_parent().remove_child(_arene)
		_arene.free()
	_arene = null


func _vue(ennemis: Array[Vector2], famille: int, evenements: Array[Dictionary] = []) -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	for i: int in ennemis.size():
		vue.ennemis_id.append(i + 1)
		vue.ennemis_pos.append(ennemis[i])
		vue.ennemis_famille.append(famille)
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	vue.evenements = evenements
	return vue


func _evenement(k: String, ou: Vector2 = POSITION) -> Dictionary:
	var e := {"k": k, "t": _tick, "de": Vector2.ZERO, "vers": ou, "rayon": 0.0}
	e["type_degats"] = TYPE_TIR
	if k == "mort":
		e["de"] = ou
	return e


func _images(n: int) -> void:
	for i: int in n:
		_image += 1
		_arene._process(PAS)


func _famille_explosive() -> int:
	var ids: PackedStringArray = Apparence.ids_entites(_donnees)
	for f: int in _donnees.familles.size():
		if Effets.famille_explosive(ids[f]):
			return f
	return -1


func test_une_mort_sans_impact_en_attente_sonne_avec_son_crane() -> void:
	_arene.afficher(_vue([POSITION], 0), 0.0)
	_arene.afficher(_vue([], 0, [_evenement("mort")]), 0.0)
	verifier_egal(_arene.nombre_morts_visibles(), 1, "crâne immédiat")
	verifier_egal(_sons.size(), 1, "son immédiat")


func test_un_ennemi_retenu_sonne_a_l_apparition_du_crane_pas_a_l_evenement() -> void:
	_arene.afficher(_vue([POSITION], 0), 0.0)
	_arene.afficher(_vue([], 0, [_evenement("tir"), _evenement("impact"), _evenement("mort")]), 0.0)
	verifier_egal(_sons.size(), 0, "rien à l'événement : l'ennemi est encore là")
	var crane: int = -1
	for i: int in 40:
		_images(1)
		if _arene.nombre_morts_visibles() > 0:
			crane = _image
			break
	verifier(crane > 1, "le crâne vient après l'événement")
	verifier_egal(_sons.size(), 1, "un seul son")
	if _sons.size() == 1:
		verifier(absi(_sons[0] - crane) <= 1, "son image %d, crâne image %d" % [_sons[0], crane])


func test_un_explosif_sonne_quand_son_explosion_est_montree() -> void:
	var f: int = _famille_explosive()
	verifier(f >= 0, "une famille explosive existe")
	if f < 0:
		return
	_arene.afficher(_vue([POSITION], f), 0.0)
	_arene.afficher(_vue([], f, [_evenement("mort")]), 0.0)
	verifier_egal(_arene.nombre_morts_visibles(), 0, "pas de crâne pour un explosif")
	verifier_egal(_sons.size(), 1, "mais le son de sa mort part avec l'explosion")


func test_au_dela_du_plafond_de_cranes_une_mort_non_montree_ne_sonne_pas() -> void:
	var positions: Array[Vector2] = []
	var evenements: Array[Dictionary] = []
	for i: int in CranesArene.PLAFOND + 6:
		var ou := Vector2(100.0 + 20.0 * i, 0.0)
		positions.append(ou)
		evenements.append(_evenement("mort", ou))
	_arene.afficher(_vue(positions, 0), 0.0)
	_arene.afficher(_vue([], 0, evenements), 0.0)
	verifier_egal(_arene.nombre_morts_visibles(), CranesArene.PLAFOND, "plafond de crânes")
	verifier_egal(_sons.size(), _arene.nombre_morts_visibles(), "un son par mort montrée")


func test_l_arene_d_un_autre_joueur_reste_muette() -> void:
	var source := SourceFactice.new()
	arbre.root.add_child(source)
	_arene.lier(source)
	_arene.montrer_arene(2, "Camille", 2)
	source.emettre_vue_regardee(2, _vue([POSITION], 0))
	source.emettre_vue_regardee(2, _vue([], 0, [_evenement("mort")]))
	_images(5)
	verifier_egal(_arene.nombre_morts_visibles(), 1, "la mort s'affiche")
	verifier_egal(_sons.size(), 0, "sans bruit")
	_arene.lier(null)
	source.free()
