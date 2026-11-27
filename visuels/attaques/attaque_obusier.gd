class_name AttaqueObusier
extends AttaqueSiege
## Obusier de brèche (bombe, vulnérabilité) : un obus file droit, le nez vers la cible, une fumée
## dans son sillage, et retombe où la vue pose la bombe. À l'explosion, après le délai de la
## simulation, le pop d'étincelles au rayon réel, un anneau, des débris et le gel d'un coup de
## siège. L'explosion est celle de l'élément : jamais celle du pack en plus ; la marque de
## vulnérabilité reste celle d'`Effets`.

const COULEUR := Color(0.9, 0.45, 0.3)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "obus",
	"cloche": 0.0,
}
const FUMEE: int = 4
const DEBRIS: int = 8
const ETINCELLES: int = 6
const COULEUR_FUMEE := Color(0.6, 0.6, 0.62)
const COULEUR_DEBRIS := Color(0.5, 0.45, 0.42)


func id() -> String:
	return ElementsArmes.OBUSIER


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, FUMEE, 12.0 * AttaquesElementaires.IMAGE, COULEUR_FUMEE, Vector2(0.0, -40.0))


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = frapper(m, "pop_petard", SEQ_POP, ou, rayon_px, fort, age, COULEUR)
	m.salve(ou, DEBRIS, COULEUR_DEBRIS, 0.4, 80.0, 200.0, Vector2(0.0, 300.0), 2.0)
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
