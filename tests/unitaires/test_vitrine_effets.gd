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


func test_le_tir_et_l_impact_partent_dans_la_meme_image_et_l_impact_attend_son_projectile() -> void:
	_jouer(1)
	verifier(_vitrine.effets.impacts_en_attente() > 0, "des impacts attendent leur projectile")
	var attente: float = Effets.DUREE_TIR + 2.0 * Effets.DECALAGE_SAUT + 0.02
	_vitrine.avancer(attente)
	verifier_egal(_vitrine.effets.impacts_en_attente(), 0, "tous les impacts sont arrivés")


func test_la_cible_de_chaque_cellule_reagit_au_coup() -> void:
	_jouer(PAS_PAR_TEST)
	var reactions: Dictionary = _vitrine.reactions_par_cellule
	for type_degats: int in Effets.PROJECTILES.size():
		for genre: int in VueArene.GENRES_ARME.size():
			var cle: String = VitrineEffets.cle_genre(type_degats, genre)
			verifier(int(reactions.get(cle, 0)) > 0, "%s : la cible a réagi" % cle)
	for statut: int in range(1, VueArene.STATUTS_ARME.size()):
		var cle: String = VitrineEffets.cle_statut(statut)
		verifier(int(reactions.get(cle, 0)) > 0, "%s : la cible a réagi" % cle)


func test_les_cibles_reculent_de_quatre_pixels_puis_reviennent() -> void:
	var recul_max: float = 0.0
	var ids: PackedInt32Array = _vitrine.ids_cibles()
	for i: int in PAS_PAR_TEST:
		_vitrine.avancer(PAS / 5.0)
		for id: int in ids:
			recul_max = maxf(recul_max, _vitrine.reactions.recul(id).length())
	verifier_proche(recul_max, ReactionsCoups.RECUL_PX, 0.01, "recul maximal")
	_jouer(PAS_PAR_TEST)
	for id: int in ids:
		verifier(_vitrine.reactions.recul(id).length() <= ReactionsCoups.RECUL_PX, "borné")
