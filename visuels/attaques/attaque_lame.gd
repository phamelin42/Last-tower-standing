class_name AttaqueLame
extends AttaqueElement
## Lame de fil (cible unique) : un croissant d'acier qui tourne sur lui-même en filant droit ; à
## l'impact une entaille blanche en arc, petite, et deux éclats métalliques.

const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "lame_croissant",
	"cloche": 0.0,
	"fps": 30.0,
	"fige_reduit": true,
}
const SEQ_ENTAILLE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const ECLATS: int = 2


func id() -> String:
	return ElementsArmes.LAME


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"lame_croissant": Vector2i(16, 16), "entaille": Vector2i(24, 24)}


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
		ECLATS,
		CONF["couleur"],
		12.0 * AttaquesElementaires.IMAGE,
		60.0,
		140.0,
		Vector2.ZERO,
		1.5
	)
	return not entaille.is_empty()
