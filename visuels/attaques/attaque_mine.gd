class_name AttaqueMine
extends AttaqueElement
## Ce que partagent les mines (pétard de rempart, mine de forge) et le sablier fêlé, piège du même
## genre : l'objet est lancé de la tour en cloche, retombe sur le chemin et reste posé, visible,
## jusqu'au déclenchement (`AttaquesElementaires.retirer_pieges`) ; à l'explosion le pop est dessiné
## au rayon réel avec un anneau (et le gel d'un coup de siège pour une arme de siège). Ce n'est pas
## un élément : chaque objet posé a le sien, qui l'étend.

const IMAGES_ANNEAU: int = 14
const SEQ_POP: Array[int] = [0, 1, 2, 2, 3, 3, 4, 4, 4, 5, 5, 5]


## Lance l'objet de la planche `planche` de `depart` vers `arrivee` et l'y pose. `echelle` : sa
## taille affichée par rapport à la planche ; `fps` : l'animation de l'objet posé (0 sans) ; `tour`
## : sa rotation sur le vol, en radians.
func lancer_et_poser(
	m: AttaquesElementaires,
	planche: String,
	depart: Vector2,
	arrivee: Vector2,
	cloche: float,
	echelle: float,
	fps: float,
	tour: float
) -> bool:
	var vol: float = AttaquesElementaires.IMAGES_VOL_CLOCHE * AttaquesElementaires.IMAGE
	var lance: Dictionary = m.nouveau("vol", planche, vol)
	if lance.is_empty():
		return false
	lance["depart"] = depart
	lance["arrivee"] = arrivee
	lance["couleur"] = Color.WHITE
	lance["echelle"] = echelle
	lance["cloche"] = cloche
	lance["tour"] = tour
	lance["vol"] = vol
	m.poser(lance)
	var pose: Dictionary = m.nouveau("piege", planche, AttaquesElementaires.DUREE_PIEGE)
	if pose.is_empty():
		return true
	pose["age"] = -vol
	pose["depart"] = arrivee
	pose["arrivee"] = arrivee
	pose["couleur"] = Color.WHITE
	pose["echelle"] = echelle
	pose["fps"] = fps
	m.poser(pose)
	return true


## Le pop de la planche `planche` au rayon réel, l'anneau, et le gel d'un coup de siège.
func exploser(
	m: AttaquesElementaires,
	planche: String,
	ou: Vector2,
	rayon_px: float,
	fort: bool,
	age: float,
	couleur: Color
) -> bool:
	var diametre: float = rayon_px * 2.0 if rayon_px > 0.0 else AttaquesElementaires.DIAMETRE_PETIT
	var pop: Dictionary = m.image_impact(planche, ou, diametre, SEQ_POP, age)
	var cree: bool = not pop.is_empty()
	if cree and fort:
		m.geler(pop, age, AttaquesElementaires.IMAGES_MONTEE_IMPACT * AttaquesElementaires.IMAGE)
	if rayon_px > 0.0:
		cree = m.anneau_impact(ou, diametre, IMAGES_ANNEAU, age, couleur) or cree
	return cree
