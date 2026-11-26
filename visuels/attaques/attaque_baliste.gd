class_name AttaqueBaliste
extends AttaquePercante
## Baliste de guet (cible unique, poison) : un gros carreau derrière une longue traînée, grise et
## verte ; à l'impact une gerbe plus lourde que celle de l'arbalète (toujours une cible unique),
## le carreau planté et quelques gouttes de venin. La marque de poison reste celle d'`Effets`.

const CONF: Dictionary = {
	"couleur": COULEUR_ACIER,
	"projectile": "carreau_baliste",
	"cloche": 0.0,
	"fps": 0.0,
	"echelle": 1.0,
}
const DIAMETRE_LOURD: float = 56.0
const DIAMETRE_PLANTE_LOURD: float = 44.0
const IMAGES_PLANTE: int = 10
const ECLATS: int = 3
const GOUTTES: int = 3
const VIE_TRAINEE: float = 20.0 * AttaquesElementaires.IMAGE


func id() -> String:
	return ElementsArmes.BALISTE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return PLANCHES_PERCANTES.merged({"carreau_baliste": Vector2i(24, 10)})


func visibles() -> Dictionary:
	return VISIBLES_PERCANTES


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 6, VIE_TRAINEE, COULEUR_ACIER, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = gerbe(m, ou, DIAMETRE_LOURD, age)
	cree = planter(m, ou, IMAGES_PLANTE, age, DIAMETRE_PLANTE_LOURD) or cree
	eclats(m, ou, ECLATS, COULEUR_ACIER)
	m.salve(
		ou,
		GOUTTES,
		COULEUR_VENIN,
		18.0 * AttaquesElementaires.IMAGE,
		30.0,
		90.0,
		Vector2(0.0, 220.0),
		1.5
	)
	return cree
