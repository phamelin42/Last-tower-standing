class_name FinUi
extends Control
## Écran de fin : défaite ou victoire de la joueuse locale, puis classement final. Il lit une
## `VueArene` et une `VueGlobale` et ne calcule que l'ordre d'affichage. Les actions sont des
## signaux : c'est `app/jeu.gd` (T4.6) qui décide de la suite.

signal continuer_sans_fin
signal quitter
signal rejouer
signal observer

const HAUTEUR_LIGNE := 48.0
const TAILLE_TEXTE := 16
const TAILLE_TITRE := 28
const COLONNES_CLASSEMENT := 5
## Largeur de chaque colonne du classement : sans elle, les libellés tronqués se réduisent à rien.
const LARGEURS_COLONNES: Array[float] = [72.0, 220.0, 112.0, 152.0, 112.0]
const VOILE := Color(0.05, 0.08, 0.09, 0.62)
## Hauteur au-delà de laquelle le classement défile (plus de joueurs que la fenêtre n'en porte).
const HAUTEUR_CLASSEMENT_MAX := 240.0
## Les dégâts sont des flottants : on les plafonne avant de les arrondir, pour qu'une valeur
## démesurée ne fasse pas déborder l'entier 64 bits.
const ENTIER_MAX := 9.0e18

const ACTIONS_DEFAITE: Array[String] = ["observer", "rejouer", "quitter"]
const ACTIONS_VICTOIRE: Array[String] = ["continuer_sans_fin", "rejouer", "quitter"]

## Panneau opaque centré de l'écran de fin.
var panneau: PanelContainer
var _titre: Label
var _recap: GridContainer
var _classement_titre: Label
var _vide: Label
var _defilement: ScrollContainer
var _tableau: GridContainer
var _actions_courantes: Array[String] = []
var _mention: Label
var _actions: HBoxContainer
var _noms: Array[Label] = []
var _globale: VueGlobale = null
var _defaite: bool = false
var _id_local: int = -1


func _init() -> void:
	ThemeJeu.appliquer(self)
	add_theme_font_size_override("font_size", TAILLE_TEXTE)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Le voile estompe la partie et l'empêche de recevoir les clics pendant l'écran de fin.
	var voile := ColorRect.new()
	voile.name = "Voile"
	voile.color = VOILE
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(voile)
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
	_titre = _etiquette("", false, TAILLE_TITRE)
	_titre.theme_type_variation = ThemeJeu.TYPE_RUBAN
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenu.add_child(_titre)
	_recap = GridContainer.new()
	_recap.columns = 6
	contenu.add_child(_recap)
	_classement_titre = _etiquette("", false)
	contenu.add_child(_classement_titre)
	_vide = _etiquette("", false)
	contenu.add_child(_vide)
	_defilement = ScrollContainer.new()
	_defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contenu.add_child(_defilement)
	_tableau = GridContainer.new()
	_tableau.columns = COLONNES_CLASSEMENT
	_tableau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_defilement.add_child(_tableau)
	_mention = _etiquette("", false)
	contenu.add_child(_mention)
	_actions = HBoxContainer.new()
	contenu.add_child(_actions)


## Défaite : le bilan de la joueuse, le classement, et l'observation des autres arènes.
## L'observation n'est proposée que s'il reste un autre joueur en vie (jamais en solo).
func afficher_defaite(vue: VueArene, globale: VueGlobale, id_local: int = -1) -> void:
	_titre.text = tr("FIN_DEFAITE_TITRE")
	_defaite = true
	_id_local = id_local
	_afficher_bilan(vue, globale, _actions_defaite(globale, id_local))


## Victoire : le bilan, le classement, et la suite possible en mode sans fin.
func afficher_victoire(vue: VueArene, globale: VueGlobale, id_local: int = -1) -> void:
	_titre.text = tr("FIN_VICTOIRE_TITRE")
	_defaite = false
	_id_local = id_local
	_afficher_bilan(vue, globale, ACTIONS_VICTOIRE)


## Met à jour le classement. `id_local` vaut -1 si la joueuse locale n'est pas dans la partie.
func afficher_classement(globale: VueGlobale, id_local: int) -> void:
	_globale = globale
	_id_local = id_local
	_rafraichir_classement()
	if _defaite:
		var voulues := _actions_defaite(globale, id_local)
		if voulues != _actions_courantes:
			_rafraichir_actions(voulues)


## Vrai s'il reste en vie un joueur autre que la joueuse locale : le seul cas où l'observation a
## quelque chose à montrer.
static func observation_possible(globale: VueGlobale, id_local: int) -> bool:
	if globale == null:
		return false
	for joueur: Dictionary in globale.joueurs:
		var id: int = joueur["id"]
		var vivant: bool = joueur["vivant"]
		if vivant and id != id_local:
			return true
	return false


## Les actions visibles, dans l'ordre d'affichage.
func actions_visibles() -> PackedStringArray:
	var sortie := PackedStringArray()
	for bouton: Node in _actions.get_children():
		sortie.append(bouton.get_meta("action"))
	return sortie


## Déclenche l'action comme le ferait un clic sur son bouton.
func presser(action: String) -> void:
	for bouton: Node in _actions.get_children():
		if bouton.get_meta("action") == action:
			(bouton as Button).pressed.emit()
			return


## Textes actuellement lisibles à l'écran.
func textes() -> PackedStringArray:
	var sortie := PackedStringArray()
	for noeud: Node in find_children("*", "Label", true, false):
		var libelle := noeud as Label
		if libelle.is_visible_in_tree() and libelle.text != "":
			sortie.append(libelle.text)
	return sortie


## Noms de la liste classée, dans l'ordre affiché.
func noms_classes() -> PackedStringArray:
	var sortie := PackedStringArray()
	for libelle: Label in _noms:
		sortie.append(libelle.text)
	return sortie


func _afficher_bilan(vue: VueArene, globale: VueGlobale, actions: Array[String]) -> void:
	_remplir_recap(vue)
	_globale = globale
	_rafraichir_classement()
	_rafraichir_actions(actions)


func _remplir_recap(vue: VueArene) -> void:
	_vider(_recap)
	_ligne_recap(tr("FIN_RECAP_MANCHE"), Nombres.groupe(vue.manche_max))
	_ligne_recap(tr("FIN_RECAP_ELIMINATIONS"), Nombres.groupe(vue.eliminations))
	_ligne_recap(tr("FIN_RECAP_DEGATS"), Nombres.groupe(_entier(vue.degats_infliges)))


func _ligne_recap(libelle: String, valeur: String) -> void:
	_recap.add_child(_etiquette(libelle, false))
	_recap.add_child(_etiquette(valeur, false))


func _rafraichir_classement() -> void:
	_classement_titre.text = tr("FIN_CLASSEMENT_TITRE")
	_vider(_tableau)
	_noms.clear()
	_mention.text = ""
	_mention.visible = false
	var joueurs: Array[Dictionary] = []
	if _globale != null:
		joueurs = _globale.joueurs
	var classes := _selon_classement(joueurs)
	var vide := classes.is_empty()
	_vide.visible = vide
	_vide.text = tr("FIN_CLASSEMENT_VIDE") if vide else ""
	_defilement.visible = not vide
	if vide:
		return
	var colonne := 0
	for entete: String in [
		"FIN_RANG", "FIN_JOUEUR", "FIN_MANCHE", "FIN_ELIMINATIONS", "FIN_DEGATS"
	]:
		var titre := _etiquette(tr(entete), false)
		titre.custom_minimum_size.x = LARGEURS_COLONNES[colonne]
		_tableau.add_child(titre)
		colonne += 1
	var rang := 0
	for joueur: Dictionary in classes:
		rang += 1
		_ajouter_ligne(rang, joueur)
	_afficher_mention(joueurs)
	_defilement.custom_minimum_size.y = minf(
		_tableau.get_combined_minimum_size().y, HAUTEUR_CLASSEMENT_MAX
	)


func _ajouter_ligne(rang: int, joueur: Dictionary) -> void:
	var id: int = joueur["id"]
	var nom: String = joueur["nom"]
	var manche: int = joueur["manche"]
	var eliminations: int = joueur["eliminations"]
	var degats: float = joueur["degats"]
	var affiche := nom
	if id == _id_local:
		affiche = "%s (%s)" % [nom, tr("FIN_VOUS")]
	var libelle_nom := _etiquette(affiche, true)
	_noms.append(libelle_nom)
	var cellules: Array[Label] = [
		_etiquette(str(rang), false),
		libelle_nom,
		_etiquette(Nombres.groupe(manche), false),
		_etiquette(Nombres.groupe(eliminations), false),
		_etiquette(Nombres.groupe(_entier(degats)), false),
	]
	for i: int in cellules.size():
		cellules[i].custom_minimum_size.x = LARGEURS_COLONNES[i]
		_tableau.add_child(cellules[i])


## La mention ne paraît que si le dernier rempart désigne un joueur de cette partie.
func _afficher_mention(joueurs: Array[Dictionary]) -> void:
	if _globale.dernier_rempart < 0:
		return
	for joueur: Dictionary in joueurs:
		var id: int = joueur["id"]
		if id == _globale.dernier_rempart:
			_mention.text = tr("FIN_DERNIER_REMPART") % joueur["nom"]
			_mention.visible = true
			return


## Ordre du classement tel que la partie l'a calculé (`VueGlobale.classement`, voir
## `sim/classement.gd`) : l'écran ne le recalcule pas. Un id absent des joueurs est ignoré.
func _selon_classement(joueurs: Array[Dictionary]) -> Array[Dictionary]:
	var sortie: Array[Dictionary] = []
	if _globale == null:
		return sortie
	for id: int in _globale.classement:
		for joueur: Dictionary in joueurs:
			if joueur["id"] == id:
				sortie.append(joueur)
				break
	return sortie


func _actions_defaite(globale: VueGlobale, id_local: int) -> Array[String]:
	var sortie: Array[String] = []
	for action: String in ACTIONS_DEFAITE:
		if action != "observer" or observation_possible(globale, id_local):
			sortie.append(action)
	return sortie


func _rafraichir_actions(actions: Array[String]) -> void:
	_actions_courantes = actions.duplicate()
	_vider(_actions)
	for action: String in actions:
		var bouton := Button.new()
		bouton.text = tr(_cle_action(action))
		bouton.custom_minimum_size = Vector2(0.0, HAUTEUR_LIGNE)
		bouton.set_meta("action", action)
		bouton.pressed.connect(_presse.bind(action))
		_actions.add_child(bouton)
	if is_inside_tree() and _actions.get_child_count() > 0:
		(_actions.get_child(0) as Button).grab_focus()


func _cle_action(action: String) -> String:
	match action:
		"continuer_sans_fin":
			return "FIN_CONTINUER_SANS_FIN"
		"observer":
			return "FIN_OBSERVER"
		"rejouer":
			return "FIN_REJOUER"
		_:
			return "FIN_MENU_PRINCIPAL"


func _presse(action: String) -> void:
	match action:
		"continuer_sans_fin":
			continuer_sans_fin.emit()
		"observer":
			observer.emit()
		"rejouer":
			rejouer.emit()
		_:
			quitter.emit()


## Entier affichable : un flottant démesuré est plafonné plutôt que de déborder.
static func _entier(valeur: float) -> int:
	return roundi(clampf(valeur, -ENTIER_MAX, ENTIER_MAX))


func _etiquette(texte: String, tronquable: bool, taille: int = TAILLE_TEXTE) -> Label:
	var libelle := Label.new()
	libelle.text = texte
	libelle.custom_minimum_size = Vector2(0.0, HAUTEUR_LIGNE)
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	libelle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	libelle.add_theme_font_size_override("font_size", taille)
	if tronquable:
		libelle.clip_text = true
		libelle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return libelle


func _vider(conteneur: Node) -> void:
	# Retiré avant d'être libéré : un enfant en attente de `queue_free` reste compté quelques instants.
	for enfant: Node in conteneur.get_children():
		conteneur.remove_child(enfant)
		enfant.free()
