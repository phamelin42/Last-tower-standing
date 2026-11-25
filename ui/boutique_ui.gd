class_name BoutiqueUi
extends Control
## Panneau de boutique : quatre cartes (nom, rareté en texte et en couleur, prix, type de dégâts,
## description), relance, armes équipées à vendre et choix du marché noir. Il lit une `VueArene`
## et n'agit que par les intentions de la `SourceVue`. Une offre trop chère reste cliquable : la
## source tranche, l'interface annonce « or insuffisant » en texte.

## Actions d'entrée : `project.godot` (T2.7) les déclare, liées à 1 à 4 et R. Les lire comme
## actions plutôt que comme touches laisse la lectrice les reconfigurer.
const ACTIONS_OFFRES: Array[String] = [
	"boutique_offre_1", "boutique_offre_2", "boutique_offre_3", "boutique_offre_4"
]
const ACTION_RELANCER := "boutique_relancer"
const NB_OFFRES := 4
const HAUTEUR_CONTROLE := 48.0
const TAILLE_TEXTE := 16
const LARGEUR_CARTE := 240.0
const LARGEUR_TEXTE := 200.0
const OPACITE_VENDUE := 0.45
const SEPARATEUR_NOTES := " · "

const CLES_TYPE: Dictionary = {
	Types.TypeDegats.TRANCHANT: "BOUTIQUE_TYPE_TRANCHANT",
	Types.TypeDegats.PERCANT: "BOUTIQUE_TYPE_PERCANT",
	Types.TypeDegats.MAGIQUE: "BOUTIQUE_TYPE_MAGIQUE",
	Types.TypeDegats.SIEGE: "BOUTIQUE_TYPE_SIEGE",
	Types.TypeDegats.CHAOS: "BOUTIQUE_TYPE_CHAOS",
}
const CLES_RESULTAT: Dictionary = {
	Types.Resultat.OK: "BOUTIQUE_RESULTAT_OK",
	Types.Resultat.OR_INSUFFISANT: "BOUTIQUE_RESULTAT_OR_INSUFFISANT",
	Types.Resultat.EMPLACEMENTS_PLEINS: "BOUTIQUE_RESULTAT_EMPLACEMENTS_PLEINS",
	Types.Resultat.OFFRE_INVALIDE: "BOUTIQUE_RESULTAT_OFFRE_INVALIDE",
	Types.Resultat.DEJA_ACHETE: "BOUTIQUE_RESULTAT_DEJA_ACHETE",
	Types.Resultat.MAUVAISE_PHASE: "BOUTIQUE_RESULTAT_MAUVAISE_PHASE",
	Types.Resultat.ARENE_MORTE: "BOUTIQUE_RESULTAT_ARENE_MORTE",
	Types.Resultat.INDICE_INVALIDE: "BOUTIQUE_RESULTAT_INDICE_INVALIDE",
	Types.Resultat.NON_DISPONIBLE: "BOUTIQUE_RESULTAT_NON_DISPONIBLE",
}

var _donnees: Donnees = null
var _source: SourceVue = null
var _offres: Array[Dictionary] = []
var _armes_ids: Array[String] = []
var _cartes: Array[PanelContainer] = []
var _raretes: Array[Label] = []
var _noms: Array[Label] = []
var _types: Array[Label] = []
var _descriptions: Array[Label] = []
var _prix: Array[Label] = []
var _notes: Array[Label] = []
var _achats: Array[Button] = []
var _relance: Button
var _note_relance: Label
var _message: Label
var _noir: VBoxContainer
var _liste_armes: VBoxContainer


func _init() -> void:
	var contenu := VBoxContainer.new()
	add_child(contenu)
	contenu.add_child(_etiquette("Titre", "BOUTIQUE_TITRE"))
	var cartes := HBoxContainer.new()
	contenu.add_child(cartes)
	for i: int in NB_OFFRES:
		cartes.add_child(_construire_carte(i))
	var ligne := HBoxContainer.new()
	contenu.add_child(ligne)
	_relance = _bouton(Callable(self, "relancer"))
	ligne.add_child(_relance)
	_note_relance = _etiquette("NoteRelance")
	ligne.add_child(_note_relance)
	_message = _etiquette("Message")
	contenu.add_child(_message)
	_noir = VBoxContainer.new()
	_noir.name = "MarcheNoir"
	_noir.visible = false
	contenu.add_child(_noir)
	contenu.add_child(_etiquette("TitreArmes", "BOUTIQUE_ARMES_TITRE"))
	_liste_armes = VBoxContainer.new()
	contenu.add_child(_liste_armes)


## Fournit les noms, descriptions et prix de vente, et branche les messages de résultat.
func configurer(donnees: Donnees, source: SourceVue) -> void:
	if _source != null and _source.resultat_intention.is_connected(_sur_resultat):
		_source.resultat_intention.disconnect(_sur_resultat)
	_donnees = donnees
	_source = source
	if _source != null:
		_source.resultat_intention.connect(_sur_resultat)
	_construire_marche_noir()


func afficher(vue: VueArene) -> void:
	_offres = vue.offres
	for i: int in NB_OFFRES:
		var offre: Dictionary = vue.offres[i] if i < vue.offres.size() else {}
		_afficher_carte(i, offre, vue)
	_afficher_relance(vue)
	_noir.visible = vue.marche_noir_ouvert
	_afficher_armes(vue)


func acheter_offre(index: int) -> void:
	if _source == null or index < 0 or index >= _offres.size():
		return
	var vendu: bool = _offres[index]["vendu"]
	if not vendu:
		_source.acheter(index)


func relancer() -> void:
	if _source != null:
		_source.relancer()


## Les raccourcis n'agissent que si la boutique est visible et qu'aucun champ de saisie ne
## porte le focus : taper un nom dans le salon ne doit rien acheter.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	for i: int in NB_OFFRES:
		if InputMap.has_action(ACTIONS_OFFRES[i]) and event.is_action_pressed(ACTIONS_OFFRES[i]):
			acheter_offre(i)
			_consommer()
			return
	if InputMap.has_action(ACTION_RELANCER) and event.is_action_pressed(ACTION_RELANCER):
		relancer()
		_consommer()


func _consommer() -> void:
	get_viewport().set_input_as_handled()


# --- Construction ----------------------------------------------------------------------------


func _construire_carte(i: int) -> PanelContainer:
	var carte := PanelContainer.new()
	carte.name = "Carte%d" % i
	carte.custom_minimum_size = Vector2(LARGEUR_CARTE, 0.0)
	carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var colonne := VBoxContainer.new()
	carte.add_child(colonne)
	var rarete := _etiquette("Rarete%d" % i)
	var nom := _etiquette("Nom%d" % i)
	var type_degats := _etiquette("Type%d" % i)
	var description := _etiquette("Description%d" % i)
	var prix := _etiquette("Prix%d" % i)
	var note := _etiquette("Note%d" % i)
	for libelle: Label in [rarete, nom, type_degats, description, prix, note]:
		libelle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		libelle.custom_minimum_size = Vector2(LARGEUR_TEXTE, 0.0)
		colonne.add_child(libelle)
	var achat := _bouton(Callable(self, "acheter_offre").bind(i))
	achat.text = tr("BOUTIQUE_ACHETER")
	colonne.add_child(achat)
	_cartes.append(carte)
	_raretes.append(rarete)
	_noms.append(nom)
	_types.append(type_degats)
	_descriptions.append(description)
	_prix.append(prix)
	_notes.append(note)
	_achats.append(achat)
	return carte


func _construire_marche_noir() -> void:
	for enfant: Node in _noir.get_children():
		_noir.remove_child(enfant)
		enfant.free()
	_noir.add_child(_etiquette("TitreNoir", "BOUTIQUE_NOIR_TITRE"))
	if _donnees == null:
		return
	# Même règle que `Boutique.choix_marche_noir` : raretés jusqu'à `raretes_max`, ids triés.
	var reglage: Dictionary = _donnees.boutique["marche_noir"]
	var max_rarete := Types.rarete_depuis_nom(str(reglage["raretes_max"]))
	var ids: Array[String] = []
	for id: String in _donnees.ameliorations:
		var amelio: Dictionary = _donnees.ameliorations[id]
		if int(amelio["rarete"]) <= max_rarete:
			ids.append(id)
	ids.sort()
	for id: String in ids:
		var amelio: Dictionary = _donnees.ameliorations[id]
		var bouton := _bouton(Callable(self, "_choisir_noir").bind(id))
		bouton.text = tr("BOUTIQUE_CHOISIR") % str(amelio["nom"])
		bouton.tooltip_text = str(amelio["description"])
		_noir.add_child(bouton)


func _choisir_noir(id: String) -> void:
	if _source != null:
		_source.choisir_marche_noir(id)


# --- Affichage -------------------------------------------------------------------------------


func _afficher_carte(i: int, offre: Dictionary, vue: VueArene) -> void:
	_achats[i].disabled = offre.is_empty() or bool(offre["vendu"])
	_cartes[i].modulate.a = 1.0
	if offre.is_empty():
		for libelle: Label in [_raretes[i], _noms[i], _types[i], _descriptions[i], _prix[i]]:
			libelle.text = ""
		_notes[i].text = ""
		return
	var genre: int = offre["genre"]
	var rarete: int = offre["rarete"]
	var prix: int = offre["prix"]
	var vendu: bool = offre["vendu"]
	var entree := _entree(str(offre["id"]), genre)
	_raretes[i].text = (
		"%s %s" % [Apparence.symbole_rarete(rarete), tr(Apparence.cle_libelle_rarete(rarete))]
	)
	_raretes[i].add_theme_color_override("font_color", Apparence.couleur_rarete(rarete))
	_noms[i].text = str(entree.get("nom", offre["id"]))
	_types[i].text = _libelle_type(entree, genre)
	_descriptions[i].text = str(entree.get("description", ""))
	_prix[i].text = tr("BOUTIQUE_PRIX") % Nombres.groupe(prix)
	var notes: Array[String] = []
	if vendu:
		notes.append(tr("BOUTIQUE_VENDU"))
		_cartes[i].modulate.a = OPACITE_VENDUE
	else:
		if vue.argent < prix:
			notes.append(tr("BOUTIQUE_OR_INSUFFISANT"))
		if genre == Types.Genre.ARME and vue.armes.size() >= _capacite():
			notes.append(tr("BOUTIQUE_PLEINS"))
	_notes[i].text = SEPARATEUR_NOTES.join(notes)


func _afficher_relance(vue: VueArene) -> void:
	if vue.relances_gratuites > 0:
		_relance.text = tr("BOUTIQUE_RELANCER_GRATUITE")
		_note_relance.text = ""
		return
	_relance.text = tr("BOUTIQUE_RELANCER_COUT") % Nombres.groupe(vue.cout_relance)
	_note_relance.text = tr("BOUTIQUE_OR_INSUFFISANT") if vue.argent < vue.cout_relance else ""


## Les lignes ne sont reconstruites que si la liste des armes change : l'état arrive à 15 Hz,
## et refaire les boutons à chaque fois leur ferait perdre le survol et le focus.
func _afficher_armes(vue: VueArene) -> void:
	var ids: Array[String] = []
	for arme: Dictionary in vue.armes:
		ids.append(str(arme["id"]))
	if ids == _armes_ids and _liste_armes.get_child_count() > 0:
		return
	_armes_ids = ids
	for enfant: Node in _liste_armes.get_children():
		_liste_armes.remove_child(enfant)
		enfant.free()
	if ids.is_empty():
		_liste_armes.add_child(_etiquette("AucuneArme", "BOUTIQUE_AUCUNE_ARME"))
		return
	for i: int in ids.size():
		var entree := _entree(ids[i], Types.Genre.ARME)
		var ligne := HBoxContainer.new()
		var nom := _etiquette("NomArme%d" % i)
		nom.text = str(entree.get("nom", ids[i]))
		nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(nom)
		var vente := _bouton(Callable(self, "_vendre").bind(i))
		vente.text = tr("BOUTIQUE_VENDRE_PRIX") % Nombres.groupe(_prix_vente(entree))
		ligne.add_child(vente)
		_liste_armes.add_child(ligne)


func _vendre(index: int) -> void:
	if _source != null:
		_source.vendre(index)


func _sur_resultat(_genre: String, code: int) -> void:
	_message.text = tr(CLES_RESULTAT.get(code, "BOUTIQUE_RESULTAT_INCONNU"))


# --- Données ---------------------------------------------------------------------------------


func _entree(id: String, genre: int) -> Dictionary:
	if _donnees == null:
		return {}
	var table: Dictionary = _donnees.armes if genre == Types.Genre.ARME else _donnees.ameliorations
	return table.get(id, {})


func _libelle_type(entree: Dictionary, genre: int) -> String:
	if genre != Types.Genre.ARME:
		return tr("BOUTIQUE_AMELIORATION")
	if not entree.has("type_degats"):
		return ""
	# `Donnees` a déjà converti le nom en valeur de `Types.TypeDegats`.
	var type_degats := int(entree["type_degats"])
	if type_degats < 0:
		return ""
	return tr(CLES_TYPE.get(type_degats, "BOUTIQUE_AMELIORATION"))


func _capacite() -> int:
	return int(_donnees.partie["emplacements_armes"]) if _donnees != null else 8


## Même arrondi que `Inventaire.prix_vente`.
func _prix_vente(entree: Dictionary) -> int:
	if _donnees == null or not entree.has("prix"):
		return 0
	return floori(float(int(entree["prix"])) * float(_donnees.partie["vente_ratio"]))


# --- Contrôles -------------------------------------------------------------------------------


func _etiquette(nom: String, cle: String = "") -> Label:
	var libelle := Label.new()
	libelle.name = nom
	libelle.add_theme_font_size_override("font_size", TAILLE_TEXTE)
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not cle.is_empty():
		libelle.text = tr(cle)
	return libelle


func _bouton(action: Callable) -> Button:
	var bouton := Button.new()
	bouton.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	bouton.add_theme_font_size_override("font_size", TAILLE_TEXTE)
	bouton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bouton.pressed.connect(action)
	return bouton
