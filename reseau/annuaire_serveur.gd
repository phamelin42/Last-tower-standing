class_name AnnuaireServeur
extends Node
## Nœud TCP de l'annuaire (ADR 001) : accepte les connexions, lit un cadre par connexion, confie
## les décisions à `AnnuaireService`, lance les sondes d'`AnnuaireSonde`, écrit la réponse et
## ferme. Aucune règle ici : les contrôles et les plafonds sont ceux du service. Ce nœud tient les
## délais (3 s pour recevoir le cadre, 7 s de vie au plus) et ne journalise que des compteurs.
##
## Une connexion se ferme seulement après l'écriture complète de la réponse, et après avoir vidé
## ce que le client a encore envoyé : fermer un socket qui a des octets non lus envoie un RST, qui
## peut faire perdre au client une réponse déjà écrite.

enum Etat { RECEPTION, SONDE, ECRITURE, FERMETURE }

const ADRESSE_ECOUTE: String = "0.0.0.0"
const DELAI_RECEPTION_MS: int = 3_000
const DELAI_VIE_MS: int = 7_000
## Après la réponse, on laisse au client le temps de fermer le premier (il lit puis ferme).
const GRACE_FERMETURE_MS: int = 1_000
const PERIODE_JOURNAL_MS: int = 60_000
const PERIODE_PURGE_MS: int = 1_000
const MAX_ACCEPTEES_PAR_IMAGE: int = 64
## Le plus grand cadre entrant légitime : préfixe de 2 octets et 128 octets de corps.
const MAX_LECTURE: int = 2 + AnnuaireProtocole.MAX_CORPS_REQUETE

var service: AnnuaireService = AnnuaireService.new()
var sonde: AnnuaireSonde = AnnuaireSonde.new()
## Horloge en millisecondes, remplaçable par les tests ; elle est aussi donnée au service et à la
## sonde.
var horloge: Callable = Callable():
	set(valeur):
		horloge = valeur
		service.horloge = valeur
		sonde.horloge = valeur
## Adresse de l'autre bout d'une connexion (`StreamPeerTCP.get_connected_host` par défaut).
var source_adresse: Callable = Callable()
## Sortie du journal (`print` par défaut) : des compteurs agrégés, jamais une IP.
var journal: Callable = Callable()

var _serveur: TCPServer = null
var _connexions: Array[_Connexion] = []
var _par_sonde: Dictionary = {}
var _prochaine_purge: int = 0
var _prochain_journal: int = 0


class _Connexion:
	extends RefCounted
	var pair: StreamPeerTCP = null
	var ip: String = ""
	var debut: int = 0
	var recu: PackedByteArray = PackedByteArray()
	var etat: Etat = Etat.RECEPTION
	var a_ecrire: PackedByteArray = PackedByteArray()
	var ecrit: int = 0
	var fin_ecriture: int = 0
	var terminee: bool = false


## Ouvre le port TCP sur toutes les interfaces IPv4. Renvoie `OK` ou l'erreur du système.
func demarrer(port: int) -> Error:
	if _serveur != null:
		return ERR_ALREADY_IN_USE
	if port < 1 or port > 65535:
		return ERR_INVALID_PARAMETER
	var ouverture := TCPServer.new()
	var erreur := ouverture.listen(port, ADRESSE_ECOUTE)
	if erreur != OK:
		return erreur
	_serveur = ouverture
	var t := _maintenant()
	_prochaine_purge = t + PERIODE_PURGE_MS
	_prochain_journal = t + PERIODE_JOURNAL_MS
	return OK


func arreter() -> void:
	for connexion: _Connexion in _connexions:
		_fermer(connexion)
	_connexions.clear()
	_par_sonde.clear()
	sonde.annuler_tout()
	if _serveur != null:
		_serveur.stop()
		_serveur = null


func est_actif() -> bool:
	return _serveur != null and _serveur.is_listening()


func port_ecoute() -> int:
	return _serveur.get_local_port() if est_actif() else 0


func nb_connexions() -> int:
	return _connexions.size()


func _process(_delta: float) -> void:
	traiter()


## Un pas : accepte, lit, avance les sondes, écrit, ferme, purge, journalise.
func traiter() -> void:
	if not est_actif():
		return
	var t := _maintenant()
	_accepter(t)
	_resultats_de_sondes()
	for connexion: _Connexion in _connexions.duplicate():
		_avancer(connexion, t)
	_connexions = _connexions.filter(func(c: _Connexion) -> bool: return not c.terminee)
	if t >= _prochaine_purge:
		_prochaine_purge = t + PERIODE_PURGE_MS
		service.purger()
	if t >= _prochain_journal:
		_prochain_journal = t + PERIODE_JOURNAL_MS
		_journaliser()


func _accepter(t: int) -> void:
	for i: int in MAX_ACCEPTEES_PAR_IMAGE:
		if not _serveur.is_connection_available():
			return
		var pair := _serveur.take_connection()
		if pair == null:
			return
		var ip := _adresse_de(pair)
		if service.connexion_ouverte(ip) != AnnuaireService.Accueil.OK:
			pair.disconnect_from_host()
			continue
		var connexion := _Connexion.new()
		connexion.pair = pair
		connexion.ip = ip
		connexion.debut = t
		_connexions.append(connexion)


func _resultats_de_sondes() -> void:
	for fini: Dictionary in sonde.sondes_finies():
		var suivi: Dictionary = _par_sonde.get(int(fini["ticket"]), {})
		if suivi.is_empty():
			continue
		_par_sonde.erase(int(fini["ticket"]))
		var reponse := service.sonde_terminee(int(suivi["service"]), bool(fini["ok"]))
		var connexion: _Connexion = suivi["connexion"]
		if connexion != null and not connexion.terminee and connexion.etat == Etat.SONDE:
			_ecrire(connexion, reponse)


func _avancer(c: _Connexion, t: int) -> void:
	c.pair.poll()
	# `poll` ferme le socket quand le client est parti sans rien laisser : interroger un socket
	# fermé journalise une erreur.
	var present := c.pair.get_status() == StreamPeerTCP.STATUS_CONNECTED
	var disponibles := c.pair.get_available_bytes() if present else 0
	var parti := not present
	match c.etat:
		Etat.RECEPTION:
			_recevoir(c, t, disponibles, parti)
		Etat.SONDE:
			_vider(c, disponibles)
			if parti or t - c.debut >= DELAI_VIE_MS:
				_fermer(c)
		Etat.ECRITURE:
			_vider(c, disponibles)
			_poursuivre_ecriture(c, t)
			if not c.terminee and (parti or t - c.debut >= DELAI_VIE_MS):
				_fermer(c)
		Etat.FERMETURE:
			_vider(c, disponibles)
			if parti or t - c.fin_ecriture >= GRACE_FERMETURE_MS or t - c.debut >= DELAI_VIE_MS:
				_fermer(c)


func _recevoir(c: _Connexion, t: int, disponibles: int, parti: bool) -> void:
	if disponibles > 0 and c.recu.size() < MAX_LECTURE:
		var lu := c.pair.get_partial_data(mini(disponibles, MAX_LECTURE - c.recu.size()))
		if lu[0] == OK:
			c.recu.append_array(lu[1])
			_decider(c, t, service.evaluer(c.ip, c.recu))
			return
	if parti:
		service.fermeture_prematuree(c.ip, c.recu)
		_fermer(c)
	elif t - c.debut >= DELAI_RECEPTION_MS:
		service.delai_depasse(c.ip, c.recu)
		_fermer(c)


func _decider(c: _Connexion, _t: int, resultat: Dictionary) -> void:
	match resultat["action"]:
		AnnuaireService.Action.FERMER:
			_fermer(c)
		AnnuaireService.Action.REPONDRE:
			_ecrire(c, resultat["octets"])
		AnnuaireService.Action.SONDER:
			var ticket := sonde.demarrer(str(resultat["ip"]), int(resultat["port"]))
			_par_sonde[ticket] = {"service": int(resultat["ticket"]), "connexion": c}
			c.etat = Etat.SONDE


func _ecrire(c: _Connexion, octets: PackedByteArray) -> void:
	c.etat = Etat.ECRITURE
	c.a_ecrire = octets
	c.ecrit = 0
	_poursuivre_ecriture(c, _maintenant())


## Écriture non bloquante : un client qui ne lit pas ne doit pas figer les autres.
func _poursuivre_ecriture(c: _Connexion, t: int) -> void:
	if c.terminee or c.etat != Etat.ECRITURE:
		return
	while c.ecrit < c.a_ecrire.size():
		var envoi := c.pair.put_partial_data(c.a_ecrire.slice(c.ecrit))
		if envoi[0] != OK or int(envoi[1]) <= 0:
			return
		c.ecrit += int(envoi[1])
	c.etat = Etat.FERMETURE
	c.fin_ecriture = t


## Jette ce que le client envoie encore, pour qu'aucun octet non lu ne provoque un RST.
func _vider(c: _Connexion, disponibles: int) -> void:
	if disponibles > 0:
		c.pair.get_partial_data(disponibles)


func _fermer(c: _Connexion) -> void:
	if c.terminee:
		return
	c.terminee = true
	c.pair.disconnect_from_host()
	service.connexion_fermee(c.ip)
	for suivi: Dictionary in _par_sonde.values():
		if suivi["connexion"] == c:
			suivi["connexion"] = null


func _journaliser() -> void:
	var statuts: PackedStringArray = []
	var compteurs := service.compteurs()
	var cles: Array = compteurs.keys()
	cles.sort()
	for statut: Variant in cles:
		statuts.append("%d=%d" % [int(statut), int(compteurs[statut])])
	service.reinitialiser_compteurs()
	var texte := (
		"Annuaire : %d salon(s) listé(s), réponses par statut [%s]."
		% [service.salons_listes(), ", ".join(statuts)]
	)
	if journal.is_valid():
		journal.call(texte)
	else:
		print(texte)


func _adresse_de(pair: StreamPeerTCP) -> String:
	if source_adresse.is_valid():
		return str(source_adresse.call(pair))
	return pair.get_connected_host()


func _maintenant() -> int:
	if horloge.is_valid():
		return int(horloge.call())
	return Time.get_ticks_msec()
