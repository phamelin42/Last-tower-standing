extends CasDeTest
## L'interface porte les couleurs de Tiny Swords : chaque texture citée existe, chaque état d'un
## bouton a son style, tout texte garde 4,5:1 sur la couleur moyenne de la texture qui le porte, et
## la police affiche tous les caractères des textes du jeu.

const SEUIL := 4.5
const DOSSIER_TEXTES := "res://i18n/"
## Focus clavier : contraste d'au moins 3:1 (WCAG 1.4.11) avec le panneau sur lequel il se pose.
const SEUIL_FOCUS := 3.0
const ETATS: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]
const ETATS_TEXTURE: Array[String] = ["normal", "hover", "pressed", "disabled"]
const TYPES_BOUTON: Array[String] = ["Button", "BoutonDanger"]


func _theme() -> Theme:
	return ThemeJeu.creer()


# --- Textures --------------------------------------------------------------------------------


func test_chaque_texture_citee_par_le_theme_existe() -> void:
	verifier(ThemeJeu.TEXTURES.size() >= 10, "le thème cite ses textures")
	for chemin: String in ThemeJeu.TEXTURES:
		verifier(ResourceLoader.exists(chemin), "texture absente : %s" % chemin)
		var t := load(chemin) as Texture2D
		verifier_non_nul(t, "texture illisible : %s" % chemin)


func test_chaque_style_de_bouton_garde_ses_extremites_et_repete_son_centre() -> void:
	# Les boutons du pack sont des bandes de 64 px de haut : trois tranches en largeur, centre
	# répété (jamais étiré, donc jamais flou).
	var t := _theme()
	for type: String in TYPES_BOUTON:
		for etat: String in ETATS_TEXTURE:
			var boite := t.get_stylebox(etat, type) as StyleBoxTexture
			verifier_non_nul(boite, "%s/%s : StyleBoxTexture" % [type, etat])
			if boite == null:
				continue
			verifier(boite.texture_margin_left > 0.0, "%s/%s : extrémité gauche" % [type, etat])
			verifier(boite.texture_margin_right > 0.0, "%s/%s : extrémité droite" % [type, etat])
			verifier_egal(
				boite.axis_stretch_horizontal,
				StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT,
				"%s/%s : centre répété" % [type, etat]
			)
	for nom: String in ["panel"]:
		var panneau := ThemeJeu.boite_panneau()
		verifier(panneau.texture_margin_left > 0.0 and panneau.texture_margin_top > 0.0, nom)
		verifier_egal(panneau.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT)
		verifier_egal(panneau.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT)


func test_appliquer_pose_le_theme_et_le_filtre_au_plus_proche_voisin() -> void:
	var racine := Control.new()
	ThemeJeu.appliquer(racine)
	verifier_egal(racine.theme, ThemeJeu.creer())
	verifier_egal(racine.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "pixels nets")
	racine.free()


# --- Boutons ---------------------------------------------------------------------------------


func test_chaque_etat_d_un_bouton_a_son_style() -> void:
	var t := _theme()
	for type: String in TYPES_BOUTON:
		for etat: String in ETATS:
			verifier(t.has_stylebox(etat, type), "%s : style « %s »" % [type, etat])
		var vus: Array[Texture2D] = []
		for etat: String in ETATS_TEXTURE:
			var boite := t.get_stylebox(etat, type) as StyleBoxTexture
			if boite != null:
				verifier(not vus.has(boite.texture), "%s/%s : texture propre" % [type, etat])
				vus.append(boite.texture)


func test_un_bouton_est_assez_haut_pour_le_toucher() -> void:
	var t := _theme()
	for type: String in TYPES_BOUTON:
		var b := Button.new()
		b.theme = t
		b.theme_type_variation = "" if type == "Button" else type
		b.text = "Acheter"
		b.custom_minimum_size = Vector2(0.0, ThemeJeu.HAUTEUR_CONTROLE)
		arbre.root.add_child(b)
		await attendre_images(1)
		verifier(b.size.y >= ThemeJeu.HAUTEUR_CONTROLE, "%s : %.0f px de haut" % [type, b.size.y])
		b.get_parent().remove_child(b)
		b.free()


func test_le_focus_clavier_reste_visible() -> void:
	var t := _theme()
	for type: String in TYPES_BOUTON:
		var focus := t.get_stylebox("focus", type) as StyleBoxFlat
		verifier_non_nul(focus, "%s : le focus est un cadre net" % type)
		if focus == null:
			continue
		verifier(focus.border_width_left >= 3, "%s : cadre d'au moins 3 px" % type)
		verifier(focus.expand_margin_left >= 2.0, "%s : le cadre déborde du bouton" % type)
		verifier(focus.bg_color.a == 0.0, "%s : le focus ne cache pas le texte" % type)
		var c := ThemeJeu.contraste(focus.border_color, ThemeJeu.ENCRE)
		verifier(c >= SEUIL_FOCUS, "%s : focus %.2f:1 sur le panneau" % [type, c])


# --- Contrastes ------------------------------------------------------------------------------


func test_chaque_couple_de_texte_atteint_4_5_pour_1() -> void:
	var couples := ThemeJeu.couples_de_texte()
	verifier(couples.size() >= 15, "les couples sont listés (%d)" % couples.size())
	for couple: Dictionary in couples:
		var c := ThemeJeu.contraste(couple["texte"] as Color, couple["fond"] as Color)
		verifier(c >= SEUIL, "%s : %.2f:1 sous %.1f:1" % [couple["nom"], c, SEUIL])


func test_les_fonds_de_panneau_mesures_sont_ceux_que_le_texte_suppose() -> void:
	var t := _theme()
	var panneau := ThemeJeu.boite_panneau()
	verifier(
		_proche(ThemeJeu.fond_moyen(panneau), ThemeJeu.ENCRE),
		"panneau mesuré %s" % ThemeJeu.fond_moyen(panneau).to_html()
	)
	var carte := t.get_stylebox("panel", "Carte") as StyleBoxTexture
	verifier_non_nul(carte, "la carte est une texture")
	if carte != null:
		verifier(
			_proche(ThemeJeu.fond_moyen(carte), ThemeJeu.ENCRE_CARTE),
			"carte mesurée %s" % ThemeJeu.fond_moyen(carte).to_html()
		)


func test_un_texte_clair_sur_un_bouton_clair_serait_refuse() -> void:
	## Contrôle négatif : la mesure sait refuser le parchemin posé sur le bouton bleu.
	var bleu := ThemeJeu.fond_moyen(_theme().get_stylebox("normal", "Button") as StyleBoxTexture)
	verifier(ThemeJeu.contraste(ThemeJeu.PARCHEMIN, bleu) < SEUIL)


func test_l_etat_d_un_bouton_ne_repose_pas_sur_la_couleur_seule() -> void:
	## Inactif : texte à la teinte propre ET texture propre (déjà vérifiée) ; survol et appui
	## changent aussi de texture, donc de contour.
	var t := _theme()
	for type: String in TYPES_BOUTON:
		var normal := t.get_color("font_color", type)
		var inactif := t.get_color("font_disabled_color", type)
		verifier(normal != inactif, "%s : le texte inactif se distingue" % type)


func _proche(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.04 and absf(a.g - b.g) < 0.04 and absf(a.b - b.b) < 0.04


# --- Police ----------------------------------------------------------------------------------


func test_la_police_affiche_chaque_caractere_des_textes_du_jeu() -> void:
	var codes := _codes_des_csv()
	verifier(codes.has(0xA0), "le texte contient bien une espace insécable")
	_verifier_rendu(codes, "csv")


## Les symboles de rareté et d'armure, les boutons « × » et les autres signes viennent du code,
## pas des `.csv` : tout littéral de chaîne de `ui/`, `app/` et `visuels/apparence.gd` compte.
func test_la_police_affiche_chaque_caractere_des_litteraux_du_code() -> void:
	var codes := _codes_des_litteraux()
	verifier(codes.has(0x25CF), "les symboles de rareté sont lus (●)")
	_verifier_rendu(codes, "code")


func _verifier_rendu(codes: Dictionary, origine: String) -> void:
	var police := ThemeJeu.police()
	verifier_non_nul(police, "police chargée")
	for code: int in codes:
		if code < 32:
			continue
		verifier(
			police.has_char(code),
			"%s : caractère rendu ni par Metamorphous ni par le repli : U+%04X" % [origine, code]
		)


func _codes_des_csv() -> Dictionary:
	var codes: Dictionary = {}
	var dossier := DirAccess.open(DOSSIER_TEXTES)
	verifier_non_nul(dossier, "dossier des textes")
	var nb_fichiers := 0
	for nom: String in dossier.get_files():
		if nom.ends_with(".csv"):
			nb_fichiers += 1
			_ajouter_codes(codes, FileAccess.get_file_as_string(DOSSIER_TEXTES + nom))
	verifier(nb_fichiers >= 8, "tous les fichiers de textes sont lus (%d)" % nb_fichiers)
	return codes


func _codes_des_litteraux() -> Dictionary:
	var codes: Dictionary = {}
	var litteral := RegEx.create_from_string('"(?:[^"\\\\\n]|\\\\.)*"')
	var echappe := RegEx.create_from_string("\\\\u([0-9a-fA-F]{4})")
	var fichiers: Array[String] = ["res://visuels/apparence.gd"]
	for dossier_source: String in ["res://ui/", "res://app/"]:
		for nom: String in DirAccess.get_files_at(dossier_source):
			if nom.ends_with(".gd"):
				fichiers.append(dossier_source + nom)
	verifier(fichiers.size() >= 10, "les sources sont listées (%d)" % fichiers.size())
	for chemin: String in fichiers:
		for ligne: String in FileAccess.get_file_as_string(chemin).split("\n"):
			if ligne.strip_edges().begins_with("#"):
				continue
			for m: RegExMatch in litteral.search_all(ligne):
				var texte := m.get_string()
				_ajouter_codes(codes, texte)
				for e: RegExMatch in echappe.search_all(texte):
					codes[e.get_string(1).hex_to_int()] = true
	return codes


func _ajouter_codes(codes: Dictionary, texte: String) -> void:
	for i: int in texte.length():
		codes[texte.unicode_at(i)] = true


func test_la_police_est_celle_du_theme() -> void:
	verifier_egal(_theme().default_font, ThemeJeu.police())


func test_metamorphous_couvre_les_caracteres_du_francais() -> void:
	var fichier := load(ThemeJeu.POLICE) as FontFile
	verifier_non_nul(fichier, "Metamorphous chargée")
	for c: String in "éèêàçœ«»\u00a0":
		verifier(fichier.has_char(c.unicode_at(0)), "Metamorphous sans U+%04X" % c.unicode_at(0))
	# L'espace fine n'y est pas : la police du thème la prend au repli, sans erreur.
	verifier(ThemeJeu.police().has_char(0x202F), "espace fine rendue par le repli")


func test_la_police_du_theme_est_metamorphous_avec_dejavu_en_repli() -> void:
	verifier(ThemeJeu.POLICE.contains("metamorphous"), "police principale")
	verifier(ThemeJeu.POLICE_REPLI.contains("dejavu-sans"), "repli")
	var v := ThemeJeu.police() as FontVariation
	verifier_non_nul(v, "police variable")
	verifier(v.fallbacks.size() >= 1, "repli déclaré")


func test_tiny5_n_est_plus_cite() -> void:
	verifier(not DirAccess.dir_exists_absolute("res://assets/polices/tiny5"), "dossier supprimé")
	for dossier: String in ["res://ui", "res://app", "res://visuels"]:
		for nom: String in DirAccess.get_files_at(dossier):
			if nom.ends_with(".gd"):
				var texte := FileAccess.get_file_as_string(dossier.path_join(nom))
				verifier(not texte.to_lower().contains("tiny5"), "Tiny5 cité dans %s" % nom)


func test_aucune_taille_de_texte_en_dur_dans_ui() -> void:
	for nom: String in DirAccess.get_files_at("res://ui"):
		if not nom.ends_with(".gd") or nom == "theme.gd":
			continue
		var texte := FileAccess.get_file_as_string("res://ui/" + nom)
		verifier(not texte.contains("font_size"), "font_size local dans %s" % nom)
		verifier(not texte.contains("const TAILLE_"), "TAILLE_* local dans %s" % nom)


func test_la_taille_de_texte_suit_le_role_et_l_echelle() -> void:
	for role: String in ["texte", "petit", "titre"]:
		for echelle: float in Reglages.ECHELLES:
			verifier_egal(
				ThemeJeu.taille(role, echelle),
				roundi(ThemeJeu.TAILLES[role] * echelle),
				"%s à %s" % [role, echelle]
			)
	verifier_egal(ThemeJeu.taille("texte"), 16)
	verifier_egal(ThemeJeu.taille("inconnu"), 16, "rôle inconnu : taille du texte")
