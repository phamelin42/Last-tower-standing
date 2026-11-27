class_name AttaqueSerpe
extends AttaqueElement
## Serpe de vigne (zone, vulnérabilité) : une serpe lancée en léger arc qui tourne en vol, son
## ombre au sol ; à l'impact un arc de lame balaie 300° au rayon réel de la zone, des éclats
## d'acier et quelques feuilles de vigne qui retombent (la marque de vulnérabilité reste celle
## d'`Effets`).

const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "serpe",
	"cloche": 0.12,
	"tour": 4.0 * PI,
}
## Deux images à 60 i/s par image de planche : les 300° sont faits au bout de 6 images.
const SEQ_BALAYAGE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
const COULEUR_FEUILLES := Color(0.4, 0.85, 0.34)
const ECLATS: int = 3
const FEUILLES: int = 3


func id() -> String:
	return ElementsArmes.SERPE


func conf() -> Dictionary:
	return CONF


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var diametre: float = rayon_px * 2.0 if rayon_px > 0.0 else AttaquesElementaires.DIAMETRE_PETIT
	var balayage: Dictionary = m.image_impact("balayage", ou, diametre, SEQ_BALAYAGE, age)
	var image: float = AttaquesElementaires.IMAGE
	m.salve(ou, ECLATS, CONF["couleur"], 14.0 * image, 50.0, 130.0, Vector2.ZERO, 1.5)
	m.salve(ou, FEUILLES, COULEUR_FEUILLES, 22.0 * image, 30.0, 90.0, Vector2(0.0, 200.0), 1.5)
	return not balayage.is_empty()
