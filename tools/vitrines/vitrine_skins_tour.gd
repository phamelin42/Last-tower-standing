class_name VitrineSkinsTour
extends Node2D
## Vitrine des skins de tour, à capturer par `tools/capturer.sh` à 30 images par seconde : une
## `Arene2D` qui montre chaque skin de `data/skins_tour.json` à son tour, `IMAGES_PAR_SKIN` images
## chacun (le temps de laisser finir le fondu), avec les superpositions du palier 3 (`--max`) ou la
## tour nue (par défaut). `--couleur N` choisit la couleur du joueur (1 à 8).
## Exemple : tools/capturer.sh res://tools/vitrines/vitrine_skins_tour.tscn --images 612 -- --max
## La dernière image de chaque skin est celle à regarder.

const SCENE_ARENE := "res://scenes/arene_2d.tscn"
const IMAGES_PAR_SKIN: int = 12

var arene: Arene2D = null
var _donnees: Donnees = null
var _image: int = 0
var _tick: int = 0
var _maximum: bool = false
var _couleur: int = 1
## `--skins 0,5,12` : seulement ces index, dans cet ordre (tous par défaut).
var _index: Array[int] = []


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_maximum = args.has("--max")
	var c: int = args.find("--couleur")
	if c >= 0 and c + 1 < args.size() and args[c + 1].is_valid_int():
		_couleur = clampi(args[c + 1].to_int(), 1, 8)
	var u: int = args.find("--skins")
	if u >= 0 and u + 1 < args.size():
		for morceau: String in args[u + 1].split(","):
			_index.append(morceau.to_int())
	var z: int = args.find("--zoom")
	var zoom: float = args[z + 1].to_float() if z >= 0 and z + 1 < args.size() else 0.4
	RenderingServer.set_default_clear_color(Color(0.24, 0.38, 0.27))
	_donnees = Donnees.charger()
	arene = (load(SCENE_ARENE) as PackedScene).instantiate() as Arene2D
	arene.donnees = _donnees
	add_child(arene)
	arene.reinitialiser()
	var camera: CameraArene = arene.get_node("Camera") as CameraArene
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE * zoom
	arene.definir_joueur(_couleur, "Joueur")
	_montrer()


func _process(_delta: float) -> void:
	_image += 1
	_montrer()


func _seuil(stat: String) -> float:
	var stats: Dictionary = _donnees.apparence_tour["stats"]
	return float((stats[stat] as Array)[2])


func _montrer() -> void:
	var rang: int = _image / IMAGES_PAR_SKIN
	var index: int = mini(rang, _donnees.ids_skins().size() - 1)
	if not _index.is_empty():
		index = _index[mini(rang, _index.size() - 1)]
	arene.definir_skin(index)
	var v := VueArene.new()
	_tick += 1
	v.tick = _tick
	v.tour_pv = 1000.0
	v.tour_pv_max = 1000.0
	if _maximum:
		for stat: String in ApparenceTour.STATS:
			v.set(ApparenceTour.CHAMPS[stat], _seuil(stat))
		v.tour_pv_max = 1000.0
		v.tour_mana = v.tour_mana_max
	arene.afficher(v, float(_image) / 30.0)
