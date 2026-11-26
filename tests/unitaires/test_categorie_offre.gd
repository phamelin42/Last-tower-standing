extends CasDeTest
## Chaque offre se reconnaît d'un coup d'œil : un ruban de couleur propre à sa catégorie, une
## icône et le mot écrit (la couleur ne porte jamais seule l'information).

const CSV_BOUTIQUE := "res://i18n/textes_boutique.csv"
const MOTS: Dictionary = {
	Types.Categorie.ARME: "Arme",
	Types.Categorie.AMELIORATION: "Amélioration",
	Types.Categorie.REVENU: "Revenu",
}

var _traduction: Translation
var _locale_avant: String = "en"


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	_traduction = Translation.new()
	_traduction.locale = "fr"
	var textes := CsvTextes.lire(CSV_BOUTIQUE)
	for cle: String in textes:
		_traduction.add_message(cle, textes[cle])
	TranslationServer.add_translation(_traduction)
	TranslationServer.set_locale("fr")


func apres_chaque() -> void:
	TranslationServer.remove_translation(_traduction)
	TranslationServer.set_locale(_locale_avant)


func test_chaque_categorie_a_un_ruban_une_icone_et_un_mot_et_les_trois_se_distinguent() -> void:
	var rubans: Dictionary = {}
	var icones: Dictionary = {}
	var mots: Dictionary = {}
	for nom: String in Types.Categorie.keys():
		var categorie: int = Types.Categorie[nom]
		var rubrique := CategorieOffre.rubrique(categorie)
		verifier_egal(
			rubrique.keys(), ["ruban", "icone", "mot_cle"], "%s : les trois repères" % nom
		)
		var ruban: String = rubrique["ruban"]
		var icone: String = rubrique["icone"]
		verifier(ResourceLoader.exists(ruban), "%s : le ruban existe" % nom)
		verifier(ResourceLoader.exists(icone), "%s : l'icône existe" % nom)
		verifier(not CategorieOffre.mot(categorie).is_empty(), "%s : un mot écrit" % nom)
		verifier_non_nul(CategorieOffre.icone(categorie), "%s : l'icône se charge" % nom)
		rubans[ruban] = true
		icones[icone] = true
		mots[CategorieOffre.mot(categorie)] = true
	verifier_egal(rubans.size(), Types.Categorie.size(), "un ruban par catégorie")
	verifier_egal(icones.size(), Types.Categorie.size(), "une icône par catégorie")
	verifier_egal(mots.size(), Types.Categorie.size(), "un mot par catégorie")
	for categorie: int in MOTS:
		verifier_egal(CategorieOffre.mot(categorie), MOTS[categorie], "le mot de %d" % categorie)


func test_chaque_offre_affiche_sa_categorie_d_apres_les_donnees() -> void:
	var donnees := Donnees.charger()
	var armes: Array = _lire("res://data/armes.json")
	var ameliorations: Array = _lire("res://data/ameliorations.json")
	var vues := 0
	for entree: Dictionary in armes:
		var id: String = entree["id"]
		verifier_egal(CategorieOffre.mot(donnees.categorie_de(id)), "Arme", "arme %s" % id)
		vues += 1
	for entree: Dictionary in ameliorations:
		var id: String = entree["id"]
		var attendu := "Revenu" if entree["categorie"] == "revenu" else "Amélioration"
		verifier_egal(CategorieOffre.mot(donnees.categorie_de(id)), attendu, "offre %s" % id)
		var ruban := CategorieOffre.creer_ruban(donnees.categorie_de(id), "Ruban")
		var mot := ruban.find_child("Mot", true, false) as Label
		verifier_non_nul(mot, "%s : le ruban écrit le mot" % id)
		if mot != null:
			verifier_egal(mot.text, attendu, "%s : mot du ruban" % id)
		ruban.free()
		vues += 1
	verifier_egal(vues, donnees.armes.size() + donnees.ameliorations.size(), "toutes les offres")
	verifier(vues > 0, "le catalogue n'est pas vide")


func test_une_categorie_inconnue_ne_leve_pas_d_exception_et_n_affiche_rien() -> void:
	for categorie: int in [-1, 3, 99]:
		verifier(CategorieOffre.rubrique(categorie).is_empty(), "rubrique vide pour %d" % categorie)
		verifier_egal(CategorieOffre.mot(categorie), "", "pas de mot pour %d" % categorie)
		verifier_nul(CategorieOffre.icone(categorie), "pas d'icône pour %d" % categorie)
		var ruban := CategorieOffre.creer_ruban(categorie, "Ruban")
		verifier_faux(ruban.visible, "ruban invisible pour %d" % categorie)
		ruban.free()


func _lire(chemin: String) -> Array:
	var analyse: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	verifier(analyse is Array, "%s se lit" % chemin)
	return analyse as Array if analyse is Array else []
