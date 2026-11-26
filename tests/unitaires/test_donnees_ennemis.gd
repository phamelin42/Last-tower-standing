extends CasDeTest
## Les ennemis du pack : chaque modèle (rôle, classe de portée) se décline en paliers de couleur de
## plus en plus forts, sans vol. Ces tests lisent `data/ennemis.json` et `Donnees.familles` et
## bouclent sur leur contenu : aucun effectif n'est figé, le catalogue peut grandir.

const FICHIER := "ennemis.json"
## Armure et classe de portée attendues de chaque modèle, et si son contact le fait exploser.
const ROLES: Dictionary = {
	"torche": [Types.Armure.LEGERE, Types.ClassePortee.CORPS_A_CORPS, false],
	"paysan": [Types.Armure.MOYENNE, Types.ClassePortee.CORPS_A_CORPS, false],
	"guerrier": [Types.Armure.LOURDE, Types.ClassePortee.CORPS_A_CORPS, false],
	"tonneau": [Types.Armure.FORTIFIEE, Types.ClassePortee.CORPS_A_CORPS, true],
	"dynamite": [Types.Armure.AUCUNE, Types.ClassePortee.MOYENNE, false],
	"archer": [Types.Armure.MOYENNE, Types.ClassePortee.LONGUE, false],
}
const PORTEE_MOYENNE := 350.0
const PORTEE_LONGUE := 650.0

var d: Donnees
var brut_ennemis: Dictionary = {}


func avant_chaque() -> void:
	d = Donnees.charger()
	brut_ennemis = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + FICHIER))


# --- Aides -------------------------------------------------------------------------------------


func _modeles() -> Array:
	return brut_ennemis["modeles"]


func _paliers() -> Array:
	return brut_ennemis["paliers"]


## Jeu de données complet et valide, dont `ennemis.json` est la copie profonde modifiable.
func _brut_complet() -> Dictionary:
	var brut: Dictionary = {}
	var tout: Array[String] = Donnees.FICHIERS_OBJET + Donnees.FICHIERS_LISTE
	for nom in tout:
		brut[nom] = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + nom))
	return brut


func _familles_du_modele(id: String) -> Array[Dictionary]:
	var trouvees: Array[Dictionary] = []
	for f: Dictionary in d.familles:
		if f["modele"] == id:
			trouvees.append(f)
	return trouvees


func _mult() -> Dictionary:
	return {"pv": 1.0, "degats": 1.0, "vitesse": 1.0, "resistance_controle": 1.0}


# --- Structure ---------------------------------------------------------------------------------


func test_vingt_quatre_familles_six_modeles_quatre_paliers() -> void:
	var nb_modeles := _modeles().size()
	var nb_paliers := _paliers().size()
	verifier(nb_modeles > 0 and nb_paliers > 0, "au moins un modèle et un palier")
	verifier_egal(d.familles.size(), nb_modeles * nb_paliers, "un modèle par palier de couleur")
	var vus: Dictionary = {}
	for m: int in nb_modeles:
		for p: int in nb_paliers:
			var famille: Dictionary = d.familles[nb_paliers * m + p]
			var attendu := "%s_%s" % [_modeles()[m]["id"], _paliers()[p]["id"]]
			verifier_egal(famille["id"], attendu, "ordre modèle puis palier")
			verifier_egal(famille["modele"], _modeles()[m]["id"])
			verifier_egal(famille["palier"], _paliers()[p]["id"])
			verifier_egal(famille["indice_palier"], p, attendu)
			verifier_egal(famille["manche_entree"], int(_paliers()[p]["manche_entree"]), attendu)
			verifier_faux(vus.has(famille["id"]), "identifiant en double : %s" % famille["id"])
			vus[famille["id"]] = true
	verifier_faux(d.familles[0].has("volant"), "plus de clé volant")


func test_le_convoi_et_le_boss_suivent_les_familles() -> void:
	var a := Arene.new(d, 4242)
	a.demarrer_manche(5, d.familles.size(), _mult())
	for _i: int in 100:
		a.avancer(0.05)
	verifier(a.nombre_ennemis() > 0, "le convoi est apparu")
	verifier_egal(
		int(a.ennemis.famille[0]), d.familles.size(), "convoi : après la dernière famille"
	)
	var b := Arene.new(d, 4242)
	b.demarrer_boss(_mult())
	verifier_egal(int(b.ennemis.famille[0]), d.familles.size() + 1, "boss : encore après")


func test_les_noms_des_24_familles_sont_distincts_et_non_vides() -> void:
	var vus: Dictionary = {}
	var noms: Array[String] = []
	for f: Dictionary in d.familles:
		noms.append(f["nom"])
	noms.append(d.convoi["nom"])
	noms.append(d.boss["nom"])
	for nom in noms:
		verifier_faux(nom.strip_edges().is_empty(), "nom vide")
		verifier_faux(vus.has(nom), "nom en double : %s" % nom)
		vus[nom] = true


func test_chaque_modele_a_son_role() -> void:
	var vus: Dictionary = {}
	for f: Dictionary in d.familles:
		var id: String = f["modele"]
		verifier(ROLES.has(id), "modèle inattendu : %s" % id)
		if not ROLES.has(id):
			continue
		var role: Array = ROLES[id]
		verifier_egal(f["armure"], role[0], "%s : armure" % f["id"])
		verifier_egal(f["classe_portee"], role[1], "%s : classe de portée" % f["id"])
		verifier_egal(f["explose"], role[2], "%s : explose au contact" % f["id"])
		vus[id] = int(vus.get(id, 0)) + 1
	for id: String in ROLES:
		verifier_egal(int(vus.get(id, 0)), _paliers().size(), "%s : un par palier" % id)


func test_la_classe_de_portee_est_coherente_avec_la_portee_d_attaque() -> void:
	for f: Dictionary in d.familles:
		var portee: float = f["portee_attaque"]
		match int(f["classe_portee"]):
			Types.ClassePortee.CORPS_A_CORPS:
				verifier(portee <= Ennemis.PORTEE_CORPS_A_CORPS, "%s : %s" % [f["id"], portee])
			Types.ClassePortee.MOYENNE:
				verifier_egal(portee, PORTEE_MOYENNE, f["id"])
			Types.ClassePortee.LONGUE:
				verifier_egal(portee, PORTEE_LONGUE, f["id"])
			_:
				verifier(false, "%s : classe de portée inconnue" % f["id"])


func test_la_force_croit_avec_le_palier() -> void:
	for m: Dictionary in _modeles():
		var famille: Array[Dictionary] = _familles_du_modele(m["id"])
		verifier_egal(famille.size(), _paliers().size(), m["id"])
		for k: int in range(1, famille.size()):
			var avant := famille[k - 1]
			var apres := famille[k]
			var nom := "%s -> %s" % [avant["id"], apres["id"]]
			verifier(apres["pv"] > avant["pv"], "%s : pv" % nom)
			verifier(apres["degats"] > avant["degats"], "%s : dégâts" % nom)
			verifier(apres["prime"] > avant["prime"], "%s : prime" % nom)
			verifier_egal(apres["vitesse"], avant["vitesse"], "%s : même vitesse" % nom)
			verifier(apres["manche_entree"] > avant["manche_entree"], "%s : entrée" % nom)


func test_aucun_champ_volant_dans_les_donnees_ni_la_simulation() -> void:
	var texte := FileAccess.get_file_as_string("res://data/" + FICHIER)
	verifier_faux("volant" in texte, "« volant » dans ennemis.json")
	for f: Dictionary in d.familles:
		verifier_faux(f.has("volant"), f["id"])
	var e := Ennemis.new(d)
	for propriete: Dictionary in e.get_property_list():
		verifier_faux("volant" in String(propriete["name"]), "propriété %s" % propriete["name"])
	for methode: Dictionary in e.get_method_list():
		verifier_faux("volant" in String(methode["name"]), "méthode %s" % methode["name"])
		for argument: Dictionary in methode["args"]:
			verifier_faux("volant" in String(argument["name"]), "argument %s" % argument["name"])


# --- Refus des données invalides ---------------------------------------------------------------


## [nom, modification de `ennemis.json`, champ que le message doit nommer].
func _cas_invalides() -> Array[Array]:
	return [
		[
			"classe de portée inconnue",
			func(e: Dictionary) -> void: e["modeles"][0]["classe_portee"] = "courte",
			"classe_portee"
		],
		[
			"classe de portée absente",
			func(e: Dictionary) -> void: (e["modeles"][0] as Dictionary).erase("classe_portee"),
			"classe_portee"
		],
		[
			"palier en double",
			func(e: Dictionary) -> void: e["paliers"][1]["id"] = e["paliers"][0]["id"],
			"id"
		],
		[
			"manche d'entrée égale à la précédente",
			func(e: Dictionary) -> void:
				e["paliers"][1]["manche_entree"] = e["paliers"][0]["manche_entree"],
			"manche_entree"
		],
		[
			"manche d'entrée qui décroît",
			func(e: Dictionary) -> void: (e["paliers"] as Array).back()["manche_entree"] = 1,
			"manche_entree"
		],
		[
			"un nom de moins",
			func(e: Dictionary) -> void: (e["modeles"][0]["noms"] as Array).pop_back(),
			"noms"
		],
		[
			"un nom de plus",
			func(e: Dictionary) -> void: (e["modeles"][0]["noms"] as Array).append("Un de trop"),
			"noms"
		],
		[
			"nom dupliqué entre deux modèles",
			func(e: Dictionary) -> void: e["modeles"][1]["noms"][0] = e["modeles"][0]["noms"][0],
			"noms"
		],
		[
			"corps à corps à longue portée",
			func(e: Dictionary) -> void: e["modeles"][0]["portee_attaque"] = 300,
			"portee_attaque"
		],
		[
			"moyenne portée au contact",
			func(e: Dictionary) -> void: _modele_de(e, "dynamite")["portee_attaque"] = 40,
			"portee_attaque"
		],
		[
			"longue portée au contact",
			func(e: Dictionary) -> void: _modele_de(e, "archer")["portee_attaque"] = 60,
			"portee_attaque"
		],
		[
			"explosion hors corps à corps",
			func(e: Dictionary) -> void: _modele_de(e, "dynamite")["explose"] = true,
			"explose"
		],
	]


static func _modele_de(e: Dictionary, id: String) -> Dictionary:
	for m: Dictionary in e["modeles"]:
		if m["id"] == id:
			return m
	return {}


func test_les_donnees_refusent_un_modele_ou_un_palier_invalide() -> void:
	# Contrôle négatif : les données réelles sont valides, seule la cause injectée peut échouer.
	verifier_egal(Donnees.valider(_brut_complet()), PackedStringArray())
	verifier(not _modele_de(_brut_complet()[FICHIER], "dynamite").is_empty(), "modèle présent")
	for cas in _cas_invalides():
		var brut := _brut_complet()
		var modifier: Callable = cas[1]
		modifier.call(brut[FICHIER])
		var messages := Donnees.valider(brut)
		var trouve := false
		for message in messages:
			trouve = trouve or (message.begins_with(FICHIER + ": ") and String(cas[2]) in message)
			verifier(
				message.begins_with(FICHIER + ": "), "%s : hors fichier : %s" % [cas[0], message]
			)
		verifier(
			trouve, "%s : attendu « %s: … %s … », reçu %s" % [cas[0], FICHIER, cas[2], messages]
		)
		for _i: int in messages.size():
			attendre_erreur(FICHIER)
		verifier_nul(Donnees.depuis_brut(brut), cas[0])
