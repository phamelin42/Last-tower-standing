extends CasDeTest
## Le catalogue d'améliorations tient les effectifs cibles du lot 9 : quinze familles, 87 en tout à
## la fin du lot. Chaque tâche de contenu ajoute ses familles à `FAMILLES_TERMINEES` ; la cible se
## lit toujours dans les données, « au moins ». T9.10 écrit les dégâts, les états et les classes.

## Familles dont la tâche de contenu est faite : leur effectif doit atteindre la cible.
const FAMILLES_TERMINEES: Array[String] = [
	"degats_type",
	"degats_global",
	"degats_classe",
	"etats",
	"epines",
	"pv_max",
	"regeneration",
	"armure",
]

## Effectif cible de chaque famille (la map d'origine, plus nos trois améliorations sans homologue).
const CIBLES: Dictionary = {
	"degats_type": 15,
	"degats_global": 3,
	"degats_classe": 7,
	"cadence": 2,
	"etats": 8,
	"epines": 11,
	"pv_max": 7,
	"regeneration": 6,
	"armure": 5,
	"esquive": 1,
	"mana": 7,
	"revenu": 9,
	"boutique": 3,
	"aura_mixte": 1,
	"critique": 2,
}
const TOTAL_FINAL := 87

## Les 18 améliorations de T9.10 : id → [famille, stat, clé du paramètre (type, classe ou état)].
const NOUVELLES: Dictionary = {
	"meule_des_lames": ["degats_type", "degats_type", "tranchant"],
	"carquois_des_siecles": ["degats_type", "degats_type", "perçant"],
	"chaire_des_arcanes": ["degats_type", "degats_type", "magique"],
	"arsenal_des_remparts": ["degats_type", "degats_type", "siège"],
	"fracas_du_desordre": ["degats_type", "degats_type", "chaos"],
	"metronome_patient": ["degats_global", "degats_global", ""],
	"caisse_d_echo": ["degats_classe", "degats_classe", "onde"],
	"garde_rapprochee": ["degats_classe", "degats_classe", "portee_courte"],
	"longue_vue": ["degats_classe", "degats_classe", "portee_longue"],
	"fierte_du_rang": ["degats_classe", "degats_classe", "commune"],
	"venin_concentre": ["etats", "etat_degats", "poison"],
	"charbon_ardent": ["etats", "etat_degats", "brulure"],
	"ampoule_tenace": ["etats", "etat_duree", "poison"],
	"braises_couvees": ["etats", "etat_duree", "brulure"],
	"maillet_de_plomb": ["etats", "etat_duree", "etourdissement"],
	"frappe_du_vertige": ["etats", "degats_contre_etat", "etourdi"],
	"dard_du_fievreux": ["etats", "degats_contre_etat", "empoisonne"],
	"proie_a_la_traine": ["etats", "degats_contre_etat", "ralenti"],
}
const CLES_PAR_STAT: Dictionary = {
	"degats_type": "type_degats",
	"degats_classe": "classe",
	"etat_degats": "etat",
	"etat_duree": "etat",
	"degats_contre_etat": "etat",
}

var _donnees: Donnees


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func _effectifs() -> Dictionary:
	var comptes: Dictionary = {}
	for id: String in _donnees.ameliorations:
		var famille: String = (_donnees.ameliorations[id] as Dictionary)["famille"]
		comptes[famille] = int(comptes.get(famille, 0)) + 1
	return comptes


func test_les_cibles_couvrent_les_quinze_familles_et_totalisent_87() -> void:
	verifier_egal(CIBLES.size(), 15)
	var somme := 0
	for famille: String in Types.FAMILLES_AMELIORATION:
		verifier(CIBLES.has(famille), "cible de %s" % famille)
		somme += int(CIBLES.get(famille, 0))
	verifier_egal(somme, TOTAL_FINAL)
	for famille: String in FAMILLES_TERMINEES:
		verifier(CIBLES.has(famille), "%s est une famille connue" % famille)


func test_les_familles_terminees_atteignent_leur_cible() -> void:
	var effectifs := _effectifs()
	for famille: String in FAMILLES_TERMINEES:
		var effectif := int(effectifs.get(famille, 0))
		verifier(
			effectif >= int(CIBLES[famille]),
			"%s : %d améliorations pour une cible de %d" % [famille, effectif, CIBLES[famille]]
		)


func test_aucune_famille_ne_depasse_le_total_final() -> void:
	verifier(_donnees.ameliorations.size() <= TOTAL_FINAL, "au plus 87 améliorations")


func test_les_dix_huit_nouvelles_ameliorations_existent_avec_leur_famille_et_leur_effet() -> void:
	verifier_egal(NOUVELLES.size(), 18)
	for id: String in NOUVELLES:
		verifier(_donnees.ameliorations.has(id), "%s existe" % id)
		if not _donnees.ameliorations.has(id):
			continue
		var attendu: Array = NOUVELLES[id]
		var amelioration: Dictionary = _donnees.ameliorations[id]
		verifier_egal(amelioration["famille"], attendu[0], "%s : famille" % id)
		var effets: Array = amelioration["effets"]
		verifier_egal(effets.size(), 1, "%s : un seul effet" % id)
		var effet: Dictionary = effets[0]
		verifier_egal(effet["stat"], attendu[1], "%s : stat" % id)
		verifier(float(effet["valeur"]) > 0.0, "%s : valeur positive" % id)
		if CLES_PAR_STAT.has(effet["stat"]):
			var cle: String = CLES_PAR_STAT[effet["stat"]]
			var recu: Variant = effet[cle]
			if cle == "type_degats":
				recu = Types.NOMS_TYPES[int(recu)]
			verifier_egal(recu, attendu[2], "%s : %s" % [id, cle])


func test_chaque_type_de_degats_a_son_palier_epique_avec_des_armes_communes() -> void:
	var vus: Dictionary = {}
	for id: String in NOUVELLES:
		var amelioration: Dictionary = _donnees.ameliorations[id]
		var effet: Dictionary = (amelioration["effets"] as Array)[0]
		if effet["stat"] != "degats_type":
			continue
		verifier_egal(amelioration["rarete"], Types.Rarete.EPIQUE, "%s : épique" % id)
		verifier(float(effet.get("par_arme_commune", 0.0)) > 0.0, "%s : par arme commune" % id)
		vus[int(effet["type_degats"])] = true
	verifier_egal(vus.size(), 5, "un palier par type de dégâts")


func test_l_ameliorations_de_degats_global_nouvelle_croit_avec_le_temps_dans_une_borne() -> void:
	var effet: Dictionary = (
		(_donnees.ameliorations["metronome_patient"] as Dictionary)["effets"] as Array
	)[0]
	verifier(float(effet["croissance"]) > 0.0 and float(effet["croissance_max"]) > 0.0)
	verifier(
		float(effet["croissance_max"]) >= float(effet["croissance"]),
		"le maximum vaut un pas au moins"
	)


func test_la_categorie_des_nouvelles_ameliorations_est_amelioration() -> void:
	for id: String in NOUVELLES:
		var amelioration: Dictionary = _donnees.ameliorations[id]
		verifier_egal(amelioration["categorie"], Types.Categorie.AMELIORATION, id)


func test_chaque_nouvelle_amelioration_a_une_image_et_une_famille() -> void:
	for id: String in NOUVELLES:
		verifier(not ImagesOffres.entree(id).is_empty(), "%s : image" % id)
		var chemin := ImagesOffres.chemin_case(id)
		verifier(FileAccess.file_exists(chemin), "%s : case composée %s" % [id, chemin])
		var amelioration: Dictionary = _donnees.ameliorations[id]
		verifier(Types.FAMILLES_AMELIORATION.has(amelioration["famille"]), "%s : famille" % id)


func test_chaque_nouvelle_amelioration_a_un_nom_et_une_description_uniques() -> void:
	var noms: Dictionary = {}
	for id: String in _donnees.ameliorations:
		var amelioration: Dictionary = _donnees.ameliorations[id]
		var nom: String = amelioration["nom"]
		verifier(nom.length() > 2, "%s : un nom" % id)
		verifier(not noms.has(nom), "%s : le nom « %s » est déjà pris" % [id, nom])
		noms[nom] = id
	for id: String in NOUVELLES:
		var texte: String = (_donnees.ameliorations[id] as Dictionary)["description"]
		verifier(texte.ends_with("."), "%s : une phrase" % id)
		verifier_faux(texte.contains("'"), "%s : apostrophe typographique" % id)


func test_le_produit_des_facteurs_reste_sous_le_plafond_avec_toutes_les_ameliorations() -> void:
	var plafond := float((_donnees.partie["ameliorations"] as Dictionary)["facteur_degats_max"])
	var inventaire := Inventaire.new(_donnees)
	for id: String in _donnees.ameliorations:
		inventaire.ajouter(id)
	var stats := inventaire.stats()
	var tous_les_bits := Types.STATUT_ETOURDI | Types.STATUT_EMPOISONNE | Types.STATUT_RALENTI
	var pire := 0.0
	var armes_par_classe: Dictionary = {}
	for id: String in _donnees.armes:
		var arme: Dictionary = _donnees.armes[id]
		var classe := stats.facteur_classe(arme)
		armes_par_classe[classe] = arme
		for t: int in 5:
			# Une heure et demie de partie sans fin, dix armes communes de chaque type équipées.
			var produit := (
				stats.facteur_degats_type(t, 5400.0, 10)
				* stats.facteur_degats_global(5400.0, 50)
				* classe
				* stats.facteur_contre_etat(tous_les_bits)
			)
			pire = maxf(pire, produit)
	verifier(pire > 1.0, "les améliorations agissent")
	verifier(pire < plafond, "pire produit ×%.2f, plafond ×%.0f" % [pire, plafond])
	verifier(armes_par_classe.size() > 1, "des armes de plusieurs classes ont été essayées")
