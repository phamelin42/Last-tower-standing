class_name AttaqueRicochet
extends AttaquePercante
## Carreau ricochet (rebond) : un carreau par saut, qui part dès que le précédent est arrivé ; à
## chaque rebond une gerbe d'étincelles, sans rester planté puisqu'il repart.

const CONF: Dictionary = {
	"couleur": COULEUR_ACIER,
	"projectile": "carreau",
	"cloche": 0.0,
	"fps": 0.0,
	"saut": true,
}
const ECLATS: int = 3


func id() -> String:
	return ElementsArmes.RICOCHET


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return PLANCHES_PERCANTES.merged({"carreau": Vector2i(16, 8)})


func visibles() -> Dictionary:
	return VISIBLES_PERCANTES


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = gerbe(m, ou, AttaquesElementaires.DIAMETRE_PETIT, age)
	eclats(m, ou, ECLATS, COULEUR_ACIER)
	return cree
