extends CasDeTest
## La mini-carte et son câblage dans la partie : un clic y déplace la vue, les vignettes des autres
## joueurs montrent leur arène, Espace revient toujours à sa tour, et rien ne couvre la boutique ni
## la barre du haut. Les intentions envoyées à la source sont notées par `SourceFactice`.

const RESOLUTIONS: Array[Vector2] = [
	Vector2(1152.0, 648.0), Vector2(1280.0, 720.0), Vector2(1366.0, 768.0), Vector2(1920.0, 1080.0)
]
const GRAINE := 7
## Ids de pair ENet : de grands entiers aléatoires, jamais des index de 0 à 255.
const LOCAL := 665857105
const AUTRE := 1138291077
const NB_ENNEMIS := 1000
const ESPACE_VIDE := Vector2(-50.0, -50.0)

var _donnees: Donnees
var _source: SourceFactice
var _locale_avant: String = ""
var _echelle_avant: float = 1.0


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	_echelle_avant = arbre.root.content_scale_factor
	_donnees = AidesPartie.donnees()
	_source = null


func apres_chaque() -> void:
	TranslationServer.set_locale(_locale_avant)
	arbre.root.content_scale_factor = _echelle_avant
	for action: String in ["camera_droite", "camera_gauche", "camera_haut", "camera_bas"]:
		Input.action_release(action)


# --- Aides ---------------------------------------------------------------------------------


## Identifiant du `i`-ième joueur : le premier est la joueuse locale.
func _id(i: int) -> int:
	return LOCAL if i == 0 else AUTRE + i


func _globale(nombre: int, densites: bool = false) -> VueGlobale:
	var g := VueGlobale.new()
	for i: int in nombre:
		g.joueurs.append(
			{
				"id": _id(i),
				"nom": "Joueuse %d" % i if i == 0 else "Adversaire numéro %d" % i,
				"manche": 3,
				"eliminations": 0,
				"degats": 5.0,
				"revenu": 10,
				"vivant": true,
				"victorieux": false,
			}
		)
		if densites and i > 0:
			var carte := PackedByteArray()
			carte.resize(VueGlobale.DENSITE_OCTETS)
			carte[i] = 40
			g.densites[_id(i)] = carte
	return g


func _vue(argent: int = 0) -> VueArene:
	var v := VueArene.new()
	v.tour_pv = 80.0
	v.tour_pv_max = 100.0
	v.argent = argent
	return v


func _minicarte(nombre: int) -> Minicarte:
	var m := Minicarte.new()
	m.configurer(_donnees)
	m.afficher(_vue(), _globale(nombre), LOCAL, Rect2(-300.0, -200.0, 600.0, 400.0))
	return m


func _famille_du_palier(palier: int) -> int:
	for i: int in _donnees.familles.size():
		if int((_donnees.familles[i] as Dictionary)["indice_palier"]) == palier:
			return i
	return -1


func _jeu(nombre: int, zone: Vector2 = Vector2(1280.0, 720.0)) -> Jeu:
	var jeu := (load("res://scenes/jeu.tscn") as PackedScene).instantiate() as Jeu
	jeu.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	jeu.nom_joueur = "Mina"
	arbre.root.add_child(jeu)
	_source = SourceFactice.new()
	_source.regler(LOCAL, LOCAL)
	jeu.add_child(_source)
	verifier(jeu.demarrer_reseau(_donnees, _source))
	var racine := jeu.get_node("Interface/Racine") as Control
	racine.anchor_right = 0.0
	racine.anchor_bottom = 0.0
	racine.offset_right = zone.x
	racine.offset_bottom = zone.y
	var vue := _vue(250)
	for id: String in _donnees.armes:
		if vue.armes.size() < 2:
			vue.armes.append({"id": id, "recharge_ratio": 0.0})
		if vue.offres.size() < BoutiqueUi.NB_OFFRES:
			vue.offres.append(
				{"id": id, "genre": Types.Genre.ARME, "rarete": 0, "prix": 40, "vendu": false}
			)
	_source.emettre_arene(vue)
	_source.emettre_globale(_globale(nombre, true))
	jeu.placer_dans(zone)
	await attendre_images(2)
	return jeu


func _espace(jeu: Jeu) -> void:
	var evenement := InputEventAction.new()
	evenement.action = "camera_recentrer"
	evenement.pressed = true
	jeu.arene._unhandled_input(evenement)


func _centre(rect: Rect2) -> Vector2:
	return rect.get_center()


func _regardes(source: SourceFactice) -> Array[int]:
	var sortie: Array[int] = []
	for appel: Dictionary in source.appels:
		if appel["nom"] == "regarder":
			sortie.append(int((appel["args"] as Array)[0]))
	return sortie


# --- La carte ------------------------------------------------------------------------------


func test_un_clic_sur_la_carte_demande_le_centrage_au_bon_point_du_monde() -> void:
	for nombre: int in [1, 2, 5, 8]:
		var m := _minicarte(nombre)
		var carte := m.rect_carte()
		var demi := Minicarte.DEMI_MONDE
		var cas: Array[Array] = [
			[carte.position, Vector2(-demi, -demi)],
			[Vector2(carte.end.x, carte.position.y), Vector2(demi, -demi)],
			[Vector2(carte.position.x, carte.end.y), Vector2(-demi, demi)],
			[carte.end, Vector2(demi, demi)],
			[carte.get_center(), Vector2.ZERO],
		]
		for entree: Array in cas:
			var demandes: Array[Vector2] = []
			m.demande_centrage.connect(func(p: Vector2) -> void: demandes.append(p))
			var local: Vector2 = entree[0]
			var attendu: Vector2 = entree[1]
			m.cliquer(local)
			verifier_egal(demandes.size(), 1, "un clic, une demande (%d joueurs)" % nombre)
			if not demandes.is_empty():
				verifier_proche(demandes[0].x, attendu.x, 0.01, "x au clic %s" % local)
				verifier_proche(demandes[0].y, attendu.y, 0.01, "y au clic %s" % local)
			verifier_proche(m.case_vers_unites(local).x, attendu.x, 0.01)
			# L'aller-retour rend la position de départ.
			verifier_proche(m.unites_vers_case(attendu).x, local.x, 0.01)
			verifier_proche(m.unites_vers_case(attendu).y, local.y, 0.01)
		m.free()


func test_les_ennemis_ont_la_couleur_de_leur_palier() -> void:
	var m := Minicarte.new()
	m.configurer(_donnees)
	# Chaque famille du catalogue a la couleur de son palier ; le convoi et le boss ont la leur.
	for f: int in _donnees.familles.size():
		var palier := int((_donnees.familles[f] as Dictionary)["indice_palier"])
		verifier_egal(m.couleur_famille(f), Minicarte.COULEURS_CLASSES[palier], "famille %d" % f)
	verifier_egal(
		m.couleur_famille(_donnees.familles.size()), Minicarte.COULEURS_CLASSES[Minicarte.CLASSE_CONVOI]
	)
	verifier_egal(
		m.couleur_famille(_donnees.familles.size() + 1),
		Minicarte.COULEURS_CLASSES[Minicarte.CLASSE_BOSS]
	)
	# Mille ennemis, un quart par palier, chacun dans son quadrant : aucun point ne prend la couleur
	# d'un autre palier, et le nombre de points reste sous le budget d'affichage.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = GRAINE
	var vue := _vue()
	var paliers := Minicarte.COULEURS_CLASSES.size() - 2
	for i: int in NB_ENNEMIS:
		var palier := i % paliers
		var signe := Vector2(-1.0 if palier % 2 == 0 else 1.0, -1.0 if palier < 2 else 1.0)
		var p := signe * Vector2(hasard.randf_range(150.0, 1000.0), hasard.randf_range(150.0, 1000.0))
		vue.ennemis_id.append(i)
		vue.ennemis_pos.append(p)
		vue.ennemis_famille.append(_famille_du_palier(palier))
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	m.afficher(vue, _globale(1), LOCAL, Rect2())
	verifier(m.points_positions.size() > 0, "des points sont dessinés")
	verifier(
		m.points_positions.size() <= Minicarte.POINTS_MAX,
		"%d points pour %d ennemis" % [m.points_positions.size(), NB_ENNEMIS]
	)
	var vus: Array[int] = [0, 0, 0, 0]
	for i: int in m.points_positions.size():
		var local := m.points_positions[i] - m.rect_carte().get_center()
		var palier := (0 if local.y < 0.0 else 2) + (0 if local.x < 0.0 else 1)
		# Quadrant (x <0, y <0) = palier 0, (x >0, y <0) = palier 1, etc.
		verifier_egal(
			m.points_couleurs[i], Minicarte.COULEURS_CLASSES[palier], "point %d du quadrant" % i
		)
		vus[palier] += 1
	for palier: int in paliers:
		verifier(vus[palier] > 0, "le palier %d est dessiné" % palier)
	m.free()


func test_le_cadre_de_la_vue_suit_le_zoom_et_le_decalage() -> void:
	var camera := CameraArene.new()
	camera.cadrer(Rect2(0.0, 0.0, 600.0, 300.0), Vector2(600.0, 300.0))
	var m := Minicarte.new()
	m.configurer(_donnees)
	var echelle := Minicarte.COTE_CARTE / (2.0 * Minicarte.DEMI_MONDE)
	camera.niveau = 0.5
	camera.zoomer(0.0)
	m.afficher(_vue(), _globale(1), LOCAL, camera.cadre_visible())
	var large := m.cadre_local
	verifier(large.size.x > 0.0 and large.size.y > 0.0, "un cadre est dessiné")
	verifier_proche(large.size.x, camera.cadre_visible().size.x * echelle, 0.01, "largeur")
	verifier_proche(large.size.y, camera.cadre_visible().size.y * echelle, 0.01, "hauteur")
	# Deux fois plus près : le cadre est deux fois plus petit.
	camera.zoomer(-0.25)
	m.afficher(_vue(), _globale(1), LOCAL, camera.cadre_visible())
	var proche := m.cadre_local
	verifier_proche(proche.size.x * 2.0, large.size.x, 0.01, "moitié en largeur")
	verifier_proche(proche.size.y * 2.0, large.size.y, 0.01, "moitié en hauteur")
	# Le centre du cadre suit le décalage de la caméra.
	var decalage := Vector2(400.0, -300.0)
	camera.deplacer(decalage)
	m.afficher(_vue(), _globale(1), LOCAL, camera.cadre_visible())
	var centre := _centre(m.cadre_local) - _centre(m.rect_carte())
	verifier_proche(centre.x, decalage.x * echelle, 0.01, "décalage en x")
	verifier_proche(centre.y, decalage.y * echelle, 0.01, "décalage en y")
	# Un cadre invalide ne dessine rien.
	m.definir_cadre(Rect2(Vector2(NAN, 0.0), Vector2(10.0, 10.0)))
	verifier_egal(m.cadre_local, Rect2())
	m.free()
	camera.free()


# --- Les vignettes -------------------------------------------------------------------------


func test_une_vignette_par_autre_joueur_avec_son_nom_et_sa_barre_de_pv() -> void:
	verifier(Minicarte.TAILLE_TEXTE >= 16, "texte de 16 px au moins")
	for nombre: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		var m := Minicarte.new()
		m.configurer(_donnees)
		var globale := _globale(nombre, true)
		m.afficher(_vue(), globale, LOCAL, Rect2())
		verifier_egal(m.vignettes.size(), nombre - 1, "une vignette par autre joueur (%d)" % nombre)
		var vignettes: Array[Dictionary] = m.vignettes
		var zone := Rect2(Vector2.ZERO, m.taille_voulue())
		for i: int in vignettes.size():
			var v: Dictionary = vignettes[i]
			var joueur: Dictionary = globale.joueurs[i + 1]
			verifier_egal(v["id"], joueur["id"], "identifiant")
			verifier_egal(v["nom"], joueur["nom"], "nom")
			verifier_egal(float(v["pv"]), -1.0, "PV inconnus tant qu'on n'a pas vu l'arène")
			verifier_egal((v["densite"] as PackedByteArray).size(), 64, "densité réduite")
			var rect: Rect2 = v["rect"]
			verifier(zone.encloses(rect), "la vignette tient dans la mini-carte")
			verifier(not rect.intersects(m.rect_carte()), "la vignette ne couvre pas la carte")
			for j: int in vignettes.size():
				if j != i:
					verifier(not rect.intersects(vignettes[j]["rect"]), "vignettes disjointes")
			verifier_egal(m.joueur_sous(_centre(rect)), int(joueur["id"]), "clic au centre")
		# Les PV connus par la vue de l'arène regardée remplissent la barre ; bornés de 0 à 1.
		if nombre > 1:
			m.definir_pv(_id(1), 30.0, 100.0)
			verifier_proche(float(m.vignettes[0]["pv"]), 0.3)
			m.definir_pv(_id(1), 500.0, 100.0)
			verifier_proche(float(m.vignettes[0]["pv"]), 1.0)
			m.definir_pv(_id(1), 5.0, 0.0)
			verifier_proche(float(m.vignettes[0]["pv"]), 0.0)
		m.free()
	# En solo : aucune vignette, la mini-carte est la carte seule.
	var solo := _minicarte(1)
	verifier(solo.vignettes.is_empty(), "pas de vignette en solo")
	verifier_egal(solo.taille_voulue(), Vector2(Minicarte.COTE_CARTE, Minicarte.COTE_CARTE))
	verifier_egal(solo.joueur_sous(Vector2(5.0, 5.0)), -1)
	solo.free()


func test_une_densite_qui_n_a_pas_256_octets_n_est_pas_dessinee() -> void:
	var m := Minicarte.new()
	var globale := _globale(2)
	globale.densites[_id(1)] = PackedByteArray([1, 2, 3])
	m.afficher(_vue(), globale, LOCAL, Rect2())
	verifier((m.vignettes[0]["densite"] as PackedByteArray).is_empty())
	m.free()


# --- Dans la partie ------------------------------------------------------------------------


## Review Focus 5.
func test_un_clic_hors_de_la_carte_ou_non_fini_ne_deplace_pas_la_vue_et_espace_revient_toujours() -> void:
	var jeu := await _jeu(3)
	var m := jeu.minicarte
	var camera := jeu.camera
	var depart := Vector2(500.0, 300.0)
	var parti_rect: Rect2 = m.vignettes[1]["rect"]
	var cas: Array[Vector2] = [
		ESPACE_VIDE,
		Vector2(1.0e6, 1.0e6),
		Vector2(NAN, NAN),
		Vector2(INF, 0.0),
		Vector2(0.0, -INF),
		Vector2(m.rect_carte().end.x + 1.0, m.rect_carte().get_center().y),
		_centre(parti_rect),
	]
	for i: int in cas.size():
		camera.centrer_sur(depart)
		if i == cas.size() - 1:
			# Le joueur de cette vignette part : sa vignette disparaît avant le clic.
			_source.emettre_globale(_globale(2))
			verifier_egal(m.joueur_sous(cas[i]), -1, "plus de joueur sous la vignette partie")
			# Un clic déjà parti vers `Jeu` avec son identifiant n'a pas d'effet non plus.
			m.demande_regarder.emit(_id(2))
		m.cliquer(cas[i])
		verifier_egal(camera.decalage_unites, depart, "la vue n'a pas bougé (cas %d)" % i)
		verifier(_regardes(_source).is_empty(), "personne n'est regardé (cas %d)" % i)
		verifier(not jeu.arene.regarde_un_autre(), "arène propre (cas %d)" % i)
		_espace(jeu)
		verifier_egal(camera.decalage_unites, Vector2.ZERO, "Espace recentre (cas %d)" % i)
		verifier(not jeu.arene.regarde_un_autre(), "Espace garde la sienne (cas %d)" % i)
	# Un identifiant inconnu, ou le sien, n'ouvre aucune arène.
	m.demande_regarder.emit(123)
	m.demande_regarder.emit(LOCAL)
	verifier(_regardes(_source).is_empty(), "ni inconnu ni soi-même")
	# Le joueur regardé qui quitte la partie : retour à sa propre arène, sans erreur.
	m.demande_regarder.emit(_id(1))
	verifier(jeu.arene.regarde_un_autre(), "on regarde l'autre")
	_source.emettre_globale(_globale(1))
	verifier(not jeu.arene.regarde_un_autre(), "l'autre est parti : retour à sa tour")
	verifier_egal(_source.id_regarde(), -1, "la source cesse de le regarder")
	_espace(jeu)
	verifier_egal(camera.decalage_unites, Vector2.ZERO)


func test_un_clic_sur_une_vignette_regarde_cette_arene_et_espace_revient_a_la_sienne() -> void:
	var jeu := await _jeu(4)
	var m := jeu.minicarte
	for i: int in m.vignettes.size():
		var id: int = m.vignettes[i]["id"]
		jeu.camera.centrer_sur(Vector2(700.0, -200.0))
		m.cliquer(_centre(m.vignettes[i]["rect"]))
		verifier(jeu.arene.regarde_un_autre(), "l'arène de la vignette %d s'affiche" % i)
		verifier_egal(_source.id_regarde(), id, "la source regarde ce joueur")
		verifier_egal(_regardes(_source).back(), id)
		verifier_egal(jeu.camera.decalage_unites, Vector2.ZERO, "la vue se recentre sur cette tour")
		_espace(jeu)
		verifier(not jeu.arene.regarde_un_autre(), "Espace revient à la sienne")
		verifier_egal(_source.id_regarde(), -1)
		verifier_egal(_regardes(_source).back(), -1, "la source cesse de l'envoyer")
		verifier_egal(jeu.camera.decalage_unites, Vector2.ZERO)


func test_la_minicarte_ne_couvre_ni_la_boutique_ni_la_barre_du_haut_aux_trois_resolutions_et_aux_cinq_echelles() -> void:
	for echelle: float in Reglages.ECHELLES:
		for resolution: Vector2 in RESOLUTIONS:
			var zone := resolution / echelle
			var jeu := await _jeu(8, zone)
			var ou := "à %s, échelle %s" % [resolution, echelle]
			for replie: bool in [false, true]:
				jeu.boutique.definir_replie(replie)
				await attendre_images(2)
				var rect := jeu.minicarte.get_global_rect()
				var etat := "%s, repliée : %s" % [ou, replie]
				verifier(jeu.minicarte.visible, "mini-carte visible %s" % etat)
				verifier(Rect2(Vector2.ZERO, zone).encloses(rect), "dans la fenêtre %s" % etat)
				verifier(not rect.intersects(jeu.hud.rect_barre()), "barre du haut libre %s" % etat)
				verifier(
					not rect.intersects(jeu.boutique.rect_bandeau()), "bandeau libre %s" % etat
				)
				for panneau: PanelContainer in jeu.boutique.panneaux():
					verifier(
						not rect.intersects(panneau.get_global_rect()),
						"panneau %s libre %s" % [panneau.name, etat]
					)
			jeu.get_parent().remove_child(jeu)
			jeu.free()


func test_le_hud_et_la_boutique_restent_ceux_du_joueur_pendant_qu_il_regarde() -> void:
	var jeu := await _jeu(3)
	var propre := _vue(123)
	_source.emettre_arene(propre)
	var or_propre: String = jeu.hud.valeur(Hud.LIGNE_OR)
	verifier_egal(or_propre, Nombres.groupe(123))
	jeu.minicarte.cliquer(_centre(jeu.minicarte.vignettes[0]["rect"]))
	verifier(jeu.arene.regarde_un_autre())
	# L'arène de l'autre arrive : ni le HUD ni la boutique ne la prennent.
	var autre := _vue(999)
	autre.tour_pv = 20.0
	_source.emettre_vue_regardee(_id(1), autre)
	verifier_egal(jeu.hud.valeur(Hud.LIGNE_OR), or_propre, "le HUD garde son or")
	verifier(jeu.boutique.visible, "la boutique reste affichée")
	verifier_proche(float(jeu.minicarte.vignettes[0]["pv"]), 0.2, 0.001, "PV de l'autre")
	# La sienne continue d'arriver : le HUD la suit, jamais l'autre.
	_source.emettre_arene(_vue(456))
	verifier_egal(jeu.hud.valeur(Hud.LIGNE_OR), Nombres.groupe(456))
	verifier(jeu.arene.regarde_un_autre(), "toujours sur l'arène de l'autre")


func test_la_taille_de_l_interface_et_la_vitesse_de_camera_des_reglages_sont_appliquees() -> void:
	var r := Reglages.new()
	r.echelle_ui = 1.25
	r.vitesse_camera = 2.0
	verifier(r.sauver(dossier_temporaire().path_join("reglages.cfg")))
	var jeu := (load("res://scenes/jeu.tscn") as PackedScene).instantiate() as Jeu
	jeu.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	jeu.nom_joueur = "Mina"
	arbre.root.add_child(jeu)
	verifier(jeu.demarrer_solo(_donnees, GRAINE, 0.5))
	verifier_proche(jeu.get_window().content_scale_factor, 1.25, 0.001, "taille de l'interface")
	verifier_proche(jeu.camera.vitesse_relative, 2.0, 0.001, "vitesse de caméra")
	# La caméra avance deux fois plus vite : une seconde de flèche droite fait 2 × la vitesse de base.
	Input.action_press("camera_droite")
	jeu.camera.avancer(0.1)
	Input.action_release("camera_droite")
	verifier_proche(jeu.camera.decalage_unites.x, CameraArene.VITESSE_BASE * 2.0 * 0.1, 0.5)
	# Une partie relancée garde le réglage.
	jeu.demarrer_solo(_donnees, GRAINE + 1, 0.5)
	verifier_proche(jeu.camera.vitesse_relative, 2.0, 0.001, "vitesse après rejouer")
