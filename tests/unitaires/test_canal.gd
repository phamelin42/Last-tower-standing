extends CasDeTest
## Ce que le canal doit garantir de bout en bout : un client et un serveur ENet du même processus,
## sur la boucle locale et un port libre trouvé à l'exécution, s'échangent chaque type de message
## avec les bons octets et le bon expéditeur.
##
## Le lanceur exécute les tests dans `_initialize`, où l'arbre n'est pas encore actif et où les
## RPC sont impossibles : le scénario tourne donc dans un processus Godot fils
## (`aide_boucle_canal.gd`), qui contient lui-même le serveur ET le client. Le fils s'arrête de
## lui-même au bout de 5 s ; le parent le tue à 20 s au plus, pour ne jamais bloquer la suite.

const AIDE := "res://tests/unitaires/aide_boucle_canal.gd"
const DELAI_PARENT_MS: int = 20000


func _lancer_fils() -> Dictionary:
	var args := PackedStringArray(
		["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", AIDE]
	)
	var fils := OS.execute_with_pipe(OS.get_executable_path(), args, false)
	if fils.is_empty():
		return {"code": -1, "sortie": "processus fils impossible à lancer"}
	var pid: int = fils["pid"]
	var flux: FileAccess = fils["stdio"]
	var erreurs: FileAccess = fils["stderr"]
	var sortie := ""
	var fin := Time.get_ticks_msec() + DELAI_PARENT_MS
	while OS.is_process_running(pid) and Time.get_ticks_msec() < fin:
		sortie += flux.get_as_text()
		erreurs.get_as_text()
		OS.delay_msec(20)
	var code := 0
	if OS.is_process_running(pid):
		OS.kill(pid)
		code = -2
	else:
		code = OS.get_process_exit_code(pid)
	sortie += flux.get_as_text() + erreurs.get_as_text()
	return {"code": code, "sortie": sortie}


func test_chaque_message_traverse_le_canal_avec_ses_octets_et_son_expediteur() -> void:
	var r := _lancer_fils()
	var sortie: String = r["sortie"]
	verifier_egal(r["code"], 0, "le scénario de boucle locale réussit : %s" % sortie.strip_edges())
	verifier(sortie.contains("OK"), "le fils confirme : %s" % sortie.strip_edges())
	verifier_faux(sortie.contains("ECART"), sortie)
