class_name VitrineApparenceTour
extends Node2D
## Vitrine de l'apparence de la tour, à capturer par `tools/capturer.sh` à 30 images par seconde :
## une `Arene2D` nourrie de vues synthétiques qui montrent tour à tour la tour nue, les piques et
## les filets, l'armure, la bulle de mana à moitié pleine, la régénération et le vol de vie, puis
## l'esquive pendant son passage et tout au maximum. Chaque étape dure une demi-seconde ; le temps
## ne vient que du compteur d'images.
## Exemple : tools/capturer.sh res://tools/vitrines/vitrine_apparence_tour.tscn --images 120
## --colonnes 8 [-- --zoom 2]

const SCENE_ARENE := "res://scenes/arene_2d.tscn"
const IMAGES_PAR_ETAPE: int = 15
const IMAGES_PAR_SECONDE: float = 30.0

var arene: Arene2D = null
var _donnees: Donnees = null
var _image: int = 0
var _tick: int = 0
## Image à laquelle l'esquive passe : la période de ses données (3 s) puis le début de sa pulsation.
var _image_esquive: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	RenderingServer.set_default_clear_color(Color(0.24, 0.38, 0.27))
	_donnees = Donnees.charger()
	arene = (load(SCENE_ARENE) as PackedScene).instantiate() as Arene2D
	arene.donnees = _donnees
	add_child(arene)
	arene.reinitialiser()
	var camera: CameraArene = arene.get_node("Camera") as CameraArene
	camera.position = Vector2.ZERO
	var i: int = args.find("--zoom")
	var zoom: float = args[i + 1].to_float() if i >= 0 and i + 1 < args.size() else 1.0
	camera.zoom = Vector2.ONE * zoom
	var regle: Dictionary = _donnees.apparence_tour["esquive"]
	_image_esquive = roundi(float(regle["periode_s"]) * IMAGES_PAR_SECONDE) + 3
	_montrer(0)


func _process(_delta: float) -> void:
	_image += 1
	_montrer(_etape())


## L'étape de l'image courante ; l'esquive a la sienne, calée sur sa pulsation.
func _etape() -> int:
	if _image >= _image_esquive and _image < _image_esquive + IMAGES_PAR_ETAPE:
		return 5
	return mini(_image / IMAGES_PAR_ETAPE, 4) if _image < _image_esquive else 6


func _seuil(stat: String, palier: int) -> float:
	var stats: Dictionary = _donnees.apparence_tour["stats"]
	return float((stats[stat] as Array)[palier - 1])


func _montrer(etape: int) -> void:
	var v := VueArene.new()
	_tick += 1
	v.tick = _tick
	v.tour_pv = 1000.0
	v.tour_pv_max = 1000.0
	match etape:
		1:
			v.tour_epines = _seuil("epines", 3)
			v.tour_vol_de_vie = _seuil("vol_de_vie", 3)
		2:
			v.tour_armure = _seuil("armure", 3)
		3:
			v.tour_mana_max = _seuil("mana", 3)
			v.tour_mana = v.tour_mana_max * 0.5
		4:
			v.tour_regen = _seuil("regen", 3)
			v.tour_pv_max = _seuil("pv_max", 3)
		5:
			v.tour_esquive = _seuil("esquive", 3)
		6:
			v.tour_epines = _seuil("epines", 3)
			v.tour_vol_de_vie = _seuil("vol_de_vie", 3)
			v.tour_armure = _seuil("armure", 3)
			v.tour_mana_max = _seuil("mana", 3)
			v.tour_mana = v.tour_mana_max
			v.tour_regen = _seuil("regen", 3)
			v.tour_pv_max = _seuil("pv_max", 3)
			v.tour_esquive = _seuil("esquive", 3)
	arene.afficher(v, float(_image) / IMAGES_PAR_SECONDE)
