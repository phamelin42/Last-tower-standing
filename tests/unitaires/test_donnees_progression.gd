extends CasDeTest
## `data/defis.json` : le fichier réel est valide, et un fichier mal formé est refusé au chargement.


func _liste() -> Array:
	var brut := AidesPartie.brut()
	var liste: Array = brut["defis.json"]
	return liste.duplicate(true)


func _erreurs(liste: Array) -> PackedStringArray:
	var brut := AidesPartie.brut()
	brut["defis.json"] = liste
	return Donnees.valider(brut)


func test_les_defis_reels_sont_valides_et_chargent() -> void:
	verifier_egal(_erreurs(_liste()), PackedStringArray())
	var d := AidesPartie.donnees()
	verifier_non_nul(d)
	verifier_egal(d.defis.size(), _liste().size())
	verifier(d.defis.size() > 0)


func test_un_dossier_sans_defis_charge_avec_une_liste_vide() -> void:
	var brut := AidesPartie.brut()
	brut.erase("defis.json")
	var d := Donnees.depuis_brut(brut)
	verifier_non_nul(d)
	verifier_egal(d.defis.size(), 0)


func test_les_defis_n_entrent_pas_dans_l_empreinte_du_reseau() -> void:
	var avec := AidesPartie.donnees()
	var brut := AidesPartie.brut()
	brut.erase("defis.json")
	verifier_egal(Donnees.depuis_brut(brut).empreinte, avec.empreinte)


func test_un_defi_malforme_est_refuse_au_chargement() -> void:
	var cas: Dictionary = {
		"condition vide": func(l: Array) -> void: l[0]["condition"] = "",
		"condition sans opérateur": func(l: Array) -> void: l[0]["condition"] = "victoire 1",
		"opérateur inconnu": func(l: Array) -> void: l[0]["condition"] = "victoire == 1",
		"compteur inconnu": func(l: Array) -> void: l[0]["condition"] = "inventé ≥ 1",
		"compteur inconnu à droite": func(l: Array) -> void: l[0]["condition"] = "victoire = zzz",
		"identifiant en double": func(l: Array) -> void: l[1]["id"] = l[0]["id"],
		"skin en double": func(l: Array) -> void: l[1]["skin"] = l[0]["skin"],
		"nom manquant": func(l: Array) -> void: (l[0] as Dictionary).erase("nom"),
		"texte vide": func(l: Array) -> void: l[0]["texte"] = "",
		"mode inconnu": func(l: Array) -> void: l[0]["mode"] = "solo",
		"entrée qui n'est pas un objet": func(l: Array) -> void: l[0] = 3,
	}
	for nom: String in cas:
		var liste := _liste()
		var changer: Callable = cas[nom]
		changer.call(liste)
		verifier(not _erreurs(liste).is_empty(), "refusé : %s" % nom)


func test_aucun_nom_ni_texte_de_defi_n_est_un_nom_d_origine() -> void:
	var noms := NomsOrigine.lire()
	verifier(noms.size() > 100)
	for defi: Dictionary in _liste():
		for cle: String in ["id", "nom", "texte", "skin"]:
			var trouves := NomsOrigine.trouver(String(defi[cle]), noms)
			verifier_egal(trouves, PackedStringArray(), "« %s » : nom d'origine" % defi[cle])


func test_chaque_compteur_du_profil_est_connu_des_conditions() -> void:
	var attendus: Array[String] = ["parties"]
	for cle: String in Profil.BORNES_CUMULS:
		attendus.append(cle)
	attendus.sort()
	var connus := DonneesProgression.COMPTEURS_PROFIL.duplicate()
	connus.sort()
	verifier_egal(connus, attendus)


func test_une_condition_se_lit_et_se_juge() -> void:
	var termes := DonneesProgression.analyser_condition("victoire = 1 et or_depense ≤ 1000")
	verifier_egal(termes.size(), 2)
	verifier(DonneesProgression.condition_tenue(termes, {"victoire": 1.0, "or_depense": 1000.0}))
	verifier_faux(DonneesProgression.condition_tenue(termes, {"victoire": 1.0, "or_depense": 1001}))
	verifier_faux(DonneesProgression.condition_tenue(termes, {"victoire": 0.0}))
	verifier_faux(DonneesProgression.condition_tenue([], {}), "une condition vide ne tient jamais")
