class_name AttaqueVortex
extends AttaqueElement
## Vortex de verre (onde, vol de vie) : rien ne part vers un ennemi ; une spirale de bras de verre
## hérissés s'écarte de la tour, à la vitesse de l'onde, jusqu'à son rayon maximal, et des éclats
## se posent derrière elle avant de s'éteindre. Le soin qui remonte vers la tour est la marque
## d'aujourd'hui.

const CONF: Dictionary = {
	"couleur": Color(0.7, 0.88, 1.0),
	"projectile": "",
	"cloche": 0.0,
	"fps": 0.0,
}
## Le rayon maximal (450 unités) et la vitesse (500 unités par seconde) de l'onde de
## `data/armes.json`, en pixels du monde : un test les compare aux données.
const RAYON_PX: float = 225.0
const VITESSE_PX: float = 250.0
const BRAS: int = 10
## Deux couronnes d'éclats, à ces fractions du rayon ; chacune apparaît quand le front passe.
const COURONNES_ECLATS: Array[float] = [0.45, 0.8]
const ECLATS: int = 6
const IMAGES_ECLAT: int = 24
const DIAMETRE_ECLAT: float = 12.0


func id() -> String:
	return ElementsArmes.VORTEX


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"vague_verre": Vector2i(16, 32), "eclat_verre": Vector2i(4, 4)}


func visibles() -> Dictionary:
	return {"eclat_verre": 4.0}


func onde(m: AttaquesElementaires, centre: Vector2, age: float) -> bool:
	var cree: bool = m.front("vague_verre", centre, RAYON_PX, VITESSE_PX, BRAS, age, Color.WHITE)
	var seq: Array[int] = []
	for i: int in IMAGES_ECLAT:
		seq.append((i / 4) % 2)
	for fraction: float in COURONNES_ECLATS:
		for k: int in ECLATS:
			var angle: float = TAU * (k + fraction * 1.7) / ECLATS
			var ou: Vector2 = centre + Vector2.from_angle(angle) * RAYON_PX * fraction
			# L'éclat naît quand le front passe sur lui.
			var delai: float = RAYON_PX * fraction / VITESSE_PX
			cree = (
				not m.image_impact("eclat_verre", ou, DIAMETRE_ECLAT, seq, age - delai).is_empty()
				or cree
			)
	return cree
