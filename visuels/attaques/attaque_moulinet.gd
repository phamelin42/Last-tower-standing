class_name AttaqueMoulinet
extends AttaqueElement
## Moulinet de cuivre (aura) : rien ne part de la tour ; six lames de cuivre tournent autour d'elle
## et s'écartent jusqu'au rayon réel de l'aura en 7 images, puis s'effacent. Un anneau fin au
## rayon exact dit la zone touchée.

const CONF: Dictionary = {
	"couleur": Color(0.85, 0.52, 0.23),
	"projectile": "",
	"cloche": 0.0,
}
const LAMES: int = 6
const IMAGES_ANNEAU: int = 10


## La lame est tangente à la couronne : sa moitié d'épaisseur dépasse du cercle
## sur lequel elle tourne, donc le cercle des centres est reculé d'autant pour que le bord
## extérieur soit au rayon.
## Ici : la moitié de l'épaisseur de la planche `lame_cuivre`, à l'écran.
static func demi_epaisseur() -> float:
	return float(AttaquesElementaires.planches()["lame_cuivre"].y) * 0.5 * PlanchesEffets.echelle()


func id() -> String:
	return ElementsArmes.MOULINET


func conf() -> Dictionary:
	return CONF


func aura(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	var cree: bool = m.couronne(
		"lame_cuivre", centre, maxf(rayon_px - demi_epaisseur(), 0.0), LAMES, age, Color.WHITE
	)
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, CONF["couleur"]) or cree
