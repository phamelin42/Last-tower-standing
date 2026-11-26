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
const LARGEUR_CARTE := 180.0
const LARGEUR_TEXTE := 130.0
## Largeur de la colonne d'actions (relance, message) et du panneau des armes.
const LARGEUR_ACTIONS := 152.0
const LARGEUR_COTE := 300.0
const LARGEUR_NOM_ARME := 100.0
## Image de l'offre en tête de carte : la plus grande taille qui tient, entre ces bornes. Elle
## grandit avec la fenêtre (de 648 à 1080 px de haut) et cède avant le texte quand la place manque.
const IMAGE_MIN := 64.0
const IMAGE_MAX := 72.0
const HAUTEUR_IMAGE_MIN := 648.0
const HAUTEUR_IMAGE_MAX := 1080.0
## Ce que la carte prend autour de l'image et du texte : marges du bandeau et de la carte.
const MARGES_CARTE := 24.0
## Rareté la plus longue (111 px) et prix le plus long (52 px), côte à côte à droite de l'image.
const LARGEUR_ENTETE_TEXTE := 165.0
## Largeur plancher du nom : de quoi tenir un mot, le reste vient de la place laissée par l'image.
const LARGEUR_MOT_NOM := 48.0
## Petite image devant le nom d'une arme équipée, et devant un choix du marché noir.
const IMAGE_ARME := 32.0
const IMAGE_NOIR := 40.0
const LARGEUR_VENTE := 140.0
## Hauteur d'une ligne de 16 px sans interligne.
const HAUTEUR_LIGNE_SERREE := 23.0
## Marges verticales du style des boutons (haut et bas) autour du texte.
const HAUTEUR_MARGES_BOUTON := 36.0
## Interligne du bouton de relance (négatif : resserre les deux lignes dans la plaque du pack).
const INTERLIGNE_RELANCE := -6
const MARGE := 4
const MARGE_COTE := ThemeJeu.MARGE_PANNEAU
const OPACITE_VENDUE := 0.45
const SEPARATEUR_NOTES := " · "

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
	Types.Resultat.ARMES_AU_MAXIMUM: "BOUTIQUE_RESULTAT_ARMES_AU_MAXIMUM",
}

var _donnees: Donnees = null
var _source: SourceVue = null
var _offres: Array[Dictionary] = []
var _armes_ids: Array[String] = []
var _cartes: Array[PanelContainer] = []
var _raretes: Array[Label] = []
var _noms: Array[Label] = []
var _images: Array[TextureRect] = []
var _prix: Array[Label] = []
var _notes: Array[Label] = []
var _achats: Array[Button] = []
var _relance: Button
var _note_relance: Label
var _message: Label
var _noir: VBoxContainer
var _liste_armes: VBoxContainer
var _bandeau: PanelContainer
var _cote: PanelContainer
var _defilement: ScrollContainer
var _contenu_cote: VBoxContainer
var _zone_libre: Rect2 = Rect2()


func _init() -> void:
	ThemeJeu.appliquer(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construire_bandeau()
	_construire_cote()


## Bandeau du bas : quatre cartes et, à droite, la relance et les messages. Il pousse vers le haut
## à partir du bord inférieur et ne prend que la hauteur de son contenu.
func _construire_bandeau() -> void:
	_bandeau = PanelContainer.new()
	_bandeau.name = "Bandeau"
	_bandeau.anchor_left = 0.0
	_bandeau.anchor_right = 1.0
	_bandeau.anchor_top = 1.0
	_bandeau.anchor_bottom = 1.0
	_bandeau.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bandeau.add_theme_stylebox_override("panel", _style_bandeau())
	add_child(_bandeau)
	var rangee := HBoxContainer.new()
	_bandeau.add_child(rangee)
	var cartes := HBoxContainer.new()
	cartes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rangee.add_child(cartes)
	for i: int in NB_OFFRES:
		cartes.add_child(_construire_carte(i))
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.custom_minimum_size = Vector2(LARGEUR_ACTIONS, 0.0)
	rangee.add_child(actions)
	var titre := _etiquette("Titre", "BOUTIQUE_TITRE")
	titre.theme_type_variation = "TitrePetit"
	actions.add_child(titre)
	_relance = _bouton(Callable(self, "relancer"))
	# « Relancer » puis le prix : deux lignes de 23 px et les marges du bouton (36 px), sinon la
	# seconde ligne est coupée.
	_relance.custom_minimum_size.y = 2.0 * HAUTEUR_LIGNE_SERREE + HAUTEUR_MARGES_BOUTON
	# La plaque du pack a une hauteur fixe (≈ 40 px utiles) : à 23 px d'interligne, la seconde
	# ligne mordait sur son cadre. Les glyphes font 12 px : deux lignes serrées y tiennent.
	_relance.add_theme_constant_override("line_spacing", INTERLIGNE_RELANCE)
	actions.add_child(_relance)
	_note_relance = _etiquette("NoteRelance")
	_message = _etiquette("Message")
	for libelle: Label in [_note_relance, _message]:
		libelle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		libelle.custom_minimum_size = Vector2(LARGEUR_ACTIONS - 8.0, 0.0)
		libelle.max_lines_visible = 3
		actions.add_child(libelle)


## Panneau compact sur le côté de l'arène : armes équipées à vendre et marché noir. Il se place
## sous le HUD, au bord droit, et défile si la liste dépasse l'arène visible.
func _construire_cote() -> void:
	_cote = PanelContainer.new()
	_cote.name = "Cote"
	_cote.anchor_left = 1.0
	_cote.anchor_right = 1.0
	_cote.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_cote.custom_minimum_size = Vector2(LARGEUR_COTE, 0.0)
	_cote.offset_right = -MiseEnPage.MARGE
	add_child(_cote)
	_defilement = ScrollContainer.new()
	_defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cote.add_child(_defilement)
	var colonne := VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_defilement.add_child(colonne)
	_contenu_cote = colonne
	_noir = VBoxContainer.new()
	_noir.name = "MarcheNoir"
	_noir.visible = false
	colonne.add_child(_noir)
	var titre_armes := _etiquette("TitreArmes", "BOUTIQUE_ARMES_TITRE")
	titre_armes.add_theme_color_override("font_color", ThemeJeu.LAITON_CLAIR)
	colonne.add_child(titre_armes)
	_liste_armes = VBoxContainer.new()
	colonne.add_child(_liste_armes)
	_placer_cote()


## Fenêtre libre entre le HUD et le bandeau : le panneau des armes s'y loge.
func definir_zone_libre(libre: Rect2) -> void:
	_zone_libre = libre
	_placer_cote()


## Rectangle écran du bandeau (cartes, relance, messages).
func rect_bandeau() -> Rect2:
	return _bandeau.get_global_rect()


## Taille minimale du bandeau : sa hauteur ne dépend que du contenu des cartes.
func rect_bandeau_minimal() -> Vector2:
	return _bandeau.get_combined_minimum_size()


## Panneaux visibles de la boutique, pour les contrôles de mise en page.
func panneaux() -> Array[PanelContainer]:
	return [_bandeau, _cote]


func _placer_cote() -> void:
	_cote.offset_top = _zone_libre.position.y + MiseEnPage.MARGE
	_cote.offset_bottom = _cote.offset_top
	var vide := _zone_libre.size.y <= 0.0
	var disponible := maxf(
		ThemeJeu.HAUTEUR_CONTROLE, _zone_libre.size.y - 2.0 * MiseEnPage.MARGE - 2.0 * MARGE_COTE
	)
	var voulu := _contenu_cote.get_combined_minimum_size().y
	_defilement.custom_minimum_size = Vector2(0.0, voulu if vide else minf(voulu, disponible))


## Fournit les noms, descriptions et prix de vente, et branche les messages de résultat.
func configurer(donnees: Donnees, source: SourceVue) -> void:
	if _source != null and _source.resultat_intention.is_connected(_sur_resultat):
		_source.resultat_intention.disconnect(_sur_resultat)
	_donnees = donnees
	_source = source
	if _source != null:
		_source.resultat_intention.connect(_sur_resultat)
	_construire_marche_noir()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_regler_images()


## Taille de l'image d'une carte pour une fenêtre de cette taille : celle que la hauteur permet,
## ramenée à ce que la largeur laisse au texte, sans jamais sortir des bornes.
static func taille_image(fenetre: Vector2) -> float:
	var t := remap(fenetre.y, HAUTEUR_IMAGE_MIN, HAUTEUR_IMAGE_MAX, IMAGE_MIN, IMAGE_MAX)
	t = clampf(t, IMAGE_MIN, IMAGE_MAX)
	if fenetre.x > 0.0:
		var carte := (fenetre.x - LARGEUR_ACTIONS - 2.0 * MARGE) / float(NB_OFFRES)
		t = minf(t, carte - MARGES_CARTE - LARGEUR_ENTETE_TEXTE)
	return clampf(floorf(t), IMAGE_MIN, IMAGE_MAX)


func _regler_images() -> void:
	var taille := taille_image(size)
	for image: TextureRect in _images:
		ImageOffre.regler_taille(image, taille)


func afficher(vue: VueArene) -> void:
	_offres = vue.offres
	for i: int in NB_OFFRES:
		var offre: Dictionary = vue.offres[i] if i < vue.offres.size() else {}
		_afficher_carte(i, offre, vue)
	_afficher_relance(vue)
	_noir.visible = vue.marche_noir_ouvert
	_afficher_armes(vue)
	_placer_cote()


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
	carte.theme_type_variation = "Carte"
	carte.custom_minimum_size = Vector2(LARGEUR_CARTE, 0.0)
	carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var colonne := VBoxContainer.new()
	# Sans interligne entre les rangées : le bandeau a 45 % de la hauteur au plus.
	colonne.add_theme_constant_override("separation", 0)
	carte.add_child(colonne)
	var rarete := _etiquette("Rarete%d" % i)
	var nom := _etiquette("Nom%d" % i)
	var prix := _etiquette("Prix%d" % i)
	var note := _etiquette("Note%d" % i)
	for libelle: Label in [rarete, nom, prix, note]:
		libelle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		libelle.custom_minimum_size = Vector2(LARGEUR_TEXTE, 0.0)
	# Les détails de la carte sont au rôle « petit » : Metamorphous est plus large que l'ancienne
	# police et le bandeau doit rester bas (D13).
	for libelle: Label in [rarete, prix, note]:
		libelle.theme_type_variation = "Petit"
	# Rangées : rareté et prix ; nom (à la ligne s'il est très long) ; type de dégâts et notes ;
	# effet (toujours entier) puis ambiance (atténuée).
	# En tête : l'image, puis rareté et prix, nom, type et notes en colonne à sa droite.
	var entete := HBoxContainer.new()
	entete.add_theme_constant_override("separation", 1)
	colonne.add_child(entete)
	var image := ImageOffre.creer("Image%d" % i, IMAGE_MIN)
	entete.add_child(image)
	var textes := VBoxContainer.new()
	textes.add_theme_constant_override("separation", 0)
	textes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entete.add_child(textes)
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 3)
	colonne.add_child(haut)
	colonne.move_child(haut, 0)
	# Rareté et prix sur la largeur de la carte : Metamorphous est plus large que l'ancienne
	# police, et dans la colonne à droite de l'image la rareté passait sur cinq lignes.
	prix.autowrap_mode = TextServer.AUTOWRAP_OFF
	prix.custom_minimum_size.x = 0.0
	rarete.custom_minimum_size = Vector2(0.0, _hauteur_ligne())
	rarete.clip_text = true
	rarete.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rarete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prix.add_theme_color_override("font_color", ThemeJeu.LAITON_CLAIR)
	haut.add_child(rarete)
	haut.add_child(prix)
	# La colonne de texte n'a plus que la largeur laissée par l'image : le nom passe à la ligne.
	nom.custom_minimum_size = Vector2(LARGEUR_MOT_NOM, _hauteur_ligne())
	nom.add_theme_color_override("font_color", ThemeJeu.LAITON_CLAIR)
	textes.add_child(nom)
	# La note (vendu, déjà équipée…) n'occupe de place que lorsqu'elle a un texte.
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.custom_minimum_size.x = 0.0
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note.add_theme_color_override("font_color", ThemeJeu.PARCHEMIN_ATTENU)
	textes.add_child(note)
	# Carte compacte (D13) : l'effet entier et l'ambiance se lisent dans l'infobulle de la carte.
	var achat := _bouton(Callable(self, "acheter_offre").bind(i))
	achat.text = tr("BOUTIQUE_ACHETER")
	colonne.add_child(achat)
	_cartes.append(carte)
	_raretes.append(rarete)
	_noms.append(nom)
	_images.append(image)
	# Les infobulles ne s'ouvrent que sur un contrôle qui reçoit la souris : un `Label` l'ignore
	# par défaut. La carte entière porte celle de l'offre.
	carte.mouse_filter = Control.MOUSE_FILTER_STOP
	_prix.append(prix)
	_notes.append(note)
	_achats.append(achat)
	return carte


## Hauteur d'une ligne de texte de 16 px : les zones de texte réservent leurs lignes d'avance, la
## hauteur des cartes ne change donc pas d'une offre à l'autre.
static func _hauteur_ligne() -> float:
	return 26.0


func _style_bandeau() -> StyleBoxFlat:
	var boite := ThemeJeu.boite_barre()
	boite.set_content_margin_all(MARGE)
	boite.set_corner_radius_all(0)
	boite.border_width_bottom = 0
	boite.border_width_left = 0
	boite.border_width_right = 0
	return boite


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
		bouton.tooltip_text = _infobulle(amelio, Types.Genre.AMELIORATION)
		bouton.icon = ImageOffre.texture(id)
		bouton.expand_icon = true
		bouton.add_theme_constant_override("icon_max_width", int(IMAGE_NOIR))
		bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_noir.add_child(bouton)


func _choisir_noir(id: String) -> void:
	if _source != null:
		_source.choisir_marche_noir(id)


# --- Affichage -------------------------------------------------------------------------------


func _afficher_carte(i: int, offre: Dictionary, vue: VueArene) -> void:
	_achats[i].disabled = offre.is_empty() or bool(offre["vendu"])
	_cartes[i].modulate.a = 1.0
	if offre.is_empty():
		for libelle: Label in [_raretes[i], _noms[i], _prix[i]]:
			libelle.text = ""
		_images[i].texture = null
		_notes[i].text = ""
		_notes[i].visible = false
		_cartes[i].tooltip_text = ""
		return
	var genre: int = offre["genre"]
	var rarete: int = offre["rarete"]
	var prix: int = offre["prix"]
	var vendu: bool = offre["vendu"]
	var entree := _entree(str(offre["id"]), genre)
	ImageOffre.poser(_images[i], str(offre["id"]))
	_raretes[i].text = (
		"%s %s" % [Apparence.symbole_rarete(rarete), tr(Apparence.cle_libelle_rarete(rarete))]
	)
	_raretes[i].add_theme_color_override("font_color", Apparence.couleur_rarete(rarete))
	_noms[i].text = str(entree.get("nom", offre["id"]))
	_cartes[i].tooltip_text = _infobulle(entree, genre)
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
	_notes[i].tooltip_text = _notes[i].text
	_notes[i].visible = not _notes[i].text.is_empty()


## « Relancer » sur une ligne, le prix sur la suivante : le retour à la ligne est voulu, pour que
## le prix ne se coupe jamais au milieu (« 50 » / « or »).
func _libelle_relance(detail: String) -> String:
	return tr("BOUTIQUE_RELANCER") + "\n" + detail


func _afficher_relance(vue: VueArene) -> void:
	if vue.relances_gratuites > 0:
		_relance.text = _libelle_relance(tr("BOUTIQUE_RELANCER_GRATUITE"))
		_note_relance.text = ""
		return
	_relance.text = _libelle_relance(
		tr("BOUTIQUE_RELANCER_COUT") % Nombres.groupe(vue.cout_relance)
	)
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
		var image := ImageOffre.creer("ImageArme%d" % i, IMAGE_ARME)
		ImageOffre.poser(image, ids[i])
		ligne.add_child(image)
		var nom := _etiquette("NomArme%d" % i)
		nom.text = str(entree.get("nom", ids[i]))
		nom.autowrap_mode = TextServer.AUTOWRAP_OFF
		nom.custom_minimum_size.x = LARGEUR_NOM_ARME
		nom.clip_text = true
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nom.tooltip_text = _infobulle(entree, Types.Genre.ARME)
		nom.mouse_filter = Control.MOUSE_FILTER_PASS
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(nom)
		var vente := _bouton(Callable(self, "_vendre").bind(i))
		vente.text = tr("BOUTIQUE_VENDRE_PRIX") % Nombres.groupe(_prix_vente(entree))
		vente.autowrap_mode = TextServer.AUTOWRAP_OFF
		vente.theme_type_variation = ThemeJeu.TYPE_DANGER
		vente.custom_minimum_size.x = LARGEUR_VENTE
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


## Nom, ligne d'effet complète (type compris) puis phrase d'ambiance : tout ce qu'on lit sur la
## carte, pour les endroits où l'offre n'a pas de carte.
func _infobulle(entree: Dictionary, genre: int) -> String:
	var morceaux := PackedStringArray()
	morceaux.append(str(entree.get("nom", "")))
	var effet := DescriptionOffre.ligne_effet(entree, genre, _donnees)
	if not effet.is_empty():
		morceaux.append(effet)
	var efficacite := DescriptionOffre.efficacite(entree, _donnees)
	if not efficacite.is_empty():
		morceaux.append(efficacite)
	morceaux.append(str(entree.get("description", "")))
	return "\n".join(morceaux)


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
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not cle.is_empty():
		libelle.text = tr(cle)
	return libelle


func _bouton(action: Callable) -> Button:
	var bouton := Button.new()
	bouton.custom_minimum_size = Vector2(0.0, HAUTEUR_CONTROLE)
	bouton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bouton.pressed.connect(action)
	return bouton
