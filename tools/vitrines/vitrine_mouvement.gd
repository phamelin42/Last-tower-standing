class_name VitrineMouvement
extends Node2D
## Vitrine du déplacement des ennemis, à capturer par `tools/capturer.sh` à 60 images par seconde :
## une `Arene2D` nourrie de vues synthétiques à `--hz N` (15 par défaut, comme le réseau ; 5 comme
## une arène regardée) où un ennemi traverse l'écran à vitesse constante. Sans lissage, il
## avance par à-coups à chaque vue ; lissé, d'un pas égal à chaque image.
## Exemple : tools/capturer.sh res://tools/vitrines/vitrine_mouvement.tscn --fps 60 --images 120
## -- --hz 15 [--vide]
##
## Le temps ne vient que du compteur d'images : à cadence fixe, deux captures sont identiques.

const SCENE_ARENE := "res://scenes/arene_2d.tscn"
const IMAGES_PAR_SECONDE: int = 60
const HZ_DEFAUT: int = 15
## Unités de jeu par seconde : 300 font 5 pixels par image, et 60 unités (sous `SAUT_MAX`) par
## vue à 5 Hz.
const VITESSE: float = 300.0
const DEPART_X: float = -520.0
## Ordonnée de chaque ennemi (un par famille, du haut vers le bas). Un seul : à plusieurs, leurs
## sprites se recouvrent et la mesure d'un déplacement devient floue.
const LIGNES_Y: Array[float] = [230.0]

var arene: Arene2D = null
var _source: SourceVue = null
var _image: int = 0
var _pas_vue: int = 4
var _tick: int = 0
## `--vide` : mêmes vues sans ennemi, pour isoler les ennemis par différence d'images.
var _vide: bool = false


func _ready() -> void:
	var hz: int = HZ_DEFAUT
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find("--hz")
	if i >= 0 and i + 1 < args.size() and args[i + 1].is_valid_int():
		hz = clampi(args[i + 1].to_int(), 1, IMAGES_PAR_SECONDE)
	_vide = args.has("--vide")
	_pas_vue = maxi(1, roundi(float(IMAGES_PAR_SECONDE) / float(hz)))
	RenderingServer.set_default_clear_color(Color(0.24, 0.38, 0.27))
	arene = (load(SCENE_ARENE) as PackedScene).instantiate() as Arene2D
	arene.donnees = Donnees.charger()
	add_child(arene)
	_source = SourceVue.new()
	add_child(_source)
	arene.lier(_source)
	arene.reinitialiser()
	var camera: CameraArene = arene.get_node("Camera") as CameraArene
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE


func _process(_delta: float) -> void:
	if _image % _pas_vue == 0:
		_emettre_vue(float(_image) / float(IMAGES_PAR_SECONDE))
	_image += 1


func _emettre_vue(temps: float) -> void:
	_tick += 1
	var v := VueArene.new()
	v.tick = _tick
	for i: int in 0 if _vide else LIGNES_Y.size():
		v.ennemis_id.append(i + 1)
		v.ennemis_pos.append(Vector2(DEPART_X + VITESSE * temps, LIGNES_Y[i]))
		v.ennemis_famille.append(i)
		v.ennemis_pv.append(255)
		v.ennemis_statuts.append(0)
	_source.vue_arene_recue.emit(v)
