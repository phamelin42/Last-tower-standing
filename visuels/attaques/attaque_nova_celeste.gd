class_name AttaqueNovaCeleste
extends AttaqueElement
## Nova céleste (onde, vulnérabilité, siphon) : rien ne part vers un ennemi ; un front de croissants
## célestes s'écarte de la tour, à la vitesse de l'onde, jusqu'à son rayon maximal, et des éclats
## étoilés éclosent derrière lui, chacun quand le front passe. Les marques de vulnérabilité et de
## siphon restent celles d'`Effets`.

const CONF: Dictionary = {
	"couleur": Color(1.0, 0.89, 0.48),
	"projectile": "",
	"cloche": 0.0,
	"fps": 0.0,
}
## Le rayon maximal (550 unités) et la vitesse (550 unités par seconde) de l'onde de
## `data/armes.json`, en pixels du monde : un test les compare aux données.
const RAYON_PX: float = 275.0
const VITESSE_PX: float = 275.0
const CROISSANTS: int = 14
## Deux couronnes d'éclats, à ces fractions du rayon ; chacune éclot quand le front passe.
const COURONNES_ECLATS: Array[float] = [0.4, 0.75]
const ECLATS: int = 6
const IMAGE_PIC: int = 3
const SEQ_ECLAT: Array[int] = [0, 1, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4]
const DIAMETRE_ECLAT: float = 36.0


func id() -> String:
	return ElementsArmes.NOVA_CELESTE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"vague_celeste": Vector2i(12, 32), "eclat_astral": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"eclat_astral": 22.0}


func onde(m: AttaquesElementaires, centre: Vector2, age: float) -> bool:
	var cree: bool = m.front(
		"vague_celeste", centre, RAYON_PX, VITESSE_PX, CROISSANTS, age, Color.WHITE
	)
	for fraction: float in COURONNES_ECLATS:
		for k: int in ECLATS:
			var angle: float = TAU * (k + fraction) / ECLATS
			var ou: Vector2 = centre + Vector2.from_angle(angle) * RAYON_PX * fraction
			# L'éclat éclot quand le front passe sur lui.
			var delai: float = RAYON_PX * fraction / VITESSE_PX
			var eclat: Dictionary = m.image_impact(
				"eclat_astral", ou, DIAMETRE_ECLAT, SEQ_ECLAT, age - delai
			)
			cree = not eclat.is_empty() or cree
	return cree
