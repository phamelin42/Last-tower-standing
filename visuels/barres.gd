class_name BarresArene
extends Node2D
## Les jauges de l'arène, dessinées par code : PV de la tour (vert, rouge sous 30 %) avec « x / y »,
## mana dessous (bleue, absente sans mana) et PV du boss au-dessus de lui. Elles gardent leur
## taille à l'écran quel que soit le zoom : l'arène donne le zoom courant, les tailles en pixels
## d'écran sont divisées par lui pour devenir des tailles du monde.

## Sous ce ratio de PV, la barre passe au rouge.
const SEUIL_PV_BAS: float = 0.3
## Taille à l'écran, en pixels.
const LARGEUR_PX: float = 180.0
const HAUTEUR_PX: float = 16.0
const HAUTEUR_MANA_PX: float = 9.0
const ECART_PX: float = 4.0
const BORD_PX: float = 2.0
const TAILLE_TEXTE_PX: int = 13
## Hauteur du sommet visible de la tour, en pixels du monde, plus un jeu au-dessus.
const HAUT_TOUR: float = 370.0
const JEU_TOUR: float = 24.0
## Hauteur au-dessus des pieds du boss où la barre se pose, en pixels du monde.
const HAUT_BOSS: float = 210.0
const COULEUR_MANA := Color(0.3, 0.55, 1.0)
const COULEUR_TEXTE := Color(1.0, 1.0, 1.0)
const COULEUR_CONTOUR := Color(0.05, 0.07, 0.1)

## Indice du boss dans `VueArene.ennemis_famille` (posé par l'arène, -1 : aucun).
var indice_boss: int = -1
## Zoom courant de la caméra (posé par l'arène).
var zoom: float = 1.0:
	set(valeur):
		if not is_equal_approx(valeur, zoom):
			zoom = valeur
			queue_redraw()

var _ratio_pv: float = 0.0
var _ratio_mana: float = 0.0
var _texte_pv: String = ""
var _mana_visible: bool = false
var _boss_visible: bool = false
var _ratio_boss: float = 0.0
var _position_boss: Vector2 = Vector2.ZERO


static func couleur_pv(ratio: float) -> Color:
	return ThemeJeu.JAUGE_PLEINE if ratio > SEUIL_PV_BAS else ThemeJeu.JAUGE_BASSE


## Largeur d'une barre en pixels du monde pour garder `LARGEUR_PX` à l'écran. Un zoom nul ou non
## fini compte pour 1.
static func largeur_monde(zoom_camera: float) -> float:
	return LARGEUR_PX / _zoom_sur(zoom_camera)


static func _zoom_sur(zoom_camera: float) -> float:
	return zoom_camera if is_finite(zoom_camera) and zoom_camera > 0.0 else 1.0


## `valeur / maximum` borné à [0, 1] ; 0 sans maximum fini et positif, ou avec une valeur NaN.
static func _ratio(valeur: float, maximum: float) -> float:
	if not is_finite(maximum) or maximum <= 0.0 or is_nan(valeur):
		return 0.0
	return clampf(valeur / maximum, 0.0, 1.0)


static func _entier(valeur: float, maximum: float) -> int:
	if not is_finite(maximum) or maximum <= 0.0 or is_nan(valeur):
		return 0
	return roundi(clampf(valeur, 0.0, maximum))


func afficher(vue: VueArene) -> void:
	if vue == null:
		return
	_ratio_pv = _ratio(vue.tour_pv, vue.tour_pv_max)
	_ratio_mana = _ratio(vue.tour_mana, vue.tour_mana_max)
	_mana_visible = is_finite(vue.tour_mana_max) and vue.tour_mana_max > 0.0
	_texte_pv = (
		"%s / %s"
		% [
			Nombres.groupe(_entier(vue.tour_pv, vue.tour_pv_max)),
			Nombres.groupe(_entier(vue.tour_pv_max, vue.tour_pv_max)),
		]
	)
	_boss_visible = false
	var n: int = mini(
		vue.ennemis_famille.size(), mini(vue.ennemis_pos.size(), vue.ennemis_pv.size())
	)
	for i: int in n:
		if indice_boss >= 0 and vue.ennemis_famille[i] == indice_boss:
			_boss_visible = true
			_ratio_boss = vue.ennemis_pv[i] / 255.0
			_position_boss = Apparence.vers_pixels(vue.ennemis_pos[i])
			break
	queue_redraw()


## Oublie tout : à appeler quand une autre partie commence.
func reinitialiser() -> void:
	_ratio_pv = 0.0
	_ratio_mana = 0.0
	_texte_pv = ""
	_mana_visible = false
	_boss_visible = false
	queue_redraw()


func ratio_pv() -> float:
	return _ratio_pv


func ratio_mana() -> float:
	return _ratio_mana


func texte_pv() -> String:
	return _texte_pv


func barre_mana_visible() -> bool:
	return _mana_visible


func barre_boss_visible() -> bool:
	return _boss_visible


func ratio_boss() -> float:
	return _ratio_boss


func _draw() -> void:
	var z: float = _zoom_sur(zoom)
	var largeur: float = largeur_monde(z)
	var haut: float = HAUTEUR_PX / z
	var x: float = -largeur * 0.5
	if _texte_pv != "":
		var y: float = -(HAUT_TOUR + JEU_TOUR) - haut
		_jauge(Rect2(x, y, largeur, haut), _ratio_pv, couleur_pv(_ratio_pv), z)
		_texte(_texte_pv, Vector2(0.0, y + haut * 0.5), largeur, z)
		if _mana_visible:
			var haut_mana: float = HAUTEUR_MANA_PX / z
			var y_mana: float = y + haut + ECART_PX / z
			_jauge(Rect2(x, y_mana, largeur, haut_mana), _ratio_mana, COULEUR_MANA, z)
	if _boss_visible:
		var y_boss: float = _position_boss.y - HAUT_BOSS - haut
		var rect := Rect2(_position_boss.x - largeur * 0.5, y_boss, largeur, haut)
		_jauge(rect, _ratio_boss, couleur_pv(_ratio_boss), z)


func _jauge(rect: Rect2, ratio: float, couleur: Color, z: float) -> void:
	var bord: float = BORD_PX / z
	draw_rect(rect.grow(bord), COULEUR_CONTOUR)
	draw_rect(rect, ThemeJeu.JAUGE_FOND)
	if ratio > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), couleur)


func _texte(texte: String, centre: Vector2, largeur: float, z: float) -> void:
	var police: Font = ThemeDB.fallback_font
	var taille: int = maxi(1, roundi(TAILLE_TEXTE_PX / z))
	var hauteur_ligne: float = police.get_ascent(taille)
	var origine := Vector2(centre.x - largeur * 0.5, centre.y + hauteur_ligne * 0.35)
	var contour: int = maxi(1, roundi(3.0 / z))
	draw_string_outline(
		police,
		origine,
		texte,
		HORIZONTAL_ALIGNMENT_CENTER,
		largeur,
		taille,
		contour,
		COULEUR_CONTOUR
	)
	draw_string(police, origine, texte, HORIZONTAL_ALIGNMENT_CENTER, largeur, taille, COULEUR_TEXTE)
