extends CasDeTest
## Le lecteur joue ce que le détecteur annonce, une fois par transition, et la musique d'ambiance
## tourne tant qu'on ne l'arrête pas.


func _lecteur() -> LecteurSons:
	var lecteur := LecteurSons.new()
	arbre.root.add_child(lecteur)
	return lecteur


func _vue_avec_tir() -> VueArene:
	var v := VueArene.new()
	v.evenements.append(
		{
			"k": "tir",
			"t": 0,
			"de": Vector2.ZERO,
			"vers": Vector2.ONE,
			"type_degats": 0,
			"rayon": 0.0
		}
	)
	return v


func test_un_tir_joue_le_son_de_tir() -> void:
	var lecteur := _lecteur()
	lecteur.traiter(_vue_avec_tir())
	verifier_contient(lecteur.derniers_sons, CatalogueSons.TIR, "le tir se joue")


func test_une_vue_sans_changement_ne_rejoue_rien() -> void:
	var lecteur := _lecteur()
	var v := _vue_avec_tir()
	lecteur.traiter(v)
	lecteur.traiter(v)
	verifier_egal(lecteur.derniers_sons.size(), 0, "même vue, aucun son au pas suivant")


func test_l_ambiance_tourne_jusqu_a_l_arret() -> void:
	var lecteur := _lecteur()
	lecteur.demarrer_ambiance()
	verifier(lecteur.ambiance_active(), "la musique d'ambiance joue")
	lecteur.arreter()
	verifier_faux(lecteur.ambiance_active(), "arrêtée à la fin de la partie")


func test_la_hauteur_varie_dans_5_pour_cent_et_prend_plusieurs_valeurs() -> void:
	var lecteur := _lecteur()
	lecteur.graine(42)
	var vues: Array[VueArene] = []
	for i: int in 20:
		var v := _vue_avec_tir()
		v.tick = i + 1
		vues.append(v)
	var valeurs: Dictionary = {}
	for v: VueArene in vues:
		lecteur.traiter(v)
		for h: float in lecteur.derniere_hauteur:
			verifier(h >= 0.95 and h <= 1.05, "hauteur %.3f hors de ± 5 %%" % h)
			valeurs[snappedf(h, 0.0001)] = true
	verifier(valeurs.size() > 5, "%d hauteurs distinctes seulement" % valeurs.size())


func test_la_meme_graine_donne_les_memes_hauteurs() -> void:
	var a: Array[float] = []
	var b: Array[float] = []
	for sortie: Array[float] in [a, b]:
		var lecteur := _lecteur()
		lecteur.graine(7)
		for i: int in 5:
			var v := _vue_avec_tir()
			v.tick = i + 1
			lecteur.traiter(v)
			sortie.append_array(lecteur.derniere_hauteur)
	verifier_egal(a, b)
