class_name AttaqueScie
extends AttaqueElement
## Scie à ruban (barrage, poison) : une rafale de disques dentelés, chacun parti deux images après
## le précédent ; à chaque impact un éclat d'acier, des étincelles et des gouttes vertes, et pour
## tout le tir un seul anneau au rayon réel (la marque de poison reste celle d'`Effets`).

const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "disque_scie",
	"cloche": 0.0,
	"fps": 30.0,
	"vrille": 6.0,
	"fige_reduit": true,
}
const SEQ_ECLAT: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const COULEUR_GOUTTES := Color(0.3, 0.72, 0.29)
const ETINCELLES: int = 2
const GOUTTES: int = 2
const IMAGES_ANNEAU: int = 18


func id() -> String:
	return ElementsArmes.SCIE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"disque_scie": Vector2i(14, 14), "eclat_acier": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"eclat_acier": 22.0}


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
		"eclat_acier", ou, AttaquesElementaires.DIAMETRE_PETIT, SEQ_ECLAT, age
	)
	var image: float = AttaquesElementaires.IMAGE
	m.salve(ou, ETINCELLES, CONF["couleur"], 10.0 * image, 50.0, 130.0, Vector2.ZERO, 1.5)
	m.salve(ou, GOUTTES, COULEUR_GOUTTES, 18.0 * image, 30.0, 90.0, Vector2(0.0, 220.0), 1.5)
	return not eclat.is_empty()


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, CONF["couleur"])
