class_name AttaqueCouperet
extends AttaqueElement
## Couperet à épines (cible unique) : un couperet hérissé qui culbute en filant droit, plus gros
## que les lames légères ; à l'impact une entaille blanche, petite, et des éclats d'épines.

const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "couperet",
	"cloche": 0.0,
	"fps": 20.0,
	"vrille": 3.0,
	"echelle": 1.15,
	"fige_reduit": true,
}
const SEQ_ENTAILLE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const EPINES: int = 4


func id() -> String:
	return ElementsArmes.COUPERET


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"couperet": Vector2i(14, 12), "entaille": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"entaille": 22.0}


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var entaille: Dictionary = m.image_impact(
		"entaille", ou, AttaquesElementaires.DIAMETRE_PETIT, SEQ_ENTAILLE, age
	)
	m.salve(
		ou,
		EPINES,
		CONF["couleur"],
		12.0 * AttaquesElementaires.IMAGE,
		70.0,
		160.0,
		Vector2.ZERO,
		1.5
	)
	return not entaille.is_empty()
