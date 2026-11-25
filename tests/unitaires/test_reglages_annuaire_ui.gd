extends CasDeTest
## Le champ « Adresse de l'annuaire » de l'écran des réglages (ADR 001, décision 16) : il montre la
## valeur lue (le défaut au premier lancement), se modifie, se vide pour désactiver l'annuaire, et
## une adresse invalide revient au défaut. Chaque changement est écrit tout de suite.

const SCENE := "res://scenes/reglages.tscn"
const CSV := "res://i18n/textes_reglages.csv"
const DEFAUT := "annuaire-lts.phamelin.fr:7779"

var _ui: ReglagesUi = null


func avant_chaque() -> void:
	_ui = (load(SCENE) as PackedScene).instantiate() as ReglagesUi
	_ui.chemin = _chemin()
	arbre.root.add_child(_ui)


func apres_chaque() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.get_parent().remove_child(_ui)
		_ui.free()
	_ui = null


func _chemin() -> String:
	return dossier_temporaire().path_join("reglages.cfg")


func _saisir(texte: String) -> void:
	_ui.annuaire.text = texte
	_ui.annuaire.text_submitted.emit(texte)


func test_au_premier_lancement_le_champ_montre_l_annuaire_par_defaut() -> void:
	_ui.configurer(Reglages.charger(_chemin()))
	verifier_egal(_ui.annuaire.text, DEFAUT)


func test_le_champ_montre_la_valeur_lue_et_la_vide_aussi() -> void:
	var r := Reglages.new()
	r.annuaire_adresse = "10.0.0.2:7000"
	_ui.configurer(r)
	verifier_egal(_ui.annuaire.text, "10.0.0.2:7000")
	r.annuaire_adresse = ""
	_ui.configurer(r)
	verifier_egal(_ui.annuaire.text, "", "un annuaire désactivé reste vide à l'écran")


func test_modifier_le_champ_ecrit_la_nouvelle_adresse_et_l_annonce() -> void:
	_ui.configurer(Reglages.charger(_chemin()))
	var annonces: Array[String] = []
	_ui.modifies.connect(func(r: Reglages) -> void: annonces.append(r.annuaire_adresse))
	_saisir("  annuaire.exemple.org:7800  ")
	verifier_egal(Reglages.charger(_chemin()).annuaire_adresse, "annuaire.exemple.org:7800")
	verifier_egal(_ui.annuaire.text, "annuaire.exemple.org:7800", "espaces retirés à l'écran")
	verifier_egal(annonces, ["annuaire.exemple.org:7800"])


func test_vider_le_champ_desactive_l_annuaire_sans_revenir_au_defaut() -> void:
	_ui.configurer(Reglages.charger(_chemin()))
	_saisir("")
	verifier_egal(Reglages.charger(_chemin()).annuaire_adresse, "")
	verifier_egal(_ui.annuaire.text, "")
	_saisir("   ")
	verifier_egal(Reglages.charger(_chemin()).annuaire_adresse, "", "des espaces valent vide")


func test_une_adresse_invalide_revient_au_defaut_a_l_ecran_et_dans_le_fichier() -> void:
	_ui.configurer(Reglages.charger(_chemin()))
	var invalides: Array[String] = ["a:b:c", "hote:0", "hote:65536", ":80", "ho te:80", "hote:x"]
	for brut: String in invalides:
		_saisir("autre.exemple.org:1234")
		_saisir(brut)
		verifier_egal(_ui.annuaire.text, DEFAUT, "« %s »" % brut)
		verifier_egal(Reglages.charger(_chemin()).annuaire_adresse, DEFAUT, brut)


func test_le_champ_est_borne_a_255_caracteres_et_lisible() -> void:
	verifier_egal(_ui.annuaire.max_length, Reglages.ADRESSE_MAX)
	verifier(_ui.annuaire.custom_minimum_size.y >= 48.0, "48 px de haut")
	verifier(_ui.controles().has(_ui.annuaire), "le champ suit les minimums des commandes")


func test_le_libelle_du_champ_existe_dans_le_csv() -> void:
	var textes := CsvTextes.lire(CSV)
	verifier_egal(
		textes.get("REGLAGES_ANNUAIRE"),
		"Adresse de l’annuaire (vide : désactivé)".replace(" :", " :")
	)
