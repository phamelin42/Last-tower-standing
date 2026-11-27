class_name ZonesBombes2D
extends Node2D
## Les zones posées et les bombes à retardement de l'arène 2D, lues dans la vue (`zones`,
## `bombes`) : une zone est un disque au sol de la couleur de son arme, qui s'estompe sur sa fin ;
## une bombe est la dynamite du pack dans un anneau rouge, qui grossit et pulse de plus en plus vite
## jusqu'à son explosion (l'explosion du pack vient de l'événement d'impact, `Effets`). Rien n'est
## gardé d'une vue à l'autre que la taille de départ d'une bombe et la phase de son battement : une
## pose qui quitte la vue disparaît. Le disque et l'anneau sont exactement la zone touchée.

## Opacité du disque d'une zone, et durée de son fondu final (secondes).
const OPACITE_ZONE: float = 0.4
const FONDU_ZONE: float = 0.5
const POINTS_CERCLE: int = 64
const EPAISSEUR_TRAIT: float = 3.0
const EPAISSEUR_CONTOUR: float = 6.0
const GRAVURES: int = 8
## Une bombe passe de 1 fois à `1 + GROSSISSEMENT` fois sa taille de départ, et son battement
## varie de `PULSATION` autour de cette taille, de `BATTEMENT_MIN` à `BATTEMENT_MAX` hertz.
const GROSSISSEMENT: float = 0.7
const PULSATION: float = 0.12
const BATTEMENT_MIN: float = 1.5
const BATTEMENT_MAX: float = 6.0
## Taille de la dynamite à l'écran, en multiple de la région du pack.
const ECHELLE_DYNAMITE: float = 1.3
const OPACITE_SOUFFLE_MIN: float = 0.06
const OPACITE_SOUFFLE_MAX: float = 0.28
## Un allié trop proche de la position d'une pose ne la confond pas : deux bombes se reconnaissent
## d'une vue à l'autre à cette distance (unités).
const TOLERANCE_POSE: float = 1.0
const COULEUR_SOUFFLE := Color(0.92, 0.3, 0.25)
const COULEUR_CONTOUR := Color(0.1, 0.07, 0.15, 0.9)

## Données pour retrouver le type de dégâts de l'arme d'une zone ; sans elles, la couleur du
## tranchant.
var donnees: Donnees = null
## D21 : ni battement ni grossissement ; l'anneau s'emplit à la place.
var mouvement_reduit: bool = false

var _zones: Array[Dictionary] = []
var _bombes: Array[Dictionary] = []
var _ecoule: float = 0.0
var _tex: TexturesEffets = TexturesEffets.new()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func nombre_zones() -> int:
	return _zones.size()


func nombre_bombes() -> int:
	return _bombes.size()


func position_zone(i: int) -> Vector2:
	return Apparence.vers_pixels(_zones[i]["pos"]) if i >= 0 and i < _zones.size() else Vector2.ZERO


func rayon_zone(i: int) -> float:
	return (
		float(_zones[i]["rayon"]) * Apparence.PX_PAR_UNITE if i >= 0 and i < _zones.size() else 0.0
	)


## 0 quand son temps est écoulé, `OPACITE_ZONE` tant qu'il en reste assez, entre deux sur la fin.
func opacite_zone(i: int) -> float:
	if i < 0 or i >= _zones.size():
		return 0.0
	var reste: float = float(_zones[i]["reste"]) - _ecoule
	return OPACITE_ZONE * clampf(reste / FONDU_ZONE, 0.0, 1.0)


func position_bombe(i: int) -> Vector2:
	return (
		Apparence.vers_pixels(_bombes[i]["pos"]) if i >= 0 and i < _bombes.size() else Vector2.ZERO
	)


## Le rayon du souffle, en pixels.
func rayon_bombe(i: int) -> float:
	return (
		float(_bombes[i]["rayon"]) * Apparence.PX_PAR_UNITE
		if i >= 0 and i < _bombes.size()
		else 0.0
	)


## De 0 (posée) à 1 (sur le point d'exploser).
func avancement_bombe(i: int) -> float:
	if i < 0 or i >= _bombes.size():
		return 0.0
	var pic: float = float(_bombes[i]["pic"])
	if not pic > 0.0:
		return 1.0
	return clampf(1.0 - (float(_bombes[i]["reste"]) - _ecoule) / pic, 0.0, 1.0)


## La taille de la bombe sans son battement : 1 au départ, `1 + GROSSISSEMENT` à la fin.
func echelle_bombe_moyenne(i: int) -> float:
	if mouvement_reduit:
		return 1.0 + GROSSISSEMENT * 0.5
	return 1.0 + GROSSISSEMENT * avancement_bombe(i)


func echelle_bombe(i: int) -> float:
	if i < 0 or i >= _bombes.size():
		return 0.0
	var moyenne: float = echelle_bombe_moyenne(i)
	if mouvement_reduit:
		return moyenne
	return moyenne * (1.0 + PULSATION * sin(float(_bombes[i]["phase"])))


## Pose les zones et les bombes de `vue` ; les autres disparaissent.
func afficher(vue: VueArene) -> void:
	_zones.clear()
	for zone: Dictionary in vue.zones.slice(0, VueArene.ZONES_MAX):
		(
			_zones
			. append(
				{
					"pos": zone["pos"],
					"rayon": zone["rayon"],
					"reste": zone["reste"],
					"couleur": _couleur_arme(int(zone["arme"])),
				}
			)
		)
	var avant: Array[Dictionary] = _bombes
	_bombes = []
	var reprises: Dictionary = {}
	for bombe: Dictionary in vue.bombes.slice(0, VueArene.BOMBES_MAX):
		var neuve: Dictionary = {
			"pos": bombe["pos"],
			"rayon": bombe["rayon"],
			"reste": bombe["reste"],
			"pic": bombe["reste"],
			"phase": 0.0,
		}
		for k: int in avant.size():
			var vieille: Dictionary = avant[k]
			var proche: bool = (
				(vieille["pos"] as Vector2).distance_to(neuve["pos"]) <= TOLERANCE_POSE
			)
			if proche and not reprises.has(k):
				reprises[k] = true
				neuve["pic"] = maxf(float(vieille["pic"]), float(bombe["reste"]))
				neuve["phase"] = vieille["phase"]
				break
		_bombes.append(neuve)
	_ecoule = 0.0
	queue_redraw()


func avancer(delta: float) -> void:
	if _zones.is_empty() and _bombes.is_empty():
		return
	_ecoule += delta
	for i: int in _bombes.size():
		var battement: float = lerpf(BATTEMENT_MIN, BATTEMENT_MAX, avancement_bombe(i))
		_bombes[i]["phase"] = float(_bombes[i]["phase"]) + TAU * battement * delta
	queue_redraw()


func vider() -> void:
	_zones.clear()
	_bombes.clear()
	_ecoule = 0.0
	queue_redraw()


func _couleur_arme(arme: int) -> Color:
	var couleur: Color = Effets.COULEURS[Types.TypeDegats.TRANCHANT]
	if donnees == null or arme < 0 or arme >= donnees.ids_catalogue.size():
		return couleur
	var fiche: Dictionary = donnees.armes.get(donnees.ids_catalogue[arme], {})
	var type: int = int(fiche.get("type_degats", Types.TypeDegats.TRANCHANT))
	return Effets.COULEURS[clampi(type, 0, Effets.COULEURS.size() - 1)]


func _draw() -> void:
	for i: int in _zones.size():
		_dessiner_zone(i)
	for i: int in _bombes.size():
		_dessiner_bombe(i)


## Un disque plein, deux anneaux cernés de sombre, huit gravures : lisible sans la couleur.
func _dessiner_zone(i: int) -> void:
	var alpha: float = opacite_zone(i) / OPACITE_ZONE
	if not alpha > 0.0:
		return
	var centre: Vector2 = position_zone(i)
	var rayon: float = rayon_zone(i)
	var couleur: Color = _zones[i]["couleur"]
	draw_circle(centre, rayon, Color(couleur, OPACITE_ZONE * alpha))
	_anneau(centre, rayon, Color(couleur, alpha), alpha)
	_anneau(centre, rayon * 0.6, Color(couleur.lightened(0.4), alpha), alpha)
	for k: int in GRAVURES:
		var sens: Vector2 = Vector2.from_angle(TAU * float(k) / float(GRAVURES))
		draw_line(
			centre + sens * rayon * 0.72,
			centre + sens * rayon * 0.9,
			Color(couleur.lightened(0.4), alpha),
			EPAISSEUR_TRAIT
		)


func _dessiner_bombe(i: int) -> void:
	var centre: Vector2 = position_bombe(i)
	var rayon: float = rayon_bombe(i)
	var avance: float = avancement_bombe(i)
	var plein: float = lerpf(OPACITE_SOUFFLE_MIN, OPACITE_SOUFFLE_MAX, avance)
	draw_circle(centre, rayon, Color(COULEUR_SOUFFLE, plein))
	_anneau(centre, rayon, COULEUR_SOUFFLE, 1.0)
	var taille: Vector2 = Effets.REGION_DYNAMITE.size * ECHELLE_DYNAMITE * echelle_bombe(i)
	var texture: Texture2D = _tex.feuille(Effets.FEUILLE_DYNAMITE)
	draw_texture_rect_region(texture, Rect2(centre - taille * 0.5, taille), Effets.REGION_DYNAMITE)


func _anneau(centre: Vector2, rayon: float, couleur: Color, alpha: float) -> void:
	draw_arc(
		centre,
		rayon,
		0.0,
		TAU,
		POINTS_CERCLE,
		Color(COULEUR_CONTOUR, COULEUR_CONTOUR.a * alpha),
		EPAISSEUR_CONTOUR
	)
	draw_arc(centre, rayon, 0.0, TAU, POINTS_CERCLE, couleur, EPAISSEUR_TRAIT)
