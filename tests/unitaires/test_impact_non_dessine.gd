extends CasDeTest
## Un coup que le plafond d'effets empêche de dessiner ne fait réagir personne : pas de gel ni de
## recul d'ennemi sans cause visible. Sous le plafond, le même coup émet toujours son impact.

const IMAGE: float = 1.0 / 60.0
const ARMES_DE_SIEGE: Array[String] = ["catapulte_a_contrepoids", "obusier_de_breche"]

## Position (unités) des zones de remplissage, loin de la cible de l'arme.
const LIMITE_REMPLISSAGE: float = 1000.0

var _effets: Effets = null
var _vitrine: VitrineArmes = null
var _impacts: Array[bool] = []


func avant_chaque() -> void:
	_effets = Effets.new()
	arbre.root.add_child(_effets)
	_vitrine = VitrineArmes.new()
	_vitrine.armes = ARMES_DE_SIEGE.duplicate()
	_impacts.clear()
	_effets.impact_visible.connect(
		func(ou: Vector2, _rayon: float, fort: bool) -> void:
			# Les zones de remplissage émettent aussi : seul le coup de l'arme compte.
			if ou.x < LIMITE_REMPLISSAGE:
				_impacts.append(fort)
	)


func apres_chaque() -> void:
	if is_instance_valid(_effets):
		if _effets.get_parent() != null:
			_effets.get_parent().remove_child(_effets)
		_effets.free()
	_effets = null
	if is_instance_valid(_vitrine):
		_vitrine.free()
	_vitrine = null


## Remplit le pool de mines lointaines, qui restent au sol tant qu'elles n'explosent pas.
func _remplir() -> void:
	var i: int = 0
	while _effets.nombre_vivants() < Effets.PLAFOND and i < 4 * Effets.PLAFOND:
		(
			_effets
			. ajouter(
				{
					"k": "tir",
					"t": 0,
					"de": Vector2(5000 + i, 0),
					"vers": Vector2(5000 + i, 100),
					"type_degats": Types.TypeDegats.MAGIQUE,
					"rayon": 150.0,
					"genre": "mine",
				}
			)
		)
		i += 1


func test_un_coup_de_siege_sous_le_plafond_emet_un_impact_fort() -> void:
	for id: String in ARMES_DE_SIEGE:
		_impacts.clear()
		_effets.vider()
		_effets.ajouter(_vitrine.evenement_de(id, "impact"))
		verifier_egal(_impacts.size(), 1, "%s : un impact visible" % id)
		verifier(_impacts.has(true), "%s : un coup fort" % id)


func test_un_coup_de_siege_que_le_plafond_empeche_de_dessiner_ne_fait_reagir_personne() -> void:
	for id: String in ARMES_DE_SIEGE:
		_effets.vider()
		_remplir()
		_impacts.clear()
		verifier_egal(_effets.nombre_vivants(), Effets.PLAFOND, "plafond plein")
		_effets.ajouter(_vitrine.evenement_de(id, "impact"))
		verifier_egal(_impacts.size(), 0, "%s : rien n'est dessiné, aucun impact visible" % id)


func test_un_impact_differe_dont_l_arrivee_tombe_au_plafond_ne_fait_reagir_personne() -> void:
	for id: String in ARMES_DE_SIEGE:
		_effets.vider()
		_impacts.clear()
		_effets.ajouter(_vitrine.evenement_de(id, "tir"))
		# Le pool se remplit après le départ du projectile, avant que son impact n'arrive.
		_remplir()
		_effets.ajouter(_vitrine.evenement_de(id, "impact"))
		for _f: int in 90:
			_remplir()
			_effets.avancer(IMAGE)
		verifier_egal(_impacts.size(), 0, "%s : plafond plein à l'arrivée, aucun impact" % id)
