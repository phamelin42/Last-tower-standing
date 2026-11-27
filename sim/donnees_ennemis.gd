class_name DonneesEnnemis
extends RefCounted
## Validation de `data/ennemis.json` et construction des familles d'ennemis. Séparé de `Donnees`
## pour tenir sous la limite de taille d'un fichier ; les briques de validation (`_nombre`,
## `_identifiant`…) sont celles de `Donnees`.


## `ennemis.json` : soit entièrement vide (modèles, paliers, convoi et boss vides : dossier de
## test), soit complet. Une famille naît d'un modèle et d'un palier de couleur :
## `<modèle>_<palier>`.
static func valider(e: Dictionary, err: Array[String]) -> void:
	var f := "ennemis.json"
	var modeles_ok := Donnees._tableau(e, "modeles", f, "", err)
	var paliers_ok := Donnees._tableau(e, "paliers", f, "", err)
	var convoi_ok := Donnees._objet(e, "convoi", f, "", err)
	var boss_ok := Donnees._objet(e, "boss", f, "", err)
	if not (modeles_ok and paliers_ok and convoi_ok and boss_ok):
		return
	var modeles_bruts: Array = e["modeles"]
	var paliers_bruts: Array = e["paliers"]
	var convoi_brut: Dictionary = e["convoi"]
	var boss_brut: Dictionary = e["boss"]
	if (
		modeles_bruts.is_empty()
		and paliers_bruts.is_empty()
		and convoi_brut.is_empty()
		and boss_brut.is_empty()
	):
		return
	if modeles_bruts.is_empty():
		Donnees._err(err, f, "modeles", "au moins un modèle attendu")
	if paliers_bruts.is_empty():
		Donnees._err(err, f, "paliers", "au moins un palier attendu")
	var ids: Dictionary = {}
	var ids_paliers: Dictionary = {}
	var noms_vus: Dictionary = {}
	_valider_paliers(paliers_bruts, ids_paliers, err)
	for i in modeles_bruts.size():
		var ch := "modeles[%d]" % i
		var entree: Variant = modeles_bruts[i]
		if not entree is Dictionary:
			Donnees._err(err, f, ch, "attendu un objet, reçu %s" % Donnees._decrire(entree))
			continue
		_valider_modele(entree, ch, paliers_bruts.size(), ids, noms_vus, err)
		_valider_ids_derives(entree, paliers_bruts, ch, ids, err)
	Donnees._identifiant(convoi_brut, f, "convoi", err, ids)
	Donnees._texte(convoi_brut, "nom", f, "convoi", err)
	for spec: Dictionary in [Donnees._pos("pv"), Donnees._pos("vitesse"), Donnees._nn("prime")]:
		Donnees._nombre(convoi_brut, spec, f, "convoi", err)
	Donnees._identifiant(boss_brut, f, "boss", err, ids)
	Donnees._texte(boss_brut, "nom", f, "boss", err)
	var champs_boss := [
		Donnees._pos("pv"),
		Donnees._pos("vitesse"),
		Donnees._nn("degats"),
		Donnees._nn("portee_attaque"),
		Donnees._pos("cadence_attaque")
	]
	for spec: Dictionary in champs_boss:
		Donnees._nombre(boss_brut, spec, f, "boss", err)
	# Le boss attaque au contact (Phil, 27/11/2026) malgré sa portée de 80 : épines et riposte le
	# touchent. La classe vient des données, pas d'un seuil de portée.
	Donnees._nom_enum(boss_brut, "classe_portee", Types.NOMS_CLASSES_PORTEE, f, "boss", err)


## Paliers de couleur : identifiants uniques, `manche_entree` strictement croissante à partir de 1,
## multiplicateurs strictement positifs.
static func _valider_paliers(paliers: Array, ids_paliers: Dictionary, err: Array[String]) -> void:
	var f := "ennemis.json"
	var precedente := 0
	for i in paliers.size():
		var ch := "paliers[%d]" % i
		var entree: Variant = paliers[i]
		if not entree is Dictionary:
			Donnees._err(err, f, ch, "attendu un objet, reçu %s" % Donnees._decrire(entree))
			continue
		var p: Dictionary = entree
		Donnees._identifiant(p, f, ch, err, ids_paliers)
		for spec: Dictionary in [Donnees._pos("pv"), Donnees._pos("degats"), Donnees._pos("prime")]:
			Donnees._nombre(p, spec, f, ch, err)
		if not Donnees._nombre(p, Donnees._ent("manche_entree", 1.0), f, ch, err):
			continue
		var manche := int(p["manche_entree"])
		if i == 0 and manche != 1:
			Donnees._err(
				err, f, Donnees._sous(ch, "manche_entree"), "le premier palier entre à la manche 1"
			)
		elif i > 0 and manche <= precedente:
			var raison := "doit croître strictement (précédente : %d)" % precedente
			Donnees._err(err, f, Donnees._sous(ch, "manche_entree"), raison)
		precedente = manche


static func _valider_modele(
	m: Dictionary,
	ch: String,
	nb_paliers: int,
	ids: Dictionary,
	noms_vus: Dictionary,
	err: Array[String]
) -> void:
	var f := "ennemis.json"
	Donnees._identifiant(m, f, ch, err, ids)
	Donnees._nom_enum(m, "armure", Types.NOMS_ARMURES, f, ch, err)
	var classe := Donnees._nom_enum(m, "classe_portee", Types.NOMS_CLASSES_PORTEE, f, ch, err)
	for spec: Dictionary in [
		Donnees._pos("pv"),
		Donnees._pos("vitesse"),
		Donnees._nn("degats"),
		Donnees._pos("cadence_attaque"),
		Donnees._ent("prime", 0.0),
		Donnees._ent("manche_min", 1.0),
	]:
		Donnees._nombre(m, spec, f, ch, err)
	Donnees._booleen(m, "explose", f, ch, err)
	if not m.has("raison_lenteur") or not m["raison_lenteur"] is String:
		var recu := Donnees._decrire(m.get("raison_lenteur"))
		Donnees._err(
			err,
			f,
			Donnees._sous(ch, "raison_lenteur"),
			"texte attendu (éventuellement vide), reçu %s" % recu
		)
	# Noms : un par palier, tous distincts d'un bout à l'autre du fichier.
	if not m.has("noms") or not m["noms"] is Array:
		Donnees._err(
			err,
			f,
			Donnees._sous(ch, "noms"),
			"tableau attendu, reçu %s" % Donnees._decrire(m.get("noms"))
		)
	else:
		var noms: Array = m["noms"]
		if noms.size() != nb_paliers:
			var raison := "%d noms attendus (un par palier), reçu %d" % [nb_paliers, noms.size()]
			Donnees._err(err, f, Donnees._sous(ch, "noms"), raison)
		for k in noms.size():
			var nom: Variant = noms[k]
			var chn := "%s[%d]" % [Donnees._sous(ch, "noms"), k]
			if not nom is String or String(nom).is_empty():
				Donnees._err(err, f, chn, "texte non vide attendu, reçu %s" % Donnees._decrire(nom))
			elif noms_vus.has(nom):
				Donnees._err(err, f, chn, "nom dupliqué « %s » (déjà : %s)" % [nom, noms_vus[nom]])
			else:
				noms_vus[nom] = "%s %s" % [ch, Donnees._sous("noms", str(k))]
	# La classe de portée dit si l'ennemi attaque au contact (`Ennemis.PORTEE_CORPS_A_CORPS`) : la
	# portée d'attaque doit lui être cohérente, sinon il s'arrêterait au mauvais endroit.
	if Donnees._nombre(m, Donnees._nn("portee_attaque"), f, ch, err) and classe >= 0:
		var portee: float = float(m["portee_attaque"])
		var au_contact := portee <= Ennemis.PORTEE_CORPS_A_CORPS
		if (classe == Types.ClassePortee.CORPS_A_CORPS) != au_contact:
			var raison := (
				"incohérente avec la classe « %s » (corps à corps : au plus %s)"
				% [Types.NOMS_CLASSES_PORTEE[classe], Ennemis.PORTEE_CORPS_A_CORPS]
			)
			Donnees._err(err, f, Donnees._sous(ch, "portee_attaque"), raison)
		if m.get("explose") is bool and m["explose"] and classe != Types.ClassePortee.CORPS_A_CORPS:
			Donnees._err(
				err, f, Donnees._sous(ch, "explose"), "seul un corps à corps explose au contact"
			)


## `<modèle>_<palier>` ne doit entrer en collision avec aucun autre identifiant.
static func _valider_ids_derives(
	m: Variant, paliers: Array, ch: String, ids: Dictionary, err: Array[String]
) -> void:
	var modele: Dictionary = m
	if not modele.get("id") is String:
		return
	for entree: Variant in paliers:
		if not entree is Dictionary or not (entree as Dictionary).get("id") is String:
			continue
		var derive := "%s_%s" % [modele["id"], (entree as Dictionary)["id"]]
		if ids.has(derive):
			var raison := "identifiant « %s » déjà défini (%s)" % [derive, ids[derive]]
			Donnees._err(err, "ennemis.json", Donnees._sous(ch, "id"), raison)
		else:
			ids[derive] = "%s, famille dérivée" % ch


## Les familles d'ennemis : un modèle et un palier de couleur donnent une famille. L'ordre est
## figé (modèle puis palier : `index = nb_paliers × modèle + palier`), le réseau et les vues
## transportent cet index.
static func construire_familles(ennemis: Dictionary) -> Array[Dictionary]:
	var familles_construites: Array[Dictionary] = []
	var modeles: Array = ennemis["modeles"]
	var paliers: Array = ennemis["paliers"]
	for m_brut: Variant in modeles:
		var m: Dictionary = m_brut
		var noms: Array = m["noms"]
		for k in paliers.size():
			var p: Dictionary = paliers[k]
			(
				familles_construites
				. append(
					{
						"id": "%s_%s" % [m["id"], p["id"]],
						"modele": String(m["id"]),
						"palier": String(p["id"]),
						"indice_palier": k,
						"nom": String(noms[k]),
						"armure": Types.armure_depuis_nom(m["armure"]),
						"classe_portee": Types.classe_portee_depuis_nom(m["classe_portee"]),
						"pv": float(m["pv"]) * float(p["pv"]),
						"vitesse": float(m["vitesse"]),
						"degats": float(m["degats"]) * float(p["degats"]),
						"portee_attaque": float(m["portee_attaque"]),
						"cadence_attaque": float(m["cadence_attaque"]),
						"prime": roundi(float(m["prime"]) * float(p["prime"])),
						"manche_min": int(m["manche_min"]),
						"manche_entree": int(p["manche_entree"]),
						"explose": bool(m["explose"]),
					}
				)
			)
	return familles_construites
