class_name AttaqueRuneVeille
extends AttaqueElement
## Rune de veille (zone posée) : une rune bleue est lancée en cloche, laisse une traînée, puis se
## pose ; son éclat de rune, petit, et un anneau fin au rayon réel disent la zone touchée à chaque
## impulsion (le disque au sol est dessiné depuis la vue, pas ici).

const COULEUR := Color(0.5, 0.75, 1.0)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"projectile": "rune",
	"cloche": 0.3,
	"fps": 12.0,
	"echelle": 1.2,
}
## Le pic de l'éclat (image 3 de la planche) est atteint à la troisième image sur douze.
const IMAGE_PIC: int = 3
const SEQ_ECLAT: Array[int] = [0, 1, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4]
const DIAMETRE_ECLAT: float = 40.0
const IMAGES_ANNEAU: int = 14
const ETINCELLES: int = 4


func id() -> String:
	return ElementsArmes.RUNE_VEILLE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"rune": Vector2i(12, 12), "eclat_rune": Vector2i(24, 24)}


func visibles() -> Dictionary:
	return {"eclat_rune": 24.0}


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 3, 10.0 * AttaquesElementaires.IMAGE, COULEUR, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = not m.image_impact("eclat_rune", ou, DIAMETRE_ECLAT, SEQ_ECLAT, age).is_empty()
	if rayon_px > 0.0:
		cree = m.anneau_impact(ou, rayon_px * 2.0, IMAGES_ANNEAU, age, COULEUR) or cree
	m.salve(
		ou, ETINCELLES, COULEUR, 15.0 * AttaquesElementaires.IMAGE, 50.0, 130.0, Vector2.ZERO, 1.5
	)
	return cree
