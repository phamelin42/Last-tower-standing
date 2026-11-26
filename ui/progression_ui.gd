class_name ProgressionUi
extends Control
## Écran « Progression » du menu : les statistiques du profil, puis chaque défi de `data/defis.json`
## avec son état écrit (« Réussi » ou « Pas encore réussi ») et le skin qu'il débloque. Il lit un
## `Profil` et les données, il ne calcule aucun défi. Chaque défi est un bouton inerte : il prend
## le focus, donc la liste se parcourt au clavier et à la manette et défile avec lui.

signal retour

const HAUTEUR_CONTROLE := 48.0
const ESPACEMENT := 8
## Hauteur de la liste des défis : au-delà, elle défile (la fenêtre la plus petite, 75 %).
const HAUTEUR_LISTE := 240.0
const LARGEUR_COLONNE := 420.0

var boutons_defis: Array[Button] = []
var bouton_retour: Button

var _colonne: VBoxContainer
var _titre: Label
var _statistiques: VBoxContainer
var _liste: VBoxContainer


func _init() -> void:
	ThemeJeu.appliquer(self)
	set_anchors_preset(PRESET_FULL_RECT)
	_colonne = VBoxContainer.new()
	_colonne.custom_minimum_size = Vector2(LARGEUR_COLONNE, 0.0)
	_colonne.set_anchors_preset(PRESET_FULL_RECT)
	_colonne.add_theme_constant_override("separation", ESPACEMENT)
	add_child(_colonne)
	_colonne.minimum_size_changed.connect(update_minimum_size)
	_titre = Label.new()
	_titre.text = tr("PROGRESSION_TITRE")
	_colonne.add_child(_titre)
	_statistiques = VBoxContainer.new()
	_colonne.add_child(_statistiques)
	var entete := Label.new()
	entete.text = tr("PROGRESSION_DEFIS")
	_colonne.add_child(entete)
	var defilement := ScrollContainer.new()
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defilement.follow_focus = true
	defilement.custom_minimum_size = Vector2(0.0, HAUTEUR_LISTE)
	defilement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_colonne.add_child(defilement)
	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(_liste)
	bouton_retour = Button.new()
	bouton_retour.name = "Retour"
	bouton_retour.text = tr("PROGRESSION_RETOUR")
	bouton_retour.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	bouton_retour.pressed.connect(retour.emit)
	_colonne.add_child(bouton_retour)


## Un `Control` ne tient pas compte de ses enfants : sans cette taille, le cadre du menu donne
## une hauteur nulle à l'écran.
func _get_minimum_size() -> Vector2:
	return _colonne.get_combined_minimum_size() if _colonne != null else Vector2.ZERO


## Clé du nom d'un skin dans `i18n/textes_progression.csv`.
static func cle_skin(id: String) -> String:
	return "SKIN_" + id.to_upper()


## Nom lisible d'un skin.
static func nom_skin(id: String) -> String:
	return TranslationServer.translate(cle_skin(id))


## Affiche le profil : statistiques, puis un bouton par défi dans l'ordre du fichier de données.
func configurer(profil: Profil, donnees: Donnees) -> void:
	_vider(_statistiques)
	_vider(_liste)
	boutons_defis.clear()
	_ligne(tr("PROGRESSION_PARTIES") % Nombres.groupe(profil.parties))
	_ligne(tr("PROGRESSION_MEILLEURE_MANCHE") % Nombres.groupe(profil.meilleure_manche))
	for id: String in donnees.defis:
		var defi: Dictionary = donnees.defis[id]
		var reussi := profil.defis_reussis.has(id)
		var bouton := Button.new()
		bouton.name = "Defi_" + id
		bouton.set_meta("defi", id)
		bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bouton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bouton.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
		bouton.focus_mode = Control.FOCUS_ALL
		_styler_ligne(bouton)
		bouton.text = (
			"%s — %s\n%s\n%s"
			% [
				String(defi["nom"]),
				tr("PROGRESSION_REUSSI") if reussi else tr("PROGRESSION_A_FAIRE"),
				String(defi["texte"]),
				tr("PROGRESSION_DEBLOQUE") % nom_skin(String(defi["skin"])),
			]
		)
		_liste.add_child(bouton)
		boutons_defis.append(bouton)


## Textes actuellement lisibles à l'écran (pour les tests et les captures).
func textes() -> PackedStringArray:
	var sortie := PackedStringArray()
	for noeud: Node in find_children("*", "Label", true, false):
		var libelle := noeud as Label
		if libelle.text != "":
			sortie.append(libelle.text)
	for bouton: Button in boutons_defis:
		sortie.append(bouton.text)
	sortie.append(bouton_retour.text)
	return sortie


## Une ligne de liste plate, sans le grand cadre des boutons : le texte reste lisible sur trois
## lignes. Le focus se voit par un bord clair, pas par la couleur du fond seule.
func _styler_ligne(bouton: Button) -> void:
	var repos := ThemeJeu.boite(ThemeJeu.ENCRE_CARTE, ThemeJeu.ENCRE_CARTE, 2, 8)
	var survol := ThemeJeu.boite(ThemeJeu.ENCRE_SURVOL, ThemeJeu.JAUGE_FOND, 2, 8)
	var focus := ThemeJeu.boite(ThemeJeu.ENCRE_CARTE, ThemeJeu.PARCHEMIN, 3, 8)
	for etat: String in ["normal", "pressed", "disabled"]:
		bouton.add_theme_stylebox_override(etat, repos)
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("focus", focus)
	for couleur: String in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_hover_pressed_color",
		"font_disabled_color"
	]:
		bouton.add_theme_color_override(couleur, ThemeJeu.PARCHEMIN)


func _ligne(texte: String) -> void:
	var libelle := Label.new()
	libelle.text = texte
	_statistiques.add_child(libelle)


func _vider(conteneur: Node) -> void:
	for enfant: Node in conteneur.get_children():
		conteneur.remove_child(enfant)
		enfant.free()
