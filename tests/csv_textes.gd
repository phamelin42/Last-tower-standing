class_name CsvTextes
extends RefCounted
## Lit un CSV de traduction Godot (`keys,fr`) directement, sans passer par le moteur : les
## tests vérifient ainsi les clés des fichiers, même avant qu'ils soient enregistrés dans
## `project.godot` (T2.7).


## Renvoie `clé → texte français`. Dictionnaire vide si le fichier est absent.
static func lire(chemin: String) -> Dictionary:
	var textes: Dictionary = {}
	var fichier := FileAccess.open(chemin, FileAccess.READ)
	if fichier == null:
		return textes
	var premiere_ligne := true
	while fichier.get_position() < fichier.get_length():
		var ligne := fichier.get_line()
		if ligne.is_empty():
			continue
		if premiere_ligne:
			premiere_ligne = false
			continue
		var champs := _champs(ligne)
		if champs.size() == 2:
			textes[champs[0]] = champs[1]
	return textes


## Découpe une ligne CSV ; un champ entre guillemets peut contenir des virgules, et `""`
## y désigne un guillemet.
static func _champs(ligne: String) -> PackedStringArray:
	var champs := PackedStringArray()
	var courant := ""
	var entre_guillemets := false
	var i: int = 0
	while i < ligne.length():
		var c: String = ligne[i]
		if entre_guillemets:
			if c == '"':
				if i + 1 < ligne.length() and ligne[i + 1] == '"':
					courant += '"'
					i += 1
				else:
					entre_guillemets = false
			else:
				courant += c
		elif c == '"':
			entre_guillemets = true
		elif c == ",":
			champs.append(courant)
			courant = ""
		else:
			courant += c
		i += 1
	champs.append(courant)
	return champs
