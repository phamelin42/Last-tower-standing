class_name AttaqueTourbillon
extends AttaqueElement
## Tourbillon d'acier (barrage, vol de vie) : plusieurs lames tournantes, chacune partie deux
## images après la précédente ; à chaque impact un éclat d'acier et quelques éclats, et pour tout
## le tir un seul anneau au rayon réel. Le soin vert qui remonte vers la tour reste celui
## d'`Effets`.

const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "lame_tournante",
	"cloche": 0.0,
	"fps": 30.0,
	"vrille": 5.0,
	"fige_reduit": true,
}
const SEQ_ECLAT: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const ECLATS: int = 3
const IMAGES_ANNEAU: int = 18


func id() -> String:
	return ElementsArmes.TOURBILLON


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"lame_tournante": Vector2i(12, 12), "eclat_acier": Vector2i(24, 24)}


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
	m.salve(
		ou,
		ECLATS,
		CONF["couleur"],
		10.0 * AttaquesElementaires.IMAGE,
		50.0,
		130.0,
		Vector2.ZERO,
		1.5
	)
	return not eclat.is_empty()


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, CONF["couleur"])
