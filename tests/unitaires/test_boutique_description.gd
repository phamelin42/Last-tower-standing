extends CasDeTest
## La carte de la boutique dit d'abord ce que fait l'offre (ligne d'effet générée, toujours entière
## et visible), puis la phrase d'ambiance en teinte atténuée. Les mêmes lignes d'effet servent
## ailleurs : infobulle du marché noir et des armes équipées.

const CSV_BOUTIQUE := "res://i18n/textes_boutique.csv"
const CSV_COMMUNS := "res://i18n/textes_communs.csv"
const SCENE := "res://scenes/boutique.tscn"
const NB_OFFRES := 4
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


func _entree(id: String, genre: int) -> Dictionary:
	var table: Dictionary = _donnees.armes if genre == Types.Genre.ARME else _donnees.ameliorations
	return table[id]


func _offre(id: String, genre: int) -> Dictionary:
	var entree := _entree(id, genre)
	return {
		"id": id,
		"genre": genre,
		"rarete": int(entree["rarete"]),
		"prix": int(entree["prix"]),
		"vendu": false,
	}


## Les `n` offres dont la ligne d'effet (celle de la carte, sans le type) est la plus longue.
func _plus_longues(n: int) -> Array[Dictionary]:
	var toutes: Array[Dictionary] = []
	for id: String in _donnees.armes:
		toutes.append(_offre(id, Types.Genre.ARME))
	for id: String in _donnees.ameliorations:
		toutes.append(_offre(id, Types.Genre.AMELIORATION))
	toutes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var ligne_a := _ligne_carte(a)
			var ligne_b := _ligne_carte(b)
			return ligne_a.length() > ligne_b.length()
	)
	var sortie: Array[Dictionary] = []
	for i: int in n:
		sortie.append(toutes[i])
	return sortie


func _ligne_carte(offre: Dictionary) -> String:
	var genre: int = offre["genre"]
	return DescriptionOffre.ligne_effet(_entree(str(offre["id"]), genre), genre, _donnees, false)


func _vue(offres: Array[Dictionary]) -> VueArene:
	var vue := VueArene.new()
	vue.argent = OR_ABONDANT
	vue.cout_relance = 50
	vue.offres = offres
	return vue


func _libelle(i: int, nom: String) -> Label:
	return _ui.find_child("%s%d" % [nom, i], true, false) as Label


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
	await attendre_images(2)
	jeu.placer_dans(zone)
	await attendre_images(2)
	return jeu


func _liberer(noeud: Node) -> void:
	if is_instance_valid(noeud):
		noeud.get_parent().remove_child(noeud)
		noeud.free()


# --- La carte --------------------------------------------------------------------------------


func test_la_carte_affiche_la_ligne_d_effet_avant_la_phrase_d_ambiance() -> void:
	_monter_boutique()
	var offres: Array[Dictionary] = []
	var ids_armes: Array = _donnees.armes.keys()
	ids_armes.sort()
	var ids_amelios: Array = _donnees.ameliorations.keys()
	ids_amelios.sort()
	offres.append(_offre(ids_armes[0], Types.Genre.ARME))
	offres.append(_offre(ids_armes[1], Types.Genre.ARME))
	offres.append(_offre(ids_amelios[0], Types.Genre.AMELIORATION))
	offres.append(_offre(ids_amelios[1], Types.Genre.AMELIORATION))
	_ui.afficher(_vue(offres))
	for i: int in NB_OFFRES:
		var offre := offres[i]
		var genre: int = offre["genre"]
		var effet := _libelle(i, "Effet")
		var ambiance := _libelle(i, "Description")
		verifier_non_nul(effet, "carte %d : la ligne d'effet" % i)
		verifier_non_nul(ambiance, "carte %d : la phrase d'ambiance" % i)
		if effet == null or ambiance == null:
			continue
		verifier_egal(effet.text, _ligne_carte(offre), "carte %d : texte de l'effet" % i)
		verifier_egal(
			ambiance.text, str(_entree(str(offre["id"]), genre)["description"]), "carte %d" % i
		)
		verifier(
			effet.get_index() < ambiance.get_index(),
			"carte %d : l'effet vient avant l'ambiance" % i
		)
		verifier_egal(effet.get_parent(), ambiance.get_parent(), "même colonne")


func test_l_ambiance_est_attenuee_et_l_effet_ne_l_est_pas() -> void:
	_monter_boutique()
	var offres: Array[Dictionary] = _plus_longues(NB_OFFRES)
	_ui.afficher(_vue(offres))
	for i: int in NB_OFFRES:
		var effet := _libelle(i, "Effet")
		var ambiance := _libelle(i, "Description")
		verifier_egal(
			ambiance.get_theme_color("font_color"), ThemeJeu.PARCHEMIN_ATTENU, "ambiance atténuée"
		)
		verifier_different(
			effet.get_theme_color("font_color"),
			ThemeJeu.PARCHEMIN_ATTENU,
			"effet en couleur pleine"
		)


func test_la_ligne_d_effet_n_est_jamais_tronquee() -> void:
	_monter_boutique()
	_ui.afficher(_vue(_plus_longues(NB_OFFRES)))
	for i: int in NB_OFFRES:
		var effet := _libelle(i, "Effet")
		verifier_egal(effet.max_lines_visible, -1, "carte %d : aucune limite de lignes" % i)
		verifier_different(
			effet.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "pas de points de suite"
		)
		verifier(
			effet.autowrap_mode != TextServer.AUTOWRAP_OFF, "carte %d : revient à la ligne" % i
		)


func test_la_carte_vide_n_affiche_aucun_texte() -> void:
	_monter_boutique()
	_ui.afficher(_vue([]))
	for i: int in NB_OFFRES:
		verifier_egal(_libelle(i, "Effet").text, "", "carte %d : effet vide" % i)
		verifier_egal(_libelle(i, "Description").text, "", "carte %d : ambiance vide" % i)


func test_les_lignes_d_effet_les_plus_longues_tiennent_sur_la_carte_a_chaque_resolution() -> void:
	var offres := _plus_longues(NB_OFFRES)
	for zone: Vector2 in RESOLUTIONS:
		var jeu := await _jeu_a(zone)
		jeu.boutique.afficher(_vue(offres))
		await attendre_images(2)
		jeu.placer_dans(zone)
		await attendre_images(2)
		var bandeau := jeu.boutique.rect_bandeau()
		verifier(
			jeu.boutique.rect_bandeau_minimal().y <= zone.y * MiseEnPage.PART_MAX_BOUTIQUE + 0.5,
			"à %s : le bandeau (%s) ne dépasse pas sa part maximale" % [zone, bandeau.size.y]
		)
		verifier(
			Rect2(Vector2.ZERO, zone).encloses(bandeau), "à %s : bandeau dans la fenêtre" % zone
		)
		for i: int in NB_OFFRES:
			var carte := jeu.boutique.find_child("Carte%d" % i, true, false) as Control
			var effet := jeu.boutique.find_child("Effet%d" % i, true, false) as Label
			verifier_egal(
				effet.get_visible_line_count(),
				effet.get_line_count(),
				"à %s, carte %d : toutes les lignes de l'effet sont visibles" % [zone, i]
			)
			var rect := effet.get_global_rect()
			verifier(
				carte.get_global_rect().grow(0.5).encloses(rect),
				(
					"à %s, carte %d : l'effet reste dans la carte (%s dans %s)"
					% [zone, i, rect, carte.get_global_rect()]
				)
			)
			var bouton := carte.find_children("*", "Button", true, false)[0] as Control
			verifier_faux(
				rect.intersects(bouton.get_global_rect()),
				"à %s, carte %d : l'effet ne passe pas sous le bouton" % [zone, i]
			)
		_liberer(jeu)


func test_dans_une_fenetre_basse_l_ambiance_cede_la_place_a_l_effet_et_reste_en_infobulle() -> void:
	var offres := _plus_longues(NB_OFFRES)
	for zone: Vector2 in RESOLUTIONS:
		var jeu := await _jeu_a(zone)
		jeu.boutique.afficher(_vue(offres))
		await attendre_images(2)
		for i: int in NB_OFFRES:
			var ambiance := jeu.boutique.find_child("Description%d" % i, true, false) as Label
			var carte := jeu.boutique.find_child("Carte%d" % i, true, false) as Control
			var phrase := str(_entree(str(offres[i]["id"]), int(offres[i]["genre"]))["description"])
			verifier_egal(ambiance.text, phrase, "à %s : le texte reste là" % zone)
			verifier(carte.tooltip_text.contains(phrase), "à %s : l'infobulle de la carte" % zone)
			if zone.y < BoutiqueUi.HAUTEUR_MIN_AMBIANCE:
				verifier_egal(ambiance.max_lines_visible, 0, "à %s : ambiance repliée" % zone)
			else:
				verifier_egal(ambiance.max_lines_visible, BoutiqueUi.LIGNES_AMBIANCE, "à %s" % zone)
				verifier(ambiance.size.y >= 2.0 * BoutiqueUi.HAUTEUR_LIGNE_SERREE, "à %s" % zone)
		_liberer(jeu)


# --- Les mêmes lignes ailleurs ---------------------------------------------------------------


func test_le_marche_noir_montre_l_effet_et_l_ambiance_en_infobulle() -> void:
	_monter_boutique()
	var vue := _vue([])
	vue.marche_noir_ouvert = true
	_ui.afficher(vue)
	var vus := 0
	for noeud: Node in _ui.find_children("*", "Button", true, false):
		var bouton := noeud as Button
		if not bouton.text.begins_with("Choisir"):
			continue
		vus += 1
		var trouve := false
		for id: String in _donnees.ameliorations:
			var entree: Dictionary = _donnees.ameliorations[id]
			if bouton.text.ends_with(str(entree["nom"])):
				var effet := DescriptionOffre.ligne_effet(
					entree, Types.Genre.AMELIORATION, _donnees
				)
				verifier(bouton.tooltip_text.contains(effet), "%s : l'effet en infobulle" % id)
				verifier(
					bouton.tooltip_text.contains(str(entree["description"])), "%s : l'ambiance" % id
				)
				verifier(
					(
						bouton.tooltip_text.find(effet)
						< bouton.tooltip_text.find(str(entree["description"]))
					),
					"%s : l'effet d'abord" % id
				)
				trouve = true
		verifier(trouve, "bouton « %s » reconnu" % bouton.text)
	verifier(vus > 0, "le marché noir propose des améliorations")


func test_les_armes_equipees_montrent_leur_effet_en_infobulle() -> void:
	_monter_boutique()
	var vue := _vue([])
	var ids: Array = _donnees.armes.keys()
	ids.sort()
	for id: String in ids:
		if vue.armes.size() < 8:
			vue.armes.append({"id": id, "recharge_ratio": 0.0})
	_ui.afficher(vue)
	for i: int in vue.armes.size():
		var nom := _ui.find_child("NomArme%d" % i, true, false) as Label
		var id: String = vue.armes[i]["id"]
		var entree := _entree(id, Types.Genre.ARME)
		verifier(nom.tooltip_text.contains(str(entree["nom"])), "%s : le nom" % id)
		verifier(
			nom.tooltip_text.contains(
				DescriptionOffre.ligne_effet(entree, Types.Genre.ARME, _donnees)
			),
			"%s : la ligne d'effet complète, type compris" % id
		)
