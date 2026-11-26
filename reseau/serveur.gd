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
## Une place ENet de plus que le salon : le neuvième client doit être accepté pour recevoir son
## refus (motif du salon plein). Sans cela, ENet ne répond pas et il finit « injoignable ».
const PLACES_ENET: int = MAX_CLIENTS + 1
const ACCELERATION_MAX: int = 60
## Intentions admises par pair : 30 par seconde au plus, dont au plus 10 entre deux pas de boucle.
const INTENTIONS_PAR_SECONDE: int = 30
const INTENTIONS_PAR_PAS: int = 10
## Cadence des cartes de densité dans l'état global (lot 8) : une fois par seconde.
const HZ_DENSITES: float = 1.0
const DELAI_BONJOUR_S: float = 5.0
## Laisse partir le refus (fiable) avant de couper : couper aussitôt le jette avec la file.
const DELAI_COUPURE_S: float = 0.5
const BONJOURS_INVALIDES_MAX: int = 3
## Un à-coup de la machine ne doit pas faire simuler des minutes d'un coup.
const DT_MAX: float = 0.5
## Événements d'arène servis par envoi : le plafond du protocole.
const TAMPON_PAR_ENVOI: int = TamponEvenements.PAR_ENVOI

## Jeton d'hôte du salon hébergé par un joueur (8 octets) : à poser avant `demarrer` ou `preparer`.
## Vide pour le serveur dédié, qui garde la règle du premier pair. Jamais journalisé.
var jeton_hote: PackedByteArray = PackedByteArray()
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
## Octets des cartes de densité du dernier état global qui en portait, et attente avant le suivant.
var _taille_densites: int = 0
var _acc_densites: float = 1.0 / HZ_DENSITES
var _fin_signalee: bool = false
var _liaisons: Array[Array] = []
var _coupures: Dictionary = {}
## joueur → événements de son arène, lus une fois par pas ; `_vues_du_pas` : vue lue ce pas.
var _tampons: Dictionary = {}
var _vues_du_pas: Dictionary = {}


class _Pair:
	extends RefCounted
	var enregistre: bool = false
	var age: float = 0.0
	var bonjours_invalides: int = 0
	var cible: int = 0
	## Numéro du dernier événement de l'arène regardée déjà reçu par ce pair.
	var curseur: int = 0
	var acc_arene: float = 0.0
	var taille_arene: int = 0
	## Joueur dont l'arène est regardée en plus de la sienne (-1 : aucun) ; son propre curseur,
	## accumulateur et taille de dernier état, comme pour l'arène du pair.
	var regarde: int = -1
	var curseur_regarde: int = 0
	var acc_regardee: float = 0.0
	var taille_regardee: int = 0
	var hz_regardee: float = 0.0
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


## Fréquence de l'arène regardée : ce qui reste du budget une fois retirés la part de l'état
## global, `reserve`, et l'état propre (`octets_propre` à `hz_propre`), bornée à
## [`hz_min`, `hz_max`] ; `hz_max` si l'état regardé n'a pas de taille connue.
static func frequence_arene_regardee(
	budget: float,
	reserve: float,
	octets_propre: int,
	hz_propre: float,
	octets_regardee: int,
	hz_max: float,
	hz_min: float
) -> float:
	if octets_regardee <= 0:
		return hz_max
	var reste := budget - reserve - float(octets_propre) * hz_propre
	var hz := reste / float(octets_regardee)
	if is_nan(hz):
		return hz_min
	return maxf(hz_min, minf(hz_max, hz))


# --- Cycle de vie ----------------------------------------------------------------------------


## Ouvre le serveur ENet. `ERR_INVALID_PARAMETER` si le port est hors 1..65535, l'erreur d'ENet si
## le port est pris, `ERR_UNCONFIGURED` si le nœud n'est pas dans l'arbre sous un `Canal`.
func demarrer(donnees: Donnees, port: int, acces: int = 1) -> Error:
	if port < 1 or port > PORT_MAX or donnees == null:
		return ERR_INVALID_PARAMETER
	if _actif:
		return ERR_ALREADY_IN_USE
	var pair := ENetMultiplayerPeer.new()
	var code := pair.create_server(port, PLACES_ENET)
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
	salon.jeton_hote = jeton_hote
	partie = null
	_pairs = {}
	_tampons = {}
	_vues_du_pas = {}
	_acc_global = 0.0
	_taille_globale = 0
	_fin_signalee = false


## Rouvre le salon après une partie sans fermer les connexions : chaque pair doit redire bonjour
## pour entrer dans le nouveau salon, et l'ancienne partie n'est plus servie.
func rouvrir_salon() -> void:
	partie = null
	salon = Salon.new()
	salon.jeton_hote = jeton_hote
	_fin_signalee = false
	_vues_du_pas = {}
	_tampons = {}
	_acc_global = 0.0
	_taille_globale = 0
	for pair: int in _pairs:
		(_pairs[pair] as _Pair).enregistre = false


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
	if p == null:
		return _frequence(0)
	return _frequence(p.taille_arene, p.taille_regardee if p.regarde >= 0 else -1)


## Fréquence actuelle d'envoi de l'arène regardée à ce pair ; 0 s'il n'en regarde aucune.
func frequence_regardee_de(pair: int) -> float:
	var p := _pairs.get(pair) as _Pair
	return p.hz_regardee if p != null and p.regarde >= 0 else 0.0


## Joueur que ce pair regarde en plus de sa propre arène ; -1 s'il n'en regarde aucun.
func regarde_de(pair: int) -> int:
	var p := _pairs.get(pair) as _Pair
	return p.regarde if p != null else -1


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
	if not salon.ajouter(pair, String(b["nom"]), b["jeton"] as PackedByteArray):
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
	elif genre == Protocole.Intention.SKIN:
		resultat = _skin(pair, arg)
	elif genre == Protocole.Intention.OBSERVER:
		resultat = _observer(p, pair, arg)
	elif genre == Protocole.Intention.REGARDER:
		resultat = _regarder(p, pair, arg)
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


## Le skin choisi au salon : hors catalogue (négatif, trop grand), c'est le skin par défaut.
func _skin(pair: int, index: int) -> int:
	if partie != null:
		return Types.Resultat.MAUVAISE_PHASE
	var borne := index if index >= 0 and index < _donnees.skins_tour.size() else 0
	return Types.Resultat.OK if salon.definir_skin(pair, borne) else Types.Resultat.NON_DISPONIBLE


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
	# `vue_arene` rend désormais toute arène : seul un joueur tombé, vainqueur ou parti remplace
	# sa propre vue (un vivant ne fait que regarder, lot 8).
	if cible != pair and not partie.observation_permise(pair):
		return Types.Resultat.INDICE_INVALIDE
	var vue := _lire_vue(pair, cible)
	if vue == null:
		return Types.Resultat.INDICE_INVALIDE
	p.cible = cible
	p.regarde = -1
	# Les événements d'avant le changement ne l'intéressent pas.
	p.curseur = _tampon(cible).dernier
	return Types.Resultat.OK


## Regarder l'arène d'un autre joueur sans quitter la sienne : réservé au joueur en jeu (le
## tombé, le vainqueur et le parti observent). -1 arrête ; soi-même ou un inconnu est refusé, et
## le joueur regardé jusque-là l'est toujours.
func _regarder(p: _Pair, pair: int, cible: int) -> int:
	if partie == null:
		return Types.Resultat.MAUVAISE_PHASE
	if cible == -1:
		p.regarde = -1
		return Types.Resultat.OK
	if cible == pair or partie.observation_permise(pair):
		return Types.Resultat.INDICE_INVALIDE
	if _lire_vue(pair, cible) == null:
		return Types.Resultat.INDICE_INVALIDE
	p.regarde = cible
	p.curseur_regarde = _tampon(cible).dernier
	# Un premier état part au prochain pas, sans attendre la période.
	p.acc_regardee = 1.0
	p.taille_regardee = 0
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
		partie.definir_skin(id, int((salon.joueurs[id] as Dictionary).get("skin", 0)))
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
	_vues_du_pas = {}
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


func _frequence(taille: int, octets_regardee: int = -1) -> float:
	var r: Dictionary = _donnees.partie["reseau"]
	var reserve := _reserve_globale()
	var plancher := float(r["hz_min"])
	if octets_regardee >= 0:
		# Pair qui regarde : on retire d'abord le strict minimum de l'arène regardée, la propre
		# arène prend le reste, quitte à descendre sous son plancher (le budget par client est
		# la limite dure).
		plancher = float(r["hz_min_regardee"])
		reserve += float(r["hz_min_regardee"]) * float(octets_regardee)
	return frequence_arene(
		float(r["budget_octets_s"]), reserve, taille, plancher, float(r["hz_arene"])
	)


## Octets par seconde de l'état global : l'état à `hz_global` plus les cartes à `HZ_DENSITES`.
func _reserve_globale() -> float:
	var r: Dictionary = _donnees.partie["reseau"]
	return float(_taille_globale) * float(r["hz_global"]) + float(_taille_densites) * HZ_DENSITES


func _envoyer_etats(dt: float) -> void:
	var r: Dictionary = _donnees.partie["reseau"]
	_acc_global += dt
	_acc_densites += dt
	var periode_globale := 1.0 / float(r["hz_global"])
	if _acc_global >= periode_globale:
		_acc_global = minf(_acc_global - periode_globale, periode_globale)
		_diffuser_global()
	for pair: int in _pairs.keys():
		var p := _pairs.get(pair) as _Pair
		if p == null or not p.enregistre:
			continue
		_envoyer_arene_propre(pair, p, dt)
		_envoyer_arene_regardee(pair, p, dt)


func _envoyer_arene_propre(pair: int, p: _Pair, dt: float) -> void:
	p.acc_arene += dt
	var periode := 1.0 / _frequence(p.taille_arene, p.taille_regardee if p.regarde >= 0 else -1)
	if p.acc_arene < periode:
		return
	p.acc_arene = minf(p.acc_arene - periode, periode)
	var vue := _vue_du_pas(p.cible)
	if vue == null and p.cible != pair:
		p.cible = pair
		p.curseur = _tampon(pair).dernier
		vue = _vue_du_pas(pair)
	if vue == null:
		return
	var lot := _tampon(p.cible).prendre(p.curseur, TAMPON_PAR_ENVOI)
	vue.evenements = lot.evenements
	var octets := Protocole.encoder_etat_arene(
		vue, _donnees.ids_catalogue, _donnees.ids_unites.size()
	)
	if octets.is_empty():
		etats_trop_gros += 1
		return
	p.taille_arene = octets.size()
	p.curseur = lot.curseur
	_envoyer(pair, "rpc_etat_arene", octets)


## L'arène regardée, en plus de la sienne, à une fréquence qui tient le budget du pair. Un joueur
## parti ou un pair tombé (qui observe désormais) ramène à sa propre arène : le pair en est averti
## par un résultat `ARENE_MORTE`, pour que son interface cesse d'attendre cette arène.
func _envoyer_arene_regardee(pair: int, p: _Pair, dt: float) -> void:
	if p.regarde < 0:
		return
	var vue := _vue_du_pas(p.regarde) if not partie.observation_permise(pair) else null
	if vue == null:
		p.regarde = -1
		_envoyer(
			pair,
			"rpc_resultat",
			Protocole.encoder_resultat(Protocole.Intention.REGARDER, Types.Resultat.ARENE_MORTE)
		)
		return
	var r: Dictionary = _donnees.partie["reseau"]
	p.acc_regardee += dt
	p.hz_regardee = frequence_arene_regardee(
		float(r["budget_octets_s"]),
		_reserve_globale(),
		p.taille_arene,
		_frequence(p.taille_arene, p.taille_regardee),
		p.taille_regardee,
		float(r["hz_arene_regardee"]),
		float(r["hz_min_regardee"])
	)
	var periode := 1.0 / p.hz_regardee
	if p.acc_regardee < periode:
		return
	p.acc_regardee = minf(p.acc_regardee - periode, periode)
	var lot := _tampon(p.regarde).prendre(p.curseur_regarde, TAMPON_PAR_ENVOI)
	# Une copie : la vue du pas sert aussi au propriétaire et à d'autres observateurs.
	var copie := VueArene.from_dict(vue.to_dict())
	if copie == null:
		etats_trop_gros += 1
		return
	copie.evenements = lot.evenements
	var octets := Protocole.encoder_etat_arene_regardee(
		p.regarde, copie, _donnees.ids_catalogue, _donnees.ids_unites.size()
	)
	if octets.is_empty():
		etats_trop_gros += 1
		return
	p.taille_regardee = octets.size()
	p.curseur_regarde = lot.curseur
	_envoyer(pair, "rpc_etat_arene_regardee", octets)


func _tampon(joueur: int) -> TamponEvenements:
	var t := _tampons.get(joueur) as TamponEvenements
	if t == null:
		t = TamponEvenements.new()
		_tampons[joueur] = t
	return t


## Lit l'arène une seule fois et verse ses événements au tampon : `Partie` les vide à chaque
## lecture, donc chaque observateur les reçoit du tampon et non de sa propre lecture.
func _lire_vue(demandeur: int, cible: int) -> VueArene:
	var vue := partie.vue_arene(demandeur, cible)
	if vue != null:
		_tampon(cible).ajouter(vue.evenements)
	return vue


## La vue de l'arène de `cible`, lue au plus une fois par pas ; `null` si elle n'existe plus.
func _vue_du_pas(cible: int) -> VueArene:
	if _vues_du_pas.has(cible):
		return _vues_du_pas[cible] as VueArene
	var vue := _lire_vue(cible, cible)
	if vue == null:
		_tampons.erase(cible)
	_vues_du_pas[cible] = vue
	return vue


## Événements de l'arène regardée par ce pair qu'il n'a pas encore reçus.
func en_attente(pair: int) -> int:
	var p := _pairs.get(pair) as _Pair
	if p == null:
		return 0
	return _tampon(p.cible).prendre(p.curseur, 1 << 30).evenements.size()


## Nombre total d'événements lus dans l'arène de ce joueur.
func evenements_lus(joueur: int) -> int:
	return _tampon(joueur).dernier


func taille_tampon(joueur: int) -> int:
	return _tampon(joueur).taille()


func _diffuser_global() -> void:
	var avec_densites := _acc_densites >= 1.0 / HZ_DENSITES
	var vue := partie.vue_globale(avec_densites)
	var octets := Protocole.encoder_etat_global(vue)
	if avec_densites:
		_acc_densites = 0.0
		# La part des cartes se compte à part : elles ne partent qu'une fois par seconde.
		var cartes := vue.densites
		vue.densites = {}
		_taille_globale = Protocole.encoder_etat_global(vue).size()
		_taille_densites = octets.size() - _taille_globale
		vue.densites = cartes
	else:
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
		_envoyer_les_bilans()
	partie_terminee_serveur.emit()


## Chaque joueur encore présent reçoit son propre bilan, et seulement le sien. Un joueur parti
## n'a plus d'arène : `bilan_joueur` rend `{}` et rien ne lui part.
func _envoyer_les_bilans() -> void:
	for pair: int in _pairs:
		if not (_pairs[pair] as _Pair).enregistre:
			continue
		var octets := Protocole.encoder_bilan(partie.bilan_joueur(pair))
		if not octets.is_empty():
			_envoyer(pair, "rpc_bilan", octets)


func _envoyer(pair: int, rpc: String, octets: PackedByteArray) -> void:
	if emetteur.is_valid():
		emetteur.call(pair, rpc, octets)
	elif _actif and canal != null:
		canal.rpc_id(pair, rpc, octets)
