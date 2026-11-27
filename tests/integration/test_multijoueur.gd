extends CasDeTest
## Le multijoueur de bout en bout, dans ce processus et sur des ports tirés à l'exécution : un hôte
## crée un salon, une seconde joueuse le rejoint par l'adresse, les deux se mettent prêtes, l'hôte
## règle ×4 et lance, chacune reçoit ses vues, l'une achète, l'autre part, l'hôte continue. Puis le
## même parcours par le menu (`Principal`), avec la découverte des salons et le retour au menu.

const DELAI_MS := 6000
const ADRESSE := "127.0.0.1"
const GRAINE := 20261125

var _donnees: Donnees
var _noeuds_avant: int = 0
var _locale_avant: String = ""
var _port_jeu: int = 0
var _port_udp: int = 0
var _sessions: Array[SessionReseau] = []
var _principal: Principal = null


class Ecoute:
	extends RefCounted
	var session: SessionReseau
	var salons: Array[Salon] = []
	var arenes: Array[VueArene] = []
	var globales: Array[VueGlobale] = []
	var demarree: bool = false
	var perte: String = ""

	func _init(s: SessionReseau) -> void:
		session = s
		s.salon_mis_a_jour.connect(func(salon: Salon) -> void: salons.append(salon))
		s.partie_demarree.connect(func() -> void: demarree = true)
		s.connexion_perdue.connect(func(motif: String) -> void: perte = motif)
		s.client.vue_arene_recue.connect(func(v: VueArene) -> void: arenes.append(v))
		s.client.vue_globale_recue.connect(func(v: VueGlobale) -> void: globales.append(v))

	func dernier_salon() -> Salon:
		return salons[salons.size() - 1] if not salons.is_empty() else null

	func derniere_arene() -> VueArene:
		return arenes[arenes.size() - 1] if not arenes.is_empty() else null


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	_donnees = Donnees.charger()
	_noeuds_avant = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_sessions = []
	_principal = null
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE + OS.get_process_id()
	_port_jeu = _port_libre(rng)
	_port_udp = _port_libre(rng)


func apres_chaque() -> void:
	TranslationServer.set_locale(_locale_avant)


## Port tiré à l'exécution, vérifié libre en UDP (jeu ENet et découverte sont deux ports UDP).
func _port_libre(rng: RandomNumberGenerator) -> int:
	for i: int in 40:
		var p := rng.randi_range(20000, 60000)
		var essai := PacketPeerUDP.new()
		var ok := essai.bind(p, ADRESSE) == OK
		essai.close()
		if ok:
			return p
	return 0


func _jusqua(condition: Callable) -> bool:
	var fin := Time.get_ticks_msec() + DELAI_MS
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await arbre.process_frame
	return condition.call()


func _session() -> SessionReseau:
	var s := SessionReseau.new()
	arbre.root.add_child(s)
	_sessions.append(s)
	return s


func _fermer_tout() -> void:
	for s: SessionReseau in _sessions:
		if is_instance_valid(s):
			s.fermer()
			s.get_parent().remove_child(s)
			s.queue_free()
	_sessions = []
	if _principal != null and is_instance_valid(_principal):
		_principal.get_parent().remove_child(_principal)
		_principal.queue_free()
		_principal = null


func _compter_arene(e: Ecoute) -> int:
	return e.arenes.size()


func _deux_joueurs(h: Ecoute, b: Ecoute) -> bool:
	for e: Ecoute in [h, b]:
		if e.dernier_salon() == null or e.dernier_salon().joueurs.size() != 2:
			return false
	return true


func _prete_et_x4(h: Ecoute, b: Ecoute, id_b: int) -> bool:
	var sh := h.dernier_salon()
	var sb := b.dernier_salon()
	if sh == null or sb == null or not sh.joueurs.has(id_b):
		return false
	return bool((sh.joueurs[id_b] as Dictionary)["pret"]) and is_equal_approx(sb.vitesse, 0.25)


func _pret(e: Ecoute, id: int) -> bool:
	var salon := e.dernier_salon()
	return (
		salon != null and salon.joueurs.has(id) and bool((salon.joueurs[id] as Dictionary)["pret"])
	)


func _a_255_armes_et_des_allies(e: Ecoute) -> bool:
	var v := e.derniere_arene()
	return v != null and v.armes.size() == 255 and not v.allies.is_empty()


func _a_achete(e: Ecoute) -> bool:
	var v := e.derniere_arene()
	return v != null and v.armes.size() + v.ameliorations.size() >= 1


func _offre_abordable(v: VueArene) -> int:
	for i: int in v.offres.size():
		if int((v.offres[i] as Dictionary)["prix"]) <= v.argent:
			return i
	return -1


# --- Sessions --------------------------------------------------------------------------------


func test_creer_rejoindre_pret_vitesse_x4_lancer_achat_depart_et_aucune_fuite() -> void:
	verifier(_port_jeu > 0 and _port_udp > 0, "des ports libres")
	var hote := _session()
	var code := hote.heberger(_donnees, _port_jeu, "Salon de Mina", "Mina", _port_udp, [ADRESSE])
	verifier_egal(code, OK)
	var h := Ecoute.new(hote)
	var autre := _session()
	verifier_egal(autre.rejoindre(_donnees, ADRESSE, _port_jeu, "Bo"), OK)
	var b := Ecoute.new(autre)
	# Le salon montre les deux joueuses aux deux, l'hôte en premier.
	verifier(await _jusqua(_deux_joueurs.bind(h, b)), "les deux voient deux joueurs")
	var id_h := hote.client.id_local()
	var id_b := autre.client.id_local()
	verifier(id_h > 0 and id_b > 0 and id_h != id_b, "deux identifiants distincts")
	verifier(hote.client.est_hote(), "l'hôte est celui qui a créé le salon")
	verifier_faux(autre.client.est_hote())
	# Prêt : la seconde se met prête, l'hôte règle ×4 (durées divisées par quatre).
	autre.client.pret(true)
	hote.client.regler_options(Salon.VITESSES[2], 0, false)
	verifier(await _jusqua(_prete_et_x4.bind(h, b, id_b)), "B est prête et ×4 est réglé pour tous")
	verifier_faux(hote.serveur.salon.lancee, "rien n'a démarré tant que l'hôte n'a pas lancé")
	hote.client.lancer()
	verifier(
		await _jusqua(func() -> bool: return h.demarree and b.demarree),
		"la partie démarre pour tous"
	)
	verifier_proche(hote.serveur.salon.vitesse, 0.25, 0.0001, "le serveur joue en ×4")
	verifier(
		await _jusqua(func() -> bool: return h.arenes.size() >= 3 and b.arenes.size() >= 3),
		"chacune reçoit ses vues"
	)
	verifier(
		await _jusqua(
			func() -> bool: return not h.globales.is_empty() and not b.globales.is_empty()
		),
		"et l'état global"
	)
	# Chacune voit sa propre arène, avec sa propre boutique.
	verifier_egal(hote.client.cible_observee(), id_h)
	verifier_egal(autre.client.cible_observee(), id_b)
	# L'une achète et voit le résultat ; l'autre n'est pas débitée.
	var offre := _offre_abordable(h.derniere_arene())
	verifier(offre >= 0, "une offre abordable")
	var argent_b := b.derniere_arene().argent
	hote.client.acheter(offre)
	verifier(await _jusqua(_a_achete.bind(h)), "l'hôte voit son achat dans sa vue")
	var vb := b.derniere_arene()
	verifier_egal(vb.armes.size() + vb.ameliorations.size(), 0, "rien n'est arrivé chez B")
	verifier(vb.argent >= argent_b, "B n'a rien payé")
	# La seconde part : l'hôte continue sans erreur, ses ticks continuent de croître.
	autre.client.quitter_partie()
	var tick := h.derniere_arene().tick
	verifier(
		await _jusqua(func() -> bool: return h.derniere_arene().tick > tick + 10),
		"la partie continue pour l'hôte"
	)
	verifier_egal(h.perte, "", "l'hôte n'a perdu aucune connexion")
	verifier(
		await _jusqua(func() -> bool: return hote.serveur.joueur_de(id_b) == -1),
		"le serveur a retiré la joueuse partie"
	)
	_fermer_tout()
	await attendre_images(4)
	verifier_egal(
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _noeuds_avant, "aucune fuite"
	)


## Le pire état que le catalogue complet puisse produire : 255 armes (les 75 du catalogue, dont les
## invocatrices, complétées en doublons), des alliés invoqués. La joueuse doit recevoir, par ENet,
## une vue qui se décode sans paquet ignoré ni état refusé par le serveur.
func test_un_client_avec_255_armes_dont_des_invocatrices_recoit_un_etat_valide() -> void:
	verifier(_port_jeu > 0 and _port_udp > 0, "des ports libres")
	var hote := _session()
	verifier_egal(hote.heberger(_donnees, _port_jeu, "Salon", "Mina", _port_udp, [ADRESSE]), OK)
	var h := Ecoute.new(hote)
	var autre := _session()
	verifier_egal(autre.rejoindre(_donnees, ADRESSE, _port_jeu, "Bo"), OK)
	var b := Ecoute.new(autre)
	verifier(await _jusqua(_deux_joueurs.bind(h, b)), "les deux voient deux joueurs")
	autre.client.pret(true)
	verifier(await _jusqua(func() -> bool: return _pret(h, autre.client.id_local())), "B est prête")
	hote.client.lancer()
	verifier(await _jusqua(func() -> bool: return b.demarree), "la partie démarre")
	verifier(await _jusqua(func() -> bool: return b.arenes.size() >= 2), "B reçoit ses vues")
	var arene: Arene = (
		hote.serveur.partie._joueur(hote.serveur.joueur_de(autre.client.id_local())).arene
	)
	var ids: Array[String] = []
	for id: String in _donnees.armes:
		ids.append(id)
	ids.sort()
	var invocatrices := 0
	for id: String in ids:
		for effet: Dictionary in _donnees.armes[id]["effets"]:
			if effet["kind"] == "invocation":
				invocatrices += 1
	verifier(invocatrices >= 2, "le catalogue a des armes invocatrices (%d)" % invocatrices)
	for k: int in 255:
		var id := ids[k % ids.size()]
		if k < ids.size():
			arene.inventaire.niveaux[id] = 1
		arene.inventaire.armes.append(id)
	arene.synchroniser()
	for k: int in 12:
		arene.allies.invoquer(k % 2, Vector2.ZERO, 30.0, 10.0, Types.TypeDegats.CHAOS, k)
	verifier_egal(arene.armes.size(), 255, "255 armes montées côté serveur")
	verifier(
		await _jusqua(_a_255_armes_et_des_allies.bind(b)), "B reçoit ses 255 armes et ses alliés"
	)
	var vue := b.derniere_arene()
	verifier_egal(vue.armes.size(), 255)
	for arme: Dictionary in vue.armes:
		verifier(_donnees.armes.has(String(arme["id"])), "arme inconnue : %s" % arme["id"])
		verifier(int(arme["niveau"]) >= 1, "niveau de %s" % arme["id"])
	verifier(vue.allies.size() <= 64 and vue.allies.size() >= 1, "alliés : %d" % vue.allies.size())
	verifier_egal(VueArene.from_dict(vue.to_dict()).to_dict(), vue.to_dict(), "aller-retour exact")
	verifier_egal(autre.client.paquets_ignores, 0, "aucun paquet ignoré chez B")
	verifier_egal(hote.serveur.etats_trop_gros, 0, "aucun état refusé par le serveur")
	verifier_egal(b.perte, "", "B n'a pas perdu la connexion")
	_fermer_tout()


func test_regarder_l_arene_de_l_autre_par_le_reseau_puis_la_voir_partir() -> void:
	verifier(_port_jeu > 0 and _port_udp > 0, "des ports libres")
	var hote := _session()
	verifier_egal(hote.heberger(_donnees, _port_jeu, "Salon", "Mina", _port_udp, [ADRESSE]), OK)
	var h := Ecoute.new(hote)
	var autre := _session()
	verifier_egal(autre.rejoindre(_donnees, ADRESSE, _port_jeu, "Bo"), OK)
	var b := Ecoute.new(autre)
	verifier(await _jusqua(_deux_joueurs.bind(h, b)), "les deux voient deux joueurs")
	var id_b := autre.client.id_local()
	autre.client.pret(true)
	hote.client.lancer()
	verifier(
		await _jusqua(func() -> bool: return h.arenes.size() >= 2 and b.arenes.size() >= 2),
		"la partie tourne"
	)
	var regardees: Array[int] = []
	hote.client.vue_regardee_recue.connect(
		func(id: int, _v: VueArene) -> void: regardees.append(id)
	)
	hote.client.regarder(id_b)
	verifier(
		await _jusqua(func() -> bool: return regardees.size() >= 3), "l'hôte voit l'arène de B"
	)
	verifier_egal(hote.client.id_regarde(), id_b)
	for id: int in regardees:
		verifier_egal(id, id_b)
	# B part : l'hôte retrouve sa propre arène, sans erreur ni perte de connexion.
	autre.client.quitter_partie()
	verifier(
		await _jusqua(func() -> bool: return hote.client.id_regarde() == -1),
		"l'hôte ne regarde plus un joueur parti"
	)
	verifier_egal(h.perte, "")
	var tick := h.derniere_arene().tick
	verifier(
		await _jusqua(func() -> bool: return h.derniere_arene().tick > tick + 10),
		"sa propre arène continue"
	)
	_fermer_tout()
	await attendre_images(4)


func test_un_port_deja_pris_donne_un_message_clair_et_ne_laisse_rien() -> void:
	var occupant := _session()
	verifier_egal(occupant.heberger(_donnees, _port_jeu, "A", "Mina", _port_udp, [ADRESSE]), OK)
	var autre := _session()
	attendre_erreur("Couldn't create an ENet host")
	var code := autre.heberger(_donnees, _port_jeu, "B", "Bo", _port_udp, [ADRESSE])
	verifier_different(code, OK, "le port est pris")
	verifier_nul(autre.client)
	verifier_nul(autre.serveur)
	var message := SessionReseau.message_erreur(code, _port_jeu)
	verifier(message.contains(str(_port_jeu)), message)
	verifier(message.contains("déjà utilisé"), message)
	verifier_egal(occupant.serveur.nb_pairs() >= 0, true)
	_fermer_tout()
	await attendre_images(4)
	verifier_egal(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _noeuds_avant)


func test_un_hote_introuvable_signale_l_injoignable_en_texte() -> void:
	var s := _session()
	# Un port UDP où personne n'écoute : ENet n'obtient jamais de réponse.
	verifier_egal(s.rejoindre(_donnees, ADRESSE, _port_udp, "Bo"), OK)
	var e := Ecoute.new(s)
	s.client.delai_connexion_s = 0.5
	verifier(await _jusqua(func() -> bool: return not e.perte.is_empty()), "une erreur arrive")
	verifier(e.perte.contains("Impossible de joindre"), e.perte)
	_fermer_tout()


func test_un_serveur_de_version_differente_est_refuse_avec_son_motif() -> void:
	var hote := _session()
	verifier_egal(hote.heberger(_donnees, _port_jeu, "A", "Mina", _port_udp, [ADRESSE]), OK)
	var autre := _session()
	verifier_egal(autre.rejoindre(_donnees, ADRESSE, _port_jeu, "Bo"), OK)
	autre.client.version_annoncee = Protocole.VERSION + 1
	var e := Ecoute.new(autre)
	verifier(await _jusqua(func() -> bool: return not e.perte.is_empty()), "refus reçu")
	verifier(e.perte.contains("Version du protocole"), e.perte)
	_fermer_tout()


# --- Par le menu -----------------------------------------------------------------------------


func _principal_neuf() -> Principal:
	var p := (load("res://scenes/principal.tscn") as PackedScene).instantiate() as Principal
	p.arguments = Arguments.lire(PackedStringArray([]))
	p.donnees = _donnees
	p.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	p.port_decouverte = _port_udp
	p.cibles_decouverte = [ADRESSE]
	arbre.root.add_child(p)
	_principal = p
	return p


func test_par_le_menu_creer_se_decouvre_se_rejoint_et_se_lance() -> void:
	var principal := _principal_neuf()
	principal.menu().champ_nom.text = "Mina"
	principal.menu().bouton_creer.pressed.emit()
	var connexion := principal.connexion()
	verifier(connexion.page_creer_visible(), "le dialogue Créer s'ouvre")
	verifier_faux(principal.menu().visible)
	verifier_egal(connexion.champ_nom_salon.text, "Salon de Mina", "nom par défaut")
	verifier_egal(connexion.champ_port_creer.text, "7777", "port par défaut")
	connexion.champ_port_creer.text = str(_port_jeu)
	connexion.bouton_creer.pressed.emit()
	var salon := principal.salon()
	verifier(salon.visible, "le salon s'ouvre")
	verifier_faux(connexion.visible)
	verifier(
		await _jusqua(
			func() -> bool: return not salon.en_attente() and salon.lignes_joueurs().size() == 1
		),
		"l'hôte se voit"
	)
	verifier(salon.est_hote())
	verifier(salon.bouton_lancer.visible and salon.bouton_lancer.disabled == false, "seul : lance")

	# La découverte : un chercheur du réseau local voit le salon annoncé.
	var chercheur := Decouverte.new()
	arbre.root.add_child(chercheur)
	verifier_egal(chercheur.chercher(_port_udp, ADRESSE), OK)
	verifier(
		await _jusqua(func() -> bool: return not chercheur.salons().is_empty()),
		"le salon est annoncé sur le réseau local"
	)
	var trouve := chercheur.salons()[0]
	verifier_egal(trouve["nom"], "Salon de Mina")
	verifier_egal(trouve["port"], _port_jeu)
	chercheur.arreter()
	arbre.root.remove_child(chercheur)
	chercheur.queue_free()

	# Une seconde joueuse rejoint par l'adresse et se met prête ; l'hôte lance.
	var autre := _session()
	verifier_egal(autre.rejoindre(_donnees, trouve["adresse"], int(trouve["port"]), "Bo"), OK)
	var b := Ecoute.new(autre)
	verifier(
		await _jusqua(func() -> bool: return salon.lignes_joueurs().size() == 2),
		"le salon de l'hôte montre deux joueuses"
	)
	verifier(salon.bouton_lancer.disabled, "Lancer attend que B soit prête")
	autre.client.pret(true)
	verifier(
		await _jusqua(func() -> bool: return not salon.bouton_lancer.disabled),
		"Lancer s'active quand tout le monde est prêt"
	)
	var lignes := salon.lignes_joueurs()
	verifier(lignes[1].contains("Prêt"), "l'état prêt se lit en texte : %s" % lignes[1])
	salon.bouton_lancer.pressed.emit()
	verifier(await _jusqua(func() -> bool: return principal.jeu() != null), "la partie s'ouvre")
	verifier(principal.jeu().en_reseau)
	verifier_faux(salon.visible)
	verifier(await _jusqua(func() -> bool: return b.demarree), "B entre aussi en partie")
	verifier(
		await _jusqua(func() -> bool: return b.arenes.size() >= 2), "B reçoit les vues du serveur"
	)

	# L'hôte quitte par le menu de jeu : retour au menu, la session est fermée.
	principal.jeu().retour_menu.emit("")
	await attendre_images(2)
	verifier_nul(principal.jeu())
	verifier_nul(principal.session())
	verifier(principal.menu().visible)
	# La seconde joueuse apprend que le salon a disparu, avec un texte.
	verifier(await _jusqua(func() -> bool: return not b.perte.is_empty()), "B voit la perte")
	_fermer_tout()
	await attendre_images(4)
	verifier_egal(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _noeuds_avant)


func test_par_le_menu_retour_au_salon_rouvre_un_salon_neuf_ou_la_joueuse_peut_revenir() -> void:
	var principal := _principal_neuf()
	principal.menu().bouton_creer.pressed.emit()
	principal.connexion().champ_port_creer.text = str(_port_jeu)
	principal.connexion().bouton_creer.pressed.emit()
	var salon := principal.salon()
	var autre := _session()
	verifier_egal(autre.rejoindre(_donnees, ADRESSE, _port_jeu, "Bo"), OK)
	var b := Ecoute.new(autre)
	verifier(await _jusqua(func() -> bool: return salon.lignes_joueurs().size() == 2), "deux")
	autre.client.pret(true)
	verifier(await _jusqua(func() -> bool: return not salon.bouton_lancer.disabled), "prêts")
	salon.bouton_lancer.pressed.emit()
	verifier(await _jusqua(func() -> bool: return principal.jeu() != null), "la partie s'ouvre")

	# L'écran de fin propose « Retour au salon » : l'hôte retrouve un salon neuf, seul dedans.
	principal.jeu().retour_salon.emit()
	verifier(
		await _jusqua(func() -> bool: return _salon_neuf_seul(principal)),
		"l'hôte est dans un salon neuf, avec lui seul"
	)
	verifier(salon.est_hote())
	verifier_faux(principal.session().serveur.salon.lancee, "la nouvelle partie n'a pas démarré")
	# B, qui avait perdu l'ancien salon, y entre en disant de nouveau bonjour.
	verifier(await _jusqua(func() -> bool: return not b.perte.is_empty()), "B voit l'ancien partir")
	var b2 := _session()
	verifier_egal(b2.rejoindre(_donnees, ADRESSE, _port_jeu, "Bo"), OK)
	var e2 := Ecoute.new(b2)
	verifier(
		await _jusqua(func() -> bool: return salon.lignes_joueurs().size() == 2),
		"B revient dans le salon rouvert"
	)
	verifier(e2.perte.is_empty())
	_fermer_tout()
	await attendre_images(4)
	verifier_egal(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _noeuds_avant)


func test_par_le_menu_la_connexion_perdue_en_partie_ramene_au_menu_avec_le_motif() -> void:
	var hote := _session()
	verifier_egal(hote.heberger(_donnees, _port_jeu, "Salon", "Mina", _port_udp, [ADRESSE]), OK)
	verifier(
		await _jusqua(func() -> bool: return hote.client.salon != null),
		"l'hôte est dans son propre salon avant l'arrivée de B"
	)
	var principal := _principal_neuf()
	principal.menu().champ_nom.text = "Bo"
	principal.menu().bouton_rejoindre.pressed.emit()
	principal.connexion().champ_adresse.text = ADRESSE
	principal.connexion().champ_port_rejoindre.text = str(_port_jeu)
	principal.connexion().bouton_rejoindre_adresse.pressed.emit()
	var salon := principal.salon()
	verifier(
		await _jusqua(func() -> bool: return salon.visible and salon.lignes_joueurs().size() == 2),
		"le client du menu entre dans le salon de l'hôte"
	)
	principal.session().client.pret(true)
	verifier(await _jusqua(func() -> bool: return _tous_prets(hote)), "l'hôte voit B prête")
	hote.client.lancer()
	verifier(await _jusqua(func() -> bool: return principal.jeu() != null), "la partie s'ouvre")
	verifier(principal.jeu().en_reseau, "elle est en réseau")
	# L'hôte disparaît : la joueuse revient au menu et lit pourquoi.
	hote.fermer()
	verifier(
		await _jusqua(func() -> bool: return principal.jeu() == null and principal.menu().visible),
		"retour au menu"
	)
	verifier_nul(principal.session())
	var attendu := "Connexion perdue"
	var trouve := false
	for n: Node in principal.menu().find_children("*", "Label", true, false):
		var l := n as Label
		trouve = (
			trouve
			or (
				l.visible and l.text.begins_with(attendu) and l.text.length() > attendu.length() + 4
			)
		)
	verifier(trouve, "le motif est lisible au menu")
	_fermer_tout()


func _salon_neuf_seul(principal: Principal) -> bool:
	var salon := principal.salon()
	return (
		principal.jeu() == null
		and salon.visible
		and not salon.en_attente()
		and salon.lignes_joueurs().size() == 1
	)


func _tous_prets(s: SessionReseau) -> bool:
	var salon := s.client.salon
	if salon == null:
		return false
	for id: int in salon.joueurs:
		if id != salon.hote and not bool((salon.joueurs[id] as Dictionary)["pret"]):
			return false
	return salon.joueurs.size() == 2


func test_par_le_menu_port_pris_message_dans_le_dialogue_et_retour_possible() -> void:
	var occupant := _session()
	verifier_egal(occupant.heberger(_donnees, _port_jeu, "A", "Mina", _port_udp, [ADRESSE]), OK)
	var principal := _principal_neuf()
	principal.menu().bouton_creer.pressed.emit()
	var connexion := principal.connexion()
	connexion.champ_port_creer.text = str(_port_jeu)
	attendre_erreur("Couldn't create an ENet host")
	connexion.bouton_creer.pressed.emit()
	verifier(connexion.page_creer_visible(), "le dialogue reste ouvert")
	verifier_faux(principal.salon().visible)
	verifier_nul(principal.session())
	var message := connexion.find_children("Message", "Label", true, false)[0] as Label
	verifier(message.visible and message.text.contains("déjà utilisé"), message.text)
	connexion.retour_demande.emit()
	verifier(principal.menu().visible, "Retour ramène au menu")
	_fermer_tout()


func test_par_le_menu_rejoindre_un_hote_introuvable_affiche_l_erreur_sur_la_page() -> void:
	var principal := _principal_neuf()
	principal.menu().bouton_rejoindre.pressed.emit()
	var connexion := principal.connexion()
	verifier(connexion.page_rejoindre_visible())
	connexion.champ_adresse.text = ADRESSE
	connexion.champ_port_rejoindre.text = str(_port_udp)
	connexion.bouton_rejoindre_adresse.pressed.emit()
	verifier(principal.salon().visible and principal.salon().en_attente(), "connexion en cours")
	principal.session().client.delai_connexion_s = 0.5
	var message := connexion.find_children("Message", "Label", true, false)[1] as Label
	verifier(
		await _jusqua(
			func() -> bool: return connexion.page_rejoindre_visible() and message.visible
		),
		"retour à la page Rejoindre avec l'erreur"
	)
	verifier(message.text.contains("Impossible de joindre"), message.text)
	verifier_faux(principal.salon().visible)
	_fermer_tout()
