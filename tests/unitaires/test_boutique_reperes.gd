extends CasDeTest
## Repères d'arme dans la boutique (S25) : chaque carte d'arme montre son type, sa mécanique et ses
## statuts en icônes nommées ; l'infobulle les écrit tous ; une amélioration n'en a pas.

const SCENE := "res://scenes/boutique.tscn"
const CSVS: Array[String] = ["res://i18n/textes_boutique.csv", "res://i18n/textes_communs.csv"]

var _ui: BoutiqueUi
var _source: SourceFactice
var _donnees: Donnees
var _traduction: Translation
var _locale_avant: String = "en"


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	_traduction = Translation.new()
	_traduction.locale = "fr"
	for chemin: String in CSVS:
		var textes := CsvTextes.lire(chemin)
		for cle: String in textes:
			_traduction.add_message(cle, str(textes[cle]))
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


func _vue_avec(id: String, genre: int) -> VueArene:
	var vue := VueArene.new()
	vue.argent = 5000
	vue.offres = [{"id": id, "genre": genre, "rarete": 0, "prix": 80, "vendu": false}]
	return vue


func _statuts_distincts(arme: Dictionary) -> int:
	var vus: Dictionary = {}
	for statut: Dictionary in arme.get("statuts", []):
		vus[str(statut["kind"])] = true
	return vus.size()


func test_chaque_carte_d_arme_montre_son_type_sa_mecanique_et_ses_statuts_en_icones_nommees(
) -> void:
	for id: String in _donnees.armes:
		_ui.afficher(_vue_avec(id, Types.Genre.ARME))
		var rangee := _ui.find_child("Reperes0", true, false) as Control
		var attendus := (
			2 + mini(_statuts_distincts(_donnees.armes[id]), ReperesArme.statuts_max_carte())
		)
		verifier_egal(rangee.get_child_count(), attendus, "%s : icônes sur la carte" % id)
		for puce: Control in rangee.get_children():
			verifier(not puce.tooltip_text.is_empty(), "%s : infobulle de %s" % [id, puce.name])
			verifier_egal(puce.accessibility_name, puce.tooltip_text, "%s : nom accessible" % id)


func test_l_infobulle_de_la_carte_ecrit_tous_les_reperes_meme_les_statuts_non_montres() -> void:
	for id: String in _donnees.armes:
		_ui.afficher(_vue_avec(id, Types.Genre.ARME))
		var carte := _ui.find_child("Carte0", true, false) as Control
		var ligne := ReperesArme.texte_court(_donnees.armes[id])
		verifier(not ligne.is_empty(), "%s : ligne de repères" % id)
		verifier(
			carte.tooltip_text.contains(ligne), "%s : l'infobulle contient « %s »" % [id, ligne]
		)


func test_une_amelioration_n_a_pas_de_reperes_et_la_rangee_suit_l_offre() -> void:
	var armes: Array = _donnees.armes.keys()
	var amelios: Array = _donnees.ameliorations.keys()
	_ui.afficher(_vue_avec(str(armes[0]), Types.Genre.ARME))
	var rangee := _ui.find_child("Reperes0", true, false) as Control
	verifier(rangee.get_child_count() > 0, "une arme a des repères")
	_ui.afficher(_vue_avec(str(amelios[0]), Types.Genre.AMELIORATION))
	rangee = _ui.find_child("Reperes0", true, false) as Control
	verifier_egal(rangee.get_child_count(), 0, "une amélioration n'en a pas")
	_ui.afficher(_vue_avec(str(armes[1]), Types.Genre.ARME))
	rangee = _ui.find_child("Reperes0", true, false) as Control
	verifier(rangee.get_child_count() > 0, "l'arme suivante en a de nouveau")


func test_une_arme_equipee_montre_l_icone_de_son_type_de_degats() -> void:
	var vue := _vue_avec(str(_donnees.armes.keys()[0]), Types.Genre.ARME)
	for id: String in _donnees.armes:
		vue.armes.append({"id": id, "recharge_ratio": 0.0})
	_ui.afficher(vue)
	for i: int in vue.armes.size():
		var case := _ui.find_child("Arme%d" % i, true, false) as Control
		verifier(case.find_child("TypeDegats", false, false) != null, "arme %d : icône du type" % i)
