class_name AttaqueJaveline
extends AttaquePercante
## Javeline de jet (cible unique, repoussement) : une javeline longue file droit derrière une fine
## traînée d'acier ; à l'impact une gerbe plus lourde que celle de l'arbalète, la javeline reste
## plantée huit images et des éclats d'acier jaillissent. Le trait de recul reste celui d'`Effets`.

const CONF: Dictionary = {
	"couleur": COULEUR_ACIER,
	"projectile": "javeline",
	"cloche": 0.0,
	"fps": 0.0,
	"echelle": 0.85,
}
const DIAMETRE_GERBE: float = 52.0
const IMAGES_PLANTE: int = 8
const ECLATS: int = 4
const VIE_TRAINEE: float = 10.0 * AttaquesElementaires.IMAGE


func id() -> String:
	return ElementsArmes.JAVELINE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return PLANCHES_PERCANTES.merged({"javeline": Vector2i(24, 8)})


func visibles() -> Dictionary:
	return VISIBLES_PERCANTES


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 4, VIE_TRAINEE, COULEUR_ACIER, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = gerbe(m, ou, DIAMETRE_GERBE, age)
	cree = planter(m, ou, IMAGES_PLANTE, age) or cree
	eclats(m, ou, ECLATS, COULEUR_ACIER)
	return cree
