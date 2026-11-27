class_name AttaqueSerment
extends AttaqueChaos
## Serment brisé (cible unique, malédiction) : un sceau d'or fendu tourne sur lui-même en filant
## droit ; à l'impact il éclate en deux moitiés d'or, des éclats violets autour, petit. La marque de
## malédiction reste celle d'aujourd'hui.

const CONF: Dictionary = {
	"couleur": OR,
	"projectile": "serment",
	"cloche": 0.0,
	"fps": 0.0,
	"vrille": 1.5,
}
const DIAMETRE_COUP: float = 48.0


func id() -> String:
	return ElementsArmes.SERMENT


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return cases(["eclat_serment"]).merged({"serment": Vector2i(12, 12)})


func visibles() -> Dictionary:
	return mesures(["eclat_serment"])


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 3, 9.0 * AttaquesElementaires.IMAGE, VIOLET, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	eclats(m, ou, ECLATS, VIOLET)
	return jouer(m, "eclat_serment", ou, DIAMETRE_COUP, SEQ_IMPACT, age)
