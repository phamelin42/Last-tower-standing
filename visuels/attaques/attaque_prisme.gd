class_name AttaquePrisme
extends AttaqueElement
## Prisme de faille (cible unique, vulnérabilité) : un cristal bleu file droit en tournant sur
## lui-même derrière des reflets ; à l'impact il éclate en étoile, petit, et des éclats de cristal
## jaillissent. La marque de vulnérabilité reste celle d'`Effets`.

const COULEUR := Color(0.7, 0.9, 1.0)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"projectile": "prisme",
	"cloche": 0.0,
	"vrille": 2.0,
}
## La plus grande image de l'étoile est la deuxième.
const IMAGE_PIC: int = 1
const SEQ_ECLAT: Array[int] = [0, 1, 1, 1, 2, 2, 3, 3, 3, 3]
const DIAMETRE_ECLAT: float = 44.0
const ECLATS: int = 5


func id() -> String:
	return ElementsArmes.PRISME


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 3, 10.0 * AttaquesElementaires.IMAGE, COULEUR, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = not (
		m.image_impact("eclat_prisme", ou, DIAMETRE_ECLAT, SEQ_ECLAT, age).is_empty()
	)
	m.salve(ou, ECLATS, COULEUR, 14.0 * AttaquesElementaires.IMAGE, 60.0, 150.0, Vector2.ZERO, 1.5)
	return cree
