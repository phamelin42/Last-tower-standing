extends CasDeTest
## Le contenu de la version 1 doit passer la validation de `Donnees`, et chaque objet doit
## pouvoir être proposé par la boutique à au moins une manche. Dépend de T1.1 (`Types`,
## `Donnees`, `data/boutique.json`).

const CLES_RARETE: Array[String] = ["commune", "peu_commune", "rare", "epique"]
const MANCHE_BOSS := 31

var donnees: Donnees


func avant_chaque() -> void:
	donnees = Donnees.charger()


func test_les_donnees_reelles_se_chargent() -> void:
	verifier_non_nul(donnees, "Donnees.charger() doit renvoyer une instance")


func test_le_contenu_charge_est_complet() -> void:
	if donnees == null:
		return
	verifier(donnees.armes.size() >= 25, "%d armes chargées" % donnees.armes.size())
	verifier(donnees.ameliorations.size() >= 30, "%d améliorations" % donnees.ameliorations.size())
	# Une famille par modèle et par palier de couleur, lus dans le fichier et non écrits en dur.
	var brut: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/ennemis.json")
	)
	var nb_modeles: int = (brut["modeles"] as Array).size()
	var nb_paliers: int = (brut["paliers"] as Array).size()
	verifier(nb_modeles > 0 and nb_paliers > 0, "ni modèle ni palier dans ennemis.json")
	verifier_egal(donnees.familles.size(), nb_modeles * nb_paliers)
	verifier_faux(donnees.convoi.is_empty(), "convoi absent")
	verifier_faux(donnees.boss.is_empty(), "boss absent")


func test_chaque_type_de_degats_a_au_moins_cinq_armes_apres_chargement() -> void:
	if donnees == null:
		return
	var nombre: Dictionary = {}
	for id: String in donnees.armes:
		var arme: Dictionary = donnees.armes[id]
		var type_degats: int = arme["type_degats"]
		nombre[type_degats] = int(nombre.get(type_degats, 0)) + 1
	for type_degats: int in [
		Types.TypeDegats.TRANCHANT,
		Types.TypeDegats.PERCANT,
		Types.TypeDegats.MAGIQUE,
		Types.TypeDegats.SIEGE,
		Types.TypeDegats.CHAOS,
	]:
		verifier(int(nombre.get(type_degats, 0)) >= 5, "type %d : %s armes" % [type_degats, nombre])


func test_chaque_arme_et_amelioration_a_une_rarete_proposable_a_une_manche() -> void:
	if donnees == null:
		return
	var poids: Array = donnees.boutique["poids"]
	var proposables: Array[bool] = []
	for rarete: int in CLES_RARETE.size():
		var possible := false
		for manche in range(1, MANCHE_BOSS + 1):
			possible = possible or donnees.palier(poids, manche, CLES_RARETE[rarete]) > 0.0
		proposables.append(possible)
	var catalogues: Array[Dictionary] = [donnees.armes, donnees.ameliorations]
	for catalogue: Dictionary in catalogues:
		for id: String in catalogue:
			var objet: Dictionary = catalogue[id]
			var rarete: int = objet["rarete"]
			verifier(
				rarete >= 0 and rarete < proposables.size() and proposables[rarete],
				(
					"%s : rareté %d jamais proposée entre les manches 1 et %d"
					% [id, rarete, MANCHE_BOSS]
				)
			)


func test_la_categorie_revenu_regroupe_exactement_les_stats_economiques() -> void:
	if donnees == null:
		return
	var economiques: Array[String] = [
		"revenu_fixe",
		"revenu_croissant",
		"revenu_mult",
		"prime_mult",
		"bonus_elim",
		"revenu_contre_pv",
	]
	var nb_revenu := 0
	for id: String in donnees.ameliorations:
		var amelioration: Dictionary = donnees.ameliorations[id]
		var effets: Array = amelioration["effets"]
		var tous_economiques := true
		for effet: Dictionary in effets:
			if not (effet["stat"] as String) in economiques:
				tous_economiques = false
		var est_revenu: bool = int(amelioration["categorie"]) == Types.Categorie.REVENU
		verifier_egal(est_revenu, tous_economiques, "%s : catégorie et effets" % id)
		nb_revenu += 1 if est_revenu else 0
	verifier(nb_revenu > 0, "au moins une offre de revenu")
	verifier_egal(
		donnees.categorie_de("commerce_a_credit"), Types.Categorie.REVENU, "revenu contre des PV"
	)
	for id: String in ["bourse_de_rebut", "jeton_de_l_arriere_boutique", "echo_de_l_aubaine"]:
		verifier_egal(
			donnees.categorie_de(id), Types.Categorie.AMELIORATION, "%s n'est pas un revenu" % id
		)
