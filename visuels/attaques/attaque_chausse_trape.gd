class_name AttaqueChausseTrape
extends AttaquePercante
## Chausse-trape (piège) : trois chausse-trapes lancées en éventail retombent autour de la cible et
## restent au sol, visibles, tant que le piège n'a pas servi ; au déclenchement les pointes
## jaillissent de la zone, dessinée exactement au rayon du piège.

const CONF: Dictionary = {
	"couleur": COULEUR_ACIER,
	"projectile": "chausse_trape",
	"cloche": 0.22,
	"fps": 0.0,
	"tour": 4.0 * PI,
}
const LANCES: int = 3
## Écart latéral des chausse-trapes de l'éventail, en pixels.
const ECART_EVENTAIL: float = 22.0
## Plus petites que les autres projectiles : au sol, elles ne doivent pas cacher la cible.
const ECHELLE_CHAUSSE_TRAPE: float = 2.0
const AVANCE_CENTRE: float = 7.0
## Elles sont lancées l'une après l'autre, à deux images d'intervalle.
const RETARD_LANCE: float = 2.0 * AttaquesElementaires.IMAGE
const SEQ_POINTES: Array[int] = [0, 1, 2, 2, 2, 3, 3, 4, 4, 5, 5, 5]
const IMAGES_ANNEAU: int = 14
const ECLATS: int = 6


func id() -> String:
	return ElementsArmes.CHAUSSE_TRAPE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {"chausse_trape": Vector2i(12, 12), "pointes_sol": Vector2i(32, 32)}


func visibles() -> Dictionary:
	return {"pointes_sol": 28.0}


func piege(m: AttaquesElementaires, depart: Vector2, arrivee: Vector2) -> bool:
	var sens: Vector2 = (arrivee - depart).normalized() if arrivee != depart else Vector2.RIGHT
	var cote: Vector2 = sens.orthogonal()
	var vol: float = AttaquesElementaires.IMAGES_VOL_CLOCHE * AttaquesElementaires.IMAGE
	var cree: bool = false
	for k: int in LANCES:
		var but: Vector2 = arrivee + cote * ((k - 1) * ECART_EVENTAIL)
		if k == 1:
			but += sens * AVANCE_CENTRE
		var retard: float = k * RETARD_LANCE
		var lance: Dictionary = m.nouveau("vol", "chausse_trape", vol)
		if lance.is_empty():
			break
		lance["age"] = -retard
		lance["depart"] = depart
		lance["arrivee"] = but
		lance["couleur"] = Color.WHITE
		lance["echelle"] = ECHELLE_CHAUSSE_TRAPE
		lance["cloche"] = float(CONF["cloche"])
		lance["tour"] = float(CONF["tour"])
		lance["vol"] = vol
		m.poser(lance)
		var pose: Dictionary = m.nouveau("piege", "chausse_trape", AttaquesElementaires.DUREE_PIEGE)
		if pose.is_empty():
			break
		pose["age"] = -(retard + vol)
		pose["depart"] = but
		pose["arrivee"] = arrivee
		pose["tour"] = k * 2.1
		pose["couleur"] = Color.WHITE
		pose["echelle"] = ECHELLE_CHAUSSE_TRAPE
		m.poser(pose)
		cree = true
	return cree


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var diametre: float = rayon_px * 2.0 if rayon_px > 0.0 else AttaquesElementaires.DIAMETRE_PETIT
	var cree: bool = not m.image_impact("pointes_sol", ou, diametre, SEQ_POINTES, age).is_empty()
	if rayon_px > 0.0:
		cree = m.anneau_impact(ou, diametre, IMAGES_ANNEAU, age, COULEUR_ACIER) or cree
	eclats(m, ou, ECLATS, COULEUR_ACIER)
	return cree
