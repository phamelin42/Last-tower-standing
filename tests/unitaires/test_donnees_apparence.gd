extends CasDeTest
## `data/apparence_tour.json` : les seuils d'apparence de la tour (sept statistiques, trois paliers
## nets chacune) et l'agrandissement de la tour. Le fichier réel est valide ; une table mal formée
## est refusée au chargement. Les tests bouclent sur les données, aucun seuil n'est figé ici.

const FICHIER := "apparence_tour.json"
const STATS: Array[String] = [
	"epines", "pv_max", "mana", "armure", "esquive", "regen", "vol_de_vie"
]
const AGRANDISSEMENT_MAX := 0.25


func _brut() -> Dictionary:
	return AidesPartie.brut()


func _table(brut: Dictionary) -> Dictionary:
	return brut[FICHIER]


func _erreurs(brut: Dictionary) -> PackedStringArray:
	return Donnees.valider(brut)


func test_le_fichier_reel_est_valide_et_charge_dans_les_donnees() -> void:
	verifier_egal(_erreurs(_brut()), PackedStringArray())
	var d := Donnees.charger()
	verifier_non_nul(d)
	if d != null:
		verifier(d.apparence_tour.has("stats") and d.apparence_tour.has("agrandissement"))


func test_chaque_statistique_a_trois_seuils_strictement_croissants() -> void:
	var d := Donnees.charger()
	var stats: Dictionary = d.apparence_tour["stats"]
	verifier_egal(stats.size(), STATS.size())
	for nom: String in STATS:
		verifier(stats.has(nom), "statistique %s présente" % nom)
		var seuils: Array = stats[nom]
		verifier_egal(seuils.size(), 3, nom)
		for i: int in range(1, seuils.size()):
			verifier(float(seuils[i]) > float(seuils[i - 1]), "%s : seuil %d croissant" % [nom, i])
		verifier(float(seuils[0]) > 0.0, "%s : le premier seuil est positif" % nom)


func test_un_seuil_non_croissant_non_fini_ou_manquant_est_refuse() -> void:
	for nom: String in STATS:
		var mutations: Array[Array] = [
			[[3.0, 2.0, 5.0], "non croissant"],
			[[1.0, 1.0, 5.0], "égaux"],
			[[1.0, 2.0], "manquant"],
			[[1.0, 2.0, 3.0, 4.0], "en trop"],
			[[1.0, NAN, 3.0], "NaN"],
			[[1.0, 2.0, INF], "infini"],
			[[1.0, 2.0, "3"], "texte"],
			[[], "vide"],
		]
		for m: Array in mutations:
			var brut := _brut()
			var stats: Dictionary = _table(brut)["stats"]
			stats[nom] = m[0]
			verifier(not _erreurs(brut).is_empty(), "%s : %s refusé" % [nom, m[1]])
		var brut_absent := _brut()
		var stats_absentes: Dictionary = _table(brut_absent)["stats"]
		stats_absentes.erase(nom)
		verifier(not _erreurs(brut_absent).is_empty(), "%s manquante refusée" % nom)


func test_une_statistique_inconnue_est_refusee() -> void:
	var brut := _brut()
	var stats: Dictionary = _table(brut)["stats"]
	stats["charisme"] = [1.0, 2.0, 3.0]
	verifier(not _erreurs(brut).is_empty())


func test_l_agrandissement_est_borne_a_25_pour_cent_et_croissant() -> void:
	var d := Donnees.charger()
	var paliers: Array = d.apparence_tour["agrandissement"]
	verifier_egal(paliers.size(), 3)
	for i: int in paliers.size():
		verifier(
			float(paliers[i]) > 0.0 and float(paliers[i]) <= AGRANDISSEMENT_MAX, "palier %d" % i
		)
		if i > 0:
			verifier(float(paliers[i]) > float(paliers[i - 1]), "croissant au palier %d" % i)
	var refus: Array[Array] = [
		[[0.05, 0.1, 0.26], "0,26"],
		[[0.1, 0.05, 0.2], "décroissant"],
		[[0.1, 0.1, 0.2], "égaux"],
		[[0.1, 0.2], "manquant"],
		[[0.1, NAN, 0.2], "NaN"],
		[[-0.1, 0.1, 0.2], "négatif"],
	]
	for m: Array in refus:
		var brut := _brut()
		_table(brut)["agrandissement"] = m[0]
		verifier(not _erreurs(brut).is_empty(), "%s refusé" % m[1])
	var limite := _brut()
	_table(limite)["agrandissement"] = [0.1, 0.2, 0.25]
	verifier_egal(_erreurs(limite), PackedStringArray(), "0,25 exactement est accepté")


func test_une_table_absente_ou_mal_typee_est_refusee() -> void:
	for cle: String in ["stats", "agrandissement"]:
		var brut := _brut()
		_table(brut).erase(cle)
		verifier(not _erreurs(brut).is_empty(), "%s absente" % cle)
	var brut2 := _brut()
	brut2[FICHIER] = []
	verifier(not _erreurs(brut2).is_empty(), "racine mal typée")


func test_le_fichier_n_entre_pas_dans_l_empreinte_reseau() -> void:
	var a := Donnees.depuis_brut(_brut())
	var brut := _brut()
	var stats: Dictionary = _table(brut)["stats"]
	stats["armure"] = [1.0, 2.0, 3.0]
	var b := Donnees.depuis_brut(brut)
	verifier_egal(a.empreinte, b.empreinte, "l'apparence est locale")


func test_le_dessin_a_son_dossier_son_fondu_son_esquive_et_son_animation() -> void:
	var d := Donnees.charger()
	var t: Dictionary = d.apparence_tour
	verifier(String(t["dossier"]).ends_with("/"), "dossier")
	verifier(float(t["fondu_s"]) > 0.0, "fondu")
	var esquive: Dictionary = t["esquive"]
	verifier(float(esquive["periode_s"]) >= 1.0 / 3.0, "au plus trois éclairs par seconde")
	verifier(float(esquive["duree_s"]) < float(esquive["periode_s"]), "l'esquive s'éteint")
	var animation: Dictionary = t["animation"]
	verifier(float(animation["par_seconde"]) <= 3.0, "au plus trois images par seconde")
	# Chaque image du tour lent annoncée existe, pour les deux couches des deux statistiques.
	for stat: String in ["epines", "vol_de_vie"]:
		for couche: String in ["arriere", "avant"]:
			for k: int in int(animation["images"]):
				var chemin := Apparence.fichier_superposition(
					String(t["dossier"]), stat, 3, couche, k
				)
				verifier(FileAccess.file_exists(chemin), "image présente : %s" % chemin)


func test_un_reglage_de_dessin_mal_forme_est_refuse() -> void:
	var refus: Array[Array] = [
		["dossier", "sans_barre", "dossier sans « / »"],
		["dossier", 3.0, "dossier mal typé"],
		["fondu_s", 0.0, "fondu nul"],
		["fondu_s", NAN, "fondu non fini"],
		["fondu_s", 10.0, "fondu trop long"],
		["esquive", {"periode_s": 0.2, "duree_s": 0.1}, "plus de trois éclairs par seconde"],
		["esquive", {"periode_s": 2.0, "duree_s": 2.0}, "durée égale à la période"],
		["esquive", {"periode_s": 2.0}, "durée manquante"],
		["animation", {"images": 0, "par_seconde": 1.0}, "aucune image"],
		["animation", {"images": 99, "par_seconde": 1.0}, "trop d'images"],
		["animation", {"images": 4, "par_seconde": 4.0}, "plus de trois images par seconde"],
		["animation", {"images": 4}, "rythme manquant"],
	]
	for r: Array in refus:
		var brut := _brut()
		_table(brut)[r[0]] = r[1]
		verifier(not _erreurs(brut).is_empty(), "%s refusé" % r[2])
	for cle: String in ["dossier", "fondu_s", "esquive", "animation"]:
		var brut := _brut()
		_table(brut).erase(cle)
		verifier(not _erreurs(brut).is_empty(), "%s manquant refusé" % cle)
