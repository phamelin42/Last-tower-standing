class_name AttaqueDiscorde
extends AttaqueChaos
## Miroir de discorde (rebond, vulnérabilité) : un éclat fendu, magenta d'un côté et violet de
## l'autre, par saut, qui vrille en lançant une traînée de verre ; à chaque cible huit pointes de
## verre, petites. La marque de vulnérabilité reste celle d'aujourd'hui.

const CONF: Dictionary = {
	"couleur": MAGENTA,
	"projectile": "eclat_discorde",
	"cloche": 0.0,
	"vrille": 2.0,
	"saut": true,
	"fige_reduit": true,
}
const DIAMETRE_COUP: float = 44.0


func id() -> String:
	return ElementsArmes.DISCORDE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return cases(["pointes_discorde"]).merged(super.planches())


func visibles() -> Dictionary:
	return mesures(["pointes_discorde"]).merged(super.visibles())


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 3, 9.0 * AttaquesElementaires.IMAGE, VERRE, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	eclats(m, ou, ECLATS, MAGENTA)
	return jouer(m, "pointes_discorde", ou, DIAMETRE_COUP, SEQ_IMPACT, age)
