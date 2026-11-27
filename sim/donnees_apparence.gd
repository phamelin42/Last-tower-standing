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
## Les superpositions sont dessinées pour la tour par défaut : l'échelle d'un skin (2 au plus).
const ECHELLE_SKIN_MAX := 2.0
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


## Skins de la tour (`data/skins_tour.json`, B5 à B8) : id → `{sprite, cadre?, echelle, defi,
## marque, licence, source, ancrages}`. Un skin donne le sprite de la tour (`cadre` : la partie
## de l'image utilisée, pour une feuille), l'échelle des superpositions (1 pour la tour par
## défaut), le défi qui le débloque (vide pour `defaut`), la zone de marque de la couleur du
## joueur, sa licence et, pour chaque superposition, le point (en pixels du cadre) où son centre
## se pose. Un fichier non vide contient au moins le skin `defaut`.
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
		_valider_identite_skin(skin, chemin, err)
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


## Défi, échelle, cadre, marque, licence et source d'un skin (T11.6), hors sprite et ancrages.
static func _valider_identite_skin(skin: Dictionary, chemin: String, err: Array[String]) -> void:
	var f := "skins_tour.json"
	if not skin.get("defi") is String:
		Donnees._err(err, f, "%s.defi" % chemin, "identifiant de défi attendu (vide pour defaut)")
	elif String(skin["defi"]).is_empty() != (chemin == "defaut"):
		Donnees._err(err, f, "%s.defi" % chemin, "vide pour defaut seulement")
	for champ: String in ["licence", "source"]:
		if not skin.get(champ) is String or String(skin[champ]).is_empty():
			Donnees._err(err, f, "%s.%s" % [chemin, champ], "texte attendu")
	var echelle: Variant = skin.get("echelle")
	if not (echelle is float or echelle is int) or not is_finite(float(echelle)):
		Donnees._err(err, f, "%s.echelle" % chemin, "nombre fini attendu")
	elif float(echelle) <= 0.0 or float(echelle) > ECHELLE_SKIN_MAX:
		Donnees._err(err, f, "%s.echelle" % chemin, "entre 0 (exclu) et %s" % ECHELLE_SKIN_MAX)
	if skin.has("cadre"):
		_valider_rectangle(skin["cadre"], "%s.cadre" % chemin, err)
	if not skin.get("marque") is Dictionary:
		Donnees._err(err, f, "%s.marque" % chemin, "objet attendu")
		return
	var marque: Dictionary = skin["marque"]
	if not marque.get("genre") in ["origine", "fanion"]:
		Donnees._err(err, f, "%s.marque.genre" % chemin, "« origine » ou « fanion » attendu")
	_valider_rectangle(marque, "%s.marque" % chemin, err)


## Un rectangle {x, y, largeur, hauteur} d'entiers : position positive ou nulle, taille non nulle.
static func _valider_rectangle(rect: Variant, chemin: String, err: Array[String]) -> void:
	if not rect is Dictionary:
		Donnees._err(err, "skins_tour.json", chemin, "objet attendu")
		return
	var r: Dictionary = rect
	for cle: String in ["x", "y", "largeur", "hauteur"]:
		var v: Variant = r.get(cle)
		if not (v is int or (v is float and v == floorf(v))):
			Donnees._err(err, "skins_tour.json", "%s.%s" % [chemin, cle], "entier attendu")
		elif int(v) < 0 or (cle in ["largeur", "hauteur"] and int(v) == 0):
			Donnees._err(err, "skins_tour.json", "%s.%s" % [chemin, cle], "valeur hors bornes")
