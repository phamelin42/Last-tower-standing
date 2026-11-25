class_name SalonUi
extends Control
## Le salon : les joueurs et leur état « prêt » en texte, le bouton « Prêt » (chaque joueur sauf
## l'hôte), la vitesse ×1, ×2 ou ×4 et « Lancer la partie » (hôte seulement), « Quitter le salon ».
## L'hôte n'a pas de bouton « Prêt » : le serveur lance dès que tous les joueurs sont prêts, donc
## « Lancer » est son « prêt », actif quand tous les autres le sont.

signal pret_change(pret: bool)
## Vitesse choisie par l'hôte (facteur de durée) ; la graine reste aléatoire en jeu.
signal options_changees(vitesse: float, graine: int, graine_fixe: bool)
signal lancer_demande
signal quitter

const HAUTEUR_CONTROLE := 48.0
const LARGEUR_COLONNE := 460.0
const TAILLE_TEXTE := 16
const TAILLE_TITRE := 28
const ESPACEMENT := 12

var bouton_pret: Button
var bouton_lancer: Button
var bouton_quitter: Button
var boutons_vitesse: Array[Button] = []

var _titre: Label
var _info: Label
var _avertissement: Label
var _joueurs: VBoxContainer
var _vitesse_texte: Label
var _vitesse_ligne: HBoxContainer
var _etat_lancer: Label
var _est_hote: bool = false
var _en_attente: bool = false
var _groupe: ButtonGroup


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
	var cadre := PanelContainer.new()
	centre.add_child(cadre)
	var colonne := VBoxContainer.new()
	colonne.custom_minimum_size = Vector2(LARGEUR_COLONNE, 0.0)
	colonne.add_theme_constant_override("separation", ESPACEMENT)
	cadre.add_child(colonne)

	_titre = Label.new()
	_titre.name = "Titre"
	_titre.text = tr("SALON_TITRE")
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titre.theme_type_variation = ThemeJeu.TYPE_RUBAN
	_titre.add_theme_font_size_override("font_size", TAILLE_TITRE)
	colonne.add_child(_titre)
	_info = Label.new()
	_info.name = "Info"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.visible = false
	colonne.add_child(_info)
	_avertissement = Label.new()
	_avertissement.name = "Avertissement"
	_avertissement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_avertissement.visible = false
	colonne.add_child(_avertissement)
	var entete := Label.new()
	entete.text = tr("SALON_JOUEURS")
	colonne.add_child(entete)
	_joueurs = VBoxContainer.new()
	_joueurs.name = "Joueurs"
	colonne.add_child(_joueurs)

	_vitesse_texte = Label.new()
	_vitesse_texte.name = "Vitesse"
	_vitesse_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(_vitesse_texte)
	_vitesse_ligne = HBoxContainer.new()
	_vitesse_ligne.name = "ChoixVitesse"
	_groupe = ButtonGroup.new()
	for v: float in Salon.VITESSES:
		var b := Button.new()
		b.text = libelle_vitesse(v)
		b.toggle_mode = true
		b.button_group = _groupe
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
		b.set_meta("vitesse", v)
		b.pressed.connect(_sur_vitesse.bind(v))
		_vitesse_ligne.add_child(b)
		boutons_vitesse.append(b)
	colonne.add_child(_vitesse_ligne)

	_etat_lancer = Label.new()
	_etat_lancer.name = "EtatLancer"
	_etat_lancer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(_etat_lancer)
	bouton_pret = _bouton("Pret", "SALON_BOUTON_PRET", _sur_pret)
	bouton_pret.toggle_mode = true
	colonne.add_child(bouton_pret)
	bouton_lancer = _bouton("Lancer", "SALON_LANCER", lancer_demande.emit)
	colonne.add_child(bouton_lancer)
	bouton_quitter = _bouton("Quitter", "SALON_QUITTER", quitter.emit)
	colonne.add_child(bouton_quitter)
	visible = false


## « ×1 », « ×2 », « ×4 » : la vitesse est un facteur de durée, ×2 = durées divisées par deux.
static func libelle_vitesse(facteur: float) -> String:
	return "×%d" % roundi(1.0 / facteur) if facteur > 0.0 else "×1"


## Précise le salon affiché sous le titre (nom et port quand on en est l'hôte).
func afficher_infos(texte: String) -> void:
	_info.text = texte
	_info.visible = not texte.is_empty()


## Ligne d'état non bloquante sous les infos (la box n'a pas ouvert le port) ; vide la masque.
func afficher_avertissement(texte: String) -> void:
	_avertissement.text = texte
	_avertissement.visible = not texte.is_empty()


## Le texte de la ligne d'état si elle est visible, sinon vide.
func avertissement() -> String:
	return _avertissement.text if _avertissement.visible else ""


## Dessine l'état du salon pour le joueur `id_local`.
func afficher(salon: Salon, id_local: int) -> void:
	visible = true
	_en_attente = false
	_est_hote = salon.hote == id_local and id_local > 0
	for enfant: Node in _joueurs.get_children():
		_joueurs.remove_child(enfant)
		enfant.queue_free()
	# L'hôte en tête, puis les autres : les numéros de pair sont tirés au hasard par ENet, trier
	# dessus donnerait un ordre qui change d'une partie à l'autre.
	var ids: Array = salon.joueurs.keys()
	ids.sort_custom(
		func(a: int, b: int) -> bool:
			if (a == salon.hote) != (b == salon.hote):
				return a == salon.hote
			return a < b
	)
	var autres_prets := true
	for id: int in ids:
		var j: Dictionary = salon.joueurs[id]
		var pret := bool(j["pret"])
		if id != salon.hote and not pret:
			autres_prets = false
		_ajouter_ligne(id, String(j["nom"]), pret, id == salon.hote, id == id_local)
	var moi: Dictionary = salon.joueurs.get(id_local, {})
	var suis_pret := bool(moi.get("pret", false))
	bouton_pret.visible = not _est_hote
	bouton_pret.set_pressed_no_signal(suis_pret)
	bouton_pret.text = tr("SALON_BOUTON_PAS_PRET") if suis_pret else tr("SALON_BOUTON_PRET")
	bouton_lancer.visible = _est_hote
	bouton_lancer.disabled = not (_est_hote and autres_prets and not salon.lancee)
	_etat_lancer.visible = _est_hote
	_etat_lancer.text = tr("SALON_PRET_A_LANCER") if autres_prets else tr("SALON_ATTENTE")
	_vitesse_ligne.visible = _est_hote
	_vitesse_texte.text = (
		tr("SALON_VITESSE")
		if _est_hote
		else tr("SALON_VITESSE_FIXEE") % libelle_vitesse(salon.vitesse)
	)
	for b: Button in boutons_vitesse:
		b.disabled = not _est_hote or salon.lancee
		b.set_pressed_no_signal(is_equal_approx(float(b.get_meta("vitesse")), salon.vitesse))


## Montre « Connexion en cours… » en attendant le premier état du salon.
func afficher_attente() -> void:
	visible = true
	_en_attente = true
	for enfant: Node in _joueurs.get_children():
		_joueurs.remove_child(enfant)
		enfant.queue_free()
	var l := Label.new()
	l.text = tr("SALON_CONNEXION")
	_joueurs.add_child(l)
	bouton_pret.visible = false
	bouton_lancer.visible = false
	_etat_lancer.visible = false
	_vitesse_ligne.visible = false
	_vitesse_texte.text = ""


func est_hote() -> bool:
	return _est_hote


func en_attente() -> bool:
	return _en_attente


## Une ligne de texte par joueur, telle qu'elle est lue (pour les tests et les captures).
func lignes_joueurs() -> PackedStringArray:
	var sortie := PackedStringArray()
	for l: Node in _joueurs.get_children():
		sortie.append((l as Label).text)
	return sortie


func _ajouter_ligne(_id: int, nom: String, pret: bool, hote: bool, moi: bool) -> void:
	var etat := tr("SALON_HOTE") if hote else (tr("SALON_PRET") if pret else tr("SALON_PAS_PRET"))
	var ligne := Label.new()
	ligne.text = "%s — %s" % [nom, etat]
	if moi:
		ligne.text += " " + tr("SALON_VOUS")
	ligne.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	ligne.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ligne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_joueurs.add_child(ligne)


func _sur_pret() -> void:
	pret_change.emit(bouton_pret.button_pressed)


func _sur_vitesse(facteur: float) -> void:
	if _est_hote:
		options_changees.emit(facteur, 0, false)


func _bouton(nom: String, cle: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.name = nom
	bouton.text = tr(cle)
	bouton.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	bouton.pressed.connect(action)
	return bouton
