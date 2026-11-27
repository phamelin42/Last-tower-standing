class_name AttaqueArchere
extends AttaqueChaos
## Archère fantôme (invocation, chaos) : une flèche spectrale pâle file de la tour à l'endroit où
## l'archère se lève ; à son arrivée des volutes de verre montent d'un anneau pâle et se referment
## en capuche. Chaque tir de l'archère éclabousse sa cible de gouttes pâles. L'allié lui-même est
## dessiné par `Allies2D`.

const CONF: Dictionary = {
	"couleur": VERRE,
	"projectile": "fleche_spectre",
	"cloche": 0.0,
	"fps": 0.0,
}
const DIAMETRE_APPARITION: float = 60.0
const DIAMETRE_COUP: float = 44.0


func id() -> String:
	return ElementsArmes.ARCHERE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return cases(["apparition_spectre", "eclat_spectre"]).merged(
		{"fleche_spectre": Vector2i(20, 8)}
	)


func visibles() -> Dictionary:
	return mesures(["apparition_spectre", "eclat_spectre"])


func suivre_vol(m: AttaquesElementaires, vol: Dictionary, attente: float, duree_vol: float) -> void:
	m.trainee(vol, 3, 9.0 * AttaquesElementaires.IMAGE, VERRE, Vector2.ZERO)
	apparaitre(m, vol, attente, duree_vol, "apparition_spectre", DIAMETRE_APPARITION)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	eclats(m, ou, ECLATS, VERRE)
	return jouer(m, "eclat_spectre", ou, DIAMETRE_COUP, SEQ_IMPACT, age)
