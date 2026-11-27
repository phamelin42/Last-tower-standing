class_name AttaqueLegion
extends AttaqueChaos
## Légion de cendre (zone, chaos) : une motte de cendre lancée en cloche, qui roule sur elle-même,
## retombe en un nuage de mottes grises et de braises étalé sur tout le rayon réel, qui s'éteint
## lentement ; un anneau fin au rayon exact et quelques flocons.

const CONF: Dictionary = {
	"couleur": VIOLET,
	"projectile": "cendre",
	"cloche": 0.35,
	"tour": TAU,
	"fige_reduit": true,
}
## Le nuage s'attarde : trois images de montée, le pic au troisième rang, puis un long fondu.
const SEQ_NUAGE: Array[int] = [
	0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
]
const IMAGES_ANNEAU_ZONE: int = 14
const FLOCONS: int = 6
const COULEUR_FLOCON := Color(0.7, 0.68, 0.7)


func id() -> String:
	return ElementsArmes.LEGION


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return cases(["nuage_cendre"]).merged(super.planches())


func visibles() -> Dictionary:
	return mesures(["nuage_cendre"]).merged(super.visibles())


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var diametre: float = rayon_px * 2.0 if rayon_px > 0.0 else 48.0
	var cree: bool = jouer(m, "nuage_cendre", ou, diametre, SEQ_NUAGE, age)
	if rayon_px > 0.0:
		cree = m.anneau_impact(ou, diametre, IMAGES_ANNEAU_ZONE, age, VIOLET) or cree
	eclats(m, ou, FLOCONS, COULEUR_FLOCON)
	return cree
