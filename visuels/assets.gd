class_name Assets
extends RefCounted
## Le seul accès aux données des assets (`data/assets.json`, T10.4) : chemin, case, nombre d'images,
## régions, ancrages, échelle, durée de chaque image ou son. Remplacer un pack d'images ne demande
## que de changer les fichiers et ce JSON, jamais le code. Les nombres du JSON sont lus tels quels :
## `convertir` en tire les types du moteur (`Rect2`, `Vector2i`, `Color`) d'après la forme de chaque
## objet, comme les constantes qu'ils remplacent.

const CHEMIN := "res://data/assets.json"
## Clés dont les nombres sont des entiers dans les tables du code (le JSON ne distingue pas).
const ENTIERS: Array[String] = ["colonnes", "lignes", "images", "ligne"]
## Clés dont l'objet `{x, y}` est un `Vector2i` et non un `Vector2`.
const POINTS_ENTIERS: Array[String] = ["origine"]
## Clés dont la liste de 3 ou 4 nombres est une couleur.
const COULEURS: Array[String] = ["teinte", "exterieur", "interieur", "contour"]

static var _tout: Dictionary = {}
static var _lu: bool = false


## Tout le fichier, lu une fois. Vide (et une erreur) si le fichier manque ou est abîmé.
static func tout() -> Dictionary:
	if not _lu:
		_lu = true
		_tout = _lire(CHEMIN)
	return _tout


## Une section du fichier (`unites`, `tour`, `decor`…), vide si elle manque.
static func section(nom: String) -> Dictionary:
	return tout().get(nom, {})


## Une section avec les types du moteur : `Rect2`, `Vector2`, `Vector2i`, `Color`, entiers.
static func typee(nom: String) -> Dictionary:
	return convertir(section(nom), nom) as Dictionary


## Remplace les données par `donnees` (tests : un autre pack, d'autres tailles). `reinitialiser`
## relit le fichier.
static func remplacer(donnees: Dictionary) -> void:
	_tout = donnees
	_lu = true


static func reinitialiser() -> void:
	_tout = {}
	_lu = false


static func _lire(chemin: String) -> Dictionary:
	var texte := FileAccess.get_file_as_string(chemin)
	var json := JSON.new()
	if texte.is_empty() or json.parse(texte) != OK or not json.data is Dictionary:
		push_error("%s : fichier absent ou illisible" % chemin)
		return {}
	return json.data


## Les types du moteur d'après la forme : `{x, y, largeur, hauteur}` → `Rect2`, `{largeur, hauteur}`
## → `Vector2i`, `{ligne, images}` → `Vector2i`, `{x, y}` → `Vector2` (`Vector2i` pour les clés de
## `POINTS_ENTIERS`), liste de 3 ou 4 nombres sous une clé de `COULEURS` → `Color`.
static func convertir(valeur: Variant, cle: String = "") -> Variant:
	if valeur is Dictionary:
		var d: Dictionary = valeur
		var forme := PackedStringArray()
		for k: Variant in d:
			forme.append(str(k))
		forme.sort()
		if forme == PackedStringArray(["hauteur", "largeur", "x", "y"]):
			return Rect2(float(d["x"]), float(d["y"]), float(d["largeur"]), float(d["hauteur"]))
		if forme == PackedStringArray(["hauteur", "largeur"]):
			return Vector2i(int(d["largeur"]), int(d["hauteur"]))
		if forme == PackedStringArray(["images", "ligne"]):
			return Vector2i(int(d["ligne"]), int(d["images"]))
		if forme == PackedStringArray(["x", "y"]):
			if cle in POINTS_ENTIERS:
				return Vector2i(int(d["x"]), int(d["y"]))
			return Vector2(float(d["x"]), float(d["y"]))
		var sortie: Dictionary = {}
		for k: Variant in d:
			sortie[k] = convertir(d[k], str(k))
		return sortie
	if valeur is Array:
		var liste: Array = valeur
		if cle in COULEURS and (liste.size() == 3 or liste.size() == 4):
			return Color(
				float(liste[0]),
				float(liste[1]),
				float(liste[2]),
				float(liste[3]) if liste.size() == 4 else 1.0
			)
		var sortie: Array = []
		for x: Variant in liste:
			sortie.append(convertir(x, cle))
		return sortie
	if valeur is float and cle in ENTIERS:
		return int(valeur)
	return valeur
