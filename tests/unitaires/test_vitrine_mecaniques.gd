extends CasDeTest
## La vitrine des mécaniques (`tools/vitrines/vitrine_mecaniques.tscn`) : un agent qui la capture
## doit voir, sur un cycle, des alliés, des zones, des bombes qui explosent, des rayons, un recul et
## les trois nouveaux statuts, sous le plafond d'effets.

const SCENE := "res://tools/vitrines/vitrine_mecaniques.tscn"
const PAS := 1.0 / 60.0

var _vitrine: VitrineMecaniques = null


func apres_chaque() -> void:
	if is_instance_valid(_vitrine):
		if _vitrine.get_parent() != null:
			_vitrine.get_parent().remove_child(_vitrine)
		_vitrine.free()
	_vitrine = null


func _ouvrir(reduit: bool, charge: bool) -> void:
	var scene: PackedScene = load(SCENE)
	verifier_non_nul(scene, "la scène existe")
	_vitrine = scene.instantiate() as VitrineMecaniques
	_vitrine.mouvement_reduit = reduit
	_vitrine.charge = charge
	arbre.root.add_child(_vitrine)


## Joue `secondes` ; rend ce qu'on a vu au plus, mécanique par mécanique.
func _jouer(secondes: float) -> Dictionary:
	var vu: Dictionary = {"allies": 0, "zones": 0, "bombes": 0, "marques": 0}
	var formes: Dictionary = {}
	var effets := _vitrine.arene.get_node("Effets") as Effets
	for _i: int in int(secondes / PAS):
		_vitrine.avancer(PAS)
		vu["allies"] = maxi(int(vu["allies"]), _vitrine.arene.nombre_allies_visibles())
		var poses: ZonesBombes2D = _vitrine.arene.zones_bombes()
		vu["zones"] = maxi(int(vu["zones"]), poses.nombre_zones())
		vu["bombes"] = maxi(int(vu["bombes"]), poses.nombre_bombes())
		var marques: MarquesStatut = _vitrine.arene.marques_statut()
		for k: int in marques.nombre():
			formes[marques.forme_de(k)] = true
		for forme: String in effets.formes_vivantes():
			formes[forme] = true
	vu["formes"] = formes
	return vu


func test_un_cycle_montre_toutes_les_mecaniques() -> void:
	_ouvrir(false, false)
	var vu: Dictionary = _jouer(VitrineMecaniques.PERIODE)
	verifier_egal(vu["allies"], VitrineMecaniques.NB_ALLIES)
	verifier_egal(vu["zones"], VitrineMecaniques.ZONES.size())
	verifier_egal(vu["bombes"], VitrineMecaniques.BOMBES.size(), "deux bombes en même temps")
	var formes: Dictionary = vu["formes"]
	for forme: String in [
		"trait_rayon", "recul", "explosion", "anneau", "cible_brisee", "voile", "siphon"
	]:
		verifier(formes.has(forme), "la forme %s est vue" % forme)
	verifier(_vitrine.pic_vivants <= Effets.PLAFOND, "plafond tenu")
	verifier(_vitrine.vues_envoyees >= 30, "des vues partent à 10 Hz")


func test_l_option_mouvement_reduit_arrive_jusqu_a_l_arene() -> void:
	_ouvrir(true, false)
	verifier(_vitrine.arene.mouvement_reduit)
	verifier(_vitrine.arene.zones_bombes().mouvement_reduit)
	_jouer(1.0)


func test_la_charge_pose_64_allies_32_zones_et_32_bombes_sous_le_plafond() -> void:
	_ouvrir(false, true)
	var vu: Dictionary = _jouer(2.0)
	verifier_egal(vu["allies"], VueArene.ALLIES_MAX)
	verifier_egal(vu["zones"], VueArene.ZONES_MAX)
	verifier(vu["bombes"] > 0 and vu["bombes"] <= VueArene.BOMBES_MAX)
	verifier(_vitrine.pic_vivants <= Effets.PLAFOND, "plafond tenu : %d" % _vitrine.pic_vivants)
	verifier(_vitrine.pic_vivants > 100, "et bien atteint presque : %d" % _vitrine.pic_vivants)
