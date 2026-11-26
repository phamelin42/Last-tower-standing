extends CasDeTest
## La vitrine d'effets (`tools/vitrines/vitrine_effets.tscn`) rejoue tout ce que `Effets` sait
## dessiner : chaque type de dégâts avec chaque genre d'arme, chaque statut, l'explosion et
## l'absorption. Un agent qui la capture doit y trouver chaque cas, à chaque cycle.

const SCENE := "res://tools/vitrines/vitrine_effets.tscn"
const PAS := 0.05
## Un cycle entier, plus de quoi voir le suivant commencer.
const PAS_PAR_TEST: int = 40

var _vitrine: VitrineEffets = null


func avant_chaque() -> void:
	var scene: PackedScene = load(SCENE)
	verifier_non_nul(scene, "la scène de la vitrine existe")
	_vitrine = scene.instantiate() as VitrineEffets
	arbre.root.add_child(_vitrine)


func apres_chaque() -> void:
	if is_instance_valid(_vitrine):
		_vitrine.free()
	_vitrine = null


func _jouer(pas: int) -> void:
	for i: int in pas:
		_vitrine.avancer(PAS)


func test_chaque_type_de_degats_et_chaque_genre_cree_un_effet() -> void:
	await attendre_images(2)
	_jouer(PAS_PAR_TEST)
	var crees: Dictionary = _vitrine.crees
	for type_degats: int in Effets.PROJECTILES.size():
		for genre: int in VueArene.GENRES_ARME.size():
			var cle: String = VitrineEffets.cle_genre(type_degats, genre)
			verifier(crees.has(cle), "%s : la cellule a été tirée" % cle)
			verifier(int(crees.get(cle, 0)) > 0, "%s : au moins un effet créé" % cle)


func test_chaque_statut_ajoute_son_effet() -> void:
	_jouer(PAS_PAR_TEST)
	var crees: Dictionary = _vitrine.crees
	for statut: int in range(1, VueArene.STATUTS_ARME.size()):
		var cle: String = VitrineEffets.cle_statut(statut)
		verifier(crees.has(cle), "%s : la cellule a été tirée" % cle)
		# L'impact de base plus, quand le statut a une forme (Effets.FORMES_STATUT), la sienne.
		var attendu: int = 2 if Effets.FORMES_STATUT.has(VueArene.STATUTS_ARME[statut]) else 1
		verifier(int(crees.get(cle, 0)) >= attendu, "%s : %d effet(s) au moins" % [cle, attendu])


func test_explosion_et_absorption() -> void:
	_jouer(PAS_PAR_TEST)
	var crees: Dictionary = _vitrine.crees
	verifier(int(crees.get(VitrineEffets.CLE_EXPLOSION, 0)) > 0, "explosion créée")
	verifier(int(crees.get(VitrineEffets.CLE_ABSORPTION, 0)) > 0, "absorption créée")


func test_le_pool_ne_depasse_jamais_le_plafond_sur_plusieurs_cycles() -> void:
	_jouer(PAS_PAR_TEST * 5)
	verifier(_vitrine.pic_vivants > 0, "des effets ont vécu")
	verifier(_vitrine.pic_vivants <= Effets.PLAFOND, "vivants sous le plafond")
	verifier(_vitrine.effets.taille_pool() <= Effets.PLAFOND, "pool sous le plafond")


func test_le_cycle_se_repete() -> void:
	_jouer(PAS_PAR_TEST * 3)
	verifier(_vitrine.cycles >= 2, "au moins deux cycles complets rejoués")
