extends CasDeTest
## Ce que le joueur doit voir d'un ennemi touché : il s'éclaircit un instant et recule d'un
## cheveu, puis revient. Jamais plus de trois flashs par seconde pour un même ennemi (WCAG 2.3.1),
## et l'état suit l'identifiant de l'ennemi, pas sa place dans la vue.

const IMAGE: float = 1.0 / 60.0
## Unités de jeu : 1 px d'écran vaut 1 / PX_PAR_UNITE unités.
const PX: float = 1.0 / Apparence.PX_PAR_UNITE

var _reactions: ReactionsCoups = null


func avant_chaque() -> void:
	_reactions = ReactionsCoups.new()


func _ids(n: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for i: int in n:
		ids.append(i + 1)
	return ids


func _positions(liste: Array) -> PackedVector2Array:
	var positions := PackedVector2Array()
	for p: Vector2 in liste:
		positions.append(p)
	return positions


func _images(n: int) -> void:
	for i: int in n:
		_reactions.avancer(IMAGE)


func test_le_plus_proche_dans_le_rayon_de_touche_clignote_et_pas_les_autres() -> void:
	var ids := PackedInt32Array([10, 20, 30])
	var pos := _positions([Vector2(500, 0), Vector2(505, 0) + Vector2(0, 20 * PX), Vector2(900, 0)])
	var n: int = _reactions.toucher(Vector2(500, 0), 0.0, ids, pos)
	verifier_egal(n, 1, "un seul ennemi pour un coup simple")
	verifier_egal(_reactions.eclat(10), ReactionsCoups.FACTEUR_FLASH, "le plus proche s'éclaircit")
	verifier_egal(_reactions.eclat(20), 1.0, "le voisin proche ne réagit pas")
	verifier_egal(_reactions.eclat(30), 1.0, "l'ennemi lointain non plus")


func test_aucun_ennemi_hors_du_rayon_de_touche_ne_reagit() -> void:
	verifier_proche(ReactionsCoups.RAYON_TOUCHE_PX, 40.0, 0.0001)
	var ids := PackedInt32Array([1])
	var dehors := _positions([Vector2(41.0 * PX, 0)])
	verifier_egal(_reactions.toucher(Vector2.ZERO, 0.0, ids, dehors), 0, "à 41 px")
	verifier_egal(_reactions.eclat(1), 1.0)
	var dedans := _positions([Vector2(39.0 * PX, 0)])
	verifier_egal(_reactions.toucher(Vector2.ZERO, 0.0, ids, dedans), 1, "à 39 px")


func test_le_flash_dure_trois_images_puis_s_eteint() -> void:
	var ids := PackedInt32Array([1])
	_reactions.toucher(Vector2.ZERO, 0.0, ids, _positions([Vector2.ZERO]))
	for i: int in 3:
		verifier_egal(_reactions.eclat(1), ReactionsCoups.FACTEUR_FLASH, "image %d allumée" % i)
		_images(1)
	verifier_egal(_reactions.eclat(1), 1.0, "éteint après 3 images")


func test_jamais_deux_flashs_a_moins_de_un_tiers_de_seconde_pour_le_meme_ennemi() -> void:
	var ids := PackedInt32Array([7])
	var pos := _positions([Vector2(100, 0)])
	var departs: Array[float] = []
	var allume: bool = false
	var temps: float = 0.0
	for i: int in 240:
		_reactions.toucher(Vector2(100, 0), 0.0, ids, pos)
		var maintenant: bool = _reactions.eclat(7) > 1.0
		if maintenant and not allume:
			departs.append(temps)
		allume = maintenant
		_reactions.avancer(IMAGE)
		temps += IMAGE
	verifier(departs.size() >= 10, "il clignote bien : %d flashs en 4 s" % departs.size())
	for i: int in range(1, departs.size()):
		verifier(
			departs[i] - departs[i - 1] >= 0.33 - 0.0001, "écart %f" % (departs[i] - departs[i - 1])
		)
	# Aucune seconde ne contient plus de trois départs.
	for i: int in departs.size():
		var dans_la_seconde: int = 0
		for d: float in departs:
			if d >= departs[i] and d < departs[i] + 1.0:
				dans_la_seconde += 1
		verifier(
			dans_la_seconde <= 3, "%d flashs dans la seconde de %f" % [dans_la_seconde, departs[i]]
		)


func test_le_recul_est_de_quatre_pixels_a_l_oppose_de_la_tour_puis_revient_a_zero() -> void:
	var ids := PackedInt32Array([1])
	var pos := _positions([Vector2(600, 0)])
	_reactions.toucher(Vector2(600, 0), 0.0, ids, pos)
	verifier_egal(_reactions.recul(1), Vector2.ZERO, "rien au premier instant")
	_images(1)
	var a_une_image: Vector2 = _reactions.recul(1)
	verifier(a_une_image.x > ReactionsCoups.RECUL_PX * 0.5, "sortie amortie : %s" % a_une_image)
	verifier(a_une_image.x < ReactionsCoups.RECUL_PX, "pas encore au bout")
	_images(1)
	verifier_proche(_reactions.recul(1).length(), 4.0, 0.001, "4 px à 2 images")
	verifier(
		_reactions.recul(1).x > 0.0 and absf(_reactions.recul(1).y) < 0.001, "à l'opposé de la tour"
	)
	var dernier: float = _reactions.recul(1).length()
	for i: int in 6:
		_images(1)
		var longueur: float = _reactions.recul(1).length()
		verifier(longueur < dernier, "il revient (image %d)" % i)
		dernier = longueur
	verifier_egal(_reactions.recul(1), Vector2.ZERO, "de retour à zéro après 8 images")


func test_le_recul_s_eloigne_de_la_tour_dans_toutes_les_directions() -> void:
	for angle: int in 12:
		_reactions = ReactionsCoups.new()
		var sens := Vector2.from_angle(TAU * angle / 12.0)
		var ids := PackedInt32Array([1])
		var p: Vector2 = sens * 500.0
		_reactions.toucher(p, 0.0, ids, _positions([p]))
		_images(2)
		var recul: Vector2 = _reactions.recul(1)
		verifier(recul.dot(sens) > 3.99, "direction %d : %s" % [angle, recul])


func test_l_etat_suit_l_identifiant_quand_l_ordre_des_ennemis_change() -> void:
	var pos := _positions([Vector2(100, 0), Vector2(200, 0), Vector2(300, 0)])
	_reactions.toucher(Vector2(200, 0), 0.0, PackedInt32Array([1, 2, 3]), pos)
	verifier_egal(_reactions.eclat(2), ReactionsCoups.FACTEUR_FLASH)
	# L'ordre change : l'ennemi 2 est maintenant en première place.
	var autre := _positions([Vector2(200, 0), Vector2(300, 0), Vector2(100, 0)])
	var ids2 := PackedInt32Array([2, 3, 1])
	verifier_egal(_reactions.eclat(2), ReactionsCoups.FACTEUR_FLASH, "toujours l'ennemi 2")
	verifier_egal(_reactions.eclat(1), 1.0)
	verifier_egal(
		_reactions.toucher(Vector2(200, 0), 0.0, ids2, autre), 0, "encore dans l'intervalle"
	)
	_images(30)
	verifier_egal(
		_reactions.toucher(Vector2(200, 0), 0.0, ids2, autre), 1, "puis il réagit de nouveau"
	)
	verifier_egal(_reactions.eclat(2), ReactionsCoups.FACTEUR_FLASH)


func test_une_zone_fait_reagir_ceux_du_rayon_et_au_plus_douze() -> void:
	verifier_egal(ReactionsCoups.MAX_ZONE, 12)
	var ids := PackedInt32Array()
	var liste: Array = []
	for i: int in 30:
		ids.append(100 + i)
		liste.append(Vector2(300 + i * 4, 0))
	liste.append(Vector2(5000, 0))
	ids.append(999)
	var n: int = _reactions.toucher(Vector2(300, 0), 200.0, ids, _positions(liste))
	verifier_egal(n, 12, "plafonnée à 12")
	var allumes: int = 0
	for i: int in 30:
		if _reactions.eclat(100 + i) > 1.0:
			allumes += 1
			verifier(i < 12, "les plus proches d'abord (ennemi %d)" % i)
	verifier_egal(allumes, 12)
	verifier_egal(_reactions.eclat(999), 1.0, "hors du rayon : rien")


func test_une_zone_ne_prend_que_ceux_de_son_rayon() -> void:
	var ids := PackedInt32Array([1, 2])
	var pos := _positions([Vector2(150, 0), Vector2(260, 0)])
	var n: int = _reactions.toucher(Vector2(100, 0), 100.0, ids, pos)
	verifier_egal(n, 1)
	verifier_egal(_reactions.eclat(1), ReactionsCoups.FACTEUR_FLASH)
	verifier_egal(_reactions.eclat(2), 1.0)


func test_un_ennemi_inconnu_ou_apres_reinitialisation_est_au_repos() -> void:
	verifier_egal(_reactions.eclat(42), 1.0)
	verifier_egal(_reactions.recul(42), Vector2.ZERO)
	_reactions.toucher(Vector2.ZERO, 0.0, PackedInt32Array([1]), _positions([Vector2.ZERO]))
	_reactions.reinitialiser()
	verifier_egal(_reactions.eclat(1), 1.0)
	verifier_egal(_reactions.nombre_suivis(), 0)


func test_l_etat_se_purge_une_fois_l_intervalle_ecoule() -> void:
	var ids := _ids(50)
	var liste: Array = []
	for i: int in 50:
		liste.append(Vector2(i, 0))
	for tour: int in 20:
		_reactions.toucher(Vector2(25, 0), 200.0, ids, _positions(liste))
		_images(30)
	verifier_egal(_reactions.nombre_suivis(), 0, "rien ne reste suivi")
