extends CasDeTest
## Éléments de fin de partie (T12.8) : chacune des 15 armes a son élément D22, bâti sur la famille
## d'une arme existante et teinté par rareté (ambre, rose) d'après `data/assets.json` ; rien ne
## reste muet : tir, impact, zone, aura, onde ou piège, selon sa mécanique, créent un effet teinté.

var d: Donnees
var m: AttaquesElementaires


func avant_chaque() -> void:
	d = Donnees.charger()
	m = AttaquesElementaires.new()
	m.place = 400


func _tardives() -> Array[String]:
	var ids: Array[String] = []
	for id: String in d.armes:
		if int((d.armes[id] as Dictionary)["rarete"]) >= Types.Rarete.ANCESTRALE:
			ids.append(id)
	return ids


func _teinte_attendue(id: String) -> Color:
	var table: Dictionary = Assets.typee("signatures").get("raretes_tardives", {})
	var nom: String = Types.NOMS_RARETES[int((d.armes[id] as Dictionary)["rarete"])]
	return (table[nom] as Dictionary)["teinte"]


func test_chaque_arme_tardive_a_son_element_teinte_par_sa_rarete() -> void:
	verifier_egal(_tardives().size(), 15, "quinze armes de fin de partie")
	var registre: Dictionary = AttaquesElementaires.registre()
	for id: String in _tardives():
		verifier_egal(ElementsArmes.de(id), id, "%s : élément de l'arme" % id)
		verifier(AttaquesElementaires.connait(id), "%s : élément connu du rendu" % id)
		var element: AttaqueElement = registre.get(id)
		verifier_non_nul(element, "%s : élément dans le registre" % id)
		if element == null:
			continue
		verifier_egal(element.teinte(), _teinte_attendue(id), "%s : teinte de sa rareté" % id)
		verifier(element.teinte() != Color.WHITE, "%s : une teinte qui se voit" % id)
		verifier(SignaturesArmes.en_jeu(id), "%s : en jeu (la garde du lot 12 est levée)" % id)


func test_les_armes_d_avant_ne_sont_pas_teintees() -> void:
	var registre: Dictionary = AttaquesElementaires.registre()
	for id: String in d.armes:
		if int((d.armes[id] as Dictionary)["rarete"]) >= Types.Rarete.ANCESTRALE:
			continue
		var element: AttaqueElement = registre.get(ElementsArmes.de(id))
		verifier_non_nul(element, "%s : élément" % id)
		if element != null:
			verifier_egal(element.teinte(), Color.WHITE, "%s : pas de teinte" % id)


func test_les_planches_d_une_arme_tardive_sont_celles_de_sa_famille_et_son_tapis_propre() -> void:
	var familles: Dictionary = Assets.typee("signatures").get("familles_tardives", {})
	var registre: Dictionary = AttaquesElementaires.registre()
	for id: String in _tardives():
		var fiche: Dictionary = familles[id]
		var base: AttaqueElement = registre.get(str(fiche["famille"]))
		var element: AttaqueElement = registre.get(id)
		verifier_non_nul(base, "%s : famille %s" % [id, fiche["famille"]])
		if base == null or element == null:
			continue
		# Un tapis propre (`disque` des données) remplace celui de la famille, rien d'autre.
		var attendu: Dictionary = base.conf().duplicate()
		if fiche.has("disque"):
			attendu["disque"] = fiche["disque"]
		verifier_egal(element.conf(), attendu, "%s : fiche de la famille" % id)
		for planche: String in base.planches():
			verifier_egal(
				element.planches().get(planche), base.planches()[planche], "%s : %s" % [id, planche]
			)
		if not fiche.has("disque"):
			verifier_egal(element.planches(), base.planches(), "%s : planches de la famille" % id)


func test_chaque_arme_tardive_cree_un_effet_teinte_selon_sa_mecanique() -> void:
	for id: String in _tardives():
		m.vider()
		var effets: Array = (d.armes[id] as Dictionary)["effets"]
		var kind: String = str((effets[0] as Dictionary)["kind"])
		var cree := false
		var depart := Vector2(0.0, 0.0)
		var arrivee := Vector2(240.0, 60.0)
		match kind:
			"aura":
				cree = m.aura(id, depart, 300.0)
			"onde":
				cree = m.onde(id, depart)
			"piege", "mine":
				cree = m.piege(id, depart, arrivee)
			"zone", "barrage":
				cree = m.tirer(id, depart, arrivee) >= 0.0
				cree = m.impacter(id, arrivee, 200.0, false, depart, 0.0) or cree
			_:
				cree = m.tirer(id, depart, arrivee) >= 0.0
				cree = m.impacter(id, arrivee, 0.0, false, depart, 0.0) or cree
		verifier(cree, "%s (%s) : un effet est créé" % [id, kind])
		var teintes := 0
		for effet: Dictionary in m._vivants:
			if (effet["teinte"] as Color) == _teinte_attendue(id):
				teintes += 1
		verifier(teintes > 0, "%s : au moins un effet porte la teinte de sa rareté" % id)
	m.vider()
