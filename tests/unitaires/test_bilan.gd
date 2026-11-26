extends CasDeTest
## Bilan de partie (T11.2) : les compteurs de `docs/defis.md` §2, produits par la simulation pour
## chaque joueur, déterministes, jamais négatifs ni non finis, sans effet sur la partie.

const DT := 0.05
const DOC := "res://docs/defis.md"

var d: Donnees


func avant_chaque() -> void:
	d = AidesPartie.donnees()


## Les compteurs du tableau du §2 de `docs/defis.md`, lus dans le document (pas une liste en dur).
func _compteurs_du_document() -> Array[String]:
	var noms: Array[String] = []
	var dans_le_tableau := false
	for ligne: String in FileAccess.get_file_as_string(DOC).split("\n"):
		if ligne.begins_with("## 2."):
			dans_le_tableau = true
			continue
		if dans_le_tableau and ligne.begins_with("## "):
			break
		if dans_le_tableau and ligne.begins_with("| `"):
			noms.append(ligne.split("`")[1])
	return noms


func test_chaque_compteur_de_la_liste_est_produit() -> void:
	var attendus := _compteurs_du_document()
	verifier(attendus.size() >= 30, "le tableau du §2 a été lu (%d compteurs)" % attendus.size())
	var p := AidesPartie.partie(d, 11, 1)
	var bilan := p.bilan_joueur(1)
	for nom: String in attendus:
		verifier(bilan.has(nom), "le bilan porte « %s »" % nom)
	for nom: String in BilanPartie.noms():
		verifier(bilan.has(nom), "et tout ce que `noms()` annonce : %s" % nom)
	verifier_egal(bilan.size(), BilanPartie.noms().size(), "ni plus, ni moins")


func test_chaque_type_genre_et_statut_des_donnees_a_son_compteur_d_armes() -> void:
	var noms := BilanPartie.noms()
	for type_degats: int in Types.NOMS_TYPES.size():
		verifier(BilanPartie.nom_type(type_degats) in noms, "type %d" % type_degats)
	var attendus_types: Array[String] = [
		"armes_type_tranchant",
		"armes_type_percant",
		"armes_type_magique",
		"armes_type_siege",
		"armes_type_chaos",
	]
	for type_degats: int in 5:
		verifier_egal(BilanPartie.nom_type(type_degats), attendus_types[type_degats])
	var genres: Dictionary = {}
	var statuts: Dictionary = {}
	for id: String in d.armes:
		var arme: Dictionary = d.armes[id]
		for effet: Variant in arme["effets"] as Array:
			genres[str((effet as Dictionary)["kind"])] = true
		for statut: Variant in arme["statuts"] as Array:
			statuts[str((statut as Dictionary)["kind"])] = true
	for genre: String in genres:
		verifier(("armes_genre_" + genre) in noms, "genre %s" % genre)
	for statut: String in statuts:
		verifier(("armes_statut_" + statut) in noms, "statut %s" % statut)


func test_une_arme_compte_pour_chacun_de_ses_genres_et_de_ses_statuts() -> void:
	for id: String in d.armes:
		var arme: Dictionary = d.armes[id]
		var bilan := BilanPartie.new()
		bilan.achat_arme(arme)
		var genres: Dictionary = {}
		for effet: Variant in arme["effets"] as Array:
			genres[str((effet as Dictionary)["kind"])] = true
		var statuts: Dictionary = {}
		for statut: Variant in arme["statuts"] as Array:
			statuts[str((statut as Dictionary)["kind"])] = true
		# Armes achetées et distinctes, le type, chaque genre, chaque statut : rien d'autre ne bouge.
		var attendu := 3.0 + float(genres.size()) + float(statuts.size())
		var somme := 0.0
		for nom: String in BilanPartie.noms():
			if nom.begins_with("armes_") or nom == "armes_distinctes":
				somme += float(bilan.valeurs[nom])
		verifier_proche(somme, attendu, 0.0001, id)
		verifier_egal(bilan.valeurs[BilanPartie.nom_type(int(arme["type_degats"]))], 1.0, id)
		for genre: String in genres:
			verifier_egal(bilan.valeurs["armes_genre_" + genre], 1.0, "%s : %s" % [id, genre])
		for statut: String in statuts:
			verifier_egal(bilan.valeurs["armes_statut_" + statut], 1.0, "%s : %s" % [id, statut])


func test_les_exemplaires_d_une_meme_arme_comptent_pour_une_arme_distincte() -> void:
	var ids: Array[String] = []
	for id: String in d.armes:
		ids.append(id)
	ids.sort()
	var bilan := BilanPartie.new()
	for _k: int in 3:
		bilan.achat_arme(d.armes[ids[0]])
	verifier_egal(bilan.valeurs["armes_achetees"], 3.0)
	verifier_egal(bilan.valeurs["armes_distinctes"], 1.0)
	bilan.achat_arme(d.armes[ids[1]])
	verifier_egal(bilan.valeurs["armes_distinctes"], 2.0)


func test_les_ameliorations_de_revenu_et_leurs_statistiques_distinctes_sont_comptees() -> void:
	var bilan := BilanPartie.new()
	var stats_vues: Dictionary = {}
	var revenus := 0
	for id: String in d.ameliorations:
		var amelio: Dictionary = d.ameliorations[id]
		bilan.achat_amelioration(amelio)
		if int(amelio["categorie"]) == Types.Categorie.REVENU:
			revenus += 1
		for effet: Variant in amelio["effets"] as Array:
			var stat := str((effet as Dictionary)["stat"])
			if stat in BilanPartie.STATS_REVENU:
				stats_vues[stat] = true
	verifier_egal(bilan.valeurs["ameliorations_achetees"], float(d.ameliorations.size()))
	verifier_egal(bilan.valeurs["ameliorations_revenu_achetees"], float(revenus))
	verifier_egal(bilan.valeurs["stats_revenu_distinctes"], float(stats_vues.size()))
	verifier(stats_vues.size() >= 1)


func test_la_serie_de_manches_sans_degats_continue_puis_retombe() -> void:
	var bilan := BilanPartie.new()
	for _k: int in 4:
		bilan.fin_de_manche()
	verifier_egal(bilan.valeurs["manches_sans_degats_de_suite"], 4.0)
	bilan.perte_pv()
	bilan.fin_de_manche()
	for _k: int in 2:
		bilan.fin_de_manche()
	verifier_egal(bilan.valeurs["manches_sans_degats_de_suite"], 4.0, "le maximum reste")
	for _k: int in 3:
		bilan.fin_de_manche()
	verifier_egal(bilan.valeurs["manches_sans_degats_de_suite"], 5.0, "une série de 5 dépasse 4")


func test_la_serie_d_eliminations_est_une_fenetre_glissante_de_cinq_secondes() -> void:
	var bilan := BilanPartie.new()
	for _k: int in BilanPartie.FENETRE_PAS:
		bilan.pas(100.0, 100.0, 0, 0, 1)
	verifier_egal(bilan.valeurs["serie_eliminations_5s"], 100.0, "100 pas à 1 par pas")
	var autre := BilanPartie.new()
	for k: int in 400:
		autre.pas(100.0, 100.0, 0, 0, 2 if k % 100 == 0 else 0)
	verifier_egal(autre.valeurs["serie_eliminations_5s"], 2.0, "des éliminations espacées de 5 s")
	var rafale := BilanPartie.new()
	for k: int in 300:
		rafale.pas(100.0, 100.0, 0, 0, 10 if k == 150 else 0)
	verifier_egal(rafale.valeurs["serie_eliminations_5s"], 10.0)


func test_pv_min_ratio_garde_le_plus_bas_rapport_et_reste_dans_zero_un() -> void:
	var bilan := BilanPartie.new()
	verifier_egal(bilan.valeurs["pv_min_ratio"], 1.0)
	bilan.pas(500.0, 1000.0, 0, 0, 0)
	bilan.pas(800.0, 1000.0, 0, 0, 0)
	verifier_proche(float(bilan.valeurs["pv_min_ratio"]), 0.5, 0.0001)
	bilan.pas(-50.0, 1000.0, 0, 0, 0)
	verifier_egal(bilan.valeurs["pv_min_ratio"], 0.0, "jamais négatif")
	bilan.pas(NAN, 1000.0, 0, 0, 0)
	bilan.pas(10.0, 0.0, 0, 0, 0)
	verifier_egal(bilan.valeurs["pv_min_ratio"], 0.0)


func test_les_montants_non_finis_ou_negatifs_ne_changent_aucun_compteur() -> void:
	var bilan := BilanPartie.new()
	for mauvais: float in [NAN, INF, -INF, -5.0, 0.0]:
		bilan.soin(mauvais)
		bilan.epines(mauvais)
		bilan.debut_de_la_premiere_manche(mauvais)
	verifier_egal(bilan.valeurs["pv_soignes"], 0.0)
	verifier_egal(bilan.valeurs["degats_epines"], 0.0)
	verifier_egal(bilan.valeurs["mana_max_avant_manche_1"], 0.0)


func test_a_dict_est_une_copie_et_depuis_dict_refuse_les_bilans_malformes() -> void:
	var bilan := BilanPartie.new()
	bilan.soin(12.0)
	var copie := bilan.a_dict()
	copie["pv_soignes"] = 999.0
	verifier_egal(bilan.valeurs["pv_soignes"], 12.0, "la copie ne touche pas au bilan")
	var relu := BilanPartie.depuis_dict(bilan.a_dict())
	verifier_non_nul(relu)
	if relu != null:
		verifier_egal(relu.valeurs, bilan.valeurs)
	for nom: String in BilanPartie.noms():
		var manquant := bilan.a_dict()
		manquant.erase(nom)
		verifier_nul(BilanPartie.depuis_dict(manquant), "sans %s" % nom)
		for mauvais: Variant in [NAN, INF, -1.0, "x", null]:
			var faux := bilan.a_dict()
			faux[nom] = mauvais
			verifier_nul(BilanPartie.depuis_dict(faux), "%s = %s" % [nom, mauvais])
	var en_trop := bilan.a_dict()
	en_trop["inconnu"] = 1.0
	verifier_nul(BilanPartie.depuis_dict(en_trop), "un compteur de trop")


# --- Parties complètes ---------------------------------------------------------------------------


## Joue une partie d'un robot (stratégie `nom`) jusqu'à la manche `jusqu_a` ; rend la suite des
## bilans relevés une fois par manche.
func _jouer(graine: int, strategie: String, jusqu_a: int) -> Array[Dictionary]:
	var p := AidesPartie.partie(d, graine, 1, 8.0)
	var suite: Array[Dictionary] = []
	var derniere := -1
	var pas := 0
	while not p.est_terminee() and pas < 40000:
		var v := p.vue_arene(1, 1)
		if v == null:
			break
		if v.manche != derniere:
			derniere = v.manche
			StrategiesJoueur.jouer(strategie, p, d, 1, false)
			suite.append(p.bilan_joueur(1))
		if v.manche >= jusqu_a:
			break
		p.avancer(DT)
		pas += 1
	suite.append(p.bilan_joueur(1))
	return suite


func test_aucun_compteur_n_est_negatif_ni_non_fini() -> void:
	for strategie: String in StrategiesJoueur.TOUTES:
		for graine: int in [3, 17]:
			for bilan: Dictionary in _jouer(graine, strategie, 6):
				for nom: String in bilan:
					var x := float(bilan[nom])
					verifier(
						is_finite(x) and x >= 0.0, "%s/%d : %s = %s" % [strategie, graine, nom, x]
					)
				verifier(float(bilan["pv_min_ratio"]) <= 1.0)


func test_les_compteurs_croissants_ne_decroissent_jamais() -> void:
	var decroissants: Array[String] = ["pv_min_ratio"]
	for strategie: String in [StrategiesJoueur.RAISONNABLE, StrategiesJoueur.BONNE]:
		var suite := _jouer(5, strategie, 7)
		for k: int in suite.size() - 1:
			for nom: String in BilanPartie.noms():
				if nom in decroissants or nom in ["victoire", "dernier_rempart"]:
					continue
				verifier(
					float(suite[k + 1][nom]) >= float(suite[k][nom]),
					(
						"%s : %s ne décroît pas (%s → %s)"
						% [strategie, nom, suite[k][nom], suite[k + 1][nom]]
					)
				)
			verifier(float(suite[k + 1]["pv_min_ratio"]) <= float(suite[k]["pv_min_ratio"]))


func test_un_robot_qui_achete_remplit_les_compteurs_d_achats() -> void:
	var suite := _jouer(5, StrategiesJoueur.BONNE, 6)
	var fin: Dictionary = suite[suite.size() - 1]
	verifier(float(fin["armes_achetees"]) >= 1.0, "des armes achetées")
	verifier(float(fin["or_depense"]) > 0.0, "de l'or dépensé")
	verifier(float(fin["or_gagne_total"]) > 0.0, "de l'or gagné")
	verifier(float(fin["or_gagne_primes"]) <= float(fin["or_gagne_total"]), "primes ⊂ total")
	verifier(float(fin["or_max_detenu"]) >= 1.0, "or_max %s" % fin["or_max_detenu"])
	verifier(float(fin["armes_equipees_max"]) >= 1.0, "eq_max %s" % fin["armes_equipees_max"])
	var par_type := 0.0
	for type_degats: int in 5:
		par_type += float(fin[BilanPartie.nom_type(type_degats)])
	verifier_egal(par_type, float(fin["armes_achetees"]), "chaque arme compte pour un type")


func test_le_robot_passif_n_achete_rien() -> void:
	var fin := _jouer(5, StrategiesJoueur.PASSIVE, 5).back() as Dictionary
	for nom: String in ["armes_achetees", "ameliorations_achetees", "or_depense"]:
		verifier_egal(fin[nom], 0.0, nom)
	verifier(float(fin["or_gagne_total"]) > 0.0, "il touche quand même son revenu")


func test_le_bilan_est_deterministe() -> void:
	for strategie: String in StrategiesJoueur.TOUTES:
		verifier_egal(_jouer(9, strategie, 6), _jouer(9, strategie, 6), strategie)


func test_chaque_joueur_a_son_propre_bilan() -> void:
	var p := AidesPartie.partie(d, 21, 2, 8.0)
	for _k: int in 2:
		StrategiesJoueur.jouer(StrategiesJoueur.BONNE, p, d, 1, false)
	AidesPartie.pas(p, 400)
	var un := p.bilan_joueur(1)
	var deux := p.bilan_joueur(2)
	verifier(float(un["armes_achetees"]) >= 1.0)
	verifier_egal(deux["armes_achetees"], 0.0, "le second n'a rien acheté")
	verifier_egal(deux["or_depense"], 0.0)
	verifier(float(un["or_depense"]) > 0.0)
	verifier_egal(p.bilan_joueur(99), {}, "un identifiant inconnu")


func test_le_bilan_ne_change_pas_la_simulation() -> void:
	var sans := AidesPartie.partie(d, 33, 1, 8.0)
	var avec := AidesPartie.partie(d, 33, 1, 8.0)
	var h_sans := 0
	var h_avec := 0
	for pas in 600:
		sans.avancer(DT)
		avec.avancer(DT)
		avec.bilan_joueur(1)
		var vs := sans.vue_arene(1, 1)
		var va := avec.vue_arene(1, 1)
		h_sans = hash([h_sans, str(vs.ennemis_pos), str(vs.ennemis_pv), vs.tour_pv, vs.argent])
		h_avec = hash([h_avec, str(va.ennemis_pos), str(va.ennemis_pv), va.tour_pv, va.argent])
	verifier_egal(h_sans, h_avec, "même empreinte de vue sur 600 pas")


func test_la_victoire_vient_de_la_partie_et_survit_au_mode_sans_fin() -> void:
	var p := AidesPartie.partie(d, 41, 2, 8.0)
	verifier_egal(p.bilan_joueur(1)["victoire"], 0.0)
	var joueur: JoueurPartie = p._joueur(1)
	p._vaincre(joueur)
	verifier_egal(p.bilan_joueur(1)["victoire"], 1.0, "le boss est vaincu")
	verifier_egal(p.bilan_joueur(2)["victoire"], 0.0, "pas l'autre joueur")
	joueur.victorieux = false
	joueur.sans_fin = true
	verifier_egal(p.bilan_joueur(1)["victoire"], 1.0, "reprendre en sans fin ne l'efface pas")


func test_la_derniere_tour_debout_n_est_connue_qu_a_la_fin_de_la_partie() -> void:
	var p := AidesPartie.partie(d, 41, 2, 8.0)
	verifier_egal(p.bilan_joueur(1)["dernier_rempart"], 0.0, "pas avant la fin de la partie")
	var pas := 0
	while not p.est_terminee() and pas < 60000:
		p.avancer(DT)
		pas += 1
	verifier(p.est_terminee(), "la partie de deux robots passifs finit")
	var rempart := p.vue_globale().dernier_rempart
	var nombre := 0.0
	for id: int in [1, 2]:
		var bilan := p.bilan_joueur(id)
		nombre += float(bilan["dernier_rempart"])
		verifier_egal(bilan["dernier_rempart"] == 1.0, id == rempart, "joueur %d" % id)
		verifier_egal(bilan["victoire"], 0.0)
		verifier(float(bilan["manche_atteinte"]) >= 1.0)
	verifier(nombre <= 1.0, "au plus une dernière tour debout")


func test_un_joueur_parti_n_a_plus_de_bilan() -> void:
	var p := AidesPartie.partie(d, 41, 2, 8.0)
	p.retirer_joueur(2)
	verifier_egal(p.bilan_joueur(2), {})
	verifier(not p.bilan_joueur(1).is_empty())
