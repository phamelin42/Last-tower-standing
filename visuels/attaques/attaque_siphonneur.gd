class_name AttaqueSiphonneur
extends AttaqueElement
## Éclat siphonneur (cible unique, siphon de mana) : un orbe violet file droit derrière une queue
## de volutes ; à l'impact un anneau de siphon se resserre sur la cible, petit, et quelques volutes
## montent. La marque de siphon et le gain de mana restent ceux d'`Effets`.

const COULEUR := Color(0.72, 0.5, 1.0)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"projectile": "siphon",
	"cloche": 0.0,
	"fige_reduit": true,
}
## L'anneau de la planche se resserre : sa plus grande image est la première, donc le pic.
const IMAGE_PIC: int = 0
const SEQ_ECLAT: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 3, 3]
const DIAMETRE_ECLAT: float = 44.0
const VOLUTES: int = 4


func id() -> String:
	return ElementsArmes.SIPHONNEUR


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 4, 12.0 * AttaquesElementaires.IMAGE, COULEUR, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = not (
		m.image_impact("eclat_siphon", ou, DIAMETRE_ECLAT, SEQ_ECLAT, age).is_empty()
	)
	# Les volutes montent : la mana quitte la cible.
	m.salve(
		ou,
		VOLUTES,
		COULEUR,
		18.0 * AttaquesElementaires.IMAGE,
		30.0,
		90.0,
		Vector2(0.0, -160.0),
		1.5
	)
	return cree
