class_name AttaqueMaillet
extends AttaqueSiege
## Maillet de rempart (zone) : le maillet de pierre tourne sur lui-même, lancé en cloche, son ombre
## sur la ligne droite ; à l'impact une onde de choc de poussière s'élargit jusqu'au rayon réel, un
## anneau fin la borne, de la poussière retombe, et le coup de siège gèle l'image.

const COULEUR := Color(0.78, 0.7, 0.58)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "maillet",
	"cloche": 0.5,
	"fps": 0.0,
	"tour": TAU,
	"bosse": 0.1,
	"echelle": 1.3,
}
const POUSSIERE: int = 10
const COULEUR_POUSSIERE := Color(0.62, 0.56, 0.48)


func id() -> String:
	return ElementsArmes.MAILLET


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"maillet": Vector2i(16, 14), "onde_choc": Vector2i(32, 32)}


func visibles() -> Dictionary:
	return {"onde_choc": 32.0}


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = frapper(m, "onde_choc", SEQ_ONDE, ou, rayon_px, fort, age, COULEUR)
	m.salve(ou, POUSSIERE, COULEUR_POUSSIERE, 0.45, 60.0, 180.0, Vector2(0.0, 200.0), 2.0)
	return cree
