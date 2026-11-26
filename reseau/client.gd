class_name Client
extends SourceVue
## Source de vue du jeu en réseau, interchangeable avec `SourceLocale`. Le client est un enfant du
## `Canal` (comme `Serveur`) : les RPC se résolvent par le chemin du nœud, identique des deux
## côtés. Il n'applique aucune règle de jeu : il encode les intentions, décode ce que le serveur
## envoie, et signale la perte du serveur une seule fois. Tout octet reçu est une donnée non
## fiable : un paquet invalide, d'un mauvais type ou trop gros est ignoré et compté.

signal salon_mis_a_jour(salon: Salon)
signal partie_demarree

## ENet ignore un client de trop (huit au plus) : indiscernable d'une adresse fausse.
const MOTIF_INJOIGNABLE := "Impossible de joindre le serveur (adresse fausse ou salon plein)."

## Délai sans nouvelles du serveur, en partie, avant de le déclarer perdu.
var delai_silence_s: float = 5.0
## Délai pour joindre le serveur.
var delai_connexion_s: float = 10.0
## Données du jeu ; chargées au premier `connecter` si l'appelant n'en fournit pas.
var donnees: Donnees = null
var canal: Canal = null
## Version du protocole annoncée dans le bonjour ; seuls les tests la changent (client périmé).
var version_annoncee: int = Protocole.VERSION
## Dernier salon reçu (`null` avant le premier).
var salon: Salon = null
## Paquets reçus puis ignorés (invalides, trop gros, de type inattendu).
var paquets_ignores: int = 0

var _peer: ENetMultiplayerPeer = null
var _nom: String = ""
## Jeton d'hôte du client local d'un salon hébergé ; vide pour tout autre client. Jamais journalisé.
var _jeton: PackedByteArray = PackedByteArray()
var _lie: bool = false
var _connecte: bool = false
var _perdu: bool = false
var _en_partie: bool = false
var _termine: bool = false
var _cible: int = -1
var _cible_demandee: int = -1
## Joueur regardé en plus de soi (confirmé par le serveur), sa demande en cours, le dernier tick
## reçu de son arène et les dernières cartes de densité reçues (id de joueur → 256 octets).
var _regarde: int = -1
var _regarde_demande: int = -1
var _dernier_tick_regarde: int = -1
var _densites: Dictionary = {}
var _dernier_tick: int = -1
var _dernier_bilan: Dictionary = {}
var _silence: float = 0.0
var _attente_connexion: float = 0.0


func _init() -> void:
	set_process(false)


func _exit_tree() -> void:
	deconnecter()


# --- Connexion -------------------------------------------------------------------------------


## Ouvre la connexion ; le bonjour part dès qu'elle est établie. `ERR_INVALID_PARAMETER` (sans
## connexion) pour une adresse vide ou un port hors 1..65535, `ERR_UNCONFIGURED` hors d'un `Canal`.
func connecter(
	adresse: String, port: int, nom: String, jeton: PackedByteArray = PackedByteArray()
) -> Error:
	if adresse.strip_edges().is_empty() or port < 1 or port > 65535:
		return ERR_INVALID_PARAMETER
	if _peer != null:
		return ERR_ALREADY_IN_USE
	if canal == null:
		canal = get_parent() as Canal
	if canal == null or not is_inside_tree():
		return ERR_UNCONFIGURED
	if donnees == null:
		donnees = Donnees.charger()
	if donnees == null:
		return ERR_FILE_CORRUPT
	var pair := ENetMultiplayerPeer.new()
	var code := pair.create_client(adresse.strip_edges(), port)
	if code != OK:
		return code
	_reinitialiser()
	_nom = nom
	_jeton = jeton
	_peer = pair
	multiplayer.multiplayer_peer = pair
	multiplayer.connected_to_server.connect(_a_la_connexion)
	multiplayer.connection_failed.connect(_a_l_echec_de_connexion)
	multiplayer.server_disconnected.connect(_a_la_deconnexion)
	canal.salon_recu.connect(_a_la_reception_salon)
	canal.etat_arene_recu.connect(_a_la_reception_arene)
	canal.etat_arene_regardee_recu.connect(_a_la_reception_regardee)
	canal.etat_global_recu.connect(_a_la_reception_global)
	canal.refus_recu.connect(_a_la_reception_refus)
	canal.resultat_recu.connect(_a_la_reception_resultat)
	canal.bilan_recu.connect(_a_la_reception_bilan)
	_lie = true
	set_process(true)
	return OK


## Ferme la connexion sans rien signaler : c'est un départ voulu. Sans effet si rien n'est ouvert.
func deconnecter() -> void:
	set_process(false)
	_connecte = false
	if _lie:
		_delier(multiplayer.connected_to_server, _a_la_connexion)
		_delier(multiplayer.connection_failed, _a_l_echec_de_connexion)
		_delier(multiplayer.server_disconnected, _a_la_deconnexion)
		if canal != null:
			_delier(canal.salon_recu, _a_la_reception_salon)
			_delier(canal.etat_arene_recu, _a_la_reception_arene)
			_delier(canal.etat_arene_regardee_recu, _a_la_reception_regardee)
			_delier(canal.etat_global_recu, _a_la_reception_global)
			_delier(canal.refus_recu, _a_la_reception_refus)
			_delier(canal.resultat_recu, _a_la_reception_resultat)
			_delier(canal.bilan_recu, _a_la_reception_bilan)
		_lie = false
	if _peer != null:
		_peer.close()
		if multiplayer.multiplayer_peer == _peer:
			multiplayer.multiplayer_peer = null
	_peer = null


## Le bilan de la partie qui vient de finir, `{}` tant qu'il n'est pas arrivé.
func bilan() -> Dictionary:
	return _dernier_bilan.duplicate()


func est_connecte() -> bool:
	return _connecte


func _delier(s: Signal, c: Callable) -> void:
	if s.is_connected(c):
		s.disconnect(c)


func _reinitialiser() -> void:
	salon = null
	paquets_ignores = 0
	_connecte = false
	_perdu = false
	_en_partie = false
	_termine = false
	_cible = -1
	_cible_demandee = -1
	_regarde = -1
	_regarde_demande = -1
	_dernier_tick_regarde = -1
	_densites = {}
	_dernier_tick = -1
	_dernier_bilan = {}
	_silence = 0.0
	_attente_connexion = 0.0


func _a_la_connexion() -> void:
	_connecte = true
	_silence = 0.0
	_cible = id_local()
	var bonjour := Protocole.encoder_bonjour(_nom, donnees.empreinte, _jeton)
	bonjour[1] = version_annoncee
	_envoyer("rpc_bonjour", bonjour)


func _a_l_echec_de_connexion() -> void:
	_perdre(MOTIF_INJOIGNABLE)


func _a_la_deconnexion() -> void:
	_perdre("Connexion perdue")


## Une seule émission par connexion : le refus est suivi d'une coupure, le silence aussi.
func _perdre(motif: String) -> void:
	if _perdu:
		return
	_perdu = true
	deconnecter()
	connexion_perdue.emit(motif)


# --- Horloge ---------------------------------------------------------------------------------


func _process(delta: float) -> void:
	avancer_horloge(delta)


## Fait avancer les délais de `dt` secondes (appelée chaque image ; les tests l'appellent aussi).
func avancer_horloge(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0 or _perdu or _peer == null:
		return
	if not _connecte:
		_attente_connexion += dt
		if _attente_connexion > delai_connexion_s:
			_perdre(MOTIF_INJOIGNABLE)
		return
	# Le serveur ne parle pas dans un salon inactif, ni après la fin de partie.
	if not _en_partie or _termine:
		return
	_silence += dt
	if _silence > delai_silence_s:
		_perdre("Connexion perdue")


# --- Réception -------------------------------------------------------------------------------


func _valide(octets: PackedByteArray, type: int) -> bool:
	if _perdu or Protocole.type_de(octets) != type:
		paquets_ignores += 1
		return false
	return true


func _a_la_reception_salon(octets: PackedByteArray) -> void:
	if not _valide(octets, Protocole.Msg.SALON):
		return
	var s := Salon.depuis_octets(octets)
	if s == null:
		paquets_ignores += 1
		return
	_silence = 0.0
	salon = s
	salon_mis_a_jour.emit(s)
	if s.lancee and not _en_partie:
		_en_partie = true
		partie_demarree.emit()


func _a_la_reception_arene(octets: PackedByteArray) -> void:
	if not _valide(octets, Protocole.Msg.ETAT_ARENE) or donnees == null:
		return
	var vue := Protocole.decoder_etat_arene(
		octets, donnees.ids_catalogue, donnees.ids_unites.size()
	)
	if vue == null:
		paquets_ignores += 1
		return
	_silence = 0.0
	_en_partie = true
	# Les paquets non fiables arrivent dans le désordre : seul un tick plus récent compte.
	if vue.tick <= _dernier_tick:
		return
	_dernier_tick = vue.tick
	vue_arene_recue.emit(vue)


## L'arène d'un autre joueur : ignorée si on ne la demande pas (ou plus), ou si elle est plus
## ancienne que la dernière reçue.
func _a_la_reception_regardee(octets: PackedByteArray) -> void:
	if not _valide(octets, Protocole.Msg.ETAT_ARENE_REGARDEE) or donnees == null:
		return
	var r := Protocole.decoder_etat_arene_regardee(
		octets, donnees.ids_catalogue, donnees.ids_unites.size()
	)
	if r.is_empty():
		paquets_ignores += 1
		return
	_silence = 0.0
	var id: int = r["id"]
	if id != _regarde:
		return
	var vue: VueArene = r["vue"]
	if vue.tick <= _dernier_tick_regarde:
		return
	_dernier_tick_regarde = vue.tick
	vue_regardee_recue.emit(id, vue)


func _a_la_reception_global(octets: PackedByteArray) -> void:
	if not _valide(octets, Protocole.Msg.ETAT_GLOBAL):
		return
	var vue := Protocole.decoder_etat_global(octets)
	if vue == null:
		paquets_ignores += 1
		return
	_porter_les_densites(vue)
	_silence = 0.0
	_en_partie = true
	_termine = vue.termine
	vue_globale_recue.emit(vue)


## Les cartes ne partent qu'une fois par seconde : un état global sans carte porte les dernières,
## celles des joueurs encore dans la partie.
func _porter_les_densites(vue: VueGlobale) -> void:
	if not vue.densites.is_empty():
		_densites = vue.densites.duplicate()
	var presents := {}
	for j: Dictionary in vue.joueurs:
		presents[int(j["id"])] = true
	for id: Variant in _densites.keys():
		if not presents.has(id):
			_densites.erase(id)
	vue.densites = _densites.duplicate()


func _a_la_reception_refus(octets: PackedByteArray) -> void:
	if not _valide(octets, Protocole.Msg.REFUS):
		return
	var motif := Protocole.decoder_refus(octets)
	_perdre(motif if not motif.is_empty() else "Connexion refusée.")


## Le bilan de fin de partie : le dernier reçu est gardé (`bilan()`), le signal le porte une fois.
func _a_la_reception_bilan(octets: PackedByteArray) -> void:
	if not _valide(octets, Protocole.Msg.BILAN):
		return
	var recu := Protocole.decoder_bilan(octets)
	if recu.is_empty():
		paquets_ignores += 1
		return
	_silence = 0.0
	_dernier_bilan = recu
	bilan_recu.emit(recu)


func _a_la_reception_resultat(octets: PackedByteArray) -> void:
	if not _valide(octets, Protocole.Msg.RESULTAT):
		return
	var r := Protocole.decoder_resultat(octets)
	if r.is_empty():
		paquets_ignores += 1
		return
	_silence = 0.0
	var genre: int = r["genre"]
	var code: int = r["code"]
	if genre == Protocole.Intention.OBSERVER and code == Types.Resultat.OK:
		_cible = _cible_demandee
		# Une autre arène a son propre compteur de ticks.
		_dernier_tick = -1
		_regarde = -1
	elif genre == Protocole.Intention.REGARDER:
		if code == Types.Resultat.OK:
			_regarde = _regarde_demande
			_dernier_tick_regarde = -1
		elif code == Types.Resultat.ARENE_MORTE:
			# Le serveur a ramené ce pair à sa propre arène (joueur parti, ou pair tombé).
			_regarde = -1
			_regarde_demande = -1
	resultat_intention.emit(_nom_du_genre(genre), code)


static func _nom_du_genre(genre: int) -> String:
	match genre:
		Protocole.Intention.ACHETER:
			return "acheter"
		Protocole.Intention.RELANCER:
			return "relancer"
		Protocole.Intention.VENDRE:
			return "vendre"
		Protocole.Intention.MARCHE_NOIR:
			return "choisir_marche_noir"
		Protocole.Intention.OBSERVER:
			return "observer"
		Protocole.Intention.REGARDER:
			return "regarder"
		Protocole.Intention.SANS_FIN:
			return "continuer_sans_fin"
		Protocole.Intention.QUITTER:
			return "quitter_partie"
		Protocole.Intention.PRET:
			return "pret"
		_:
			return "options"


# --- Envoi -----------------------------------------------------------------------------------


func _envoyer(rpc: String, octets: PackedByteArray) -> void:
	if _connecte and canal != null and _peer != null:
		canal.rpc_id(1, rpc, octets)


## Envoie une intention ; sans connexion, ou si elle ne s'encode pas, le résultat est rendu tout
## de suite à l'interface, comme `SourceLocale`.
func _intention(genre: int, arg: int, texte: String = "") -> void:
	var octets := Protocole.encoder_intention(genre, arg, texte)
	if not _connecte or octets.is_empty():
		resultat_intention.emit(_nom_du_genre(genre), Types.Resultat.ARENE_MORTE)
		return
	_envoyer("rpc_intention", octets)


# --- SourceVue -------------------------------------------------------------------------------


func id_local() -> int:
	if _peer == null or not _connecte:
		return -1
	return multiplayer.get_unique_id()


func cible_observee() -> int:
	return _cible


func acheter(index_offre: int) -> void:
	if index_offre < 0:
		resultat_intention.emit("acheter", Types.Resultat.INDICE_INVALIDE)
		return
	_intention(Protocole.Intention.ACHETER, index_offre)


func relancer() -> void:
	_intention(Protocole.Intention.RELANCER, 0)


func vendre(index_arme: int) -> void:
	if index_arme < 0:
		resultat_intention.emit("vendre", Types.Resultat.INDICE_INVALIDE)
		return
	_intention(Protocole.Intention.VENDRE, index_arme)


func choisir_marche_noir(id_amelioration: String) -> void:
	_intention(Protocole.Intention.MARCHE_NOIR, 0, id_amelioration)


## Pris en compte (la cible change) seulement quand le serveur répond `OK`.
func observer(id_joueur: int) -> void:
	_cible_demandee = id_joueur
	_intention(Protocole.Intention.OBSERVER, id_joueur)


## Regarde l'arène d'un autre joueur en gardant la sienne ; -1 cesse. Pris en compte quand le
## serveur répond `OK` ; soi-même est refusé tout de suite, sans rien envoyer.
func regarder(id_joueur: int) -> void:
	if id_joueur == id_local() and id_joueur != -1:
		resultat_intention.emit("regarder", Types.Resultat.INDICE_INVALIDE)
		return
	_regarde_demande = id_joueur
	_intention(Protocole.Intention.REGARDER, id_joueur)


func id_regarde() -> int:
	return _regarde


func continuer_sans_fin() -> void:
	_intention(Protocole.Intention.SANS_FIN, 0)


## Prévient le serveur, puis ferme : le serveur retire de toute façon le joueur à la coupure.
func quitter_partie() -> void:
	if _peer == null:
		return
	if _connecte:
		_envoyer("rpc_intention", Protocole.encoder_intention(Protocole.Intention.QUITTER, 0))
	deconnecter()


# --- Salon -----------------------------------------------------------------------------------


func est_hote() -> bool:
	return salon != null and salon.hote == id_local() and id_local() > 0


func pret(est_pret: bool) -> void:
	_intention(Protocole.Intention.PRET, 1 if est_pret else 0)


## Hôte seulement : sinon refusé tout de suite (`NON_DISPONIBLE`), rien n'est envoyé.
func regler_options(vitesse: float, graine: int, graine_fixe: bool) -> void:
	if not est_hote():
		resultat_intention.emit("options", Types.Resultat.NON_DISPONIBLE)
		return
	_envoyer("rpc_intention", Serveur.encoder_options(vitesse, graine, graine_fixe))


## Hôte seulement. Le serveur lance la partie dès que tous les joueurs sont prêts : l'hôte se
## met donc prêt, et la partie part si les autres le sont déjà.
func lancer() -> void:
	if not est_hote():
		resultat_intention.emit("pret", Types.Resultat.NON_DISPONIBLE)
		return
	pret(true)
