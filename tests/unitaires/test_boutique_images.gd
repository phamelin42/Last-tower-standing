extends CasDeTest
## Chaque offre de la boutique montre sa case peinte : en tête de carte (de 64 à 96 px, sans
## repousser l'effet), devant chaque arme équipée et à chaque choix du marché noir. L'image est
## décorative : ni souris, ni focus.

const CSV_BOUTIQUE := "res://i18n/textes_boutique.csv"
const CSV_COMMUNS := "res://i18n/textes_communs.csv"
const SCENE := "res://scenes/boutique.tscn"
const NB_OFFRES := 4
const NB_OFFRES_TOTAL := 70
const RESOLUTIONS: Array[Vector2] = [
	Vector2(1152.0, 648.0), Vector2(1280.0, 720.0), Vector2(1366.0, 768.0), Vector2(1920.0, 1080.0)
]
const OR_ABONDANT := 1000000

var _donnees: Donnees
var _traduction: Translation
var _locale_avant: String = "en"
var _source: SourceFactice
var _ui: BoutiqueUi


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	_traduction = Translation.new()
	_traduction.locale = "fr"
	for chemin: String in [CSV_BOUTIQUE, CSV_COMMUNS]:
		var textes := CsvTextes.lire(chemin)
		for cle: String in textes:
			var texte: String = textes[cle]
			_traduction.add_message(cle, texte)
	TranslationServer.add_translation(_traduction)
	TranslationServer.set_locale("fr")
	_donnees = Donnees.charger()


func apres_chaque() -> void:
	for noeud: Node in [_ui, _source]:
		if is_instance_valid(noeud):
			noeud.get_parent().remove_child(noeud)
			noeud.free()
	_ui = null
	_source = null
	TranslationServer.remove_translation(_traduction)
	TranslationServer.set_locale(_locale_avant)


# --- Aides ---------------------------------------------------------------------------------


func _monter_boutique() -> void:
	_source = SourceFactice.new()
	arbre.root.add_child(_source)
	_ui = (load(SCENE) as PackedScene).instantiate() as BoutiqueUi
	arbre.root.add_child(_ui)
	_ui.configurer(_donnees, _source)


func _genre(id: String) -> int:
	return Types.Genre.ARME if _donnees.armes.has(id) else Types.Genre.AMELIORATION


func _offre(id: String) -> Dictionary:
	var genre := _genre(id)
	var table: Dictionary = _donnees.armes if genre == Types.Genre.ARME else _donnees.ameliorations
	var entree: Dictionary = table[id]
	return {
		"id": id,
		"genre": genre,
		"rarete": int(entree["rarete"]),
		"prix": int(entree["prix"]),
		"vendu": false,
	}


func _vue(offres: Array[Dictionary]) -> VueArene:
	var vue := VueArene.new()
	vue.argent = OR_ABONDANT
	vue.cout_relance = 50
	vue.offres = offres
	return vue


## Les quatre offres de longue ligne d'effet : le pire cas pour la place.
func _plus_longues() -> Array[Dictionary]:
	var toutes: Array[Dictionary] = []
	for id: String in ImagesOffres.ids():
		toutes.append(_offre(id))
	toutes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return _ligne(a).length() > _ligne(b).length()
	)
	var sortie: Array[Dictionary] = []
	for i: int in NB_OFFRES:
		sortie.append(toutes[i])
	return sortie


func _ligne(offre: Dictionary) -> String:
	var genre: int = offre["genre"]
	var table: Dictionary = _donnees.armes if genre == Types.Genre.ARME else _donnees.ameliorations
	return DescriptionOffre.ligne_effet(table[str(offre["id"])], genre, _donnees, false)


func _image(i: int) -> TextureRect:
	return _ui.find_child("Image%d" % i, true, false) as TextureRect


func _chemin(rect_texture: Texture2D) -> String:
	return "" if rect_texture == null else rect_texture.resource_path


func _jeu_a(zone: Vector2) -> Jeu:
	var donnees := AidesPartie.donnees({"economie.json": [[["or_depart"], OR_ABONDANT]]})
	var jeu := (load("res://scenes/jeu.tscn") as PackedScene).instantiate() as Jeu
	jeu.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	jeu.nom_joueur = "Mina"
	arbre.root.add_child(jeu)
	verifier(jeu.demarrer_solo(donnees, 2024, 0.5))
	var racine := jeu.get_node("Interface/Racine") as Control
	racine.anchor_right = 0.0
	racine.anchor_bottom = 0.0
	racine.offset_right = zone.x
	racine.offset_bottom = zone.y
	jeu.source._process(1.0)
	# La source rejouerait ses propres offres à chaque image : le test pose les siennes.
	jeu.source.set_process(false)
	await attendre_images(2)
	jeu.placer_dans(zone)
	await attendre_images(2)
	return jeu


func _liberer(noeud: Node) -> void:
	if is_instance_valid(noeud):
		noeud.get_parent().remove_child(noeud)
		noeud.free()


# --- La carte --------------------------------------------------------------------------------


func test_la_table_couvre_les_70_offres_de_la_boutique() -> void:
	verifier_egal(ImagesOffres.ids().size(), NB_OFFRES_TOTAL, "70 offres dessinées")
	verifier_egal(
		_donnees.armes.size() + _donnees.ameliorations.size(), NB_OFFRES_TOTAL, "70 offres au total"
	)


func test_chaque_offre_affichee_montre_l_image_de_son_identifiant_en_boucle() -> void:
	_monter_boutique()
	for id: String in ImagesOffres.ids():
		var offres: Array[Dictionary] = [_offre(id)]
		_ui.afficher(_vue(offres))
		var attendu := ImagesOffres.chemin_case(id)
		verifier_egal(_chemin(_image(0).texture), attendu, "carte 0 : l'image de %s" % id)
		verifier(_image(1).texture == null, "carte 1 sans offre : pas d'image")


func test_les_quatre_cartes_montrent_chacune_leur_image() -> void:
	_monter_boutique()
	var ids := ImagesOffres.ids()
	var offres: Array[Dictionary] = []
	for i: int in NB_OFFRES:
		offres.append(_offre(ids[i * 17]))
	_ui.afficher(_vue(offres))
	for i: int in NB_OFFRES:
		verifier_egal(
			_chemin(_image(i).texture),
			ImagesOffres.chemin_case(str(offres[i]["id"])),
			"carte %d" % i
		)


func test_l_image_est_decorative_ni_souris_ni_focus() -> void:
	_monter_boutique()
	var offres: Array[Dictionary] = [_offre(ImagesOffres.ids()[0])]
	_ui.afficher(_vue(offres))
	for i: int in NB_OFFRES:
		var image := _image(i)
		verifier_egal(image.mouse_filter, Control.MOUSE_FILTER_IGNORE, "carte %d : souris" % i)
		verifier_egal(image.focus_mode, Control.FOCUS_NONE, "carte %d : focus" % i)
		verifier_egal(
			image.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "filtrage lisse"
		)
	var armes: Array[String] = []
	for id: String in _donnees.armes:
		armes.append(id)
	var vue := _vue(offres)
	vue.armes.append({"id": armes[0], "recharge_ratio": 0.0})
	_ui.afficher(vue)
	var arme := _ui.find_child("ImageArme0", true, false) as TextureRect
	verifier_egal(arme.mouse_filter, Control.MOUSE_FILTER_IGNORE, "arme : souris")
	verifier_egal(arme.focus_mode, Control.FOCUS_NONE, "arme : focus")


func test_la_taille_de_l_image_reste_dans_ses_bornes_et_dans_la_carte_a_chaque_resolution() -> void:
	var offres := _plus_longues()
	for zone: Vector2 in RESOLUTIONS:
		var jeu := await _jeu_a(zone)
		jeu.boutique.afficher(_vue(offres))
		await attendre_images(2)
		jeu.placer_dans(zone)
		await attendre_images(2)
		for i: int in NB_OFFRES:
			var carte := jeu.boutique.find_child("Carte%d" % i, true, false) as Control
			var image := jeu.boutique.find_child("Image%d" % i, true, false) as TextureRect
			var cote := image.get_global_rect().size
			verifier(
				cote.x >= BoutiqueUi.IMAGE_MIN - 0.5 and cote.x <= BoutiqueUi.IMAGE_MAX + 0.5,
				"à %s, carte %d : image de %s px dans [64, 96]" % [zone, i, cote.x]
			)
			verifier_proche(cote.x, cote.y, 0.5, "à %s : l'image est carrée" % zone)
			verifier(
				carte.get_global_rect().grow(0.5).encloses(image.get_global_rect()),
				"à %s, carte %d : l'image reste dans la carte" % [zone, i]
			)
			var effet := jeu.boutique.find_child("Effet%d" % i, true, false) as Label
			verifier_faux(
				image.get_global_rect().intersects(effet.get_global_rect()),
				"à %s, carte %d : l'image ne recouvre pas l'effet" % [zone, i]
			)
			verifier_egal(
				effet.get_visible_line_count(),
				effet.get_line_count(),
				"à %s, carte %d : l'effet reste entier" % [zone, i]
			)
			var nom := jeu.boutique.find_child("Nom%d" % i, true, false) as Label
			verifier_faux(
				image.get_global_rect().intersects(nom.get_global_rect()),
				"à %s, carte %d : l'image ne recouvre pas le nom" % [zone, i]
			)
		_liberer(jeu)


func test_l_image_grandit_avec_la_fenetre_sans_depasser_ses_bornes() -> void:
	var precedente := 0.0
	for zone: Vector2 in RESOLUTIONS:
		var t := BoutiqueUi.taille_image(zone)
		verifier(t >= BoutiqueUi.IMAGE_MIN and t <= BoutiqueUi.IMAGE_MAX, "à %s : %s" % [zone, t])
		verifier(
			t >= precedente, "à %s : jamais plus petite que dans une fenêtre plus basse" % zone
		)
		precedente = t
	verifier_egal(BoutiqueUi.taille_image(RESOLUTIONS[0]), BoutiqueUi.IMAGE_MIN, "la plus petite")
	verifier_egal(BoutiqueUi.taille_image(RESOLUTIONS[3]), BoutiqueUi.IMAGE_MAX, "la plus grande")


# --- Armes équipées et marché noir -----------------------------------------------------------


func test_chaque_arme_equipee_montre_son_image_devant_son_nom_en_boucle() -> void:
	_monter_boutique()
	var vue := _vue([])
	var ids: Array[String] = []
	for id: String in _donnees.armes:
		ids.append(id)
	for id: String in ids:
		vue.armes = [{"id": id, "recharge_ratio": 0.0}]
		_ui.afficher(vue)
		var image := _ui.find_child("ImageArme0", true, false) as TextureRect
		var nom := _ui.find_child("NomArme0", true, false) as Label
		verifier_egal(_chemin(image.texture), ImagesOffres.chemin_case(id), "l'image de %s" % id)
		verifier(
			image.get_index() < nom.get_index() and image.get_parent() == nom.get_parent(),
			"%s : l'image précède le nom sur sa ligne" % id
		)
		var cote := image.custom_minimum_size.x
		verifier(cote >= 32.0 and cote <= 40.0, "%s : image de %s px dans [32, 40]" % [id, cote])


func test_chaque_choix_du_marche_noir_montre_son_image() -> void:
	_monter_boutique()
	var vue := _vue([])
	vue.marche_noir_ouvert = true
	_ui.afficher(vue)
	var noir := _ui.find_child("MarcheNoir", true, false) as Control
	var choix: Array[Button] = []
	for noeud: Node in noir.find_children("*", "Button", true, false):
		choix.append(noeud as Button)
	verifier(choix.size() > 0, "des choix sont proposés")
	var ids: Array[String] = []
	for id: String in _donnees.ameliorations:
		var amelio: Dictionary = _donnees.ameliorations[id]
		var reglage: Dictionary = _donnees.boutique["marche_noir"]
		if int(amelio["rarete"]) <= Types.rarete_depuis_nom(str(reglage["raretes_max"])):
			ids.append(id)
	ids.sort()
	verifier_egal(choix.size(), ids.size(), "un choix par amélioration admise")
	for i: int in choix.size():
		verifier_egal(
			_chemin(choix[i].icon), ImagesOffres.chemin_case(ids[i]), "choix %d : %s" % [i, ids[i]]
		)
		verifier(choix[i].text.contains(str(_donnees.ameliorations[ids[i]]["nom"])), "nom écrit")
		verifier_egal(choix[i].get_theme_constant("icon_max_width"), 40, "image de 40 px")


# --- Relance ---------------------------------------------------------------------------------


## Le libellé du bouton de relance tient entier dans le bouton, pour chaque prix (0, 2 chiffres,
## 4 chiffres) : « Relancer » sur une ligne, le prix sur la suivante, chaque ligne en largeur et
## les deux en hauteur.
func test_le_libelle_de_relance_tient_dans_son_bouton_a_chaque_resolution() -> void:
	for prix: int in [0, 50, 1000]:
		for zone: Vector2 in RESOLUTIONS:
			await _verifier_relance(prix, zone)


func _verifier_relance(prix: int, zone: Vector2) -> void:
	var jeu := await _jeu_a(zone)
	var vue := _vue([])
	vue.cout_relance = prix
	vue.relances_gratuites = 0
	jeu.boutique.afficher(vue)
	await attendre_images(2)
	jeu.placer_dans(zone)
	await attendre_images(2)
	var actions := jeu.boutique.find_child("Actions", true, false) as Control
	var bouton := actions.find_children("*", "Button", true, false)[0] as Button
	var boite := bouton.get_theme_stylebox("normal")
	var police := bouton.get_theme_font("font")
	var taille := bouton.get_theme_font_size("font_size")
	var largeur := bouton.size.x - boite.get_minimum_size().x
	var contexte := "à %s, prix %d" % [zone, prix]
	verifier(
		bouton.text.begins_with("Relancer\n"),
		"%s : retour à la ligne voulu (%s)" % [contexte, bouton.text]
	)
	verifier(bouton.text.contains(Nombres.groupe(prix)), "%s : le prix est écrit" % contexte)
	var lignes := bouton.text.split("\n")
	verifier_egal(lignes.size(), 2, "%s : deux lignes voulues" % contexte)
	for ligne: String in lignes:
		var paragraphe := TextParagraph.new()
		paragraphe.add_string(ligne, police, taille)
		paragraphe.width = largeur
		paragraphe.break_flags = (
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		)
		verifier_egal(
			paragraphe.get_line_count(),
			1,
			"%s : « %s » ne passe pas à la ligne" % [contexte, ligne]
		)
	# Une ligne occupe la hauteur de la police (celle des `Label` de l'interface) : c'est elle que
	# le bouton doit pouvoir loger, deux fois.
	var requis := 2.0 * police.get_height(taille) + boite.get_minimum_size().y
	verifier(
		requis <= bouton.size.y + 0.5,
		"%s : %s px requis pour 2 lignes, bouton de %s px" % [contexte, requis, bouton.size.y]
	)
	_liberer(jeu)
