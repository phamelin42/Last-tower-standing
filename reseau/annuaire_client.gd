class_name AnnuaireClient
extends Node
## Le jeu face à l'annuaire (ADR 001) : annoncer le salon de l'hôte, le retirer, lister les salons
## des autres. Une requête par connexion TCP, sans fil ni blocage : chaque échange avance à chaque
## image. L'annuaire est un confort : injoignable, lent, invalide ou d'une autre version, il ne
## lève aucune exception et ne gêne jamais le réseau local ni la création d'un salon.
##
## Tout octet reçu vient d'un tiers : le codec unique `AnnuaireProtocole` décode et borne.

## Fin d'une demande de liste. `salons` est vide sauf si `etat` vaut `OK`.
signal liste_terminee(etat: int, salons: Array[Dictionary])
## Fin d'une annonce. `statut` est celui de l'annuaire (`AnnuaireProtocole.Statut`) quand `etat`
## vaut `OK`, `-1` sinon.
signal annonce_terminee(etat: int, statut: int)

## `OK` : une réponse exploitable est arrivée. `DESACTIVE` : adresse vide, rien n'a été tenté.
## `LIMITE` : la liste est refusée pour cause de débit ; l'annuaire marche, on garde la dernière.
enum Etat { OK, DESACTIVE, INDISPONIBLE, INCOMPATIBLE, LIMITE }
enum EtatCadre { ATTENTE, COMPLET, INVALIDE, AUTRE_VERSION }

const PERIODE_ANNONCE_MS: int = 10_000
## Limite de débit du service : 3 en rafale puis 1 par 5 s.
const INTERVALLE_MIN_MS: int = 5_000
const INTERVALLE_LISTE_MS: int = 2_000
const DELAI_CONNEXION_MS: int = 3_000
const DELAI_REPONSE_ANNONCE_MS: int = 8_000
const DELAI_REPONSE_LISTE_MS: int = 3_000
const STATUT_AUCUN: int = -1

## `hote:port` de l'annuaire ; vide le désactive.
var adresse: String = ""
var version_jeu: int = Protocole.VERSION
## Raccourcir la période s'applique à l'annonce en attente, pas seulement à la suivante.
var periode_ms: int = PERIODE_ANNONCE_MS:
	set(valeur):
		periode_ms = valeur
		if _dernier_envoi_ms > 0:
			_prochaine_ms = mini(_prochaine_ms, _dernier_envoi_ms + valeur)
var intervalle_min_ms: int = INTERVALLE_MIN_MS
## Entre deux demandes de liste : la limite du service est une liste par 2 s, au-delà il répond
## « débit dépassé ». Le client n'insiste pas.
var intervalle_liste_ms: int = INTERVALLE_LISTE_MS
var delai_connexion_ms: int = DELAI_CONNEXION_MS
var delai_reponse_annonce_ms: int = DELAI_REPONSE_ANNONCE_MS
var delai_reponse_liste_ms: int = DELAI_REPONSE_LISTE_MS
## Horloge en millisecondes, remplaçable par les tests.
var horloge: Callable = Callable()
## Nombre d'annonces réellement envoyées (pour les tests).
var annonces_envoyees: int = 0

var _fournisseur: Callable = Callable()
var _annonce_active: bool = false
var _echange_annonce: _Echange = null
var _echange_liste: _Echange = null
var _echange_retrait: _Echange = null
var _derniere: Dictionary = {}
var _port_annonce: int = 0
var _dernier_envoi_ms: int = -1_000_000
var _dernier_debut_liste_ms: int = -1_000_000
var _prochaine_ms: int = 0
var _quitte: bool = false


class _Echange:
	extends RefCounted
	enum Phase { RESOLUTION, CONNEXION, REPONSE }
	var type: int = 0
	var requete: PackedByteArray = PackedByteArray()
	var hote: String = ""
	var port: int = 0
	var phase: Phase = Phase.RESOLUTION
	var resolution: int = IP.RESOLVER_INVALID_ID
	var pair: StreamPeerTCP = null
	var debut: int = 0
	var debut_reponse: int = 0
	var recu: PackedByteArray = PackedByteArray()
	var delai_reponse: int = 0
	var fini: bool = false
	var etat: int = Etat.INDISPONIBLE
	var statut: int = STATUT_AUCUN
	var salons: Array[Dictionary] = []


## `{hote, port}` d'une adresse `hote[:port]` (port 7779 sans précision), `{}` si elle est
## invalide : hôte vide, espace ou caractère de contrôle, port hors de 1 à 65 535, plus de 255
## caractères.
static func analyser_adresse(brut: String) -> Dictionary:
	var texte := brut.strip_edges()
	if texte.is_empty() or texte.length() > 255:
		return {}
	for i: int in texte.length():
		var c := texte.unicode_at(i)
		if c <= 32 or c == 127:
			return {}
	var parties := texte.split(":")
	if parties.size() > 2 or parties[0].is_empty():
		return {}
	var port := AnnuaireProtocole.PORT_DEFAUT
	if parties.size() == 2:
		var p := parties[1]
		if p.is_empty() or p.length() > 5 or not p.is_valid_int():
			return {}
		if p.begins_with("+") or p.begins_with("-"):
			return {}
		port = p.to_int()
		if port < 1 or port > 65535:
			return {}
	return {"hote": parties[0], "port": port}


# --- Liste -------------------------------------------------------------------------------------


## Demande la liste des salons. Le résultat arrive par `liste_terminee`, jamais dans l'appel. Une
## demande en cours est abandonnée : seule la dernière répond. Vrai si la demande est prise en
## compte, faux si elle est ignorée parce que la précédente date de moins de `intervalle_liste_ms`.
func lister() -> bool:
	var vide := adresse.strip_edges().is_empty()
	var cible := {} if vide else analyser_adresse(adresse)
	var reel := not vide and not cible.is_empty()
	if reel and _maintenant() - _dernier_debut_liste_ms < intervalle_liste_ms:
		return false
	_abandonner(_echange_liste)
	_echange_liste = null
	if not reel:
		var etat := Etat.DESACTIVE if vide else Etat.INDISPONIBLE
		liste_terminee.emit.call_deferred(etat, [] as Array[Dictionary])
		return true
	_dernier_debut_liste_ms = _maintenant()
	_echange_liste = _ouvrir(
		AnnuaireProtocole.Type.LISTE,
		AnnuaireProtocole.encoder_liste(),
		cible,
		delai_reponse_liste_ms
	)
	return true


func liste_en_cours() -> bool:
	return _echange_liste != null


# --- Annonce -----------------------------------------------------------------------------------


## Annonce le salon décrit par `fournisseur` (`() -> Dictionary` de `nom`, `joueurs`, `max`,
## `port`) dès maintenant, puis à chaque période et à chaque changement du nombre de joueurs. Un
## dictionnaire vide veut dire « plus rien à annoncer » : l'entrée est retirée, une fois.
func demarrer_annonce(fournisseur: Callable) -> void:
	_fournisseur = fournisseur
	_annonce_active = true
	_derniere = {}
	_prochaine_ms = 0


## Retire le salon de l'annuaire puis libère ce nœud. Il se déplace à la racine de l'arbre pour
## finir l'échange même si son parent disparaît tout de suite après.
func retirer_et_quitter() -> void:
	_quitte = true
	_annonce_active = false
	_abandonner(_echange_annonce)
	_echange_annonce = null
	_abandonner(_echange_liste)
	_echange_liste = null
	var cible := analyser_adresse(adresse)
	if _port_annonce > 0 and not cible.is_empty():
		_echange_retrait = _ouvrir(
			AnnuaireProtocole.Type.RETRAIT,
			AnnuaireProtocole.encoder_retrait(_port_annonce),
			cible,
			delai_reponse_annonce_ms
		)
	if _echange_retrait == null:
		queue_free()
		return
	_port_annonce = 0
	if is_inside_tree():
		var racine := get_tree().root
		if get_parent() != racine:
			reparent(racine, false)


# --- Cycle -------------------------------------------------------------------------------------


func _process(_delta: float) -> void:
	avancer()


## Un pas : fait avancer les échanges, puis envoie l'annonce due. Public pour les tests.
func avancer() -> void:
	var t := _maintenant()
	if _echange_liste != null and _avancer(_echange_liste, t):
		var e := _echange_liste
		_echange_liste = null
		liste_terminee.emit(e.etat, e.salons)
	if _echange_annonce != null and _avancer(_echange_annonce, t):
		var e := _echange_annonce
		_echange_annonce = null
		annonce_terminee.emit(e.etat, e.statut)
	if _echange_retrait != null and _avancer(_echange_retrait, t):
		_echange_retrait = null
		if _quitte:
			queue_free()
			return
	_planifier(t)


func _planifier(t: int) -> void:
	if not _annonce_active or _echange_annonce != null or not _fournisseur.is_valid():
		return
	var voulue: Variant = _fournisseur.call()
	if not voulue is Dictionary:
		return
	var salon: Dictionary = voulue
	if salon.is_empty():
		_annonce_active = false
		if _port_annonce > 0:
			var cible := analyser_adresse(adresse)
			if not cible.is_empty():
				_echange_retrait = _ouvrir(
					AnnuaireProtocole.Type.RETRAIT,
					AnnuaireProtocole.encoder_retrait(_port_annonce),
					cible,
					delai_reponse_annonce_ms
				)
			_port_annonce = 0
		return
	var change := not _meme_salon(salon, _derniere)
	var due := t >= _prochaine_ms
	if not due and not (change and t - _dernier_envoi_ms >= intervalle_min_ms):
		return
	_prochaine_ms = t + periode_ms
	var cible := analyser_adresse(adresse)
	if cible.is_empty():
		return
	var octets := _encoder(salon)
	if octets.is_empty():
		return
	_derniere = salon.duplicate()
	_dernier_envoi_ms = t
	_port_annonce = int(salon["port"])
	annonces_envoyees += 1
	_echange_annonce = _ouvrir(
		AnnuaireProtocole.Type.ANNONCE, octets, cible, delai_reponse_annonce_ms
	)


## Le cadre d'annonce d'un salon, vide si un champ manque, a le mauvais type ou sort des bornes.
func _encoder(salon: Dictionary) -> PackedByteArray:
	for cle: String in ["nom", "joueurs", "max", "port"]:
		if not salon.has(cle):
			return PackedByteArray()
	if not salon["nom"] is String:
		return PackedByteArray()
	for cle: String in ["joueurs", "max", "port"]:
		if not salon[cle] is int:
			return PackedByteArray()
	return AnnuaireProtocole.encoder_annonce(
		version_jeu, int(salon["joueurs"]), int(salon["max"]), int(salon["port"]), salon["nom"]
	)


func _meme_salon(a: Dictionary, b: Dictionary) -> bool:
	for cle: String in ["nom", "joueurs", "max", "port"]:
		if a.get(cle) != b.get(cle):
			return false
	return true


# --- Échanges ----------------------------------------------------------------------------------


func _ouvrir(type: int, requete: PackedByteArray, cible: Dictionary, delai: int) -> _Echange:
	var e := _Echange.new()
	e.type = type
	e.requete = requete
	e.hote = cible["hote"]
	e.port = cible["port"]
	e.debut = _maintenant()
	e.delai_reponse = delai
	if e.hote.is_valid_ip_address():
		_connecter(e)
	else:
		e.resolution = IP.resolve_hostname_queue_item(e.hote, IP.TYPE_IPV4)
	return e


func _connecter(e: _Echange) -> void:
	e.pair = StreamPeerTCP.new()
	if e.pair.connect_to_host(e.hote, e.port) != OK:
		_echouer(e)
		return
	e.phase = _Echange.Phase.CONNEXION


## Vrai quand l'échange est fini (réussi ou non) ; `etat`, `statut` et `salons` sont alors posés.
func _avancer(e: _Echange, t: int) -> bool:
	if e.fini:
		return true
	if e.phase != _Echange.Phase.REPONSE and t - e.debut >= delai_connexion_ms:
		_echouer(e)
	elif e.phase == _Echange.Phase.RESOLUTION:
		_avancer_resolution(e)
	elif e.phase == _Echange.Phase.CONNEXION:
		_avancer_connexion(e, t)
	else:
		_avancer_reponse(e, t)
	return e.fini


func _avancer_resolution(e: _Echange) -> void:
	var etat_dns := IP.get_resolve_item_status(e.resolution)
	if etat_dns == IP.RESOLVER_STATUS_ERROR or etat_dns == IP.RESOLVER_STATUS_NONE:
		_echouer(e)
	elif etat_dns == IP.RESOLVER_STATUS_DONE:
		var ip := IP.get_resolve_item_address(e.resolution)
		IP.erase_resolve_item(e.resolution)
		e.resolution = IP.RESOLVER_INVALID_ID
		if ip.is_empty():
			_echouer(e)
		else:
			e.hote = ip
			_connecter(e)


func _avancer_connexion(e: _Echange, t: int) -> void:
	e.pair.poll()
	var statut_tcp := e.pair.get_status()
	if statut_tcp == StreamPeerTCP.STATUS_CONNECTED:
		if e.pair.put_data(e.requete) != OK:
			_echouer(e)
			return
		e.phase = _Echange.Phase.REPONSE
		e.debut_reponse = t
	elif statut_tcp != StreamPeerTCP.STATUS_CONNECTING:
		_echouer(e)


func _avancer_reponse(e: _Echange, t: int) -> void:
	if t - e.debut_reponse >= e.delai_reponse:
		_echouer(e)
		return
	e.pair.poll()
	_lire(e, e.pair.get_status())


func _lire(e: _Echange, statut_tcp: int) -> void:
	if statut_tcp == StreamPeerTCP.STATUS_CONNECTED:
		var disponibles := e.pair.get_available_bytes()
		var plafond := 2 + AnnuaireProtocole.MAX_CADRE_CLIENT + 1 - e.recu.size()
		if disponibles > 0 and plafond > 0:
			var lu := e.pair.get_partial_data(mini(disponibles, plafond))
			if lu[0] == OK:
				e.recu.append_array(lu[1])
	match _etat_du_cadre(e.recu):
		EtatCadre.INVALIDE:
			_echouer(e)
		EtatCadre.AUTRE_VERSION:
			_echouer(e, Etat.INCOMPATIBLE)
		EtatCadre.COMPLET:
			_conclure(e)
		_:
			# Fermé avant la fin du cadre : réponse tronquée.
			if statut_tcp != StreamPeerTCP.STATUS_CONNECTED:
				_echouer(e)


## Ce que disent les octets reçus. La version se lit avant la taille : une version future peut
## changer l'une et l'autre.
static func _etat_du_cadre(cadre: PackedByteArray) -> EtatCadre:
	if cadre.size() >= 2 + AnnuaireProtocole.TAILLE_EN_TETE:
		if cadre[2] != AnnuaireProtocole.MAGIE:
			return EtatCadre.INVALIDE
		if cadre[3] != AnnuaireProtocole.VERSION:
			return EtatCadre.AUTRE_VERSION
	if cadre.size() < 2:
		return EtatCadre.ATTENTE
	var taille: int = cadre[0] | (cadre[1] << 8)
	if taille < AnnuaireProtocole.TAILLE_EN_TETE or taille > AnnuaireProtocole.MAX_CADRE_CLIENT:
		return EtatCadre.INVALIDE
	return EtatCadre.COMPLET if cadre.size() >= 2 + taille else EtatCadre.ATTENTE


func _conclure(e: _Echange) -> void:
	var type_recu := e.recu[4] if e.recu.size() > 4 else -1
	if e.type == AnnuaireProtocole.Type.LISTE and type_recu == AnnuaireProtocole.Type.SALONS:
		var decode := AnnuaireProtocole.decoder_salons(e.recu)
		if decode.is_empty():
			_echouer(e)
			return
		e.salons = decode["salons"]
		_terminer(e, Etat.OK, STATUT_AUCUN)
		return
	var reponse := AnnuaireProtocole.decoder_reponse(e.recu)
	if reponse.is_empty():
		_echouer(e)
		return
	if e.type == AnnuaireProtocole.Type.LISTE:
		# Une réponse de statut à la place de la liste : pas de salons. Le débit n'est pas une panne.
		if int(reponse["statut"]) == AnnuaireProtocole.Statut.DEBIT:
			_terminer(e, Etat.LIMITE, STATUT_AUCUN)
		else:
			_echouer(e)
		return
	_terminer(e, Etat.OK, int(reponse["statut"]))


func _echouer(e: _Echange, etat: int = Etat.INDISPONIBLE) -> void:
	_terminer(e, etat, STATUT_AUCUN)


func _terminer(e: _Echange, etat: int, statut: int) -> void:
	e.fini = true
	e.etat = etat
	e.statut = statut
	_fermer(e)


func _fermer(e: _Echange) -> void:
	if e.resolution != IP.RESOLVER_INVALID_ID:
		IP.erase_resolve_item(e.resolution)
		e.resolution = IP.RESOLVER_INVALID_ID
	if e.pair != null:
		e.pair.disconnect_from_host()


## Une demande dont on n'attend plus la réponse : la connexion est fermée, rien n'est émis.
func _abandonner(e: _Echange) -> void:
	if e != null:
		e.fini = true
		_fermer(e)


func _maintenant() -> int:
	if horloge.is_valid():
		return int(horloge.call())
	return Time.get_ticks_msec()


func _exit_tree() -> void:
	if _quitte:
		return
	for e: _Echange in [_echange_annonce, _echange_liste, _echange_retrait]:
		_abandonner(e)
