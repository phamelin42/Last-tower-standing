extends CasDeTest
## Contrat des assertions : ce que la personne qui écrit un test obtient quand
## une valeur est juste (rien) ou fausse (un échec enregistré, sans interruption).


func _nouveau() -> CasDeTest:
	return CasDeTest.new()


func test_verifier_accepte_le_vrai_et_refuse_le_faux() -> void:
	var sujet := _nouveau()
	sujet.verifier(true)
	verifier_egal(sujet.echecs.size(), 0)
	sujet.verifier(false, "doit échouer")
	verifier_egal(sujet.echecs.size(), 1)
	verifier_contient(sujet.echecs[0], "doit échouer")
	verifier_egal(sujet.nb_assertions, 2)


func test_verifier_faux_est_l_inverse_de_verifier() -> void:
	var sujet := _nouveau()
	sujet.verifier_faux(false)
	verifier_egal(sujet.echecs.size(), 0)
	sujet.verifier_faux(true)
	verifier_egal(sujet.echecs.size(), 1)


func test_message_vide_accepte_et_sans_parenthese_orpheline() -> void:
	var sujet := _nouveau()
	sujet.verifier(false)
	sujet.verifier_egal(1, 2)
	verifier_egal(sujet.echecs.size(), 2)
	verifier_faux(sujet.echecs[1].begins_with(" "), "pas d'espace de tête sans message")


func test_message_d_echec_donne_attendu_et_recu() -> void:
	var sujet := _nouveau()
	sujet.verifier_egal(1, 2, "compte")
	verifier_contient(sujet.echecs[0], "compte")
	verifier_contient(sujet.echecs[0], "attendu 2")
	verifier_contient(sujet.echecs[0], "reçu 1")


func test_egal_sur_valeurs_simples() -> void:
	var sujet := _nouveau()
	sujet.verifier_egal(3, 3)
	sujet.verifier_egal("a", "a")
	sujet.verifier_egal(true, true)
	sujet.verifier_egal(Vector2(1, 2), Vector2(1, 2))
	sujet.verifier_egal(1.5, 1.5)
	verifier_egal(sujet.echecs.size(), 0)
	sujet.verifier_egal(3, 4)
	sujet.verifier_egal("a", "b")
	sujet.verifier_egal(Vector2(1, 2), Vector2(2, 1))
	verifier_egal(sujet.echecs.size(), 3)


func test_egal_sur_null() -> void:
	var sujet := _nouveau()
	sujet.verifier_egal(null, null)
	verifier_egal(sujet.echecs.size(), 0)
	sujet.verifier_egal(null, 0)
	sujet.verifier_egal(0, null)
	sujet.verifier_egal(null, "")
	verifier_egal(sujet.echecs.size(), 3)


func test_egal_distingue_entier_et_flottant() -> void:
	# Choix documenté : 1 et 1.0 ne sont PAS égaux, même imbriqués. Un test qui
	# attend un entier ne doit pas passer sur un flottant (et inversement).
	var sujet := _nouveau()
	sujet.verifier_egal(1, 1.0)
	sujet.verifier_egal(1.0, 1)
	sujet.verifier_egal([1], [1.0])
	sujet.verifier_egal({"a": 1}, {"a": 1.0})
	verifier_egal(sujet.echecs.size(), 4)
	sujet.verifier_egal(1, 1)
	sujet.verifier_egal(1.0, 1.0)
	verifier_egal(sujet.echecs.size(), 4)


func test_egal_sur_tableaux_imbriques() -> void:
	var sujet := _nouveau()
	sujet.verifier_egal([1, [2, [3, "x"]], null], [1, [2, [3, "x"]], null])
	sujet.verifier_egal([], [])
	verifier_egal(sujet.echecs.size(), 0)
	sujet.verifier_egal([1, [2, [3]]], [1, [2, [4]]])
	sujet.verifier_egal([1, 2], [1, 2, 3])
	sujet.verifier_egal([1, 2], [2, 1])
	verifier_egal(sujet.echecs.size(), 3)


func test_egal_sur_dictionnaires() -> void:
	var sujet := _nouveau()
	sujet.verifier_egal({"a": 1, "b": [1, 2]}, {"b": [1, 2], "a": 1})
	sujet.verifier_egal({}, {})
	verifier_egal(sujet.echecs.size(), 0)
	sujet.verifier_egal({"a": 1}, {"a": 2})
	sujet.verifier_egal({"a": 1}, {"b": 1})
	sujet.verifier_egal({"a": 1}, {"a": 1, "b": 2})
	sujet.verifier_egal({"a": {"b": 1}}, {"a": {"b": 2}})
	verifier_egal(sujet.echecs.size(), 4)


func test_egal_refuse_types_differents() -> void:
	var sujet := _nouveau()
	sujet.verifier_egal("1", 1)
	sujet.verifier_egal([], {})
	sujet.verifier_egal([], null)
	verifier_egal(sujet.echecs.size(), 3)


func test_different() -> void:
	var sujet := _nouveau()
	sujet.verifier_different(1, 2)
	sujet.verifier_different(1, 1.0)
	sujet.verifier_different([1], [2])
	verifier_egal(sujet.echecs.size(), 0)
	sujet.verifier_different(1, 1)
	sujet.verifier_different([1, [2]], [1, [2]])
	verifier_egal(sujet.echecs.size(), 2)


func test_proche_accepte_dans_la_tolerance_bornes_comprises() -> void:
	var sujet := _nouveau()
	sujet.verifier_proche(0.5, 0.5)
	sujet.verifier_proche(0.5, 0.625, 0.125)
	sujet.verifier_proche(0.625, 0.5, 0.125)
	sujet.verifier_proche(1.0, 1.00005)
	verifier_egal(sujet.echecs.size(), 0)


func test_proche_refuse_hors_tolerance() -> void:
	var sujet := _nouveau()
	sujet.verifier_proche(0.5, 0.75, 0.125)
	sujet.verifier_proche(0.75, 0.5, 0.125)
	sujet.verifier_proche(1.0, 1.001)
	sujet.verifier_proche(0.0, NAN)
	sujet.verifier_proche(INF, INF)
	verifier_egal(sujet.echecs.size(), 5)


func test_nul_et_non_nul() -> void:
	var sujet := _nouveau()
	sujet.verifier_nul(null)
	sujet.verifier_non_nul(0)
	sujet.verifier_non_nul("")
	sujet.verifier_non_nul([])
	verifier_egal(sujet.echecs.size(), 0)
	sujet.verifier_nul(0)
	sujet.verifier_nul("")
	sujet.verifier_non_nul(null)
	verifier_egal(sujet.echecs.size(), 3)


func test_contient_sur_chaque_type_de_collection() -> void:
	var sujet := _nouveau()
	sujet.verifier_contient([1, 2, 3], 2)
	sujet.verifier_contient({"a": 1}, "a")
	sujet.verifier_contient("bonjour", "jou")
	sujet.verifier_contient(PackedStringArray(["x", "y"]), "y")
	sujet.verifier_contient(PackedInt32Array([4, 5]), 5)
	verifier_egal(sujet.echecs.size(), 0)
	sujet.verifier_contient([1, 2, 3], 4)
	sujet.verifier_contient({"a": 1}, 1)
	sujet.verifier_contient("bonjour", "xyz")
	sujet.verifier_contient(PackedStringArray(["x"]), "z")
	sujet.verifier_contient(null, 1)
	verifier_egal(sujet.echecs.size(), 5)


func test_chaque_assertion_est_comptee() -> void:
	var sujet := _nouveau()
	sujet.verifier(true)
	sujet.verifier_faux(false)
	sujet.verifier_egal(1, 1)
	sujet.verifier_different(1, 2)
	sujet.verifier_proche(1.0, 1.0)
	sujet.verifier_nul(null)
	sujet.verifier_non_nul(1)
	sujet.verifier_contient([1], 1)
	verifier_egal(sujet.nb_assertions, 8)
	verifier_egal(sujet.echecs.size(), 0)
