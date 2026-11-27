extends CasDeTest
## Acheter vite (S28, Phil 27/11) : la touche de chaque offre est écrite sur son bouton et suit la
## table d'entrées, « Tout acheter » prend ce que l'or permet de la moins chère à la plus chère,
## et la touche T l'actionne comme le bouton.

const CSV_BOUTIQUE := "res://i18n/textes_boutique.csv"
const CSV_COMMUNS := "res://i18n/textes_communs.csv"
const SCENE := "res://scenes/boutique.tscn"
const ACTIONS_OFFRES: Array[String] = [
	"boutique_offre_1", "boutique_offre_2", "boutique_offre_3", "boutique_offre_4"
]

var _ui: BoutiqueUi
var _source: SourceFactice
var _donnees: Donnees
var _traduction: Translation
var _locale_avant: String = "en"


func avant_chaque() -> void:
	InputMap.load_from_project_settings()
	_locale_avant = TranslationServer.get_locale()
	_traduction = Translation.new()
	_traduction.locale = "fr"
	for chemin: String in [CSV_BOUTIQUE, CSV_COMMUNS]:
		var textes := CsvTextes.lire(chemin)
		for cle: String in textes:
			_traduction.add_message(cle, textes[cle])
	TranslationServer.add_translation(_traduction)
	TranslationServer.set_locale("fr")
	_donnees = Donnees.charger()
	_source = SourceFactice.new()
	arbre.root.add_child(_source)
	_ui = (load(SCENE) as PackedScene).instantiate() as BoutiqueUi
	arbre.root.add_child(_ui)
	_ui.configurer(_donnees, _source)


func apres_chaque() -> void:
	for noeud: Node in [_ui, _source]:
		if is_instance_valid(noeud):
			noeud.get_parent().remove_child(noeud)
			noeud.free()
	InputMap.load_from_project_settings()
	TranslationServer.remove_translation(_traduction)
	TranslationServer.set_locale(_locale_avant)


# --- Aides ---------------------------------------------------------------------------------


func _ids(table: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id: String in table:
		ids.append(id)
	ids.sort()
	return ids


## Une vue de quatre offres : trois armes et une amélioration, aux prix donnés.
func _vue(prix: Array[int], argent: int) -> VueArene:
	var vue := VueArene.new()
	vue.argent = argent
	var armes := _ids(_donnees.armes)
	var amelios := _ids(_donnees.ameliorations)
	for i: int in prix.size():
		var arme := i < 3
		(
			vue
			. offres
			. append(
				{
					"id": armes[i] if arme else amelios[0],
					"genre": Types.Genre.ARME if arme else Types.Genre.AMELIORATION,
					"rarete": Types.Rarete.COMMUNE,
					"prix": prix[i],
					"vendu": false,
				}
			)
		)
	return vue


func _bouton(nom: String) -> Button:
	return _ui.find_child(nom, true, false) as Button


func _boutons_achat() -> Array[Button]:
	var sortie: Array[Button] = []
	for noeud: Node in _ui.find_children("*", "Button", true, false):
		var b := noeud as Button
		if b.theme_type_variation in [ThemeJeu.TYPE_ACHAT, ThemeJeu.TYPE_ACHAT_INSUFFISANT]:
			sortie.append(b)
	return sortie


func _touche(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


# --- Quoi acheter --------------------------------------------------------------------------


func test_tout_acheter_prend_les_offres_de_la_moins_chere_a_la_plus_chere() -> void:
	var vue := _vue([300, 100, 500, 200], 650)
	# 100 + 200 + 300 = 600 ; 500 ne tient plus dans les 50 restants.
	verifier_egal(AchatsGroupes.ordre_tout_acheter(vue), [1, 3, 0] as Array[int])


func test_tout_acheter_a_prix_egal_suit_l_ordre_d_affichage() -> void:
	var vue := _vue([100, 100, 100, 100], 250)
	verifier_egal(AchatsGroupes.ordre_tout_acheter(vue), [0, 1] as Array[int])


func test_tout_acheter_saute_une_offre_trop_chere_et_prend_les_suivantes() -> void:
	var vue := _vue([900, 100, 100, 100], 350)
	verifier_egal(AchatsGroupes.ordre_tout_acheter(vue), [1, 2, 3] as Array[int])


func test_tout_acheter_ne_prend_ni_vendu_ni_case_vide() -> void:
	var vue := _vue([100, 100, 100, 100], 1000)
	vue.offres[0]["vendu"] = true
	vue.offres[2] = {}
	verifier_egal(AchatsGroupes.ordre_tout_acheter(vue), [1, 3] as Array[int])


func test_tout_acheter_sans_or_n_achete_rien() -> void:
	verifier_egal(AchatsGroupes.ordre_tout_acheter(_vue([100, 200, 300, 400], 99)).size(), 0)
	verifier_egal(AchatsGroupes.ordre_tout_acheter(VueArene.new()).size(), 0)


func test_tout_acheter_ecarte_une_arme_nouvelle_quand_les_emplacements_sont_pleins() -> void:
	var vue := _vue([100, 100, 100, 100], 1000)
	var ids := _ids(_donnees.armes)
	# Le maximum d'armes portées, dont celle de l'offre 1 : elle monte d'un niveau, les offres 0 et 2
	# sont des armes nouvelles, refusées par la simulation.
	vue.armes.append({"id": ids[1], "niveau": 1})
	for i: int in Inventaire.ARMES_MAX - 1:
		vue.armes.append({"id": "arme_test_%d" % i, "niveau": 1})
	verifier_egal(AchatsGroupes.ordre_tout_acheter(vue), [1, 3] as Array[int])


# --- Touches affichées ---------------------------------------------------------------------


func test_chaque_bouton_acheter_porte_la_touche_de_son_offre() -> void:
	_ui.afficher(_vue([100, 200, 300, 400], 1000))
	var boutons := _boutons_achat()
	verifier_egal(boutons.size(), 4)
	for i: int in 4:
		verifier_egal(boutons[i].text, "Acheter (%d)" % (i + 1), "offre %d" % (i + 1))


func test_la_touche_affichee_suit_la_table_d_entrees() -> void:
	InputMap.action_erase_events(ACTIONS_OFFRES[0])
	InputMap.action_add_event(ACTIONS_OFFRES[0], _touche(KEY_Q))
	_ui.afficher(_vue([100, 200, 300, 400], 1000))
	verifier_egal(_boutons_achat()[0].text, "Acheter (Q)")


func test_sans_touche_liee_le_bouton_reste_lisible() -> void:
	InputMap.action_erase_events(ACTIONS_OFFRES[2])
	_ui.afficher(_vue([100, 200, 300, 400], 1000))
	verifier_egal(_boutons_achat()[2].text, "Acheter")


# --- Le bouton et la touche ----------------------------------------------------------------


func test_le_bouton_tout_acheter_envoie_un_achat_par_offre_payee() -> void:
	_ui.afficher(_vue([300, 100, 500, 200], 650))
	_bouton("ToutAcheter").pressed.emit()
	var indices: Array[int] = []
	for appel: Dictionary in _source.appels:
		if appel["nom"] == "acheter":
			indices.append(int(appel["args"][0]))
	verifier_egal(indices, [1, 3, 0] as Array[int])


func test_la_touche_t_fait_comme_le_bouton() -> void:
	_ui.afficher(_vue([300, 100, 500, 200], 650))
	_ui._unhandled_input(_touche(KEY_T))
	var achats := 0
	for appel: Dictionary in _source.appels:
		achats += 1 if appel["nom"] == "acheter" else 0
	verifier_egal(achats, 3)


func test_le_bouton_est_grise_quand_aucune_offre_ne_se_paie() -> void:
	_ui.afficher(_vue([300, 100, 500, 200], 50))
	verifier(_bouton("ToutAcheter").disabled, "rien à acheter : le bouton est grisé")
	_ui.afficher(_vue([300, 100, 500, 200], 150))
	verifier_faux(_bouton("ToutAcheter").disabled, "une offre se paie : le bouton est actif")


func test_le_bouton_tient_sur_une_ligne_et_son_infobulle_dit_la_touche() -> void:
	_ui.afficher(_vue([100, 200, 300, 400], 1000))
	var b := _bouton("ToutAcheter")
	verifier_egal(b.text, "Tout acheter")
	verifier(b.tooltip_text.contains("Touche : T"), "l'infobulle dit la touche : " + b.tooltip_text)
	verifier(b.focus_mode != Control.FOCUS_NONE, "atteignable à la manette et au clavier")
