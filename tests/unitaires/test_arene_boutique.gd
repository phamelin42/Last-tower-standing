extends CasDeTest
## Arène, côté joueur : revenus, primes, achats, ventes, relances, marché noir.

const DT := 0.05
const GRAINE := 31

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


# --- Aides -------------------------------------------------------------------------------------


func _avancer(a: Arene, pas: int) -> void:
	for _i: int in pas:
		a.avancer(DT)


func _vue(a: Arene) -> VueArene:
	return a.vue(Types.Phase.PREPARATION, 10.0, -1, false)


func _poser_offre(a: Arene, index: int, id: String) -> void:
	var est_arme := d.armes.has(id)
	var fiche: Dictionary = d.armes[id] if est_arme else d.ameliorations[id]
	a.boutique.offres[index] = {
		"id": id,
		"genre": Types.Genre.ARME if est_arme else Types.Genre.AMELIORATION,
		"rarete": int(fiche["rarete"]),
		"prix": int(fiche["prix"]),
		"vendu": false,
	}


func _mult() -> Dictionary:
	return {"pv": 1.0, "degats": 1.0, "vitesse": 0.0, "resistance_controle": 1.0}


# --- Revenus -----------------------------------------------------------------------------------


func test_le_revenu_est_verse_toutes_les_10_s() -> void:
	var a := Arene.new(d, GRAINE)
	_avancer(a, 199)
	verifier_egal(a.economie.argent, 500, "rien avant 10 s")
	_avancer(a, 1)
	verifier_egal(a.economie.argent, 520, "20 d'or à 10 s")
	_avancer(a, 200)
	verifier_egal(a.economie.argent, 540, "puis 20 de plus à 20 s")


func test_un_objet_de_revenu_augmente_le_versement() -> void:
	var a := Arene.new(d, GRAINE)
	a.inventaire.ameliorations["cagnotte_du_guet"] = 1  # +4
	a.synchroniser()
	verifier_egal(_vue(a).revenu, 24)
	_avancer(a, 200)
	verifier_egal(a.economie.argent, 524)


func test_le_revenu_suit_le_palier_de_la_manche() -> void:
	var a := Arene.new(d, GRAINE)
	a.demarrer_manche(6, 0, _mult())
	verifier_egal(_vue(a).revenu, 30, "30 d'or par période dès la manche 6")


func test_le_revenu_est_verse_pendant_la_preparation_et_l_etat_est_annonce() -> void:
	var a := Arene.new(d, GRAINE)
	_avancer(a, 100)
	verifier_proche(_vue(a).revenu_dans, 5.0, 0.001, "5 s avant le prochain versement")


# --- Primes et éliminations --------------------------------------------------------------------


func test_une_elimination_verse_la_prime_de_l_ennemi() -> void:
	var a := Arene.new(d, GRAINE)
	var i := a.ennemis.ajouter(0, Vector2(1300, 0), 10.0, 0.0, 0.0, 30.0, 1.0, 7, false, 4)
	a.ennemis.infliger(a.ennemis.indice_de(i), 1e6, Types.TypeDegats.CHAOS)
	a.avancer(DT)
	verifier_egal(a.economie.argent, 507)
	verifier_egal(_vue(a).eliminations, 1)


func test_la_prime_suit_le_palier_et_les_objets() -> void:
	var a := Arene.new(d, GRAINE)
	a.demarrer_manche(10, 0, _mult())  # prime ×1,5
	a.inventaire.ameliorations["prime_du_guet"] = 1  # +0,15 → ×1,65
	a.synchroniser()
	var i := a.ennemis.ajouter(0, Vector2(1300, 0), 10.0, 0.0, 0.0, 30.0, 1.0, 10, false, 4)
	a.ennemis.infliger(a.ennemis.indice_de(i), 1e6, Types.TypeDegats.CHAOS)
	a.avancer(DT)
	verifier_egal(a.economie.argent, 500 + roundi(10.0 * 1.5 * 1.15), "10 × 1,5 × 1,15")


func test_le_bonus_tous_les_n_est_verse_a_chaque_serie() -> void:
	var effet: Dictionary = d.ameliorations["tirelire_d_honneur"]["effets"][0]
	var n := int(effet["tous_les"])
	var bonus := int(effet["or"])
	var a := Arene.new(d, GRAINE)
	a.inventaire.ameliorations["tirelire_d_honneur"] = 1
	a.synchroniser()
	var prime := 3
	for serie: int in 3:
		for _k: int in n:
			var i := a.ennemis.ajouter(
				0, Vector2(1300, 0), 10.0, 0.0, 0.0, 30.0, 1.0, prime, false, 4
			)
			a.ennemis.infliger(a.ennemis.indice_de(i), 1e6, Types.TypeDegats.CHAOS)
			a.avancer(DT)
		var attendu := 500 + (serie + 1) * (n * prime + bonus)
		verifier_egal(a.economie.argent, attendu, "après %d séries de %d" % [serie + 1, n])


func test_le_bonus_est_verse_meme_si_la_serie_meurt_au_meme_pas() -> void:
	var effet: Dictionary = d.ameliorations["tirelire_d_honneur"]["effets"][0]
	var n := int(effet["tous_les"])
	var a := Arene.new(d, GRAINE)
	a.inventaire.ameliorations["tirelire_d_honneur"] = 1
	a.synchroniser()
	for _k: int in n:
		var i := a.ennemis.ajouter(0, Vector2(1300, 0), 10.0, 0.0, 0.0, 30.0, 1.0, 1, false, 4)
		a.ennemis.infliger(a.ennemis.indice_de(i), 1e6, Types.TypeDegats.CHAOS)
	a.avancer(DT)
	verifier_egal(a.economie.argent, 500 + n + int(effet["or"]), "n primes + un bonus")


# --- Achat, vente, relance ---------------------------------------------------------------------


func test_acheter_pendant_la_preparation_debite_le_prix_exact() -> void:
	var a := Arene.new(d, GRAINE)  # aucune manche démarrée : préparation
	_poser_offre(a, 0, "orbe_de_brume")
	var attendu := 500 - 130
	verifier_egal(a.acheter(0), Types.Resultat.OK, "la boutique est ouverte en préparation")
	verifier_egal(a.economie.argent, attendu, "débit exact")
	verifier(bool(_vue(a).offres[0]["vendu"]), "l'offre est marquée vendue")
	verifier_egal(a.acheter(0), Types.Resultat.DEJA_ACHETE, "pas deux fois")
	verifier_egal(a.economie.argent, attendu, "sans second débit")


func test_acheter_une_arme_l_equipe_et_elle_apparait_dans_la_vue() -> void:
	var a := Arene.new(d, GRAINE)
	_poser_offre(a, 0, "de_pipe")
	verifier_egal(a.acheter(0), Types.Resultat.OK)
	verifier_egal(a.economie.argent, 430)
	var v := _vue(a)
	verifier_egal(v.armes.size(), 1)
	verifier_egal(v.armes[0]["id"], "de_pipe")
	verifier_proche(float(v.armes[0]["recharge_ratio"]), 0.0, 0.0001, "prête à tirer")


func test_acheter_une_amelioration_modifie_les_stats() -> void:
	var a := Arene.new(d, GRAINE)
	_poser_offre(a, 1, "renfort_de_poutres")
	verifier_egal(a.acheter(1), Types.Resultat.OK)
	verifier_proche(_vue(a).tour_pv_max, 1150.0)
	verifier_egal(_vue(a).ameliorations["renfort_de_poutres"], 1)


func test_or_insuffisant_ne_debite_rien() -> void:
	var a := Arene.new(d, GRAINE)
	_poser_offre(a, 0, "grande_bombarde")
	a.economie.argent = 100
	verifier_egal(a.acheter(0), Types.Resultat.OR_INSUFFISANT)
	verifier_egal(a.economie.argent, 100)
	verifier_faux(bool(_vue(a).offres[0]["vendu"]))


func test_la_neuvieme_et_la_quarantieme_arme_sont_achetees_et_debitees() -> void:
	var a := Arene.new(d, GRAINE)
	a.economie.argent = 100000
	for k: int in 40:
		_poser_offre(a, 0, "de_pipe")
		verifier_egal(a.acheter(0), Types.Resultat.OK, "achat %d" % (k + 1))
	verifier_egal(a.economie.argent, 100000 - 40 * 70, "quarante achats débités exactement")
	var vue := _vue(a)
	verifier_egal(vue.armes.size(), 40, "la vue porte les 40 armes")
	for arme: Dictionary in vue.armes:
		verifier_egal(arme["id"], "de_pipe")
		var ratio := float(arme["recharge_ratio"])
		verifier(ratio >= 0.0 and ratio <= 1.0, "recharge %s" % ratio)


func test_vendre_une_arme_rend_la_moitie_du_prix() -> void:
	var a := Arene.new(d, GRAINE)
	_poser_offre(a, 0, "orbe_de_brume")  # 130
	a.acheter(0)
	verifier_egal(a.economie.argent, 370)
	verifier_egal(a.vendre(0), Types.Resultat.OK)
	verifier_egal(a.economie.argent, 435, "vente à 50 % : +65")
	verifier_egal(_vue(a).armes.size(), 0)


func test_vendre_une_arme_en_pleine_recharge_ne_derange_pas_les_autres() -> void:
	var a := Arene.new(d, GRAINE)
	a.inventaire.ajouter("sablier_fele")  # recharge 2,5 s, portée 300
	a.inventaire.ajouter("de_pipe")  # portée 600
	a.synchroniser()
	a.ennemis.ajouter(0, Vector2(250, 0), 4000.0, 0.0, 0.0, 30.0, 1.0, 1, false, 4)
	_avancer(a, 5)
	var avant := _vue(a)
	verifier_egal(avant.armes.size(), 2)
	verifier(float(avant.armes[0]["recharge_ratio"]) > 0.0, "le sablier est en recharge")
	var ratio_pipe := float(avant.armes[1]["recharge_ratio"])
	var argent := a.economie.argent
	verifier_egal(a.vendre(0), Types.Resultat.OK)
	verifier_egal(a.economie.argent, argent + 55, "110 / 2")
	var apres := _vue(a)
	verifier_egal(apres.armes.size(), 1)
	verifier_egal(apres.armes[0]["id"], "de_pipe")
	verifier_proche(float(apres.armes[0]["recharge_ratio"]), ratio_pipe, 0.0001, "recharge intacte")
	_avancer(a, 100)
	verifier_egal(_vue(a).armes.size(), 1, "la simulation continue sans erreur")


func test_relance_debite_puis_augmente() -> void:
	var a := Arene.new(d, GRAINE)
	verifier_egal(a.relancer(), Types.Resultat.OK)
	verifier_egal(a.economie.argent, 450, "50 d'or")
	verifier_egal(_vue(a).cout_relance, 75, "la suivante coûte 25 de plus")
	verifier_egal(a.relancer(), Types.Resultat.OK)
	verifier_egal(a.economie.argent, 375)
	verifier_egal(_vue(a).offres.size(), 4, "toujours quatre offres")
	a.economie.argent = 10
	verifier_egal(a.relancer(), Types.Resultat.OR_INSUFFISANT)
	verifier_egal(a.economie.argent, 10)


func test_la_relance_gratuite_passe_avant_l_or_et_revient_a_la_manche() -> void:
	var a := Arene.new(d, GRAINE)
	a.inventaire.ameliorations["bourse_de_rebut"] = 1
	a.synchroniser()
	verifier_egal(_vue(a).relances_gratuites, 1)
	verifier_egal(a.relancer(), Types.Resultat.OK)
	verifier_egal(a.economie.argent, 500, "gratuite")
	verifier_egal(_vue(a).relances_gratuites, 0)
	verifier_egal(a.relancer(), Types.Resultat.OK)
	verifier_egal(a.economie.argent, 450, "la suivante est payante, au coût de départ")
	a.demarrer_manche(1, 0, _mult())
	verifier_egal(_vue(a).relances_gratuites, 1, "une nouvelle manche rend la relance gratuite")
	verifier_egal(_vue(a).cout_relance, 50, "et remet le coût à zéro")


func test_une_nouvelle_manche_tire_de_nouvelles_offres() -> void:
	var a := Arene.new(d, GRAINE)
	var avant: Array[Dictionary] = _vue(a).offres
	var change := false
	for manche: int in range(1, 6):
		a.demarrer_manche(manche, 0, _mult())
		if _vue(a).offres != avant:
			change = true
	verifier(change, "les offres changent d'une manche à l'autre")
	for offre: Dictionary in _vue(a).offres:
		verifier_faux(bool(offre["vendu"]))


# --- Marché noir -------------------------------------------------------------------------------


func test_marche_noir_un_jeton_un_choix() -> void:
	var a := Arene.new(d, GRAINE)
	verifier_faux(_vue(a).marche_noir_ouvert)
	_poser_offre(a, 0, "jeton_de_l_arriere_boutique")
	verifier_egal(a.acheter(0), Types.Resultat.OK)
	verifier(_vue(a).marche_noir_ouvert, "un jeton donne un choix en attente")
	verifier_egal(a.choisir_marche_noir("pas_un_objet"), Types.Resultat.OFFRE_INVALIDE)
	verifier(_vue(a).marche_noir_ouvert, "un choix refusé garde le jeton")
	var argent := a.economie.argent
	verifier_egal(a.choisir_marche_noir("affutage_fin"), Types.Resultat.OK)
	verifier_egal(a.economie.argent, argent, "le marché noir est gratuit")
	verifier_egal(_vue(a).ameliorations["affutage_fin"], 1)
	verifier_faux(_vue(a).marche_noir_ouvert, "le jeton est consommé")
	verifier_egal(a.choisir_marche_noir("affutage_fin"), Types.Resultat.NON_DISPONIBLE)
