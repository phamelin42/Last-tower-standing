extends CasDeTest
## L'adresse de l'annuaire et le choix « Partie publique » dans les réglages (ADR 001, décision
## 16) : valeur par défaut, vidable pour désactiver l'annuaire, bornée à 255 caractères, et une
## valeur de mauvais type revient au défaut sans rien casser.

const DEFAUT := "annuaire-lts.phamelin.fr:7779"
const ADRESSE_MAX := 255


func _chemin() -> String:
	return dossier_temporaire().path_join("reglages.cfg")


func _ecrire_brut(contenu: String) -> void:
	var f := FileAccess.open(_chemin(), FileAccess.WRITE)
	f.store_string(contenu)
	f.close()


func test_par_defaut_l_annuaire_de_phil_et_la_partie_publique() -> void:
	var r := Reglages.new()
	verifier_egal(r.annuaire_adresse, DEFAUT)
	verifier_egal(Reglages.ANNUAIRE_DEFAUT, DEFAUT)
	verifier(r.salon_public, "case cochée par défaut")
	var absent := Reglages.charger(_chemin())
	verifier_egal(absent.annuaire_adresse, DEFAUT)
	verifier(absent.salon_public)


func test_chaque_adresse_et_chaque_choix_revient_identique() -> void:
	var adresses: Array[String] = [
		"", DEFAUT, "10.0.0.2:7779", "h", "é".repeat(ADRESSE_MAX), "x".repeat(ADRESSE_MAX)
	]
	for adresse: String in adresses:
		for publique: bool in [true, false]:
			var r := Reglages.new()
			r.annuaire_adresse = adresse
			r.salon_public = publique
			verifier(r.sauver(_chemin()))
			var relu := Reglages.charger(_chemin())
			verifier_egal(relu.annuaire_adresse, adresse, "« %s »" % adresse.left(20))
			verifier_egal(relu.salon_public, publique)


func test_une_adresse_videe_reste_videe_et_ne_revient_pas_au_defaut() -> void:
	var r := Reglages.new()
	r.annuaire_adresse = ""
	verifier(r.sauver(_chemin()))
	verifier_egal(Reglages.charger(_chemin()).annuaire_adresse, "")
	var espaces := Reglages.new()
	espaces.annuaire_adresse = "   "
	verifier(espaces.sauver(_chemin()))
	verifier_egal(Reglages.charger(_chemin()).annuaire_adresse, "", "des espaces valent vide")


func test_l_adresse_est_bornee_a_255_caracteres_et_sans_controle() -> void:
	var r := Reglages.new()
	r.annuaire_adresse = "h".repeat(400) + "\n"
	r.normaliser()
	verifier_egal(r.annuaire_adresse.length(), ADRESSE_MAX)
	var sale := Reglages.new()
	sale.annuaire_adresse = "an\nnu\u0007aire:7779"
	sale.normaliser()
	verifier_egal(sale.annuaire_adresse, "annuaire:7779")
	verifier_egal(Reglages.ADRESSE_MAX, ADRESSE_MAX)


func test_un_fichier_de_types_faux_donne_les_defauts_de_l_annuaire() -> void:
	var faux: Array[String] = ["12", "true", "[1]", "null", "1.5"]
	for valeur: String in faux:
		_ecrire_brut(
			"[reglages]\nannuaire_adresse=%s\nsalon_public=%s\n; fin\n" % [valeur, '"oui"']
		)
		var r := Reglages.charger(_chemin())
		verifier_egal(r.annuaire_adresse, DEFAUT, "adresse %s" % valeur)
		verifier(r.salon_public, "choix de mauvais type : défaut")


func test_un_fichier_sans_ces_cles_garde_les_defauts_et_les_autres_reglages() -> void:
	_ecrire_brut('[reglages]\nvolume_general=0.5\nnom_joueur="Mina"\n; fin\n')
	var r := Reglages.charger(_chemin())
	verifier_egal(r.annuaire_adresse, DEFAUT)
	verifier(r.salon_public)
	verifier_egal(r.nom_joueur, "Mina")
	verifier_proche(r.volume_general, 0.5)
