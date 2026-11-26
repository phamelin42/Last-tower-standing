class_name AttaqueArcane
extends AttaqueElement
## Arcane (étincelle runique) : une rune qui tourne, deux points en orbite et trois points bleus ;
## à l'impact un éclat de rune, petit : une cible unique n'a plus de disque de 70 px.

const SEQ_RUNE: Array[int] = [0, 1, 3, 3, 3, 4, 4, 4, 4]
const CONF: Dictionary = {
	"couleur": Color(0.5, 0.75, 1.0),
	"projectile": "rune",
	"cloche": 0.0,
	"fps": 12.0,
	"echelle": 1.5,
}
## Deux points tournent autour de la rune.
const POINTS: int = 2
## La rune et son éclat s'affichent 1,5 fois plus grands (ils étaient 36 px) : un coup à cible
## unique reste sous 60 px.
const DIAMETRE_RUNE: float = 54.0


func id() -> String:
	return ElementsArmes.ARCANE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"rune": Vector2i(12, 12), "eclat_rune": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"eclat_rune": 24.0}


func suivre_vol(m: AttaquesElementaires, vol: Dictionary, attente: float, duree_vol: float) -> void:
	m.trainee(vol, 3, 10.0 * AttaquesElementaires.IMAGE, CONF["couleur"], Vector2.ZERO)
	for k: int in POINTS:
		var point: Dictionary = m.nouveau("orbite", "etincelle", duree_vol)
		if point.is_empty():
			return
		point["age"] = -attente
		point["depart"] = vol["depart"]
		point["arrivee"] = vol["arrivee"]
		point["vol"] = duree_vol
		point["tour"] = PI * k
		point["couleur"] = CONF["couleur"]
		m.poser(point)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var couleur: Color = CONF["couleur"]
	var cree: bool = not m.image_impact("eclat_rune", ou, DIAMETRE_RUNE, SEQ_RUNE, age).is_empty()
	m.salve(ou, 4, couleur, 15.0 * AttaquesElementaires.IMAGE, 50.0, 130.0, Vector2.ZERO, 1.5)
	return cree
