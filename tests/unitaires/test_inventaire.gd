extends CasDeTest
## Ce que le joueur obtient de son équipement : autant d'armes qu'il en achète (255 au plus, la
## limite du réseau), des améliorations qui s'empilent, et des statistiques cumulées comme la spec
## le dit (additif dans une catégorie, multiplicatif entre catégories).


func _donnees_reelles() -> Donnees:
	var d := Donnees.charger()
	verifier_non_nul(d, "les données réelles doivent se charger")
	return d


func _lire(nom: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/" + nom))


## Données réelles dont armes et améliorations sont remplacées par celles du test.
func _donnees_avec(armes: Array, ameliorations: Array) -> Donnees:
	var brut: Dictionary = {}
	for nom: String in Donnees.FICHIERS_OBJET:
		brut[nom] = _lire(nom)
	brut["armes.json"] = armes
	brut["ameliorations.json"] = ameliorations
	var d := Donnees.depuis_brut(brut)
	verifier_non_nul(d, "les données de test doivent être valides")
	return d


func _arme(id: String, prix: int) -> Dictionary:
	var modele: Array = _lire("armes.json")
	var a: Dictionary = (modele[0] as Dictionary).duplicate(true)
	a["id"] = id
	a["prix"] = prix
	return a


func _amelio(id: String, effets: Array) -> Dictionary:
	return {
		"id": id,
		"nom": id,
		"description": "Test.",
		"rarete": "commune",
		"prix": 10,
		"categorie": "amelioration",
		"famille": "degats_type",
		"effets": effets,
	}


func _degats(type_degats: String, valeur: float, categorie: String) -> Dictionary:
	return {
		"stat": "degats_type", "type_degats": type_degats, "valeur": valeur, "categorie": categorie
	}


func _huit_armes(d: Donnees) -> Inventaire:
	var inv := Inventaire.new(d)
	var ids: Array = d.armes.keys()
	for i: int in 8:
		verifier_egal(inv.ajouter(str(ids[i])), Types.Resultat.OK)
	return inv


# --- Emplacements -------------------------------------------------------------------------------


func test_la_neuvieme_et_la_quarantieme_arme_sont_acceptees() -> void:
	var d := _donnees_reelles()
	var inv := _huit_armes(d)
	var ids: Array = d.armes.keys()
	verifier_egal(inv.ajouter(str(ids[8 % ids.size()])), Types.Resultat.OK, "la 9e arme entre")
	for i: int in range(9, 40):
		verifier_egal(inv.ajouter(str(ids[i % ids.size()])), Types.Resultat.OK, "arme %d" % (i + 1))
	verifier_egal(inv.armes.size(), 40)


func test_la_256e_arme_est_refusee_avec_armes_au_maximum_et_n_entre_pas() -> void:
	var d := _donnees_reelles()
	var inv := Inventaire.new(d)
	var ids: Array = d.armes.keys()
	for i: int in Inventaire.ARMES_MAX:
		verifier_egal(inv.ajouter(str(ids[i % ids.size()])), Types.Resultat.OK)
	verifier_egal(inv.armes.size(), 255)
	verifier_egal(inv.ajouter(str(ids[0])), Types.Resultat.ARMES_AU_MAXIMUM)
	verifier_egal(inv.armes.size(), 255, "la 256e n'entre pas")
	var id_amelio := str(d.ameliorations.keys()[0])
	verifier_egal(inv.ajouter(id_amelio), Types.Resultat.OK, "une amélioration entre toujours")


func test_la_limite_d_armes_est_celle_du_reseau() -> void:
	verifier_egal(Inventaire.ARMES_MAX, Protocole.MAX_ARMES)


func test_la_vente_de_la_40e_arme_rend_50_pour_cent_de_son_prix() -> void:
	var d := _donnees_reelles()
	var inv := Inventaire.new(d)
	var ids: Array = d.armes.keys()
	for i: int in 40:
		inv.ajouter(str(ids[i % ids.size()]))
	var id := inv.armes[39]
	var prix := int((d.armes[id] as Dictionary)["prix"])
	verifier_egal(inv.prix_vente(39), floori(float(prix) * 0.5))
	verifier_egal(inv.retirer_arme(39), id)
	verifier_egal(inv.armes.size(), 39)


func test_une_amelioration_entre_meme_avec_huit_armes_et_s_empile() -> void:
	var d := _donnees_reelles()
	var inv := _huit_armes(d)
	var id := str(d.ameliorations.keys()[0])
	verifier_egal(inv.ajouter(id), Types.Resultat.OK)
	verifier_egal(inv.ajouter(id), Types.Resultat.OK)
	verifier_egal(inv.ameliorations[id], 2)
	verifier_egal(inv.armes.size(), 8, "une amélioration n'occupe pas d'emplacement")


func test_un_id_inconnu_est_refuse() -> void:
	var inv := Inventaire.new(_donnees_reelles())
	verifier_egal(inv.ajouter("n_existe_pas"), Types.Resultat.OFFRE_INVALIDE)
	verifier_egal(inv.armes.size(), 0)
	verifier(inv.ameliorations.is_empty())


func test_retirer_libere_un_emplacement_reutilisable() -> void:
	var d := _donnees_reelles()
	var inv := _huit_armes(d)
	var ids: Array = d.armes.keys()
	verifier_egal(inv.retirer_arme(3), str(ids[3]))
	verifier_egal(inv.armes.size(), 7)
	verifier_egal(inv.ajouter(str(ids[9])), Types.Resultat.OK)
	verifier_egal(inv.armes.size(), 8)


func test_retirer_un_indice_invalide_rend_vide_sans_rien_changer() -> void:
	var d := _donnees_reelles()
	var inv := Inventaire.new(d)
	verifier_egal(inv.retirer_arme(0), "", "emplacement vide")
	inv.ajouter(str(d.armes.keys()[0]))
	for i: int in [-1, 1, 99]:
		verifier_egal(inv.retirer_arme(i), "", "indice %d" % i)
	verifier_egal(inv.armes.size(), 1)


func test_prix_de_vente_est_la_moitie_arrondie_a_l_inferieur() -> void:
	var d := _donnees_avec([_arme("a_pair", 900), _arme("a_impair", 901), _arme("a_un", 1)], [])
	var inv := Inventaire.new(d)
	for id: String in ["a_pair", "a_impair", "a_un"]:
		inv.ajouter(id)
	verifier_egal(inv.prix_vente(0), 450)
	verifier_egal(inv.prix_vente(1), 450, "901 → 450, pas 451")
	verifier_egal(inv.prix_vente(2), 0, "1 → 0")
	for i: int in [-1, 3, 99]:
		verifier_egal(inv.prix_vente(i), 0, "indice invalide %d" % i)


# --- Cumul des améliorations --------------------------------------------------------------------


func _inventaire_avec(ameliorations: Array, a_ajouter: Array[String]) -> Inventaire:
	var d := _donnees_avec([_arme("a", 100)], ameliorations)
	var inv := Inventaire.new(d)
	for id: String in a_ajouter:
		verifier_egal(inv.ajouter(id), Types.Resultat.OK)
	return inv


func test_etat_vide_donne_les_valeurs_neutres() -> void:
	var s := Inventaire.new(_donnees_reelles()).stats()
	for t: int in 5:
		verifier_proche(s.degats_type[t], 1.0)
	verifier_proche(s.degats_global, 1.0)
	verifier_proche(s.revenu_mult, 1.0)
	verifier_proche(s.prime_mult, 1.0)
	verifier_proche(s.pv_max_bonus, 0.0)
	verifier_egal(s.marche_noir, 0)
	verifier_egal(s.relances_gratuites, 0)
	verifier_egal(s.bonus_elim_tous_les, 0)
	verifier_egal(s.bonus_elim_or, 0)


func test_deux_plus_dix_pour_cent_dans_la_meme_categorie_font_plus_vingt() -> void:
	var inv := _inventaire_avec(
		[_amelio("x", [_degats("magique", 0.1, "A")])] as Array, ["x", "x"] as Array[String]
	)
	verifier_proche(inv.stats().degats_type[Types.TypeDegats.MAGIQUE], 1.2)


func test_deux_categories_se_multiplient() -> void:
	var inv := _inventaire_avec(
		[
			_amelio("x", [_degats("magique", 0.1, "A")]),
			_amelio("y", [_degats("magique", 0.1, "B")]),
		],
		["x", "y"] as Array[String]
	)
	verifier_proche(inv.stats().degats_type[Types.TypeDegats.MAGIQUE], 1.1 * 1.1)


func test_les_types_sont_independants() -> void:
	var inv := _inventaire_avec(
		[_amelio("x", [_degats("magique", 0.1, "A")])] as Array, ["x"] as Array[String]
	)
	var s := inv.stats()
	verifier_proche(s.degats_type[Types.TypeDegats.MAGIQUE], 1.1)
	for t: int in [0, 1, 3, 4]:
		verifier_proche(s.degats_type[t], 1.0, 0.0001, "type %d inchangé" % t)


func test_degats_global_suit_la_meme_regle_et_reste_separe_des_types() -> void:
	var global_a: Dictionary = {"stat": "degats_global", "valeur": 0.1, "categorie": "A"}
	var global_b: Dictionary = {"stat": "degats_global", "valeur": 0.1, "categorie": "B"}
	var inv := _inventaire_avec(
		[_amelio("g1", [global_a]), _amelio("g2", [global_a]), _amelio("g3", [global_b])],
		["g1", "g2", "g3"] as Array[String]
	)
	var s := inv.stats()
	verifier_proche(s.degats_global, 1.2 * 1.1)
	verifier_proche(s.degats_type[Types.TypeDegats.TRANCHANT], 1.0)


func test_statistiques_additives_et_compteurs() -> void:
	var inv := _inventaire_avec(
		[
			_amelio("pv", [{"stat": "pv_max", "valeur": 150}]),
			_amelio("rc", [{"stat": "revenu_croissant", "valeur": 1}]),
			_amelio("rm", [{"stat": "revenu_mult", "valeur": 0.1}]),
			_amelio("pm", [{"stat": "prime_mult", "valeur": 0.15}]),
			_amelio("rg", [{"stat": "relance_gratuite", "valeur": 1}]),
			_amelio("mn", [{"stat": "marche_noir", "valeur": 1}]),
			_amelio("be", [{"stat": "bonus_elim", "tous_les": 10, "or": 15}]),
			_amelio("tm", [{"stat": "tirs_multiples", "valeur": 1}]),
		],
		(
			[
				"pv",
				"pv",
				"rc",
				"rc",
				"rm",
				"rm",
				"pm",
				"rg",
				"rg",
				"mn",
				"mn",
				"mn",
				"be",
				"tm",
				"tm"
			]
			as Array[String]
		)
	)
	var s := inv.stats()
	verifier_proche(s.pv_max_bonus, 300.0, 0.0001, "valeurs absolues additionnées")
	verifier_proche(s.revenu_croissant, 2.0)
	verifier_proche(s.revenu_mult, 1.2, 0.0001, "un bonus de revenu de 0,1 vaut +10 %")
	verifier_proche(s.prime_mult, 1.15)
	verifier_egal(s.relances_gratuites, 2)
	verifier_egal(s.marche_noir, 3, "un jeton par achat")
	verifier_egal(s.bonus_elim_tous_les, 10)
	verifier_egal(s.bonus_elim_or, 15)
	verifier_egal(s.tirs_multiples, 2)


func test_vendre_une_arme_ne_touche_pas_aux_ameliorations() -> void:
	var inv := _inventaire_avec(
		[_amelio("x", [_degats("magique", 0.1, "A")])] as Array, ["x"] as Array[String]
	)
	inv.ajouter("a")
	inv.retirer_arme(0)
	verifier_proche(inv.stats().degats_type[Types.TypeDegats.MAGIQUE], 1.1)


func test_chaque_amelioration_reelle_s_agrege_sans_erreur() -> void:
	var d := _donnees_reelles()
	for id: String in d.ameliorations:
		var inv := Inventaire.new(d)
		verifier_egal(inv.ajouter(id), Types.Resultat.OK, id)
		verifier_non_nul(inv.stats(), id)


func test_les_ameliorations_de_mana_s_additionnent_dans_les_stats() -> void:
	var d := _donnees_reelles()
	var par_stat: Dictionary = {"mana_max": [], "mana_regen": []}
	for id: String in d.ameliorations:
		var effets: Array = (d.ameliorations[id] as Dictionary)["effets"]
		for effet: Dictionary in effets:
			var stat := String(effet["stat"])
			if par_stat.has(stat):
				(par_stat[stat] as Array).append([id, float(effet["valeur"])])
	for stat: String in par_stat:
		var liste: Array = par_stat[stat]
		verifier(not liste.is_empty(), "une amélioration de %s existe" % stat)
		var inv := Inventaire.new(d)
		var attendu := 0.0
		for entree: Array in liste:
			inv.ajouter(String(entree[0]))
			inv.ajouter(String(entree[0]))
			attendu += 2.0 * float(entree[1])
		var s := inv.stats()
		var recu := s.mana_max_bonus if stat == "mana_max" else s.mana_regen
		verifier_proche(recu, attendu, 0.0001, "%s : deux exemplaires de chacune" % stat)
	var vide := Inventaire.new(d).stats()
	verifier_proche(vide.mana_max_bonus, 0.0, 0.0)
	verifier_proche(vide.mana_regen, 0.0, 0.0)


func test_exemplaires_et_comptes_d_ameliorations() -> void:
	var armes: Array = [_arme("a", 10), _arme("b", 10)]
	var amelios: Array = [
		_amelio("x", [_degats("tranchant", 0.1, "A")]),
		_amelio("y", [{"stat": "cadence", "valeur": 0.1}]),
	]
	var d := _donnees_avec(armes, amelios)
	var inv := Inventaire.new(d)
	verifier_egal(inv.exemplaires("a"), 0)
	for id: String in ["a", "a", "b", "x", "x", "x", "y"]:
		inv.ajouter(id)
	verifier_egal(inv.exemplaires("a"), 2)
	verifier_egal(inv.exemplaires("b"), 1)
	verifier_egal(inv.exemplaires("inconnue"), 0)
	verifier_egal(inv.comptes_armes(), {"a": 2, "b": 1})
	verifier_egal(
		inv.compter_stat("degats_type"), 3, "une amélioration achetée trois fois compte trois fois"
	)
	verifier_egal(inv.compter_stat("cadence"), 1)
	verifier_egal(inv.compter_stat("esquive"), 0)
