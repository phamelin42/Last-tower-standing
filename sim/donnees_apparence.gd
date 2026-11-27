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
## Filtres de texture d'un skin : `nearest` (pixel net, le défaut) ou `lineaire` (image lissée).
const FILTRES_SKIN: Array[String] = ["nearest", "lineaire"]
const PALIERS := 3
## Agrandissement maximal de la tour (purement visuel, A3).
const AGRANDISSEMENT_MAX := 0.25
## Aucun éclair au-dessus de trois par seconde : une période d'au moins un tiers de seconde, au plus
## trois images d'animation par seconde.
const MIN_PERIODE_S := 1.0 / 3.0
const MAX_PAR_SECONDE := 3.0
const IMAGES_ANIMEES_MAX := 8


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
	_valider_dessin(t, err)


## Ce dont le dessin a besoin (T9.25) : dossier des images, durée du fondu, rythme de l'esquive et
## de l'animation. Aucun éclair au-dessus de trois par seconde : les périodes sont bornées.
static func _valider_dessin(t: Dictionary, err: Array[String]) -> void:
	var f := "apparence_tour.json"
	var dossier: Variant = t.get("dossier")
	if not dossier is String or not String(dossier).ends_with("/"):
		Donnees._err(err, f, "dossier", "chemin de dossier terminé par « / » attendu")
	var fanion: Variant = t.get("fanion")
	if not fanion is String or String(fanion).get_extension() != "png":
		Donnees._err(err, f, "fanion", "nom d'un fichier .png du dossier attendu")
	var fondu := _nombre(t, "fondu_s", 0.05, 2.0, err)
	if (
		not Donnees._objet(t, "esquive", f, "", err)
		or not Donnees._objet(t, "animation", f, "", err)
	):
		return
	var esquive: Dictionary = t["esquive"]
	var periode := _nombre(esquive, "periode_s", MIN_PERIODE_S, 60.0, err, "esquive.")
	var duree := _nombre(esquive, "duree_s", 0.05, 60.0, err, "esquive.")
	if is_finite(periode) and is_finite(duree) and duree >= periode:
		Donnees._err(err, f, "esquive.duree_s", "inférieure à la période attendue")
	var animation: Dictionary = t["animation"]
	var images: Variant = animation.get("images")
	var entier := (images is float or images is int) and float(images) == floorf(float(images))
	if not entier or float(images) < 1.0 or float(images) > IMAGES_ANIMEES_MAX:
		Donnees._err(err, f, "animation.images", "entier de 1 à %d attendu" % IMAGES_ANIMEES_MAX)
	_nombre(animation, "par_seconde", 0.05, MAX_PAR_SECONDE, err, "animation.")
	if not is_finite(fondu):
		return


## Un nombre fini de `bas` à `haut` (bornes comprises) ; `NAN` (et une erreur) sinon.
static func _nombre(
	d: Dictionary, cle: String, bas: float, haut: float, err: Array[String], prefixe: String = ""
) -> float:
	var v: Variant = d.get(cle)
	if not (v is float or v is int) or not is_finite(float(v)):
		Donnees._err(err, "apparence_tour.json", prefixe + cle, "nombre fini attendu")
		return NAN
	var x := float(v)
	if x < bas or x > haut:
		Donnees._err(err, "apparence_tour.json", prefixe + cle, "de %s à %s attendu" % [bas, haut])
		return NAN
	return x


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
		return {
			"stats": {},
			"agrandissement": [],
			"dossier": "",
			"fanion": "",
			"fondu_s": 0.3,
			"esquive": {},
			"animation": {}
		}
	var stats: Dictionary = {}
	var brutes: Dictionary = t["stats"]
	for nom: String in brutes:
		stats[nom] = _en_flottants(brutes[nom])
	var sortie: Dictionary = {"stats": stats, "agrandissement": _en_flottants(t["agrandissement"])}
	for cle: String in ["dossier", "fanion", "fondu_s", "esquive", "animation"]:
		sortie[cle] = (
			(t[cle] as Variant)
			if not t[cle] is Dictionary
			else (t[cle] as Dictionary).duplicate(true)
		)
	return sortie


static func _en_flottants(liste: Array) -> Array[float]:
	var sortie: Array[float] = []
	for x: Variant in liste:
		sortie.append(float(x))
	return sortie


## Skins de la tour (`data/skins_tour.json`, B5 à B8) : id → `{sprite, cadre?, echelle, defi,
## marque, licence, source, ancrages, filtre?}`. Un skin donne le sprite de la tour (`cadre` : la
## partie de l'image utilisée, pour une feuille), l'échelle des superpositions (1 pour la tour par
## défaut), le défi qui le débloque (vide pour `defaut`), la zone de marque de la couleur du
## joueur, sa licence et, pour chaque superposition, le point (en pixels du cadre) où son centre
## se pose ; `filtre` (`nearest` par défaut, ou `lineaire`) règle le lissage de l'image.
## Un fichier non vide contient au moins le skin `defaut`.
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
	if skin.has("filtre") and not (skin["filtre"] is String and skin["filtre"] in FILTRES_SKIN):
		Donnees._err(err, f, "%s.filtre" % chemin, "« nearest » ou « lineaire » attendu")
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
