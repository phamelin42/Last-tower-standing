class_name VitrineEffets
extends Node2D
## Vitrine des effets de combat, à capturer par `tools/capturer.sh` : rejoue en boucle tout ce que
## `Effets` sait dessiner, sans simulation ni réseau, sur un fond uni. Aucun texte affiché.
##
## Disposition (écran de 1152 × 648, une cellule de 128 × 108 px, tour à gauche et cible à droite) :
## - une ligne par type de dégâts, de haut en bas : tranchant, perçant, magique, siège, chaos ;
## - une colonne par genre d'arme, de gauche à droite : aucun, cible unique, zone, rebond, aura,
##   onde, barrage, piège, mine (l'ordre de `VueArene.GENRES_ARME`) ;
## - la dernière ligne, de gauche à droite : les statuts poison, brûlure, givre, étourdissement et
##   vol de vie (`VueArene.STATUTS_ARME`, sans « aucun »), puis une explosion de mort et
##   l'absorption par la mana.
## Chaque cycle (`PERIODE`) tire les cellules, puis déclenche les impacts `DELAI_IMPACT` plus tard.
## Le temps ne vient que de `_process(delta)` : à cadence fixe, deux captures sont identiques.

const FOND := Color(0.24, 0.38, 0.27)
const COULEUR_TOUR := Color(0.9, 0.85, 0.6, 0.6)
const SPRITE_CIBLE := "guerrier_rouge"
## Échelle de la cible : assez petite pour tenir dans une cellule sans cacher les effets.
const ECHELLE_CIBLE: float = 0.35

const LARGEUR_ECRAN: float = 1152.0
const HAUTEUR_ECRAN: float = 648.0
const COLONNES: int = 9
const LIGNES: int = 6
const LARGEUR_CELLULE: float = LARGEUR_ECRAN / COLONNES
const HAUTEUR_CELLULE: float = HAUTEUR_ECRAN / LIGNES
## Position de la tour et de la cible dans une cellule, en pixels depuis son coin haut gauche.
const TOUR_DANS_CELLULE := Vector2(16.0, 54.0)
const CIBLE_DANS_CELLULE := Vector2(96.0, 54.0)
const RAYON_TOUR_PX: float = 4.0
## Rayon des genres de zone, en unités de jeu : 90 unités font 90 px de diamètre à l'écran.
const RAYON_ZONE: float = 90.0
## Type de dégâts des cellules de statut : le magique, dont l'impact (le halo) reste discret.
const TYPE_STATUT: int = Types.TypeDegats.MAGIQUE
const LIGNE_SPECIALE: int = LIGNES - 1
const COLONNE_EXPLOSION: int = 5
const COLONNE_ABSORPTION: int = 6

const PERIODE: float = 1.5
const DELAI_IMPACT: float = 0.25
const GRAINE: int = 20261126

const CLE_EXPLOSION := "explosion"
const CLE_ABSORPTION := "absorption"

## Nombre d'effets créés par cellule depuis le début (clés de `cle_genre`, `cle_statut`, etc.).
var crees: Dictionary = {}
## Cycles entièrement rejoués (le tir et l'impact ont eu lieu).
var cycles: int = 0
## Plus grand nombre d'effets vivants vu depuis le début.
var pic_vivants: int = 0
var effets: Effets = null

var _temps: float = 0.0
var _impacts_faits: bool = false
var _premier: bool = true


## Clé de la cellule du type de dégâts `type_degats` et du genre d'index `genre`.
static func cle_genre(type_degats: int, genre: int) -> String:
	var nom: String = VueArene.GENRES_ARME[genre]
	return "%d/%s" % [type_degats, nom if nom != "" else "aucun"]


## Clé de la cellule du statut d'index `statut` (`VueArene.STATUTS_ARME`).
static func cle_statut(statut: int) -> String:
	return "statut/%s" % VueArene.STATUTS_ARME[statut]


## Coin haut gauche de la cellule (`colonne`, `ligne`), en pixels.
static func coin(colonne: int, ligne: int) -> Vector2:
	return Vector2(colonne * LARGEUR_CELLULE, ligne * HAUTEUR_CELLULE)


## Pixels de l'écran vers unités de jeu, ce que `Effets` attend dans les événements.
static func en_unites(pixels: Vector2) -> Vector2:
	return pixels / Apparence.PX_PAR_UNITE


func _ready() -> void:
	seed(GRAINE)
	effets = Effets.new()
	effets.name = "Effets"
	add_child(effets)
	_poser_cibles()


func _process(delta: float) -> void:
	avancer(delta)


## Fait avancer la vitrine (et ses effets) de `delta` secondes ; `_process` n'est que son appelant.
func avancer(delta: float) -> void:
	if _premier:
		_premier = false
		_tirer()
	_temps += delta
	if not _impacts_faits and _temps >= DELAI_IMPACT:
		_impacts_faits = true
		_declencher_impacts()
	if _temps >= PERIODE:
		_temps -= PERIODE
		cycles += 1
		_impacts_faits = false
		effets.vider()
		_tirer()
		if _temps >= DELAI_IMPACT:
			_impacts_faits = true
			_declencher_impacts()
	effets.avancer(delta)
	pic_vivants = maxi(pic_vivants, effets.nombre_vivants())


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, LARGEUR_ECRAN, HAUTEUR_ECRAN), FOND)
	for ligne: int in LIGNES:
		for colonne: int in COLONNES:
			draw_circle(coin(colonne, ligne) + TOUR_DANS_CELLULE, RAYON_TOUR_PX, COULEUR_TOUR)


func _poser_cibles() -> void:
	var entree: Dictionary = Apparence.entree(SPRITE_CIBLE)
	var texture: Texture2D = load(String(entree["feuille"])) as Texture2D
	var case_px: Vector2i = entree["case"]
	var pieds: float = float(entree["pieds"])
	var repos: Vector2i = entree["repos"]
	for ligne: int in LIGNES:
		for colonne: int in COLONNES:
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.region_enabled = true
			sprite.region_rect = Rect2(
				0.0, float(repos.x * case_px.y), float(case_px.x), float(case_px.y)
			)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2.ONE * ECHELLE_CIBLE
			# Les pieds de l'unité sur la cible, pas le centre de sa case.
			sprite.offset = Vector2(0.0, case_px.y * 0.5 - pieds)
			sprite.position = coin(colonne, ligne) + CIBLE_DANS_CELLULE
			add_child(sprite)
			move_child(sprite, 0)


## Les cellules dans l'ordre de la disposition : `[cle, colonne, ligne, genre, statut, type]`.
func _cellules() -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	for type_degats: int in Effets.PROJECTILES.size():
		for genre: int in VueArene.GENRES_ARME.size():
			(
				liste
				. append(
					{
						"cle": cle_genre(type_degats, genre),
						"colonne": genre,
						"ligne": type_degats,
						"genre": genre,
						"statut": 0,
						"type": type_degats,
					}
				)
			)
	for statut: int in range(1, VueArene.STATUTS_ARME.size()):
		(
			liste
			. append(
				{
					"cle": cle_statut(statut),
					"colonne": statut - 1,
					"ligne": LIGNE_SPECIALE,
					"genre": 1,
					"statut": statut,
					"type": TYPE_STATUT,
				}
			)
		)
	return liste


func _evenement(k: String, cellule: Dictionary) -> Dictionary:
	var coin_cellule: Vector2 = coin(int(cellule["colonne"]), int(cellule["ligne"]))
	var genre: String = VueArene.GENRES_ARME[int(cellule["genre"])]
	var zone: bool = genre == "zone" or genre == "aura" or genre == "onde" or genre == "mine"
	return {
		"k": k,
		"t": 0,
		"de": en_unites(coin_cellule + TOUR_DANS_CELLULE),
		"vers": en_unites(coin_cellule + CIBLE_DANS_CELLULE),
		"type_degats": int(cellule["type"]),
		"rayon": RAYON_ZONE if zone else 0.0,
		"genre": int(cellule["genre"]),
		"statut": int(cellule["statut"]),
	}


func _compter(cle: String, avant: int) -> void:
	crees[cle] = int(crees.get(cle, 0)) + effets.nombre_vivants() - avant


func _tirer() -> void:
	for cellule: Dictionary in _cellules():
		if int(cellule["statut"]) != 0:
			continue
		var avant: int = effets.nombre_vivants()
		effets.ajouter(_evenement("tir", cellule))
		_compter(String(cellule["cle"]), avant)


func _declencher_impacts() -> void:
	for cellule: Dictionary in _cellules():
		var avant: int = effets.nombre_vivants()
		effets.ajouter(_evenement("impact", cellule))
		_compter(String(cellule["cle"]), avant)
	var cible_explosion: Vector2 = coin(COLONNE_EXPLOSION, LIGNE_SPECIALE) + CIBLE_DANS_CELLULE
	var avant: int = effets.nombre_vivants()
	effets.exploser(en_unites(cible_explosion))
	_compter(CLE_EXPLOSION, avant)
	avant = effets.nombre_vivants()
	var cible_absorption: Vector2 = coin(COLONNE_ABSORPTION, LIGNE_SPECIALE) + TOUR_DANS_CELLULE
	effets.ajouter({"k": "absorption", "t": 0, "de": en_unites(cible_absorption)})
	_compter(CLE_ABSORPTION, avant)
