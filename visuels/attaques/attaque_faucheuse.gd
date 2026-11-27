class_name AttaqueFaucheuse
extends AttaqueElement
## Faucheuse double (tir tournant, quatre branches, poison) : une lame tournante teintée de vert
## pâle par branche, qui file le long du rayon ; au bout un éclat d'acier, des étincelles et des
## gouttes vertes qui retombent (la marque de poison reste celle d'`Effets`).

const TEINTE := Color(0.7, 1.0, 0.75)
const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "lame_tournante",
	"cloche": 0.0,
	"fps": 30.0,
	"vrille": 5.0,
	"fige_reduit": true,
	"teinte": TEINTE,
}
const SEQ_ECLAT: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const COULEUR_GOUTTES := Color(0.3, 0.72, 0.29)
const ETINCELLES: int = 3
const GOUTTES: int = 3


func id() -> String:
	return ElementsArmes.FAUCHEUSE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"lame_tournante": Vector2i(12, 12), "eclat_acier": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"eclat_acier": 22.0}


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var eclat: Dictionary = m.image_impact(
		"eclat_acier", ou, AttaquesElementaires.DIAMETRE_PETIT, SEQ_ECLAT, age
	)
	var image: float = AttaquesElementaires.IMAGE
	m.salve(ou, ETINCELLES, CONF["couleur"], 10.0 * image, 60.0, 150.0, Vector2.ZERO, 1.5)
	m.salve(ou, GOUTTES, COULEUR_GOUTTES, 18.0 * image, 30.0, 90.0, Vector2(0.0, 220.0), 1.5)
	return not eclat.is_empty()
