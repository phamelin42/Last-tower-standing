extends CasDeTest
## Ce que la joueuse doit voir de l'arène 2D : chaque ennemi reçu est un sprite de sa famille, à
## la bonne place, tourné du bon côté et animé selon ce qu'il fait ; la tour est au centre avec
## le nom du joueur dessous ; le nombre de sprites suit la vue sans rien laisser derrière lui.

const SCENE := "res://scenes/arene_2d.tscn"
const RAYON_SPAWN: float = 1300.0

var _arene: Arene2D = null
var _donnees: Donnees = null
var _tick: int = 0


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_arene = _instancier()
	_tick = 0


func apres_chaque() -> void:
	_liberer(_arene)
	_arene = null


func _instancier() -> Arene2D:
	var arene := (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(arene)
	arene.reinitialiser()
	return arene


# Libéré tout de suite : un nœud en attente de `queue_free` ne l'est jamais dans le lanceur.
func _liberer(noeud: Node) -> void:
	if is_instance_valid(noeud):
		if noeud.get_parent() != null:
			noeud.get_parent().remove_child(noeud)
		noeud.free()


func _nb_entites() -> int:
	return _donnees.familles.size() + 2


## `repartition` : index d'entité → nombre d'ennemis, dispersés dans le cercle d'apparition avec
## une graine fixe.
func _vue(repartition: Dictionary, evenements: Array[Dictionary] = []) -> VueArene:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	var id: int = 0
	for entite: int in repartition:
		var nb: int = repartition[entite]
		for i: int in nb:
			id += 1
			var angle: float = rng.randf() * TAU
			vue.ennemis_id.append(id)
			vue.ennemis_pos.append(Vector2.from_angle(angle) * RAYON_SPAWN * rng.randf())
			vue.ennemis_famille.append(entite)
			vue.ennemis_pv.append(255)
			vue.ennemis_statuts.append(0)
	vue.evenements = evenements
	return vue


## Une vue avec un seul ennemi de l'entité `entite`, à la position `p`.
func _vue_un(entite: int, p: Vector2) -> VueArene:
	var vue := _vue({entite: 1})
	vue.ennemis_pos[0] = p
	return vue


func _portee(entite: int) -> float:
	if entite < _donnees.familles.size():
		return float((_donnees.familles[entite] as Dictionary)["portee_attaque"])
	if entite == _donnees.familles.size():
		return 0.0
	return float(_donnees.boss["portee_attaque"])


func _entree(entite: int) -> Dictionary:
	return Apparence.entree(Apparence.ids_entites(_donnees)[entite])


func _ligne(entite: int) -> int:
	return _arene.ligne_instance(entite, 0)


## Nombre d'images de la ligne `ligne` dans les animations d'une entrée (0 si aucune n'y joue).
## Décalage (offset) de base du sprite pour l'image `image`, miroir ou non.
func _placement(e: Dictionary, image: int, miroir: bool) -> Vector2:
	var p: Dictionary = Apparence.placement(
		String(e["cle_boites"]), image, e["case"], int(e["colonnes"]), float(e["pieds"]), true
	)
	var offset: Vector2 = p["offset"]
	return Vector2(-offset.x if miroir else offset.x, offset.y)


func _images_ligne(e: Dictionary, ligne: int) -> int:
	var images: int = 0
	for nom: String in ["repos", "course", "attaque", "attaque_bas", "attaque_haut"]:
		var anim: Vector2i = e[nom]
		if anim.x == ligne:
			images = maxi(images, anim.y)
	return images


func _evenement(k: String, p: Vector2 = Vector2(100, 0)) -> Dictionary:
	return {"k": k, "t": _tick, "de": p, "vers": p, "type_degats": 0, "rayon": 0.0}


func _rayon_tour() -> float:
	return float((_donnees.partie["tour"] as Dictionary)["rayon"])


func test_la_scene_se_construit_avec_la_tour_au_centre_le_sol_et_la_camera() -> void:
	verifier_non_nul(_arene)
	var tour := _arene.find_child("Tour", true, false) as Sprite2D
	verifier_non_nul(tour, "nœud Tour")
	if tour != null:
		verifier_proche(tour.global_position.x, 0.0, 0.0001)
		verifier_proche(tour.global_position.y, 0.0, 0.0001)
	verifier_non_nul(_arene.get_node_or_null("Sol"), "nœud Sol")
	verifier_non_nul(_arene.get_node_or_null("CercleApparition"), "cercle d'apparition")
	verifier_non_nul(_arene.get_node_or_null("Camera") as CameraArene, "caméra")


func test_le_pixel_art_reste_net_et_les_ennemis_se_trient_en_profondeur() -> void:
	verifier_egal(_arene.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "plus proche voisin")
	var ennemis := _arene.get_node("Ennemis") as Node2D
	verifier(ennemis.y_sort_enabled, "tri en profondeur par Y")
	var tour := _arene.find_child("Tour", true, false) as Node2D
	verifier_egal(tour.get_parent(), ennemis, "la tour se trie avec les ennemis")


func test_comptes_exacts_par_entite_pour_0_1_300_et_1000_ennemis() -> void:
	for total: int in [0, 1, 300, 1000]:
		for cible: int in _nb_entites():
			_arene.afficher(_vue({cible: total}), 1.0)
			for entite: int in _nb_entites():
				var attendu: int = total if entite == cible else 0
				verifier_egal(
					_arene.nombre_instances_visibles(entite),
					attendu,
					"total %d, cible %d, entité %d" % [total, cible, entite]
				)


func test_repartition_mixte_et_famille_absente() -> void:
	_arene.afficher(_vue({0: 5, 2: 7, _donnees.familles.size() + 1: 1}), 1.0)
	verifier_egal(_arene.nombre_instances_visibles(0), 5)
	verifier_egal(_arene.nombre_instances_visibles(1), 0, "famille absente")
	verifier_egal(_arene.nombre_instances_visibles(2), 7)
	verifier_egal(_arene.nombre_instances_visibles(_donnees.familles.size() + 1), 1, "boss")


func test_une_famille_inconnue_n_echoue_pas() -> void:
	var inconnue: int = _nb_entites() + 5
	_arene.afficher(_vue({inconnue: 3, 0: 2}), 1.0)
	verifier_egal(_arene.nombre_instances_visibles(0), 2)
	verifier_egal(_arene.nombre_instances_visibles(inconnue), 0)
	verifier_egal(_arene.nombre_instances_visibles(-1), 0)


func test_la_position_du_plan_devient_le_pixel_du_monde() -> void:
	for entite: int in _nb_entites():
		for p: Vector2 in [Vector2.ZERO, Vector2(500, -250), Vector2(-1300, 0), Vector2(0, 1300)]:
			_arene.afficher(_vue_un(entite, p), 1.0)
			verifier_egal(
				_arene.position_instance(entite, 0),
				Apparence.vers_pixels(p),
				"entité %d en %s" % [entite, p]
			)


func test_l_ennemi_regarde_la_tour_d_ou_qu_il_vienne() -> void:
	for entite: int in _nb_entites():
		_arene.afficher(_vue_un(entite, Vector2(900, 100)), 1.0)
		verifier(_arene.sprite_instance(entite, 0).flip_h, "entité %d venue de la droite" % entite)
		_arene.afficher(_vue_un(entite, Vector2(-900, 100)), 2.0)
		verifier_faux(
			_arene.sprite_instance(entite, 0).flip_h, "entité %d venue de la gauche" % entite
		)


func test_l_animation_suit_ce_que_fait_l_ennemi() -> void:
	for entite: int in _nb_entites():
		var e := _entree(entite)
		var portee: float = _portee(entite)
		var arret: float = Apparence.distance_arret(portee, _rayon_tour())
		var a_distance: bool = portee > Apparence.PORTEE_CORPS_A_CORPS
		# Loin de la tour : il court.
		_arene.afficher(_vue_un(entite, Vector2(RAYON_SPAWN, 0)), 1.0)
		verifier_egal(_ligne(entite), (e["course"] as Vector2i).x, "entité %d court" % entite)
		# À l'arrêt, au bord de la tour : repos pour un tireur, attaque pour qui est au contact ;
		# le convoi, qui ne combat pas, continue de marcher.
		_arene.afficher(_vue_un(entite, Vector2(arret, 0)), 2.0)
		var attendu: Vector2i = e["attaque"]
		if entite == _donnees.familles.size():
			attendu = e["course"]
		elif a_distance:
			attendu = e["repos"]
		verifier_egal(_ligne(entite), attendu.x, "entité %d à l'arrêt" % entite)


func test_l_attaque_au_contact_regarde_vers_la_tour() -> void:
	# Un ennemi au-dessus de la tour frappe vers le bas, un ennemi dessous vers le haut.
	for entite: int in _donnees.familles.size():
		if _portee(entite) > Apparence.PORTEE_CORPS_A_CORPS:
			continue
		var e := _entree(entite)
		var arret: float = Apparence.distance_arret(_portee(entite), _rayon_tour())
		_arene.afficher(_vue_un(entite, Vector2(0, -arret)), 1.0)
		verifier_egal(_ligne(entite), (e["attaque_bas"] as Vector2i).x)
		_arene.afficher(_vue_un(entite, Vector2(0, arret)), 2.0)
		verifier_egal(_ligne(entite), (e["attaque_haut"] as Vector2i).x)


func test_l_image_affichee_reste_dans_les_images_de_l_animation() -> void:
	for entite: int in _nb_entites():
		var e := _entree(entite)
		var arret: float = Apparence.distance_arret(_portee(entite), _rayon_tour())
		for p: Vector2 in [Vector2(RAYON_SPAWN, 0), Vector2(arret, 0)]:
			for t: int in 40:
				_arene.afficher(_vue_un(entite, p), 1.0 + float(t) * 0.07)
				var colonne: int = _arene.colonne_instance(entite, 0)
				verifier(colonne < int(e["colonnes"]), "colonne valide")
				verifier(_ligne(entite) < int(e["lignes"]), "ligne valide")
				var images: int = _images_ligne(e, _ligne(entite))
				verifier(
					colonne < images, "entité %d : colonne %d sur %d" % [entite, colonne, images]
				)


func test_le_volant_flotte_et_les_autres_restent_au_sol() -> void:
	for entite: int in _nb_entites():
		var e := _entree(entite)
		var amplitude: float = float(e["flottement"])
		var ecart_max: float = 0.0
		for t: int in 40:
			_arene.afficher(_vue_un(entite, Vector2(300, 300)), 1.0 + float(t) * 0.1)
			var image: int = _arene.image_instance(entite, 0)
			var base: float = _placement(e, image, false).y
			var decalage: float = _arene.sprite_instance(entite, 0).offset.y - base
			ecart_max = maxf(ecart_max, absf(decalage))
			verifier(absf(decalage) <= amplitude + 0.0001, "entité %d dans l'amplitude" % entite)
			# L'ombre est dessinée sur la feuille : aucun sprite d'ombre en plus.
			verifier_nul(_arene.sprite_instance(entite, 0).get_node_or_null("Ombre"))
		if bool(e["volant"]):
			verifier(ecart_max > amplitude * 0.5, "entité %d flotte vraiment" % entite)
		else:
			verifier_proche(ecart_max, 0.0, 0.0001, "entité %d ne bouge pas" % entite)


func test_le_convoi_porte_son_sac_d_or() -> void:
	var convoi: int = _donnees.familles.size()
	_arene.afficher(_vue_un(convoi, Vector2(300, 300)), 1.0)
	verifier(_arene.sprite_instance(convoi, 0).get_child_count() > 0, "le sac suit le convoi")


func test_passage_de_1000_a_zero_ennemi_ne_laisse_aucun_noeud() -> void:
	_arene.afficher(_vue({}), 1.0)
	var vide: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_arene.afficher(_vue({0: 100, 1: 300, 4: 400, _donnees.familles.size() + 1: 200}), 2.0)
	var plein: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	verifier(plein >= vide + 1000, "les sprites existent : %d contre %d" % [plein, vide])
	_arene.afficher(_vue({}), 3.0)
	verifier_egal(
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), vide, "rien ne reste"
	)


func test_le_nombre_de_sprites_suit_apparition_et_disparition() -> void:
	var total: Array[int] = [0, 1, 50, 300, 20, 0, 7]
	var temps: float = 1.0
	for n: int in total:
		temps += 1.0
		_arene.afficher(_vue({1: n}), temps)
		verifier_egal(_arene.nombre_instances_visibles(1), n)
		var noeuds: int = _arene.get_node("Ennemis").get_child_count()
		verifier(noeuds <= n + Arene2D.RESERVE_POOL + 2, "pool %d pour %d ennemis" % [noeuds, n])


func test_la_mort_joue_la_feuille_commune_puis_disparait() -> void:
	verifier_egal(_arene.nombre_morts_visibles(), 0)
	_arene.afficher(_vue({}, [_evenement("mort", Vector2(200, 100))]), 1.0)
	verifier_egal(_arene.nombre_morts_visibles(), 1, "un mort affiché")
	var mort := _arene.sprite_mort(0)
	verifier(mort.texture.resource_path.ends_with("Dead.png"))
	verifier_egal(mort.global_position, Apparence.vers_pixels(Vector2(200, 100)))
	_arene.afficher_courant(10.0)
	verifier_egal(_arene.nombre_morts_visibles(), 0, "la mort est finie")


func test_une_rafale_de_morts_reste_sous_le_plafond() -> void:
	var rafale: Array[Dictionary] = []
	for i: int in 5000:
		rafale.append(_evenement("mort", Vector2(i % 700, i % 300)))
	_arene.afficher(_vue({}, rafale), 1.0)
	verifier(_arene.nombre_morts_visibles() <= Arene2D.PLAFOND_MORTS)
	verifier(_arene.nombre_morts_visibles() > 0)
	_arene.afficher_courant(10.0)
	verifier_egal(_arene.nombre_morts_visibles(), 0)


func test_chaque_numero_de_joueur_donne_sa_tour_et_son_nom_sous_la_tour() -> void:
	var tour := _arene.find_child("Tour", true, false) as Sprite2D
	var etiquette := _arene.find_child("NomJoueur", true, false) as Label
	verifier_non_nul(etiquette, "étiquette du nom")
	for numero: int in range(1, 9):
		var nom: String = "Joueuse longue numéro %d" % numero
		_arene.definir_joueur(numero, nom)
		var t: Dictionary = Apparence.tour(numero)
		verifier_egal(tour.texture.resource_path, String(t["fichier"]), "tour %d" % numero)
		verifier_egal(tour.material != null, numero > 4, "nuanceur de la tour %d" % numero)
		verifier_contient(etiquette.text, nom, "nom écrit pour %d" % numero)
		verifier_contient(etiquette.text, str(numero), "numéro écrit pour %d" % numero)
		verifier(etiquette.get_global_rect().position.y >= tour.global_position.y, "sous la tour")


func test_la_vue_reconstruite_par_dictionnaire_donne_le_meme_affichage() -> void:
	var vue := _vue({0: 4, 1: 30, 3: 10})
	var copie := VueArene.from_dict(vue.to_dict())
	verifier_non_nul(copie)
	var autre := _instancier()
	_arene.afficher(vue, 1.0)
	autre.afficher(copie, 1.0)
	for entite: int in _nb_entites():
		var nb: int = _arene.nombre_instances_visibles(entite)
		verifier_egal(autre.nombre_instances_visibles(entite), nb, "entité %d" % entite)
		for i: int in nb:
			verifier_egal(autre.position_instance(entite, i), _arene.position_instance(entite, i))
	_liberer(autre)


func test_l_arene_se_nourrit_des_signaux_de_la_source() -> void:
	var source := SourceFactice.new()
	_arene.lier(source)
	source.emettre_arene(_vue({1: 12, 4: 3}))
	_arene.afficher_courant(1.0)
	verifier_egal(_arene.nombre_instances_visibles(1), 12)
	verifier_egal(_arene.nombre_instances_visibles(4), 3)
	source.free()


func test_aucune_vue_recue_n_affiche_rien_et_n_echoue() -> void:
	var source := SourceFactice.new()
	_arene.lier(source)
	_arene.afficher_courant(1.0)
	for entite: int in _nb_entites():
		verifier_egal(_arene.nombre_instances_visibles(entite), 0)
	source.free()


func test_tout_noeud_cree_est_libere() -> void:
	var avant: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var arene := _instancier()
	var rafale: Array[Dictionary] = []
	for i: int in 500:
		rafale.append(_evenement("mort"))
	arene.afficher(_vue({0: 50, 1: 400}, rafale), 1.0)
	_liberer(arene)
	var apres: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	verifier_egal(apres, avant, "aucun nœud restant")


func test_le_pied_reste_au_meme_point_de_l_ecran_apres_recadrage_pour_chaque_image() -> void:
	# Le point de la case où le pied touche le sol (centre, ligne `pieds`) doit tomber exactement sur
	# la position de l'ennemi, quelle que soit l'image, le côté d'où il vient et l'animation.
	var arret_loin := Vector2(RAYON_SPAWN, 0.0)
	for entite: int in _nb_entites():
		var e := _entree(entite)
		var case_px: Vector2i = e["case"]
		var arret: float = Apparence.distance_arret(_portee(entite), _rayon_tour())
		var vues: Array[Vector2] = [arret_loin, -arret_loin, Vector2(arret, 0), Vector2(-arret, 0)]
		vues.append_array([Vector2(0, arret), Vector2(0, -arret)])
		for p: Vector2 in vues:
			for t: int in 12:
				_arene.afficher(_vue_un(entite, p), 1.0 + float(t) * 0.1)
				var s := _arene.sprite_instance(entite, 0)
				var image: int = _arene.image_instance(entite, 0)
				var colonne: int = image % int(e["colonnes"])
				var ligne: int = image / int(e["colonnes"])
				var pied := Vector2(
					float(colonne * case_px.x) + float(case_px.x) * 0.5,
					float(ligne * case_px.y) + float(e["pieds"])
				)
				var centre: Vector2 = s.region_rect.get_center()
				var atterrit := Vector2(
					(
						s.offset.x - (pied.x - centre.x)
						if s.flip_h
						else s.offset.x + pied.x - centre.x
					),
					s.offset.y + pied.y - centre.y
				)
				# Un volant flotte : on retire le flottement avant de comparer.
				if bool(e["volant"]):
					atterrit.y += _flottement(entite, s, image)
				verifier_proche(
					atterrit.x, 0.0, 0.001, "x du pied, entité %d image %d" % [entite, image]
				)
				verifier_proche(
					atterrit.y, 0.0, 0.001, "y du pied, entité %d image %d" % [entite, image]
				)


## Part du décalage vertical due au flottement : la différence avec le placement de base.
func _flottement(entite: int, s: Sprite2D, image: int) -> float:
	return -(s.offset.y - _placement(_entree(entite), image, false).y)


func test_un_ennemi_qui_recouvre_la_tour_devient_translucide_et_la_retrouve_en_s_eloignant(
) -> void:
	for entite: int in _nb_entites():
		# Devant la tour, sur elle : translucide.
		_arene.afficher(_vue_un(entite, Vector2(0, 40)), 1.0)
		var devant := _arene.sprite_instance(entite, 0)
		verifier(devant.modulate.a < 1.0, "entité %d devant la tour" % entite)
		verifier(devant.modulate.a > 0.0, "entité %d reste visible" % entite)
		# Derrière la tour, la tour la cache déjà : opaque.
		_arene.afficher(_vue_un(entite, Vector2(0, -40)), 2.0)
		verifier_proche(_arene.sprite_instance(entite, 0).modulate.a, 1.0, 0.0001, "derrière")
		# Loin de la tour, à droite comme devant : opaque, sur le même sprite réutilisé.
		_arene.afficher(_vue_un(entite, Vector2(0, 40)), 3.0)
		_arene.afficher(_vue_un(entite, Vector2(900, 900)), 4.0)
		verifier_proche(_arene.sprite_instance(entite, 0).modulate.a, 1.0, 0.0001, "loin")


func test_le_nom_du_joueur_est_dessine_apres_les_ennemis() -> void:
	var noms := _arene.get_node("Noms")
	var ennemis := _arene.get_node("Ennemis")
	verifier(noms.get_index() > ennemis.get_index(), "le nom reste lisible sous un ennemi")


func test_tailles_a_l_ecran_au_zoom_par_defaut() -> void:
	# Cibles de Phil à 720p : ennemi ordinaire 6 à 7 % de la hauteur, tour 18 %.
	var zone := Vector2(1280, 720)
	var camera := _arene.get_node("Camera") as CameraArene
	camera.cadrer(Rect2(0.0, zone.y * 0.1, zone.x, zone.y * 0.65), zone)
	var zoom: float = camera.zoom.x
	var tour := _arene.find_child("Tour", true, false) as Sprite2D
	# Hauteur visible de la tour dans sa feuille (183 px sur 256) : le reste est transparent.
	var hauteur_tour: float = 183.0 * tour.scale.y * zoom
	verifier(
		hauteur_tour / zone.y >= 0.15 and hauteur_tour / zone.y <= 0.21,
		"tour %f" % (hauteur_tour / zone.y)
	)
	for entite: int in _donnees.familles.size():
		var e := _entree(entite)
		if float(e["echelle"]) != 1.0 or bool(e["volant"]):
			continue
		_arene.afficher(_vue_un(entite, Vector2(RAYON_SPAWN, 0)), 1.0 + float(entite))
		var s := _arene.sprite_instance(entite, 0)
		var part: float = s.region_rect.size.y * s.scale.y * zoom / zone.y
		verifier(part >= 0.04 and part <= 0.09, "entité %d : %f de la hauteur" % [entite, part])
