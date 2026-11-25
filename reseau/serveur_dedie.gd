class_name ServeurDedie
extends Node
## Lancement du serveur sans interface : `--serveur --port N --graine N --vitesse X
## --acceleration N --quitter-a-la-fin`. Il n'ajoute aucune règle : il ouvre `Serveur`, journalise
## en français sur la sortie standard (connexions, départs, salon, manches, fin de partie) et
## rouvre le salon après chaque partie, sans redémarrer le processus.
##
## Codes de sortie : 0 normal, 2 données du jeu absentes, 3 port impossible (invalide ou pris).

const CODE_OK: int = 0
const CODE_DONNEES: int = 2
const CODE_PORT: int = 3
const OPTION_ACCELERATION: String = "--acceleration"
const OPTION_QUITTER: String = "--quitter-a-la-fin"

## Sortie du processus : `get_tree().quit(code)` par défaut, remplaçable par les tests.
var sortie: Callable = Callable()

var _quitter_a_la_fin: bool = false
var _nb_joueurs: int = -1
var _partie_suivie: bool = false

@onready var serveur: Serveur = $Canal/Serveur


## Lit les options du serveur dédié, puis délègue le reste à `Arguments` : `acceleration` est
## borné entre 1 et `Serveur.ACCELERATION_MAX`, `quitter_a_la_fin` vaut vrai si le drapeau est là.
static func lire_options(args: PackedStringArray) -> Dictionary:
	var restant := PackedStringArray()
	var acceleration_texte := ""
	var acceleration_donnee := false
	var quitter := false
	var i := 0
	while i < args.size():
		var option := args[i]
		var egal := option.find("=")
		var nom := option.substr(0, egal) if option.begins_with("--") and egal > 0 else option
		match nom:
			OPTION_ACCELERATION:
				acceleration_donnee = true
				if egal > 0:
					acceleration_texte = option.substr(egal + 1)
				elif i + 1 < args.size():
					i += 1
					acceleration_texte = args[i]
			OPTION_QUITTER:
				quitter = true
			_:
				restant.append(option)
		i += 1
	var lu: Dictionary = Arguments.lire(restant)
	var messages: Array = lu["messages"]
	var acceleration := 1
	if acceleration_donnee:
		if acceleration_texte.is_valid_int():
			acceleration = acceleration_texte.to_int()
		else:
			messages.append("Accélération invalide : « %s » (1 par défaut)" % acceleration_texte)
		if acceleration < 1 or acceleration > Serveur.ACCELERATION_MAX:
			messages.append("Accélération bornée à l'intervalle 1 à %d." % Serveur.ACCELERATION_MAX)
		acceleration = clampi(acceleration, 1, Serveur.ACCELERATION_MAX)
	lu["acceleration"] = acceleration
	lu["quitter_a_la_fin"] = quitter
	return lu


## Ouvre le serveur et renvoie son code de sortie (0 : le serveur tourne, il ne se termine que
## par la fin de partie avec `--quitter-a-la-fin`).
func lancer(args: Dictionary, donnees: Donnees) -> int:
	var messages: Array = args.get("messages", [])
	for message: Variant in messages:
		_journal("Avertissement : %s" % str(message))
	if donnees == null:
		_journal("Données du jeu absentes ou invalides : arrêt.")
		return CODE_DONNEES
	_isoler_multijoueur()
	var port: int = int(args.get("port", 0))
	var acceleration: int = int(args.get("acceleration", 1))
	var code := serveur.demarrer(donnees, port, acceleration)
	if code != OK:
		_journal("Port %d impossible (%s) : arrêt." % [port, error_string(code)])
		return CODE_PORT
	_quitter_a_la_fin = bool(args.get("quitter_a_la_fin", false))
	serveur.partie_terminee_serveur.connect(_fin_de_partie)
	multiplayer.peer_connected.connect(_connexion)
	multiplayer.peer_disconnected.connect(_depart)
	_journal(
		(
			"Serveur ouvert sur le port %d, accélération ×%d, en attente de joueurs."
			% [port, acceleration]
		)
	)
	return CODE_OK


## Les RPC se résolvent par un chemin relatif à la racine du multijoueur. Un client
## (`SessionReseau`) a son `Canal` à la racine de sa propre `SceneMultiplayer` : le serveur doit en
## faire autant, sinon il cherche « Canal » sous `/root` au lieu de `ServeurDedie/Canal` et rejette
## tous les paquets. Sans effet si l'appelant (un test) a déjà posé la sienne.
func _isoler_multijoueur() -> void:
	if not is_inside_tree() or multiplayer != get_tree().get_multiplayer():
		return
	get_tree().set_multiplayer(SceneMultiplayer.new(), get_path())


func est_actif() -> bool:
	return serveur.est_actif()


func arreter() -> void:
	if serveur.partie_terminee_serveur.is_connected(_fin_de_partie):
		serveur.partie_terminee_serveur.disconnect(_fin_de_partie)
	if is_inside_tree():
		if multiplayer.peer_connected.is_connected(_connexion):
			multiplayer.peer_connected.disconnect(_connexion)
		if multiplayer.peer_disconnected.is_connected(_depart):
			multiplayer.peer_disconnected.disconnect(_depart)
	serveur.arreter()


func _process(_delta: float) -> void:
	if not serveur.est_actif():
		return
	var nb := serveur.salon.joueurs.size()
	if nb != _nb_joueurs:
		_nb_joueurs = nb
		_journal("Salon : %d joueur(s)." % nb)
	if serveur.partie != null and not _partie_suivie:
		_partie_suivie = true
		_journal("Début de partie avec %d joueur(s)." % nb)
		serveur.partie.manche_commencee.connect(_manche_commencee)


func _connexion(pair: int) -> void:
	_journal("Connexion du pair %d." % pair)


func _depart(pair: int) -> void:
	_journal("Départ du pair %d." % pair)


func _manche_commencee(numero: int) -> void:
	_journal("Manche %d." % numero)


func _fin_de_partie() -> void:
	if serveur.partie != null:
		_journal("Fin de partie : %d joueur(s)." % serveur.salon.joueurs.size())
	if _quitter_a_la_fin:
		_sortir(CODE_OK)
		return
	serveur.rouvrir_salon()
	_partie_suivie = false
	_nb_joueurs = -1
	_journal("Salon rouvert, en attente de joueurs pour une nouvelle partie.")


func _sortir(code: int) -> void:
	if sortie.is_valid():
		sortie.call(code)
	else:
		get_tree().quit(code)


func _journal(texte: String) -> void:
	print(texte)
