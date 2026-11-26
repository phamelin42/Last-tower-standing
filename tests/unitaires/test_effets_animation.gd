extends CasDeTest
## Ce que le joueur doit voir d'un coup : le projectile arrive avant l'impact, l'impact a un pic
## puis se dissipe, l'anneau montre la vraie zone et la tient, le rebond se propage de saut en saut,
## des étincelles partent de chaque impact visible, et rien de tout cela ne dépasse son plafond.

const TYPES: Array[int] = [
	Types.TypeDegats.TRANCHANT,
	Types.TypeDegats.PERCANT,
	Types.TypeDegats.MAGIQUE,
	Types.TypeDegats.SIEGE,
	Types.TypeDegats.CHAOS,
]
const IMAGE: float = 1.0 / 60.0
const ARRIVEE := Vector2(300, -200)

var _effets: Effets = null
## Chaque impact devenu visible : `[image, point, rayon]`, l'image étant celle de `_image`.
var _visibles: Array = []
var _image: int = 0


func avant_chaque() -> void:
	_effets = Effets.new()
	arbre.root.add_child(_effets)
	_visibles = []
	_image = 0
	_effets.impact_visible.connect(_noter_impact)


func apres_chaque() -> void:
	if is_instance_valid(_effets):
		if _effets.get_parent() != null:
			_effets.get_parent().remove_child(_effets)
		_effets.free()
	_effets = null


func _noter_impact(ou: Vector2, rayon: float) -> void:
	_visibles.append([_image, ou, rayon])


func _evenement(
	k: String, type_degats: int, de: Vector2, vers: Vector2, rayon: float, genre: String = ""
) -> Dictionary:
	var e := {"k": k, "t": 1, "de": de, "vers": vers, "type_degats": type_degats, "rayon": rayon}
	if genre != "":
		e["genre"] = genre
	return e


func _images(n: int) -> void:
	for i: int in n:
		_image += 1
		_effets.avancer(IMAGE)


# --- L'impact attend le projectile ---------------------------------------------------------------


func test_un_impact_lie_a_un_tir_attend_l_arrivee_du_projectile() -> void:
	for type_degats: int in TYPES:
		_effets.vider()
		_visibles = []
		_effets.ajouter(_evenement("tir", type_degats, Vector2.ZERO, ARRIVEE, 0.0, "cible_unique"))
		_effets.ajouter(
			_evenement("impact", type_degats, Vector2.ZERO, ARRIVEE, 0.0, "cible_unique")
		)
		var forme: String = Effets.IMPACTS[type_degats]
		verifier_faux(
			_effets.formes_vivantes().has(forme), "type %d : pas d'impact au tir" % type_degats
		)
		verifier_egal(_effets.impacts_en_attente(), 1, "type %d : l'impact attend" % type_degats)
		verifier_egal(_visibles.size(), 0, "type %d : rien de signalé encore" % type_degats)
		_effets.avancer(Effets.DUREE_TIR - IMAGE * 0.5)
		verifier_faux(
			_effets.formes_vivantes().has(forme), "type %d : le projectile vole" % type_degats
		)
		_effets.avancer(IMAGE)
		verifier(_effets.formes_vivantes().has(forme), "type %d : l'impact est là" % type_degats)
		verifier_egal(_effets.impacts_en_attente(), 0)
		verifier_egal(_visibles.size(), 1, "type %d : signalé une fois" % type_degats)


func test_un_impact_sans_tir_est_visible_tout_de_suite() -> void:
	for type_degats: int in TYPES:
		for genre: String in ["cible_unique", "zone", "aura", "onde", ""]:
			_effets.vider()
			_visibles = []
			var rayon: float = 0.0 if genre == "cible_unique" or genre == "" else 120.0
			var vers: Vector2 = Vector2.ZERO if genre == "aura" or genre == "onde" else ARRIVEE
			_effets.ajouter(_evenement("impact", type_degats, Vector2.ZERO, vers, rayon, genre))
			var message := "%d/%s" % [type_degats, genre]
			verifier_egal(_effets.impacts_en_attente(), 0, message)
			verifier(_effets.nombre_vivants() > 0, "%s : visible tout de suite" % message)
			verifier_egal(_visibles.size(), 1, "%s : signalé" % message)


func test_un_tir_d_ailleurs_ne_retient_pas_un_impact() -> void:
	_effets.ajouter(_evenement("tir", 0, Vector2.ZERO, ARRIVEE, 0.0, "cible_unique"))
	_effets.ajouter(_evenement("impact", 0, Vector2.ZERO, Vector2(-500, 40), 0.0, "cible_unique"))
	verifier_egal(_effets.impacts_en_attente(), 0)
	_effets.vider()
	# Même point mais autre type de dégâts : un autre tir.
	_effets.ajouter(_evenement("tir", 0, Vector2.ZERO, ARRIVEE, 0.0, "cible_unique"))
	_effets.ajouter(_evenement("impact", 2, Vector2.ZERO, ARRIVEE, 0.0, "cible_unique"))
	verifier_egal(_effets.impacts_en_attente(), 0)


func test_un_tir_ne_retient_qu_un_seul_impact() -> void:
	_effets.ajouter(_evenement("tir", 0, Vector2.ZERO, ARRIVEE, 0.0, "cible_unique"))
	_effets.ajouter(_evenement("impact", 0, Vector2.ZERO, ARRIVEE, 0.0, "cible_unique"))
	_effets.ajouter(_evenement("impact", 0, Vector2.ZERO, ARRIVEE, 0.0, "cible_unique"))
	verifier_egal(_effets.impacts_en_attente(), 1)
	verifier_egal(_visibles.size(), 1, "le second impact, sans tir, part tout de suite")


func test_le_projectile_vole_sept_images_et_apparait_en_grossissant() -> void:
	verifier_proche(Effets.DUREE_TIR, 7.0 * IMAGE, 0.0001, "sept images à 60 i/s")
	_effets.ajouter(_evenement("tir", Types.TypeDegats.PERCANT, Vector2.ZERO, ARRIVEE, 0.0))
	var plein: float = Effets.ECHELLE_FLECHE
	verifier_proche(_effets.taille_du_premier(), plein * 0.5, 0.001, "départ à la moitié")
	_images(1)
	var a_une_image: float = _effets.taille_du_premier()
	verifier(a_une_image > plein * 0.5 and a_une_image < plein, "grossit : %f" % a_une_image)
	# Sortie amortie : plus de la moitié du chemin est faite à mi-parcours de l'apparition.
	verifier(a_une_image > plein * 0.75, "sortie amortie : %f" % a_une_image)
	_images(1)
	verifier_proche(_effets.taille_du_premier(), plein, 0.001, "pleine taille à 2 images")


# --- Pic puis dissipation -----------------------------------------------------------------------


func test_l_impact_a_son_pic_dans_le_premier_quart_puis_se_dissipe() -> void:
	verifier_proche(Effets.DUREE_IMPACT, 0.30, 0.0001, "0,30 s")
	for type_degats: int in TYPES:
		if type_degats == Types.TypeDegats.SIEGE:
			continue  # Le siège joue l'explosion du pack, pas la forme dessinée.
		_effets.vider()
		var forme: String = Effets.IMPACTS[type_degats]
		_effets.ajouter(_evenement("impact", type_degats, Vector2.ZERO, ARRIVEE, 0.0))
		var echelles: Array[float] = []
		var clartes: Array[float] = []
		var alphas: Array[float] = []
		for i: int in 18:
			var c: Color = _effets.couleur_de(forme)
			echelles.append(_effets.echelle_de(forme))
			clartes.append(c.r + c.g + c.b)
			alphas.append(c.a)
			_effets.avancer(IMAGE)
		var message := "type %d" % type_degats
		verifier(
			echelles.find(echelles.max()) <= 4,
			"%s : pic de taille à l'image %d" % [message, echelles.find(echelles.max())]
		)
		verifier(
			clartes.find(clartes.max()) <= 4,
			"%s : pic de clarté à l'image %d" % [message, clartes.find(clartes.max())]
		)
		verifier_proche(echelles[3] / echelles[0], 1.2 / 0.5, 0.02, "%s : 0,5 vers 1,2" % message)
		verifier_proche(echelles[6] / echelles[3], 1.0 / 1.2, 0.02, "%s : retour à 1,0" % message)
		verifier(echelles[17] > echelles[6], "%s : grossit encore en se dissipant" % message)
		verifier(
			clartes[0] > clartes[3] + 0.05,
			"%s : blanc à l'image 0, couleur de l'arme à 3" % message
		)
		var arme: Color = Effets.COULEURS[type_degats]
		verifier_proche(
			clartes[3], arme.r + arme.g + arme.b, 0.02, "%s : couleur de l'arme" % message
		)
		for a: float in alphas:
			verifier(a <= Effets.ALPHA_MAX + 0.0001, "%s : jamais au-dessus d'ALPHA_MAX" % message)
		verifier_proche(
			alphas[5], Effets.ALPHA_MAX, 0.0001, "%s : opaque jusqu'à l'image 6" % message
		)
		verifier(alphas[12] < alphas[8] and alphas[8] < alphas[6], "%s : s'éteint" % message)
		# Entrée amortie (t²) : à mi-dissipation il reste plus de la moitié de l'opacité.
		verifier(alphas[12] > Effets.ALPHA_MAX * 0.5, "%s : entrée amortie" % message)
		verifier_egal(_effets.nombre_vivants(), 0, "%s : plus rien après 18 images" % message)


func test_l_impact_est_presque_transparent_juste_avant_sa_fin() -> void:
	_effets.ajouter(_evenement("impact", Types.TypeDegats.MAGIQUE, Vector2.ZERO, ARRIVEE, 0.0))
	_effets.avancer(Effets.DUREE_IMPACT - 0.0001)
	verifier(_effets.couleur_de("halo").a < 0.01, "alpha nul à la fin")
	_effets.avancer(0.001)
	verifier_egal(_effets.nombre_vivants(), 0)


# --- Anneau à la vraie portée -------------------------------------------------------------------


func test_l_anneau_atteint_exactement_sa_portee_et_la_garde_jusqu_a_60_pour_cent() -> void:
	var duree: float = Effets.DUREE_ANNEAU
	for genre: String in ["onde", "aura"]:
		_effets.vider()
		var rayon: float = 300.0
		_effets.ajouter(_evenement("impact", 0, Vector2.ZERO, Vector2.ZERO, rayon, genre))
		# Diamètre dessiné = rayon × PX_PAR_UNITE × 2, texture de 64 px.
		var voulu: float = rayon * Apparence.PX_PAR_UNITE * 2.0 / 64.0
		var depart: float = _effets.echelle_de("anneau")
		verifier(depart < voulu * 0.2, "%s : part de petit" % genre)
		_effets.avancer(duree * 0.15)
		var mi_expansion: float = _effets.echelle_de("anneau")
		verifier(mi_expansion > voulu * 0.5, "%s : expansion amortie (%f)" % [genre, mi_expansion])
		verifier(mi_expansion < voulu, "%s : pas encore à pleine taille" % genre)
		_effets.avancer(duree * 0.15)
		verifier_proche(
			_effets.echelle_de("anneau"), voulu, 0.0001, "%s : portée exacte à 30 %%" % genre
		)
		for fraction: float in [0.1, 0.149]:
			_effets.avancer(duree * fraction)
			verifier_proche(_effets.echelle_de("anneau"), voulu, 0.0001, "%s : tenu" % genre)
			verifier_proche(
				_effets.couleur_de("anneau").a, Effets.ALPHA_MAX, 0.0001, "%s : opaque" % genre
			)
		_effets.avancer(duree * 0.3)
		var fondu: float = _effets.couleur_de("anneau").a
		verifier(fondu < Effets.ALPHA_MAX, "%s : fond après 60 %%" % genre)
		verifier_proche(_effets.echelle_de("anneau"), voulu, 0.0001, "%s : taille gardée" % genre)


# --- Le rebond se propage -----------------------------------------------------------------------


func test_les_sauts_d_un_rebond_demarrent_trois_images_apres_le_precedent() -> void:
	var v1 := Vector2(300, 0)
	var v2 := Vector2(400, 60)
	var v3 := Vector2(520, -40)
	var type_degats: int = Types.TypeDegats.TRANCHANT
	_effets.ajouter(_evenement("tir", type_degats, Vector2.ZERO, v1, 0.0, "rebond"))
	_effets.ajouter(_evenement("impact", type_degats, Vector2.ZERO, v1, 0.0, "rebond"))
	_effets.ajouter(_evenement("impact", type_degats, v1, v2, 0.0, "rebond"))
	_effets.ajouter(_evenement("impact", type_degats, v2, v3, 0.0, "rebond"))
	verifier_egal(_effets.impacts_en_attente(), 3, "les trois sauts attendent")
	_images(20)
	verifier_egal(_visibles.size(), 3, "trois sauts")
	var images: Array[int] = []
	var points: Array[Vector2] = []
	for v: Array in _visibles:
		images.append(v[0])
		points.append(v[1])
	verifier_egal(points, [v1, v2, v3] as Array[Vector2], "dans l'ordre de la chaîne")
	verifier_egal(images, [7, 10, 13] as Array[int], "à l'arrivée du projectile, puis +3 images")


func test_le_trait_d_un_saut_s_allume_blanc_puis_prend_la_couleur_et_s_eteint() -> void:
	var v1 := Vector2(300, 0)
	var v2 := Vector2(400, 60)
	var type_degats: int = Types.TypeDegats.TRANCHANT
	_effets.ajouter(_evenement("impact", type_degats, v1, v2, 0.0, "rebond"))
	var allume: Color = _effets.couleur_de("trait")
	verifier(allume.r > 0.99 and allume.g > 0.99 and allume.b > 0.99, "blanc : %s" % allume)
	_images(2)
	var arme: Color = Effets.COULEURS[type_degats]
	var teinte: Color = _effets.couleur_de("trait")
	verifier_proche(teinte.r, arme.r, 0.001, "couleur de l'arme")
	verifier_proche(teinte.b, arme.b, 0.001, "couleur de l'arme")
	_images(6)
	verifier(_effets.couleur_de("trait").a < teinte.a, "s'éteint")
	_images(12)
	verifier_egal(_effets.nombre_vivants(), 0)


func test_des_sauts_de_lots_differents_ne_forment_pas_une_chaine() -> void:
	var v1 := Vector2(300, 0)
	var v2 := Vector2(400, 60)
	_effets.ajouter(_evenement("impact", 0, Vector2.ZERO, v1, 0.0, "rebond"))
	_images(1)
	_effets.ajouter(_evenement("impact", 0, v1, v2, 0.0, "rebond"))
	verifier_egal(_effets.impacts_en_attente(), 0, "sans tir ni chaîne en cours : tout de suite")


# --- Étincelles ---------------------------------------------------------------------------------


func test_un_coup_simple_lance_quatre_etincelles_et_une_zone_huit() -> void:
	for type_degats: int in TYPES:
		_effets.vider()
		_effets.ajouter(_evenement("impact", type_degats, Vector2.ZERO, ARRIVEE, 0.0))
		var actifs: Array[CPUParticles2D] = _effets.etincelles_actives()
		verifier_egal(actifs.size(), 1, "type %d : une salve" % type_degats)
		if actifs.size() == 1:
			# Le siège joue l'explosion du pack : une explosion vaut une zone.
			var attendu: int = 8 if type_degats == Types.TypeDegats.SIEGE else 4
			verifier_egal(actifs[0].amount, attendu, "type %d : coup simple" % type_degats)
			verifier(actifs[0].one_shot, "salve unique")
			verifier(actifs[0].use_fixed_seed, "graine fixe")
			verifier_egal(actifs[0].texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "nettes")
			verifier_proche(actifs[0].lifetime, 0.25, 0.0001, "vie de 0,25 s")
		_effets.vider()
		_effets.ajouter(_evenement("impact", type_degats, Vector2.ZERO, ARRIVEE, 120.0, "zone"))
		actifs = _effets.etincelles_actives()
		verifier_egal(actifs.size(), 1, "type %d : une salve de zone" % type_degats)
		if actifs.size() == 1:
			verifier_egal(actifs[0].amount, 8, "type %d : 8 pour une zone" % type_degats)


func test_les_etincelles_sont_des_carres_de_6_px_a_la_couleur_de_l_arme_eclaircie() -> void:
	verifier_egal(Etincelles.COTE, 6)
	verifier_proche(Etincelles.ECLAIRCISSEMENT, 0.3, 0.0001)
	for type_degats: int in TYPES:
		_effets.vider()
		_effets.ajouter(_evenement("impact", type_degats, Vector2.ZERO, ARRIVEE, 0.0))
		var salve: CPUParticles2D = _effets.etincelles_actives()[0]
		var voulue: Color = Effets.COULEURS[type_degats].lerp(Color.WHITE, 0.3)
		verifier_proche(salve.color.r, voulue.r, 0.001, "rouge du type %d" % type_degats)
		verifier_proche(salve.color.g, voulue.g, 0.001, "vert du type %d" % type_degats)
		verifier_proche(salve.color.b, voulue.b, 0.001, "bleu du type %d" % type_degats)
		verifier(salve.color.a <= Effets.ALPHA_MAX + 0.0001, "pas plus opaque qu'un effet")
		verifier_egal(salve.position, Apparence.vers_pixels(ARRIVEE), "part de l'impact")
		verifier_egal(salve.texture.get_width(), 6, "texture de 6 px")
		verifier_proche(salve.scale_amount_min, 1.0, 0.0001, "pas de réduction : 6 px")


func test_les_etincelles_partent_quand_l_impact_devient_visible() -> void:
	_effets.ajouter(_evenement("tir", 0, Vector2.ZERO, ARRIVEE, 0.0, "cible_unique"))
	_effets.ajouter(_evenement("impact", 0, Vector2.ZERO, ARRIVEE, 0.0, "cible_unique"))
	verifier_egal(_effets.etincelles_actives().size(), 0, "rien pendant le vol")
	_effets.avancer(Effets.DUREE_TIR + IMAGE)
	verifier_egal(_effets.etincelles_actives().size(), 1, "une salve à l'arrivée")


func test_les_etincelles_ont_un_pool_plafonne_et_ne_creent_jamais_de_noeud_en_plus() -> void:
	verifier_egal(Etincelles.PLAFOND, 32)
	for tour: int in 3:
		for i: int in 500:
			_effets.ajouter(_evenement("impact", i % 5, Vector2.ZERO, Vector2(i * 3, i), 0.0))
		verifier_egal(_effets.emetteurs_etincelles().size(), Etincelles.PLAFOND)
		verifier_egal(_effets.etincelles_actives().size(), Etincelles.PLAFOND)
		var particules: int = 0
		for enfant: Node in _effets.get_children():
			if enfant is CPUParticles2D:
				particules += 1
		verifier_egal(particules, Etincelles.PLAFOND, "aucun émetteur de plus (tour %d)" % tour)
		_effets.avancer(0.5)
		verifier_egal(_effets.etincelles_actives().size(), 0, "tout est retombé (tour %d)" % tour)


func test_les_etincelles_se_rejouent_a_l_identique() -> void:
	var autre := Effets.new()
	arbre.root.add_child(autre)
	for i: int in 6:
		var e := _evenement("impact", i % 5, Vector2.ZERO, Vector2(i * 40, i * 7), 0.0)
		_effets.ajouter(e)
		autre.ajouter(e)
	var a: Array[CPUParticles2D] = _effets.emetteurs_etincelles()
	var b: Array[CPUParticles2D] = autre.emetteurs_etincelles()
	verifier_egal(a.size(), b.size())
	for i: int in mini(a.size(), b.size()):
		verifier_egal(a[i].seed, b[i].seed, "même graine, émetteur %d" % i)
	autre.get_parent().remove_child(autre)
	autre.free()


# --- Statuts ------------------------------------------------------------------------------------


func test_un_statut_apparait_avec_un_petit_pic() -> void:
	verifier_proche(CourbesEffets.echelle_apparition_statut(0.0), 0.5, 0.001, "départ")
	verifier_proche(
		CourbesEffets.echelle_apparition_statut(2.0 * IMAGE), 1.1, 0.001, "pic à 2 images"
	)
	verifier_proche(
		CourbesEffets.echelle_apparition_statut(3.0 * IMAGE), 1.0, 0.001, "retour à 3 images"
	)
	verifier_proche(CourbesEffets.echelle_apparition_statut(1.0), 1.0, 0.001, "ensuite rien")
	var croissant: bool = true
	var dernier: float = 0.0
	for i: int in 3:
		var v: float = CourbesEffets.echelle_apparition_statut(i * IMAGE)
		croissant = croissant and v >= dernier
		dernier = v
	verifier(croissant, "monte jusqu'au pic")


func test_chaque_statut_a_forme_apparait_plus_petit_qu_il_ne_finit() -> void:
	for statut: String in ["givre", "poison", "etourdissement"]:
		_effets.vider()
		var e := _evenement("impact", Types.TypeDegats.MAGIQUE, Vector2.ZERO, ARRIVEE, 0.0)
		e["statut"] = statut
		_effets.ajouter(e)
		var forme: String = Effets.FORMES_STATUT[statut]
		var au_depart: float = _effets.echelle_de(forme)
		_images(2)
		verifier(_effets.echelle_de(forme) > au_depart, "%s : grandit dès l'apparition" % statut)
