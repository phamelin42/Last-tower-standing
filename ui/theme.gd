class_name ThemeJeu
extends RefCounted
## Thème commun de l'interface, aux couleurs de Tiny Swords (CC0) : boutons, panneaux et rubans du
## pack en tranches de neuf, police Metamorphous (OFL), pointeurs et icônes du pack. Il est
## construit en code et posé sur la racine de chaque écran par `appliquer`.
## Les panneaux sont les textures sculptées du pack, assombries : le texte clair y garde son
## contraste. Les boutons gardent les couleurs du pack, avec un texte d'encre foncée. Toutes les
## couleurs de texte et leurs fonds sont ici : `test_contraste.gd` et `test_theme_pack.gd` les
## mesurent, sur la couleur moyenne des textures.

## Tailles de base par rôle ; `taille` est le seul endroit où une taille de texte se décide.
const TAILLES: Dictionary = {"texte": 16, "petit": 16, "titre": 28}
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

## Texte d'encre des boutons du pack (fonds clairs) et son pendant inactif.
const ENCRE_TEXTE_BOUTON := Color("#101619")
const ENCRE_TEXTE_INACTIF := Color("#3f3329")
## Bord du pack (la teinte du cadre sculpté) : filet des barres pleine largeur.
const BORD_PACK := Color("#cab18d")

const DOSSIER_UI := "res://assets/tiny_swords/UI/"
const TEX_BOUTON := DOSSIER_UI + "Buttons/Button_Blue_3Slides.png"
const TEX_BOUTON_SURVOL := DOSSIER_UI + "Buttons/Button_Hover_3Slides.png"
const TEX_BOUTON_APPUI := DOSSIER_UI + "Buttons/Button_Blue_3Slides_Pressed.png"
const TEX_BOUTON_INACTIF := DOSSIER_UI + "Buttons/Button_Disable_3Slides.png"
const TEX_DANGER := DOSSIER_UI + "Buttons/Button_Red_3Slides.png"
const TEX_DANGER_APPUI := DOSSIER_UI + "Buttons/Button_Red_3Slides_Pressed.png"
const TEX_PANNEAU := DOSSIER_UI + "Banners/Carved_9Slides.png"
const TEX_RUBAN := DOSSIER_UI + "Ribbons/Ribbon_Yellow_3Slides.png"
const TEX_RUBAN_ROUGE := DOSSIER_UI + "Ribbons/Ribbon_Red_3Slides.png"
const TEX_RUBAN_BLEU := DOSSIER_UI + "Ribbons/Ribbon_Blue_3Slides.png"
const TEX_POINTEUR := DOSSIER_UI + "Pointers/01.png"
const ICONES := {
	"fermer": DOSSIER_UI + "Icons/Regular_01.png",
	"reglages": DOSSIER_UI + "Icons/Regular_02.png",
	"son": DOSSIER_UI + "Icons/Regular_03.png",
}
## Icônes de la barre du haut (une par information) : Ravenmore (CC BY 3.0) et le sablier de
## sonild (CC0). Chaque icône porte aussi un nom et une infobulle dans le HUD.
const ICONES_HUD := {
	"or": "res://assets/icones/ravenmore/coin.png",
	"revenu": "res://assets/icones/ravenmore/gemGreen.png",
	"manche": "res://assets/icones/ravenmore/map.png",
	"temps": "res://assets/icones/sablier/sablier.png",
	"armure": "res://assets/icones/ravenmore/shield.png",
	"armes": "res://assets/icones/ravenmore/sword.png",
}

## Repères de catégorie d'une offre (`CategorieOffre`), dans l'ordre de `Types.Categorie` : ruban du
## pack (rouge pour l'arme, bleu pour l'amélioration, jaune pour le revenu), icône et type de
## thème du ruban. Le mot écrit accompagne toujours la couleur.
const TEXTURES_RUBAN_CATEGORIE: Array[String] = [TEX_RUBAN_ROUGE, TEX_RUBAN_BLEU, TEX_RUBAN]
const ICONES_CATEGORIE: Array[String] = [
	"res://assets/icones/ravenmore/sword.png",
	"res://assets/icones/ravenmore/gemBlue.png",
	"res://assets/icones/ravenmore/coin.png",
]
const TYPES_RUBAN_CATEGORIE: Array[String] = ["RubanArme", "RubanAmelioration", "RubanRevenu"]
## Texte du ruban de catégorie : une encre plus sombre que celle des boutons, pour atteindre 4,5:1
## sur le rouge du ruban (vérifié par `test_theme_pack`).
const ENCRE_RUBAN_CATEGORIE := Color("#050708")
## Le ruban de catégorie n'utilise que le corps du ruban du pack (sans ses queues) : une bande
## qui s'allonge avec le mot et tient sur une seule ligne basse.
const CORPS_RUBAN := Rect2(64.0, 0.0, 64.0, 52.0)
## Toutes les textures citées par le thème (le test vérifie qu'elles existent).
const TEXTURES: Array[String] = [
	TEX_BOUTON,
	TEX_BOUTON_SURVOL,
	TEX_BOUTON_APPUI,
	TEX_BOUTON_INACTIF,
	TEX_DANGER,
	TEX_DANGER_APPUI,
	TEX_PANNEAU,
	TEX_RUBAN,
	TEX_RUBAN_ROUGE,
	TEX_RUBAN_BLEU,
	TEX_POINTEUR,
	DOSSIER_UI + "Icons/Regular_01.png",
	DOSSIER_UI + "Icons/Regular_02.png",
	DOSSIER_UI + "Icons/Regular_03.png",
]
const POLICE := "res://assets/polices/metamorphous/metamorphous-latin-400-normal.woff2"
## Repli pour tout caractère absent de Metamorphous : symboles de rareté et d'armure, ∅, espace
## fine.
const POLICE_REPLI := "res://assets/polices/dejavu-sans/dejavu-sans-latin-400-normal.woff2"
## Zone des icônes (64 px, glyphe centré) : on rogne les marges vides.
const ZONE_ICONE := Rect2(16.0, 9.0, 32.0, 32.0)
const POINTEUR_POINTE := Vector2(22.0, 17.0)

## Panneaux et cartes : la texture sculptée, multipliée pour retrouver `ENCRE` et `ENCRE_CARTE`
## (moyenne du pack : #cab18d).
const TEINTE_PANNEAU := Color(0.134, 0.203, 0.277)
const TEINTE_CARTE := Color(0.188, 0.294, 0.411)
## Bouton rouge appuyé : trop sombre pour un texte d'encre, on l'éclaircit.
const TEINTE_DANGER_APPUI := Color(1.25, 1.25, 1.25)

const TYPE_DANGER := "BoutonDanger"
## Case d'une grille d'icônes : un bouton (choisir une arme) ou un cadre fixe (amélioration).
## Bouton d'une seule ligne dans un espace compté (« Acheter » des cartes de la boutique).
const TYPE_ACHAT := "BoutonAchat"
## « Acheter » d'une offre trop chère (S19) : le bouton reste actif (le clic part, la source dit
## « or insuffisant »), mais il garde l'aspect inactif au survol, à l'appui et au clavier ; seul
## son filet de focus le distingue d'un bouton réellement désactivé.
const TYPE_ACHAT_INSUFFISANT := "BoutonAchatInsuffisant"
## Ses marges verticales, dans la proportion 14 : 22 de la plaque du pack (le texte tombe au milieu
## du corps, l'ombre est en dessous) : 59 px de haut avec celles du bouton ordinaire, 47 avec ces
## marges, que la hauteur minimale des contrôles porte à 48 px.
const MARGE_HAUT_ACHAT := 8.0
const MARGE_BAS_ACHAT := 16.0
const MARGE_VERTICALE_CARTE := 4.0
const TYPE_CELLULE := "CelluleIcone"
const TYPE_CELLULE_FIXE := "CelluleFixe"
const TYPE_RUBAN := "TitreRuban"

static var _cache: Theme = null
static var _police: Font = null


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


## Boîte d'un panneau opaque : la texture sculptée du pack, en neuf tranches.
static func boite_panneau() -> StyleBoxTexture:
	return _tranches(TEX_PANNEAU, 16, 16, 16, 16, MARGE_PANNEAU, TEINTE_PANNEAU)


## Barre pleine largeur (HUD, bandeau de la boutique) : aplat d'encre, filet de la teinte du pack.
## Les appelants retirent les filets des côtés qui touchent le bord de l'écran.
static func boite_barre() -> StyleBoxFlat:
	var b := boite(ENCRE, BORD_PACK, FILET, MARGE_PANNEAU)
	b.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	b.shadow_size = 8
	return b


## Style en tranches de neuf, pixels nets : les marges sont celles de la texture, jamais étirées.
static func _tranches(
	chemin: String, gauche: int, haut: int, droite: int, bas: int, interieur: int, teinte: Color
) -> StyleBoxTexture:
	var b := StyleBoxTexture.new()
	b.texture = load(chemin) as Texture2D
	b.texture_margin_left = gauche
	b.texture_margin_top = haut
	b.texture_margin_right = droite
	b.texture_margin_bottom = bas
	b.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	b.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	b.modulate_color = teinte
	b.set_content_margin_all(interieur)
	return b


## Couleur moyenne du centre de la texture (le tiers du milieu), teinte comprise : c'est le fond
## sur lequel le texte se pose. L'alpha dit si le panneau est opaque.
static func fond_moyen(boite_texture: StyleBoxTexture) -> Color:
	var image := boite_texture.texture.get_image()
	var w := image.get_width()
	var h := image.get_height()
	var somme := Color(0.0, 0.0, 0.0, 0.0)
	var n := 0
	for y: int in range(h / 3, 2 * h / 3):
		for x: int in range(w / 3, 2 * w / 3):
			var p := image.get_pixel(x, y)
			somme += Color(p.r * p.a, p.g * p.a, p.b * p.a, p.a)
			n += 1
	var alpha := somme.a / float(n)
	var m := boite_texture.modulate_color
	return Color(
		clampf(somme.r / somme.a * m.r, 0.0, 1.0),
		clampf(somme.g / somme.a * m.g, 0.0, 1.0),
		clampf(somme.b / somme.a * m.b, 0.0, 1.0),
		alpha * m.a
	)


## Chaque texte du thème avec le fond qui le porte : de quoi mesurer tous les contrastes.
static func couples_de_texte() -> Array[Dictionary]:
	var t := creer()
	var liste: Array[Dictionary] = []
	var cles := {
		"normal": "font_color",
		"hover": "font_hover_color",
		"pressed": "font_pressed_color",
		"disabled": "font_disabled_color",
	}
	for type: String in ["Button", TYPE_DANGER]:
		for etat: String in cles:
			var fond := fond_moyen(t.get_stylebox(etat, type) as StyleBoxTexture)
			(
				liste
				. append(
					{
						"nom": "%s/%s" % [type, etat],
						"texte": t.get_color(str(cles[etat]), type),
						"fond": fond,
					}
				)
			)
	var panneau := fond_moyen(boite_panneau())
	var carte := fond_moyen(t.get_stylebox("panel", "Carte") as StyleBoxTexture)
	var textes := {
		"PARCHEMIN": PARCHEMIN, "PARCHEMIN_ATTENU": PARCHEMIN_ATTENU, "LAITON_CLAIR": LAITON_CLAIR
	}
	for nom: String in textes:
		var texte: Color = textes[nom]
		liste.append({"nom": "%s sur panneau" % nom, "texte": texte, "fond": panneau})
		liste.append({"nom": "%s sur carte" % nom, "texte": texte, "fond": carte})
	(
		liste
		. append(
			{
				"nom": "titre sur ruban",
				"texte": t.get_color("font_color", TYPE_RUBAN),
				"fond": fond_moyen(t.get_stylebox("normal", TYPE_RUBAN) as StyleBoxTexture),
			}
		)
	)
	for c: int in TYPES_RUBAN_CATEGORIE.size():
		var bande := t.get_stylebox("panel", TYPES_RUBAN_CATEGORIE[c]) as StyleBoxTexture
		(
			liste
			. append(
				{
					"nom": "mot du ruban %s" % TYPES_RUBAN_CATEGORIE[c],
					"texte": ENCRE_RUBAN_CATEGORIE,
					"fond": fond_moyen(bande),
				}
			)
		)
	return liste


## Pose le thème, le filtre au plus proche voisin (pixels nets, hérité par les enfants) et le
## pointeur du pack sur la racine d'un écran.
static func appliquer(racine: Control) -> void:
	racine.theme = creer()
	racine.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pointeur := load(TEX_POINTEUR) as Texture2D
	if pointeur != null:
		Input.set_custom_mouse_cursor(pointeur, Input.CURSOR_ARROW, POINTEUR_POINTE)


## Icône de la barre du haut (`ICONES_HUD`), entière.
static func icone_hud(nom: String) -> Texture2D:
	return load(str(ICONES_HUD[nom])) as Texture2D


## Icône d'une catégorie d'offre (`ICONES_CATEGORIE`), `null` pour une catégorie inconnue.
static func icone_categorie(categorie: int) -> Texture2D:
	if categorie < 0 or categorie >= ICONES_CATEGORIE.size():
		return null
	return load(ICONES_CATEGORIE[categorie]) as Texture2D


## Icône du pack pour une action (`ICONES`), rognée à son glyphe.
static func icone(nom: String) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(str(ICONES[nom])) as Texture2D
	atlas.region = ZONE_ICONE
	return atlas


## Taille de texte d'un rôle (« texte », « petit », « titre »), multipliée par `echelle` (la
## « Taille de l'interface » de `Reglages`). Un rôle inconnu prend la taille du texte.
static func taille(role: String, echelle: float = 1.0) -> int:
	var base: int = TAILLES.get(role, TAILLES["texte"])
	return maxi(1, roundi(base * echelle))


## La police du jeu ; tout signe qu'elle n'a pas vient de DejaVu Sans, puis du moteur.
static func police() -> Font:
	if _police == null:
		var v := FontVariation.new()
		v.base_font = load(POLICE) as Font
		v.fallbacks = [load(POLICE_REPLI) as Font, ThemeDB.fallback_font]
		_police = v
	return _police


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
	t.default_font = police()
	t.default_font_size = taille("texte")
	t.set_font_size("font_size", "Label", taille("texte"))
	t.set_font_size("font_size", "TooltipLabel", taille("texte"))
	t.set_color("font_color", "Label", PARCHEMIN)
	t.set_font_size("font_size", "Button", taille("texte"))
	t.set_font_size("font_size", "LineEdit", taille("texte"))
	t.set_font_size("font_size", "CheckBox", taille("texte"))
	t.set_stylebox("panel", "PanelContainer", boite_panneau())
	t.set_stylebox("panel", "Panel", boite_panneau())
	_boutons(t)
	_cellules(t)
	_champs(t)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "GridContainer", 16)
	t.set_constant("v_separation", "GridContainer", 0)
	t.set_type_variation("Titre", "Label")
	t.set_font_size("font_size", "Titre", taille("titre"))
	t.set_color("font_color", "Titre", LAITON_CLAIR)
	t.set_type_variation("Petit", "Label")
	t.set_font_size("font_size", "Petit", taille("petit"))
	t.set_type_variation("TitrePetit", "Label")
	t.set_font_size("font_size", "TitrePetit", taille("texte"))
	t.set_color("font_color", "TitrePetit", LAITON_CLAIR)
	t.set_type_variation(TYPE_RUBAN, "Label")
	t.set_font_size("font_size", TYPE_RUBAN, taille("titre"))
	t.set_color("font_color", TYPE_RUBAN, ENCRE_TEXTE_BOUTON)
	var ruban := _tranches(TEX_RUBAN, 56, 12, 56, 20, 0, Color.WHITE)
	ruban.content_margin_left = 64.0
	ruban.content_margin_right = 64.0
	ruban.content_margin_top = 10.0
	ruban.content_margin_bottom = 20.0
	t.set_stylebox("normal", TYPE_RUBAN, ruban)
	for c: int in TYPES_RUBAN_CATEGORIE.size():
		t.set_type_variation(TYPES_RUBAN_CATEGORIE[c], "PanelContainer")
		t.set_stylebox("panel", TYPES_RUBAN_CATEGORIE[c], _bande_ruban(TEXTURES_RUBAN_CATEGORIE[c]))
	t.set_type_variation("Carte", "PanelContainer")
	var carte := _tranches(TEX_PANNEAU, 16, 16, 16, 16, 8, TEINTE_CARTE)
	# Haut et bas plus serrés que les côtés : la boutique doit tenir dans 45 % de la hauteur, même
	# avec les noms les plus longs et la note « Or insuffisant » sur chaque carte (S15).
	carte.content_margin_top = MARGE_VERTICALE_CARTE
	carte.content_margin_bottom = MARGE_VERTICALE_CARTE
	t.set_stylebox("panel", "Carte", carte)
	return t


## Corps d'un ruban (`CORPS_RUBAN`) en bande : répété en largeur, étiré en hauteur, sans marge
## verticale pour que le ruban reste bas.
static func _bande_ruban(chemin: String) -> StyleBoxTexture:
	var b := StyleBoxTexture.new()
	b.texture = load(chemin) as Texture2D
	b.region_rect = CORPS_RUBAN
	b.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	b.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	b.content_margin_left = 6.0
	b.content_margin_right = 6.0
	b.content_margin_top = 0.0
	b.content_margin_bottom = 0.0
	return b


static func _style_bouton(chemin: String, teinte: Color = Color.WHITE) -> StyleBoxTexture:
	# Textures de 64 px de haut (corps de 56 px et ombre de 8 px) : on ne les étire qu'en largeur,
	# le centre se répète, les extrémités arrondies gardent leur forme. Le haut et le bas laissent
	# la place du contour et de l'ombre pour que le texte tombe au milieu du corps.
	var b := _tranches(chemin, 40, 0, 40, 0, 0, teinte)
	b.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	b.content_margin_left = 24.0
	b.content_margin_right = 24.0
	b.content_margin_top = 14.0
	b.content_margin_bottom = 22.0
	return b


## Boutons du pack : bleu pour l'ordinaire, rouge pour ce qui détruit ou quitte. Le texte est
## d'encre foncée (les textures sont claires) ; l'état se lit aussi à la forme du bouton.
## Cases des grilles d'icônes : aplat d'encre et filet de laiton, filet clair au survol et à la
## sélection ; le focus clavier garde son filet épais. L'icône prend toute la case.
static func _cellules(t: Theme) -> void:
	var normal := boite(ENCRE_CARTE, LAITON, FILET, 4)
	var survol := boite(ENCRE_SURVOL, LAITON_CLAIR, FILET, 4)
	var choisie := boite(ENCRE_APPUI, LAITON_CLAIR, FILET_FOCUS, 4)
	var focus := boite(Color(0.0, 0.0, 0.0, 0.0), LAITON_CLAIR, FILET_FOCUS, 4)
	for b: StyleBoxFlat in [normal, survol, choisie, focus]:
		b.set_content_margin_all(4.0)
	t.set_type_variation(TYPE_CELLULE, "Button")
	t.set_stylebox("normal", TYPE_CELLULE, normal)
	t.set_stylebox("hover", TYPE_CELLULE, survol)
	t.set_stylebox("pressed", TYPE_CELLULE, choisie)
	t.set_stylebox("hover_pressed", TYPE_CELLULE, choisie)
	t.set_stylebox("disabled", TYPE_CELLULE, normal)
	t.set_stylebox("focus", TYPE_CELLULE, focus)
	t.set_constant("icon_max_width", TYPE_CELLULE, 36)
	t.set_type_variation(TYPE_CELLULE_FIXE, "PanelContainer")
	t.set_stylebox("panel", TYPE_CELLULE_FIXE, normal)


static func _boutons(t: Theme) -> void:
	var focus := boite(Color(0.0, 0.0, 0.0, 0.0), LAITON_CLAIR, FILET_FOCUS, 0)
	focus.expand_margin_left = 3.0
	focus.expand_margin_right = 3.0
	focus.expand_margin_top = 3.0
	focus.expand_margin_bottom = 3.0
	t.set_constant("icon_max_width", "Button", 32)
	var jeux := {
		"Button":
		[TEX_BOUTON, TEX_BOUTON_SURVOL, TEX_BOUTON_APPUI, TEX_BOUTON_INACTIF, Color.WHITE],
		TYPE_DANGER:
		[TEX_DANGER, TEX_BOUTON_SURVOL, TEX_DANGER_APPUI, TEX_BOUTON_INACTIF, TEINTE_DANGER_APPUI],
	}
	t.set_type_variation(TYPE_DANGER, "Button")
	for type: String in jeux:
		var l: Array = jeux[type]
		t.set_stylebox("normal", type, _style_bouton(str(l[0])))
		t.set_stylebox("hover", type, _style_bouton(str(l[1])))
		t.set_stylebox("pressed", type, _style_bouton(str(l[2]), l[4] as Color))
		t.set_stylebox("disabled", type, _style_bouton(str(l[3])))
		t.set_stylebox("focus", type, focus)
		if type == "Button":
			t.set_type_variation(TYPE_ACHAT, "Button")
			for etat: String in ["normal", "hover", "pressed", "disabled"]:
				var serre := t.get_stylebox(etat, type).duplicate() as StyleBoxTexture
				serre.content_margin_top = MARGE_HAUT_ACHAT
				serre.content_margin_bottom = MARGE_BAS_ACHAT
				t.set_stylebox(etat, TYPE_ACHAT, serre)
			t.set_type_variation(TYPE_ACHAT_INSUFFISANT, TYPE_ACHAT)
			for etat: String in ["normal", "hover", "pressed", "disabled"]:
				t.set_stylebox(etat, TYPE_ACHAT_INSUFFISANT, t.get_stylebox("disabled", TYPE_ACHAT))
			for cle: String in [
				"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
			]:
				t.set_color(cle, TYPE_ACHAT_INSUFFISANT, ENCRE_TEXTE_INACTIF)
		for cle: String in [
			"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
		]:
			t.set_color(cle, type, ENCRE_TEXTE_BOUTON)
		t.set_color("font_disabled_color", type, ENCRE_TEXTE_INACTIF)
	# Les cases à cocher gardent les aplats d'encre : elles ne sont pas des boutons du pack.
	var marge_v := 12
	var normal := boite(ENCRE_BOUTON, LAITON, FILET, 10)
	var survol := boite(ENCRE_SURVOL, LAITON_CLAIR, FILET, 10)
	var appui := boite(ENCRE_APPUI, LAITON_CLAIR, FILET, 10)
	var inactif := boite(ENCRE_INACTIF, ENCRE_BOUTON, FILET, 10)
	var focus_case := boite(Color(0.0, 0.0, 0.0, 0.0), LAITON_CLAIR, FILET_FOCUS, 10)
	for b: StyleBoxFlat in [normal, survol, appui, inactif, focus_case]:
		b.content_margin_top = marge_v
		b.content_margin_bottom = marge_v
	t.set_stylebox("normal", "CheckBox", normal)
	t.set_stylebox("hover", "CheckBox", survol)
	t.set_stylebox("pressed", "CheckBox", appui)
	t.set_stylebox("disabled", "CheckBox", inactif)
	t.set_stylebox("focus", "CheckBox", focus_case)
	t.set_color("font_color", "CheckBox", PARCHEMIN)
	t.set_color("font_hover_color", "CheckBox", PARCHEMIN)
	t.set_color("font_pressed_color", "CheckBox", PARCHEMIN)
	t.set_color("font_focus_color", "CheckBox", PARCHEMIN)
	t.set_color("font_disabled_color", "CheckBox", TEXTE_INACTIF)


static func _champs(t: Theme) -> void:
	var normal := boite(JAUGE_FOND, LAITON, FILET, 10)
	var focus := boite(JAUGE_FOND, LAITON_CLAIR, FILET_FOCUS, 10)
	t.set_stylebox("normal", "LineEdit", normal)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", PARCHEMIN)
	t.set_color("caret_color", "LineEdit", LAITON_CLAIR)
