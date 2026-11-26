extends CasDeTest
## Le mouvement réduit (D21) : ni gel d'impact, ni recul, ni rebond d'échelle, ni étincelles ; un
## éclat bref à l'impact et le flash de la cible restent, les projectiles volent toujours. Le
## réglage est faux par défaut et peut changer en cours de partie.

const TYPES: Array[int] = [
	Types.TypeDegats.TRANCHANT,
	Types.TypeDegats.PERCANT,
	Types.TypeDegats.MAGIQUE,
	Types.TypeDegats.SIEGE,
	Types.TypeDegats.CHAOS,
]
const IMAGE: float = 1.0 / 60.0
const ARRIVEE := Vector2(300, -200)
## Formes d'impact et d'anneau dont la taille ne doit plus bouger une fois apparues.
const FORMES_FIXES: Array[String] = ["halo", "entaille", "pointes", "etoile", "anneau", "explosion"]
const FORMES_STATUT: Array[String] = ["flocon", "bulles", "croix_plus"]

var _effets: Effets = null


func avant_chaque() -> void:
	_effets = Effets.new()
	arbre.root.add_child(_effets)


func apres_chaque() -> void:
	if is_instance_valid(_effets):
		if _effets.get_parent() != null:
			_effets.get_parent().remove_child(_effets)
		_effets.free()
	_effets = null


func _evenement(k: String, type_degats: int, rayon: float, genre: int = 0) -> Dictionary:
	return {
		"k": k,
		"t": 1,
		"de": Vector2.ZERO,
		"vers": ARRIVEE,
		"type_degats": type_degats,
		"rayon": rayon,
		"genre": genre
	}


## Joue un coup (tir puis impact) et rend, par forme, les échelles vues à chaque image.
func _jouer(evenement_impact: Dictionary, formes: Array[String], images: int) -> Dictionary:
	_effets.vider()
	var tir: Dictionary = evenement_impact.duplicate()
	tir["k"] = "tir"
	_effets.ajouter(tir)
	_effets.ajouter(evenement_impact)
	var echelles: Dictionary = {}
	for forme: String in formes:
		echelles[forme] = [] as Array[float]
	for i: int in images:
		verifier_egal(_effets.gel_restant(), 0.0, "image %d : aucun gel" % i)
		verifier_egal(_effets.etincelles_actives().size(), 0, "image %d : aucune étincelle" % i)
		for forme: String in formes:
			var e: float = _effets.echelle_de(forme)
			if e > 0.0:
				(echelles[forme] as Array[float]).append(e)
		_effets.avancer(IMAGE)
	return echelles


func _amplitude(valeurs: Array[float]) -> float:
	return (valeurs.max() - valeurs.min()) if not valeurs.is_empty() else 0.0


func test_le_mouvement_reduit_est_faux_par_defaut() -> void:
	verifier_faux(_effets.mouvement_reduit, "Effets")
	verifier_faux(ReactionsCoups.new().mouvement_reduit, "ReactionsCoups")
	var arene: Arene2D = (load("res://scenes/arene_2d.tscn") as PackedScene).instantiate()
	verifier_faux(arene.mouvement_reduit, "Arene2D")
	arene.free()


func test_sans_mouvement_reduit_les_effets_rebondissent_et_lancent_des_etincelles() -> void:
	var echelles: Dictionary = {}
	_effets.vider()
	_effets.ajouter(_evenement("impact", Types.TypeDegats.MAGIQUE, 0.0))
	var valeurs: Array[float] = []
	for i: int in 18:
		valeurs.append(_effets.echelle_de("halo"))
		_effets.avancer(IMAGE)
	verifier(_amplitude(valeurs) > 0.5, "contrôle : en mode normal la taille varie")
	_effets.vider()
	_effets.ajouter(_evenement("impact", Types.TypeDegats.MAGIQUE, 0.0))
	verifier_egal(_effets.etincelles_actives().size(), 1, "contrôle : des étincelles")
	verifier_egal(echelles.size(), 0)


func test_en_boucle_aucun_gel_aucune_etincelle_et_une_taille_constante() -> void:
	_effets.mouvement_reduit = true
	for type_degats: int in TYPES:
		for genre: int in VueArene.GENRES_ARME.size():
			for rayon: float in [0.0, 120.0]:
				var message := "type %d, genre %d, rayon %d" % [type_degats, genre, int(rayon)]
				var evenement: Dictionary = _evenement("impact", type_degats, rayon, genre)
				var echelles: Dictionary = _jouer(evenement, FORMES_FIXES, 40)
				for forme: String in FORMES_FIXES:
					var valeurs: Array[float] = echelles[forme]
					verifier_proche(
						_amplitude(valeurs),
						0.0,
						0.0001,
						"%s : %s garde sa taille" % [message, forme]
					)
				verifier_egal(_effets.emetteurs_etincelles().size(), 0, "%s : rien émis" % message)


func test_chaque_statut_apparait_directement_a_sa_taille() -> void:
	_effets.mouvement_reduit = true
	for statut: int in range(1, VueArene.STATUTS_ARME.size()):
		var evenement: Dictionary = _evenement("impact", Types.TypeDegats.MAGIQUE, 0.0)
		evenement["statut"] = statut
		var echelles: Dictionary = _jouer(evenement, FORMES_STATUT, 25)
		for forme: String in FORMES_STATUT:
			verifier_proche(
				_amplitude(echelles[forme]), 0.0, 0.0001, "statut %d : %s" % [statut, forme]
			)


func test_l_anneau_apparait_a_sa_portee_exacte() -> void:
	_effets.mouvement_reduit = true
	for genre: String in ["onde", "aura"]:
		_effets.vider()
		var rayon: float = 150.0
		var evenement := _evenement("impact", Types.TypeDegats.MAGIQUE, rayon)
		evenement["genre"] = genre
		evenement["vers"] = Vector2.ZERO
		_effets.ajouter(evenement)
		var portee: float = rayon * Apparence.PX_PAR_UNITE * 2.0 / 64.0
		verifier_proche(_effets.echelle_de("anneau"), portee, 0.001, "%s : à la portée" % genre)
		_effets.avancer(Effets.DUREE_ANNEAU * 0.5)
		verifier_proche(_effets.echelle_de("anneau"), portee, 0.001, "%s : elle la garde" % genre)
		_effets.avancer(Effets.DUREE_ANNEAU)
		verifier_egal(_effets.nombre_vivants(), 0, "%s : puis s'efface" % genre)


func test_les_explosions_et_le_siege_ne_gelent_pas() -> void:
	_effets.mouvement_reduit = true
	_effets.exploser(Vector2(100, 100))
	verifier_egal(_effets.gel_restant(), 0.0, "explosion de mort")
	var images: int = 0
	while _effets.nombre_vivants() > 0 and images < 100:
		_effets.avancer(IMAGE)
		images += 1
	verifier_proche(images * IMAGE, Effets.DUREE_EXPLOSION, 1.5 * IMAGE, "durée d'origine")


func test_il_reste_un_eclat_bref_a_l_impact_sans_changement_de_taille() -> void:
	_effets.mouvement_reduit = true
	for type_degats: int in [
		Types.TypeDegats.TRANCHANT,
		Types.TypeDegats.PERCANT,
		Types.TypeDegats.MAGIQUE,
		Types.TypeDegats.CHAOS
	]:
		_effets.vider()
		_effets.ajouter(_evenement("impact", type_degats, 0.0))
		var forme: String = Effets.IMPACTS[type_degats]
		var clartes: Array[float] = []
		for i: int in 6:
			var c: Color = _effets.couleur_de(forme)
			clartes.append(c.r + c.g + c.b)
			_effets.avancer(IMAGE)
		var message := "type %d" % type_degats
		verifier(clartes[0] > clartes[3] + 0.05, "%s : l'éclat est là à l'image 0" % message)
		verifier_proche(clartes[1], clartes[0], 0.001, "%s : il dure deux images" % message)
		verifier_proche(clartes[2], clartes[3], 0.001, "%s : puis couleur de l'arme" % message)
		var arme: Color = Effets.COULEURS[type_degats]
		verifier_proche(clartes[3], arme.r + arme.g + arme.b, 0.02, "%s : couleur" % message)


func test_les_projectiles_volent_toujours() -> void:
	_effets.mouvement_reduit = true
	for type_degats: int in TYPES:
		_effets.vider()
		_effets.ajouter(_evenement("tir", type_degats, 0.0))
		var forme: String = Effets.PROJECTILES[type_degats]
		var depart: Vector2 = _effets.trajet_de(forme)[0]
		var arrivee: Vector2 = _effets.trajet_de(forme)[1]
		verifier(depart != arrivee, "type %d : un trajet" % type_degats)
		_effets.avancer(Effets.DUREE_TIR * 0.5)
		verifier(_effets.nombre_vivants() >= 1, "type %d : en vol" % type_degats)


func test_la_bascule_en_cours_de_partie_n_affecte_que_les_effets_suivants() -> void:
	_effets.ajouter(_evenement("impact", Types.TypeDegats.MAGIQUE, 0.0))
	_effets.avancer(IMAGE)
	var avant: float = _effets.echelle_de("halo")
	_effets.mouvement_reduit = true
	_effets.avancer(IMAGE)
	verifier(_effets.echelle_de("halo") != avant, "l'effet déjà né continue son rebond")
	_effets.ajouter(_evenement("impact", Types.TypeDegats.TRANCHANT, 0.0))
	var neuf: float = _effets.echelle_de("entaille")
	_effets.avancer(3 * IMAGE)
	verifier_proche(_effets.echelle_de("entaille"), neuf, 0.0001, "le suivant est réduit")
	_effets.mouvement_reduit = false
	_effets.ajouter(_evenement("impact", Types.TypeDegats.PERCANT, 0.0))
	var normal: float = _effets.echelle_de("pointes")
	_effets.avancer(3 * IMAGE)
	verifier(_effets.echelle_de("pointes") != normal, "et le retour au normal aussi")
	_effets.avancer(1.0)
	verifier_egal(_effets.nombre_vivants(), 0, "tout finit proprement")


# --- La cible touchée -------------------------------------------------------------------------


func _toucher(reactions: ReactionsCoups, rayon: float) -> void:
	var ids := PackedInt32Array([1, 2])
	var pos := PackedVector2Array([Vector2(500, 0), Vector2(520, 0)])
	reactions.toucher(Vector2(500, 0), rayon, ids, pos)


func test_la_cible_ne_recule_ni_ne_gele_mais_son_flash_reste() -> void:
	for rayon: float in [0.0, 100.0]:
		var reactions := ReactionsCoups.new()
		reactions.mouvement_reduit = true
		_toucher(reactions, rayon)
		var courant := Vector2(300, 0)
		for i: int in 3:
			verifier_egal(
				reactions.eclat(1), ReactionsCoups.FACTEUR_FLASH, "rayon %d : flash" % int(rayon)
			)
			verifier_egal(reactions.recul(1), Vector2.ZERO, "pas de recul")
			courant.x += 10.0
			verifier_egal(reactions.position_affichee(1, courant), courant, "pas de gel")
			verifier_egal(reactions.image_animation(1, 40 + i), 40 + i, "animation libre")
			reactions.avancer(IMAGE)
		verifier_egal(reactions.eclat(1), 1.0, "le flash dure trois images")


func test_le_flash_reste_limite_a_un_toutes_les_034_s_en_mouvement_reduit() -> void:
	var reactions := ReactionsCoups.new()
	reactions.mouvement_reduit = true
	var departs: Array[float] = []
	var allume: bool = false
	var temps: float = 0.0
	for i: int in 240:
		_toucher(reactions, 100.0)
		var maintenant: bool = reactions.eclat(1) > 1.0
		if maintenant and not allume:
			departs.append(temps)
		allume = maintenant
		reactions.avancer(IMAGE)
		temps += IMAGE
	verifier(departs.size() >= 8, "il clignote : %d flashs" % departs.size())
	for i: int in range(1, departs.size()):
		verifier(
			departs[i] - departs[i - 1] >= 0.33 - 0.0001, "écart %f" % (departs[i] - departs[i - 1])
		)


func test_changer_le_reglage_en_cours_de_partie_ne_casse_rien() -> void:
	var reactions := ReactionsCoups.new()
	_toucher(reactions, 100.0)
	reactions.mouvement_reduit = true
	for i: int in 10:
		reactions.avancer(IMAGE)
		reactions.position_affichee(1, Vector2(10, 10))
	reactions.mouvement_reduit = false
	_toucher(reactions, 100.0)
	reactions.avancer(1.0)
	verifier_egal(reactions.nombre_suivis(), 0, "tout s'éteint")
