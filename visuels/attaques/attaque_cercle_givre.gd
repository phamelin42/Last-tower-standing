class_name AttaqueCercleGivre
extends AttaqueElement
## Cercle de givre (aura) : rien ne part de la tour ; huit cristaux de glace tournent autour d'elle
## et s'écartent jusqu'au rayon réel en 7 images, du givre se pose au sol à ce rayon et un anneau
## fin le dit. Les planches sont celles de la glace.

const CONF: Dictionary = {
	"couleur": Color(0.75, 0.95, 1.0),
	"projectile": "",
	"cloche": 0.0,
	"fps": 0.0,
}
const CRISTAUX: int = 8
## Le cristal est tangent à la couronne : la moitié de sa hauteur (8 px de planche) dépasse du
## cercle des centres, qui est reculé d'autant pour que le bord extérieur soit au rayon.
const DEMI_EPAISSEUR: float = 4.0 * AttaquesElementaires.ECHELLE
const IMAGES_GIVRE: int = 24
const IMAGES_ANNEAU: int = 10
const FLOCONS: int = 6


func id() -> String:
	return ElementsArmes.CERCLE_GIVRE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"eclat_glace": Vector2i(20, 8), "givre_sol": Vector2i(32, 16)}


func visibles() -> Dictionary:
	return {"givre_sol": 31.0}


func aura(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	var couleur: Color = CONF["couleur"]
	var cree: bool = m.couronne(
		"eclat_glace", centre, maxf(rayon_px - DEMI_EPAISSEUR, 0.0), CRISTAUX, age, Color.WHITE
	)
	var diametre: float = rayon_px * 2.0
	var sol: Dictionary = m.nouveau("sol", "givre_sol", IMAGES_GIVRE * AttaquesElementaires.IMAGE)
	if not sol.is_empty():
		sol["age"] = age
		sol["depart"] = centre
		sol["diametre"] = diametre
		sol["echelle"] = diametre / float(visibles()["givre_sol"])
		m.poser(sol)
		cree = true
	cree = m.anneau_impact(centre, diametre, IMAGES_ANNEAU, age, couleur) or cree
	m.salve(
		centre, FLOCONS, couleur, 20.0 * AttaquesElementaires.IMAGE, 50.0, 120.0, Vector2.ZERO, 1.5
	)
	return cree
