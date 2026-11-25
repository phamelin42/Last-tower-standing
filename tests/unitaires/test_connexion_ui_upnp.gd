extends CasDeTest
## L'échec de la redirection du port, tel que le joueur le lit sur la page de création : un
## message qui dit la conséquence (joueurs extérieurs) sans interdire de jouer en local.

const MESSAGE := (
	"Votre box n’a pas ouvert le port\u00a0: "
	+ "les joueurs extérieurs ne pourront pas vous rejoindre"
)

var _ui: ConnexionUi


func avant_chaque() -> void:
	_ui = ConnexionUi.new()
	arbre.root.add_child(_ui)
	_ui.ouvrir_creer("Alix")


func apres_chaque() -> void:
	_ui.queue_free()


func _message_visible() -> Label:
	for noeud: Node in _ui.find_children("*", "Label", true, false):
		var l := noeud as Label
		if l.visible and l.text == MESSAGE:
			return l
	return null


func test_l_echec_affiche_le_message_exact() -> void:
	_ui.afficher_echec_redirection()
	verifier_non_nul(_message_visible(), "le message exact est visible sur la page de création")
	verifier(_ui.page_creer_visible())


func test_le_message_garde_l_apostrophe_typographique_et_l_espace_insecable() -> void:
	verifier_egal(tr("CONNEXION_UPNP_ECHEC"), MESSAGE)
	verifier_contient(MESSAGE, "n’a")
	verifier_contient(MESSAGE, "port :")


func test_rouvrir_la_page_efface_l_avertissement() -> void:
	_ui.afficher_echec_redirection()
	_ui.ouvrir_creer("Alix")
	verifier_nul(_message_visible())


func test_le_formulaire_reste_utilisable_apres_l_echec() -> void:
	_ui.afficher_echec_redirection()
	verifier_faux(_ui.bouton_creer.disabled, "créer reste possible : le réseau local marche")
