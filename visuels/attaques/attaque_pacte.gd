class_name AttaquePacte
extends AttaqueChaos
## Pacte de sang (cible unique, siphon de vie) : une goutte de sang lancée en arc, la pointe en
## haut, qui s'écrase en croix rouge sur la cible, petite, avec quelques gouttes. Le siphon qui
## remonte vers la tour est la marque d'aujourd'hui.

const COULEUR := Color(0.85, 0.2, 0.25)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"projectile": "goutte_sang",
	"cloche": 0.25,
	"fps": 0.0,
	"tour": 0.0,
}
const DIAMETRE_COUP: float = 44.0


func id() -> String:
	return ElementsArmes.PACTE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return cases(["eclat_sang"]).merged({"goutte_sang": Vector2i(10, 12)})


func visibles() -> Dictionary:
	return mesures(["eclat_sang"])


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	eclats(m, ou, ECLATS, COULEUR)
	return jouer(m, "eclat_sang", ou, DIAMETRE_COUP, SEQ_IMPACT, age)
