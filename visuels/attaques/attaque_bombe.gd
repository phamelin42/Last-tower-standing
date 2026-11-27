class_name AttaqueBombe
extends AttaqueElement
## Bombe (bombarde de poche) : une bombe à mèche qui tourne sur un vol en cloche, son ombre au sol ;
## à l'impact seulement des débris, l'explosion est celle du pack, dessinée par `Effets`.

const CONF: Dictionary = {
	"couleur": Color(0.72, 0.72, 0.75),
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "bombe",
	"cloche": 0.35,
	"tour": PI,
	"bosse": 0.15,
	"explosion": true,
}


func id() -> String:
	return ElementsArmes.BOMBE


func conf() -> Dictionary:
	return CONF


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, _age: float
) -> bool:
	return m.salve(ou, 10, Color(0.5, 0.45, 0.42), 0.4, 80.0, 200.0, Vector2(0.0, 300.0), 2.0)
