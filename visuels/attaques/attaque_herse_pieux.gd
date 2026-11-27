class_name AttaqueHersePieux
extends AttaquePercante
## Herse de pieux (onde, repoussement) : rien ne part vers un ennemi ; un front de pieux s'écarte de
## la tour, à la vitesse de l'onde, jusqu'à son rayon maximal, et des touffes de pointes jaillissent
## du sol derrière lui, chacune quand le front passe, avant de s'abaisser. Le trait de recul reste
## celui d'`Effets`.

const CONF: Dictionary = {
	"couleur": COULEUR_BOIS,
	"projectile": "",
	"cloche": 0.0,
}
## Le rayon maximal (400 unités) et la vitesse (450 unités par seconde) de l'onde de
## `data/armes.json`, en pixels du monde : un test les compare aux données.
const RAYON_PX: float = 200.0
const VITESSE_PX: float = 225.0
const PIQUES: int = 12
## Deux couronnes de touffes, à ces fractions du rayon ; chacune sort quand le front passe.
const COURONNES_POINTES: Array[float] = [0.45, 0.8]
const TOUFFES: int = 8
const DIAMETRE_POINTES: float = 36.0
const SEQ_POINTES: Array[int] = [0, 1, 2, 2, 2, 3, 3, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5]


func id() -> String:
	return ElementsArmes.HERSE_PIEUX


func conf() -> Dictionary:
	return CONF


func onde(m: AttaquesElementaires, centre: Vector2, age: float) -> bool:
	var cree: bool = m.front("pique", centre, RAYON_PX, VITESSE_PX, PIQUES, age, Color.WHITE)
	for fraction: float in COURONNES_POINTES:
		for k: int in TOUFFES:
			var angle: float = TAU * (k + fraction) / TOUFFES
			var ou: Vector2 = centre + Vector2.from_angle(angle) * RAYON_PX * fraction
			# La touffe sort quand le front passe sur elle.
			var delai: float = RAYON_PX * fraction / VITESSE_PX
			var touffe: Dictionary = m.image_impact(
				"pointes_sol", ou, DIAMETRE_POINTES, SEQ_POINTES, age - delai
			)
			cree = not touffe.is_empty() or cree
	return cree
