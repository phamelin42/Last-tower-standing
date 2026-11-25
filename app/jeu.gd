class_name Jeu
extends Node
## Une partie en cours : source de vue, arène 3D, HUD, boutique, scores, observation et écran de
## fin, câblés ensemble. Pour l'instant le solo seul (`SourceLocale`) ; le réseau mettra un
## `Client` à la place sans changer le reste, car tout passe par `SourceVue`.

## La joueuse veut revenir au menu (`motif` vide) ou la connexion est perdue (`motif` lisible).
signal retour_menu(motif: String)

const SCENE_ARENE := "res://scenes/arene_3d.tscn"
const MARGE := 16.0
## Un cran de molette déplace le zoom de ce pas, multiplié par la sensibilité des réglages.
const PAS_ZOOM := 0.05
const ACTION_MENU := "menu_jeu"
const ACTION_SANS_FIN := "continuer_sans_fin"
const ACTION_REJOUER := "rejouer"
const HAUTEUR_CONTROLE := 48.0

## Fichier des réglages : le lanceur de tests le remplace par un dossier temporaire.
var chemin_reglages: String = Reglages.CHEMIN_DEFAUT
var nom_joueur: String = ""
var source: SourceLocale = null
var arene: Arene3D = null
var camera: CameraArene = null

var _donnees: Donnees = null
var _facteur: float = 1.0
var _sensibilite: float = 1.0
var _derniere_vue: VueArene = null
var _globale: VueGlobale = null
var _fin_affichee: bool = false
var _observe: bool = false
var _pause: PanelContainer = null
var _reprendre: Button = null

@onready var hud: Hud = $Interface/Racine/Hud
@onready var scores: TableauScores = $Interface/Racine/Scores
@onready var boutique: BoutiqueUi = $Interface/Racine/Boutique
@onready var observation: ObservationUi = $Interface/Racine/Observation
@onready var fin: FinUi = $Interface/Racine/Fin
@onready var _racine: Control = $Interface/Racine


## Applique à la fenêtre ce que les réglages demandent : échelle de l'interface et plein écran.
## Sans écran (tests, serveur), le mode de fenêtre ne change pas.
static func appliquer_fenetre(fenetre: Window, r: Reglages) -> void:
	if fenetre == null:
		return
	var echelle := Reglages.echelle_valide(r.echelle_ui)
	if not is_equal_approx(fenetre.content_scale_factor, echelle):
		fenetre.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		fenetre.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		fenetre.content_scale_size = Vector2i.ZERO
		fenetre.content_scale_factor = echelle
	if DisplayServer.get_name() == "headless":
		return
	var voulu := Window.MODE_FULLSCREEN if r.plein_ecran else Window.MODE_WINDOWED
	if fenetre.mode != voulu:
		fenetre.mode = voulu


func _ready() -> void:
	fin.visible = false
	_construire_pause()
	_racine.resized.connect(_placer)
	fin.rejouer.connect(_rejouer)
	fin.quitter.connect(_demander_menu)
	fin.observer.connect(_observer)
	# « Continuer sans fin » : désactivé jusqu'au mode sans fin (T4.3), on ne l'écoute pas.
	_placer()


## Démarre une partie solo. Faux, sans exception ni écran à moitié monté, si les données
## manquent ou si la partie refuse de démarrer.
func demarrer_solo(donnees: Donnees, graine: int, facteur_duree: float) -> bool:
	if donnees == null:
		return false
	_donnees = donnees
	_facteur = facteur_duree
	_appliquer_reglages()
	if source == null:
		source = SourceLocale.new()
		source.name = "Source"
		add_child(source)
		source.vue_arene_recue.connect(_sur_arene)
		source.vue_globale_recue.connect(_sur_globale)
		source.connexion_perdue.connect(func(motif: String) -> void: retour_menu.emit(motif))
	return _lancer(graine)


func _lancer(graine: int) -> bool:
	source.quitter_partie()
	var config := Partie.Config.new()
	config.graine = graine
	config.facteur_duree = _facteur
	if not source.demarrer(_donnees, config, nom_joueur):
		return false
	_vider_ecran()
	if arene == null:
		arene = (load(SCENE_ARENE) as PackedScene).instantiate() as Arene3D
		arene.donnees = _donnees
		add_child(arene)
		move_child(arene, 0)
		camera = arene.find_children("*", "CameraArene", true, false)[0] as CameraArene
		arene.lier(source)
	arene.reinitialiser()
	hud.configurer(_donnees)
	boutique.configurer(_donnees, source)
	observation.configurer(source)
	return true


func _appliquer_reglages() -> void:
	var r := Reglages.charger(chemin_reglages)
	_sensibilite = r.sensibilite_zoom
	appliquer_fenetre(get_window(), r)


## Remet l'écran comme au premier instant d'une partie.
func _vider_ecran() -> void:
	_derniere_vue = null
	_globale = null
	_fin_affichee = false
	_observe = false
	fin.visible = false
	observation.visible = false
	scores.visible = false
	boutique.visible = true
	_pause.visible = false


func _sur_arene(vue: VueArene) -> void:
	_derniere_vue = vue
	hud.afficher(vue)
	boutique.afficher(vue)
	boutique.visible = source.cible_observee() == source.id_local()
	if vue.phase == Types.Phase.DEFAITE:
		_montrer_fin(false)
	elif vue.phase == Types.Phase.VICTOIRE:
		_montrer_fin(true)


func _sur_globale(vue: VueGlobale) -> void:
	_globale = vue
	scores.afficher(vue, source.id_local())
	if vue.termine and not _fin_affichee:
		_montrer_fin(_a_gagne(vue))
	if _fin_affichee:
		fin.afficher_classement(vue, source.id_local())
		_adapter_boutons_fin()
	if _observe:
		observation.afficher(vue, source.id_local(), source.cible_observee())
	_placer()


func _a_gagne(vue: VueGlobale) -> bool:
	for joueur: Dictionary in vue.joueurs:
		var id: int = joueur["id"]
		if id == source.id_local():
			return bool(joueur["victorieux"])
	return false


## Défaite ou victoire : l'écran de fin, une seule fois par partie.
func _montrer_fin(victoire: bool) -> void:
	if _fin_affichee:
		return
	_fin_affichee = true
	var vue := _derniere_vue if _derniere_vue != null else VueArene.new()
	if victoire:
		fin.afficher_victoire(vue, _globale)
	else:
		fin.afficher_defaite(vue, _globale)
	fin.visible = true
	observation.visible = false
	_adapter_boutons_fin()
	_placer()


## Le mode sans fin n'existe pas encore : son bouton reste là, grisé, avec une infobulle.
func _adapter_boutons_fin() -> void:
	var rejouer_bouton: Button = null
	for noeud: Node in fin.find_children("*", "Button", true, false):
		var bouton := noeud as Button
		if bouton.get_meta("action", "") == ACTION_SANS_FIN:
			bouton.disabled = true
			bouton.tooltip_text = tr("MENU_BIENTOT")
		elif bouton.get_meta("action", "") == ACTION_REJOUER:
			rejouer_bouton = bouton
	if rejouer_bouton != null and fin.is_inside_tree() and fin.visible:
		if (
			get_viewport().gui_get_focus_owner() == null
			or (get_viewport().gui_get_focus_owner() as Button).disabled
		):
			rejouer_bouton.grab_focus()


func _observer() -> void:
	_observe = true
	fin.visible = false
	if _globale != null:
		observation.afficher(_globale, source.id_local(), source.cible_observee())
	_placer()


func _rejouer() -> void:
	_lancer(randi())


func _demander_menu() -> void:
	if source != null:
		source.quitter_partie()
	retour_menu.emit("")


func _construire_pause() -> void:
	_pause = PanelContainer.new()
	_pause.name = "Pause"
	_pause.visible = false
	var colonne := VBoxContainer.new()
	_pause.add_child(colonne)
	var titre := Label.new()
	titre.text = tr("JEU_MENU_TITRE")
	colonne.add_child(titre)
	_reprendre = _bouton_pause("JEU_REPRENDRE", _basculer_pause)
	colonne.add_child(_reprendre)
	colonne.add_child(_bouton_pause("JEU_MENU_PRINCIPAL", _demander_menu))
	_racine.add_child(_pause)


func _bouton_pause(cle: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.text = tr(cle)
	bouton.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	bouton.pressed.connect(action)
	return bouton


func _basculer_pause() -> void:
	_pause.visible = not _pause.visible
	if _pause.visible:
		_placer()
		_reprendre.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(ACTION_MENU) and event.is_action_pressed(ACTION_MENU):
		_basculer_pause()
		get_viewport().set_input_as_handled()
		return
	var molette := event as InputEventMouseButton
	if molette == null or not molette.pressed or camera == null:
		return
	if molette.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.zoomer(-PAS_ZOOM * _sensibilite)
	elif molette.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.zoomer(PAS_ZOOM * _sensibilite)


# --- Mise en page ----------------------------------------------------------------------------


## Chaque panneau garde son contenu dans un conteneur : on le place d'après la taille de ce
## contenu (les `Control` racine des panneaux n'ont pas de taille propre).
func _placer() -> void:
	if _racine == null:
		return
	var zone := _racine.size
	hud.position = Vector2(MARGE, MARGE)
	var bas := _taille_contenu(boutique)
	boutique.position = Vector2(MARGE, maxf(MARGE, zone.y - bas.y - MARGE))
	var haut := _taille_contenu(scores)
	scores.position = Vector2(maxf(MARGE, (zone.x - haut.x) * 0.5), MARGE)
	observation.position = Vector2(
		maxf(MARGE, zone.x - observation.custom_minimum_size.x - MARGE), MARGE
	)
	var centre := _taille_contenu(fin)
	fin.position = ((zone - centre) * 0.5).max(Vector2(MARGE, MARGE))
	var menu := _pause.get_combined_minimum_size()
	_pause.position = ((zone - menu) * 0.5).max(Vector2(MARGE, MARGE))


static func _taille_contenu(panneau: Control) -> Vector2:
	var taille := Vector2.ZERO
	for enfant: Node in panneau.get_children():
		var controle := enfant as Control
		if controle != null:
			taille = taille.max(controle.get_combined_minimum_size())
	return taille
