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
	var res := await moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["tests"], 1)
	verifier_egal(res["echecs"], 0)
	verifier_egal(res["assertions"], 2)
	verifier_egal(_lignes(res).size(), 0)


func test_executer_rapporte_une_assertion_fausse_avec_son_message() -> void:
	var chemin := _ecrire(
		"test_ko.gd", ENTETE + '\n\nfunc test_deux() -> void:\n\tverifier_egal(1, 2, "le compte")\n'
	)
	var res := await moteur.executer(PackedStringArray([chemin]), "", arbre)
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
	var res := await moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["tests"], 1)
	verifier_egal(res["echecs"], 1)
	verifier_egal(res["assertions"], 3)
	verifier_egal(_lignes(res).size(), 2, "une ligne par assertion fausse")


func test_executer_une_methode_sans_assertion_est_un_echec() -> void:
	var chemin := _ecrire("test_vide.gd", ENTETE + "\n\nfunc test_vide() -> void:\n\tpass\n")
	var res := await moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["tests"], 1)
	verifier_egal(res["echecs"], 1)
	verifier_contient(_lignes(res)[0], "aucune assertion")


func test_executer_un_fichier_illisible_est_un_echec_et_les_autres_tournent() -> void:
	attendre_erreur("Expected parameter name")
	attendre_erreur("Failed to load script")
	var casse := _ecrire("test_a_casse.gd", ENTETE + "\n\nfunc test_x( -> void:\n\tverifier(true\n")
	var bon := _ecrire("test_b_bon.gd", ENTETE + "\n\nfunc test_ok() -> void:\n\tverifier(true)\n")
	var res := await moteur.executer(PackedStringArray([casse, bon]), "", arbre)
	verifier_egal(res["echecs"], 1)
	verifier_egal(res["assertions"], 1, "le fichier suivant a bien été exécuté")
	verifier_egal(_lignes(res).size(), 1)
	verifier_contient(_lignes(res)[0], casse)


func test_executer_un_fichier_absent_est_un_echec() -> void:
	var bon := _ecrire("test_b_bon.gd", ENTETE + "\n\nfunc test_ok() -> void:\n\tverifier(true)\n")
	var res := await moteur.executer(
		PackedStringArray([RACINE.path_join("fantome.gd"), bon]), "", arbre
	)
	verifier_egal(res["echecs"], 1)
	verifier_egal(res["assertions"], 1)


func test_executer_rejette_une_classe_qui_n_etend_pas_cas_de_test() -> void:
	var chemin := _ecrire(
		"test_intrus.gd", "extends RefCounted\n\n\nfunc test_x() -> void:\n\tpass\n"
	)
	var res := await moteur.executer(PackedStringArray([chemin]), "", arbre)
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
	var res := await moteur.executer(PackedStringArray([chemin]), "", arbre)
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
	var res := await moteur.executer(PackedStringArray([chemin]), "", arbre)
	verifier_egal(res["echecs"], 0)
	verifier_egal(Array(_trace()), ["avant", "a", "apres", "avant", "b", "apres"])


func test_executer_donne_l_arbre_aux_tests() -> void:
	var chemin := _ecrire(
		"test_arbre.gd", ENTETE + "\n\nfunc test_arbre() -> void:\n\tverifier_non_nul(arbre)\n"
	)
	var res := await moteur.executer(PackedStringArray([chemin]), "", arbre)
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
	var par_methode := await moteur.executer(PackedStringArray([chemin]), "garde", arbre)
	verifier_egal(par_methode["tests"], 1)
	verifier_egal(par_methode["echecs"], 0)
	var par_fichier := await moteur.executer(PackedStringArray([chemin]), "test_filtre", arbre)
	verifier_egal(par_fichier["tests"], 2, "le nom du fichier garde toutes ses méthodes")
	verifier_egal(par_fichier["echecs"], 1)


# --- erreurs d'exécution -------------------------------------------------------


func _executer_source(nom: String, source: String) -> Dictionary:
	var chemin := _ecrire(nom, ENTETE + source)
	return await moteur.executer(PackedStringArray([chemin]), "", arbre)


func test_executer_une_erreur_de_script_apres_une_assertion_est_un_echec() -> void:
	# Chaque erreur est aussi vue par le moteur qui exécute CE test : on la déclare.
	var cas := [
		["null", '\tvar x: Object = null\n\tx.call("foo")', "Cannot call method"],
		["borne", "\tvar a: Array = [1]\n\tvar k := 5\n\tprint(a[k])", "Out of bounds"],
	]
	for cas_i: Array in cas:
		var motif: String = cas_i[2]
		attendre_erreur(motif)
		var corps: String = cas_i[1]
		var source := "\n\nfunc test_plante() -> void:\n\tverifier(true)\n%s\n" % corps
		var res := await _executer_source("test_%s.gd" % cas_i[0], source)
		verifier_egal(res["tests"], 1, motif)
		verifier_egal(res["echecs"], 1, "la méthode qui plante échoue : %s" % motif)
		verifier_egal(res["assertions"], 1, motif)
		verifier_contient(_lignes(res)[0], "::test_plante — ")
		verifier_contient(_lignes(res)[0], motif)


func test_executer_un_push_error_non_attendu_est_un_echec() -> void:
	attendre_erreur("boum")
	var res := await _executer_source(
		"test_push.gd", '\n\nfunc test_push() -> void:\n\tpush_error("boum")\n\tverifier(true)\n'
	)
	verifier_egal(res["echecs"], 1)
	verifier_contient(_lignes(res)[0], "boum")


func test_executer_un_push_error_attendu_reussit() -> void:
	attendre_erreur("boum")
	var source := '\n\nfunc test_push() -> void:\n\tattendre_erreur("boum")\n\tpush_error("boum")\n'
	var res := await _executer_source("test_attendu.gd", source)
	verifier_egal(res["tests"], 1)
	verifier_egal(res["echecs"], 0, "l'erreur voulue ne fait pas échouer")
	verifier_egal(res["assertions"], 1, "l'erreur attendue survenue compte pour une assertion")
	verifier_egal(_lignes(res).size(), 0)


func test_executer_une_erreur_attendue_qui_ne_vient_pas_est_un_echec() -> void:
	var source := '\n\nfunc test_absent() -> void:\n\tattendre_erreur("jamais")\n\tverifier(true)\n'
	var res := await _executer_source("test_absent.gd", source)
	verifier_egal(res["echecs"], 1)
	verifier_contient(_lignes(res)[0], "jamais")


func test_executer_une_erreur_attendue_n_est_consommee_qu_une_fois() -> void:
	attendre_erreur("boum")
	attendre_erreur("boum")
	var source := (
		'\n\nfunc test_deux() -> void:\n\tattendre_erreur("boum")\n'
		+ '\tpush_error("boum")\n\tpush_error("boum")\n'
	)
	var res := await _executer_source("test_deux.gd", source)
	verifier_egal(res["echecs"], 1, "la seconde erreur n'était pas attendue")
	verifier_egal(_lignes(res).size(), 1)


func test_executer_un_motif_attendu_ne_couvre_pas_une_autre_erreur() -> void:
	attendre_erreur("autre")
	var source := (
		'\n\nfunc test_autre() -> void:\n\tattendre_erreur("voulue")\n'
		+ '\tpush_error("autre")\n\tverifier(true)\n'
	)
	var res := await _executer_source("test_autre.gd", source)
	verifier_egal(res["echecs"], 1)
	verifier_egal(_lignes(res).size(), 2, "l'erreur imprévue et l'erreur voulue absente")


func test_executer_une_erreur_hors_methode_fait_echouer_le_fichier() -> void:
	attendre_erreur("au chargement")
	var source := (
		"\nvar _v: int = _boum()\n"
		+ '\n\nfunc _boum() -> int:\n\tpush_error("au chargement")\n\treturn 1\n'
		+ "\n\nfunc test_ok() -> void:\n\tverifier(true)\n"
	)
	var res := await _executer_source("test_chargement.gd", source)
	verifier_egal(res["echecs"], 1)
	verifier_egal(res["assertions"], 0, "aucune méthode n'est lancée")
	verifier_contient(_lignes(res)[0], "au chargement")


# --- code de sortie ----------------------------------------------------------


func test_code_de_sortie_normal() -> void:
	verifier_egal(moteur.code_de_sortie({"tests": 3, "echecs": 0}, false), 0)
	verifier_egal(moteur.code_de_sortie({"tests": 3, "echecs": 1}, false), 1)
	verifier_egal(moteur.code_de_sortie({"tests": 3, "echecs": 3}, false), 1)


func test_code_de_sortie_controle_exige_que_tout_echoue() -> void:
	verifier_egal(moteur.code_de_sortie({"tests": 2, "echecs": 2}, true), 0)
	verifier_egal(moteur.code_de_sortie({"tests": 2, "echecs": 1}, true), 1)
	verifier_egal(moteur.code_de_sortie({"tests": 2, "echecs": 0}, true), 1)
	verifier_egal(moteur.code_de_sortie({"tests": 0, "echecs": 0}, true), 1, "contrôle vide")


# --- tests asynchrones et arbre actif ----------------------------------------


func test_executer_attend_une_methode_asynchrone_avant_de_passer_a_la_suivante() -> void:
	var source := (
		_noter_source()
		+ '\n\nfunc test_a() -> void:\n\t_noter("a debut")\n\tawait arbre.process_frame\n'
		+ '\tawait arbre.process_frame\n\t_noter("a fin")\n\tverifier(true)\n'
		+ '\n\nfunc test_b() -> void:\n\t_noter("b")\n\tverifier(true)\n'
	)
	var res := await _executer_source("test_async.gd", source)
	verifier_egal(res["echecs"], 0)
	verifier_egal(res["tests"], 2)
	verifier_egal(_trace(), PackedStringArray(["a debut", "a fin", "b"]))


func test_executer_compte_les_assertions_faites_apres_un_await() -> void:
	var source := "\n\nfunc test_a() -> void:\n\tawait attendre_images(2)\n\tverifier_egal(1, 2, 'apres')\n"
	var res := await _executer_source("test_apres_await.gd", source)
	verifier_egal(res["echecs"], 1)
	verifier_egal(res["assertions"], 1)
	verifier_contient(_lignes(res)[0], "apres")


func test_executer_une_methode_trop_longue_echoue_et_la_suite_continue() -> void:
	var source := (
		"\nfunc avant_chaque() -> void:\n\tdelai_max = 0.1\n"
		+ "\n\nfunc test_a_lent() -> void:\n\tverifier(true)\n\tawait arbre.create_timer(5.0).timeout\n"
		+ "\n\nfunc test_b() -> void:\n\tverifier(true)\n"
	)
	var debut := Time.get_ticks_msec()
	var res := await _executer_source("test_delai.gd", source)
	var duree := Time.get_ticks_msec() - debut
	verifier_egal(res["tests"], 2)
	verifier_egal(res["echecs"], 1)
	verifier_contient(_lignes(res)[0], "délai dépassé")
	verifier(duree < 3000, "le moteur n'attend pas la fin de la méthode lente (%d ms)" % duree)


func test_executer_attribue_l_erreur_a_la_methode_qui_attendait() -> void:
	var source := (
		"\n\nfunc test_a() -> void:\n\tawait attendre_images(1)\n"
		+ '\tpush_error("apres await")\n\tverifier(true)\n'
		+ "\n\nfunc test_b() -> void:\n\tverifier(true)\n"
	)
	attendre_erreur("apres await")
	var res := await _executer_source("test_erreur_await.gd", source)
	verifier_egal(res["echecs"], 1)
	verifier_contient(_lignes(res)[0], "test_a")
	verifier_contient(_lignes(res)[0], "apres await")


func test_un_noeud_ajoute_a_l_arbre_recoit_ready() -> void:
	var noeud := NoeudSonde.new()
	arbre.root.add_child(noeud)
	verifier(noeud.pret, "_ready doit avoir été appelé dès l'ajout")
	noeud.free()


func test_executer_libere_les_noeuds_ajoutes_par_un_test() -> void:
	var source := (
		_noter_source()
		+ '\n\nfunc test_a() -> void:\n\tvar n := Node.new()\n\tn.name = &"SondeLiberee"\n'
		+ "\tarbre.root.add_child(n)\n\tverifier(true)\n"
	)
	await _executer_source("test_libere.gd", source)
	await attendre_images(1)
	verifier_faux(arbre.root.has_node("SondeLiberee"), "le nœud ajouté doit être libéré")


class NoeudSonde:
	extends Node
	var pret := false

	func _ready() -> void:
		pret = true
