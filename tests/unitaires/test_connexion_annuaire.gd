extends CasDeTest
## « Rejoindre une partie » et « Créer une partie » face à l'annuaire (ADR 001) : la liste fusionne
## le réseau local et l'annuaire avec leur origine en texte, masque le doublon (le local gagne),
## marque une autre version du jeu sans la filtrer, et ne perd ni le réseau local ni l'adresse
## saisie quand l'annuaire se tait. Chemin réel : `Principal`, le client et le service de T7.1
## sur la boucle locale (sonde simulée).

const TestServeur := preload("res://tests/unitaires/test_annuaire_serveur.gd")
const TestClient := preload("res://tests/unitaires/test_annuaire_client.gd")
const LOCAL := "127.0.0.1"
const DELAI_MS := 8000
const GRAINE := 20291125
const NOTICE := (
	"Partie publique : votre adresse IP sera transmise à l’annuaire et visible des joueurs "
	+ "qui consultent la liste, tant que le salon est ouvert. Rien n’est conservé ensuite."
)

var _donnees: Donnees
var _principal: Principal = null
var _noeud: AnnuaireServeur = null
var _fausse: TestServeur.FausseSonde = null
var _faux: TestClient.FauxAnnuaire = null
var _port_annuaire: int = 0
var _clients: Array[AnnuaireClient] = []
var _locale_avant: String = ""


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	_donnees = Donnees.charger()
	_principal = null
	_noeud = null
	_faux = null
	_clients = []
	delai_max = 40.0


func apres_chaque() -> void:
	for c: AnnuaireClient in _clients:
		if is_instance_valid(c):
			if c.get_parent() != null:
				c.get_parent().remove_child(c)
			c.free()
	_clients = []
	if _principal != null and is_instance_valid(_principal):
		_principal.get_parent().remove_child(_principal)
		_principal.free()
	_principal = null
	if _faux != null:
		_faux.get_parent().remove_child(_faux)
		_faux.free()
		_faux = null
	if _noeud != null:
		_noeud.arreter()
		_noeud.free()
		_noeud = null
	TranslationServer.set_locale(_locale_avant)


func _connexion_neuve() -> ConnexionUi:
	return (load("res://scenes/connexion.tscn") as PackedScene).instantiate() as ConnexionUi


func _t(cle: String) -> String:
	return TranslationServer.translate(cle)


func _port_aleatoire(decalage: int, ouvrir: Callable) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE + OS.get_process_id() + decalage
	for i: int in 60:
		var p := rng.randi_range(20000, 60000)
		if ouvrir.call(p):
			return p
	return -1


func _annuaire() -> void:
	_fausse = TestServeur.FausseSonde.new()
	_noeud = AnnuaireServeur.new()
	_noeud.sonde = _fausse
	_noeud.journal = func(_t: String) -> void: pass
	_noeud.service.autoriser_prive = true
	arbre.root.add_child(_noeud)
	_port_annuaire = _port_aleatoire(0, func(p: int) -> bool: return _noeud.demarrer(p) == OK)


func _annuaire_faux(octets: PackedByteArray, muet: bool = false) -> void:
	_faux = TestClient.FauxAnnuaire.new()
	_faux.octets = octets
	_faux.muet = muet
	arbre.root.add_child(_faux)
	_port_annuaire = _port_aleatoire(3, func(p: int) -> bool: return _faux.ouvrir(p) == OK)


func _principal_neuf(adresse: String) -> Principal:
	var p := (load("res://scenes/principal.tscn") as PackedScene).instantiate() as Principal
	p.arguments = Arguments.lire(PackedStringArray([]))
	p.donnees = _donnees
	p.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	p.port_decouverte = _port_aleatoire(5, _udp_libre)
	p.cibles_decouverte = []
	p.fabrique_passerelle = func() -> UpnpHote.Passerelle: return null
	p.adresse_annuaire = func() -> String: return adresse
	arbre.root.add_child(p)
	_principal = p
	return p


func _udp_libre(port: int) -> bool:
	var essai := PacketPeerUDP.new()
	var ok := essai.bind(port, LOCAL) == OK
	essai.close()
	return ok


func _adresse_annuaire() -> String:
	return "%s:%d" % [LOCAL, _port_annuaire]


func _annoncer(nom: String, joueurs: int, port: int, version: int = Protocole.VERSION) -> void:
	var c := AnnuaireClient.new()
	c.adresse = _adresse_annuaire()
	c.version_jeu = version
	arbre.root.add_child(c)
	_clients.append(c)
	c.demarrer_annonce(
		func() -> Dictionary: return {"nom": nom, "joueurs": joueurs, "max": 8, "port": port}
	)


func _jusqua(condition: Callable, delai_ms: int = DELAI_MS) -> bool:
	var fin := Time.get_ticks_msec() + delai_ms
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await arbre.process_frame
	return condition.call()


func _ouvrir_rejoindre(p: Principal) -> void:
	p.menu().champ_nom.text = "Mina"
	p.menu().bouton_rejoindre.pressed.emit()


func _local(p: Principal, nom: String, port: int) -> void:
	var chercheur := p.get_node("Chercheur") as Decouverte
	chercheur.recevoir(Decouverte.encoder(nom, 1, 8, port), LOCAL)


# --- Fusion ------------------------------------------------------------------------------------


func _a(nom: String, port: int, ip: String = "203.0.113.9", version: int = 4) -> Dictionary:
	return {"nom": nom, "port": port, "ip": ip, "version_jeu": version, "joueurs": 1, "max": 8}


func _l(nom: String, port: int, adresse: String = "192.168.1.5") -> Dictionary:
	return {"nom": nom, "port": port, "adresse": adresse, "joueurs": 2, "max": 8}


func test_un_doublon_exact_est_masque_et_l_entree_locale_l_emporte() -> void:
	var locaux: Array[Dictionary] = [_l("Chez Mina", 7777)]
	var annuaire: Array[Dictionary] = [_a("Chez Mina", 7777)]
	var liste := ConnexionUi.fusionner(locaux, annuaire, 4)
	verifier_egal(liste.size(), 1)
	verifier_egal(liste[0]["origine"], ConnexionUi.ORIGINE_LOCAL)
	verifier_egal(liste[0]["adresse"], "192.168.1.5", "on rejoint par l'adresse locale")
	verifier_egal(liste[0]["joueurs"], 2)


func test_meme_nom_avec_un_autre_port_n_est_pas_un_doublon() -> void:
	var locaux: Array[Dictionary] = [_l("Chez Mina", 7777)]
	var annuaire: Array[Dictionary] = [_a("Chez Mina", 7778)]
	var liste := ConnexionUi.fusionner(locaux, annuaire, 4)
	verifier_egal(liste.size(), 2)
	verifier_egal(liste[0]["origine"], ConnexionUi.ORIGINE_LOCAL)
	verifier_egal(liste[1]["origine"], ConnexionUi.ORIGINE_ANNUAIRE)
	verifier_egal(liste[1]["adresse"], "203.0.113.9")


func test_meme_port_avec_un_autre_nom_n_est_pas_un_doublon() -> void:
	var locaux: Array[Dictionary] = [_l("Chez Mina", 7777)]
	var annuaire: Array[Dictionary] = [_a("Chez Zoé", 7777)]
	verifier_egal(ConnexionUi.fusionner(locaux, annuaire, 4).size(), 2)


func test_un_nom_de_24_caracteres_accentues_se_compare_exactement() -> void:
	var nom := "ÉàüîÉàüîÉàüîÉàüîÉàüîÉàüî"
	var locaux: Array[Dictionary] = [_l(nom, 7777)]
	var annuaire: Array[Dictionary] = [_a(nom, 7777), _a(nom.to_lower(), 7777)]
	var liste := ConnexionUi.fusionner(locaux, annuaire, 4)
	verifier_egal(liste.size(), 2, "la casse différente n'est pas le même salon")


func test_une_autre_version_du_jeu_est_marquee_jamais_filtree() -> void:
	var annuaire: Array[Dictionary] = []
	for v: int in [0, 3, 4, 5, 255]:
		annuaire.append(_a("Salon v%d" % v, 7000 + v, "203.0.113.%d" % (v % 200 + 1), v))
	var liste := ConnexionUi.fusionner([] as Array[Dictionary], annuaire, 4)
	verifier_egal(liste.size(), 5, "aucun salon filtré")
	for s: Dictionary in liste:
		verifier_egal(s["autre_version"], not String(s["nom"]).ends_with("v4"), s["nom"])


func test_les_salons_locaux_ne_sont_jamais_marques_autre_version() -> void:
	var liste := ConnexionUi.fusionner(
		[_l("Local", 7777)] as Array[Dictionary], [] as Array[Dictionary], 4
	)
	verifier_egal(liste[0]["autre_version"], false)


func test_liste_vide_et_liste_pleine() -> void:
	verifier_egal(
		ConnexionUi.fusionner([] as Array[Dictionary], [] as Array[Dictionary], 4).size(), 0
	)
	var annuaire: Array[Dictionary] = []
	for i: int in AnnuaireProtocole.MAX_SALONS:
		annuaire.append(_a("Salon %d" % i, 7000 + i, "203.0.113.%d" % (i + 1)))
	var locaux: Array[Dictionary] = []
	for i: int in 3:
		locaux.append(_l("Salon %d" % i, 7000 + i))
	var liste := ConnexionUi.fusionner(locaux, annuaire, 4)
	verifier_egal(liste.size(), 100, "100 de l'annuaire dont 3 masqués, plus 3 locaux")


func test_la_ligne_dit_l_origine_et_l_autre_version_en_texte() -> void:
	var connexion := _connexion_neuve()
	arbre.root.add_child(connexion)
	connexion.ouvrir_rejoindre()
	var annuaire: Array[Dictionary] = [_a("Loin", 7777, "203.0.113.9", 9)]
	var locaux: Array[Dictionary] = [_l("Près", 7777)]
	connexion.afficher_salons(ConnexionUi.fusionner(locaux, annuaire, 4))
	var lignes := connexion.lignes_salons()
	verifier_egal(lignes.size(), 2)
	verifier(lignes[0].contains("Réseau local"), lignes[0])
	verifier(not lignes[0].contains("autre version"), lignes[0])
	verifier(lignes[1].contains("Annuaire") and lignes[1].contains("autre version"), lignes[1])
	connexion.get_parent().remove_child(connexion)
	connexion.free()


# --- Page « Créer » ----------------------------------------------------------------------------


func test_la_case_partie_publique_est_cochee_par_defaut_avec_sa_notice_exacte() -> void:
	var connexion := _connexion_neuve()
	arbre.root.add_child(connexion)
	connexion.ouvrir_creer("Mina")
	verifier(connexion.salon_public(), "cochée par défaut")
	verifier_egal(connexion.case_publique.text, "Partie publique")
	verifier_egal(connexion.notice_publique.text, NOTICE)
	verifier_egal(_t("CONNEXION_PUBLIQUE_NOTICE"), NOTICE)
	verifier(connexion.case_publique.custom_minimum_size.y >= 48.0, "la case fait 48 px")
	connexion.ouvrir_creer("Mina", false)
	verifier_faux(connexion.salon_public())
	connexion.get_parent().remove_child(connexion)
	connexion.free()


func test_la_notice_a_la_typographie_francaise() -> void:
	var notice := _t("CONNEXION_PUBLIQUE_NOTICE")
	verifier(notice.contains("publique : votre"), "espace insécable avant les deux-points")
	verifier(notice.contains("l’annuaire") and notice.contains("n’est"), "apostrophes ’")
	verifier(not notice.contains("'"), "aucune apostrophe droite")


func test_les_textes_de_l_annuaire_sont_dans_le_csv() -> void:
	verifier_egal(_t("CONNEXION_ANNUAIRE_INDISPONIBLE"), "Annuaire indisponible")
	verifier_egal(
		_t("CONNEXION_ANNUAIRE_INCOMPATIBLE"), "Annuaire incompatible : mettez le jeu à jour"
	)
	verifier_egal(_t("CONNEXION_ORIGINE_LOCAL"), "Réseau local")
	verifier_egal(_t("CONNEXION_ORIGINE_ANNUAIRE"), "Annuaire")
	verifier_egal(_t("CONNEXION_AUTRE_VERSION"), "autre version")


func test_decocher_la_case_empeche_toute_annonce_et_se_retient() -> void:
	_annuaire()
	var p := _principal_neuf(_adresse_annuaire())
	p.menu().champ_nom.text = "Mina"
	p.menu().bouton_creer.pressed.emit()
	p.connexion().case_publique.button_pressed = false
	var port := _port_aleatoire(9, _udp_libre)
	p.connexion().champ_port_creer.text = str(port)
	p.connexion().bouton_creer.pressed.emit()
	verifier_non_nul(p.session())
	await attendre_images(40)
	verifier_egal(_fausse.lancees.size(), 0, "rien n'est parti")
	verifier_faux(Reglages.charger(p.chemin_reglages).salon_public, "le choix est retenu")
	p.connexion().ouvrir_creer("Mina", Reglages.charger(p.chemin_reglages).salon_public)
	verifier_faux(p.connexion().salon_public())


func test_un_salon_public_est_annonce_a_l_annuaire() -> void:
	_annuaire()
	var p := _principal_neuf(_adresse_annuaire())
	p.menu().champ_nom.text = "Mina"
	p.menu().bouton_creer.pressed.emit()
	var port := _port_aleatoire(9, _udp_libre)
	p.connexion().champ_port_creer.text = str(port)
	p.connexion().champ_nom_salon.text = "Chez Mina"
	p.connexion().bouton_creer.pressed.emit()
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	verifier_egal(_noeud.service.salons()[0]["nom"], "Chez Mina")
	verifier_egal(_fausse.lancees[0]["port"], port)


# --- Page « Rejoindre » ------------------------------------------------------------------------


func test_rejoindre_montre_les_salons_de_l_annuaire_avec_leur_origine() -> void:
	_annuaire()
	_annoncer("Loin de chez moi", 3, 7777)
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	var p := _principal_neuf(_adresse_annuaire())
	_ouvrir_rejoindre(p)
	verifier(await _jusqua(func() -> bool: return p.connexion().lignes_salons().size() == 1))
	var ligne := p.connexion().lignes_salons()[0]
	verifier(ligne.contains("Loin de chez moi") and ligne.contains("3 sur 8"), ligne)
	verifier(ligne.contains("Annuaire"), ligne)
	verifier_egal(p.connexion().message_annuaire(), "", "aucun message quand tout va bien")
	var demandes: Array = []
	p.connexion().rejoindre_demande.connect(
		func(a: String, port: int) -> void: demandes.append([a, port])
	)
	p.connexion().presser_salon(0)
	verifier_egal(demandes, [[LOCAL, 7777]])


func test_un_salon_d_une_autre_version_est_liste_et_marque() -> void:
	_annuaire()
	_annoncer("Vieux salon", 1, 7777, Protocole.VERSION + 1)
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	var p := _principal_neuf(_adresse_annuaire())
	_ouvrir_rejoindre(p)
	verifier(await _jusqua(func() -> bool: return p.connexion().lignes_salons().size() == 1))
	verifier(p.connexion().lignes_salons()[0].contains("autre version"))


func test_le_doublon_local_et_annuaire_n_affiche_que_le_local() -> void:
	_annuaire()
	_annoncer("Chez Mina", 2, 7777)
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	var p := _principal_neuf(_adresse_annuaire())
	_ouvrir_rejoindre(p)
	_local(p, "Chez Mina", 7777)
	verifier(await _jusqua(func() -> bool: return p.connexion().message_annuaire() == ""))
	await attendre_images(30)
	var lignes := p.connexion().lignes_salons()
	verifier_egal(lignes.size(), 1, "un seul salon")
	verifier(lignes[0].contains("Réseau local"), lignes[0])


func test_actualiser_relit_l_annuaire_sans_toucher_au_reste() -> void:
	_annuaire()
	var p := _principal_neuf(_adresse_annuaire())
	_ouvrir_rejoindre(p)
	await attendre_images(20)
	verifier_egal(p.connexion().lignes_salons().size(), 0)
	_annoncer("Nouveau", 1, 7777)
	verifier(await _jusqua(func() -> bool: return _noeud.service.salons().size() == 1))
	await attendre_images(20)
	verifier_egal(p.connexion().lignes_salons().size(), 0, "jamais d'interrogation en fond")
	p.connexion().bouton_actualiser.pressed.emit()
	verifier(await _jusqua(func() -> bool: return p.connexion().lignes_salons().size() == 1))


func test_l_annuaire_n_est_pas_contacte_en_arriere_plan() -> void:
	_annuaire_faux(PackedByteArray(), true)
	var p := _principal_neuf(_adresse_annuaire())
	p.menu().champ_nom.text = "Mina"
	await attendre_images(40)
	verifier_egal(_faux.recus.size(), 0, "avant « Rejoindre », rien")
	_ouvrir_rejoindre(p)
	verifier(await _jusqua(func() -> bool: return _faux.recus.size() == 1))
	p.connexion().boutons_retour[1].pressed.emit()
	await attendre_images(40)
	verifier_egal(_faux.recus.size(), 1, "une seule requête, pas de rafraîchissement automatique")


func test_un_annuaire_injoignable_garde_le_local_et_l_adresse_saisie() -> void:
	_annuaire()
	var port := _port_annuaire
	_noeud.arreter()
	var p := _principal_neuf("%s:%d" % [LOCAL, port])
	_ouvrir_rejoindre(p)
	_local(p, "Chez Mina", 7777)
	verifier(
		await _jusqua(
			func() -> bool: return p.connexion().message_annuaire() == "Annuaire indisponible"
		)
	)
	verifier_egal(p.connexion().lignes_salons().size(), 1, "le réseau local reste")
	var demandes: Array = []
	p.connexion().rejoindre_demande.connect(
		func(a: String, pt: int) -> void: demandes.append([a, pt])
	)
	p.connexion().champ_adresse.text = "10.0.0.7"
	p.connexion().bouton_rejoindre_adresse.pressed.emit()
	verifier_egal(demandes, [["10.0.0.7", 7777]], "l'IP saisie marche toujours")


func test_un_annuaire_muet_ne_gele_pas_la_page_puis_repli() -> void:
	_annuaire_faux(PackedByteArray(), true)
	var p := _principal_neuf(_adresse_annuaire())
	_ouvrir_rejoindre(p)
	_local(p, "Chez Mina", 7777)
	await attendre_images(5)
	verifier_egal(p.connexion().lignes_salons().size(), 1, "le local s'affiche pendant l'attente")
	verifier(
		await _jusqua(
			func() -> bool: return p.connexion().message_annuaire() == "Annuaire indisponible", 6000
		),
		"repli au bout du délai"
	)


func test_une_autre_version_d_annuaire_dit_incompatible() -> void:
	_annuaire_faux(
		PackedByteArray([5, 0, AnnuaireProtocole.MAGIE, AnnuaireProtocole.VERSION + 1, 0x81, 1, 2])
	)
	var p := _principal_neuf(_adresse_annuaire())
	_ouvrir_rejoindre(p)
	_local(p, "Chez Mina", 7777)
	var attendu := _t("CONNEXION_ANNUAIRE_INCOMPATIBLE")
	verifier(await _jusqua(func() -> bool: return p.connexion().message_annuaire() == attendu))
	verifier_egal(p.connexion().lignes_salons().size(), 1)


func test_un_annuaire_vide_dans_les_reglages_le_desactive_sans_message() -> void:
	_annuaire_faux(PackedByteArray())
	var p := _principal_neuf("")
	_ouvrir_rejoindre(p)
	_local(p, "Chez Mina", 7777)
	await attendre_images(30)
	verifier_egal(p.connexion().message_annuaire(), "")
	verifier_egal(p.connexion().lignes_salons().size(), 1)
	verifier_egal(_faux.recus.size(), 0)


func test_un_annuaire_invalide_dans_les_reglages_dit_indisponible() -> void:
	var p := _principal_neuf("a:b:c")
	_ouvrir_rejoindre(p)
	_local(p, "Chez Mina", 7777)
	verifier(
		await _jusqua(
			func() -> bool: return p.connexion().message_annuaire() == "Annuaire indisponible"
		)
	)
	verifier_egal(p.connexion().lignes_salons().size(), 1)
