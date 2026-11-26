class_name CourbesEffets
extends RefCounted
## Les courbes d'animation d'un coup, en fonction de l'âge de l'effet (secondes) : apparition du
## projectile et des statuts, pic puis dissipation de l'impact, expansion de l'anneau. Pures : les
## mêmes âges donnent les mêmes valeurs, ce qui les rend testables sans nœud.

## Apparition du projectile : de la moitié à la pleine taille sur les 2 premières images.
const IMAGES_APPARITION_TIR: float = 2.0
const ECHELLE_DEPART_TIR: float = 0.5
## Apparition d'un statut : 0,5 vers 1,1 en 2 images, puis retour à 1 à la 3e.
const ECHELLE_DEPART_STATUT: float = 0.5
const ECHELLE_PIC_STATUT: float = 1.1
const IMAGES_PIC_STATUT: float = 2.0
const IMAGES_APPARITION_STATUT: float = 3.0
## Pic d'impact : échelle 0,5 vers 1,2, blanc mêlé à 60 % à l'image 0, couleur de l'arme à la 3.
const IMAGES_MONTEE_IMPACT: float = 3.0
const IMAGES_RETOUR_IMPACT: float = 6.0
const ECHELLE_DEPART_IMPACT: float = 0.5
const ECHELLE_PIC_IMPACT: float = 1.2
const ECHELLE_FIN_IMPACT: float = 1.15
const MELANGE_BLANC_IMPACT: float = 0.6
## Anneau : il atteint sa portée sur les 30 premiers % de sa vie, la tient jusqu'à 60 %, puis fond.
const ECHELLE_DEPART_ANNEAU: float = 0.1
const FIN_EXPANSION_ANNEAU: float = 0.3
const FIN_TENUE_ANNEAU: float = 0.6


## Sortie amortie : part vite, finit doucement.
static func sortie(t: float) -> float:
	var reste: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - reste * reste * reste


## Le projectile naît à moitié de sa taille et la prend en 2 images.
static func echelle_apparition_tir(age: float) -> float:
	return lerpf(ECHELLE_DEPART_TIR, 1.0, sortie(age / (IMAGES_APPARITION_TIR * Effets.IMAGE)))


## Un statut naît petit, dépasse un instant sa taille, puis la reprend (3 images en tout).
static func echelle_apparition_statut(age: float) -> float:
	var pic: float = IMAGES_PIC_STATUT * Effets.IMAGE
	if age < pic:
		return lerpf(ECHELLE_DEPART_STATUT, ECHELLE_PIC_STATUT, sortie(age / pic))
	var fin: float = IMAGES_APPARITION_STATUT * Effets.IMAGE
	if age < fin:
		return lerpf(ECHELLE_PIC_STATUT, 1.0, (age - pic) / (fin - pic))
	return 1.0


## Facteur de taille d'un impact : pic en 3 images, retour en 3, puis il gonfle en s'éteignant.
static func echelle_impact(age: float) -> float:
	var montee: float = IMAGES_MONTEE_IMPACT * Effets.IMAGE
	var retour: float = IMAGES_RETOUR_IMPACT * Effets.IMAGE
	if age < montee:
		return lerpf(ECHELLE_DEPART_IMPACT, ECHELLE_PIC_IMPACT, sortie(age / montee))
	if age < retour:
		return lerpf(ECHELLE_PIC_IMPACT, 1.0, sortie((age - montee) / (retour - montee)))
	var u: float = clampf((age - retour) / (Effets.DUREE_IMPACT - retour), 0.0, 1.0)
	return lerpf(1.0, ECHELLE_FIN_IMPACT, u)


## Part de blanc mêlée à la couleur de l'arme : 60 % à l'image 0, plus rien à la 3.
static func blanc_impact(age: float) -> float:
	return lerpf(
		MELANGE_BLANC_IMPACT, 0.0, clampf(age / (IMAGES_MONTEE_IMPACT * Effets.IMAGE), 0.0, 1.0)
	)


## Opaque jusqu'à l'image 6, puis entrée amortie (t²) vers la transparence.
static func alpha_impact(age: float) -> float:
	var retour: float = IMAGES_RETOUR_IMPACT * Effets.IMAGE
	if age < retour:
		return Effets.ALPHA_MAX
	var u: float = clampf((age - retour) / (Effets.DUREE_IMPACT - retour), 0.0, 1.0)
	return lerpf(Effets.ALPHA_MAX, 0.0, u * u)


## L'anneau atteint sa portée exacte sur le début de sa vie et la garde ensuite.
static func echelle_anneau(t: float) -> float:
	return lerpf(ECHELLE_DEPART_ANNEAU, 1.0, sortie(t / FIN_EXPANSION_ANNEAU))


static func alpha_anneau(t: float) -> float:
	if t < FIN_TENUE_ANNEAU:
		return Effets.ALPHA_MAX
	var u: float = (t - FIN_TENUE_ANNEAU) / (1.0 - FIN_TENUE_ANNEAU)
	return lerpf(Effets.ALPHA_MAX, 0.0, u * u)
