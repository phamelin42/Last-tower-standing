class_name AttaqueOrage
extends AttaqueElement
## Orage en cage (zone posée, brûlure) : une grosse étincelle violette est lancée en cloche
## (ombre, traînée) ; à l'arrivée un éclat étoilé, petit, et un anneau fin au rayon réel dessinent
## la cage à chaque impulsion (le disque au sol vient de la vue). La marque de brûlure reste celle
## d'`Effets`.

const COULEUR := Color(0.78, 0.7, 1.0)
const COULEUR_OR := Color(1.0, 0.89, 0.48)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"projectile": "etincelle",
	"cloche": 0.3,
	"fps": 0.0,
	"echelle": 1.6,
	"bosse": 0.2,
}
## Le pic de l'éclat étoilé (image 3 de la planche) est atteint à la troisième image sur douze.
const IMAGE_PIC: int = 3
const SEQ_ECLAT: Array[int] = [0, 1, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4]
const DIAMETRE_ECLAT: float = 40.0
const IMAGES_ANNEAU: int = 14
const ETINCELLES: int = 4


func id() -> String:
	return ElementsArmes.ORAGE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"eclat_astral": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"eclat_astral": 22.0}


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 3, 10.0 * AttaquesElementaires.IMAGE, COULEUR, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = not (
		m.image_impact("eclat_astral", ou, DIAMETRE_ECLAT, SEQ_ECLAT, age).is_empty()
	)
	if rayon_px > 0.0:
		cree = m.anneau_impact(ou, rayon_px * 2.0, IMAGES_ANNEAU, age, COULEUR) or cree
	m.salve(
		ou,
		ETINCELLES,
		COULEUR_OR,
		14.0 * AttaquesElementaires.IMAGE,
		50.0,
		140.0,
		Vector2.ZERO,
		1.5
	)
	return cree
