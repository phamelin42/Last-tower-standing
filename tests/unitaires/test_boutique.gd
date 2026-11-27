extends CasDeTest
## Ce que le joueur obtient de la boutique : quatre offres variées et reproductibles, des achats
## qui ne débitent jamais à tort, des relances au coût croissant, des achats répétés qui
## montent le niveau d'une arme (la vente n'existe plus, D23) et un marché
## noir qui ne s'ouvre qu'avec un jeton.

const GRAINE := 20261124
const MANCHES := 40
const GRAINES: Array[int] = [1, 7, 42, 20261124, 987654321]
const BUDGET_MANCHE_MS := 250


func _donnees_reelles() -> Donnees:
	var d := Donnees.charger()
	verifier_non_nul(d, "les données réelles doivent se charger")
	return d


func _lire(nom: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/" + nom))


func _donnees_avec(armes: Array, ameliorations: Array) -> Donnees:
	var brut: Dictionary = {}
	for nom: String in Donnees.FICHIERS_OBJET:
		brut[nom] = _lire(nom)
	brut["armes.json"] = armes
	brut["ameliorations.json"] = ameliorations
	brut["unites.json"] = _lire("unites.json")
	var d := Donnees.depuis_brut(brut)
	verifier_non_nul(d, "les données de test doivent être valides")
	return d


func _rng(graine: int = GRAINE) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	return rng


func _boutique(d: Donnees, graine: int = GRAINE) -> Boutique:
	return Boutique.new(d, _rng(graine))


func _eco(d: Donnees, montant: int) -> Economie:
	var e := Economie.new(d)
	e.argent = montant
	return e


## Remplace les offres par une offre connue pour tester achat et refus.
func _forcer(b: Boutique, d: Donnees, index: int, id: String) -> void:
	var est_arme := d.armes.has(id)
	var fiche: Dictionary = d.armes[id] if est_arme else d.ameliorations[id]
	b.offres[index] = {
		"id": id,
		"genre": Types.Genre.ARME if est_arme else Types.Genre.AMELIORATION,
		"rarete": int(fiche["rarete"]),
		"prix": int(fiche["prix"]),
		"vendu": false,
	}


func _id_arme(d: Donnees, i: int) -> String:
	return str(d.armes.keys()[i])


func _id_amelio_qui_donne(d: Donnees, stat: String) -> String:
	for id: String in d.ameliorations:
		var fiche: Dictionary = d.ameliorations[id]
		var effets: Array = fiche["effets"]
		for e: Variant in effets:
			var effet: Dictionary = e
			if effet["stat"] == stat:
				return id
	return ""


func _ids(b: Boutique) -> Array[String]:
	var ids: Array[String] = []
	for o: Dictionary in b.offres:
		ids.append(str(o["id"]))
	return ids


# --- Offres --------------------------------------------------------------------------------------


func test_quatre_offres_a_chaque_manche_de_1_a_40() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	for manche: int in range(1, MANCHES + 1):
		b.nouvelle_manche(manche, 0)
		verifier_egal(b.offres.size(), 4, "manche %d" % manche)
		for o: Dictionary in b.offres:
			verifier_faux(bool(o["vendu"]))
			verifier(int(o["prix"]) > 0)


func test_jamais_deux_fois_le_meme_id_dans_les_quatre_offres() -> void:
	var d := _donnees_reelles()
	for graine: int in GRAINES:
		var b := _boutique(d, graine)
		for manche: int in range(1, MANCHES + 1):
			b.nouvelle_manche(manche, 0)
			for _r: int in 5:
				var ids := _ids(b)
				var uniques: Dictionary = {}
				for id: String in ids:
					uniques[id] = true
				verifier_egal(uniques.size(), 4, "graine %d manche %d" % [graine, manche])
				b.tirer(manche)


func test_une_offre_correspond_a_sa_fiche() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	for manche: int in range(1, MANCHES + 1):
		b.nouvelle_manche(manche, 0)
		for o: Dictionary in b.offres:
			var id := str(o["id"])
			var est_arme := d.armes.has(id)
			verifier(est_arme or d.ameliorations.has(id), id)
			var fiche: Dictionary = d.armes[id] if est_arme else d.ameliorations[id]
			verifier_egal(int(o["prix"]), int(fiche["prix"]))
			verifier_egal(int(o["rarete"]), int(fiche["rarete"]))
			verifier_egal(
				int(o["genre"]), Types.Genre.ARME if est_arme else Types.Genre.AMELIORATION
			)


func test_aucun_epique_a_la_manche_1() -> void:
	var d := _donnees_reelles()
	verifier_proche(d.palier(d.boutique["poids"], 1, "epique"), 0.0)
	for graine: int in GRAINES:
		var b := _boutique(d, graine)
		b.nouvelle_manche(1, 0)
		for _i: int in 300:
			for o: Dictionary in b.offres:
				verifier(int(o["rarete"]) != Types.Rarete.EPIQUE, "épique en manche 1")
			b.tirer(1)


func test_meme_graine_memes_offres_sur_20_manches() -> void:
	var d := _donnees_reelles()
	var a := _boutique(d)
	var b := _boutique(d)
	for manche: int in range(1, 21):
		a.nouvelle_manche(manche, 0)
		b.nouvelle_manche(manche, 0)
		verifier_egal(a.offres, b.offres, "manche %d" % manche)
		a.tirer(manche)
		b.tirer(manche)
		verifier_egal(a.offres, b.offres, "relance manche %d" % manche)


func test_une_autre_graine_donne_d_autres_offres() -> void:
	var d := _donnees_reelles()
	var a := _boutique(d, 1)
	var b := _boutique(d, 2)
	var different := false
	for manche: int in range(1, 11):
		a.nouvelle_manche(manche, 0)
		b.nouvelle_manche(manche, 0)
		different = different or _ids(a) != _ids(b)
	verifier(different, "deux graines ne doivent pas donner dix fois les mêmes offres")


func test_une_rarete_sans_objet_ne_fait_jamais_planter_le_tirage() -> void:
	# Aucun objet peu commun ni épique, alors que les poids de la manche 40 les demandent.
	var armes: Array = []
	for a: Variant in _lire("armes.json") as Array:
		var arme: Dictionary = a
		if arme["rarete"] == "commune" or arme["rarete"] == "rare":
			armes.append(arme)
	var amelios: Array = []
	for a: Variant in _lire("ameliorations.json") as Array:
		var amelio: Dictionary = a
		if amelio["rarete"] == "commune" or amelio["rarete"] == "rare":
			amelios.append(amelio)
	var d := _donnees_avec(armes, amelios)
	for graine: int in GRAINES:
		var b := _boutique(d, graine)
		for manche: int in range(1, MANCHES + 1):
			b.nouvelle_manche(manche, 0)
			verifier_egal(b.offres.size(), 4, "manche %d" % manche)
			for o: Dictionary in b.offres:
				var r := int(o["rarete"])
				verifier(r == Types.Rarete.COMMUNE or r == Types.Rarete.RARE)


func test_un_catalogue_trop_petit_donne_moins_d_offres_sans_planter() -> void:
	var armes: Array = [(_lire("armes.json") as Array)[0]]
	var d := _donnees_avec(armes, [])
	var b := _boutique(d)
	for manche: int in range(1, MANCHES + 1):
		b.nouvelle_manche(manche, 0)
		verifier_egal(b.offres.size(), 1)


func test_tout_le_catalogue_est_propose_entre_les_manches_1_et_40() -> void:
	var d := _donnees_reelles()
	var vus: Dictionary = {}
	var b := _boutique(d)
	var durees_us := PackedInt32Array()
	for manche: int in range(1, MANCHES + 1):
		var debut := Time.get_ticks_usec()
		b.nouvelle_manche(manche, 0)
		for _i: int in 400:
			for o: Dictionary in b.offres:
				vus[str(o["id"])] = true
			b.tirer(manche)
		durees_us.append(Time.get_ticks_usec() - debut)
	for id: String in d.ids_catalogue:
		verifier(vus.has(id), "« %s » n'est jamais proposé" % id)
	# Budget par manche (400 tirages) au 10e centile, pas sur le total : une mesure globale échouait
	# sous la charge (3 069 ms pour 3 000 en CI). Coût local au 10e centile : 47 à 55 ms ;
	# budget retenu : 250 ms, environ 5 fois ce coût.
	var cout_ms := MesurePas.centile_bas_ms(durees_us)
	print("atteignabilité : %.1f ms par manche au 10e centile" % cout_ms)
	verifier(
		cout_ms < BUDGET_MANCHE_MS,
		"400 tirages dépassent %d ms : %.1f ms" % [BUDGET_MANCHE_MS, cout_ms]
	)


# --- Achat ---------------------------------------------------------------------------------------


func test_acheter_une_arme_la_debite_et_marque_l_offre_vendue() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	b.nouvelle_manche(1, 0)
	_forcer(b, d, 0, _id_arme(d, 0))
	var prix := int(b.offres[0]["prix"])
	var eco := _eco(d, prix + 10)
	verifier_egal(b.acheter(0, eco, inv), Types.Resultat.OK)
	verifier_egal(eco.argent, 10)
	verifier(bool(b.offres[0]["vendu"]))
	verifier_egal(inv.armes, [_id_arme(d, 0)] as Array[String])


func test_or_exact_passe_et_laisse_zero() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	b.nouvelle_manche(1, 0)
	_forcer(b, d, 1, _id_arme(d, 2))
	var eco := _eco(d, int(b.offres[1]["prix"]))
	verifier_egal(b.acheter(1, eco, inv), Types.Resultat.OK)
	verifier_egal(eco.argent, 0)


func test_or_insuffisant_de_un_refuse_sans_rien_changer() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	b.nouvelle_manche(1, 0)
	_forcer(b, d, 0, _id_arme(d, 0))
	var prix := int(b.offres[0]["prix"])
	var eco := _eco(d, prix - 1)
	verifier_egal(b.acheter(0, eco, inv), Types.Resultat.OR_INSUFFISANT)
	verifier_egal(eco.argent, prix - 1)
	verifier_faux(bool(b.offres[0]["vendu"]))
	verifier(inv.armes.is_empty())


func test_la_neuvieme_arme_s_achete_et_est_debitee() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	for i: int in 8:
		inv.ajouter(_id_arme(d, i))
	b.nouvelle_manche(1, 0)
	_forcer(b, d, 2, _id_arme(d, 8))
	var prix := int(b.offres[2]["prix"])
	var eco := _eco(d, 1000000)
	verifier_egal(b.acheter(2, eco, inv), Types.Resultat.OK)
	verifier_egal(eco.argent, 1000000 - prix, "l'or est débité")
	verifier(bool(b.offres[2]["vendu"]), "l'offre est vendue")
	verifier_egal(inv.armes.size(), 9)


func test_acheter_300_fois_la_meme_arme_monte_son_niveau_sans_jamais_etre_refuse() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	var id := _id_arme(d, 0)
	var prix := int((d.armes[id] as Dictionary)["prix"])
	var eco := _eco(d, 1000000)
	b.nouvelle_manche(1, 0)
	for i: int in 300:
		_forcer(b, d, 2, id)
		verifier_egal(b.acheter(2, eco, inv), Types.Resultat.OK, "achat %d" % (i + 1))
	verifier_egal(inv.armes.size(), 1, "l'arme reste unique")
	verifier_egal(inv.niveau(id), 300)
	verifier_egal(eco.argent, 1000000 - 300 * prix, "chaque achat est payé plein pot")


func test_emplacements_pleins_n_est_jamais_renvoye() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	var eco := _eco(d, 100000000)
	b.nouvelle_manche(1, 0)
	for achat: int in range(1, 41):
		_forcer(b, d, 0, _id_arme(d, achat % d.armes.size()))
		var resultat := b.acheter(0, eco, inv)
		verifier(resultat != Types.Resultat.EMPLACEMENTS_PLEINS, "achat %d" % achat)
		verifier_egal(resultat, Types.Resultat.OK, "achat %d" % achat)


func test_une_amelioration_s_achete_meme_avec_huit_armes() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	for i: int in 8:
		inv.ajouter(_id_arme(d, i))
	b.nouvelle_manche(1, 0)
	var id := str(d.ameliorations.keys()[0])
	_forcer(b, d, 0, id)
	var eco := _eco(d, 1000000)
	verifier_egal(b.acheter(0, eco, inv), Types.Resultat.OK)
	verifier_egal(int(inv.ameliorations[id]), 1)


func test_une_offre_deja_achetee_ne_se_rachete_pas() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	b.nouvelle_manche(1, 0)
	_forcer(b, d, 0, _id_arme(d, 0))
	var eco := _eco(d, 1000000)
	b.acheter(0, eco, inv)
	var apres := eco.argent
	verifier_egal(b.acheter(0, eco, inv), Types.Resultat.DEJA_ACHETE)
	verifier_egal(eco.argent, apres)
	verifier_egal(inv.armes.size(), 1)


func test_indices_hors_bornes_refuses() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	b.nouvelle_manche(1, 0)
	var eco := _eco(d, 1000000)
	for i: int in [-1, 4, 99]:
		verifier_egal(b.acheter(i, eco, inv), Types.Resultat.INDICE_INVALIDE, "indice %d" % i)
	verifier_egal(eco.argent, 1000000)
	verifier(inv.armes.is_empty() and inv.ameliorations.is_empty())


# --- Relance -------------------------------------------------------------------------------------


func test_relance_a_zero_or_refusee_offres_inchangees() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	b.nouvelle_manche(1, 0)
	var avant := b.offres.duplicate(true)
	var eco := _eco(d, 0)
	var r := b.relancer(eco, 0)
	verifier_egal(r[0], Types.Resultat.OR_INSUFFISANT)
	verifier_egal(r[1], 0)
	verifier_egal(b.offres, avant)
	verifier_egal(eco.argent, 0)
	verifier_egal(b.cout_relance, 50)


func test_les_relances_coutent_50_puis_75_puis_100() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	b.nouvelle_manche(1, 0)
	var eco := _eco(d, 1000)
	var attendus: Array[int] = [50, 75, 100]
	for cout: int in attendus:
		verifier_egal(b.cout_relance, cout, "coût annoncé")
		var avant := eco.argent
		verifier_egal(b.relancer(eco, 0)[0], Types.Resultat.OK)
		verifier_egal(avant - eco.argent, cout, "or débité")
	verifier_egal(b.cout_relance, 125)


func test_le_cout_revient_a_50_a_la_manche_suivante() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	b.nouvelle_manche(1, 0)
	var eco := _eco(d, 1000)
	b.relancer(eco, 0)
	b.relancer(eco, 0)
	b.nouvelle_manche(2, 0)
	verifier_egal(b.cout_relance, 50)
	var avant := eco.argent
	b.relancer(eco, 0)
	verifier_egal(avant - eco.argent, 50)


func test_une_relance_remplace_les_quatre_offres_vendues_ou_non() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	b.nouvelle_manche(5, 0)
	var eco := _eco(d, 1000000)
	b.acheter(0, eco, inv)
	verifier(bool(b.offres[0]["vendu"]))
	b.relancer(eco, 0)
	verifier_egal(b.offres.size(), 4)
	for o: Dictionary in b.offres:
		verifier_faux(bool(o["vendu"]))


func test_relance_gratuite_consommee_avant_l_or_sans_faire_monter_le_cout() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	b.nouvelle_manche(1, 2)
	var eco := _eco(d, 1000)
	var r := b.relancer(eco, 2)
	verifier_egal(r[0], Types.Resultat.OK)
	verifier_egal(r[1], 1)
	verifier_egal(eco.argent, 1000, "gratuite : pas de débit")
	verifier_egal(b.cout_relance, 50, "le coût ne monte pas")
	r = b.relancer(eco, 1)
	verifier_egal(r[1], 0)
	verifier_egal(eco.argent, 1000)
	r = b.relancer(eco, 0)
	verifier_egal(r[0], Types.Resultat.OK)
	verifier_egal(eco.argent, 950, "la première payante coûte 50")
	verifier_egal(b.cout_relance, 75)


func test_relance_gratuite_marche_meme_sans_or() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	b.nouvelle_manche(1, 1)
	var r := b.relancer(_eco(d, 0), 1)
	verifier_egal(r[0], Types.Resultat.OK)


# --- Vente supprimée (D23) -----------------------------------------------------------------------


func test_la_vente_n_existe_plus() -> void:
	verifier_faux(_boutique(_donnees_reelles()).has_method("vendre"))


# --- Marché noir ---------------------------------------------------------------------------------


func test_le_choix_de_marche_noir_liste_les_ameliorations_jusqu_a_rare_triees() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var choix := b.choix_marche_noir(d)
	verifier(not choix.is_empty())
	var triee := Array(choix)
	triee.sort()
	verifier_egal(Array(choix), triee)
	for id: String in d.ameliorations:
		var rarete := int((d.ameliorations[id] as Dictionary)["rarete"])
		var present := choix.has(id)
		verifier_egal(present, rarete <= Types.Rarete.RARE, "« %s »" % id)
	for id: String in choix:
		verifier_faux(d.armes.has(id), "aucune arme au marché noir")


func test_marche_noir_refuse_sans_jeton() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	var eco := _eco(d, 1000)
	var id := b.choix_marche_noir(d)[0]
	verifier_egal(b.acheter_marche_noir(id, eco, inv), Types.Resultat.NON_DISPONIBLE)
	verifier(inv.ameliorations.is_empty())


func test_un_jeton_donne_un_seul_choix() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	var eco := _eco(d, 100000)
	var jeton := _id_amelio_qui_donne(d, "marche_noir")
	verifier(jeton != "", "le contenu doit porter un jeton de marché noir")
	b.nouvelle_manche(1, 0)
	_forcer(b, d, 0, jeton)
	verifier_egal(b.acheter(0, eco, inv), Types.Resultat.OK)
	var avant := eco.argent
	var choisi := ""
	for id: String in b.choix_marche_noir(d):
		if id != jeton:
			choisi = id
			break
	verifier_egal(b.acheter_marche_noir(choisi, eco, inv), Types.Resultat.OK)
	verifier_egal(int(inv.ameliorations[choisi]), 1)
	verifier_egal(eco.argent, avant, "le choix est gratuit : le jeton l'a déjà payé")
	verifier_egal(
		b.acheter_marche_noir(choisi, eco, inv), Types.Resultat.NON_DISPONIBLE, "jeton consommé"
	)
	verifier_egal(int(inv.ameliorations[choisi]), 1)


func test_deux_jetons_donnent_deux_choix() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	var eco := _eco(d, 100000)
	var jeton := _id_amelio_qui_donne(d, "marche_noir")
	b.nouvelle_manche(1, 0)
	for _i: int in 2:
		_forcer(b, d, 0, jeton)
		b.offres[0]["vendu"] = false
		b.acheter(0, eco, inv)
	var choisi := str(b.choix_marche_noir(d)[0])
	verifier_egal(b.acheter_marche_noir(choisi, eco, inv), Types.Resultat.OK)
	verifier_egal(b.acheter_marche_noir(choisi, eco, inv), Types.Resultat.OK)
	verifier_egal(b.acheter_marche_noir(choisi, eco, inv), Types.Resultat.NON_DISPONIBLE)


func test_marche_noir_refuse_un_id_hors_liste_sans_consommer_le_jeton() -> void:
	var d := _donnees_reelles()
	var b := _boutique(d)
	var inv := Inventaire.new(d)
	var eco := _eco(d, 100000)
	var jeton := _id_amelio_qui_donne(d, "marche_noir")
	b.nouvelle_manche(1, 0)
	_forcer(b, d, 0, jeton)
	b.acheter(0, eco, inv)
	verifier_egal(b.acheter_marche_noir("inconnu", eco, inv), Types.Resultat.OFFRE_INVALIDE)
	verifier_egal(b.acheter_marche_noir(_id_arme(d, 0), eco, inv), Types.Resultat.OFFRE_INVALIDE)
	var choisi := str(b.choix_marche_noir(d)[0])
	verifier_egal(b.acheter_marche_noir(choisi, eco, inv), Types.Resultat.OK)
