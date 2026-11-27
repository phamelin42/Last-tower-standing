extends CasDeTest
## Les skins de tour en jeu (T11.7) : chaque skin se dessine avec son sprite, son échelle et ses
## ancrages de `data/skins_tour.json`, les superpositions de D19 se posent à ses ancrages, la marque
## de la couleur du joueur reste visible pour les huit couleurs, et rien de cela ne touche la
## simulation. Aucun nombre de ce fichier n'est propre à un skin : tout vient des données.

const SCENE := "res://scenes/arene_2d.tscn"

var d: Donnees
var _tour: Sprite2D
var _sup: SuperpositionsTour


func avant_chaque() -> void:
	d = Donnees.charger()
	_tour = Sprite2D.new()
	_tour.texture = load(String(Apparence.tour(1)["fichier"])) as Texture2D
	_tour.scale = Vector2.ONE * Apparence.tour_echelle
	_tour.offset = Vector2(0.0, _tour.texture.get_height() * 0.5 - Apparence.tour_pieds)
	arbre.root.add_child(_tour)
	_sup = SuperpositionsTour.new()
	_sup.construire(_tour, d)


func apres_chaque() -> void:
	if is_instance_valid(_tour):
		if _tour.get_parent() != null:
			_tour.get_parent().remove_child(_tour)
		_tour.free()


func _skin(id: String) -> Dictionary:
	return d.skins_tour[id]


## La taille du cadre d'un skin : sa région d'image, sinon l'image entière.
func _taille_cadre(id: String) -> Vector2:
	var skin := _skin(id)
	if skin.has("cadre"):
		var c: Dictionary = skin["cadre"]
		return Vector2(float(c["largeur"]), float(c["hauteur"]))
	return (load(String(skin["sprite"])) as Texture2D).get_size()


func _seuil(stat: String, palier: int) -> float:
	var stats: Dictionary = d.apparence_tour["stats"]
	return float((stats[stat] as Array)[palier - 1])


func _vue_palier(stat: String, palier: int) -> VueArene:
	var v := VueArene.new()
	v.set(ApparenceTour.CHAMPS[stat], _seuil(stat, palier))
	if stat == "mana":
		v.tour_mana = v.tour_mana_max
	return v


func test_chaque_superposition_se_pose_sur_chaque_skin_a_son_ancrage() -> void:
	for id: String in d.ids_skins():
		_sup.definir_skin(id, 1)
		var ancrages: Dictionary = _skin(id)["ancrages"]
		var haut_gauche := _tour.offset - _taille_cadre(id) / 2.0
		for stat: String in ApparenceTour.SUPERPOSITIONS:
			var seuils: Array = (d.apparence_tour["stats"] as Dictionary)[stat]
			for p: int in range(1, seuils.size() + 1):
				_sup.reinitialiser()
				_sup.viser(_vue_palier(stat, p))
				_sup.avancer(0.0, false)
				var a: Dictionary = ancrages[stat]
				var attendu := haut_gauche + Vector2(float(a["x"]), float(a["y"]))
				for couche: String in ["arriere", "avant"]:
					var s := _sup.sprite(stat, couche)
					verifier(s.visible, "%s %s %d %s visible" % [id, stat, p, couche])
					verifier(
						s.position.is_equal_approx(attendu),
						"%s %s %d %s : %s attendu %s" % [id, stat, p, couche, s.position, attendu]
					)


func test_chaque_skin_se_dessine_avec_son_sprite_son_cadre_et_son_echelle() -> void:
	var base := _tour.scale
	for id: String in d.ids_skins():
		_sup.definir_skin(id, 1)
		var skin := _skin(id)
		if id != "defaut":
			verifier_egal(_tour.texture.resource_path, String(skin["sprite"]), "%s : sprite" % id)
			verifier(
				_tour.scale.is_equal_approx(base * float(skin["echelle"])), "%s : échelle" % id
			)
		verifier_egal(_tour.region_enabled, skin.has("cadre"), "%s : cadre" % id)
		if skin.has("cadre"):
			var c: Dictionary = skin["cadre"]
			verifier_egal(
				_tour.region_rect,
				Rect2(float(c["x"]), float(c["y"]), float(c["largeur"]), float(c["hauteur"])),
				"%s : région" % id
			)
		# Le pied du skin repose sur l'origine du monde : le bas du cadre en est proche.
		var bas := _tour.offset.y + _taille_cadre(id).y / 2.0
		verifier(bas >= 0.0 and bas < _taille_cadre(id).y * 0.2, "%s : pied (%s)" % [id, bas])
	_sup.definir_skin("defaut", 1)
	verifier_egal(_tour.scale, base, "retour au skin par défaut : même taille")


func test_un_index_ou_un_identifiant_de_skin_inconnu_se_dessine_avec_le_skin_par_defaut() -> void:
	_sup.definir_skin("defaut", 1)
	var texture := _tour.texture.resource_path
	var echelle := _tour.scale
	for inconnu: String in ["", "n_existe_pas", "TOUR_DE_GUET", "../../x"]:
		_sup.definir_skin("tour_de_guet", 1)
		_sup.definir_skin(inconnu, 1)
		verifier_egal(_tour.texture.resource_path, texture, "« %s » : sprite par défaut" % inconnu)
		verifier_egal(_tour.scale, echelle, "« %s » : taille par défaut" % inconnu)


func test_la_marque_de_chaque_skin_prend_la_couleur_du_joueur_pour_les_huit_couleurs() -> void:
	for id: String in d.ids_skins():
		var skin := _skin(id)
		var marque: Dictionary = skin["marque"]
		var zone := Rect2(
			float(marque["x"]),
			float(marque["y"]),
			float(marque["largeur"]),
			float(marque["hauteur"])
		)
		var cadre := Rect2(Vector2.ZERO, _taille_cadre(id))
		verifier(cadre.encloses(zone), "%s : la zone de marque est dans le cadre" % id)
		var couleurs: Array[Color] = []
		var decalages: Array[float] = []
		for numero: int in range(1, 9):
			_sup.definir_skin(id, numero)
			decalages.append(_sup.decalage_marque())
			couleurs.append(_couleur_moyenne_de_la_marque(id, zone, numero))
			var fanion := _sup.fanion()
			verifier_egal(fanion.visible, marque["genre"] == "fanion", "%s : fanion" % id)
			if marque["genre"] == "fanion":
				var haut_gauche := _tour.offset - _taille_cadre(id) / 2.0
				verifier(
					fanion.position.is_equal_approx(haut_gauche + zone.get_center()),
					"%s : fanion au centre de sa zone" % id
				)
				var taille := fanion.texture.get_size() * fanion.scale
				verifier(
					taille.is_equal_approx(zone.size), "%s : fanion à la taille de sa zone" % id
				)
		for i: int in 8:
			for j: int in range(i + 1, 8):
				var ecart := (
					Vector3(
						couleurs[i].r - couleurs[j].r,
						couleurs[i].g - couleurs[j].g,
						couleurs[i].b - couleurs[j].b
					)
					. length()
				)
				verifier(
					ecart > 0.03,
					"%s : couleurs %d et %d distinctes (%.3f)" % [id, i + 1, j + 1, ecart]
				)
				# Le skin par défaut a une tour par couleur de 1 à 4 : pas de rotation à comparer.
				if id != "defaut":
					verifier(
						not is_equal_approx(decalages[i], decalages[j]),
						"%s : décalages %d et %d" % [id, i + 1, j + 1]
					)


## La couleur moyenne des pixels de la marque une fois la teinte du joueur posée : ceux du skin dans
## sa zone (marque d'origine ; pour le skin par défaut, la tour du pack de ce joueur), ou ceux du
## fanion (marque posée).
func _couleur_moyenne_de_la_marque(id: String, zone: Rect2, numero: int) -> Color:
	var skin := _skin(id)
	var image: Image
	var region := Rect2i()
	var decalage := _sup.decalage_marque()
	var toute_couleur := false
	if skin["marque"]["genre"] == "fanion":
		image = _sup.fanion().texture.get_image()
		region = Rect2i(Vector2i.ZERO, image.get_size())
	else:
		var chemin := (
			String(skin["sprite"]) if id != "defaut" else String(Apparence.tour(numero)["fichier"])
		)
		toute_couleur = id == "defaut"
		image = (load(chemin) as Texture2D).get_image()
		var origine := Vector2i.ZERO
		if skin.has("cadre"):
			origine = Vector2i(int(skin["cadre"]["x"]), int(skin["cadre"]["y"]))
		region = Rect2i(origine + Vector2i(zone.position), Vector2i(zone.size))
	var somme := Vector3.ZERO
	var n := 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var c := image.get_pixel(x, y)
			var dans_la_famille := c.h >= 0.375 and c.h <= 0.75
			if c.a >= 0.5 and c.s > 0.2 and (dans_la_famille or toute_couleur):
				var t := ApparenceTour.teinter(c, decalage)
				somme += Vector3(t.r, t.g, t.b)
				n += 1
	verifier(n >= 12, "%s : la marque a des pixels à teinter (%d)" % [id, n])
	if n == 0:
		return Color.BLACK
	somme /= float(n)
	return Color(somme.x, somme.y, somme.z)


func test_un_skin_ne_change_ni_la_distance_d_arret_ni_le_rayon_de_la_tour() -> void:
	var rayon: float = float((d.partie["tour"] as Dictionary)["rayon"])
	var arret := Apparence.distance_arret(500.0, rayon)
	var maximum := VueArene.new()
	for stat: String in ApparenceTour.STATS:
		maximum.set(ApparenceTour.CHAMPS[stat], _seuil(stat, 3))
	for id: String in d.ids_skins():
		_sup.definir_skin(id, 1)
		_sup.reinitialiser()
		_sup.viser(maximum)
		_sup.avancer(1.0, false)
		var base := (
			Apparence.tour_echelle * float(_skin(id)["echelle"])
			if id != "defaut"
			else Apparence.tour_echelle
		)
		verifier(
			_tour.scale.x <= base * 1.25 + 0.0001, "%s : au plus +25 %% (%s)" % [id, _tour.scale]
		)
		verifier_egal(Apparence.distance_arret(500.0, rayon), arret, "%s : distance d'arrêt" % id)
	verifier_egal(float((d.partie["tour"] as Dictionary)["rayon"]), rayon, "le rayon ne change pas")


func _arene() -> Arene2D:
	var arene := (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(arene)
	arene.reinitialiser()
	return arene


func _liberer(arene: Arene2D) -> void:
	if is_instance_valid(arene):
		if arene.get_parent() != null:
			arene.get_parent().remove_child(arene)
		arene.free()


func _texture_de_la_tour(arene: Arene2D) -> String:
	var tour := arene.get_node("Ennemis/Tour") as Sprite2D
	return tour.texture.resource_path


func test_le_nom_du_joueur_reste_ecrit_sous_chaque_skin() -> void:
	var arene := _arene()
	var etiquette := arene.get_node("Noms/NomJoueur") as Label
	for index: int in d.ids_skins().size():
		arene.definir_skin(index)
		arene.definir_joueur(1 + index % 8, "Mina")
		verifier(etiquette.text.contains("Mina"), "skin %d : le nom reste écrit" % index)
		verifier(etiquette.visible, "skin %d : nom visible" % index)
	_liberer(arene)


func test_un_index_de_skin_inconnu_dans_l_arene_se_dessine_avec_le_skin_par_defaut() -> void:
	var arene := _arene()
	arene.definir_joueur(1, "Mina")
	var defaut := _texture_de_la_tour(arene)
	var n := d.ids_skins().size()
	for index: int in [-1, n, n + 5, 2147483647]:
		arene.definir_skin(1)
		arene.definir_skin(index)
		verifier_egal(_texture_de_la_tour(arene), defaut, "index %d : skin par défaut" % index)
	_liberer(arene)


func test_la_tour_regardee_porte_le_skin_de_son_joueur() -> void:
	var arene := _arene()
	arene.definir_joueur(1, "Moi")
	var propre := _texture_de_la_tour(arene)
	var ids := d.ids_skins()
	for index: int in range(1, ids.size()):
		arene.montrer_arene(77, "Autre", 2, index)
		verifier_egal(
			_texture_de_la_tour(arene),
			String(_skin(ids[index])["sprite"]),
			"skin %d regardé" % index
		)
		arene.montrer_arene(-1, "", 0)
		verifier_egal(_texture_de_la_tour(arene), propre, "retour à ma tour (skin %d)" % index)
	_liberer(arene)


func test_changer_de_skin_ne_change_pas_les_performances() -> void:
	var arene := _arene()
	arene.definir_joueur(1, "Mina")
	var vue := VueArene.new()
	for i: int in 1000:
		vue.ennemis_id.append(i + 1)
		vue.ennemis_pos.append(Vector2(300.0 + float(i % 40) * 30.0, -float(i / 40) * 30.0))
		vue.ennemis_famille.append(0)
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	vue.tick = 1
	arene.afficher(vue, 0.0)
	var autre := d.ids_skins().size() - 1
	var mesures: Dictionary = {0: INF, autre: INF}
	# Deux passes alternées, le meilleur temps de chacun : la charge d'autres processus passe par là.
	for _passe: int in 2:
		for index: int in [0, autre]:
			arene.definir_skin(index)
			var durees := PackedInt32Array()
			for lot: int in 20:
				var debut := Time.get_ticks_usec()
				for i: int in 5:
					arene.afficher_courant(0.05 * float(lot * 5 + i))
				durees.append(Time.get_ticks_usec() - debut)
			mesures[index] = minf(float(mesures[index]), MesurePas.centile_bas_ms(durees, 5))
	var ecart := absf(float(mesures[0]) - float(mesures[autre]))
	verifier(
		ecart < 0.5 + 0.25 * float(mesures[0]), "un autre skin coûte autant (%s ms)" % str(mesures)
	)
	_liberer(arene)


## Un skin n'est pas forcément du pixel art : son filtre de texture et son échelle (n'importe quel
## nombre entre 0 et le maximum, entier ou non) se règlent dans ses données, pas dans le code.
func test_le_filtre_et_l_echelle_d_un_skin_se_reglent_dans_ses_donnees() -> void:
	var brut := AidesPartie.brut()
	var skins: Dictionary = brut["skins_tour.json"]
	var skin: Dictionary = skins["tour_de_guet"]
	skin["filtre"] = "lineaire"
	skin["echelle"] = 0.37
	var donnees := Donnees.depuis_brut(brut)
	verifier_non_nul(donnees, "données valides avec un filtre lisse et une échelle fractionnaire")
	if donnees == null:
		return
	var sup := SuperpositionsTour.new()
	sup.construire(_tour, donnees)
	sup.definir_skin("tour_de_guet", 1)
	verifier_egal(_tour.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "image lissée")
	verifier(
		_tour.scale.is_equal_approx(Vector2.ONE * Apparence.tour_echelle * 0.37), "échelle 0,37"
	)
	sup.definir_skin("tour_embuscade", 1)
	verifier_egal(_tour.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "sans champ : pixel net")
	sup.definir_skin("defaut", 1)
	verifier_egal(_tour.texture_filter, CanvasItem.TEXTURE_FILTER_PARENT_NODE, "défaut : hérité")
	for mauvais: Variant in ["bilineaire", "", 3, null, true]:
		var b2 := AidesPartie.brut()
		((b2["skins_tour.json"] as Dictionary)["tour_de_guet"] as Dictionary)["filtre"] = mauvais
		verifier(not Donnees.valider(b2).is_empty(), "filtre %s refusé" % str(mauvais))
