class_name Etincelles
extends RefCounted
## Les étincelles d'un impact : une petite salve de carrés nets (3-4 px, filtre `nearest`), vers
## l'extérieur, à la couleur de l'arme. Des `CPUParticles2D` en salve unique (`one_shot`, relancée
## par `restart()`), posées chez `hote` et réutilisées. Une fois `PLAFOND` émetteurs en vol, une
## salve de plus est perdue : jamais de nœud créé de plus. La graine suit le compte des salves, donc
## les mêmes événements donnent les mêmes étincelles (captures reproductibles).

const PLAFOND: int = 32
## Un coup simple, puis une zone ou une explosion.
const NOMBRE_COUP: int = 4
const NOMBRE_ZONE: int = 8
const VIE: float = 0.25
const COTE: int = 4
const VITESSE_MIN: float = 50.0
const VITESSE_MAX: float = 110.0
const ECHELLE_MIN: float = 0.75
const GRAINE: int = 20261126
## Une étincelle n'est pas plus opaque qu'un effet : la tour reste lisible.
const ALPHA_MAX: float = 0.85

var _hote: Node2D = null
## `{n: CPUParticles2D, reste: float}` ; `reste` > 0 tant que la salve est en cours.
var _emetteurs: Array[Dictionary] = []
var _nb_salves: int = 0
var _carre: Texture2D = null
var _degrade: Gradient = null


func _init(hote: Node2D) -> void:
	_hote = hote


## Les émetteurs créés (jamais plus de `PLAFOND`).
func emetteurs() -> Array[CPUParticles2D]:
	var liste: Array[CPUParticles2D] = []
	for e: Dictionary in _emetteurs:
		liste.append(e["n"])
	return liste


## Ceux dont la salve est en cours.
func actifs() -> Array[CPUParticles2D]:
	var liste: Array[CPUParticles2D] = []
	for e: Dictionary in _emetteurs:
		if float(e["reste"]) > 0.0:
			liste.append(e["n"])
	return liste


## Lance une salve de `nombre` étincelles en `ou`. `age` : le temps déjà écoulé depuis l'impact.
func lancer(ou: Vector2, nombre: int, couleur: Color, age: float = 0.0) -> void:
	if age >= VIE:
		return
	var emetteur: Dictionary = _emetteur_libre()
	if emetteur.is_empty():
		return
	var particules: CPUParticles2D = emetteur["n"]
	particules.position = ou
	particules.amount = nombre
	particules.color = Color(couleur, ALPHA_MAX)
	_nb_salves += 1
	particules.seed = GRAINE + _nb_salves
	particules.restart()
	particules.emitting = true
	emetteur["reste"] = VIE - age


func avancer(delta: float) -> void:
	for e: Dictionary in _emetteurs:
		if float(e["reste"]) > 0.0:
			e["reste"] = float(e["reste"]) - delta
			if float(e["reste"]) <= 0.0:
				(e["n"] as CPUParticles2D).emitting = false


## Éteint toutes les salves en cours.
func vider() -> void:
	for e: Dictionary in _emetteurs:
		e["reste"] = 0.0
		(e["n"] as CPUParticles2D).emitting = false


func _emetteur_libre() -> Dictionary:
	for e: Dictionary in _emetteurs:
		if float(e["reste"]) <= 0.0:
			return e
	if _emetteurs.size() >= PLAFOND:
		return {}
	var particules := CPUParticles2D.new()
	particules.name = "Etincelles"
	particules.one_shot = true
	particules.emitting = false
	particules.explosiveness = 1.0
	particules.lifetime = VIE
	particules.amount = NOMBRE_COUP
	particules.local_coords = false
	particules.texture = _texture_carre()
	particules.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particules.direction = Vector2.UP
	particules.spread = 180.0
	particules.gravity = Vector2.ZERO
	particules.initial_velocity_min = VITESSE_MIN
	particules.initial_velocity_max = VITESSE_MAX
	particules.scale_amount_min = ECHELLE_MIN
	particules.scale_amount_max = 1.0
	particules.color_ramp = _degrade_etincelles()
	particules.use_fixed_seed = true
	particules.z_index = 1
	_hote.add_child(particules)
	var emetteur := {"n": particules, "reste": 0.0}
	_emetteurs.append(emetteur)
	return emetteur


func _texture_carre() -> Texture2D:
	if _carre == null:
		var image := Image.create(COTE, COTE, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_carre = ImageTexture.create_from_image(image)
	return _carre


## Pleine opacité au départ, transparente à la fin de la vie de la particule.
func _degrade_etincelles() -> Gradient:
	if _degrade == null:
		_degrade = Gradient.new()
		_degrade.set_color(0, Color.WHITE)
		_degrade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	return _degrade
