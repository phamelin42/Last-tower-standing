class_name ThemeJeu
extends RefCounted
## Thème commun de l'interface : une tour de garde artisanale (encre verdâtre, laiton, parchemin).
## Il est construit en code, sans ressource externe, et posé sur la racine de chaque écran.
## Toutes les couleurs de texte et leurs fonds sont ici : `test_contraste.gd` les mesure.

const TAILLE_TEXTE := 16
const TAILLE_TITRE := 28
const HAUTEUR_CONTROLE := 48.0
const RAYON := 6
const FILET := 2
const FILET_FOCUS := 3
const MARGE_PANNEAU := 12

const ENCRE := Color("#1b2427")
const ENCRE_CARTE := Color("#26343a")
const ENCRE_BOUTON := Color("#2f4046")
const ENCRE_SURVOL := Color("#3b5159")
const ENCRE_APPUI := Color("#1f2b2f")
const ENCRE_INACTIF := Color("#222b2e")
const LAITON := Color("#c99a43")
const LAITON_CLAIR := Color("#f0cd7a")
const PARCHEMIN := Color("#f1e7d0")
const PARCHEMIN_ATTENU := Color("#b9b3a1")
const TEXTE_INACTIF := Color("#a3aba7")
## Jauge de PV : le texte parchemin se pose sur ces remplissages sombres.
const JAUGE_FOND := Color("#0f1618")
const JAUGE_PLEINE := Color("#2a6b4a")
const JAUGE_BASSE := Color("#8e2f25")

static var _cache: Theme = null


## Le thème partagé (créé une fois).
static func creer() -> Theme:
	if _cache == null:
		_cache = _construire()
	return _cache


static func boite(fond: Color, bord: Color, filet: int = FILET, marge: int = 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fond
	b.border_color = bord
	b.set_border_width_all(filet)
	b.set_corner_radius_all(RAYON)
	if marge > 0:
		b.set_content_margin_all(marge)
	return b


## Boîte d'un panneau opaque : bord laiton, léger relief.
static func boite_panneau(fond: Color = ENCRE) -> StyleBoxFlat:
	var b := boite(fond, LAITON, FILET, MARGE_PANNEAU)
	b.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	b.shadow_size = 8
	return b


## Rapport de contraste WCAG entre deux couleurs.
static func contraste(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	return 0.2126 * _lineaire(c.r) + 0.7152 * _lineaire(c.g) + 0.0722 * _lineaire(c.b)


static func _lineaire(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


static func _construire() -> Theme:
	var t := Theme.new()
	t.default_font_size = TAILLE_TEXTE
	t.set_font_size("font_size", "Label", TAILLE_TEXTE)
	t.set_color("font_color", "Label", PARCHEMIN)
	t.set_font_size("font_size", "Button", TAILLE_TEXTE)
	t.set_font_size("font_size", "LineEdit", TAILLE_TEXTE)
	t.set_font_size("font_size", "CheckBox", TAILLE_TEXTE)
	t.set_stylebox("panel", "PanelContainer", boite_panneau())
	t.set_stylebox("panel", "Panel", boite_panneau())
	_boutons(t)
	_champs(t)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "GridContainer", 16)
	t.set_constant("v_separation", "GridContainer", 0)
	t.set_type_variation("Titre", "Label")
	t.set_font_size("font_size", "Titre", TAILLE_TITRE)
	t.set_color("font_color", "Titre", LAITON_CLAIR)
	t.set_type_variation("Carte", "PanelContainer")
	t.set_stylebox("panel", "Carte", boite(ENCRE_CARTE, LAITON, 1, 8))
	return t


static func _boutons(t: Theme) -> void:
	var marge_v := 12
	var normal := boite(ENCRE_BOUTON, LAITON, FILET, 10)
	var survol := boite(ENCRE_SURVOL, LAITON_CLAIR, FILET, 10)
	var appui := boite(ENCRE_APPUI, LAITON_CLAIR, FILET, 10)
	var inactif := boite(ENCRE_INACTIF, ENCRE_BOUTON, FILET, 10)
	var focus := boite(Color(0.0, 0.0, 0.0, 0.0), LAITON_CLAIR, FILET_FOCUS, 10)
	for b: StyleBoxFlat in [normal, survol, appui, inactif, focus]:
		b.content_margin_top = marge_v
		b.content_margin_bottom = marge_v
	for type: String in ["Button", "CheckBox"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, survol)
		t.set_stylebox("pressed", type, appui)
		t.set_stylebox("disabled", type, inactif)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, PARCHEMIN)
		t.set_color("font_hover_color", type, PARCHEMIN)
		t.set_color("font_pressed_color", type, PARCHEMIN)
		t.set_color("font_focus_color", type, PARCHEMIN)
		t.set_color("font_disabled_color", type, TEXTE_INACTIF)


static func _champs(t: Theme) -> void:
	var normal := boite(JAUGE_FOND, LAITON, FILET, 10)
	var focus := boite(JAUGE_FOND, LAITON_CLAIR, FILET_FOCUS, 10)
	t.set_stylebox("normal", "LineEdit", normal)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", PARCHEMIN)
	t.set_color("caret_color", "LineEdit", LAITON_CLAIR)
