extends CasDeTest
## Dans l'arène : un coup de zone retient l'ennemi touché (le recul attend la fin du gel), le
## mouvement réduit supprime gel et recul en gardant le flash, et le réglage se change en cours de
## partie. L'écran ne tremble pas : la caméra n'est jamais décalée par un impact.

const SCENE := "res://scenes/arene_2d.tscn"
const IMAGE: float = 1.0 / 60.0
const CIBLE := Vector2(800, 0)
const AUTRE := Vector2(-900, 500)

var _arene: Arene2D = null
var _tick: int = 0


func avant_chaque() -> void:
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


func _vue(evenements: Array[Dictionary]) -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	for i: int in 2:
		vue.ennemis_id.append(i + 1)
		vue.ennemis_pos.append(CIBLE if i == 0 else AUTRE)
		vue.ennemis_famille.append(0)
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	vue.evenements = evenements
	return vue


func _zone() -> Dictionary:
	return {
		"k": "impact",
		"t": _tick,
		"de": CIBLE,
		"vers": CIBLE,
		"type_degats": 3,
		"rayon": 120.0,
		"genre": 2
	}


func _images(n: int) -> void:
	for i: int in n:
		_arene._process(IMAGE)


func _ecart() -> Vector2:
	return _arene.position_instance(0, 0) - Apparence.vers_pixels(CIBLE)


func test_le_recul_de_l_ennemi_touche_par_une_zone_attend_la_fin_du_gel() -> void:
	_arene.afficher(_vue([]), 1.0)
	_arene.afficher(_vue([_zone()]), 1.0)
	_images(3)
	verifier_egal(_ecart(), Vector2.ZERO, "retenu : aucun recul pendant le gel")
	var recul_max: float = 0.0
	for i: int in 12:
		_images(1)
		recul_max = maxf(recul_max, _ecart().length())
	verifier(recul_max > 3.0, "puis il recule : %f" % recul_max)


func test_en_mouvement_reduit_l_ennemi_ne_recule_pas_mais_clignote() -> void:
	_arene.mouvement_reduit = true
	_arene.afficher(_vue([]), 1.0)
	var repos: float = _arene.sprite_instance(0, 0).modulate.r
	_arene.afficher(_vue([_zone()]), 1.0)
	verifier(_arene.sprite_instance(0, 0).modulate.r > repos * 1.5, "le flash reste")
	for i: int in 12:
		_images(1)
		verifier_egal(_ecart(), Vector2.ZERO, "image %d : pas de recul" % i)


func test_le_reglage_change_en_cours_de_partie() -> void:
	_arene.afficher(_vue([]), 1.0)
	_arene.mouvement_reduit = true
	_arene.afficher(_vue([_zone()]), 1.0)
	_images(2)
	verifier_egal(_ecart(), Vector2.ZERO, "réduit : rien ne bouge")
	_arene.mouvement_reduit = false
	_images(40)
	_arene.afficher(_vue([_zone()]), 1.0)
	var recul_max: float = 0.0
	for i: int in 12:
		_images(1)
		recul_max = maxf(recul_max, _ecart().length())
	verifier(recul_max > 3.0, "remis à faux : le recul revient (%f)" % recul_max)


func test_une_aura_ne_retient_pas_l_ennemi_qu_elle_touche() -> void:
	_arene.afficher(_vue([]), 1.0)
	var aura := _zone()
	aura["genre"] = "aura"
	aura["type_degats"] = 2
	_arene.afficher(_vue([aura]), 1.0)
	var recul_max: float = 0.0
	for i: int in 3:
		_images(1)
		recul_max = maxf(recul_max, _ecart().length())
	verifier(recul_max > 3.0, "l'ennemi recule aussitôt, sans gel : %f" % recul_max)
