class_name AttaqueDePipe
extends AttaqueElement
## Dé pipé (cible unique, vol de vie) : un dé violet qui roule en tournant, une face de 1 à 4 points
## par image ; à l'impact un éclat de points d'or et quelques points qui sautent. Le soin qui
## remonte vers la tour est la marque d'aujourd'hui.

const CONF: Dictionary = {
	"couleur": Color(0.66, 0.4, 0.9),
	"projectile": "de_pipe",
	"cloche": 0.0,
	"vrille": 2.5,
	"fige_reduit": true,
}
const SEQ_ECLAT: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const POINTS: int = 4
const COULEUR_POINTS := Color(1.0, 0.82, 0.29)


func id() -> String:
	return ElementsArmes.DE_PIPE


func conf() -> Dictionary:
	return CONF


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var eclat: Dictionary = m.image_impact(
		"eclat_des", ou, AttaquesElementaires.DIAMETRE_PETIT, SEQ_ECLAT, age
	)
	m.salve(
		ou,
		POINTS,
		COULEUR_POINTS,
		14.0 * AttaquesElementaires.IMAGE,
		50.0,
		130.0,
		Vector2(0.0, 200.0),
		1.5
	)
	return not eclat.is_empty()
