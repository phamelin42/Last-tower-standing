class_name NomsOrigine
extends RefCounted
## Les noms d'armes et d'améliorations de la map d'origine, lus dans `docs/tower_survivors.md`
## (§4.1, §4.2 et §4.3), et leur recherche dans un texte. Le jeu ne reprend que les mécaniques :
## aucun de ces noms ne doit apparaître dans nos données, nos textes ni notre code.

const DOCUMENT := "res://docs/tower_survivors.md"
const PREFIXE_SECTION_NOMS := "### 4."
const FIN_SECTIONS := "## 5."

## Mots courants (français ou anglais) qui sont aussi un nom d'origine d'un seul mot. Un tel
## nom n'est refusé que s'il est le nom entier d'un objet (`nom` d'une arme, d'une amélioration,
## d'une famille, d'une unité), jamais comme mot d'un texte ou d'un code. Liste fermée, 3 au plus.
const HOMOGRAPHES_FRANCAIS: Array[String] = [
	# Clé de données du jeu (`recharge` : temps de recharge d'une arme) et mot courant.
	"Recharge",
	# Mot anglais ordinaire, et nom de fichier d'icône du pack (`bow`, `upg_bow` dans
	# `visuels/images_offres.gd`, hors de tout chemin à `/`) : écart au plan, qui ne prévoyait
	# que des chemins.
	"Bow",
]


## Noms bruts dans l'ordre du document, sans doublon : première colonne des tableaux de §4.1 et
## §4.2, puis les puces de §4.3. Vide si le document est absent.
static func lire(chemin: String = DOCUMENT) -> PackedStringArray:
	var noms := PackedStringArray()
	var fichier := FileAccess.open(chemin, FileAccess.READ)
	if fichier == null:
		return noms
	var dans_section := false
	var dans_puces := false
	while not fichier.eof_reached():
		var ligne := fichier.get_line()
		if ligne.begins_with(FIN_SECTIONS):
			break
		if ligne.begins_with("#") and not ligne.begins_with("####"):
			dans_section = ligne.begins_with(PREFIXE_SECTION_NOMS)
			dans_puces = ligne.begins_with("### 4.3")
			continue
		if not dans_section:
			continue
		var nom := ""
		if dans_puces:
			if ligne.begins_with("- "):
				nom = ligne.substr(2).strip_edges()
		elif ligne.begins_with("|"):
			var colonnes := ligne.split("|")
			if colonnes.size() > 1:
				nom = colonnes[1].strip_edges()
			if nom.is_empty() or nom.begins_with("-") or nom.contains("nom d’origine"):
				nom = ""
		if not nom.is_empty() and not noms.has(nom):
			noms.append(nom)
	return noms


## Minuscules, sans accents, apostrophes droites, espaces insécables et fines en espaces simples.
static func normaliser(texte: String) -> String:
	var propre := texte.to_lower()
	for apostrophe: String in ["’", "‘", "ʼ"]:
		propre = propre.replace(apostrophe, "'")
	for espace: String in ["\u00a0", "\u202f", "\u2009", "\u2007"]:
		propre = propre.replace(espace, " ")
	# Une chaîne vide fait journaliser une erreur à `strip_diacritics` (ICU).
	if propre.is_empty():
		return propre
	return TextServerManager.get_primary_interface().strip_diacritics(propre)


static func _motif(nom: String) -> RegEx:
	var regex := RegEx.new()
	var corps := normaliser(nom)
	var echappe := ""
	for i: int in corps.length():
		var c := corps[i]
		echappe += "\\" + c if "\\.+*?()|[]{}^$-/".contains(c) else c
	regex.compile("(?<![\\p{L}\\p{N}])" + echappe + "(?![\\p{L}\\p{N}])")
	return regex


## Les noms de `noms` contenus dans `texte` (mot entier, normalisé).
static func trouver(texte: String, noms: PackedStringArray) -> PackedStringArray:
	var trouves := PackedStringArray()
	var propre := normaliser(texte)
	for nom: String in noms:
		if _motif(nom).search(propre) != null:
			trouves.append(nom)
	return trouves


## Retire de la source GDScript tout littéral entre guillemets qui contient `/` (chemin de
## ressource) : le pack d'images nomme ses fichiers avec des mots anglais ordinaires.
static func sans_chemins_d_images(source: String) -> String:
	var regex := RegEx.new()
	regex.compile('"[^"\\n]*/[^"\\n]*"')
	return regex.sub(source, '""', true)
