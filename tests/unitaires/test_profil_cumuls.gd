extends CasDeTest
## Cumuls entre parties dans la sauvegarde (T11.3bis, `docs/defis.md` §3, version 2 du fichier).

const DOC := "res://docs/defis.md"
## Pour chaque cumul : le compteur du bilan qu'il additionne.
const SOURCES: Dictionary = {
	"cumul_victoires": "victoire",
	"cumul_eliminations": "eliminations",
	"cumul_or_gagne": "or_gagne_total",
	"cumul_manches": "manche_atteinte",
	"cumul_dernier_rempart": "dernier_rempart",
}


func apres_chaque() -> void:
	Sauvegarde.simuler_echec("")
	super.apres_chaque()


func _chemin() -> String:
	return dossier_temporaire().path_join("progression.json")


func _ecrire(chemin: String, texte: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(texte)
	f.close()


func _bilan(valeurs: Dictionary = {}) -> Dictionary:
	var b := BilanPartie.new().a_dict()
	b.merge(valeurs, true)
	return b


## Les compteurs du tableau du §3 de `docs/defis.md`, lus dans le document.
func _compteurs_du_document() -> Array[String]:
	var noms: Array[String] = []
	var dans := false
	for ligne: String in FileAccess.get_file_as_string(DOC).split("\n"):
		if ligne.begins_with("## 3."):
			dans = true
			continue
		if dans and ligne.begins_with("## "):
			break
		if dans and ligne.begins_with("| `"):
			noms.append(ligne.split("`")[1])
	return noms


func test_chaque_cumul_du_document_est_un_champ_du_profil() -> void:
	var noms := _compteurs_du_document()
	verifier(noms.size() >= 7, "le tableau du §3 a été lu (%d compteurs)" % noms.size())
	var p := Profil.new()
	for nom: String in noms:
		verifier(nom in Profil.CLES or nom == "parties", "le profil porte « %s »" % nom)
		verifier(p.get(nom) != null, "et le champ existe : %s" % nom)
		verifier(p.a_dict().has(nom), "et s'écrit : %s" % nom)
	for cle: String in Profil.BORNES_CUMULS:
		verifier(cle in noms, "%s est dans le document" % cle)
	verifier_egal(Profil.BORNES_CUMULS.size(), 6)


func test_un_fichier_de_version_1_se_migre_sans_rien_perdre() -> void:
	var v1 := {
		"version": 1,
		"defis_reussis": ["premier_rempart"],
		"skins_debloques": ["tour_de_guet"],
		"skin_choisi": "tour_de_guet",
		"parties": 7,
		"meilleure_manche": 19,
	}
	_ecrire(_chemin(), JSON.stringify(v1))
	var p := Sauvegarde.charger(_chemin())
	verifier_egal(p.version, Sauvegarde.VERSION)
	verifier_egal(p.parties, 7)
	verifier_egal(p.meilleure_manche, 19)
	verifier_egal(p.defis_reussis, ["premier_rempart"] as Array[String])
	verifier_egal(p.skin_choisi, "tour_de_guet")
	for cle: String in Profil.BORNES_CUMULS:
		verifier_egal(p.get(cle), 0, "%s part de 0" % cle)
	# La réécriture est en version 2 et garde tout.
	verifier(Sauvegarde.enregistrer(p, _chemin()))
	var relu := Sauvegarde.charger(_chemin())
	verifier_egal(relu.a_dict(), p.a_dict())
	var brut: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_chemin()))
	verifier_egal(int(brut["version"]), 2)


func test_une_version_3_n_est_ni_lue_ni_ecrasee() -> void:
	var p := Profil.new()
	p.parties = 4
	verifier(Sauvegarde.enregistrer(p, _chemin()))
	var futur := FileAccess.get_file_as_string(_chemin()).replace('"version": 2', '"version": 3')
	_ecrire(_chemin(), futur)
	var lu := Sauvegarde.charger(_chemin())
	verifier(lu.verrouille, "un fichier de la version 3 n'est pas lu")
	verifier_faux(Sauvegarde.enregistrer(Profil.new(), _chemin()), "ni écrasé")
	verifier_egal(FileAccess.get_file_as_string(_chemin()), futur, "à l'octet près")


func test_un_bilan_s_ajoute_aux_cumuls() -> void:
	var p := Profil.new()
	(
		p
		. ajouter_bilan(
			_bilan(
				{
					"victoire": 1.0,
					"eliminations": 420.0,
					"or_gagne_total": 5000.0,
					"manche_atteinte": 31.0,
					"dernier_rempart": 1.0,
				}
			),
			true
		)
	)
	verifier_egal(p.parties, 1)
	verifier_egal(p.meilleure_manche, 31)
	verifier_egal(p.cumul_victoires, 1)
	verifier_egal(p.cumul_eliminations, 420)
	verifier_egal(p.cumul_or_gagne, 5000)
	verifier_egal(p.cumul_manches, 31)
	verifier_egal(p.cumul_parties_multijoueur, 1)
	verifier_egal(p.cumul_dernier_rempart, 1)
	p.ajouter_bilan(_bilan({"manche_atteinte": 12.0, "eliminations": 10.0}), false)
	verifier_egal(p.parties, 2)
	verifier_egal(p.meilleure_manche, 31, "la meilleure manche ne baisse pas")
	verifier_egal(p.cumul_manches, 43)
	verifier_egal(p.cumul_eliminations, 430)
	verifier_egal(p.cumul_parties_multijoueur, 1, "une partie solo ne compte pas à plusieurs")


func test_un_cumul_s_arrete_a_sa_borne_en_boucle_sur_les_six() -> void:
	var champs: Dictionary = {
		"cumul_victoires": "victoire",
		"cumul_eliminations": "eliminations",
		"cumul_or_gagne": "or_gagne_total",
		"cumul_manches": "manche_atteinte",
		"cumul_dernier_rempart": "dernier_rempart",
	}
	for cle: String in champs:
		var p := Profil.new()
		var borne := int(Profil.BORNES_CUMULS[cle])
		p.set(cle, borne - 1)
		p.ajouter_bilan(_bilan({champs[cle]: 1.0e12}), true)
		verifier_egal(p.get(cle), borne, "%s s'arrête à sa borne" % cle)
		p.ajouter_bilan(_bilan({champs[cle]: 5.0}), true)
		verifier_egal(p.get(cle), borne, "et n'en repart pas")
	var multi := Profil.new()
	var borne_multi := int(Profil.BORNES_CUMULS["cumul_parties_multijoueur"])
	multi.cumul_parties_multijoueur = borne_multi
	multi.ajouter_bilan(_bilan(), true)
	verifier_egal(multi.cumul_parties_multijoueur, borne_multi)
	var parties := Profil.new()
	parties.parties = Profil.PARTIES_MAX
	parties.ajouter_bilan(_bilan(), false)
	verifier_egal(parties.parties, Profil.PARTIES_MAX, "les parties aussi")


func test_un_bilan_malforme_compte_pour_zero() -> void:
	var p := Profil.new()
	for mauvais: Variant in [NAN, INF, -5.0, "x", null, [1]]:
		p.ajouter_bilan(
			{"eliminations": mauvais, "or_gagne_total": mauvais, "victoire": mauvais}, false
		)
	p.ajouter_bilan({}, false)
	for cle: String in Profil.BORNES_CUMULS:
		verifier_egal(p.get(cle), 0, cle)
	verifier_egal(p.parties, 7, "chaque partie compte, même sans bilan lisible")


func test_un_echec_d_ecriture_garde_les_cumuls_precedents() -> void:
	var p := Profil.new()
	p.ajouter_bilan(_bilan({"eliminations": 100.0, "manche_atteinte": 10.0}), true)
	verifier(Sauvegarde.enregistrer(p, _chemin()))
	var avant := FileAccess.get_file_as_bytes(_chemin())
	for etape: String in Sauvegarde.ETAPES:
		var suite := Sauvegarde.charger(_chemin())
		suite.ajouter_bilan(_bilan({"eliminations": 900.0}), true)
		Sauvegarde.simuler_echec(etape)
		verifier_faux(Sauvegarde.enregistrer(suite, _chemin()), "échec à l'étape %s" % etape)
		Sauvegarde.simuler_echec("")
		verifier_egal(FileAccess.get_file_as_bytes(_chemin()), avant, "fichier intact (%s)" % etape)
		verifier_egal(Sauvegarde.charger(_chemin()).cumul_eliminations, 100, etape)


func test_valeurs_hors_bornes_ou_de_mauvais_types_des_cumuls() -> void:
	var p := Profil.new()
	verifier(Sauvegarde.enregistrer(p, _chemin()))
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_chemin()))
	for cle: String in Profil.BORNES_CUMULS:
		var borne := int(Profil.BORNES_CUMULS[cle])
		for cas: Array in [[-5, 0], [1.0e30, borne], [borne + 1, borne]]:
			var d := base.duplicate()
			d[cle] = cas[0]
			_ecrire(_chemin(), JSON.stringify(d))
			var lu := Sauvegarde.charger(_chemin())
			verifier_egal(lu.get(cle), cas[1], "%s = %s est ramené dans ses bornes" % [cle, cas[0]])
		for mauvais: Variant in ["12", null, true, [1], {"a": 1}]:
			var d := base.duplicate()
			d[cle] = mauvais
			_ecrire(_chemin(), JSON.stringify(d))
			var lu := Sauvegarde.charger(_chemin())
			verifier_egal(lu.cumul_eliminations, 0)
			verifier_egal(lu.parties, 0, "%s = %s : fichier refusé, profil vide" % [cle, mauvais])
