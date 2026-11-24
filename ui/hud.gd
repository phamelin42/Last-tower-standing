class_name Hud
extends Control
## HUD de l'arène : PV de la tour, or, revenu, manche, temps, prochaine armure et armes. Il lit
## une `VueArene` et ne calcule rien. Chaque ligne est une étiquette et sa valeur, à 48 px de
## haut, en 16 px au moins : la lectrice le lit à un mètre.

const HAUTEUR_LIGNE := 48.0
const TAILLE_TEXTE := 16
## Espace fine insécable : séparateur des milliers à la française, sans rupture de ligne.
const SEPARATEUR_MILLIERS := " "

const LIGNE_PV := 0
const LIGNE_OR := 1
const LIGNE_REVENU := 2
const LIGNE_MANCHE := 3
const LIGNE_TEMPS := 4
const LIGNE_PROCHAINE := 5
const LIGNE_ARMES := 6
const NB_LIGNES := 7

var _cles: Array[Label] = []
var _valeurs: Array[Label] = []


func _init() -> void:
	add_theme_font_size_override("font_size", TAILLE_TEXTE)
	var grille := GridContainer.new()
	grille.columns = 2
	add_child(grille)
	for i: int in NB_LIGNES:
		var cle := _etiquette()
		var valeur := _etiquette()
		grille.add_child(cle)
		grille.add_child(valeur)
		_cles.append(cle)
		_valeurs.append(valeur)


func afficher(vue: VueArene) -> void:
	_definir(
		LIGNE_PV,
		tr("HUD_PV"),
		tr("HUD_PV_VALEUR") % [nombre(roundi(vue.tour_pv)), nombre(roundi(vue.tour_pv_max))]
	)
	_definir(LIGNE_OR, tr("HUD_OR"), nombre(vue.argent))
	_definir(LIGNE_REVENU, tr("HUD_REVENU"), "+" + nombre(vue.revenu))
	var manche := tr("HUD_PREPARATION") if vue.manche == 0 else nombre(vue.manche)
	_definir(LIGNE_MANCHE, tr("HUD_MANCHE"), manche)
	_definir(LIGNE_TEMPS, tr("HUD_TEMPS"), tr("HUD_SECONDES") % nombre(ceili(vue.temps_restant)))
	var prochaine := (
		tr("HUD_AUCUNE") if vue.prochaine_famille < 0 else libelle_armure(vue.prochaine_armure)
	)
	_definir(LIGNE_PROCHAINE, tr("HUD_PROCHAINE"), prochaine)
	_definir(LIGNE_ARMES, tr("HUD_ARMES"), nombre(vue.armes.size()))


## Le libellé d'une armure porte son symbole et son nom : jamais la couleur seule.
static func libelle_armure(a: int) -> String:
	return (
		"%s %s"
		% [
			Apparence.symbole_armure(a),
			TranslationServer.translate(Apparence.cle_libelle_armure(a))
		]
	)


## Groupe les milliers : 999 999, et jamais de séparateur sous mille.
static func nombre(valeur: int) -> String:
	var chiffres := str(absi(valeur))
	var sortie := ""
	var compte := 0
	for i: int in range(chiffres.length() - 1, -1, -1):
		if compte > 0 and compte % 3 == 0:
			sortie = SEPARATEUR_MILLIERS + sortie
		sortie = chiffres[i] + sortie
		compte += 1
	return "-" + sortie if valeur < 0 else sortie


func _definir(ligne: int, cle: String, valeur: String) -> void:
	_cles[ligne].text = cle
	_valeurs[ligne].text = valeur


func _etiquette() -> Label:
	var libelle := Label.new()
	libelle.custom_minimum_size = Vector2(0.0, HAUTEUR_LIGNE)
	libelle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	libelle.clip_text = true
	libelle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return libelle
