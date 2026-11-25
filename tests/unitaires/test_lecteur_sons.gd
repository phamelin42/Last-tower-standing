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
