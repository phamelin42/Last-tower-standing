class_name AttaquePoison
extends AttaqueElement
## Poison (cornue instable) : une fiole qui fait 1,5 tour sur un vol en cloche ; à l'impact
## l'éclaboussure au rayon, puis trois nuages qui montent et s'effacent en 36 images.

const CONF: Dictionary = {
	"couleur": Color(0.45, 0.85, 0.35),
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "fiole",
	"cloche": 0.25,
	"tour": 3.0 * PI,
}
const NUAGES: int = 3


func id() -> String:
	return ElementsArmes.POISON


func conf() -> Dictionary:
	return CONF


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var zone: bool = rayon_px > 0.0
	var diametre: float = rayon_px * 2.0 if zone else AttaquesElementaires.DIAMETRE_PETIT
	var couleur: Color = CONF["couleur"]
	var cree: bool = not (
		m
		. image_impact("eclaboussure_poison", ou, diametre, AttaquesElementaires.SEQ_EXPLOSION, age)
		. is_empty()
	)
	for k: int in NUAGES:
		var nuage: Dictionary = m.nouveau(
			"nuage", "nuage_poison", AttaquesElementaires.IMAGES_NUAGE * AttaquesElementaires.IMAGE
		)
		if nuage.is_empty():
			break
		var angle: float = TAU * k / NUAGES
		nuage["age"] = age
		nuage["depart"] = ou + Vector2.from_angle(angle) * diametre * 0.2
		nuage["couleur"] = couleur
		m.poser(nuage)
		cree = true
	m.salve(
		ou, 6, couleur, 25.0 * AttaquesElementaires.IMAGE, 40.0, 120.0, Vector2(0.0, 200.0), 1.5
	)
	return cree
