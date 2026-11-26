class_name Hud
extends Control
## HUD de l'arène, en barre d'environ 40 px en haut de l'écran : une icône par information (or,
## revenu, manche, temps, armures de la prochaine manche, nombre d'armes), sans PV (ils sont sur
## la tour). Il lit une `VueArene` et ne calcule rien. L'information ne repose jamais sur l'icône
## ou la couleur seule : chaque case porte un nom accessible et une infobulle (« Or : 1 500 »),
## et chaque armure garde son symbole et son nom.

const HAUTEUR_LIGNE := 32.0
const MARGE_BARRE := 4
const COTE_ICONE := 28.0

const LIGNE_OR := 0
const LIGNE_REVENU := 1
const LIGNE_MANCHE := 2
const LIGNE_TEMPS := 3
const LIGNE_PROCHAINE := 4
const LIGNE_ARMES := 5
const NB_LIGNES := 6

## Clé du nom de chaque information (accessibilité et infobulle) et clé de son icône du thème.
const CLES_NOMS: Array[String] = [
	"HUD_OR", "HUD_REVENU", "HUD_MANCHE", "HUD_TEMPS", "HUD_PROCHAINE", "HUD_ARMES"
]
const NOMS_ICONES: Array[String] = ["or", "revenu", "manche", "temps", "armure", "armes"]
## Largeur minimale de la valeur de chaque information (0 : celle du texte).
const LARGEURS_VALEUR: Array[float] = [64.0, 44.0, 24.0, 44.0, 0.0, 28.0]
## Armures de la prochaine manche : une par famille, deux ou trois familles au plus.
const SEPARATEUR_ARMURES := " · "

var _cellules: Array[HBoxContainer] = []
var _icones: Array[TextureRect] = []
var _valeurs: Array[Label] = []
var _donnees: Donnees = null
var _barre: PanelContainer = null


func _init() -> void:
	_barre = PanelContainer.new()
	_barre.name = "Barre"
	_barre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barre.add_theme_stylebox_override("panel", _style_barre())
	add_child(_barre)
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 16)
	_barre.add_child(rangee)
	for i: int in NB_LIGNES:
		var cellule := HBoxContainer.new()
		cellule.name = "Ligne%d" % i
		cellule.add_theme_constant_override("separation", 6)
		# La case reçoit la souris : c'est elle qui porte l'infobulle de l'information.
		cellule.mouse_filter = Control.MOUSE_FILTER_STOP
		var icone := TextureRect.new()
		icone.name = "Icone%d" % i
		icone.texture = ThemeJeu.icone_hud(NOMS_ICONES[i])
		icone.custom_minimum_size = Vector2(COTE_ICONE, COTE_ICONE)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var valeur := _etiquette()
		valeur.name = "Valeur%d" % i
		valeur.custom_minimum_size.x = LARGEURS_VALEUR[i]
		valeur.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == LIGNE_MANCHE or i == LIGNE_PROCHAINE:
			# « Préparation » et trois armures sont plus longs que tout nombre : jamais tronqués.
			valeur.clip_text = false
			valeur.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		cellule.add_child(icone)
		cellule.add_child(valeur)
		rangee.add_child(cellule)
		_cellules.append(cellule)
		_icones.append(icone)
		_valeurs.append(valeur)


## Hauteur de la barre : celle de son contenu (une ligne et ses marges), environ 40 px.
func hauteur_barre() -> float:
	return _barre.get_combined_minimum_size().y


## Rectangle écran de la barre.
func rect_barre() -> Rect2:
	return _barre.get_global_rect()


## Fournit les noms des familles. Sans cet appel, le HUD reste lisible (armures seules) et ne
## signale aucune erreur.
func configurer(donnees: Donnees) -> void:
	_donnees = donnees


## Texte de la valeur d'une information (`LIGNE_*`), tel qu'affiché.
func valeur(ligne: int) -> String:
	return _valeurs[ligne].text


func afficher(vue: VueArene) -> void:
	_definir(LIGNE_OR, Nombres.groupe(vue.argent))
	_definir(LIGNE_REVENU, "+" + Nombres.groupe(vue.revenu))
	var manche := tr("HUD_PREPARATION") if vue.manche == 0 else Nombres.groupe(vue.manche)
	if vue.sans_fin:
		manche = tr("HUD_MANCHE_SANS_FIN") % manche
	_definir(LIGNE_MANCHE, manche)
	_definir(LIGNE_TEMPS, tr("HUD_SECONDES") % Nombres.groupe(ceili(vue.temps_restant)))
	var armures := armures_a_venir(vue)
	var texte_armures := SEPARATEUR_ARMURES.join(_libelles_armures(armures))
	_definir(
		LIGNE_PROCHAINE,
		tr("HUD_AUCUNE") if armures.is_empty() else texte_armures,
		_detail_prochaine(vue)
	)
	_valeurs[LIGNE_PROCHAINE].add_theme_color_override("font_color", ThemeJeu.PARCHEMIN)
	_definir(LIGNE_ARMES, Nombres.groupe(vue.armes.size()))


## Le libellé d'une armure porte son symbole et son nom : jamais la couleur seule.
static func libelle_armure(a: int) -> String:
	return (
		"%s %s"
		% [
			Apparence.symbole_armure(a),
			TranslationServer.translate(Apparence.cle_libelle_armure(a))
		]
	)


## Armures des familles de la prochaine manche, dans l'ordre de la vue : vide sans famille. Une
## vue qui ne porte que la famille majoritaire (`prochaine_famille`) donne sa seule armure.
static func armures_a_venir(vue: VueArene) -> Array[int]:
	var sortie: Array[int] = []
	for armure: int in vue.prochaines_armures:
		sortie.append(armure)
	if sortie.is_empty() and vue.prochaine_famille >= 0:
		sortie.append(vue.prochaine_armure)
	return sortie


static func _libelles_armures(armures: Array[int]) -> PackedStringArray:
	var sortie := PackedStringArray()
	for armure: int in armures:
		sortie.append(libelle_armure(armure))
	return sortie


## Une ligne par famille à venir : son nom puis son armure (l'infobulle de l'annonce).
func _detail_prochaine(vue: VueArene) -> String:
	var lignes := PackedStringArray()
	var familles: Array[int] = []
	for famille: int in vue.prochaines_familles:
		familles.append(famille)
	if familles.is_empty() and vue.prochaine_famille >= 0:
		familles.append(vue.prochaine_famille)
	var armures := armures_a_venir(vue)
	for i: int in familles.size():
		var armure := libelle_armure(armures[i]) if i < armures.size() else ""
		var nom := _nom_prochaine(familles[i])
		lignes.append(armure if nom.is_empty() else "%s (%s)" % [nom, armure])
	return "\n".join(lignes)


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


## Pose la valeur, puis le nom accessible et l'infobulle de la case : « Nom : valeur », ou le
## détail donné pour l'annonce des armures.
func _definir(ligne: int, valeur: String, detail: String = "") -> void:
	_valeurs[ligne].text = valeur
	var nom := tr(CLES_NOMS[ligne])
	var contenu := valeur if detail.is_empty() else detail
	var infobulle := "%s : %s" % [nom, contenu]
	_cellules[ligne].tooltip_text = infobulle
	_cellules[ligne].accessibility_name = infobulle
	_icones[ligne].accessibility_name = nom


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
	libelle.theme_type_variation = "Petit"
	libelle.custom_minimum_size = Vector2(0.0, HAUTEUR_LIGNE)
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	libelle.clip_text = true
	libelle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return libelle
