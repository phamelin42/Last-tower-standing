class_name MoteurDeTests
extends RefCounted
## Découvre et exécute les fichiers de tests. Ne plante jamais sur un test cassé :
## tout problème devient un échec rapporté, et les fichiers suivants sont lancés.

const SEGMENT_CONTROLE := "/controle/"

## Journal des erreurs du moteur, rempli pendant `executer`.
var _journal: JournalErreurs


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
## À `await`er : une méthode peut attendre des images ou des signaux (arbre actif requis).
func executer(chemins: PackedStringArray, filtre: String, arbre: SceneTree) -> Dictionary:
	var bilan := {"tests": 0, "echecs": 0, "assertions": 0, "lignes": PackedStringArray()}
	_journal = JournalErreurs.new()
	OS.add_logger(_journal)
	for chemin: String in chemins:
		await _executer_fichier(chemin, filtre, arbre, bilan)
	OS.remove_logger(_journal)
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
	_journal.prendre()
	var script := ResourceLoader.load(chemin, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	var erreurs := _journal.prendre()
	if script == null or not script.can_instantiate():
		var detail := _texte_erreurs(erreurs)
		_echec_fichier(chemin, "script impossible à charger %s" % detail, bilan)
		return
	var sonde: Variant = script.new()
	erreurs.append_array(_journal.prendre())
	if not erreurs.is_empty():
		_echec_fichier(chemin, "erreur hors méthode %s" % _texte_erreurs(erreurs), bilan)
		return
	if not sonde is CasDeTest:
		_echec_fichier(chemin, "la classe doit étendre CasDeTest", bilan)
		return
	for nom: String in _methodes_a_lancer(script, chemin, filtre):
		await _executer_methode(script, chemin, nom, arbre, bilan)


func _texte_erreurs(erreurs: Array[Dictionary]) -> String:
	var morceaux := PackedStringArray()
	for erreur in erreurs:
		morceaux.append("%s [%s]" % [erreur["message"], erreur["lieu"]])
	return ": " + " ; ".join(morceaux) if not morceaux.is_empty() else "(erreur d'analyse)"


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
	_journal.prendre()
	# Une instance neuve par méthode : aucun état ne fuit d'un test à l'autre.
	var cas: CasDeTest = script.new()
	cas.arbre = arbre
	cas.noter_noeuds_initiaux()
	var suivi := SuiviMethode.new()
	_derouler(cas, nom, suivi)
	var debut := Time.get_ticks_msec()
	while not suivi.fini and (Time.get_ticks_msec() - debut) < cas.delai_max * 1000.0:
		await arbre.process_frame
	var messages: Array[String] = []
	if not suivi.fini:
		messages.append("délai dépassé (%s s)" % cas.delai_max)
	messages.append_array(cas.echecs)
	# Un test en retard n'a pas fini : son `apres_chaque` ne le rattrape pas.
	if suivi.fini:
		await cas.apres_chaque()
	cas.liberer_ajouts()
	await arbre.process_frame
	_rapprocher_erreurs(cas, _journal.prendre(), messages)
	if cas.nb_assertions == 0:
		messages.append("aucune assertion")
	bilan["tests"] += 1
	bilan["assertions"] += cas.nb_assertions
	if messages.is_empty():
		return
	bilan["echecs"] += 1
	var lignes: PackedStringArray = bilan["lignes"]
	for message in messages:
		lignes.append("ECHEC %s::%s — %s" % [chemin, nom, message])


## Déroule avant, test et après dans une coroutine que le moteur surveille.
func _derouler(cas: CasDeTest, nom: String, suivi: SuiviMethode) -> void:
	await cas.avant_chaque()
	await cas.call(nom)
	suivi.fini = true


## Une erreur journalisée fait échouer la méthode, sauf si elle était attendue.
func _rapprocher_erreurs(
	cas: CasDeTest, erreurs: Array[Dictionary], messages: Array[String]
) -> void:
	var attendues := cas.erreurs_attendues.duplicate()
	for erreur in erreurs:
		var message: String = erreur["message"]
		var trouvee := -1
		for i in attendues.size():
			if attendues[i] in message:
				trouvee = i
				break
		if trouvee >= 0:
			attendues.remove_at(trouvee)
			cas.nb_assertions += 1
		else:
			messages.append("erreur non attendue : %s [%s]" % [message, erreur["lieu"]])
	for motif: String in attendues:
		messages.append("erreur attendue qui n'est jamais survenue : %s" % motif)


## État partagé entre la coroutine d'un test et le moteur qui la surveille.
class SuiviMethode:
	extends RefCounted
	var fini := false


## Reçoit les erreurs du moteur (script, `push_error`, chargement). Les rappels peuvent
## venir d'un autre fil, d'où le verrou. Les avertissements ne sont pas des erreurs.
class JournalErreurs:
	extends Logger

	var _verrou := Mutex.new()
	var _erreurs: Array[Dictionary] = []

	func prendre() -> Array[Dictionary]:
		_verrou.lock()
		var recues := _erreurs.duplicate()
		_erreurs.clear()
		_verrou.unlock()
		return recues

	func _log_error(
		_fonction: String,
		fichier: String,
		ligne: int,
		code: String,
		rationale: String,
		_editeur: bool,
		type: int,
		_traces: Array[ScriptBacktrace]
	) -> void:
		if type == Logger.ERROR_TYPE_WARNING:
			return
		var message := code if rationale.is_empty() else "%s %s" % [code, rationale]
		_verrou.lock()
		_erreurs.append({"message": message.strip_edges(), "lieu": "%s:%d" % [fichier, ligne]})
		_verrou.unlock()
