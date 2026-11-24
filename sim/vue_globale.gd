class_name VueGlobale
extends RefCounted
## Vue globale : l'état partagé de la partie (joueurs, classement), diffusé à 2 Hz. Même
## contrat que `VueArene` : `from_dict` renvoie `null` sur donnée invalide, sans exception,
## et la vue ne partage aucune mémoire avec la source.

const SCHEMA: Dictionary = {
	"joueurs": TYPE_ARRAY,
	"temps_ecoule": TYPE_FLOAT,
	"en_cours": TYPE_BOOL,
	"termine": TYPE_BOOL,
	"classement": TYPE_ARRAY,
	"dernier_rempart": TYPE_INT,
}

const SCHEMA_JOUEUR: Dictionary = {
	"id": TYPE_INT,
	"nom": TYPE_STRING,
	"manche": TYPE_INT,
	"eliminations": TYPE_INT,
	"degats": TYPE_FLOAT,
	"revenu": TYPE_INT,
	"vivant": TYPE_BOOL,
	"victorieux": TYPE_BOOL,
}

var joueurs: Array[Dictionary] = []
var temps_ecoule: float = 0.0
var en_cours: bool = false
var termine: bool = false
var classement: Array[int] = []
var dernier_rempart: int = -1


func to_dict() -> Dictionary:
	return {
		"joueurs": joueurs.duplicate(true),
		"temps_ecoule": temps_ecoule,
		"en_cours": en_cours,
		"termine": termine,
		"classement": classement.duplicate(),
		"dernier_rempart": dernier_rempart,
	}


static func from_dict(d: Dictionary) -> VueGlobale:
	if not _valide(d):
		return null
	var vue := VueGlobale.new()
	vue.joueurs = _copie_joueurs(d["joueurs"])
	vue.temps_ecoule = d["temps_ecoule"]
	vue.en_cours = d["en_cours"]
	vue.termine = d["termine"]
	vue.classement = _copie_entiers(d["classement"])
	vue.dernier_rempart = d["dernier_rempart"]
	return vue


static func _valide(d: Dictionary) -> bool:
	if not _conforme(d, SCHEMA):
		return false
	if not _liste_conforme(d["joueurs"], SCHEMA_JOUEUR):
		return false
	return _liste_entiers_valide(d["classement"])


static func _conforme(d: Dictionary, schema: Dictionary) -> bool:
	for cle: String in schema:
		if not d.has(cle):
			return false
		var attendu: int = schema[cle]
		if typeof(d[cle]) != attendu:
			return false
	return true


static func _liste_conforme(valeur: Variant, schema: Dictionary) -> bool:
	if typeof(valeur) != TYPE_ARRAY:
		return false
	var liste: Array = valeur
	for item: Variant in liste:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var entree: Dictionary = item
		if not _conforme(entree, schema):
			return false
	return true


static func _liste_entiers_valide(valeur: Variant) -> bool:
	if typeof(valeur) != TYPE_ARRAY:
		return false
	var liste: Array = valeur
	for item: Variant in liste:
		if typeof(item) != TYPE_INT:
			return false
	return true


static func _copie_joueurs(valeur: Variant) -> Array[Dictionary]:
	var copie: Array[Dictionary] = []
	var liste: Array = valeur
	for item: Variant in liste:
		var entree: Dictionary = item
		copie.append(entree.duplicate(true))
	return copie


static func _copie_entiers(valeur: Variant) -> Array[int]:
	var copie: Array[int] = []
	var liste: Array = valeur
	for item: Variant in liste:
		var entier: int = item
		copie.append(entier)
	return copie
