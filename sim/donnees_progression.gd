class_name DonneesProgression
extends RefCounted
## Validation et lecture de `data/defis.json` (lot 11) : la liste des défis, leur condition sur les
## compteurs du bilan de partie et des cumuls, et le skin que chacun débloque. Sortie de `Donnees`
## pour qu'il tienne sous la limite de lignes de gdlint. Un défi est cosmétique : le fichier n'entre
## pas dans l'empreinte de poignée de main réseau.

## Les compteurs que le profil porte en plus du bilan de la partie (`Profil`, `docs/defis.md` §3).
## Un test garde cette liste égale à celle de `Profil`.
const COMPTEURS_PROFIL: Array[String] = [
	"parties",
	"cumul_victoires",
	"cumul_eliminations",
	"cumul_or_gagne",
	"cumul_manches",
	"cumul_parties_multijoueur",
	"cumul_dernier_rempart",
]
const MODES: Array[String] = ["les_deux", "multijoueur"]
const OPERATEURS: Array[String] = ["≤", "≥", "=", ">", "<"]
const SEPARATEUR := " et "
const LONGUEUR_MAX := 200


## Tous les compteurs qu'une condition peut citer.
static func compteurs_connus() -> Dictionary:
	var connus: Dictionary = {}
	for nom: String in BilanPartie.noms():
		connus[nom] = true
	for nom: String in COMPTEURS_PROFIL:
		connus[nom] = true
	return connus


## Une condition « compteur op nombre » ou « compteur op compteur », liées par « et », en liste de
## termes `{compteur, op, valeur}` ou `{compteur, op, autre}`. Liste vide si le texte est invalide.
static func analyser_condition(texte: String) -> Array[Dictionary]:
	var termes: Array[Dictionary] = []
	if texte.is_empty() or texte.length() > LONGUEUR_MAX:
		return termes
	for morceau: String in texte.split(SEPARATEUR):
		var mots := morceau.strip_edges().split(" ", false)
		if mots.size() != 3 or not OPERATEURS.has(mots[1]) or not _est_nom(mots[0]):
			return []
		var terme: Dictionary = {"compteur": mots[0], "op": mots[1]}
		if _est_nom(mots[2]):
			terme["autre"] = mots[2]
		elif mots[2].is_valid_float():
			terme["valeur"] = mots[2].to_float()
		else:
			return []
		termes.append(terme)
	return termes


## Vrai si tous les termes tiennent pour `valeurs` (nom → nombre ; un compteur absent vaut 0).
static func condition_tenue(termes: Array[Dictionary], valeurs: Dictionary) -> bool:
	if termes.is_empty():
		return false
	for terme: Dictionary in termes:
		var gauche := _valeur(valeurs, String(terme["compteur"]))
		var droite: float = float(terme["valeur"]) if terme.has("valeur") else 0.0
		if terme.has("autre"):
			droite = _valeur(valeurs, String(terme["autre"]))
		var ok := false
		match String(terme["op"]):
			"≤":
				ok = gauche <= droite
			"≥":
				ok = gauche >= droite
			"=":
				ok = is_equal_approx(gauche, droite)
			">":
				ok = gauche > droite
			"<":
				ok = gauche < droite
		if not ok:
			return false
	return true


static func valider(liste: Array, err: Array[String]) -> void:
	var f := "defis.json"
	var ids: Dictionary = {}
	var skins: Dictionary = {}
	var connus := compteurs_connus()
	for i: int in liste.size():
		var ch := "[%d]" % i
		if not liste[i] is Dictionary:
			Donnees._err(err, f, ch, "attendu un objet")
			continue
		var d: Dictionary = liste[i]
		for cle: String in ["id", "nom", "texte", "condition", "skin"]:
			Donnees._texte(d, cle, f, ch, err)
		if d.has("id") and d["id"] is String:
			if ids.has(d["id"]):
				Donnees._err(err, f, ch + ".id", "doublon « %s »" % d["id"])
			ids[d["id"]] = true
		if d.get("skin") is String:
			if skins.has(d["skin"]):
				Donnees._err(err, f, ch + ".skin", "skin déjà pris par un autre défi")
			skins[d["skin"]] = true
		if not d.get("mode") is String or not MODES.has(d["mode"]):
			Donnees._err(err, f, ch + ".mode", "attendu un de %s" % str(MODES))
		if d.get("condition") is String:
			_valider_condition(d["condition"], connus, f, ch + ".condition", err)


static func _valider_condition(
	texte: String, connus: Dictionary, f: String, ch: String, err: Array[String]
) -> void:
	var termes := analyser_condition(texte)
	if termes.is_empty():
		Donnees._err(err, f, ch, "condition vide ou mal formée « %s »" % texte)
		return
	for terme: Dictionary in termes:
		for cle: String in ["compteur", "autre"]:
			if terme.has(cle) and not connus.has(terme[cle]):
				Donnees._err(err, f, ch, "compteur inconnu « %s »" % terme[cle])


## id → {id, nom, texte, condition (texte), termes, skin, mode}, dans l'ordre du fichier.
static func normaliser(liste: Array) -> Dictionary:
	var sortie: Dictionary = {}
	for entree: Variant in liste:
		var d: Dictionary = entree
		var condition := String(d["condition"])
		sortie[String(d["id"])] = {
			"id": String(d["id"]),
			"nom": String(d["nom"]),
			"texte": String(d["texte"]),
			"condition": condition,
			"termes": analyser_condition(condition),
			"skin": String(d["skin"]),
			"mode": String(d["mode"]),
		}
	return sortie


static func _valeur(valeurs: Dictionary, nom: String) -> float:
	var v: Variant = valeurs.get(nom)
	return float(v) if v is float or v is int else 0.0


static func _est_nom(mot: String) -> bool:
	if mot.is_empty():
		return false
	var premier := mot.unicode_at(0)
	return premier >= 97 and premier <= 122
