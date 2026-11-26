extends CasDeTest
## Ce que le joueur voit pendant une manche : l'or, le revenu, la manche, le temps, les armures de
## la prochaine manche (en texte et en symbole), les armes et le tableau des scores. Les textes
## passent par `tr()` : on enregistre les CSV comme le fera T2.7, puis on lit ce qui est affiché.

const CSV_HUD := "res://i18n/textes_hud.csv"
const CSV_COMMUNS := "res://i18n/textes_communs.csv"
const SCENE_HUD := "res://scenes/hud.tscn"
const SCENE_SCORES := "res://scenes/scores.tscn"
const HAUTEUR_BARRE_MAX := 44.0
const RESOLUTIONS: Array[Vector2] = [
	Vector2(1152.0, 648.0), Vector2(1280.0, 720.0), Vector2(1366.0, 768.0), Vector2(1920.0, 1080.0)
]
const TAILLE_MIN := 16
const ESPACE_MILLIERS := " "
const NB_EMPLACEMENTS_TEST := 8

var _hud: Hud
var _scores: TableauScores
var _traduction: Translation
var _locale_avant: String = "en"


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	_traduction = Translation.new()
	_traduction.locale = "fr"
	for chemin: String in [CSV_HUD, CSV_COMMUNS]:
		var textes := CsvTextes.lire(chemin)
		for cle: String in textes:
			var texte: String = textes[cle]
			_traduction.add_message(cle, texte)
	TranslationServer.add_translation(_traduction)
	TranslationServer.set_locale("fr")
	_hud = (load(SCENE_HUD) as PackedScene).instantiate() as Hud
	_scores = (load(SCENE_SCORES) as PackedScene).instantiate() as TableauScores
	arbre.root.add_child(_hud)
	arbre.root.add_child(_scores)


func apres_chaque() -> void:
	# Libérés tout de suite : un nœud en attente de `queue_free` ne l'est jamais dans le lanceur.
	for noeud: Node in [_hud, _scores]:
		if is_instance_valid(noeud):
			noeud.get_parent().remove_child(noeud)
			noeud.free()
	if InputMap.has_action(TableauScores.ACTION_SCORES):
		InputMap.erase_action(TableauScores.ACTION_SCORES)
	InputMap.load_from_project_settings()
	TranslationServer.remove_translation(_traduction)
	TranslationServer.set_locale(_locale_avant)


# --- Aides ---------------------------------------------------------------------------------


func _vue(manche: int, argent: int, pv: float, pv_max: float) -> VueArene:
	var vue := VueArene.new()
	vue.manche = manche
	vue.argent = argent
	vue.tour_pv = pv
	vue.tour_pv_max = pv_max
	vue.temps_restant = 30.0
	vue.prochaine_famille = 0
	vue.prochaine_armure = Types.Armure.LEGERE
	return vue


func _armes(nombre_armes: int) -> Array[Dictionary]:
	var armes: Array[Dictionary] = []
	for i: int in nombre_armes:
		armes.append({"id": "arme_%d" % i, "recharge_ratio": 1.0})
	return armes


func _joueur(id: int, nom: String, vivant: bool) -> Dictionary:
	return {
		"id": id,
		"nom": nom,
		"manche": 3,
		"eliminations": 2,
		"degats": 1234.0,
		"revenu": 40,
		"vivant": vivant,
		"victorieux": false,
	}


func _vue_globale(joueurs: Array[Dictionary]) -> VueGlobale:
	var vue := VueGlobale.new()
	vue.joueurs = joueurs
	vue.en_cours = true
	return vue


func _textes(noeud: Node) -> PackedStringArray:
	var sortie := PackedStringArray()
	for enfant: Node in noeud.find_children("*", "Label", true, false):
		sortie.append((enfant as Label).text)
	return sortie


func _affiche(noeud: Node, texte: String, message: String) -> void:
	verifier(_textes(noeud).has(texte), "%s (attendu « %s »)" % [message, texte])


## Vrai si un libellé contient `fragment` ; sert quand le texte porte aussi un symbole.
func _affiche_partie(noeud: Node, fragment: String, message: String) -> void:
	var trouve := false
	for texte: String in _textes(noeud):
		trouve = trouve or texte.contains(fragment)
	verifier(trouve, "%s (attendu un libellé contenant « %s »)" % [message, fragment])


func _tous_les_libelles(noeud: Node) -> Array[Label]:
	var sortie: Array[Label] = []
	for enfant: Node in noeud.find_children("*", "Label", true, false):
		sortie.append(enfant as Label)
	return sortie


# --- Formatage des nombres (la fonction elle-même est testée dans test_nombres.gd) --------


func test_or_a_999_999_est_affiche_groupe() -> void:
	_hud.afficher(_vue(4, 999999, 1000.0, 1000.0))
	_affiche(_hud, "999" + ESPACE_MILLIERS + "999", "l'or doit être lisible d'un coup d'œil")


# --- HUD -------------------------------------------------------------------------------------


func test_la_barre_n_affiche_plus_les_pv_et_montre_six_informations_avec_icone() -> void:
	_hud.afficher(_vue(2, 1500, 800.0, 1000.0))
	for texte: String in _textes(_hud):
		verifier(not texte.contains(" / "), "aucun « x / y » (PV) dans la barre : « %s »" % texte)
	verifier_egal(Hud.NB_LIGNES, 6, "six informations")
	for ligne: int in Hud.NB_LIGNES:
		var icone := _hud.find_child("Icone%d" % ligne, true, false) as TextureRect
		verifier_non_nul(icone, "ligne %d : une icône" % ligne)
		verifier_non_nul(icone.texture, "ligne %d : l'icône a une image" % ligne)
		verifier(
			icone.size.x >= 0.0 and icone.custom_minimum_size.x > 0.0,
			"ligne %d : l'icône a une taille" % ligne
		)


func test_manche_zero_affiche_preparation() -> void:
	_hud.afficher(_vue(0, 500, 1000.0, 1000.0))
	_affiche(_hud, "Préparation", "avant la première manche")
	_hud.afficher(_vue(7, 500, 1000.0, 1000.0))
	_affiche(_hud, "7", "une manche numérotée")


func test_le_mode_sans_fin_se_voit_dans_la_manche() -> void:
	var vue := _vue(32, 500, 1000.0, 1000.0)
	vue.sans_fin = true
	_hud.afficher(vue)
	_affiche(_hud, "32 ∞", "manche au-delà du boss")
	vue.sans_fin = false
	_hud.afficher(vue)
	_affiche(_hud, "32", "sans le mode, pas de symbole")


func test_temps_restant_a_zero_ne_plante_pas_et_affiche_zero_seconde() -> void:
	var vue := _vue(3, 0, 1000.0, 1000.0)
	vue.temps_restant = 0.0
	_hud.afficher(vue)
	_affiche(_hud, "0 s", "temps écoulé")


func test_temps_restant_arrondi_a_la_seconde_superieure() -> void:
	var vue := _vue(3, 0, 1000.0, 1000.0)
	vue.temps_restant = 12.2
	_hud.afficher(vue)
	_affiche(_hud, "13 s", "un décompte ne montre pas la seconde déjà passée")


func test_armure_annoncee_en_texte_et_en_symbole_pour_les_six_valeurs() -> void:
	for a: int in Types.Armure.size():
		var vue := _vue(3, 0, 1000.0, 1000.0)
		vue.prochaine_armure = a
		_hud.afficher(vue)
		var attendu := Hud.libelle_armure(a)
		verifier(
			attendu.contains(Apparence.symbole_armure(a)), "l'armure %d doit porter son symbole" % a
		)
		verifier(attendu.length() > 2, "l'armure %d doit porter son libellé" % a)
		_affiche(_hud, attendu, "l'armure %d est affichée en texte et symbole" % a)


func test_aucune_famille_a_venir_affiche_aucune() -> void:
	var vue := _vue(3, 0, 1000.0, 1000.0)
	vue.prochaine_famille = -1
	_hud.afficher(vue)
	_affiche(_hud, "Aucune", "pas de prochaine famille")


func test_armes_equipees_de_zero_a_huit() -> void:
	for n: int in range(0, NB_EMPLACEMENTS_TEST + 1):
		var vue := _vue(3, 0, 1000.0, 1000.0)
		vue.armes = _armes(n)
		_hud.afficher(vue)
		_affiche(_hud, str(n), "%d arme(s) équipée(s)" % n)


func test_chaque_icone_a_un_nom_accessible_et_une_infobulle() -> void:
	var vue := _vue(3, 1500, 800.0, 1000.0)
	vue.armes = _armes(2)
	_hud.afficher(vue)
	for ligne: int in Hud.NB_LIGNES:
		var cellule := _hud.find_child("Ligne%d" % ligne, true, false) as Control
		var nom := tr(Hud.CLES_NOMS[ligne])
		verifier(not nom.is_empty() and nom != Hud.CLES_NOMS[ligne], "ligne %d : un nom" % ligne)
		verifier(cellule.tooltip_text.begins_with(nom + " : "), "ligne %d : infobulle" % ligne)
		verifier_egal(
			cellule.accessibility_name, cellule.tooltip_text, "ligne %d : accessible" % ligne
		)
		verifier_egal(cellule.mouse_filter, Control.MOUSE_FILTER_STOP, "la case reçoit la souris")
		var icone := _hud.find_child("Icone%d" % ligne, true, false) as Control
		verifier_egal(icone.accessibility_name, nom, "ligne %d : l'icône est nommée" % ligne)


func test_les_icones_de_la_barre_existent_et_le_sablier_a_sa_licence() -> void:
	verifier_egal(ThemeJeu.ICONES_HUD.size(), Hud.NB_LIGNES, "une icône par information")
	for nom: String in ThemeJeu.ICONES_HUD:
		var chemin: String = ThemeJeu.ICONES_HUD[nom]
		verifier(ResourceLoader.exists(chemin), "l'icône « %s » existe (%s)" % [nom, chemin])
		verifier_non_nul(ThemeJeu.icone_hud(nom), "l'icône « %s » se charge" % nom)
	var licence := FileAccess.get_file_as_string("res://assets/icones/sablier/LICENCE.md")
	verifier(licence.contains("CC0"), "le sablier est sous CC0 ou CC BY, et le dit")
	verifier(licence.contains("opengameart.org"), "le sablier cite sa source")


func test_la_barre_fait_au_plus_44_px_de_haut_aux_trois_resolutions() -> void:
	var vue := _vue(3, 1500, 800.0, 1000.0)
	vue.armes = _armes(2)
	_hud.afficher(vue)
	verifier(_hud.hauteur_barre() <= HAUTEUR_BARRE_MAX, "barre de %s px" % _hud.hauteur_barre())
	verifier(_hud.hauteur_barre() >= 32.0, "barre lisible")
	for libelle: Label in _tous_les_libelles(_hud):
		verifier(
			libelle.get_theme_font_size("font_size") >= TAILLE_MIN,
			"« %s » s'écrit en moins de 16 px" % libelle.text
		)


# --- Tableau des scores ----------------------------------------------------------------------


func test_tableau_affiche_chaque_joueur_a_un_et_huit_joueurs() -> void:
	for n: int in [1, 8]:
		var joueurs: Array[Dictionary] = []
		for i: int in n:
			joueurs.append(_joueur(i + 1, "Joueur %d" % (i + 1), true))
		_scores.afficher(_vue_globale(joueurs), 1)
		for i: int in n:
			var attendu := "Joueur %d" % (i + 1)
			if i == 0:
				attendu += " (vous)"
			_affiche(_scores, attendu, "%d joueur(s), ligne %d" % [n, i + 1])


func test_le_tableau_montre_revenu_dps_et_degats_totaux_pour_huit_joueurs() -> void:
	var joueurs: Array[Dictionary] = []
	for i: int in 8:
		var joueur := _joueur(i + 1, "Joueur %d" % (i + 1), true)
		joueur["revenu"] = 1200 + 111 * i
		joueur["degats"] = 1234567.0 + 1000.0 * i
		joueur["dps"] = 4321.4 + 100.0 * i
		joueurs.append(joueur)
	_scores.afficher(_vue_globale(joueurs), 1)
	verifier_egal(
		TableauScores.COLONNES, 7, "joueur, manche, éliminations, revenu, dps, dégâts, état"
	)
	for entete: String in ["Revenu / 10\u00a0s", "Dégâts par seconde", "Dégâts totaux"]:
		_affiche(_scores, entete, "l'intitulé exact « %s »" % entete)
	for i: int in 8:
		_affiche(_scores, Nombres.groupe(1200 + 111 * i), "revenu du joueur %d" % (i + 1))
		_affiche(_scores, Nombres.groupe(roundi(4321.4 + 100.0 * i)), "dps du joueur %d" % (i + 1))
		_affiche(
			_scores, Nombres.groupe(roundi(1234567.0 + 1000.0 * i)), "dégâts du joueur %d" % (i + 1)
		)
	verifier(
		_scores.get_combined_minimum_size().x <= TableauScores.LARGEUR_MAX,
		"le tableau tient dans sa largeur maximale"
	)


func test_joueur_elimine_est_marque_en_texte() -> void:
	var joueurs: Array[Dictionary] = [
		_joueur(1, "Anne", true),
		_joueur(2, "Basile", false),
	]
	_scores.afficher(_vue_globale(joueurs), 1)
	_affiche_partie(_scores, "Éliminé", "le joueur éliminé porte un libellé")
	_affiche_partie(_scores, "En vie", "le joueur vivant porte aussi son état en texte")


func test_noms_les_plus_longs_ne_debordent_pas() -> void:
	var nom_long := "Sélène-Marie-Hortense de la Roche-Fontaine des Trois Chênes"
	var joueurs: Array[Dictionary] = []
	for i: int in 8:
		joueurs.append(_joueur(i + 1, nom_long, i % 2 == 0))
	_scores.afficher(_vue_globale(joueurs), 2)
	var noms := 0
	for libelle: Label in _tous_les_libelles(_scores):
		if libelle.text.begins_with("Sélène"):
			noms += 1
			verifier(libelle.clip_text, "le nom doit être tronqué, pas dépasser")
			verifier(
				libelle.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
				"le nom long doit finir par des points de suite"
			)
	verifier_egal(noms, 8, "chaque joueur garde son nom")
	verifier(
		_scores.get_combined_minimum_size().x <= TableauScores.LARGEUR_MAX,
		"le tableau ne doit pas déborder de sa largeur"
	)


func test_action_scores_maintenue_affiche_le_tableau() -> void:
	# Les actions existent déjà dans project.godot : le test pose les siennes.
	if InputMap.has_action(TableauScores.ACTION_SCORES):
		InputMap.erase_action(TableauScores.ACTION_SCORES)
	InputMap.add_action(TableauScores.ACTION_SCORES)
	verifier_faux(_scores.visible, "caché au départ")
	Input.action_press(TableauScores.ACTION_SCORES)
	_scores._process(0.0)
	verifier(_scores.visible, "visible tant que l'action est maintenue")
	Input.action_release(TableauScores.ACTION_SCORES)
	_scores._process(0.0)
	verifier_faux(_scores.visible, "caché dès que l'action est relâchée")


func test_sans_action_declaree_le_tableau_reste_cache_sans_erreur() -> void:
	# project.godot déclare l'action ; ce test simule son absence.
	InputMap.erase_action(TableauScores.ACTION_SCORES)
	verifier_faux(InputMap.has_action(TableauScores.ACTION_SCORES), "action absente au départ")
	_scores._process(0.0)
	verifier_faux(_scores.visible, "sans action, rien ne s'affiche")


func _infobulle_prochaine() -> String:
	return (_hud.find_child("Ligne%d" % Hud.LIGNE_PROCHAINE, true, false) as Control).tooltip_text


func test_chaque_famille_convoi_et_boss_sont_nommes_en_boucle() -> void:
	var donnees := Donnees.charger()
	verifier_non_nul(donnees, "les données réelles doivent se charger")
	if donnees == null:
		return
	_hud.configurer(donnees)
	var nb := donnees.familles.size()
	for index: int in range(0, nb + 2):
		var vue := _vue(3, 0, 1000.0, 1000.0)
		vue.prochaine_famille = index
		vue.prochaine_armure = Types.Armure.LEGERE
		vue.prochaines_familles = PackedInt32Array([index])
		vue.prochaines_armures = PackedByteArray([Types.Armure.LEGERE])
		_hud.afficher(vue)
		var nom := ""
		if index < nb:
			var famille: Dictionary = donnees.familles[index]
			nom = famille["nom"]
		elif index == nb:
			nom = donnees.convoi["nom"]
		else:
			nom = donnees.boss["nom"]
		verifier(not nom.is_empty(), "l'index %d doit avoir un nom" % index)
		verifier(_infobulle_prochaine().contains(nom), "l'infobulle nomme l'entité %d" % index)
		_affiche_partie(_hud, Hud.libelle_armure(Types.Armure.LEGERE), "son armure reste annoncée")


func test_l_annonce_montre_les_armures_de_chaque_famille_suivante() -> void:
	var donnees := Donnees.charger()
	verifier_non_nul(donnees, "les données réelles doivent se charger")
	if donnees == null:
		return
	_hud.configurer(donnees)
	for nombre: int in [0, 1, 2, 3]:
		var vue := _vue(3, 0, 1000.0, 1000.0)
		vue.prochaine_famille = -1 if nombre == 0 else 0
		var familles := PackedInt32Array()
		var armures := PackedByteArray()
		for i: int in nombre:
			familles.append(i)
			armures.append(i % Types.Armure.size())
		vue.prochaines_familles = familles
		vue.prochaines_armures = armures
		_hud.afficher(vue)
		var texte := _hud.valeur(Hud.LIGNE_PROCHAINE)
		if nombre == 0:
			verifier_egal(texte, "Aucune", "vide sans famille")
			continue
		for i: int in nombre:
			verifier(
				texte.contains(Hud.libelle_armure(i % Types.Armure.size())),
				"%d famille(s) : l'armure de la famille %d" % [nombre, i]
			)
			verifier(
				_infobulle_prochaine().contains(str(donnees.familles[i]["nom"])),
				"%d famille(s) : le nom de la famille %d en infobulle" % [nombre, i]
			)


func test_le_nombre_d_armes_tient_pour_0_8_40_et_255_armes() -> void:
	for n: int in [0, 8, 40, 255]:
		var vue := _vue(3, 0, 1000.0, 1000.0)
		vue.armes = _armes(n)
		_hud.afficher(vue)
		_affiche(_hud, str(n), "%d arme(s) : un compte, sans capacité" % n)
		var cellule := _hud.find_child("Ligne%d" % Hud.LIGNE_ARMES, true, false) as Control
		verifier(cellule.get_combined_minimum_size().x < 120.0, "le compte tient à %d armes" % n)


func test_sans_configuration_le_hud_reste_lisible_sans_erreur() -> void:
	var vue := _vue(3, 0, 1000.0, 1000.0)
	vue.prochaine_famille = 2
	vue.prochaine_armure = Types.Armure.LEGERE
	vue.armes = _armes(2)
	_hud.afficher(vue)
	_affiche(_hud, Hud.libelle_armure(Types.Armure.LEGERE), "l'armure seule, sans nom")
	_affiche(_hud, "2", "le nombre d'armes, sans capacité")


# --- Textes ----------------------------------------------------------------------------------


func test_chaque_cle_hud_et_scores_du_code_existe_dans_le_csv() -> void:
	var textes := CsvTextes.lire(CSV_HUD)
	verifier(not textes.is_empty(), "le CSV des textes HUD doit se lire")
	var motif := RegEx.create_from_string('"((HUD|SCORES)_[A-Z_]+)"')
	var cles_trouvees := 0
	for fichier: String in ["res://ui/hud.gd", "res://ui/scores.gd"]:
		var source := FileAccess.get_file_as_string(fichier)
		verifier(not source.is_empty(), "%s doit exister" % fichier)
		for resultat: RegExMatch in motif.search_all(source):
			var cle := resultat.get_string(1)
			cles_trouvees += 1
			verifier(textes.has(cle), "clé absente du CSV : %s (dans %s)" % [cle, fichier])
	verifier(cles_trouvees >= 10, "le code doit référencer ses libellés par clé")
