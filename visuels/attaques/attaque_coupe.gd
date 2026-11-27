class_name AttaqueCoupe
extends AttaqueChaos
## Coupe d'oubli (aura, siphon de vie) : rien ne part de la tour ; cinq coupes violettes tournent
## autour d'elle et s'écartent jusqu'au rayon réel en sept images, des anneaux d'aspiration se
## resserrent dans la zone, des gouttes magenta en montent, et un anneau fin dit la zone touchée.
## La marque de siphon reste celle d'`Effets`.

const CONF: Dictionary = {
	"couleur": VIOLET,
	"projectile": "",
	"cloche": 0.0,
}
const COUPES: int = 5
const VOLUTES: int = 4
## Les volutes se posent aux trois cinquièmes du rayon.
const PART_VOLUTES: float = 0.6
const DIAMETRE_VOLUTE: float = 56.0


func id() -> String:
	return ElementsArmes.COUPE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return cases(["volute_oubli"]).merged(super.planches())


func visibles() -> Dictionary:
	return mesures(["volute_oubli"]).merged(super.visibles())


func aura(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	# La coupe est tangente à la couronne : la moitié de sa hauteur dépasse du cercle des centres,
	# reculé d'autant (lue sur la planche, pas en dur).
	var demi: float = float(AttaquesElementaires.planches()["coupe"].y) * 0.5
	var recul: float = demi * PlanchesEffets.echelle()
	var cree: bool = m.couronne(
		"coupe", centre, maxf(rayon_px - recul, 0.0), COUPES, age, Color.WHITE
	)
	for k: int in VOLUTES:
		var angle: float = TAU * (k + 0.5) / VOLUTES
		var ou: Vector2 = centre + Vector2.from_angle(angle) * rayon_px * PART_VOLUTES
		cree = jouer(m, "volute_oubli", ou, DIAMETRE_VOLUTE, SEQ_RESSERRE, age) or cree
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, MAGENTA) or cree
