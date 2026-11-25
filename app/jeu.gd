class_name Jeu
extends Node
## Une partie en cours : source de vue, arène 3D, HUD, boutique, scores, observation et écran de
## fin, câblés ensemble. La source de vue est une `SourceLocale` (solo, créée ici) ou un `Client`
## déjà connecté (réseau, fourni par `Principal`) : tout passe par `SourceVue`.

## La joueuse veut revenir au menu (`motif` vide) ou la connexion est perdue (`motif` lisible).
signal retour_menu(motif: String)
## En réseau, l'écran de fin propose « Retour au salon » à la place de « Rejouer ».
signal retour_salon

const SCENE_ARENE := "res://scenes/arene_2d.tscn"
## Un cran de molette déplace le zoom de ce pas, multiplié par la sensibilité des réglages.
const PAS_ZOOM := 0.05
const ACTION_MENU := "menu_jeu"
const ACTION_SANS_FIN := "continuer_sans_fin"
const ACTION_REJOUER := "rejouer"
const HAUTEUR_CONTROLE := 48.0
const OPACITE_HUD_FIN := 0.35

## Fichier des réglages : le lanceur de tests le remplace par un dossier temporaire.
var chemin_reglages: String = Reglages.CHEMIN_DEFAUT
var nom_joueur: String = ""
var source: SourceVue = null
## Vrai quand la source est un `Client` fourni de l'extérieur (jamais libéré par `Jeu`).
var en_reseau: bool = false
var arene: Arene2D = null
var camera: CameraArene2D = null

var _donnees: Donnees = null
var _facteur: float = 1.0
var _sensibilite: float = 1.0
var _derniere_vue: VueArene = null
var _globale: VueGlobale = null
var _fin_affichee: bool = false
## Vrai dès que la source a accepté « continuer sans fin » : une vue de victoire arrivée en retard
## (réseau) ne doit pas rouvrir l'écran de fin.
var _sans_fin: bool = false
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
	ThemeJeu.appliquer(_racine)
	# Hors du sol de l'arène, le fond reprend l'encre de l'interface plutôt que le gris par défaut.
	RenderingServer.set_default_clear_color(ThemeJeu.JAUGE_FOND)
	fin.visible = false
	_construire_pause()
	_racine.resized.connect(_placer)
	fin.rejouer.connect(_rejouer)
	fin.quitter.connect(_demander_menu)
	fin.observer.connect(_observer)
	fin.continuer_sans_fin.connect(_continuer_sans_fin)
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
		_brancher(source)
	return _lancer(graine)


## Démarre une partie en réseau sur une source déjà connectée dont la partie a commencé. Faux,
## sans écran à moitié monté, si les données ou la source manquent.
func demarrer_reseau(donnees: Donnees, src: SourceVue) -> bool:
	if donnees == null or src == null:
		return false
	_donnees = donnees
	en_reseau = true
	_appliquer_reglages()
	source = src
	_brancher(src)
	_monter()
	return true


func _brancher(src: SourceVue) -> void:
	src.vue_arene_recue.connect(_sur_arene)
	src.vue_globale_recue.connect(_sur_globale)
	src.connexion_perdue.connect(_sur_perte)
	src.resultat_intention.connect(_sur_resultat)


func _sur_perte(motif: String) -> void:
	retour_menu.emit(motif)


func _lancer(graine: int) -> bool:
	var locale := source as SourceLocale
	locale.quitter_partie()
	var config := Partie.Config.new()
	config.graine = graine
	config.facteur_duree = _facteur
	if not locale.demarrer(_donnees, config, nom_joueur):
		return false
	_monter()
	return true


## Monte l'écran de la partie sur la source courante (solo ou réseau).
func _monter() -> void:
	_vider_ecran()
	if arene == null:
		arene = (load(SCENE_ARENE) as PackedScene).instantiate() as Arene2D
		arene.donnees = _donnees
		add_child(arene)
		move_child(arene, 0)
		camera = arene.find_children("*", "CameraArene2D", true, false)[0] as CameraArene2D
		arene.lier(source)
	arene.reinitialiser()
	hud.configurer(_donnees)
	boutique.configurer(_donnees, source)
	observation.configurer(source)


func _appliquer_reglages() -> void:
	var r := Reglages.charger(chemin_reglages)
	_sensibilite = r.sensibilite_zoom
	appliquer_fenetre(get_window(), r)


## Remet l'écran comme au premier instant d'une partie.
func _vider_ecran() -> void:
	_derniere_vue = null
	_globale = null
	_fin_affichee = false
	_sans_fin = false
	_observe = false
	fin.visible = false
	observation.visible = false
	scores.visible = false
	boutique.visible = true
	hud.modulate.a = 1.0
	_pause.visible = false


func _sur_arene(vue: VueArene) -> void:
	_derniere_vue = vue
	hud.afficher(vue)
	boutique.afficher(vue)
	boutique.visible = _boutique_active()
	if vue.phase == Types.Phase.DEFAITE:
		_montrer_fin(false)
	elif vue.phase == Types.Phase.VICTOIRE and not _sans_fin:
		_montrer_fin(true)


func _sur_globale(vue: VueGlobale) -> void:
	_globale = vue
	_nommer_tour(vue)
	scores.afficher(vue, source.id_local())
	if vue.termine and not _fin_affichee:
		_montrer_fin(_a_gagne(vue))
	if _fin_affichee:
		fin.afficher_classement(vue, source.id_local())
		_adapter_boutons_fin()
	if _observe:
		observation.afficher(vue, source.id_local(), source.cible_observee())
	_placer()


## La tour affichée est celle du joueur observé : sa couleur suit sa place dans la liste (la même
## pour tous les spectateurs) et son nom est écrit dessous.
func _nommer_tour(vue: VueGlobale) -> void:
	if arene == null or source == null:
		return
	var cible: int = source.cible_observee()
	for i: int in vue.joueurs.size():
		var joueur: Dictionary = vue.joueurs[i]
		if int(joueur["id"]) == cible:
			arene.definir_joueur(i + 1, String(joueur["nom"]))
			return


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
	var id_local := source.id_local() if source != null else -1
	if victoire:
		fin.afficher_victoire(vue, _globale, id_local)
	else:
		fin.afficher_defaite(vue, _globale, id_local)
	fin.visible = true
	# La partie est finie : la boutique disparaît (et ne reçoit plus d'entrée), le HUD s'estompe.
	boutique.visible = false
	hud.modulate.a = OPACITE_HUD_FIN
	observation.visible = false
	_adapter_boutons_fin()
	_placer()


## En réseau, « Rejouer » devient « Retour au salon ».
func _adapter_boutons_fin() -> void:
	var rejouer_bouton: Button = null
	for noeud: Node in fin.find_children("*", "Button", true, false):
		var bouton := noeud as Button
		if bouton.get_meta("action", "") == ACTION_REJOUER:
			rejouer_bouton = bouton
			if en_reseau:
				bouton.text = tr("SALON_RETOUR_SALON")
	if rejouer_bouton != null and fin.is_inside_tree() and fin.visible:
		if (
			get_viewport().gui_get_focus_owner() == null
			or (get_viewport().gui_get_focus_owner() as Button).disabled
		):
			rejouer_bouton.grab_focus()


func _continuer_sans_fin() -> void:
	if source != null:
		source.continuer_sans_fin()


## La source a répondu : si « sans fin » est accepté, l'écran de victoire cède la place à la partie.
func _sur_resultat(genre: String, code: int) -> void:
	if genre != "continuer_sans_fin" or code != Types.Resultat.OK:
		return
	_sans_fin = true
	_fin_affichee = false
	fin.visible = false
	boutique.visible = _boutique_active()
	hud.modulate.a = 1.0
	_placer()


func _observer() -> void:
	_observe = true
	fin.visible = false
	if _globale != null:
		observation.afficher(_globale, source.id_local(), source.cible_observee())
	_placer()


func _rejouer() -> void:
	# En réseau, le serveur ne relance pas la même partie : on retourne au salon.
	if en_reseau:
		retour_salon.emit()
		return
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
	if camera == null:
		return
	var pincement := event as InputEventMagnifyGesture
	if pincement != null:
		camera.zoomer_facteur(pincement.factor)
		return
	var molette := event as InputEventMouseButton
	if molette == null or not molette.pressed:
		return
	if molette.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.zoomer(-PAS_ZOOM * _sensibilite)
	elif molette.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.zoomer(PAS_ZOOM * _sensibilite)


# --- Mise en page ----------------------------------------------------------------------------


## La boutique ne sert qu'à la joueuse vivante qui regarde sa propre arène, partie en cours.
func _boutique_active() -> bool:
	return not _fin_affichee and source.cible_observee() == source.id_local()


func _placer() -> void:
	if _racine != null:
		placer_dans(_racine.size)


## Barre du HUD en haut, bandeau de la boutique en bas, arène visible entre les deux : la caméra
## centre la tour dans cette zone libre. Les panneaux modaux se centrent d'eux-mêmes.
func placer_dans(zone: Vector2) -> void:
	var hauteur_hud := hud.hauteur_barre()
	var hauteur_boutique := boutique.rect_bandeau_minimal().y
	var rects := MiseEnPage.calculer(zone, hauteur_hud, hauteur_boutique)
	var rect_hud: Rect2 = rects["hud"]
	var libre: Rect2 = rects["libre"]
	hud.position = rect_hud.position
	hud.size = rect_hud.size
	boutique.definir_zone_libre(libre)
	if camera != null:
		camera.cadrer(libre, zone)
	observation.position = Vector2(
		maxf(MiseEnPage.MARGE, zone.x - observation.custom_minimum_size.x - MiseEnPage.MARGE),
		libre.position.y + MiseEnPage.MARGE
	)
	var menu := _pause.get_combined_minimum_size()
	_pause.position = MiseEnPage.centrer(zone, menu).position
