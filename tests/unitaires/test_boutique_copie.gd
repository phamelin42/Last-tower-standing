extends CasDeTest
## `copie_prochaine_offre` (T9.12) : le prochain achat d'une offre de rareté au plus `raretes_max`
## donne un second exemplaire gratuit, une seule fois par exemplaire de l'amélioration.

var d: Donnees
var _boutique: Boutique
var _economie: Economie
var _inventaire: Inventaire


func avant_chaque() -> void:
	d = Donnees.charger()
	for r: int in Types.NOMS_RARETES.size():
		d.ameliorations["copie_%d" % r] = _amelio(
			"copie_%d" % r, Types.Rarete.RARE, {"stat": "copie_prochaine_offre", "raretes_max": r}
		)
		d.ameliorations["cible_%d" % r] = _amelio(
			"cible_%d" % r, r, {"stat": "regen", "valeur": 1.0}
		)
	_boutique = Boutique.new(d, RandomNumberGenerator.new())
	_economie = Economie.new(d)
	_economie.argent = 100000
	_inventaire = Inventaire.new(d)


func _amelio(id: String, rarete: int, effet: Dictionary) -> Dictionary:
	return {
		"id": id,
		"nom": id,
		"description": id,
		"rarete": rarete,
		"prix": 10,
		"categorie": Types.Categorie.AMELIORATION,
		"famille": "boutique",
		"effets": [effet],
	}


func _proposer(ids: Array[String]) -> void:
	_boutique.offres.clear()
	for id: String in ids:
		var fiche: Dictionary = d.ameliorations[id]
		_boutique.offres.append(
			{
				"id": id,
				"genre": Types.Genre.AMELIORATION,
				"rarete": int(fiche["rarete"]),
				"prix": int(fiche["prix"]),
				"vendu": false,
			}
		)


func _acheter(index: int) -> int:
	return _boutique.acheter(index, _economie, _inventaire)


func _nombre(id: String) -> int:
	return int(_inventaire.ameliorations.get(id, 0))


func test_copie_prochaine_offre_double_le_prochain_achat_eligible_une_fois_et_pas_une_offre_plus_rare() -> void:
	for plafond: int in Types.NOMS_RARETES.size():
		avant_chaque()
		_inventaire.ameliorations["copie_%d" % plafond] = 1
		var cibles: Array[String] = []
		for r: int in Types.NOMS_RARETES.size():
			cibles.append("cible_%d" % r)
		_proposer(cibles)
		for r: int in Types.NOMS_RARETES.size():
			var argent := _economie.argent
			verifier_egal(_acheter(r), Types.Resultat.OK)
			verifier_egal(argent - _economie.argent, 10, "un seul prix payé (plafond %d)" % plafond)
		# Les offres de rareté au plus `plafond` sont achetées dans l'ordre : seule la première
		# donne sa copie, car l'exemplaire est consommé.
		var copies := 0
		for r: int in Types.NOMS_RARETES.size():
			copies += _nombre("cible_%d" % r) - 1
		verifier_egal(copies, 1, "une seule copie, plafond %d" % plafond)
		verifier_egal(_nombre("cible_0"), 2, "la première offre éligible est doublée")


func test_une_offre_plus_rare_que_le_plafond_n_est_pas_doublee_et_ne_consomme_rien() -> void:
	for plafond: int in Types.NOMS_RARETES.size() - 1:
		avant_chaque()
		_inventaire.ameliorations["copie_%d" % plafond] = 1
		var plus_rare := "cible_%d" % (plafond + 1)
		_proposer([plus_rare, "cible_0"])
		_acheter(0)
		verifier_egal(_nombre(plus_rare), 1, "plafond %d : pas de copie" % plafond)
		_acheter(1)
		verifier_egal(_nombre("cible_0"), 2, "l'exemplaire n'avait pas été consommé")


func test_chaque_exemplaire_de_l_amelioration_donne_sa_propre_copie() -> void:
	_inventaire.ameliorations["copie_3"] = 2
	_proposer(["cible_0", "cible_1", "cible_2"])
	_acheter(0)
	_acheter(1)
	_acheter(2)
	verifier_egal(_nombre("cible_0"), 2)
	verifier_egal(_nombre("cible_1"), 2)
	verifier_egal(_nombre("cible_2"), 1, "deux exemplaires, deux copies, pas trois")


func test_acheter_la_copie_elle_meme_ne_se_double_pas_avec_elle_meme() -> void:
	_proposer(["copie_3", "cible_0"])
	_acheter(0)
	verifier_egal(_nombre("copie_3"), 1, "la charge n'existait pas avant l'achat")
	_acheter(1)
	verifier_egal(_nombre("cible_0"), 2, "elle double l'achat suivant")


func test_une_arme_est_copiee_si_la_tour_a_de_la_place_et_sans_amelioration_rien_ne_change() -> void:
	var id_arme: String = d.armes.keys()[0]
	d.armes[id_arme]["rarete"] = Types.Rarete.COMMUNE
	_boutique.offres = [
		{"id": id_arme, "genre": Types.Genre.ARME, "rarete": 0, "prix": 10, "vendu": false}
	]
	_acheter(0)
	verifier_egal(_inventaire.armes.size(), 1, "sans la charge, un seul exemplaire")
	_inventaire.ameliorations["copie_0"] = 1
	_boutique.offres[0]["vendu"] = false
	_acheter(0)
	verifier_egal(_inventaire.armes.size(), 3, "un achat et sa copie gratuite")
