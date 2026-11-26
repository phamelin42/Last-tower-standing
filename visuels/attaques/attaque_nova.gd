class_name AttaqueNova
extends AttaqueElement
## Nova d'ambre (onde) : rien ne part vers un ennemi ; un front de croissants de feu ambré s'écarte
## de la tour, à la vitesse de l'onde, jusqu'à son rayon maximal, et des braises se posent derrière
## lui avant de s'éteindre. La brûlure est la marque d'aujourd'hui.

const CONF: Dictionary = {
	"couleur": Color(0.91, 0.6, 0.17),
	"projectile": "",
	"cloche": 0.0,
	"fps": 0.0,
}
## Le rayon maximal (450 unités) et la vitesse (500 unités par seconde) de l'onde de
## `data/armes.json`, en pixels du monde : un test les compare aux données.
const RAYON_PX: float = 225.0
const VITESSE_PX: float = 250.0
const LAMES: int = 12
## Deux couronnes de braises, à ces fractions du rayon ; chacune apparaît quand le front passe.
const COURONNES_BRAISES: Array[float] = [0.4, 0.75]
const BRAISES: int = 6
const IMAGES_BRAISE: int = 24
const DIAMETRE_BRAISE: float = 12.0


func id() -> String:
	return ElementsArmes.NOVA


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"vague_ambre": Vector2i(12, 32), "braise": Vector2i(4, 4)}


func visibles() -> Dictionary:
	return {"braise": 4.0}


func onde(m: AttaquesElementaires, centre: Vector2, age: float) -> bool:
	var cree: bool = m.front("vague_ambre", centre, RAYON_PX, VITESSE_PX, LAMES, age, Color.WHITE)
	var seq: Array[int] = []
	for i: int in IMAGES_BRAISE:
		seq.append((i / 3) % 2)
	for fraction: float in COURONNES_BRAISES:
		for k: int in BRAISES:
			var angle: float = TAU * (k + fraction) / BRAISES
			var ou: Vector2 = centre + Vector2.from_angle(angle) * RAYON_PX * fraction
			# La braise naît quand le front passe sur elle.
			var delai: float = RAYON_PX * fraction / VITESSE_PX
			cree = (
				not m.image_impact("braise", ou, DIAMETRE_BRAISE, seq, age - delai).is_empty()
				or cree
			)
	return cree
