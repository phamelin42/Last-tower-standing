class_name AttaqueHache
extends AttaqueElement
## Hache de garde (aura, malédiction) : rien ne part de la tour ; quatre haches tournent autour
## d'elle et s'écartent jusqu'au rayon réel de l'aura en 7 images, puis s'effacent. Un anneau fin
## au rayon exact dit la zone touchée (la marque de malédiction reste celle d'`Effets`).

const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "",
	"cloche": 0.0,
	"fps": 0.0,
}
const HACHES: int = 4
const IMAGES_ANNEAU: int = 10


func id() -> String:
	return ElementsArmes.HACHE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"hache": Vector2i(14, 14)}


func aura(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	# La hache est tangente à la couronne : sa demi-hauteur dépasse du cercle sur lequel elle
	# tourne, donc le cercle des centres est reculé d'autant (lue sur la planche, pas en dur).
	var demi: float = float(AttaquesElementaires.planches()["hache"].y) * 0.5
	var recul: float = demi * AttaquesElementaires.ECHELLE
	var cree: bool = m.couronne(
		"hache", centre, maxf(rayon_px - recul, 0.0), HACHES, age, Color.WHITE
	)
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, CONF["couleur"]) or cree
