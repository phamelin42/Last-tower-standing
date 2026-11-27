class_name AttaqueUrne
extends AttaqueChaos
## Urne des ombres (invocation, chaos) : l'urne violette est lancée en cloche, sans tourner, de la
## tour à l'endroit où l'allié se lève ; à son arrivée une colonne de braise monte d'un anneau
## violet. Chaque coup de la sentinelle est une bouffée de fumée violette et de braises sur sa
## cible. L'allié lui-même est dessiné par `Allies2D`.

const CONF: Dictionary = {
	"couleur": VIOLET,
	"projectile": "urne",
	"cloche": 0.35,
	"fps": 0.0,
	"tour": 0.0,
}
const DIAMETRE_APPARITION: float = 60.0
const DIAMETRE_COUP: float = 40.0
const BRAISES: int = 4
const COULEUR_BRAISE := Color(1.0, 0.6, 0.2)


func id() -> String:
	return ElementsArmes.URNE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return cases(["apparition_ombre", "eclat_ombre"]).merged({"urne": Vector2i(12, 14)})


func visibles() -> Dictionary:
	return mesures(["apparition_ombre", "eclat_ombre"])


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, attente: float, duree_vol: float
) -> void:
	apparaitre(m, vol, attente, duree_vol, "apparition_ombre", DIAMETRE_APPARITION)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	eclats(m, ou, BRAISES, COULEUR_BRAISE)
	return jouer(m, "eclat_ombre", ou, DIAMETRE_COUP, SEQ_IMPACT, age)
