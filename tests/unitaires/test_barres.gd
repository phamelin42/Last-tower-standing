extends CasDeTest
## Ce que la joueuse lit au-dessus de la tour : une barre de PV verte (rouge sous 30 %) avec ses
## chiffres, une barre de mana bleue dessous (absente sans mana), une barre au-dessus du boss.
## Toutes gardent leur taille à l'écran quel que soit le zoom, et aucune valeur absurde ne les
## fait déborder ni diviser par zéro.

const SCENE := "res://scenes/arene_2d.tscn"
const SEUIL: float = 0.3

var _barres: BarresArene = null
var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_barres = BarresArene.new()
	arbre.root.add_child(_barres)


func apres_chaque() -> void:
	if is_instance_valid(_barres):
		if _barres.get_parent() != null:
			_barres.get_parent().remove_child(_barres)
		_barres.free()
	_barres = null


func _vue(pv: float, pv_max: float, mana: float = 0.0, mana_max: float = 0.0) -> VueArene:
	var v := VueArene.new()
	v.tour_pv = pv
	v.tour_pv_max = pv_max
	v.tour_mana = mana
	v.tour_mana_max = mana_max
	return v


func test_la_barre_de_pv_est_verte_au_dessus_de_30_pour_cent_et_rouge_en_dessous() -> void:
	for ratio: float in [1.0, 0.31]:
		verifier_egal(BarresArene.couleur_pv(ratio), ThemeJeu.JAUGE_PLEINE, "vert à %.2f" % ratio)
	for ratio: float in [0.30, 0.1, 0.0]:
		verifier_egal(BarresArene.couleur_pv(ratio), ThemeJeu.JAUGE_BASSE, "rouge à %.2f" % ratio)


func test_les_chiffres_sont_x_sur_y_avec_les_separateurs_de_milliers() -> void:
	_barres.afficher(_vue(1234.0, 1500.0))
	verifier_egal(_barres.texte_pv(), "%s / %s" % [Nombres.groupe(1234), Nombres.groupe(1500)])
	_barres.afficher(_vue(80.0, 100.0))
	verifier_egal(_barres.texte_pv(), "80 / 100")


func test_les_ratios_sont_bornes_et_sans_division_par_zero() -> void:
	var maxima: Array[float] = [0.0, 1.0, 1000.0]
	var valeurs: Array[float] = [-5.0, 0.0, 500.0, 2000.0, NAN, INF]
	for maximum: float in maxima:
		for valeur: float in valeurs:
			_barres.afficher(_vue(valeur, maximum, valeur, maximum))
			var contexte: String = "pv=%s max=%s" % [valeur, maximum]
			for ratio: float in [_barres.ratio_pv(), _barres.ratio_mana()]:
				verifier(not is_nan(ratio), "NaN : %s" % contexte)
				verifier(ratio >= 0.0 and ratio <= 1.0, "hors [0, 1] : %s (%s)" % [contexte, ratio])
			verifier_egal(_barres.barre_mana_visible(), maximum > 0.0, "mana : %s" % contexte)
			verifier(_barres.texte_pv() != "", "texte vide : %s" % contexte)
	_barres.afficher(_vue(10.0, INF, 10.0, INF))
	verifier_egal(_barres.ratio_pv(), 0.0, "maximum infini")
	verifier_faux(_barres.barre_mana_visible(), "mana maximale infinie")


func test_les_barres_suivent_la_vue_a_chaque_pas() -> void:
	_barres.afficher(_vue(50.0, 100.0, 20.0, 40.0))
	verifier_proche(_barres.ratio_pv(), 0.5, 0.001)
	verifier_proche(_barres.ratio_mana(), 0.5, 0.001)
	_barres.afficher(_vue(25.0, 100.0, 40.0, 40.0))
	verifier_proche(_barres.ratio_pv(), 0.25, 0.001)
	verifier_proche(_barres.ratio_mana(), 1.0, 0.001)
	_barres.afficher(null)
	verifier_proche(_barres.ratio_pv(), 0.25, 0.001, "une vue nulle ne change rien")


func test_la_taille_a_l_ecran_reste_lisible_du_zoom_le_plus_proche_au_plus_lointain() -> void:
	for zoom: float in [CameraArene.ZOOM_MIN, 1.0, CameraArene.ZOOM_MAX]:
		var largeur: float = BarresArene.largeur_monde(zoom) * zoom
		verifier(largeur >= 60.0 and largeur <= 400.0, "largeur %.0f px à %.2f" % [largeur, zoom])
		var hauteur: float = BarresArene.HAUTEUR_PX
		verifier(hauteur * 1.0 >= 8.0, "hauteur de barre %.0f px" % hauteur)
	verifier(BarresArene.largeur_monde(0.0) > 0.0, "zoom nul sans division par zéro")
	verifier(is_finite(BarresArene.largeur_monde(NAN)), "zoom non fini")


func _arene() -> Arene2D:
	var arene := (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(arene)
	arene.reinitialiser()
	return arene


func _vue_boss(tick: int, avec_boss: bool, pv_octet: int) -> VueArene:
	var v := _vue(100.0, 100.0)
	v.tick = tick
	if avec_boss:
		v.ennemis_id.append(1)
		v.ennemis_pos.append(Vector2(300, 0))
		v.ennemis_famille.append(_donnees.familles.size() + 1)
		v.ennemis_pv.append(pv_octet)
		v.ennemis_statuts.append(0)
	return v


func test_la_barre_du_boss_apparait_avec_le_boss_suit_ses_pv_et_disparait_avec_lui() -> void:
	var arene: Arene2D = _arene()
	var barres := arene.get_node("Barres") as BarresArene
	verifier_non_nul(barres, "nœud Barres dans l'arène")
	if barres == null:
		return
	arene.afficher(_vue_boss(1, false, 255), 1.0)
	verifier_faux(barres.barre_boss_visible(), "pas de boss, pas de barre")
	arene.afficher(_vue_boss(2, true, 128), 1.1)
	verifier(barres.barre_boss_visible(), "le boss a sa barre")
	verifier_proche(barres.ratio_boss(), 0.5, 1.0 / 255.0)
	arene.afficher(_vue_boss(3, true, 255), 1.2)
	verifier_proche(barres.ratio_boss(), 1.0, 1.0 / 255.0)
	arene.afficher(_vue_boss(4, false, 255), 1.3)
	verifier_faux(barres.barre_boss_visible(), "le boss est mort, la barre part")
	arene.get_parent().remove_child(arene)
	arene.free()


func test_l_arene_pose_les_barres_de_la_tour_depuis_la_vue() -> void:
	var arene: Arene2D = _arene()
	var barres := arene.get_node("Barres") as BarresArene
	arene.afficher(_vue(30.0, 100.0, 10.0, 20.0), 1.0)
	verifier_proche(barres.ratio_pv(), 0.3, 0.001)
	verifier_proche(barres.ratio_mana(), 0.5, 0.001)
	arene.get_parent().remove_child(arene)
	arene.free()
