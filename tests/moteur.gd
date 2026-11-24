class_name MoteurDeTests
extends RefCounted
## Découvre et exécute les fichiers de tests. Ne plante jamais sur un test cassé :
## tout problème devient un échec rapporté, et les fichiers suivants sont lancés.

const SEGMENT_CONTROLE := "/controle/"


## Chemins des `test_*.gd` de `dossier`, triés. Le dossier `controle/` n'est
## visible qu'en mode contrôle (et alors il est le seul). Le filtre garde un
## fichier dont le nom, ou dont une méthode `test_*`, contient le motif.
func decouvrir(dossier: String, filtre: String, controle: bool) -> PackedStringArray:
	var tous := PackedStringArray()
	_collecter(dossier, tous)
	var gardes := PackedStringArray()
	for chemin: String in tous:
		if (SEGMENT_CONTROLE in chemin) != controle:
			continue
		if not filtre.is_empty() and not _correspond(chemin, filtre):
			continue
		gardes.append(chemin)
	gardes.sort()
	return gardes


## Exécute les fichiers. Retourne {tests, echecs, assertions, lignes}.
## Un test = une méthode `test_*` ; un fichier inutilisable compte pour un test échoué.
func executer(chemins: PackedStringArray, filtre: String, arbre: SceneTree) -> Dictionary:
	var bilan := {"tests": 0, "echecs": 0, "assertions": 0, "lignes": PackedStringArray()}
	for chemin: String in chemins:
		_executer_fichier(chemin, filtre, arbre, bilan)
	return bilan


## 0 si tout est bon ; en mode contrôle, 0 seulement si CHAQUE test a échoué
## (et qu'il y en avait au moins un) : c'est la preuve que les échecs sont détectés.
func code_de_sortie(bilan: Dictionary, controle: bool) -> int:
	var tests: int = bilan["tests"]
	var echecs: int = bilan["echecs"]
	if controle:
		return 0 if tests > 0 and echecs == tests else 1
	return 0 if echecs == 0 else 1


func _collecter(dossier: String, sortie: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(dossier):
		return
	for fichier: String in DirAccess.get_files_at(dossier):
		if fichier.begins_with("test_") and fichier.ends_with(".gd"):
			sortie.append(dossier.path_join(fichier))
	for sous: String in DirAccess.get_directories_at(dossier):
		_collecter(dossier.path_join(sous), sortie)


func _correspond(chemin: String, filtre: String) -> bool:
	if filtre in chemin.get_file():
		return true
	for nom: String in _methodes_du_source(chemin):
		if filtre in nom:
			return true
	return false


func _methodes_du_source(chemin: String) -> PackedStringArray:
	var noms := PackedStringArray()
	for ligne: String in FileAccess.get_file_as_string(chemin).split("\n"):
		if ligne.begins_with("func test_"):
			noms.append(ligne.trim_prefix("func ").get_slice("(", 0))
	return noms


func _echec_fichier(chemin: String, raison: String, bilan: Dictionary) -> void:
	bilan["tests"] += 1
	bilan["echecs"] += 1
	var lignes: PackedStringArray = bilan["lignes"]
	lignes.append("ECHEC %s — %s" % [chemin, raison])


func _executer_fichier(chemin: String, filtre: String, arbre: SceneTree, bilan: Dictionary) -> void:
	if not FileAccess.file_exists(chemin):
		_echec_fichier(chemin, "fichier absent", bilan)
		return
	var script := ResourceLoader.load(chemin, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	if script == null or not script.can_instantiate():
		_echec_fichier(
			chemin, "script impossible à charger (erreur d'analyse ou fichier absent)", bilan
		)
		return
	var sonde: Variant = script.new()
	if not sonde is CasDeTest:
		_echec_fichier(chemin, "la classe doit étendre CasDeTest", bilan)
		return
	for nom: String in _methodes_a_lancer(script, chemin, filtre):
		_executer_methode(script, chemin, nom, arbre, bilan)


func _methodes_a_lancer(script: GDScript, chemin: String, filtre: String) -> PackedStringArray:
	var noms := PackedStringArray()
	for methode: Dictionary in script.get_script_method_list():
		var nom: String = methode["name"]
		if not nom.begins_with("test_") or nom in noms:
			continue
		# Un filtre qui nomme le fichier garde toutes ses méthodes.
		if filtre.is_empty() or filtre in chemin.get_file() or filtre in nom:
			noms.append(nom)
	noms.sort()
	return noms


func _executer_methode(
	script: GDScript, chemin: String, nom: String, arbre: SceneTree, bilan: Dictionary
) -> void:
	# Une instance neuve par méthode : aucun état ne fuit d'un test à l'autre.
	var cas: CasDeTest = script.new()
	cas.arbre = arbre
	cas.avant_chaque()
	cas.call(nom)
	cas.apres_chaque()
	bilan["tests"] += 1
	bilan["assertions"] += cas.nb_assertions
	var messages: Array[String] = cas.echecs.duplicate()
	if cas.nb_assertions == 0:
		messages.append("aucune assertion")
	if messages.is_empty():
		return
	bilan["echecs"] += 1
	var lignes: PackedStringArray = bilan["lignes"]
	for message in messages:
		lignes.append("ECHEC %s::%s — %s" % [chemin, nom, message])
