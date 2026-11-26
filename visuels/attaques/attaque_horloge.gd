class_name AttaqueHorloge
extends AttaqueElement
## Horloge folle (barrage, brûlure) : plusieurs rouages d'or qui tournent, chacun parti deux images
## après le précédent ; à chaque impact un éclat de petits rouages et quelques étincelles, et pour
## tout le tir un seul anneau au rayon réel. La brûlure est la marque d'aujourd'hui.

const CONF: Dictionary = {
	"couleur": Color(0.88, 0.25, 0.6),
	"projectile": "engrenage",
	"cloche": 0.0,
	"fps": 8.0,
	"vrille": 3.0,
	"fige_reduit": true,
}
const COULEUR_ANNEAU := Color(1.0, 0.82, 0.29)
const SEQ_ECLAT: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const ETINCELLES: int = 4
const IMAGES_ANNEAU: int = 18


func id() -> String:
	return ElementsArmes.HORLOGE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"engrenage": Vector2i(12, 12), "eclat_engrenage": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"eclat_engrenage": 22.0}


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, de: Vector2, age: float
) -> bool:
	var cree: bool = impacter_en_groupe(m, ou, rayon_px, fort, de, age)
	if rayon_px > 0.0:
		cree = zone(m, ou, rayon_px, age) or cree
	return cree


func impacter_en_groupe(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var eclat: Dictionary = m.image_impact(
		"eclat_engrenage", ou, AttaquesElementaires.DIAMETRE_PETIT, SEQ_ECLAT, age
	)
	m.salve(
		ou,
		ETINCELLES,
		COULEUR_ANNEAU,
		12.0 * AttaquesElementaires.IMAGE,
		50.0,
		130.0,
		Vector2.ZERO,
		1.5
	)
	return not eclat.is_empty()


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, COULEUR_ANNEAU)
