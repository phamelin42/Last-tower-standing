class_name AttaqueCouronnePointes
extends AttaquePercante
## Couronne de pointes (aura, repoussement, vulnérabilité) : rien ne part de la tour ; huit pointes
## de fer tournent autour d'elle et s'écartent jusqu'au rayon réel de l'aura en sept images, des
## touffes de pointes jaillissent du sol à ce rayon et un anneau fin dit la zone touchée. Le trait
## de recul et la marque de vulnérabilité restent ceux d'`Effets`.

const CONF: Dictionary = {
	"couleur": COULEUR_ACIER,
	"projectile": "",
	"cloche": 0.0,
	"fps": 0.0,
}
const POINTES: int = 8
const DIAMETRE_POINTES: float = 36.0
const IMAGES_ANNEAU: int = 10
## Les touffes sortent quand la couronne est presque ouverte.
const IMAGES_RETARD_POINTES: int = 5
const SEQ_POINTES: Array[int] = [0, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5, 5, 5, 5]
const ECLATS: int = 4


func id() -> String:
	return ElementsArmes.COURONNE_POINTES


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"chausse_trape": Vector2i(12, 12), "pointes_sol": Vector2i(32, 32)}


func visibles() -> Dictionary:
	return {"pointes_sol": 28.0}


func aura(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	# La pointe est tangente à la couronne : sa demi-hauteur dépasse du cercle sur lequel elle
	# tourne, donc le cercle des centres est reculé d'autant (lue sur la planche, pas en dur).
	var demi: float = float(AttaquesElementaires.planches()["chausse_trape"].y) * 0.5
	var recul: float = demi * AttaquesElementaires.ECHELLE
	var cree: bool = m.couronne(
		"chausse_trape", centre, maxf(rayon_px - recul, 0.0), POINTES, age, Color.WHITE
	)
	var bord: float = maxf(rayon_px - DIAMETRE_POINTES * 0.5, 0.0)
	for k: int in POINTES:
		var angle: float = TAU * (k + 0.5) / POINTES
		var touffe: Dictionary = m.image_impact(
			"pointes_sol",
			centre + Vector2.from_angle(angle) * bord,
			DIAMETRE_POINTES,
			SEQ_POINTES,
			age - IMAGES_RETARD_POINTES * AttaquesElementaires.IMAGE
		)
		cree = not touffe.is_empty() or cree
	cree = m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, COULEUR_ACIER) or cree
	eclats(m, centre, ECLATS, COULEUR_ACIER)
	return cree
