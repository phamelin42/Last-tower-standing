extends CasDeTest
## Le parcours solo, sans écran : menu, partie, achat au clavier, défaite, observation, rejouer,
## retour au menu. La simulation avance par grands pas à la main (`source._process`), jamais à
## l'horloge, pour rester sous le délai du lanceur.

const GRAINE := 2024
const PAS := 1.0
const PAS_MAX := 4000
const OR_ABONDANT := 1000000
## En solo, personne n'est en vie après la défaite : l'observation n'est pas proposée.
const ACTIONS_DEFAITE: Array[String] = ["rejouer", "quitter"]

var _donnees: Donnees
var _noeuds_avant: int = 0
var _orphelins_avant: int = 0
var _locale_avant: String = ""


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	_donnees = AidesPartie.donnees({"economie.json": [[["or_depart"], OR_ABONDANT]]})
	_noeuds_avant = _nombre_noeuds()
	_orphelins_avant = _nombre_orphelins()


func apres_chaque() -> void:
	TranslationServer.set_locale(_locale_avant)


# --- Aides ---------------------------------------------------------------------------------


func _nombre_noeuds() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _nombre_orphelins() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func _principal(solo_auto: bool = false) -> Principal:
	var principal := (load("res://scenes/principal.tscn") as PackedScene).instantiate() as Principal
	var args := ["--solo-auto"] if solo_auto else []
	principal.arguments = Arguments.lire(PackedStringArray(args))
	principal.arguments["graine"] = GRAINE
	principal.arguments["vitesse"] = 0.5
	principal.donnees = _donnees
	principal.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	arbre.root.add_child(principal)
	return principal


func _jeu_direct() -> Jeu:
	var jeu := (load("res://scenes/jeu.tscn") as PackedScene).instantiate() as Jeu
	jeu.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	jeu.nom_joueur = "Mina"
	arbre.root.add_child(jeu)
	return jeu


func _liberer(noeud: Node) -> void:
	if is_instance_valid(noeud):
		noeud.get_parent().remove_child(noeud)
		noeud.free()


func _avancer(jeu: Jeu, secondes: float) -> void:
	var t := 0.0
	while t < secondes:
		jeu.source._process(PAS)
		t += PAS


## Avance jusqu'à ce que `condition` soit vraie (borné). Faux si elle ne l'est jamais.
func _avancer_jusqua(jeu: Jeu, condition: Callable) -> bool:
	for _i: int in PAS_MAX:
		if condition.call():
			return true
		if jeu.source == null:
			return false
		jeu.source._process(PAS)
	return condition.call()


func _or_affiche(jeu: Jeu) -> int:
	var etiquettes := jeu.hud.find_children("*", "Label", true, false)
	var valeur := (etiquettes[2 * Hud.LIGNE_OR + 1] as Label).text
	return int(valeur.replace(Nombres.SEPARATEUR_MILLIERS, "").replace(" ", ""))


func _touche(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


func _vue_globale_victorieuse() -> VueGlobale:
	var g := VueGlobale.new()
	g.joueurs = [
		{
			"id": SourceLocale.ID_LOCAL,
			"nom": "Mina",
			"manche": 31,
			"eliminations": 10,
			"degats": 1000.0,
			"revenu": 20,
			"vivant": true,
			"victorieux": true
		}
	]
	g.termine = true
	g.classement = [SourceLocale.ID_LOCAL]
	return g


func _jusqua_la_defaite(jeu: Jeu) -> void:
	verifier(_avancer_jusqua(jeu, func() -> bool: return jeu.fin.visible), "défaite atteinte")


# --- Menu ----------------------------------------------------------------------------------


func test_le_menu_propose_les_quatre_boutons_et_le_nom_du_joueur() -> void:
	var textes := CsvTextes.lire("res://i18n/textes_menu.csv")
	var principal := _principal()
	var menu := principal.menu()
	verifier(menu.visible)
	verifier_egal(menu.bouton_solo.text, textes["MENU_JOUER_SEUL"])
	verifier_egal(menu.bouton_reglages.text, textes["MENU_REGLAGES"])
	verifier_egal(menu.bouton_quitter.text, textes["MENU_QUITTER"])
	verifier_egal(menu.bouton_multijoueur.text, textes["MENU_MULTIJOUEUR"])
	verifier(menu.bouton_multijoueur.text.contains("bientôt"))
	verifier(menu.bouton_multijoueur.disabled, "le multijoueur n'est pas branché")
	verifier_egal(menu.bouton_multijoueur.tooltip_text, textes["MENU_BIENTOT"])
	verifier_faux(menu.bouton_solo.disabled)
	var titres: Array[String] = []
	for noeud: Node in menu.find_children("*", "Label", true, false):
		titres.append((noeud as Label).text)
	verifier_contient(titres, "Last Tower Standing")
	_liberer(principal)


func test_le_nom_est_prerempli_depuis_les_reglages_et_garde_au_lancement() -> void:
	var chemin := dossier_temporaire().path_join("reglages.cfg")
	var r := Reglages.new()
	r.nom_joueur = "Odile"
	verifier(r.sauver(chemin))
	var principal := _principal()
	verifier_egal(principal.menu().champ_nom.text, "Odile")
	principal.menu().champ_nom.text = "Brigitte"
	principal.menu().bouton_solo.pressed.emit()
	verifier_egal(principal.jeu().nom_joueur, "Brigitte")
	verifier_egal(Reglages.charger(chemin).nom_joueur, "Brigitte")
	_liberer(principal)


func test_un_nom_vide_donne_le_nom_par_defaut() -> void:
	var principal := _principal()
	principal.menu().champ_nom.text = ""
	principal.menu().bouton_solo.pressed.emit()
	verifier_egal(
		principal.jeu().nom_joueur,
		CsvTextes.lire("res://i18n/textes_menu.csv")["MENU_NOM_PAR_DEFAUT"]
	)
	_liberer(principal)


func test_les_reglages_s_ouvrent_depuis_le_menu() -> void:
	var principal := _principal()
	principal.menu().bouton_reglages.pressed.emit()
	verifier(principal.menu().page_reglages_visible())
	_liberer(principal)


# --- Parcours complet ---------------------------------------------------------------------


func test_parcours_solo_du_menu_a_la_defaite_puis_retour_au_menu_sans_fuite() -> void:
	var principal := _principal()
	var menu := principal.menu()
	menu.bouton_solo.pressed.emit()
	var jeu := principal.jeu()
	verifier_non_nul(jeu, "la partie est ouverte")
	verifier_faux(menu.visible, "le menu laisse la place à la partie")
	_avancer(jeu, 1.0)
	var or_avant := _or_affiche(jeu)
	verifier_egal(or_avant, OR_ABONDANT, "or de départ dans le HUD")

	jeu.boutique._unhandled_input(_touche(KEY_1))
	_avancer(jeu, 1.0)
	verifier(_or_affiche(jeu) < or_avant, "acheter la première offre coûte de l'or")

	_jusqua_la_defaite(jeu)
	verifier(jeu.fin.visible)
	verifier_egal(jeu.fin.actions_visibles(), PackedStringArray(ACTIONS_DEFAITE))
	verifier_contient(
		jeu.fin.textes(), CsvTextes.lire("res://i18n/textes_fin.csv")["FIN_DEFAITE_TITRE"]
	)

	jeu.fin.presser("quitter")
	await attendre_images(2)
	verifier_nul(principal.jeu(), "la partie est fermée")
	verifier(menu.visible, "le menu est de retour")
	_liberer(principal)
	await attendre_images(2)
	verifier_egal(_nombre_noeuds(), _noeuds_avant, "aucun nœud ne fuit")
	verifier_egal(_nombre_orphelins(), _orphelins_avant, "aucun orphelin")


func test_rejouer_lance_une_partie_neuve_sans_fuite() -> void:
	var jeu := _jeu_direct()
	verifier(jeu.demarrer_solo(_donnees, GRAINE, 0.5))
	_jusqua_la_defaite(jeu)
	var noeuds_en_fin := _nombre_noeuds()
	jeu.fin.presser("rejouer")
	verifier_faux(jeu.fin.visible, "l'écran de fin se ferme")
	_avancer(jeu, 1.0)
	verifier_egal(_or_affiche(jeu), OR_ABONDANT, "une partie neuve : or de départ")
	verifier_egal(_nombre_noeuds(), noeuds_en_fin, "rejouer ne laisse aucun nœud derrière")
	_jusqua_la_defaite(jeu)
	verifier(jeu.fin.visible, "la nouvelle partie finit aussi")
	_liberer(jeu)
	await attendre_images(2)
	verifier_egal(_nombre_noeuds(), _noeuds_avant)


func test_en_solo_l_observation_n_est_pas_proposee_et_l_ouvrir_donne_un_message_sans_erreur(
) -> void:
	var jeu := _jeu_direct()
	verifier(jeu.demarrer_solo(_donnees, GRAINE, 0.5))
	_jusqua_la_defaite(jeu)
	verifier_faux(jeu.fin.actions_visibles().has("observer"), "personne à observer en solo")
	jeu._observer()
	verifier_faux(jeu.fin.visible)
	verifier(jeu.observation.visible, "l'observation prend la place")
	var textes: Array[String] = []
	for noeud: Node in jeu.observation.find_children("*", "Label", true, false):
		if (noeud as Label).is_visible_in_tree():
			textes.append((noeud as Label).text)
	verifier_contient(
		textes, CsvTextes.lire("res://i18n/textes_observation.csv")["OBSERVATION_PERSONNE"]
	)
	_liberer(jeu)


func test_la_victoire_propose_rejouer_et_le_menu_et_le_mode_sans_fin_reste_grise() -> void:
	var jeu := _jeu_direct()
	verifier(jeu.demarrer_solo(_donnees, GRAINE, 0.5))
	_avancer(jeu, 1.0)
	jeu._sur_globale(_vue_globale_victorieuse())
	verifier(jeu.fin.visible)
	verifier_egal(
		jeu.fin.actions_visibles(), PackedStringArray(["continuer_sans_fin", "rejouer", "quitter"])
	)
	verifier_contient(
		jeu.fin.textes(), CsvTextes.lire("res://i18n/textes_fin.csv")["FIN_VICTOIRE_TITRE"]
	)
	var trouve := false
	for noeud: Node in jeu.fin.find_children("*", "Button", true, false):
		var bouton := noeud as Button
		if bouton.get_meta("action", "") == "continuer_sans_fin":
			trouve = true
			verifier(bouton.disabled, "sans fin désactivé")
			verifier_egal(
				bouton.tooltip_text, CsvTextes.lire("res://i18n/textes_menu.csv")["MENU_BIENTOT"]
			)
		else:
			verifier_faux(bouton.disabled, "les autres boutons restent actifs")
	verifier(trouve)
	_liberer(jeu)


# --- Scène de jeu directe, pause, entrées --------------------------------------------------


func test_la_scene_de_jeu_se_lance_seule_avec_solo_auto() -> void:
	var principal := _principal(true)
	verifier_non_nul(principal.jeu(), "--solo-auto ouvre la partie sans passer par le menu")
	verifier_faux(principal.menu().visible)
	_avancer(principal.jeu(), 2.0)
	verifier_egal(_or_affiche(principal.jeu()), OR_ABONDANT)
	_liberer(principal)
	await attendre_images(2)
	verifier_egal(_nombre_noeuds(), _noeuds_avant)


func test_la_scene_de_jeu_refuse_sans_donnees_puis_demarre_avec() -> void:
	var jeu := _jeu_direct()
	verifier_faux(jeu.demarrer_solo(null, GRAINE, 1.0), "sans données : refus propre")
	verifier_nul(jeu.source)
	verifier(jeu.demarrer_solo(_donnees, GRAINE, 0.5), "reconstruction avec de bonnes données")
	_avancer(jeu, 1.0)
	verifier_egal(_or_affiche(jeu), OR_ABONDANT)
	_liberer(jeu)


func test_echap_ouvre_le_menu_de_jeu_et_menu_principal_revient_au_menu() -> void:
	var principal := _principal()
	principal.menu().bouton_solo.pressed.emit()
	var jeu := principal.jeu()
	var pause: Control = jeu.find_child("Pause", true, false)
	verifier_faux(pause.visible)
	jeu._unhandled_input(_touche(KEY_ESCAPE))
	verifier(pause.visible, "Échap ouvre le menu")
	jeu._unhandled_input(_touche(KEY_ESCAPE))
	verifier_faux(pause.visible, "Échap le referme")
	jeu._unhandled_input(_touche(KEY_ESCAPE))
	var boutons := pause.find_children("*", "Button", true, false)
	(boutons[1] as Button).pressed.emit()
	await attendre_images(2)
	verifier_nul(principal.jeu())
	verifier(principal.menu().visible)
	_liberer(principal)


func test_la_molette_zoome_dans_les_bornes() -> void:
	var jeu := _jeu_direct()
	verifier(jeu.demarrer_solo(_donnees, GRAINE, 0.5))
	for _i: int in 100:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		jeu._unhandled_input(e)
	verifier_proche(jeu.camera.zoom, CameraArene.ZOOM_MIN, 0.0001, "zoom avant borné")
	for _i: int in 100:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_DOWN
		e.pressed = true
		jeu._unhandled_input(e)
	verifier_proche(jeu.camera.zoom, CameraArene.ZOOM_MAX, 0.0001, "zoom arrière borné")
	_liberer(jeu)


func test_des_reglages_invalides_sont_ignores() -> void:
	var chemin := dossier_temporaire().path_join("reglages.cfg")
	var fichier := FileAccess.open(chemin, FileAccess.WRITE)
	fichier.store_string("n'importe quoi [[[")
	fichier.close()
	var jeu := _jeu_direct()
	verifier(jeu.demarrer_solo(_donnees, GRAINE, 0.5), "la partie démarre quand même")
	_liberer(jeu)
