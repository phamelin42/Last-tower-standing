class_name AttaqueFleau
extends AttaqueElement
## Fléau de rasoirs (rebond, vulnérabilité) : un rasoir droit par saut, qui tourne vite en filant
## d'ennemi en ennemi ; à chaque impact un éclat d'acier et quelques étincelles (la marque de
## vulnérabilité reste celle d'`Effets`).

const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "rasoir",
	"cloche": 0.0,
	"fps": 30.0,
	"vrille": 7.0,
	"fige_reduit": true,
	"saut": true,
}
const SEQ_ECLAT: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const ETINCELLES: int = 3


func id() -> String:
	return ElementsArmes.FLEAU


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"rasoir": Vector2i(12, 12), "eclat_acier": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"eclat_acier": 22.0}


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var eclat: Dictionary = m.image_impact(
		"eclat_acier", ou, AttaquesElementaires.DIAMETRE_PETIT, SEQ_ECLAT, age
	)
	m.salve(
		ou,
		ETINCELLES,
		CONF["couleur"],
		10.0 * AttaquesElementaires.IMAGE,
		60.0,
		150.0,
		Vector2.ZERO,
		1.5
	)
	return not eclat.is_empty()
