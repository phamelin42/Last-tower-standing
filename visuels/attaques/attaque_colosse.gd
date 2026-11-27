class_name AttaqueColosse
extends AttaqueSiege
## Colosse de pierre (cible unique, vulnérabilité puis étourdissement) : un rocher énorme aux yeux
## de forge, le plus gros projectile de siège, lancé en haute cloche avec son ombre ; à l'impact un
## cratère et une onde de choc, petits, des éclats de pierre et d'étincelles de forge, et le gel
## d'un coup de siège. Les marques de vulnérabilité et d'étourdissement sont celles d'`Effets`.

const COULEUR := Color(0.75, 0.62, 0.5)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "bloc_colosse",
	"cloche": 0.55,
	"fps": 0.0,
	"tour": 0.0,
	"bosse": 0.12,
	"echelle": 1.7,
}
const ECLATS: int = 22
const ETINCELLES: int = 4
const COULEUR_ECLATS := Color(0.5, 0.45, 0.4)
const COULEUR_FORGE := Color(1.0, 0.55, 0.2)


func id() -> String:
	return ElementsArmes.COLOSSE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {
		"bloc_colosse": Vector2i(18, 16),
		"cratere": Vector2i(32, 32),
		"onde_choc": Vector2i(32, 32),
	}


func visibles() -> Dictionary:
	return {"cratere": 30.0, "onde_choc": 32.0}


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = coup_seul(m, "cratere", SEQ_CRATERE, ou, fort, age, TEINTE_BRUN)
	cree = coup_seul(m, "onde_choc", SEQ_ONDE, ou, false, age, TEINTE_PIERRE) or cree
	m.salve(ou, ECLATS, COULEUR_ECLATS, 0.45, 80.0, 210.0, Vector2(0.0, 300.0), 2.0)
	m.salve(
		ou,
		ETINCELLES,
		COULEUR_FORGE,
		14.0 * AttaquesElementaires.IMAGE,
		60.0,
		150.0,
		Vector2.ZERO,
		1.5
	)
	return cree
