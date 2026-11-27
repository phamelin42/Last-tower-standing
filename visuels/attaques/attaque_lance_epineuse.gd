class_name AttaqueLanceEpineuse
extends AttaquePercante
## Lance épineuse (cible unique, poison, épines) : une lance hérissée de trois épines vertes file
## droit derrière une traînée de venin ; à l'impact une gerbe lourde, la lance plantée quatorze
## images, des épines vertes projetées et quelques gouttes de venin. Elle pique en retour : le
## venin reste la marque d'`Effets`.

const COULEUR_EPINE := Color(0.55, 0.78, 0.3)
const CONF: Dictionary = {
	"couleur": COULEUR_VENIN,
	"projectile": "lance_epineuse",
	"cloche": 0.0,
}
const DIAMETRE_GERBE: float = 48.0
const IMAGES_PLANTE: int = 14
const EPINES: int = 5
const GOUTTES: int = 3
const VIE_TRAINEE: float = 14.0 * AttaquesElementaires.IMAGE


func id() -> String:
	return ElementsArmes.LANCE_EPINEUSE


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 5, VIE_TRAINEE, COULEUR_VENIN, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = gerbe(m, ou, DIAMETRE_GERBE, age)
	cree = planter(m, ou, IMAGES_PLANTE, age, diametre_plante(MULTIPLE_PLANTE_LOURD)) or cree
	m.salve(
		ou, EPINES, COULEUR_EPINE, 14.0 * AttaquesElementaires.IMAGE, 70.0, 160.0, Vector2.ZERO, 1.5
	)
	m.salve(
		ou,
		GOUTTES,
		COULEUR_VENIN,
		18.0 * AttaquesElementaires.IMAGE,
		30.0,
		90.0,
		Vector2(0.0, 220.0),
		1.5
	)
	return cree
