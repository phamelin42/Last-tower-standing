class_name Hud
extends Control
## HUD de l'arène, en barre en haut de l'écran : PV de la tour (jauge), or, revenu, manche, temps,
## prochaine famille et armure, armes. Il lit une `VueArene` et ne calcule rien. Chaque ligne est
## une étiquette et sa valeur, à 48 px de haut, en 16 px au moins. L'armure garde son symbole et
## son nom : la couleur ne la porte jamais seule.

const HAUTEUR_LIGNE := 48.0
const MARGE_BARRE := 6
const LARGEUR_JAUGE := 160.0
const SEUIL_PV_BAS := 0.3

const LIGNE_PV := 0
const LIGNE_OR := 1
const LIGNE_REVENU := 2
const LIGNE_MANCHE := 3
const LIGNE_TEMPS := 4
const LIGNE_PROCHAINE := 5
const LIGNE_ARMES := 6
const NB_LIGNES := 7

## Largeur minimale de la valeur de chaque ligne (0 : celle du texte).
const LARGEURS_VALEUR: Array[float] = [0.0, 72.0, 48.0, 28.0, 48.0, 190.0, 48.0]

var _cles: Array[Label] = []
var _valeurs: Array[Label] = []
var _donnees: Donnees = null
var _jauge: ProgressBar = null
var _barre: PanelContainer = null


func _init() -> void:
	_barre = PanelContainer.new()
	_barre.name = "Barre"
	_barre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barre.add_theme_stylebox_override("panel", _style_barre())
	add_child(_barre)
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 10)
	_barre.add_child(rangee)
	for i: int in NB_LIGNES:
		var cle := _etiquette()
		var valeur := _etiquette()
		cle.clip_text = false
		cle.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		cle.add_theme_color_override("font_color", ThemeJeu.PARCHEMIN_ATTENU)
		valeur.custom_minimum_size.x = LARGEURS_VALEUR[i]
		if i == LIGNE_MANCHE:
			# « Préparation » est plus long que tout numéro de manche : il s'étend, jamais tronqué.
			valeur.clip_text = false
			valeur.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		_cles.append(cle)
		_valeurs.append(valeur)
		var cellule := HBoxContainer.new()
		cellule.add_theme_constant_override("separation", 6)
		cellule.add_child(cle)
		if i == LIGNE_PV:
			cellule.add_child(_construire_jauge(valeur))
		else:
			cellule.add_child(valeur)
		if i == LIGNE_PROCHAINE:
			cellule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cellule.size_flags_stretch_ratio = 2.0
			valeur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rangee.add_child(cellule)


## Hauteur de la barre : celle de son contenu (une ligne de 48 px et ses marges).
func hauteur_barre() -> float:
	return _barre.get_combined_minimum_size().y


## Rectangle écran de la barre.
func rect_barre() -> Rect2:
	return _barre.get_global_rect()


## Fournit les noms des familles et la capacité d'armes. Sans cet appel, le HUD reste lisible
## (armure seule, nombre d'armes) et ne signale aucune erreur.
func configurer(donnees: Donnees) -> void:
	_donnees = donnees


func afficher(vue: VueArene) -> void:
	_definir(
		LIGNE_PV,
		tr("HUD_PV"),
		(
			tr("HUD_PV_VALEUR")
			% [Nombres.groupe(roundi(vue.tour_pv)), Nombres.groupe(roundi(vue.tour_pv_max))]
		)
	)
	_jauge.max_value = maxf(vue.tour_pv_max, 1.0)
	_jauge.value = clampf(vue.tour_pv, 0.0, _jauge.max_value)
	var bas := vue.tour_pv < vue.tour_pv_max * SEUIL_PV_BAS
	var remplissage := ThemeJeu.JAUGE_BASSE if bas else ThemeJeu.JAUGE_PLEINE
	_jauge.add_theme_stylebox_override("fill", ThemeJeu.boite(remplissage, remplissage, 0))
	_definir(LIGNE_OR, tr("HUD_OR"), Nombres.groupe(vue.argent))
	_definir(LIGNE_REVENU, tr("HUD_REVENU"), "+" + Nombres.groupe(vue.revenu))
	var manche := tr("HUD_PREPARATION") if vue.manche == 0 else Nombres.groupe(vue.manche)
	if vue.sans_fin:
		manche = tr("HUD_MANCHE_SANS_FIN") % manche
	_definir(LIGNE_MANCHE, tr("HUD_MANCHE"), manche)
	_definir(
		LIGNE_TEMPS, tr("HUD_TEMPS"), tr("HUD_SECONDES") % Nombres.groupe(ceili(vue.temps_restant))
	)
	_definir(LIGNE_PROCHAINE, tr("HUD_PROCHAINE"), _prochaine(vue))
	var couleur := (
		ThemeJeu.PARCHEMIN
		if vue.prochaine_famille < 0
		else Apparence.couleur_texte_armure(vue.prochaine_armure)
	)
	_valeurs[LIGNE_PROCHAINE].add_theme_color_override("font_color", couleur)
	_definir(LIGNE_ARMES, tr("HUD_ARMES"), _armes(vue))


## Le libellé d'une armure porte son symbole et son nom : jamais la couleur seule.
static func libelle_armure(a: int) -> String:
	return (
		"%s %s"
		% [
			Apparence.symbole_armure(a),
			TranslationServer.translate(Apparence.cle_libelle_armure(a))
		]
	)


func _prochaine(vue: VueArene) -> String:
	if vue.prochaine_famille < 0:
		return tr("HUD_AUCUNE")
	var armure := libelle_armure(vue.prochaine_armure)
	var nom := _nom_prochaine(vue.prochaine_famille)
	if nom.is_empty():
		return armure
	return "%s (%s)" % [nom, armure]


## Index 0 à n-1 : une famille ; n : le convoi ; n+1 : le boss (convention de `Apparence`).
func _nom_prochaine(index: int) -> String:
	if _donnees == null or index < 0:
		return ""
	var nb := _donnees.familles.size()
	if index < nb:
		var famille: Dictionary = _donnees.familles[index]
		var nom_famille: String = famille["nom"]
		return nom_famille
	if index == nb:
		var nom_convoi: String = _donnees.convoi["nom"]
		return nom_convoi
	if index == nb + 1:
		var nom_boss: String = _donnees.boss["nom"]
		return nom_boss
	return ""


func _armes(vue: VueArene) -> String:
	var equipees := Nombres.groupe(vue.armes.size())
	if _donnees == null:
		return equipees
	var capacite: int = int(_donnees.partie["emplacements_armes"])
	return tr("HUD_ARMES_VALEUR") % [equipees, Nombres.groupe(capacite)]


func _definir(ligne: int, cle: String, valeur: String) -> void:
	_cles[ligne].text = cle
	_valeurs[ligne].text = valeur
	_valeurs[ligne].tooltip_text = valeur


## La valeur des PV se pose sur la jauge ; l'étiquette garde sa place dans l'ordre des lignes.
func _construire_jauge(valeur: Label) -> Control:
	var pile := Control.new()
	pile.name = "Jauge"
	pile.custom_minimum_size = Vector2(LARGEUR_JAUGE, HAUTEUR_LIGNE)
	_jauge = ProgressBar.new()
	_jauge.show_percentage = false
	_jauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_jauge.max_value = 1.0
	_jauge.value = 1.0
	_jauge.add_theme_stylebox_override(
		"background", ThemeJeu.boite(ThemeJeu.JAUGE_FOND, ThemeJeu.LAITON, 2)
	)
	_jauge.add_theme_stylebox_override(
		"fill", ThemeJeu.boite(ThemeJeu.JAUGE_PLEINE, ThemeJeu.JAUGE_PLEINE, 0)
	)
	pile.add_child(_jauge)
	valeur.set_anchors_preset(Control.PRESET_FULL_RECT)
	valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	valeur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.add_child(valeur)
	return pile


func _style_barre() -> StyleBoxFlat:
	var boite := ThemeJeu.boite_barre()
	boite.set_content_margin_all(MARGE_BARRE)
	boite.content_margin_left = ThemeJeu.MARGE_PANNEAU
	boite.content_margin_right = ThemeJeu.MARGE_PANNEAU
	boite.set_corner_radius_all(0)
	boite.border_width_top = 0
	boite.border_width_left = 0
	boite.border_width_right = 0
	return boite


func _etiquette() -> Label:
	var libelle := Label.new()
	# Metamorphous est plus large que l'ancienne police : la barre ne tient sinon pas à 1 152 px.
	libelle.theme_type_variation = "Petit"
	libelle.custom_minimum_size = Vector2(0.0, HAUTEUR_LIGNE)
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	libelle.clip_text = true
	libelle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return libelle
