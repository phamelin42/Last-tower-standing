class_name AttaqueCarquois
extends AttaquePercante
## Carquois en rafale (barrage de huit, vulnérabilité) : huit traits teintés de chaud partent à la
## suite, décalés de deux images ; chacun jette une petite gerbe et reste planté un instant, et un
## seul anneau au rayon réel marque la zone pour toute la rafale. La marque de vulnérabilité reste
## celle d'`Effets`.

const TEINTE := Color(1.0, 0.85, 0.7)
const COULEUR_PLUME := Color(0.85, 0.3, 0.25)
const CONF: Dictionary = {
	"couleur": COULEUR_PLUME,
	"projectile": "aiguille",
	"cloche": 0.0,
	"fps": 0.0,
	"echelle": 0.9,
	"teinte": TEINTE,
}
const DIAMETRE_GERBE: float = 22.0
const DIAMETRE_TRAIT: float = 20.0
const IMAGES_PLANTE: int = 10
const IMAGES_ANNEAU: int = 18
const ECLATS: int = 2


func id() -> String:
	return ElementsArmes.CARQUOIS


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return PLANCHES_PERCANTES.merged({"aiguille": Vector2i(14, 4)})


func visibles() -> Dictionary:
	return VISIBLES_PERCANTES


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
	var cree: bool = gerbe(m, ou, DIAMETRE_GERBE, age)
	cree = planter(m, ou, IMAGES_PLANTE, age, DIAMETRE_TRAIT) or cree
	eclats(m, ou, ECLATS, COULEUR_PLUME)
	return cree


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, TEINTE)
