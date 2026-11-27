class_name AttaqueSablier
extends AttaqueMine
## Sablier fêlé (piège) : un sablier d'or et de verre, lancé en cloche, se pose sur le chemin et
## laisse couler son sable tant qu'il attend ; au déclenchement un tourbillon de sable d'or et de
## violet s'ouvre, dessiné exactement au rayon du piège.

const CONF: Dictionary = {
	"couleur": Color(1.0, 0.82, 0.29),
	"projectile": "sablier",
	"cloche": 0.3,
	"tour": TAU,
}
const ECHELLE_SABLIER: float = 2.0
const GRAINS: int = 6
const COULEUR_VIOLET := Color(0.54, 0.25, 0.82)


func id() -> String:
	return ElementsArmes.SABLIER


func conf() -> Dictionary:
	return CONF


func piege(m: AttaquesElementaires, depart: Vector2, arrivee: Vector2) -> bool:
	return lancer_et_poser(
		m,
		"sablier",
		depart,
		arrivee,
		CONF["cloche"],
		ECHELLE_SABLIER,
		PlanchesEffets.cadence_de("sablier"),
		CONF["tour"]
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
