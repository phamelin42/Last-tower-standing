class_name CasDeTest
extends RefCounted
## Classe de base d'un fichier de tests. Une assertion fausse enregistre un échec
## et laisse la méthode continuer.
##
## Égalité : `verifier_egal` compare les valeurs en profondeur (tableaux et
## dictionnaires, ordre des clés ignoré) ET exige le même type. Ainsi `1` et `1.0`
## ne sont pas égaux, même imbriqués : un test qui attend un entier ne doit pas
## passer sur un flottant. Pour comparer des flottants, utiliser `verifier_proche`.

## Fourni par le lanceur, pour instancier des nœuds.
var arbre: SceneTree
var echecs: Array[String] = []
var nb_assertions: int = 0
## Motifs des erreurs voulues, pas encore survenues (voir `attendre_erreur`).
var erreurs_attendues: Array[String] = []


func avant_chaque() -> void:
	pass


func apres_chaque() -> void:
	pass


## Toute erreur journalisée pendant la méthode (erreur de script, `push_error`) la fait
## échouer, sauf si elle est déclarée ici : une erreur dont le message contient `motif`
## doit survenir. Chaque déclaration est consommée par une seule erreur ; une déclaration
## qui ne se réalise pas fait échouer la méthode. Une erreur voulue qui survient compte
## pour une assertion.
func attendre_erreur(motif: String) -> void:
	erreurs_attendues.append(motif)


func verifier(condition: bool, message: String = "") -> void:
	nb_assertions += 1
	if not condition:
		echecs.append(message if not message.is_empty() else "condition fausse")


func verifier_faux(condition: bool, message: String = "") -> void:
	nb_assertions += 1
	if condition:
		echecs.append(message if not message.is_empty() else "condition vraie")


func verifier_egal(recu: Variant, attendu: Variant, message: String = "") -> void:
	nb_assertions += 1
	if not _egal(recu, attendu):
		echecs.append(_echec(message, "attendu %s, reçu %s" % [_texte(attendu), _texte(recu)]))


func verifier_different(recu: Variant, interdit: Variant, message: String = "") -> void:
	nb_assertions += 1
	if _egal(recu, interdit):
		echecs.append(_echec(message, "valeur interdite : %s" % _texte(recu)))


func verifier_proche(
	recu: float, attendu: float, tolerance: float = 0.0001, message: String = ""
) -> void:
	nb_assertions += 1
	# Écrit en positif pour que NAN soit toujours un échec.
	if not absf(recu - attendu) <= tolerance:
		var detail := "attendu %s ± %s, reçu %s" % [attendu, tolerance, recu]
		echecs.append(_echec(message, detail))


func verifier_nul(valeur: Variant, message: String = "") -> void:
	nb_assertions += 1
	if valeur != null:
		echecs.append(_echec(message, "attendu null, reçu %s" % _texte(valeur)))


func verifier_non_nul(valeur: Variant, message: String = "") -> void:
	nb_assertions += 1
	if valeur == null:
		echecs.append(_echec(message, "attendu une valeur, reçu null"))


func verifier_contient(collection: Variant, element: Variant, message: String = "") -> void:
	nb_assertions += 1
	var present := false
	match typeof(collection):
		TYPE_NIL:
			present = false
		TYPE_STRING, TYPE_STRING_NAME:
			present = (
				typeof(element) in [TYPE_STRING, TYPE_STRING_NAME]
				and str(element) in str(collection)
			)
		_:
			# `in` tolère int/float ; on garde la règle de verifier_egal pour les listes.
			present = _contient(collection, element)
	if not present:
		var detail := "%s ne contient pas %s" % [_texte(collection), _texte(element)]
		echecs.append(_echec(message, detail))


func _contient(collection: Variant, element: Variant) -> bool:
	if collection is Dictionary:
		var dico: Dictionary = collection
		for cle: Variant in dico:
			if _egal(cle, element):
				return true
		return false
	if collection is Array:
		var liste: Array = collection
		for item: Variant in liste:
			if _egal(item, element):
				return true
		return false
	# Tableaux compactés : ils sont typés, `in` suffit.
	return element in collection


func _echec(message: String, detail: String) -> String:
	if message.is_empty():
		return detail
	return "%s (%s)" % [message, detail]


func _texte(valeur: Variant) -> String:
	return var_to_str(valeur).replace("\n", " ")


func _egal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		return _egal_tableaux(a, b)
	if a is Dictionary:
		return _egal_dictionnaires(a, b)
	return a == b


func _egal_tableaux(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not _egal(a[i], b[i]):
			return false
	return true


func _egal_dictionnaires(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for cle: Variant in a:
		if not b.has(cle) or not _egal(a[cle], b[cle]):
			return false
	return true
