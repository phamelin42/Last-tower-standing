class_name DonneesApparence
extends RefCounted
## Validation de `data/apparence_tour.json` (D19) : pour chacune des sept statistiques qui se voient
## sur la tour, trois seuils strictement croissants, et l'agrandissement de chaque palier de PV
## maximum. La simulation ne lit que ces nombres, jamais une image : l'apparence est locale.

const STATS: Array[String] = [
	"epines", "pv_max", "mana", "armure", "esquive", "regen", "vol_de_vie"
]
## Celles qui ont une image : la tour qui grandit (`pv_max`) n'a qu'un facteur.
const SUPERPOSITIONS: Array[String] = ["epines", "mana", "armure", "esquive", "regen", "vol_de_vie"]
const PALIERS := 3
## Agrandissement maximal de la tour (purement visuel, A3).
const AGRANDISSEMENT_MAX := 0.25


## Un fichier vide (dossier de test) est accepté : il n'y a alors aucune apparence.
static func valider(t: Dictionary, err: Array[String]) -> void:
	var f := "apparence_tour.json"
	if t.is_empty():
		return
	var stats_ok := Donnees._objet(t, "stats", f, "", err)
	var agrandissement_ok := Donnees._tableau(t, "agrandissement", f, "", err)
	if stats_ok:
		var stats: Dictionary = t["stats"]
		for nom: Variant in stats:
			if not nom is String or not STATS.has(nom):
				Donnees._err(err, f, "stats", "statistique inconnue : %s" % str(nom))
		for nom: String in STATS:
			if not stats.has(nom):
				Donnees._err(err, f, "stats.%s" % nom, "statistique manquante")
				continue
			_valider_liste(stats[nom], "stats.%s" % nom, -1.0, err)
	if agrandissement_ok:
		_valider_liste(t["agrandissement"], "agrandissement", AGRANDISSEMENT_MAX, err)


## `maximum` : borne haute des valeurs (négatif : aucune). Trois nombres finis, positifs,
## strictement croissants.
static func _valider_liste(v: Variant, chemin: String, maximum: float, err: Array[String]) -> void:
	var f := "apparence_tour.json"
	if not v is Array:
		Donnees._err(err, f, chemin, "attendu un tableau, reçu %s" % Donnees._decrire(v))
		return
	var liste: Array = v
	if liste.size() != PALIERS:
		Donnees._err(err, f, chemin, "%d valeurs attendues, reçu %d" % [PALIERS, liste.size()])
		return
	var precedent := 0.0
	for i: int in PALIERS:
		var x: Variant = liste[i]
		var ch := "%s[%d]" % [chemin, i]
		if not (x is float or x is int):
			Donnees._err(err, f, ch, "attendu un nombre, reçu %s" % Donnees._decrire(x))
			return
		var n := float(x)
		if not is_finite(n) or n <= 0.0:
			Donnees._err(err, f, ch, "un nombre fini strictement positif est attendu")
			return
		if n <= precedent:
			Donnees._err(err, f, ch, "les valeurs doivent être strictement croissantes")
			return
		if maximum > 0.0 and n > maximum:
			Donnees._err(err, f, ch, "au plus %s" % maximum)
			return
		precedent = n


## Copie profonde, en flottants, pour `Donnees.apparence_tour`.
static func normaliser(t: Dictionary) -> Dictionary:
	if t.is_empty():
		return {"stats": {}, "agrandissement": []}
	var stats: Dictionary = {}
	var brutes: Dictionary = t["stats"]
	for nom: String in brutes:
		stats[nom] = _en_flottants(brutes[nom])
	return {"stats": stats, "agrandissement": _en_flottants(t["agrandissement"])}


static func _en_flottants(liste: Array) -> Array[float]:
	var sortie: Array[float] = []
	for x: Variant in liste:
		sortie.append(float(x))
	return sortie


## Skins de la tour (`data/skins_tour.json`, B7) : id → `{sprite, ancrages}`. Un skin donne le
## sprite de la tour et, pour chaque superposition, le point (en pixels du sprite) où son centre se
## pose. Un fichier non vide contient au moins le skin `defaut`.
static func valider_skins(skins: Dictionary, err: Array[String]) -> void:
	var f := "skins_tour.json"
	if skins.is_empty():
		return
	if not skins.has("defaut"):
		Donnees._err(err, f, "defaut", "le skin par défaut est obligatoire")
	for id: Variant in skins:
		var chemin := str(id)
		if not skins[id] is Dictionary:
			Donnees._err(err, f, chemin, "attendu un objet, reçu %s" % Donnees._decrire(skins[id]))
			continue
		var skin: Dictionary = skins[id]
		if not skin.get("sprite") is String or String(skin["sprite"]).is_empty():
			Donnees._err(err, f, "%s.sprite" % chemin, "chemin d'image attendu")
		if not skin.get("ancrages") is Dictionary:
			Donnees._err(err, f, "%s.ancrages" % chemin, "objet attendu")
			continue
		var ancrages: Dictionary = skin["ancrages"]
		for stat: String in SUPERPOSITIONS:
			var ch := "%s.ancrages.%s" % [chemin, stat]
			if not ancrages.get(stat) is Dictionary:
				Donnees._err(err, f, ch, "ancrage manquant")
				continue
			var a: Dictionary = ancrages[stat]
			for axe: String in ["x", "y"]:
				var v: Variant = a.get(axe)
				if not (v is float or v is int) or not is_finite(float(v)):
					Donnees._err(err, f, "%s.%s" % [ch, axe], "nombre fini attendu")
