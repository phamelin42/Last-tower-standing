class_name PlanDecor2D
extends RefCounted
## Disposition du terrain et du décor d'une arène 2D, tirée d'une graine : quelles cases sont de la
## terre, quelle tuile du pack va sur chacune, où poser chaque objet. Purement visuelle et sans
## nœud : `Decor2D` la dessine, les tests la lisent. Même graine, même plan ; deux graines, deux
## plans. Tout est en pixels du monde (la tour est en `(0, 0)`, une case de terre mesure `CASE`).

## Une tuile du pack fait 64 px ; affichée à ×2 comme les unités et la tour, elle en fait 128.
const CASE: int = 128
const ECHELLE: float = 2.0
## Le cercle d'apparition, en pixels du monde (1 300 unités à 0,5 px par unité).
const RAYON_CERCLE: float = CameraArene2D.RAYON_APPARITION * Apparence2D.PX_PAR_UNITE
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

const FEUILLE_TERRAIN := "Terrain/Ground/Tilemap_Flat.png"
const FEUILLE_EAU := "Terrain/Water/Water.png"
const FEUILLE_ECUME := "Terrain/Water/Foam/Foam.png"
const CASE_ECUME: int = 192
const IMAGES_ECUME: int = 8
## Le contenu de l'écume dans sa case de 192 px, toutes images confondues (centré sur la case) :
## on ne dessine que lui, le reste est transparent et coûterait du remplissage pour rien.
const BOITE_ECUME := Rect2(53, 53, 86, 86)
## Le retournement d'une tuile intérieure (bits de `TileSetAtlasSource`).
const RETOURNEMENTS: Array[int] = [0, 4096, 8192, 12288]

## Les images du pack. `cellule` : taille d'une image dans la feuille ; `origine` : coin de la
## première image ; `ligne` : rangée de l'animation ; `images` : combien de pas ; `boite` : le
## contenu visible dans une cellule, toutes images confondues (seul lui est dessiné) ; `pieds` : le point de la cellule posé sur la position de
## l'objet ; `haut` : un objet qui peut cacher quelqu'un, donc jamais dans la zone de marche.
const TYPES: Dictionary = {
	"sapin":
	{
		"fichier": "Resources/Trees/Tree.png",
		"cellule": Vector2i(192, 192),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 4,
		"boite": Rect2(42, 4, 112, 174),
		"pieds": Vector2(98, 172),
		"echelle": 2.0,
		"categorie": "sapin",
		"haut": true,
	},
	"souche":
	{
		"fichier": "Resources/Trees/Tree.png",
		"cellule": Vector2i(192, 192),
		"origine": Vector2i(0, 0),
		"ligne": 2,
		"images": 1,
		"boite": Rect2(79, 146, 36, 30),
		"pieds": Vector2(97, 172),
		"echelle": 2.0,
		"categorie": "divers",
		"haut": true,
	},
	"maison_bleue":
	{
		"fichier": "Factions/Knights/Buildings/House/House_Blue.png",
		"cellule": Vector2i(128, 192),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(10, 24, 108, 148),
		"pieds": Vector2(64, 168),
		"echelle": 2.0,
		"categorie": "maison",
		"haut": true,
	},
	"maison_rouge":
	{
		"fichier": "Factions/Knights/Buildings/House/House_Red.png",
		"cellule": Vector2i(128, 192),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(10, 24, 108, 148),
		"pieds": Vector2(64, 168),
		"echelle": 2.0,
		"categorie": "maison",
		"haut": true,
	},
	"maison_jaune":
	{
		"fichier": "Factions/Knights/Buildings/House/House_Yellow.png",
		"cellule": Vector2i(128, 192),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(10, 24, 108, 148),
		"pieds": Vector2(64, 168),
		"echelle": 2.0,
		"categorie": "maison",
		"haut": true,
	},
	"maison_violette":
	{
		"fichier": "Factions/Knights/Buildings/House/House_Purple.png",
		"cellule": Vector2i(128, 192),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(10, 24, 108, 148),
		"pieds": Vector2(64, 168),
		"echelle": 2.0,
		"categorie": "maison",
		"haut": true,
	},
	"maison_gobelin":
	{
		"fichier": "Factions/Goblins/Buildings/Wood_House/Goblin_House.png",
		"cellule": Vector2i(128, 192),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(7, 26, 113, 145),
		"pieds": Vector2(64, 168),
		"echelle": 2.0,
		"categorie": "maison",
		"haut": true,
	},
	"mine":
	{
		"fichier": "Resources/Gold Mine/GoldMine_Active.png",
		"cellule": Vector2i(192, 128),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(12, 5, 169, 121),
		"pieds": Vector2(96, 116),
		"echelle": 2.0,
		"categorie": "mine",
		"haut": true,
	},
	# Plus petit que le mouton du convoi (×2 avec son sac d'or) : on ne les confond pas.
	"mouton":
	{
		"fichier": "Resources/Sheep/HappySheep_Idle.png",
		"cellule": Vector2i(128, 128),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 8,
		"boite": Rect2(42, 48, 46, 38),
		"pieds": Vector2(64, 84),
		"echelle": 1.5,
		"categorie": "mouton",
		"haut": true,
	},
	"champignon_geant":
	{
		"fichier": "Deco/03.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(14, 12, 38, 37),
		"pieds": Vector2(33, 46),
		"echelle": 2.0,
		"categorie": "divers",
		"haut": true,
	},
	"rocher":
	{
		"fichier": "Deco/06.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(12, 15, 44, 34),
		"pieds": Vector2(34, 46),
		"echelle": 2.0,
		"categorie": "rocher",
		"haut": true,
	},
	"buisson_petit":
	{
		"fichier": "Deco/07.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(16, 21, 31, 22),
		"pieds": Vector2(31, 42),
		"echelle": 2.0,
		"categorie": "buisson",
		"haut": true,
	},
	"buisson_moyen":
	{
		"fichier": "Deco/08.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(11, 17, 42, 32),
		"pieds": Vector2(32, 47),
		"echelle": 2.0,
		"categorie": "buisson",
		"haut": true,
	},
	"buisson_grand":
	{
		"fichier": "Deco/09.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(2, 11, 61, 42),
		"pieds": Vector2(32, 51),
		"echelle": 2.0,
		"categorie": "buisson",
		"haut": true,
	},
	"citrouille_petite":
	{
		"fichier": "Deco/12.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(11, 12, 40, 39),
		"pieds": Vector2(31, 49),
		"echelle": 2.0,
		"categorie": "divers",
		"haut": true,
	},
	"citrouille_grande":
	{
		"fichier": "Deco/13.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(5, 10, 56, 45),
		"pieds": Vector2(33, 53),
		"echelle": 2.0,
		"categorie": "divers",
		"haut": true,
	},
	"panneau_crane":
	{
		"fichier": "Deco/16.png",
		"cellule": Vector2i(64, 128),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(7, 3, 52, 101),
		"pieds": Vector2(32, 100),
		"echelle": 2.0,
		"categorie": "divers",
		"haut": true,
	},
	"panneau_fleche":
	{
		"fichier": "Deco/17.png",
		"cellule": Vector2i(64, 128),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(2, 15, 59, 90),
		"pieds": Vector2(32, 102),
		"echelle": 2.0,
		"categorie": "divers",
		"haut": true,
	},
	"epouvantail":
	{
		"fichier": "Deco/18.png",
		"cellule": Vector2i(192, 192),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(54, 48, 87, 121),
		"pieds": Vector2(97, 166),
		"echelle": 2.0,
		"categorie": "divers",
		"haut": true,
	},
	# Décor plat : à ras du sol, il se pose aussi dans la zone de marche, sous les ennemis.
	"champignon_petit":
	{
		"fichier": "Deco/01.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(25, 24, 17, 19),
		"pieds": Vector2(33, 41),
		"echelle": 2.0,
		"categorie": "plat",
		"haut": false,
	},
	"champignon_moyen":
	{
		"fichier": "Deco/02.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(21, 20, 26, 27),
		"pieds": Vector2(34, 45),
		"echelle": 2.0,
		"categorie": "plat",
		"haut": false,
	},
	"caillou_petit":
	{
		"fichier": "Deco/04.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(24, 19, 20, 18),
		"pieds": Vector2(34, 36),
		"echelle": 2.0,
		"categorie": "plat",
		"haut": false,
	},
	"caillou_moyen":
	{
		"fichier": "Deco/05.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(18, 18, 29, 22),
		"pieds": Vector2(32, 38),
		"echelle": 2.0,
		"categorie": "plat",
		"haut": false,
	},
	"touffe_petite":
	{
		"fichier": "Deco/10.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(22, 23, 22, 23),
		"pieds": Vector2(33, 45),
		"echelle": 2.0,
		"categorie": "plat",
		"haut": false,
	},
	"touffe_moyenne":
	{
		"fichier": "Deco/11.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(20, 15, 32, 35),
		"pieds": Vector2(36, 48),
		"echelle": 2.0,
		"categorie": "plat",
		"haut": false,
	},
	"os_long":
	{
		"fichier": "Deco/14.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(15, 16, 36, 31),
		"pieds": Vector2(33, 45),
		"echelle": 2.0,
		"categorie": "plat",
		"haut": false,
	},
	"os_court":
	{
		"fichier": "Deco/15.png",
		"cellule": Vector2i(64, 64),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(24, 20, 24, 24),
		"pieds": Vector2(36, 42),
		"echelle": 2.0,
		"categorie": "plat",
		"haut": false,
	},
	# Les trois touffes d'herbe dessinées au bord de la feuille du terrain.
	"herbe_hautes":
	{
		"fichier": "Terrain/Ground/Tilemap_Flat.png",
		"cellule": Vector2i(58, 21),
		"origine": Vector2i(258, 43),
		"ligne": 0,
		"images": 1,
		"boite": Rect2(0, 0, 58, 21),
		"pieds": Vector2(29, 19),
		"echelle": 2.0,
		"categorie": "plat",
		"haut": false,
	},
	# Rochers qui dépassent de l'eau, avec leurs ondes.
	"rocher_eau_1":
	{
		"fichier": "Terrain/Water/Rocks/Rocks_01.png",
		"cellule": Vector2i(128, 128),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 8,
		"boite": Rect2(46, 54, 32, 23),
		"pieds": Vector2(62, 70),
		"echelle": 2.0,
		"categorie": "eau",
		"haut": false,
	},
	"rocher_eau_2":
	{
		"fichier": "Terrain/Water/Rocks/Rocks_02.png",
		"cellule": Vector2i(128, 128),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 8,
		"boite": Rect2(39, 53, 47, 34),
		"pieds": Vector2(63, 82),
		"echelle": 2.0,
		"categorie": "eau",
		"haut": false,
	},
	"rocher_eau_3":
	{
		"fichier": "Terrain/Water/Rocks/Rocks_03.png",
		"cellule": Vector2i(128, 128),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 8,
		"boite": Rect2(29, 35, 75, 56),
		"pieds": Vector2(66, 85),
		"echelle": 2.0,
		"categorie": "eau",
		"haut": false,
	},
	"rocher_eau_4":
	{
		"fichier": "Terrain/Water/Rocks/Rocks_04.png",
		"cellule": Vector2i(128, 128),
		"origine": Vector2i(0, 0),
		"ligne": 0,
		"images": 8,
		"boite": Rect2(20, 34, 91, 65),
		"pieds": Vector2(65, 94),
		"echelle": 2.0,
		"categorie": "eau",
		"haut": false,
	},
}

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
const NB_SAPINS: int = 90
const NB_GROUPES_SAPINS: int = 8
const NB_BUISSONS: int = 30
const NB_ROCHERS: int = 10
const NB_DIVERS: int = 14
const NB_PLATS_ZONE: int = 80
const NB_PLATS_DEHORS: int = 110
const NB_ROCHERS_EAU: int = 14

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
	return int((TYPES[type] as Dictionary)["images"]) > 1


## Vrai si un rectangle (pixels du monde) touche la zone de marche.
static func touche_la_zone(rect: Rect2) -> bool:
	var proche := Vector2(
		clampf(0.0, rect.position.x, rect.end.x), clampf(0.0, rect.position.y, rect.end.y)
	)
	return proche.length() < RAYON_ZONE


## Où tombe, dans le monde, le contenu visible d'un objet posé par ses pieds.
static func rect_de(type: String, pieds: Vector2, miroir: bool) -> Rect2:
	var t: Dictionary = TYPES[type]
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


static func generer(graine_voulue: int) -> PlanDecor2D:
	var plan := PlanDecor2D.new()
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
	return Vector2i(floori(p.x / float(CASE)), floori(p.y / float(CASE)))


func _centre_de(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * float(CASE)


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
	var t: Dictionary = TYPES[type]
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
	var t: Dictionary = TYPES[type]
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
			* float(CASE)
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
					"phase": rng.randi_range(0, IMAGES_ECUME - 1),
				}
			)
		)
		poses += 1
