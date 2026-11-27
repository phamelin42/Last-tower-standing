class_name AttaquePetard
extends AttaqueMine
## Pétard de rempart (mine) : un pétard rouge, lancé en cloche, se pose sur le chemin ; sa mèche
## crépite tant qu'il attend, puis il pète en un pop d'étincelles au rayon de la mine.

const CONF: Dictionary = {
	"couleur": Color(0.82, 0.29, 0.26),
	"projectile": "petard",
	"cloche": 0.3,
	"tour": TAU,
}
const ECHELLE_PETARD: float = 2.0
const ETINCELLES: int = 8


func id() -> String:
	return ElementsArmes.PETARD


func conf() -> Dictionary:
	return CONF


func piege(m: AttaquesElementaires, depart: Vector2, arrivee: Vector2) -> bool:
	return lancer_et_poser(
		m,
		"petard",
		depart,
		arrivee,
		CONF["cloche"],
		ECHELLE_PETARD,
		PlanchesEffets.cadence_de("petard"),
		CONF["tour"]
	)


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = exploser(m, "pop_petard", ou, rayon_px, fort, age, CONF["couleur"])
	m.salve(
		ou,
		ETINCELLES,
		Color(1.0, 0.89, 0.15),
		14.0 * AttaquesElementaires.IMAGE,
		60.0,
		160.0,
		Vector2.ZERO,
		1.5
	)
	return cree
