class_name AttaqueTempete
extends AttaqueElement
## Tempête astrale (rebond) : une étoile d'or et de violet par saut, qui part dès que la précédente
## est arrivée et tourne sur elle-même ; à chaque cible un éclat étoilé et quelques étincelles.
## L'étourdissement est la marque d'aujourd'hui.

const CONF: Dictionary = {
	"couleur": Color(1.0, 0.89, 0.48),
	"projectile": "etoile_astrale",
	"cloche": 0.0,
	"fps": 12.0,
	"saut": true,
	"fige_reduit": true,
}
const SEQ_ECLAT: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4]
const ETINCELLES: int = 5
const COULEUR_VIOLET := Color(0.49, 0.31, 0.84)


func id() -> String:
	return ElementsArmes.TEMPETE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"etoile_astrale": Vector2i(12, 12), "eclat_astral": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"eclat_astral": 22.0}


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 3, 10.0 * AttaquesElementaires.IMAGE, COULEUR_VIOLET, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = not (
		m
		. image_impact("eclat_astral", ou, AttaquesElementaires.DIAMETRE_PETIT, SEQ_ECLAT, age)
		. is_empty()
	)
	m.salve(
		ou,
		ETINCELLES,
		CONF["couleur"],
		14.0 * AttaquesElementaires.IMAGE,
		50.0,
		140.0,
		Vector2.ZERO,
		1.5
	)
	return cree
