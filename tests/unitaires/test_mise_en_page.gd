extends CasDeTest
## La mise en page d'une partie, mesurée en mode sans interface à plusieurs résolutions : HUD en
## haut, boutique en bas, l'arène visible entre les deux et la tour au centre de cet espace ;
## panneaux opaques ; écran de fin qui masque la boutique ; observation seulement s'il reste un
## autre joueur en vie.

const RESOLUTIONS: Array[Vector2] = [
	Vector2(1152.0, 648.0), Vector2(1280.0, 720.0), Vector2(1366.0, 768.0), Vector2(1920.0, 1080.0)
]
const GRAINE := 2024
const PAS := 1.0
const PAS_MAX := 4000
const OR_ABONDANT := 1000000
## Part minimale de la hauteur qui reste à l'arène entre la barre et le bandeau.
const PART_ARENE_MIN := 0.4
const OPACITE_MIN := 0.9
## Crans extrêmes de « Taille de l'interface » (T8.17) : la fenêtre logique mesure la résolution
## divisée par l'échelle, comme avec `content_scale_factor`.
## Surface (px²) du bandeau et du côté de la boutique avant T8.17, mesurée sur `main` (c4f37ef) à
## la création du test, aux résolutions de `RESOLUTIONS`, même partie solo, avant tout achat.
const SURFACE_AVANT: Array[float] = [328080.0, 427280.0, 454456.0, 585360.0]
const ECHELLES_EXTREMES: Array[float] = [0.75, 1.25]

var _donnees: Donnees
var _locale_avant: String = ""


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	_donnees = AidesPartie.donnees({"economie.json": [[["or_depart"], OR_ABONDANT]]})


func apres_chaque() -> void:
	TranslationServer.set_locale(_locale_avant)


# --- Aides ---------------------------------------------------------------------------------


func _jeu_a(zone: Vector2) -> Jeu:
	var jeu := (load("res://scenes/jeu.tscn") as PackedScene).instantiate() as Jeu
	jeu.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	jeu.nom_joueur = "Mina"
	arbre.root.add_child(jeu)
	verifier(jeu.demarrer_solo(_donnees, GRAINE, 0.5))
	var racine := jeu.get_node("Interface/Racine") as Control
	racine.anchor_right = 0.0
	racine.anchor_bottom = 0.0
	racine.offset_right = zone.x
	racine.offset_bottom = zone.y
	jeu.source._process(PAS)
	await attendre_images(2)
	jeu.placer_dans(zone)
	await attendre_images(2)
	return jeu


func _liberer(noeud: Node) -> void:
	if is_instance_valid(noeud):
		noeud.get_parent().remove_child(noeud)
		noeud.free()


func _jusqua_la_defaite(jeu: Jeu) -> void:
	for _i: int in PAS_MAX:
		if jeu.fin.visible:
			return
		jeu.source._process(PAS)
	verifier(jeu.fin.visible, "défaite atteinte")


func _fond_opaque(panneau: Control, nom: String) -> void:
	var style := panneau.get_theme_stylebox("panel")
	var alpha := -1.0
	if style is StyleBoxFlat:
		alpha = (style as StyleBoxFlat).bg_color.a
	elif style is StyleBoxTexture:
		# Un panneau du pack est opaque si le centre de sa texture l'est, teinte comprise.
		alpha = ThemeJeu.fond_moyen(style as StyleBoxTexture).a
	verifier(alpha >= 0.0, "%s : un fond uni ou une texture" % nom)
	verifier(alpha >= OPACITE_MIN, "%s : fond opaque (alpha %.2f)" % [nom, alpha])


func _vue_globale(autres_en_vie: int) -> VueGlobale:
	var g := VueGlobale.new()
	g.joueurs = [
		{
			"id": SourceLocale.ID_LOCAL,
			"nom": "Mina",
			"manche": 3,
			"eliminations": 1,
			"degats": 10.0,
			"revenu": 20,
			"vivant": false,
			"victorieux": false
		}
	]
	for i: int in 7:
		g.joueurs.append(
			{
				"id": 100 + i,
				"nom": "Adversaire numéro %d" % i,
				"manche": 3,
				"eliminations": 0,
				"degats": 5.0,
				"revenu": 10,
				"vivant": i < autres_en_vie,
				"victorieux": false
			}
		)
	return g


# --- Calcul pur ----------------------------------------------------------------------------


func test_le_calcul_place_le_hud_en_haut_la_boutique_en_bas_et_l_arene_entre_les_deux() -> void:
	for zone: Vector2 in RESOLUTIONS:
		var r := MiseEnPage.calculer(zone, 60.0, 250.0)
		var hud: Rect2 = r["hud"]
		var boutique: Rect2 = r["boutique"]
		var libre: Rect2 = r["libre"]
		verifier_faux(hud.intersects(boutique), "HUD et boutique ne se chevauchent pas à %s" % zone)
		verifier_faux(libre.intersects(hud), "l'arène libre ne touche pas le HUD")
		verifier_faux(libre.intersects(boutique), "l'arène libre ne touche pas la boutique")
		verifier_proche(hud.position.y, 0.0, 0.001, "HUD collé en haut")
		verifier_proche(boutique.end.y, zone.y, 0.001, "boutique collée en bas")
		verifier_proche(
			libre.size.y + hud.size.y + boutique.size.y, zone.y, 0.01, "tout est couvert"
		)


func test_une_boutique_trop_haute_est_bornee_et_ne_masque_jamais_le_hud() -> void:
	for zone: Vector2 in RESOLUTIONS:
		var r := MiseEnPage.calculer(zone, 60.0, 5000.0)
		var hud: Rect2 = r["hud"]
		var boutique: Rect2 = r["boutique"]
		var libre: Rect2 = r["libre"]
		verifier_faux(hud.intersects(boutique), "bornée à %s" % zone)
		verifier(libre.size.y > 0.0, "il reste de l'arène visible à %s" % zone)


func test_un_panneau_modal_se_centre_et_reste_dans_la_fenetre() -> void:
	for zone: Vector2 in RESOLUTIONS:
		var petit := MiseEnPage.centrer(zone, Vector2(300.0, 200.0))
		verifier_proche(petit.get_center().x, zone.x * 0.5, 0.01, "centré en x")
		verifier_proche(petit.get_center().y, zone.y * 0.5, 0.01, "centré en y")
		var grand := MiseEnPage.centrer(zone, zone * 3.0)
		verifier(Rect2(Vector2.ZERO, zone).encloses(grand), "un panneau trop grand est borné")


# --- La partie, à chaque résolution ----------------------------------------------------------


func test_le_hud_est_une_barre_visible_au_dessus_de_la_boutique() -> void:
	for zone: Vector2 in RESOLUTIONS:
		var jeu := await _jeu_a(zone)
		var ecran := Rect2(Vector2.ZERO, zone)
		var barre := jeu.hud.rect_barre()
		var bandeau := jeu.boutique.rect_bandeau()
		verifier(jeu.hud.is_visible_in_tree(), "le HUD est visible à %s" % zone)
		verifier(barre.size.x >= zone.x - 1.0, "la barre prend toute la largeur à %s" % zone)
		verifier(barre.size.y >= 32.0, "la barre est lisible (≥ 32 px) à %s" % zone)
		verifier(barre.size.y <= 44.0, "la barre fait au plus 44 px à %s" % zone)
		verifier(ecran.encloses(barre), "la barre est dans la fenêtre à %s : %s" % [zone, barre])
		verifier(
			ecran.encloses(bandeau), "le bandeau est dans la fenêtre à %s : %s" % [zone, bandeau]
		)
		verifier_faux(barre.intersects(bandeau), "le HUD ne chevauche pas la boutique à %s" % zone)
		verifier(barre.end.y <= bandeau.position.y, "le HUD est au-dessus de la boutique")
		var libre := bandeau.position.y - barre.end.y
		verifier(libre >= zone.y * PART_ARENE_MIN, "l'arène garde %.0f px à %s" % [libre, zone])
		_liberer(jeu)


func test_le_hud_montre_chaque_valeur_a_chaque_resolution() -> void:
	for zone: Vector2 in RESOLUTIONS:
		var jeu := await _jeu_a(zone)
		var barre := jeu.hud.rect_barre()
		for noeud: Node in jeu.hud.find_children("*", "Label", true, false):
			var libelle := noeud as Label
			var rect := libelle.get_global_rect()
			verifier(libelle.is_visible_in_tree(), "« %s » visible" % libelle.text)
			verifier(rect.size.x > 1.0, "« %s » a une largeur à %s" % [libelle.text, zone])
			verifier(
				barre.encloses(rect.grow(-1.0)),
				"« %s » tient dans la barre à %s" % [libelle.text, zone]
			)
		_liberer(jeu)


func test_la_tour_est_au_centre_de_l_arene_visible_et_le_cercle_d_apparition_y_tient() -> void:
	for zone: Vector2 in RESOLUTIONS:
		var jeu := await _jeu_a(zone)
		var haut := jeu.hud.rect_barre().end.y
		var bas := jeu.boutique.rect_bandeau().position.y
		var libre := Rect2(0.0, haut, zone.x, bas - haut)
		var centre := jeu.camera.projeter(Vector2.ZERO)
		var attendu := libre.get_center()
		verifier_proche(centre.x, attendu.x, 1.0, "tour centrée en x à %s" % zone)
		verifier_proche(centre.y, attendu.y, 1.0, "tour centrée en y à %s" % zone)
		var rayon: float = Apparence.vers_pixels(Vector2(CameraArene.RAYON_APPARITION, 0.0)).x
		for i: int in 64:
			var angle: float = TAU * float(i) / 64.0
			var px := jeu.camera.projeter(Vector2.from_angle(angle) * rayon)
			verifier(
				libre.grow(1.0).has_point(px),
				"point %d du cercle d'apparition hors de l'arène visible à %s : %s" % [i, zone, px]
			)
		_liberer(jeu)


func test_les_panneaux_ont_un_fond_opaque() -> void:
	var jeu := await _jeu_a(RESOLUTIONS[0])
	_fond_opaque(jeu.hud.get_node("Barre"), "HUD")
	_fond_opaque(jeu.boutique.get_node("Bandeau"), "bandeau de la boutique")
	_fond_opaque(jeu.boutique.get_node("Cote"), "panneau des armes")
	_fond_opaque(jeu.scores.panneau, "tableau des scores")
	_fond_opaque(jeu.fin.panneau, "écran de fin")
	_fond_opaque(jeu.observation.panneau, "observation")
	_fond_opaque(jeu.find_child("Pause", true, false) as Control, "menu de jeu")
	var menu := (load("res://scenes/principal.tscn") as PackedScene).instantiate() as Principal
	menu.donnees = _donnees
	menu.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	arbre.root.add_child(menu)
	_fond_opaque(menu.menu().find_child("CadreAccueil", true, false) as Control, "menu principal")
	_liberer(menu)
	_liberer(jeu)


func test_les_cartes_ont_un_fond_et_un_bord() -> void:
	var jeu := await _jeu_a(RESOLUTIONS[0])
	for i: int in 4:
		var carte := jeu.boutique.find_child("Carte%d" % i, true, false) as Control
		_fond_opaque(carte, "carte %d" % i)
	_liberer(jeu)


func test_le_tableau_des_scores_a_huit_joueurs_tient_dans_la_fenetre_sans_toucher_le_hud() -> void:
	for zone: Vector2 in RESOLUTIONS:
		var jeu := await _jeu_a(zone)
		jeu._sur_globale(_vue_globale(3))
		jeu.scores.definir_maintenu(true)
		await attendre_images(2)
		var rect := jeu.scores.panneau.get_global_rect()
		verifier(
			Rect2(Vector2.ZERO, zone).encloses(rect),
			"scores dans la fenêtre à %s : %s" % [zone, rect]
		)
		verifier_faux(rect.intersects(jeu.hud.rect_barre()), "les scores ne couvrent pas le HUD")
		_liberer(jeu)


func test_l_ecran_de_fin_masque_la_boutique_estompe_le_hud_et_tient_dans_la_fenetre() -> void:
	for zone: Vector2 in RESOLUTIONS:
		var jeu := await _jeu_a(zone)
		verifier(jeu.boutique.is_visible_in_tree(), "la boutique est là pendant la partie")
		_jusqua_la_defaite(jeu)
		await attendre_images(2)
		verifier(jeu.fin.visible, "l'écran de fin est affiché")
		verifier_faux(jeu.boutique.is_visible_in_tree(), "la boutique est masquée à %s" % zone)
		verifier(jeu.hud.modulate.a < 1.0, "le HUD est estompé")
		var rect := jeu.fin.panneau.get_global_rect()
		verifier(
			Rect2(Vector2.ZERO, zone).encloses(rect), "la fin tient dans la fenêtre à %s" % zone
		)
		verifier_proche(rect.get_center().x, zone.x * 0.5, 2.0, "la fin est centrée")
		_fond_opaque(jeu.fin.panneau, "écran de fin")
		# Une mise à jour de vue ne rouvre pas la boutique.
		jeu.source._process(PAS)
		verifier_faux(jeu.boutique.is_visible_in_tree(), "la boutique reste masquée")
		_liberer(jeu)


func test_rejouer_rend_la_boutique_et_le_hud() -> void:
	var jeu := await _jeu_a(RESOLUTIONS[0])
	_jusqua_la_defaite(jeu)
	jeu.fin.presser("rejouer")
	jeu.source._process(PAS)
	verifier(jeu.boutique.is_visible_in_tree(), "boutique de retour")
	verifier_proche(jeu.hud.modulate.a, 1.0, 0.001, "HUD à pleine opacité")
	_liberer(jeu)


func test_en_solo_le_bouton_d_observation_est_cache() -> void:
	var jeu := await _jeu_a(RESOLUTIONS[0])
	_jusqua_la_defaite(jeu)
	var boutons: Array[String] = []
	for noeud: Node in jeu.fin.find_children("*", "Button", true, false):
		boutons.append(str((noeud as Button).get_meta("action", "")))
	verifier_faux(boutons.has("observer"), "aucun bouton d'observation en solo")
	_liberer(jeu)


func test_le_bouton_d_observation_n_apparait_que_s_il_reste_un_autre_joueur_en_vie() -> void:
	for en_vie: int in range(0, 8):
		var jeu := await _jeu_a(RESOLUTIONS[0])
		_jusqua_la_defaite(jeu)
		jeu._sur_globale(_vue_globale(en_vie))
		verifier_egal(
			jeu.fin.actions_visibles().has("observer"), en_vie > 0, "%d autre(s) en vie" % en_vie
		)
		_liberer(jeu)


func test_les_armes_et_le_marche_noir_restent_entre_le_hud_et_la_boutique() -> void:
	for zone: Vector2 in RESOLUTIONS:
		var jeu := await _jeu_a(zone)
		var vue := VueArene.new()
		vue.argent = 1000
		vue.marche_noir_ouvert = true
		var ids: Array = _donnees.armes.keys()
		for i: int in 8:
			vue.armes.append({"id": ids[i % ids.size()], "recharge_ratio": 0.0})
		jeu.boutique.afficher(vue)
		await attendre_images(2)
		var cote := jeu.boutique.get_node("Cote") as Control
		var rect := cote.get_global_rect()
		verifier(rect.position.y >= jeu.hud.rect_barre().end.y, "armes sous le HUD à %s" % zone)
		verifier(
			rect.end.y <= jeu.boutique.rect_bandeau().position.y + 1.0,
			"armes au-dessus de la boutique à %s : %s" % [zone, rect]
		)
		_liberer(jeu)


## Review Focus 4 : aux crans extrêmes de la taille de l'interface et aux résolutions testées,
## aucun libellé du HUD ni de la boutique n'est plus large que sa case (pas de texte coupé), et
## les plus longs noms réels tiennent sur deux lignes d'une carte.
func test_aucun_texte_ne_deborde_ni_ne_se_coupe_a_75_et_125_pour_cent() -> void:
	# Or de départ réel : la valeur d'essai du fichier (un million) n'est pas un cas d'usage.
	_donnees = AidesPartie.donnees()
	var police := ThemeJeu.police()
	for echelle: float in ECHELLES_EXTREMES:
		# La fenêtre applique l'échelle (`content_scale_factor`) : le texte garde sa taille de base
		# dans une fenêtre logique plus petite ou plus grande.
		var taille := ThemeJeu.taille("texte")
		for resolution: Vector2 in RESOLUTIONS:
			var zone := resolution / echelle
			var jeu := await _jeu_a(zone)
			var ecran := Rect2(Vector2.ZERO, zone)
			verifier(ecran.encloses(jeu.hud.rect_barre()), "barre dans la fenêtre")
			verifier(ecran.encloses(jeu.boutique.rect_bandeau()), "bandeau dans la fenêtre")
			for panneau: Control in [jeu.hud, jeu.boutique]:
				for noeud: Node in panneau.find_children("*", "Label", true, false):
					var libelle := noeud as Label
					if (
						not libelle.is_visible_in_tree()
						or libelle.autowrap_mode != TextServer.AUTOWRAP_OFF
					):
						continue
					var largeur := (
						police
						. get_string_size(
							libelle.text, 0, -1, libelle.get_theme_font_size("font_size")
						)
						. x
					)
					verifier(
						largeur <= libelle.size.x + 1.0,
						"« %s » coupé à %s, échelle %s" % [libelle.text, resolution, echelle]
					)
			_liberer(jeu)
		for nom: String in _noms_les_plus_longs():
			var largeur := police.get_string_size(nom, 0, -1, taille).x
			verifier(
				largeur <= 2.0 * (BoutiqueUi.LARGEUR_CARTE - 32.0),
				"« %s » ne tient pas sur deux lignes à l'échelle %s" % [nom, echelle]
			)


## T8.19 : les quatre plus longs noms réels (armes et améliorations), avec leur ruban de
## catégorie, la grille des armes et le marché noir ouvert, tiennent à 75 % et à 125 % aux quatre
## résolutions : aucun libellé n'est plus large que sa case, aucune ligne n'est masquée, aucun
## bouton n'est plus petit que son texte.
func test_aucun_libelle_ne_se_coupe_avec_les_plus_longs_noms_reels_a_75_et_125_pour_cent() -> void:
	_donnees = AidesPartie.donnees()
	var police := ThemeJeu.police()
	var taille := ThemeJeu.taille("texte")
	var entrees: Array[Dictionary] = []
	for id: String in _donnees.armes:
		entrees.append({"id": id, "genre": Types.Genre.ARME})
	for id: String in _donnees.ameliorations:
		entrees.append({"id": id, "genre": Types.Genre.AMELIORATION})
	var nom_de := func(e: Dictionary) -> String:
		var table: Dictionary = (
			_donnees.armes if e["genre"] == Types.Genre.ARME else _donnees.ameliorations
		)
		return String((table[e["id"]] as Dictionary)["nom"])
	entrees.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (
				police.get_string_size(nom_de.call(a), 0, -1, taille).x
				> police.get_string_size(nom_de.call(b), 0, -1, taille).x
			)
	)
	# Le prix le plus long du catalogue : un prix inventé plus long ne dirait rien du jeu.
	var prix_max := 0
	for e: Dictionary in entrees:
		var table: Dictionary = (
			_donnees.armes if e["genre"] == Types.Genre.ARME else _donnees.ameliorations
		)
		prix_max = maxi(prix_max, int((table[e["id"]] as Dictionary)["prix"]))
	var plus_longues := entrees.slice(0, BoutiqueUi.NB_OFFRES)
	verifier_egal(plus_longues.size(), BoutiqueUi.NB_OFFRES, "assez d'offres réelles")
	for echelle: float in ECHELLES_EXTREMES:
		for resolution: Vector2 in RESOLUTIONS:
			var zone := resolution / echelle
			var jeu := await _jeu_a(zone)
			# Une vue de la partie arrivant entre deux images remplacerait celle du test.
			jeu.source.set_process(false)
			var vue := VueArene.new()
			# Or insuffisant sur chaque offre : la note « Or insuffisant » doit tenir entière.
			vue.argent = 0
			vue.cout_relance = prix_max
			vue.marche_noir_ouvert = true
			for i: int in plus_longues.size():
				var e: Dictionary = plus_longues[i]
				(
					vue
					. offres
					. append(
						{
							"id": e["id"],
							"genre": e["genre"],
							"rarete": i % 4,
							"prix": prix_max,
							"vendu": i == 0,
						}
					)
				)
				if e["genre"] == Types.Genre.ARME:
					vue.armes.append({"id": e["id"], "recharge_ratio": 0.0})
				else:
					vue.ameliorations[e["id"]] = 12
			jeu.boutique.afficher(vue)
			await attendre_images(3)
			var ou := "à %s, échelle %s" % [resolution, echelle]
			var notes_or := 0
			for noeud: Node in jeu.boutique.find_children("*", "Label", true, false):
				var libelle := noeud as Label
				if not libelle.is_visible_in_tree() or libelle.text.is_empty():
					continue
				var largeur := (
					police
					. get_string_size(libelle.text, 0, -1, libelle.get_theme_font_size("font_size"))
					. x
				)
				if libelle.text.begins_with(tr("BOUTIQUE_OR_INSUFFISANT")):
					notes_or += 1
				if libelle.autowrap_mode == TextServer.AUTOWRAP_OFF:
					verifier(
						largeur <= libelle.size.x + 1.0, "« %s » coupé %s" % [libelle.text, ou]
					)
				else:
					verifier_egal(
						libelle.get_visible_line_count(),
						libelle.get_line_count(),
						"« %s » : ligne masquée %s" % [libelle.text, ou]
					)
					verifier(
						libelle.get_line_count() <= 3,
						"« %s » : trop de lignes %s" % [libelle.text, ou]
					)
			for noeud: Node in jeu.boutique.find_children("*", "Button", true, false):
				var bouton := noeud as Button
				if bouton.is_visible_in_tree():
					var minimum := bouton.get_minimum_size()
					verifier(
						minimum.x <= bouton.size.x + 1.0 and minimum.y <= bouton.size.y + 1.0,
						"bouton « %s » trop petit pour son texte %s" % [bouton.text, ou]
					)
			verifier(notes_or > 0, "une note « Or insuffisant » est affichée %s" % ou)
			var ecran := Rect2(Vector2.ZERO, zone)
			for panneau: PanelContainer in jeu.boutique.panneaux():
				verifier(
					ecran.encloses(panneau.get_global_rect()), "panneau dans la fenêtre %s" % ou
				)
			_liberer(jeu)


## Or insuffisant : la note « Or insuffisant » de chaque carte s'affiche entière (ni points de
## suspension, ni ligne masquée) aux crans extrêmes de l'interface et aux quatre résolutions, sans
## faire dépasser au bandeau 45 % de la hauteur. L'or de départ à zéro rend toute offre trop chère,
## avec les offres réelles de la partie : plus besoin d'un or abondant pour contourner le défaut.
func test_la_note_or_insuffisant_tient_entiere_sans_depasser_les_seuils() -> void:
	_donnees = AidesPartie.donnees({"economie.json": [[["or_depart"], 0]]})
	var police := ThemeJeu.police()
	var texte := tr("BOUTIQUE_OR_INSUFFISANT")
	for echelle: float in ECHELLES_EXTREMES:
		for resolution: Vector2 in RESOLUTIONS:
			var zone := resolution / echelle
			var jeu := await _jeu_a(zone)
			jeu.source.set_process(false)
			var ou := "à %s, échelle %s" % [resolution, echelle]
			var vues := 0
			for i: int in BoutiqueUi.NB_OFFRES:
				var note := jeu.boutique.find_child("Note%d" % i, true, false) as Label
				if note == null or not note.visible:
					continue
				vues += 1
				verifier_egal(note.text, texte, "note de la carte %d %s" % [i, ou])
				verifier(not note.clip_text, "note non rognée %s" % ou)
				verifier_egal(
					note.get_visible_line_count(), note.get_line_count(), "ligne masquée %s" % ou
				)
				var largeur := police.get_string_size(note.text, 0, -1, 16).x
				verifier(
					note.get_line_count() > 1 or largeur <= note.size.x + 1.0, "note coupée %s" % ou
				)
			verifier(vues > 0, "au moins une note affichée %s" % ou)
			verifier(
				jeu.boutique.rect_bandeau_minimal().y <= MiseEnPage.PART_MAX_BOUTIQUE * zone.y,
				(
					"bandeau sous %d %% de la hauteur %s"
					% [roundi(MiseEnPage.PART_MAX_BOUTIQUE * 100), ou]
				)
			)
			_liberer(jeu)


## S15 : le pire cas de la boutique (les quatre offres aux plus longs noms réels, or à zéro donc la
## note « Or insuffisant » sur chaque carte) tient dans la part maximale de la hauteur, aux quatre
## résolutions et aux crans extrêmes de l'interface. Les noms viennent de `data/`, pas du test.
func test_le_pire_cas_de_la_boutique_tient_dans_la_part_maximale_a_125_pour_cent() -> void:
	_donnees = AidesPartie.donnees()
	var police := ThemeJeu.police()
	var taille := ThemeJeu.taille("texte")
	var entrees: Array[Dictionary] = []
	for id: String in _donnees.armes:
		entrees.append({"id": id, "genre": Types.Genre.ARME})
	for id: String in _donnees.ameliorations:
		entrees.append({"id": id, "genre": Types.Genre.AMELIORATION})
	var table_de := func(e: Dictionary) -> Dictionary:
		return _donnees.armes if e["genre"] == Types.Genre.ARME else _donnees.ameliorations
	var nom_de := func(e: Dictionary) -> String:
		return String(((table_de.call(e) as Dictionary)[e["id"]] as Dictionary)["nom"])
	entrees.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (
				police.get_string_size(nom_de.call(a), 0, -1, taille).x
				> police.get_string_size(nom_de.call(b), 0, -1, taille).x
			)
	)
	var plus_longues := entrees.slice(0, BoutiqueUi.NB_OFFRES)
	verifier_egal(plus_longues.size(), BoutiqueUi.NB_OFFRES, "assez d'offres réelles")
	for echelle: float in ECHELLES_EXTREMES:
		for resolution: Vector2 in RESOLUTIONS:
			var zone := resolution / echelle
			var jeu := await _jeu_a(zone)
			jeu.source.set_process(false)
			var vue := VueArene.new()
			vue.argent = 0
			for i: int in plus_longues.size():
				var e: Dictionary = plus_longues[i]
				var entree: Dictionary = (table_de.call(e) as Dictionary)[e["id"]]
				(
					vue
					. offres
					. append(
						{
							"id": e["id"],
							"genre": e["genre"],
							"rarete": i % 4,
							"prix": int(entree["prix"]),
							"vendu": false,
						}
					)
				)
			jeu.boutique.afficher(vue)
			await attendre_images(3)
			var ou := "à %s, échelle %s" % [resolution, echelle]
			var notes_or := 0
			for i: int in BoutiqueUi.NB_OFFRES:
				var note := jeu.boutique.find_child("Note%d" % i, true, false) as Label
				if note != null and note.visible and note.text == tr("BOUTIQUE_OR_INSUFFISANT"):
					notes_or += 1
			verifier_egal(
				notes_or, BoutiqueUi.NB_OFFRES, "« Or insuffisant » sur chaque carte %s" % ou
			)
			var hauteur := jeu.boutique.rect_bandeau_minimal().y
			verifier(
				hauteur <= zone.y * MiseEnPage.PART_MAX_BOUTIQUE + 0.5,
				(
					"pire cas : bandeau de %.1f px, limite %.1f px %s"
					% [hauteur, zone.y * MiseEnPage.PART_MAX_BOUTIQUE, ou]
				)
			)
			_liberer(jeu)


## T8.19 et T8.20 : replier la boutique libère la zone, que `Jeu` recalcule dès le signal
## `repli_change` ; la déplier la lui rend.
func test_le_repli_de_la_boutique_libere_la_zone() -> void:
	_donnees = AidesPartie.donnees()
	for resolution: Vector2 in RESOLUTIONS:
		var jeu := await _jeu_a(resolution)
		# La tour est au centre de la zone libre : elle descend quand le bandeau disparaît.
		var avant := jeu.camera.projeter(Vector2.ZERO).y
		var bandeau := jeu.boutique.rect_bandeau_minimal().y
		verifier(bandeau > 0.0, "déplié, le bandeau prend de la place")
		jeu.boutique.definir_replie(true)
		await attendre_images(2)
		verifier_egal(jeu.boutique.rect_bandeau_minimal().y, 0.0, "replié, plus de hauteur")
		verifier(jeu.camera.projeter(Vector2.ZERO).y > avant, "la vue gagne la place du bandeau")
		verifier(
			jeu.minicarte.get_global_rect().end.y > resolution.y - bandeau,
			"la mini-carte descend dans la zone libérée"
		)
		jeu.boutique.definir_replie(false)
		await attendre_images(2)
		verifier_proche(jeu.camera.projeter(Vector2.ZERO).y, avant, 0.01, "déplié, la vue rétrécit")
		_liberer(jeu)


func _noms_les_plus_longs() -> Array[String]:
	var noms: Array[String] = []
	for id: Variant in _donnees.armes:
		noms.append(String((_donnees.armes[id] as Dictionary)["nom"]))
	for id: Variant in _donnees.ameliorations:
		noms.append(String((_donnees.ameliorations[id] as Dictionary)["nom"]))
	for famille: Dictionary in _donnees.familles:
		noms.append(String(famille["nom"]))
	return noms


## D13 : la boutique prenait trop de place, elle doit perdre au moins 30 % de sa surface.
func test_la_boutique_est_au_moins_30_pour_cent_plus_petite_qu_avant() -> void:
	_donnees = AidesPartie.donnees()
	verifier_egal(SURFACE_AVANT.size(), RESOLUTIONS.size())
	for i: int in RESOLUTIONS.size():
		var jeu := await _jeu_a(RESOLUTIONS[i])
		var surface := 0.0
		for panneau: PanelContainer in jeu.boutique.panneaux():
			if panneau.is_visible_in_tree():
				var rect := panneau.get_global_rect()
				surface += rect.size.x * rect.size.y
		verifier(
			surface <= 0.7 * SURFACE_AVANT[i],
			"à %s : %.0f px² pour %.0f avant" % [RESOLUTIONS[i], surface, SURFACE_AVANT[i]]
		)
		_liberer(jeu)
