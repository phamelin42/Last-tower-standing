class_name DonneesArmes
extends RefCounted
## Validation et normalisation de `data/armes.json` : les champs d'une arme, ses effets (un `kind`
## parmi les mécaniques du lot 9) et ses statuts. Les briques de validation sont celles de
## `Donnees` ; ce fichier n'a été sorti de `donnees.gd` que pour le garder sous la limite de lignes.


static func valider(
	liste: Array, ids: Dictionary, err: Array[String], unites: Dictionary = {}
) -> void:
	var f := "armes.json"
	for i in liste.size():
		var ch := "[%d]" % i
		var entree: Variant = liste[i]
		if not entree is Dictionary:
			Donnees._err(err, f, ch, "attendu un objet, reçu %s" % Donnees._decrire(entree))
			continue
		var a: Dictionary = entree
		Donnees._identifiant(a, f, ch, err, ids)
		Donnees._texte(a, "nom", f, ch, err)
		Donnees._texte(a, "description", f, ch, err)
		Donnees._nom_enum(a, "rarete", Types.NOMS_RARETES, f, ch, err)
		Donnees._nombre(a, Donnees._ent("prix", 0.0), f, ch, err)
		Donnees._nom_enum(a, "type_degats", Types.NOMS_TYPES, f, ch, err)
		Donnees._nombre(a, Donnees._pos("degats"), f, ch, err)
		Donnees._nombre(a, Donnees._pos("recharge"), f, ch, err)
		Donnees._nom_enum(a, "ciblage", Types.NOMS_CIBLAGES, f, ch, err)
		for nom: String in ["degats_par_mana_max", "degats_par_pv_max", "degats_par_niveau"]:
			if a.has(nom):
				Donnees._nombre(a, Donnees._nn(nom), f, ch, err)
		if a.has("degats_par_amelioration"):
			DonneesLot9.valider_degats_par_amelioration(a["degats_par_amelioration"], f, ch, err)
		if a.has("type_secondaire") and a["type_secondaire"] != "epines":
			var brut_second := Donnees._decrire(a["type_secondaire"])
			Donnees._err(
				err,
				f,
				Donnees._sous(ch, "type_secondaire"),
				"« epines » attendu, reçu %s" % brut_second
			)
		if Donnees._nombre(a, Donnees._ent("portee", 0.0), f, ch, err):
			var portee: int = int(a["portee"])
			if not portee in Donnees.PORTEES:
				Donnees._err(
					err, f, Donnees._sous(ch, "portee"), "doit valoir 500, 750, 1000 ou 1250"
				)
		var effets_ok := Donnees._tableau(a, "effets", f, ch, err)
		if effets_ok:
			var effets: Array = a["effets"]
			if effets.is_empty():
				Donnees._err(err, f, Donnees._sous(ch, "effets"), "au moins un effet attendu")
			for j in effets.size():
				valider_sous_effet(
					effets[j],
					f,
					"%s[%d]" % [Donnees._sous(ch, "effets"), j],
					err,
					kinds_effets(),
					unites
				)
		if a.has("statuts"):
			var statuts_ok := Donnees._tableau(a, "statuts", f, ch, err)
			if statuts_ok:
				var statuts: Array = a["statuts"]
				for j in statuts.size():
					var chemin := "%s[%d]" % [Donnees._sous(ch, "statuts"), j]
					valider_sous_effet(statuts[j], f, chemin, err, kinds_statuts())


## Un effet d'arme ou un statut : `kind` connu, puis les paramètres de ce `kind`.
static func valider_sous_effet(
	entree: Variant,
	f: String,
	ch: String,
	err: Array[String],
	kinds: Dictionary,
	unites: Dictionary = {}
) -> void:
	if not entree is Dictionary:
		Donnees._err(err, f, ch, "attendu un objet, reçu %s" % Donnees._decrire(entree))
		return
	var e: Dictionary = entree
	if not e.has("kind") or not e["kind"] is String:
		Donnees._err(
			err,
			f,
			Donnees._sous(ch, "kind"),
			"texte attendu, reçu %s" % Donnees._decrire(e.get("kind"))
		)
		return
	var kind: String = e["kind"]
	if not kinds.has(kind):
		var connus := ", ".join(PackedStringArray(kinds.keys()))
		Donnees._err(
			err, f, Donnees._sous(ch, "kind"), "inconnu « %s » (attendu : %s)" % [kind, connus]
		)
		return
	var specs: Array = kinds[kind]
	for spec: Dictionary in specs:
		Donnees._nombre(e, spec, f, ch, err)
	if kind == "vol_de_vie" and e.has("a_la_mort") and not e["a_la_mort"] is bool:
		Donnees._err(
			err,
			f,
			Donnees._sous(ch, "a_la_mort"),
			"booléen attendu, reçu %s" % Donnees._decrire(e["a_la_mort"])
		)
	DonneesLot9.valider_champs_texte(kind, e, f, ch, err, unites)


static func kinds_effets() -> Dictionary:
	return {
		"cible_unique": [],
		"zone": [Donnees._pos("rayon")],
		"rebond":
		[
			Donnees._spec("cibles", 4.0, false, 8.0, true),
			Donnees._pos("portee_saut"),
			Donnees._spec("decroissance", 0.0, true, 1.0)
		],
		"onde": [Donnees._pos("rayon_max"), Donnees._pos("vitesse")],
		"barrage":
		[Donnees._ent("projectiles", 1.0), Donnees._nn("dispersion_deg"), Donnees._pos("rayon")],
		"mine": [Donnees._pos("rayon"), Donnees._ent("max_actives", 1.0)],
		"piege": [Donnees._pos("rayon"), Donnees._ent("max_actives", 1.0)],
		"aura": [Donnees._pos("rayon"), Donnees._pos("periode")],
		"tournant":
		[
			Donnees._spec("branches", 1.0, false, 8.0, true),
			Donnees._spec("pas_deg", 0.0, true, 180.0),
			Donnees._pos("largeur")
		],
		"zone_posee":
		[
			Donnees._pos("rayon"),
			Donnees._pos("duree"),
			Donnees._pos("periode"),
			Donnees._pos("ratio"),
			Donnees._ent("max_actives", 1.0)
		],
		"bombe":
		[
			Donnees._spec("delai", 0.0, true, 5.0),
			Donnees._pos("rayon"),
			Donnees._pos("ratio"),
			Donnees._ent("max_actives", 1.0)
		],
		"invocation":
		[Donnees._pos("duree"), Donnees._pos("ratio_degats"), Donnees._ent("max_actives", 1.0)],
	}


static func kinds_statuts() -> Dictionary:
	return {
		"poison": [Donnees._pos("total_ratio"), Donnees._pos("duree")],
		"brulure": [Donnees._pos("ratio"), Donnees._pos("duree")],
		"givre": [],
		"etourdissement": [Donnees._pos("duree")],
		"vol_de_vie": [Donnees._pos("ratio")],
		"vulnerabilite": [Donnees._pos("ratio"), Donnees._pos("duree")],
		"malediction_degats": [Donnees._spec("ratio", 0.0, true, 1.0), Donnees._pos("duree")],
		"malediction_toucher": [Donnees._spec("ratio", 0.0, true, 1.0), Donnees._pos("duree")],
		"repoussement": [Donnees._pos("distance")],
		"siphon": [Donnees._pos("par_seconde"), Donnees._pos("duree")],
		"mana_au_coup": [Donnees._pos("valeur")],
	}


static func normaliser_sous_effet(v: Variant, kinds: Dictionary) -> Dictionary:
	var source: Dictionary = v
	var kind: String = source["kind"]
	var sortie: Dictionary = {"kind": kind}
	var specs: Array = kinds[kind]
	for spec: Dictionary in specs:
		var nom: String = spec["nom"]
		sortie[nom] = Donnees._entier_ou_flottant(source[nom], spec["entier"])
	if kind == "vol_de_vie":
		sortie["a_la_mort"] = source.get("a_la_mort", false)
	match kind:
		"tournant":
			sortie["sens"] = source["sens"]
		"siphon":
			sortie["ressource"] = source["ressource"]
		"invocation":
			sortie["unite"] = source["unite"]
		"vulnerabilite":
			# -1 : le type de l'arme qui pose le statut.
			sortie["type_degats"] = (
				Types.type_depuis_nom(source["type_degats"]) if source.has("type_degats") else -1
			)
	return sortie


static func normaliser(v: Variant) -> Dictionary:
	var a: Dictionary = v
	var sortie: Dictionary = {
		"id": a["id"],
		"nom": a["nom"],
		"description": a["description"],
		"rarete": Types.rarete_depuis_nom(a["rarete"]),
		"prix": int(a["prix"]),
		"type_degats": Types.type_depuis_nom(a["type_degats"]),
		"degats": float(a["degats"]),
		"recharge": float(a["recharge"]),
		"portee": int(a["portee"]),
		"ciblage": Types.ciblage_depuis_nom(a["ciblage"]),
		"degats_par_mana_max": float(a.get("degats_par_mana_max", 0.0)),
		"degats_par_pv_max": float(a.get("degats_par_pv_max", 0.0)),
		"degats_par_niveau": float(a.get("degats_par_niveau", 0.0)),
		"degats_par_amelioration": DonneesLot9.normaliser_par_amelioration(a),
		"type_secondaire": String(a.get("type_secondaire", "")),
	}
	var effets: Array = []
	var effets_bruts: Array = a["effets"]
	for e: Variant in effets_bruts:
		effets.append(normaliser_sous_effet(e, kinds_effets()))
	sortie["effets"] = effets
	var statuts: Array = []
	var statuts_bruts: Array = a.get("statuts", [])
	for s: Variant in statuts_bruts:
		statuts.append(normaliser_sous_effet(s, kinds_statuts()))
	sortie["statuts"] = statuts
	return sortie
