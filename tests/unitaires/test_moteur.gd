extends CasDeTest
## Le moteur doit trouver les bons fichiers, exécuter chaque test isolément et
## signaler tout ce qui cloche, sans jamais planter lui-même.
## Les scripts de démonstration sont écrits sous user:// puis effacés.

const RACINE := "user://moteur_test"
const TRACE := "user://moteur_test/trace.txt"
const ENTETE := "extends CasDeTest\n"
const NOTER := (
	"\n\nfunc _noter(s: String) -> void:\n"
	+ '\tvar f := FileAccess.open("user://moteur_test/trace.txt", FileAccess.%s)\n'
	+ "\tf.seek_end()\n"
	+ "\tf.store_line(s)\n"
)

var moteur: MoteurDeTests


func avant_chaque() -> void:
	moteur = MoteurDeTests.new()
	_nettoyer(RACINE)
	DirAccess.make_dir_recursive_absolute(RACINE)


func apres_chaque() -> void:
	_nettoyer(RACINE)


func _nettoyer(dossier: String) -> void:
	if not DirAccess.dir_exists_absolute(dossier):
		return
	for sous: String in DirAccess.get_directories_at(dossier):
		_nettoyer(dossier.path_join(sous))
	for fichier: String in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(fichier))
	DirAccess.remove_absolute(dossier)


func _ecrire(relatif: String, contenu: String) -> String:
	var chemin := RACINE.path_join(relatif)
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(contenu)
	f.close()
	return chemin


func _lignes(bilan: Dictionary) -> PackedStringArray:
	return bilan["lignes"]


func _trace() -> PackedStringArray:
	var texte := FileAccess.get_file_as_string(TRACE).strip_edges()
	if texte.is_empty():
		return PackedStringArray()
	return texte.split("\n")


func _noter_source() -> String:
	# Ouvre en écriture au premier appel, en lecture/écriture ensuite.
	return (
		NOTER
		% 'READ_WRITE if FileAccess.file_exists("user://moteur_test/trace.txt") else FileAccess.WRITE'
	)


# --- decouvrir -------------------------------------------------------------


func test_decouvrir_trie_par_chemin_et_ignore_ce_qui_n_est_pas_un_test() -> void:
	var b := _ecrire("test_b.gd", ENTETE)
	var a := _ecrire("test_a.gd", ENTETE)
	var d := _ecrire("sous/test_d.gd", ENTETE)
	_ecrire("assistant.gd", ENTETE)
	_ecrire("test_note.txt", "x")
	var trouves := moteur.decouvrir(RACINE, "", false)
	verifier_egal(Array(trouves), [d, a, b], "tri par chemin complet")


func test_decouvrir_exclut_le_dossier_controle() -> void:
	var a := _ecrire("test_a.gd", ENTETE)
	_ecrire("controle/test_c.gd", ENTETE)
	_ecrire("sous/controle/test_e.gd", ENTETE)
	verifier_egal(Array(moteur.decouvrir(RACINE, "", false)), [a])


func test_decouvrir_en_mode_controle_ne_garde_que_le_dossier_controle() -> void:
	_ecrire("test_a.gd", ENTETE)
	var c := _ecrire("controle/test_c.gd", ENTETE)
	verifier_egal(Array(moteur.decouvrir(RACINE, "", true)), [c])


func test_decouvrir_filtre_sur_le_nom_du_fichier() -> void:
	_ecrire("test_alpha.gd", ENTETE)
	var b := _ecrire("test_beta.gd", ENTETE)
	verifier_egal(Array(moteur.decouvrir(RACINE, "beta", false)), [b])


func test_decouvrir_filtre_sur_le_nom_d_une_methode() -> void:
	_ecrire("test_alpha.gd", ENTETE + "\n\nfunc test_rare_cas() -> void:\n\tpass\n")
	var b := _ecrire("test_beta.gd", ENTETE + "\n\nfunc test_cas_unique() -> void:\n\tpass\n")
	verifier_egal(Array(moteur.decouvrir(RACINE, "cas_unique", false)), [b])
	verifier_egal(moteur.decouvrir(RACINE, "inexistant", false).size(), 0)


func test_decouvrir_dossier_absent_donne_une_liste_vide() -> void:
	verifier_egal(moteur.decouvrir(RACINE.path_join("rien"), "", false).size(), 0)


# --- executer --------------------------------------------------------------


func test_executer_un_test_juste_ne_signale_rien() -> void:
	var chemin := _ecrire(
		"test_ok.gd",
		ENTETE + "\n\nfunc test_un() -> void:\n\tverifier(true)\n\tverifier_egal(1, 1)\n"
	)
	var res := moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["tests"], 1)
	verifier_egal(res["echecs"], 0)
	verifier_egal(res["assertions"], 2)
	verifier_egal(_lignes(res).size(), 0)


func test_executer_rapporte_une_assertion_fausse_avec_son_message() -> void:
	var chemin := _ecrire(
		"test_ko.gd", ENTETE + '\n\nfunc test_deux() -> void:\n\tverifier_egal(1, 2, "le compte")\n'
	)
	var res := moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["tests"], 1)
	verifier_egal(res["echecs"], 1)
	verifier_egal(_lignes(res).size(), 1)
	var ligne: String = _lignes(res)[0]
	verifier(ligne.begins_with("ECHEC %s::test_deux — " % chemin), ligne)
	verifier_contient(ligne, "le compte")
	verifier_contient(ligne, "attendu 2")
	verifier_contient(ligne, "reçu 1")


func test_executer_une_assertion_fausse_n_interrompt_pas_la_methode() -> void:
	var chemin := _ecrire(
		"test_suite.gd",
		(
			ENTETE
			+ '\n\nfunc test_trois() -> void:\n\tverifier(false, "premier")\n'
			+ '\tverifier(false, "second")\n\tverifier(true)\n'
		)
	)
	var res := moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["tests"], 1)
	verifier_egal(res["echecs"], 1)
	verifier_egal(res["assertions"], 3)
	verifier_egal(_lignes(res).size(), 2, "une ligne par assertion fausse")


func test_executer_une_methode_sans_assertion_est_un_echec() -> void:
	var chemin := _ecrire("test_vide.gd", ENTETE + "\n\nfunc test_vide() -> void:\n\tpass\n")
	var res := moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["tests"], 1)
	verifier_egal(res["echecs"], 1)
	verifier_contient(_lignes(res)[0], "aucune assertion")


func test_executer_un_fichier_illisible_est_un_echec_et_les_autres_tournent() -> void:
	var casse := _ecrire("test_a_casse.gd", ENTETE + "\n\nfunc test_x( -> void:\n\tverifier(true\n")
	var bon := _ecrire("test_b_bon.gd", ENTETE + "\n\nfunc test_ok() -> void:\n\tverifier(true)\n")
	var res := moteur.executer(PackedStringArray([casse, bon]), "", arbre)
	verifier_egal(res["echecs"], 1)
	verifier_egal(res["assertions"], 1, "le fichier suivant a bien été exécuté")
	verifier_egal(_lignes(res).size(), 1)
	verifier_contient(_lignes(res)[0], casse)


func test_executer_un_fichier_absent_est_un_echec() -> void:
	var bon := _ecrire("test_b_bon.gd", ENTETE + "\n\nfunc test_ok() -> void:\n\tverifier(true)\n")
	var res := moteur.executer(PackedStringArray([RACINE.path_join("fantome.gd"), bon]), "", arbre)
	verifier_egal(res["echecs"], 1)
	verifier_egal(res["assertions"], 1)


func test_executer_rejette_une_classe_qui_n_etend_pas_cas_de_test() -> void:
	var chemin := _ecrire(
		"test_intrus.gd", "extends RefCounted\n\n\nfunc test_x() -> void:\n\tpass\n"
	)
	var res := moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["echecs"], 1)
	verifier_contient(_lignes(res)[0], "CasDeTest")


func test_executer_isole_chaque_methode_dans_une_instance_neuve() -> void:
	var chemin := _ecrire(
		"test_isole.gd",
		(
			ENTETE
			+ "\nvar compteur: int = 0\n"
			+ "\n\nfunc test_a() -> void:\n\tcompteur += 1\n\tverifier_egal(compteur, 1)\n"
			+ "\n\nfunc test_b() -> void:\n\tcompteur += 1\n\tverifier_egal(compteur, 1)\n"
		)
	)
	var res := moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["tests"], 2)
	verifier_egal(res["echecs"], 0, "l'état d'un test ne fuit pas dans le suivant")


func test_executer_appelle_avant_et_apres_chaque_dans_l_ordre_alphabetique() -> void:
	var source := (
		ENTETE
		+ _noter_source()
		+ '\n\nfunc avant_chaque() -> void:\n\t_noter("avant")\n'
		+ '\n\nfunc apres_chaque() -> void:\n\t_noter("apres")\n'
		+ '\n\nfunc test_b() -> void:\n\t_noter("b")\n\tverifier(true)\n'
		+ '\n\nfunc test_a() -> void:\n\t_noter("a")\n\tverifier(true)\n'
	)
	var chemin := _ecrire("test_ordre.gd", source)
	var res := moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["echecs"], 0)
	verifier_egal(Array(_trace()), ["avant", "a", "apres", "avant", "b", "apres"])


func test_executer_donne_l_arbre_aux_tests() -> void:
	var chemin := _ecrire(
		"test_arbre.gd", ENTETE + "\n\nfunc test_arbre() -> void:\n\tverifier_non_nul(arbre)\n"
	)
	var res := moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["echecs"], 0)


func test_executer_filtre_par_methode_ou_par_fichier() -> void:
	var chemin := _ecrire(
		"test_filtre.gd",
		(
			ENTETE
			+ "\n\nfunc test_garde() -> void:\n\tverifier(true)\n"
			+ "\n\nfunc test_ecarte() -> void:\n\tverifier(false)\n"
		)
	)
	var par_methode := moteur.executer(PackedStringArray([chemin]), "garde", arbre)
	verifier_egal(par_methode["tests"], 1)
	verifier_egal(par_methode["echecs"], 0)
	var par_fichier := moteur.executer(PackedStringArray([chemin]), "test_filtre", arbre)
	verifier_egal(par_fichier["tests"], 2, "le nom du fichier garde toutes ses méthodes")
	verifier_egal(par_fichier["echecs"], 1)


# --- code de sortie ----------------------------------------------------------


func test_code_de_sortie_normal_et_controle() -> void:
	verifier_egal(moteur.code_de_sortie({"tests": 3, "echecs": 0}, false), 0)
	verifier_egal(moteur.code_de_sortie({"tests": 3, "echecs": 1}, false), 1)
	verifier_egal(moteur.code_de_sortie({"tests": 3, "echecs": 3}, false), 1)
	# En mode contrôle, tout doit avoir échoué : c'est la preuve de détection.
	verifier_egal(moteur.code_de_sortie({"tests": 2, "echecs": 2}, true), 0)
	verifier_egal(moteur.code_de_sortie({"tests": 2, "echecs": 1}, true), 1)
	verifier_egal(moteur.code_de_sortie({"tests": 2, "echecs": 0}, true), 1)
	verifier_egal(moteur.code_de_sortie({"tests": 0, "echecs": 0}, true), 1, "contrôle vide")
