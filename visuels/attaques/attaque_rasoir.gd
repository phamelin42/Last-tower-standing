class_name AttaqueRasoir
extends AttaqueElement
## Rasoir tournoyant (tir tournant, deux branches) : un rasoir droit par branche, qui file droit
## le long du rayon en tournant sur lui-même ; au bout du rayon une entaille blanche, petite, et
## deux éclats métalliques. Les rayons de la marque restent ceux d'`Effets`.

const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "rasoir",
	"cloche": 0.0,
	"vrille": 8.0,
	"fige_reduit": true,
}
const SEQ_ENTAILLE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const ECLATS: int = 2


func id() -> String:
	return ElementsArmes.RASOIR


func conf() -> Dictionary:
	return CONF


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
