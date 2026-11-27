class_name AttaqueSalve
extends AttaqueSiege
## Salve du rempart (bombe, brûlure) : une bombe teintée de braise, lancée en cloche avec son ombre,
## retombe où la vue pose la bombe. À l'explosion, après le délai de la simulation, un grand pop au
## rayon réel entouré d'une salve de petits pops qui éclatent un à un à l'intérieur, un anneau, des
## braises et le gel d'un coup de siège. Une seule explosion : celle de l'élément.

const COULEUR := Color(1.0, 0.55, 0.25)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "bombe",
	"cloche": 0.35,
	"fps": 8.0,
	"tour": PI,
	"bosse": 0.15,
	"echelle": 1.2,
	"teinte": Color(1.0, 0.8, 0.65),
}
## Les petits pops : leur nombre, leur place (fraction du rayon), leur taille (fraction du rayon) et
## le retard entre deux (images).
const POPS: int = 4
const PLACE_POP: float = 0.5
const TAILLE_POP: float = 0.45
const RETARD_POP: int = 2
const BRAISES: int = 14


func id() -> String:
	return ElementsArmes.SALVE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"bombe": Vector2i(12, 12), "pop_petard": Vector2i(32, 32)}


func visibles() -> Dictionary:
	return {"pop_petard": 30.0}


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = frapper(m, "pop_petard", SEQ_POP, ou, rayon_px, fort, age, COULEUR)
	if rayon_px > 0.0:
		for k: int in POPS:
			var angle: float = TAU * (k + 0.5) / POPS
			var place: Vector2 = ou + Vector2.from_angle(angle) * rayon_px * PLACE_POP
			var retard: float = (k + 1) * RETARD_POP * AttaquesElementaires.IMAGE
			var pop: Dictionary = m.image_impact(
				"pop_petard", place, rayon_px * TAILLE_POP, SEQ_POP, age - retard
			)
			cree = not pop.is_empty() or cree
	m.salve(
		ou,
		BRAISES,
		COULEUR,
		16.0 * AttaquesElementaires.IMAGE,
		50.0,
		150.0,
		Vector2(0.0, -80.0),
		1.5
	)
	return cree
