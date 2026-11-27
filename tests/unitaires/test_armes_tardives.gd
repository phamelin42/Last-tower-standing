extends CasDeTest
## Armes de fin de partie (T12.7, §6.17.2) : trois par type de dégâts (deux ancestrales, une
## souveraine), aux prix des bandes de leur rareté et au rendement 1,2 × et 1,5 × celui de la
## meilleure épique du type ; chacune a son nom original, sa description, son son de tir, sa case
## d'image et sa signature.

const BANDES: Dictionary = {
	Types.Rarete.ANCESTRALE: Vector2i(3000, 5000), Types.Rarete.SOUVERAINE: Vector2i(8000, 10000)
}
const RAPPORTS: Dictionary = {Types.Rarete.ANCESTRALE: 1.2, Types.Rarete.SOUVERAINE: 1.5}
const PAR_TYPE: Dictionary = {Types.Rarete.ANCESTRALE: 2, Types.Rarete.SOUVERAINE: 1}
const TOLERANCE := 0.01
const DOC_ORIGINE := "res://docs/tower_survivors.md"

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _tardives() -> Array[String]:
	var ids: Array[String] = []
	for id: String in d.armes:
		if int((d.armes[id] as Dictionary)["rarete"]) >= Types.Rarete.ANCESTRALE:
			ids.append(id)
	return ids


func _meilleur_rendement_epique(type_degats: int) -> float:
	var meilleur := 0.0
	for id: String in d.armes:
		var arme: Dictionary = d.armes[id]
		if int(arme["rarete"]) == Types.Rarete.EPIQUE and int(arme["type_degats"]) == type_degats:
			meilleur = maxf(meilleur, Equilibrage.rendement(arme))
	return meilleur


func test_chaque_type_a_ses_trois_armes_tardives() -> void:
	verifier_egal(_tardives().size(), 15, "quinze armes de fin de partie")
	for type_degats: int in Types.NOMS_TYPES.size():
		for rarete: int in PAR_TYPE:
			var n := 0
			for id: String in _tardives():
				var arme: Dictionary = d.armes[id]
				if int(arme["type_degats"]) == type_degats and int(arme["rarete"]) == rarete:
					n += 1
			verifier_egal(
				n,
				int(PAR_TYPE[rarete]),
				"%s : %s" % [Types.NOMS_TYPES[type_degats], Types.NOMS_RARETES[rarete]]
			)


func test_chaque_arme_tardive_a_un_prix_dans_la_bande_de_sa_rarete() -> void:
	for id: String in _tardives():
		var arme: Dictionary = d.armes[id]
		var bande: Vector2i = BANDES[int(arme["rarete"])]
		var prix := int(arme["prix"])
		verifier(prix >= bande.x and prix <= bande.y, "%s : prix %d dans %s" % [id, prix, bande])


func test_le_rendement_est_1_2_fois_ou_1_5_fois_celui_de_la_meilleure_epique_du_type() -> void:
	for id: String in _tardives():
		var arme: Dictionary = d.armes[id]
		var rapport := float(RAPPORTS[int(arme["rarete"])])
		var meilleur := _meilleur_rendement_epique(int(arme["type_degats"]))
		var vu := Equilibrage.rendement(arme) / meilleur
		verifier(
			absf(vu / rapport - 1.0) <= TOLERANCE, "%s : rapport %.3f pour %.2f" % [id, vu, rapport]
		)


func test_chaque_arme_tardive_a_un_nom_original_et_une_description() -> void:
	var origine := FileAccess.get_file_as_string(DOC_ORIGINE).to_lower()
	for id: String in _tardives():
		var arme: Dictionary = d.armes[id]
		var nom := str(arme["nom"])
		verifier(not nom.is_empty(), "%s : nom" % id)
		verifier(
			not origine.contains(nom.to_lower()),
			"%s : « %s » figure dans la map d'origine" % [id, nom]
		)
		verifier(not str(arme["description"]).strip_edges().is_empty(), "%s : description" % id)


func test_chaque_arme_tardive_a_son_son_de_tir_sa_case_et_sa_signature() -> void:
	for id: String in _tardives():
		verifier(CatalogueSons.liste_ids_armes.has(id), "%s : son déclaré" % id)
		verifier(
			FileAccess.file_exists(CatalogueSons.chemin(CatalogueSons.id_tir(id))),
			"%s : fichier du son" % id
		)
		verifier_egal(CatalogueSons.id_tir(id), "tir_" + id, "%s : son propre" % id)
		verifier(ImageOffre.texture(id) != null, "%s : case d'image" % id)
		verifier(not SignaturesArmes.de(id).is_empty(), "%s : signature" % id)


func test_les_armes_tardives_ne_sont_pas_en_jeu_avant_la_validation_des_signatures() -> void:
	for id: String in _tardives():
		verifier_egal(
			SignaturesArmes.en_jeu(id), ElementsArmes.de(id) != "", "%s : en jeu ou proposée" % id
		)
