extends CasDeTest
## D23 (§6.17.4) : une arme déjà portée n'est plus un doublon muet. Son offre dit « niv. N → N + 1 »
## et les dégâts gagnés ; la grille des armes montre une icône par arme distincte, avec son niveau.

const CSV_BOUTIQUE := "res://i18n/textes_boutique.csv"
const CSV_COMMUNS := "res://i18n/textes_communs.csv"
const SCENE := "res://scenes/boutique.tscn"

var _ui: BoutiqueUi
var _source: SourceFactice
var _donnees: Donnees
var _traduction: Translation
var _locale_avant: String = "en"


func avant_chaque() -> void:
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
	TranslationServer.remove_translation(_traduction)
	TranslationServer.set_locale(_locale_avant)


func _ids_armes() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _donnees.armes:
		ids.append(id)
	ids.sort()
	return ids


## Une vue dont la première offre est l'arme `id`, portée au niveau `niveau` (0 : non portée).
func _vue_avec(id: String, niveau: int, argent: int = 100000) -> VueArene:
	var vue := VueArene.new()
	vue.argent = argent
	vue.cout_relance = 50
	var fiche: Dictionary = _donnees.armes[id]
	vue.offres = [
		{
			"id": id,
			"genre": Types.Genre.ARME,
			"rarete": int(fiche["rarete"]),
			"prix": int(fiche["prix"]),
			"vendu": false,
		}
	]
	if niveau > 0:
		vue.armes.append({"id": id, "recharge_ratio": 0.0, "niveau": niveau})
	return vue


func _texte_carte(i: int) -> String:
	var carte := _ui.find_child("Carte%d" % i, true, false)
	verifier_non_nul(carte)
	var morceaux := PackedStringArray()
	for noeud: Node in carte.find_children("*", "Label", true, false):
		var l := noeud as Label
		morceaux.append(l.text if l.visible else "")
	return "\n".join(morceaux)


func test_l_offre_d_une_arme_portee_dit_son_niveau_et_les_degats_gagnes() -> void:
	for id: String in _ids_armes():
		_ui.afficher(_vue_avec(id, 2))
		var texte := _texte_carte(0)
		var gain := roundi(float((_donnees.armes[id] as Dictionary)["degats"]) * 0.30)
		var attendu := "Niv. 2 → 3 : +%s" % Nombres.groupe(gain)
		verifier(texte.contains(attendu), "%s : « %s » absent de « %s »" % [id, attendu, texte])
		var infobulle: String = (_ui.find_child("Carte0", true, false) as Control).tooltip_text
		verifier(
			infobulle.contains("+%s dégâts" % Nombres.groupe(gain)),
			"%s : gain dans l'infobulle" % id
		)


func test_une_arme_non_portee_ou_une_amelioration_n_affiche_aucun_niveau() -> void:
	var id := _ids_armes()[0]
	_ui.afficher(_vue_avec(id, 0))
	verifier_faux(_texte_carte(0).contains("Niv."), "arme non portée")
	var vue := _vue_avec(id, 0)
	var amelio: String = _donnees.ameliorations.keys()[0]
	vue.offres = [
		{"id": amelio, "genre": Types.Genre.AMELIORATION, "rarete": 0, "prix": 100, "vendu": false}
	]
	_ui.afficher(vue)
	verifier_faux(_texte_carte(0).contains("Niv."), "amélioration")


func test_la_note_de_niveau_ne_fait_pas_bouger_le_bouton_d_achat() -> void:
	var id := _ids_armes()[0]
	_ui.afficher(_vue_avec(id, 0))
	await attendre_images(3)
	var avant: Rect2 = _ui._achats[0].get_global_rect()
	_ui.afficher(_vue_avec(id, 7))
	await attendre_images(3)
	verifier_egal(_ui._achats[0].get_global_rect(), avant, "bouton d'achat")


func test_la_grille_montre_une_icone_par_arme_distincte_avec_son_niveau() -> void:
	var ids := _ids_armes()
	var vue := _vue_avec(ids[0], 0)
	var niveaux: Array[int] = [1, 3, 12]
	for i: int in niveaux.size():
		vue.armes.append({"id": ids[i], "recharge_ratio": 0.0, "niveau": niveaux[i]})
	_ui.afficher(vue)
	var grille := _ui.find_child("GrilleArmes", true, false)
	verifier_non_nul(grille)
	var cases := grille.get_children().filter(func(n: Node) -> bool: return n is Button)
	verifier_egal(cases.size(), 3, "une case par arme distincte")
	for i: int in niveaux.size():
		var case := cases[i] as Button
		var insigne := case.find_child("Niveau%d" % i, true, false) as Label
		if niveaux[i] == 1:
			verifier(insigne == null or not insigne.visible, "pas d'insigne au niveau 1")
		else:
			verifier_non_nul(insigne, "insigne de l'arme %d" % i)
			if insigne != null:
				verifier_egal(insigne.text, str(niveaux[i]))
		verifier(case.tooltip_text.contains("Niveau %d" % niveaux[i]), "infobulle : niveau")


func test_les_textes_de_niveau_ont_leurs_espaces_insecables() -> void:
	var textes := CsvTextes.lire(CSV_BOUTIQUE)
	for cle: String in [
		"BOUTIQUE_NIVEAU_SUIVANT", "BOUTIQUE_NIVEAU_INFOBULLE", "BOUTIQUE_NIVEAU_INSIGNE"
	]:
		verifier(textes.has(cle), cle)
	verifier((textes["BOUTIQUE_NIVEAU_SUIVANT"] as String).contains(" :"))
