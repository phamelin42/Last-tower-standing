class_name AnnuaireService
extends RefCounted
## Logique pure de l'annuaire (ADR 001) : entrées et expiration, seaux à jetons, quotas, filtre
## d'adresses, état des sondes. Sans nœud ni réseau : l'horloge (millisecondes) est injectée, et
## les sondes de joignabilité sont lancées par l'appelant, qui rend leur résultat par
## `sonde_terminee`. Tout est en mémoire, rien sur disque, aucune IP n'est journalisée (§ 14).
##
## L'adresse d'un salon est celle de la connexion TCP (`ip` passée à `evaluer`), jamais un champ du
## message : le message n'en a aucun. Seul le port est déclaré.
##
## `evaluer` applique les contrôles 3 à 13 de l'ADR dans l'ordre, et s'arrête au premier qui
## échoue ; `connexion_ouverte` fait les contrôles 1 et 2.

enum Accueil { OK, ECARTEE, PLAFOND }
enum Action { ATTENTE, FERMER, REPONDRE, SONDER }

const DUREE_EXPIRATION_MS: int = 30_000
const VALIDITE_SUCCES_MS: int = 120_000
const VALIDITE_ECHEC_MS: int = 30_000
const MAX_ENTREES: int = 100
const MAX_PAR_IP: int = 3
const MAX_CONNEXIONS: int = 64
const MAX_CONNEXIONS_IP: int = 4
const MAX_SONDES: int = 4
const MAX_IP_SUIVIES: int = 1024
const MAX_SONDES_MEMORISEES: int = 1024

## Seaux à jetons en millisecondes de recharge : un jeton « coûte » sa période de recharge, donc
## tous les calculs restent entiers et exacts.
const COUT_ANNONCE_MS: int = 5_000
const CAPACITE_ANNONCE_MS: int = 3 * COUT_ANNONCE_MS
const COUT_LISTE_MS: int = 2_000
const CAPACITE_LISTE_MS: int = 5 * COUT_LISTE_MS

const INVALIDES_MAX: int = 5
const FENETRE_INVALIDES_MS: int = 60_000
const MISE_DE_COTE_MS: int = 300_000
const OUBLI_IP_MS: int = 60_000

## Plages IPv4 non publiques : `[base, nombre de bits du préfixe]`. Boucle locale, privées, lien
## local, CGNAT, multicast, non spécifiée et plages réservées ou de documentation.
const _NON_PUBLIQUES: Array[Array] = [
	[0x00000000, 8],
	[0x0A000000, 8],
	[0x64400000, 10],
	[0x7F000000, 8],
	[0xA9FE0000, 16],
	[0xAC100000, 12],
	[0xC0000000, 24],
	[0xC0000200, 24],
	[0xC0A80000, 16],
	[0xC6120000, 15],
	[0xC6336400, 24],
	[0xCB007100, 24],
	[0xE0000000, 4],
	[0xF0000000, 4],
]

## Horloge en millisecondes (`Time.get_ticks_msec` par défaut), remplaçable par les tests.
var horloge: Callable = Callable()
## Désactive le seul rejet des adresses non publiques (tests, vérification de bout en bout).
var autoriser_prive: bool = false

var _entrees: Dictionary = {}
var _par_ip: Dictionary = {}
var _suivi: Dictionary = {}
var _connexions: Dictionary = {}
var _nb_connexions: int = 0
var _sondes: Dictionary = {}
var _cle_en_sonde: Dictionary = {}
var _memoire_sondes: Dictionary = {}
var _prochain_ticket: int = 1
var _compteurs: Dictionary = {}


class _Entree:
	extends RefCounted
	var ip: String = ""
	var port: int = 0
	var version_jeu: int = 0
	var joueurs: int = 0
	var maximum: int = 0
	var nom: String = ""
	var expire: int = 0
	## Réponses 7 consécutives sans sonde réussie ; seule la première prolonge l'entrée.
	var occupees: int = 0


class _SuiviIp:
	extends RefCounted
	var jetons_annonce: int = AnnuaireService.CAPACITE_ANNONCE_MS
	var t_annonce: int = 0
	var jetons_liste: int = AnnuaireService.CAPACITE_LISTE_MS
	var t_liste: int = 0
	var invalides: Array[int] = []
	var ecartee_jusqua: int = 0
	var vu: int = 0


# --- Adresses ----------------------------------------------------------------------------------


## Ramène une IPv4 mappée en IPv6 (`::ffff:a.b.c.d`, ou sa forme hexadécimale) à `a.b.c.d`. Toute
## autre chaîne est rendue telle quelle.
static func normaliser_ip(ip: String) -> String:
	var bas := ip.to_lower()
	var reste := ""
	if bas.begins_with("::ffff:"):
		reste = bas.substr(7)
	elif bas.begins_with("0:0:0:0:0:ffff:"):
		reste = bas.substr(15)
	else:
		return ip
	if not AnnuaireProtocole.ip_en_octets(reste).is_empty():
		return reste
	var parties := reste.split(":")
	if parties.size() != 2:
		return ip
	var valeurs: Array[int] = []
	for partie: String in parties:
		if partie.is_empty() or partie.length() > 4 or not partie.is_valid_hex_number(false):
			return ip
		valeurs.append(partie.hex_to_int())
	return "%d.%d.%d.%d" % [valeurs[0] >> 8, valeurs[0] & 0xFF, valeurs[1] >> 8, valeurs[1] & 0xFF]


## Vrai pour une IPv4 publique ; faux pour toute adresse non publique ou mal formée (dont IPv6).
static func est_publique(ip: String) -> bool:
	var octets := AnnuaireProtocole.ip_en_octets(normaliser_ip(ip))
	if octets.is_empty():
		return false
	var v := (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3]
	for plage: Array in _NON_PUBLIQUES:
		var decalage := 32 - int(plage[1])
		if (v >> decalage) == (int(plage[0]) >> decalage):
			return false
	return true


# --- Connexions (contrôles 1 et 2) ---------------------------------------------------------------


## Contrôle 1 (IP mise de côté) puis 2 (64 connexions, 4 par IP). Une connexion acceptée est
## comptée jusqu'à `connexion_fermee`.
func connexion_ouverte(ip_brute: String) -> Accueil:
	var ip := normaliser_ip(ip_brute)
	var t := _maintenant()
	var ligne: _SuiviIp = _suivi.get(ip)
	if ligne != null and t < ligne.ecartee_jusqua:
		return Accueil.ECARTEE
	if _nb_connexions >= MAX_CONNEXIONS or int(_connexions.get(ip, 0)) >= MAX_CONNEXIONS_IP:
		return Accueil.PLAFOND
	_connexions[ip] = int(_connexions.get(ip, 0)) + 1
	_nb_connexions += 1
	return Accueil.OK


func connexion_fermee(ip_brute: String) -> void:
	var ip := normaliser_ip(ip_brute)
	var n := int(_connexions.get(ip, 0))
	if n <= 0:
		return
	_nb_connexions -= 1
	if n == 1:
		_connexions.erase(ip)
	else:
		_connexions[ip] = n - 1


func nb_connexions() -> int:
	return _nb_connexions


## Le délai de réception (3 s) est passé : la connexion est fermée sans réponse et compte comme
## message invalide, qu'elle ait envoyé des octets ou non.
func delai_depasse(ip_brute: String, _octets: PackedByteArray) -> void:
	_invalide(normaliser_ip(ip_brute), _maintenant())


## Le client a fermé avant la fin du cadre : invalide s'il avait envoyé quelque chose. Une
## connexion ouverte puis fermée sans un octet (contrôle de santé) n'est pas une erreur.
func fermeture_prematuree(ip_brute: String, octets: PackedByteArray) -> void:
	if not octets.is_empty():
		_invalide(normaliser_ip(ip_brute), _maintenant())


# --- Requêtes (contrôles 3 à 13) ------------------------------------------------------------------


## Traite les octets reçus de `ip` depuis l'acceptation. Renvoie `{action}` avec :
## `ATTENTE` (cadre incomplet), `FERMER` (fermer sans répondre), `REPONDRE` (`octets` : le cadre à
## écrire, puis fermer) ou `SONDER` (`ticket`, `ip`, `port` : lancer la sonde, puis appeler
## `sonde_terminee`).
func evaluer(ip_brute: String, octets: PackedByteArray) -> Dictionary:
	var ip := normaliser_ip(ip_brute)
	var t := _maintenant()
	var analyse := AnnuaireProtocole.analyser(octets)
	match analyse["etat"]:
		AnnuaireProtocole.Analyse.ATTENTE:
			return {"action": Action.ATTENTE}
		AnnuaireProtocole.Analyse.FERMER:
			_invalide(ip, t)
			return {"action": Action.FERMER}
		AnnuaireProtocole.Analyse.VERSION_DIFFERENTE:
			return _repondre(AnnuaireProtocole.Statut.VERSION_DIFFERENTE)
		AnnuaireProtocole.Analyse.TROP_GRAND:
			_invalide(ip, t)
			return _repondre(AnnuaireProtocole.Statut.INVALIDE)
	_purger_entrees(t)
	return _traiter(ip, analyse["corps"], t)


## Contrôles 8 à 13 sur un cadre complet.
func _traiter(ip: String, corps: PackedByteArray, t: int) -> Dictionary:
	var type := AnnuaireProtocole.type_de(corps)
	if type < 0:
		_invalide(ip, t)
		return _repondre(AnnuaireProtocole.Statut.INVALIDE)
	var liste := type == AnnuaireProtocole.Type.LISTE
	if not _prendre_jeton(_ligne(ip, t), liste, t):
		return _repondre(AnnuaireProtocole.Statut.DEBIT)
	var champs := _decoder(type, corps)
	if champs.is_empty():
		_invalide(ip, t)
		return _repondre(AnnuaireProtocole.Statut.INVALIDE)
	if liste:
		return {"action": Action.REPONDRE, "octets": AnnuaireProtocole.encoder_salons(salons())}
	if type == AnnuaireProtocole.Type.RETRAIT:
		var cle := _cle(ip, int(champs["port"]))
		_retirer_entree(cle)
		# Une sonde en cours pour cette clé ne doit pas recréer l'entrée à son retour.
		var en_cours: Dictionary = _sondes.get(_cle_en_sonde.get(cle, -1), {})
		if not en_cours.is_empty():
			en_cours["annule"] = true
		return _repondre(AnnuaireProtocole.Statut.ACCEPTE)
	return _annoncer(ip, champs, t)


## Champs de la requête (contrôle 10), `{}` si invalide ; une liste valide donne `{"ok": 1}`.
func _decoder(type: int, corps: PackedByteArray) -> Dictionary:
	match type:
		AnnuaireProtocole.Type.LISTE:
			return {"ok": 1} if AnnuaireProtocole.decoder_liste(corps) else {}
		AnnuaireProtocole.Type.RETRAIT:
			return AnnuaireProtocole.decoder_retrait(corps)
	return AnnuaireProtocole.decoder_annonce(corps)


## Résultat d'une sonde lancée pour un `SONDER`. Renvoie le cadre REPONSE à écrire (vide si le
## ticket est inconnu). L'entrée est créée, mise à jour ou supprimée ici.
func sonde_terminee(ticket: int, joignable: bool) -> PackedByteArray:
	var attente: Dictionary = _sondes.get(ticket, {})
	if attente.is_empty():
		return PackedByteArray()
	_sondes.erase(ticket)
	var cle: String = attente["cle"]
	_cle_en_sonde.erase(cle)
	var t := _maintenant()
	_memoriser_sonde(cle, joignable, t)
	var statut := AnnuaireProtocole.Statut.ACCEPTE
	if not joignable:
		_retirer_entree(cle)
		statut = AnnuaireProtocole.Statut.INJOIGNABLE
	elif not bool(attente.get("annule", false)):
		var existante: _Entree = _entrees.get(cle)
		var ip: String = attente["ip"]
		# Les sondes simultanées n'ont pas vu les entrées les unes des autres : le quota est
		# revérifié à l'arrivée du résultat.
		if existante == null and (_entrees.size() >= MAX_ENTREES or _nb_par_ip(ip) >= MAX_PAR_IP):
			statut = AnnuaireProtocole.Statut.PLEIN
		else:
			var entree := _enregistrer(ip, attente["annonce"], int(attente["t"]), existante)
			entree.occupees = 0
	return _repondre(statut)["octets"]


## Entrées non expirées, dans l'ordre d'arrivée, au plus 100 : `{ip, port, version_jeu, joueurs,
## max, nom}`.
func salons() -> Array[Dictionary]:
	var sortie: Array[Dictionary] = []
	var t := _maintenant()
	for cle: Variant in _entrees:
		var e: _Entree = _entrees[cle]
		if t >= e.expire:
			continue
		(
			sortie
			. append(
				{
					"ip": e.ip,
					"port": e.port,
					"version_jeu": e.version_jeu,
					"joueurs": e.joueurs,
					"max": e.maximum,
					"nom": e.nom,
				}
			)
		)
		if sortie.size() >= AnnuaireProtocole.MAX_SALONS:
			break
	return sortie


## Oublie ce qui a expiré : entrées, résultats de sonde, IP sans requête depuis 60 s (5 min si
## mises de côté).
func purger() -> void:
	var t := _maintenant()
	_purger_entrees(t)
	for cle: Variant in _memoire_sondes.keys():
		if t >= int((_memoire_sondes[cle] as Dictionary)["jusqua"]):
			_memoire_sondes.erase(cle)
	for ip: Variant in _suivi.keys():
		var ligne: _SuiviIp = _suivi[ip]
		if t >= ligne.vu + OUBLI_IP_MS and t >= ligne.ecartee_jusqua:
			_suivi.erase(ip)


func nb_entrees() -> int:
	return _entrees.size()


func nb_sondes() -> int:
	return _sondes.size()


func nb_ip_suivies() -> int:
	return _suivi.size()


## Réponses données depuis la dernière remise à zéro : `{statut: nombre}`. Aucune IP.
func compteurs() -> Dictionary:
	return _compteurs.duplicate()


func reinitialiser_compteurs() -> void:
	_compteurs.clear()


func salons_listes() -> int:
	return salons().size()


# --- Annonce -----------------------------------------------------------------------------------


func _annoncer(ip: String, annonce: Dictionary, t: int) -> Dictionary:
	if not autoriser_prive and not est_publique(ip):
		return _repondre(AnnuaireProtocole.Statut.NON_PUBLIQUE)
	var port := int(annonce["port"])
	var cle := _cle(ip, port)
	var existante: _Entree = _entrees.get(cle)
	if existante == null and (_entrees.size() >= MAX_ENTREES or _nb_par_ip(ip) >= MAX_PAR_IP):
		return _repondre(AnnuaireProtocole.Statut.PLEIN)
	var memoire: Dictionary = _memoire_sondes.get(cle, {})
	if not memoire.is_empty() and t < int(memoire["jusqua"]):
		if bool(memoire["ok"]):
			_enregistrer(ip, annonce, t, existante)
			return _repondre(AnnuaireProtocole.Statut.ACCEPTE)
		_retirer_entree(cle)
		return _repondre(AnnuaireProtocole.Statut.INJOIGNABLE)
	if _cle_en_sonde.has(cle) or _sondes.size() >= MAX_SONDES:
		# Pas de file d'attente : l'hôte réessaie à sa période suivante.
		if existante != null and existante.occupees == 0:
			existante.occupees = 1
			existante.expire = t + DUREE_EXPIRATION_MS
		return _repondre(AnnuaireProtocole.Statut.OCCUPE)
	var ticket := _prochain_ticket
	_prochain_ticket += 1
	_sondes[ticket] = {"cle": cle, "ip": ip, "annonce": annonce, "t": t}
	_cle_en_sonde[cle] = ticket
	return {"action": Action.SONDER, "ticket": ticket, "ip": ip, "port": port}


func _enregistrer(ip: String, annonce: Dictionary, t: int, existante: _Entree) -> _Entree:
	var entree := existante
	if entree == null:
		entree = _Entree.new()
		entree.ip = ip
		entree.port = int(annonce["port"])
		_entrees[_cle(ip, entree.port)] = entree
		_par_ip[ip] = _nb_par_ip(ip) + 1
	entree.version_jeu = int(annonce["version_jeu"])
	entree.joueurs = int(annonce["joueurs"])
	entree.maximum = int(annonce["max"])
	entree.nom = str(annonce["nom"])
	entree.expire = t + DUREE_EXPIRATION_MS
	return entree


func _retirer_entree(cle: String) -> void:
	var e: _Entree = _entrees.get(cle)
	if e == null:
		return
	_entrees.erase(cle)
	var n := _nb_par_ip(e.ip) - 1
	if n <= 0:
		_par_ip.erase(e.ip)
	else:
		_par_ip[e.ip] = n


func _purger_entrees(t: int) -> void:
	for cle: Variant in _entrees.keys():
		if t >= (_entrees[cle] as _Entree).expire:
			_retirer_entree(str(cle))


func _memoriser_sonde(cle: String, ok: bool, t: int) -> void:
	_memoire_sondes.erase(cle)
	if _memoire_sondes.size() >= MAX_SONDES_MEMORISEES:
		_memoire_sondes.erase(_memoire_sondes.keys()[0])
	var duree := VALIDITE_SUCCES_MS if ok else VALIDITE_ECHEC_MS
	_memoire_sondes[cle] = {"ok": ok, "jusqua": t + duree}


# --- Suivi par IP ------------------------------------------------------------------------------


## Ligne de l'IP, créée au besoin et replacée en dernier : les plus anciennes sortent au-delà de
## 1 024.
func _ligne(ip: String, t: int) -> _SuiviIp:
	var ligne: _SuiviIp = _suivi.get(ip)
	if ligne == null:
		ligne = _SuiviIp.new()
		ligne.t_annonce = t
		ligne.t_liste = t
		while _suivi.size() >= MAX_IP_SUIVIES:
			_suivi.erase(_suivi.keys()[0])
	else:
		_suivi.erase(ip)
	ligne.vu = t
	_suivi[ip] = ligne
	return ligne


func _prendre_jeton(ligne: _SuiviIp, liste: bool, t: int) -> bool:
	if liste:
		ligne.jetons_liste = mini(CAPACITE_LISTE_MS, ligne.jetons_liste + t - ligne.t_liste)
		ligne.t_liste = t
		if ligne.jetons_liste < COUT_LISTE_MS:
			return false
		ligne.jetons_liste -= COUT_LISTE_MS
		return true
	ligne.jetons_annonce = mini(CAPACITE_ANNONCE_MS, ligne.jetons_annonce + t - ligne.t_annonce)
	ligne.t_annonce = t
	if ligne.jetons_annonce < COUT_ANNONCE_MS:
		return false
	ligne.jetons_annonce -= COUT_ANNONCE_MS
	return true


## Compte un message invalide ; la 6ᵉ erreur en 60 s met l'IP de côté 5 minutes.
func _invalide(ip: String, t: int) -> void:
	var ligne := _ligne(ip, t)
	var recentes: Array[int] = []
	for quand: int in ligne.invalides:
		if t - quand < FENETRE_INVALIDES_MS:
			recentes.append(quand)
	recentes.append(t)
	ligne.invalides = recentes
	if recentes.size() > INVALIDES_MAX:
		ligne.ecartee_jusqua = t + MISE_DE_COTE_MS
		ligne.invalides = []


# --- Interne -----------------------------------------------------------------------------------


func _repondre(statut: int) -> Dictionary:
	_compteurs[statut] = int(_compteurs.get(statut, 0)) + 1
	return {"action": Action.REPONDRE, "octets": AnnuaireProtocole.encoder_reponse(statut)}


func _nb_par_ip(ip: String) -> int:
	return int(_par_ip.get(ip, 0))


func _cle(ip: String, port: int) -> String:
	return "%s:%d" % [ip, port]


func _maintenant() -> int:
	if horloge.is_valid():
		return int(horloge.call())
	return Time.get_ticks_msec()
