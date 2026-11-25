extends CasDeTest
## Les dossiers temporaires des tests : propres au processus et à la méthode, supprimés après
## elle, et sans collision entre deux suites lancées en même temps (tous les worktrees
## partagent le même `user://`).

const DELAI_FILS_MS: int = 60000
const FIXTURE := (
	"extends CasDeTest\n"
	+ "\n\nfunc _ecrire_et_relire(marque: String) -> void:\n"
	+ '\tvar chemin := dossier_temporaire().path_join("partage.txt")\n'
	+ "\tfor i: int in 30:\n"
	+ "\t\tvar f := FileAccess.open(chemin, FileAccess.WRITE)\n"
	+ "\t\tf.store_string(marque)\n"
	+ "\t\tf.close()\n"
	+ "\t\tawait attendre_images(1)\n"
	+ "\t\tverifier_egal(FileAccess.get_file_as_string(chemin), marque)\n"
	+ "\n\nfunc test_a() -> void:\n\tawait _ecrire_et_relire(str(OS.get_process_id()))\n"
	+ "\n\nfunc test_b() -> void:\n\tawait _ecrire_et_relire(str(OS.get_process_id()))\n"
)
const ENTETE := "extends CasDeTest\n"


func test_le_dossier_est_propre_au_processus_et_a_la_methode() -> void:
	var dossier := dossier_temporaire()
	verifier(DirAccess.dir_exists_absolute(dossier), "créé à la demande")
	verifier_contient(dossier, str(OS.get_process_id()), "porte le pid")
	verifier_contient(dossier, "test_dossiers_temporaires", "porte le fichier")
	verifier_contient(dossier, "test_le_dossier_est_propre", "porte la méthode")
	verifier_egal(dossier_temporaire(), dossier, "stable dans une même méthode")


func test_le_dossier_est_supprime_apres_la_methode_meme_en_echec() -> void:
	var racine := dossier_temporaire().path_join("scripts")
	DirAccess.make_dir_recursive_absolute(racine)
	var traces := racine.path_join("chemins.txt")
	var source := (
		(
			ENTETE
			+ "\n\nfunc test_ok() -> void:\n\tvar d := dossier_temporaire()\n"
			+ '\tDirAccess.make_dir_recursive_absolute(d.path_join("sous"))\n'
			+ '\tvar f := FileAccess.open(d.path_join("sous/x.txt"), FileAccess.WRITE)\n'
			+ "\tf.store_string('x')\n\tf.close()\n"
			+ '\tvar t := FileAccess.open("%s", FileAccess.READ_WRITE if '
			+ 'FileAccess.file_exists("%s") else FileAccess.WRITE)\n'
			+ "\tt.seek_end()\n\tt.store_line(d)\n\tt.close()\n\tverifier(true)\n"
			+ "\n\nfunc test_ko() -> void:\n\ttest_ok()\n\tverifier(false, 'échec voulu')\n"
		)
		% [traces, traces]
	)
	var script := racine.path_join("test_ephemere.gd")
	var f := FileAccess.open(script, FileAccess.WRITE)
	f.store_string(source)
	f.close()
	var moteur := MoteurDeTests.new()
	var bilan := await moteur.executer(PackedStringArray([script]), "", arbre)
	verifier_egal(bilan["tests"], 2)
	verifier_egal(bilan["echecs"], 1)
	var chemins := FileAccess.get_file_as_string(traces).strip_edges().split("\n")
	verifier_egal(chemins.size(), 2)
	for chemin: String in chemins:
		verifier_faux(DirAccess.dir_exists_absolute(chemin), "supprimé : %s" % chemin)


func test_aucun_test_n_ecrit_un_chemin_user_en_dur() -> void:
	# Le motif est coupé pour que ce fichier ne se dénonce pas lui-même.
	var motif := "user:" + "//"
	var autorises := ["cas_de_test.gd", "moteur.gd"]
	var vus := 0
	for chemin: String in _fichiers_gd("res://tests"):
		vus += 1
		if chemin.get_file() in autorises or chemin.get_file() == "test_dossiers_temporaires.gd":
			continue
		verifier_faux(
			FileAccess.get_file_as_string(chemin).contains(motif),
			"chemin %s en dur dans %s : utiliser dossier_temporaire()" % [motif, chemin]
		)
	verifier(vus > 10, "le contrôle a vu les fichiers de tests")


func test_deux_suites_en_parallele_ne_se_genent_pas() -> void:
	var racine := dossier_temporaire().path_join("fixture")
	DirAccess.make_dir_recursive_absolute(racine)
	var f := FileAccess.open(racine.path_join("test_ecriture_commune.gd"), FileAccess.WRITE)
	f.store_string(FIXTURE)
	f.close()
	var fils: Array[Dictionary] = []
	for i: int in 2:
		var args := PackedStringArray(
			[
				"--headless",
				"--path",
				ProjectSettings.globalize_path("res://"),
				"--script",
				"res://tests/lanceur.gd",
				"--",
				"--dossier",
				racine,
			]
		)
		var lance := OS.execute_with_pipe(OS.get_executable_path(), args, false)
		verifier_faux(lance.is_empty(), "processus fils %d lancé" % i)
		if not lance.is_empty():
			fils.append(lance)
	var fin := Time.get_ticks_msec() + DELAI_FILS_MS
	var sorties: Array[String] = ["", ""]
	var encore := true
	while encore and Time.get_ticks_msec() < fin:
		encore = false
		for i: int in fils.size():
			var flux: FileAccess = fils[i]["stdio"]
			var erreurs: FileAccess = fils[i]["stderr"]
			sorties[i] += flux.get_as_text() + erreurs.get_as_text()
			if OS.is_process_running(fils[i]["pid"]):
				encore = true
		await attendre_images(1)
	for i: int in fils.size():
		var pid: int = fils[i]["pid"]
		if OS.is_process_running(pid):
			OS.kill(pid)
			verifier(false, "le fils %d n'a pas fini à temps" % i)
			continue
		var flux: FileAccess = fils[i]["stdio"]
		var erreurs: FileAccess = fils[i]["stderr"]
		sorties[i] += flux.get_as_text() + erreurs.get_as_text()
		verifier_egal(OS.get_process_exit_code(pid), 0, "suite %d : %s" % [i, sorties[i]])
		verifier_contient(sorties[i], "2 tests, 0 échecs", "suite %d : %s" % [i, sorties[i]])


func _fichiers_gd(dossier: String) -> PackedStringArray:
	var sortie := PackedStringArray()
	for fichier: String in DirAccess.get_files_at(dossier):
		if fichier.ends_with(".gd"):
			sortie.append(dossier.path_join(fichier))
	for sous: String in DirAccess.get_directories_at(dossier):
		sortie.append_array(_fichiers_gd(dossier.path_join(sous)))
	return sortie
