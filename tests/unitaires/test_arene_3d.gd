extends CasDeTest
## Ce que le joueur doit voir de l'arène : chaque ennemi reçu est affiché dans sa famille, au
## sol ou en l'air selon sa nature, la tour est au centre, la caméra cadre tout le cercle
## d'apparition, et une rafale d'effets ne fait ni ramer ni fuir de mémoire.

const SCENE := "res://scenes/arene_3d.tscn"
const RAYON_SPAWN: float = 1300.0

var _arene: Arene3D = null
var _donnees: Donnees = null
var _tick: int = 0


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_arene = _instancier()
	_tick = 0


func apres_chaque() -> void:
	_liberer(_arene)
	_arene = null


func _instancier() -> Arene3D:
	var arene := (load(SCENE) as PackedScene).instantiate() as Arene3D
	arbre.root.add_child(arene)
	# Le lanceur n'appelle pas `_ready` : on force la construction comme le ferait le jeu.
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


## `repartition` : index de famille → nombre d'ennemis. Les positions sont dispersées dans le
## cercle d'apparition, avec une graine fixe pour rester reproductible.
func _vue(repartition: Dictionary, evenements: Array[Dictionary] = []) -> VueArene:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	var id: int = 0
	for famille: int in repartition:
		var nb: int = repartition[famille]
		for i: int in nb:
			id += 1
			var angle: float = rng.randf() * TAU
			vue.ennemis_id.append(id)
			vue.ennemis_pos.append(Vector2.from_angle(angle) * RAYON_SPAWN * rng.randf())
			vue.ennemis_famille.append(famille)
			vue.ennemis_pv.append(255)
			vue.ennemis_statuts.append(0)
	vue.evenements = evenements
	return vue


func _index_volant() -> int:
	for i: int in _donnees.familles.size():
		var f: Dictionary = _donnees.familles[i]
		if f["volant"]:
			return i
	return -1


func _index_marcheur() -> int:
	for i: int in _donnees.familles.size():
		var f: Dictionary = _donnees.familles[i]
		if not f["volant"]:
			return i
	return -1


func _evenement(k: String, type_degats: int = 0, rayon: float = 0.0) -> Dictionary:
	return {
		"k": k,
		"t": _tick,
		"de": Vector2(100, 0),
		"vers": Vector2(300, 200),
		"type_degats": type_degats,
		"rayon": rayon,
	}


func test_la_scene_se_construit_avec_la_tour_au_centre_et_la_camera() -> void:
	verifier_non_nul(_arene)
	var tour := _arene.get_node_or_null("Tour") as MeshInstance3D
	verifier_non_nul(tour, "nœud Tour")
	if tour != null:
		verifier_proche(tour.position.x, 0.0, 0.0001)
		verifier_proche(tour.position.z, 0.0, 0.0001)
		# Le centre du maillage est à l'origine du nœud : la tour repose sur le sol.
		var demi: float = tour.mesh.get_aabb().size.y * 0.5
		verifier_proche(tour.position.y, demi, 0.0001)
	verifier_non_nul(_arene.get_node_or_null("Sol"), "nœud Sol")
	verifier_non_nul(_arene.get_node_or_null("Camera") as CameraArene, "caméra")


func test_comptes_exacts_par_famille_pour_0_1_300_et_1000_ennemis() -> void:
	var nb_entites: int = _nb_entites()
	for total: int in [0, 1, 300, 1000]:
		# Tous les ennemis dans une seule famille, tour à tour : chaque famille, convoi et
		# boss compris, doit compter exactement `total` et les autres 0.
		for cible: int in nb_entites:
			_arene.afficher(_vue({cible: total}), 1.0)
			for famille: int in nb_entites:
				var attendu: int = total if famille == cible else 0
				verifier_egal(
					_arene.nombre_instances_visibles(famille),
					attendu,
					"total %d, cible %d, famille %d" % [total, cible, famille]
				)


func test_repartition_mixte_et_famille_absente() -> void:
	_arene.afficher(_vue({0: 5, 2: 7, _donnees.familles.size() + 1: 1}), 1.0)
	verifier_egal(_arene.nombre_instances_visibles(0), 5)
	verifier_egal(_arene.nombre_instances_visibles(1), 0, "famille absente")
	verifier_egal(_arene.nombre_instances_visibles(2), 7)
	verifier_egal(_arene.nombre_instances_visibles(_donnees.familles.size() + 1), 1, "boss")


func test_passage_de_300_a_zero_ennemi() -> void:
	_arene.afficher(_vue({1: 300}), 1.0)
	verifier_egal(_arene.nombre_instances_visibles(1), 300)
	_arene.afficher(_vue({}), 2.0)
	verifier_egal(_arene.nombre_instances_visibles(1), 0)


func test_une_famille_inconnue_n_echoue_pas() -> void:
	var inconnue: int = _nb_entites() + 5
	_arene.afficher(_vue({inconnue: 3, 0: 2}), 1.0)
	verifier_egal(_arene.nombre_instances_visibles(0), 2)
	verifier_egal(_arene.nombre_instances_visibles(inconnue), 0)
	verifier_egal(_arene.nombre_instances_visibles(-1), 0)


func test_les_volants_sont_plus_hauts_que_les_marcheurs_et_tout_est_au_dessus_du_sol() -> void:
	var volant: int = _index_volant()
	var marcheur: int = _index_marcheur()
	verifier(volant >= 0 and marcheur >= 0, "les données ont les deux sortes")
	_arene.afficher(_vue({volant: 1, marcheur: 1}), 1.0)
	var y_volant: float = _arene.transform_instance(volant, 0).origin.y
	var y_marcheur: float = _arene.transform_instance(marcheur, 0).origin.y
	verifier(y_volant > y_marcheur, "volant %f > marcheur %f" % [y_volant, y_marcheur])
	# Chaque entité repose sur le sol : son centre est à au moins une demi-hauteur.
	for famille: int in _nb_entites():
		_arene.afficher(_vue({famille: 1}), 1.0)
		var demi: float = Apparence.maillage_famille(famille).get_aabb().size.y * 0.5
		var y: float = _arene.transform_instance(famille, 0).origin.y
		verifier(y >= demi - 0.0001, "famille %d : y %f, demi-hauteur %f" % [famille, y, demi])


func test_la_position_du_plan_devient_le_sol() -> void:
	var vue := _vue({1: 1})
	vue.ennemis_pos[0] = Vector2(500, -250)
	_arene.afficher(vue, 1.0)
	var origine: Vector3 = _arene.transform_instance(1, 0).origin
	verifier_proche(origine.x, 500.0 * Apparence.ECHELLE, 0.0001)
	verifier_proche(origine.z, -250.0 * Apparence.ECHELLE, 0.0001)


func test_la_vue_reconstruite_par_dictionnaire_donne_le_meme_affichage() -> void:
	var vue := _vue({0: 4, 1: 30, 3: 10})
	var copie := VueArene.from_dict(vue.to_dict())
	verifier_non_nul(copie)
	var autre := _instancier()
	_arene.afficher(vue, 1.0)
	autre.afficher(copie, 1.0)
	for famille: int in _nb_entites():
		var nb: int = _arene.nombre_instances_visibles(famille)
		verifier_egal(autre.nombre_instances_visibles(famille), nb, "famille %d" % famille)
		for i: int in nb:
			verifier_egal(
				autre.transform_instance(famille, i), _arene.transform_instance(famille, i)
			)
	_liberer(autre)


func test_la_scene_se_nourrit_des_signaux_de_la_source() -> void:
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
	for famille: int in _nb_entites():
		verifier_egal(_arene.nombre_instances_visibles(famille), 0)
	source.free()


func test_le_plafond_d_effets_tient_sous_une_rafale_de_5000_evenements() -> void:
	var rafale: Array[Dictionary] = []
	var kinds: Array[String] = ["tir", "impact", "mort"]
	for i: int in 5000:
		rafale.append(_evenement(kinds[i % 3], i % 5, 100.0 if i % 3 == 1 else 0.0))
	_arene.afficher(_vue({}, rafale), 1.0)
	var effets := _arene.get_node("Effets") as Effets
	verifier(effets.nombre_vivants() <= Effets.PLAFOND, "vivants %d" % effets.nombre_vivants())
	verifier(effets.taille_pool() <= Effets.PLAFOND, "pool %d" % effets.taille_pool())
	verifier(effets.nombre_vivants() > 0, "les premiers effets sont bien affichés")


func test_les_effets_s_eteignent_et_le_pool_est_reutilise() -> void:
	var effets := _arene.get_node("Effets") as Effets
	for tour: int in 10:
		var lot: Array[Dictionary] = []
		for i: int in 50:
			lot.append(_evenement("impact", 0, 100.0))
		_arene.afficher(_vue({}, lot), float(tour))
		effets.avancer(1.0)
		verifier_egal(effets.nombre_vivants(), 0, "tout est éteint après 1 s")
	verifier(effets.taille_pool() <= 50, "pool réutilisé : %d" % effets.taille_pool())


func test_cent_impacts_dans_une_vue_restent_sous_la_borne() -> void:
	var lot: Array[Dictionary] = []
	for i: int in 100:
		lot.append(_evenement("impact", 0, 100.0))
	_arene.afficher(_vue({}, lot), 1.0)
	var effets := _arene.get_node("Effets") as Effets
	verifier(effets.taille_pool() <= Effets.PLAFOND)


func test_la_camera_borne_le_zoom() -> void:
	var camera := _arene.get_node("Camera") as CameraArene
	var depart: float = camera.distance()
	camera.zoomer(-1000.0)
	var proche: float = camera.distance()
	camera.zoomer(1000.0)
	var loin: float = camera.distance()
	verifier(proche < loin, "proche < loin")
	verifier(proche > 0.0)
	camera.zoomer(1000.0)
	verifier_proche(camera.distance(), loin, 0.0001, "borne haute stable")
	camera.zoomer(-1000.0)
	verifier_proche(camera.distance(), proche, 0.0001, "borne basse stable")
	verifier(depart >= proche and depart <= loin)


func test_la_camera_cadre_tout_le_cercle_d_apparition_au_zoom_maximum() -> void:
	var camera := _arene.get_node("Camera") as CameraArene
	camera.zoomer(1000.0)
	var rayon: float = RAYON_SPAWN * Apparence.ECHELLE
	# Zone visible d'une fenêtre 16/9 : on vérifie avec les angles de vue, sans viewport.
	var demi_v: float = deg_to_rad(camera.fov) * 0.5
	var demi_h: float = atan(tan(demi_v) * 16.0 / 9.0)
	for i: int in 64:
		var angle: float = TAU * float(i) / 64.0
		var point := Vector3(cos(angle) * rayon, 0.0, sin(angle) * rayon)
		var local: Vector3 = camera.transform.affine_inverse() * point
		verifier(local.z < 0.0, "point %d devant la caméra" % i)
		var vers_avant: float = -local.z
		verifier(
			absf(atan2(local.y, vers_avant)) <= demi_v, "point %d hors cadre verticalement" % i
		)
		verifier(
			absf(atan2(local.x, vers_avant)) <= demi_h, "point %d hors cadre horizontalement" % i
		)


func test_tout_noeud_cree_est_libere() -> void:
	var avant: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var arene := _instancier()
	var rafale: Array[Dictionary] = []
	for i: int in 500:
		rafale.append(_evenement("tir"))
	arene.afficher(_vue({0: 50, 1: 400}, rafale), 1.0)
	_liberer(arene)
	var apres: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	verifier_egal(apres, avant, "aucun nœud restant")
