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
	"densites": TYPE_DICTIONARY,
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

## Champ facultatif d'un joueur : les dégâts par seconde (flottant). Un état qui ne l'a pas se relit
## avec 0.0, pour que les lecteurs n'aient pas à tester sa présence.
const CHAMPS_JOUEUR_FACULTATIFS: Dictionary = {"dps": TYPE_FLOAT}

## Carte de densité d'une arène : 16 × 16 cases, ligne par ligne, un octet par case.
const DENSITE_OCTETS := 256

var joueurs: Array[Dictionary] = []
var temps_ecoule: float = 0.0
var en_cours: bool = false
var termine: bool = false
var classement: Array[int] = []
var dernier_rempart: int = -1
## Identifiant de joueur → carte de densité (`DENSITE_OCTETS` octets). Vide quand elle n'est pas
## diffusée à ce tour.
var densites: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"joueurs": joueurs.duplicate(true),
		"temps_ecoule": temps_ecoule,
		"en_cours": en_cours,
		"termine": termine,
		"classement": classement.duplicate(),
		"dernier_rempart": dernier_rempart,
		"densites": _copie_densites(densites),
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
	vue.densites = _copie_densites(d["densites"])
	return vue


static func _valide(d: Dictionary) -> bool:
	if not _conforme(d, SCHEMA):
		return false
	if not _liste_conforme(d["joueurs"], SCHEMA_JOUEUR):
		return false
	if not _champs_facultatifs_conformes(d["joueurs"]):
		return false
	if not _densites_valides(d["densites"]):
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
		var joueur: Dictionary = entree.duplicate(true)
		if not joueur.has("dps"):
			joueur["dps"] = 0.0
		copie.append(joueur)
	return copie


## Les champs facultatifs d'un joueur, quand ils sont là, ont le bon type.
static func _champs_facultatifs_conformes(valeur: Variant) -> bool:
	var liste: Array = valeur
	for item: Variant in liste:
		var entree: Dictionary = item
		for cle: String in CHAMPS_JOUEUR_FACULTATIFS:
			if entree.has(cle) and typeof(entree[cle]) != int(CHAMPS_JOUEUR_FACULTATIFS[cle]):
				return false
	return true


## Clés entières, valeurs : exactement `DENSITE_OCTETS` octets.
static func _densites_valides(valeur: Variant) -> bool:
	var dico: Dictionary = valeur
	for cle: Variant in dico:
		if typeof(cle) != TYPE_INT or typeof(dico[cle]) != TYPE_PACKED_BYTE_ARRAY:
			return false
		var carte: PackedByteArray = dico[cle]
		if carte.size() != DENSITE_OCTETS:
			return false
	return true


static func _copie_densites(valeur: Variant) -> Dictionary:
	var source: Dictionary = valeur
	var copie: Dictionary = {}
	for cle: Variant in source:
		var carte: PackedByteArray = source[cle]
		copie[cle] = carte.duplicate()
	return copie


static func _copie_entiers(valeur: Variant) -> Array[int]:
	var copie: Array[int] = []
	var liste: Array = valeur
	for item: Variant in liste:
		var entier: int = item
		copie.append(entier)
	return copie
