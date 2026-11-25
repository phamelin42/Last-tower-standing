class_name Hud
extends Control
## HUD de l'arène : PV de la tour, or, revenu, manche, temps, prochaine famille et armes. Il lit
## une `VueArene` et ne calcule rien. Chaque ligne est une étiquette et sa valeur, à 48 px de
## haut, en 16 px au moins : la lectrice le lit à un mètre.

const HAUTEUR_LIGNE := 48.0
const TAILLE_TEXTE := 16

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
var _donnees: Donnees = null


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
	_definir(LIGNE_OR, tr("HUD_OR"), Nombres.groupe(vue.argent))
	_definir(LIGNE_REVENU, tr("HUD_REVENU"), "+" + Nombres.groupe(vue.revenu))
	var manche := tr("HUD_PREPARATION") if vue.manche == 0 else Nombres.groupe(vue.manche)
	_definir(LIGNE_MANCHE, tr("HUD_MANCHE"), manche)
	_definir(
		LIGNE_TEMPS, tr("HUD_TEMPS"), tr("HUD_SECONDES") % Nombres.groupe(ceili(vue.temps_restant))
	)
	_definir(LIGNE_PROCHAINE, tr("HUD_PROCHAINE"), _prochaine(vue))
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


func _etiquette() -> Label:
	var libelle := Label.new()
	libelle.custom_minimum_size = Vector2(0.0, HAUTEUR_LIGNE)
	libelle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	libelle.clip_text = true
	libelle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return libelle
