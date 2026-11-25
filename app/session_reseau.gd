class_name SessionReseau
extends Node
## Le multijoueur vu du menu : héberger un salon (un `Canal` avec son `Serveur`, un `Client` local
## qui s'y connecte en 127.0.0.1, et l'annonce de découverte) ou rejoindre celui d'un autre
## (un `Client`). Chaque côté a sa propre racine et sa propre `SceneMultiplayer` : un arbre n'en
## porte qu'une par défaut, et l'hôte est serveur et client dans le même processus.

signal salon_mis_a_jour(salon: Salon)
signal partie_demarree
## Refus, serveur injoignable ou perdu. Une seule émission par session.
signal connexion_perdue(motif: String)

const ADRESSE_LOCALE := "127.0.0.1"

var client: Client = null
var serveur: Serveur = null
var decouverte: Decouverte = null
var nom_salon: String = ""
var port: int = 0
## Jeton d'hôte de la session hébergée (8 octets), tiré à chaque `heberger` ; vide sinon. Il réserve
## le rôle d'hôte au client local et ne doit être ni affiché ni journalisé.
var jeton_hote: PackedByteArray = PackedByteArray()
## `(n: int) -> PackedByteArray` : source des octets du jeton, remplacée dans les tests.
var source_octets: Callable = _octets_aleatoires

var _racines: Array[Node] = []
var _apis: Array[SceneMultiplayer] = []
var _perdue: bool = false


## Le motif lisible d'une erreur de création (port occupé, port invalide, données absentes).
static func message_erreur(code: Error, port_demande: int) -> String:
	match code:
		ERR_CANT_CREATE, ERR_ALREADY_IN_USE:
			return TranslationServer.translate("CONNEXION_ERREUR_PORT_PRIS") % port_demande
		ERR_INVALID_PARAMETER:
			return TranslationServer.translate("CONNEXION_ERREUR_PORT")
		ERR_FILE_CORRUPT:
			return TranslationServer.translate("MENU_ERREUR_DONNEES")
		_:
			return TranslationServer.translate("CONNEXION_ERREUR_CREATION") % int(code)


func est_hote() -> bool:
	return serveur != null


func est_ouverte() -> bool:
	return client != null


## Ouvre un salon sur cette machine. `port_decouverte` et `cibles` ne changent que pour les tests.
func heberger(
	donnees: Donnees,
	port_jeu: int,
	nom_du_salon: String,
	nom_joueur: String,
	port_decouverte: int = Decouverte.PORT_DECOUVERTE,
	cibles: Array[String] = [Decouverte.DIFFUSION]
) -> Error:
	fermer()
	var tirage: Variant = source_octets.call(Protocole.JETON_OCTETS)
	# Un jeton absent ou de mauvaise taille ferait retomber le salon sur « le premier pair est
	# hôte » : on n'ouvre rien plutôt que de laisser un pair distant prendre le rôle.
	if (
		not tirage is PackedByteArray
		or (tirage as PackedByteArray).size() != Protocole.JETON_OCTETS
	):
		return ERR_UNAVAILABLE
	jeton_hote = tirage as PackedByteArray
	var canal_serveur := _nouvelle_racine("RacineHote")
	var s := Serveur.new()
	s.name = "Serveur"
	s.jeton_hote = jeton_hote
	canal_serveur.add_child(s)
	var code := s.demarrer(donnees, port_jeu)
	if code != OK:
		fermer()
		return code
	serveur = s
	nom_salon = nom_du_salon
	port = port_jeu
	code = _connecter_client(donnees, ADRESSE_LOCALE, port_jeu, nom_joueur, jeton_hote)
	if code != OK:
		fermer()
		return code
	decouverte = Decouverte.new()
	decouverte.name = "Decouverte"
	add_child(decouverte)
	decouverte.fournisseur = _annonce
	# Une annonce impossible (réseau absent) ne gêne pas le salon : on y entre par l'adresse.
	decouverte.annoncer(port_decouverte, cibles)
	return OK


## Se connecte à un salon. La réponse (salon, refus, injoignable) arrive par les signaux.
func rejoindre(donnees: Donnees, adresse: String, port_jeu: int, nom_joueur: String) -> Error:
	fermer()
	var code := _connecter_client(donnees, adresse, port_jeu, nom_joueur)
	if code != OK:
		fermer()
	return code


## Ferme tout, dans l'ordre : l'annonce, le client (départ voulu), le serveur, les racines.
func fermer() -> void:
	if decouverte != null:
		decouverte.arreter()
		remove_child(decouverte)
		decouverte.queue_free()
		decouverte = null
	if client != null:
		client.deconnecter()
		client = null
	if serveur != null:
		serveur.arreter()
		serveur = null
	for api: SceneMultiplayer in _apis:
		api.multiplayer_peer = null
	_apis = []
	jeton_hote = PackedByteArray()
	for racine: Node in _racines:
		if racine.get_parent() != null:
			racine.get_parent().remove_child(racine)
		racine.queue_free()
	_racines = []
	_perdue = false


static func _octets_aleatoires(n: int) -> PackedByteArray:
	return Crypto.new().generate_random_bytes(n)


func _nouvelle_racine(nom: String) -> Canal:
	var racine := Node.new()
	racine.name = nom
	add_child(racine)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, racine.get_path())
	_apis.append(api)
	_racines.append(racine)
	var canal := Canal.new()
	canal.name = "Canal"
	racine.add_child(canal)
	return canal


func _connecter_client(
	donnees: Donnees,
	adresse: String,
	port_jeu: int,
	nom: String,
	jeton: PackedByteArray = PackedByteArray()
) -> Error:
	var canal := _nouvelle_racine("RacineClient")
	var c := Client.new()
	c.name = "Client"
	c.donnees = donnees
	canal.add_child(c)
	var code := c.connecter(adresse, port_jeu, nom, jeton)
	if code != OK:
		return code
	client = c
	c.salon_mis_a_jour.connect(salon_mis_a_jour.emit)
	c.partie_demarree.connect(partie_demarree.emit)
	c.connexion_perdue.connect(_sur_perte)
	return OK


func _sur_perte(motif: String) -> void:
	if _perdue:
		return
	_perdue = true
	connexion_perdue.emit(motif)


## Ce que l'annonce dit du salon : le nombre de joueurs suit le salon du serveur. Une fois la
## partie lancée, on n'annonce plus rien : plus personne ne peut entrer.
func _annonce() -> Dictionary:
	if serveur == null:
		return {}
	if serveur.partie != null:
		return {}
	return {
		"nom": nom_salon,
		"joueurs": serveur.salon.joueurs.size(),
		"max": Salon.MAX_JOUEURS,
		"port": port,
	}
