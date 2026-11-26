extends CasDeTest
## Les attaques élémentaires (D22), élément par élément : le joueur voit une anticipation, un vol
## dont la durée est celle que `tirer` annonce, un impact à la taille de la zone, puis la
## dissipation. Les durées sont des nombres d'images à 60 i/s (`IMAGE`).

## La couleur des pixels de la planche `ombre` (`tools/dessin/dessin_commun.gd`).
const ENCRE_OMBRE := Color("161c2e")
const IMAGE: float = 1.0 / 60.0
const DEPART := Vector2(40.0, 300.0)
const ARRIVEE := Vector2(360.0, 300.0)
## Planche du projectile de chaque élément (celles du dossier `assets/maison/effets_attaques/`).
const PROJECTILES: Dictionary = {
	"feu": "boule_feu",
	"glace": "eclat_glace",
	"bombe": "bombe",
	"poison": "fiole",
	"arcane": "rune",
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
		var taille: Vector2i = AttaquesElementaires.planches()[planche]
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


func test_la_glace_dure_dix_images_et_trois_eclats_se_suivent() -> void:
	verifier_proche(_duree_en_images("glace"), 10.0, 0.01)
	var eclats: Array[Dictionary] = _a.etats("eclat_glace")
	verifier_egal(eclats.size(), 3, "un éclat et deux qui le suivent")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 4)
	eclats = _a.etats("eclat_glace")
	verifier(eclats[0]["position"].x > eclats[1]["position"].x, "le premier est devant")
	verifier(eclats[1]["position"].x > eclats[2]["position"].x, "les suivants le suivent")
	verifier(eclats[1]["echelle"].x < eclats[0]["echelle"].x, "les suivants sont plus petits")
	verifier(_a.particules_actives() >= 1, "des points de givre")


func test_la_glace_brise_au_rayon_puis_laisse_du_givre_au_sol() -> void:
	_a.impacter("glace", ARRIVEE, 60.0)
	verifier_proche(_a.etats("brisure_glace")[0]["diametre"], 120.0, 0.01, "brisure au rayon")
	var givre: Array[Dictionary] = _a.etats("givre_sol")
	verifier_egal(givre.size(), 1, "le givre reste au sol")
	verifier_proche(givre[0]["diametre"], 120.0, 0.01, "givre au rayon exact")
	_avancer(20)
	verifier_egal(_a.etats("brisure_glace").size(), 0, "la brisure s'est dissipée")
	verifier_egal(_a.etats("givre_sol").size(), 1, "le givre tient encore après 20 images")
	var alpha_20: float = _a.etats("givre_sol")[0]["alpha"]
	_avancer(3)
	verifier(_a.etats("givre_sol")[0]["alpha"] < alpha_20, "le givre s'efface")
	_avancer(2)
	verifier_egal(_a.etats("givre_sol").size(), 0, "il a disparu en 24 images")


func _a_mi_vol(element: String) -> void:
	_a.tirer(element, DEPART, ARRIVEE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)


func test_la_bombe_et_la_fiole_durent_quatorze_images() -> void:
	verifier_proche(_duree_en_images("bombe"), 14.0, 0.01)
	_a.vider()
	verifier_proche(_duree_en_images("poison"), 14.0, 0.01)


func test_la_bombe_et_la_fiole_passent_au_dessus_de_la_ligne_droite() -> void:
	var distance: float = DEPART.distance_to(ARRIVEE)
	var attendu: Dictionary = {"bombe": 0.35, "poison": 0.25}
	for element: String in attendu:
		_a.vider()
		_a_mi_vol(element)
		var planche: String = AttaquesElementaires.planche_projectile(element)
		var projectile: Dictionary = _a.etats(planche)[0]
		var monte: float = DEPART.y - float(projectile["position"].y)
		verifier(monte >= 0.9 * float(attendu[element]) * distance, "sommet de %s" % element)
		verifier(monte <= 1.05 * float(attendu[element]) * distance, "pas trop haut : %s" % element)
		var ombre: Dictionary = _a.etats("ombre")[0]
		verifier_proche(ombre["position"].y, DEPART.y, 0.01, "l'ombre reste sur la ligne droite")
		verifier_proche(ombre["position"].x, projectile["position"].x, 40.0, "sous le projectile")
		verifier_proche(ombre["alpha"], 0.55, 0.001, "ombre à 55 %")
		var sol := Color(0.24, 0.38, 0.27)
		var pixel: Color = ENCRE_OMBRE * (ombre["teinte"] as Color)
		verifier(pixel.get_luminance() < sol.get_luminance() * 0.5, "plus sombre que l'herbe")
		verifier(ombre["echelle"].x < 3.0 * 0.76, "l'ombre rétrécit au sommet")


func test_la_hauteur_du_sommet_a_un_minimum_sur_une_courte_distance() -> void:
	_a.tirer("poison", DEPART, DEPART + Vector2(40.0, 0.0))
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
	var monte: float = DEPART.y - float(_a.etats("fiole")[0]["position"].y)
	verifier(monte >= 0.9 * AttaquesElementaires.HAUTEUR_MIN_CLOCHE, "au moins 30 px")


func test_la_bombe_tourne_d_un_demi_tour_et_la_fiole_d_un_tour_et_demi() -> void:
	_a.tirer("bombe", DEPART, ARRIVEE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 10)
	verifier_proche(_a.etats("bombe")[0]["rotation"], PI * 10.0 / 11.0, 0.01, "demi-tour")
	_a.vider()
	_a.tirer("poison", DEPART, ARRIVEE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 10)
	verifier_proche(_a.etats("fiole")[0]["rotation"], 3.0 * PI * 10.0 / 11.0, 0.01, "1,5 tour")


func test_la_bombe_grossit_au_sommet_puis_reprend_sa_taille() -> void:
	_a_mi_vol("bombe")
	verifier(_a.etats("bombe")[0]["echelle"].x > 3.0 * 1.1, "elle grossit au sommet")


func test_mouvement_reduit_ni_rotation_ni_particule() -> void:
	_a.mouvement_reduit = true
	for element: String in ["bombe", "poison"]:
		_a.vider()
		_a_mi_vol(element)
		var planche: String = AttaquesElementaires.planche_projectile(element)
		verifier_proche(_a.etats(planche)[0]["rotation"], 0.0, 0.0001, "pas de rotation")
		_a.impacter(element, ARRIVEE, 60.0, true)
		verifier_egal(_a.particules_actives(), 0, "aucune particule en %s" % element)


func test_la_bombe_lance_dix_debris_a_l_impact() -> void:
	verifier(_a.impacter("bombe", ARRIVEE, 65.0, true), "des débris sont lancés")
	verifier_egal(_a.particules_actives(), 1)
	verifier_egal((_a.get_child(0) as CPUParticles2D).amount, 10, "dix débris, au plus douze")


func test_le_poison_eclabousse_au_rayon_puis_laisse_trois_nuages() -> void:
	_a.impacter("poison", ARRIVEE, 70.0)
	verifier_proche(_a.etats("eclaboussure_poison")[0]["diametre"], 140.0, 0.01)
	verifier_egal(_a.etats("nuage_poison").size(), 3, "trois nuages")
	_avancer(30)
	verifier_egal(_a.etats("eclaboussure_poison").size(), 0, "l'éclaboussure est finie")
	verifier_egal(_a.etats("nuage_poison").size(), 3, "le poison dure : les nuages restent")
	verifier(_a.opacite_max() <= 0.6 + 0.001, "un nuage n'est jamais plus opaque que 0,6")
	_avancer(7)
	verifier_egal(_a.nombre_vivants(), 0, "les nuages s'effacent en 36 images")


func test_l_arcane_dure_dix_images_avec_deux_points_qui_tournent() -> void:
	verifier_proche(_duree_en_images("arcane"), 10.0, 0.01)
	verifier_egal(_a.etats("etincelle").size(), 2, "deux points autour de la rune")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	var rune: Vector2 = _a.etats("rune")[0]["position"]
	var points: Array[Dictionary] = _a.etats("etincelle")
	for point: Dictionary in points:
		var position: Vector2 = point["position"]
		verifier_proche(position.distance_to(rune), AttaquesElementaires.RAYON_ORBITE, 0.5)
	verifier(_a.particules_actives() >= 1, "trois points bleus qui s'effacent")


## Avant le socle D22 la rune et son éclat étaient 36 px, la garde 40 px ; ×1,5, la garde 60.
func test_l_eclat_de_rune_est_une_fois_et_demie_plus_grand_sous_soixante_pixels() -> void:
	_a.impacter("arcane", ARRIVEE, 0.0)
	var plus_grand: float = 0.0
	for image: int in 12:
		for eclat: Dictionary in _a.etats("eclat_rune"):
			verifier(eclat["taille"].x <= 60.0 and eclat["taille"].y <= 60.0, "rune ≤ 60 px")
			plus_grand = maxf(plus_grand, float(eclat["taille"].x))
		_avancer(1)
	verifier(
		plus_grand >= 36.0 * 1.5 - 0.01, "au moins 1,5 fois les 36 px d'avant : %f" % plus_grand
	)


func test_la_rune_en_vol_est_une_fois_et_demie_plus_grande() -> void:
	_a.tirer("arcane", DEPART, ARRIVEE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	var rune: Dictionary = _a.etats("rune")[0]
	verifier(
		float(rune["taille"].x) >= 12.0 * 3.0 * 1.5 - 0.01, "rune ≥ 54 px : %s" % rune["taille"]
	)


func _eclair(de: Vector2, vers: Vector2) -> void:
	_a.impacter("foudre", vers, 0.0, false, de)


func test_la_foudre_attend_son_anticipation_puis_trace_un_eclair() -> void:
	verifier_proche(_duree_en_images("foudre"), 3.0, 0.01, "3 images d'anticipation")
	verifier_egal(_a.etats("depart").size(), 1)
	verifier_egal(_a.etats("rune").size() + _a.etats("boule_feu").size(), 0, "pas de projectile")
	_eclair(DEPART, ARRIVEE)
	var eclairs: Array[PackedVector2Array] = _a.eclairs()
	verifier_egal(eclairs.size(), 1)
	var points: PackedVector2Array = eclairs[0]
	verifier(points.size() >= 7 and points.size() <= 9, "6 à 8 segments")
	verifier_egal(points[0], DEPART)
	verifier_egal(points[points.size() - 1], ARRIVEE)
	verifier_egal(_a.etats("etincelle").size(), 1, "une étincelle sur la cible")


func test_l_eclair_est_retrace_toutes_les_deux_images_a_graine_fixe() -> void:
	_eclair(DEPART, ARRIVEE)
	var premier: PackedVector2Array = _a.eclairs()[0]
	_avancer(1)
	verifier_egal(_a.eclairs()[0], premier, "même tracé dans les 2 premières images")
	_avancer(1)
	verifier_different(_a.eclairs()[0], premier, "retracé à la 3e image")
	var autre := AttaquesElementaires.new()
	arbre.root.add_child(autre)
	autre.impacter("foudre", ARRIVEE, 0.0, false, DEPART)
	verifier_egal(autre.eclairs()[0], premier, "mêmes événements, même éclair")
	autre.free()


func test_l_eclair_dure_six_images_puis_s_efface_en_trois() -> void:
	_eclair(DEPART, ARRIVEE)
	_avancer(5)
	verifier_proche(_a.opacite_max(), AttaquesElementaires.ALPHA_MAX, 0.001, "plein jusqu'à 6")
	_avancer(2)
	verifier(_a.opacite_max() < AttaquesElementaires.ALPHA_MAX, "il s'efface")
	_avancer(3)
	verifier_egal(_a.eclairs().size(), 0, "fini en 9 images")


func test_mouvement_reduit_l_eclair_reste_fixe() -> void:
	_a.mouvement_reduit = true
	_eclair(DEPART, ARRIVEE)
	var premier: PackedVector2Array = _a.eclairs()[0]
	_avancer(5)
	verifier_egal(_a.eclairs()[0], premier)
	verifier_egal(_a.particules_actives(), 0)
