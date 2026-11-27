class_name AttaqueMineForge
extends AttaqueMine
## Mine de forge (mine) : une mine de fer à rune rougeoyante, lancée en cloche, reste posée sur le
## chemin, sa rune pulsant ; au déclenchement l'explosion est celle du pack, dessinée par `Effets`
## au rayon réel, que l'anneau et des éclats de fer accompagnent.

const CONF: Dictionary = {
	"couleur": Color(1.0, 0.48, 0.23),
	"projectile": "mine_forge",
	"cloche": 0.2,
	"tour": PI,
	"explosion": true,
}
const ECHELLE_MINE: float = 2.5
const DEBRIS: int = 10


func id() -> String:
	return ElementsArmes.MINE_FORGE


func conf() -> Dictionary:
	return CONF


func piege(m: AttaquesElementaires, depart: Vector2, arrivee: Vector2) -> bool:
	return lancer_et_poser(
		m,
		"mine_forge",
		depart,
		arrivee,
		CONF["cloche"],
		ECHELLE_MINE,
		PlanchesEffets.cadence_de("mine_forge"),
		CONF["tour"]
	)


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = false
	if rayon_px > 0.0:
		cree = m.anneau_impact(ou, rayon_px * 2.0, IMAGES_ANNEAU, age, CONF["couleur"])
	return (
		m.salve(ou, DEBRIS, Color(0.49, 0.52, 0.6), 0.4, 80.0, 200.0, Vector2(0.0, 300.0), 2.0)
		or cree
	)
