class_name ReglagesUi
extends Control
## Écran des réglages : volume, plein écran, taille du texte (trois niveaux), sensibilité du
## zoom, nom du joueur et dernière adresse. Chaque modification est écrite tout de suite
## (`Reglages.sauver`) puis annoncée par `modifies`. Les commandes font 48 px de haut au moins,
## les textes 16 px au moins, à chaque niveau d'échelle.

signal modifies(r: Reglages)

const HAUTEUR_CONTROLE := 48.0
const ESPACEMENT := 8

const CLE_TITRE := "REGLAGES_TITRE"
const CLES_TAILLE: Array[String] = [
	"REGLAGES_TAILLE_NORMALE", "REGLAGES_TAILLE_GRANDE", "REGLAGES_TAILLE_TRES_GRANDE"
]
const CLE_ECHEC := "REGLAGES_ECHEC_SAUVEGARDE"

## Dossier du fichier de réglages : le lanceur de tests le remplace par un dossier temporaire.
var chemin: String = Reglages.CHEMIN_DEFAUT
var volume: HSlider
var plein_ecran: CheckButton
var taille: OptionButton
var zoom: HSlider
var nom: LineEdit
var adresse: LineEdit
var afficher_ips: CheckButton

var _r: Reglages = Reglages.new()
var _taille_texte: int = Reglages.TAILLE_TEXTE_BASE
var _etat: Label
var _colonne: VBoxContainer


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var colonne := VBoxContainer.new()
	_colonne = colonne
	colonne.add_theme_constant_override("separation", ESPACEMENT)
	add_child(colonne)
	colonne.minimum_size_changed.connect(update_minimum_size)

	var titre := Label.new()
	titre.text = tr(CLE_TITRE)
	colonne.add_child(titre)

	volume = HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	_ajouter(colonne, "REGLAGES_VOLUME", volume)
	volume.value_changed.connect(_sur_volume)

	plein_ecran = CheckButton.new()
	plein_ecran.text = tr("REGLAGES_PLEIN_ECRAN")
	_ajouter_sans_libelle(colonne, plein_ecran)
	plein_ecran.toggled.connect(_sur_plein_ecran)

	taille = OptionButton.new()
	for cle: String in CLES_TAILLE:
		taille.add_item(tr(cle))
	_ajouter(colonne, "REGLAGES_TAILLE_TEXTE", taille)
	taille.item_selected.connect(_sur_taille)

	zoom = HSlider.new()
	zoom.min_value = Reglages.SENSIBILITE_MIN
	zoom.max_value = Reglages.SENSIBILITE_MAX
	zoom.step = 0.05
	_ajouter(colonne, "REGLAGES_ZOOM", zoom)
	zoom.value_changed.connect(_sur_zoom)

	nom = LineEdit.new()
	nom.max_length = Reglages.NOM_MAX
	_ajouter(colonne, "REGLAGES_NOM", nom)
	nom.text_submitted.connect(func(_texte: String) -> void: _sur_nom())
	nom.focus_exited.connect(_sur_nom)

	adresse = LineEdit.new()
	adresse.max_length = Reglages.ADRESSE_MAX
	_ajouter(colonne, "REGLAGES_ADRESSE", adresse)
	adresse.text_submitted.connect(func(_texte: String) -> void: _sur_adresse())
	adresse.focus_exited.connect(_sur_adresse)

	afficher_ips = CheckButton.new()
	afficher_ips.text = tr("REGLAGES_AFFICHER_IPS")
	_ajouter_sans_libelle(colonne, afficher_ips)
	afficher_ips.toggled.connect(_sur_afficher_ips)

	_etat = Label.new()
	colonne.add_child(_etat)
	appliquer_echelle(Reglages.ECHELLES[0])


## Un `Control` ne tient pas compte de ses enfants : sans cette taille, la page du menu lui donne
## une hauteur nulle et le bouton « Retour » se pose sur les champs.
func _get_minimum_size() -> Vector2:
	return _colonne.get_combined_minimum_size() if _colonne != null else Vector2.ZERO


## Affiche les réglages lus. Ne rien écrire ici : l'affichage ne déclenche aucune sauvegarde.
func configurer(r: Reglages) -> void:
	_r = r
	var echelle := Reglages.echelle_valide(r.echelle_ui)
	volume.set_value_no_signal(r.volume_general)
	taille.select(Reglages.ECHELLES.find(echelle))
	plein_ecran.set_pressed_no_signal(r.plein_ecran)
	zoom.set_value_no_signal(r.sensibilite_zoom)
	nom.text = r.nom_joueur
	adresse.text = r.derniere_adresse
	afficher_ips.set_pressed_no_signal(r.afficher_ips)
	appliquer_echelle(echelle)


## Taille de texte de tout l'écran, héritée par les commandes : 16 px au niveau 1,0.
func appliquer_echelle(echelle: float) -> void:
	_taille_texte = Reglages.taille_texte_pour(echelle)
	add_theme_font_size_override("font_size", _taille_texte)


func taille_texte() -> int:
	return _taille_texte


func controles() -> Array[Control]:
	var liste: Array[Control] = []
	liste.append(volume)
	liste.append(plein_ecran)
	liste.append(taille)
	liste.append(zoom)
	liste.append(nom)
	liste.append(adresse)
	liste.append(afficher_ips)
	return liste


func _ajouter(colonne: VBoxContainer, cle_libelle: String, commande: Control) -> void:
	var libelle := Label.new()
	libelle.text = tr(cle_libelle)
	colonne.add_child(libelle)
	_ajouter_sans_libelle(colonne, commande)


func _ajouter_sans_libelle(colonne: VBoxContainer, commande: Control) -> void:
	commande.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	commande.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_child(commande)


func _sur_volume(valeur: float) -> void:
	_r.volume_general = valeur
	_enregistrer()


func _sur_plein_ecran(actif: bool) -> void:
	_r.plein_ecran = actif
	_enregistrer()


func _sur_afficher_ips(actif: bool) -> void:
	_r.afficher_ips = actif
	_enregistrer()


func _sur_taille(index: int) -> void:
	_r.echelle_ui = Reglages.ECHELLES[index]
	appliquer_echelle(_r.echelle_ui)
	_enregistrer()


func _sur_zoom(valeur: float) -> void:
	_r.sensibilite_zoom = valeur
	_enregistrer()


func _sur_nom() -> void:
	_r.nom_joueur = nom.text
	_r.normaliser()
	nom.text = _r.nom_joueur
	_enregistrer()


func _sur_adresse() -> void:
	_r.derniere_adresse = adresse.text
	_r.normaliser()
	adresse.text = _r.derniere_adresse
	_enregistrer()


## Une écriture refusée ne se tait pas : la lectrice voit que son réglage n'est pas gardé.
func _enregistrer() -> void:
	if _r.sauver(chemin):
		_etat.text = ""
	else:
		_etat.text = tr(CLE_ECHEC)
	modifies.emit(_r)
