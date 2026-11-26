class_name AttaqueMoulinet
extends AttaqueElement
## Moulinet de cuivre (aura) : rien ne part de la tour ; six lames de cuivre tournent autour d'elle
## et s'écartent jusqu'au rayon réel de l'aura en 7 images, puis s'effacent. Un anneau fin au
## rayon exact dit la zone touchée.

const CONF: Dictionary = {
	"couleur": Color(0.85, 0.52, 0.23),
	"projectile": "",
	"cloche": 0.0,
	"fps": 0.0,
}
const LAMES: int = 6
## La lame est tangente à la couronne : sa moitié d'épaisseur (8 px de planche) dépasse du cercle
## sur lequel elle tourne, donc le cercle des centres est reculé d'autant pour que le bord
## extérieur soit au rayon.
const DEMI_EPAISSEUR: float = 4.0 * AttaquesElementaires.ECHELLE
const IMAGES_ANNEAU: int = 10


func id() -> String:
	return ElementsArmes.MOULINET


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"lame_cuivre": Vector2i(16, 8)}


func aura(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	var cree: bool = m.couronne(
		"lame_cuivre", centre, maxf(rayon_px - DEMI_EPAISSEUR, 0.0), LAMES, age, Color.WHITE
	)
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, CONF["couleur"]) or cree
