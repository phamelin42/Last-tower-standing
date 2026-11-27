class_name AttaqueCouronneEtoiles
extends AttaqueElement
## Couronne d'étoiles (tir tournant, cinq branches, mana au coup) : une étoile d'or par branche
## file droit le long du rayon en tournant sur elle-même ; au bout un éclat étoilé à la largeur du
## rayon et quelques étincelles. La simulation n'émet aucun impact à cet endroit : l'éclat est
## décoratif et ne fait réagir aucun ennemi (les rayons de la marque restent ceux d'`Effets`).

const COULEUR := Color(1.0, 0.89, 0.48)
const COULEUR_VIOLET := Color(0.49, 0.31, 0.84)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"projectile": "etoile_astrale",
	"cloche": 0.0,
	"fps": 12.0,
	"vrille": 2.5,
	"fige_reduit": true,
}
const IMAGE_PIC: int = 3
const SEQ_ECLAT: Array[int] = [0, 1, 3, 3, 3, 4, 4, 4, 4]
const ETINCELLES: int = 3


func id() -> String:
	return ElementsArmes.COURONNE_ETOILES


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
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var diametre: float = rayon_px * 2.0 if rayon_px > 0.0 else AttaquesElementaires.DIAMETRE_PETIT
	var cree: bool = not m.image_impact("eclat_astral", ou, diametre, SEQ_ECLAT, age).is_empty()
	m.salve(
		ou, ETINCELLES, COULEUR, 12.0 * AttaquesElementaires.IMAGE, 50.0, 130.0, Vector2.ZERO, 1.5
	)
	return cree
