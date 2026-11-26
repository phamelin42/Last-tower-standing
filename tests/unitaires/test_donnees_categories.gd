extends CasDeTest
## Catégories d'offres, mana et classes de portée du lot 8 : ce que les données et les types
## doivent promettre. Les fixtures partent des vrais fichiers de `data/`.

const SUP := &"__supprimer__"
const FICHIERS: Array[String] = [
	"partie.json",
	"economie.json",
	"difficulte.json",
	"efficacite.json",
	"boutique.json",
	"armes.json",
	"ameliorations.json",
	"ennemis.json",
]


func _brut_reel() -> Dictionary:
	var brut: Dictionary = {}
	for nom in FICHIERS:
		brut[nom] = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + nom))
	return brut


func _muter(brut: Dictionary, fichier: String, chemin: Array, valeur: Variant) -> Dictionary:
	var copie: Dictionary = brut.duplicate(true)
	var courant: Variant = copie[fichier]
	for i in chemin.size() - 1:
		courant = courant[chemin[i]]
	var dernier: Variant = chemin[chemin.size() - 1]
	if typeof(valeur) == TYPE_STRING_NAME:
		if courant is Dictionary:
			var dico: Dictionary = courant
			dico.erase(dernier)
	else:
		courant[dernier] = valeur
	return copie


func _un_message_nomme(messages: PackedStringArray, fichier: String, champ: String) -> bool:
	for m in messages:
		if m.begins_with(fichier + ": ") and champ in m:
			return true
	return false


func test_les_categories_et_les_classes_de_portee_suivent_l_ordre_de_la_conception() -> void:
	verifier_egal(Types.NOMS_CATEGORIES, ["arme", "amelioration", "revenu"] as Array[String])
	verifier_egal(Types.Categorie.ARME, 0)
	verifier_egal(Types.Categorie.AMELIORATION, 1)
	verifier_egal(Types.Categorie.REVENU, 2)
	verifier_egal(
		Types.NOMS_CLASSES_PORTEE, ["corps_a_corps", "moyenne", "longue"] as Array[String]
	)
	verifier_egal(Types.ClassePortee.CORPS_A_CORPS, 0)
	verifier_egal(Types.ClassePortee.MOYENNE, 1)
	verifier_egal(Types.ClassePortee.LONGUE, 2)
	for i in Types.NOMS_CATEGORIES.size():
		verifier_egal(Types.categorie_depuis_nom(Types.NOMS_CATEGORIES[i]), i)
	for i in Types.NOMS_CLASSES_PORTEE.size():
		verifier_egal(Types.classe_portee_depuis_nom(Types.NOMS_CLASSES_PORTEE[i]), i)
	verifier_egal(Types.categorie_depuis_nom("Arme"), -1)
	verifier_egal(Types.classe_portee_depuis_nom("longue "), -1)


func test_resultat_arme_au_maximum_est_ajoute_a_la_fin_sans_renumeroter() -> void:
	verifier_egal(Types.Resultat.EMPLACEMENTS_PLEINS, 2, "le code réseau d'avant ne bouge pas")
	verifier_egal(Types.Resultat.NON_DISPONIBLE, 8)
	verifier_egal(Types.Resultat.ARMES_AU_MAXIMUM, 9)


func test_stats_tour_le_mana_est_nul_par_defaut() -> void:
	var s := StatsTour.new()
	verifier_proche(s.mana_max_bonus, 0.0)
	verifier_proche(s.mana_regen, 0.0)


func test_chaque_amelioration_a_une_categorie_valide() -> void:
	var d := Donnees.charger()
	verifier_non_nul(d)
	if d == null:
		return
	for id: String in d.ameliorations:
		var categorie: int = d.ameliorations[id]["categorie"]
		verifier(
			categorie == Types.Categorie.AMELIORATION or categorie == Types.Categorie.REVENU,
			"%s : catégorie %d" % [id, categorie]
		)


func test_categorie_de_rend_arme_pour_chaque_arme_et_la_categorie_des_donnees_sinon() -> void:
	var d := Donnees.charger()
	verifier_non_nul(d)
	if d == null:
		return
	for id: String in d.armes:
		verifier_egal(d.categorie_de(id), Types.Categorie.ARME, id)
	for id: String in d.ameliorations:
		verifier_egal(d.categorie_de(id), int(d.ameliorations[id]["categorie"]), id)
	verifier_egal(d.categorie_de("inconnu"), -1)


func test_categorie_absente_ou_inconnue_est_refusee_en_nommant_le_fichier_et_le_champ() -> void:
	var base := _brut_reel()
	for valeur: Variant in [SUP, "bonus", "arme", "Revenu", "", 1, null]:
		var brut := _muter(base, "ameliorations.json", [0, "categorie"], valeur)
		var messages := Donnees.valider(brut)
		verifier(
			_un_message_nomme(messages, "ameliorations.json", "categorie"),
			"valeur %s : %s" % [str(valeur), messages]
		)
		attendre_erreur("ameliorations.json")
		verifier_nul(Donnees.depuis_brut(brut), "valeur %s" % str(valeur))
	var ok := Donnees.depuis_brut(base)
	verifier_non_nul(ok)
	if ok != null:
		verifier_egal(ok.ameliorations["affutage_fin"]["categorie"], Types.Categorie.AMELIORATION)
		verifier_egal(ok.ameliorations["cagnotte_du_guet"]["categorie"], Types.Categorie.REVENU)


func test_degats_par_mana_max_est_zero_par_defaut_et_negatif_est_refuse() -> void:
	# Sans la clé, une arme n'a aucun dégât de mana (les armes de mana la portent explicitement).
	var sans := _brut_reel()
	for arme: Dictionary in sans["armes.json"]:
		arme.erase("degats_par_mana_max")
	var d := Donnees.depuis_brut(sans)
	verifier_non_nul(d)
	if d == null:
		return
	for id: String in d.armes:
		verifier_proche(float(d.armes[id]["degats_par_mana_max"]), 0.0, 0.0, id)
	var premiere_arme: String = _brut_reel()["armes.json"][0]["id"]
	var avec := _muter(_brut_reel(), "armes.json", [0, "degats_par_mana_max"], 0.25)
	var d_avec := Donnees.depuis_brut(avec)
	verifier_non_nul(d_avec)
	if d_avec != null:
		verifier_proche(float(d_avec.armes[premiere_arme]["degats_par_mana_max"]), 0.25)
	var negatif := _muter(_brut_reel(), "armes.json", [0, "degats_par_mana_max"], -0.1)
	verifier(
		_un_message_nomme(Donnees.valider(negatif), "armes.json", "degats_par_mana_max"),
		"un ratio négatif est refusé"
	)


func test_le_mana_de_depart_est_zero_dans_les_donnees() -> void:
	var d := Donnees.charger()
	verifier_non_nul(d)
	if d == null:
		return
	var tour: Dictionary = d.partie["tour"]
	verifier_proche(float(tour["mana_max"]), 0.0)
	verifier_proche(float(tour["mana_regen"]), 1.0)


func test_les_stats_de_mana_sont_des_stats_d_amelioration_valides() -> void:
	for stat: String in ["mana_max", "mana_regen"]:
		var brut := _muter(_brut_reel(), "ameliorations.json", [0, "effets", 0, "stat"], stat)
		verifier_egal(Donnees.valider(brut), PackedStringArray(), "stat « %s »" % stat)


func test_les_portees_d_armes_sont_500_750_1000_1250() -> void:
	var d := Donnees.charger()
	verifier_non_nul(d)
	if d == null:
		return
	verifier_egal(Donnees.PORTEES, [500, 750, 1000, 1250] as Array[int])
	var utilisees: Dictionary = {}
	for id: String in d.armes:
		var portee := int((d.armes[id] as Dictionary)["portee"])
		verifier(portee in Donnees.PORTEES, "%s : portée %d" % [id, portee])
		utilisees[portee] = true
	for portee: int in Donnees.PORTEES:
		verifier(utilisees.has(portee), "aucune arme de portée %d" % portee)


func test_une_ancienne_portee_est_refusee_en_nommant_armes_json_et_portee() -> void:
	for ancienne: int in [300, 600, 900, 1200, 499, 1251, 0]:
		var brut := _muter(_brut_reel(), "armes.json", [0, "portee"], ancienne)
		var messages := Donnees.valider(brut)
		verifier(
			_un_message_nomme(messages, "armes.json", "portee"),
			"portée %d acceptée : %s" % [ancienne, messages]
		)
