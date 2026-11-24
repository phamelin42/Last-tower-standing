class_name VueArene
extends RefCounted
## Vue d'arène : le seul état que lisent `visuels/` et `ui/`. Elle se sérialise en
## dictionnaire pour le réseau. `from_dict` ne lève jamais d'exception : une donnée
## invalide donne `null`, et la vue ne partage aucune mémoire avec la source.

## Types attendus de chaque champ de premier niveau. Un entier et un flottant sont
## distincts : une valeur entière pour un champ `float` est refusée, et inversement.
const SCHEMA: Dictionary = {
	"tick": TYPE_INT,
	"manche": TYPE_INT,
	"phase": TYPE_INT,
	"temps_restant": TYPE_FLOAT,
	"prochaine_famille": TYPE_INT,
	"prochaine_armure": TYPE_INT,
	"sans_fin": TYPE_BOOL,
	"tour_pv": TYPE_FLOAT,
	"tour_pv_max": TYPE_FLOAT,
	"tour_armure": TYPE_FLOAT,
	"argent": TYPE_INT,
	"revenu": TYPE_INT,
	"revenu_dans": TYPE_FLOAT,
	"cout_relance": TYPE_INT,
	"relances_gratuites": TYPE_INT,
	"offres": TYPE_ARRAY,
	"armes": TYPE_ARRAY,
	"ameliorations": TYPE_DICTIONARY,
	"marche_noir_ouvert": TYPE_BOOL,
	"ennemis_id": TYPE_PACKED_INT32_ARRAY,
	"ennemis_pos": TYPE_PACKED_VECTOR2_ARRAY,
	"ennemis_famille": TYPE_PACKED_BYTE_ARRAY,
	"ennemis_pv": TYPE_PACKED_BYTE_ARRAY,
	"ennemis_statuts": TYPE_PACKED_BYTE_ARRAY,
	"evenements": TYPE_ARRAY,
	"eliminations": TYPE_INT,
	"degats_infliges": TYPE_FLOAT,
	"manche_max": TYPE_INT,
}

const SCHEMA_OFFRE: Dictionary = {
	"id": TYPE_STRING,
	"genre": TYPE_INT,
	"rarete": TYPE_INT,
	"prix": TYPE_INT,
	"vendu": TYPE_BOOL,
}

const SCHEMA_ARME: Dictionary = {
	"id": TYPE_STRING,
	"recharge_ratio": TYPE_FLOAT,
}

const SCHEMA_EVENEMENT: Dictionary = {
	"k": TYPE_STRING,
	"t": TYPE_INT,
	"de": TYPE_VECTOR2,
	"vers": TYPE_VECTOR2,
	"type_degats": TYPE_INT,
	"rayon": TYPE_FLOAT,
}

var tick: int = 0
var manche: int = 0
var phase: int = 0
var temps_restant: float = 0.0
var prochaine_famille: int = -1
var prochaine_armure: int = 0
var sans_fin: bool = false
var tour_pv: float = 0.0
var tour_pv_max: float = 0.0
var tour_armure: float = 0.0
var argent: int = 0
var revenu: int = 0
var revenu_dans: float = 0.0
var cout_relance: int = 0
var relances_gratuites: int = 0
var offres: Array[Dictionary] = []
var armes: Array[Dictionary] = []
var ameliorations: Dictionary = {}
var marche_noir_ouvert: bool = false
var ennemis_id: PackedInt32Array = PackedInt32Array()
var ennemis_pos: PackedVector2Array = PackedVector2Array()
var ennemis_famille: PackedByteArray = PackedByteArray()
var ennemis_pv: PackedByteArray = PackedByteArray()
var ennemis_statuts: PackedByteArray = PackedByteArray()
var evenements: Array[Dictionary] = []
var eliminations: int = 0
var degats_infliges: float = 0.0
var manche_max: int = 0


func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"manche": manche,
		"phase": phase,
		"temps_restant": temps_restant,
		"prochaine_famille": prochaine_famille,
		"prochaine_armure": prochaine_armure,
		"sans_fin": sans_fin,
		"tour_pv": tour_pv,
		"tour_pv_max": tour_pv_max,
		"tour_armure": tour_armure,
		"argent": argent,
		"revenu": revenu,
		"revenu_dans": revenu_dans,
		"cout_relance": cout_relance,
		"relances_gratuites": relances_gratuites,
		"offres": offres.duplicate(true),
		"armes": armes.duplicate(true),
		"ameliorations": ameliorations.duplicate(true),
		"marche_noir_ouvert": marche_noir_ouvert,
		"ennemis_id": ennemis_id.duplicate(),
		"ennemis_pos": ennemis_pos.duplicate(),
		"ennemis_famille": ennemis_famille.duplicate(),
		"ennemis_pv": ennemis_pv.duplicate(),
		"ennemis_statuts": ennemis_statuts.duplicate(),
		"evenements": evenements.duplicate(true),
		"eliminations": eliminations,
		"degats_infliges": degats_infliges,
		"manche_max": manche_max,
	}


static func from_dict(d: Dictionary) -> VueArene:
	if not _valide(d):
		return null
	var vue := VueArene.new()
	vue.tick = d["tick"]
	vue.manche = d["manche"]
	vue.phase = d["phase"]
	vue.temps_restant = d["temps_restant"]
	vue.prochaine_famille = d["prochaine_famille"]
	vue.prochaine_armure = d["prochaine_armure"]
	vue.sans_fin = d["sans_fin"]
	vue.tour_pv = d["tour_pv"]
	vue.tour_pv_max = d["tour_pv_max"]
	vue.tour_armure = d["tour_armure"]
	vue.argent = d["argent"]
	vue.revenu = d["revenu"]
	vue.revenu_dans = d["revenu_dans"]
	vue.cout_relance = d["cout_relance"]
	vue.relances_gratuites = d["relances_gratuites"]
	vue.offres = _copie_dicts(d["offres"])
	vue.armes = _copie_dicts(d["armes"])
	var ameliorations: Dictionary = d["ameliorations"]
	vue.ameliorations = ameliorations.duplicate(true)
	vue.marche_noir_ouvert = d["marche_noir_ouvert"]
	var ids: PackedInt32Array = d["ennemis_id"]
	vue.ennemis_id = ids.duplicate()
	var positions: PackedVector2Array = d["ennemis_pos"]
	vue.ennemis_pos = positions.duplicate()
	var familles: PackedByteArray = d["ennemis_famille"]
	vue.ennemis_famille = familles.duplicate()
	var pvs: PackedByteArray = d["ennemis_pv"]
	vue.ennemis_pv = pvs.duplicate()
	var statuts: PackedByteArray = d["ennemis_statuts"]
	vue.ennemis_statuts = statuts.duplicate()
	vue.evenements = _copie_dicts(d["evenements"])
	vue.eliminations = d["eliminations"]
	vue.degats_infliges = d["degats_infliges"]
	vue.manche_max = d["manche_max"]
	return vue


## Vrai si la donnée respecte les types et la cohérence des tableaux d'ennemis. Ne lève
## jamais d'exception, quelle que soit la forme du dictionnaire.
static func _valide(d: Dictionary) -> bool:
	if not _conforme(d, SCHEMA):
		return false
	if not _liste_conforme(d["offres"], SCHEMA_OFFRE):
		return false
	if not _liste_conforme(d["armes"], SCHEMA_ARME):
		return false
	if not _liste_conforme(d["evenements"], SCHEMA_EVENEMENT):
		return false
	if not _ameliorations_valides(d["ameliorations"]):
		return false
	var ids: PackedInt32Array = d["ennemis_id"]
	var nombre: int = ids.size()
	var positions: PackedVector2Array = d["ennemis_pos"]
	var familles: PackedByteArray = d["ennemis_famille"]
	var pvs: PackedByteArray = d["ennemis_pv"]
	var statuts: PackedByteArray = d["ennemis_statuts"]
	return (
		positions.size() == nombre
		and familles.size() == nombre
		and pvs.size() == nombre
		and statuts.size() == nombre
	)


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


static func _ameliorations_valides(valeur: Variant) -> bool:
	if typeof(valeur) != TYPE_DICTIONARY:
		return false
	var dico: Dictionary = valeur
	for cle: Variant in dico:
		if typeof(cle) != TYPE_STRING or typeof(dico[cle]) != TYPE_INT:
			return false
	return true


## Copie profonde d'une liste de dictionnaires, déjà validée.
static func _copie_dicts(valeur: Variant) -> Array[Dictionary]:
	var copie: Array[Dictionary] = []
	var liste: Array = valeur
	for item: Variant in liste:
		var entree: Dictionary = item
		copie.append(entree.duplicate(true))
	return copie
