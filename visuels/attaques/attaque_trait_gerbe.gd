class_name AttaqueTraitGerbe
extends AttaquePercante
## Trait en gerbe (barrage de trois, épines) : trois traits barbelés partent en éventail, décalés de
## deux images, et filent droit ; chacun jette une petite gerbe et reste planté un instant, hérissé
## d'épines vertes, et un seul anneau au rayon réel marque la zone pour tout le tir.

const CONF: Dictionary = {
	"couleur": COULEUR_ACIER,
	"projectile": "aiguille",
	"cloche": 0.0,
	"echelle": 1.2,
}
const COULEUR_EPINE := Color(0.55, 0.7, 0.3)
const DIAMETRE_GERBE: float = 28.0
const DIAMETRE_TRAIT: float = 24.0
const IMAGES_PLANTE: int = 8
const IMAGES_ANNEAU: int = 18
const VIE_TRAINEE: float = 6.0 * AttaquesElementaires.IMAGE
const ECLATS: int = 2
const EPINES: int = 3


func id() -> String:
	return ElementsArmes.TRAIT_GERBE


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 2, VIE_TRAINEE, COULEUR_ACIER, Vector2.ZERO)


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
	eclats(m, ou, ECLATS, COULEUR_BOIS)
	eclats(m, ou, EPINES, COULEUR_EPINE)
	return cree


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, COULEUR_BOIS)
