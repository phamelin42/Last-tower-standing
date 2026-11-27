class_name AttaqueBraise
extends AttaqueSiege
## Braise de siège (zone posée, brûlure) : un brasero plein de braises, dont la flamme change de
## forme, est lancé en cloche avec son ombre et laisse des flammes dans son sillage. À chaque
## impulsion un cœur de feu petit et un anneau fin au rayon réel, des braises qui montent, sans gel.
## Le disque au sol (`disque`) est dessiné depuis la vue, tant que la zone dure.

const COULEUR := Color(1.0, 0.6, 0.2)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "brasero",
	"cloche": 0.4,
	"fps": 8.0,
	"tour": 0.0,
	"bosse": 0.1,
	"echelle": 1.3,
	"disque": "disque_braise",
}
const FLAMMES: int = 4
const BRAISES: int = 6


func id() -> String:
	return ElementsArmes.BRAISE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {
		"brasero": Vector2i(12, 12),
		"explosion_feu": Vector2i(32, 32),
		"disque_braise": Vector2i(32, 16),
	}


func visibles() -> Dictionary:
	return {"explosion_feu": 28.0, "disque_braise": 30.0}


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, FLAMMES, 15.0 * AttaquesElementaires.IMAGE, COULEUR, Vector2(0.0, -80.0))


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = pulser(m, "explosion_feu", SEQ_FEU, ou, rayon_px, age, COULEUR)
	m.salve(
		ou,
		BRAISES,
		COULEUR,
		15.0 * AttaquesElementaires.IMAGE,
		40.0,
		110.0,
		Vector2(0.0, -80.0),
		1.5
	)
	return cree
