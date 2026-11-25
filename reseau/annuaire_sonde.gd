class_name AnnuaireSonde
extends RefCounted
## Sonde de joignabilité (ADR 001, § Joignabilité) : une connexion ENet depuis le service vers
## `ip:port`, coupée aussitôt établie. Asynchrone et sans thread : `demarrer` ouvre un hôte ENet
## client par sonde, `sondes_finies` (appelée à chaque image) les fait avancer et rend les
## résultats. Elle ne filtre aucune adresse : le service refuse les adresses non publiques avant
## de lancer une sonde.
##
## Les tests de nœud remplacent cette classe par un double qui en reprend les trois méthodes
## publiques.

## Au-delà, la sonde échoue : ENet ignore les erreurs ICMP et attendrait sans fin.
const DELAI_MS: int = 4_000
const CANAUX: int = 1

## Horloge en millisecondes (`Time.get_ticks_msec` par défaut), remplaçable par les tests.
var horloge: Callable = Callable()

var _en_cours: Dictionary = {}
var _echecs_immediats: Array[int] = []
var _prochain_ticket: int = 1


class _Essai:
	extends RefCounted
	var hote: ENetConnection = null
	var pair: ENetPacketPeer = null
	var debut: int = 0


## Lance une sonde et renvoie son ticket. Une cible impossible à ouvrir (adresse ou port
## invalides) échoue au prochain `sondes_finies`, sans exception.
func demarrer(ip: String, port: int) -> int:
	var ticket := _prochain_ticket
	_prochain_ticket += 1
	if not ip.is_valid_ip_address() or port < 1 or port > 65535:
		_echecs_immediats.append(ticket)
		return ticket
	var essai := _Essai.new()
	essai.hote = ENetConnection.new()
	if essai.hote.create_host(1, CANAUX) != OK:
		_echecs_immediats.append(ticket)
		return ticket
	essai.pair = essai.hote.connect_to_host(ip, port, CANAUX)
	if essai.pair == null:
		essai.hote.destroy()
		_echecs_immediats.append(ticket)
		return ticket
	essai.debut = _maintenant()
	_en_cours[ticket] = essai
	return ticket


## Sondes terminées depuis le dernier appel : `{ticket, ok}`. À appeler à chaque image.
func sondes_finies() -> Array[Dictionary]:
	var finies: Array[Dictionary] = []
	for ticket: int in _echecs_immediats:
		finies.append({"ticket": ticket, "ok": false})
	_echecs_immediats.clear()
	var t := _maintenant()
	for ticket: Variant in _en_cours.keys():
		var essai: _Essai = _en_cours[ticket]
		var resultat := _avancer(essai, t)
		if resultat != 0:
			_fermer(essai)
			_en_cours.erase(ticket)
			finies.append({"ticket": int(ticket), "ok": resultat > 0})
	return finies


func nb_en_cours() -> int:
	return _en_cours.size()


## Abandonne toutes les sondes, sans rendre de résultat (arrêt du service).
func annuler_tout() -> void:
	for essai: _Essai in _en_cours.values():
		_fermer(essai)
	_en_cours.clear()
	_echecs_immediats.clear()


## 1 : connexion établie, -1 : échec, 0 : encore en cours.
func _avancer(essai: _Essai, t: int) -> int:
	# Les paquets reçus (le serveur de jeu envoie son identifiant) ne nous intéressent pas.
	for i: int in 8:
		var evenement: Array = essai.hote.service(0)
		var type: int = evenement[0]
		match type:
			ENetConnection.EVENT_CONNECT:
				return 1
			ENetConnection.EVENT_DISCONNECT, ENetConnection.EVENT_ERROR:
				return -1
			ENetConnection.EVENT_NONE:
				break
	return -1 if t - essai.debut >= DELAI_MS else 0


## Coupe sans attendre l'accusé, puis envoie la demande de déconnexion et libère l'hôte.
func _fermer(essai: _Essai) -> void:
	if essai.pair != null:
		essai.pair.peer_disconnect_now()
	essai.hote.flush()
	essai.hote.destroy()


func _maintenant() -> int:
	if horloge.is_valid():
		return int(horloge.call())
	return Time.get_ticks_msec()
