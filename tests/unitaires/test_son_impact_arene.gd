extends CasDeTest
## L'arène demande le son d'un impact à l'image où il devient visible, avec son type de dégâts ;
## quand on regarde l'arène d'un autre joueur, elle reste muette comme avant (seule la partie du
## joueur a des sons).

const SCENE := "res://scenes/arene_2d.tscn"
const PAS: float = 1.0 / 60.0
const CIBLE := Vector2(200.0, 100.0)
const TYPE_TIR: int = Types.TypeDegats.PERCANT

var _arene: Arene2D = null
var _tick: int = 0
var _demandes: Array[int] = []


func avant_chaque() -> void:
	_arene = (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(_arene)
	_arene.reinitialiser()
	_tick = 0
	_demandes.clear()
	_arene.son_impact_demande.connect(func(type_degats: int) -> void: _demandes.append(type_degats))


func apres_chaque() -> void:
	if is_instance_valid(_arene):
		if _arene.get_parent() != null:
			_arene.get_parent().remove_child(_arene)
		_arene.free()
	_arene = null


func _vue_avec_tir() -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	for k: String in ["tir", "impact"]:
		(
			vue
			. evenements
			. append(
				{
					"k": k,
					"t": _tick,
					"de": Vector2.ZERO,
					"vers": CIBLE,
					"type_degats": TYPE_TIR,
					"rayon": 0.0,
				}
			)
		)
	return vue


func _images(n: int) -> void:
	for i: int in n:
		_arene._process(PAS)


func test_le_son_d_impact_est_demande_a_l_arrivee_du_projectile_pas_a_la_vue() -> void:
	_arene.afficher(_vue_avec_tir(), 0.0)
	verifier_egal(_demandes.size(), 0, "à la réception de la vue, rien ne sonne")
	_images(40)
	verifier_egal(
		_demandes, [TYPE_TIR] as Array[int], "un son, du type du coup, une fois l'impact vu"
	)


func test_regarder_l_arene_d_un_autre_ne_demande_aucun_son() -> void:
	var source := SourceFactice.new()
	arbre.root.add_child(source)
	_arene.lier(source)
	_arene.montrer_arene(2, "Camille", 2)
	source.emettre_vue_regardee(2, _vue_avec_tir())
	_images(40)
	verifier_egal(_demandes.size(), 0, "l'arène regardée reste muette")
	_arene.lier(null)
	source.free()
