class_name Principal
extends Node
## Racine du jeu : montre le menu, ouvre la scène de partie et la ferme au retour. Les
## arguments de la ligne de commande et les données se règlent avant l'entrée dans l'arbre (tests).

const SCENE_JEU := "res://scenes/jeu.tscn"

## Injectable avant `_ready` ; sinon lus sur la ligne de commande.
var arguments: Dictionary = {}
## Injectables : données de la partie (sinon `data/`) et fichier de réglages.
var donnees: Donnees = null
var chemin_reglages: String = Reglages.CHEMIN_DEFAUT

var _menu: MenuPrincipal
var _jeu: Jeu = null


func _ready() -> void:
	if arguments.is_empty():
		arguments = Arguments.lire(OS.get_cmdline_user_args())
	var messages: Array = arguments["messages"]
	for message: Variant in messages:
		print(message)
	_menu = $Menu as MenuPrincipal
	_menu.configurer(chemin_reglages)
	_menu.solo_demande.connect(_lancer_solo)
	_menu.quitter_demande.connect(_quitter)
	_menu.reglages_modifies.connect(_appliquer_reglages)
	_appliquer_reglages(Reglages.charger(chemin_reglages))
	if bool(arguments["solo_auto"]):
		_lancer_solo(_menu.nom_joueur())


func menu() -> MenuPrincipal:
	return _menu


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
	if _jeu != null:
		remove_child(_jeu)
		_jeu.queue_free()
		_jeu = null
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
