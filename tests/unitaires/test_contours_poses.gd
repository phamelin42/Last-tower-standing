extends CasDeTest
## Une zone posée se lit même dans une foule : son tapis reste sous les ennemis, et un contour fin,
## sans remplissage, est tracé au-dessus d'eux, au rayon exact de la zone touchée. Il suit la zone
## (fondu final, disparition) et reste en mouvement réduit, sans battement.

const ZONES: Array[String] = [
	"couronne_du_vide",
	"champ_de_ruines",
	"orage_en_cage",
	"braise_de_siege",
	"rune_de_veille",
	"sablier_d_aurore",
]
const BOMBES: Array[String] = ["baril_a_retardement", "obusier_de_breche"]
const SCENE := "res://scenes/arene_2d.tscn"

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


func _rayon_de(id: String) -> float:
	for effet: Dictionary in _donnees.armes[id]["effets"]:
		if String(effet.get("kind", "")) in ["zone_posee", "bombe"]:
			return float(effet["rayon"])
	return 0.0


func _zone(id: String, reste: float = 5.0) -> Dictionary:
	var arme: int = _donnees.ids_catalogue.find(id)
	return {"pos": Vector2(100.0, 50.0), "rayon": _rayon_de(id), "reste": reste, "arme": arme}


func _cercles() -> Array[Dictionary]:
	return _poses.contours().cercles()


func test_chaque_zone_posee_a_son_contour_au_rayon_reel() -> void:
	for id: String in ZONES:
		_poses.afficher(_vue([_zone(id)]))
		var cercles: Array[Dictionary] = _cercles()
		verifier_egal(cercles.size(), 1, "%s : un contour" % id)
		if cercles.size() == 1:
			var attendu: float = _rayon_de(id) * Apparence.PX_PAR_UNITE
			verifier_proche(float(cercles[0]["rayon"]), attendu, attendu * 0.05, id)
			verifier_egal(cercles[0]["centre"], _poses.position_zone(0), "%s : centre" % id)


func test_le_souffle_d_une_bombe_a_son_contour_au_rayon_reel() -> void:
	for id: String in BOMBES:
		_poses.afficher(
			_vue([], [{"pos": Vector2(50.0, 50.0), "rayon": _rayon_de(id), "reste": 2.0}])
		)
		var cercles: Array[Dictionary] = _cercles()
		verifier_egal(cercles.size(), 1, "%s : un contour" % id)
		if cercles.size() == 1:
			var attendu: float = _rayon_de(id) * Apparence.PX_PAR_UNITE
			verifier_proche(float(cercles[0]["rayon"]), attendu, attendu * 0.05, id)


func test_une_bombe_encore_en_vol_n_a_pas_de_contour() -> void:
	var effets: Effets = Effets.new()
	arbre.root.add_child(effets)
	effets.catalogue = _donnees.ids_catalogue
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = ["obusier_de_breche"] as Array[String]
	effets.ajouter(vitrine.evenement_de("obusier_de_breche", "tir"))
	var tir: Dictionary = vitrine.evenement_de("obusier_de_breche", "tir")
	vitrine.free()
	var bombe: Dictionary = {"pos": tir["vers"], "rayon": 180.0, "reste": 2.0}
	_poses.afficher(_vue([], [bombe]), effets)
	verifier(effets.vol_restant(tir["vers"]) > 0.0, "le projectile est en vol")
	verifier_egal(_cercles().size(), 0, "pas de souffle avant l'arrivée de la bombe")
	effets.free()


func test_le_contour_est_fin_sans_remplissage_et_jamais_opaque() -> void:
	_poses.afficher(_vue([_zone("champ_de_ruines")]))
	var c: Dictionary = _cercles()[0] if _cercles().size() == 1 else {}
	verifier(not c.is_empty(), "un contour")
	if c.is_empty():
		return
	verifier(float(c["epaisseur"]) >= 1.0 and float(c["epaisseur"]) <= 2.0, "1 à 2 px d'écran")
	verifier(float(c["alpha"]) > 0.0 and float(c["alpha"]) <= AttaquesElementaires.ALPHA_MAX)
	verifier_faux(c.has("remplissage"), "aucun remplissage")


func test_le_contour_prend_la_couleur_de_la_zone() -> void:
	_poses.afficher(_vue([_zone("couronne_du_vide")]))
	var attendu: Color = Effets.COULEURS[Types.TypeDegats.CHAOS]
	var c: Color = _cercles()[0]["couleur"]
	verifier_egal(Color(c, 1.0), Color(attendu, 1.0))


func test_le_contour_s_efface_avec_la_zone() -> void:
	_poses.afficher(_vue([_zone("champ_de_ruines", 5.0)]))
	var plein: float = float(_cercles()[0]["alpha"])
	_poses.afficher(_vue([_zone("champ_de_ruines", 0.5)]))
	_poses.avancer(0.25)
	var fondu: float = float(_cercles()[0]["alpha"])
	verifier(fondu < plein, "il s'estompe sur la fin de la zone")
	_poses.avancer(0.3)
	verifier_egal(_cercles().size(), 0, "plus de contour quand le temps de la zone est écoulé")
	_poses.afficher(_vue([_zone("champ_de_ruines", 5.0)]))
	_poses.afficher(_vue())
	verifier_egal(_cercles().size(), 0, "la zone quitte la vue, son contour aussi")


func test_en_mouvement_reduit_le_contour_reste_et_ne_pulse_pas() -> void:
	for reduit: bool in [true, false]:
		_poses.mouvement_reduit = reduit
		_poses.afficher(_vue([_zone("orage_en_cage", 5.0)]))
		var avant: Dictionary = _cercles()[0]
		for i: int in 20:
			_poses.avancer(1.0 / 60.0)
		var apres: Dictionary = _cercles()[0]
		verifier_egal(apres["rayon"], avant["rayon"], "rayon constant (réduit : %s)" % reduit)
		verifier_egal(apres["alpha"], avant["alpha"], "opacité constante (réduit : %s)" % reduit)


func _z_effectif(n: Node2D) -> int:
	var z: int = 0
	var courant: Node = n
	while courant is Node2D:
		z += (courant as Node2D).z_index
		if not (courant as Node2D).z_as_relative:
			break
		courant = courant.get_parent()
	return z


func test_le_contour_est_dessine_au_dessus_des_ennemis_et_le_tapis_dessous() -> void:
	var arene: Arene2D = (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(arene)
	arene.reinitialiser()
	var poses: ZonesBombes2D = arene.get_node("Poses") as ZonesBombes2D
	var ennemis: Node2D = arene.get_node("Ennemis") as Node2D
	var contours: Node2D = poses.contours()
	verifier(_z_effectif(contours) > _z_effectif(ennemis), "le contour passe au-dessus des ennemis")
	verifier(_z_effectif(poses) <= _z_effectif(ennemis), "le tapis reste dessous")
	verifier(contours.is_visible_in_tree(), "le contour est dans l'arbre de l'arène")
	arene.get_parent().remove_child(arene)
	arene.free()
