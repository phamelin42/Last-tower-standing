class_name ReperesArme
extends RefCounted
## Repères d'une arme lus d'un coup d'œil : type de dégâts, mécanique (genre de l'effet) et statuts
## posés, chacun une petite icône avec son nom. Les icônes, leurs textes et leur taille vivent dans
## `data/assets.json` (section `icones_offre`) : remplacer un pack ne demande que les fichiers et
## ce JSON. La couleur ne porte jamais seule l'information : le type et la mécanique s'écrivent à
## côté de l'icône ; sur une carte, où la place manque, chaque icône a son nom en infobulle et en
## nom accessible.

const GROUPE_TYPE := "types_degats"
const GROUPE_GENRE := "genres"
const GROUPE_STATUT := "statuts"
const GROUPES: Array[String] = [GROUPE_TYPE, GROUPE_GENRE, GROUPE_STATUT]
const SEPARATEUR := " · "
const ESPACE := 2
const COTE_REPLI := 16.0


## Nombre de statuts qu'une carte montre en icône : au-delà, la ligne passerait à la ligne et la
## boutique grandirait (D13). L'infobulle de l'arme les cite tous (`texte_court`).
static func statuts_max_carte() -> int:
	return int(Assets.section("icones_offre").get("statuts_max_carte", 2))


## Taille d'une icône à l'écran, lue dans les données.
static func taille() -> float:
	return float(Assets.section("icones_offre").get("taille", COTE_REPLI))


## `{chemin, texte}` d'un repère (`texte` est une clé de traduction), vide s'il est inconnu.
static func entree(groupe: String, id: String) -> Dictionary:
	var table: Dictionary = Assets.section("icones_offre").get(groupe, {})
	return table.get(id, {})


## Icône d'un repère, `null` s'il est inconnu ou si son fichier manque.
static func icone(groupe: String, id: String) -> Texture2D:
	return ThemeJeu.icone_de_donnees(str(entree(groupe, id).get("chemin", "")))


## Mot écrit d'un repère, vide s'il est inconnu.
static func texte(groupe: String, id: String) -> String:
	var cle := str(entree(groupe, id).get("texte", ""))
	return "" if cle.is_empty() else TranslationServer.translate(cle)


## Les repères d'une arme, dans l'ordre : son type de dégâts, la mécanique de son effet, puis
## chaque statut distinct. Chacun est `{groupe, id}` ; une arme sans donnée n'en a aucun.
static func reperes(arme: Dictionary) -> Array[Dictionary]:
	var sortie: Array[Dictionary] = []
	if arme.has("type_degats"):
		sortie.append({"groupe": GROUPE_TYPE, "id": _nom_type(arme["type_degats"])})
	var vus: Dictionary = {}
	for effet: Dictionary in arme.get("effets", []):
		var kind := str(effet.get("kind", ""))
		if not vus.has(GROUPE_GENRE + kind):
			vus[GROUPE_GENRE + kind] = true
			sortie.append({"groupe": GROUPE_GENRE, "id": kind})
	for statut: Dictionary in arme.get("statuts", []):
		var kind := str(statut.get("kind", ""))
		if not vus.has(GROUPE_STATUT + kind):
			vus[GROUPE_STATUT + kind] = true
			sortie.append({"groupe": GROUPE_STATUT, "id": kind})
	return sortie


## Nom du type de dégâts : `Donnees` le garde en entier (`Types.TypeDegats`), le JSON en texte.
static func _nom_type(valeur: Variant) -> String:
	if valeur is int and valeur >= 0 and valeur < Types.NOMS_TYPES.size():
		return Types.NOMS_TYPES[valeur]
	return str(valeur)


## « Tranchant · Rebond · Poison » : les repères en une ligne, pour une infobulle ou une fiche.
static func texte_court(arme: Dictionary) -> String:
	var mots := PackedStringArray()
	for repere: Dictionary in reperes(arme):
		var mot := texte(str(repere["groupe"]), str(repere["id"]))
		if not mot.is_empty():
			mots.append(mot)
	return SEPARATEUR.join(mots)


## Rangée de repères d'une arme, sur une ligne : une icône par repère, dont le mot est en
## infobulle et en nom accessible ; avec `avec_texte`, le type et la mécanique s'écrivent aussi à
## côté de l'icône (un statut reste une icône seule) ; `statuts_max` borne les statuts montrés. Vide
## (sans enfant) pour une arme sans donnée.
static func creer_rangee(
	arme: Dictionary, nom: String, avec_texte: bool = true, statuts_max: int = 99
) -> Control:
	var rangee := HBoxContainer.new()
	rangee.name = nom
	rangee.add_theme_constant_override("separation", ESPACE)
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var statuts := 0
	for repere: Dictionary in reperes(arme):
		if str(repere["groupe"]) == GROUPE_STATUT:
			statuts += 1
			if statuts > statuts_max:
				continue
		var puce := _creer_puce(str(repere["groupe"]), str(repere["id"]), avec_texte)
		if puce != null:
			rangee.add_child(puce)
	return rangee


## Petite icône du type de dégâts d'une arme, posée en haut à gauche de son parent. Décorative : le
## type s'écrit dans l'infobulle de l'arme. `null` si l'arme n'a pas de type connu.
static func creer_icone_type(arme: Dictionary, cote: float) -> TextureRect:
	if not arme.has("type_degats"):
		return null
	var image := icone(GROUPE_TYPE, _nom_type(arme["type_degats"]))
	if image == null:
		return null
	var vignette := TextureRect.new()
	vignette.name = "TypeDegats"
	vignette.texture = image
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vignette.custom_minimum_size = Vector2(cote, cote)
	vignette.modulate = ThemeJeu.LAITON_CLAIR
	vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_TOP_LEFT)
	return vignette


static func _creer_puce(groupe: String, id: String, avec_texte: bool) -> Control:
	var image := icone(groupe, id)
	var mot := texte(groupe, id)
	if image == null or mot.is_empty():
		return null
	var puce := HBoxContainer.new()
	puce.name = "Repere_%s_%s" % [groupe, id]
	puce.add_theme_constant_override("separation", ESPACE)
	puce.tooltip_text = mot
	puce.accessibility_name = mot
	puce.mouse_filter = Control.MOUSE_FILTER_STOP
	puce.set_meta("groupe", groupe)
	puce.set_meta("id", id)
	var vignette := TextureRect.new()
	vignette.name = "Icone"
	vignette.texture = image
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vignette.custom_minimum_size = Vector2(taille(), taille())
	vignette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vignette.modulate = ThemeJeu.LAITON_CLAIR
	vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puce.add_child(vignette)
	if avec_texte and groupe != GROUPE_STATUT:
		var libelle := Label.new()
		libelle.name = "Mot"
		libelle.text = mot
		libelle.theme_type_variation = "Petit"
		libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		libelle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		puce.add_child(libelle)
	return puce
