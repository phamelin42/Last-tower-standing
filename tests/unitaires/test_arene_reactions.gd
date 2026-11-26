extends CasDeTest
## Ce que le joueur doit voir dans l'arène quand un coup porte : l'ennemi touché s'éclaircit et
## recule d'un cheveu à l'opposé de la tour, puis revient, sans que sa position simulée change ;
## il ne réagit qu'à l'arrivée du projectile, et les autres ennemis restent tranquilles.

const SCENE := "res://scenes/arene_2d.tscn"
const IMAGE: float = 1.0 / 60.0
const CIBLE := Vector2(800, 0)
const AUTRE := Vector2(-900, 500)

var _arene: Arene2D = null
var _donnees: Donnees = null
var _tick: int = 0
var _famille: int = 0


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_arene = (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(_arene)
	_arene.reinitialiser()
	_tick = 0
	_famille = 0


func apres_chaque() -> void:
	if is_instance_valid(_arene):
		if _arene.get_parent() != null:
			_arene.get_parent().remove_child(_arene)
		_arene.free()
	_arene = null


## Deux ennemis (de la famille 0, ids 1 et 2) et les événements voulus.
func _vue(evenements: Array[Dictionary]) -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	for i: int in 2:
		vue.ennemis_id.append(i + 1)
		vue.ennemis_pos.append(CIBLE if i == 0 else AUTRE)
		vue.ennemis_famille.append(_famille)
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	vue.evenements = evenements
	return vue


func _impact(vers: Vector2) -> Dictionary:
	return {"k": "impact", "t": _tick, "de": vers, "vers": vers, "type_degats": 0, "rayon": 0.0}


func _images(n: int) -> void:
	for i: int in n:
		_arene._process(IMAGE)


func _clarte(i: int) -> float:
	return _arene.sprite_instance(_famille, i).modulate.r


## Écart d'affichage du sprite `i` (celui d'une position `p` de la vue), en pixels.
func _ecart(i: int, p: Vector2) -> Vector2:
	return _arene.position_instance(_famille, i) - Apparence.vers_pixels(p)


func test_l_ennemi_touche_s_eclaircit_et_recule_puis_revient() -> void:
	_arene.afficher(_vue([]), 1.0)
	var repos: float = _clarte(0)
	verifier_egal(_ecart(0, CIBLE), Vector2.ZERO, "au repos")
	var vue := _vue([_impact(CIBLE)])
	_arene.afficher(vue, 1.0)
	verifier_proche(_clarte(0), repos * ReactionsCoups.FACTEUR_FLASH, 0.001, "éclairci")
	verifier_proche(_clarte(1), repos, 0.001, "l'autre ennemi non")
	verifier_egal(_ecart(1, AUTRE), Vector2.ZERO, "l'autre ennemi ne bouge pas")
	_images(2)
	var recul: Vector2 = _ecart(0, CIBLE)
	verifier_proche(recul.length(), ReactionsCoups.RECUL_PX, 0.01, "recule de 4 px : %s" % recul)
	verifier(recul.x > 0.0, "à l'opposé de la tour (qui est à gauche)")
	_images(1)
	verifier_proche(_clarte(0), repos, 0.001, "le flash a duré 3 images")
	_images(6)
	verifier_egal(_ecart(0, CIBLE), Vector2.ZERO, "revenu à sa place")
	verifier_egal(vue.ennemis_pos[0], CIBLE, "la position simulée n'a pas changé")


func test_la_reaction_suit_l_ennemi_quand_l_ordre_de_la_vue_change() -> void:
	_arene.afficher(_vue([]), 1.0)
	_arene.afficher(_vue([_impact(CIBLE)]), 1.0)
	_images(1)
	# L'ennemi 1 passe en deuxième place : c'est lui qui est encore éclairci et reculé.
	var vue := _vue([])
	vue.ennemis_id = PackedInt32Array([2, 1])
	vue.ennemis_pos = PackedVector2Array([AUTRE, CIBLE])
	_arene.afficher(vue, 1.0)
	_arene.afficher(vue, 1.0)
	verifier_egal(_ecart(0, AUTRE), Vector2.ZERO, "l'ennemi 2 ne bouge pas")
	verifier(_ecart(1, CIBLE).length() > 0.5, "l'ennemi 1 est toujours en recul")


func test_un_impact_lie_a_un_tir_ne_fait_reagir_qu_a_l_arrivee() -> void:
	var tir := {"k": "tir", "t": 1, "de": Vector2.ZERO, "vers": CIBLE, "type_degats": 0}
	tir["rayon"] = 0.0
	_arene.afficher(_vue([]), 1.0)
	var repos: float = _clarte(0)
	_arene.afficher(_vue([tir, _impact(CIBLE)]), 1.0)
	verifier_proche(_clarte(0), repos, 0.001, "rien tant que le projectile vole")
	_images(int(Effets.DUREE_TIR / IMAGE) + 1)
	verifier_proche(_clarte(0), repos * ReactionsCoups.FACTEUR_FLASH, 0.001, "éclairci à l'arrivée")


func test_un_impact_loin_de_tout_ennemi_ne_fait_rien_reagir() -> void:
	_arene.afficher(_vue([]), 1.0)
	var repos: float = _clarte(0)
	_arene.afficher(_vue([_impact(Vector2(0, -700))]), 1.0)
	_images(2)
	verifier_proche(_clarte(0), repos, 0.001)
	verifier_proche(_clarte(1), repos, 0.001)
	verifier_egal(_ecart(0, CIBLE), Vector2.ZERO)
	verifier_egal(_ecart(1, AUTRE), Vector2.ZERO)
