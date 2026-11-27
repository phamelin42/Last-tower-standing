class_name AttaqueFaucille
extends AttaqueElement
## Faucille à ressort (zone) : une faucille lancée en léger arc qui tourne en vol, son ombre au
## sol ; à l'impact un arc de lame balaie 300° au rayon réel de la zone, quelques éclats d'acier.

const CONF: Dictionary = {
	"couleur": Color(0.81, 0.85, 0.92),
	"projectile": "faucille",
	"cloche": 0.12,
	"tour": 4.0 * PI,
}
## Deux images à 60 i/s par image de planche : les 300° sont faits au bout de 6 images.
const SEQ_BALAYAGE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
const ECLATS: int = 4


func id() -> String:
	return ElementsArmes.FAUCILLE


func conf() -> Dictionary:
	return CONF


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var diametre: float = rayon_px * 2.0 if rayon_px > 0.0 else AttaquesElementaires.DIAMETRE_PETIT
	var balayage: Dictionary = m.image_impact("balayage", ou, diametre, SEQ_BALAYAGE, age)
	m.salve(
		ou,
		ECLATS,
		CONF["couleur"],
		14.0 * AttaquesElementaires.IMAGE,
		50.0,
		130.0,
		Vector2.ZERO,
		1.5
	)
	return not balayage.is_empty()
