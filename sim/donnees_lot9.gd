class_name DonneesLot9
extends RefCounted
## Validation et normalisation des données du lot 9 (unités, plafonds de `partie.json`, champs
## facultatifs d'arme, stats d'amélioration à paramètres) : sorties de `Donnees` pour qu'il tienne
## sous la limite de lignes de gdlint.


static func valider_partie_lot9(p: Dictionary, err: Array[String]) -> void:
	var f := "partie.json"
	if Donnees._objet(p, "vulnerabilite", f, "", err):
		var v: Dictionary = p["vulnerabilite"]
		Donnees._nombre(v, Donnees._spec("plafond", 0.0, true, 5.0), f, "vulnerabilite", err)
		Donnees._nombre(v, Donnees._pos("duree_max"), f, "vulnerabilite", err)
	if Donnees._objet(p, "malediction", f, "", err):
		var m: Dictionary = p["malediction"]
		Donnees._nombre(m, Donnees._spec("plafond", 0.0, true, 1.0), f, "malediction", err)
	if Donnees._objet(p, "repoussement", f, "", err):
		var r: Dictionary = p["repoussement"]
		Donnees._nombre(r, Donnees._pos("distance_max"), f, "repoussement", err)
		Donnees._nombre(r, Donnees._ratio("facteur_boss"), f, "repoussement", err)
	if Donnees._objet(p, "limites", f, "", err):
		var l: Dictionary = p["limites"]
		for nom: String in ["allies", "zones", "bombes"]:
			Donnees._nombre(l, Donnees._ent(nom, 1.0), f, "limites", err)
	if Donnees._objet(p, "armes", f, "", err):
		var a: Dictionary = p["armes"]
		Donnees._nombre(a, Donnees._pos("bonus_selon_stat_max"), f, "armes", err)
	if Donnees._objet(p, "ameliorations", f, "", err):
		var am: Dictionary = p["ameliorations"]
		Donnees._nombre(am, Donnees._spec("facteur_degats_max", 1.0), f, "ameliorations", err)
		Donnees._nombre(am, Donnees._pos("croissance_pas_s"), f, "ameliorations", err)


## Les champs non numériques des effets et statuts du lot 9.
static func valider_champs_texte(
	kind: String, e: Dictionary, f: String, ch: String, err: Array[String], unites: Dictionary
) -> void:
	match kind:
		"tournant":
			Donnees._nom_enum(e, "sens", Donnees.SENS_TOURNANT, f, ch, err)
		"siphon":
			Donnees._nom_enum(e, "ressource", Donnees.RESSOURCES_SIPHON, f, ch, err)
		"vulnerabilite":
			if e.has("type_degats"):
				Donnees._nom_enum(e, "type_degats", Types.NOMS_TYPES, f, ch, err)
		"invocation":
			if not Donnees._texte(e, "unite", f, ch, err):
				return
			if not unites.has(e["unite"]):
				Donnees._err(
					err,
					f,
					Donnees._sous(ch, "unite"),
					"unité inconnue « %s » (unites.json)" % e["unite"]
				)


static func valider_degats_par_amelioration(
	v: Variant, f: String, ch: String, err: Array[String]
) -> void:
	var chemin := Donnees._sous(ch, "degats_par_amelioration")
	if not v is Dictionary:
		Donnees._err(err, f, chemin, "attendu un objet, reçu %s" % Donnees._decrire(v))
		return
	var d: Dictionary = v
	Donnees._nombre(d, Donnees._nn("ratio"), f, chemin, err)
	if not d.has("stat") or not d["stat"] is String:
		Donnees._err(
			err,
			f,
			Donnees._sous(chemin, "stat"),
			"texte attendu, reçu %s" % Donnees._decrire(d.get("stat"))
		)
	elif not d["stat"] in Donnees.STATS_AMELIORATION:
		Donnees._err(
			err, f, Donnees._sous(chemin, "stat"), "stat d’amélioration inconnue « %s »" % d["stat"]
		)


static func valider_unites(liste: Array, ids: Dictionary, err: Array[String]) -> void:
	var f := "unites.json"
	for i in liste.size():
		var ch := "[%d]" % i
		var entree: Variant = liste[i]
		if not entree is Dictionary:
			Donnees._err(err, f, ch, "attendu un objet, reçu %s" % Donnees._decrire(entree))
			continue
		var u: Dictionary = entree
		Donnees._identifiant(u, f, ch, err, ids)
		Donnees._texte(u, "nom", f, ch, err)
		Donnees._nom_enum(u, "modele", Donnees.MODELES_UNITES, f, ch, err)
		for nom: String in ["vitesse", "portee", "cadence", "rayon_garde"]:
			Donnees._nombre(u, Donnees._pos(nom), f, ch, err)


static func normaliser_unite(v: Variant) -> Dictionary:
	var u: Dictionary = v
	return {
		"id": u["id"],
		"nom": u["nom"],
		"modele": u["modele"],
		"vitesse": float(u["vitesse"]),
		"portee": float(u["portee"]),
		"cadence": float(u["cadence"]),
		"rayon_garde": float(u["rayon_garde"]),
	}


static func normaliser_par_amelioration(arme: Dictionary) -> Dictionary:
	if not arme.has("degats_par_amelioration"):
		return {"stat": "", "ratio": 0.0}
	var brut: Dictionary = arme["degats_par_amelioration"]
	return {"stat": String(brut["stat"]), "ratio": float(brut["ratio"])}


## Paramètres numériques des stats qui n'ont pas de `valeur` (vide pour les autres).
static func specs_sans_valeur(stat: String) -> Array:
	match stat:
		"bonus_elim":
			return [Donnees._ent("tous_les", 1.0), Donnees._ent("or", 0.0)]
		"soin_periodique":
			return [Donnees._pos("tous_les"), Donnees._pos("ratio")]
		"mana_rupture_etourdit":
			return [Donnees._pos("rayon"), Donnees._pos("duree")]
		"revenu_contre_pv":
			return [Donnees._pos("pv"), Donnees._ent("or", 0.0)]
		"copie_prochaine_offre":
			return []
		"aura_mixte":
			return [Donnees._pos("rayon"), Donnees._nn("poison"), Donnees._nn("regen")]
	return []


static func valider_effet_amelioration(
	entree: Variant, f: String, ch: String, err: Array[String]
) -> void:
	if not entree is Dictionary:
		Donnees._err(err, f, ch, "attendu un objet, reçu %s" % Donnees._decrire(entree))
		return
	var e: Dictionary = entree
	if not e.has("stat") or not e["stat"] is String:
		Donnees._err(
			err,
			f,
			Donnees._sous(ch, "stat"),
			"texte attendu, reçu %s" % Donnees._decrire(e.get("stat"))
		)
		return
	var stat: String = e["stat"]
	if not stat in Donnees.STATS_AMELIORATION:
		Donnees._err(err, f, Donnees._sous(ch, "stat"), "inconnue « %s »" % stat)
		return
	if stat in Donnees.STATS_SANS_VALEUR:
		for spec: Dictionary in specs_sans_valeur(stat):
			Donnees._nombre(e, spec, f, ch, err)
		if stat == "copie_prochaine_offre":
			Donnees._nom_enum(e, "raretes_max", Types.NOMS_RARETES, f, ch, err)
		return
	if stat == "resurrection":
		# Un pourcentage entier de PV maximum (50 : la tour est relevée à 50 %), cumulé entre
		# exemplaires puis borné à 100 par `Arene`.
		Donnees._nombre(e, Donnees._spec("valeur", 1.0, false, 100.0, true), f, ch, err)
	elif stat in Donnees.STATS_ENTIERES:
		Donnees._nombre(e, Donnees._ent("valeur", 0.0), f, ch, err)
	else:
		Donnees._nombre(e, Donnees._spec("valeur", -INF), f, ch, err)
	if stat == "degats_type":
		Donnees._nom_enum(e, "type_degats", Types.NOMS_TYPES, f, ch, err)
	if stat == "degats_type" or stat == "degats_global":
		if not e.has("categorie") or not e["categorie"] in Donnees.CATEGORIES:
			var raison := "attendu A, B ou C, reçu %s" % Donnees._decrire(e.get("categorie"))
			Donnees._err(err, f, Donnees._sous(ch, "categorie"), raison)
		if e.has("croissance"):
			Donnees._nombre(e, Donnees._pos("croissance"), f, ch, err)
			Donnees._nombre(e, Donnees._pos("croissance_max"), f, ch, err)
		if e.has("par_arme_commune"):
			Donnees._nombre(e, Donnees._pos("par_arme_commune"), f, ch, err)
	if stat in Donnees.STATS_CROISSANTES:
		Donnees._nombre(e, Donnees._pos("max"), f, ch, err)
	if Donnees.STATS_A_CLE.has(stat):
		var def: Array = Donnees.STATS_A_CLE[stat]
		var noms: Array[String] = []
		noms.assign(def[1])
		Donnees._nom_enum(e, String(def[0]), noms, f, ch, err)


static func normaliser_amelioration(v: Variant) -> Dictionary:
	var a: Dictionary = v
	var effets: Array = []
	var effets_bruts: Array = a["effets"]
	for e_brut: Variant in effets_bruts:
		var e: Dictionary = e_brut
		var stat: String = e["stat"]
		var sortie_effet: Dictionary = {"stat": stat}
		if stat in Donnees.STATS_SANS_VALEUR:
			for spec: Dictionary in specs_sans_valeur(stat):
				var nom: String = spec["nom"]
				sortie_effet[nom] = Donnees._entier_ou_flottant(e[nom], spec["entier"])
			if stat == "copie_prochaine_offre":
				sortie_effet["raretes_max"] = Types.rarete_depuis_nom(e["raretes_max"])
		else:
			sortie_effet["valeur"] = Donnees._entier_ou_flottant(
				e["valeur"], stat in Donnees.STATS_ENTIERES
			)
		if stat == "degats_type":
			sortie_effet["type_degats"] = Types.type_depuis_nom(e["type_degats"])
		if stat == "degats_type" or stat == "degats_global":
			sortie_effet["categorie"] = e["categorie"]
			for nom: String in ["croissance", "croissance_max", "par_arme_commune"]:
				if e.has(nom):
					sortie_effet[nom] = float(e[nom])
		if stat in Donnees.STATS_CROISSANTES:
			sortie_effet["max"] = float(e["max"])
		if Donnees.STATS_A_CLE.has(stat):
			var def: Array = Donnees.STATS_A_CLE[stat]
			sortie_effet[String(def[0])] = String(e[String(def[0])])
		effets.append(sortie_effet)
	return {
		"id": a["id"],
		"nom": a["nom"],
		"description": a["description"],
		"rarete": Types.rarete_depuis_nom(a["rarete"]),
		"prix": int(a["prix"]),
		"categorie": Types.categorie_depuis_nom(a["categorie"]),
		"famille": a["famille"],
		"effets": effets,
	}
