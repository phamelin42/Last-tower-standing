extends CasDeTest
## Les attaques élémentaires (D22), élément par élément : le joueur voit une anticipation, un vol
## dont la durée est celle que `tirer` annonce, un impact à la taille de la zone, puis la
## dissipation. Les durées sont des nombres d'images à 60 i/s (`IMAGE`).

const IMAGE: float = 1.0 / 60.0
const DEPART := Vector2(40.0, 300.0)
const ARRIVEE := Vector2(360.0, 300.0)
## Planche du projectile de chaque élément (celles du dossier `assets/maison/effets_attaques/`).
const PROJECTILES: Dictionary = {
	"feu": "boule_feu",
}

var _a: AttaquesElementaires = null


func avant_chaque() -> void:
	_a = AttaquesElementaires.new()
	arbre.root.add_child(_a)


func apres_chaque() -> void:
	if is_instance_valid(_a):
		_a.free()
	_a = null


func _avancer(images: int) -> void:
	for i: int in images:
		_a.avancer(IMAGE)


## Les images d'avance de `tirer` : durée jusqu'à l'arrivée.
func _duree_en_images(element: String) -> float:
	return _a.tirer(element, DEPART, ARRIVEE) / IMAGE


func test_chaque_element_a_sa_planche_et_une_silhouette_unique() -> void:
	var masques: Dictionary = {}
	for element: String in PROJECTILES:
		var planche: String = AttaquesElementaires.planche_projectile(element)
		verifier_egal(planche, String(PROJECTILES[element]), "planche de %s" % element)
		var texture: Texture2D = load("res://assets/maison/effets_attaques/%s.png" % planche)
		verifier_non_nul(texture, "la planche %s existe" % planche)
		var taille: Vector2i = AttaquesElementaires.PLANCHES[planche]
		var image: Image = texture.get_image().get_region(Rect2i(0, 0, taille.x, taille.y))
		var masque: String = ""
		for y: int in taille.y:
			for x: int in taille.x:
				masque += "1" if image.get_pixel(x, y).a > 0.0 else "0"
		verifier(not masques.has(masque), "silhouette de %s déjà prise" % element)
		masques[masque] = element


func test_le_feu_dure_dix_images_du_depart_a_l_arrivee() -> void:
	verifier_proche(_duree_en_images("feu"), 10.0, 0.01)


func test_le_feu_montre_son_anticipation_puis_sa_boule() -> void:
	_a.tirer("feu", DEPART, ARRIVEE)
	verifier_egal(_a.etats("depart").size(), 1, "anticipation de départ")
	var sprite_depart: Dictionary = _a.etats("depart")[0]
	verifier(sprite_depart["position"].x > DEPART.x, "l'anticipation est au bord de la tour")
	var boule: Array[Dictionary] = _a.etats("boule_feu")
	verifier_egal(boule.size(), 1)
	verifier_faux(boule[0]["visible"], "la boule attend la fin de l'anticipation")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	boule = _a.etats("boule_feu")
	verifier(boule[0]["visible"], "la boule vole")
	verifier_proche(boule[0]["position"].y, ARRIVEE.y, 0.5, "elle vole droit")
	verifier(boule[0]["position"].x > DEPART.x, "elle avance vers la cible")


func test_la_boule_est_orientee_vers_la_cible() -> void:
	_a.tirer("feu", DEPART, DEPART + Vector2(0.0, 200.0))
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	verifier_proche(_a.etats("boule_feu")[0]["rotation"], PI / 2.0, 0.01)


func test_le_feu_laisse_des_braises_pendant_le_vol() -> void:
	_a.tirer("feu", DEPART, ARRIVEE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 3)
	verifier(_a.particules_actives() >= 1, "une traînée de braises")


func test_l_impact_de_feu_a_le_rayon_de_la_zone() -> void:
	_a.impacter("feu", ARRIVEE, 60.0, true)
	verifier_proche(_a.diametre_max(), 120.0, 12.0, "l'anneau est au rayon exact")
	verifier_egal(_a.etats("explosion_feu").size(), 1, "un cœur de feu")
	verifier_proche(_a.etats("explosion_feu")[0]["diametre"], 60.0, 0.01, "cœur à mi-rayon")


func test_le_feu_a_cible_unique_reste_petit() -> void:
	_a.impacter("feu", ARRIVEE, 0.0)
	verifier(_a.diametre_max() <= AttaquesElementaires.DIAMETRE_PETIT + 0.01)


func test_tout_se_dissipe_et_rend_le_pool() -> void:
	_a.tirer("feu", DEPART, ARRIVEE)
	_a.impacter("feu", ARRIVEE, 60.0, true)
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0, "plus rien après une seconde")
	verifier_egal(_a.particules_actives(), 0, "plus de particule")
