class_name Decouverte
extends Node
## Découverte des salons du réseau local, en UDP, hors du jeu (ENet) : l'hôte annonce son salon
## chaque seconde (diffusion sur `PORT_DECOUVERTE`), le chercheur écoute et tient la liste à jour.
## Un salon qui se tait plus de `EXPIRATION_S` disparaît. Tout paquet reçu est une donnée non
## fiable : invalide, trop grand ou d'une autre version, il est ignoré sans bruit.
##
## Annonce (7 octets + nom) : `u8 magie · u8 version · u8 joueurs · u8 max · u16 port du jeu ·
## u8 n + nom UTF-8` (au plus 24 caractères, soit 96 octets : 103 octets au pire).

## La liste a changé (salon apparu, mis à jour ou expiré).
signal liste_changee

## Port UDP fixe des annonces (le port de jeu ENet, 7777 par défaut, est annoncé dans le paquet).
const PORT_DECOUVERTE: int = 7778
const PERIODE_S: float = 1.0
const EXPIRATION_S: float = 3.0
const MAGIE: int = 0x4C
const MAX_TAILLE: int = 128
## Au plus ce nombre de salons retenus : une inondation d'annonces forgées ne gonfle pas la liste.
const MAX_SALONS: int = 64
## Au plus ce nombre de paquets lus par image : le reste attend l'image suivante.
const PAQUETS_PAR_IMAGE: int = 64
const DIFFUSION: String = "255.255.255.255"
const _ENTETE: int = 7

## Donne l'annonce de l'hôte : `{nom, joueurs, max, port}`. Appelée à chaque émission.
var fournisseur: Callable = Callable()
## Horloge en secondes, injectable pour les tests.
var horloge: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

var _salons: Dictionary = {}
var _entree: PacketPeerUDP = null
var _sortie: PacketPeerUDP = null
var _port_udp: int = PORT_DECOUVERTE
var _cibles: Array[String] = []
var _acc: float = 0.0

# --- Codec -----------------------------------------------------------------------------------


static func encoder(nom: String, joueurs: int, maxi: int, port: int) -> PackedByteArray:
	var propre := ""
	for i: int in nom.length():
		var c := nom.unicode_at(i)
		if c >= 32 and c != 127:
			propre += char(c)
	var octets := propre.substr(0, Protocole.MAX_NOM).to_utf8_buffer()
	var b := PackedByteArray()
	b.resize(_ENTETE + octets.size())
	b.encode_u8(0, MAGIE)
	b.encode_u8(1, Protocole.VERSION)
	b.encode_u8(2, clampi(joueurs, 0, 255))
	b.encode_u8(3, clampi(maxi, 0, 255))
	b.encode_u16(4, clampi(port, 0, 65535))
	b.encode_u8(6, octets.size())
	for i: int in octets.size():
		b[_ENTETE + i] = octets[i]
	return b


## `{nom, joueurs, max, port}`, ou `{}` pour toute annonce invalide, trop grande, incohérente ou
## d'une autre version du protocole.
static func decoder(b: PackedByteArray) -> Dictionary:
	if b.size() < _ENTETE or b.size() > MAX_TAILLE:
		return {}
	var l := Protocole.LecteurOctets.new(b)
	if l.u8() != MAGIE or l.u8() != Protocole.VERSION:
		return {}
	var joueurs := l.u8()
	var maxi := l.u8()
	var port := l.u16()
	var nom := l.texte(l.u8(), Protocole.MAX_NOM)
	if not l.ok or l.reste() != 0 or nom.is_empty():
		return {}
	if maxi < 1 or maxi > Salon.MAX_JOUEURS or joueurs > maxi or port < 1:
		return {}
	return {"nom": nom, "joueurs": joueurs, "max": maxi, "port": port}


# --- Chercheur -------------------------------------------------------------------------------


## Écoute les annonces. Une erreur (port UDP déjà pris, par un autre jeu lancé sur la même
## machine) laisse la liste vide : l'adresse saisie à la main reste possible.
func chercher(port_udp: int = PORT_DECOUVERTE, adresse: String = "*") -> Error:
	arreter()
	var socket := PacketPeerUDP.new()
	var code := socket.bind(port_udp, adresse)
	if code != OK:
		return code
	_entree = socket
	_salons = {}
	return OK


## Retient une annonce reçue de `adresse`. Faux (rien retenu) si elle est invalide.
func recevoir(octets: PackedByteArray, adresse: String) -> bool:
	var a := decoder(octets)
	if a.is_empty():
		return false
	var cle := "%s:%d" % [adresse, int(a["port"])]
	var maintenant := _maintenant()
	var ancien: Variant = _salons.get(cle)
	if ancien == null and _salons.size() >= MAX_SALONS:
		if _purger_silencieux(maintenant) == 0:
			return false
	var change := ancien == null
	if ancien != null:
		var s: Dictionary = ancien
		change = s["nom"] != a["nom"] or s["joueurs"] != a["joueurs"] or s["max"] != a["max"]
	_salons[cle] = {
		"nom": a["nom"],
		"joueurs": a["joueurs"],
		"max": a["max"],
		"port": a["port"],
		"adresse": adresse,
		"vu": maintenant,
	}
	if change:
		liste_changee.emit()
	return true


## Les salons vivants, triés par nom puis par adresse.
func salons() -> Array[Dictionary]:
	_purger_silencieux(_maintenant())
	var sortie: Array[Dictionary] = []
	for cle: String in _salons:
		sortie.append(_salons[cle])
	sortie.sort_custom(
		func(x: Dictionary, y: Dictionary) -> bool:
			if x["nom"] != y["nom"]:
				return String(x["nom"]) < String(y["nom"])
			return String(x["adresse"]) + str(x["port"]) < String(y["adresse"]) + str(y["port"])
	)
	return sortie


## Retire les salons expirés et prévient si la liste a changé.
func purger() -> void:
	if _purger_silencieux(_maintenant()) > 0:
		liste_changee.emit()


func _purger_silencieux(maintenant: float) -> int:
	var perdus: Array[String] = []
	for cle: String in _salons:
		var s: Dictionary = _salons[cle]
		if maintenant - float(s["vu"]) >= EXPIRATION_S:
			perdus.append(cle)
	for cle: String in perdus:
		_salons.erase(cle)
	return perdus.size()


func _maintenant() -> float:
	return float(horloge.call())


# --- Annonceur -------------------------------------------------------------------------------


## Commence à annoncer, d'abord tout de suite puis chaque seconde. `cibles` : adresses de
## destination (la diffusion par défaut ; les tests visent 127.0.0.1).
func annoncer(port_udp: int = PORT_DECOUVERTE, cibles: Array[String] = [DIFFUSION]) -> Error:
	arreter_annonce()
	if not fournisseur.is_valid():
		return ERR_UNCONFIGURED
	var socket := PacketPeerUDP.new()
	socket.set_broadcast_enabled(true)
	_sortie = socket
	_port_udp = port_udp
	_cibles = cibles
	_acc = 0.0
	emettre()
	return OK


## Envoie l'annonce courante à chaque cible. Les erreurs d'envoi (réseau absent) sont sans suite :
## la prochaine seconde réessaie.
func emettre() -> void:
	if _sortie == null or not fournisseur.is_valid():
		return
	var a: Dictionary = fournisseur.call()
	var octets := encoder(
		String(a.get("nom", "")),
		int(a.get("joueurs", 0)),
		int(a.get("max", Salon.MAX_JOUEURS)),
		int(a.get("port", 0))
	)
	for cible: String in _cibles:
		if _sortie.set_dest_address(cible, _port_udp) == OK:
			_sortie.put_packet(octets)


## Fait avancer l'horloge d'émission de `dt` secondes (appelée à chaque image).
func avancer(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	_acc += dt
	if _acc >= PERIODE_S:
		# Un grand `dt` (fenêtre gelée) ne déclenche qu'une annonce, pas une rafale.
		_acc = fmod(_acc, PERIODE_S)
		emettre()


func arreter_annonce() -> void:
	if _sortie != null:
		_sortie.close()
	_sortie = null


## Coupe l'écoute et l'annonce.
func arreter() -> void:
	arreter_annonce()
	if _entree != null:
		_entree.close()
	_entree = null
	_salons = {}


func _process(delta: float) -> void:
	if _sortie != null:
		avancer(delta)
	if _entree != null:
		_lire()
		purger()


func _lire() -> void:
	for _i: int in PAQUETS_PAR_IMAGE:
		if _entree.get_available_packet_count() <= 0:
			return
		var octets := _entree.get_packet()
		if _entree.get_packet_error() != OK:
			continue
		recevoir(octets, _entree.get_packet_ip())


func _exit_tree() -> void:
	arreter()
