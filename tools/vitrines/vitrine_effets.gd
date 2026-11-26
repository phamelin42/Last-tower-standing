class_name VitrineEffets
extends Node2D
## Vitrine des effets de combat, à capturer par `tools/capturer.sh` : rejoue en boucle tout ce que
## `Effets` sait dessiner, sans simulation ni réseau, sur un fond uni. Aucun texte affiché.
##
## Disposition (écran de 1152 × 648, cellules de 89 × 108 px, tour à gauche, cible à droite) :
## - une ligne par type de dégâts, de haut en bas : tranchant, perçant, magique, siège, chaos ;
## - une colonne par genre d'arme, de gauche à droite : aucun, cible unique, zone, rebond, aura,
##   onde, barrage, piège, mine, tournant, zone posée, bombe, invocation (l'ordre de
##   `VueArene.GENRES_ARME`) ;
## - la dernière ligne, de gauche à droite : les onze statuts de `VueArene.STATUTS_ARME` (sans
##   « aucun »), puis une explosion de mort et l'absorption par la mana. Les colonnes tiennent
##   13 cellules : un genre ou un statut de plus demande d'élargir `COLONNES`.
## Chaque cycle (`PERIODE`) envoie le tir et l'impact de chaque cellule dans la même image, comme la
## simulation : c'est `Effets` qui fait attendre l'impact jusqu'à l'arrivée du projectile. Les
## cibles réagissent aux coups comme les ennemis de l'arène (`ReactionsCoups`).
## `-- --mouvement-reduit` montre le mode réduit : ni gel, ni recul, ni rebond, ni étincelles.
## Le temps ne vient que de `_process(delta)` : à cadence fixe, deux captures sont identiques.

const FOND := Color(0.24, 0.38, 0.27)
const COULEUR_TOUR := Color(0.9, 0.85, 0.6, 0.6)
const SPRITE_CIBLE := "guerrier_rouge"
## Échelle de la cible : assez petite pour tenir dans une cellule sans cacher les effets.
const ECHELLE_CIBLE: float = 0.35

const LARGEUR_ECRAN: float = 1152.0
const HAUTEUR_ECRAN: float = 648.0
const COLONNES: int = 13
const LIGNES: int = 6
const LARGEUR_CELLULE: float = LARGEUR_ECRAN / COLONNES
const HAUTEUR_CELLULE: float = HAUTEUR_ECRAN / LIGNES
## Position de la tour et de la cible dans une cellule, en pixels depuis son coin haut gauche.
const TOUR_DANS_CELLULE := Vector2(12.0, 54.0)
const CIBLE_DANS_CELLULE := Vector2(66.0, 54.0)
const RAYON_TOUR_PX: float = 4.0
## Rayon des genres de zone, en unités de jeu : 70 unités font 70 px de diamètre à l'écran.
const RAYON_ZONE: float = 70.0
## Type de dégâts des cellules de statut : le magique, dont l'impact (le halo) reste discret.
const TYPE_STATUT: int = Types.TypeDegats.MAGIQUE
const LIGNE_SPECIALE: int = LIGNES - 1
const COLONNE_EXPLOSION: int = 11
const COLONNE_ABSORPTION: int = 12

const PERIODE: float = 1.5
const GRAINE: int = 20261126
## Les sauts suivants d'un rebond, depuis la cible, en pixels : la chaîne se propage de saut en
## saut dans la cellule.
const SAUTS_REBOND: Array[Vector2] = [Vector2(-30.0, -34.0), Vector2(-56.0, 18.0)]

const CLE_EXPLOSION := "explosion"
const CLE_ABSORPTION := "absorption"

## Nombre d'effets créés par cellule depuis le début (clés de `cle_genre`, `cle_statut`, etc.) ;
## un impact qui attend son projectile compte dès qu'il est en attente.
var crees: Dictionary = {}
## Les cellules dont la cible a réagi à un coup : clé de cellule vers nombre de réactions.
var reactions_par_cellule: Dictionary = {}
var reactions: ReactionsCoups = ReactionsCoups.new()
## Cycles entièrement rejoués (le tir et l'impact ont eu lieu).
var cycles: int = 0
## Plus grand nombre d'effets vivants vu depuis le début.
var pic_vivants: int = 0
var effets: Effets = null
## Montre le mode réduit ; posé avant l'entrée dans l'arbre, ou par `-- --mouvement-reduit`.
var mouvement_reduit: bool = false

var _temps: float = 0.0
var _premier: bool = true
var _cibles: Array[Sprite2D] = []
var _ids_cibles: PackedInt32Array = PackedInt32Array()
var _positions_cibles: PackedVector2Array = PackedVector2Array()
var _cle_par_cellule: Dictionary = {}


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
	if OS.get_cmdline_user_args().has("--mouvement-reduit"):
		mouvement_reduit = true
	reactions.mouvement_reduit = mouvement_reduit
	effets = Effets.new()
	effets.mouvement_reduit = mouvement_reduit
	effets.name = "Effets"
	add_child(effets)
	effets.impact_visible.connect(_sur_impact_visible)
	for cellule: Dictionary in _cellules():
		_cle_par_cellule[Vector2i(int(cellule["colonne"]), int(cellule["ligne"]))] = cellule["cle"]
	_poser_cibles()


func _process(delta: float) -> void:
	avancer(delta)


## Fait avancer la vitrine (et ses effets) de `delta` secondes ; `_process` n'est que son appelant.
func avancer(delta: float) -> void:
	if _premier:
		_premier = false
		_jouer_cycle()
	_temps += delta
	if _temps >= PERIODE:
		_temps -= PERIODE
		cycles += 1
		effets.vider()
		reactions.reinitialiser()
		_jouer_cycle()
	effets.avancer(delta)
	reactions.avancer(delta)
	_animer_cibles()
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
			_cibles.append(sprite)
			_ids_cibles.append(_cibles.size())
			_positions_cibles.append(en_unites(sprite.position))


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
	crees[cle] = int(crees.get(cle, 0)) + _en_jeu() - avant


## Ce que `Effets` tient en jeu : les effets vivants et les impacts qui attendent leur projectile.
func _en_jeu() -> int:
	return effets.nombre_vivants() + effets.impacts_en_attente()


## La cible de la cellule touchée réagit, comme un ennemi de l'arène : elle recule à l'opposé de la
## tour de sa cellule.
func _sur_impact_visible(ou: Vector2, rayon: float) -> void:
	var pixels: Vector2 = ou * Apparence.PX_PAR_UNITE
	var cellule := Vector2i(int(pixels.x / LARGEUR_CELLULE), int(pixels.y / HAUTEUR_CELLULE))
	var tour: Vector2 = en_unites(coin(cellule.x, cellule.y) + TOUR_DANS_CELLULE)
	var n: int = reactions.toucher(ou, rayon, _ids_cibles, _positions_cibles, tour)
	if n > 0 and _cle_par_cellule.has(cellule):
		var cle: String = _cle_par_cellule[cellule]
		reactions_par_cellule[cle] = int(reactions_par_cellule.get(cle, 0)) + n


## Les identifiants des cibles, dans l'ordre des cellules.
func ids_cibles() -> PackedInt32Array:
	return _ids_cibles


func _animer_cibles() -> void:
	for i: int in _cibles.size():
		var id: int = _ids_cibles[i]
		var base: Vector2 = _positions_cibles[i] * Apparence.PX_PAR_UNITE
		_cibles[i].position = reactions.position_affichee(id, base)
		var eclat: float = reactions.eclat(id)
		_cibles[i].modulate = Color(eclat, eclat, eclat)


## Le tir et l'impact de chaque cellule partent ensemble, puis l'explosion de mort et l'absorption.
func _jouer_cycle() -> void:
	for cellule: Dictionary in _cellules():
		var avant: int = _en_jeu()
		if int(cellule["statut"]) == 0:
			effets.ajouter(_evenement("tir", cellule))
		effets.ajouter(_evenement("impact", cellule))
		_sauter(cellule)
		_compter(String(cellule["cle"]), avant)
	var cible_explosion: Vector2 = coin(COLONNE_EXPLOSION, LIGNE_SPECIALE) + CIBLE_DANS_CELLULE
	var avant: int = _en_jeu()
	effets.exploser(en_unites(cible_explosion))
	_compter(CLE_EXPLOSION, avant)
	avant = _en_jeu()
	var cible_absorption: Vector2 = coin(COLONNE_ABSORPTION, LIGNE_SPECIALE) + TOUR_DANS_CELLULE
	effets.ajouter({"k": "absorption", "t": 0, "de": en_unites(cible_absorption)})
	_compter(CLE_ABSORPTION, avant)


## Un rebond continue de la cible vers deux autres points : chaque saut part du précédent.
func _sauter(cellule: Dictionary) -> void:
	if VueArene.GENRES_ARME[int(cellule["genre"])] != "rebond":
		return
	var coin_cellule: Vector2 = coin(int(cellule["colonne"]), int(cellule["ligne"]))
	var depart: Vector2 = coin_cellule + CIBLE_DANS_CELLULE
	for decalage: Vector2 in SAUTS_REBOND:
		var evenement: Dictionary = _evenement("impact", cellule)
		evenement["de"] = en_unites(depart)
		depart = coin_cellule + CIBLE_DANS_CELLULE + decalage
		evenement["vers"] = en_unites(depart)
		effets.ajouter(evenement)
