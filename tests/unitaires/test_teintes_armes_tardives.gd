extends CasDeTest
## Teintes de fin de partie (T12.8) : chaque rareté tardive a sa teinte dans les données, distincte
## et assez claire pour teinter un sprite ; les fiches des 15 armes ne portent pas de teinte propre
## (elle vient de la rareté), et chacune cite des planches qui existent.

const Fiches := preload("res://tools/dessin/fiches_planche.gd")
const Dessin := preload("res://tools/dessiner_effets_attaques.gd")
const TEINTE_MIN := 0.6

var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func _teintes() -> Dictionary:
	return Assets.typee("signatures").get("raretes_tardives", {})


func test_chaque_rarete_tardive_a_une_teinte_claire_et_distincte() -> void:
	var vues: Array[Color] = []
	for rarete: int in range(Types.Rarete.ANCESTRALE, Types.NOMS_RARETES.size()):
		var nom: String = Types.NOMS_RARETES[rarete]
		verifier(_teintes().has(nom), "%s : teinte dans les données" % nom)
		var teinte: Color = (_teintes().get(nom, {}) as Dictionary).get("teinte", Color.BLACK)
		verifier(teinte.v >= TEINTE_MIN, "%s : teinte assez claire" % nom)
		verifier(teinte != Color.WHITE, "%s : une teinte qui se voit" % nom)
		for autre: Color in vues:
			verifier(
				Vector3(autre.r - teinte.r, autre.g - teinte.g, autre.b - teinte.b).length() > 0.1,
				"%s : teinte distincte" % nom
			)
		vues.append(teinte)
	verifier_egal(_teintes().size(), vues.size(), "aucune teinte pour une rareté d'avant")


func test_les_quinze_fiches_de_fin_de_partie_citent_des_planches_et_n_ont_pas_de_teinte_propre(
) -> void:
	var n := 0
	for id: String in _donnees.armes:
		var arme: Dictionary = _donnees.armes[id]
		if int(arme["rarete"]) < Types.Rarete.ANCESTRALE:
			continue
		n += 1
		var fiche: Dictionary = Fiches.de(id)
		verifier(not fiche.is_empty(), "%s : fiche" % id)
		verifier(not fiche.has("teinte"), "%s : la teinte vient de la rareté" % id)
		var projectile := String(fiche.get("projectile", ""))
		verifier(projectile == "" or Dessin.PLANCHES.has(projectile), "%s : projectile" % id)
		verifier(Dessin.PLANCHES.has(String(fiche.get("impact", ""))), "%s : impact" % id)
	verifier_egal(n, 15, "quinze armes de fin de partie")
