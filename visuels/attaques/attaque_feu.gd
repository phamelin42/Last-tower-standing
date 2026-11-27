class_name AttaqueFeu
extends AttaqueElement
## Feu (canon, barrage) : une boule qui laisse des braises ; à l'impact un cœur de feu à la moitié
## du rayon, l'anneau au rayon exact et six braises.

const CONF: Dictionary = {
	"couleur": Color(1.0, 0.62, 0.2),
	"projectile": "boule_feu",
	"cloche": 0.0,
}


func id() -> String:
	return ElementsArmes.FEU


func conf() -> Dictionary:
	return CONF


func suivre_vol(
	m: AttaquesElementaires, vol: Dictionary, _attente: float, _duree_vol: float
) -> void:
	m.trainee(vol, 4, 15.0 * AttaquesElementaires.IMAGE, CONF["couleur"], Vector2(0.0, -80.0))


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	return _impact(m, ou, rayon_px, fort, age, rayon_px > 0.0)


## Un barrage garde le cœur de feu et les braises de chaque boule, mais un seul anneau pour tout le
## tir (`zone`) : quatre anneaux empilés cachaient la cible.
func impacter_en_groupe(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, _de: Vector2, age: float
) -> bool:
	return _impact(m, ou, rayon_px, fort, age, false)


func zone(m: AttaquesElementaires, centre: Vector2, rayon_px: float, age: float) -> bool:
	return m.anneau_impact(centre, rayon_px * 2.0, 18, age, CONF["couleur"])


## Un cœur de feu à la moitié du rayon, l'anneau au rayon exact s'il est demandé, six braises.
func _impact(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, fort: bool, age: float, anneau: bool
) -> bool:
	var diametre: float = rayon_px if rayon_px > 0.0 else AttaquesElementaires.DIAMETRE_PETIT
	var coeur: Dictionary = m.image_impact(
		"explosion_feu", ou, diametre, AttaquesElementaires.SEQ_EXPLOSION, age
	)
	var cree: bool = not coeur.is_empty()
	if cree and fort:
		m.geler(coeur, age, AttaquesElementaires.IMAGES_MONTEE_IMPACT * AttaquesElementaires.IMAGE)
	if anneau:
		cree = zone(m, ou, rayon_px, age) or cree
	m.salve(
		ou,
		6,
		CONF["couleur"],
		15.0 * AttaquesElementaires.IMAGE,
		40.0,
		110.0,
		Vector2(0.0, -80.0),
		1.5
	)
	return cree
