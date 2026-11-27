extends CasDeTest
## Ce que la vue pose au sol pour les armes de siège du lot 9 (T9.19) : la bombe est la bombe à
## mèche de sa carte, dont l'anneau se resserre et la mèche raccourcit jusqu'à l'explosion ; une
## zone posée dont l'arme a un disque (braise, ruines) le montre, à la taille exacte de la zone.

const CASE_DISQUE: float = 32.0

var _donnees: Donnees = Donnees.charger()
var _poses: ZonesBombes2D = null
var _tick: int = 0


func avant_chaque() -> void:
	_poses = ZonesBombes2D.new()
	_poses.donnees = _donnees
	arbre.root.add_child(_poses)
	_tick = 0


func apres_chaque() -> void:
	if is_instance_valid(_poses):
		_poses.free()
	_poses = null


func _vue(zones: Array[Dictionary] = [], bombes: Array[Dictionary] = []) -> VueArene:
	var vue: VueArene = VueArene.new()
	_tick += 1
	vue.tick = _tick
	vue.zones = zones
	vue.bombes = bombes
	return vue


func _zone_de(id: String, rayon: float) -> Dictionary:
	var arme: int = _donnees.ids_catalogue.find(id)
	return {"pos": Vector2(100.0, 50.0), "rayon": rayon, "reste": 5.0, "arme": arme}


func _bombe(reste: float) -> Dictionary:
	return {"pos": Vector2(50.0, 50.0), "rayon": 90.0, "reste": reste}


func test_la_bombe_est_la_bombe_a_meche_de_sa_carte() -> void:
	verifier_egal(_poses.planche_bombe(), "bombe_meche")
	verifier(
		ResourceLoader.exists("%sbombe_meche.png" % AttaquesElementaires.DOSSIER),
		"planche présente"
	)
	verifier(AttaquesElementaires.planches().has("bombe_meche"), "planche déclarée")


func test_la_meche_raccourcit_et_l_anneau_se_resserre_jusqu_a_l_explosion() -> void:
	_poses.afficher(_vue([], [_bombe(2.0)]))
	verifier_egal(_poses.image_bombe(0), 0, "posée : l'anneau en tirets")
	_poses.afficher(_vue([], [_bombe(1.0)]))
	var milieu: int = _poses.image_bombe(0)
	_poses.afficher(_vue([], [_bombe(0.05)]))
	var fin: int = _poses.image_bombe(0)
	verifier(milieu > 0 and fin > milieu, "image %d puis %d : l'anneau se ferme" % [milieu, fin])
	verifier_egal(fin, 2, "sur le point d'exploser : la dernière image")


func test_le_souffle_de_la_bombe_reste_le_rayon_reel() -> void:
	_poses.afficher(_vue([], [_bombe(2.0)]))
	verifier_egal(_poses.rayon_bombe(0), 90.0 * Apparence.PX_PAR_UNITE, "l'anneau est le souffle")


func test_une_zone_de_braise_ou_de_ruines_montre_son_disque_a_la_taille_de_la_zone() -> void:
	var disques: Dictionary = {
		"braise_de_siege": "disque_braise", "champ_de_ruines": "disque_ruines"
	}
	for id: String in disques:
		var zone: Dictionary = _zone_de(id, 220.0)
		_poses.afficher(_vue([zone]))
		verifier_egal(_poses.disque_zone(0), String(disques[id]), "disque de %s" % id)
		var visible: float = AttaquesElementaires.visible_de(String(disques[id]))
		var taille: Vector2 = _poses.taille_disque(0)
		verifier_proche(
			taille.x * visible / CASE_DISQUE,
			220.0 * 2.0 * Apparence.PX_PAR_UNITE,
			0.5,
			"la partie visible du disque couvre exactement la zone de %s" % id
		)


func test_une_zone_sans_disque_garde_le_disque_trace_et_la_vue_sans_donnees_aussi() -> void:
	_poses.afficher(_vue([_zone_de("rune_de_veille", 100.0)]))
	verifier_egal(_poses.disque_zone(0), "", "la rune n'a pas de disque dessiné")
	_poses.donnees = null
	_poses.afficher(_vue([_zone_de("braise_de_siege", 100.0)]))
	verifier_egal(_poses.disque_zone(0), "", "sans données, on ne devine pas")


func test_le_disque_de_la_braise_pulse_et_se_fige_en_mouvement_reduit() -> void:
	_poses.afficher(_vue([_zone_de("braise_de_siege", 220.0)]))
	var images: Dictionary = {}
	for _i: int in 30:
		_poses.avancer(0.05)
		images[_poses.image_disque(0)] = true
	verifier(images.size() > 1, "les braises pulsent")
	_poses.mouvement_reduit = true
	images.clear()
	for _i: int in 30:
		_poses.avancer(0.05)
		images[_poses.image_disque(0)] = true
	verifier_egal(images.size(), 1, "figé en mouvement réduit")


# --- La bombe de la vue apparaît à l'arrivée du projectile ----------------------------------


func _tir_de_bombe(id: String) -> Dictionary:
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = [id] as Array[String]
	var tir: Dictionary = vitrine.evenement_de(id, "tir")
	vitrine.free()
	return tir


## Pose la bombe de `id` dans la vue et rend les images (à 60 i/s) avant qu'elle apparaisse, -1 si
## elle n'apparaît pas en `max_images`.
func _images_avant_apparition(id: String, reduit: bool, avec_tir: bool) -> int:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	effets.mouvement_reduit = reduit
	arbre.root.add_child(effets)
	_poses.vider()
	_poses.mouvement_reduit = reduit
	var tir: Dictionary = _tir_de_bombe(id)
	if avec_tir:
		effets.ajouter(tir)
	var bombe: Dictionary = {"pos": tir["vers"], "rayon": 90.0, "reste": 2.0}
	_poses.afficher(_vue([], [bombe]), effets)
	var rang: int = -1
	for i: int in 40:
		if _poses.nombre_bombes_visibles() > 0:
			rang = i
			break
		effets.avancer(1.0 / 60.0)
		_poses.avancer(1.0 / 60.0)
	effets.free()
	return rang


func test_la_bombe_de_la_vue_attend_l_arrivee_du_projectile_de_l_element() -> void:
	var arrivee: int = (
		AttaquesElementaires.IMAGES_ANTICIPATION + AttaquesElementaires.IMAGES_VOL_CLOCHE
	)
	for reduit: bool in [false, true]:
		var rang: int = _images_avant_apparition("baril_a_retardement", reduit, true)
		verifier(abs(rang - arrivee) <= 1, "réduit %s : apparaît à l'arrivée (%d)" % [reduit, rang])
	var direct: int = (
		AttaquesElementaires.IMAGES_ANTICIPATION + AttaquesElementaires.IMAGES_VOL_DIRECT
	)
	var obus: int = _images_avant_apparition("obusier_de_breche", false, true)
	verifier(abs(obus - direct) <= 1, "l'obus arrive en vol droit (%d)" % obus)


func test_une_bombe_sans_projectile_apparait_tout_de_suite() -> void:
	verifier_egal(_images_avant_apparition("baril_a_retardement", false, false), 0, "pas de tir")
	_poses.afficher(_vue([], [_bombe(2.0)]))
	verifier_egal(_poses.nombre_bombes_visibles(), 1, "sans Effets non plus")
