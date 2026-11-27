class_name ContoursPoses
extends Node2D
## Le contour fin des zones posées et des souffles de bombe, tracé au-dessus des ennemis. Le tapis
## au sol (`ZonesBombes2D`) reste sous eux : dans une foule de 700 ennemis il n'en laisse voir que
## 16 à 33 % au pic. Ce trait, sans remplissage, dit la zone touchée au rayon exact sans cacher la
## teinte de statut des ennemis. C'est une information de jeu : il reste en mouvement réduit, et ne
## pulse jamais. Il n'est pas dans le pool d'`Effets` (donc hors de son plafond de 200) : ses
## cercles sont ceux, bornés (`VueArene.ZONES_MAX`, `BOMBES_MAX`), de la vue.

## Épaisseur à l'écran, en pixels : assez pour se suivre à l'œil, trop fine pour couvrir un ennemi
## (un sprite en fait 30 à 60 au zoom de jeu).
const EPAISSEUR_ECRAN: float = 2.0
const POINTS_CERCLE: int = 96
## Tracé au-dessus des ennemis (z 0) et sous les particules d'effets (z 1, plus loin dans l'arbre).
const COUCHE: int = 1
## Éclaircissement du trait : une teinte de zone, pas un autre ton, mais lisible sur des sprites
## sombres (le chaos et le magique, violets, se perdaient dans la foule).
const CLAIR: float = 0.35


func _init() -> void:
	name = "Contours"
	z_index = COUCHE


## Les cercles à tracer : `{centre, rayon, couleur, alpha, epaisseur}`, en pixels du monde.
func cercles() -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	var poses: ZonesBombes2D = get_parent() as ZonesBombes2D
	if poses == null:
		return liste
	var epaisseur: float = EPAISSEUR_ECRAN / _zoom()
	for i: int in poses.nombre_zones():
		var alpha: float = poses.opacite_zone(i) / ZonesBombes2D.OPACITE_ZONE
		if alpha > 0.0:
			(
				liste
				. append(
					{
						"centre": poses.position_zone(i),
						"rayon": poses.rayon_zone(i),
						"couleur": poses.couleur_zone(i),
						"alpha": alpha * AttaquesElementaires.ALPHA_MAX,
						"epaisseur": epaisseur,
					}
				)
			)
	for i: int in poses.nombre_bombes():
		if not poses.bombe_en_vol(i):
			(
				liste
				. append(
					{
						"centre": poses.position_bombe(i),
						"rayon": poses.rayon_bombe(i),
						"couleur": ZonesBombes2D.COULEUR_SOUFFLE,
						"alpha": AttaquesElementaires.ALPHA_MAX,
						"epaisseur": epaisseur,
					}
				)
			)
	return liste


func _draw() -> void:
	for cercle: Dictionary in cercles():
		draw_arc(
			cercle["centre"],
			float(cercle["rayon"]),
			0.0,
			TAU,
			POINTS_CERCLE,
			Color((cercle["couleur"] as Color).lightened(CLAIR), float(cercle["alpha"])),
			float(cercle["epaisseur"])
		)


## Le grossissement de la caméra : l'épaisseur est donnée à l'écran, pas dans le monde.
func _zoom() -> float:
	if not is_inside_tree():
		return 1.0
	return maxf(get_canvas_transform().get_scale().x, 0.01)
