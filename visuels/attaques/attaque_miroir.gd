class_name AttaqueMiroir
extends AttaqueElement
## Miroir brisé (rebond) : un éclat de verre par saut, qui tourne en lançant un reflet blanc ; à
## chaque cible une gerbe de verre, petite, et quelques éclats qui retombent.

const CONF: Dictionary = {
	"couleur": Color(0.85, 0.95, 1.0),
	"projectile": "eclat_miroir",
	"cloche": 0.0,
	"vrille": 2.0,
	"saut": true,
	"fige_reduit": true,
}
const SEQ_GERBE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4]
const ECLATS: int = 5
const COULEUR_BLEU := Color(0.5, 0.72, 0.88)


func id() -> String:
	return ElementsArmes.MIROIR


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 3, 9.0 * AttaquesElementaires.IMAGE, COULEUR_BLEU, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var gerbe: Dictionary = m.image_impact(
		"gerbe_verre", ou, AttaquesElementaires.DIAMETRE_PETIT, SEQ_GERBE, age
	)
	m.salve(
		ou,
		ECLATS,
		CONF["couleur"],
		14.0 * AttaquesElementaires.IMAGE,
		50.0,
		140.0,
		Vector2(0.0, 220.0),
		1.5
	)
	return not gerbe.is_empty()
