class_name AttaqueRuines
extends AttaqueSiege
## Champ de ruines (zone posée, vulnérabilité) : un tas de gravats est lancé en cloche avec son
## ombre et laisse de la poussière dans son sillage. À chaque impulsion un cœur de gravats petit et
## un anneau fin au rayon réel, des éclats de pierre, sans gel. Le disque au sol (`disque`) est
## dessiné depuis la vue, tant que la zone dure ; la marque de vulnérabilité est celle d'`Effets`.

const COULEUR := Color(0.62, 0.56, 0.48)
const CONF: Dictionary = {
	"couleur": COULEUR,
	"anticipation": AttaquesElementaires.COULEUR_BOUFFEE,
	"projectile": "gravats",
	"cloche": 0.45,
	"fps": 0.0,
	"tour": 0.0,
	"bosse": 0.1,
	"echelle": 1.4,
	"disque": "disque_ruines",
}
const POUSSIERE: int = 4
const ECLATS: int = 6
const COULEUR_ECLATS := Color(0.5, 0.45, 0.4)


func id() -> String:
	return ElementsArmes.RUINES


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {
		"gravats": Vector2i(12, 10),
		"cratere": Vector2i(32, 32),
		"disque_ruines": Vector2i(32, 16),
	}


func visibles() -> Dictionary:
	return {"cratere": 30.0, "disque_ruines": 30.0}


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, POUSSIERE, 12.0 * AttaquesElementaires.IMAGE, COULEUR, Vector2(0.0, 30.0))


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = pulser(m, "cratere", SEQ_CRATERE, ou, rayon_px, age, COULEUR)
	m.salve(ou, ECLATS, COULEUR_ECLATS, 0.4, 60.0, 160.0, Vector2(0.0, 300.0), 2.0)
	return cree
