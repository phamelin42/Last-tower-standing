extends CasDeTest
## Ce que la joueuse lit sur une offre : une ligne d'effet générée depuis `data/`, avec les chiffres
## exacts et la vraie règle de la simulation, puis une phrase d'ambiance sans chiffre. Chaque test
## parcourt les 30 armes et les 40 améliorations en boucle.

const CSV_BOUTIQUE := "res://i18n/textes_boutique.csv"
const CSV_COMMUNS := "res://i18n/textes_communs.csv"
const LONGUEUR_AMBIANCE_MAX := 70
const NBSP := "\u00A0"
const FINE := "\u202F"
## Mots vagues qui ne disent rien du chiffre : l'effet exact est dans la ligne d'effet.
const MOTS_VAGUES: Array[String] = ["décuple", "gros bonus", "énorme", "bien plus", "colossal"]
const ARMURES: Array[String] = ["légère", "moyenne", "lourde", "fortifiée"]

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
			var texte: String = textes[cle]
			_traduction.add_message(cle, texte)
	TranslationServer.add_translation(_traduction)
	TranslationServer.set_locale("fr")
	_donnees = Donnees.charger()


func apres_chaque() -> void:
	TranslationServer.remove_translation(_traduction)
	TranslationServer.set_locale(_locale_avant)


# --- Aides ---------------------------------------------------------------------------------


func _ligne(id: String, genre: int, avec_type: bool = true) -> String:
	var table: Dictionary = _donnees.armes if genre == Types.Genre.ARME else _donnees.ameliorations
	return DescriptionOffre.ligne_effet(table[id], genre, _donnees, avec_type)


func _offres() -> Array[Dictionary]:
	var sortie: Array[Dictionary] = []
	var ids_armes: Array = _donnees.armes.keys()
	ids_armes.sort()
	for id: String in ids_armes:
		sortie.append({"id": id, "genre": Types.Genre.ARME, "entree": _donnees.armes[id]})
	var ids_amelios: Array = _donnees.ameliorations.keys()
	ids_amelios.sort()
	for id: String in ids_amelios:
		var entree: Dictionary = _donnees.ameliorations[id]
		sortie.append({"id": id, "genre": Types.Genre.AMELIORATION, "entree": entree})
	return sortie


## Un nombre comme la joueuse le lit : virgule décimale, sans zéro inutile.
func _fr(valeur: float) -> String:
	var texte := String.num(snappedf(valeur, 0.01))
	if texte.contains("."):
		texte = texte.rstrip("0").rstrip(".")
	return texte.replace(".", ",")


func _sans_milliers(texte: String) -> String:
	return texte.replace(FINE, "")


func _chiffres_attendus(entree: Dictionary, genre: int) -> Array[String]:
	var attendus: Array[String] = []
	if genre == Types.Genre.ARME:
		attendus.append(_fr(float(entree["degats"])))
		var effets: Array = entree["effets"]
		var kind: String = (effets[0] as Dictionary)["kind"]
		if kind == "aura":
			attendus.append(_fr(float((effets[0] as Dictionary)["periode"])))
		else:
			attendus.append(_fr(float(entree["recharge"])))
			attendus.append("portée " + _fr(float(entree["portee"])))
		for brut: Variant in effets:
			var effet: Dictionary = brut
			for cle: String in effet:
				if (
					cle != "kind"
					and cle not in ["decroissance", "vitesse", "dispersion_deg", "portee_saut"]
				):
					attendus.append(_fr(float(effet[cle])))
		var statuts: Array = entree["statuts"]
		for brut: Variant in statuts:
			var statut: Dictionary = brut
			match String(statut["kind"]):
				"poison":
					attendus.append(_fr(float(statut["total_ratio"]) * 100.0))
					attendus.append(_fr(float(statut["duree"])))
				"brulure":
					attendus.append(_fr(float(statut["ratio"]) * 100.0))
					attendus.append(_fr(float(statut["duree"])))
				"etourdissement":
					attendus.append(_fr(float(statut["duree"])))
				"vol_de_vie":
					attendus.append(_fr(float(statut["ratio"]) * 100.0))
		return attendus
	var effets_amelio: Array = entree["effets"]
	for brut: Variant in effets_amelio:
		var effet: Dictionary = brut
		var stat: String = effet["stat"]
		match stat:
			"degats_type", "degats_global", "eclaboussure", "focalisation", "vol_de_vie_coup":
				attendus.append(_fr(float(effet["valeur"]) * 100.0))
			"epines", "critique_chance", "cadence", "revenu_mult", "prime_mult":
				attendus.append(_fr(float(effet["valeur"]) * 100.0))
			"esquive":
				var v := float(effet["valeur"])
				var k := float(_donnees.partie["esquive_k"])
				attendus.append(_fr(snappedf(v / (v + k) * 100.0, 0.1)))
			"bonus_elim":
				attendus.append(_fr(float(effet["tous_les"])))
				attendus.append(_fr(float(effet["or"])))
			"marche_noir":
				pass
			_:
				attendus.append(_fr(float(effet["valeur"])))
	return attendus


# --- Ligne d'effet : une pour chaque offre ---------------------------------------------------


func test_chaque_offre_a_une_ligne_d_effet_avec_ses_chiffres() -> void:
	var offres := _offres()
	verifier_egal(offres.size(), 70, "30 armes et 40 améliorations")
	for offre: Dictionary in offres:
		var id: String = offre["id"]
		var genre: int = offre["genre"]
		var entree: Dictionary = offre["entree"]
		var ligne := _ligne(id, genre)
		verifier(not ligne.strip_edges().is_empty(), "%s : ligne vide" % id)
		for interdit: String in ["{", "}", "%s", "%d", "%f", "BOUTIQUE_"]:
			verifier_faux(
				ligne.contains(interdit), "%s : « %s » dans « %s »" % [id, interdit, ligne]
			)
		var plat := _sans_milliers(ligne)
		for attendu: String in _chiffres_attendus(entree, genre):
			verifier(plat.contains(attendu), "%s : « %s » absent de « %s »" % [id, attendu, ligne])


func test_chaque_genre_d_effet_chaque_statut_et_chaque_statistique_a_son_modele() -> void:
	var kinds_vus := {}
	var statuts_vus := {}
	var stats_vues := {}
	for offre: Dictionary in _offres():
		var entree: Dictionary = offre["entree"]
		var effets: Array = entree["effets"]
		for brut: Variant in effets:
			var effet: Dictionary = brut
			if offre["genre"] == Types.Genre.ARME:
				kinds_vus[String(effet["kind"])] = true
			else:
				stats_vues[String(effet["stat"])] = true
		var statuts: Array = entree.get("statuts", [])
		for brut: Variant in statuts:
			var statut: Dictionary = brut
			statuts_vus[String(statut["kind"])] = true
	verifier(kinds_vus.size() >= 8, "les huit genres d'effet sont présents dans data/")
	verifier(statuts_vus.size() >= 5, "les cinq statuts sont présents dans data/")
	verifier(stats_vues.size() >= 21, "les vingt et une statistiques sont présentes dans data/")
	for kind: String in kinds_vus:
		verifier(DescriptionOffre.EFFETS.has(kind), "genre d'effet sans modèle : %s" % kind)
	for kind: String in statuts_vus:
		verifier(DescriptionOffre.STATUTS.has(kind), "statut sans modèle : %s" % kind)
	for stat: String in stats_vues:
		verifier(DescriptionOffre.STATISTIQUES.has(stat), "statistique sans modèle : %s" % stat)


func test_un_genre_un_statut_ou_une_statistique_inconnus_ne_passent_pas_en_silence() -> void:
	var arme: Dictionary = (_donnees.armes["lame_de_fil"] as Dictionary).duplicate(true)
	verifier(DescriptionOffre.est_complete(arme, Types.Genre.ARME), "l'arme réelle est complète")
	arme["effets"] = [{"kind": "rayon_de_la_mort"}]
	verifier_faux(DescriptionOffre.est_complete(arme, Types.Genre.ARME), "genre inconnu")
	verifier_egal(DescriptionOffre.ligne_effet(arme, Types.Genre.ARME, _donnees), "", "ligne vide")
	var statut: Dictionary = (_donnees.armes["lame_de_fil"] as Dictionary).duplicate(true)
	statut["statuts"] = [{"kind": "malediction"}]
	verifier_faux(DescriptionOffre.est_complete(statut, Types.Genre.ARME), "statut inconnu")
	var amelio: Dictionary = {"id": "x", "effets": [{"stat": "magie_noire", "valeur": 1.0}]}
	verifier_faux(DescriptionOffre.est_complete(amelio, Types.Genre.AMELIORATION), "stat inconnue")
	verifier_egal(
		DescriptionOffre.ligne_effet(amelio, Types.Genre.AMELIORATION, _donnees), "", "ligne vide"
	)


# --- Ce que la simulation fait vraiment ------------------------------------------------------


func test_une_arme_dit_son_type_ses_degats_sa_recharge_sa_portee_et_sa_cible() -> void:
	var ligne := _ligne("lame_de_fil", Types.Genre.ARME)
	for attendu: String in [
		"Tranchant",
		"30,6 dégâts toutes les 0,8 s",
		"portée 500",
	]:
		verifier(ligne.contains(attendu), "« %s » absent de « %s »" % [attendu, ligne])
	verifier_faux(
		_ligne("lame_de_fil", Types.Genre.ARME, false).contains("Tranchant"),
		"sans le type, la carte ne le répète pas"
	)


func test_le_ciblage_ne_s_ecrit_que_s_il_change_du_plus_proche() -> void:
	# `Tir._choisir` : plus proche par défaut, sinon le plus de PV ou le moins de PV.
	var attendu := {
		"baliste_de_guet": "vise le plus de PV",
		"carreau_ricochet": "vise le moins de PV",
		"trebuchet_de_chambre": "vise le plus de PV",
	}
	for id: String in attendu:
		var ligne := _ligne(id, Types.Genre.ARME)
		verifier(ligne.contains(attendu[id]), "%s : %s" % [id, ligne])
	var ids: Array = _donnees.armes.keys()
	for id: String in ids:
		var entree: Dictionary = _donnees.armes[id]
		var effet: Dictionary = (entree["effets"] as Array)[0]
		var vise := String(effet["kind"]) not in ["aura", "onde"]
		var ligne := _ligne(id, Types.Genre.ARME)
		var par_defaut := int(entree["ciblage"]) == Types.Ciblage.PLUS_PROCHE
		verifier_faux(ligne.contains("le plus proche") and not par_defaut, id)
		if par_defaut or not vise:
			verifier_faux(ligne.contains("vise"), "%s : rien à dire du ciblage : %s" % [id, ligne])


func test_l_efficacite_contre_l_armure_se_lit_dans_l_infobulle_pas_dans_la_ligne() -> void:
	# `efficacite.json` : tranchant ×2 contre l'armure moyenne, perçant contre la légère, etc.
	var attendu := {
		"lame_de_fil": "×2 contre armure moyenne",
		"arbalete_de_bureau": "×2 contre armure légère",
		"etincelle_runique": "×2 contre armure lourde",
		"bombarde_de_poche": "×2 contre armure fortifiée",
	}
	for id: String in attendu:
		var entree: Dictionary = _donnees.armes[id]
		verifier_egal(DescriptionOffre.efficacite(entree, _donnees), attendu[id], id)
		verifier_faux(_ligne(id, Types.Genre.ARME).contains("contre"), "%s : hors de la ligne" % id)
	var chaos: Dictionary = _donnees.armes["de_pipe"]
	verifier_egal(DescriptionOffre.efficacite(chaos, _donnees), "", "le chaos n'a aucun avantage")
	var amelio: Dictionary = _donnees.ameliorations["affutage_fin"]
	verifier_egal(
		DescriptionOffre.efficacite(amelio, _donnees), "", "une amélioration n'attaque pas"
	)


func test_les_milliers_se_separent_par_une_espace_fine() -> void:
	var ligne := _ligne("grande_bombarde", Types.Genre.ARME)
	verifier(ligne.contains("1" + FINE + "087,8 dégâts"), "1 087,8 : %s" % ligne)


func test_le_rebond_dit_le_nombre_de_cibles_et_la_perte_par_saut() -> void:
	var ligne := _ligne("disque_scie", Types.Genre.ARME)
	verifier(ligne.contains("rebondit sur 4 ennemis"), ligne)
	verifier(ligne.contains("−10" + NBSP + "% par rebond"), ligne)


func test_l_aura_ne_montre_pas_une_portee_que_la_simulation_ignore() -> void:
	# `Tir._aura` ne lit que le rayon et la période : la portée de data/ ne sert à rien.
	var ligne := _ligne("moulinet_de_cuivre", Types.Genre.ARME)
	verifier_faux(ligne.contains("portée"), ligne)
	verifier(ligne.contains("toutes les 0,5 s"), ligne)
	verifier(ligne.contains("280"), ligne)
	verifier_faux(ligne.contains("vise"), "une aura ne vise personne : %s" % ligne)


func test_mines_et_pieges_disent_qu_ils_ne_touchent_que_le_sol() -> void:
	for id: String in ["petard_de_rempart", "mine_de_forge"]:
		var ligne := _ligne(id, Types.Genre.ARME)
		verifier(ligne.contains("mine"), ligne)
		verifier(ligne.contains("au sol"), "%s : %s" % [id, ligne])
	for id: String in ["chausse_trape", "sablier_fele"]:
		var ligne := _ligne(id, Types.Genre.ARME)
		verifier(ligne.contains("piège"), "%s : %s" % [id, ligne])
		verifier(ligne.contains("au sol"), "%s : %s" % [id, ligne])


func test_statuts_en_clair() -> void:
	var poison := _ligne("baliste_de_guet", Types.Genre.ARME)
	verifier(poison.contains("poison" + NBSP + ": 40" + NBSP + "% des dégâts en 5 s"), poison)
	var givre := _ligne("orbe_de_brume", Types.Genre.ARME)
	verifier(givre.contains("−8" + NBSP + "% de vitesse par coup"), givre)
	verifier(givre.contains("gel de 3 s après 8 coups"), givre)
	var mort := _ligne("vortex_de_verre", Types.Genre.ARME)
	verifier(mort.contains("3" + NBSP + "% des PV max de l’ennemi"), mort)


func test_la_focalisation_ne_vaut_que_pour_les_armes_a_cible_unique() -> void:
	var ligne := _ligne("lentille_fixe", Types.Genre.AMELIORATION)
	verifier(ligne.contains("25" + NBSP + "%"), ligne)
	verifier(ligne.contains("cible unique"), ligne)


func test_les_tirs_multiples_excluent_ondes_mines_pieges_et_auras() -> void:
	var ligne := _ligne("double_encoche", Types.Genre.AMELIORATION)
	verifier(ligne.contains("+1 tir par salve"), ligne)
	for exclu: String in ["ondes", "mines", "pièges", "auras"]:
		verifier(ligne.contains(exclu), "« %s » absent de « %s »" % [exclu, ligne])


func test_les_bonus_de_degats_disent_comment_ils_se_cumulent() -> void:
	var ligne := _ligne("affutage_fin", Types.Genre.AMELIORATION)
	verifier(ligne.contains("+10" + NBSP + "% de dégâts tranchants"), ligne)
	verifier(ligne.contains("rang A"), ligne)
	verifier(ligne.contains("s’additionne"), ligne)
	verifier(ligne.contains("se multiplie"), ligne)


func test_les_statistiques_a_rendement_decroissant_le_disent() -> void:
	var armure := _ligne("plaques_de_laiton", Types.Genre.AMELIORATION)
	verifier(armure.contains("−13" + NBSP + "% de dégâts reçus"), armure)
	var esquive := _ligne("meurtrieres_biaisees", Types.Genre.AMELIORATION)
	verifier(esquive.contains("7,4" + NBSP + "%"), esquive)
	verifier(esquive.contains("décroissant"), esquive)


func test_le_revenu_dit_ce_qu_il_multiplie_et_la_periode() -> void:
	var fixe := _ligne("cagnotte_du_guet", Types.Genre.AMELIORATION)
	verifier(fixe.contains("+4 or toutes les 10 s"), fixe)
	var mult := _ligne("livre_de_comptes", Types.Genre.AMELIORATION)
	verifier(mult.contains("revenu acheté"), mult)
	verifier(mult.contains("base"), mult)
	var croissant := _ligne("placement_de_rente", Types.Genre.AMELIORATION)
	verifier(croissant.contains("minute"), croissant)
	var relance := _ligne("bourse_de_rebut", Types.Genre.AMELIORATION)
	verifier(relance.contains("1 relance gratuite"), relance)
	verifier(relance.contains("par manche"), relance)


func test_les_epines_ne_renvoient_que_le_corps_a_corps() -> void:
	var ligne := _ligne("herisson_de_fer", Types.Genre.AMELIORATION)
	verifier(ligne.contains("30" + NBSP + "%"), ligne)
	verifier(ligne.contains("corps à corps"), ligne)


# --- Typographie -----------------------------------------------------------------------------


func test_typographie_francaise_des_lignes_d_effet() -> void:
	var avant_ponctuation := RegEx.create_from_string("(?<!\\x{00A0})[:;?!%]")
	var decimale_pointee := RegEx.create_from_string("[0-9]\\.[0-9]")
	var millier_colle := RegEx.create_from_string("[0-9]{4}")
	for offre: Dictionary in _offres():
		var id: String = offre["id"]
		var ligne := _ligne(id, offre["genre"])
		verifier(
			avant_ponctuation.search(ligne) == null,
			"%s : espace insécable manquante avant : ; ? ! %% dans « %s »" % [id, ligne]
		)
		verifier(
			decimale_pointee.search(ligne) == null, "%s : point décimal dans « %s »" % [id, ligne]
		)
		verifier(
			millier_colle.search(ligne) == null, "%s : milliers collés dans « %s »" % [id, ligne]
		)
		verifier_faux("'" in ligne, "%s : apostrophe droite" % id)
		verifier_faux('"' in ligne, "%s : guillemet droit" % id)
		verifier_faux(ligne.contains("  "), "%s : espaces doublées" % id)
		verifier_faux(ligne.begins_with(" ") or ligne.ends_with(" "), "%s : espace en bord" % id)


func test_la_typographie_detecte_ses_fautes() -> void:
	var avant_ponctuation := RegEx.create_from_string("(?<!\\x{00A0})[:;?!%]")
	verifier(avant_ponctuation.search("10 %") != null)
	verifier(avant_ponctuation.search("10" + NBSP + "%") == null)


# --- Phrases d'ambiance ----------------------------------------------------------------------


func test_chaque_phrase_d_ambiance_est_courte_sans_chiffre_et_sans_mot_vague() -> void:
	var chiffre := RegEx.create_from_string("[0-9]")
	var nombres_en_lettres := RegEx.create_from_string("(?i)\\b(un quart|moitié|double|triple)\\b")
	var vues := {}
	for offre: Dictionary in _offres():
		var id: String = offre["id"]
		var entree: Dictionary = offre["entree"]
		var phrase: String = entree["description"]
		verifier(not phrase.strip_edges().is_empty(), "%s : phrase vide" % id)
		verifier(
			phrase.length() <= LONGUEUR_AMBIANCE_MAX,
			"%s : %d caractères (« %s »)" % [id, phrase.length(), phrase]
		)
		verifier(chiffre.search(phrase) == null, "%s : un chiffre dans « %s »" % [id, phrase])
		verifier(
			nombres_en_lettres.search(phrase) == null,
			"%s : une quantité dans « %s »" % [id, phrase]
		)
		for mot: String in MOTS_VAGUES:
			verifier_faux(
				phrase.to_lower().contains(mot), "%s : « %s » dans « %s »" % [id, mot, phrase]
			)
		verifier_faux(vues.has(phrase), "%s : phrase en double" % id)
		vues[phrase] = true
		verifier_faux(
			phrase.to_lower().contains(String(entree["nom"]).to_lower()),
			"%s : la phrase ne recopie pas le nom" % id
		)


## Les 70 phrases ont été relues une à une contre la règle de la simulation : chacune cite une
## image du nom de l'offre. Ce test garde le lien le plus facile à casser en retouchant un nom.
func test_la_phrase_d_ambiance_ne_contredit_pas_la_ligne_d_effet() -> void:
	# Une phrase qui parle de soin suppose que l'offre rende des PV, et la ligne le dit.
	var mots_de_soin: Array[String] = [
		"soigne", "rend", "guérit", "referme", "recolle", "vie", "sang"
	]
	var separateur := RegEx.create_from_string("[^\\p{L}]+")
	for offre: Dictionary in _offres():
		var id: String = offre["id"]
		var entree: Dictionary = offre["entree"]
		var phrase := String(entree["description"]).to_lower()
		var ligne := _ligne(id, offre["genre"]).to_lower()
		var parle_de_soin := false
		for mot: String in separateur.sub(phrase, " ", true).split(" ", false):
			parle_de_soin = parle_de_soin or mots_de_soin.has(mot)
		var soigne := (
			ligne.contains("rend")
			or ligne.contains("vol de vie")
			or ligne.contains("régénère")
			or ligne.contains("pv par seconde")
			or ligne.contains("pv max")
		)
		if parle_de_soin:
			verifier(soigne, "%s : « %s » parle de soin, pas la ligne « %s »" % [id, phrase, ligne])
