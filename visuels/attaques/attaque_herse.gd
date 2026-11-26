class_name AttaqueHerse
extends AttaquePercante
## Herse de ressorts (barrage, étourdissement) : des piques de herse partent décalés de deux
## images ; chacun jette une petite gerbe, et un seul anneau au rayon réel marque la zone pour tout
## le tir. Les étoiles d'étourdissement restent celles d'`Effets`.

const CONF: Dictionary = {
	"couleur": COULEUR_BOIS,
	"projectile": "pique",
	"cloche": 0.0,
	"fps": 0.0,
}
const IMAGES_ANNEAU: int = 18
const ECLATS: int = 3


func id() -> String:
	return ElementsArmes.HERSE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return PLANCHES_PERCANTES.merged({"pique": Vector2i(12, 10)})


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
	var cree: bool = gerbe(m, ou, AttaquesElementaires.DIAMETRE_PETIT, age)
	eclats(m, ou, ECLATS, COULEUR_BOIS)
	return cree


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, COULEUR_BOIS)
