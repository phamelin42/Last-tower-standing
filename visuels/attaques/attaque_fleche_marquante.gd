class_name AttaqueFlecheMarquante
extends AttaquePercante
## Flèche marquante (cible unique, vulnérabilité) : une flèche au fer orange file droit derrière une
## traînée orange ; à l'impact une gerbe, la flèche plantée dix images et des éclats orange. La
## marque de vulnérabilité posée sur l'ennemi reste celle d'`Effets` : rien ici ne la redessine.

const COULEUR_MARQUE := Color(1.0, 0.62, 0.18)
const CONF: Dictionary = {
	"couleur": COULEUR_MARQUE,
	"projectile": "fleche_marquante",
	"cloche": 0.0,
	"echelle": 0.9,
}
const DIAMETRE_GERBE: float = 44.0
const IMAGES_PLANTE: int = 10
const ECLATS: int = 4
const VIE_TRAINEE: float = 8.0 * AttaquesElementaires.IMAGE


func id() -> String:
	return ElementsArmes.FLECHE_MARQUANTE


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 4, VIE_TRAINEE, COULEUR_MARQUE, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = gerbe(m, ou, DIAMETRE_GERBE, age)
	cree = planter(m, ou, IMAGES_PLANTE, age) or cree
	eclats(m, ou, ECLATS, COULEUR_MARQUE)
	return cree
