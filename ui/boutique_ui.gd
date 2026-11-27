class_name BoutiqueUi
extends Control
## Panneau de boutique : quatre cartes (ruban de catégorie, nom, rareté en texte et en couleur,
## prix), relance, grille des armes équipées (en lecture, sans vente), améliorations
## achetées et choix du marché noir. Il lit une `VueArene` et n'agit que par les intentions de la
## `SourceVue`. Une offre trop chère reste cliquable : la source tranche, l'interface annonce
## « or insuffisant » en texte. Le panneau se replie (touche B ou bouton) : il ne reste alors que
## le bouton pour le déplier, et le marché noir s'il est ouvert.

## Le panneau vient de se replier (`true`) ou de se déplier : la mise en page de la partie
## recalcule la zone libre de l'arène.
signal repli_change(replie: bool)

## Actions d'entrée : `project.godot` (T2.7) les déclare, liées à 1 à 4 et R. Les lire comme
## actions plutôt que comme touches laisse la lectrice les reconfigurer.
const ACTIONS_OFFRES: Array[String] = [
	"boutique_offre_1", "boutique_offre_2", "boutique_offre_3", "boutique_offre_4"
]
const ACTION_RELANCER := "boutique_relancer"
const ACTION_REPLIER := "boutique_replier"
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
const IMAGE_NOIR := 40.0
## Case d'une grille d'icônes (armes équipées, améliorations achetées) : une cible de 48 px,
## l'icône dedans et l'icône de la catégorie en coin.
const CELLULE := 48.0
const IMAGE_CELLULE := 36.0
const ICONE_COIN := 16.0
const ESPACE_CELLULES := 4
## Largeur que la barre de défilement du panneau latéral prend sur la grille.
const LARGEUR_ASCENSEUR := 20.0
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
var _section_armes: VBoxContainer
var _grille_armes: GridContainer
var _section_amelios: VBoxContainer
var _grille_amelios: GridContainer
var _amelios_vues: Dictionary = {}
var _rubans: Array[HBoxContainer] = []
var _categories_cartes: Array[int] = []
var _bouton_repli: Button
var _replie: bool = false
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
	_construire_repli()


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


## Panneau compact sur le côté de l'arène : armes équipées et marché noir. Il se place
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
	_section_armes = VBoxContainer.new()
	_section_armes.name = "SectionArmes"
	colonne.add_child(_section_armes)
	var entete := HBoxContainer.new()
	_section_armes.add_child(entete)
	entete.add_child(CategorieOffre.creer_ruban(Types.Categorie.ARME, "RubanArmes"))
	var titre_armes := _etiquette("TitreArmes", "BOUTIQUE_ARMES_TITRE")
	titre_armes.add_theme_color_override("font_color", ThemeJeu.LAITON_CLAIR)
	entete.add_child(titre_armes)
	_grille_armes = _creer_grille("GrilleArmes")
	_section_armes.add_child(_grille_armes)
	_section_amelios = VBoxContainer.new()
	_section_amelios.name = "SectionAmeliorations"
	_section_amelios.visible = false
	colonne.add_child(_section_amelios)
	var titre_amelios := _etiquette("TitreAmeliorations", "BOUTIQUE_AMELIORATIONS_TITRE")
	titre_amelios.add_theme_color_override("font_color", ThemeJeu.LAITON_CLAIR)
	_section_amelios.add_child(titre_amelios)
	_grille_amelios = _creer_grille("GrilleAmeliorations")
	_section_amelios.add_child(_grille_amelios)
	_placer_cote()


## Bouton qui replie et déplie le panneau : il reste visible, en bas à gauche, au-dessus du
## bandeau déplié ou dans le coin quand tout est replié (la mini-carte occupe le coin droit).
func _construire_repli() -> void:
	_bouton_repli = _bouton(Callable(self, "basculer_repli"))
	_bouton_repli.name = "BoutonRepli"
	_bouton_repli.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bouton_repli.anchor_left = 0.0
	_bouton_repli.anchor_right = 0.0
	_bouton_repli.anchor_top = 1.0
	_bouton_repli.anchor_bottom = 1.0
	_bouton_repli.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bouton_repli.offset_left = MiseEnPage.MARGE
	add_child(_bouton_repli)
	_appliquer_repli()


func est_replie() -> bool:
	return _replie


func basculer_repli() -> void:
	definir_replie(not _replie)


func definir_replie(replie: bool) -> void:
	if replie == _replie:
		return
	_replie = replie
	_appliquer_repli()
	repli_change.emit(_replie)


func _appliquer_repli() -> void:
	_bandeau.visible = not _replie
	_section_armes.visible = not _replie
	_section_amelios.visible = not _replie and _grille_amelios.get_child_count() > 0
	# Le panneau latéral n'apparaît que s'il a quelque chose à montrer : armes équipées, améliorations
	# achetées, ou le marché noir (qui reste là même replié : un choix attend).
	var contenu := not _armes_ids.is_empty() or _grille_amelios.get_child_count() > 0
	_cote.visible = _noir.visible or (not _replie and contenu)
	_bouton_repli.text = tr("BOUTIQUE_DEPLIER") if _replie else tr("BOUTIQUE_REPLIER")
	_bouton_repli.tooltip_text = _raccourci_repli()
	_placer_cote()


func _raccourci_repli() -> String:
	if not InputMap.has_action(ACTION_REPLIER):
		return ""
	var evenements := InputMap.action_get_events(ACTION_REPLIER)
	return "" if evenements.is_empty() else tr("BOUTIQUE_RACCOURCI") % evenements[0].as_text()


## Le bouton se pose juste au-dessus du bandeau déplié, ou au ras du bas une fois replié.
func _placer_repli() -> void:
	var dessous := 0.0 if _replie else _bandeau.get_combined_minimum_size().y
	_bouton_repli.offset_bottom = -(dessous + MiseEnPage.MARGE)
	_bouton_repli.offset_top = _bouton_repli.offset_bottom - HAUTEUR_CONTROLE


## Fenêtre libre entre le HUD et le bandeau : le panneau des armes s'y loge.
func definir_zone_libre(libre: Rect2) -> void:
	_zone_libre = libre
	_placer_cote()


## Rectangle écran du bandeau (cartes, relance, messages) ; replié, celui du bouton de dépliage.
func rect_bandeau() -> Rect2:
	return _bouton_repli.get_global_rect() if _replie else _bandeau.get_global_rect()


## Taille minimale du bandeau : sa hauteur ne dépend que du contenu des cartes. Replié, il ne
## prend plus rien : l'arène visible retrouve sa place (le bouton de dépliage flotte dessus).
func rect_bandeau_minimal() -> Vector2:
	return Vector2.ZERO if _replie else _bandeau.get_combined_minimum_size()


## Panneaux visibles de la boutique, pour les contrôles de mise en page.
func panneaux() -> Array[PanelContainer]:
	var visibles: Array[PanelContainer] = []
	for panneau: PanelContainer in [_bandeau, _cote]:
		if panneau.visible:
			visibles.append(panneau)
	return visibles


func _placer_cote() -> void:
	_cote.offset_top = _zone_libre.position.y + MiseEnPage.MARGE
	_cote.offset_bottom = _cote.offset_top
	var vide := _zone_libre.size.y <= 0.0
	var disponible := maxf(
		ThemeJeu.HAUTEUR_CONTROLE, _zone_libre.size.y - 2.0 * MiseEnPage.MARGE - 2.0 * MARGE_COTE
	)
	var voulu := _contenu_cote.get_combined_minimum_size().y
	_defilement.custom_minimum_size = Vector2(0.0, voulu if vide else minf(voulu, disponible))


## Fournit les noms et descriptions, et branche les messages de résultat.
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
		_placer_repli()


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
	_afficher_ameliorations(vue)
	_appliquer_repli()
	_placer_repli()


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
		return
	if InputMap.has_action(ACTION_REPLIER) and event.is_action_pressed(ACTION_REPLIER):
		basculer_repli()
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
	# Rareté et prix côte à côte quand la carte est assez large ; sinon le prix passe dessous plutôt
	# que d'écraser la rareté (à 125 % de taille d'interface, les deux ne tiennent plus ensemble).
	var haut := HFlowContainer.new()
	haut.add_theme_constant_override("h_separation", 12)
	haut.add_theme_constant_override("v_separation", 0)
	colonne.add_child(haut)
	colonne.move_child(haut, 0)
	# En tête de carte : le ruban de la catégorie (icône et mot), posé par `_afficher_carte`.
	var repere := HBoxContainer.new()
	repere.name = "Repere%d" % i
	colonne.add_child(repere)
	colonne.move_child(repere, 0)
	_rubans.append(repere)
	_categories_cartes.append(-1)
	# Rareté et prix sur la largeur de la carte : Metamorphous est plus large que l'ancienne
	# police, et dans la colonne à droite de l'image la rareté passait sur cinq lignes.
	prix.autowrap_mode = TextServer.AUTOWRAP_OFF
	prix.custom_minimum_size.x = 0.0
	rarete.custom_minimum_size = Vector2(0.0, HAUTEUR_LIGNE_SERREE)
	# Jamais à la ligne ni rognée : un mot de rareté coupé en deux (« Peu » / « commune ») serait
	# masqué par la hauteur d'une seule ligne.
	rarete.autowrap_mode = TextServer.AUTOWRAP_OFF
	prix.add_theme_color_override("font_color", ThemeJeu.LAITON_CLAIR)
	haut.add_child(rarete)
	# La colonne de texte n'a plus que la largeur laissée par l'image : le nom passe à la ligne.
	nom.custom_minimum_size = Vector2(LARGEUR_MOT_NOM, _hauteur_ligne())
	nom.add_theme_color_override("font_color", ThemeJeu.LAITON_CLAIR)
	# Un nom long passe sur trois lignes : l'interligne du thème (3 px) coûterait 6 px au bandeau.
	nom.add_theme_constant_override("line_spacing", 0)
	textes.add_child(nom)
	# Le prix se range sous le nom, dans la colonne à droite de l'image : la rangée de la rareté
	# ne le fait plus passer à la ligne, et la note « Or insuffisant » trouve sa place sous
	# l'en-tête sans rendre le bandeau plus haut que 45 % de la fenêtre.
	textes.add_child(prix)
	# La note (vendu, déjà équipée, or insuffisant…) n'occupe de place que lorsqu'elle a un texte. Elle
	# prend la largeur de la carte, sous l'en-tête : dans la colonne à droite de l'image, « Or
	# insuffisant » se rognait (« Or insuffi… ») à 125 %, et à la ligne il coûtait deux lignes.
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Une ligne reste réservée même sans texte : sinon la note qui apparaît (« Or insuffisant »
	# après un achat) ajoute une ligne à la carte et fait sauter les boutons.
	note.custom_minimum_size = Vector2(0.0, HAUTEUR_LIGNE_SERREE)
	note.add_theme_color_override("font_color", ThemeJeu.PARCHEMIN_ATTENU)
	colonne.add_child(note)
	# Carte compacte (D13) : l'effet entier et l'ambiance se lisent dans l'infobulle de la carte.
	var achat := _bouton(Callable(self, "acheter_offre").bind(i))
	achat.text = tr("BOUTIQUE_ACHETER")
	achat.theme_type_variation = ThemeJeu.TYPE_ACHAT
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
		var choix := VBoxContainer.new()
		choix.name = "Choix_%s" % id
		choix.add_theme_constant_override("separation", 0)
		var categorie := _categorie(id, Types.Genre.AMELIORATION)
		var repere := HBoxContainer.new()
		repere.add_child(CategorieOffre.creer_ruban(categorie, "Ruban"))
		choix.add_child(repere)
		var bouton := _bouton(Callable(self, "_choisir_noir").bind(id))
		bouton.text = tr("BOUTIQUE_CHOISIR") % str(amelio["nom"])
		bouton.tooltip_text = _infobulle(amelio, Types.Genre.AMELIORATION)
		bouton.icon = ImageOffre.texture(id)
		bouton.expand_icon = true
		bouton.add_theme_constant_override("icon_max_width", int(IMAGE_NOIR))
		bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choix.add_child(bouton)
		_noir.add_child(choix)


func _choisir_noir(id: String) -> void:
	if _source != null:
		_source.choisir_marche_noir(id)


# --- Affichage -------------------------------------------------------------------------------


func _afficher_carte(i: int, offre: Dictionary, vue: VueArene) -> void:
	_achats[i].disabled = offre.is_empty() or bool(offre["vendu"])
	_cartes[i].modulate.a = 1.0
	if offre.is_empty():
		_poser_ruban(i, -1)
		for libelle: Label in [_raretes[i], _noms[i], _prix[i]]:
			libelle.text = ""
		_images[i].texture = null
		_notes[i].text = ""
		_notes[i].visible = true
		_cartes[i].tooltip_text = ""
		return
	var genre: int = offre["genre"]
	var rarete: int = offre["rarete"]
	var prix: int = offre["prix"]
	var vendu: bool = offre["vendu"]
	var entree := _entree(str(offre["id"]), genre)
	_poser_ruban(i, _categorie(str(offre["id"]), genre))
	ImageOffre.poser(_images[i], str(offre["id"]))
	_raretes[i].text = (
		"%s %s" % [Apparence.symbole_rarete(rarete), tr(Apparence.cle_libelle_rarete(rarete))]
	)
	_raretes[i].add_theme_color_override("font_color", Apparence.couleur_rarete(rarete))
	_noms[i].text = str(entree.get("nom", offre["id"]))
	_cartes[i].tooltip_text = _infobulle(entree, genre)
	_prix[i].text = tr("BOUTIQUE_PRIX") % Nombres.groupe(prix)
	var notes: Array[String] = []
	_achats[i].theme_type_variation = (
		ThemeJeu.TYPE_ACHAT_INSUFFISANT if not vendu and vue.argent < prix else ThemeJeu.TYPE_ACHAT
	)
	if vendu:
		notes.append(tr("BOUTIQUE_VENDU"))
		_cartes[i].modulate.a = OPACITE_VENDUE
	else:
		if vue.argent < prix:
			notes.append(tr("BOUTIQUE_OR_INSUFFISANT"))
		if genre == Types.Genre.ARME and vue.armes.size() >= Inventaire.ARMES_MAX:
			notes.append(tr("BOUTIQUE_ARMES_AU_MAXIMUM"))
	_notes[i].text = SEPARATEUR_NOTES.join(notes)
	_notes[i].tooltip_text = _notes[i].text
	_notes[i].visible = true


## Ruban de la catégorie en tête de la carte `i` ; refait seulement quand la catégorie change,
## vide (rien d'affiché) pour une catégorie inconnue ou une carte sans offre.
func _poser_ruban(i: int, categorie: int) -> void:
	if _categories_cartes[i] == categorie and _rubans[i].get_child_count() > 0:
		return
	_categories_cartes[i] = categorie
	for enfant: Node in _rubans[i].get_children():
		_rubans[i].remove_child(enfant)
		enfant.free()
	_rubans[i].add_child(CategorieOffre.creer_ruban(categorie, "Ruban%d" % i))


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


## La grille n'est reconstruite que si la liste des armes change : l'état arrive à 15 Hz, et
## refaire les cases à chaque fois leur ferait perdre le survol et le focus.
func _afficher_armes(vue: VueArene) -> void:
	var ids: Array[String] = []
	for arme: Dictionary in vue.armes:
		ids.append(str(arme["id"]))
	if ids == _armes_ids and _grille_armes.get_child_count() > 0:
		return
	_armes_ids = ids
	_vider(_grille_armes)
	for i: int in ids.size():
		var entree := _entree(ids[i], Types.Genre.ARME)
		var case := Button.new()
		case.name = "Arme%d" % i
		case.theme_type_variation = ThemeJeu.TYPE_CELLULE
		case.custom_minimum_size = Vector2(CELLULE, CELLULE)
		case.icon = ImageOffre.texture(ids[i])
		case.expand_icon = true
		case.tooltip_text = _infobulle(entree, Types.Genre.ARME)
		case.add_child(_coin(_categorie(ids[i], Types.Genre.ARME)))
		_grille_armes.add_child(case)
	if ids.is_empty():
		_grille_armes.add_child(_etiquette("AucuneArme", "BOUTIQUE_AUCUNE_ARME"))


## Améliorations achetées (id → nombre d'achats), rangées par identifiant. Chaque case porte le
## repère de sa catégorie (amélioration ou revenu) et son nombre ; le détail est en infobulle.
func _afficher_ameliorations(vue: VueArene) -> void:
	if vue.ameliorations == _amelios_vues and _grille_amelios.get_child_count() > 0:
		return
	_amelios_vues = vue.ameliorations.duplicate()
	_vider(_grille_amelios)
	var ids: Array[String] = []
	for id: Variant in _amelios_vues:
		ids.append(str(id))
	ids.sort()
	for id: String in ids:
		var entree := _entree(id, Types.Genre.AMELIORATION)
		var case := PanelContainer.new()
		case.name = "Amelioration_%s" % id
		case.theme_type_variation = ThemeJeu.TYPE_CELLULE_FIXE
		case.custom_minimum_size = Vector2(CELLULE, CELLULE)
		case.mouse_filter = Control.MOUSE_FILTER_STOP
		case.tooltip_text = _infobulle(entree, Types.Genre.AMELIORATION)
		var image := ImageOffre.creer("Image", IMAGE_CELLULE)
		ImageOffre.poser(image, id)
		image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		case.add_child(image)
		case.add_child(_coin(_categorie(id, Types.Genre.AMELIORATION)))
		var nombre := int(_amelios_vues[id]) if _amelios_vues[id] is int else 1
		if nombre > 1:
			var quantite := _etiquette("Quantite", "")
			quantite.text = tr("BOUTIQUE_QUANTITE") % Nombres.groupe(nombre)
			quantite.theme_type_variation = "Petit"
			quantite.add_theme_color_override("font_outline_color", ThemeJeu.ENCRE)
			quantite.add_theme_constant_override("outline_size", 6)
			quantite.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			quantite.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			quantite.mouse_filter = Control.MOUSE_FILTER_IGNORE
			case.add_child(quantite)
		_grille_amelios.add_child(case)
	_section_amelios.visible = not _replie and not ids.is_empty()


## Repère de catégorie dans le coin bas droit d'une case : l'icône, le mot est dans l'infobulle.
func _coin(categorie: int) -> TextureRect:
	var icone := CategorieOffre.creer_icone(categorie, CategorieOffre.NOM_REPERE, ICONE_COIN)
	icone.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	icone.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	icone.grow_vertical = Control.GROW_DIRECTION_BEGIN
	icone.visible = icone.texture != null
	return icone


func _creer_grille(nom: String) -> GridContainer:
	var grille := GridContainer.new()
	grille.name = nom
	grille.columns = maxi(
		1,
		int(
			(
				(LARGEUR_COTE - 2.0 * MARGE_COTE - LARGEUR_ASCENSEUR)
				/ (CELLULE + float(ESPACE_CELLULES))
			)
		)
	)
	grille.add_theme_constant_override("h_separation", ESPACE_CELLULES)
	grille.add_theme_constant_override("v_separation", ESPACE_CELLULES)
	return grille


func _vider(conteneur: Node) -> void:
	for enfant: Node in conteneur.get_children():
		conteneur.remove_child(enfant)
		enfant.free()


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
	var mot := CategorieOffre.mot(_categorie(str(entree.get("id", "")), genre))
	if not mot.is_empty():
		morceaux.append(mot)
	var effet := DescriptionOffre.ligne_effet(entree, genre, _donnees)
	if not effet.is_empty():
		morceaux.append(effet)
	var efficacite := DescriptionOffre.efficacite(entree, _donnees)
	if not efficacite.is_empty():
		morceaux.append(efficacite)
	morceaux.append(str(entree.get("description", "")))
	return "\n".join(morceaux)


## Catégorie d'une offre d'après les données ; à défaut (identifiant inconnu), celle de son genre.
## -1 si rien ne la dit : le repère disparaît, jamais d'exception.
func _categorie(id: String, genre: int) -> int:
	var categorie := _donnees.categorie_de(id) if _donnees != null else -1
	if categorie >= 0:
		return categorie
	if genre == Types.Genre.ARME:
		return Types.Categorie.ARME
	if genre == Types.Genre.AMELIORATION:
		return Types.Categorie.AMELIORATION
	return -1


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
