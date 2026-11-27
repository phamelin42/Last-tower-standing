class_name AttaqueMalefices
extends AttaqueChaos
## Tempête de maléfices (barrage, trois statuts) : neuf orbes violets à quatre pointes magenta,
## partis tous les deux images, filent droit en tournant ; à chaque arrivée un orbe qui éclate en
## croix, et un seul anneau violet au rayon réel pour tout le tir. Les marques des trois statuts
## restent celles d'`Effets`.

const CONF: Dictionary = {
	"couleur": MAGENTA,
	"projectile": "malefice",
	"cloche": 0.0,
	"fps": 12.0,
	"fige_reduit": true,
	"retard": 2.0,
}
const DIAMETRE_COUP: float = 40.0
const ECLATS_PAR_COUP: int = 1


func id() -> String:
	return ElementsArmes.MALEFICES


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return cases(["eclat_malefice"]).merged({"malefice": Vector2i(12, 12)})


func visibles() -> Dictionary:
	return mesures(["eclat_malefice"])


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, de: Vector2, age: float
) -> bool:
	var cree: bool = impacter_en_groupe(m, ou, rayon_px, fort, de, age)
	if rayon_px > 0.0:
		cree = zone(m, ou, rayon_px, age) or cree
	return cree


func impacter_en_groupe(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	eclats(m, ou, ECLATS_PAR_COUP, MAGENTA)
	return jouer(m, "eclat_malefice", ou, DIAMETRE_COUP, SEQ_IMPACT, age)


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return m.anneau_impact(centre, rayon_px * 2.0, IMAGES_ANNEAU, age, VIOLET)
