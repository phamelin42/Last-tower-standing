class_name TableauScores
extends Control
## Tableau des scores, affiché tant que Tab est maintenu. Un joueur éliminé porte son état en
## texte et en symbole. Les noms sont tronqués par des points de suite : un nom long ne fait
## jamais déborder la largeur du tableau.

const LARGEUR_MAX := 960.0
const HAUTEUR_LIGNE := 48.0
const TAILLE_TEXTE := 16
const COLONNES := 6

var _tableau: GridContainer
var _titre: Label


func _init() -> void:
	add_theme_font_size_override("font_size", TAILLE_TEXTE)
	visible = false
	var contenu := VBoxContainer.new()
	add_child(contenu)
	_titre = _etiquette(false)
	contenu.add_child(_titre)
	_tableau = GridContainer.new()
	_tableau.columns = COLONNES
	contenu.add_child(_tableau)


## Appelé par le gestionnaire de touches : vrai tant que Tab est enfoncé.
func definir_maintenu(maintenu: bool) -> void:
	visible = maintenu


func _unhandled_input(evenement: InputEvent) -> void:
	var touche := evenement as InputEventKey
	if touche == null or touche.keycode != KEY_TAB or touche.echo:
		return
	definir_maintenu(touche.pressed)
	accept_event()


func afficher(vue: VueGlobale, id_local: int) -> void:
	_titre.text = tr("SCORES_TITRE")
	for enfant: Node in _tableau.get_children():
		_tableau.remove_child(enfant)
		enfant.free()
	for entete: String in [
		"SCORES_JOUEUR",
		"SCORES_MANCHE",
		"SCORES_ELIMINATIONS",
		"SCORES_DEGATS",
		"SCORES_REVENU",
		"SCORES_ETAT",
	]:
		_tableau.add_child(_etiquette(false, tr(entete)))
	for joueur: Dictionary in vue.joueurs:
		_ajouter_ligne(joueur, id_local)


func _ajouter_ligne(joueur: Dictionary, id_local: int) -> void:
	var id: int = joueur["id"]
	var nom: String = joueur["nom"]
	if id == id_local:
		nom = "%s (%s)" % [nom, tr("SCORES_VOUS")]
	var vivant: bool = joueur["vivant"]
	var etat := "● " + tr("SCORES_EN_VIE") if vivant else "× " + tr("SCORES_ELIMINE")
	var degats: float = joueur["degats"]
	var cellules: Array[String] = [
		nom,
		Hud.nombre(joueur["manche"]),
		Hud.nombre(joueur["eliminations"]),
		Hud.nombre(roundi(degats)),
		Hud.nombre(joueur["revenu"]),
		etat,
	]
	for texte: String in cellules:
		_tableau.add_child(_etiquette(true, texte))


func _etiquette(tronquable: bool, texte: String = "") -> Label:
	var libelle := Label.new()
	libelle.text = texte
	libelle.custom_minimum_size = Vector2(0.0, HAUTEUR_LIGNE)
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	libelle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tronquable:
		libelle.clip_text = true
		libelle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return libelle
