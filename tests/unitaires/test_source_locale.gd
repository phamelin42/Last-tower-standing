extends CasDeTest
## SourceLocale : cadence des vues, parité avec le réseau, intentions, observation, fin et sortie.

const GRAINE := 2024
const DT := 1.0 / 60.0
const INTENTIONS := ["acheter", "relancer", "vendre", "choisir_marche_noir", "continuer_sans_fin"]

var donnees: Donnees
var arenes: Array[VueArene] = []
var globales: Array[VueGlobale] = []
var resultats: Array = []


func avant_chaque() -> void:
	donnees = Donnees.charger()
	arenes = []
	globales = []
	resultats = []


func _creer(graine: int = GRAINE) -> SourceLocale:
	var source := SourceLocale.new()
	arbre.root.add_child(source)
	source.vue_arene_recue.connect(func(v: VueArene) -> void: arenes.append(v))
	source.vue_globale_recue.connect(func(v: VueGlobale) -> void: globales.append(v))
	source.resultat_intention.connect(
		func(genre: String, code: int) -> void: resultats.append([genre, code])
	)
	verifier(source.demarrer(donnees, AidesPartie.config(graine), "Mina"), "démarrage")
	return source


func _simuler(source: SourceLocale, secondes: float, dt: float = DT) -> void:
	var t := 0.0
	while t < secondes:
		source._process(dt)
		t += dt


func test_demarrer_sans_donnees_renvoie_faux_sans_erreur() -> void:
	var source := SourceLocale.new()
	arbre.root.add_child(source)
	verifier_faux(source.demarrer(null, AidesPartie.config(GRAINE), "Mina"))
	source._process(1.0)
	verifier_egal(arenes.size(), 0)


func test_le_joueur_local_a_un_id_fixe_et_observe_sa_propre_arene() -> void:
	var source := _creer()
	verifier_egal(source.id_local(), SourceLocale.ID_LOCAL)
	verifier_egal(source.cible_observee(), SourceLocale.ID_LOCAL)


func test_les_vues_arrivent_a_la_bonne_cadence() -> void:
	var source := _creer()
	_simuler(source, 2.0)
	verifier(absi(arenes.size() - 30) <= 1, "15 Hz sur 2 s : %d vues" % arenes.size())
	verifier(absi(globales.size() - 4) <= 1, "2 Hz sur 2 s : %d vues" % globales.size())


func test_une_grande_image_n_emet_qu_une_vue_de_chaque() -> void:
	var source := _creer()
	source._process(1.0)
	verifier_egal(arenes.size(), 1)
	verifier_egal(globales.size(), 1)


func test_la_vue_est_celle_que_donnerait_le_reseau() -> void:
	var source := _creer()
	source._process(1.0)
	var jumelle := Partie.new(donnees, AidesPartie.config(GRAINE))
	jumelle.ajouter_joueur(SourceLocale.ID_LOCAL, "Mina")
	jumelle.demarrer()
	jumelle.avancer(1.0)
	var attendue := VueArene.from_dict(jumelle.vue_arene(1, 1).to_dict())
	verifier_egal(arenes[0].to_dict(), attendue.to_dict())
	var globale := VueGlobale.from_dict(jumelle.vue_globale().to_dict())
	verifier_egal(globales[0].to_dict(), globale.to_dict())


func test_un_achat_debite_l_or_dans_la_vue_suivante() -> void:
	var source := _creer()
	_simuler(source, 0.5)
	var avant: VueArene = arenes[-1]
	var prix: int = avant.offres[0]["prix"]
	source.acheter(0)
	verifier_egal(resultats, [["acheter", Types.Resultat.OK]])
	_simuler(source, 0.2)
	verifier_egal(arenes[-1].argent, avant.argent - prix)
	verifier(arenes[-1].offres[0]["vendu"], "l'offre est marquée vendue")


func test_chaque_intention_renvoie_son_resultat() -> void:
	var source := _creer()
	_simuler(source, 0.2)
	var appels := {
		"acheter": func() -> void: source.acheter(99),
		"relancer": func() -> void: source.relancer(),
		"vendre": func() -> void: source.vendre(99),
		"choisir_marche_noir": func() -> void: source.choisir_marche_noir("inconnue"),
		"continuer_sans_fin": func() -> void: source.continuer_sans_fin(),
	}
	for genre: String in INTENTIONS:
		resultats = []
		var appel: Callable = appels[genre]
		appel.call()
		verifier_egal(resultats.size(), 1, genre)
		verifier_egal(resultats[0][0], genre)
	# Le code est celui de la partie : indice invalide, mode sans fin indisponible.
	resultats = []
	source.acheter(99)
	verifier_egal(resultats[0][1], Types.Resultat.INDICE_INVALIDE)
	resultats = []
	source.vendre(99)
	verifier_egal(resultats[0][1], Types.Resultat.INDICE_INVALIDE)
	resultats = []
	source.continuer_sans_fin()
	verifier_egal(resultats[0][1], Types.Resultat.MAUVAISE_PHASE)


func test_un_indice_invalide_ne_change_rien() -> void:
	var source := _creer()
	_simuler(source, 0.5)
	var avant: VueArene = arenes[-1]
	source.acheter(-1)
	verifier(resultats[0][1] != Types.Resultat.OK)
	_simuler(source, 0.2)
	verifier_egal(arenes[-1].argent, avant.argent)


func test_observer_est_refuse_tant_que_le_joueur_local_est_en_jeu() -> void:
	var source := _creer()
	source.observer(7)
	verifier_egal(source.cible_observee(), SourceLocale.ID_LOCAL)
	source.observer(SourceLocale.ID_LOCAL)
	verifier_egal(source.cible_observee(), SourceLocale.ID_LOCAL)


func test_solo_regarder_est_sans_effet() -> void:
	var source := _creer()
	var vues_regardees := 0
	source.vue_regardee_recue.connect(func(_id: int, _v: VueArene) -> void: vues_regardees += 1)
	for cible: int in [-1, 0, 7, SourceLocale.ID_LOCAL, 1 << 30]:
		source.regarder(cible)
		verifier_egal(source.id_regarde(), -1, "cible %d : rien n'est regardé" % cible)
	_simuler(source, 2.0)
	verifier_egal(vues_regardees, 0, "aucune vue d'une autre arène en solo")
	verifier(arenes.size() > 0, "la sienne continue")
	verifier_egal(source.cible_observee(), SourceLocale.ID_LOCAL)


func test_une_partie_perdue_se_termine_par_une_vue_globale_terminee() -> void:
	var source := _creer()
	var images := 0
	while source.is_processing() and images < 5000:
		source._process(2.0)
		images += 1
	verifier_faux(source.is_processing(), "la boucle s'est arrêtée")
	verifier(globales[-1].termine, "la dernière vue globale est terminée")
	verifier_egal(globales[-1].classement, [SourceLocale.ID_LOCAL])
	verifier_faux(globales[-1].joueurs[0]["vivant"])
	var nb_globales := globales.size()
	var nb_arenes := arenes.size()
	source._process(2.0)
	verifier_egal(globales.size(), nb_globales, "plus rien après la fin")
	verifier_egal(arenes.size(), nb_arenes)


func test_quitter_en_pleine_manche_arrete_tout_proprement() -> void:
	var source := _creer()
	_simuler(source, 40.0, 0.25)
	verifier(arenes[-1].manche >= 1, "manche en cours")
	source.quitter_partie()
	verifier_egal(resultats[-1], ["quitter_partie", Types.Resultat.OK])
	verifier_faux(source.is_processing())
	source.quitter_partie()
	source.acheter(0)
	verifier_egal(resultats[-1][1], Types.Resultat.ARENE_MORTE)


func test_aucune_vue_apres_quitter_partie() -> void:
	var source := _creer()
	_simuler(source, 1.0)
	source.quitter_partie()
	var nb_arenes := arenes.size()
	var nb_globales := globales.size()
	_simuler(source, 3.0)
	verifier_egal(arenes.size(), nb_arenes)
	verifier_egal(globales.size(), nb_globales)


func test_aucune_vue_apres_quitter_partie_dans_le_vrai_arbre() -> void:
	var source := _creer()
	await attendre_images(3)
	source.quitter_partie()
	var nb := arenes.size() + globales.size()
	await attendre_images(5)
	verifier_egal(arenes.size() + globales.size(), nb)


func test_deux_sources_ne_se_melangent_pas() -> void:
	var source_a := _creer(GRAINE)
	var source_b := SourceLocale.new()
	arbre.root.add_child(source_b)
	var vues_b: Array[VueArene] = []
	source_b.vue_arene_recue.connect(func(v: VueArene) -> void: vues_b.append(v))
	verifier(source_b.demarrer(donnees, AidesPartie.config(GRAINE + 1), "Noa"))
	_simuler(source_a, 1.0)
	verifier(arenes.size() >= 10 and vues_b.is_empty(), "B n'avance pas quand A tourne")
	source_a.acheter(0)
	_simuler(source_b, 1.0)
	verifier(vues_b.size() >= 10)
	verifier_egal(
		vues_b[-1].argent, int(donnees.economie["or_depart"]), "l'achat de A n'a pas touché B"
	)
	source_a.quitter_partie()
	var nb := vues_b.size()
	_simuler(source_b, 0.5)
	verifier(vues_b.size() > nb, "B continue après la sortie de A")


func test_le_skin_choisi_avant_le_depart_arrive_dans_la_vue_globale_et_reste_borne() -> void:
	var d_skins := AidesPartie.donnees()
	var nombre := d_skins.ids_skins().size()
	for index: int in [1, 0, -4, nombre, 99999]:
		var source := SourceLocale.new()
		arbre.root.add_child(source)
		var vues: Array[VueGlobale] = []
		source.vue_globale_recue.connect(func(v: VueGlobale) -> void: vues.append(v))
		source.definir_skin(index)
		verifier(source.demarrer(d_skins, AidesPartie.config(GRAINE), "Mina"), "démarrage")
		_simuler(source, 1.0)
		verifier(not vues.is_empty(), "une vue globale")
		if not vues.is_empty():
			var attendu := index if index >= 0 and index < nombre else 0
			verifier_egal(int(vues[0].joueurs[0]["skin"]), attendu, "skin %d" % index)
		source.quitter_partie()
		source.free()
