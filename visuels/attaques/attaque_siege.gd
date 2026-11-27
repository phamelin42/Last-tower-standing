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
## Le premier éclat d'un coup sur une cible seule : deux images au pic, claires.
const IMAGES_ECLAT: int = 2
const TEINTE_ECLAT := Color(1.0, 0.97, 0.88)
## Brun foncé et gris pierre, qui se lisent sur l'herbe là où le beige des planches s'y perd.
const TEINTE_BRUN := Color(0.5, 0.35, 0.25)
const TEINTE_PIERRE := Color(0.45, 0.47, 0.52)


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


## Le coup sur une cible seule (au plus `DIAMETRE_CIBLE_UNIQUE`) : `planche` jouée en `seq`, teintée
## de `sombre` pour se lire sur l'herbe, un premier éclat clair au pic de la planche, et le gel.
func coup_seul(
	m: AttaquesElementaires,
	planche: String,
	seq: Array[int],
	ou: Vector2,
	fort: bool,
	age: float,
	sombre: Color
) -> bool:
	var corps: Dictionary = m.image_impact(planche, ou, DIAMETRE_CIBLE_UNIQUE, seq, age)
	if corps.is_empty():
		return false
	corps["couleur"] = sombre
	m.poser(corps)
	if fort:
		m.geler(corps, age, AttaquesElementaires.IMAGES_MONTEE_IMPACT * AttaquesElementaires.IMAGE)
	var pic: Array[int] = []
	pic.resize(IMAGES_ECLAT)
	pic.fill(seq[IMAGES_ECLAT])
	var eclat: Dictionary = m.image_impact(planche, ou, DIAMETRE_CIBLE_UNIQUE, pic, age)
	if not eclat.is_empty():
		eclat["couleur"] = TEINTE_ECLAT
		m.poser(eclat)
	return true


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
