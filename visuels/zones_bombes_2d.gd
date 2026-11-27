class_name ZonesBombes2D
extends Node2D
## Les zones posées et les bombes à retardement de l'arène 2D, lues dans la vue (`zones`,
## `bombes`) : une zone est un disque au sol de la couleur de son arme (le disque dessiné de sa
## carte quand l'arme en a un : braise, ruines), qui s'estompe sur sa fin ; une bombe est la bombe à
## mèche de sa carte dans le souffle rouge, qui grossit et pulse de plus en plus vite jusqu'à son
## explosion, la mèche raccourcissant et l'anneau se fermant (l'explosion vient de l'événement
## d'impact, `Effets`). Rien n'est
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
## La bombe à mèche : sa planche. Ses images (de la posée à la sur le point d'exploser) se comptent
## sur la texture, sa taille à l'écran est l'échelle des planches.
const PLANCHE_BOMBE: String = "bombe_meche"
## Le disque au sol : opacité. Ses images (le cycle de braises) se comptent sur la texture et sa
## cadence est celle de sa planche.
const OPACITE_DISQUE: float = 0.85
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
var _horloge: float = 0.0


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


## La planche de la bombe à mèche.
func planche_bombe() -> String:
	return PLANCHE_BOMBE


## L'image de la bombe à mèche : la première posée, la dernière sur le point d'exploser.
func image_bombe(i: int) -> int:
	var images: int = AttaquesElementaires.images_de(PLANCHE_BOMBE)
	return mini(int(avancement_bombe(i) * images), images - 1)


## La planche du disque au sol de la zone `i`, `""` si son arme n'en a pas (disque tracé).
func disque_zone(i: int) -> String:
	return String(_zones[i]["disque"]) if i >= 0 and i < _zones.size() else ""


## L'image du disque : un cycle de braises, figé en mouvement réduit.
func image_disque(i: int) -> int:
	if mouvement_reduit or i < 0 or i >= _zones.size():
		return 1
	var planche: String = disque_zone(i)
	if planche == "":
		return 1
	var cadence: float = PlanchesEffets.cadence_de(planche)
	return int(_horloge * cadence) % AttaquesElementaires.images_de(planche)


## La taille à l'écran du disque de la zone `i` : sa partie visible couvre exactement le disque de
## la zone (la case est plus grande que ce qui est dessiné dedans).
func taille_disque(i: int) -> Vector2:
	var planche: String = disque_zone(i)
	if planche == "":
		return Vector2.ZERO
	var case_px: Vector2i = AttaquesElementaires.planches()[planche]
	var cote: float = (
		rayon_zone(i) * 2.0 * float(case_px.x) / AttaquesElementaires.visible_de(planche)
	)
	return Vector2(cote, cote)


## Les bombes que la vue dessine : celles dont le projectile est arrivé.
func nombre_bombes_visibles() -> int:
	var n: int = 0
	for bombe: Dictionary in _bombes:
		n += 1 if float(bombe["attente"]) <= 0.0 else 0
	return n


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


## Pose les zones et les bombes de `vue` ; les autres disparaissent. `effets` dit si le projectile
## d'une bombe est encore en vol : elle n'apparaît qu'à son arrivée (sans projectile : de suite).
func afficher(vue: VueArene, effets: Effets = null) -> void:
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
					"disque": _disque_arme(int(zone["arme"])),
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
			"attente": 0.0 if effets == null else effets.vol_restant(bombe["pos"]),
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
				neuve["attente"] = vieille["attente"]
				break
		_bombes.append(neuve)
	_ecoule = 0.0
	queue_redraw()


func avancer(delta: float) -> void:
	if _zones.is_empty() and _bombes.is_empty():
		return
	_ecoule += delta
	_horloge += delta
	for bombe: Dictionary in _bombes:
		bombe["attente"] = maxf(float(bombe["attente"]) - delta, 0.0)
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


## Le disque au sol que l'arme de la zone dessine, `""` sans données ou sans disque.
func _disque_arme(arme: int) -> String:
	if donnees == null or arme < 0 or arme >= donnees.ids_catalogue.size():
		return ""
	return AttaquesElementaires.disque_de(ElementsArmes.de(donnees.ids_catalogue[arme]))


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
	var disque: String = disque_zone(i)
	if disque != "":
		_dessiner_disque(i, centre, alpha)
		_anneau(centre, rayon, Color(couleur, alpha), alpha)
		return
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


## Le disque dessiné de la carte de l'arme, étiré à la taille de la zone.
func _dessiner_disque(i: int, centre: Vector2, alpha: float) -> void:
	var planche: String = disque_zone(i)
	var case_px: Vector2i = AttaquesElementaires.planches()[planche]
	var taille: Vector2 = taille_disque(i)
	var source: Rect2 = Rect2(image_disque(i) * case_px.x, 0.0, case_px.x, case_px.y)
	draw_texture_rect_region(
		AttaquesElementaires.texture_de(planche),
		Rect2(centre - taille * 0.5, taille),
		source,
		Color(1.0, 1.0, 1.0, OPACITE_DISQUE * alpha)
	)


func _dessiner_bombe(i: int) -> void:
	if float(_bombes[i]["attente"]) > 0.0:
		return
	var centre: Vector2 = position_bombe(i)
	var rayon: float = rayon_bombe(i)
	var avance: float = avancement_bombe(i)
	var plein: float = lerpf(OPACITE_SOUFFLE_MIN, OPACITE_SOUFFLE_MAX, avance)
	draw_circle(centre, rayon, Color(COULEUR_SOUFFLE, plein))
	_anneau(centre, rayon, COULEUR_SOUFFLE, 1.0)
	var case_px: Vector2i = AttaquesElementaires.planches()[PLANCHE_BOMBE]
	var taille: Vector2 = Vector2(case_px) * PlanchesEffets.echelle() * echelle_bombe(i)
	var source: Rect2 = Rect2(image_bombe(i) * case_px.x, 0.0, case_px.x, case_px.y)
	draw_texture_rect_region(
		AttaquesElementaires.texture_de(PLANCHE_BOMBE), Rect2(centre - taille * 0.5, taille), source
	)


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
