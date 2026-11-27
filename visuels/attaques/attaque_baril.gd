class_name AttaqueBaril
extends AttaqueSiege
## Baril à retardement (bombe) : un baril de poudre tourne sur un vol en cloche, son ombre au sol,
## une étincelle à la mèche ; il retombe où la vue pose la bombe. À l'explosion, qui n'arrive
## qu'après le délai de la simulation, le feu du baril au rayon réel, un anneau, des débris et le
## gel d'un coup de siège. L'explosion est celle de l'élément : jamais celle du pack en plus.

const COULEUR := Color(0.85, 0.5, 0.2)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "baril",
	"cloche": 0.35,
	"tour": PI,
	"bosse": 0.1,
	"echelle": 1.2,
}
const DEBRIS: int = 10
const COULEUR_DEBRIS := Color(0.5, 0.4, 0.3)
const ETINCELLES: int = 3


func id() -> String:
	return ElementsArmes.BARIL


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(
		vol, ETINCELLES, 8.0 * AttaquesElementaires.IMAGE, Color(1.0, 0.89, 0.15), Vector2.ZERO
	)


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = frapper(m, "explosion_feu", SEQ_FEU, ou, rayon_px, fort, age, COULEUR)
	m.salve(ou, DEBRIS, COULEUR_DEBRIS, 0.4, 80.0, 200.0, Vector2(0.0, 300.0), 2.0)
	return cree
