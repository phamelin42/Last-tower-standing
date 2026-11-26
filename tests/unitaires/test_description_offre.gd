extends CasDeTest
## Ce que la joueuse lit sur une offre : une ligne d'effet générée depuis `data/`, avec les chiffres
## exacts et la vraie règle de la simulation, puis une phrase d'ambiance sans chiffre. Chaque test
## parcourt toutes les armes et toutes les améliorations des données en boucle.

const CSV_BOUTIQUE := "res://i18n/textes_boutique.csv"
const CSV_COMMUNS := "res://i18n/textes_communs.csv"
const LONGUEUR_AMBIANCE_MAX := 70
const NBSP := "\u00A0"
const FINE := "\u202F"
## Mots vagues qui ne disent rien du chiffre : l'effet exact est dans la ligne d'effet.
const MOTS_VAGUES: Array[String] = ["décuple", "gros bonus", "énorme", "bien plus", "colossal"]
const ARMURES: Array[String] = ["légère", "moyenne", "lourde", "fortifiée"]
const LONGUEUR_LIGNE_MAX := 260
const PARAMETRES_SANS_CHIFFRE: Array[String] = ["kind", "unite", "sens", "ressource", "type_degats"]
## Stats d'avant le lot 9 dont le chiffre se calcule (esquive) ou ne se lit pas (marché noir) :
## leurs tests propres existent déjà.
const STATS_AU_CHIFFRE_CALCULE: Array[String] = ["esquive", "marche_noir"]

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
					and (effet[cle] is float or effet[cle] is int)
				):
					# Un ratio se lit en pourcentage (« 30 % »), pas en fraction (« 0,3 »).
					var facteur := 100.0 if cle in ["ratio", "ratio_degats"] else 1.0
					attendus.append(_fr(float(effet[cle]) * facteur))
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
			"degats_classe", "etat_degats", "etat_duree", "degats_contre_etat":
				# Des pourcentages : +25 % de dégâts, +30 % de durée, +30 % contre un état.
				attendus.append(_fr(float(effet["valeur"]) * 100.0))
			"epines_degats", "epines_premier_coup", "epines_soin", "epines_reduction":
				attendus.append(_fr(float(effet["valeur"]) * 100.0))
			"pv_max_mult", "soin_pv_manquants", "degats_par_pv_max":
				attendus.append(_fr(float(effet["valeur"]) * 100.0))
			"epines_croissantes":
				attendus.append(_fr(float(effet["valeur"]) * 100.0))
				attendus.append(_fr(float(effet["max"]) * 100.0))
			"regen_croissante", "armure_croissante":
				attendus.append(_fr(float(effet["valeur"])))
				attendus.append(_fr(float(effet["max"])))
			"soin_periodique":
				attendus.append(_fr(float(effet["ratio"]) * 100.0))
				attendus.append(_fr(float(effet["tous_les"])))
			"resurrection":
				# Un pourcentage entier : 50 s'écrit « 50 % », pas « 5 000 % ».
				attendus.append(_fr(float(effet["valeur"])) + "\u00a0%")
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
	verifier_egal(
		offres.size(), _donnees.armes.size() + _donnees.ameliorations.size(), "une par offre"
	)
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


# --- Mécaniques du lot 9 (T9.21) ---------------------------------------------------------------


## Valeur valide d'un paramètre numérique selon sa contrainte (`Donnees._spec`).
func _valeur_de(spec: Dictionary) -> float:
	var mini := float(spec["min"])
	if bool(spec["entier"]):
		return maxf(mini, 1.0) + 1.0
	return 0.5 if bool(spec["exclu"]) or mini <= 0.0 else mini + 0.5


func _sous_effet_factice(kind: String, specs: Array) -> Dictionary:
	var effet: Dictionary = {"kind": kind}
	for brut: Variant in specs:
		var spec: Dictionary = brut
		effet[String(spec["nom"])] = _valeur_de(spec)
	match kind:
		"tournant":
			effet["sens"] = "horaire"
		"siphon":
			effet["ressource"] = "mana"
		"invocation":
			effet["unite"] = "inconnue"
		"vulnerabilite":
			effet["type_degats"] = -1
	return effet


func _arme_factice(effets: Array, statuts: Array = []) -> Dictionary:
	var arme: Dictionary = (_donnees.armes["lame_de_fil"] as Dictionary).duplicate(true)
	arme["effets"] = effets
	arme["statuts"] = statuts
	return arme


## Une fiche valide par stat (et par valeur de sa clé), avec les paramètres que le schéma exige.
func _stats_factices() -> Array[Dictionary]:
	var sortie: Array[Dictionary] = []
	for stat: String in Donnees.STATS_AMELIORATION:
		var base: Dictionary = {"stat": stat, "valeur": 0.5}
		if stat in Donnees.STATS_SANS_VALEUR:
			base.erase("valeur")
			for brut: Variant in DonneesLot9.specs_sans_valeur(stat):
				var spec: Dictionary = brut
				base[String(spec["nom"])] = _valeur_de(spec)
			if stat == "copie_prochaine_offre":
				base["raretes_max"] = Types.Rarete.RARE
		if stat in Donnees.STATS_ENTIERES:
			base["valeur"] = 1
		if stat in Donnees.STATS_CROISSANTES:
			base["max"] = 3.0
		if stat == "degats_type":
			base["type_degats"] = Types.TypeDegats.TRANCHANT
		if stat == "degats_type" or stat == "degats_global":
			base["categorie"] = "A"
		if Donnees.STATS_A_CLE.has(stat):
			var def: Array = Donnees.STATS_A_CLE[stat]
			for nom: String in def[1]:
				var variante := base.duplicate()
				variante[String(def[0])] = nom
				sortie.append(variante)
			continue
		sortie.append(base)
	return sortie


func _fiche_amelio(effet: Dictionary) -> Dictionary:
	return {"id": "factice", "effets": [effet]}


## Toutes les lignes que les mécaniques du lot 9 peuvent produire, avec leur fiche.
func _lignes_lot9() -> Array[String]:
	var lignes: Array[String] = []
	var kinds: Dictionary = Donnees._kinds_effets()
	for kind: String in kinds:
		var fiche := _arme_factice([_sous_effet_factice(kind, kinds[kind])])
		lignes.append(DescriptionOffre.ligne_effet(fiche, Types.Genre.ARME, _donnees))
	var kinds_statuts: Dictionary = Donnees._kinds_statuts()
	for kind: String in kinds_statuts:
		var statut := _sous_effet_factice(kind, kinds_statuts[kind])
		var fiche := _arme_factice(_arme_factice([])["effets"] as Array, [statut])
		fiche["effets"] = [{"kind": "cible_unique"}]
		lignes.append(DescriptionOffre.ligne_effet(fiche, Types.Genre.ARME, _donnees))
	for effet: Dictionary in _stats_factices():
		var ligne := DescriptionOffre.ligne_effet(
			_fiche_amelio(effet), Types.Genre.AMELIORATION, _donnees
		)
		lignes.append(ligne)
	return lignes


func test_chaque_nouveau_genre_statut_champ_et_stat_a_son_modele() -> void:
	var kinds_effets: Array = Donnees._kinds_effets().keys()
	var kinds_statuts: Array = Donnees._kinds_statuts().keys()
	kinds_effets.sort()
	kinds_statuts.sort()
	var effets_modeles: Array = DescriptionOffre.EFFETS.duplicate()
	var statuts_modeles: Array = DescriptionOffre.STATUTS.duplicate()
	var stats_modeles: Array = DescriptionOffre.STATISTIQUES.duplicate()
	var stats_schema: Array = Donnees.STATS_AMELIORATION.duplicate()
	effets_modeles.sort()
	statuts_modeles.sort()
	stats_modeles.sort()
	stats_schema.sort()
	verifier_egal(
		effets_modeles, kinds_effets, "un modèle par genre d'effet du schéma, pas un de plus"
	)
	verifier_egal(statuts_modeles, kinds_statuts, "un modèle par statut du schéma, pas un de plus")
	verifier_egal(
		stats_modeles, stats_schema, "un modèle par statistique du schéma, pas un de plus"
	)
	for kind: String in kinds_effets:
		var specs: Array = Donnees._kinds_effets()[kind]
		var effet := _sous_effet_factice(kind, specs)
		var ligne := DescriptionOffre.ligne_effet(
			_arme_factice([effet]), Types.Genre.ARME, _donnees
		)
		_verifier_ligne_pleine(ligne, "effet « %s »" % kind, effet)
	for kind: String in kinds_statuts:
		var statut := _sous_effet_factice(kind, Donnees._kinds_statuts()[kind])
		var fiche := _arme_factice([{"kind": "cible_unique"}], [statut])
		var ligne := DescriptionOffre.ligne_effet(fiche, Types.Genre.ARME, _donnees)
		_verifier_ligne_pleine(ligne, "statut « %s »" % kind, statut)
	for effet: Dictionary in _stats_factices():
		var ligne := DescriptionOffre.ligne_effet(
			_fiche_amelio(effet), Types.Genre.AMELIORATION, _donnees
		)
		var sans_chiffre: Dictionary = {} if effet["stat"] in STATS_AU_CHIFFRE_CALCULE else effet
		_verifier_ligne_pleine(ligne, "stat « %s » %s" % [effet["stat"], effet], sans_chiffre)


## Une ligne non vide, sans clé de traduction restée telle quelle, avec les chiffres de la fiche.
func _verifier_ligne_pleine(ligne: String, nom: String, fiche: Dictionary) -> void:
	verifier_faux(ligne.is_empty(), "%s : ligne vide" % nom)
	verifier_faux(
		ligne.contains("BOUTIQUE_"), "%s : clé de texte sans valeur dans « %s »" % [nom, ligne]
	)
	verifier_faux(ligne.contains("%" + "s"), "%s : modèle non rempli dans « %s »" % [nom, ligne])
	for cle: String in fiche:
		if cle in PARAMETRES_SANS_CHIFFRE or not (fiche[cle] is float or fiche[cle] is int):
			continue
		if cle == "raretes_max" or cle == "categorie":
			continue
		var valeur := float(fiche[cle])
		var lu := _sans_milliers(ligne)
		var direct := _fr(valeur)
		var en_pourcent := _fr(valeur * 100.0)
		verifier(
			lu.contains(direct) or lu.contains(en_pourcent),
			"%s : le chiffre de « %s » (%s) manque dans « %s »" % [nom, cle, direct, ligne]
		)


func test_les_champs_d_arme_du_lot_9_ont_leur_ligne() -> void:
	var base := _arme_factice([{"kind": "cible_unique"}])
	var cas: Array[Dictionary] = [
		{"degats_par_pv_max": 0.02},
		{"degats_par_exemplaire": 0.25},
		{"degats_par_amelioration": {"stat": "epines", "ratio": 0.1}},
		{"type_secondaire": "epines"},
	]
	verifier_egal(cas.size(), DescriptionOffre.CHAMPS_ARME.size(), "un cas par champ d'arme")
	var sans := DescriptionOffre.ligne_effet(base, Types.Genre.ARME, _donnees)
	for champs: Dictionary in cas:
		var arme := base.duplicate(true)
		arme.merge(champs, true)
		var ligne := DescriptionOffre.ligne_effet(arme, Types.Genre.ARME, _donnees)
		verifier(ligne.length() > sans.length(), "le champ %s ajoute une ligne" % champs.keys())
		verifier_faux(ligne.contains("BOUTIQUE_"), "clé de texte sans valeur : %s" % ligne)
	var par_amelio := base.duplicate(true)
	par_amelio["degats_par_amelioration"] = {"stat": "epines", "ratio": 0.1}
	var ligne_amelio := DescriptionOffre.ligne_effet(par_amelio, Types.Genre.ARME, _donnees)
	verifier(ligne_amelio.contains("10" + NBSP + "%"), "le ratio se lit : %s" % ligne_amelio)
	verifier(ligne_amelio.contains("épines"), "la stat citée se lit : %s" % ligne_amelio)


func test_un_champ_d_arme_inconnu_ne_passe_pas_en_silence() -> void:
	var arme := _arme_factice([{"kind": "cible_unique"}])
	arme["type_secondaire"] = "foudre"
	verifier_faux(DescriptionOffre.est_complete(arme, Types.Genre.ARME), "type secondaire inconnu")
	arme["type_secondaire"] = ""
	arme["degats_par_amelioration"] = {"stat": "magie_noire", "ratio": 0.1}
	verifier_faux(DescriptionOffre.est_complete(arme, Types.Genre.ARME), "stat citée inconnue")
	verifier_egal(DescriptionOffre.ligne_effet(arme, Types.Genre.ARME, _donnees), "", "ligne vide")


func test_la_ligne_de_chaque_mecanique_dit_son_plafond_ou_sa_borne_quand_elle_en_a_une() -> void:
	var partie := _donnees.partie
	var vulnerabilite: Dictionary = partie["vulnerabilite"]
	var statut := {"kind": "vulnerabilite", "ratio": 0.1, "duree": 4.0, "type_degats": -1}
	var arme := _arme_factice([{"kind": "cible_unique"}], [statut])
	var ligne := DescriptionOffre.ligne_effet(arme, Types.Genre.ARME, _donnees)
	var plafond := _fr(float(vulnerabilite["plafond"]) * 100.0) + NBSP + "%"
	verifier(
		ligne.contains("jusqu’à +" + plafond),
		"vulnérabilité : plafond %s dans « %s »" % [plafond, ligne]
	)
	var malediction: Dictionary = partie["malediction"]
	var limite := _fr(float(malediction["plafond"]) * 100.0) + NBSP + "%"
	for kind: String in ["malediction_degats", "malediction_toucher"]:
		var maudit := {"kind": kind, "ratio": 0.3, "duree": 5.0}
		var fiche := _arme_factice([{"kind": "cible_unique"}], [maudit])
		var ligne_m := DescriptionOffre.ligne_effet(fiche, Types.Genre.ARME, _donnees)
		verifier(ligne_m.contains(limite), "%s : plafond %s dans « %s »" % [kind, limite, ligne_m])
	var borne := _fr(float((partie["armes"] as Dictionary)["bonus_selon_stat_max"]))
	for champ: String in ["degats_par_pv_max", "degats_par_exemplaire"]:
		var fiche_m5 := _arme_factice([{"kind": "cible_unique"}])
		fiche_m5[champ] = 0.1
		var ligne_5 := DescriptionOffre.ligne_effet(fiche_m5, Types.Genre.ARME, _donnees)
		verifier(
			ligne_5.contains("au plus %s fois" % borne),
			"%s : borne M5 dans « %s »" % [champ, ligne_5]
		)
	var croissance := {
		"stat": "degats_global",
		"valeur": 0.1,
		"categorie": "A",
		"croissance": 0.02,
		"croissance_max": 0.3
	}
	var ligne_c := DescriptionOffre.ligne_effet(
		_fiche_amelio(croissance), Types.Genre.AMELIORATION, _donnees
	)
	var reglage: Dictionary = partie["ameliorations"]
	verifier(ligne_c.contains("+30" + NBSP + "%"), "croissance : sa borne dans « %s »" % ligne_c)
	verifier(
		ligne_c.contains(_fr(float(reglage["croissance_pas_s"])) + " s"),
		"croissance : le pas dans « %s »" % ligne_c
	)
	verifier(
		ligne_c.contains("×" + _fr(float(reglage["facteur_degats_max"]))),
		"dégâts : plafond du produit dans « %s »" % ligne_c
	)
	for stat: String in ["epines_croissantes", "regen_croissante", "armure_croissante"]:
		var croissante := {"stat": stat, "valeur": 0.5, "max": 3.0}
		var ligne_s := DescriptionOffre.ligne_effet(
			_fiche_amelio(croissante), Types.Genre.AMELIORATION, _donnees
		)
		verifier(ligne_s.contains("jusqu’à"), "%s : sa borne dans « %s »" % [stat, ligne_s])


func test_typographie_francaise_des_nouvelles_lignes() -> void:
	var avant_ponctuation := RegEx.create_from_string("(?<!\\x{00A0})[:;?!%]")
	var decimale_pointee := RegEx.create_from_string("[0-9]\\.[0-9]")
	var guillemet_colle := RegEx.create_from_string("«(?!\\x{00A0})|(?<!\\x{00A0})»")
	for ligne: String in _lignes_lot9():
		verifier(
			avant_ponctuation.search(ligne) == null,
			"espace insécable manquante dans « %s »" % ligne
		)
		verifier(decimale_pointee.search(ligne) == null, "point décimal dans « %s »" % ligne)
		verifier(
			guillemet_colle.search(ligne) == null, "guillemets sans insécable dans « %s »" % ligne
		)
		verifier_faux("'" in ligne, "apostrophe droite dans « %s »" % ligne)
		verifier_faux(ligne.contains("  "), "espaces doublées dans « %s »" % ligne)


func test_les_nouvelles_infobulles_restent_courtes() -> void:
	# L'infobulle n'a pas la largeur d'une carte : elle se replie, mais une ligne démesurée reste
	# illisible aux trois échelles d'interface. On borne donc la longueur de la plus longue.
	var plus_longue := ""
	for ligne: String in _lignes_lot9():
		if ligne.length() > plus_longue.length():
			plus_longue = ligne
	verifier(
		plus_longue.length() <= LONGUEUR_LIGNE_MAX,
		"ligne trop longue (%d) : %s" % [plus_longue.length(), plus_longue]
	)


func test_les_cles_de_textes_boutique_ont_toutes_une_valeur_francaise() -> void:
	var textes := CsvTextes.lire(CSV_BOUTIQUE)
	verifier(textes.size() > 100, "le fichier est lu")
	for cle: String in textes:
		verifier_faux(String(textes[cle]).strip_edges().is_empty(), "%s : valeur vide" % cle)
	for stat: String in Donnees.STATS_AMELIORATION:
		verifier(textes.has("BOUTIQUE_STAT_" + stat.to_upper()), "nom court de la stat %s" % stat)


# --- Ce que disent les gabarits de T9.10 : la règle que la simulation applique ----------------


func test_la_ligne_d_un_palier_de_type_dit_les_communes_du_meme_type_et_le_plafond() -> void:
	var plat := _sans_milliers(_ligne("meule_des_lames", Types.Genre.AMELIORATION)).replace(
		NBSP, " "
	)
	verifier(plat.contains("+5 % de dégâts par arme commune du même type possédée"), plat)
	verifier(plat.contains("×20"), "le plafond du produit : " + plat)


func test_la_ligne_d_une_croissance_dit_le_pas_de_partie_et_le_total_maximal() -> void:
	var plat := _ligne("metronome_patient", Types.Genre.AMELIORATION).replace(NBSP, " ")
	verifier(plat.contains("+2 % de dégâts par tranche de 30 s de partie, jusqu’à +30 %"), plat)
	verifier_faux(plat.contains("du même type"), "le global compte les communes de tous les types")


func test_les_armes_zone_posee_bombe_et_invocation_disent_degats_de_base_et_portee() -> void:
	# Les vraies armes de ces genres n'existent pas toutes : on lit des armes fictives, en boucle.
	var effets: Array[Dictionary] = [
		{
			"kind": "zone_posee",
			"rayon": 200.0,
			"duree": 5.0,
			"periode": 1.5,
			"ratio": 0.3,
			"max_actives": 4
		},
		{"kind": "bombe", "delai": 2.5, "rayon": 150.0, "ratio": 0.8, "max_actives": 3},
		{
			"kind": "invocation",
			"unite": "inconnue",
			"duree": 12.0,
			"ratio_degats": 0.6,
			"max_actives": 5
		},
	]
	for effet: Dictionary in effets:
		var kind := String(effet["kind"])
		for degats: float in [12.0, 37.0, 480.0]:
			for portee: int in Donnees.PORTEES:
				var arme := _arme_factice([effet])
				arme["degats"] = degats
				arme["recharge"] = 3.5
				arme["portee"] = portee
				var ligne := DescriptionOffre.ligne_effet(arme, Types.Genre.ARME, _donnees)
				var plat := _sans_milliers(ligne)
				var contexte := "%s, %s dégâts, portée %d : « %s »" % [kind, degats, portee, ligne]
				verifier(
					plat.contains(_fr(degats) + " dégâts de base"), "dégâts de base : " + contexte
				)
				verifier(plat.contains("portée " + str(portee)), "portée : " + contexte)
				verifier(plat.contains("3,5"), "recharge : " + contexte)
				verifier(
					plat.contains("30" + NBSP + "%") or kind != "zone_posee",
					"ratio en % : " + contexte
				)
				for attendu: String in _chiffres_attendus(arme, Types.Genre.ARME):
					verifier(plat.contains(attendu), "« %s » absent : %s" % [attendu, contexte])
				verifier_faux(plat.contains("BOUTIQUE_"), "clé brute : " + contexte)
