extends CasDeTest
## Déploiement de l'annuaire (ADR 001, § Déploiement), vérifié sans Docker : redémarrage
## automatique, système de fichiers en lecture seule avec un `tmpfs` sur le dossier utilisateur de
## Godot, journal borné, contrôle de santé sur le port du service, réseau de l'hôte (l'IP source
## réelle), et jamais `--autoriser-prive` ni secret. Un garde-fou non branché ne garde rien.

const COMPOSE: String = "res://service-annuaire/compose.yaml"
const DOCKERFILE: String = "res://service-annuaire/Dockerfile"
const DOSSIER_GODOT: String = "/home/annuaire/.local/share/godot"


## Lignes utiles (sans commentaire ni ligne vide), espaces de tête retirés.
func _lignes(chemin: String) -> PackedStringArray:
	var sortie := PackedStringArray()
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return sortie
	for ligne: String in f.get_as_text().split("\n"):
		var propre := ligne.strip_edges()
		if not propre.is_empty() and not propre.begins_with("#"):
			sortie.append(propre)
	return sortie


func _compose() -> String:
	return "\n".join(_lignes(COMPOSE))


func test_le_compose_existe_et_construit_l_image_du_depot() -> void:
	var texte := _compose()
	verifier_faux(texte.is_empty(), "service-annuaire/compose.yaml")
	verifier("dockerfile: service-annuaire/Dockerfile" in texte, "Dockerfile de l'annuaire")
	verifier("context: .." in texte, "contexte = racine du dépôt")


func test_le_service_redemarre_sauf_arret_voulu() -> void:
	verifier(_lignes(COMPOSE).has("restart: unless-stopped"), "restart: unless-stopped")


func test_le_systeme_de_fichiers_est_en_lecture_seule_avec_un_tmpfs_sur_le_dossier_de_godot(
) -> void:
	verifier(_lignes(COMPOSE).has("read_only: true"), "read_only: true")
	var tmpfs := ""
	for ligne: String in _lignes(COMPOSE):
		if ligne.begins_with("- " + DOSSIER_GODOT):
			tmpfs = ligne
	verifier_faux(tmpfs.is_empty(), "un tmpfs sur " + DOSSIER_GODOT)
	# Le tmpfs appartient à l'utilisateur du Dockerfile (sinon Godot ne peut pas y écrire).
	var docker := "\n".join(_lignes(DOCKERFILE))
	verifier("--create-home --uid 10001 annuaire" in docker, "uid de l'utilisateur annuaire")
	verifier("uid=10001" in tmpfs and "gid=10001" in tmpfs, tmpfs)


func test_le_journal_est_borne() -> void:
	var texte := _compose()
	verifier("max-size:" in texte, "taille maximale du journal")
	verifier("max-file:" in texte, "nombre de fichiers du journal")


func test_le_controle_de_sante_ouvre_le_port_du_service() -> void:
	var texte := _compose()
	verifier("healthcheck:" in texte, "healthcheck")
	verifier(
		("/dev/tcp/127.0.0.1/%d" % AnnuaireProtocole.PORT_DEFAUT) in texte,
		"ouverture TCP du port %d" % AnnuaireProtocole.PORT_DEFAUT
	)


func test_le_reseau_est_celui_de_l_hote_pour_voir_l_ip_source_reelle() -> void:
	verifier(_lignes(COMPOSE).has("network_mode: host"), "network_mode: host")
	# Le port du service est celui du Dockerfile : rien n'est publié, tout passe par l'hôte.
	verifier("EXPOSE %d/tcp" % AnnuaireProtocole.PORT_DEFAUT in _compose_ou_docker())
	verifier_faux("ports:" in _compose(), "aucune publication de port avec le réseau de l'hôte")


func _compose_ou_docker() -> String:
	return "\n".join(_lignes(DOCKERFILE))


func test_le_compose_n_a_ni_option_de_test_ni_secret_ni_volume() -> void:
	var texte := _compose()
	for interdit: String in [
		"--autoriser-prive",
		"command:",
		"entrypoint:",
		"environment:",
		"env_file:",
		"volumes:",
		"secrets:",
		"privileged",
		"password",
		"token"
	]:
		verifier_faux(interdit in texte.to_lower(), "« %s » ne doit pas figurer" % interdit)
