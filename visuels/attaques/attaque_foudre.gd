class_name AttaqueFoudre
extends AttaqueElement
## Foudre (chaîne d'arcanes) : pas de vol, un éclair brisé tracé d'un coup de la source à la cible
## et une étincelle sur la cible.

const SEQ_ETINCELLE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const CONF: Dictionary = {
	"couleur": Color(0.78, 0.7, 1.0),
	"projectile": "",
	"cloche": 0.0,
	"fps": 0.0,
}


func id() -> String:
	return ElementsArmes.FOUDRE


func conf() -> Dictionary:
	return CONF


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, de: Vector2, age: float
) -> bool:
	var couleur: Color = CONF["couleur"]
	var cree: bool = m.eclair(de, ou, age, couleur)
	var etincelle: Dictionary = m.image_impact(
		"etincelle", ou, 8.0 * AttaquesElementaires.ECHELLE, SEQ_ETINCELLE, age
	)
	cree = cree or not etincelle.is_empty()
	m.salve(ou, 4, couleur, 12.0 * AttaquesElementaires.IMAGE, 60.0, 150.0, Vector2.ZERO, 1.5)
	return cree
