class_name AttaqueBaliste
extends AttaquePercante
## Baliste de guet (cible unique, poison) : un gros carreau derrière une longue traînée, grise et
## verte ; à l'impact une gerbe plus lourde que celle de l'arbalète (toujours une cible unique),
## le carreau planté et quelques gouttes de venin. La marque de poison reste celle d'`Effets`.

const CONF: Dictionary = {
	"couleur": COULEUR_ACIER,
	"projectile": "carreau_baliste",
	"cloche": 0.0,
	"echelle": 1.0,
}
const DIAMETRE_LOURD: float = 56.0
const IMAGES_PLANTE: int = 10
const ECLATS: int = 3
const GOUTTES: int = 3
const VIE_TRAINEE: float = 20.0 * AttaquesElementaires.IMAGE


func id() -> String:
	return ElementsArmes.BALISTE


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 6, VIE_TRAINEE, COULEUR_ACIER, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = gerbe(m, ou, DIAMETRE_LOURD, age)
	cree = planter(m, ou, IMAGES_PLANTE, age, diametre_plante(MULTIPLE_PLANTE_LOURD)) or cree
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
