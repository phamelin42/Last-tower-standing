extends CasDeTest
## Mouvement réduit (D21, décision de Phil du 27/11/2026) : le décor animé, la flamme du boss et le
## crâne d'un ennemi mort se figent sur une image fixe (celle que fixe `data/assets.json`), au lieu
## de continuer à s'animer. Sans mouvement réduit ils changent d'image comme avant. Le réglage
## change en cours de partie : on fige et on reprend sans saut du temps (l'horloge s'arrête pendant
## le gel, elle ne rattrape rien à la reprise).

const SCENE := "res://scenes/arene_2d.tscn"
const PAS: float = 1.0 / 60.0
const POSITION := Vector2(300.0, 100.0)
const VICTIME := Vector2(-300.0, 100.0)
## Une seconde d'images : plus que la durée d'un tour de flamme (7 images à 10 i/s) et du crâne.
const IMAGES: int = 60

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


## Le boss (id 1) s'il est demandé, et une victime (id 2, famille 0) si `victime`.
func _vue(boss: bool, evenements: Array[Dictionary] = [], victime: bool = false) -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	var presents: Array[Vector3] = []
	if boss:
		presents.append(Vector3(1.0, _famille_boss(), 0.0))
	if victime:
		presents.append(Vector3(2.0, 0.0, 1.0))
	for p: Vector3 in presents:
		vue.ennemis_id.append(int(p.x))
		vue.ennemis_pos.append(POSITION if p.z == 0.0 else VICTIME)
		vue.ennemis_famille.append(int(p.y))
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	vue.evenements = evenements
	return vue


func _famille_boss() -> int:
	return _arene._pools.size() - 1


func _flamme() -> FlammeBoss:
	var boss: Sprite2D = _arene.sprite_instance(_famille_boss(), 0)
	verifier_non_nul(boss, "le boss est affiché")
	return boss.get_node("Flamme") as FlammeBoss


func _mort() -> Dictionary:
	return {"k": "mort", "t": _tick, "de": VICTIME, "vers": VICTIME, "type_degats": 0, "rayon": 0.0}


## Les régions (ou images) vues pendant `n` images, sans doublon, dans l'ordre.
func _regions(n: int, lire: Callable) -> Array:
	var vues: Array = []
	for _i: int in n:
		_avancer()
		var valeur: Variant = lire.call()
		if not vues.has(valeur):
			vues.append(valeur)
	return vues


## Une image : l'arène, et la flamme du boss que le moteur fait avancer d'elle-même en jeu.
func _avancer() -> void:
	_arene._process(PAS)
	var boss: Sprite2D = _arene.sprite_instance(_famille_boss(), 0)
	if boss != null:
		(boss.get_node("Flamme") as FlammeBoss)._process(PAS)


func _image_decor() -> Dictionary:
	return _arene._sol.images_courantes()


func _region_flamme() -> Rect2:
	return _flamme().region_rect


func _region_crane() -> Rect2:
	return _arene.sprite_mort(0).region_rect


func _poser_boss_et_crane() -> void:
	_arene.afficher(_vue(true, [], true), 0.0)
	_arene.afficher(_vue(true, [_mort()]), 0.0)
	verifier_egal(_arene.nombre_morts_visibles(), 1, "un crâne")


# --- Le décor ------------------------------------------------------------------------------------


func test_le_decor_s_anime_sans_mouvement_reduit() -> void:
	var vues: Array = _regions(IMAGES, _image_decor)
	verifier(vues.size() > 1, "le décor change d'image (%d vues)" % vues.size())


func test_le_decor_reste_sur_son_image_fixe_en_mouvement_reduit() -> void:
	_arene.mouvement_reduit = true
	var vues: Array = _regions(IMAGES, _image_decor)
	verifier_egal(vues.size(), 1, "une seule image du décor sur %d images" % IMAGES)
	# L'image fixe est celle des données : la même que celle d'un décor encore à l'instant zéro.
	verifier_egal(PlanchesEffets.image_fixe("decor"), 0, "les données fixent l'image 0")
	var neuf := Decor.new()
	neuf.construire(_arene._sol.plan)
	verifier_egal(vues[0], neuf.images_courantes(), "l'image du décor à l'instant zéro")
	neuf.free()


func test_le_decor_ne_saute_pas_quand_on_fige_puis_qu_on_reprend() -> void:
	var decor := Decor.new()
	decor.construire(PlanDecor.generer(7))
	for _i: int in 17:
		decor.avancer(PAS)
	var avant: Dictionary = decor.images_courantes()
	decor.mouvement_reduit = true
	for _i: int in IMAGES:
		decor.avancer(PAS)
	decor.mouvement_reduit = false
	verifier_egal(decor.images_courantes(), avant, "il reprend où il s'était arrêté")
	decor.free()


# --- La flamme du boss ---------------------------------------------------------------------------


func test_la_flamme_s_anime_sans_mouvement_reduit() -> void:
	_arene.afficher(_vue(true), 0.0)
	var vues: Array = _regions(IMAGES, _region_flamme)
	verifier(vues.size() > 1, "la flamme change d'image (%d vues)" % vues.size())


func test_la_flamme_reste_sur_son_image_fixe_en_mouvement_reduit() -> void:
	_arene.mouvement_reduit = true
	_arene.afficher(_vue(true), 0.0)
	var vues: Array = _regions(IMAGES, _region_flamme)
	verifier_egal(vues.size(), 1, "une seule image de flamme sur %d images" % IMAGES)
	var feu: Dictionary = PlanchesEffets.pack("feu")
	var case_px: Vector2i = feu["case"]
	var attendu := Rect2(
		PlanchesEffets.image_fixe("flamme_boss") * case_px.x, 0.0, case_px.x, case_px.y
	)
	verifier_egal(vues[0], attendu, "l'image fixe des données")


func test_la_flamme_d_un_boss_apparu_apres_le_reglage_est_figee_aussi() -> void:
	_arene.afficher(_vue(false), 0.0)
	_arene.mouvement_reduit = true
	_arene.afficher(_vue(true), 0.0)
	var vues: Array = _regions(IMAGES, _region_flamme)
	verifier_egal(vues.size(), 1, "figée dès son apparition")


# --- Le crâne ------------------------------------------------------------------------------------


func test_le_crane_s_anime_sans_mouvement_reduit() -> void:
	_poser_boss_et_crane()
	var vues: Array = _regions(40, _region_crane)
	verifier(vues.size() > 1, "le crâne change d'image (%d vues)" % vues.size())


func test_le_crane_reste_sur_son_image_fixe_en_mouvement_reduit() -> void:
	_arene.mouvement_reduit = true
	_poser_boss_et_crane()
	var vues: Array = _regions(40, _region_crane)
	verifier_egal(vues.size(), 1, "une seule image de crâne sur 40 images")
	var cible := Rect2(
		(PlanchesEffets.image_fixe("crane") % 7) * 128.0,
		(PlanchesEffets.image_fixe("crane") / 7) * 128.0,
		128.0,
		128.0
	)
	verifier(vues[0] is Rect2 and cible.encloses(vues[0] as Rect2), "dans l'image fixe des données")


func test_le_crane_fige_reste_affiche_aussi_longtemps_puis_disparait() -> void:
	var normal: int = _images_avant_disparition(false)
	apres_chaque()
	avant_chaque()
	var reduit: int = _images_avant_disparition(true)
	verifier(normal > 0, "le crâne disparaît")
	verifier_egal(reduit, normal, "même durée d'affichage en mouvement réduit")


func _images_avant_disparition(reduit: bool) -> int:
	_arene.mouvement_reduit = reduit
	_poser_boss_et_crane()
	for image: int in range(1, 3 * IMAGES):
		_avancer()
		if _arene.nombre_morts_visibles() == 0:
			return image
	return -1


# --- En cours de partie ---------------------------------------------------------------------------


func test_basculer_en_cours_de_partie_fige_puis_reprend() -> void:
	_poser_boss_et_crane()
	for _i: int in 10:
		_avancer()
	_arene.mouvement_reduit = true
	_avancer()
	var decor: Dictionary = _image_decor()
	var flamme: Rect2 = _region_flamme()
	var crane: Rect2 = _region_crane()
	for _i: int in 20:
		_avancer()
		verifier_egal(_image_decor(), decor, "décor figé")
		verifier_egal(_region_flamme(), flamme, "flamme figée")
		verifier_egal(_region_crane(), crane, "crâne figé")
	_arene.mouvement_reduit = false
	var vues: Array = _regions(30, _region_flamme)
	verifier(vues.size() > 1, "la flamme repart")
	var vues_decor: Array = _regions(IMAGES, _image_decor)
	verifier(vues_decor.size() > 1, "le décor repart")


func test_les_images_fixes_viennent_des_donnees() -> void:
	var tout: Dictionary = Assets.tout().duplicate(true)
	((tout["effets"] as Dictionary)["mouvement_reduit"] as Dictionary)["crane"] = 4
	((tout["effets"] as Dictionary)["mouvement_reduit"] as Dictionary)["flamme_boss"] = 3
	Assets.remplacer(tout)
	verifier_egal(PlanchesEffets.image_fixe("crane"), 4, "le crâne")
	verifier_egal(PlanchesEffets.image_fixe("flamme_boss"), 3, "la flamme")
	var flamme: FlammeBoss = FlammeBoss.creer()
	flamme.mouvement_reduit = true
	verifier_egal(flamme.region_rect.position.x, 3.0 * 128.0, "la flamme se fige sur l'image 3")
	flamme.free()
	Assets.reinitialiser()
	verifier_egal(PlanchesEffets.image_fixe("crane"), 9, "les données du fichier reviennent")
