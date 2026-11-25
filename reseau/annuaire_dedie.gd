class_name AnnuaireDedie
extends Node
## Lancement de l'annuaire sans interface : `--annuaire [--port N] [--autoriser-prive]`, comme
## `ServeurDedie` pour `--serveur`. Il ne tient aucune règle : il ouvre `AnnuaireServeur` et
## journalise en français sur la sortie standard, sans jamais écrire une IP.
##
## `--autoriser-prive` désactive le seul rejet des adresses non publiques ; il sert aux tests et
## à la vérification de bout en bout du déploiement, jamais à l'exploitation.
##
## Codes de sortie : 0 normal, 3 port impossible (invalide ou pris).

const CODE_OK: int = 0
const CODE_PORT: int = 3

## Sortie du processus : `get_tree().quit(code)` par défaut, remplaçable par les tests.
var sortie: Callable = Callable()

@onready var serveur: AnnuaireServeur = $Serveur


## Lit les options via `Arguments` ; sans `--port` valide, le port est celui de l'annuaire (7779),
## pas celui du jeu.
static func lire_options(args: PackedStringArray) -> Dictionary:
	var lu: Dictionary = Arguments.lire(args)
	if not bool(lu["port_donne"]):
		lu["port"] = AnnuaireProtocole.PORT_DEFAUT
	return lu


## Ouvre l'annuaire et renvoie son code de sortie (0 : il tourne, sans fin).
func lancer(args: Dictionary) -> int:
	var messages: Array = args.get("messages", [])
	for message: Variant in messages:
		_journal("Avertissement : %s" % str(message))
	var port := int(args.get("port", AnnuaireProtocole.PORT_DEFAUT))
	if not bool(args.get("port_donne", true)):
		port = AnnuaireProtocole.PORT_DEFAUT
	var autoriser_prive := bool(args.get("autoriser_prive", false))
	serveur.service.autoriser_prive = autoriser_prive
	var code := serveur.demarrer(port)
	if code != OK:
		_journal("Port %d impossible (%s) : arrêt." % [port, error_string(code)])
		return CODE_PORT
	if autoriser_prive:
		_journal("Avertissement : --autoriser-prive, les adresses non publiques sont acceptées.")
	_journal("Annuaire ouvert sur le port %d (TCP)." % port)
	return CODE_OK


func est_actif() -> bool:
	return serveur.est_actif()


func arreter() -> void:
	serveur.arreter()


func _journal(texte: String) -> void:
	print(texte)
