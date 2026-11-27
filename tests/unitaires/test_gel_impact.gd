extends CasDeTest
## Le gel d'impact (D21) : un coup fort tient un instant son effet sur son pic et retient les
## ennemis touchés, puis tout reprend sans bond. Purement visuel : `Engine.time_scale` ne bouge pas
## et rien ne gèle hors des effets et des ennemis touchés. L'écran ne tremble jamais.

const IMAGE: float = 1.0 / 60.0
const UNITE: float = Apparence.PX_PAR_UNITE
const IMPACT := Vector2(500, 0)
const ARRIVEE := Vector2(300, -200)

var _reactions: ReactionsCoups = null
var _effets: Effets = null


func avant_chaque() -> void:
	_reactions = ReactionsCoups.new()
	_effets = Effets.new()
	arbre.root.add_child(_effets)


func apres_chaque() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(_effets):
		if _effets.get_parent() != null:
			_effets.get_parent().remove_child(_effets)
		_effets.free()
	_effets = null


func _evenement(type_degats: int, rayon: float, genre: String = "") -> Dictionary:
	var e := {
		"k": "impact",
		"t": 1,
		"de": Vector2.ZERO,
		"vers": ARRIVEE,
		"type_degats": type_degats,
		"rayon": rayon
	}
	if genre != "":
		e["genre"] = genre
	return e


func _avancer_effets(n: int) -> void:
	for i: int in n:
		_effets.avancer(IMAGE)


## Deux ennemis : l'ennemi 1 est au point d'impact, l'ennemi 2 loin de la zone.
func _ids() -> PackedInt32Array:
	return PackedInt32Array([1, 2])


func _positions() -> PackedVector2Array:
	return PackedVector2Array([IMPACT, Vector2(900, 0)])


## Position courante (interpolée) d'un ennemi à l'image `f` : il glisse de 20 px à l'image 1 puis
## reste là.
func _courante(f: int) -> Vector2:
	return Apparence.vers_pixels(IMPACT) + (Vector2(20.0, 0.0) if f >= 1 else Vector2.ZERO)


## Position affichée de l'ennemi 1 sans son recul : seule la tenue du gel nous intéresse ici.
func _sans_recul(courante: Vector2) -> Vector2:
	return _reactions.position_affichee(1, courante) - _reactions.recul(1)


func _toucher_zone() -> void:
	_reactions.toucher(IMPACT, 100.0, _ids(), _positions(), Vector2.ZERO, true)


# --- Les ennemis touchés ---------------------------------------------------------------------


func test_la_duree_du_gel_est_de_cinq_images() -> void:
	verifier_proche(GelImpact.DUREE_GEL, 5.0 / 60.0, 0.0001, "5 images à 60 i/s")


func test_un_ennemi_touche_par_une_zone_garde_position_et_image_pendant_le_gel() -> void:
	_toucher_zone()
	var tenue: Vector2 = _sans_recul(_courante(0))
	for f: int in 5:
		verifier_egal(_sans_recul(_courante(f)), tenue, "image %d : position tenue" % f)
		verifier_egal(_reactions.image_animation(1, 100 + f), 100, "image %d : image tenue" % f)
		_reactions.avancer(IMAGE)
	verifier(_sans_recul(_courante(5)).distance_to(tenue) > 0.5, "après le gel il repart")
	verifier_egal(_reactions.image_animation(1, 105), 105, "l'animation reprend")


func test_les_autres_ennemis_ne_gelent_pas() -> void:
	_toucher_zone()
	for f: int in 5:
		var vive := Vector2(10.0 * f, 3.0)
		verifier_egal(_reactions.position_affichee(2, vive), vive, "l'ennemi lointain bouge")
		verifier_egal(_reactions.image_animation(2, 7 + f), 7 + f, "son animation continue")
		_reactions.avancer(IMAGE)


func test_un_coup_simple_ne_gele_pas_l_ennemi() -> void:
	_reactions.toucher(IMPACT, 0.0, _ids(), _positions())
	for f: int in 5:
		verifier_egal(_sans_recul(_courante(f)).x, _courante(f).x, "image %d : pas de gel" % f)
		_reactions.avancer(IMAGE)


func test_la_reprise_prend_trois_images_sans_bond_de_plus_d_un_tiers() -> void:
	_toucher_zone()
	_sans_recul(_courante(0))
	for f: int in 5:
		_reactions.avancer(IMAGE)
	var cible: Vector2 = _courante(5)
	var tenue: Vector2 = Apparence.vers_pixels(IMPACT)
	var ecart: float = cible.distance_to(tenue)
	var avant: Vector2 = tenue
	for f: int in range(5, 8):
		var affichee: Vector2 = _sans_recul(_courante(f))
		verifier(
			affichee.distance_to(avant) <= ecart / 3.0 + 0.001,
			"image %d : bond %f pour un écart de %f" % [f, affichee.distance_to(avant), ecart]
		)
		verifier(affichee.distance_to(avant) > 0.1, "image %d : il avance" % f)
		avant = affichee
		_reactions.avancer(IMAGE)
	verifier_proche(avant.x, cible.x, 0.01, "arrivé en trois images")
	verifier_egal(_sans_recul(_courante(8)).x, cible.x, "puis calé")


func test_au_plus_douze_ennemis_gelent() -> void:
	var ids := PackedInt32Array()
	var pos := PackedVector2Array()
	for i: int in 20:
		ids.append(i + 1)
		pos.append(IMPACT + Vector2(i, 0))
	_reactions.toucher(IMPACT, 100.0, ids, pos, Vector2.ZERO, true)
	var geles: int = 0
	for i: int in 20:
		var tenue: Vector2 = _reactions.position_affichee(i + 1, Vector2(1, 1))
		if _reactions.position_affichee(i + 1, Vector2(50, 50)) == tenue:
			geles += 1
	verifier_egal(geles, ReactionsCoups.MAX_ZONE, "douze gelés, pas un de plus")


func test_deux_gels_rapproches_ne_prolongent_pas_le_gel() -> void:
	_toucher_zone()
	_sans_recul(_courante(0))
	for f: int in 3:
		_reactions.avancer(IMAGE)
	_toucher_zone()
	for f: int in range(3, 5):
		_reactions.avancer(IMAGE)
	# 5 images après le premier coup : le gel est fini, malgré le second coup.
	verifier(
		_sans_recul(_courante(5)).x > Apparence.vers_pixels(IMPACT).x + 0.5,
		"le second coup n'ajoute rien"
	)
	for f: int in 10:
		_reactions.avancer(IMAGE)
	_toucher_zone()
	_reactions.avancer(IMAGE)
	verifier_egal(
		_sans_recul(_courante(20)).x,
		_courante(20).x,
		"après le flash, un nouveau coup ne regèle pas dans la foulée d'un autre"
	)


func test_le_recul_et_le_flash_attendent_la_fin_du_gel() -> void:
	_toucher_zone()
	for f: int in 4:
		_reactions.avancer(IMAGE)
		verifier_egal(_reactions.recul(1), Vector2.ZERO, "image %d : le recul attend" % f)
		verifier_egal(_reactions.eclat(1), ReactionsCoups.FACTEUR_FLASH, "le flash est tenu")
	for f: int in 12:
		_reactions.avancer(IMAGE)
	verifier(_reactions.nombre_suivis() <= 1, "tout finit par s'éteindre")


func test_une_aura_ou_une_onde_ne_gele_jamais_ses_ennemis() -> void:
	# Une aura pulse en continu : un gel à chaque pulsation ferait saccader ses ennemis.
	for genre: String in ["aura", "onde"]:
		var effets_forts: Array[bool] = []
		_effets.impact_visible.connect(
			func(_ou: Vector2, _rayon: float, fort: bool) -> void: effets_forts.append(fort)
		)
		for pulsation: int in 6:
			var evenement: Dictionary = _evenement(Types.TypeDegats.MAGIQUE, 100.0, genre)
			evenement["vers"] = Vector2.ZERO
			_effets.ajouter(evenement)
			_avancer_effets(int(0.5 / IMAGE))
		verifier_egal(effets_forts.size(), 6, "%s : six pulsations" % genre)
		verifier(not effets_forts.has(true), "%s : jamais un coup fort" % genre)
		for fort: bool in effets_forts:
			_reactions = ReactionsCoups.new()
			_reactions.toucher(IMPACT, 100.0, _ids(), _positions(), Vector2.ZERO, fort)
			for f: int in 5:
				var vive := Vector2(10.0 * f, 0.0)
				verifier_egal(
					_sans_recul(vive), vive, "%s : l'ennemi bouge dès l'image %d" % [genre, f]
				)
				_reactions.avancer(IMAGE)


func test_le_signal_dit_quels_coups_sont_forts() -> void:
	var forts: Array[bool] = []
	_effets.impact_visible.connect(
		func(_ou: Vector2, _rayon: float, fort: bool) -> void: forts.append(fort)
	)
	var cas: Array = [
		[Types.TypeDegats.MAGIQUE, 120.0, "zone", true],
		[Types.TypeDegats.SIEGE, 0.0, "", true],
		[Types.TypeDegats.TRANCHANT, 100.0, "mine", true],
		[Types.TypeDegats.MAGIQUE, 100.0, "aura", false],
		[Types.TypeDegats.TRANCHANT, 100.0, "mine", true],
		[Types.TypeDegats.MAGIQUE, 100.0, "onde", false],
		[Types.TypeDegats.TRANCHANT, 0.0, "", false],
		[Types.TypeDegats.CHAOS, 0.0, "", false],
	]
	for c: Array in cas:
		forts.clear()
		_effets.vider()
		_effets.ajouter(_evenement(int(c[0]), float(c[1]), String(c[2])))
		verifier_egal(forts.size(), 1, "%s : un impact" % c[2])
		if forts.size() == 1:
			verifier_egal(forts[0], bool(c[3]), "type %d genre « %s »" % [c[0], c[2]])


func test_un_siege_sans_rayon_gele_sa_cible_la_plus_proche_et_elle_seule() -> void:
	var ids := PackedInt32Array([1, 2])
	var pos := PackedVector2Array([IMPACT, IMPACT + Vector2(5, 0)])
	_reactions.toucher(IMPACT, 0.0, ids, pos, Vector2.ZERO, true)
	var tenue: Vector2 = _sans_recul(_courante(0))
	for f: int in 5:
		verifier_egal(_sans_recul(_courante(f)), tenue, "image %d : la cible est retenue" % f)
		verifier_egal(
			_reactions.position_affichee(2, Vector2(10.0 * f, 0.0)),
			Vector2(10.0 * f, 0.0),
			"image %d : sa voisine non" % f
		)
		_reactions.avancer(IMAGE)


# --- L'effet d'impact ------------------------------------------------------------------------


func test_un_impact_de_zone_fige_son_effet_sur_son_pic_puis_reprend() -> void:
	_effets.ajouter(_evenement(Types.TypeDegats.MAGIQUE, 120.0, "zone"))
	var pic: float = Effets.TAILLE_IMPACT / 32.0 * CourbesEffets.ECHELLE_PIC_IMPACT
	verifier(_effets.gel_restant() > 0.0, "un gel est en cours")
	var clarte_pic: float = 0.0
	for f: int in 5:
		verifier_proche(_effets.echelle_de("halo"), pic, 0.001, "image %d : taille du pic" % f)
		var c: Color = _effets.couleur_de("halo")
		if f == 0:
			clarte_pic = c.r + c.g + c.b
		verifier_proche(c.r + c.g + c.b, clarte_pic, 0.001, "image %d : clarté tenue" % f)
		_effets.avancer(IMAGE)
	verifier_egal(_effets.gel_restant(), 0.0, "le gel est fini")
	_avancer_effets(3)
	verifier(_effets.echelle_de("halo") < pic - 0.01, "après le gel l'effet reprend")
	_avancer_effets(40)
	verifier_egal(_effets.nombre_vivants(), 0, "et se dissipe")


func test_le_pic_tenu_porte_le_blanc_et_la_taille_maximale() -> void:
	_effets.ajouter(_evenement(Types.TypeDegats.MAGIQUE, 120.0, "zone"))
	var c: Color = _effets.couleur_de("halo")
	var arme: Color = Effets.COULEURS[Types.TypeDegats.MAGIQUE]
	verifier(c.r + c.g + c.b > arme.r + arme.g + arme.b + 0.2, "le blanc du pic est tenu")


func test_un_impact_simple_ne_gele_rien() -> void:
	for type_degats: int in [
		Types.TypeDegats.TRANCHANT, Types.TypeDegats.PERCANT, Types.TypeDegats.MAGIQUE
	]:
		_effets.vider()
		_effets.ajouter(_evenement(type_degats, 0.0))
		verifier_egal(_effets.gel_restant(), 0.0, "type %d : aucun gel" % type_degats)
		var forme: String = Effets.IMPACTS[type_degats]
		var avant: float = _effets.echelle_de(forme)
		_effets.avancer(IMAGE)
		verifier(_effets.echelle_de(forme) != avant, "type %d : l'effet avance" % type_degats)


func test_une_explosion_de_mort_et_le_siege_gelent_leur_effet() -> void:
	_effets.exploser(Vector2(100, 100))
	verifier(_effets.gel_restant() > 0.0, "l'explosion de mort gèle")
	_effets.vider()
	_effets.ajouter(_evenement(Types.TypeDegats.SIEGE, 0.0))
	verifier(_effets.gel_restant() > 0.0, "le siège gèle")
	_effets.vider()
	_effets.exploser(Vector2(100, 100))
	var images: int = 0
	while _effets.nombre_vivants() > 0 and images < 100:
		_effets.avancer(IMAGE)
		images += 1
	var attendu: float = Effets.DUREE_EXPLOSION - Effets.age_pic_explosion() + GelImpact.DUREE_GEL
	verifier_proche(images * IMAGE, attendu, 1.5 * IMAGE, "l'explosion tient son pic DUREE_GEL")


func test_l_effet_gele_ne_retient_pas_les_autres_effets() -> void:
	_effets.ajouter(_evenement(Types.TypeDegats.MAGIQUE, 120.0, "zone"))
	_effets.ajouter(_evenement(Types.TypeDegats.TRANCHANT, 0.0))
	var avant: float = _effets.echelle_de("entaille")
	_effets.avancer(IMAGE)
	verifier(_effets.echelle_de("entaille") != avant, "l'impact simple avance pendant le gel")
	verifier(_effets.gel_restant() > 0.0, "le gel dure encore")


func test_le_gel_ne_touche_ni_au_temps_du_moteur_ni_a_la_simulation() -> void:
	_effets.ajouter(_evenement(Types.TypeDegats.SIEGE, 120.0, "zone"))
	_toucher_zone()
	_avancer_effets(10)
	verifier_egal(Engine.time_scale, 1.0, "Engine.time_scale reste à 1")


func test_aucune_secousse_d_ecran_n_existe() -> void:
	for dossier: String in ["res://visuels", "res://app"]:
		var d: DirAccess = DirAccess.open(dossier)
		verifier_non_nul(d, dossier)
		for fichier: String in d.get_files():
			if not fichier.ends_with(".gd"):
				continue
			var texte: String = (
				FileAccess.get_file_as_string("%s/%s" % [dossier, fichier]).to_lower()
			)
			for mot: String in ["shake", "secousse", "trauma"]:
				verifier_faux(
					texte.contains(mot), "%s/%s : aucune secousse (%s)" % [dossier, fichier, mot]
				)
