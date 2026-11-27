class_name AttaqueMurPointes
extends AttaquePercante
## Mur de pointes (zone, repoussement) : un pieu teinté de vert file droit vers la cible ; à
## l'impact une haie de pieux surgit en sept images et s'écarte du centre jusqu'au rayon réel de
## la zone, des touffes de pointes se dressent au bord pendant dix-huit images et un anneau fin dit
## la zone exacte. Le trait de recul reste celui d'`Effets`.

const TEINTE := Color(0.8, 1.0, 0.8)
const COULEUR_HAIE := Color(0.55, 0.78, 0.45)
const CONF: Dictionary = {
	"couleur": COULEUR_HAIE,
	"projectile": "pique",
	"cloche": 0.0,
	"teinte": TEINTE,
}
const PIQUES: int = 12
const TOUFFES: int = 10
## La haie sort en sept images, comme la couronne d'une aura.
const IMAGES_SURGISSEMENT: int = 7
const DIAMETRE_POINTES: float = 36.0
const IMAGES_ANNEAU: int = 18
const SEQ_POINTES: Array[int] = [0, 1, 2, 2, 2, 3, 3, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5]
const ECLATS: int = 4


func id() -> String:
	return ElementsArmes.MUR_POINTES


func conf() -> Dictionary:
	return CONF


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var rayon: float = rayon_px if rayon_px > 0.0 else AttaquesElementaires.DIAMETRE_PETIT * 0.5
	# Le pieu regarde vers l'extérieur : sa pointe, et non son centre, s'arrête au rayon réel ; la
	# demi-longueur se lit sur la planche.
	var demi: float = float(AttaquesElementaires.planches()["pique"].x) * 0.5
	var arret: float = maxf(rayon - demi * PlanchesEffets.echelle(), 0.0)
	var vitesse: float = arret / (IMAGES_SURGISSEMENT * AttaquesElementaires.IMAGE)
	var cree: bool = m.front("pique", ou, arret, vitesse, PIQUES, age, TEINTE)
	var bord: float = maxf(rayon - DIAMETRE_POINTES * 0.5, 0.0)
	for k: int in TOUFFES:
		var angle: float = TAU * (k + 0.5) / TOUFFES
		var touffe: Dictionary = m.image_impact(
			"pointes_sol",
			ou + Vector2.from_angle(angle) * bord,
			DIAMETRE_POINTES,
			SEQ_POINTES,
			age - IMAGES_SURGISSEMENT * AttaquesElementaires.IMAGE
		)
		cree = not touffe.is_empty() or cree
	cree = m.anneau_impact(ou, rayon * 2.0, IMAGES_ANNEAU, age, COULEUR_HAIE) or cree
	eclats(m, ou, ECLATS, COULEUR_HAIE)
	return cree
