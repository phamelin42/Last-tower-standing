class_name CompteurIps
extends Control
## Compteur d'images par seconde (T5.1b) : images par seconde actuelles, minimum des 5 dernières
## secondes et nombre d'ennemis visibles, dans un petit cadre en haut à gauche, sous la barre du
## HUD (le panneau des armes est à droite, la boutique en bas). Il vit au-dessus de tous les
## écrans : F3 l'affiche ou le masque, menu compris. Il est masqué par défaut ; la case des
## réglages et F3 décident, `Principal` pose l'état initial.
## La mesure se prend environ 4 fois par seconde, pas à chaque image : le compteur ne doit pas
## coûter ce qu'il mesure.

const ACTION := "afficher_ips"
const CLE_TEXTE := "IPS_COMPTEUR"
const FENETRE_S := 5.0
const PERIODE_S := 0.25
const TAILLE_TEXTE := 16
const MARGE := 8.0
## Sous la barre du HUD (≈ 60 px), pour ne la recouvrir à aucune échelle d'interface.
const DECALAGE_HAUT := 72.0
const MARGE_CADRE := 6

## Nombre d'ennemis à afficher ; sans fournisseur, 0.
var fournisseur_ennemis: Callable = Callable()

var _temps: float = 0.0
var _reste: float = 0.0
var _dates: PackedFloat64Array = PackedFloat64Array()
var _valeurs: PackedFloat32Array = PackedFloat32Array()
var _cadre: PanelContainer = null
var _etiquette: Label = null


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = ThemeJeu.creer()
	visible = false
	_cadre = PanelContainer.new()
	_cadre.name = "Cadre"
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre.position = Vector2(MARGE, DECALAGE_HAUT)
	_cadre.add_theme_stylebox_override(
		"panel", ThemeJeu.boite(ThemeJeu.ENCRE, ThemeJeu.BORD_PACK, ThemeJeu.FILET, MARGE_CADRE)
	)
	add_child(_cadre)
	_etiquette = Label.new()
	_etiquette.name = "Texte"
	_etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiquette.add_theme_font_size_override("font_size", TAILLE_TEXTE)
	_etiquette.add_theme_color_override("font_color", ThemeJeu.PARCHEMIN)
	_cadre.add_child(_etiquette)


## Dernière ligne affichée, pour les tests et les captures.
func etiquette() -> Label:
	return _etiquette


## Nombre d'ennemis de l'arène donnée dont le sprite est affiché, toutes familles confondues
## (la tour n'est pas un ennemi).
static func ennemis_visibles(arene: Arene2D) -> int:
	if arene == null or not is_instance_valid(arene) or arene.donnees == null:
		return 0
	var total: int = 0
	for f: int in Apparence2D.ids_entites(arene.donnees).size():
		total += arene.nombre_instances_visibles(f)
	return total


## Pose une mesure à la date `temps` (secondes) et fait sortir celles de plus de 5 s.
func mesurer(temps: float, ips: float) -> void:
	_dates.append(temps)
	_valeurs.append(ips)
	var premiere: int = 0
	while premiere < _dates.size() - 1 and temps - _dates[premiere] > FENETRE_S:
		premiere += 1
	if premiere > 0:
		_dates = _dates.slice(premiere)
		_valeurs = _valeurs.slice(premiere)
	_rafraichir()


func nombre_mesures() -> int:
	return _dates.size()


## Dernière mesure ; sans mesure, la valeur du moteur.
func ips_courant() -> float:
	if _valeurs.is_empty():
		return Engine.get_frames_per_second()
	return _valeurs[_valeurs.size() - 1]


## Plus petite mesure des 5 dernières secondes.
func minimum() -> float:
	if _valeurs.is_empty():
		return Engine.get_frames_per_second()
	var plus_petit: float = _valeurs[0]
	for v: float in _valeurs:
		plus_petit = minf(plus_petit, v)
	return plus_petit


func texte() -> String:
	var ennemis: int = 0
	if fournisseur_ennemis.is_valid():
		ennemis = int(fournisseur_ennemis.call())
	return (
		tr(CLE_TEXTE)
		% [
			Nombres.groupe(roundi(ips_courant())),
			Nombres.groupe(roundi(minimum())),
			Nombres.groupe(ennemis),
		]
	)


func definir_visible(voulu: bool) -> void:
	visible = voulu
	_rafraichir()


func _process(delta: float) -> void:
	_temps += delta
	_reste += delta
	if _reste < PERIODE_S:
		return
	_reste -= PERIODE_S
	mesurer(_temps, Engine.get_frames_per_second())


func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action(ACTION) or not event.is_action_pressed(ACTION):
		return
	definir_visible(not visible)
	get_viewport().set_input_as_handled()


## Le texte n'est recomposé que s'il se voit : masqué, le compteur ne fait que prendre ses mesures.
func _rafraichir() -> void:
	if visible and _etiquette != null:
		_etiquette.text = texte()
