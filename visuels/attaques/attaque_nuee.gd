class_name AttaqueNuee
extends AttaqueElement
## Nuée d'étincelles (barrage de six, mana au coup) : six petites étincelles violettes partent à la
## suite, décalées de deux images, et filent droit ; chacune éclate en un éclat de rune, petit, et
## un seul anneau fin au rayon réel marque la zone pour toute la nuée. La marque de mana reste
## celle d'`Effets`.

const COULEUR := Color(0.7, 0.8, 1.0)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"projectile": "etincelle",
	"cloche": 0.0,
	"echelle": 0.9,
	"vrille": 3.0,
	"fige_reduit": true,
}
const IMAGE_PIC: int = 3
const SEQ_ECLAT: Array[int] = [0, 1, 3, 3, 4, 4, 4, 4]
const DIAMETRE_ECLAT: float = 30.0
const IMAGES_ANNEAU: int = 18
const ETINCELLES: int = 2


func id() -> String:
	return ElementsArmes.NUEE


func conf() -> Dictionary:
	return CONF


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, de: Vector2, age: float
) -> bool:
	var cree: bool = impacter_en_groupe(m, ou, rayon_px, fort, de, age)
	if rayon_px > 0.0:
		cree = zone(m, ou, rayon_px, age) or cree
	return cree


func impacter_en_groupe(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = not m.image_impact("eclat_rune", ou, DIAMETRE_ECLAT, SEQ_ECLAT, age).is_empty()
	m.salve(
		ou, ETINCELLES, COULEUR, 10.0 * AttaquesElementaires.IMAGE, 50.0, 130.0, Vector2.ZERO, 1.5
	)
	return cree


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, COULEUR)
