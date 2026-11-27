class_name FlammeBoss
extends Sprite2D
## Une flamme en boucle, posée derrière l'unité qui la porte (le boss). Elle s'anime seule.

## La flamme dépasse sous les pieds du boss, que son corps large cacherait sinon.
const DECALAGE_FLAMME: float = 10.0

var _temps: float = 0.0


static func creer() -> FlammeBoss:
	var flamme := FlammeBoss.new()
	flamme.name = "Flamme"
	var feu: Dictionary = PlanchesEffets.pack("feu")
	var case_px: Vector2i = feu["case"]
	flamme.texture = load(PlanchesEffets.chemin_pack("feu")) as Texture2D
	flamme.region_enabled = true
	flamme.region_rect = Rect2(0.0, 0.0, case_px.x, case_px.y)
	flamme.offset = Vector2(0.0, case_px.y * 0.5 - float(feu["pieds"]) + DECALAGE_FLAMME)
	flamme.show_behind_parent = true
	flamme.scale = Vector2.ONE * float(feu["echelle_boss"])
	return flamme


func _process(delta: float) -> void:
	_temps += delta
	var feu: Dictionary = PlanchesEffets.pack("feu")
	var case_px: Vector2i = feu["case"]
	var image: int = int(_temps * float(feu["images_par_seconde"])) % int(feu["images"])
	region_rect = Rect2(image * case_px.x, 0.0, case_px.x, case_px.y)
