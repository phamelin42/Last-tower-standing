class_name Principal
extends Node
## Racine du jeu : montre le menu, ouvre la scène de partie et la ferme au retour, et mène le
## multijoueur (créer un salon, en rejoindre un, le salon, la partie en réseau). Les arguments de la
## ligne de commande et les données se règlent avant l'entrée dans l'arbre (tests).

const SCENE_JEU := "res://scenes/jeu.tscn"
const SCENE_SALON := "res://scenes/salon.tscn"
const SCENE_CONNEXION := "res://scenes/connexion.tscn"
## Serveur dédié (`--serveur`), fourni par `reseau/serveur_dedie.gd`.
const SCENE_SERVEUR := "res://scenes/serveur.tscn"

## Injectable avant `_ready` ; sinon lus sur la ligne de commande.
var arguments: Dictionary = {}
## Injectables : données de la partie (sinon `data/`) et fichier de réglages.
var donnees: Donnees = null
var chemin_reglages: String = Reglages.CHEMIN_DEFAUT
## Découverte des salons : seuls les tests changent le port et les cibles (127.0.0.1).
var port_decouverte: int = Decouverte.PORT_DECOUVERTE
var cibles_decouverte: Array[String] = [Decouverte.DIFFUSION]

var _menu: MenuPrincipal
var _jeu: Jeu = null
var _connexion: ConnexionUi
var _salon: SalonUi
var _session: SessionReseau = null
var _chercheur: Decouverte = null
var _nom_joueur: String = ""
var _parametres_hote: Array = []
var _erreur_creation: String = ""


## La scène à charger à la place du menu : le serveur dédié si `--serveur`, sinon rien.
static func scene_de_demarrage(args: Dictionary) -> String:
	return SCENE_SERVEUR if bool(args.get("serveur", false)) else ""


func _ready() -> void:
	if arguments.is_empty():
		arguments = Arguments.lire(OS.get_cmdline_user_args())
	var messages: Array = arguments["messages"]
	for message: Variant in messages:
		print(message)
	var scene := scene_de_demarrage(arguments)
	if not scene.is_empty():
		_lancer_serveur_dedie(scene)
		return
	_menu = $Menu as MenuPrincipal
	_menu.configurer(chemin_reglages)
	_menu.solo_demande.connect(_lancer_solo)
	_menu.quitter_demande.connect(_quitter)
	_menu.reglages_modifies.connect(_appliquer_reglages)
	_menu.creer_demande.connect(_ouvrir_creer)
	_menu.rejoindre_demande.connect(_ouvrir_rejoindre)
	_construire_multijoueur()
	_appliquer_reglages(Reglages.charger(chemin_reglages))
	if bool(arguments["solo_auto"]):
		_lancer_solo(_menu.nom_joueur())


func menu() -> MenuPrincipal:
	return _menu


func connexion() -> ConnexionUi:
	return _connexion


func salon() -> SalonUi:
	return _salon


## La session multijoueur en cours, ou `null`.
func session() -> SessionReseau:
	return _session


## Le serveur dédié n'a pas d'interface : sa scène remplace celle-ci. Si elle manque, on le dit
## et on sort en erreur plutôt que d'ouvrir un menu qu'un serveur sans écran ne peut pas lire.
func _lancer_serveur_dedie(scene: String) -> void:
	if not ResourceLoader.exists(scene):
		printerr("Scène du serveur dédié introuvable : %s" % scene)
		get_tree().quit(1)
		return
	get_tree().change_scene_to_file.call_deferred(scene)


## La partie en cours, ou `null` quand le menu est affiché.
func jeu() -> Jeu:
	return _jeu


func _lancer_solo(nom: String) -> void:
	if _jeu != null:
		return
	var d := donnees if donnees != null else Donnees.charger()
	if d == null:
		_menu.afficher_message(tr("MENU_ERREUR_DONNEES"))
		return
	var graine: int = arguments["graine"]
	if graine < 0:
		graine = randi()
	var facteur: float = arguments["vitesse"]
	_enregistrer_nom(nom)
	var jeu_neuf := (load(SCENE_JEU) as PackedScene).instantiate() as Jeu
	jeu_neuf.chemin_reglages = chemin_reglages
	jeu_neuf.nom_joueur = nom
	add_child(jeu_neuf)
	if not jeu_neuf.demarrer_solo(d, graine, facteur):
		remove_child(jeu_neuf)
		jeu_neuf.queue_free()
		_menu.afficher_message(tr("MENU_ERREUR_DONNEES"))
		return
	_jeu = jeu_neuf
	_jeu.retour_menu.connect(_retour_menu)
	_menu.afficher_message("")
	_menu.visible = false


func _retour_menu(motif: String) -> void:
	_fermer_jeu()
	_fermer_session()
	_arreter_recherche()
	_connexion.fermer()
	_salon.visible = false
	_menu.visible = true
	_menu.afficher_message(tr("MENU_CONNEXION_PERDUE") % motif if not motif.is_empty() else "")
	_menu.bouton_solo.grab_focus()


func _enregistrer_nom(nom: String) -> void:
	var r := Reglages.charger(chemin_reglages)
	if r.nom_joueur != nom and nom != tr("MENU_NOM_PAR_DEFAUT"):
		r.nom_joueur = nom
		r.sauver(chemin_reglages)


func _appliquer_reglages(r: Reglages) -> void:
	Jeu.appliquer_fenetre(get_window(), r)


func _quitter() -> void:
	get_tree().quit()


# --- Multijoueur -------------------------------------------------------------------------------


func _construire_multijoueur() -> void:
	_connexion = (load(SCENE_CONNEXION) as PackedScene).instantiate() as ConnexionUi
	_salon = (load(SCENE_SALON) as PackedScene).instantiate() as SalonUi
	add_child(_connexion)
	add_child(_salon)
	_connexion.creer_demande.connect(_creer)
	_connexion.rejoindre_demande.connect(_rejoindre)
	_connexion.retour_demande.connect(_retour_depuis_connexion)
	_salon.pret_change.connect(_sur_pret)
	_salon.options_changees.connect(_sur_options)
	_salon.lancer_demande.connect(_sur_lancer)
	_salon.quitter.connect(_quitter_salon)


func _donnees_du_jeu() -> Donnees:
	return donnees if donnees != null else Donnees.charger()


func _ouvrir_creer(nom: String) -> void:
	if _jeu != null:
		return
	_nom_joueur = nom
	_enregistrer_nom(nom)
	_menu.visible = false
	_connexion.ouvrir_creer(nom)


func _ouvrir_rejoindre(nom: String) -> void:
	if _jeu != null:
		return
	_nom_joueur = nom
	_enregistrer_nom(nom)
	_menu.visible = false
	_arreter_recherche()
	_chercheur = Decouverte.new()
	_chercheur.name = "Chercheur"
	add_child(_chercheur)
	_connexion.ouvrir_rejoindre()
	var code := _chercheur.chercher(port_decouverte)
	if code != OK:
		_connexion.afficher_erreur_rejoindre(tr("CONNEXION_DECOUVERTE_INDISPONIBLE"))
		return
	_chercheur.liste_changee.connect(_sur_liste_changee)


func _sur_liste_changee() -> void:
	if _chercheur != null:
		_connexion.afficher_salons(_chercheur.salons())


func _arreter_recherche() -> void:
	if _chercheur != null:
		_chercheur.arreter()
		remove_child(_chercheur)
		_chercheur.queue_free()
		_chercheur = null


func _retour_depuis_connexion() -> void:
	_arreter_recherche()
	_connexion.fermer()
	_menu.visible = true
	_menu.bouton_solo.grab_focus()


func _nouvelle_session() -> SessionReseau:
	_fermer_session()
	_session = SessionReseau.new()
	_session.name = "Session"
	add_child(_session)
	_session.salon_mis_a_jour.connect(_sur_salon)
	_session.partie_demarree.connect(_sur_partie_demarree)
	_session.connexion_perdue.connect(_sur_perte)
	return _session


func _fermer_session() -> void:
	if _session == null:
		return
	var s := _session
	_session = null
	s.fermer()
	remove_child(s)
	s.queue_free()


func _creer(nom_salon: String, port: int) -> void:
	var d := _donnees_du_jeu()
	if d == null:
		_connexion.afficher_erreur_creer(tr("MENU_ERREUR_DONNEES"))
		return
	var s := _nouvelle_session()
	var code := s.heberger(d, port, nom_salon, _nom_joueur, port_decouverte, cibles_decouverte)
	if code != OK:
		_fermer_session()
		_erreur_creation = SessionReseau.message_erreur(code, port)
		_connexion.afficher_erreur_creer(_erreur_creation)
		return
	_erreur_creation = ""
	_parametres_hote = [nom_salon, port]
	_connexion.fermer()
	_salon.afficher_infos(tr("SALON_ANNONCE_HOTE") % [nom_salon, port])
	_salon.afficher_attente()


func _rejoindre(adresse: String, port: int) -> void:
	var d := _donnees_du_jeu()
	if d == null:
		_connexion.afficher_erreur_rejoindre(tr("MENU_ERREUR_DONNEES"))
		return
	var s := _nouvelle_session()
	var code := s.rejoindre(d, adresse, port, _nom_joueur)
	if code != OK:
		_fermer_session()
		_connexion.afficher_erreur_rejoindre(SessionReseau.message_erreur(code, port))
		return
	_parametres_hote = []
	_arreter_recherche()
	_connexion.fermer()
	_salon.afficher_infos("")
	_salon.afficher_attente()


func _sur_salon(s: Salon) -> void:
	if _session != null and _session.client != null and _jeu == null:
		_salon.afficher(s, _session.client.id_local())


func _sur_pret(pret: bool) -> void:
	if _session != null and _session.client != null:
		_session.client.pret(pret)


func _sur_options(vitesse: float, graine: int, graine_fixe: bool) -> void:
	if _session != null and _session.client != null:
		_session.client.regler_options(vitesse, graine, graine_fixe)


func _sur_lancer() -> void:
	if _session != null and _session.client != null:
		_session.client.lancer()


func _quitter_salon() -> void:
	_fermer_session()
	_salon.visible = false
	_menu.visible = true
	_menu.bouton_solo.grab_focus()


## Refus, serveur injoignable ou perdu. Avant le premier état du salon, la joueuse revient à la
## page « Rejoindre » avec la raison ; plus tard, au menu.
func _sur_perte(motif: String) -> void:
	var en_connexion := _salon.visible and _salon.en_attente() and _parametres_hote.is_empty()
	if not en_connexion:
		_retour_menu(motif)
		return
	_fermer_session()
	_salon.visible = false
	_ouvrir_rejoindre(_nom_joueur)
	_connexion.afficher_erreur_rejoindre(motif)


func _sur_partie_demarree() -> void:
	if _jeu != null or _session == null or _session.client == null:
		return
	var jeu_neuf := (load(SCENE_JEU) as PackedScene).instantiate() as Jeu
	jeu_neuf.chemin_reglages = chemin_reglages
	jeu_neuf.nom_joueur = _nom_joueur
	add_child(jeu_neuf)
	if not jeu_neuf.demarrer_reseau(_session.client.donnees, _session.client):
		remove_child(jeu_neuf)
		jeu_neuf.queue_free()
		_retour_menu(tr("MENU_ERREUR_DONNEES"))
		return
	_jeu = jeu_neuf
	_jeu.retour_menu.connect(_retour_menu)
	_jeu.retour_salon.connect(_retour_salon)
	_salon.visible = false
	_menu.visible = false


## Après la partie : l'hôte rouvre un salon neuf sur le même port, les autres reviennent à la
## liste des salons (le serveur ne relance pas une partie dans le même salon).
func _retour_salon() -> void:
	var etait_hote := _session != null and _session.est_hote()
	var params := _parametres_hote.duplicate()
	_fermer_jeu()
	_fermer_session()
	if etait_hote and params.size() == 2:
		_creer(String(params[0]), int(params[1]))
		if _session == null:
			_retour_menu(_erreur_creation)
	else:
		_ouvrir_rejoindre(_nom_joueur)


func _fermer_jeu() -> void:
	if _jeu != null:
		remove_child(_jeu)
		_jeu.queue_free()
		_jeu = null
