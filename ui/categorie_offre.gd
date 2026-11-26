class_name CategorieOffre
extends RefCounted
## Repère de catégorie d'une offre : ruban de couleur (rouge pour une arme, bleu pour une
## amélioration, jaune pour le revenu), icône et mot écrit. La couleur ne porte jamais seule
## l'information : le mot est toujours là. Les chemins d'images vivent dans `ThemeJeu`.

## Clés de texte du mot, dans l'ordre de `Types.Categorie`.
const CLES_MOT: Array[String] = [
	"BOUTIQUE_CATEGORIE_ARME", "BOUTIQUE_CATEGORIE_AMELIORATION", "BOUTIQUE_CATEGORIE_REVENU"
]
const COTE_ICONE := 20.0
const NOM_REPERE := "Repere"


## `{ruban, icone, mot_cle}` d'une catégorie (`Types.Categorie`) : chemins du ruban et de l'icône,
## clé de texte du mot. Vide pour une catégorie inconnue.
static func rubrique(categorie: int) -> Dictionary:
	if categorie < 0 or categorie >= Types.NOMS_CATEGORIES.size():
		return {}
	return {
		"ruban": ThemeJeu.TEXTURES_RUBAN_CATEGORIE[categorie],
		"icone": ThemeJeu.ICONES_CATEGORIE[categorie],
		"mot_cle": CLES_MOT[categorie],
	}


## Mot écrit de la catégorie (« Arme », « Amélioration », « Revenu »), vide si elle est inconnue.
static func mot(categorie: int) -> String:
	var entree := rubrique(categorie)
	return "" if entree.is_empty() else TranslationServer.translate(str(entree["mot_cle"]))


## Icône de la catégorie, `null` si elle est inconnue.
static func icone(categorie: int) -> Texture2D:
	return ThemeJeu.icone_categorie(categorie)


## Ruban de catégorie : icône et mot sur la bande de la couleur de la catégorie. Un contrôle
## vide (invisible) pour une catégorie inconnue, jamais une exception.
static func creer_ruban(categorie: int, nom: String) -> Control:
	var ruban := PanelContainer.new()
	ruban.name = nom
	ruban.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rubrique(categorie).is_empty():
		ruban.visible = false
		return ruban
	ruban.theme_type_variation = ThemeJeu.TYPES_RUBAN_CATEGORIE[categorie]
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 4)
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ruban.add_child(rangee)
	rangee.add_child(creer_icone(categorie, NOM_REPERE))
	var libelle := Label.new()
	libelle.name = "Mot"
	libelle.text = mot(categorie)
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	libelle.theme_type_variation = "Petit"
	libelle.add_theme_color_override("font_color", ThemeJeu.ENCRE_RUBAN_CATEGORIE)
	libelle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(libelle)
	return ruban


## Petite icône de la catégorie, décorative (le mot est écrit ailleurs : infobulle ou ruban).
static func creer_icone(categorie: int, nom: String, taille: float = COTE_ICONE) -> TextureRect:
	var image := TextureRect.new()
	image.name = nom
	image.texture = icone(categorie)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(taille, taille)
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_meta("categorie", categorie)
	return image
