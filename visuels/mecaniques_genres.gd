class_name MecaniquesGenres
extends RefCounted
## Les mécaniques propres à un genre d'arme sans projectile ordinaire (D22) : la couronne d'une
## aura, le front d'une onde, le projectile d'un saut de rebond et le piège posé. Elles se
## servent du pool d'`AttaquesElementaires` par ses primitives publiques (`nouveau`, `poser`) et
## ne gardent aucun état : l'aiguilleur reste le seul à posséder les effets vivants.

## Une couronne tourne de 1,5 tour par seconde et part du quart de son rayon.
const TOURS_COURONNE: float = 1.5
const ECHELLE_COURONNE_DEPART: float = 0.25
## Posé, un piège retombe de 1,3 à 1 en trois images, puis ne bouge plus.
const IMAGES_POSE_PIEGE: float = 3.0
const ECHELLE_POSE_PIEGE: float = 1.3


## Voir `AttaquesElementaires.couronne`.
static func couronne(
	m: AttaquesElementaires,
	planche: String,
	centre: Vector2,
	rayon_px: float,
	nombre: int,
	age: float,
	couleur: Color
) -> bool:
	var cree: bool = false
	for k: int in nombre:
		var lame: Dictionary = m.nouveau(
			"couronne", planche, AttaquesElementaires.IMAGES_COURONNE * AttaquesElementaires.IMAGE
		)
		if lame.is_empty():
			break
		lame["age"] = age
		lame["depart"] = centre
		lame["rayon_px"] = rayon_px
		lame["tour"] = TAU * k / nombre
		lame["couleur"] = couleur
		m.poser(lame)
		cree = true
	return cree


## Voir `AttaquesElementaires.front`.
static func front(
	m: AttaquesElementaires,
	planche: String,
	centre: Vector2,
	rayon_px: float,
	vitesse_px: float,
	nombre: int,
	age: float,
	couleur: Color
) -> bool:
	var cree: bool = false
	for k: int in nombre:
		var lame: Dictionary = m.nouveau("front", planche, rayon_px / vitesse_px)
		if lame.is_empty():
			break
		lame["age"] = age
		lame["depart"] = centre
		lame["rayon_px"] = rayon_px
		lame["vitesse"] = vitesse_px
		lame["tour"] = TAU * k / nombre
		lame["couleur"] = couleur
		m.poser(lame)
		cree = true
	return cree


## Voir `AttaquesElementaires.saut` : `el` est l'élément déjà résolu.
static func saut(
	m: AttaquesElementaires, el: AttaqueElement, depart: Vector2, arrivee: Vector2, retard: float
) -> float:
	var conf: Dictionary = el.conf()
	if not bool(conf.get("saut", false)):
		return -1.0
	var vol: float = AttaquesElementaires.IMAGES_VOL_DIRECT * AttaquesElementaires.IMAGE
	var projectile: Dictionary = m.nouveau("vol", String(conf["projectile"]), vol)
	if projectile.is_empty():
		return -1.0
	projectile["age"] = -retard
	projectile["depart"] = depart
	projectile["arrivee"] = arrivee
	projectile["couleur"] = Color.WHITE
	projectile["echelle"] = PlanchesEffets.echelle() * float(conf.get("echelle", 1.0))
	projectile["fps"] = PlanchesEffets.cadence_de(String(conf["projectile"]))
	projectile["vrille"] = float(conf.get("vrille", 0.0))
	projectile["fige_reduit"] = bool(conf.get("fige_reduit", false))
	projectile["vol"] = vol
	m.poser(projectile)
	el.suivre_vol(m, projectile, retard, vol)
	return retard + vol


## Place un sprite de couronne ; rend son opacité. En mouvement réduit, elle ne tourne pas.
static func poser_couronne(
	effet: Dictionary, n: Node2D, age: float, t: float, mouvement_reduit: bool
) -> float:
	var ouverture: float = clampf(
		age / (AttaquesElementaires.IMAGES_COURONNE_OUVERTURE * AttaquesElementaires.IMAGE),
		0.0,
		1.0
	)
	var rayon: float = float(effet["rayon_px"])
	var rayon_courant: float = (
		rayon * lerpf(ECHELLE_COURONNE_DEPART, 1.0, CourbesEffets.sortie(ouverture))
	)
	var phase: float = float(effet["tour"]) + age * TAU * TOURS_COURONNE
	if mouvement_reduit:
		phase = float(effet["tour"])
	n.position = (effet["depart"] as Vector2) + Vector2.from_angle(phase) * rayon_courant
	n.rotation = phase + PI / 2.0
	return AttaquesElementaires.ALPHA_MAX * (1.0 - maxf(t - 0.5, 0.0) / 0.5)


## Place un sprite de front d'onde ; rend son opacité (le dernier quart s'efface).
static func poser_front(effet: Dictionary, n: Node2D, age: float, t: float) -> float:
	var avance: float = minf(age * float(effet["vitesse"]), float(effet["rayon_px"]))
	var cap: float = float(effet["tour"])
	n.position = (effet["depart"] as Vector2) + Vector2.from_angle(cap) * avance
	n.rotation = cap
	return AttaquesElementaires.ALPHA_MAX * (1.0 - maxf(t - 0.75, 0.0) / 0.25)


## Place un piège posé ; rend le facteur d'échelle de sa retombée.
static func poser_piege(effet: Dictionary, n: Node2D, age: float) -> float:
	n.position = effet["depart"]
	n.rotation = float(effet["tour"])
	var pose: float = clampf(age / (IMAGES_POSE_PIEGE * AttaquesElementaires.IMAGE), 0.0, 1.0)
	return lerpf(ECHELLE_POSE_PIEGE, 1.0, pose)
