class_name AttaquePluie
extends AttaquePercante
## Pluie d'aiguilles (barrage) : les aiguilles tombent du haut sur la zone, décalées de deux
## images ; chacune reste plantée un instant, et un seul anneau au rayon réel marque la zone pour
## tout le tir.

const CONF: Dictionary = {
	"couleur": COULEUR_ACIER,
	"projectile": "aiguille",
	"cloche": 0.0,
	"fps": 0.0,
	"chute": 110.0,
	"echelle": 0.6667,
}
const DIAMETRE_AIGUILLE: float = 22.0
const IMAGES_PLANTE: int = 24
const IMAGES_ANNEAU: int = 18
const ECLATS: int = 2
const DIAMETRE_GERBE: float = 26.0


func id() -> String:
	return ElementsArmes.PLUIE


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
	cree = planter(m, ou, IMAGES_PLANTE, age, DIAMETRE_AIGUILLE) or cree
	eclats(m, ou, ECLATS, COULEUR_ACIER)
	return cree


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, COULEUR_ACIER)
