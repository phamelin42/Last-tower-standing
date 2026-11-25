class_name UpnpHote
extends Node
## Ouverture du port UDP de jeu par UPnP chez l'hôte (ADR 001, « UPnP chez l'hôte »).
##
## Les appels de `UPNP` bloquent : un seul fil dédié les exécute, sur ordre (ouvrir, renouveler,
## fermer), et le résultat revient par un appel différé. Un échec n'est jamais bloquant : le jeu
## continue en réseau local, `tentative_terminee` dit simplement 0.

## Émis une seule fois par tentative, réussie ou non : le port externe obtenu, 0 en cas d'échec.
signal tentative_terminee(port_externe: int)
## Un renouvellement a échoué en cours de partie : le jeu continue, la redirection expirera.
signal renouvellement_echoue

const DELAI_DECOUVERTE_MS := 2000
const BAIL_S := 3600
const PERIODE_RENOUVELLEMENT_S := 1800.0
const DELAI_FERMETURE_S := 2.0
const PORT_ALEATOIRE_MIN := 49152
const PORT_ALEATOIRE_MAX := 65535
const DESCRIPTION := "Last Tower Standing"

## Fils dont la fermeture a dépassé le délai : gardés en vie ici, un `Thread` libéré en cours
## d'exécution plante le moteur. Chacun finit seul (la commande « fermer » est déjà postée).
static var _abandonnes: Array[Thread] = []

## La box vue par l'hôte ; remplacée par un double dans les tests.
var passerelle: Passerelle = null
## Période du renouvellement (secondes), réglable pour les tests.
var periode_renouvellement: float = PERIODE_RENOUVELLEMENT_S
## Attente maximale de la fin du fil à la fermeture (secondes).
var delai_fermeture: float = DELAI_FERMETURE_S
## Tire le port du second essai ; graine fixée dans les tests.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Port externe obtenu, 0 tant que la tentative n'a pas réussi (et après la fermeture).
var port_externe: int = 0

var _fil: Thread = null
var _semaphore: Semaphore = Semaphore.new()
var _mutex: Mutex = Mutex.new()
var _commandes: Array[String] = []
var _annule: bool = false
var _port_interne: int = 0
# Écrits par le fil seul ; lus ici une fois l'appel différé arrivé ou le fil terminé.
var _ouvert: int = 0
var _bail: int = BAIL_S
var _resultat: int = 0
var _livree: bool = false
var _ferme: bool = false
var _ecoule: float = 0.0
var _renouvellements: int = 0


## Adaptateur de la classe `UPNP` : seul endroit qui la touche, remplacé par un double en test.
class Passerelle:
	extends RefCounted

	func decouvrir(_delai_ms: int) -> int:
		return UPNP.UPNP_RESULT_NO_GATEWAY

	func adresse_externe() -> String:
		return ""

	func ajouter(_port_externe: int, _port_interne: int, _bail_s: int) -> int:
		return UPNP.UPNP_RESULT_NO_GATEWAY

	func supprimer(_port_externe: int) -> int:
		return UPNP.UPNP_RESULT_NO_GATEWAY


## La vraie box, par `UPNP`.
class PasserelleUpnp:
	extends Passerelle
	var _upnp: UPNP = UPNP.new()

	func decouvrir(delai_ms: int) -> int:
		var code: int = _upnp.discover(delai_ms)
		if code != UPNP.UPNP_RESULT_SUCCESS:
			return code
		var box: UPNPDevice = _upnp.get_gateway()
		if box == null or not box.is_valid_gateway():
			return UPNP.UPNP_RESULT_NO_GATEWAY
		return UPNP.UPNP_RESULT_SUCCESS

	func adresse_externe() -> String:
		return _upnp.query_external_address()

	func ajouter(port_externe: int, port_interne: int, bail_s: int) -> int:
		return _upnp.add_port_mapping(port_externe, port_interne, DESCRIPTION, "UDP", bail_s)

	func supprimer(port_externe: int) -> int:
		return _upnp.delete_port_mapping(port_externe, "UDP")


## Une adresse « externe » privée, partagée (CGNAT) ou locale n'est pas joignable d'Internet.
static func adresse_privee(ip: String) -> bool:
	var morceaux := ip.split(".")
	if morceaux.size() != 4:
		return false
	var a := morceaux[0].to_int()
	var b := morceaux[1].to_int()
	return (
		a == 10
		or a == 127
		or (a == 172 and b >= 16 and b <= 31)
		or (a == 192 and b == 168)
		or (a == 169 and b == 254)
		or (a == 100 and b >= 64 and b <= 127)
	)


static func est_conflit(code: int) -> bool:
	return (
		code == UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING
		or code == UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MECHANISM
	)


## Fils abandonnés encore vivants (les terminés sont récupérés au passage).
static func fils_abandonnes() -> int:
	var vivants: Array[Thread] = []
	for fil: Thread in _abandonnes:
		if fil.is_alive():
			vivants.append(fil)
		else:
			fil.wait_to_finish()
	_abandonnes = vivants
	return _abandonnes.size()


func fil_actif() -> bool:
	return _fil != null


## Lance la tentative pour le port de jeu `port_interne`, sans jamais bloquer l'appelant.
func demarrer(port_interne: int) -> void:
	if _fil != null or _ferme:
		return
	fils_abandonnes()
	if passerelle == null:
		passerelle = PasserelleUpnp.new()
	_port_interne = port_interne
	_fil = Thread.new()
	_fil.start(_boucle)
	_poster("ouvrir")


## Referme le port et arrête le fil. Sans danger si appelée deux fois. Attend le fil jusqu'à
## `delai_fermeture` puis l'abandonne : le bail fini expire seul.
func fermer() -> void:
	if _ferme:
		return
	_ferme = true
	_mutex.lock()
	_annule = true
	_mutex.unlock()
	if _fil != null:
		_poster("fermer")
		var fin := Time.get_ticks_msec() + int(delai_fermeture * 1000.0)
		while _fil.is_alive() and Time.get_ticks_msec() < fin:
			OS.delay_msec(2)
		if _fil.is_alive():
			_abandonnes.append(_fil)
		else:
			_fil.wait_to_finish()
		_fil = null
	port_externe = 0
	# Une tentative coupée ou jamais livrée dit quand même son échec, une seule fois.
	_resultat = 0
	_livrer()


func _exit_tree() -> void:
	fermer()


func _process(delta: float) -> void:
	if _ferme or not _livree or port_externe <= 0 or _bail <= 0:
		return
	_ecoule += delta
	if _ecoule < periode_renouvellement:
		return
	_ecoule = 0.0
	_mutex.lock()
	var deja := _renouvellements > 0
	_mutex.unlock()
	if not deja:
		_poster("renouveler")


func _poster(commande: String) -> void:
	_mutex.lock()
	_commandes.append(commande)
	if commande == "renouveler":
		_renouvellements += 1
	_mutex.unlock()
	_semaphore.post()


func _livrer() -> void:
	if _livree:
		return
	_livree = true
	_mutex.lock()
	var port := _resultat
	_mutex.unlock()
	port_externe = port
	tentative_terminee.emit(port)


func _signaler_echec_renouvellement() -> void:
	if not _ferme:
		renouvellement_echoue.emit()


# --- Fil dédié ---------------------------------------------------------------------------------


func _boucle() -> void:
	while true:
		_semaphore.wait()
		_mutex.lock()
		var commande: String = _commandes.pop_front()
		_mutex.unlock()
		match commande:
			"ouvrir":
				_ouvrir()
			"renouveler":
				_renouveler()
			"fermer":
				_fermer_le_port()
				return


func _est_annule() -> bool:
	_mutex.lock()
	var annule := _annule
	_mutex.unlock()
	return annule


func _ouvrir() -> void:
	var port := 0 if _est_annule() else _tenter()
	_mutex.lock()
	_resultat = port
	_mutex.unlock()
	_livrer.call_deferred()


func _tenter() -> int:
	if passerelle.decouvrir(DELAI_DECOUVERTE_MS) != OK:
		return 0
	# Fermeture demandée pendant la découverte : ne rien ouvrir que `fermer` devrait refermer.
	if _est_annule():
		return 0
	if adresse_privee(passerelle.adresse_externe()):
		return 0
	var code := _ajouter(_port_interne)
	if est_conflit(code) and not _est_annule():
		# Un seul nouvel essai, sur un port tiré hors des ports courants.
		var autre := _port_interne
		while autre == _port_interne:
			autre = rng.randi_range(PORT_ALEATOIRE_MIN, PORT_ALEATOIRE_MAX)
		code = _ajouter(autre)
	return _ouvert if code == OK else 0


## Bail fini d'abord ; si la box le refuse (autrement que par un conflit), bail 0.
func _ajouter(port_ext: int) -> int:
	var code := passerelle.ajouter(port_ext, _port_interne, BAIL_S)
	if code != OK and not est_conflit(code):
		code = passerelle.ajouter(port_ext, _port_interne, 0)
		if code == OK:
			_bail = 0
	if code == OK:
		_ouvert = port_ext
	return code


func _renouveler() -> void:
	_mutex.lock()
	_renouvellements -= 1
	_mutex.unlock()
	if _ouvert <= 0 or _est_annule():
		return
	if passerelle.ajouter(_ouvert, _port_interne, _bail) != OK:
		_signaler_echec_renouvellement.call_deferred()


func _fermer_le_port() -> void:
	if _ouvert > 0:
		passerelle.supprimer(_ouvert)
		_ouvert = 0
