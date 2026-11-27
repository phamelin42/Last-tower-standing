class_name DonneesAssets
extends RefCounted
## Validation de `data/assets.json` (T10.4) : tout ce qui est propre à une image ou à un son
## (chemin, taille de case, nombre d'images, régions, ancrages, échelle, durée) vit ici, pas dans
## le code.
## Remplacer un pack ne demande que de changer les fichiers et ces nombres. La simulation ne lit
## rien de ce fichier ; `visuels/assets.gd` le lit pour le rendu. Un fichier vide (dossier de test)
## est accepté.
##
## `FORME` décrit chaque section : une chaîne nomme un type de feuille, un objet décrit ses clés
## (`"*"` : toutes les clés ont la même forme), un tableau à un élément décrit une liste. Une clé
## précédée de `?` est facultative.

const MODELE: Dictionary = {
	"chemin": "texte",
	"case": "taille",
	"colonnes": "entier",
	"lignes": "entier",
	"repos": "ligne_images",
	"course": "ligne_images",
	"attaque": "ligne_images",
	"attaque_bas": "ligne_images",
	"attaque_haut": "ligne_images",
	"pieds": "nombre",
}
const ENTITE: Dictionary = {"modele": "texte", "couleur_pack": "chaine", "echelle": "positif"}
const ALLIE: Dictionary = {
	"modele": "texte", "couleur_pack": "chaine", "echelle": "positif", "teinte": "couleur"
}
const MORT: Dictionary = {
	"feuille": "texte",
	"case": "taille",
	"colonnes": "entier",
	"lignes": "entier",
	"images": "entier",
	"pieds": "nombre",
	"echelle": "positif",
	"images_par_seconde": "positif",
	"cle_boites": "texte",
}
const TYPE_DECOR: Dictionary = {
	"fichier": "texte",
	"cellule": "taille",
	"origine": "point",
	"ligne": "entier_nul",
	"images": "entier",
	"boite": "rect",
	"pieds": "point",
	"echelle": "positif",
	"categorie": "texte",
	"haut": "bool",
}
const TRANCHES: Dictionary = {
	"gauche": "entier_nul", "haut": "entier_nul", "droite": "entier_nul", "bas": "entier_nul"
}
const TIR_FLECHE: Dictionary = {"chemin": "texte", "region": "rect", "echelle": "positif"}
const TIR_BOMBE: Dictionary = {
	"chemin": "texte",
	"case": "taille",
	"images": "entier",
	"images_par_seconde": "positif",
	"region": "rect",
	"echelle": "positif",
	"arc": "nombre",
}
const PACK_FEU: Dictionary = {
	"chemin": "texte",
	"case": "taille",
	"images": "entier",
	"pieds": "nombre",
	"visible": "positif",
	"images_par_seconde": "positif",
	"echelle_boss": "positif",
}
const PACK_EXPLOSION: Dictionary = {
	"chemin": "texte", "case": "taille", "images": "entier", "visible": "positif"
}
const PACK_FLECHE: Dictionary = {"chemin": "texte", "region": "rect", "echelle": "positif"}
const PACK_DYNAMITE: Dictionary = {
	"chemin": "texte",
	"case": "taille",
	"images": "entier",
	"region": "rect",
	"echelle": "positif",
}
const PLANCHE_MAISON: Dictionary = {
	"case": "taille", "?visible": "positif", "?images_par_seconde": "positif"
}
const FORME: Dictionary = {
	"unites":
	{
		"images_par_seconde": "positif",
		"echelle": "positif",
		"modeles": {"*": MODELE},
		"entites": {"*": ENTITE},
		"allies": {"*": ALLIE},
		"anneau_allie": {"exterieur": "couleur", "interieur": "couleur", "contour": "couleur"},
		"mort": MORT,
	},
	"tour":
	{
		"echelle": "positif",
		"pieds": "nombre",
		"demi_largeur": "positif",
		"fichier_base": "texte",
		"teinte_base": "nombre",
		"couleurs_pack": [{"couleur": "texte", "teinte": "nombre"}],
		"teintes_calculees": ["nombre"],
	},
	"decor":
	{
		"images_par_seconde": "positif",
		"tuile": "entier",
		"case": "entier",
		"feuille_terrain": "texte",
		"feuille_eau": "texte",
		"ecume": {"feuille": "texte", "case": "entier", "images": "entier", "boite": "rect"},
		"types": {"*": TYPE_DECOR},
		"tuiles_herbe": {"*": "point"},
	},
	"signatures": {"taille": "entier", "bandeau": "taille"},
	"tirs_ennemis":
	{
		"plafond": "entier",
		"vol_s": "positif",
		"decalage_id_s": "positif",
		"marge_arret": "positif",
		"fleche": TIR_FLECHE,
		"bombe": TIR_BOMBE,
	},
	"ui":
	{
		"corps_ruban": "rect",
		"zone_icone": "rect",
		"pointeur_pointe": "point",
		"tranches": {"bouton": TRANCHES, "panneau": TRANCHES, "ruban": TRANCHES},
	},
	"effets":
	{
		"pack":
		{
			"feu": PACK_FEU,
			"explosion": PACK_EXPLOSION,
			"fleche": PACK_FLECHE,
			"dynamite": PACK_DYNAMITE,
		},
		"maison":
		{
			"dossier": "texte",
			"extension": "texte",
			"echelle": "positif",
			"communes": ["texte"],
			"planches": {"*": PLANCHE_MAISON},
			"elements": {"*": ["texte"]},
		},
	},
	"sons":
	{
		"dossier": "texte",
		"extension": "texte",
		"ids_armes": ["texte"],
		"suffixes_impact": ["texte"],
		"frequence_substitution": "entier",
	},
}


static func valider(a: Dictionary, err: Array[String]) -> void:
	if a.is_empty():
		return
	_objet(a, FORME, "", err)
	_liens(a, err)


## Les références entre sections : un modèle cité existe, une ligne et un nombre d'images tiennent
## dans la feuille décrite.
static func _liens(a: Dictionary, err: Array[String]) -> void:
	_liens_effets(a, err)
	_liens_decor(a, err)
	var unites: Variant = a.get("unites")
	if not unites is Dictionary:
		return
	var modeles: Variant = (unites as Dictionary).get("modeles")
	if not modeles is Dictionary:
		return
	for groupe: String in ["entites", "allies"]:
		var liste: Variant = (unites as Dictionary).get(groupe)
		if not liste is Dictionary:
			continue
		for id: Variant in liste:
			var entree: Variant = liste[id]
			if (
				entree is Dictionary
				and not (modeles as Dictionary).has((entree as Dictionary).get("modele"))
			):
				_err(err, "unites.%s.%s.modele" % [groupe, id], "modèle inconnu")
	for id: Variant in modeles:
		var m: Variant = modeles[id]
		if not m is Dictionary:
			continue
		var md: Dictionary = m
		var lignes: Variant = md.get("lignes")
		var colonnes: Variant = md.get("colonnes")
		if not (lignes is float or lignes is int) or not (colonnes is float or colonnes is int):
			continue
		for anim: String in ["repos", "course", "attaque", "attaque_bas", "attaque_haut"]:
			var r: Variant = md.get(anim)
			if not r is Dictionary:
				continue
			var rd: Dictionary = r
			var ligne: Variant = rd.get("ligne")
			if not (ligne is float or ligne is int):
				continue
			if float(ligne) >= float(lignes) or float(rd.get("images", 0)) > float(colonnes):
				_err(
					err,
					"unites.modeles.%s.%s" % [id, anim],
					"hors de la feuille (lignes, colonnes)"
				)


## Les planches nommées par les éléments d'attaque et les planches communes sont décrites ; une
## planche décrite sert à quelqu'un.
static func _liens_effets(a: Dictionary, err: Array[String]) -> void:
	var effets: Variant = a.get("effets")
	if not effets is Dictionary:
		return
	var maison: Variant = (effets as Dictionary).get("maison")
	if not maison is Dictionary:
		return
	var planches: Variant = (maison as Dictionary).get("planches")
	if not planches is Dictionary:
		return
	var citees: Dictionary = {}
	var communes: Variant = (maison as Dictionary).get("communes")
	if communes is Array:
		for nom: Variant in communes:
			citees[nom] = true
	var elements: Variant = (maison as Dictionary).get("elements")
	if elements is Dictionary:
		for id: Variant in elements:
			if not elements[id] is Array:
				continue
			for nom: Variant in elements[id]:
				citees[nom] = true
	for nom: Variant in citees:
		if not (planches as Dictionary).has(nom):
			_err(err, "effets.maison", "planche citée mais non décrite : %s" % nom)
	for nom: Variant in planches:
		if not citees.has(nom):
			_err(err, "effets.maison.planches.%s" % nom, "planche décrite mais citée par personne")


## Les seize combinaisons de voisines du terrain ont chacune leur tuile.
static func _liens_decor(a: Dictionary, err: Array[String]) -> void:
	var decor: Variant = a.get("decor")
	if not decor is Dictionary:
		return
	var tuiles: Variant = (decor as Dictionary).get("tuiles_herbe")
	if not tuiles is Dictionary:
		return
	for i: int in 16:
		var cle := "%d%d%d%d" % [(i >> 3) & 1, (i >> 2) & 1, (i >> 1) & 1, i & 1]
		if not (tuiles as Dictionary).has(cle):
			_err(err, "decor.tuiles_herbe.%s" % cle, "combinaison de voisines sans tuile")


static func _objet(v: Variant, forme: Dictionary, chemin: String, err: Array[String]) -> void:
	if not v is Dictionary:
		_err(err, chemin if chemin != "" else "racine", "objet attendu")
		return
	var d: Dictionary = v
	if forme.has("*"):
		for cle: Variant in d:
			_noeud(d[cle], forme["*"], _sous(chemin, str(cle)), err)
		return
	for cle: String in forme:
		var facultative: bool = cle.begins_with("?")
		var nom: String = cle.trim_prefix("?")
		if not d.has(nom):
			if not facultative:
				_err(err, _sous(chemin, nom), "clé manquante")
			continue
		_noeud(d[nom], forme[cle], _sous(chemin, nom), err)


static func _noeud(v: Variant, forme: Variant, chemin: String, err: Array[String]) -> void:
	if forme is Dictionary:
		_objet(v, forme, chemin, err)
	elif forme is Array:
		if not v is Array:
			_err(err, chemin, "tableau attendu")
			return
		var liste: Array = v
		if liste.is_empty():
			_err(err, chemin, "au moins un élément attendu")
		for i: int in liste.size():
			_noeud(liste[i], (forme as Array)[0], "%s[%d]" % [chemin, i], err)
	else:
		_feuille(v, String(forme), chemin, err)


static func _feuille(v: Variant, type: String, chemin: String, err: Array[String]) -> void:
	match type:
		"texte":
			if not v is String or String(v).is_empty():
				_err(err, chemin, "texte non vide attendu")
		"chaine":
			if not v is String:
				_err(err, chemin, "texte attendu (éventuellement vide)")
		"bool":
			if not v is bool:
				_err(err, chemin, "booléen attendu")
		"nombre":
			_nombre(v, chemin, err, -INF)
		"positif":
			_nombre(v, chemin, err, 0.0, true)
		"entier":
			_entier(v, chemin, err, 1)
		"entier_nul":
			_entier(v, chemin, err, 0)
		"point":
			_cles(v, ["x", "y"], chemin, err, -INF, false)
		"taille":
			_cles(v, ["largeur", "hauteur"], chemin, err, 0.0, true)
		"rect":
			_cles(v, ["x", "y"], chemin, err, -INF, false)
			_cles(v, ["largeur", "hauteur"], chemin, err, 0.0, true)
		"ligne_images":
			if _cles(v, ["ligne", "images"], chemin, err, 0.0, false):
				_entier((v as Dictionary)["ligne"], chemin + ".ligne", err, 0)
				_entier((v as Dictionary)["images"], chemin + ".images", err, 1)
		"couleur":
			if not v is Array or not ((v as Array).size() == 3 or (v as Array).size() == 4):
				_err(err, chemin, "3 ou 4 composantes attendues")
				return
			for i: int in (v as Array).size():
				_nombre((v as Array)[i], "%s[%d]" % [chemin, i], err, 0.0)
		_:
			_err(err, chemin, "forme inconnue « %s »" % type)


static func _nombre(
	v: Variant, chemin: String, err: Array[String], minimum: float, strict: bool = false
) -> bool:
	if not (v is float or v is int) or not is_finite(float(v)):
		_err(err, chemin, "nombre fini attendu")
		return false
	if float(v) < minimum or (strict and float(v) <= minimum):
		_err(err, chemin, "trop petit (%s)" % str(v))
		return false
	return true


static func _entier(v: Variant, chemin: String, err: Array[String], minimum: int) -> void:
	if not _nombre(v, chemin, err, float(minimum)):
		return
	if float(v) != floorf(float(v)):
		_err(err, chemin, "entier attendu")


## Les clés `noms` d'un objet, nombres finis au-dessus de `minimum` (strictement si `strict`).
static func _cles(
	v: Variant,
	noms: Array[String],
	chemin: String,
	err: Array[String],
	minimum: float,
	strict: bool
) -> bool:
	if not v is Dictionary:
		_err(err, chemin, "objet attendu")
		return false
	var ok := true
	for nom: String in noms:
		if not (v as Dictionary).has(nom):
			_err(err, _sous(chemin, nom), "clé manquante")
			ok = false
		elif not _nombre((v as Dictionary)[nom], _sous(chemin, nom), err, minimum, strict):
			ok = false
	return ok


static func _sous(chemin: String, cle: String) -> String:
	return cle if chemin == "" else "%s.%s" % [chemin, cle]


static func _err(err: Array[String], chemin: String, raison: String) -> void:
	err.append("assets.json: %s: %s" % [chemin, raison])
