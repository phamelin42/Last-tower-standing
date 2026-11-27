extends CasDeTest
## Le rayon d'un tir tournant prend la teinte de la rareté de l'arme de fin de partie (T11.9) :
## même teinte que le reste de ses effets, lue dans `data/assets.json` ; une arme d'avant garde la
## couleur de son type.

var _effets: Effets = null
var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_effets = Effets.new()
	_effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(_effets)


func apres_chaque() -> void:
	if is_instance_valid(_effets):
		_effets.get_parent().remove_child(_effets)
		_effets.free()


func _couleur_du_rayon(id: String) -> Color:
	_effets.vider()
	var arme: Dictionary = _donnees.armes[id]
	var evenement := {
		"k": "tir",
		"t": 1,
		"de": Vector2.ZERO,
		"vers": Vector2(0, -400),
		"type_degats": int(arme["type_degats"]),
		"rayon": 20.0,
		"genre": VueArene.GENRES_ARME.find("tournant"),
		"arme": _donnees.ids_catalogue.find(id),
	}
	verifier(_effets.ajouter(evenement), "%s : un effet est créé" % id)
	return _effets.couleur_de("trait_rayon")


func _sans_alpha(c: Color) -> Color:
	return Color(c.r, c.g, c.b)


func test_le_rayon_d_une_arme_tardive_est_teinte_comme_le_reste_de_ses_effets() -> void:
	var vues := 0
	for id: String in _donnees.armes:
		var arme: Dictionary = _donnees.armes[id]
		if int(arme["rarete"]) < Types.Rarete.ANCESTRALE:
			continue
		if str((arme["effets"][0] as Dictionary)["kind"]) != "tournant":
			continue
		vues += 1
		var teinte: Color = AttaquesElementaires.teinte_de(ElementsArmes.de(id))
		verifier(teinte != Color.WHITE, "%s : une teinte de rareté" % id)
		var attendu: Color = (Effets.COULEURS[int(arme["type_degats"])] as Color) * teinte
		verifier_egal(_sans_alpha(_couleur_du_rayon(id)), _sans_alpha(attendu), "%s" % id)
	verifier(vues > 0, "au moins une arme de fin de partie à tir tournant")


func test_le_rayon_d_une_arme_d_avant_garde_la_couleur_de_son_type() -> void:
	for id: String in ["rasoir_tournoyant", "moissonneuse_d_acier", "faucheuse_double"]:
		var type_degats := int((_donnees.armes[id] as Dictionary)["type_degats"])
		var attendu: Color = Effets.COULEURS[type_degats]
		verifier_egal(_sans_alpha(_couleur_du_rayon(id)), _sans_alpha(attendu), "%s" % id)
