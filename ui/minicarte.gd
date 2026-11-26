class_name Minicarte
extends Control
## Mini-carte en bas à droite : l'arène affichée (la tour, les ennemis en points de la couleur de
## leur palier, le cercle d'apparition, le cadre de la vue) et, à sa gauche, une vignette par autre
## joueur (nom, barre de PV, carte de densité). Un clic sur la carte demande de centrer la vue ;
## un clic sur une vignette, de regarder cette arène. Elle ne dessine que des formes (`_draw`) et
## n'agit que par ses deux signaux : `Jeu` les relie à la caméra et à `SourceVue.regarder`.

## L'utilisateur veut déplacer la vue sur ce point (unités de jeu, repère de la tour).
signal demande_centrage(point_unites: Vector2)
## L'utilisateur veut voir l'arène de ce joueur à la place de la sienne.
signal demande_regarder(id_joueur: int)

## Côté de la carte, en pixels de l'interface.
const COTE_CARTE := 136.0
const LARGEUR_VIGNETTE := 124.0
const HAUTEUR_VIGNETTE := 31.0
const ESPACE := 6.0
## Quatre vignettes et leurs trois intervalles font la hauteur de la carte.
const INTERVALLE := 4.0
## Vignettes par colonne : la colonne a la hauteur de la carte.
const VIGNETTES_PAR_COLONNE := 4
## La carte montre un peu plus que le cercle d'apparition, pour que les ennemis qui arrivent au bord
## ne soient pas collés au cadre.
const DEMI_MONDE := CameraArene.RAYON_APPARITION * 1.15
## Côté d'une cellule d'agrégation des ennemis, en pixels : mille ennemis se dessinent en au plus
## `POINTS_MAX` rectangles quelle que soit leur foule.
const COTE_CELLULE := 5.0
const POINTS_MAX := 800
## La carte de densité d'une arène est de 16 × 16 cases ; la vignette la rend en 8 × 8.
const COTE_DENSITE := 16
const COTE_DENSITE_VIGNETTE := 8
const COTE_APERCU := 28.0
const HAUTEUR_BARRE := 5.0
const TAILLE_TEXTE := 16
## Classes de couleur : les quatre paliers (jaune, rouge, violet, bleu), puis le convoi et le boss.
const CLASSE_CONVOI := 4
const CLASSE_BOSS := 5
const COULEURS_CLASSES: Array[Color] = [
	Color("#e8c547"),
	Color("#d9483b"),
	Color("#a56fe0"),
	Color("#4f9be0"),
	Color("#f1e7d0"),
	Color("#ffffff"),
]

const FOND := Color(0.06, 0.09, 0.1, 0.9)
const BORD := ThemeJeu.LAITON
const CERCLE := Color(0.94, 0.8, 0.48, 0.55)
const CADRE := Color("#ffffff")
const TOUR := ThemeJeu.LAITON_CLAIR

## Données de la carte principale, lisibles par les tests : points agrégés (coin de la cellule,
## relatif à la carte, et couleur), rectangle du cadre de la vue et de la carte.
var points_positions: PackedVector2Array = PackedVector2Array()
var points_couleurs: PackedColorArray = PackedColorArray()
var cadre_local: Rect2 = Rect2()
## Une entrée par autre joueur : `id`, `nom`, `rect` (local), `vivant`, `pv` (0 à 1, -1 s'il est
## inconnu) et `densite` (8 × 8 octets).
var vignettes: Array[Dictionary] = []

var _id_local: int = -1
var _id_regarde: int = -1
var _tour_pv: float = -1.0
var _classe_par_famille: PackedInt32Array = PackedInt32Array()
var _pv_connus: Dictionary = {}
var _cellules: PackedInt32Array = PackedInt32Array()
var _noms_courts: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(COTE_CARTE, COTE_CARTE)
	size = custom_minimum_size
	visible = false


## Les familles d'ennemis et leur palier : sans cet appel, le palier se déduit du rang de la
## famille. Le convoi et le boss (au-delà des 24 familles) ont leur propre couleur.
func configurer(donnees: Donnees) -> void:
	_classe_par_famille = PackedInt32Array()
	if donnees == null:
		return
	for famille: Dictionary in donnees.familles:
		_classe_par_famille.append(int(famille["indice_palier"]))
	_classe_par_famille.append(CLASSE_CONVOI)
	_classe_par_famille.append(CLASSE_BOSS)


## Couleur d'un ennemi de la famille `famille` : celle de son palier.
func couleur_famille(famille: int) -> Color:
	return COULEURS_CLASSES[_classe(famille)]


## Met à jour la carte avec l'arène `vue` (la sienne ou celle qu'on regarde), la vue globale (les
## autres joueurs et leurs densités), l'identifiant du joueur local et le cadre de la vue (unités
## de jeu, repère de la tour). Sans `vue`, la carte ne bouge pas.
func afficher(vue: VueArene, globale: VueGlobale, id_local: int, cadre: Rect2) -> void:
	_id_local = id_local
	if vue != null:
		_tour_pv = _ratio(vue.tour_pv, vue.tour_pv_max)
		_agreger(vue)
	_construire_vignettes(globale)
	definir_cadre(cadre)
	_ajuster_taille()
	queue_redraw()


## Seul le cadre bouge (la caméra se déplace à chaque image, l'arène arrive à 15 Hz).
func definir_cadre(cadre: Rect2) -> void:
	if (
		not cadre.position.is_finite()
		or not cadre.size.is_finite()
		or cadre.size.x <= 0.0
		or cadre.size.y <= 0.0
	):
		cadre_local = Rect2()
	else:
		var coin := unites_vers_case(cadre.position)
		var fin := unites_vers_case(cadre.end)
		cadre_local = Rect2(coin, fin - coin).intersection(rect_carte())
	queue_redraw()


## Les PV de tour d'un joueur, connus quand on regarde son arène : la vue globale ne les porte
## pas, sa vignette n'a donc de barre que pour la dernière arène regardée.
func definir_pv(id_joueur: int, pv: float, pv_max: float) -> void:
	_pv_connus[id_joueur] = _ratio(pv, pv_max)
	for v: Dictionary in vignettes:
		if int(v["id"]) == id_joueur:
			v["pv"] = _pv_connus[id_joueur]
	queue_redraw()


## L'arène regardée (-1 : la sienne), pour entourer sa vignette.
func definir_regarde(id_joueur: int) -> void:
	_id_regarde = id_joueur
	queue_redraw()


## Rectangle de la carte principale, en coordonnées locales : à droite des vignettes.
func rect_carte() -> Rect2:
	return Rect2(Vector2(_largeur_vignettes(), 0.0), Vector2(COTE_CARTE, COTE_CARTE))


## Taille que la mini-carte veut occuper : la carte seule en solo, les vignettes à sa gauche sinon.
func taille_voulue() -> Vector2:
	return Vector2(_largeur_vignettes() + COTE_CARTE, COTE_CARTE)


## Point du monde (unités de jeu, repère de la tour) sous la position locale `position_locale` de
## la carte. Hors de la carte ou non fini : `Vector2(NAN, NAN)`, que personne ne doit suivre.
func case_vers_unites(position_locale: Vector2) -> Vector2:
	var carte := rect_carte()
	# Les bords comptent comme dans la carte (`Rect2.has_point` exclut le bord droit et le bas).
	if (
		not position_locale.is_finite()
		or position_locale.x < carte.position.x
		or position_locale.x > carte.end.x
		or position_locale.y < carte.position.y
		or position_locale.y > carte.end.y
	):
		return Vector2(NAN, NAN)
	return (position_locale - carte.get_center()) / _echelle()


## Position locale d'un point du monde, sans borne (le cadre peut déborder de la carte).
func unites_vers_case(point_unites: Vector2) -> Vector2:
	return rect_carte().get_center() + point_unites * _echelle()


## Identifiant du joueur dont la vignette contient `position_locale`, -1 s'il n'y en a pas.
func joueur_sous(position_locale: Vector2) -> int:
	if not position_locale.is_finite():
		return -1
	for v: Dictionary in vignettes:
		if (v["rect"] as Rect2).has_point(position_locale):
			return int(v["id"])
	return -1


# --- Données ---------------------------------------------------------------------------------


func _echelle() -> float:
	return COTE_CARTE / (2.0 * DEMI_MONDE)


func _largeur_vignettes() -> float:
	if vignettes.is_empty():
		return 0.0
	var colonnes := ceili(float(vignettes.size()) / VIGNETTES_PAR_COLONNE)
	return colonnes * (LARGEUR_VIGNETTE + ESPACE)


func _ajuster_taille() -> void:
	var voulue := taille_voulue()
	custom_minimum_size = voulue
	size = voulue


func _classe(famille: int) -> int:
	if famille >= 0 and famille < _classe_par_famille.size():
		return clampi(_classe_par_famille[famille], 0, COULEURS_CLASSES.size() - 1)
	# Sans données : quatre familles par modèle (palier = rang modulo 4), au-delà le convoi.
	return clampi(maxi(famille, 0) % CLASSE_CONVOI, 0, CLASSE_CONVOI - 1)


static func _ratio(valeur: float, maximum: float) -> float:
	if not is_finite(valeur) or not is_finite(maximum) or maximum <= 0.0:
		return 0.0
	return clampf(valeur / maximum, 0.0, 1.0)


## Les ennemis tombent dans une grille de cellules de `COTE_CELLULE` pixels ; chaque cellule
## prend la couleur de la classe la plus nombreuse. Le nombre de rectangles est borné par la
## surface de la carte, pas par la foule.
func _agreger(vue: VueArene) -> void:
	var cote := ceili(COTE_CARTE / COTE_CELLULE)
	var classes := COULEURS_CLASSES.size()
	_cellules.resize(cote * cote * classes)
	_cellules.fill(0)
	var echelle := _echelle()
	var nombre := mini(vue.ennemis_pos.size(), vue.ennemis_famille.size())
	for i: int in nombre:
		var p := vue.ennemis_pos[i]
		if not p.is_finite():
			continue
		var local := p * echelle + Vector2(COTE_CARTE, COTE_CARTE) * 0.5
		var cx := clampi(int(local.x / COTE_CELLULE), 0, cote - 1)
		var cy := clampi(int(local.y / COTE_CELLULE), 0, cote - 1)
		_cellules[(cy * cote + cx) * classes + _classe(vue.ennemis_famille[i])] += 1
	points_positions = PackedVector2Array()
	points_couleurs = PackedColorArray()
	for cy: int in cote:
		for cx: int in cote:
			var base := (cy * cote + cx) * classes
			var meilleure := -1
			var meilleur := 0
			for c: int in classes:
				if _cellules[base + c] > meilleur:
					meilleur = _cellules[base + c]
					meilleure = c
			if meilleure < 0:
				continue
			var coin := Vector2(cx, cy) * COTE_CELLULE
			points_positions.append(coin)
			points_couleurs.append(COULEURS_CLASSES[meilleure])


func _construire_vignettes(globale: VueGlobale) -> void:
	vignettes = []
	if globale == null:
		return
	var rang := 0
	for joueur: Dictionary in globale.joueurs:
		var id: int = joueur["id"]
		if id == _id_local:
			continue
		var colonne := floori(float(rang) / VIGNETTES_PAR_COLONNE)
		var rangee := rang % VIGNETTES_PAR_COLONNE
		var coin := Vector2(
			colonne * (LARGEUR_VIGNETTE + ESPACE), rangee * (HAUTEUR_VIGNETTE + INTERVALLE)
		)
		var vivant: bool = joueur["vivant"]
		var densite: PackedByteArray = _reduire(globale.densites.get(id, PackedByteArray()))
		(
			vignettes
			. append(
				{
					"id": id,
					"nom": str(joueur["nom"]),
					"rect": Rect2(coin, Vector2(LARGEUR_VIGNETTE, HAUTEUR_VIGNETTE)),
					"vivant": vivant,
					"pv": 0.0 if not vivant else float(_pv_connus.get(id, -1.0)),
					"densite": densite,
				}
			)
		)
		rang += 1


## Carte 16 × 16 → 8 × 8 (somme de quatre cases, saturée à 255). Vide si la carte est absente ou
## n'a pas 256 octets.
func _reduire(brute: Variant) -> PackedByteArray:
	var sortie := PackedByteArray()
	if typeof(brute) != TYPE_PACKED_BYTE_ARRAY:
		return sortie
	var densite: PackedByteArray = brute
	if densite.size() != COTE_DENSITE * COTE_DENSITE:
		return sortie
	sortie.resize(COTE_DENSITE_VIGNETTE * COTE_DENSITE_VIGNETTE)
	for y: int in COTE_DENSITE_VIGNETTE:
		for x: int in COTE_DENSITE_VIGNETTE:
			var somme := 0
			for dy: int in 2:
				for dx: int in 2:
					somme += densite[(2 * y + dy) * COTE_DENSITE + 2 * x + dx]
			sortie[y * COTE_DENSITE_VIGNETTE + x] = mini(somme, 255)
	return sortie


# --- Entrée ----------------------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	var bouton := event as InputEventMouseButton
	if bouton != null and bouton.pressed and bouton.button_index == MOUSE_BUTTON_LEFT:
		cliquer(bouton.position)
		accept_event()
		return
	var mouvement := event as InputEventMouseMotion
	if mouvement != null and (mouvement.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		# Glisser sur la carte déplace la vue en continu ; sur une vignette, rien.
		var point := case_vers_unites(mouvement.position)
		if point.is_finite():
			demande_centrage.emit(point)
			accept_event()


## Un clic à `position_locale` : une vignette demande de la regarder, la carte de s'y centrer ;
## ailleurs, hors de la carte ou à une coordonnée non finie, rien ne se passe.
func cliquer(position_locale: Vector2) -> void:
	var id := joueur_sous(position_locale)
	if id >= 0:
		demande_regarder.emit(id)
		return
	var point := case_vers_unites(position_locale)
	if point.is_finite():
		demande_centrage.emit(point)


func _get_tooltip(at_position: Vector2) -> String:
	var id := joueur_sous(at_position)
	if id < 0:
		return tr("MINICARTE_INFOBULLE_CARTE")
	for v: Dictionary in vignettes:
		if int(v["id"]) == id:
			return tr("MINICARTE_INFOBULLE_VIGNETTE") % str(v["nom"])
	return ""


# --- Dessin ----------------------------------------------------------------------------------


func _draw() -> void:
	var carte := rect_carte()
	draw_rect(carte, FOND)
	var cellule := Vector2(COTE_CELLULE, COTE_CELLULE)
	for i: int in points_positions.size():
		draw_rect(Rect2(carte.position + points_positions[i], cellule), points_couleurs[i])
	draw_arc(
		carte.get_center(), CameraArene.RAYON_APPARITION * _echelle(), 0.0, TAU, 48, CERCLE, 1.0
	)
	draw_circle(carte.get_center(), 3.0, TOUR)
	if cadre_local.size.x > 0.0 and cadre_local.size.y > 0.0:
		draw_rect(cadre_local, CADRE, false, 1.0)
	draw_rect(carte, BORD, false, 2.0)
	for v: Dictionary in vignettes:
		_dessiner_vignette(v)


func _dessiner_vignette(v: Dictionary) -> void:
	var rect: Rect2 = v["rect"]
	var vivant: bool = v["vivant"]
	var regardee: bool = int(v["id"]) == _id_regarde
	draw_rect(rect, FOND)
	var apercu := Rect2(rect.position + Vector2(3.0, 3.0), Vector2(COTE_APERCU, COTE_APERCU))
	var densite: PackedByteArray = v["densite"]
	var pas := COTE_APERCU / COTE_DENSITE_VIGNETTE
	for i: int in densite.size():
		if densite[i] == 0:
			continue
		var intensite := clampf(0.25 + densite[i] / 64.0, 0.25, 1.0)
		var couleur := ThemeJeu.JAUGE_BASSE.lerp(TOUR, intensite)
		couleur.a = 1.0 if vivant else 0.35
		var case := Vector2(i % COTE_DENSITE_VIGNETTE, floori(float(i) / COTE_DENSITE_VIGNETTE))
		draw_rect(Rect2(apercu.position + case * pas, Vector2(pas, pas)), couleur)
	draw_rect(apercu, BORD, false, 1.0)
	var x_texte := apercu.end.x + 4.0
	var largeur_texte := rect.end.x - x_texte - 3.0
	var couleur_texte := ThemeJeu.PARCHEMIN if vivant else ThemeJeu.PARCHEMIN_ATTENU
	var police := ThemeJeu.police()
	draw_string(
		police,
		Vector2(x_texte, rect.position.y + 17.0),
		_nom_court(str(v["nom"]), largeur_texte, police),
		HORIZONTAL_ALIGNMENT_LEFT,
		largeur_texte,
		TAILLE_TEXTE,
		couleur_texte
	)
	var barre := Rect2(
		Vector2(x_texte, rect.end.y - HAUTEUR_BARRE - 3.0), Vector2(largeur_texte, HAUTEUR_BARRE)
	)
	draw_rect(barre, ThemeJeu.JAUGE_FOND)
	var pv: float = v["pv"]
	if pv >= 0.0:
		var plein := Rect2(barre.position, Vector2(barre.size.x * pv, barre.size.y))
		draw_rect(plein, ThemeJeu.JAUGE_PLEINE if pv > 0.35 else ThemeJeu.JAUGE_BASSE)
	draw_rect(barre, ThemeJeu.PARCHEMIN_ATTENU, false, 1.0)
	draw_rect(rect, TOUR if regardee else BORD, false, 3.0 if regardee else 1.0)


## Le nom raccourci par « … » pour tenir dans `largeur` ; le nom entier est dans l'infobulle.
func _nom_court(nom: String, largeur: float, police: Font) -> String:
	var cle := "%s|%d" % [nom, roundi(largeur)]
	if _noms_courts.has(cle):
		return _noms_courts[cle]
	var court := nom
	if police.get_string_size(nom, 0, -1, TAILLE_TEXTE).x > largeur:
		while (
			court.length() > 1
			and police.get_string_size(court + "…", 0, -1, TAILLE_TEXTE).x > largeur
		):
			court = court.substr(0, court.length() - 1)
		court += "…"
	_noms_courts[cle] = court
	return court
