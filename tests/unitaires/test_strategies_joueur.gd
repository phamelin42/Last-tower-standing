extends CasDeTest
## Les robots de mesure de l'équilibrage suivent les règles du lot 12 (D23) : une arme déjà portée
## se monte de niveau quand l'arsenal est plein, les raretés de fin de partie s'achètent, aucune
## vente, et la « bonne » stratégie cherche les améliorations de revenu d'une partie gagnable (Phil,
## 27/11/2026 : « suffisamment d'améliorations d'income »).

var d: Donnees


func avant_chaque() -> void:
	d = AidesPartie.donnees()


## Joue la « bonne » stratégie jusqu'à `manche` et rend la dernière vue d'arène.
func _jusqu_a(graine: int, manche: int) -> VueArene:
	var p := Partie.new(d, AidesPartie.config(graine))
	p.ajouter_joueur(1, "Robot")
	p.demarrer()
	var vue: VueArene = p.vue_arene(1, 1)
	for _t: int in 4000:
		vue = p.vue_arene(1, 1)
		if vue == null or vue.manche >= manche:
			break
		var fin := vue.temps_restant <= 2.0 and vue.phase == Types.Phase.MANCHE
		StrategiesJoueur.jouer(StrategiesJoueur.BONNE, p, d, 1, fin)
		p.avancer(1.0)
	return vue


func test_la_bonne_strategie_monte_des_niveaux_quand_l_arsenal_est_plein() -> void:
	for graine: int in [2, 4, 6]:
		var vue := _jusqu_a(graine, 14)
		verifier_non_nul(vue, "graine %d" % graine)
		var niveaux := 0
		for arme: Dictionary in vue.armes:
			niveaux += int(arme["niveau"])
		verifier_egal(
			vue.armes.size(), StrategiesJoueur.ARMES_VISEES, "graine %d : arsenal" % graine
		)
		verifier(niveaux > 2 * vue.armes.size(), "graine %d : %d niveaux" % [graine, niveaux])


func test_une_arme_portee_vaut_son_gain_de_niveau_et_pas_une_arme_nouvelle() -> void:
	var gain := StrategiesJoueur._gain_niveau(d)
	var niveaux: Dictionary = d.partie["niveaux"]
	verifier_proche(gain, float(niveaux["gain_degats"]) + float(niveaux["gain_cadence"]), 0.0001)
	verifier(gain > 0.0 and gain < 1.0, "un niveau vaut moins qu'une arme neuve")


func test_la_bonne_strategie_prefere_les_ameliorations_de_revenu_tant_qu_elle_en_manque() -> void:
	var revenu := ""
	for id: String in d.ameliorations:
		if int((d.ameliorations[id] as Dictionary)["categorie"]) == Types.Categorie.REVENU:
			revenu = id
			break
	verifier(not revenu.is_empty())
	var offre := {
		"id": revenu, "genre": Types.Genre.AMELIORATION, "rarete": 0, "prix": 100, "vendu": false
	}
	var pauvre := VueArene.new()
	pauvre.manche = 12
	# Trois armes au moins : en dessous, la « bonne » stratégie retient toute dépense d'économie.
	for k: int in 3:
		pauvre.armes.append({"id": d.armes.keys()[k], "recharge_ratio": 0.0, "niveau": 1})
	var riche := VueArene.new()
	riche.manche = 12
	riche.armes = pauvre.armes
	riche.ameliorations = {revenu: StrategiesJoueur.REVENUS_VISES}
	var types := PackedInt32Array([1, 1, 1, 1, 1])
	var avant := StrategiesJoueur._valeur_offre(StrategiesJoueur.BONNE, pauvre, d, offre, types)
	var apres := StrategiesJoueur._valeur_offre(StrategiesJoueur.BONNE, riche, d, offre, types)
	verifier(apres > 0.0, "l'offre a une valeur")
	verifier_proche(avant / apres, StrategiesJoueur.BOOST_REVENU, 0.0001, "revenu préféré")
	# Le joueur raisonnable ne change pas de goût.
	var r1 := StrategiesJoueur._valeur_offre(StrategiesJoueur.RAISONNABLE, pauvre, d, offre, types)
	var r2 := StrategiesJoueur._valeur_offre(StrategiesJoueur.RAISONNABLE, riche, d, offre, types)
	verifier_proche(r1, r2, 0.0001)


func test_la_bonne_strategie_achete_des_ameliorations_de_fin_de_partie() -> void:
	for graine: int in [1, 2, 4, 5]:
		var vue := _jusqu_a(graine, 31)
		verifier_non_nul(vue, "graine %d" % graine)
		var tardives := 0
		for id: String in vue.ameliorations:
			if int((d.ameliorations[id] as Dictionary)["rarete"]) >= Types.Rarete.ANCESTRALE:
				tardives += int(vue.ameliorations[id])
		verifier(
			tardives >= 1, "graine %d : %d améliorations de fin de partie" % [graine, tardives]
		)


func test_le_boss_n_est_pas_plafonne() -> void:
	# Phil (D23) : le boss se bat par la puissance, jamais par un plafond de ses PV.
	var ennemis := JSON.new()
	verifier_egal(ennemis.parse(FileAccess.get_file_as_string("res://data/ennemis.json")), OK)
	var boss: Dictionary = (ennemis.data as Dictionary)["boss"]
	verifier(float(boss["pv"]) >= 35000.0, "PV du boss : %s" % boss["pv"])
	var difficulte := JSON.new()
	verifier_egal(difficulte.parse(FileAccess.get_file_as_string("res://data/difficulte.json")), OK)
	var apres: Dictionary = (difficulte.data as Dictionary)["apres_table"]
	verifier(float(apres["pv"]) >= 2.8, "rampe de PV après la manche 20 : %s" % apres["pv"])
