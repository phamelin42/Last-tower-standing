extends CasDeTest
## La vitrine des armes montre une bombe comme la simulation la joue (l'explosion vient après le
## délai de la bombe, pas avec le tir) et peut montrer une seule arme en grand, la tour au centre,
## pour juger une zone ou une explosion large.

const PAS := 1.0 / 60.0
const CENTRE := Vector2(576.0, 324.0)

var _vitrine: VitrineArmes = null


func apres_chaque() -> void:
	if is_instance_valid(_vitrine):
		_vitrine.free()
	_vitrine = null


func _vitrine_de(id: String) -> VitrineArmes:
	_vitrine = VitrineArmes.new()
	_vitrine.armes = [id] as Array[String]
	arbre.root.add_child(_vitrine)
	return _vitrine


func _jouer(images: int) -> int:
	var pic: int = 0
	for _i: int in images:
		_vitrine.avancer(PAS)
		pic = maxi(pic, _vitrine.effets.elementaires().etats("explosion_feu").size())
	return pic


func test_une_bombe_n_explose_qu_apres_son_delai() -> void:
	var delai: float = float(Donnees.charger().armes["baril_a_retardement"]["effets"][0]["delai"])
	_vitrine_de("baril_a_retardement")
	var images_delai: int = int(delai / PAS)
	verifier_egal(_jouer(images_delai - 20), 0, "rien avant le délai : le baril est posé")
	verifier(_jouer(40) > 0, "l'explosion vient à la fin du délai")


func test_l_instance_garde_les_armes_qu_on_lui_donne_sans_option() -> void:
	_vitrine_de("baril_a_retardement")
	verifier_egal(_vitrine.armes, ["baril_a_retardement"] as Array[String])


func test_l_option_large_demande_une_seule_arme() -> void:
	var avec: PackedStringArray = PackedStringArray(["--large"])
	verifier(VitrineArmes.lire_grand(avec, 1), "une arme : en grand")
	verifier_faux(VitrineArmes.lire_grand(avec, 2), "deux armes : refusé")
	verifier_faux(VitrineArmes.lire_grand(PackedStringArray(), 1), "sans l'option : non")


func test_en_grand_la_tour_est_au_centre_de_l_ecran() -> void:
	_vitrine = VitrineArmes.new()
	_vitrine.armes = ["maillet_de_rempart"] as Array[String]
	_vitrine.grand = true
	arbre.root.add_child(_vitrine)
	verifier_proche(
		VitrineArmes.position_tour(0).distance_to(CENTRE - _vitrine.position), 0.0, 0.01
	)
	var cible: Vector2 = (
		VitrineArmes.position_ennemi(0, VitrineArmes.INDEX_TIRE) + _vitrine.position
	)
	verifier(cible.x < VitrineArmes.LARGEUR_ECRAN, "l'ennemi visé reste à l'écran")
