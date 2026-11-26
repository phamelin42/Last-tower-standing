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
## La redirection UPnP est tentée (réussie ou non) : le port externe obtenu, 0 si échec, et 0 aussi
## quand la box n'a pas répondu dans `delai_upnp_max` (l'annonce part alors avec le port local).
## Une réponse tardive réussie émet une seconde fois, avec le port obtenu ; un échec tardif
## n'émet rien de plus.
signal tentative_upnp_terminee(port_externe: int)
## Le client local est dans le salon et en est l'hôte. Émis une seule fois par `heberger` : c'est
## le feu vert de l'annuaire (un salon listé a un hôte présent).
signal hote_enregistre
## Ce que l'annuaire a répondu à une annonce, en `AnnuaireProtocole.Statut` (0 : acceptée). Une
## autre version d'annuaire arrive comme `VERSION_DIFFERENTE`. Un annuaire muet ou illisible n'émet
## rien : l'hôte n'a pas de raison à lire.
signal annonce_repondue(statut: int)

const ADRESSE_LOCALE := "127.0.0.1"
## Combien de temps la première annonce attend la tentative UPnP (ADR 001, décision 21).
const DELAI_UPNP_MAX_S := 10.0

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
## La redirection du port de jeu de la session hébergée, `null` sans salon hébergé.
var upnp: UpnpHote = null
## Port externe ouvert par UPnP, 0 tant que la tentative n'a pas réussi.
var port_externe: int = 0
## `() -> UpnpHote.Passerelle` : la box à utiliser, remplacée par un double dans les tests. Une
## valeur nulle (aucune redirection) est celle du mode sans fenêtre : ni les tests ni un serveur
## sans écran n'interrogent le réseau de la machine.
var fabrique_passerelle: Callable = _passerelle_par_defaut
## Attente maximale de la tentative UPnP avant d'annoncer le port local : réglable par les tests.
var delai_upnp_max: float = DELAI_UPNP_MAX_S
## `hote:port` de l'annuaire et choix « Partie publique » : réglés avant `heberger`. Sans adresse
## ou sans la case, rien n'est jamais envoyé.
var annuaire_adresse: String = ""
var salon_public: bool = false
## L'annonceur de la session hébergée, `null` tant que les conditions ne sont pas réunies.
var annuaire: AnnuaireClient = null

var _racines: Array[Node] = []
var _apis: Array[SceneMultiplayer] = []
var _perdue: bool = false
var _hote_enregistre: bool = false
var _upnp_terminee: bool = false
## Le délai a déjà dit « 0 » à l'hôte : un échec tardif de la box ne le répète pas.
var _delai_upnp_depasse: bool = false
## Décompte de la tentative UPnP. Un `Timer` enfant plutôt qu'un `SceneTreeTimer` : ce dernier ne
## s'annule pas, et son échéance réveillerait une session fermée ou hébergée à nouveau.
var _decompte_upnp: Timer = null


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
	_hote_enregistre = false
	_upnp_terminee = false
	_delai_upnp_depasse = false
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
	_ouvrir_port(port_jeu)
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
	_arreter_annonce_annuaire()
	_hote_enregistre = false
	_upnp_terminee = false
	_delai_upnp_depasse = false
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
	_fermer_port()
	jeton_hote = PackedByteArray()
	for racine: Node in _racines:
		if racine.get_parent() != null:
			racine.get_parent().remove_child(racine)
		racine.queue_free()
	_racines = []
	_perdue = false


static func _passerelle_par_defaut() -> UpnpHote.Passerelle:
	if DisplayServer.get_name() == "headless":
		return null
	return UpnpHote.PasserelleUpnp.new()


## Demande à la box d'ouvrir le port, dans un fil dédié : l'interface ne s'arrête jamais dessus.
func _ouvrir_port(port_jeu: int) -> void:
	var box: Variant = fabrique_passerelle.call()
	if not box is UpnpHote.Passerelle:
		# Pas de box à interroger : la tentative est « terminée » d'emblée, l'annonce n'attend rien.
		_upnp_terminee = true
		_essayer_annonce_annuaire()
		return
	upnp = UpnpHote.new()
	upnp.name = "Upnp"
	upnp.passerelle = box as UpnpHote.Passerelle
	upnp.tentative_terminee.connect(_sur_tentative_upnp)
	add_child(upnp)
	upnp.demarrer(port_jeu)
	_decompte_upnp = Timer.new()
	_decompte_upnp.one_shot = true
	_decompte_upnp.timeout.connect(_sur_delai_upnp)
	add_child(_decompte_upnp)
	_decompte_upnp.start(delai_upnp_max)


func _fermer_port() -> void:
	port_externe = 0
	_arreter_decompte_upnp()
	if upnp == null:
		return
	var u := upnp
	upnp = null
	# Quitter n'est pas un échec : la fermeture ne doit pas faire croire à un refus de la box.
	u.tentative_terminee.disconnect(_sur_tentative_upnp)
	u.fermer()
	remove_child(u)
	u.queue_free()


func _arreter_decompte_upnp() -> void:
	if _decompte_upnp == null:
		return
	var d := _decompte_upnp
	_decompte_upnp = null
	d.stop()
	remove_child(d)
	d.queue_free()


## La box n'a pas fini à temps (décision 21) : on la tient pour muette, l'hôte le voit, et le salon
## est annoncé avec le port local. Sa réponse tardive, si elle vient, met le port à jour.
func _sur_delai_upnp() -> void:
	_arreter_decompte_upnp()
	if _upnp_terminee:
		return
	_delai_upnp_depasse = true
	_upnp_terminee = true
	port_externe = 0
	tentative_upnp_terminee.emit(0)
	_essayer_annonce_annuaire()


func _sur_tentative_upnp(port_obtenu: int) -> void:
	_arreter_decompte_upnp()
	if _delai_upnp_depasse and port_obtenu <= 0:
		return
	port_externe = port_obtenu
	_upnp_terminee = true
	tentative_upnp_terminee.emit(port_obtenu)
	_essayer_annonce_annuaire()


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
	c.salon_mis_a_jour.connect(_sur_salon_du_client)
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


func _sur_salon_du_client(salon: Salon) -> void:
	salon_mis_a_jour.emit(salon)
	if _hote_enregistre or serveur == null or client == null:
		return
	var moi := client.id_local()
	if salon.hote == moi and salon.joueurs.has(moi):
		_hote_enregistre = true
		hote_enregistre.emit()
		_essayer_annonce_annuaire()


## Première annonce : hôte enregistré **et** tentative UPnP terminée (ADR, décision 20), case
## cochée, annuaire configuré. Le serveur dédié n'a pas de `SessionReseau` : jamais annoncé.
func _essayer_annonce_annuaire() -> void:
	if annuaire != null or serveur == null or not salon_public:
		return
	if not _hote_enregistre or not _upnp_terminee:
		return
	if annuaire_adresse.strip_edges().is_empty():
		return
	var a := AnnuaireClient.new()
	a.name = "Annuaire"
	a.adresse = annuaire_adresse
	add_child(a)
	annuaire = a
	a.annonce_terminee.connect(_sur_annonce_terminee)
	a.demarrer_annonce(_annonce_annuaire)


func _sur_annonce_terminee(etat: int, statut: int) -> void:
	if etat == AnnuaireClient.Etat.OK:
		annonce_repondue.emit(statut)
	elif etat == AnnuaireClient.Etat.INCOMPATIBLE:
		annonce_repondue.emit(AnnuaireProtocole.Statut.VERSION_DIFFERENTE)


## Ce que l'annuaire reçoit : l'annonce locale, avec le port que les autres joueurs peuvent
## atteindre (le port externe d'UPnP, sinon le port de jeu).
func _annonce_annuaire() -> Dictionary:
	var a := _annonce()
	if a.is_empty():
		return a
	a["port"] = port_externe if port_externe > 0 else port
	return a


func _arreter_annonce_annuaire() -> void:
	if annuaire == null:
		return
	var a := annuaire
	annuaire = null
	# Le RETRAIT part même si la session disparaît aussitôt : l'annonceur finit seul.
	a.retirer_et_quitter()
