extends CasDeTest
## Garde de l'équilibrage : un joueur qui ne fait rien doit tomber tôt, un joueur raisonnable doit
## aller loin. Les seuils sont bien en deçà de la cible mesurée par `tools/equilibrage.gd` (passif
## vers la manche 5, raisonnable vers la 19) : ils attrapent une régression franche, pas un réglage
## fin. Le détail chiffré est dans `docs/equilibrage.md`.

const GRAINES: Array[int] = [1, 2, 3, 4, 5]
const MANCHE_MEDIANE_RAISONNABLE_MIN := 12
const MANCHE_PASSIVE_MAX := 3
## Une graine isolée peut tomber tôt sur un tirage de boutique pauvre : on garde la médiane.
const MANCHE_ACHAT_MEDIANE := 8
const GRAINES_SEUIL_BAS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
## Robot de référence (« bonne ») : la conception veut qu'il ne tombe pas avant la manche 20.
## Mesuré sur les graines 1 à 10 avec le catalogue de 75 armes (docs/equilibrage.md) : toutes les
## graines atteignent la 20.
const MANCHE_REFERENCE := 20


func _manches(strategie: String) -> Array[int]:
	var d := AidesPartie.donnees()
	var manches: Array[int] = []
	for graine: int in GRAINES:
		var r := SimulationEquilibrage.jouer(d, graine, strategie, MANCHE_MEDIANE_RAISONNABLE_MIN)
		manches.append(int(r["manche"]))
	manches.sort()
	return manches


func test_sans_achat_la_tour_tombe_avant_la_fin_de_la_manche_3() -> void:
	var d := AidesPartie.donnees()
	for graine: int in GRAINES_SEUIL_BAS:
		var r := SimulationEquilibrage.jouer(d, graine, StrategiesJoueur.PASSIVE, 0)
		verifier(
			int(r["manche"]) <= MANCHE_PASSIVE_MAX and not bool(r["victoire"]),
			"graine %d : le joueur passif a tenu jusqu'à la manche %d" % [graine, int(r["manche"])]
		)


func test_pv_et_degats_des_ennemis_augmentent_a_chaque_manche() -> void:
	var d := AidesPartie.donnees()
	for temps: float in [0.0]:
		for manche: int in range(1, 41):
			var a := Planning.multiplicateurs(d, manche, temps)
			var b := Planning.multiplicateurs(d, manche + 1, temps)
			verifier(
				float(b["pv"]) > float(a["pv"]),
				"PV : la manche %d ne dépasse pas la %d (temps %s)" % [manche + 1, manche, temps]
			)
			verifier(
				float(b["degats"]) > float(a["degats"]),
				(
					"dégâts : la manche %d ne dépasse pas la %d (temps %s)"
					% [manche + 1, manche, temps]
				)
			)


func test_la_force_d_une_meme_famille_augmente_a_chaque_manche() -> void:
	var d := AidesPartie.donnees()
	for famille: Dictionary in d.familles:
		var premiere := maxi(int(famille["manche_entree"]), int(famille["manche_min"]))
		var pv_avant := -1.0
		var degats_avant := -1.0
		for manche: int in range(premiere, 41):
			var m := Planning.multiplicateurs(d, manche, 0.0)
			var pv := float(famille["pv"]) * float(m["pv"])
			var degats := float(famille["degats"]) * float(m["degats"])
			verifier(
				pv > pv_avant, "%s : PV non croissants à la manche %d" % [famille["id"], manche]
			)
			verifier(
				degats > degats_avant,
				"%s : dégâts non croissants à la manche %d" % [famille["id"], manche]
			)
			pv_avant = pv
			degats_avant = degats


func test_un_robot_qui_achete_survit_a_la_manche_du_joueur_passif_sur_la_plupart_des_graines(
) -> void:
	var d := AidesPartie.donnees()
	for strategie: String in [StrategiesJoueur.RAISONNABLE, StrategiesJoueur.BONNE]:
		var manches: Array[int] = []
		for graine: int in GRAINES_SEUIL_BAS:
			var r := SimulationEquilibrage.jouer(d, graine, strategie, MANCHE_ACHAT_MEDIANE)
			manches.append(int(r["manche"]))
		manches.sort()
		verifier(
			manches[0] > MANCHE_PASSIVE_MAX,
			(
				"%s : tombé en manche %d, comme le joueur passif (manches %s)"
				% [strategie, manches[0], manches]
			)
		)
		verifier(
			manches[manches.size() / 2] >= MANCHE_ACHAT_MEDIANE,
			(
				"%s : médiane %d sous %d (manches %s)"
				% [strategie, manches[manches.size() / 2], MANCHE_ACHAT_MEDIANE, manches]
			)
		)


func test_un_joueur_raisonnable_atteint_au_moins_la_manche_douze_en_mediane() -> void:
	var manches := _manches(StrategiesJoueur.RAISONNABLE)
	var mediane := manches[manches.size() / 2]
	verifier(
		mediane >= MANCHE_MEDIANE_RAISONNABLE_MIN,
		"médiane %d (manches %s) sous %d" % [mediane, manches, MANCHE_MEDIANE_RAISONNABLE_MIN]
	)


func _fichiers_texte(dossier: String) -> Array[String]:
	var fichiers: Array[String] = []
	for nom: String in DirAccess.get_files_at(dossier):
		if nom.ends_with(".gd") or nom.ends_with(".json"):
			fichiers.append(dossier.path_join(nom))
	for sous: String in DirAccess.get_directories_at(dossier):
		fichiers.append_array(_fichiers_texte(dossier.path_join(sous)))
	return fichiers


func test_emplacements_armes_n_est_plus_lu_nulle_part() -> void:
	var cle := "emplacements" + "_armes"
	var fichiers: Array[String] = ["res://data/partie.json"]
	for dossier: String in ["res://sim", "res://ui", "res://app", "res://reseau"]:
		fichiers.append_array(_fichiers_texte(dossier))
	verifier(fichiers.size() > 10, "aucun fichier à examiner")
	for chemin: String in fichiers:
		verifier(
			not FileAccess.get_file_as_string(chemin).contains(cle),
			"%s mentionne encore %s" % [chemin, cle]
		)


func test_le_robot_de_reference_n_est_pas_elimine_avant_la_manche_20() -> void:
	var d := AidesPartie.donnees()
	for graine: int in GRAINES_SEUIL_BAS:
		var r := SimulationEquilibrage.jouer(d, graine, StrategiesJoueur.BONNE, MANCHE_REFERENCE)
		verifier(
			int(r["manche"]) >= MANCHE_REFERENCE,
			"bonne, graine %d : tombé à la manche %d" % [graine, int(r["manche"])]
		)
