class_name NomTour
extends Node2D
## Le nom du joueur écrit sous la tour (nœud « Noms », étiquette « NomJoueur »), gardé à taille
## d'écran constante quel que soit le zoom de la caméra.

const LARGEUR: float = 260.0
const TAILLE: int = 18
const CONTOUR: int = 6
## Écart entre le pied de la tour et le haut du nom, en pixels d'écran.
const ECART: float = 8.0

var _nom: Label = null


func _init() -> void:
	name = "Noms"
	_nom = Label.new()
	_nom.name = "NomJoueur"
	_nom.position = Vector2(-LARGEUR * 0.5, 0.0)
	_nom.custom_minimum_size = Vector2(LARGEUR, 0.0)
	_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_nom.add_theme_font_size_override("font_size", TAILLE)
	_nom.add_theme_color_override("font_color", Apparence.COULEUR_NOM)
	_nom.add_theme_color_override("font_outline_color", Apparence.COULEUR_CONTOUR_NOM)
	_nom.add_theme_constant_override("outline_size", CONTOUR)
	add_child(_nom)


## « numéro. nom » ; un nom vide n'écrit rien.
func ecrire(numero: int, nom: String) -> void:
	_nom.text = "%d. %s" % [Apparence.numero_valide(numero), nom] if nom != "" else ""


## Compense le grossissement de la caméra (strictement positif).
func ajuster(grossissement: float) -> void:
	scale = Vector2.ONE / grossissement
	position = Vector2(0.0, ECART / grossissement)
