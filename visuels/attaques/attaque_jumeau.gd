class_name AttaqueJumeau
extends AttaqueChaos
## Engrenage jumeau (cible unique) : deux engrenages d'or qui s'engrènent filent droit en tournant
## d'un cran par image, une traînée d'étincelles dorées ; à l'impact une étoile d'or à huit
## branches, petite, et quelques étincelles.

const CONF: Dictionary = {
	"couleur": OR,
	"projectile": "engrenage_double",
	"cloche": 0.0,
	"fps": 12.0,
	"fige_reduit": true,
}
const DIAMETRE_COUP: float = 46.0


func id() -> String:
	return ElementsArmes.JUMEAU


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return cases(["eclat_jumeau"]).merged({"engrenage_double": Vector2i(16, 12)})


func visibles() -> Dictionary:
	return mesures(["eclat_jumeau"])


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 3, 9.0 * AttaquesElementaires.IMAGE, OR, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	eclats(m, ou, ECLATS, OR)
	return jouer(m, "eclat_jumeau", ou, DIAMETRE_COUP, SEQ_IMPACT, age)
