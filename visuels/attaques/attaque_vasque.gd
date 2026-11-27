class_name AttaqueVasque
extends AttaqueElement
## Vasque d'arcanes (aura, siphon de mana) : rien ne part de la tour ; six vasques violettes
## tournent autour d'elle et s'écartent jusqu'au rayon réel en sept images, des volutes de siphon
## se resserrent dans la zone et un anneau fin dit la zone touchée. La marque de siphon reste celle
## d'`Effets`.

const COULEUR := Color(0.72, 0.5, 1.0)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"projectile": "",
	"cloche": 0.0,
	"fps": 0.0,
}
const VASQUES: int = 6
const VOLUTES: int = 4
## Les volutes se posent aux trois cinquièmes du rayon ; l'anneau de la planche se resserre : sa
## plus grande image est la première, donc le pic.
const PART_VOLUTES: float = 0.6
const IMAGE_PIC: int = 0
const SEQ_VOLUTE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 3, 3]
const DIAMETRE_VOLUTE: float = 36.0
const IMAGES_ANNEAU: int = 12


func id() -> String:
	return ElementsArmes.VASQUE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"vasque": Vector2i(14, 10), "eclat_siphon": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"eclat_siphon": 24.0}


func aura(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	# La vasque est tangente à la couronne : la moitié de sa hauteur dépasse du cercle des centres,
	# reculé d'autant (lue sur la planche, pas en dur).
	var demi: float = float(AttaquesElementaires.planches()["vasque"].y) * 0.5
	var recul: float = demi * AttaquesElementaires.ECHELLE
	var cree: bool = m.couronne(
		"vasque", centre, maxf(rayon_px - recul, 0.0), VASQUES, age, Color.WHITE
	)
	for k: int in VOLUTES:
		var angle: float = TAU * (k + 0.5) / VOLUTES
		var ou: Vector2 = centre + Vector2.from_angle(angle) * rayon_px * PART_VOLUTES
		var volute: Dictionary = m.image_impact(
			"eclat_siphon", ou, DIAMETRE_VOLUTE, SEQ_VOLUTE, age
		)
		cree = not volute.is_empty() or cree
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, COULEUR) or cree
