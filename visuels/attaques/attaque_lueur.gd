class_name AttaqueLueur
extends AttaqueElement
## Lueur vagabonde (tir tournant, trois branches) : une comète bleue par branche file droit le long
## du rayon ; au bout un éclat de rune à la largeur du rayon et deux étincelles. La simulation
## n'émet aucun impact à cet endroit : l'éclat est décoratif et ne fait réagir aucun ennemi (les
## rayons de la marque restent ceux d'`Effets`).

const COULEUR := Color(0.6, 0.85, 1.0)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"projectile": "lueur",
	"cloche": 0.0,
	"fige_reduit": true,
}
const IMAGE_PIC: int = 3
const SEQ_ECLAT: Array[int] = [0, 1, 3, 3, 3, 4, 4, 4, 4]
const ETINCELLES: int = 2


func id() -> String:
	return ElementsArmes.LUEUR


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 3, 8.0 * AttaquesElementaires.IMAGE, COULEUR, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var diametre: float = rayon_px * 2.0 if rayon_px > 0.0 else AttaquesElementaires.DIAMETRE_PETIT
	var cree: bool = not m.image_impact("eclat_rune", ou, diametre, SEQ_ECLAT, age).is_empty()
	m.salve(
		ou, ETINCELLES, COULEUR, 12.0 * AttaquesElementaires.IMAGE, 50.0, 130.0, Vector2.ZERO, 1.5
	)
	return cree
