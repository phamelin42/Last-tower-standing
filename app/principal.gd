class_name Principal
extends Node
## Racine du jeu : montre le menu, ouvre la scène de partie et la ferme au retour, et mène le
## multijoueur (créer un salon, en rejoindre un, le salon, la partie en réseau). Les arguments de la
## ligne de commande et les données se règlent avant l'entrée dans l'arbre (tests).

const SCENE_JEU := "res://scenes/jeu.tscn"
const SCENE_SALON := "res://scenes/salon.tscn"
const SCENE_CONNEXION := "res://scenes/connexion.tscn"
## Serveur dédié (`--serveur`), fourni par `reseau/serveur_dedie.gd`.
const SCENE_SERVEUR := "res://scenes/serveur.tscn"
## Annuaire des parties en ligne (`--annuaire`), fourni par `reseau/annuaire_dedie.gd`.
const SCENE_ANNUAIRE := "res://scenes/annuaire.tscn"
## Banc d'essai des images par seconde (`--banc-ips`), fourni par `app/banc_ips.gd`.
const SCENE_BANC := "res://scenes/banc_ips.tscn"

## Injectable avant `_ready` ; sinon lus sur la ligne de commande.
var arguments: Dictionary = {}
## Injectables : données de la partie (sinon `data/`) et fichier de réglages.
var donnees: Donnees = null
var dossier_donnees: String = Donnees.DOSSIER_REEL
var chemin_reglages: String = Reglages.CHEMIN_DEFAUT
## Sortie du processus : `get_tree().quit(code)` par défaut, remplaçable par les tests.
var sortie: Callable = Callable()
## Découverte des salons : seuls les tests changent le port et les cibles (127.0.0.1).
var port_decouverte: int = Decouverte.PORT_DECOUVERTE
var cibles_decouverte: Array[String] = [Decouverte.DIFFUSION]
## `() -> UpnpHote.Passerelle` : la box de la redirection UPnP, remplacée par un double dans les
## tests ; vide, la session choisit la vraie.
var fabrique_passerelle: Callable = Callable()
## `() -> String` : l'adresse `hote:port` de l'annuaire. Par défaut le réglage du joueur, sauf en
## mode sans fenêtre (tests, serveur sans écran) où aucun annuaire n'est contacté : comme pour la
## box, seuls les tests qui le demandent touchent au réseau.
var adresse_annuaire: Callable = Callable()

var _menu: MenuPrincipal
var _banc: BancIps = null
var _compteur: CompteurIps = null
## Dernier réglage « afficher les images par seconde » appliqué : F3 n'est défait que par un
## changement de la case, pas par un autre réglage (volume, échelle…).
var _ips_applique: bool = false
var _ips_connu: bool = false
var _jeu: Jeu = null
var _connexion: ConnexionUi
var _salon: SalonUi
var _session: SessionReseau = null
var _chercheur: Decouverte = null
var _annuaire: AnnuaireClient = null
var _salons_annuaire: Array[Dictionary] = []
## Les lignes d'avertissement de l'écran du salon, par origine (`upnp`, `annuaire`) : elles se
## lisent ensemble, aucune n'écrase l'autre.
var _avertissements: Dictionary = {}
var _nom_joueur: String = ""
var _parametres_hote: Array = []
var _erreur_creation: String = ""


## Seuls les ports de jeu de 1 024 à 65 535 sont listés par l'annuaire (ADR, décision 8).
static func port_listable(port: int) -> bool:
	return port >= AnnuaireProtocole.PORT_MIN and port <= AnnuaireProtocole.PORT_MAX


## La scène à charger à la place du menu : l'annuaire si `--annuaire`, le serveur dédié si
## `--serveur`, le banc d'essai si `--banc-ips`, sinon rien.
static func scene_de_demarrage(args: Dictionary) -> String:
	if bool(args.get("annuaire", false)):
		return SCENE_ANNUAIRE
	if bool(args.get("serveur", false)):
		return SCENE_SERVEUR
	return SCENE_BANC if int(args.get("banc_ips", 0)) > 0 else ""


func _ready() -> void:
	if arguments.is_empty():
		arguments = ServeurDedie.lire_options(OS.get_cmdline_user_args())
	var messages: Array = arguments["messages"]
	for message: Variant in messages:
		print(message)
	var scene := scene_de_demarrage(arguments)
	if scene == SCENE_BANC:
		_lancer_banc(scene)
		return
	if scene == SCENE_ANNUAIRE:
		_lancer_annuaire(scene)
		return
	if not scene.is_empty():
		_lancer_serveur_dedie(scene)
		return
	_menu = $Menu as MenuPrincipal
	_menu.configurer(chemin_reglages)
	_menu.solo_demande.connect(_lancer_solo)
	_menu.quitter_demande.connect(_quitter)
	_menu.reglages_modifies.connect(_appliquer_reglages)
	_menu.creer_demande.connect(_ouvrir_creer)
	_menu.rejoindre_demande.connect(_ouvrir_rejoindre)
	_construire_multijoueur()
	_construire_compteur(
		func() -> int: return CompteurIps.ennemis_visibles(_jeu.arene if _jeu != null else null)
	)
	_appliquer_reglages(Reglages.charger(chemin_reglages))
	if bool(arguments["solo_auto"]):
		_lancer_solo(_menu.nom_joueur())


func menu() -> MenuPrincipal:
	return _menu


## Le banc d'essai ouvert par `--banc-ips`, ou `null`.
func banc() -> BancIps:
	return _banc


## Le compteur d'images par seconde (absent du serveur dédié et de l'annuaire, sans écran).
func compteur() -> CompteurIps:
	return _compteur


## Le compteur vit au-dessus de tout (menu, partie, banc) : F3 le montre ou le cache partout.
func _construire_compteur(ennemis: Callable) -> void:
	var couche := CanvasLayer.new()
	couche.name = "Ips"
	couche.layer = 100
	add_child(couche)
	_compteur = CompteurIps.new()
	_compteur.name = "Compteur"
	_compteur.fournisseur_ennemis = ennemis
	couche.add_child(_compteur)


## Le banc remplace le menu : le compteur y est affiché d'office, Échap quitte.
func _lancer_banc(scene: String) -> void:
	var d := _donnees_du_jeu()
	if d == null or not ResourceLoader.exists(scene):
		printerr("Banc d'essai impossible : données ou scène introuvables.")
		_sortir(1)
		return
	var menu_inutile := get_node_or_null("Menu")
	if menu_inutile != null:
		remove_child(menu_inutile)
		menu_inutile.queue_free()
	_banc = (load(scene) as PackedScene).instantiate() as BancIps
	_banc.quitter_demande.connect(func() -> void: _sortir(0))
	add_child(_banc)
	_banc.lancer(d, int(arguments["banc_ips"]))
	_construire_compteur(func() -> int: return CompteurIps.ennemis_visibles(_banc.arene))
	_compteur.definir_visible(true)


func connexion() -> ConnexionUi:
	return _connexion


func salon() -> SalonUi:
	return _salon


## La session multijoueur en cours, ou `null`.
func session() -> SessionReseau:
	return _session


## Le serveur dédié n'a pas d'interface : sa scène remplace le menu, qui n'est pas chargé. Un code
## de sortie non nul (données absentes, port impossible) ferme le processus, sans quoi un serveur
## qui n'écoute pas resterait lancé pour rien.
func _lancer_serveur_dedie(scene: String) -> void:
	if not ResourceLoader.exists(scene):
		printerr("Scène du serveur dédié introuvable : %s" % scene)
		_sortir(1)
		return
	var menu_inutile := get_node_or_null("Menu")
	if menu_inutile != null:
		remove_child(menu_inutile)
		menu_inutile.queue_free()
	var dedie := (load(scene) as PackedScene).instantiate() as ServeurDedie
	dedie.sortie = _sortir
	add_child(dedie)
	var donnees_serveur := donnees if donnees != null else Donnees.charger(dossier_donnees)
	var code := dedie.lancer(arguments, donnees_serveur)
	if code != ServeurDedie.CODE_OK:
		_sortir(code)


## Le processus ne fait que tenir l'annuaire : ni menu, ni données du jeu.
func _lancer_annuaire(scene: String) -> void:
	if not ResourceLoader.exists(scene):
		printerr("Scène de l'annuaire introuvable : %s" % scene)
		_sortir(1)
		return
	var menu_inutile := get_node_or_null("Menu")
	if menu_inutile != null:
		remove_child(menu_inutile)
		menu_inutile.queue_free()
	var annuaire := (load(scene) as PackedScene).instantiate() as AnnuaireDedie
	annuaire.sortie = _sortir
	add_child(annuaire)
	var code := annuaire.lancer(arguments)
	if code != AnnuaireDedie.CODE_OK:
		_sortir(code)


func _sortir(code: int) -> void:
	if sortie.is_valid():
		sortie.call(code)
	else:
		get_tree().quit(code)


## La partie en cours, ou `null` quand le menu est affiché.
func jeu() -> Jeu:
	return _jeu


func _lancer_solo(nom: String) -> void:
	if _jeu != null:
		return
	var d := donnees if donnees != null else Donnees.charger(dossier_donnees)
	if d == null:
		_menu.afficher_message(tr("MENU_ERREUR_DONNEES"))
		return
	var graine: int = arguments["graine"]
	if graine < 0:
		graine = randi()
	var facteur: float = arguments["vitesse"]
	_enregistrer_nom(nom)
	var jeu_neuf := (load(SCENE_JEU) as PackedScene).instantiate() as Jeu
	jeu_neuf.chemin_reglages = chemin_reglages
	jeu_neuf.nom_joueur = nom
	add_child(jeu_neuf)
	if not jeu_neuf.demarrer_solo(d, graine, facteur):
		remove_child(jeu_neuf)
		jeu_neuf.queue_free()
		_menu.afficher_message(tr("MENU_ERREUR_DONNEES"))
		return
	_jeu = jeu_neuf
	_jeu.retour_menu.connect(_retour_menu)
	_menu.afficher_message("")
	_menu.visible = false


func _retour_menu(motif: String) -> void:
	_fermer_jeu()
	_fermer_session()
	_arreter_recherche()
	_connexion.fermer()
	_salon.visible = false
	_menu.visible = true
	_menu.afficher_message(tr("MENU_CONNEXION_PERDUE") % motif if not motif.is_empty() else "")
	_menu.bouton_solo.grab_focus()


func _enregistrer_nom(nom: String) -> void:
	var r := Reglages.charger(chemin_reglages)
	if r.nom_joueur != nom and nom != tr("MENU_NOM_PAR_DEFAUT"):
		r.nom_joueur = nom
		r.sauver(chemin_reglages)


func _enregistrer_salon_public(publique: bool) -> void:
	var r := Reglages.charger(chemin_reglages)
	if r.salon_public != publique:
		r.salon_public = publique
		r.sauver(chemin_reglages)


func _appliquer_reglages(r: Reglages) -> void:
	Jeu.appliquer_fenetre(get_window(), r)
	BusAudio.appliquer_volume(r.volume_general)
	if _jeu != null:
		_jeu.appliquer_mouvement_reduit(r.mouvement_reduit)
	if _compteur != null and (not _ips_connu or r.afficher_ips != _ips_applique):
		_ips_connu = true
		_ips_applique = r.afficher_ips
		_compteur.definir_visible(r.afficher_ips)


func _quitter() -> void:
	get_tree().quit()


# --- Multijoueur -------------------------------------------------------------------------------


func _construire_multijoueur() -> void:
	_connexion = (load(SCENE_CONNEXION) as PackedScene).instantiate() as ConnexionUi
	_salon = (load(SCENE_SALON) as PackedScene).instantiate() as SalonUi
	add_child(_connexion)
	add_child(_salon)
	_connexion.creer_demande.connect(_creer)
	_connexion.rejoindre_demande.connect(_rejoindre)
	_connexion.retour_demande.connect(_retour_depuis_connexion)
	_connexion.actualiser_demande.connect(_interroger_annuaire)
	_salon.pret_change.connect(_sur_pret)
	_salon.options_changees.connect(_sur_options)
	_salon.lancer_demande.connect(_sur_lancer)
	_salon.quitter.connect(_quitter_salon)


func _donnees_du_jeu() -> Donnees:
	return donnees if donnees != null else Donnees.charger(dossier_donnees)


func _ouvrir_creer(nom: String) -> void:
	if _jeu != null:
		return
	_nom_joueur = nom
	_enregistrer_nom(nom)
	_menu.visible = false
	_connexion.ouvrir_creer(nom, Reglages.charger(chemin_reglages).salon_public)


func _ouvrir_rejoindre(nom: String) -> void:
	if _jeu != null:
		return
	_nom_joueur = nom
	_enregistrer_nom(nom)
	_menu.visible = false
	_arreter_recherche()
	_chercheur = Decouverte.new()
	_chercheur.name = "Chercheur"
	add_child(_chercheur)
	_connexion.ouvrir_rejoindre()
	_interroger_annuaire()
	var code := _chercheur.chercher(port_decouverte)
	if code != OK:
		_connexion.afficher_erreur_rejoindre(tr("CONNEXION_DECOUVERTE_INDISPONIBLE"))
		return
	_chercheur.liste_changee.connect(_sur_liste_changee)


func _sur_liste_changee() -> void:
	_afficher_liste()


## Le réseau local et l'annuaire en une liste. Sans annuaire joint, la liste est celle du réseau.
func _afficher_liste() -> void:
	if _chercheur == null:
		return
	_connexion.afficher_salons(
		ConnexionUi.fusionner(_chercheur.salons(), _salons_annuaire, Protocole.VERSION)
	)


func _adresse_de_l_annuaire() -> String:
	if adresse_annuaire.is_valid():
		return str(adresse_annuaire.call())
	if DisplayServer.get_name() == "headless":
		return ""
	return Reglages.charger(chemin_reglages).annuaire_adresse


## Seuls moments où l'annuaire est contacté : l'ouverture de « Rejoindre » et l'actualisation. Une
## demande encore en vol n'est pas doublée (limite de débit du service).
func _interroger_annuaire() -> void:
	if _annuaire == null:
		_annuaire = AnnuaireClient.new()
		_annuaire.name = "Annuaire"
		add_child(_annuaire)
		_annuaire.liste_terminee.connect(_sur_liste_annuaire)
	if _annuaire.liste_en_cours():
		return
	_annuaire.adresse = _adresse_de_l_annuaire()
	_annuaire.lister()


func _sur_liste_annuaire(etat: int, salons: Array[Dictionary]) -> void:
	# Un refus de débit n'est pas une panne : l'annuaire marche, la dernière liste reste affichée.
	if etat == AnnuaireClient.Etat.LIMITE:
		return
	_salons_annuaire = []
	if etat == AnnuaireClient.Etat.OK:
		_salons_annuaire = salons
	_connexion.afficher_etat_annuaire(etat)
	_afficher_liste()


func _arreter_recherche() -> void:
	_salons_annuaire = []
	if _annuaire != null:
		remove_child(_annuaire)
		_annuaire.queue_free()
		_annuaire = null
	if _chercheur != null:
		_chercheur.arreter()
		remove_child(_chercheur)
		_chercheur.queue_free()
		_chercheur = null


func _retour_depuis_connexion() -> void:
	_arreter_recherche()
	_connexion.fermer()
	_menu.visible = true
	_menu.bouton_solo.grab_focus()


func _nouvelle_session() -> SessionReseau:
	_fermer_session()
	_session = SessionReseau.new()
	_session.name = "Session"
	add_child(_session)
	_session.salon_mis_a_jour.connect(_sur_salon)
	_session.partie_demarree.connect(_sur_partie_demarree)
	_session.connexion_perdue.connect(_sur_perte)
	_session.tentative_upnp_terminee.connect(_sur_upnp)
	_session.annonce_repondue.connect(_sur_reponse_annuaire)
	_avertissements = {}
	if fabrique_passerelle.is_valid():
		_session.fabrique_passerelle = fabrique_passerelle
	return _session


func _fermer_session() -> void:
	if _session == null:
		return
	var s := _session
	_session = null
	s.fermer()
	remove_child(s)
	s.queue_free()


func _creer(nom_salon: String, port: int) -> void:
	var d := _donnees_du_jeu()
	if d == null:
		_connexion.afficher_erreur_creer(tr("MENU_ERREUR_DONNEES"))
		return
	var s := _nouvelle_session()
	s.annuaire_adresse = _adresse_de_l_annuaire()
	s.salon_public = _connexion.salon_public()
	_enregistrer_salon_public(s.salon_public)
	var code := s.heberger(d, port, nom_salon, _nom_joueur, port_decouverte, cibles_decouverte)
	if code != OK:
		_fermer_session()
		_erreur_creation = SessionReseau.message_erreur(code, port)
		_connexion.afficher_erreur_creer(_erreur_creation)
		return
	_erreur_creation = ""
	_parametres_hote = [nom_salon, port]
	_connexion.fermer()
	_salon.afficher_infos(tr("SALON_ANNONCE_HOTE") % [nom_salon, port])
	_salon.afficher_avertissement("")
	if s.salon_public and not s.annuaire_adresse.is_empty() and not port_listable(port):
		_avertir("annuaire", tr("CONNEXION_ANNUAIRE_PORT_BAS"))
	_salon.afficher_attente()


func _rejoindre(adresse: String, port: int) -> void:
	var d := _donnees_du_jeu()
	if d == null:
		_connexion.afficher_erreur_rejoindre(tr("MENU_ERREUR_DONNEES"))
		return
	var s := _nouvelle_session()
	var code := s.rejoindre(d, adresse, port, _nom_joueur)
	if code != OK:
		_fermer_session()
		_connexion.afficher_erreur_rejoindre(SessionReseau.message_erreur(code, port))
		return
	_parametres_hote = []
	_arreter_recherche()
	_connexion.fermer()
	_salon.afficher_infos("")
	_salon.afficher_avertissement("")
	_salon.afficher_attente()


## La box a répondu : sans port ouvert, l'hôte le lit sur le salon (le réseau local fonctionne).
func _sur_upnp(port_obtenu: int) -> void:
	_avertir("upnp", tr("CONNEXION_UPNP_ECHEC") if port_obtenu == 0 else "")


## L'annuaire a jugé l'annonce : seuls les refus qui disent pourquoi la partie n'est pas listée
## (port injoignable, autre version, annuaire plein) s'affichent ; un refus passager (débit,
## sondes occupées) laisse la ligne telle quelle, une annonce acceptée l'efface.
func _sur_reponse_annuaire(statut: int) -> void:
	var cles := {
		AnnuaireProtocole.Statut.VERSION_DIFFERENTE: "CONNEXION_ANNUAIRE_HOTE_INCOMPATIBLE",
		AnnuaireProtocole.Statut.INJOIGNABLE: "CONNEXION_ANNUAIRE_HOTE_INJOIGNABLE",
		AnnuaireProtocole.Statut.PLEIN: "CONNEXION_ANNUAIRE_HOTE_PLEIN",
	}
	if statut == AnnuaireProtocole.Statut.ACCEPTE:
		_avertir("annuaire", "")
	elif cles.has(statut):
		_avertir("annuaire", tr(str(cles[statut])))


func _avertir(origine: String, texte: String) -> void:
	_avertissements[origine] = texte
	var lignes := PackedStringArray()
	for cle: String in ["upnp", "annuaire"]:
		var ligne := str(_avertissements.get(cle, ""))
		if not ligne.is_empty():
			lignes.append(ligne)
	_salon.afficher_avertissement("\n".join(lignes))


func _sur_salon(s: Salon) -> void:
	if _session != null and _session.client != null and _jeu == null:
		_salon.afficher(s, _session.client.id_local())


func _sur_pret(pret: bool) -> void:
	if _session != null and _session.client != null:
		_session.client.pret(pret)


func _sur_options(vitesse: float, graine: int, graine_fixe: bool) -> void:
	if _session != null and _session.client != null:
		_session.client.regler_options(vitesse, graine, graine_fixe)


func _sur_lancer() -> void:
	if _session != null and _session.client != null:
		_session.client.lancer()


func _quitter_salon() -> void:
	_fermer_session()
	_salon.visible = false
	_menu.visible = true
	_menu.bouton_solo.grab_focus()


## Refus, serveur injoignable ou perdu. Avant le premier état du salon, la joueuse revient à la
## page « Rejoindre » avec la raison ; plus tard, au menu.
func _sur_perte(motif: String) -> void:
	var en_connexion := _salon.visible and _salon.en_attente() and _parametres_hote.is_empty()
	if not en_connexion:
		_retour_menu(motif)
		return
	_fermer_session()
	_salon.visible = false
	_ouvrir_rejoindre(_nom_joueur)
	_connexion.afficher_erreur_rejoindre(motif)


func _sur_partie_demarree() -> void:
	if _jeu != null or _session == null or _session.client == null:
		return
	var jeu_neuf := (load(SCENE_JEU) as PackedScene).instantiate() as Jeu
	jeu_neuf.chemin_reglages = chemin_reglages
	jeu_neuf.nom_joueur = _nom_joueur
	add_child(jeu_neuf)
	if not jeu_neuf.demarrer_reseau(_session.client.donnees, _session.client):
		remove_child(jeu_neuf)
		jeu_neuf.queue_free()
		_retour_menu(tr("MENU_ERREUR_DONNEES"))
		return
	_jeu = jeu_neuf
	_jeu.retour_menu.connect(_retour_menu)
	_jeu.retour_salon.connect(_retour_salon)
	_salon.visible = false
	_menu.visible = false


## Après la partie : l'hôte rouvre un salon neuf sur le même port, les autres reviennent à la
## liste des salons (le serveur ne relance pas une partie dans le même salon).
func _retour_salon() -> void:
	var etait_hote := _session != null and _session.est_hote()
	var params := _parametres_hote.duplicate()
	_fermer_jeu()
	_fermer_session()
	if etait_hote and params.size() == 2:
		_creer(String(params[0]), int(params[1]))
		if _session == null:
			_retour_menu(_erreur_creation)
	else:
		_ouvrir_rejoindre(_nom_joueur)


func _fermer_jeu() -> void:
	if _jeu != null:
		remove_child(_jeu)
		_jeu.queue_free()
		_jeu = null
