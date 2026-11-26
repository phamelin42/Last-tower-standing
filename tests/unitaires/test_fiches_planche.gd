extends CasDeTest
## Les fiches de `tools/dessin/fiches_planche.gd` disent quels sprites la planche des signatures
## montre pour chaque arme : tout ce qu'elles citent existe, et chaque arme tranchante, perçante ou
## magique signée a la sienne (celles de siège et de chaos du lot 9 l'auront avec leurs dessins ;
## d'ici là la planche les montre par les formes de leur signature).

const Fiches := preload("res://tools/dessin/fiches_planche.gd")
const Dessin := preload("res://tools/dessiner_effets_attaques.gd")
## Rang des types de dégâts dans `data/armes.json` qui ont toutes leurs fiches : tranchant,
## perçant, magique.
const TYPES_AVEC_FICHES: Array[int] = [0, 1, 2]

var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func test_chaque_fiche_designe_une_arme_et_des_planches_qui_existent() -> void:
	for id: Variant in Fiches.FICHES:
		var fiche: Dictionary = Fiches.de(String(id))
		verifier(_donnees.armes.has(String(id)), "fiche orpheline : %s" % id)
		var projectile: String = String(fiche["projectile"])
		verifier(
			projectile == "" or Dessin.PLANCHES.has(projectile),
			"%s : projectile %s inconnu" % [id, projectile]
		)
		var impact: String = String(fiche["impact"])
		verifier(Dessin.PLANCHES.has(impact), "%s : impact %s inconnu" % [id, impact])
		if fiche.has("disque"):
			verifier(Dessin.PLANCHES.has(String(fiche["disque"])), "%s : disque inconnu" % id)
		if fiche.has("teinte"):
			var teinte: Color = fiche["teinte"]
			verifier(teinte.v >= 0.6, "%s : teinte trop sombre" % id)


func test_chaque_arme_signee_des_trois_premiers_types_a_une_fiche() -> void:
	for id: String in SignaturesArmes.ids():
		var rang: int = int((_donnees.armes[id] as Dictionary)["type_degats"])
		if TYPES_AVEC_FICHES.has(rang):
			verifier(not Fiches.de(id).is_empty(), "%s n'a pas de fiche" % id)


func test_une_arme_a_disque_au_sol_a_la_planche_de_son_disque() -> void:
	var vues: int = 0
	for id: String in SignaturesArmes.ids():
		if SignaturesArmes.de(id)["marque"] == "disque_au_sol":
			verifier(Fiches.de(id).has("disque"), "%s : pas de disque" % id)
			vues += 1
	verifier(vues > 0, "aucune arme à disque au sol")


func test_les_images_d_un_impact_sont_distinctes_et_dans_la_planche() -> void:
	for n: int in range(1, 9):
		var rangs: Array[int] = Fiches.images_impact(n)
		verifier(not rangs.is_empty(), "%d images : aucune image montrée" % n)
		for k: int in rangs.size():
			verifier(rangs[k] >= 0 and rangs[k] < n, "%d images : rang %d" % [n, rangs[k]])
			verifier(not rangs.slice(0, k).has(rangs[k]), "%d images : rang en double" % n)


func test_les_rayons_couvrent_le_nombre_de_branches_de_chaque_tir_tournant() -> void:
	var images: int = int(Dessin.PLANCHES["rayons"]["images"])
	var vues: int = 0
	for id: Variant in _donnees.armes:
		for effet: Variant in (_donnees.armes[id] as Dictionary)["effets"]:
			if String((effet as Dictionary)["kind"]) != "tournant":
				continue
			var branches: int = int((effet as Dictionary)["branches"])
			verifier(branches >= 2 and branches - 2 < images, "%s : %d branches" % [id, branches])
			vues += 1
	verifier(vues > 0, "aucun tir tournant")
