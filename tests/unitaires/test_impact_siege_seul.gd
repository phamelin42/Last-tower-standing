extends CasAttaquesSiegeLot9
## Les impacts de siège à cible seule sont plus grands que ceux des autres armes à cible unique
## (décision de Phil du 27/11/2026, exception à la règle D22 « cible unique : 60 px au plus ») : au
## zoom de jeu le plus lointain, ils faisaient la taille d'un ennemi (132, 189 et 416 px d'empreinte
## pour une nova de 1 467). Leur taille est une donnée (`data/assets.json`,
## `effets.impact_siege_cible_unique`), la même pour toutes les armes de siège à cible seule ; une
## arme de siège de ce genre qui s'ajoute au catalogue la reçoit sans toucher au code. Les autres
## armes à cible unique gardent leurs 60 px.


## Les armes de siège à cible seule du catalogue, par la règle : type siège, genre cible unique.
func _armes_de_siege_a_cible_seule() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _donnees.armes:
		var arme: Dictionary = _donnees.armes[id]
		if (
			int(arme["type_degats"]) == Types.TypeDegats.SIEGE
			and String((arme["effets"] as Array)[0]["kind"]) == "cible_unique"
		):
			ids.append(id)
	return ids


func test_la_regle_trouve_les_quatre_armes_de_siege_a_cible_seule() -> void:
	var ids: Array[String] = _armes_de_siege_a_cible_seule()
	ids.sort()
	verifier_egal(
		ids,
		[
			"canon_du_dernier_rempart",
			"catapulte_a_contrepoids",
			"colosse_de_pierre",
			"ecrasement_de_tour"
		],
		"catapulte, écrasement, colosse et le canon souverain qui reprend le colosse"
	)


func test_chaque_arme_de_siege_a_cible_seule_frappe_a_la_taille_des_donnees() -> void:
	for id: String in _armes_de_siege_a_cible_seule():
		_a.vider()
		var element: String = ElementsArmes.de(id)
		verifier(_a.impacter(element, CIBLE, 0.0, true), "%s : un impact" % id)
		verifier_egal(_a.diametre_max(), _diametre_siege_seul(), "%s : la taille des données" % id)


func test_la_taille_vient_des_donnees_et_change_avec_elles() -> void:
	var tout: Dictionary = Assets.tout().duplicate(true)
	((tout["effets"] as Dictionary)["impact_siege_cible_unique"] as Dictionary)["diametre"] = 77.0
	Assets.remplacer(tout)
	for id: String in _armes_de_siege_a_cible_seule():
		_a.vider()
		_a.impacter(ElementsArmes.de(id), CIBLE, 0.0, true)
		verifier_egal(_a.diametre_max(), 77.0, "%s : 77 px" % id)
	Assets.reinitialiser()
	_a.vider()
	_a.impacter("catapulte", CIBLE, 0.0, true)
	verifier_egal(_a.diametre_max(), _diametre_siege_seul(), "les données du fichier reviennent")


func test_le_coup_de_siege_seul_se_lit_comme_un_coup_fort_sans_masquer_la_cible() -> void:
	var ordinaire: float = 60.0
	verifier(_diametre_siege_seul() > ordinaire, "plus grand que les 60 px d'une cible unique")
	verifier(
		_diametre_siege_seul() < _plus_petite_zone_de_siege_px(),
		"mais pas une zone (%.0f px)" % _plus_petite_zone_de_siege_px()
	)
	for id: String in _armes_de_siege_a_cible_seule():
		_a.vider()
		_a.impacter(ElementsArmes.de(id), CIBLE, 0.0, true)
		verifier(
			_a.opacite_max() <= AttaquesElementaires.ALPHA_MAX + 0.0001,
			"%s : la cible reste visible dessous (ALPHA_MAX)" % id
		)
		verifier(_a.gel_restant() > 0.0, "%s : le gel d'un coup fort" % id)


func test_les_autres_armes_a_cible_unique_gardent_leurs_soixante_pixels() -> void:
	var vues: int = 0
	for id: String in _donnees.armes:
		var arme: Dictionary = _donnees.armes[id]
		var genre: String = String((arme["effets"] as Array)[0]["kind"])
		if genre != "cible_unique" or int(arme["type_degats"]) == Types.TypeDegats.SIEGE:
			continue
		var element: String = ElementsArmes.de(id)
		if not AttaquesElementaires.connait(element):
			continue
		_a.vider()
		_a.impacter(element, CIBLE, 0.0, true)
		verifier(_a.diametre_max() <= DIAMETRE_MAX_CIBLE_UNIQUE, "%s : au plus 60 px" % id)
		vues += 1
	verifier(vues >= 15, "assez d'armes vues (%d)" % vues)
