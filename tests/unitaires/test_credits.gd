extends CasDeTest
## Les crédits (T11.9) : chaque source tierce qui exige un crédit ou une citation figure dans
## `CREDITS.md` : les auteurs CC-BY des skins, ceux des icônes de repères, chaque pack de sons
## cité dans `assets/sons/SOURCES.md`, et rien de la map d'origine dans les textes du lot 11.

const CREDITS := "res://CREDITS.md"
const SOURCES_TOURS := "res://assets/tours/SOURCES.md"
const SOURCES_SONS := "res://assets/sons/SOURCES.md"
const LICENCE_ICONES := "res://assets/icones/game_icons/LICENCE.md"
const FICHIERS_DU_LOT: Array[String] = [
	"res://data/defis.json", "res://data/skins_tour.json", "res://i18n/textes_progression.csv"
]


func _lire(chemin: String) -> String:
	return FileAccess.get_file_as_string(chemin)


## Les lignes du tableau de `assets/tours/SOURCES.md` : `[fichier, auteur, licence]`.
func _lignes_tours() -> Array[PackedStringArray]:
	var sortie: Array[PackedStringArray] = []
	for ligne: String in _lire(SOURCES_TOURS).split("\n"):
		if not ligne.begins_with("| `"):
			continue
		var cases := ligne.split("|")
		sortie.append(
			PackedStringArray(
				[cases[1].strip_edges(), cases[2].strip_edges(), cases[3].strip_edges()]
			)
		)
	return sortie


## Les noms d'un auteur de la colonne « Auteur » (`Snabisch (Catapult)` → `Snabisch`).
func _noms(auteur: String) -> PackedStringArray:
	var sortie := PackedStringArray()
	for morceau: String in auteur.split(","):
		var nom := morceau.split("(")[0].strip_edges()
		if not nom.is_empty():
			sortie.append(nom)
	return sortie


func test_chaque_source_cc_by_des_skins_est_creditee_dans_credits_md() -> void:
	var credits := _lire(CREDITS)
	var lignes := _lignes_tours()
	verifier(lignes.size() >= 30, "le tableau des sprites se lit (%d lignes)" % lignes.size())
	var cc_by := 0
	for ligne: PackedStringArray in lignes:
		if not ligne[2].begins_with("CC-BY"):
			verifier(ligne[2].begins_with("CC0"), "%s : licence connue (%s)" % [ligne[0], ligne[2]])
			continue
		cc_by += 1
		verifier(credits.contains("CC BY 3.0"), "la licence CC BY 3.0 est citée")
		for nom: String in _noms(ligne[1]):
			verifier(credits.contains(nom), "%s : l'auteur « %s » est crédité" % [ligne[0], nom])
	verifier(cc_by > 0, "des sprites CC-BY existent")


func test_chaque_licence_des_skins_des_donnees_est_creditee() -> void:
	var donnees := Donnees.charger()
	var credits := _lire(CREDITS)
	for id: String in donnees.skins_tour:
		var skin: Dictionary = donnees.skins_tour[id]
		if str(skin["sprite"]).begins_with("res://assets/tours/"):
			var licence := str(skin["licence"]).replace("-", " ")
			verifier(credits.contains(licence), "%s : licence « %s » citée" % [id, licence])


func test_les_auteurs_des_icones_de_reperes_sont_credites() -> void:
	var credits := _lire(CREDITS)
	var licence := _lire(LICENCE_ICONES)
	for auteur: String in ["Lorc", "Delapouite"]:
		verifier(licence.contains(auteur), "%s : cité dans la licence des icônes" % auteur)
		verifier(credits.contains(auteur), "%s : crédité" % auteur)
	verifier(credits.contains("game-icons.net"), "la source est nommée")


func test_chaque_pack_de_sons_cite_dans_sources_est_dans_credits() -> void:
	var credits := _lire(CREDITS)
	var pages := RegEx.create_from_string("https://opengameart\\.org/content/[a-z0-9-]+")
	var vues := 0
	for correspondance: RegExMatch in pages.search_all(_lire(SOURCES_SONS)):
		vues += 1
		var url := correspondance.get_string()
		verifier(credits.contains(url), "pack de sons %s dans CREDITS.md" % url)
	verifier(vues >= 7, "les packs de sons se lisent (%d)" % vues)


func test_aucun_nom_d_origine_dans_les_defis_les_skins_et_les_textes() -> void:
	var noms := PackedStringArray()
	for nom: String in NomsOrigine.lire():
		if not NomsOrigine.HOMOGRAPHES_FRANCAIS.has(nom):
			noms.append(nom)
	verifier(noms.size() > 50, "la liste des noms de la map se lit (%d)" % noms.size())
	for chemin: String in FICHIERS_DU_LOT:
		var texte := _lire(chemin)
		verifier(texte.length() > 100, "%s : texte lu" % chemin)
		var trouves := NomsOrigine.trouver(texte, noms)
		verifier(trouves.is_empty(), "%s : contient %s" % [chemin, trouves])
