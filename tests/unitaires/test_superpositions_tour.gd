extends CasDeTest
## Le dessin de l'apparence de la tour (T9.25) : chaque statistique à son palier montre ses deux
## couches à son ancrage, un changement de palier se fond, la bulle de mana se remplit, l'esquive
## ne clignote pas, et rien de tout cela ne touche la simulation. Les seuils, ancrages, durées et
## images viennent des données : aucun nombre de ce fichier n'est propre à un asset.

var d: Donnees
var _tour: Sprite2D
var _sup: SuperpositionsTour
var _base: Vector2


func avant_chaque() -> void:
	d = Donnees.charger()
	_tour = Sprite2D.new()
	_tour.texture = load(String(Apparence.tour(1)["fichier"])) as Texture2D
	_tour.scale = Vector2.ONE * Apparence.tour_echelle
	_tour.offset = Vector2(0.0, _tour.texture.get_height() * 0.5 - Apparence.tour_pieds)
	arbre.root.add_child(_tour)
	_base = _tour.scale
	_sup = SuperpositionsTour.new()
	_sup.construire(_tour, d)


func apres_chaque() -> void:
	if is_instance_valid(_tour):
		if _tour.get_parent() != null:
			_tour.get_parent().remove_child(_tour)
		_tour.free()


func _seuils(stat: String) -> Array:
	var stats: Dictionary = d.apparence_tour["stats"]
	return stats[stat]


## Une vue où chaque statistique de `valeurs` (nom → valeur) est posée sur son champ.
func _vue(valeurs: Dictionary) -> VueArene:
	var v := VueArene.new()
	for stat: String in valeurs:
		v.set(ApparenceTour.CHAMPS[stat], float(valeurs[stat]))
	if valeurs.has("mana") and not valeurs.has("mana_ratio"):
		v.tour_mana = v.tour_mana_max
	return v


func _afficher(vue: VueArene) -> void:
	_sup.viser(vue)
	_sup.avancer(0.0, false)


func _fondu() -> float:
	return float(d.apparence_tour["fondu_s"])


func _chemin(stat: String, palier: int, couche: String, image: int = 0) -> String:
	return Apparence.fichier_superposition(
		String(d.apparence_tour["dossier"]), stat, palier, couche, image
	)


func _haut_gauche() -> Vector2:
	return _tour.offset - _tour.texture.get_size() / 2.0


func test_chaque_statistique_a_chaque_palier_dessine_sa_superposition_a_son_ancrage() -> void:
	var skin: Dictionary = d.skins_tour["defaut"]
	var ancrages: Dictionary = skin["ancrages"]
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		var seuils := _seuils(stat)
		for p: int in range(1, seuils.size() + 1):
			_sup.reinitialiser()
			_afficher(_vue({stat: float(seuils[p - 1])}))
			var a: Dictionary = ancrages[stat]
			var attendu := _haut_gauche() + Vector2(float(a["x"]), float(a["y"]))
			for couche: String in ["arriere", "avant"]:
				var s := _sup.sprite(stat, couche)
				verifier(s.visible, "%s palier %d %s visible" % [stat, p, couche])
				verifier_egal(
					s.texture.resource_path,
					_chemin(stat, p, couche),
					"%s %d %s" % [stat, p, couche]
				)
				verifier(
					s.position.is_equal_approx(attendu + Vector2(0.0, 0.0)),
					(
						"%s %d %s : à son ancrage (%s attendu %s)"
						% [stat, p, couche, s.position, attendu]
					)
				)
			for autre: String in ApparenceTour.SUPERPOSITIONS:
				if autre != stat:
					verifier_faux(_sup.sprite(autre, "avant").visible, "%s ne montre rien" % autre)


func test_une_statistique_sous_son_premier_seuil_ne_dessine_rien() -> void:
	var sous: Dictionary = {}
	for stat: String in ApparenceTour.STATS:
		sous[stat] = float(_seuils(stat)[0]) * 0.5
	_afficher(_vue(sous))
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		for couche: String in ["arriere", "avant"]:
			verifier_faux(_sup.sprite(stat, couche).visible, "%s %s sous le seuil" % [stat, couche])
	verifier_egal(_tour.scale, _base, "la tour garde sa taille")


func test_une_tour_sans_amelioration_se_dessine_comme_avant() -> void:
	_afficher(VueArene.new())
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		for couche: String in ["arriere", "avant"]:
			verifier_faux(_sup.sprite(stat, couche).visible)
	verifier_egal(_tour.scale, _base)
	verifier_egal(
		_tour.get_child_count(),
		ApparenceTour.SUPERPOSITIONS.size() * 4 + 1,
		"4 sprites par statistique, plus le fanion de la marque"
	)


func test_les_couches_arriere_se_dessinent_derriere_la_tour_et_les_couches_avant_devant() -> void:
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		verifier(_sup.sprite(stat, "arriere").show_behind_parent, "%s arrière derrière" % stat)
		verifier_faux(_sup.sprite(stat, "avant").show_behind_parent, "%s avant devant" % stat)
		verifier(_sup.sprite(stat, "avant").get_parent() == _tour, "enfant direct de la tour")


func test_l_agrandissement_ne_depasse_jamais_1_25_et_ne_touche_pas_la_simulation() -> void:
	var seuils := _seuils("pv_max")
	for p: int in range(1, seuils.size() + 1):
		_sup.reinitialiser()
		_afficher(_vue({"pv_max": float(seuils[p - 1])}))
		var attendu := _base * (1.0 + float((d.apparence_tour["agrandissement"] as Array)[p - 1]))
		verifier(_tour.scale.is_equal_approx(attendu), "palier %d : %s" % [p, _tour.scale])
		verifier(_tour.scale.x <= _base.x * 1.25 + 0.0001, "au plus 1,25 (%s)" % _tour.scale)
	var rayon: float = float((d.partie["tour"] as Dictionary)["rayon"])
	var avant := Apparence.distance_arret(500.0, rayon)
	_afficher(_vue({"pv_max": 1.0e9}))
	verifier_egal(Apparence.distance_arret(500.0, rayon), avant, "la distance d'arrêt ne bouge pas")


func test_un_changement_de_palier_se_fond_sans_saut() -> void:
	var seuils := _seuils("armure")
	_afficher(_vue({"armure": float(seuils[0])}))
	verifier_proche(_sup.sprite("armure", "avant").modulate.a, 1.0, 0.001, "palier 1 plein")
	_sup.viser(_vue({"armure": float(seuils[1])}))
	_sup.avancer(_fondu() * 0.5, false)
	var nouveau := _sup.sprite("armure", "avant")
	var ancien := _sup.sprite("armure", "avant", true)
	verifier_egal(nouveau.texture.resource_path, _chemin("armure", 2, "avant"))
	verifier_egal(ancien.texture.resource_path, _chemin("armure", 1, "avant"))
	verifier_proche(nouveau.modulate.a, 0.5, 0.01, "à mi-fondu, le nouveau est à moitié")
	verifier_proche(ancien.modulate.a, 0.5, 0.01, "et l'ancien aussi")
	verifier(ancien.visible and nouveau.visible)
	_sup.avancer(_fondu(), false)
	verifier_proche(nouveau.modulate.a, 1.0, 0.001, "fondu fini : plein")
	verifier_faux(ancien.visible, "l'ancien a disparu")


func test_la_tour_grandit_en_douceur() -> void:
	_afficher(VueArene.new())
	_sup.viser(_vue({"pv_max": 1.0e9}))
	_sup.avancer(_fondu() * 0.5, false)
	verifier(
		_tour.scale.x > _base.x and _tour.scale.x < _base.x * 1.2, "à mi-chemin : %s" % _tour.scale
	)
	_sup.avancer(_fondu(), false)
	verifier(_tour.scale.x > _base.x * 1.2, "arrivée")


func test_la_bulle_de_mana_disparait_a_zero_et_est_pleine_au_maximum() -> void:
	var seuils := _seuils("mana")
	var maximum := float(seuils[seuils.size() - 1])
	var vue := _vue({"mana": maximum})
	vue.tour_mana = 0.0
	_afficher(vue)
	for couche: String in ["arriere", "avant"]:
		verifier_faux(_sup.sprite("mana", couche).visible, "mana 0 : bulle %s cachée" % couche)
	for part: float in [0.25, 0.5, 1.0]:
		vue.tour_mana = maximum * part
		_afficher(vue)
		for couche: String in ["arriere", "avant"]:
			var s := _sup.sprite("mana", couche)
			verifier(s.visible, "mana %s : visible" % part)
			verifier(s.region_enabled, "recadrée")
			var haut := float(s.texture.get_height())
			verifier_proche(
				s.region_rect.size.y, haut * part, 1.0, "mana %s : hauteur remplie" % part
			)
			# Le bas de la bulle reste en place : la partie pleine monte depuis le bas.
			var bas := s.position.y + s.region_rect.size.y / 2.0
			var bas_plein := (
				_haut_gauche().y
				+ float(d.skins_tour["defaut"]["ancrages"]["mana"]["y"])
				+ haut / 2.0
			)
			verifier_proche(bas, bas_plein, 1.0, "mana %s : le bas de la bulle ne bouge pas" % part)


func test_l_esquive_pulse_a_intervalles_sans_jamais_clignoter() -> void:
	var seuils := _seuils("esquive")
	_afficher(_vue({"esquive": float(seuils[1])}))
	var s := _sup.sprite("esquive", "arriere")
	var alphas: Array[float] = []
	for i: int in 400:
		_sup.avancer(0.05, false)
		alphas.append(s.modulate.a)
	var fronts: Array[int] = []
	for i: int in range(1, alphas.size()):
		if alphas[i] > 0.05 and alphas[i - 1] <= 0.05:
			fronts.append(i)
	verifier(fronts.size() >= 2, "elle revient à intervalles (%d)" % fronts.size())
	for i: int in range(0, fronts.size()):
		var dans_la_seconde := 0
		for j: int in fronts:
			if j >= fronts[i] and j < fronts[i] + 20:
				dans_la_seconde += 1
		verifier(dans_la_seconde <= 3, "au plus trois éclairs par seconde")
	var mn := alphas.min() as float
	verifier(mn <= 0.05, "elle disparaît entre deux passages")
	# Mouvement réduit : plus de pulsation, une valeur fixe.
	var fixes: Array[float] = []
	for i: int in 100:
		_sup.avancer(0.05, true)
		fixes.append(s.modulate.a)
	verifier_egal(fixes.min(), fixes.max(), "mouvement réduit : opacité constante")


func test_les_images_du_tour_lent_changent_au_plus_trois_fois_par_seconde() -> void:
	var seuils := _seuils("epines")
	_afficher(_vue({"epines": float(seuils[2])}))
	var s := _sup.sprite("epines", "avant")
	var noms: Array[String] = []
	for i: int in 400:
		_sup.avancer(0.05, false)
		noms.append(s.texture.resource_path)
	var distinctes: Dictionary = {}
	for n: String in noms:
		distinctes[n] = true
	verifier(distinctes.size() >= 2, "les piques tournent (%d images)" % distinctes.size())
	for i: int in range(0, noms.size() - 20):
		var changements := 0
		for j: int in range(i + 1, i + 21):
			if noms[j] != noms[j - 1]:
				changements += 1
		verifier(changements <= 3, "au plus trois changements par seconde (%d)" % changements)
	for n: String in distinctes:
		verifier(FileAccess.file_exists(n), "image présente : %s" % n)
	for i: int in 40:
		_sup.avancer(0.05, true)
		verifier_egal(
			s.texture.resource_path, _chemin("epines", 3, "avant"), "mouvement réduit : image fixe"
		)


func test_chaque_effet_s_allege_quand_les_autres_s_ajoutent() -> void:
	var seul: Dictionary = {"armure": float(_seuils("armure")[2])}
	_afficher(_vue(seul))
	verifier_proche(_sup.sprite("armure", "avant").modulate.a, 1.0, 0.001, "seul : plein")
	var tout: Dictionary = {}
	for stat: String in ApparenceTour.STATS:
		tout[stat] = float(_seuils(stat)[2])
	_sup.reinitialiser()
	_afficher(_vue(tout))
	var attendu := ApparenceTour.opacite_cumul(ApparenceTour.paliers(_vue(tout), d))
	verifier(attendu < 1.0, "le cumul allège")
	verifier_proche(_sup.sprite("armure", "avant").modulate.a, attendu, 0.001, "armure allégée")
	verifier_proche(
		_sup.sprite("regen", "avant").modulate.a, attendu, 0.001, "régénération allégée"
	)


func test_le_dessin_des_sept_statistiques_au_maximum_tient_dans_le_budget() -> void:
	var tout: Dictionary = {}
	for stat: String in ApparenceTour.STATS:
		tout[stat] = float(_seuils(stat)[2])
	var vue := _vue(tout)
	_afficher(vue)
	var mesures := PackedInt32Array()
	for lot: int in 40:
		var debut := Time.get_ticks_usec()
		for i: int in 25:
			_sup.viser(vue)
			_sup.avancer(0.016, false)
		mesures.append(Time.get_ticks_usec() - debut)
	var ms := MesurePas.centile_bas_ms(mesures, 25)
	verifier(ms < 1.0, "au plus 1 ms par image (%.3f ms)" % ms)
