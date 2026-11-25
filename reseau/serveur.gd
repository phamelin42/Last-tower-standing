class_name Serveur
extends Node
## Serveur autoritaire : ENet, boucle à pas fixe (celui de `Partie`), intentions validées, états
## d'arène envoyés à une fréquence adaptée au débit de chaque client, état global à 2 Hz.
##
## Il ne contient aucune règle de jeu : tout passe par `Partie`. Il ne croit que le numéro du pair
## donné par ENet (`get_remote_sender_id()`, transmis par `Canal`) : aucun message ne porte
## d'identité, et le numéro du pair est le numéro du joueur. Tout octet reçu est une donnée non
## fiable : borné, décodé défensivement, refusé sans exception.
##
## Les tests n'ont pas besoin de socket : `preparer` + `pair_connecte` / `traiter_bonjour` /
## `traiter_intention` / `tick`, et `emetteur` capte ce qui serait envoyé.

signal partie_terminee_serveur

const PORT_MAX: int = 65535
const MAX_CLIENTS: int = Salon.MAX_JOUEURS
const ACCELERATION_MAX: int = 60
## Intentions admises par pair : 30 par seconde au plus, dont au plus 10 entre deux pas de boucle.
const INTENTIONS_PAR_SECONDE: int = 30
const INTENTIONS_PAR_PAS: int = 10
const DELAI_BONJOUR_S: float = 5.0
## Laisse partir le refus (fiable) avant de couper : couper aussitôt le jette avec la file.
const DELAI_COUPURE_S: float = 0.5
const BONJOURS_INVALIDES_MAX: int = 3
## Un à-coup de la machine ne doit pas faire simuler des minutes d'un coup.
const DT_MAX: float = 0.5

## Nœud `Canal` qui porte les RPC ; à défaut, le parent de ce nœud.
var canal: Canal = null
## `(pair: int, rpc: String, octets: PackedByteArray)` : remplace l'envoi réseau (tests, mesures).
var emetteur: Callable = Callable()
var salon: Salon = Salon.new()
var partie: Partie = null
var acceleration: int = 1
## Cumuls en microsecondes, pour mesurer le coût de la boucle.
var temps_sim_us: int = 0
var temps_envoi_us: int = 0
var etats_trop_gros: int = 0

var _donnees: Donnees = null
var _pairs: Dictionary = {}
var _actif: bool = false
var _peer: ENetMultiplayerPeer = null
var _acc_global: float = 0.0
var _taille_globale: int = 0
var _fin_signalee: bool = false
var _liaisons: Array[Array] = []
var _coupures: Dictionary = {}


class _Pair:
	extends RefCounted
	var enregistre: bool = false
	var age: float = 0.0
	var bonjours_invalides: int = 0
	var cible: int = 0
	var acc_arene: float = 0.0
	var taille_arene: int = 0
	var fenetre: float = 0.0
	var n_fenetre: int = 0
	var n_pas: int = 0
	var admises: int = 0
	var limitees: int = 0


## `arg` = graine, `texte` = « vitesse;fixe » (fixe = 0 ou 1) : seule convention d'`OPTIONS`.
static func encoder_options(vitesse: float, graine: int, graine_fixe: bool) -> PackedByteArray:
	var texte := "%s;%d" % [vitesse, 1 if graine_fixe else 0]
	return Protocole.encoder_intention(Protocole.Intention.OPTIONS, graine, texte)


## `hz = clamp((budget − part_globale) / taille, hz_min, hz_arene)`.
static func frequence_arene(
	budget: float, reserve: float, taille: int, hz_min: float, hz_arene: float
) -> float:
	if taille <= 0:
		return hz_arene
	return clampf((budget - reserve) / float(taille), hz_min, hz_arene)


# --- Cycle de vie ----------------------------------------------------------------------------


## Ouvre le serveur ENet. `ERR_INVALID_PARAMETER` si le port est hors 1..65535, l'erreur d'ENet si
## le port est pris, `ERR_UNCONFIGURED` si le nœud n'est pas dans l'arbre sous un `Canal`.
func demarrer(donnees: Donnees, port: int, acces: int = 1) -> Error:
	if port < 1 or port > PORT_MAX or donnees == null:
		return ERR_INVALID_PARAMETER
	if _actif:
		return ERR_ALREADY_IN_USE
	var pair := ENetMultiplayerPeer.new()
	var code := pair.create_server(port, MAX_CLIENTS)
	if code != OK:
		return code
	if canal == null:
		canal = get_parent() as Canal
	if canal == null or not is_inside_tree():
		pair.close()
		return ERR_UNCONFIGURED
	preparer(donnees, acces)
	_peer = pair
	multiplayer.multiplayer_peer = pair
	# Sans relais, un client ne peut parler qu'au serveur : aucun message forgé vers un autre.
	var api := multiplayer as SceneMultiplayer
	if api != null:
		api.server_relay = false
	_lier(multiplayer.peer_connected, pair_connecte)
	_lier(multiplayer.peer_disconnected, pair_deconnecte)
	_lier(canal.bonjour_recu, _a_la_reception_bonjour)
	_lier(canal.intention_recue, _a_la_reception_intention)
	_actif = true
	return OK


## Prépare l'état du serveur sans ouvrir de socket.
func preparer(donnees: Donnees, acces: int = 1) -> void:
	_donnees = donnees
	acceleration = clampi(acces, 1, ACCELERATION_MAX)
	salon = Salon.new()
	partie = null
	_pairs = {}
	_acc_global = 0.0
	_taille_globale = 0
	_fin_signalee = false


func arreter() -> void:
	for l: Array in _liaisons:
		var s: Signal = l[0]
		var c: Callable = l[1]
		if s.is_connected(c):
			s.disconnect(c)
	_liaisons = []
	if _peer != null:
		_peer.close()
		if is_inside_tree() and multiplayer.multiplayer_peer == _peer:
			multiplayer.multiplayer_peer = null
	_peer = null
	_coupures = {}
	_actif = false


func est_actif() -> bool:
	return _actif


func nb_pairs() -> int:
	return _pairs.size()


## Numéro du joueur du pair (le même), -1 s'il n'a pas dit bonjour ou a été refusé.
func joueur_de(pair: int) -> int:
	var p := _pairs.get(pair) as _Pair
	return pair if p != null and p.enregistre else -1


func admises(pair: int) -> int:
	var p := _pairs.get(pair) as _Pair
	return p.admises if p != null else 0


func limitees(pair: int) -> int:
	var p := _pairs.get(pair) as _Pair
	return p.limitees if p != null else 0


## Fréquence actuelle d'envoi de l'état d'arène à ce pair.
func frequence_de(pair: int) -> float:
	var p := _pairs.get(pair) as _Pair
	return _frequence(p.taille_arene if p != null else 0)


func _exit_tree() -> void:
	arreter()


func _physics_process(delta: float) -> void:
	if _actif:
		tick(delta)


func _lier(s: Signal, c: Callable) -> void:
	s.connect(c)
	_liaisons.append([s, c])


# --- Pairs -----------------------------------------------------------------------------------


func pair_connecte(pair: int) -> void:
	if not _pairs.has(pair):
		_pairs[pair] = _Pair.new()


func pair_deconnecte(pair: int) -> void:
	var p := _pairs.get(pair) as _Pair
	if p == null:
		return
	_pairs.erase(pair)
	if p.enregistre:
		if partie == null:
			salon.retirer(pair)
			_diffuser_salon()
		else:
			partie.retirer_joueur(pair)
	_verifier_fin()


func _couper(pair: int) -> void:
	if _actif and _peer != null:
		_coupures[pair] = DELAI_COUPURE_S
	pair_deconnecte(pair)


func _refuser(pair: int, motif: String) -> bool:
	_envoyer(pair, "rpc_refus", Protocole.encoder_refus(motif))
	_couper(pair)
	return false


func _a_la_reception_bonjour(pair: int, octets: PackedByteArray) -> void:
	traiter_bonjour(pair, octets)


func _a_la_reception_intention(pair: int, octets: PackedByteArray) -> void:
	traiter_intention(pair, octets)


## Vrai si le pair est admis au salon.
func traiter_bonjour(pair: int, octets: PackedByteArray) -> bool:
	if _donnees == null:
		return false
	var p := _pairs.get(pair) as _Pair
	if p == null:
		p = _Pair.new()
		_pairs[pair] = p
	if p.enregistre:
		return false
	var b := Protocole.decoder_bonjour(octets)
	var motif := _motif_refus_bonjour(octets, b)
	if not motif.is_empty():
		return _refuser(pair, motif)
	if b.is_empty():
		p.bonjours_invalides += 1
		if p.bonjours_invalides >= BONJOURS_INVALIDES_MAX:
			_couper(pair)
		return false
	if not salon.ajouter(pair, String(b["nom"])):
		return _refuser(pair, salon.motif_refus)
	p.enregistre = true
	p.cible = pair
	# Décale les envois des clients : huit encodages le même pas feraient un pic.
	var hz: float = (_donnees.partie["reseau"] as Dictionary)["hz_arene"]
	p.acc_arene = float(salon.joueurs.size() % MAX_CLIENTS) / float(MAX_CLIENTS) / hz
	_diffuser_salon()
	return true


## Pourquoi ce bonjour est refusé (vide : pas de refus à signaler). `b` : bonjour décodé, ou `{}`.
func _motif_refus_bonjour(octets: PackedByteArray, b: Dictionary) -> String:
	var version := Protocole.version_bonjour(octets)
	if version >= 0 and version != Protocole.VERSION:
		return Protocole.motif_version(version)
	if b.is_empty():
		return ""
	if int(b["empreinte"]) != _donnees.empreinte:
		return "Les données du jeu diffèrent de celles du serveur."
	if partie != null:
		return "La partie a déjà commencé."
	return ""


# --- Intentions ------------------------------------------------------------------------------


## Un `Types.Resultat`, ou `NON_DISPONIBLE` pour ce qui est ignoré, limité ou refusé hors de
## `Partie`. `pair` vient d'ENet : c'est la seule identité.
func traiter_intention(pair: int, octets: PackedByteArray) -> int:
	var p := _pairs.get(pair) as _Pair
	if p == null or not p.enregistre or not _admettre(p):
		return Types.Resultat.NON_DISPONIBLE
	var i := Protocole.decoder_intention(octets)
	if i.is_empty():
		return Types.Resultat.NON_DISPONIBLE
	var arg: int = i["arg"]
	var genre: int = i["genre"]
	var resultat := Types.Resultat.NON_DISPONIBLE
	if genre == Protocole.Intention.PRET:
		resultat = _pret(pair, arg)
	elif genre == Protocole.Intention.OPTIONS:
		resultat = _options(pair, arg, String(i["texte"]))
	elif genre == Protocole.Intention.OBSERVER:
		resultat = _observer(p, pair, arg)
	elif partie == null:
		resultat = _hors_phase()
	else:
		resultat = _intention_de_jeu(pair, genre, arg, String(i["texte"]))
	# Au seul expéditeur : le client apprend ainsi pourquoi un achat échoue.
	_envoyer(pair, "rpc_resultat", Protocole.encoder_resultat(genre, resultat))
	return resultat


## Limite de débit : au plus 10 intentions par pas de boucle et 30 par seconde et par pair.
func _admettre(p: _Pair) -> bool:
	if p.n_pas >= INTENTIONS_PAR_PAS or p.n_fenetre >= INTENTIONS_PAR_SECONDE:
		p.limitees += 1
		return false
	p.n_pas += 1
	p.n_fenetre += 1
	p.admises += 1
	return true


## Les intentions de la boutique : `Partie` valide tout (phase, indices, identifiants).
func _intention_de_jeu(pair: int, genre: int, arg: int, texte: String) -> int:
	var resultat := Types.Resultat.NON_DISPONIBLE
	match genre:
		Protocole.Intention.ACHETER:
			resultat = partie.intention_acheter(pair, arg)
		Protocole.Intention.RELANCER:
			resultat = partie.intention_relancer(pair)
		Protocole.Intention.VENDRE:
			resultat = partie.intention_vendre(pair, arg)
		Protocole.Intention.MARCHE_NOIR:
			resultat = partie.intention_marche_noir(pair, texte)
		Protocole.Intention.SANS_FIN:
			resultat = partie.intention_continuer_sans_fin(pair)
		Protocole.Intention.QUITTER:
			resultat = partie.intention_quitter(pair)
	return resultat


func _hors_phase() -> int:
	return Types.Resultat.MAUVAISE_PHASE


func _pret(pair: int, arg: int) -> int:
	if partie != null:
		return Types.Resultat.MAUVAISE_PHASE
	if arg != 0 and arg != 1:
		return Types.Resultat.NON_DISPONIBLE
	if not salon.marquer_pret(pair, arg == 1):
		return Types.Resultat.NON_DISPONIBLE
	if salon.peut_demarrer():
		_lancer_partie()
	else:
		_diffuser_salon()
	return Types.Resultat.OK


func _options(pair: int, graine: int, texte: String) -> int:
	if partie != null:
		return Types.Resultat.MAUVAISE_PHASE
	var morceaux := texte.split(";")
	if morceaux.size() != 2 or not morceaux[0].is_valid_float():
		return Types.Resultat.NON_DISPONIBLE
	if morceaux[1] != "0" and morceaux[1] != "1":
		return Types.Resultat.NON_DISPONIBLE
	var vitesse := morceaux[0].to_float()
	if not is_finite(vitesse) or not salon.regler(pair, pair, vitesse, graine, morceaux[1] == "1"):
		return Types.Resultat.NON_DISPONIBLE
	_diffuser_salon()
	return Types.Resultat.OK


## Mémorisé seulement si `Partie` accepte de montrer cette arène à ce joueur.
func _observer(p: _Pair, pair: int, cible: int) -> int:
	if partie == null:
		return Types.Resultat.MAUVAISE_PHASE
	if partie.vue_arene(pair, cible) == null:
		return Types.Resultat.INDICE_INVALIDE
	p.cible = cible
	return Types.Resultat.OK


func _lancer_partie() -> void:
	if partie != null or not salon.demarrer(salon.hote):
		return
	var config := Partie.Config.new()
	config.graine = salon.graine_de_partie()
	config.facteur_duree = salon.vitesse
	partie = Partie.new(_donnees, config)
	for id: int in salon.joueurs:
		partie.ajouter_joueur(id, String((salon.joueurs[id] as Dictionary)["nom"]))
	partie.demarrer()
	_diffuser_salon()


# --- Boucle ----------------------------------------------------------------------------------


## Fait avancer le serveur de `dt` secondes réelles : simulation à pas fixe (dans `Partie`), puis
## envois. Les deux sont indépendants : l'envoi ne dépend que des accumulateurs.
func tick(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	dt = minf(dt, DT_MAX)
	_horloge_pairs(dt)
	if partie == null:
		return
	var t0 := Time.get_ticks_usec()
	for _i: int in acceleration:
		partie.avancer(dt)
	var t1 := Time.get_ticks_usec()
	_envoyer_etats(dt)
	temps_sim_us += t1 - t0
	temps_envoi_us += Time.get_ticks_usec() - t1
	_verifier_fin()


func _horloge_pairs(dt: float) -> void:
	for pair: int in _coupures.keys():
		var reste := float(_coupures[pair]) - dt
		if reste > 0.0:
			_coupures[pair] = reste
			continue
		_coupures.erase(pair)
		if _peer != null and _peer.get_peer(pair) != null:
			_peer.disconnect_peer(pair)
	var muets: Array[int] = []
	for pair: int in _pairs:
		var p := _pairs[pair] as _Pair
		p.n_pas = 0
		p.fenetre += dt
		if p.fenetre >= 1.0:
			p.fenetre = 0.0
			p.n_fenetre = 0
		if not p.enregistre:
			p.age += dt
			if p.age > DELAI_BONJOUR_S:
				muets.append(pair)
	for pair: int in muets:
		_couper(pair)


func _frequence(taille: int) -> float:
	var r: Dictionary = _donnees.partie["reseau"]
	var reserve := float(_taille_globale) * float(r["hz_global"])
	return frequence_arene(
		float(r["budget_octets_s"]), reserve, taille, float(r["hz_min"]), float(r["hz_arene"])
	)


func _envoyer_etats(dt: float) -> void:
	var r: Dictionary = _donnees.partie["reseau"]
	_acc_global += dt
	var periode_globale := 1.0 / float(r["hz_global"])
	if _acc_global >= periode_globale:
		_acc_global = minf(_acc_global - periode_globale, periode_globale)
		_diffuser_global()
	for pair: int in _pairs.keys():
		var p := _pairs.get(pair) as _Pair
		if p == null or not p.enregistre:
			continue
		p.acc_arene += dt
		var periode := 1.0 / _frequence(p.taille_arene)
		if p.acc_arene < periode:
			continue
		p.acc_arene = minf(p.acc_arene - periode, periode)
		var vue := partie.vue_arene(pair, p.cible)
		if vue == null and p.cible != pair:
			p.cible = pair
			vue = partie.vue_arene(pair, pair)
		if vue == null:
			continue
		var octets := Protocole.encoder_etat_arene(vue, _donnees.ids_catalogue)
		if octets.is_empty():
			etats_trop_gros += 1
			continue
		p.taille_arene = octets.size()
		_envoyer(pair, "rpc_etat_arene", octets)


func _diffuser_global() -> void:
	var octets := Protocole.encoder_etat_global(partie.vue_globale())
	_taille_globale = octets.size()
	for pair: int in _pairs:
		if (_pairs[pair] as _Pair).enregistre:
			_envoyer(pair, "rpc_etat_global", octets)


func _diffuser_salon() -> void:
	var octets := salon.vers_octets()
	for pair: int in _pairs:
		if (_pairs[pair] as _Pair).enregistre:
			_envoyer(pair, "rpc_salon", octets)


## Fin de partie : dernier état global (terminé) à chacun, puis un seul signal.
func _verifier_fin() -> void:
	if partie == null or _fin_signalee:
		return
	if not partie.est_terminee() and not _pairs.is_empty():
		return
	_fin_signalee = true
	if not _pairs.is_empty():
		_diffuser_global()
	partie_terminee_serveur.emit()


func _envoyer(pair: int, rpc: String, octets: PackedByteArray) -> void:
	if emetteur.is_valid():
		emetteur.call(pair, rpc, octets)
	elif _actif and canal != null:
		canal.rpc_id(pair, rpc, octets)
