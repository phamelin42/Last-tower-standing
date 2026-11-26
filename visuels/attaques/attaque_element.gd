class_name AttaqueElement
extends RefCounted
## L'interface d'un élément d'attaque (D22) : ce qui change d'un élément à l'autre, derrière un
## aiguilleur (`AttaquesElementaires`) qui garde le pool, le plafond, la limite d'éclats blancs et
## le mouvement. Un élément dit son identifiant, ses planches, sa fiche (`conf`), ce qui suit son
## projectile en vol et son impact, en créant ses effets par les primitives publiques du moteur
## (`nouveau`, `image_impact`, `anneau_impact`, `salve`, `trainee`…). Ajouter un élément : un
## fichier qui étend celui-ci, une ligne dans `AttaquesElementaires.ELEMENTS`, et son id dans
## `ElementsArmes`.


## L'identifiant (`ElementsArmes.FEU`…).
func id() -> String:
	return ""


## La fiche : `couleur`, `projectile` (planche, `""` sans projectile), `cloche` (hauteur du sommet
## en fraction de la distance, 0 en direct), `fps` (animation du projectile, 0 sans), et au besoin
## `anticipation` (couleur de la bouffée de départ), `tour` (rotation sur le vol, radians),
## `bosse` (grossissement au sommet), `fige_reduit` (vrai : l'animation d'images est un tour sur
## soi-même, figée en mouvement réduit), `vrille` (tours par seconde d'un projectile qui tourne sur
## lui-même, 0 sans) et `saut` (vrai : un projectile par saut d'un rebond).
func conf() -> Dictionary:
	return {}


## Taille d'une image des planches propres à cet élément, en pixels.
func planches() -> Dictionary:
	return {}


## Diamètre visible, en pixels de planche, de l'image la plus grande de chaque impact.
func visibles() -> Dictionary:
	return {}


## Ce qui accompagne le projectile `vol` : traînée, éclats qui suivent, points qui tournent.
## `attente` est le temps avant le départ, `duree_vol` celui du vol.
func suivre_vol(
	_m: AttaquesElementaires, _vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	pass


## Dessine l'impact en `ou` ; rend vrai si un effet a été créé. `rayon_px` : 0 pour une cible
## unique ; `fort` : coup de siège ; `de` : l'origine d'un éclair ; `age` : retard de l'impact.
func impacter(
	_m: AttaquesElementaires, _ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, _age: float
) -> bool:
	return false


## Un impact d'un barrage (plusieurs impacts d'un même tir, voir `zone`) : par défaut, un impact
## ordinaire.
func impacter_en_groupe(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, de: Vector2, age: float
) -> bool:
	return impacter(m, ou, rayon_px, fort, de, age)


## La zone d'un barrage, dessinée une seule fois, centrée en `centre` (le point d'impact moyen),
## au rayon réel `rayon_px` ; par défaut rien.
func zone(_m: AttaquesElementaires, _centre: Vector2, _rayon_px: float, _age: float) -> bool:
	return false


## Une aura : une couronne qui naît de la tour (`centre`) et s'étend jusqu'au rayon réel
## `rayon_px` ; par défaut rien.
func aura(_m: AttaquesElementaires, _centre: Vector2, _rayon_px: float, _age: float) -> bool:
	return false


## Le départ d'une onde : un front qui part de la tour (`centre`) et s'étend à la vitesse de
## l'onde jusqu'à son rayon ; par défaut rien.
func onde(_m: AttaquesElementaires, _centre: Vector2, _age: float) -> bool:
	return false


## Un piège (ou une mine) lancé de `depart` vers `arrivee` : l'objet reste ensuite au sol, visible,
## jusqu'à `AttaquesElementaires.retirer_pieges(arrivee)` ; par défaut rien.
func piege(_m: AttaquesElementaires, _depart: Vector2, _arrivee: Vector2) -> bool:
	return false
