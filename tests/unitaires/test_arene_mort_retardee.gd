extends CasDeTest
## « Que le coup paraisse tuer » : l'ennemi tué reste affiché, figé, jusqu'à l'impact visible qui le
## vise, puis le crâne apparaît. Sans impact en attente, le crâne vient tout de suite comme avant ;
## un impact qui n'arrive pas ne retient jamais l'ennemi plus de 20 images. Visuel seulement : la
## vue reçue n'est pas modifiée.

const SCENE := "res://scenes/arene_2d.tscn"
const PAS: float = 1.0 / 60.0
const POSITION := Vector2(200.0, 100.0)
const IMAGES_MAX: int = 40
## Type de dégâts du tir à projectile de 7 images (flèche).
const TYPE_TIR: int = 1

var _arene: Arene2D = null
var _donnees: Donnees = null
var _effets: Effets = null
var _tick: int = 0
var _impact_vu: bool = false


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_arene = (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(_arene)
	_arene.reinitialiser()
	_effets = _arene.find_child("Effets", true, false) as Effets
	_effets.impact_visible.connect(_noter_impact)
	_tick = 0
	_impact_vu = false


func apres_chaque() -> void:
	if is_instance_valid(_arene):
		if _arene.get_parent() != null:
			_arene.get_parent().remove_child(_arene)
		_arene.free()
	_arene = null


func _noter_impact(_ou: Vector2, _rayon: float, _fort: bool) -> void:
	_impact_vu = true


func _vue(avec_ennemi: bool, evenements: Array[Dictionary] = []) -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	if avec_ennemi:
		vue.ennemis_id.append(7)
		vue.ennemis_pos.append(POSITION)
		vue.ennemis_famille.append(0)
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	vue.evenements = evenements
	return vue


func _evenement(k: String, type_degats: int = TYPE_TIR) -> Dictionary:
	return {
		"k": k,
		"t": _tick,
		"de": Vector2.ZERO,
		"vers": POSITION,
		"type_degats": type_degats,
		"rayon": 0.0,
	}


func _mort() -> Dictionary:
	return {
		"k": "mort", "t": _tick, "de": POSITION, "vers": POSITION, "type_degats": 0, "rayon": 0.0
	}


## L'ennemi est vu, puis la vue suivante annonce son tir, son impact et sa mort.
func _tuer_par_un_tir() -> void:
	_arene.afficher(_vue(true), 0.0)
	_arene.afficher(_vue(false, [_evenement("tir"), _evenement("impact"), _mort()]), 0.0)


## Fait avancer l'arène image par image et rend l'image où le crâne est apparu (-1 s'il n'est pas
## venu en `IMAGES_MAX`). `reperes` reçoit l'image de l'impact visible.
func _jusqu_au_crane(reperes: Dictionary) -> int:
	reperes["impact"] = -1
	for image: int in range(1, IMAGES_MAX + 1):
		_arene._process(PAS)
		if _impact_vu and int(reperes["impact"]) < 0:
			reperes["impact"] = image
		if _arene.nombre_morts_visibles() > 0:
			return image
		verifier(_arene.nombre_mourants() == 1, "image %d : l'ennemi tué est toujours là" % image)
	return -1


func test_l_ennemi_tue_reste_visible_a_sa_place_jusqu_a_l_impact() -> void:
	_tuer_par_un_tir()
	verifier_egal(_arene.nombre_morts_visibles(), 0, "pas de crâne à l'annonce de la mort")
	verifier_egal(_arene.nombre_mourants(), 1, "l'ennemi tué est retenu")
	var sprite: Sprite2D = _arene.sprite_mourant(0)
	verifier_non_nul(sprite, "son sprite")
	verifier(sprite.visible, "visible")
	verifier_egal(sprite.position, Apparence.vers_pixels(POSITION), "à sa dernière position")
	verifier_egal(_arene.nombre_instances_visibles(0), 0, "il n'est plus dans les listes de la vue")


func test_le_crane_n_apparait_jamais_avant_l_impact_qui_tue_et_apparait_avec_lui() -> void:
	_tuer_par_un_tir()
	var reperes: Dictionary = {}
	var crane: int = _jusqu_au_crane(reperes)
	verifier(int(reperes["impact"]) > 0, "l'impact devient visible")
	verifier_egal(crane, int(reperes["impact"]), "le crâne arrive à l'image de l'impact")
	verifier_egal(_arene.nombre_mourants(), 0, "l'ennemi retenu est libéré")
	verifier_egal(_arene.nombre_morts_visibles(), 1, "un seul crâne")


func test_sans_tir_en_cours_le_crane_apparait_tout_de_suite() -> void:
	_arene.afficher(_vue(true), 0.0)
	_arene.afficher(_vue(false, [_mort()]), 0.0)
	verifier_egal(_arene.nombre_morts_visibles(), 1, "crâne immédiat")
	verifier_egal(_arene.nombre_mourants(), 0, "personne n'est retenu")


func test_sans_vue_precedente_le_crane_apparait_tout_de_suite() -> void:
	# On ne sait pas qui est mort : pas d'ennemi à garder, même avec un impact en attente.
	_arene.afficher(_vue(false, [_evenement("tir"), _evenement("impact"), _mort()]), 0.0)
	verifier_egal(_arene.nombre_morts_visibles(), 1, "crâne immédiat")
	verifier_egal(_arene.nombre_mourants(), 0)


func test_un_impact_tardif_ne_retient_pas_l_ennemi_plus_de_vingt_images() -> void:
	var arme: int = _donnees.ids_catalogue.find("canon_de_cloche")
	var genre: int = VueArene.genre_depuis_nom("barrage")
	var evenements: Array[Dictionary] = []
	var tir: Dictionary = _evenement("tir", 0)
	tir["arme"] = arme
	tir["genre"] = genre
	evenements.append(tir)
	# Huit impacts décalés de deux images chacun : le dernier tombe bien après vingt images.
	for i: int in 8:
		var impact: Dictionary = _evenement("impact", 0)
		impact["arme"] = arme
		impact["genre"] = genre
		impact["rayon"] = 60.0
		evenements.append(impact)
	evenements.append(_mort())
	_arene.afficher(_vue(true), 0.0)
	_arene.afficher(_vue(false, evenements), 0.0)
	verifier_egal(_arene.nombre_mourants(), 1, "l'ennemi est retenu")
	verifier(
		_effets.delai_avant_impact(POSITION) > Arene2D.DELAI_MORT_MAX, "l'impact est plus tardif"
	)
	var crane: int = _jusqu_au_crane({})
	verifier(crane > 0, "le crâne vient")
	verifier(crane <= 20, "au plus 20 images après la mort (%d)" % crane)


func test_l_ennemi_mort_ne_bouge_plus_et_ne_reagit_a_aucun_coup() -> void:
	_tuer_par_un_tir()
	var sprite: Sprite2D = _arene.sprite_mourant(0)
	var position: Vector2 = sprite.position
	var teinte: Color = sprite.modulate
	var region: Rect2 = sprite.region_rect
	var images: int = 0
	while _arene.nombre_mourants() == 1 and images < IMAGES_MAX:
		_arene._process(PAS)
		images += 1
		if _arene.nombre_mourants() == 1:
			verifier_egal(sprite.position, position, "image %d : il ne bouge pas" % images)
			verifier_egal(sprite.modulate, teinte, "image %d : ni flash ni teinte" % images)
			verifier_egal(sprite.region_rect, region, "image %d : il ne s'anime plus" % images)
	verifier(images < IMAGES_MAX, "l'impact est venu")


func test_la_vue_recue_n_est_pas_modifiee() -> void:
	var vue: VueArene = _vue(false, [_evenement("tir"), _evenement("impact"), _mort()])
	_arene.afficher(_vue(true), 0.0)
	var avant_ids: PackedInt32Array = vue.ennemis_id.duplicate()
	var avant_pos: PackedVector2Array = vue.ennemis_pos.duplicate()
	var avant_evenements: Array[Dictionary] = vue.evenements.duplicate(true)
	_arene.afficher(vue, 0.0)
	for i: int in 10:
		_arene._process(PAS)
	verifier_egal(vue.ennemis_id, avant_ids, "ids")
	verifier_egal(vue.ennemis_pos, avant_pos, "positions")
	verifier_egal(vue.evenements, avant_evenements, "événements")


func test_le_mouvement_reduit_ne_change_pas_le_moment_du_crane() -> void:
	_tuer_par_un_tir()
	var normal: Dictionary = {}
	var crane_normal: int = _jusqu_au_crane(normal)
	apres_chaque()
	avant_chaque()
	_arene.mouvement_reduit = true
	_tuer_par_un_tir()
	var reduit: Dictionary = {}
	var crane_reduit: int = _jusqu_au_crane(reduit)
	verifier(crane_normal > 0, "le crâne vient")
	verifier_egal(crane_reduit, crane_normal, "même image en mouvement réduit")
	verifier_egal(int(reduit["impact"]), int(normal["impact"]), "même image d'impact")


func test_vider_les_vues_n_affiche_aucun_crane_et_libere_l_ennemi_retenu() -> void:
	_tuer_par_un_tir()
	verifier_egal(_arene.nombre_mourants(), 1)
	_arene.reinitialiser()
	verifier_egal(_arene.nombre_mourants(), 0, "plus d'ennemi retenu")
	_arene._process(PAS)
	verifier_egal(_arene.nombre_morts_visibles(), 0, "aucun crâne d'une partie finie")
