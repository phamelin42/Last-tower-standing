extends CasDeTest
## Écran de fin : ce que la joueuse lit après la défaite ou la victoire, et ce qu'elle peut
## faire ensuite. Les textes passent par `tr()` : on enregistre `textes_fin.csv` comme le fera
## T2.7, puis on lit ce qui est affiché.

const CSV_FIN := "res://i18n/textes_fin.csv"
const SCENE_FIN := "res://scenes/fin.tscn"
const FICHIER_UI := "res://ui/fin_ui.gd"
const HAUTEUR_MIN := 48.0
const TAILLE_MIN := 16
const NOM_TRES_LONG := "Ça est un nom de joueuse extrêmement long, bien plus long que le tableau"

var _fin: FinUi
var _traduction: Translation
var _locale_avant: String = "en"


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	_traduction = Translation.new()
	_traduction.locale = "fr"
	var textes := CsvTextes.lire(CSV_FIN)
	for cle: String in textes:
		var texte: String = textes[cle]
		_traduction.add_message(cle, texte)
	TranslationServer.add_translation(_traduction)
	TranslationServer.set_locale("fr")
	_fin = (load(SCENE_FIN) as PackedScene).instantiate() as FinUi
	arbre.root.add_child(_fin)


func apres_chaque() -> void:
	# Libéré tout de suite : un nœud en attente de `queue_free` ne l'est jamais dans le lanceur.
	if is_instance_valid(_fin):
		_fin.get_parent().remove_child(_fin)
		_fin.free()
	TranslationServer.remove_translation(_traduction)
	TranslationServer.set_locale(_locale_avant)


# --- Aides ---------------------------------------------------------------------------------


func _t(cle: String) -> String:
	return TranslationServer.translate(cle)


func _vue(manche_max: int, eliminations: int, degats: float) -> VueArene:
	var vue := VueArene.new()
	vue.manche_max = manche_max
	vue.manche = manche_max
	vue.eliminations = eliminations
	vue.degats_infliges = degats
	return vue


func _joueur(id: int, nom: String, manche: int, degats: float) -> Dictionary:
	return {
		"id": id,
		"nom": nom,
		"manche": manche,
		"eliminations": 2,
		"degats": degats,
		"revenu": 40,
		"vivant": false,
		"victorieux": false,
	}


## Partie terminée dont le classement est celui qu'elle a calculé : `ordre` donne les ids dans
## l'ordre de la partie. Sans `ordre`, les joueurs sont classés dans l'ordre où ils sont donnés.
func _globale_classee(
	joueurs: Array[Dictionary], ordre: Array[int], dernier_rempart: int = -1
) -> VueGlobale:
	var vue := VueGlobale.new()
	vue.joueurs = joueurs
	vue.termine = true
	vue.dernier_rempart = dernier_rempart
	vue.classement = ordre
	return vue


func _globale(joueurs: Array[Dictionary], dernier_rempart: int = -1) -> VueGlobale:
	var ordre: Array[int] = []
	for joueur: Dictionary in joueurs:
		ordre.append(joueur["id"])
	return _globale_classee(joueurs, ordre, dernier_rempart)


func _joueurs(n: int) -> Array[Dictionary]:
	var joueurs: Array[Dictionary] = []
	for i: int in range(1, n + 1):
		joueurs.append(_joueur(i, "Joueuse %d" % i, 10 + i, 100.0 * i))
	return joueurs


func _affiche(texte: String, message: String) -> void:
	verifier(_textes().has(texte), "%s (attendu « %s »)" % [message, texte])


func _absent(texte: String, message: String) -> void:
	verifier_faux(
		_textes().has(texte), "%s (« %s » ne devrait pas être affiché)" % [message, texte]
	)


func _textes() -> PackedStringArray:
	return _fin.textes()


func _mention(fragment: String) -> bool:
	for texte: String in _textes():
		if texte.contains(fragment):
			return true
	return false


func _libelle_exact(texte: String) -> Label:
	for noeud: Node in _fin.find_children("*", "Label", true, false):
		if (noeud as Label).text == texte:
			return noeud as Label
	return null


func _bouton(action: String) -> Button:
	for noeud: Node in _fin.find_children("*", "Button", true, false):
		if noeud.has_meta("action") and noeud.get_meta("action") == action:
			return noeud as Button
	return null


# --- Défaite et victoire -------------------------------------------------------------------


func test_defaite_annonce_la_defaite_en_texte() -> void:
	_fin.afficher_defaite(_vue(7, 12, 3400.0), _globale(_joueurs(2)))
	_affiche(_t("FIN_DEFAITE_TITRE"), "la défaite est écrite, pas seulement colorée")
	_absent(_t("FIN_VICTOIRE_TITRE"), "pas de victoire affichée après une défaite")


func test_defaite_propose_rejouer_observer_et_menu_mais_pas_continuer() -> void:
	_fin.afficher_defaite(_vue(7, 12, 3400.0), _globale(_joueurs(2)))
	var visibles: PackedStringArray = _fin.actions_visibles()
	for attendu: String in ["rejouer", "observer", "quitter"]:
		verifier(visibles.has(attendu), "la défaite propose « %s »" % attendu)
	verifier_faux(visibles.has("continuer_sans_fin"), "pas de mode sans fin après une défaite")


func test_victoire_annonce_la_victoire_en_texte() -> void:
	_fin.afficher_victoire(_vue(31, 40, 98000.0), _globale(_joueurs(2)))
	_affiche(_t("FIN_VICTOIRE_TITRE"), "la victoire est écrite en texte")
	_absent(_t("FIN_DEFAITE_TITRE"), "pas de défaite affichée après une victoire")


func test_victoire_propose_continuer_sans_fin_rejouer_et_menu() -> void:
	_fin.afficher_victoire(_vue(31, 40, 98000.0), _globale(_joueurs(2)))
	var visibles: PackedStringArray = _fin.actions_visibles()
	for attendu: String in ["continuer_sans_fin", "rejouer", "quitter"]:
		verifier(visibles.has(attendu), "la victoire propose « %s »" % attendu)
	verifier_faux(visibles.has("observer"), "la victoire ne propose pas l'observation")


func test_chaque_bouton_emet_son_signal() -> void:
	var recus: Array[String] = []
	_fin.continuer_sans_fin.connect(func() -> void: recus.append("continuer_sans_fin"))
	_fin.quitter.connect(func() -> void: recus.append("quitter"))
	_fin.rejouer.connect(func() -> void: recus.append("rejouer"))
	_fin.observer.connect(func() -> void: recus.append("observer"))
	_fin.afficher_victoire(_vue(31, 1, 1.0), _globale(_joueurs(1)))
	_fin.presser("continuer_sans_fin")
	_fin.presser("rejouer")
	_fin.presser("quitter")
	verifier_egal(
		recus, ["continuer_sans_fin", "rejouer", "quitter"], "chaque bouton émet son signal"
	)


func test_recapitulatif_affiche_manche_eliminations_et_degats() -> void:
	_fin.afficher_defaite(_vue(7, 12, 3400.0), _globale(_joueurs(2)))
	_affiche(_t("FIN_RECAP_MANCHE"), "libellé de la manche atteinte")
	_affiche(_t("FIN_RECAP_ELIMINATIONS"), "libellé des éliminations")
	_affiche(_t("FIN_RECAP_DEGATS"), "libellé des dégâts")
	_affiche("7", "manche atteinte affichée")
	_affiche("12", "éliminations affichées")
	_affiche("3 400", "dégâts groupés à la française")


func test_manche_zero_et_zero_degat_s_affichent_sans_erreur() -> void:
	_fin.afficher_defaite(_vue(0, 0, 0.0), _globale([]))
	_affiche(_t("FIN_RECAP_MANCHE"), "la manche 0 a son libellé")
	_affiche("0", "manche 0 écrite en chiffre, pas en « préparation »")


# --- Classement -----------------------------------------------------------------------------


func test_classement_a_un_joueur() -> void:
	_fin.afficher_classement(_globale(_joueurs(1)), -1)
	verifier_egal(Array(_fin.noms_classes()), ["Joueuse 1"], "un seul joueur, classé seul")


func test_classement_de_1_a_8_joueurs_liste_chacun_une_fois() -> void:
	for n: int in range(1, 9):
		_fin.afficher_classement(_globale(_joueurs(n)), -1)
		verifier_egal(_fin.noms_classes().size(), n, "%d joueur(s) : une ligne par joueur" % n)


## L'écran suit l'ordre de la partie et ne le recalcule pas : ici, la partie a placé « Rapide »
## en tête alors que la règle à l'œil l'aurait mise ailleurs.
func test_classement_suit_l_ordre_de_la_partie() -> void:
	var joueurs: Array[Dictionary] = [
		_joueur(1, "Lente", 5, 900.0),
		_joueur(2, "Rapide", 9, 10.0),
		_joueur(3, "Forte", 5, 4000.0),
	]
	var ordre: Array[int] = [2, 3, 1]
	_fin.afficher_classement(_globale_classee(joueurs, ordre), -1)
	verifier_egal(
		Array(_fin.noms_classes()),
		["Rapide", "Forte", "Lente"],
		"l'ordre de la partie est affiché tel quel"
	)


## Un vainqueur à la manche du boss passe devant un joueur tombé à la même manche : la partie
## le range ainsi, l'écran l'affiche tel quel, même si les dégâts du tombé sont plus grands.
func test_victoire_passe_devant_un_tombe_de_meme_manche() -> void:
	var joueurs: Array[Dictionary] = [
		_joueur(1, "Tombée", 31, 9000.0),
		_joueur(2, "Vainqueur", 31, 100.0),
	]
	var ordre: Array[int] = [2, 1]
	_fin.afficher_classement(_globale_classee(joueurs, ordre), -1)
	verifier_egal(Array(_fin.noms_classes()), ["Vainqueur", "Tombée"], "le vainqueur est premier")


func test_egalite_se_lit_dans_l_ordre_donne_par_la_partie() -> void:
	# Égalité de manche et de dégâts : c'est l'ordre donné par la partie qui tranche.
	for n: int in range(1, 9):
		var joueurs: Array[Dictionary] = []
		var ordre: Array[int] = []
		for id: int in range(1, n + 1):
			joueurs.append(_joueur(id, "Joueuse %d" % id, 6, 500.0))
		for id: int in range(n, 0, -1):
			ordre.append(id)
		_fin.afficher_classement(_globale_classee(joueurs, ordre), -1)
		var attendu: Array = []
		for id: int in range(n, 0, -1):
			attendu.append("Joueuse %d" % id)
		verifier_egal(
			Array(_fin.noms_classes()), attendu, "%d joueurs à égalité : ordre de la partie" % n
		)


func test_classement_vide_n_affiche_pas_d_erreur() -> void:
	# Partie non classée : des joueurs existent mais la partie n'a pas (encore) de classement.
	var ordre: Array[int] = []
	_fin.afficher_classement(_globale_classee(_joueurs(2), ordre), -1)
	verifier_egal(_fin.noms_classes().size(), 0, "aucune ligne sans classement")
	_affiche(_t("FIN_CLASSEMENT_VIDE"), "un message dit que le classement est vide")


func test_joueur_local_est_signale_en_texte() -> void:
	_fin.afficher_classement(_globale(_joueurs(3)), 2)
	verifier(_mention("Joueuse 2 (" + _t("FIN_VOUS") + ")"), "la ligne locale porte « (vous) »")
	verifier_faux(
		_mention("Joueuse 1 (" + _t("FIN_VOUS") + ")"), "une autre ligne ne porte pas « (vous) »"
	)


func test_joueur_local_absent_du_classement_ne_plante_pas() -> void:
	_fin.afficher_classement(_globale(_joueurs(3)), 99)
	verifier_egal(_fin.noms_classes().size(), 3, "les autres joueurs restent classés")
	verifier_faux(_mention("(" + _t("FIN_VOUS") + ")"), "personne n'est signalé comme local")


func test_dernier_rempart_affiche_quand_il_designe_un_joueur() -> void:
	_fin.afficher_classement(_globale(_joueurs(3), 2), -1)
	_affiche(_t("FIN_DERNIER_REMPART") % "Joueuse 2", "la mention nomme le dernier rempart")


func test_dernier_rempart_absent_sans_designation() -> void:
	_fin.afficher_classement(_globale(_joueurs(3), -1), -1)
	verifier_faux(_mention(_fragment_dernier_rempart()), "pas de mention sans dernier rempart")


func test_dernier_rempart_absent_si_id_inconnu() -> void:
	_fin.afficher_classement(_globale(_joueurs(3), 42), -1)
	verifier_faux(_mention(_fragment_dernier_rempart()), "pas de mention pour un id inconnu")


func _fragment_dernier_rempart() -> String:
	return _t("FIN_DERNIER_REMPART").split("%")[0].strip_edges()


func test_noms_tres_longs_sont_tronques_sans_depasser() -> void:
	var joueurs: Array[Dictionary] = [_joueur(1, NOM_TRES_LONG, 3, 10.0)]
	_fin.afficher_classement(_globale(joueurs), -1)
	var libelle: Label = _libelle_exact(NOM_TRES_LONG)
	verifier(libelle != null, "le nom complet reste dans les données affichées")
	if libelle != null:
		verifier(libelle.clip_text, "le nom long est rogné dans sa cellule")
		verifier_egal(
			libelle.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "points de suite"
		)
		verifier(libelle.custom_minimum_size.y >= HAUTEUR_MIN, "la ligne fait 48 px au moins")


func test_grands_nombres_sont_groupes_sans_erreur() -> void:
	var joueurs: Array[Dictionary] = [_joueur(1, "Géante", 999999, 1234567890123.0)]
	_fin.afficher_classement(_globale(joueurs), -1)
	_affiche("999 999", "une manche très grande est groupée")
	_affiche("1 234 567 890 123", "des dégâts très grands sont groupés")


func test_degats_demesures_ne_plantent_pas() -> void:
	var joueurs: Array[Dictionary] = [_joueur(1, "Démesurée", 1, 1.0e30)]
	_fin.afficher_classement(_globale(joueurs), -1)
	verifier_egal(_fin.noms_classes().size(), 1, "la ligne est tout de même affichée")


# --- Textes, clavier et lisibilité ----------------------------------------------------------


func test_chaque_cle_utilisee_existe_dans_le_csv() -> void:
	var cles := CsvTextes.lire(CSV_FIN)
	var source := FileAccess.get_file_as_string(FICHIER_UI)
	var motif := RegEx.create_from_string('tr\\("([A-Z_]+)"\\)')
	var trouvees := 0
	for correspondance: RegExMatch in motif.search_all(source):
		trouvees += 1
		var cle: String = correspondance.get_string(1)
		verifier(cles.has(cle), "la clé « %s » existe dans textes_fin.csv" % cle)
	verifier(trouvees > 0, "le code utilise des clés de traduction")


func test_textes_francais_ont_des_espaces_insecables() -> void:
	var cles := CsvTextes.lire(CSV_FIN)
	for cle: String in cles:
		var texte: String = cles[cle]
		for i: int in range(1, texte.length()):
			var c: String = texte[i]
			if c in [":", ";", "?", "!"]:
				var avant: String = texte[i - 1]
				verifier(
					avant == " " or avant == " ",
					"« %s » : espace insécable avant « %s »" % [cle, c]
				)
		if texte.contains("«"):
			verifier(
				texte.contains("« ") or texte.contains("« "),
				"« %s » : espace insécable après «" % cle
			)


func test_boutons_font_48_px_de_haut() -> void:
	_fin.afficher_victoire(_vue(31, 1, 1.0), _globale(_joueurs(1)))
	for action: String in _fin.actions_visibles():
		var bouton: Button = _bouton(action)
		verifier(bouton != null, "le bouton « %s » existe" % action)
		if bouton != null:
			verifier(
				bouton.custom_minimum_size.y >= HAUTEUR_MIN, "« %s » fait 48 px au moins" % action
			)


func test_noms_au_moins_16_px() -> void:
	_fin.afficher_classement(_globale(_joueurs(2)), -1)
	var libelle: Label = _libelle_exact("Joueuse 1")
	verifier(libelle != null, "le nom est affiché")
	if libelle != null:
		verifier(
			libelle.get_theme_font_size("font_size") >= TAILLE_MIN, "le nom est lu à 16 px au moins"
		)
