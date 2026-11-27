class_name AttaqueGrandeBombe
extends AttaqueBombe
## Grande bombarde (zone, étourdissement) : la bombe de la bombarde de poche, une fois et demie plus
## grosse, sur le même vol en cloche avec son ombre ; l'explosion est celle du pack au rayon réel
## (dessinée par `Effets`), avec douze débris. Les étoiles d'étourdissement sont la marque
## d'aujourd'hui.

const CONF_GRANDE: Dictionary = {
	"couleur": Color(0.72, 0.72, 0.75),
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "bombe",
	"cloche": 0.35,
	"tour": PI,
	"bosse": 0.15,
	"echelle": 1.5,
	"explosion": true,
}
const DEBRIS: int = 12


func id() -> String:
	return ElementsArmes.GRANDE_BOMBE


func conf() -> Dictionary:
	return CONF_GRANDE


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, _age: float
) -> bool:
	return m.salve(ou, DEBRIS, Color(0.5, 0.45, 0.42), 0.45, 90.0, 230.0, Vector2(0.0, 300.0), 2.0)
