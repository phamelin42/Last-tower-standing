class_name ObservationUi
extends Control
## Observation après la défaite : la joueuse vaincue choisit l'arène qu'elle regarde parmi celles
## qui sont encore en jeu. Invisible tant qu'elle vit. Il lit une `VueGlobale` et n'agit que par
## `SourceVue.observer` : une arène dont le joueur est mort ne reste jamais affichée.

## Actions d'entrée : `project.godot` les déclare, liées à Page précédente et Page suivante (les
## flèches déplacent la vue depuis T8.13 : les deux ne doivent pas jouer ensemble).
const ACTION_SUIVANT := "observation_suivant"
const ACTION_PRECEDENT := "observation_precedent"
const HAUTEUR_CONTROLE := 48.0
const LARGEUR := 360.0

## Renvoie le contrôle qui a le focus. Remplaçable : le lanceur de tests tourne hors de l'arbre,
## où aucun contrôle ne peut prendre le focus.
var lecteur_focus: Callable = Callable(self, "_focus_viewport")

var panneau: PanelContainer
var _source: SourceVue = null
var _cible: int = -1
## Arènes vivantes, triées : l'ordre de « suivant » et « précédent ».
var _ids: Array[int] = []
var _noms: Dictionary = {}
## Empreinte de la liste affichée : elle ne se reconstruit que si les joueurs changent, sinon un
## bouton perdrait son focus à chaque mise à jour (2 Hz).
var _signature: String = ""
var _message: Label
var _observe: Label
var _titre_liste: Label
var _navigation: HBoxContainer
var _liste: VBoxContainer


func _init() -> void:
	ThemeJeu.appliquer(self)
	custom_minimum_size = Vector2(LARGEUR, 0.0)
	visible = false
	panneau = PanelContainer.new()
	panneau.name = "Panneau"
	panneau.add_theme_stylebox_override("panel", ThemeJeu.boite_panneau())
	panneau.custom_minimum_size = Vector2(LARGEUR, 0.0)
	add_child(panneau)
	var colonne := VBoxContainer.new()
	panneau.add_child(colonne)
	colonne.add_child(_etiquette("Titre", "OBSERVATION_TITRE"))
	_message = _etiquette("Message")
	colonne.add_child(_message)
	_observe = _etiquette("Observe")
	colonne.add_child(_observe)
	_navigation = HBoxContainer.new()
	_navigation.name = "Navigation"
	colonne.add_child(_navigation)
	_navigation.add_child(
		_bouton(Callable(self, "_aller").bind(-1), "NavPrecedent", "OBSERVATION_PRECEDENTE")
	)
	_navigation.add_child(
		_bouton(Callable(self, "_aller").bind(1), "NavSuivant", "OBSERVATION_SUIVANTE")
	)
	_titre_liste = _etiquette("TitreListe", "OBSERVATION_LISTE")
	colonne.add_child(_titre_liste)
	_liste = VBoxContainer.new()
	_liste.name = "Liste"
	colonne.add_child(_liste)


## Fournit la source vers laquelle les demandes d'observation sont envoyées.
func configurer(source: SourceVue) -> void:
	_source = source


## `cible` est l'identifiant de l'arène observée en ce moment. Si elle n'est plus en vie, l'écran
## passe d'elle-même à l'arène vivante suivante.
func afficher(vue: VueGlobale, id_local: int, cible: int) -> void:
	_cible = cible
	var moi: Dictionary = _joueur(vue, id_local)
	visible = not moi.is_empty() and not bool(moi["vivant"])
	if not visible:
		return
	_noms.clear()
	var vivants: Array[int] = []
	for joueur: Dictionary in vue.joueurs:
		var id: int = joueur["id"]
		_noms[id] = str(joueur["nom"])
		if bool(joueur["vivant"]):
			vivants.append(id)
	vivants.sort()
	_ids = vivants
	_construire_liste()
	var personne := _ids.is_empty()
	_message.text = tr("OBSERVATION_PERSONNE") if personne else ""
	_navigation.visible = not personne
	_titre_liste.visible = not personne
	if personne:
		_observe.text = ""
		return
	if _ids.has(cible):
		_afficher_observee()
	else:
		_demander(_suivant_apres(cible))


## Page précédente et suivante n'agissent que si l'écran est visible et qu'aucun champ de saisie n'a le focus :
## taper un nom ne doit pas changer d'arène.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	var focus: Variant = lecteur_focus.call()
	if focus is LineEdit or focus is TextEdit:
		return
	if InputMap.has_action(ACTION_SUIVANT) and event.is_action_pressed(ACTION_SUIVANT):
		_aller(1)
		_consommer()
		return
	if InputMap.has_action(ACTION_PRECEDENT) and event.is_action_pressed(ACTION_PRECEDENT):
		_aller(-1)
		_consommer()


# --- Navigation ------------------------------------------------------------------------------


## Passe à l'arène vivante voisine de la cible, dans l'ordre des identifiants, en bouclant.
func _aller(pas: int) -> void:
	if _ids.is_empty():
		return
	var index := _ids.find(_cible)
	if index < 0:
		index = 0 if pas > 0 else _ids.size() - 1
	else:
		index = posmod(index + pas, _ids.size())
	_demander(_ids[index])


## Première arène vivante après `cible` ; bouclage sur la première si `cible` est la dernière.
func _suivant_apres(cible: int) -> int:
	for id: int in _ids:
		if id > cible:
			return id
	return _ids[0]


func _demander(id: int) -> void:
	_cible = id
	_afficher_observee()
	if _source != null:
		_source.observer(id)


func _afficher_observee() -> void:
	if _ids.is_empty():
		_observe.text = ""
		return
	_observe.text = tr("OBSERVATION_VOUS_OBSERVEZ") % str(_noms.get(_cible, ""))


# --- Construction ----------------------------------------------------------------------------


func _construire_liste() -> void:
	var signature := ""
	for id: int in _ids:
		var nom: String = _noms[id]
		signature += "%d=%s;" % [id, nom]
	if signature == _signature:
		return
	_signature = signature
	for enfant: Node in _liste.get_children():
		_liste.remove_child(enfant)
		enfant.queue_free()
	for id: int in _ids:
		var nom: String = _noms[id]
		var bouton := _bouton(Callable(self, "_demander").bind(id), "Arene%d" % id)
		bouton.text = nom
		_liste.add_child(bouton)


# --- Données ---------------------------------------------------------------------------------


func _joueur(vue: VueGlobale, id: int) -> Dictionary:
	for joueur: Dictionary in vue.joueurs:
		if int(joueur["id"]) == id:
			return joueur
	return {}


func _focus_viewport() -> Control:
	var fenetre := get_viewport()
	return fenetre.gui_get_focus_owner() if fenetre != null else null


func _consommer() -> void:
	var fenetre := get_viewport()
	if fenetre != null:
		fenetre.set_input_as_handled()


# --- Contrôles -------------------------------------------------------------------------------


func _etiquette(nom: String, cle: String = "") -> Label:
	var libelle := Label.new()
	libelle.name = nom
	libelle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not cle.is_empty():
		libelle.text = tr(cle)
	return libelle


func _bouton(action: Callable, nom: String, cle: String = "") -> Button:
	var bouton := Button.new()
	bouton.name = nom
	bouton.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bouton.pressed.connect(action)
	if not cle.is_empty():
		bouton.text = tr(cle)
	return bouton
