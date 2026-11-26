class_name AttaqueArbalete
extends AttaquePercante
## Arbalète de bureau (cible unique) : un carreau court qui file droit derrière une fine traînée ;
## à l'impact une petite gerbe d'éclats, et le carreau reste planté six images.

const CONF: Dictionary = {
	"couleur": COULEUR_BOIS,
	"projectile": "carreau",
	"cloche": 0.0,
	"fps": 0.0,
}
const IMAGES_PLANTE: int = 6
const ECLATS: int = 4


func id() -> String:
	return ElementsArmes.ARBALETE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return PLANCHES_PERCANTES.merged({"carreau": Vector2i(16, 8)})


func visibles() -> Dictionary:
	return VISIBLES_PERCANTES


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 3, 8.0 * AttaquesElementaires.IMAGE, COULEUR_ACIER, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = gerbe(m, ou, AttaquesElementaires.DIAMETRE_PETIT, age)
	cree = planter(m, ou, IMAGES_PLANTE, age) or cree
	eclats(m, ou, ECLATS, COULEUR_BOIS)
	return cree
