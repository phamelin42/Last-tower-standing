extends CasDeTest
## « Que le coup paraisse tuer » : l'ennemi tué reste affiché, figé, jusqu'à l'impact visible qui le
## vise, puis le crâne apparaît. Sans impact en attente, le crâne vient tout de suite comme avant ;
## un impact qui n'arrive pas ne retient jamais l'ennemi plus de 20 images. Le coup qui le tue lui
## donne son flash et son recul, comme un coup qui ne tue pas (décision de Phil du 27/11/2026), et
## le crâne vient quand le flash est fini, jamais après 20 images. Visuel seulement : la vue reçue
## n'est pas modifiée.

const SCENE := "res://scenes/arene_2d.tscn"
const PAS: float = 1.0 / 60.0
const POSITION := Vector2(200.0, 100.0)
const IMAGES_MAX: int = 40
const MORTS_RAFALE: int = 40
const RAYON_RAFALE: float = 150.0
const IMAGES_RAFALE: int = 90
## Un coup de zone est fort : le flash tient pendant les 5 images de gel puis les 3 de son éclat.
const MAX_IMAGES_FLASH_FORT: int = 8
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


func test_le_crane_n_apparait_jamais_avant_l_impact_qui_tue_et_apparait_quand_son_flash_finit(
) -> void:
	_tuer_par_un_tir()
	var reperes: Dictionary = {}
	var crane: int = _jusqu_au_crane(reperes)
	verifier(int(reperes["impact"]) > 0, "l'impact devient visible")
	verifier(crane > int(reperes["impact"]), "le crâne vient après l'impact, à la fin du flash")
	verifier(crane <= int(reperes["impact"]) + 4, "au plus 4 images après l'impact (%d)" % crane)
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


## Déroule la mort d'un ennemi tué par un tir et rend ce qu'on a vu : l'image de l'impact, celle du
## crâne, le nombre d'images de flash, le plus grand recul et son sens (positif : loin de la tour).
func _derouler_la_mort() -> Dictionary:
	_tuer_par_un_tir()
	var sprite: Sprite2D = _arene.sprite_mourant(0)
	var depart: Vector2 = sprite.position
	var teinte: Color = sprite.modulate
	var region: Rect2 = sprite.region_rect
	var vu: Dictionary = {"impact": -1, "crane": -1, "flash": 0, "recul": 0.0, "sens": 0.0}
	var images: int = 0
	while _arene.nombre_mourants() == 1 and images < IMAGES_MAX:
		_arene._process(PAS)
		images += 1
		if _impact_vu and int(vu["impact"]) < 0:
			vu["impact"] = images
		if _arene.nombre_mourants() == 0:
			break
		verifier_egal(sprite.region_rect, region, "image %d : il ne s'anime plus" % images)
		if int(vu["impact"]) < 0:
			verifier_egal(sprite.position, depart, "image %d : il ne bouge pas" % images)
			verifier_egal(sprite.modulate, teinte, "image %d : ni flash ni teinte" % images)
			continue
		if sprite.modulate.r > teinte.r + 0.01:
			vu["flash"] = int(vu["flash"]) + 1
		var ecart: Vector2 = sprite.position - depart
		if ecart.length() > float(vu["recul"]):
			vu["recul"] = ecart.length()
			vu["sens"] = ecart.x
	vu["crane"] = images if _arene.nombre_morts_visibles() > 0 else -1
	return vu


func test_l_ennemi_tue_ne_bouge_pas_avant_l_impact_puis_clignote_et_recule() -> void:
	var vu: Dictionary = _derouler_la_mort()
	verifier(int(vu["impact"]) > 0, "l'impact est venu")
	verifier(int(vu["flash"]) >= 2, "il clignote au coup qui le tue (%d images)" % int(vu["flash"]))
	verifier(int(vu["flash"]) <= 4, "un flash de 3 images, pas plus (%d)" % int(vu["flash"]))
	verifier(float(vu["recul"]) > 1.0, "il recule d'un cheveu (%.1f px)" % float(vu["recul"]))
	verifier(
		float(vu["recul"]) <= ReactionsCoups.RECUL_PX + 0.01,
		"pas plus que le recul d'un coup ordinaire (%.1f px)" % float(vu["recul"])
	)
	verifier(float(vu["sens"]) > 0.0, "à l'opposé de la tour")
	verifier(int(vu["crane"]) > 0, "puis le crâne")


func test_en_mouvement_reduit_l_ennemi_tue_clignote_mais_ne_recule_pas() -> void:
	_arene.mouvement_reduit = true
	var vu: Dictionary = _derouler_la_mort()
	verifier(int(vu["flash"]) >= 2, "le flash reste (%d images)" % int(vu["flash"]))
	verifier_egal(float(vu["recul"]), 0.0, "le recul est coupé (D21)")
	verifier(int(vu["crane"]) > 0, "puis le crâne")


func test_le_flash_ne_prolonge_pas_la_mort_au_dela_de_vingt_images() -> void:
	# On mesure l'image `k` de l'impact, puis on fait vieillir l'ennemi retenu pour que ses vingt
	# images tombent une image après `k` : le flash est coupé là, le crâne vient sans dépasser.
	_tuer_par_un_tir()
	var reperes: Dictionary = {}
	_jusqu_au_crane(reperes)
	var k: int = int(reperes["impact"])
	verifier(k > 0, "l'impact est venu")
	apres_chaque()
	avant_chaque()
	_tuer_par_un_tir()
	_arene._morts.liste[0]["debut"] = _arene._horloge - (Arene2D.DELAI_MORT_MAX - (k + 1) * PAS)
	var crane: int = _jusqu_au_crane({})
	verifier(crane >= k, "pas avant l'impact (%d)" % crane)
	verifier(crane <= k + 1, "coupé à la vingtième image (%d, impact à %d)" % [crane, k])


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


# --- Une rafale de morts : le plafond d'éclats (WCAG 2.3.1) tient --------------------------------


## Quarante ennemis serrés, tués ensemble par une zone, puis des impacts qui reviennent toutes les
## deux images au même endroit : le pire pour le plafond d'éclats. Rend, par id retenu, les images
## où son flash a commencé, et le plus grand nombre d'ennemis qui clignotent en même temps.
func _rafale_de_morts() -> Dictionary:
	var positions: Array[Vector2] = []
	for i: int in MORTS_RAFALE:
		positions.append(POSITION + Vector2.from_angle(TAU * i / MORTS_RAFALE) * (8.0 + i))
	var avant := VueArene.new()
	_tick += 1
	avant.tick = _tick
	for i: int in MORTS_RAFALE:
		avant.ennemis_id.append(100 + i)
		avant.ennemis_pos.append(positions[i])
		avant.ennemis_famille.append(0)
		avant.ennemis_pv.append(255)
		avant.ennemis_statuts.append(0)
	_arene.afficher(avant, 0.0)
	var evenements: Array[Dictionary] = []
	var tir: Dictionary = _evenement("tir")
	tir["rayon"] = RAYON_RAFALE
	evenements.append(tir)
	var impact: Dictionary = _evenement("impact")
	impact["rayon"] = RAYON_RAFALE
	evenements.append(impact)
	for p: Vector2 in positions:
		evenements.append(
			{"k": "mort", "t": _tick + 1, "de": p, "vers": p, "type_degats": TYPE_TIR, "rayon": 0.0}
		)
	_arene.afficher(_vue(false, evenements), 0.0)
	var source := SourceVue.new()
	_arene.lier(source)
	var longueurs: Dictionary = {}
	var departs: Dictionary = {}
	var en_flash_avant: Dictionary = {}
	var simultanes: int = 0
	for image: int in IMAGES_RAFALE:
		if image > 0 and image % 2 == 0 and image < 40:
			var encore: Dictionary = _evenement("impact")
			encore["rayon"] = RAYON_RAFALE
			# Par la source, comme en jeu : `afficher` remettrait l'horloge de l'arène à zéro.
			source.vue_arene_recue.emit(_vue(false, [_tir_vers(RAYON_RAFALE), encore]))
		_arene._process(PAS)
		var maintenant: int = 0
		for mourant: Dictionary in _arene._morts.liste:
			var id: int = int(mourant["id"])
			var flash: bool = (mourant["sprite"] as Sprite2D).modulate.r > 1.01
			if flash:
				maintenant += 1
				longueurs[id] = int(longueurs.get(id, 0)) + 1
				if not en_flash_avant.get(id, false):
					(departs.get_or_add(id, []) as Array).append(image)
			en_flash_avant[id] = flash
		simultanes = maxi(simultanes, maintenant)
	return {"departs": departs, "simultanes": simultanes, "longueurs": longueurs}


func _tir_vers(rayon: float) -> Dictionary:
	var tir: Dictionary = _evenement("tir")
	tir["rayon"] = rayon
	return tir


func test_une_rafale_de_morts_ne_depasse_pas_le_plafond_d_eclats() -> void:
	var vu: Dictionary = _rafale_de_morts()
	var departs: Dictionary = vu["departs"]
	verifier(departs.size() >= 1, "certains clignotent au coup qui les tue")
	verifier(
		int(vu["simultanes"]) <= ReactionsCoups.MAX_ZONE,
		(
			"au plus %d ennemis qui clignotent d'un même coup (%d)"
			% [ReactionsCoups.MAX_ZONE, int(vu["simultanes"])]
		)
	)
	var longueurs: Dictionary = vu["longueurs"]
	for id: Variant in longueurs:
		verifier(
			int(longueurs[id]) <= MAX_IMAGES_FLASH_FORT,
			(
				"ennemi %d : flash de %d images, que les impacts répétés ne prolongent pas"
				% [int(id), int(longueurs[id])]
			)
		)
	# Au plus trois éclats par seconde pour un même ennemi (WCAG 2.3.1) : ici, un seul départ chacun.
	for id: Variant in departs:
		var images: Array = departs[id]
		var dans_la_seconde: int = 0
		for image: Variant in images:
			if int(image) < 60:
				dans_la_seconde += 1
		verifier(
			dans_la_seconde <= 3,
			"ennemi %d : %d éclats dans la première seconde" % [int(id), dans_la_seconde]
		)
		verifier_egal(
			images.size(), 1, "ennemi %d : un seul éclat (images %s)" % [int(id), str(images)]
		)
