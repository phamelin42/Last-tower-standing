class_name AttaqueChaos
extends AttaqueElement
## Ce que partagent les armes de chaos du lot 9 (D22) : les séquences d'images d'un impact (pic
## dans le premier quart), un petit effet qui se joue à l'arrivée d'un projectile (l'apparition d'un
## allié), quelques éclats. Ce n'est pas un élément : chaque arme a le sien, qui l'étend. Les
## planches carrées d'impact et d'apparition donnent leur géométrie par `GeometriePlanches` ; les
## planches de projectile du lot 9 gardent la taille déclarée ici, comme celles des autres armes.

const VIOLET := Color(0.76, 0.38, 0.95)
const MAGENTA := Color(1.0, 0.35, 0.78)
const OR := Color(1.0, 0.82, 0.29)
const VERRE := Color(0.85, 0.95, 1.0)
## Les quatre images d'une planche d'impact : flash, montée, pic (la 3e), dissipation.
const SEQ_IMPACT: Array[int] = [0, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3]
## Une planche qui se resserre : sa plus grande image est la première.
const SEQ_RESSERRE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 3, 3]
const IMAGES_ANNEAU: int = 12
const ECLATS: int = 3


## Les tailles d'image des planches carrées `noms`, lues sur les fichiers.
func cases(noms: Array[String]) -> Dictionary:
	var rendu: Dictionary = {}
	for nom: String in noms:
		rendu[nom] = GeometriePlanches.case_de(nom)
	return rendu


## Le diamètre visible des planches carrées `noms`, mesuré sur les fichiers.
func mesures(noms: Array[String]) -> Dictionary:
	var rendu: Dictionary = {}
	for nom: String in noms:
		rendu[nom] = GeometriePlanches.visible_de(nom)
	return rendu


## Joue `planche` en `seq` à `diametre` ; vrai si l'effet existe.
func jouer(
	m: AttaquesElementaires,
	planche: String,
	ou: Vector2,
	diametre: float,
	seq: Array[int],
	age: float
) -> bool:
	return not m.image_impact(planche, ou, diametre, seq, age).is_empty()


## Quelques carrés qui retombent, de `couleur` ; rien en mouvement réduit.
func eclats(m: AttaquesElementaires, ou: Vector2, nombre: int, couleur: Color) -> void:
	m.salve(
		ou,
		nombre,
		couleur,
		14.0 * AttaquesElementaires.IMAGE,
		40.0,
		120.0,
		Vector2(0.0, 150.0),
		1.5
	)


## Fait apparaître `planche` à l'arrivée du projectile `vol` (là où l'allié se pose), sans attendre
## un événement : l'impact en retard naît avec un âge négatif, caché jusqu'à l'arrivée.
func apparaitre(
	m: AttaquesElementaires,
	vol: Dictionary,
	attente: float,
	duree_vol: float,
	planche: String,
	diametre: float
) -> void:
	var ou: Vector2 = vol["arrivee"]
	m.image_impact(planche, ou, diametre, SEQ_IMPACT, -(attente + duree_vol))
