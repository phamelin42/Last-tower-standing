class_name MenuPrincipal
extends Control
## Menu principal : « Jouer seul », « Créer une partie », « Rejoindre une partie », « Réglages » et
## « Quitter », avec le nom du joueur. Il n'ouvre rien lui-même : il annonce ce que la joueuse
## demande, `Principal` agit.

signal solo_demande(nom: String)
signal creer_demande(nom: String)
signal rejoindre_demande(nom: String)
signal quitter_demande
## Les réglages ont changé (écran des réglages) : `Principal` les applique à la fenêtre.
signal reglages_modifies(r: Reglages)

const HAUTEUR_CONTROLE := 48.0
const LARGEUR_COLONNE := 420.0
const TAILLE_TEXTE := 16
const TAILLE_TITRE := 34
const ESPACEMENT := 12

## Fichier des réglages : le lanceur de tests le remplace par un dossier temporaire.
var chemin_reglages: String = Reglages.CHEMIN_DEFAUT
var bouton_solo: Button
var bouton_creer: Button
var bouton_rejoindre: Button
var bouton_reglages: Button
var bouton_quitter: Button
var champ_nom: LineEdit

var _cadre_accueil: PanelContainer
var _cadre_reglages: PanelContainer
var _accueil: VBoxContainer
var _message: Label
var _reglages: ReglagesUi
var _page_reglages: VBoxContainer
var _bouton_retour: Button


func _init() -> void:
	ThemeJeu.appliquer(self)
	set_anchors_preset(PRESET_FULL_RECT)
	add_theme_font_size_override("font_size", TAILLE_TEXTE)
	var fond := ColorRect.new()
	fond.name = "Fond"
	fond.color = ThemeJeu.JAUGE_FOND
	fond.set_anchors_preset(PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fond)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(PRESET_FULL_RECT)
	add_child(centre)

	_cadre_accueil = PanelContainer.new()
	_cadre_accueil.name = "CadreAccueil"
	centre.add_child(_cadre_accueil)
	_accueil = VBoxContainer.new()
	_accueil.name = "Accueil"
	_accueil.custom_minimum_size = Vector2(LARGEUR_COLONNE, 0.0)
	_accueil.add_theme_constant_override("separation", ESPACEMENT)
	_cadre_accueil.add_child(_accueil)

	var titre := Label.new()
	titre.name = "Titre"
	titre.text = tr("MENU_TITRE")
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.theme_type_variation = ThemeJeu.TYPE_RUBAN
	titre.add_theme_font_size_override("font_size", TAILLE_TITRE)
	_accueil.add_child(titre)

	var libelle := Label.new()
	libelle.text = tr("MENU_NOM_JOUEUR")
	_accueil.add_child(libelle)
	champ_nom = LineEdit.new()
	champ_nom.name = "ChampNom"
	champ_nom.max_length = Reglages.NOM_MAX
	champ_nom.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	_accueil.add_child(champ_nom)

	bouton_solo = _bouton("JouerSeul", "MENU_JOUER_SEUL", _sur_solo)
	bouton_creer = _bouton("Creer", "MENU_CREER", _sur_creer)
	bouton_rejoindre = _bouton("Rejoindre", "MENU_REJOINDRE", _sur_rejoindre)
	bouton_reglages = _bouton("Reglages", "MENU_REGLAGES", _sur_reglages)
	bouton_quitter = _bouton("Quitter", "MENU_QUITTER", quitter_demande.emit)
	bouton_quitter.theme_type_variation = ThemeJeu.TYPE_DANGER
	bouton_reglages.icon = ThemeJeu.icone("reglages")
	_message = Label.new()
	_message.name = "Message"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	_accueil.add_child(_message)

	_cadre_reglages = PanelContainer.new()
	_cadre_reglages.name = "CadreReglages"
	_cadre_reglages.visible = false
	centre.add_child(_cadre_reglages)
	_page_reglages = VBoxContainer.new()
	_page_reglages.name = "PageReglages"
	_cadre_reglages.add_child(_page_reglages)
	_reglages = ReglagesUi.new()
	_reglages.custom_minimum_size = Vector2(LARGEUR_COLONNE, 0.0)
	_reglages.modifies.connect(reglages_modifies.emit)
	_page_reglages.add_child(_reglages)
	_bouton_retour = Button.new()
	_bouton_retour.text = tr("MENU_RETOUR")
	_bouton_retour.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	_bouton_retour.pressed.connect(_sur_retour)
	_bouton_retour.icon = ThemeJeu.icone("fermer")
	_page_reglages.add_child(_bouton_retour)


func _ready() -> void:
	bouton_solo.grab_focus()


## Lit les réglages sur disque : le nom est prérempli, l'écran des réglages les montre.
func configurer(chemin: String = Reglages.CHEMIN_DEFAUT) -> void:
	chemin_reglages = chemin
	var r := Reglages.charger(chemin)
	champ_nom.text = r.nom_joueur
	_reglages.chemin = chemin
	_reglages.configurer(r)


## Nom saisi, nettoyé ; le nom par défaut si le champ est vide.
func nom_joueur() -> String:
	var propre := Reglages.texte_propre(champ_nom.text, Reglages.NOM_MAX)
	return propre if not propre.is_empty() else tr("MENU_NOM_PAR_DEFAUT")


## Un message lisible sous les boutons (données invalides, connexion perdue…).
func afficher_message(texte: String) -> void:
	_message.text = texte
	_message.visible = not texte.is_empty()


func page_reglages_visible() -> bool:
	return _cadre_reglages.visible


func ouvrir_reglages() -> void:
	_sur_reglages()


func _sur_solo() -> void:
	solo_demande.emit(nom_joueur())


func _sur_creer() -> void:
	creer_demande.emit(nom_joueur())


func _sur_rejoindre() -> void:
	rejoindre_demande.emit(nom_joueur())


func _sur_reglages() -> void:
	_cadre_accueil.visible = false
	_cadre_reglages.visible = true
	_bouton_retour.grab_focus()


func _sur_retour() -> void:
	_cadre_reglages.visible = false
	_cadre_accueil.visible = true
	bouton_solo.grab_focus()


func _bouton(nom: String, cle: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.name = nom
	bouton.text = tr(cle)
	bouton.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	if action.is_valid():
		bouton.pressed.connect(action)
	_accueil.add_child(bouton)
	return bouton
