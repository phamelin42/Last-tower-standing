extends CasDeTest
## En solo, la source locale remet le bilan du joueur à la fin de la partie, une seule fois.

const DT := 0.05

var d: Donnees


func avant_chaque() -> void:
	d = AidesPartie.donnees()


func _source() -> SourceLocale:
	var s := SourceLocale.new()
	arbre.root.add_child(s)
	return s


func apres_chaque() -> void:
	for enfant: Node in arbre.root.get_children():
		if enfant is SourceLocale:
			enfant.free()


func test_le_bilan_arrive_une_fois_a_la_fin_de_la_partie_solo() -> void:
	var s := _source()
	var recus: Array[Dictionary] = []
	s.bilan_recu.connect(func(b: Dictionary) -> void: recus.append(b))
	verifier(s.demarrer(d, AidesPartie.config(5, 8.0), "Solo"))
	verifier_egal(s.bilan(), {}, "pas de bilan avant la fin")
	var pas := 0
	while recus.is_empty() and pas < 80000:
		s._process(DT)
		pas += 1
	verifier_egal(recus.size(), 1, "un bilan à la fin de la partie")
	for _i: int in 10:
		s._process(DT)
	verifier_egal(recus.size(), 1, "et un seul")
	var bilan := recus[0]
	verifier_egal(bilan.size(), BilanPartie.noms().size())
	verifier(float(bilan["manche_atteinte"]) >= 1.0)
	verifier_egal(s.bilan(), bilan, "bilan() rend le même")
	verifier_non_nul(BilanPartie.depuis_dict(bilan), "un bilan valide")


func test_un_nouveau_depart_efface_le_dernier_bilan() -> void:
	var s := _source()
	verifier(s.demarrer(d, AidesPartie.config(6, 8.0), "Solo"))
	var pas := 0
	while s.bilan().is_empty() and pas < 80000:
		s._process(DT)
		pas += 1
	verifier_faux(s.bilan().is_empty())
	verifier(s.demarrer(d, AidesPartie.config(7, 8.0), "Solo"))
	verifier_egal(s.bilan(), {}, "la partie suivante repart sans bilan")


func test_quitter_la_partie_ne_donne_pas_de_bilan() -> void:
	var s := _source()
	var recus: Array[Dictionary] = []
	s.bilan_recu.connect(func(b: Dictionary) -> void: recus.append(b))
	verifier(s.demarrer(d, AidesPartie.config(8, 8.0), "Solo"))
	for _i: int in 100:
		s._process(DT)
	s.quitter_partie()
	for _i: int in 10:
		s._process(DT)
	verifier_egal(recus.size(), 0)
	verifier_egal(s.bilan(), {})
