extends CasDeTest
## Ce que le jeu doit obtenir des données : des types sûrs, des fichiers valides chargés,
## et pour chaque donnée invalide un message qui nomme le fichier et le champ fautif.

const FICHIERS_REELS: Array[String] = [
	"partie.json", "economie.json", "difficulte.json", "efficacite.json", "boutique.json"
]
const DOSSIER_TEST := "user://test_donnees"
## Valeur de mutation : supprimer la clé (StringName, donc distinct de tout texte du fichier).
const SUP := &"__supprimer__"
const PALIERS_NON_TRIES: Array = [
	{"manche": 1, "valeur": 20}, {"manche": 9, "valeur": 30}, {"manche": 6, "valeur": 40}
]
const PALIERS_DUPLIQUES: Array = [{"manche": 1, "valeur": 1.0}, {"manche": 1, "valeur": 1.5}]

# Noms français tels que les écrivent les fichiers, dans l'ordre des énumérations.
const NOMS_TYPES: Array[String] = ["tranchant", "perçant", "magique", "siège", "chaos"]
const NOMS_ARMURES: Array[String] = ["légère", "moyenne", "lourde", "fortifiée", "aucune", "boss"]
const NOMS_RARETES: Array[String] = ["commune", "peu_commune", "rare", "epique"]
const NOMS_CIBLAGES: Array[String] = ["plus_proche", "plus_fort", "plus_faible"]


func avant_chaque() -> void:
	_nettoyer_dossier()


func apres_chaque() -> void:
	_nettoyer_dossier()


# --- Aides -----------------------------------------------------------------------------------


func _lire_reel(nom: String) -> Variant:
	var texte := FileAccess.get_file_as_string("res://data/" + nom)
	return JSON.parse_string(texte)


func _armes_valides() -> Array:
	return [
		{
			"id": "arbalete_percante",
			"nom": "Arbalète perçante légère",
			"description": "Un carreau qui traverse les armures légères.",
			"rarete": "peu_commune",
			"prix": 300,
			"type_degats": "perçant",
			"degats": 12.0,
			"recharge": 0.8,
			"portee": 900,
			"ciblage": "plus_faible",
			"effets": [{"kind": "cible_unique"}],
		},
		{
			"id": "catapulte_de_siege",
			"nom": "Catapulte de siège fortifiée",
			"description": "Écrase les murs et les foules.",
			"rarete": "rare",
			"prix": 900,
			"type_degats": "siège",
			"degats": 42.0,
			"recharge": 1.2,
			"portee": 600,
			"ciblage": "plus_proche",
			"effets": [{"kind": "rebond", "cibles": 5, "portee_saut": 250, "decroissance": 0.9}],
			"statuts": [{"kind": "givre"}, {"kind": "vol_de_vie", "ratio": 0.05}],
		},
	]


func _ameliorations_valides() -> Array:
	return [
		{
			"id": "lame_aiguisee",
			"nom": "Lame aiguisée",
			"description": "Les dégâts tranchants augmentent.",
			"rarete": "commune",
			"prix": 150,
			"effets":
			[{"stat": "degats_type", "type_degats": "tranchant", "valeur": 0.1, "categorie": "A"}],
		},
		{
			"id": "prime_de_guerre",
			"nom": "Prime de guerre",
			"description": "De l'or tous les dix ennemis.",
			"rarete": "epique",
			"prix": 700,
			"effets": [{"stat": "bonus_elim", "tous_les": 10, "or": 25}],
		},
	]


func _ennemis_valides() -> Dictionary:
	return {
		"familles":
		[
			{
				"id": "rampant",
				"nom": "Rampant des cendres légères",
				"armure": "légère",
				"volant": false,
				"pv": 40,
				"vitesse": 60,
				"degats": 4,
				"portee_attaque": 40,
				"cadence_attaque": 1.0,
				"prime": 2,
			},
			{
				"id": "belier",
				"nom": "Bélier fortifié",
				"armure": "fortifiée",
				"volant": true,
				"pv": 120,
				"vitesse": 50,
				"degats": 9,
				"portee_attaque": 200,
				"cadence_attaque": 2.0,
				"prime": 5,
			},
		],
		"convoi":
		{"id": "convoi_dore", "nom": "Convoi doré", "pv": 400, "vitesse": 45, "prime": 120},
		"boss":
		{
			"id": "seigneur_des_cendres",
			"nom": "Seigneur des cendres",
			"pv": 20000,
			"vitesse": 35,
			"degats": 60,
			"portee_attaque": 80,
			"cadence_attaque": 1.5,
		},
	}


## Jeu complet valide : les cinq fichiers réels de la tâche + un contenu minimal pour les autres.
func _brut_valide() -> Dictionary:
	var brut: Dictionary = {}
	for nom in FICHIERS_REELS:
		brut[nom] = _lire_reel(nom)
	brut["armes.json"] = _armes_valides()
	brut["ameliorations.json"] = _ameliorations_valides()
	brut["ennemis.json"] = _ennemis_valides()
	return brut


func _brut_listes_vides() -> Dictionary:
	var brut: Dictionary = {}
	for nom in FICHIERS_REELS:
		brut[nom] = _lire_reel(nom)
	brut["armes.json"] = []
	brut["ameliorations.json"] = []
	brut["ennemis.json"] = {"familles": [], "convoi": {}, "boss": {}}
	return brut


## Copie profonde de `brut` où `chemin` (clés et indices) reçoit `valeur`, ou est supprimé.
func _muter(
	brut: Dictionary, fichier: String, chemin: Array, valeur: Variant, supprimer: bool
) -> Dictionary:
	var copie: Dictionary = brut.duplicate(true)
	var courant: Variant = copie[fichier]
	for i in chemin.size() - 1:
		courant = courant[chemin[i]]
	var dernier: Variant = chemin[chemin.size() - 1]
	if supprimer:
		if courant is Dictionary:
			var dico: Dictionary = courant
			dico.erase(dernier)
		else:
			var liste: Array = courant
			liste.remove_at(int(dernier))
	else:
		courant[dernier] = valeur
	return copie


func _ecrire(nom: String, contenu: Variant) -> void:
	var texte: String = contenu if contenu is String else JSON.stringify(contenu)
	DirAccess.make_dir_recursive_absolute(DOSSIER_TEST)
	var f := FileAccess.open(DOSSIER_TEST + "/" + nom, FileAccess.WRITE)
	f.store_string(texte)
	f.close()


func _ecrire_dossier(brut: Dictionary) -> void:
	for nom: String in brut:
		_ecrire(nom, brut[nom])


func _nettoyer_dossier() -> void:
	var dossier := DirAccess.open(DOSSIER_TEST)
	if dossier == null:
		return
	for nom in dossier.get_files():
		dossier.remove(nom)
	DirAccess.remove_absolute(DOSSIER_TEST)


func _un_message_nomme(messages: PackedStringArray, fichier: String, champ: String) -> bool:
	for m in messages:
		if m.begins_with(fichier + ": ") and champ in m:
			return true
	return false


# --- Types : noms français -------------------------------------------------------------------


func test_types_chaque_nom_francais_avec_accents_donne_son_enum() -> void:
	for i in NOMS_TYPES.size():
		verifier_egal(Types.type_depuis_nom(NOMS_TYPES[i]), i, NOMS_TYPES[i])
	for i in NOMS_ARMURES.size():
		verifier_egal(Types.armure_depuis_nom(NOMS_ARMURES[i]), i, NOMS_ARMURES[i])
	for i in NOMS_RARETES.size():
		verifier_egal(Types.rarete_depuis_nom(NOMS_RARETES[i]), i, NOMS_RARETES[i])
	for i in NOMS_CIBLAGES.size():
		verifier_egal(Types.ciblage_depuis_nom(NOMS_CIBLAGES[i]), i, NOMS_CIBLAGES[i])


func test_types_les_valeurs_d_enum_suivent_l_ordre_de_la_spec() -> void:
	verifier_egal(Types.TypeDegats.TRANCHANT, 0)
	verifier_egal(Types.TypeDegats.CHAOS, 4)
	verifier_egal(Types.Armure.LEGERE, 0)
	verifier_egal(Types.Armure.BOSS, 5)
	verifier_egal(Types.Rarete.EPIQUE, 3)
	verifier_egal(Types.Ciblage.PLUS_FAIBLE, 2)
	verifier_egal(Types.Phase.DEFAITE, 4)
	verifier_egal(Types.Genre.AMELIORATION, 1)
	verifier_egal(Types.Resultat.NON_DISPONIBLE, 8)
	verifier_egal(Types.STATUT_GELE, 1)
	verifier_egal(Types.STATUT_RALENTI, 2)
	verifier_egal(Types.STATUT_EMPOISONNE, 4)
	verifier_egal(Types.STATUT_BRULE, 8)
	verifier_egal(Types.STATUT_ETOURDI, 16)


func test_types_les_noms_sans_accent_en_majuscules_ou_espaces_sont_refuses() -> void:
	var refuses: Array[String] = [
		"percant",
		"Perçant",
		"PERÇANT",
		"siege",
		"Siège",
		"legere",
		"Légère",
		"LÉGÈRE",
		"fortifiee",
		"Fortifiée",
		"Tranchant",
		"MAGIQUE",
		"Chaos",
		"Boss",
		"AUCUNE",
		" perçant",
		"perçant ",
		"",
		"inconnu",
		"peu commune",
		"Peu_Commune",
		"epique ",
		"Plus_Proche",
		"plus proche",
		# « ç » décomposé (c + cédille combinante) : visuellement identique, donc refusé.
		"perçant",
	]
	for nom in refuses:
		verifier_egal(Types.type_depuis_nom(nom), -1, "type « %s »" % nom)
		verifier_egal(Types.armure_depuis_nom(nom), -1, "armure « %s »" % nom)
		verifier_egal(Types.rarete_depuis_nom(nom), -1, "rareté « %s »" % nom)
		verifier_egal(Types.ciblage_depuis_nom(nom), -1, "ciblage « %s »" % nom)


func test_types_un_nom_d_une_autre_famille_n_est_pas_reconnu() -> void:
	verifier_egal(Types.type_depuis_nom("légère"), -1)
	verifier_egal(Types.armure_depuis_nom("perçant"), -1)
	verifier_egal(Types.rarete_depuis_nom("plus_proche"), -1)
	verifier_egal(Types.ciblage_depuis_nom("rare"), -1)


# --- StatsTour -------------------------------------------------------------------------------


func test_stats_tour_toutes_les_valeurs_sont_neutres_par_defaut() -> void:
	var s := StatsTour.new()
	verifier_egal(s.degats_type.size(), 5)
	for i in 5:
		verifier_proche(s.degats_type[i], 1.0, 0.0, "multiplicateur type %d" % i)
	verifier_proche(s.degats_global, 1.0)
	verifier_proche(s.revenu_mult, 1.0)
	verifier_proche(s.prime_mult, 1.0)
	var nuls: Array[float] = [
		s.pv_max_bonus,
		s.regen,
		s.armure,
		s.esquive,
		s.epines,
		s.critique_chance,
		s.cadence,
		s.eclaboussure,
		s.focalisation,
		s.vol_de_vie_coup,
		s.vol_de_vie_mort,
		s.revenu_croissant,
	]
	for valeur in nuls:
		verifier_proche(valeur, 0.0)
	var entiers: Array[int] = [
		s.tirs_multiples,
		s.revenu_fixe,
		s.bonus_elim_tous_les,
		s.bonus_elim_or,
		s.relances_gratuites,
		s.marche_noir,
	]
	for entier in entiers:
		verifier_egal(entier, 0)


func test_stats_tour_deux_instances_ne_partagent_pas_leur_tableau() -> void:
	var a := StatsTour.new()
	var b := StatsTour.new()
	a.degats_type[0] = 3.0
	verifier_proche(b.degats_type[0], 1.0)


# --- Données réelles -------------------------------------------------------------------------


func test_les_cinq_fichiers_reels_sont_valides_avec_trois_listes_vides() -> void:
	verifier_egal(Donnees.valider(_brut_listes_vides()), PackedStringArray())


func test_charger_renvoie_une_instance_sur_un_dossier_de_test_avec_les_cinq_fichiers() -> void:
	# Mode « dossier de test » : tout dossier autre que res://data peut omettre les trois
	# fichiers de contenu, lus alors comme des listes vides.
	var brut: Dictionary = {}
	for nom in FICHIERS_REELS:
		brut[nom] = _lire_reel(nom)
	_ecrire_dossier(brut)
	var d := Donnees.charger(DOSSIER_TEST)
	verifier_non_nul(d)
	if d == null:
		return
	verifier_egal(d.armes.size(), 0)
	verifier_egal(d.ameliorations.size(), 0)
	verifier_egal(d.familles.size(), 0)
	verifier_egal(d.ids_catalogue.size(), 0)
	verifier_proche(float(d.partie["rayon_spawn"]), 1300.0)
	verifier_egal(d.efficacite.size(), 5)


func test_charger_lit_aussi_les_trois_fichiers_de_contenu_quand_ils_existent() -> void:
	_ecrire_dossier(_brut_valide())
	var d := Donnees.charger(DOSSIER_TEST)
	verifier_non_nul(d)
	if d == null:
		return
	verifier_egal(d.armes.size(), 2)
	verifier_egal(d.ameliorations.size(), 2)
	verifier_egal(d.familles.size(), 2)
	verifier_egal(d.convoi["id"], "convoi_dore")
	verifier_egal(d.boss["id"], "seigneur_des_cendres")


func test_les_noms_francais_sont_convertis_en_enums_dans_les_donnees_normalisees() -> void:
	var d := Donnees.depuis_brut(_brut_valide())
	verifier_non_nul(d)
	if d == null:
		return
	var arme: Dictionary = d.armes["catapulte_de_siege"]
	verifier_egal(arme["type_degats"], Types.TypeDegats.SIEGE)
	verifier_egal(arme["rarete"], Types.Rarete.RARE)
	verifier_egal(arme["ciblage"], Types.Ciblage.PLUS_PROCHE)
	verifier_egal(arme["portee"], 600)
	verifier_egal(arme["prix"], 900)
	var percante: Dictionary = d.armes["arbalete_percante"]
	verifier_egal(percante["type_degats"], Types.TypeDegats.PERCANT)
	verifier_egal(percante["ciblage"], Types.Ciblage.PLUS_FAIBLE)
	verifier_egal(d.familles[0]["armure"], Types.Armure.LEGERE)
	verifier_egal(d.familles[1]["armure"], Types.Armure.FORTIFIEE)
	verifier_egal(d.familles[1]["volant"], true)
	var amelio: Dictionary = d.ameliorations["lame_aiguisee"]
	verifier_egal(amelio["rarete"], Types.Rarete.COMMUNE)
	var effets: Array = amelio["effets"]
	var effet: Dictionary = effets[0]
	verifier_egal(effet["type_degats"], Types.TypeDegats.TRANCHANT)
	verifier_egal(effet["stat"], "degats_type")


func test_ids_catalogue_reunit_armes_et_ameliorations_tries() -> void:
	var d := Donnees.depuis_brut(_brut_valide())
	verifier_non_nul(d)
	if d == null:
		return
	var attendu := PackedStringArray(
		["arbalete_percante", "catapulte_de_siege", "lame_aiguisee", "prime_de_guerre"]
	)
	verifier_egal(d.ids_catalogue, attendu)


func test_matrice_d_efficacite_entiere_30_cases() -> void:
	var d := Donnees.depuis_brut(_brut_listes_vides())
	verifier_non_nul(d)
	if d == null:
		return
	verifier_egal(d.efficacite.size(), 5)
	var cases := 0
	for t in 5:
		var ligne: Array = d.efficacite[t]
		verifier_egal(ligne.size(), 6)
		for a in 6:
			var double := (
				(t == Types.TypeDegats.TRANCHANT and a == Types.Armure.MOYENNE)
				or (t == Types.TypeDegats.PERCANT and a == Types.Armure.LEGERE)
				or (t == Types.TypeDegats.MAGIQUE and a == Types.Armure.LOURDE)
				or (t == Types.TypeDegats.SIEGE and a == Types.Armure.FORTIFIEE)
			)
			var attendu := 2.0 if double else 1.0
			var nom := "%s contre %s" % [NOMS_TYPES[t], NOMS_ARMURES[a]]
			verifier_proche(float(ligne[a]), attendu, 0.0, nom)
			cases += 1
	verifier_egal(cases, 30)


# --- Mutations : chaque donnée invalide nomme le fichier et le champ ---------------------------
# Entrée : nom, f (fichier), c (chemin), v (nouvelle valeur) ou s (supprimer), champ attendu.


func _mutations() -> Array[Array]:
	var table: Array[Array] = []
	table.append_array(_mutations_partie())
	table.append_array(_mutations_economie_difficulte())
	table.append_array(_mutations_efficacite_boutique())
	table.append_array(_mutations_armes())
	table.append_array(_mutations_ameliorations())
	table.append_array(_mutations_ennemis())
	return table


func _mutations_partie() -> Array[Array]:
	var f := "partie.json"
	return [
		["partie : champ manquant", f, ["rayon_spawn"], SUP, "rayon_spawn"],
		["partie : nombre en chaîne", f, ["preparation_s"], "30", "preparation_s"],
		["partie : ratio de vente négatif", f, ["vente_ratio"], -0.5, "vente_ratio"],
		["partie : ratio de vente > 1", f, ["vente_ratio"], 1.5, "vente_ratio"],
		["partie : NaN", f, ["pas_s"], NAN, "pas_s"],
		["partie : infini", f, ["rayon_spawn"], INF, "rayon_spawn"],
		[
			"partie : moins l'infini",
			f,
			["spawn_baisse_par_manche"],
			-INF,
			"spawn_baisse_par_manche"
		],
		["partie : fraction pour un entier", f, ["manche_boss"], 31.5, "manche_boss"],
		["partie : pas nul", f, ["pas_s"], 0.0, "pas_s"],
		["partie : sous-objet manquant", f, ["tour", "pv"], SUP, "tour.pv"],
		["partie : sous-objet mal typé", f, ["tour"], [], "tour"],
		["partie : vitesses vides", f, ["vitesses_partie"], [], "vitesses_partie"],
		["partie : vitesse en chaîne", f, ["vitesses_partie", 1], "0.66", "vitesses_partie"],
		["partie : plancher > départ", f, ["spawn_plancher"], 5.0, "spawn_plancher"],
		["partie : plafond de givre > 1", f, ["givre", "plafond"], 1.2, "givre.plafond"],
		[
			"partie : probabilité de convoi < 0",
			f,
			["convoi", "probabilite"],
			-0.1,
			"convoi.probabilite"
		],
	]


func _mutations_economie_difficulte() -> Array[Array]:
	var e := "economie.json"
	var d := "difficulte.json"
	return [
		["économie : or en chaîne", e, ["or_depart"], "500", "or_depart"],
		[
			"économie : premier palier ≠ 1",
			e,
			["revenu_base"],
			[{"manche": 2, "valeur": 20}],
			"revenu_base"
		],
		["économie : paliers non triés", e, ["revenu_base"], PALIERS_NON_TRIES, "revenu_base"],
		["économie : manche dupliquée", e, ["prime_mult"], PALIERS_DUPLIQUES, "prime_mult"],
		["économie : valeur négative", e, ["revenu_base", 0, "valeur"], -20, "revenu_base"],
		["économie : table vide", e, ["prime_mult"], [], "prime_mult"],
		["économie : période nulle", e, ["revenu_periode_s"], 0, "revenu_periode_s"],
		["difficulté : paliers sans manche 1", d, ["paliers", 0, "manche"], 3, "paliers"],
		["difficulté : multiplicateur négatif", d, ["paliers", 0, "pv"], -1.0, "paliers"],
		[
			"difficulté : accélérations non triées",
			d,
			["accelerations", 1, "temps_s"],
			100,
			"accelerations"
		],
		["difficulté : après la table négatif", d, ["apres_table", "pv"], -1.0, "apres_table.pv"],
		["difficulté : plancher > 1", d, ["resistance_plancher"], 2.0, "resistance_plancher"],
	]


func _mutations_efficacite_boutique() -> Array[Array]:
	var e := "efficacite.json"
	var b := "boutique.json"
	var zero := {"manche": 1, "commune": 0, "peu_commune": 0, "rare": 0, "epique": 0}
	return [
		["efficacité : ligne manquante", e, ["valeurs"], [[1, 2, 1, 1, 1, 1]], "valeurs"],
		["efficacité : colonne manquante", e, ["valeurs", 0], [1, 2, 1, 1, 1], "valeurs"],
		["efficacité : malus interdit", e, ["valeurs", 0, 0], -1.0, "valeurs"],
		["efficacité : valeur en chaîne", e, ["valeurs", 0, 0], "1", "valeurs"],
		["efficacité : ligne sans accent", e, ["lignes", 1], "percant", "lignes"],
		["efficacité : colonne en majuscules", e, ["colonnes", 0], "LÉGÈRE", "colonnes"],
		[
			"efficacité : lignes en désordre",
			e,
			["lignes"],
			["perçant", "tranchant", "magique", "siège", "chaos"],
			"lignes"
		],
		["boutique : poids tous nuls", b, ["poids"], [zero], "poids"],
		["boutique : poids négatif", b, ["poids", 0, "rare"], -5, "poids"],
		["boutique : poids manquant", b, ["poids", 0, "epique"], SUP, "poids"],
		["boutique : relance négative", b, ["relance", "cout_depart"], -50, "relance.cout_depart"],
		[
			"boutique : rareté max inconnue",
			b,
			["marche_noir", "raretes_max"],
			"légendaire",
			"marche_noir.raretes_max"
		],
	]


func _mutations_armes() -> Array[Array]:
	var f := "armes.json"
	return [
		["armes : rareté inconnue", f, [0, "rarete"], "mythique", "rarete"],
		["armes : rareté en majuscules", f, [0, "rarete"], "RARE", "rarete"],
		["armes : type sans accent", f, [0, "type_degats"], "percant", "type_degats"],
		["armes : type en majuscules", f, [1, "type_degats"], "SIÈGE", "type_degats"],
		["armes : ciblage inconnu", f, [0, "ciblage"], "au_hasard", "ciblage"],
		["armes : kind d'effet inconnu", f, [0, "effets", 0, "kind"], "laser", "kind"],
		["armes : kind de statut inconnu", f, [1, "statuts", 0, "kind"], "malediction", "kind"],
		["armes : id dupliqué", f, [1, "id"], "arbalete_percante", "id"],
		["armes : id vide", f, [0, "id"], "", "id"],
		["armes : portée hors paliers", f, [0, "portee"], 500, "portee"],
		["armes : portée en chaîne", f, [0, "portee"], "600", "portee"],
		["armes : rebond < 4", f, [1, "effets", 0, "cibles"], 3, "cibles"],
		["armes : rebond > 8", f, [1, "effets", 0, "cibles"], 9, "cibles"],
		[
			"armes : décroissance manquante",
			f,
			[1, "effets", 0, "decroissance"],
			SUP,
			"decroissance"
		],
		["armes : prix en chaîne", f, [0, "prix"], "300", "prix"],
		["armes : dégâts négatifs", f, [0, "degats"], -1.0, "degats"],
		["armes : recharge nulle", f, [0, "recharge"], 0.0, "recharge"],
		["armes : dégâts NaN", f, [0, "degats"], NAN, "degats"],
		["armes : effets vides", f, [0, "effets"], [], "effets"],
		["armes : nom manquant", f, [1, "nom"], SUP, "nom"],
		["armes : élément non objet", f, [0], 7, "[0]"],
		["armes : vol de vie négatif", f, [1, "statuts", 1, "ratio"], -0.05, "ratio"],
	]


func _mutations_ameliorations() -> Array[Array]:
	var f := "ameliorations.json"
	return [
		["améliorations : stat inconnue", f, [0, "effets", 0, "stat"], "magie_noire", "stat"],
		["améliorations : catégorie inconnue", f, [0, "effets", 0, "categorie"], "D", "categorie"],
		[
			"améliorations : type inconnu",
			f,
			[0, "effets", 0, "type_degats"],
			"tranchante",
			"type_degats"
		],
		["améliorations : rareté inconnue", f, [1, "rarete"], "unique", "rarete"],
		["améliorations : id pris par une arme", f, [0, "id"], "catapulte_de_siege", "id"],
		["améliorations : id dupliqué", f, [1, "id"], "lame_aiguisee", "id"],
		["améliorations : valeur en chaîne", f, [0, "effets", 0, "valeur"], "0.1", "valeur"],
		["améliorations : valeur infinie", f, [0, "effets", 0, "valeur"], INF, "valeur"],
		["améliorations : tous_les manquant", f, [1, "effets", 0, "tous_les"], SUP, "tous_les"],
		["améliorations : tous_les à 0", f, [1, "effets", 0, "tous_les"], 0, "tous_les"],
		["améliorations : effets vides", f, [0, "effets"], [], "effets"],
	]


func _mutations_ennemis() -> Array[Array]:
	var f := "ennemis.json"
	return [
		["ennemis : armure en majuscule", f, ["familles", 0, "armure"], "Légère", "armure"],
		["ennemis : armure sans accent", f, ["familles", 1, "armure"], "fortifiee", "armure"],
		["ennemis : id dupliqué", f, ["familles", 1, "id"], "rampant", "id"],
		["ennemis : id du convoi pris", f, ["convoi", "id"], "rampant", "convoi.id"],
		["ennemis : boss sans id", f, ["boss", "id"], SUP, "boss.id"],
		["ennemis : PV nuls", f, ["familles", 0, "pv"], 0, "pv"],
		["ennemis : volant en chaîne", f, ["familles", 0, "volant"], "non", "volant"],
		["ennemis : prime négative", f, ["familles", 0, "prime"], -2, "prime"],
		["ennemis : portée manquante", f, ["familles", 0, "portee_attaque"], SUP, "portee_attaque"],
		["ennemis : vitesse infinie", f, ["convoi", "vitesse"], INF, "convoi.vitesse"],
	]


## Entrée de mutation : [nom, fichier, chemin, valeur (ou SUP), champ attendu dans le message].
func _muter_entree(base: Dictionary, m: Array) -> Dictionary:
	var fichier: String = m[1]
	var chemin: Array = m[2]
	var valeur: Variant = m[3]
	return _muter(base, fichier, chemin, valeur, typeof(valeur) == TYPE_STRING_NAME)


func test_le_jeu_valide_de_reference_ne_produit_aucune_erreur() -> void:
	# Contrôle négatif : sans lui, la table de mutations pourrait échouer pour une autre raison.
	verifier_egal(Donnees.valider(_brut_valide()), PackedStringArray())


func test_chaque_mutation_est_refusee_avec_le_fichier_et_le_champ() -> void:
	var base := _brut_valide()
	var table := _mutations()
	verifier(table.size() >= 80, "la table de mutations doit rester complète")
	for m in table:
		var nom: String = m[0]
		var fichier: String = m[1]
		var champ: String = m[4]
		var messages := Donnees.valider(_muter_entree(base, m))
		verifier(
			_un_message_nomme(messages, fichier, champ),
			"%s : attendu « %s: … %s … », reçu %s" % [nom, fichier, champ, messages]
		)
		# Une seule cause injectée : aucun autre fichier ne doit être accusé.
		for message in messages:
			verifier(message.begins_with(fichier + ": "), "%s : hors fichier : %s" % [nom, message])


func test_chaque_mutation_fait_echouer_depuis_brut_sans_planter() -> void:
	var base := _brut_valide()
	for m in _mutations():
		var mutee := _muter_entree(base, m)
		var fichier: String = m[1]
		# depuis_brut journalise chaque erreur : une déclaration par message.
		for i in Donnees.valider(mutee).size():
			attendre_erreur(fichier)
		verifier_nul(Donnees.depuis_brut(mutee), m[0])


func test_fichier_absent_du_jeu_est_signale_pour_chacun_des_huit() -> void:
	var base := _brut_valide()
	for nom: String in base:
		var brut: Dictionary = base.duplicate(true)
		brut.erase(nom)
		var messages := Donnees.valider(brut)
		verifier(_un_message_nomme(messages, nom, "absent"), "%s : %s" % [nom, messages])


func test_racine_tableau_au_lieu_d_objet_est_refusee_pour_chaque_fichier_objet() -> void:
	var base := _brut_valide()
	var objets: Array[String] = [
		"partie.json",
		"economie.json",
		"difficulte.json",
		"efficacite.json",
		"boutique.json",
		"ennemis.json"
	]
	for nom in objets:
		var brut: Dictionary = base.duplicate(true)
		brut[nom] = []
		var messages := Donnees.valider(brut)
		verifier(_un_message_nomme(messages, nom, "objet"), "%s : %s" % [nom, messages])


func test_racine_objet_au_lieu_de_tableau_est_refusee_pour_armes_et_ameliorations() -> void:
	var base := _brut_valide()
	for nom: String in ["armes.json", "ameliorations.json"]:
		var brut: Dictionary = base.duplicate(true)
		brut[nom] = {}
		var messages := Donnees.valider(brut)
		verifier(_un_message_nomme(messages, nom, "tableau"), "%s : %s" % [nom, messages])


func test_valider_ne_modifie_pas_son_entree() -> void:
	var base := _brut_valide()
	var copie: Dictionary = base.duplicate(true)
	Donnees.valider(base)
	verifier_egal(base, copie)


# --- Chargement depuis le disque -------------------------------------------------------------


func test_charger_refuse_un_json_malforme_en_nommant_le_fichier() -> void:
	var brut := _brut_valide()
	brut["partie.json"] = '{"pas_s": 0.05,'
	_ecrire_dossier(brut)
	attendre_erreur("partie.json")
	verifier_nul(Donnees.charger(DOSSIER_TEST))


func test_charger_refuse_nan_et_infini_ecrits_dans_le_json() -> void:
	# Le parseur de Godot refuse « NaN » ; « 1e999 » passe en infini et doit être refusé ensuite.
	for litteral: String in ["NaN", "Infinity", "-Infinity", "1e999"]:
		var partie_json := JSON.stringify(_lire_reel("partie.json"))
		var texte := partie_json.replace('"pas_s":0.05', '"pas_s":' + litteral)
		var brut := _brut_valide()
		brut["partie.json"] = texte
		_ecrire_dossier(brut)
		attendre_erreur("partie.json")
		verifier_nul(Donnees.charger(DOSSIER_TEST), litteral)
		_nettoyer_dossier()


func test_charger_refuse_une_racine_tableau() -> void:
	var brut := _brut_valide()
	brut["economie.json"] = "[]"
	_ecrire_dossier(brut)
	attendre_erreur("economie.json")
	verifier_nul(Donnees.charger(DOSSIER_TEST))


func test_charger_refuse_un_nombre_ecrit_en_chaine() -> void:
	var partie: Dictionary = _lire_reel("partie.json")
	partie["preparation_s"] = "30"
	var brut := _brut_valide()
	brut["partie.json"] = partie
	_ecrire_dossier(brut)
	attendre_erreur("preparation_s")
	verifier_nul(Donnees.charger(DOSSIER_TEST))


func test_charger_signale_un_fichier_obligatoire_absent() -> void:
	var brut := _brut_valide()
	brut.erase("boutique.json")
	_ecrire_dossier(brut)
	attendre_erreur("boutique.json")
	verifier_nul(Donnees.charger(DOSSIER_TEST))


func test_charger_signale_un_dossier_inexistant() -> void:
	# Cinq fichiers obligatoires manquants : un message par fichier.
	for nom in FICHIERS_REELS:
		attendre_erreur(nom)
	verifier_nul(Donnees.charger("user://dossier_qui_n_existe_pas"))


# --- palier() --------------------------------------------------------------------------------


func test_palier_aux_bornes_et_entre_deux_paliers() -> void:
	var d := Donnees.depuis_brut(_brut_listes_vides())
	verifier_non_nul(d)
	if d == null:
		return
	var table: Array = [
		{"manche": 1, "valeur": 20.0},
		{"manche": 6, "valeur": 30.0},
		{"manche": 11, "valeur": 45.0},
	]
	verifier_proche(d.palier(table, 1, "valeur"), 20.0, 0.0, "manche 1")
	verifier_proche(d.palier(table, 5, "valeur"), 20.0, 0.0, "juste avant un palier")
	verifier_proche(d.palier(table, 6, "valeur"), 30.0, 0.0, "pile sur un palier")
	verifier_proche(d.palier(table, 8, "valeur"), 30.0, 0.0, "entre deux paliers")
	verifier_proche(d.palier(table, 11, "valeur"), 45.0, 0.0, "dernier palier")
	verifier_proche(d.palier(table, 500, "valeur"), 45.0, 0.0, "au-delà du dernier")
	verifier_proche(d.palier(table, 0, "valeur"), 20.0, 0.0, "préparation : premier palier")


func test_palier_sur_les_tables_reelles_de_chaque_fichier() -> void:
	var d := Donnees.depuis_brut(_brut_listes_vides())
	verifier_non_nul(d)
	if d == null:
		return
	var revenu: Array = d.economie["revenu_base"]
	verifier_proche(d.palier(revenu, 1, "valeur"), 20.0)
	verifier_proche(d.palier(revenu, 6, "valeur"), 30.0)
	var prime: Array = d.economie["prime_mult"]
	verifier_proche(d.palier(prime, 9, "valeur"), 1.0)
	verifier_proche(d.palier(prime, 10, "valeur"), 1.5)
	var diff: Array = d.difficulte["paliers"]
	verifier_proche(d.palier(diff, 3, "pv"), 1.0)
	var poids: Array = d.boutique["poids"]
	verifier_proche(d.palier(poids, 1, "commune"), 70.0)


func test_palier_sur_table_vide_ou_cle_inconnue_signale_sans_planter() -> void:
	var d := Donnees.depuis_brut(_brut_listes_vides())
	verifier_non_nul(d)
	if d == null:
		return
	attendre_erreur("palier")
	verifier_proche(d.palier([], 3, "valeur"), 0.0)
	attendre_erreur("palier")
	verifier_proche(d.palier([{"manche": 1, "valeur": 2.0}], 3, "absente"), 0.0)


# --- Empreinte -------------------------------------------------------------------------------


func test_deux_chargements_donnent_la_meme_empreinte() -> void:
	_ecrire_dossier(_brut_valide())
	var a := Donnees.charger(DOSSIER_TEST)
	var b := Donnees.charger(DOSSIER_TEST)
	verifier_non_nul(a)
	verifier_non_nul(b)
	if a == null or b == null:
		return
	verifier_egal(a.empreinte, b.empreinte)
	verifier_different(a.empreinte, 0)


func test_charger_et_depuis_brut_donnent_la_meme_empreinte() -> void:
	var brut := _brut_valide()
	_ecrire_dossier(brut)
	var chargee := Donnees.charger(DOSSIER_TEST)
	var memoire := Donnees.depuis_brut(brut)
	verifier_non_nul(chargee)
	verifier_non_nul(memoire)
	if chargee == null or memoire == null:
		return
	verifier_egal(chargee.empreinte, memoire.empreinte)


func test_une_valeur_modifiee_change_l_empreinte_dans_chacun_des_huit_fichiers() -> void:
	var base := _brut_valide()
	var ref := Donnees.depuis_brut(base)
	verifier_non_nul(ref)
	if ref == null:
		return
	var modifs: Array[Array] = [
		["", "partie.json", ["rayon_spawn"], 1301, ""],
		["", "economie.json", ["or_depart"], 501, ""],
		["", "difficulte.json", ["resistance_plancher"], 0.2, ""],
		["", "efficacite.json", ["valeurs", 0, 0], 1.5, ""],
		["", "boutique.json", ["relance", "increment"], 26, ""],
		["", "armes.json", [0, "degats"], 12.5, ""],
		["", "ameliorations.json", [0, "prix"], 151, ""],
		["", "ennemis.json", ["boss", "pv"], 20001, ""],
	]
	for m in modifs:
		var autre := Donnees.depuis_brut(_muter_entree(base, m))
		var fichier: String = m[1]
		verifier_non_nul(autre, fichier)
		if autre != null:
			verifier_different(autre.empreinte, ref.empreinte, fichier)


func test_l_empreinte_ignore_la_mise_en_forme_du_fichier() -> void:
	var brut := _brut_valide()
	var a := Donnees.depuis_brut(brut)
	var reformate: Dictionary = brut.duplicate(true)
	reformate["partie.json"] = JSON.parse_string(JSON.stringify(brut["partie.json"], "\t", true))
	var b := Donnees.depuis_brut(reformate)
	verifier_non_nul(a)
	verifier_non_nul(b)
	if a == null or b == null:
		return
	verifier_egal(a.empreinte, b.empreinte)
