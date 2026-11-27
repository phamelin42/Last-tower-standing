class_name AttaqueTrebuchet
extends AttaqueElement
## Trébuchet de chambre (zone) : un rocher qui tourne sur lui-même, lancé en haute cloche, son ombre
## sur la ligne droite ; à l'impact un cratère de poussière au rayon réel, un anneau, des débris de
## roche, et le gel d'un coup de siège.

const CONF: Dictionary = {
	"couleur": Color(0.7, 0.64, 0.56),
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "rocher",
	"cloche": 0.5,
	"tour": TAU,
	"bosse": 0.1,
}
const IMAGES_ANNEAU: int = 14
const DEBRIS: int = 10
const COULEUR_DEBRIS := Color(0.5, 0.45, 0.4)


func id() -> String:
	return ElementsArmes.TREBUCHET


func conf() -> Dictionary:
	return CONF


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	var diametre: float = rayon_px * 2.0 if rayon_px > 0.0 else AttaquesElementaires.DIAMETRE_PETIT
	var cratere: Dictionary = m.image_impact(
		"cratere", ou, diametre, AttaquesElementaires.SEQ_EXPLOSION, age
	)
	var cree: bool = not cratere.is_empty()
	if cree and fort:
		m.geler(
			cratere, age, AttaquesElementaires.IMAGES_MONTEE_IMPACT * AttaquesElementaires.IMAGE
		)
	if rayon_px > 0.0:
		cree = m.anneau_impact(ou, diametre, IMAGES_ANNEAU, age, CONF["couleur"]) or cree
	m.salve(ou, DEBRIS, COULEUR_DEBRIS, 0.4, 80.0, 200.0, Vector2(0.0, 300.0), 2.0)
	return cree
