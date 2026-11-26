class_name AttaqueSablier
extends AttaqueMine
## Sablier fêlé (piège) : un sablier d'or et de verre, lancé en cloche, se pose sur le chemin et
## laisse couler son sable tant qu'il attend ; au déclenchement un tourbillon de sable d'or et de
## violet s'ouvre, dessiné exactement au rayon du piège.

const CONF: Dictionary = {
	"couleur": Color(1.0, 0.82, 0.29),
	"projectile": "sablier",
	"cloche": 0.3,
	"fps": 4.0,
	"tour": TAU,
}
const ECHELLE_SABLIER: float = 2.0
const GRAINS: int = 6
const COULEUR_VIOLET := Color(0.54, 0.25, 0.82)


func id() -> String:
	return ElementsArmes.SABLIER


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"sablier": Vector2i(10, 16), "tourbillon_sable": Vector2i(32, 32)}


func visibles() -> Dictionary:
	return {"tourbillon_sable": 30.0}


func piege(m: AttaquesElementaires, depart: Vector2, arrivee: Vector2) -> bool:
	return lancer_et_poser(
		m, "sablier", depart, arrivee, CONF["cloche"], ECHELLE_SABLIER, CONF["fps"], CONF["tour"]
	)


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = exploser(m, "tourbillon_sable", ou, rayon_px, fort, age, CONF["couleur"])
	m.salve(
		ou,
		GRAINS,
		CONF["couleur"],
		18.0 * AttaquesElementaires.IMAGE,
		40.0,
		120.0,
		Vector2.ZERO,
		1.5
	)
	return cree
