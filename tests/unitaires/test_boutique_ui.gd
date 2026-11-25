extends CasDeTest
## Ce que la joueuse voit et peut faire dans la boutique : quatre cartes lisibles (rareté en
## texte et en couleur), achat, relance, vente, marché noir, raccourcis 1 à 4 et R. Les
## intentions sont notées par `SourceFactice`.

const CSV_BOUTIQUE := "res://i18n/textes_boutique.csv"
const CSV_COMMUNS := "res://i18n/textes_communs.csv"
const SCENE := "res://scenes/boutique.tscn"
const HAUTEUR_MIN := 48.0
const TAILLE_MIN := 16
const NB_OFFRES := 4
const NB_ARMES := 8
const ACTIONS_OFFRES: Array[String] = [
	"boutique_offre_1", "boutique_offre_2", "boutique_offre_3", "boutique_offre_4"
]
const TOUCHES_OFFRES: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]

var _ui: BoutiqueUi
var _source: SourceFactice
var _donnees: Donnees
var _traduction: Translation
var _locale_avant: String = "en"
var _champ: LineEdit = null


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
	for i: int in NB_OFFRES:
		_lier_action(ACTIONS_OFFRES[i], TOUCHES_OFFRES[i])
	_lier_action(BoutiqueUi.ACTION_RELANCER, KEY_R)
	_donnees = Donnees.charger()
	_source = SourceFactice.new()
	arbre.root.add_child(_source)
	_ui = (load(SCENE) as PackedScene).instantiate() as BoutiqueUi
	arbre.root.add_child(_ui)
	_ui.configurer(_donnees, _source)


func apres_chaque() -> void:
	for noeud: Node in [_champ, _ui, _source]:
		if is_instance_valid(noeud):
			noeud.get_parent().remove_child(noeud)
			noeud.free()
	_champ = null
	for action: String in ACTIONS_OFFRES + [BoutiqueUi.ACTION_RELANCER]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	InputMap.load_from_project_settings()
	TranslationServer.remove_translation(_traduction)
	TranslationServer.set_locale(_locale_avant)


# --- Aides ---------------------------------------------------------------------------------


func _lier_action(action: String, touche: Key) -> void:
	# Les actions existent déjà dans project.godot : le test pose les siennes.
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	var evenement := InputEventKey.new()
	evenement.keycode = touche
	InputMap.action_add_event(action, evenement)


func _touche(code: Key, pressee: bool = true, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressee
	e.echo = echo
	return e


func _ids_armes() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _donnees.armes:
		ids.append(id)
	ids.sort()
	return ids


func _ids_amelios() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _donnees.ameliorations:
		ids.append(id)
	ids.sort()
	return ids


func _offre(id: String, genre: int, rarete: int, prix: int, vendu: bool = false) -> Dictionary:
	return {"id": id, "genre": genre, "rarete": rarete, "prix": prix, "vendu": vendu}


## Quatre offres : trois armes et une amélioration, une rareté chacune.
func _vue(argent: int = 5000) -> VueArene:
	var vue := VueArene.new()
	vue.argent = argent
	vue.cout_relance = 50
	var armes := _ids_armes()
	var amelios := _ids_amelios()
	vue.offres = [
		_offre(armes[0], Types.Genre.ARME, Types.Rarete.COMMUNE, 80),
		_offre(armes[1], Types.Genre.ARME, Types.Rarete.PEU_COMMUNE, 200),
		_offre(armes[2], Types.Genre.ARME, Types.Rarete.RARE, 900),
		_offre(amelios[0], Types.Genre.AMELIORATION, Types.Rarete.EPIQUE, 1500),
	]
	return vue


func _vue_armes(n: int) -> VueArene:
	var vue := _vue()
	var ids := _ids_armes()
	for i: int in n:
		vue.armes.append({"id": ids[i % ids.size()], "recharge_ratio": 0.0})
	return vue


func _voit(noeud: CanvasItem) -> bool:
	return noeud.is_visible_in_tree()


func _boutons(texte: String) -> Array[Button]:
	var sortie: Array[Button] = []
	for noeud: Node in _ui.find_children("*", "Button", true, false):
		var b := noeud as Button
		if _voit(b) and b.text.begins_with(texte):
			sortie.append(b)
	return sortie


func _textes() -> PackedStringArray:
	var sortie := PackedStringArray()
	for noeud: Node in _ui.find_children("*", "Label", true, false):
		var l := noeud as Label
		if _voit(l):
			sortie.append(l.text)
	for noeud: Node in _ui.find_children("*", "Button", true, false):
		var b := noeud as Button
		if _voit(b):
			sortie.append(b.text)
	return sortie


func _affiche_partie(fragment: String, message: String) -> void:
	var trouve := false
	for t: String in _textes():
		trouve = trouve or t.contains(fragment)
	verifier(trouve, "%s (attendu un texte contenant « %s »)" % [message, fragment])


func _n_affiche_pas(fragment: String, message: String) -> void:
	var trouve := false
	for t: String in _textes():
		trouve = trouve or t.contains(fragment)
	verifier_faux(trouve, "%s (« %s » ne doit pas apparaître)" % [message, fragment])


func _appels(nom: String) -> Array[Dictionary]:
	var sortie: Array[Dictionary] = []
	for a: Dictionary in _source.appels:
		if a["nom"] == nom:
			sortie.append(a)
	return sortie


func _texte_carte(i: int) -> String:
	var carte := _ui.find_child("Carte%d" % i, true, false)
	verifier_non_nul(carte, "la carte %d existe" % i)
	if carte == null:
		return ""
	var morceaux := PackedStringArray()
	for noeud: Node in carte.find_children("*", "Label", true, false):
		var l := noeud as Label
		morceaux.append(l.text if l.visible else "")
	return "\n".join(morceaux)


# --- Cartes ----------------------------------------------------------------------------------


func test_quatre_cartes_avec_nom_rarete_prix_type_et_description() -> void:
	verifier_non_nul(_donnees, "les données réelles doivent se charger")
	var vue := _vue()
	_ui.afficher(vue)
	for i: int in NB_OFFRES:
		var offre: Dictionary = vue.offres[i]
		var texte := _texte_carte(i)
		var id: String = offre["id"]
		var entree: Dictionary = (
			_donnees.armes[id] if offre["genre"] == Types.Genre.ARME else _donnees.ameliorations[id]
		)
		var nom: String = entree["nom"]
		var description: String = entree["description"]
		verifier(texte.contains(nom), "carte %d : le nom" % i)
		verifier(texte.contains(description), "carte %d : la description" % i)
		verifier(texte.contains(Nombres.groupe(int(offre["prix"]))), "carte %d : le prix" % i)
		var rarete: int = offre["rarete"]
		var libelle: String = _traduction.get_message(Apparence.cle_libelle_rarete(rarete))
		verifier(texte.contains(libelle), "carte %d : la rareté en texte (%s)" % [i, libelle])
		verifier(texte.contains(Apparence.symbole_rarete(rarete)), "carte %d : le symbole" % i)
	var arme: Dictionary = _donnees.armes[vue.offres[0]["id"]]
	var type_arme: int = int(arme["type_degats"])
	var libelle_type: String = _traduction.get_message(
		"BOUTIQUE_TYPE_" + Types.TypeDegats.keys()[type_arme]
	)
	verifier(not libelle_type.is_empty(), "le type de dégâts a un libellé")
	verifier(_texte_carte(0).contains(libelle_type), "le type de dégâts d'une arme est écrit")


func test_la_rarete_est_ecrite_et_coloree_pour_chaque_rarete_en_boucle() -> void:
	for r: int in [
		Types.Rarete.COMMUNE, Types.Rarete.PEU_COMMUNE, Types.Rarete.RARE, Types.Rarete.EPIQUE
	]:
		var vue := _vue()
		vue.offres[0]["rarete"] = r
		_ui.afficher(vue)
		var libelle: String = _traduction.get_message(Apparence.cle_libelle_rarete(r))
		verifier(not libelle.is_empty(), "la rareté %d a un libellé" % r)
		verifier(_texte_carte(0).contains(libelle), "rareté %d écrite" % r)
		var etiquette := _ui.find_child("Rarete0", true, false) as Label
		verifier_non_nul(etiquette, "l'étiquette de rareté de la carte 0")
		if etiquette != null:
			verifier_egal(
				etiquette.get_theme_color("font_color"),
				Apparence.couleur_rarete(r),
				"rareté %d colorée" % r
			)


func test_chaque_arme_et_amelioration_reelle_s_affiche_en_boucle() -> void:
	for id: String in _donnees.armes:
		var vue := _vue()
		vue.offres[0] = _offre(id, Types.Genre.ARME, Types.Rarete.COMMUNE, 100)
		_ui.afficher(vue)
		var arme: Dictionary = _donnees.armes[id]
		var nom: String = arme["nom"]
		verifier(_texte_carte(0).contains(nom), "arme %s" % id)
	for id: String in _donnees.ameliorations:
		var vue := _vue()
		vue.offres[3] = _offre(id, Types.Genre.AMELIORATION, Types.Rarete.COMMUNE, 100)
		_ui.afficher(vue)
		var amelio: Dictionary = _donnees.ameliorations[id]
		var nom: String = amelio["nom"]
		verifier(_texte_carte(3).contains(nom), "amélioration %s" % id)


func test_carte_vendue_est_grisee_et_marquee_en_texte() -> void:
	var vue := _vue()
	vue.offres[1]["vendu"] = true
	_ui.afficher(vue)
	verifier(_texte_carte(1).contains("Vendu"), "le mot « Vendu » est écrit")
	verifier_faux(_texte_carte(0).contains("Vendu"), "les autres cartes ne sont pas vendues")
	var carte := _ui.find_child("Carte1", true, false) as Control
	verifier(carte.modulate.a < 1.0, "la carte vendue est grisée")
	verifier_egal((_ui.find_child("Carte0", true, false) as Control).modulate.a, 1.0)
	_ui.acheter_offre(1)
	verifier_egal(_appels("acheter").size(), 0, "une carte vendue n'envoie rien")


func test_offre_trop_chere_reste_cliquable_et_annonce_or_insuffisant() -> void:
	var vue := _vue(100)
	_ui.afficher(vue)
	verifier_faux(_texte_carte(0).contains("insuffisant"), "80 or avec 100 : pas de motif")
	for i: int in range(1, NB_OFFRES):
		verifier(_texte_carte(i).contains("Or insuffisant"), "carte %d trop chère" % i)
	var achats := _boutons("Acheter")
	verifier_egal(achats.size(), NB_OFFRES)
	for b: Button in achats:
		verifier_faux(b.disabled, "un bouton d'achat reste cliquable")
		verifier(b.focus_mode == Control.FOCUS_ALL, "et focalisable")
	achats[3].pressed.emit()
	verifier_egal(_appels("acheter").size(), 1, "l'achat part quand même, la source tranche")


func test_armes_pleines_annonce_sur_une_arme_et_pas_sur_une_amelioration() -> void:
	_ui.afficher(_vue_armes(NB_ARMES))
	for i: int in range(0, 3):
		verifier(_texte_carte(i).contains("Emplacements pleins"), "arme %d" % i)
	verifier_faux(_texte_carte(3).contains("Emplacements pleins"), "pas sur une amélioration")
	_ui.afficher(_vue_armes(NB_ARMES - 1))
	verifier_faux(_texte_carte(0).contains("Emplacements pleins"), "un emplacement libre")


# --- Intentions ------------------------------------------------------------------------------


func test_chaque_bouton_acheter_appelle_son_indice_en_boucle() -> void:
	_ui.afficher(_vue())
	var achats := _boutons("Acheter")
	verifier_egal(achats.size(), NB_OFFRES, "un bouton Acheter par carte")
	for i: int in achats.size():
		achats[i].pressed.emit()
		verifier_egal(_source.appels.size(), i + 1)
		verifier_egal(_source.appels[i], {"nom": "acheter", "args": [i]}, "carte %d" % i)


func test_chaque_raccourci_achete_la_bonne_carte_en_boucle() -> void:
	_ui.afficher(_vue())
	for i: int in NB_OFFRES:
		_ui._unhandled_input(_touche(TOUCHES_OFFRES[i]))
		verifier_egal(_source.appels.size(), i + 1, "touche %d" % (i + 1))
		verifier_egal(_source.appels[i], {"nom": "acheter", "args": [i]}, "touche %d" % (i + 1))


func test_raccourci_r_relance_et_bouton_relancer_aussi() -> void:
	_ui.afficher(_vue())
	_ui._unhandled_input(_touche(KEY_R))
	_boutons("Relancer")[0].pressed.emit()
	verifier_egal(_appels("relancer").size(), 2, "R et le bouton relancent")


func test_touches_hors_boutique_ou_relachees_sont_ignorees() -> void:
	_ui.afficher(_vue())
	for code: Key in [KEY_5, KEY_0, KEY_TAB, KEY_A, KEY_ENTER]:
		_ui._unhandled_input(_touche(code))
	_ui._unhandled_input(_touche(KEY_1, false))
	_ui._unhandled_input(_touche(KEY_1, true, true))
	verifier_egal(_source.appels.size(), 0, "aucune intention")


func test_touche_ignoree_pendant_la_saisie_d_un_champ() -> void:
	_ui.afficher(_vue())
	_champ = LineEdit.new()
	arbre.root.add_child(_champ)
	_champ.grab_focus()
	verifier_egal(arbre.root.gui_get_focus_owner(), _champ, "le champ a le vrai focus")
	_ui._unhandled_input(_touche(KEY_1))
	_ui._unhandled_input(_touche(KEY_R))
	verifier_egal(_source.appels.size(), 0, "pendant la saisie, rien ne part")
	_champ.release_focus()
	_ui._unhandled_input(_touche(KEY_1))
	verifier_egal(_source.appels.size(), 1, "sans champ actif, la touche agit")


func test_touche_ignoree_si_la_boutique_est_masquee() -> void:
	_ui.afficher(_vue())
	_ui.visible = false
	_ui._unhandled_input(_touche(KEY_1))
	_ui._unhandled_input(_touche(KEY_R))
	verifier_egal(_source.appels.size(), 0, "boutique masquée")


func test_raccourci_sans_offre_ne_fait_rien() -> void:
	_ui.afficher(VueArene.new())
	_ui._unhandled_input(_touche(KEY_1))
	verifier_egal(_appels("acheter").size(), 0, "pas d'offre à l'indice 0")


# --- Relance ---------------------------------------------------------------------------------


func test_relance_affiche_son_cout() -> void:
	var vue := _vue()
	vue.cout_relance = 75
	_ui.afficher(vue)
	var bouton := _boutons("Relancer")[0]
	verifier(bouton.text.contains("75"), "le coût est dans le bouton : %s" % bouton.text)
	vue.cout_relance = 12500
	_ui.afficher(vue)
	verifier(
		_boutons("Relancer")[0].text.contains(Nombres.groupe(12500)),
		"le coût est groupé par milliers"
	)
	vue.cout_relance = 75
	_ui.afficher(vue)
	verifier_faux(bouton.text.contains("gratuite"))


func test_relance_gratuite_affichee_gratuite() -> void:
	var vue := _vue(0)
	vue.relances_gratuites = 2
	_ui.afficher(vue)
	var bouton := _boutons("Relancer")[0]
	verifier(bouton.text.contains("gratuite"), "texte : %s" % bouton.text)
	verifier_faux(bouton.text.contains("50"), "pas de prix quand c'est gratuit")
	var note := _ui.find_child("NoteRelance", true, false) as Label
	verifier_non_nul(note, "la note de relance")
	verifier(note.text.is_empty(), "gratuite : pas de motif d'or sur la relance")


func test_relance_a_zero_or_annonce_or_insuffisant_et_reste_cliquable() -> void:
	_ui.afficher(_vue(0))
	var bouton := _boutons("Relancer")[0]
	verifier_faux(bouton.disabled, "le bouton reste cliquable")
	var note := _ui.find_child("NoteRelance", true, false) as Label
	verifier_non_nul(note, "la note de relance")
	verifier(note.text.contains("Or insuffisant"), "motif écrit")
	bouton.pressed.emit()
	verifier_egal(_appels("relancer").size(), 1)


# --- Armes équipées --------------------------------------------------------------------------


func test_chaque_arme_equipee_a_son_bouton_vendre_et_son_prix_en_boucle() -> void:
	var vue := _vue_armes(NB_ARMES)
	_ui.afficher(vue)
	var ventes := _boutons("Vendre")
	verifier_egal(ventes.size(), NB_ARMES, "un bouton Vendre par arme")
	var ratio: float = float(_donnees.partie["vente_ratio"])
	for i: int in ventes.size():
		var arme: Dictionary = _donnees.armes[vue.armes[i]["id"]]
		var prix: int = floori(float(int(arme["prix"])) * ratio)
		var nom: String = arme["nom"]
		var ligne := ventes[i].get_parent()
		var texte := ""
		for l: Node in ligne.find_children("*", "Label", true, false):
			texte += (l as Label).text
		texte += ventes[i].text
		verifier(texte.contains(Nombres.groupe(prix)), "prix de vente de l'arme %d" % i)
		verifier(texte.contains(nom), "le nom de l'arme %d est sur sa ligne" % i)
		ventes[i].pressed.emit()
		verifier_egal(_source.appels[i], {"nom": "vendre", "args": [i]}, "arme %d" % i)


func test_sans_arme_aucun_bouton_vendre() -> void:
	_ui.afficher(_vue())
	verifier_egal(_boutons("Vendre").size(), 0)
	_affiche_partie("Aucune arme", "la liste vide est dite en texte")


# --- Marché noir -----------------------------------------------------------------------------


func test_marche_noir_ferme_pas_de_liste() -> void:
	_ui.afficher(_vue())
	verifier_egal(_boutons("Choisir").size(), 0, "aucun choix visible")


func test_marche_noir_ouvert_liste_les_choix_et_appelle_le_choix() -> void:
	var vue := _vue()
	vue.marche_noir_ouvert = true
	_ui.afficher(vue)
	var choix := _boutons("Choisir")
	verifier(choix.size() > 0, "des choix sont proposés")
	var noir: Dictionary = _donnees.boutique["marche_noir"]
	var max_rarete := Types.rarete_depuis_nom(str(noir["raretes_max"]))
	var attendus: Array[String] = []
	for id: String in _donnees.ameliorations:
		var a: Dictionary = _donnees.ameliorations[id]
		if int(a["rarete"]) <= max_rarete:
			attendus.append(id)
	attendus.sort()
	verifier_egal(choix.size(), attendus.size(), "toutes les améliorations admises, rien de plus")
	for i: int in choix.size():
		choix[i].pressed.emit()
		verifier_egal(
			_source.appels[i], {"nom": "choisir_marche_noir", "args": [attendus[i]]}, "choix %d" % i
		)
	vue.marche_noir_ouvert = false
	_ui.afficher(vue)
	verifier_egal(_boutons("Choisir").size(), 0, "refermé avec la vue")


# --- Résultats -------------------------------------------------------------------------------


func test_chaque_code_de_resultat_affiche_un_message_texte_en_boucle() -> void:
	_ui.afficher(_vue())
	var vus: Array[String] = []
	for nom: String in Types.Resultat.keys():
		var code: int = Types.Resultat[nom]
		_source.emettre_resultat("acheter", code)
		var etiquette := _ui.find_child("Message", true, false) as Label
		verifier_non_nul(etiquette, "l'étiquette de message")
		verifier(not etiquette.text.is_empty(), "code %s : un message" % nom)
		verifier_faux(etiquette.text.begins_with("BOUTIQUE_"), "code %s : traduit" % nom)
		verifier_faux(vus.has(etiquette.text), "code %s : message distinct" % nom)
		vus.append(etiquette.text)


func test_un_code_inconnu_affiche_quand_meme_un_message() -> void:
	_source.emettre_resultat("acheter", 999)
	var etiquette := _ui.find_child("Message", true, false) as Label
	verifier(not etiquette.text.is_empty(), "message de repli")


# --- Robustesse ------------------------------------------------------------------------------


func test_vue_sans_offre_ni_arme_ne_fait_pas_planter() -> void:
	_ui.afficher(VueArene.new())
	verifier_egal(_boutons("Acheter").size(), NB_OFFRES, "les quatre cartes restent là")
	verifier_egal(_boutons("Vendre").size(), 0)
	_ui.acheter_offre(0)
	_ui.acheter_offre(99)
	_ui.acheter_offre(-1)
	verifier_egal(_source.appels.size(), 0)


func test_avant_configuration_afficher_ne_plante_pas() -> void:
	var nu := BoutiqueUi.new()
	arbre.root.add_child(nu)
	nu.afficher(_vue())
	nu.afficher(VueArene.new())
	nu.get_parent().remove_child(nu)
	nu.free()
	verifier(true)


func test_une_arme_ou_offre_inconnue_ne_plante_pas() -> void:
	var vue := _vue()
	vue.offres[0] = _offre("inconnue", Types.Genre.ARME, Types.Rarete.COMMUNE, 10)
	vue.armes = [{"id": "fantome", "recharge_ratio": 0.0}]
	_ui.afficher(vue)
	verifier_egal(_boutons("Vendre").size(), 1)


# --- Lisibilité ------------------------------------------------------------------------------


func test_controles_de_48_px_et_textes_de_16_px_au_moins() -> void:
	var vue := _vue_armes(NB_ARMES)
	vue.marche_noir_ouvert = true
	_ui.afficher(vue)
	for noeud: Node in _ui.find_children("*", "Button", true, false):
		var b := noeud as Button
		verifier(b.custom_minimum_size.y >= HAUTEUR_MIN, "bouton « %s » : hauteur" % b.text)
		verifier(b.get_theme_font_size("font_size") >= TAILLE_MIN, "bouton « %s » : texte" % b.text)
	for noeud: Node in _ui.find_children("*", "Label", true, false):
		var l := noeud as Label
		verifier(l.get_theme_font_size("font_size") >= TAILLE_MIN, "libellé « %s »" % l.text)


func test_noms_et_descriptions_passent_a_la_ligne_sans_deborder() -> void:
	_ui.afficher(_vue())
	for i: int in NB_OFFRES:
		for nom_noeud: String in ["Nom%d" % i, "Description%d" % i]:
			var l := _ui.find_child(nom_noeud, true, false) as Label
			verifier_non_nul(l, nom_noeud)
			if l != null:
				verifier(
					l.autowrap_mode != TextServer.AUTOWRAP_OFF, "%s revient à la ligne" % nom_noeud
				)
				verifier(l.custom_minimum_size.x > 0.0, "%s a une largeur bornée" % nom_noeud)


# --- Textes ----------------------------------------------------------------------------------


func test_chaque_cle_du_code_existe_dans_les_csv() -> void:
	var textes := CsvTextes.lire(CSV_BOUTIQUE)
	var communs := CsvTextes.lire(CSV_COMMUNS)
	verifier(not textes.is_empty(), "le CSV boutique se lit")
	var source := FileAccess.get_file_as_string("res://ui/boutique_ui.gd")
	verifier(not source.is_empty(), "boutique_ui.gd existe")
	var motif := RegEx.create_from_string('"(BOUTIQUE_[A-Z_0-9]+)"')
	var trouvees := 0
	for r: RegExMatch in motif.search_all(source):
		trouvees += 1
		verifier(textes.has(r.get_string(1)), "clé absente : %s" % r.get_string(1))
	verifier(trouvees >= 10, "le code référence ses libellés par clé")
	for r: int in [0, 1, 2, 3]:
		verifier(communs.has(Apparence.cle_libelle_rarete(r)), "rareté %d dans les communs" % r)
	# Les clés composées (types de dégâts, codes de résultat) se vérifient une à une.
	for nom: String in Types.TypeDegats.keys():
		verifier(textes.has("BOUTIQUE_TYPE_" + nom), "type %s" % nom)
	for nom: String in Types.Resultat.keys():
		verifier(textes.has("BOUTIQUE_RESULTAT_" + nom), "résultat %s" % nom)
