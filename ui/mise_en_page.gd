class_name MiseEnPage
extends RefCounted
## Calcul pur de la mise en page d'une partie : barre du HUD en haut, bandeau de la boutique en
## bas, arène visible au centre. Les panneaux modaux (scores, fin, pause) se centrent. Aucune
## dépendance aux nœuds : les tests le parcourent à plusieurs résolutions.

const MARGE := 8.0
## Le bandeau de la boutique ne dépasse jamais cette part de la hauteur : l'arène reste lisible.
const PART_MAX_BOUTIQUE := 0.45
const PART_MAX_HUD := 0.2


## Rectangles `hud`, `boutique` et `libre` (la zone d'arène visible entre les deux) pour une
## fenêtre de taille `zone`. Les hauteurs demandées sont celles du contenu.
static func calculer(zone: Vector2, hauteur_hud: float, hauteur_boutique: float) -> Dictionary:
	var h_hud := minf(hauteur_hud, zone.y * PART_MAX_HUD)
	var h_boutique := minf(hauteur_boutique, zone.y * PART_MAX_BOUTIQUE)
	var hud := Rect2(0.0, 0.0, zone.x, h_hud)
	var boutique := Rect2(0.0, zone.y - h_boutique, zone.x, h_boutique)
	var libre := Rect2(0.0, h_hud, zone.x, maxf(0.0, zone.y - h_hud - h_boutique))
	return {"hud": hud, "boutique": boutique, "libre": libre}


## Panneau centré dans `zone`, borné par une marge de chaque côté.
static func centrer(zone: Vector2, contenu: Vector2) -> Rect2:
	var taille := contenu.min(zone - Vector2(MARGE, MARGE) * 2.0).max(Vector2.ZERO)
	return Rect2((zone - taille) * 0.5, taille)
