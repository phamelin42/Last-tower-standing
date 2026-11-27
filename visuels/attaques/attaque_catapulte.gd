class_name AttaqueCatapulte
extends AttaqueSiege
## Catapulte à contrepoids (cible unique) : une pierre lestée, lancée en haute cloche, son ombre
## sur la ligne droite ; à l'impact un cratère de poussière petit sur la cible, des éclats de
## pierre, et le gel d'un coup de siège.

const COULEUR := Color(0.7, 0.64, 0.56)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "pierre_lestee",
	"cloche": 0.5,
	"fps": 0.0,
	"tour": 0.0,
	"bosse": 0.1,
	"echelle": 1.3,
}
const ECLATS: int = 8
const COULEUR_ECLATS := Color(0.5, 0.45, 0.4)


func id() -> String:
	return ElementsArmes.CATAPULTE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"pierre_lestee": Vector2i(14, 12), "cratere": Vector2i(32, 32)}


func visibles() -> Dictionary:
	return {"cratere": 30.0}


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = frapper(m, "cratere", SEQ_CRATERE, ou, rayon_px, fort, age, COULEUR)
	m.salve(ou, ECLATS, COULEUR_ECLATS, 0.4, 70.0, 180.0, Vector2(0.0, 300.0), 2.0)
	return cree
