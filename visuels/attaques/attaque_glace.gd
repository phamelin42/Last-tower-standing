class_name AttaqueGlace
extends AttaqueElement
## Glace (orbe de brume) : un éclat orienté suivi de deux plus petits, des points de givre ; à
## l'impact une brisure au rayon, puis le givre au sol, au rayon exact, qui s'efface en 24 images.

const CONF: Dictionary = {
	"couleur": Color(0.75, 0.95, 1.0),
	"projectile": "eclat_glace",
	"cloche": 0.0,
	"fps": 0.0,
}
## Des éclats qui suivent le premier, décalés de 2 images chacun, plus petits.
const SUITES: int = 2
const DECALAGE_SUITE: float = 2.0 * AttaquesElementaires.IMAGE
const ECHELLE_SUITE: float = 0.5
const IMAGES_GIVRE: int = 24


func id() -> String:
	return ElementsArmes.GLACE


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {
		"eclat_glace": Vector2i(20, 8),
		"brisure_glace": Vector2i(32, 32),
		"givre_sol": Vector2i(32, 16),
	}


func visibles() -> Dictionary:
	return {"brisure_glace": 30.0, "givre_sol": 31.0}


func suivre_vol(m: AttaquesElementaires, vol: Dictionary, attente: float, duree_vol: float) -> void:
	m.trainee(vol, 3, 10.0 * AttaquesElementaires.IMAGE, Color.WHITE, Vector2.ZERO)
	for k: int in range(1, SUITES + 1):
		var suite: float = k * DECALAGE_SUITE
		var eclat: Dictionary = m.nouveau("vol", String(vol["planche"]), duree_vol + suite)
		if eclat.is_empty():
			return
		eclat["age"] = -attente
		eclat["depart"] = vol["depart"]
		eclat["arrivee"] = vol["arrivee"]
		eclat["vol"] = duree_vol
		eclat["suite"] = suite
		eclat["echelle"] = AttaquesElementaires.ECHELLE * ECHELLE_SUITE
		m.poser(eclat)


func impacter(
	m: AttaquesElementaires, ou: Vector2, rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var zone: bool = rayon_px > 0.0
	var diametre: float = rayon_px * 2.0 if zone else AttaquesElementaires.DIAMETRE_PETIT
	var couleur: Color = CONF["couleur"]
	var cree: bool = not (
		m
		. image_impact("brisure_glace", ou, diametre, AttaquesElementaires.SEQ_EXPLOSION, age)
		. is_empty()
	)
	if zone:
		var sol: Dictionary = m.nouveau(
			"sol", "givre_sol", IMAGES_GIVRE * AttaquesElementaires.IMAGE
		)
		if not sol.is_empty():
			sol["age"] = age
			sol["depart"] = ou
			sol["diametre"] = diametre
			sol["echelle"] = diametre / float(visibles()["givre_sol"])
			m.poser(sol)
			cree = true
		cree = m.anneau_impact(ou, diametre, IMAGES_GIVRE, age, couleur) or cree
	m.salve(ou, 6, couleur, 20.0 * AttaquesElementaires.IMAGE, 50.0, 140.0, Vector2.ZERO, 1.5)
	return cree
