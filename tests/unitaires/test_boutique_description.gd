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


## Toutes les offres du catalogue, armes puis améliorations, dans l'ordre des identifiants.
func _toutes_les_offres() -> Array[Dictionary]:
	var offres: Array[Dictionary] = []
	var ids_armes: Array = _donnees.armes.keys()
	ids_armes.sort()
	for id: String in ids_armes:
		offres.append(_offre(id, Types.Genre.ARME))
	var ids_amelios: Array = _donnees.ameliorations.keys()
	ids_amelios.sort()
	for id: String in ids_amelios:
		offres.append(_offre(id, Types.Genre.AMELIORATION))
	return offres


## D13 : la carte est compacte, l'effet entier et l'ambiance se lisent dans son infobulle.
func test_l_infobulle_de_chaque_offre_donne_l_effet_entier_puis_l_ambiance() -> void:
	_monter_boutique()
	var toutes := _toutes_les_offres()
	var i := 0
	while i < toutes.size():
		var lot: Array[Dictionary] = []
		for k: int in NB_OFFRES:
			if i + k < toutes.size():
				lot.append(toutes[i + k])
		_ui.afficher(_vue(lot))
		for k: int in lot.size():
			var offre := lot[k]
			var genre: int = offre["genre"]
			var entree := _entree(str(offre["id"]), genre)
			var carte := _ui.find_child("Carte%d" % k, true, false) as Control
			var effet := DescriptionOffre.ligne_effet(entree, genre, _donnees)
			var ambiance := str(entree["description"])
			var texte := carte.tooltip_text
			verifier(texte.contains(effet), "%s : l'effet entier" % offre["id"])
			verifier(texte.contains(ambiance), "%s : l'ambiance" % offre["id"])
			verifier(texte.find(effet) < texte.find(ambiance), "%s : l'effet d'abord" % offre["id"])
			verifier_egal(
				carte.mouse_filter, Control.MOUSE_FILTER_STOP, "la carte reçoit la souris"
			)
		i += NB_OFFRES


func test_la_carte_ne_porte_plus_ni_ligne_d_effet_ni_ambiance() -> void:
	_monter_boutique()
	_ui.afficher(_vue(_plus_longues(NB_OFFRES)))
	for k: int in NB_OFFRES:
		verifier_nul(_libelle(k, "Effet"), "carte %d : pas de ligne d'effet" % k)
		verifier_nul(_libelle(k, "Description"), "carte %d : pas d'ambiance" % k)


func test_l_infobulle_se_lit_a_16_px_au_moins() -> void:
	var theme := ThemeJeu.creer()
	verifier(theme.get_font_size("font_size", "TooltipLabel") >= 16, "texte de l'infobulle")


func test_la_carte_vide_n_affiche_aucun_texte() -> void:
	_monter_boutique()
	_ui.afficher(_vue([]))
	for i: int in NB_OFFRES:
		verifier_egal(_libelle(i, "Nom").text, "", "carte %d : nom vide" % i)
		verifier_egal(
			(_ui.find_child("Carte%d" % i, true, false) as Control).tooltip_text,
			"",
			"carte %d : infobulle vide" % i
		)


## Les offres les plus longues, aux résolutions et aux crans extrêmes de la taille de
## l'interface (la fenêtre logique mesure la résolution divisée par l'échelle) : le bandeau reste
## sous sa part maximale et rien de la carte ne sort d'elle ni ne passe sous le bouton.
func test_les_cartes_les_plus_chargees_tiennent_a_chaque_resolution_et_a_75_et_125_pour_cent(
) -> void:
	var offres := _plus_longues(NB_OFFRES)
	for echelle: float in [0.75, 1.25]:
		for resolution: Vector2 in RESOLUTIONS:
			var zone := resolution / echelle
			var jeu := await _jeu_a(zone)
			jeu.boutique.afficher(_vue(offres))
			await attendre_images(2)
			jeu.placer_dans(zone)
			await attendre_images(2)
			var bandeau := jeu.boutique.rect_bandeau()
			var contexte := "à %s, échelle %s" % [resolution, echelle]
			verifier(
				(
					jeu.boutique.rect_bandeau_minimal().y
					<= zone.y * MiseEnPage.PART_MAX_BOUTIQUE + 0.5
				),
				"%s : le bandeau (%s) ne dépasse pas sa part maximale" % [contexte, bandeau.size.y]
			)
			verifier(
				Rect2(Vector2.ZERO, zone).encloses(bandeau),
				"%s : bandeau dans la fenêtre" % contexte
			)
			for i: int in NB_OFFRES:
				var carte := jeu.boutique.find_child("Carte%d" % i, true, false) as Control
				var bouton := carte.find_children("*", "Button", true, false)[0] as Control
				for nom: String in ["Nom", "Rarete", "Prix"]:
					var libelle := jeu.boutique.find_child("%s%d" % [nom, i], true, false) as Label
					var rect := libelle.get_global_rect()
					verifier(
						carte.get_global_rect().grow(0.5).encloses(rect),
						"%s, carte %d : %s reste dans la carte" % [contexte, i, nom]
					)
					verifier_faux(
						rect.intersects(bouton.get_global_rect()),
						"%s, carte %d : %s ne passe pas sous le bouton" % [contexte, i, nom]
					)
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
