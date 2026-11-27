class_name AttaqueEcrasement
extends AttaqueSiege
## Écrasement de tour (cible unique, étourdissement) : un morceau de créneau arraché au rempart,
## lancé en haute cloche avec son ombre ; à l'impact une onde de choc petite sur la cible, des
## gravats, et le gel d'un coup de siège. Les étoiles d'étourdissement sont la marque d'`Effets`.

const COULEUR := Color(0.72, 0.68, 0.62)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "creneau",
	"cloche": 0.5,
	"fps": 0.0,
	"tour": 0.0,
	"bosse": 0.1,
	"echelle": 1.3,
}
const GRAVATS: int = 9
const COULEUR_GRAVATS := Color(0.55, 0.5, 0.45)


func id() -> String:
	return ElementsArmes.ECRASEMENT


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"creneau": Vector2i(14, 14), "onde_choc": Vector2i(32, 32)}


func visibles() -> Dictionary:
	return {"onde_choc": 32.0}


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = coup_seul(m, "onde_choc", SEQ_ONDE, ou, fort, age, TEINTE_PIERRE)
	m.salve(ou, GRAVATS, COULEUR_GRAVATS, 0.4, 70.0, 190.0, Vector2(0.0, 300.0), 2.0)
	return cree
