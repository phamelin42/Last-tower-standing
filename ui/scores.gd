class_name TableauScores
extends Control
## Tableau des scores, affiché tant que Tab est maintenu. Un joueur éliminé porte son état en
## texte et en symbole. Les noms sont tronqués par des points de suite : un nom long ne fait
## jamais déborder la largeur du tableau.

## Action d'entrée : le tableau s'affiche tant qu'elle est maintenue. T2.7 la déclare dans
## `project.godot` (section `[input]`), liée à Tab. Lire l'état de l'action plutôt qu'un
## événement de touche : Tab est aussi la navigation de focus de Godot, qui l'intercepte.
const ACTION_SCORES := "afficher_scores"
const LARGEUR_MAX := 960.0
const HAUTEUR_LIGNE := 48.0
const COLONNES := 6
## Largeur de chaque colonne : un libellé tronqué ne doit pas se réduire à rien.
const LARGEURS_COLONNES: Array[float] = [200.0, 88.0, 136.0, 104.0, 88.0, 128.0]

## Panneau opaque du tableau (le fond ne laisse rien lire derrière lui).
var panneau: PanelContainer
var _tableau: GridContainer
var _titre: Label


func _init() -> void:
	ThemeJeu.appliquer(self)
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	panneau = PanelContainer.new()
	panneau.name = "Panneau"
	panneau.add_theme_stylebox_override("panel", ThemeJeu.boite_panneau())
	centre.add_child(panneau)
	var contenu := VBoxContainer.new()
	panneau.add_child(contenu)
	_titre = _etiquette(false)
	_titre.theme_type_variation = "Titre"
	contenu.add_child(_titre)
	_tableau = GridContainer.new()
	_tableau.columns = COLONNES
	contenu.add_child(_tableau)


## Appelé par le gestionnaire de touches : vrai tant que Tab est enfoncé.
func definir_maintenu(maintenu: bool) -> void:
	visible = maintenu


func _process(_delta: float) -> void:
	if InputMap.has_action(ACTION_SCORES):
		definir_maintenu(Input.is_action_pressed(ACTION_SCORES))


func afficher(vue: VueGlobale, id_local: int) -> void:
	_titre.text = tr("SCORES_TITRE")
	for enfant: Node in _tableau.get_children():
		_tableau.remove_child(enfant)
		enfant.free()
	var colonne := 0
	for entete: String in [
		"SCORES_JOUEUR",
		"SCORES_MANCHE",
		"SCORES_ELIMINATIONS",
		"SCORES_DEGATS",
		"SCORES_REVENU",
		"SCORES_ETAT",
	]:
		var titre := _etiquette(false, tr(entete))
		titre.custom_minimum_size.x = LARGEURS_COLONNES[colonne]
		_tableau.add_child(titre)
		colonne += 1
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
		Nombres.groupe(joueur["manche"]),
		Nombres.groupe(joueur["eliminations"]),
		Nombres.groupe(roundi(degats)),
		Nombres.groupe(joueur["revenu"]),
		etat,
	]
	for i: int in cellules.size():
		var cellule := _etiquette(true, cellules[i])
		cellule.custom_minimum_size.x = LARGEURS_COLONNES[i]
		_tableau.add_child(cellule)


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
