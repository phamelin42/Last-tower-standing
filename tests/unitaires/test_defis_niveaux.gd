extends CasDeTest
## D23 (§6.17.4) : une arme achetée plusieurs fois monte de niveau. Le bilan compte toujours un achat
## par niveau et une arme distincte ; les défis « une seule arme » se réussissent avec des niveaux ;
## le format de la sauvegarde n'a pas changé.

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _arene_avec_offre(id: String) -> Arene:
	var a := Arene.new(d, 31)
	a.economie.argent = 10000000
	a.boutique.offres[0] = {
		"id": id,
		"genre": Types.Genre.ARME,
		"rarete": int((d.armes[id] as Dictionary)["rarete"]),
		"prix": int((d.armes[id] as Dictionary)["prix"]),
		"vendu": false,
	}
	return a


func test_acheter_dix_niveaux_d_une_arme_compte_dix_achats_et_une_arme_distincte() -> void:
	var id: String = d.armes.keys()[0]
	var a := _arene_avec_offre(id)
	for i: int in 10:
		a.boutique.offres[0]["vendu"] = false
		verifier_egal(a.acheter(0), Types.Resultat.OK, "achat %d" % i)
	verifier_egal(a.inventaire.niveau(id), 10)
	verifier_egal(a.bilan_partie.valeurs["armes_achetees"], 10.0)
	verifier_egal(a.bilan_partie.valeurs["armes_distinctes"], 1.0)


func test_les_defis_d_arme_unique_se_reussissent_avec_des_niveaux() -> void:
	var id: String = d.armes.keys()[0]
	var a := _arene_avec_offre(id)
	for i: int in 10:
		a.boutique.offres[0]["vendu"] = false
		a.acheter(0)
	var bilan: Dictionary = a.bilan_partie.a_dict()
	bilan["victoire"] = 1.0
	bilan["manche_atteinte"] = 31.0
	var reussis := Defis.evaluer(bilan, Profil.new(), d, false)
	verifier(reussis.has("arme_unique"), "victoire avec les niveaux d'une seule arme")
	verifier(reussis.has("arme_unique_endurante"), "vingtième manche avec une seule arme")
	# Deux armes distinctes : plus « une seule arme ».
	var autre: String = d.armes.keys()[1]
	a.boutique.offres[1] = {
		"id": autre,
		"genre": Types.Genre.ARME,
		"rarete": int((d.armes[autre] as Dictionary)["rarete"]),
		"prix": 1,
		"vendu": false,
	}
	a.acheter(1)
	var bilan2: Dictionary = a.bilan_partie.a_dict()
	bilan2["victoire"] = 1.0
	bilan2["manche_atteinte"] = 31.0
	verifier_faux(Defis.evaluer(bilan2, Profil.new(), d, false).has("arme_unique"), "deux armes")


func test_le_texte_des_defis_d_arme_unique_parle_de_niveaux() -> void:
	var texte := FileAccess.get_file_as_string("res://data/defis.json")
	verifier(texte.contains("avec les niveaux d’une seule arme"))
	verifier_faux(texte.contains("exemplaires d’une seule arme"))
	var doc := FileAccess.get_file_as_string("res://docs/defis.md")
	verifier_faux(doc.contains("exemplaires d’une seule arme"), "docs/defis.md à jour")


func test_le_format_de_sauvegarde_n_a_pas_change() -> void:
	verifier_egal(Sauvegarde.VERSION, 2, "pas de nouvelle version du fichier")
	var cles := Profil.new().a_dict().keys()
	verifier_egal(
		cles,
		[
			"version",
			"defis_reussis",
			"skins_debloques",
			"skin_choisi",
			"parties",
			"meilleure_manche",
			"cumul_victoires",
			"cumul_eliminations",
			"cumul_or_gagne",
			"cumul_manches",
			"cumul_parties_multijoueur",
			"cumul_dernier_rempart",
		]
	)
