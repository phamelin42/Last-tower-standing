class_name ConnexionUi
extends Control
## Les deux pages du multijoueur avant le salon : « Créer une partie » (nom du salon et port) et
## « Rejoindre une partie » (salons trouvés sur le réseau local, plus adresse et port saisis à la
## main). Elle ne fait aucun réseau : elle valide la saisie, annonce ce qui est demandé et affiche
## le message d'erreur que `Principal` lui renvoie.

signal creer_demande(nom_salon: String, port: int)
signal rejoindre_demande(adresse: String, port: int)
signal retour_demande

const HAUTEUR_CONTROLE := 48.0
const LARGEUR_COLONNE := 460.0
const TAILLE_TEXTE := 16
const TAILLE_TITRE := 28
const ESPACEMENT := 12
const PORT_DEFAUT := 7777
const PORT_MAX := 65535
const ADRESSE_MAX := 253

var champ_nom_salon: LineEdit
var champ_port_creer: LineEdit
var bouton_creer: Button
var champ_adresse: LineEdit
var champ_port_rejoindre: LineEdit
var bouton_rejoindre_adresse: Button
var boutons_retour: Array[Button] = []

var _page_creer: PanelContainer
var _page_rejoindre: PanelContainer
var _message_creer: Label
var _message_rejoindre: Label
var _liste: VBoxContainer
var _vide: Label
var _salons: Array[Dictionary] = []


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
	_construire_creer(centre)
	_construire_rejoindre(centre)
	visible = false


# --- Pages -------------------------------------------------------------------------------------


## Ouvre la page « Créer » ; le nom du salon propose « Salon de <nom du joueur> ».
func ouvrir_creer(nom_joueur: String) -> void:
	visible = true
	_page_rejoindre.visible = false
	_page_creer.visible = true
	champ_nom_salon.text = tr("CONNEXION_NOM_SALON_DEFAUT") % nom_joueur
	champ_nom_salon.text = champ_nom_salon.text.substr(0, Protocole.MAX_NOM)
	champ_port_creer.text = str(PORT_DEFAUT)
	afficher_erreur_creer("")
	if is_inside_tree():
		bouton_creer.grab_focus()


func ouvrir_rejoindre() -> void:
	visible = true
	_page_creer.visible = false
	_page_rejoindre.visible = true
	champ_adresse.text = ""
	champ_port_rejoindre.text = str(PORT_DEFAUT)
	afficher_erreur_rejoindre("")
	afficher_salons([])
	if is_inside_tree():
		champ_adresse.grab_focus()


func fermer() -> void:
	visible = false


func page_creer_visible() -> bool:
	return visible and _page_creer.visible


func page_rejoindre_visible() -> bool:
	return visible and _page_rejoindre.visible


func afficher_erreur_creer(texte: String) -> void:
	_message_creer.text = texte
	_message_creer.visible = not texte.is_empty()


## Avertissement, pas une erreur : le salon est ouvert, seuls les joueurs d'Internet ne peuvent
## pas le rejoindre.
func afficher_echec_redirection() -> void:
	afficher_erreur_creer(tr("CONNEXION_UPNP_ECHEC"))


func afficher_erreur_rejoindre(texte: String) -> void:
	_message_rejoindre.text = texte
	_message_rejoindre.visible = not texte.is_empty()


## Les salons trouvés : une ligne (nom, joueurs) et un bouton « Rejoindre » chacune.
func afficher_salons(salons: Array[Dictionary]) -> void:
	_salons = salons.duplicate()
	for enfant: Node in _liste.get_children():
		_liste.remove_child(enfant)
		enfant.queue_free()
	_vide.visible = salons.is_empty()
	for i: int in salons.size():
		var s := salons[i]
		var ligne := HBoxContainer.new()
		ligne.name = "Salon%d" % i
		var libelle := Label.new()
		libelle.text = tr("CONNEXION_SALON_LIGNE") % [s["nom"], s["joueurs"], s["max"]]
		libelle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		libelle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		libelle.custom_minimum_size = Vector2(240.0, HAUTEUR_CONTROLE)
		libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ligne.add_child(libelle)
		var bouton := Button.new()
		bouton.name = "Rejoindre"
		bouton.text = tr("CONNEXION_REJOINDRE")
		bouton.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
		bouton.pressed.connect(_sur_salon.bind(i))
		ligne.add_child(bouton)
		_liste.add_child(ligne)


## Textes affichés dans la liste, une ligne par salon (pour les tests et les captures).
func lignes_salons() -> PackedStringArray:
	var sortie := PackedStringArray()
	for ligne: Node in _liste.get_children():
		sortie.append((ligne.get_child(0) as Label).text)
	return sortie


## Presse le bouton « Rejoindre » de la ligne `i`.
func presser_salon(i: int) -> void:
	if i >= 0 and i < _liste.get_child_count():
		(
			((_liste.get_child(i) as Control).find_child("Rejoindre", false, false) as Button)
			. pressed
			. emit()
		)


# --- Validation --------------------------------------------------------------------------------


## Port saisi : `0` si ce n'est pas un entier entre 1 et 65535.
static func port_valide(texte: String) -> int:
	var propre := texte.strip_edges()
	if propre.is_empty() or propre.length() > 5 or not propre.is_valid_int():
		return 0
	if propre.begins_with("-") or propre.begins_with("+"):
		return 0
	var port := propre.to_int()
	return port if port >= 1 and port <= PORT_MAX else 0


## Adresse saisie, nettoyée ; vide si invalide (espace ou caractère de contrôle à l'intérieur,
## ou plus de 253 caractères).
static func adresse_valide(texte: String) -> String:
	var propre := texte.strip_edges()
	if propre.length() > ADRESSE_MAX:
		return ""
	for i: int in propre.length():
		var c := propre.unicode_at(i)
		if c <= 32 or c == 127:
			return ""
	return propre


func _sur_creer() -> void:
	var nom := champ_nom_salon.text.strip_edges()
	if nom.is_empty() or nom.length() > Protocole.MAX_NOM:
		afficher_erreur_creer(tr("CONNEXION_ERREUR_NOM"))
		return
	var port := port_valide(champ_port_creer.text)
	if port == 0:
		afficher_erreur_creer(tr("CONNEXION_ERREUR_PORT"))
		return
	afficher_erreur_creer("")
	creer_demande.emit(nom, port)


func _sur_adresse() -> void:
	var saisie := champ_adresse.text.strip_edges()
	if saisie.is_empty():
		afficher_erreur_rejoindre(tr("CONNEXION_ERREUR_ADRESSE"))
		return
	var adresse := adresse_valide(saisie)
	if adresse.is_empty():
		afficher_erreur_rejoindre(tr("CONNEXION_ERREUR_ADRESSE_FORME"))
		return
	var port := port_valide(champ_port_rejoindre.text)
	if port == 0:
		afficher_erreur_rejoindre(tr("CONNEXION_ERREUR_PORT"))
		return
	afficher_erreur_rejoindre("")
	rejoindre_demande.emit(adresse, port)


func _sur_salon(i: int) -> void:
	if i < 0 or i >= _salons.size():
		return
	var s := _salons[i]
	afficher_erreur_rejoindre("")
	rejoindre_demande.emit(String(s["adresse"]), int(s["port"]))


# --- Construction ------------------------------------------------------------------------------


func _construire_creer(centre: CenterContainer) -> void:
	_page_creer = PanelContainer.new()
	_page_creer.name = "PageCreer"
	_page_creer.visible = false
	centre.add_child(_page_creer)
	var colonne := _colonne(_page_creer)
	colonne.add_child(_titre("CONNEXION_CREER_TITRE"))
	colonne.add_child(_libelle("CONNEXION_NOM_SALON"))
	champ_nom_salon = _champ("ChampNomSalon", Protocole.MAX_NOM)
	colonne.add_child(champ_nom_salon)
	colonne.add_child(_libelle("CONNEXION_PORT"))
	champ_port_creer = _champ("ChampPortCreer", 5)
	colonne.add_child(champ_port_creer)
	_message_creer = _message()
	colonne.add_child(_message_creer)
	bouton_creer = _bouton("Creer", "CONNEXION_CREER", _sur_creer)
	colonne.add_child(bouton_creer)
	colonne.add_child(_bouton_retour())


func _construire_rejoindre(centre: CenterContainer) -> void:
	_page_rejoindre = PanelContainer.new()
	_page_rejoindre.name = "PageRejoindre"
	_page_rejoindre.visible = false
	centre.add_child(_page_rejoindre)
	var colonne := _colonne(_page_rejoindre)
	colonne.add_child(_titre("CONNEXION_REJOINDRE_TITRE"))
	colonne.add_child(_libelle("CONNEXION_SALONS_LOCAUX"))
	_vide = Label.new()
	_vide.name = "Vide"
	_vide.text = tr("CONNEXION_AUCUN_SALON")
	_vide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(_vide)
	_liste = VBoxContainer.new()
	_liste.name = "Salons"
	colonne.add_child(_liste)
	colonne.add_child(_libelle("CONNEXION_ADRESSE"))
	champ_adresse = _champ("ChampAdresse", ADRESSE_MAX)
	colonne.add_child(champ_adresse)
	colonne.add_child(_libelle("CONNEXION_PORT"))
	champ_port_rejoindre = _champ("ChampPortRejoindre", 5)
	colonne.add_child(champ_port_rejoindre)
	_message_rejoindre = _message()
	colonne.add_child(_message_rejoindre)
	bouton_rejoindre_adresse = _bouton(
		"RejoindreAdresse", "CONNEXION_REJOINDRE_ADRESSE", _sur_adresse
	)
	colonne.add_child(bouton_rejoindre_adresse)
	colonne.add_child(_bouton_retour())


func _colonne(cadre: PanelContainer) -> VBoxContainer:
	var colonne := VBoxContainer.new()
	colonne.custom_minimum_size = Vector2(LARGEUR_COLONNE, 0.0)
	colonne.add_theme_constant_override("separation", ESPACEMENT)
	cadre.add_child(colonne)
	return colonne


func _titre(cle: String) -> Label:
	var titre := Label.new()
	titre.text = tr(cle)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.theme_type_variation = ThemeJeu.TYPE_RUBAN
	titre.add_theme_font_size_override("font_size", TAILLE_TITRE)
	return titre


func _libelle(cle: String) -> Label:
	var libelle := Label.new()
	libelle.text = tr(cle)
	return libelle


func _champ(nom: String, longueur_max: int) -> LineEdit:
	var champ := LineEdit.new()
	champ.name = nom
	champ.max_length = longueur_max
	champ.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	return champ


func _message() -> Label:
	var message := Label.new()
	message.name = "Message"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.visible = false
	return message


func _bouton(nom: String, cle: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.name = nom
	bouton.text = tr(cle)
	bouton.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	bouton.pressed.connect(action)
	return bouton


func _bouton_retour() -> Button:
	var bouton := _bouton("Retour", "CONNEXION_RETOUR", retour_demande.emit)
	boutons_retour.append(bouton)
	return bouton
