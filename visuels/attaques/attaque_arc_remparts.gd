class_name AttaqueArcRemparts
extends AttaquePercante
## Arc de remparts (rebond de quatre cibles, vulnérabilité) : un grand trait teinté de chaud, plus
## gros que le carreau ricochet, part à chaque saut dès que le précédent est arrivé, derrière une
## traînée ambrée ; à chaque rebond une petite gerbe et des éclats de braise, sans rester planté
## puisqu'il repart. La marque de vulnérabilité reste celle d'`Effets`.

const TEINTE := Color(1.0, 0.9, 0.75)
const COULEUR_BRAISE := Color(0.95, 0.5, 0.2)
const CONF: Dictionary = {
	"couleur": COULEUR_BRAISE,
	"projectile": "carreau",
	"cloche": 0.0,
	"saut": true,
	"echelle": 1.15,
	"teinte": TEINTE,
}
const ECLATS: int = 3
const VIE_TRAINEE: float = 8.0 * AttaquesElementaires.IMAGE


func id() -> String:
	return ElementsArmes.ARC_REMPARTS


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 4, VIE_TRAINEE, COULEUR_BRAISE, Vector2.ZERO)


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var cree: bool = gerbe(m, ou, AttaquesElementaires.DIAMETRE_PETIT, age)
	eclats(m, ou, ECLATS, COULEUR_BRAISE)
	return cree
