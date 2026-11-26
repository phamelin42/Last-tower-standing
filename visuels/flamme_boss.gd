class_name FlammeBoss
extends Sprite2D
## Une flamme en boucle, posée derrière l'unité qui la porte (le boss). Elle s'anime seule.

## La flamme dépasse sous les pieds du boss, que son corps large cacherait sinon.
const DECALAGE_FLAMME: float = 10.0
const ECHELLE_FLAMME_BOSS: float = 0.5
const IMAGES_FEU_PAR_SECONDE: float = 10.0

var _temps: float = 0.0


static func creer() -> FlammeBoss:
	var flamme := FlammeBoss.new()
	flamme.name = "Flamme"
	flamme.texture = load(Apparence.RACINE + Effets.FEUILLE_FEU) as Texture2D
	flamme.region_enabled = true
	flamme.region_rect = Rect2(0.0, 0.0, Effets.CASE_FEU, Effets.CASE_FEU)
	flamme.offset = Vector2(0.0, Effets.CASE_FEU * 0.5 - Effets.PIED_FEU + DECALAGE_FLAMME)
	flamme.show_behind_parent = true
	flamme.scale = Vector2.ONE * ECHELLE_FLAMME_BOSS
	return flamme


func _process(delta: float) -> void:
	_temps += delta
	var image: int = int(_temps * IMAGES_FEU_PAR_SECONDE) % Effets.IMAGES_FEU
	region_rect = Rect2(image * Effets.CASE_FEU, 0.0, Effets.CASE_FEU, Effets.CASE_FEU)
