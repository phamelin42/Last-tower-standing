class_name AttaqueGuillotine
extends AttaqueElement
## Guillotine à vapeur (onde) : rien ne part vers un ennemi ; un front de grandes lames d'acier en
## arc s'écarte de la tour, à la vitesse de l'onde, jusqu'à son rayon maximal, et des bouffées de
## vapeur se forment derrière lui avant de se dissiper.

const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "",
	"cloche": 0.0,
	"fps": 0.0,
}
## Le rayon maximal (500 unités) et la vitesse (600 unités par seconde) de l'onde de
## `data/armes.json`, en pixels du monde : un test les compare aux données.
const RAYON_PX: float = 250.0
const VITESSE_PX: float = 300.0
const LAMES: int = 10
## Deux couronnes de bouffées, à ces fractions du rayon ; chacune apparaît quand le front passe.
const COURONNES_VAPEUR: Array[float] = [0.4, 0.75]
const BOUFFEES: int = 6


func id() -> String:
	return ElementsArmes.GUILLOTINE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"arc_lame": Vector2i(12, 32), "vapeur": Vector2i(16, 16)}


func onde(m: AttaquesElementaires, centre: Vector2, age: float) -> bool:
	var cree: bool = m.front("arc_lame", centre, RAYON_PX, VITESSE_PX, LAMES, age, Color.WHITE)
	for fraction: float in COURONNES_VAPEUR:
		for k: int in BOUFFEES:
			var bouffee: Dictionary = m.nouveau(
				"nuage", "vapeur", AttaquesElementaires.IMAGES_NUAGE * AttaquesElementaires.IMAGE
			)
			if bouffee.is_empty():
				return cree
			var angle: float = TAU * (k + fraction) / BOUFFEES
			bouffee["depart"] = centre + Vector2.from_angle(angle) * RAYON_PX * fraction
			# La bouffée naît quand le front passe sur elle.
			bouffee["age"] = age - RAYON_PX * fraction / VITESSE_PX
			bouffee["couleur"] = Color.WHITE
			m.poser(bouffee)
			cree = true
	return cree
