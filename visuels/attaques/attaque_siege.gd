class_name AttaqueSiege
extends AttaqueElement
## Ce que partagent les armes de siège du lot 9 (bombes, zones, zones posées, coups sur une cible) :
## l'impact d'un coup de siège (la planche jouée au rayon réel, un anneau fin au rayon exact, le gel
## visuel du coup fort) et l'impulsion d'une zone posée (un cœur petit et le même anneau, sans gel :
## la zone, elle, reste dessinée depuis la vue). Ce n'est pas un élément : chaque arme a le sien,
## qui l'étend.

const IMAGES_ANNEAU: int = 14
## Un coup sur une cible seule, et une impulsion de zone posée : petits, la zone est dans l'anneau.
const DIAMETRE_CIBLE_UNIQUE: float = 48.0
const DIAMETRE_IMPULSION: float = 64.0
## L'image de planche à chaque image à 60 i/s ; le pic est atteint dans le premier quart.
const SEQ_FEU: Array[int] = [0, 1, 2, 2, 3, 3, 4, 4, 4, 5, 5, 5]
const SEQ_POP: Array[int] = [0, 1, 3, 3, 3, 4, 4, 4, 5, 5, 5, 5]
const SEQ_CRATERE: Array[int] = [0, 1, 3, 3, 4, 4, 4, 5, 5, 5, 5, 5]
const SEQ_ONDE: Array[int] = [0, 1, 2, 3, 3, 3, 4, 4, 4, 4, 4, 4]


## Le coup de siège : `planche` jouée en `seq` au rayon réel (`DIAMETRE_CIBLE_UNIQUE` sans rayon),
## l'anneau fin de `couleur` au rayon exact, et le gel d'impact si le coup est fort.
func frapper(
	m: AttaquesElementaires,
	planche: String,
	seq: Array[int],
	ou: Vector2,
	rayon_px: float,
	fort: bool,
	age: float,
	couleur: Color
) -> bool:
	var diametre: float = rayon_px * 2.0 if rayon_px > 0.0 else DIAMETRE_CIBLE_UNIQUE
	var image: Dictionary = m.image_impact(planche, ou, diametre, seq, age)
	var cree: bool = not image.is_empty()
	if cree and fort:
		m.geler(image, age, AttaquesElementaires.IMAGES_MONTEE_IMPACT * AttaquesElementaires.IMAGE)
	if rayon_px > 0.0:
		cree = m.anneau_impact(ou, diametre, IMAGES_ANNEAU, age, couleur) or cree
	return cree


## Une impulsion de zone posée : un cœur petit de `planche` au centre et l'anneau fin au rayon
## réel, jamais de gel (c'est un tic, pas un coup).
func pulser(
	m: AttaquesElementaires,
	planche: String,
	seq: Array[int],
	ou: Vector2,
	rayon_px: float,
	age: float,
	couleur: Color
) -> bool:
	var coeur: Dictionary = m.image_impact(planche, ou, DIAMETRE_IMPULSION, seq, age)
	var cree: bool = not coeur.is_empty()
	if rayon_px > 0.0:
		cree = m.anneau_impact(ou, rayon_px * 2.0, IMAGES_ANNEAU, age, couleur) or cree
	return cree
