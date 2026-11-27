class_name AttaqueBrume
extends AttaqueElement
## Lame de brume (cible unique, malédiction) : la lame de fil, teintée de bleu pâle, qui tourne en
## filant droit ; à l'impact une entaille de la même teinte et trois bouffées de brume qui montent
## et se dissipent (la marque de malédiction reste celle d'`Effets`).

const TEINTE := Color(0.7, 0.85, 1.0)
const CONF: Dictionary = {
	"couleur": TEINTE,
	"projectile": "lame_croissant",
	"cloche": 0.0,
	"fps": 30.0,
	"fige_reduit": true,
	"teinte": TEINTE,
}
const SEQ_ENTAILLE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const BOUFFEES: int = 3
## Les bouffées naissent autour de l'impact, à ce rayon (pixels).
const RAYON_BOUFFEES: float = 10.0


func id() -> String:
	return ElementsArmes.BRUME


func conf() -> Dictionary:
	return CONF


func planches() -> Dictionary:
	return {
		"lame_croissant": Vector2i(16, 16), "entaille": Vector2i(24, 24), "vapeur": Vector2i(16, 16)
	}


func visibles() -> Dictionary:
	return {"entaille": 22.0}


func impacter(
	m: AttaquesElementaires, ou: Vector2, _rayon_px: float, _fort: bool, _de: Vector2, age: float
) -> bool:
	var entaille: Dictionary = m.image_impact(
		"entaille", ou, AttaquesElementaires.DIAMETRE_PETIT, SEQ_ENTAILLE, age
	)
	var cree: bool = not entaille.is_empty()
	if cree:
		entaille["couleur"] = TEINTE
		m.poser(entaille)
	for k: int in BOUFFEES:
		var bouffee: Dictionary = m.nouveau(
			"nuage", "vapeur", AttaquesElementaires.IMAGES_NUAGE * AttaquesElementaires.IMAGE
		)
		if bouffee.is_empty():
			break
		bouffee["depart"] = ou + Vector2.from_angle(TAU * k / BOUFFEES + 0.5) * RAYON_BOUFFEES
		bouffee["age"] = age
		bouffee["couleur"] = TEINTE
		m.poser(bouffee)
		cree = true
	return cree
