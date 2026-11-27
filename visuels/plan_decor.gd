class_name PlanDecor
extends RefCounted
## Disposition du terrain et du décor d'une arène 2D, tirée d'une graine : quelles cases sont de la
## terre, quelle tuile du pack va sur chacune, où poser chaque objet. Purement visuelle et sans
## nœud : `Decor` la dessine, les tests la lisent. Même graine, même plan ; deux graines, deux
## plans. Tout est en pixels du monde (la tour est en `(0, 0)`, une case de terre mesure `case`).

const ECHELLE: float = 2.0
## Le cercle d'apparition, en pixels du monde (1 300 unités à 0,5 px par unité).
const RAYON_CERCLE: float = CameraArene.RAYON_APPARITION * Apparence.PX_PAR_UNITE
## Zone de marche des ennemis, cercle compris et un peu au-delà : aucun objet haut n'y touche.
const RAYON_ZONE: float = RAYON_CERCLE + 50.0
## Dans la zone de marche, le décor plat laisse la tour et le trait du cercle nets.
const RAYON_TOUR_LIBRE: float = 180.0
const LARGEUR_CERCLE_LIBRE: float = 45.0
## Toute case dont le centre est à moins de ce rayon est de la terre : l'arène n'a jamais de rivage
## en son sein.
const RAYON_TERRE_FORCEE: float = 1000.0
## Étendue de la grille de cases, de part et d'autre de la tour.
const DEMI_COLONNES: int = 22
const DEMI_LIGNES: int = 16

## Le retournement d'une tuile intérieure (bits de `TileSetAtlasSource`).
const RETOURNEMENTS: Array[int] = [0, 4096, 8192, 12288]

const MAISONS: Array[String] = [
	"maison_bleue", "maison_rouge", "maison_jaune", "maison_violette", "maison_gobelin"
]
const BUISSONS: Array[String] = ["buisson_petit", "buisson_moyen", "buisson_grand"]
const ROCHERS_EAU: Array[String] = ["rocher_eau_1", "rocher_eau_2", "rocher_eau_3", "rocher_eau_4"]
## Décor plat, avec des poids : plus de touffes que de pierres, peu d'os.
const PLATS: Array[String] = [
	"herbe_hautes",
	"herbe_hautes",
	"herbe_hautes",
	"herbe_hautes",
	"touffe_petite",
	"touffe_petite",
	"touffe_petite",
	"touffe_moyenne",
	"touffe_moyenne",
	"champignon_petit",
	"champignon_moyen",
	"caillou_petit",
	"caillou_petit",
	"caillou_moyen",
	"os_court",
]
const NB_SAPINS: int = 70
const NB_GROUPES_SAPINS: int = 8
const NB_BUISSONS: int = 30
const NB_ROCHERS: int = 10
const NB_DIVERS: int = 14
const NB_PLATS_ZONE: int = 80
const NB_PLATS_DEHORS: int = 110
const NB_ROCHERS_EAU: int = 14

## Une tuile du pack fait 64 px ; affichée à ×2 comme les unités et la tour, elle en fait 128.
static var case: int = int(_decor().get("case", 128))
## Feuilles, cases et images du pack : `data/assets.json` (`decor`), pour qu'un autre pack ne
## demande que de remplacer les fichiers.
static var feuille_terrain: String = str(_decor().get("feuille_terrain", ""))
static var feuille_eau: String = str(_decor().get("feuille_eau", ""))
static var feuille_ecume: String = str(_ecume().get("feuille", ""))
static var case_ecume: int = int(_ecume().get("case", 0))
static var images_ecume: int = int(_ecume().get("images", 0))
## Le contenu de l'écume dans sa case de 192 px, toutes images confondues (centré sur la case) :
## on ne dessine que lui, le reste est transparent et coûterait du remplissage pour rien.
static var boite_ecume: Rect2 = _ecume().get("boite", Rect2())
## Les images du pack. `cellule` : taille d'une image dans la feuille ; `origine` : coin de la
## première image ; `ligne` : rangée de l'animation ; `images` : combien de pas ; `boite` : le
## contenu visible dans une cellule, toutes images confondues (seul lui est dessiné) ; `pieds` :
## le point de la cellule posé sur la position de l'objet ; `haut` : un objet qui peut cacher
## quelqu'un, donc jamais dans la zone de marche.
static var types: Dictionary = _decor().get("types", {})

## Cases de terre : `Vector2i` → `true`.
var terre: Dictionary = {}
## Une entrée par case de terre : `{cellule, atlas, retournement}`.
var tuiles: Array[Dictionary] = []
## Cases de terre qui touchent l'eau : l'écume se pose dessous.
var ecume: Array[Vector2i] = []
## `{type, pieds, rect, haut, eau, miroir, phase}`.
var objets: Array[Dictionary] = []
var graine: int = 0

var _bases: Array[Rect2] = []
var _protege: Array[Rect2] = []
## Objets hauts posés : `{rect, y, anime}`, pour garder les animés devant les immobiles.
var _hauts_poses: Array[Dictionary] = []


## Seed d'une arène : celle de la partie mêlée au numéro du joueur, pour que chaque arène ait son
## décor et qu'il ne change pas en cours de partie.
static func graine_arene(graine_partie: int, numero: int) -> int:
	return ("decor-%d-%d" % [graine_partie, numero]).hash()


## Quelle tuile de l'herbe du pack va sur une case, selon ses quatre voisines (vrai = de la
## terre). Les bords et les coins arrondis du pack ; la grande herbe au milieu.
static func tuile_pour(nord: bool, est: bool, sud: bool, ouest: bool) -> Vector2i:
	if nord and est and sud and ouest:
		return Vector2i(1, 1)
	if not nord and est and sud and ouest:
		return Vector2i(1, 0)
	if nord and est and not sud and ouest:
		return Vector2i(1, 2)
	if nord and not est and sud and ouest:
		return Vector2i(2, 1)
	if nord and est and sud and not ouest:
		return Vector2i(0, 1)
	if not nord and est and sud and not ouest:
		return Vector2i(0, 0)
	if not nord and not est and sud and ouest:
		return Vector2i(2, 0)
	if nord and est and not sud and not ouest:
		return Vector2i(0, 2)
	if nord and not est and not sud and ouest:
		return Vector2i(2, 2)
	# Bande horizontale (est et ouest seulement) puis verticale (nord et sud seulement).
	if not nord and est and not sud and ouest:
		return Vector2i(1, 3)
	if nord and not est and sud and not ouest:
		return Vector2i(3, 1)
	# Bouts de bande : une seule voisine.
	if not nord and not est and sud and not ouest:
		return Vector2i(3, 0)
	if nord and not est and not sud and not ouest:
		return Vector2i(3, 2)
	if not nord and est and not sud and not ouest:
		return Vector2i(0, 3)
	if not nord and not est and not sud and ouest:
		return Vector2i(2, 3)
	return Vector2i(3, 3)


## Un type animé (sapin, mouton, rocher d'eau) est un sprite à part ; les autres sont composés
## dans l'image du sol.
static func est_anime(type: String) -> bool:
	return int((types[type] as Dictionary)["images"]) > 1


## Vrai si un rectangle (pixels du monde) touche la zone de marche.
static func touche_la_zone(rect: Rect2) -> bool:
	var proche := Vector2(
		clampf(0.0, rect.position.x, rect.end.x), clampf(0.0, rect.position.y, rect.end.y)
	)
	return proche.length() < RAYON_ZONE


## Où tombe, dans le monde, le contenu visible d'un objet posé par ses pieds.
static func rect_de(type: String, pieds: Vector2, miroir: bool) -> Rect2:
	var t: Dictionary = types[type]
	var boite: Rect2 = t["boite"]
	var origine: Vector2 = t["pieds"]
	var e: float = float(t["echelle"])
	var gauche: float = (boite.position.x - origine.x) * e
	var droite: float = gauche + boite.size.x * e
	if miroir:
		var g: float = -droite
		droite = -gauche
		gauche = g
	var haut: float = (boite.position.y - origine.y) * e
	return Rect2(pieds.x + gauche, pieds.y + haut, droite - gauche, boite.size.y * e)


static func generer(graine_voulue: int) -> PlanDecor:
	var plan := PlanDecor.new()
	plan.graine = graine_voulue
	var rng := RandomNumberGenerator.new()
	rng.seed = graine_voulue
	plan._former_la_terre(rng)
	plan._tuiler(rng)
	plan._poser_les_maisons_et_la_mine(rng)
	plan._poser_les_moutons(rng)
	plan._poser_les_sapins(rng)
	plan._poser_le_reste(rng)
	plan._poser_les_plats(rng)
	plan._poser_les_rochers_d_eau(rng)
	return plan


func _cellule_de(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / float(case)), floori(p.y / float(case)))


func _centre_de(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * float(case)


## Un ovale de rayon irrégulier : trois harmoniques tirées de la graine donnent à chaque arène son
## rivage. Le disque de marche est de la terre quoi qu'il arrive.
func _former_la_terre(rng: RandomNumberGenerator) -> void:
	var ax: float = rng.randf_range(1650.0, 1900.0)
	var ay: float = rng.randf_range(1150.0, 1300.0)
	var amplitudes: Array[float] = []
	var phases: Array[float] = []
	for k: int in 3:
		amplitudes.append(rng.randf_range(0.02, 0.07))
		phases.append(rng.randf() * TAU)
	for j: int in range(-DEMI_LIGNES, DEMI_LIGNES):
		for i: int in range(-DEMI_COLONNES, DEMI_COLONNES):
			var centre := _centre_de(Vector2i(i, j))
			var est_terre: bool = centre.length() <= RAYON_TERRE_FORCEE
			if not est_terre:
				var d := Vector2(centre.x / ax, centre.y / ay)
				var theta: float = d.angle()
				var limite: float = 1.0
				for k: int in 3:
					limite += amplitudes[k] * cos(float(k + 2) * theta + phases[k])
				est_terre = d.length() < limite
			if est_terre:
				terre[Vector2i(i, j)] = true
	# Un étang d'une seule case entouré de terre ferait un trou ridicule : on le comble.
	var trous: Array[Vector2i] = []
	for j: int in range(-DEMI_LIGNES, DEMI_LIGNES):
		for i: int in range(-DEMI_COLONNES, DEMI_COLONNES):
			var c := Vector2i(i, j)
			if not terre.has(c) and _voisines(c) == 4:
				trous.append(c)
	for c: Vector2i in trous:
		terre[c] = true


## Nombre de voisines de terre (quatre côtés).
func _voisines(c: Vector2i) -> int:
	var n: int = 0
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if terre.has(c + d):
			n += 1
	return n


func _tuiler(rng: RandomNumberGenerator) -> void:
	for cle: Variant in terre:
		var c: Vector2i = cle
		var nord: bool = terre.has(c + Vector2i(0, -1))
		var est: bool = terre.has(c + Vector2i(1, 0))
		var sud: bool = terre.has(c + Vector2i(0, 1))
		var ouest: bool = terre.has(c + Vector2i(-1, 0))
		var atlas := tuile_pour(nord, est, sud, ouest)
		var retournement: int = 0
		if atlas == Vector2i(1, 1):
			retournement = RETOURNEMENTS[rng.randi_range(0, RETOURNEMENTS.size() - 1)]
		else:
			ecume.append(c)
		tuiles.append({"cellule": c, "atlas": atlas, "retournement": retournement})


## Tous les pieds d'un objet haut reposent sur de la terre sans rivage dans le voisinage : un sapin
## ne pend pas au-dessus de l'eau.
func _terre_autour(pieds: Vector2, rayon_cases: int) -> bool:
	var c := _cellule_de(pieds)
	for dj: int in range(-rayon_cases, rayon_cases + 1):
		for di: int in range(-rayon_cases, rayon_cases + 1):
			if not terre.has(c + Vector2i(di, dj)):
				return false
	return true


func _base_de(type: String, pieds: Vector2, rect: Rect2) -> Rect2:
	var t: Dictionary = types[type]
	if not bool(t["haut"]):
		return rect
	var e: float = float(t["echelle"])
	var largeur: float = minf(rect.size.x * 0.45, 130.0)
	return Rect2(pieds.x - largeur * 0.5, pieds.y - 20.0 * e, largeur, 22.0 * e)


func _libre(base: Rect2, rect: Rect2, proteger: bool) -> bool:
	var marge: Rect2 = base.grow(10.0)
	for autre: Rect2 in _bases:
		if autre.intersects(marge):
			return false
	if not proteger:
		for abrite: Rect2 in _protege:
			if abrite.intersects(rect):
				return false
	return true


## Les immobiles sont composés dans le sol, sous tous les sprites : un animé qui en recouvre un
## doit donc se trouver devant lui (pieds plus au sud), comme le ferait le tri en profondeur.
func _devant_les_immobiles(type: String, pieds: Vector2, rect: Rect2) -> bool:
	var anime: bool = est_anime(type)
	for autre: Dictionary in _hauts_poses:
		if bool(autre["anime"]) == anime or not rect.intersects(autre["rect"]):
			continue
		var y_anime: float = pieds.y if anime else float(autre["y"])
		var y_immobile: float = float(autre["y"]) if anime else pieds.y
		if y_anime <= y_immobile:
			return false
	return true


## Pose un objet s'il y a la place : terre dessous, hors de la zone de marche s'il est haut, loin
## des autres. Renvoie vrai si posé.
func _poser(
	type: String, pieds: Vector2, rng: RandomNumberGenerator, proteger: bool = false
) -> bool:
	var t: Dictionary = types[type]
	var haut: bool = bool(t["haut"])
	var miroir: bool = rng.randf() < 0.5
	var rect := rect_de(type, pieds, miroir)
	if haut and touche_la_zone(rect):
		return false
	if not _terre_autour(pieds, 1):
		return false
	var base := _base_de(type, pieds, rect)
	if not _libre(base, rect, proteger):
		return false
	if haut and not _devant_les_immobiles(type, pieds, rect):
		return false
	_bases.append(base)
	if haut:
		_hauts_poses.append({"rect": rect, "y": pieds.y, "anime": est_anime(type)})
	if proteger:
		_protege.append(rect.grow(24.0))
	(
		objets
		. append(
			{
				"type": type,
				"pieds": pieds,
				"rect": rect,
				"haut": haut,
				"eau": String(t["categorie"]) == "eau",
				"miroir": miroir,
				"phase": rng.randi_range(0, int(t["images"]) - 1),
			}
		)
	)
	return true


## Un point au hasard autour de la zone de marche, à `mini`–`maxi` pixels de la tour.
func _point_en_couronne(rng: RandomNumberGenerator, mini: float, maxi: float) -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(mini, maxi)


func _essayer(
	type: String, rng: RandomNumberGenerator, mini: float, maxi: float, proteger: bool = false
) -> bool:
	for essai: int in 300:
		if _poser(type, _point_en_couronne(rng, mini, maxi), rng, proteger):
			return true
	return false


func _poser_les_maisons_et_la_mine(rng: RandomNumberGenerator) -> void:
	var choix: Array[String] = MAISONS.duplicate()
	# Mélange par tirage : deux maisons du pack et une troisième, du pack ou gobeline.
	for fois: int in 3:
		var rang: int = rng.randi_range(0, choix.size() - 1)
		_essayer(choix[rang], rng, 900.0, 1600.0, true)
		choix.remove_at(rang)
	_essayer("mine", rng, 1000.0, 1600.0, true)


func _poser_les_moutons(rng: RandomNumberGenerator) -> void:
	for groupe: int in 2:
		for essai: int in 200:
			var centre := _point_en_couronne(rng, 900.0, 1500.0)
			var voulus: int = rng.randi_range(3, 4)
			var poses: int = 0
			for mouton: int in voulus * 6:
				if poses == voulus:
					break
				var p := centre + Vector2(rng.randfn(0.0, 110.0), rng.randfn(0.0, 70.0))
				if _poser("mouton", p, rng):
					poses += 1
			if poses >= 3:
				break


func _poser_les_sapins(rng: RandomNumberGenerator) -> void:
	var centres: Array[Vector2] = []
	for k: int in NB_GROUPES_SAPINS:
		centres.append(_point_en_couronne(rng, 850.0, 1700.0))
	var poses: int = 0
	var essais: int = 0
	while poses < NB_SAPINS and essais < NB_SAPINS * 60:
		essais += 1
		var p: Vector2
		if rng.randf() < 0.7:
			var centre: Vector2 = centres[rng.randi_range(0, centres.size() - 1)]
			p = centre + Vector2(rng.randfn(0.0, 330.0), rng.randfn(0.0, 240.0))
		else:
			p = _point_en_couronne(rng, 800.0, 2000.0)
		if _poser("sapin", p, rng):
			poses += 1


func _poser_le_reste(rng: RandomNumberGenerator) -> void:
	for i: int in NB_BUISSONS:
		_essayer(BUISSONS[rng.randi_range(0, BUISSONS.size() - 1)], rng, 780.0, 1900.0)
	for i: int in NB_ROCHERS:
		_essayer("rocher", rng, 780.0, 1900.0)
	_essayer("epouvantail", rng, 800.0, 1100.0)
	_essayer("panneau_crane", rng, 780.0, 1100.0)
	_essayer("panneau_fleche", rng, 780.0, 1100.0)
	var divers: Array[String] = [
		"champignon_geant", "citrouille_petite", "citrouille_grande", "souche"
	]
	for i: int in NB_DIVERS:
		_essayer(divers[rng.randi_range(0, divers.size() - 1)], rng, 780.0, 1900.0)


## Du décor plat, d'abord dans la zone de marche (sous les ennemis, sans toucher à la tour ni au
## trait du cercle), puis tout autour.
func _poser_les_plats(rng: RandomNumberGenerator) -> void:
	var poses: int = 0
	var essais: int = 0
	while poses < NB_PLATS_ZONE and essais < NB_PLATS_ZONE * 40:
		essais += 1
		var r: float = sqrt(rng.randf()) * RAYON_ZONE
		if (
			r < RAYON_TOUR_LIBRE
			or absf(r - RAYON_CERCLE) < LARGEUR_CERCLE_LIBRE
			or r >= RAYON_ZONE - 5.0
		):
			continue
		var p := Vector2.from_angle(rng.randf() * TAU) * r
		if _poser(PLATS[rng.randi_range(0, PLATS.size() - 1)], p, rng):
			poses += 1
	poses = 0
	essais = 0
	while poses < NB_PLATS_DEHORS and essais < NB_PLATS_DEHORS * 40:
		essais += 1
		var p := Vector2(rng.randf_range(-2300.0, 2300.0), rng.randf_range(-1500.0, 1500.0))
		if p.length() <= RAYON_ZONE:
			continue
		if _poser(PLATS[rng.randi_range(0, PLATS.size() - 1)], p, rng):
			poses += 1


## Des rochers dans l'eau, à une case au moins du rivage, là où l'écume les entourerait.
func _poser_les_rochers_d_eau(rng: RandomNumberGenerator) -> void:
	var candidates: Array[Vector2i] = []
	for j: int in range(-DEMI_LIGNES, DEMI_LIGNES):
		for i: int in range(-DEMI_COLONNES, DEMI_COLONNES):
			var c := Vector2i(i, j)
			if terre.has(c) or _voisines(c) > 0:
				continue
			var proche: bool = false
			for dj: int in range(-2, 3):
				for di: int in range(-2, 3):
					if terre.has(c + Vector2i(di, dj)):
						proche = true
			if proche:
				candidates.append(c)
	var poses: int = 0
	var essais: int = 0
	while poses < NB_ROCHERS_EAU and essais < NB_ROCHERS_EAU * 30 and not candidates.is_empty():
		essais += 1
		var c: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var p := (
			(Vector2(c) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8)))
			* float(case)
		)
		var type: String = ROCHERS_EAU[rng.randi_range(0, ROCHERS_EAU.size() - 1)]
		var miroir: bool = rng.randf() < 0.5
		var rect := rect_de(type, p, miroir)
		# Le rocher ne déborde pas sur la terre.
		var sur_terre: bool = false
		for coin: Vector2 in [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]:
			if terre.has(_cellule_de(coin)):
				sur_terre = true
		if sur_terre or not _libre(rect, rect, true):
			continue
		_bases.append(rect)
		(
			objets
			. append(
				{
					"type": type,
					"pieds": p,
					"rect": rect,
					"haut": false,
					"eau": true,
					"miroir": miroir,
					"phase": rng.randi_range(0, images_ecume - 1),
				}
			)
		)
		poses += 1


static func _decor() -> Dictionary:
	return Assets.typee("decor")


static func _ecume() -> Dictionary:
	var e: Dictionary = _decor().get("ecume", {})
	return e
