extends CasDeTest
## Image Docker de l'annuaire (ADR 001, § Déploiement), vérifiée sans Docker : même version de
## Godot que `tools/install-godot.sh`, somme SHA-512 obligatoire, utilisateur non root, contexte
## de construction allégé. Un garde-fou non branché ne garde rien : la version du Dockerfile ne
## peut plus dériver de celle du script sans que ce test échoue.

const DOCKERFILE: String = "res://service-annuaire/Dockerfile"
const DOCKERIGNORE: String = "res://.dockerignore"
const SCRIPT_GODOT: String = "res://tools/install-godot.sh"


func _lire(chemin: String) -> String:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Valeur de `ARG nom=valeur` dans le Dockerfile, "" si absent.
func _arg(texte: String, nom: String) -> String:
	var re := RegEx.create_from_string("(?m)^ARG %s=(\\S+)\\s*$" % nom)
	var m := re.search(texte)
	return "" if m == null else m.get_string(1)


## Valeur de `NOM="valeur"` dans le script d'installation, "" si absent.
func _variable_du_script(texte: String, nom: String) -> String:
	var re := RegEx.create_from_string('(?m)^%s="([^"]+)"' % nom)
	var m := re.search(texte)
	return "" if m == null else m.get_string(1)


func _instructions(texte: String) -> PackedStringArray:
	var sortie := PackedStringArray()
	for ligne: String in texte.split("\n"):
		var propre := ligne.strip_edges()
		if not propre.is_empty() and not propre.begins_with("#"):
			sortie.append(propre)
	return sortie


func test_le_dockerfile_existe_et_n_est_pas_vide() -> void:
	verifier_faux(_lire(DOCKERFILE).is_empty(), "service-annuaire/Dockerfile")
	verifier_faux(_lire(SCRIPT_GODOT).is_empty(), "tools/install-godot.sh")


func test_la_version_de_godot_est_celle_du_script_d_installation() -> void:
	var docker := _lire(DOCKERFILE)
	var script := _lire(SCRIPT_GODOT)
	var version_script := _variable_du_script(script, "GODOT_VERSION")
	verifier_faux(version_script.is_empty(), "version lue dans le script")
	verifier_egal(_arg(docker, "GODOT_VERSION"), version_script, "ARG GODOT_VERSION")
	# La version du projet est la même (project.godot : features 4.7).
	verifier(version_script.begins_with("4.7"), version_script)


func test_la_somme_sha512_est_un_argument_de_128_chiffres_hexadecimaux() -> void:
	var somme := _arg(_lire(DOCKERFILE), "GODOT_SHA512")
	verifier_egal(somme.length(), 128, "somme SHA-512")
	verifier(
		RegEx.create_from_string("^[0-9a-f]{128}$").search(somme) != null, "hexadécimal minuscule"
	)


func test_la_somme_est_verifiee_sans_repli_ni_contournement() -> void:
	# Les commentaires peuvent citer ce qu'on évite : seules les instructions comptent.
	var docker := "\n".join(_instructions(_lire(DOCKERFILE)))
	verifier("sha512sum -c" in docker, "la somme est vérifiée par sha512sum -c")
	for interdit: String in [
		"non vérifiée", "--insecure", " -k ", "|| true", "--no-check-certificate"
	]:
		verifier_faux(interdit in docker, "« %s » ne doit pas figurer" % interdit)
	# Le téléchargement de l'archive précède la vérification, qui précède l'extraction.
	var i_telechargement := docker.find("releases/download/")
	var i_somme := docker.find("sha512sum -c")
	var i_unzip := docker.find("unzip -q")
	verify_ordre(i_telechargement, i_somme, i_unzip)


func verify_ordre(telechargement: int, verification: int, extraction: int) -> void:
	verifier(telechargement >= 0 and verification > telechargement, "somme après le téléchargement")
	verifier(extraction > verification, "extraction après la vérification")


func test_l_archive_est_celle_de_la_release_godot_builds_comme_dans_le_script() -> void:
	var docker := _lire(DOCKERFILE)
	var script := _lire(SCRIPT_GODOT)
	verifier("github.com/godotengine/godot-builds/releases/download/" in docker)
	verifier("github.com/godotengine/godot-builds/releases/download/" in script)
	verifier("Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" in docker, "nom de l'archive")
	verifier(
		"Godot_v${GODOT_VERSION}-${GODOT_FLAVOR}_linux.x86_64.zip" in script,
		"même nom dans le script"
	)


func test_le_processus_final_n_est_pas_root() -> void:
	var instructions := _instructions(_lire(DOCKERFILE))
	var dernier_user := ""
	var position_user := -1
	var position_entree := -1
	for i: int in instructions.size():
		if instructions[i].begins_with("USER "):
			dernier_user = instructions[i].substr(5).strip_edges()
			position_user = i
		if instructions[i].begins_with("ENTRYPOINT") or instructions[i].begins_with("CMD"):
			position_entree = i
	verifier_faux(dernier_user.is_empty(), "une instruction USER")
	for root: String in ["root", "0", "0:0", "root:root"]:
		verifier_different(dernier_user, root)
	verifier(position_user < position_entree, "USER avant le point d'entrée")


func test_le_point_d_entree_lance_l_annuaire_sans_interface_sur_le_port_par_defaut() -> void:
	var docker := _lire(DOCKERFILE)
	var entree := ""
	for ligne: String in _instructions(docker):
		if ligne.begins_with("ENTRYPOINT"):
			entree = ligne
	verifier("godot" in entree and "--headless" in entree and "--annuaire" in entree, entree)
	verifier_faux("--autoriser-prive" in docker, "cette option n'est jamais dans l'image")
	verifier(("EXPOSE %d/tcp" % AnnuaireProtocole.PORT_DEFAUT) in docker, "port 7779/TCP publié")


func test_le_projet_est_importe_a_la_construction_par_l_utilisateur_final() -> void:
	var instructions := _instructions(_lire(DOCKERFILE))
	var i_import := -1
	var i_user := -1
	for i: int in instructions.size():
		if "--import" in instructions[i] and "--headless" in instructions[i]:
			i_import = i
		if instructions[i].begins_with("USER "):
			i_user = i
	verifier(i_import >= 0, "godot --headless --import")
	verifier(
		i_import > i_user, "l'import se fait sous l'utilisateur final : le cache lui appartient"
	)


func test_l_image_part_d_une_debian_minimale_et_n_utilise_pas_le_script_d_installation() -> void:
	var instructions := _instructions(_lire(DOCKERFILE))
	var docker := "\n".join(instructions)
	if instructions.is_empty():
		verifier(false, "Dockerfile vide")
		return
	verifier(instructions[0].begins_with("FROM debian:"), instructions[0])
	verifier(
		"slim" in instructions[0] or "minimal" in instructions[0],
		"image minimale : " + instructions[0]
	)
	verifier_faux("install-godot.sh" in docker, "il tolère une liste de sommes injoignable")


func test_le_contexte_de_construction_exclut_git_tests_docs_et_superpowers() -> void:
	var lignes := _instructions(_lire(DOCKERIGNORE))
	for exclu: String in [".git", "tests/", "docs/", ".superpowers/"]:
		verifier(
			lignes.has(exclu) or lignes.has(exclu.trim_suffix("/")), "« %s » est exclu" % exclu
		)


func test_le_dockerfile_copie_le_depot_avec_les_droits_de_l_utilisateur_final() -> void:
	var instructions := _instructions(_lire(DOCKERFILE))
	var copie := ""
	for ligne: String in instructions:
		if ligne.begins_with("COPY"):
			copie = ligne
	verifier_faux(copie.is_empty(), "COPY du dépôt")
	verifier("--chown=" in copie, copie)
