extends CasDeTest
## Le client réseau contre un vrai serveur ENet du même processus (boucle locale, port tiré à
## l'exécution, graine fixée par `OPTIONS`), puis contre des octets injectés dans ses réceptions.

const DELAI_MS: int = 8000
const GRAINE: int = 4242

var d: Donnees
var serveur: Serveur
var api_serveur: SceneMultiplayer
var port: int = 0
var clients: Array[Client] = []
var racines: Array[Node] = []


class Espion:
	extends RefCounted
	var arenes: Array[VueArene] = []
	var globales: Array[VueGlobale] = []
	var resultats: Array[Array] = []
	var pertes: Array[String] = []
	var salons: int = 0
	var parties: int = 0

	func dernier() -> VueArene:
		return arenes[arenes.size() - 1] if not arenes.is_empty() else null

	func dernier_resultat() -> Array:
		return resultats[resultats.size() - 1] if not resultats.is_empty() else []


func avant_chaque() -> void:
	d = Donnees.charger()
	clients = []
	racines = []
	serveur = null
	api_serveur = null
	delai_max = 30.0


func apres_chaque() -> void:
	for c: Client in clients:
		c.deconnecter()
	if serveur != null:
		serveur.arreter()
	if api_serveur != null:
		api_serveur.multiplayer_peer = null
	for r: Node in racines:
		if is_instance_valid(r):
			r.free()
	clients = []
	racines = []


# --- Aides -----------------------------------------------------------------------------------


func _racine(nom: String, api: SceneMultiplayer) -> Canal:
	var racine := Node.new()
	racine.name = nom
	arbre.root.add_child(racine)
	racines.append(racine)
	arbre.set_multiplayer(api, racine.get_path())
	var canal := Canal.new()
	canal.name = "Canal"
	racine.add_child(canal)
	return canal


func _monter_serveur() -> bool:
	api_serveur = SceneMultiplayer.new()
	var canal := _racine("RacineServeur", api_serveur)
	serveur = Serveur.new()
	serveur.name = "Serveur"
	canal.add_child(serveur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261125 + OS.get_process_id()
	for i: int in 40:
		port = rng.randi_range(20000, 60000)
		if serveur.demarrer(d, port) == OK:
			return true
	return false


func _nouveau_client(nom: String, donnees: Donnees = null) -> Client:
	var api := SceneMultiplayer.new()
	var canal := _racine("Racine" + nom, api)
	var c := Client.new()
	c.name = "Client"
	c.donnees = donnees if donnees != null else d
	canal.add_child(c)
	clients.append(c)
	return c


func _espionner(c: Client) -> Espion:
	var e := Espion.new()
	c.vue_arene_recue.connect(func(v: VueArene) -> void: e.arenes.append(v))
	c.vue_globale_recue.connect(func(v: VueGlobale) -> void: e.globales.append(v))
	c.resultat_intention.connect(func(g: String, k: int) -> void: e.resultats.append([g, k]))
	c.connexion_perdue.connect(func(m: String) -> void: e.pertes.append(m))
	c.salon_mis_a_jour.connect(func(_s: Salon) -> void: e.salons += 1)
	c.partie_demarree.connect(func() -> void: e.parties += 1)
	return e


func _jusqua(condition: Callable) -> bool:
	var fin := Time.get_ticks_msec() + DELAI_MS
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await arbre.process_frame
	return false


## Le résultat d'intention numéro `avant` (attend qu'il arrive).
func _resultat_apres(e: Espion, avant: int) -> Array:
	await _jusqua(func() -> bool: return e.resultats.size() > avant)
	return e.resultats[avant] if e.resultats.size() > avant else []


## Serveur + deux clients A (hôte) et B, partie lancée, graine fixée.
func _partie_a_deux() -> Array:
	verifier(_monter_serveur(), "un port libre")
	var a := _nouveau_client("A")
	var b := _nouveau_client("B")
	var ea := _espionner(a)
	var eb := _espionner(b)
	verifier_egal(a.connecter("127.0.0.1", port, "Aki"), OK)
	verifier(await _jusqua(func() -> bool: return a.salon != null), "A reçoit le salon")
	verifier_egal(b.connecter("127.0.0.1", port, "Bo"), OK)
	verifier(
		await _jusqua(func() -> bool: return b.salon != null and b.salon.joueurs.size() == 2),
		"B reçoit le salon à deux"
	)
	verifier(a.est_hote() and not b.est_hote(), "A est l'hôte")
	a.regler_options(1.0, GRAINE, true)
	verifier(
		await _jusqua(func() -> bool: return b.salon.graine_fixe and b.salon.graine == GRAINE),
		"B voit les options de l'hôte"
	)
	b.pret(true)
	a.lancer()
	verifier(
		await _jusqua(func() -> bool: return ea.parties == 1 and eb.parties == 1),
		"la partie démarre pour les deux"
	)
	verifier(
		await _jusqua(func() -> bool: return ea.arenes.size() >= 3 and eb.arenes.size() >= 3),
		"des vues arrivent"
	)
	return [a, b, ea, eb]


func _achat_debite(e: Espion, cible: int, plafond: int) -> bool:
	var v := e.dernier()
	return bool((v.offres[cible] as Dictionary)["vendu"]) and v.argent <= plafond


# --- Connexion -------------------------------------------------------------------------------


func test_connecter_refuse_adresse_vide_et_ports_invalides_sans_connexion() -> void:
	var c := _nouveau_client("X")
	verifier_egal(c.connecter("", 7777, "Aki"), ERR_INVALID_PARAMETER)
	for p: int in [0, -1, 70000, 65536]:
		verifier_egal(c.connecter("127.0.0.1", p, "Aki"), ERR_INVALID_PARAMETER, "port %d" % p)
	verifier_faux(c.est_connecte())
	verifier_egal(c.id_local(), -1)


func test_hors_connexion_une_intention_n_envoie_rien_et_repond_tout_de_suite() -> void:
	var c := _nouveau_client("X")
	var e := _espionner(c)
	c.acheter(-1)
	c.acheter(0)
	verifier_egal(e.resultats[0], ["acheter", Types.Resultat.INDICE_INVALIDE])
	verifier_egal(e.resultats[1][1], Types.Resultat.ARENE_MORTE)
	c.regler_options(1.0, 0, false)
	verifier_egal(e.resultats[2], ["options", Types.Resultat.NON_DISPONIBLE])


func test_le_client_n_a_plus_de_methode_vendre() -> void:
	var c := _nouveau_client("X")
	verifier_faux(c.has_method("vendre"), "la vente n'existe plus (D23)")


# --- Une partie réelle -----------------------------------------------------------------------


func test_salon_pret_lancement_et_vues_a_tick_croissant() -> void:
	var cs := await _partie_a_deux()
	var a: Client = cs[0]
	var b: Client = cs[1]
	var ea: Espion = cs[2]
	verifier(a.id_local() > 0 and a.id_local() != b.id_local(), "numéros distincts")
	verifier_egal(a.cible_observee(), a.id_local())
	verifier_egal(a.salon.joueurs.size(), 2)
	verifier(a.salon.lancee, "le salon est lancé")
	for i: int in range(1, ea.arenes.size()):
		verifier(ea.arenes[i].tick > ea.arenes[i - 1].tick, "ticks strictement croissants")
	verifier(
		await _jusqua(func() -> bool: return ea.globales.size() >= 1), "A reçoit un état global"
	)
	var ids: Array[int] = []
	for j: Dictionary in ea.globales[0].joueurs:
		ids.append(int(j["id"]))
	ids.sort()
	var attendus: Array[int] = [a.id_local(), b.id_local()]
	attendus.sort()
	verifier_egal(ids, attendus)
	verifier_egal(a.paquets_ignores + b.paquets_ignores, 0, "rien d'invalide n'est arrivé")


func test_un_non_hote_ne_regle_ni_ne_lance() -> void:
	verifier(_monter_serveur())
	var a := _nouveau_client("A")
	var b := _nouveau_client("B")
	var eb := _espionner(b)
	a.connecter("127.0.0.1", port, "Aki")
	await _jusqua(func() -> bool: return a.salon != null)
	b.connecter("127.0.0.1", port, "Bo")
	await _jusqua(func() -> bool: return b.salon != null)
	b.regler_options(0.5, 9, true)
	b.lancer()
	verifier_egal(eb.resultats[0], ["options", Types.Resultat.NON_DISPONIBLE])
	verifier_egal(eb.resultats[1], ["pret", Types.Resultat.NON_DISPONIBLE])
	await attendre_images(10)
	verifier_faux(serveur.salon.graine_fixe, "le serveur n'a rien reçu")
	verifier_faux(bool(serveur.salon.joueurs[b.id_local()]["pret"]))


func test_un_achat_debite_l_or_et_chaque_client_ne_voit_que_son_arene() -> void:
	var cs := await _partie_a_deux()
	var a: Client = cs[0]
	var ea: Espion = cs[2]
	var eb: Espion = cs[3]
	var avant := ea.dernier()
	var cible := -1
	for i: int in avant.offres.size():
		if int((avant.offres[i] as Dictionary)["prix"]) <= avant.argent:
			cible = i
			break
	verifier(cible >= 0, "une offre abordable")
	var prix: int = (avant.offres[cible] as Dictionary)["prix"]
	var n := ea.resultats.size()
	a.acheter(cible)
	var r := await _resultat_apres(ea, n)
	verifier_egal(r, ["acheter", Types.Resultat.OK])
	verifier(
		await _jusqua(_achat_debite.bind(ea, cible, avant.argent - prix + 100)),
		"la vue suivante montre l'achat débité"
	)
	# B n'a rien payé et ne voit pas l'offre vendue de A.
	var vb := eb.dernier()
	verifier_faux(bool((vb.offres[cible] as Dictionary)["vendu"]), "B ne voit pas l'achat de A")
	verifier(vb.argent >= avant.argent - 1, "B n'est pas débité")
	# Même offre une seconde fois : déjà achetée.
	n = ea.resultats.size()
	a.acheter(cible)
	verifier_egal((await _resultat_apres(ea, n))[1], Types.Resultat.DEJA_ACHETE)
	# Hors bornes côté serveur.
	n = ea.resultats.size()
	a.acheter(99)
	verifier((await _resultat_apres(ea, n))[1] != Types.Resultat.OK, "indice 99 refusé")


func test_l_or_insuffisant_est_rapporte_avec_le_bon_code() -> void:
	var cs := await _partie_a_deux()
	var a: Client = cs[0]
	var ea: Espion = cs[2]
	var vu_insuffisant := false
	# Chaque relance coûte plus cher que la précédente : l'or finit par manquer.
	for i: int in 30:
		var n := ea.resultats.size()
		a.relancer()
		var r := await _resultat_apres(ea, n)
		verifier_egal(r[0], "relancer")
		if r[1] == Types.Resultat.OR_INSUFFISANT:
			vu_insuffisant = true
			break
		verifier_egal(r[1], Types.Resultat.OK)
	verifier(vu_insuffisant, "OR_INSUFFISANT reçu")


func test_observer_apres_la_mort_et_pas_avant() -> void:
	var cs := await _partie_a_deux()
	var a: Client = cs[0]
	var b: Client = cs[1]
	var eb: Espion = cs[3]
	var n := eb.resultats.size()
	b.observer(a.id_local())
	var r := await _resultat_apres(eb, n)
	verifier(r[1] != Types.Resultat.OK, "vivant : observation refusée")
	verifier_egal(b.cible_observee(), b.id_local(), "la cible n'a pas changé")
	# B tombe (côté serveur) : il peut maintenant regarder A, et ne plus rien acheter.
	serveur.partie.intention_quitter(b.id_local())
	n = eb.resultats.size()
	b.acheter(0)
	verifier_egal((await _resultat_apres(eb, n))[1], Types.Resultat.ARENE_MORTE)
	n = eb.resultats.size()
	b.observer(a.id_local())
	verifier_egal(await _resultat_apres(eb, n), ["observer", Types.Resultat.OK])
	verifier_egal(b.cible_observee(), a.id_local())
	var vues := eb.arenes.size()
	verifier(
		await _jusqua(func() -> bool: return eb.arenes.size() > vues + 2),
		"des vues de l'arène de A"
	)


func test_regarder_une_autre_arene_de_son_vivant_et_cesser() -> void:
	var cs := await _partie_a_deux()
	var a: Client = cs[0]
	var b: Client = cs[1]
	var ea: Espion = cs[2]
	var regardees: Array = []
	a.vue_regardee_recue.connect(func(id: int, v: VueArene) -> void: regardees.append([id, v]))
	verifier_egal(a.id_regarde(), -1)
	var n := ea.resultats.size()
	a.regarder(a.id_local())
	verifier_egal(ea.dernier_resultat(), ["regarder", Types.Resultat.INDICE_INVALIDE], "soi-même")
	verifier_egal(a.id_regarde(), -1)
	n = ea.resultats.size()
	a.regarder(b.id_local())
	verifier_egal(await _resultat_apres(ea, n), ["regarder", Types.Resultat.OK])
	verifier_egal(a.id_regarde(), b.id_local())
	verifier(
		await _jusqua(func() -> bool: return regardees.size() >= 3), "des vues de l'arène de B"
	)
	for r: Array in regardees:
		verifier_egal(r[0], b.id_local())
	var propres := ea.arenes.size()
	verifier(
		await _jusqua(func() -> bool: return ea.arenes.size() > propres + 2),
		"la sienne continue d'arriver"
	)
	n = ea.resultats.size()
	a.regarder(-1)
	verifier_egal(await _resultat_apres(ea, n), ["regarder", Types.Resultat.OK])
	verifier_egal(a.id_regarde(), -1)
	await attendre_images(20)
	var apres := regardees.size()
	await attendre_images(30)
	verifier_egal(regardees.size(), apres, "après -1, plus rien")


func test_un_etat_regarde_non_demande_ou_obsolete_est_ignore() -> void:
	var cs := await _partie_a_deux()
	var a: Client = cs[0]
	var b: Client = cs[1]
	var regardees: Array = []
	a.vue_regardee_recue.connect(func(id: int, v: VueArene) -> void: regardees.append([id, v]))
	var vue := VueArene.new()
	vue.tick = 50
	var octets := Protocole.encoder_etat_arene_regardee(b.id_local(), vue, d.ids_catalogue)
	verifier_faux(octets.is_empty())
	a.canal.etat_arene_regardee_recu.emit(octets)
	verifier_egal(regardees.size(), 0, "rien n'a été demandé")
	# Forgé à la main : un paquet tronqué ou du bruit ne lève rien.
	a.canal.etat_arene_regardee_recu.emit(octets.slice(0, 3))
	a.canal.etat_arene_regardee_recu.emit(PackedByteArray([Protocole.Msg.ETAT_ARENE_REGARDEE]))
	verifier(a.paquets_ignores >= 2)


func _a_des_densites(e: Espion) -> bool:
	for v: VueGlobale in e.globales:
		if not v.densites.is_empty():
			return true
	return false


func test_le_client_garde_les_dernieres_densites_entre_deux_envois() -> void:
	var cs := await _partie_a_deux()
	var a: Client = cs[0]
	var ea: Espion = cs[2]
	verifier(await _jusqua(func() -> bool: return _a_des_densites(ea)), "une carte arrive")
	var avant := ea.globales.size()
	verifier(
		await _jusqua(func() -> bool: return ea.globales.size() > avant + 2),
		"d'autres états globaux arrivent"
	)
	for i: int in range(ea.globales.size() - 3, ea.globales.size()):
		verifier_egal(ea.globales[i].densites.size(), 2, "les dernières cartes sont portées")


func test_quitter_deconnecte_proprement_sans_perte_signalee() -> void:
	var cs := await _partie_a_deux()
	var a: Client = cs[0]
	var b: Client = cs[1]
	var ea: Espion = cs[2]
	var eb: Espion = cs[3]
	var id_b := b.id_local()
	b.quitter_partie()
	verifier_faux(b.est_connecte())
	verifier(
		await _jusqua(func() -> bool: return serveur.joueur_de(id_b) == -1),
		"le serveur voit le départ"
	)
	await attendre_images(10)
	verifier_egal(eb.pertes.size(), 0, "partir n'est pas une perte")
	verifier_egal(ea.pertes.size(), 0)
	var tick := ea.dernier().tick
	verifier(
		await _jusqua(func() -> bool: return ea.dernier().tick > tick + 5), "A continue de jouer"
	)
	b.quitter_partie()
	verifier(a.est_connecte(), "un second quitter n'a aucun effet")


# --- Refus et perte --------------------------------------------------------------------------


func test_un_client_de_version_1_est_refuse_avec_son_motif() -> void:
	verifier(_monter_serveur())
	var c := _nouveau_client("V1")
	var e := _espionner(c)
	c.version_annoncee = 1
	verifier_egal(c.connecter("127.0.0.1", port, "Aki"), OK)
	verifier(await _jusqua(func() -> bool: return not e.pertes.is_empty()), "refus reçu")
	verifier_egal(e.pertes[0], Protocole.motif_version(1))
	await attendre_images(30)
	verifier_egal(e.pertes.size(), 1, "une seule perte, malgré la coupure qui suit")
	verifier_faux(c.est_connecte())


func test_des_donnees_differentes_sont_refusees_avec_un_motif_lisible() -> void:
	verifier(_monter_serveur())
	var autres := Donnees.charger()
	autres.empreinte = d.empreinte + 1
	var c := _nouveau_client("D", autres)
	var e := _espionner(c)
	c.connecter("127.0.0.1", port, "Aki")
	verifier(await _jusqua(func() -> bool: return not e.pertes.is_empty()), "refus reçu")
	verifier(e.pertes[0].contains("données"), "motif : %s" % e.pertes[0])
	await attendre_images(30)
	verifier_egal(e.pertes.size(), 1)


func test_un_salon_plein_est_refuse() -> void:
	verifier(_monter_serveur())
	for i: int in Salon.MAX_JOUEURS:
		var c := _nouveau_client("J%d" % i)
		c.connecter("127.0.0.1", port, "Joueur %d" % i)
	verifier(
		await _jusqua(func() -> bool: return serveur.salon.joueurs.size() == Salon.MAX_JOUEURS),
		"salon plein"
	)
	var trop := _nouveau_client("Trop")
	var e := _espionner(trop)
	trop.delai_connexion_s = 2.0
	trop.connecter("127.0.0.1", port, "Trop")
	verifier(await _jusqua(func() -> bool: return not e.pertes.is_empty()), "refus reçu")
	verifier_egal(e.pertes[0], "Le salon est plein (%d joueurs)." % Salon.MAX_JOUEURS)
	await attendre_images(30)
	verifier_egal(e.pertes.size(), 1)


## Serveur dédié après une partie : il rouvre son salon sans fermer les connexions. Un client qui
## attend sur l'écran de fin n'est pas coupé cinq secondes plus tard : il redit bonjour au salon
## neuf.
func test_un_salon_rouvert_re_enregistre_les_clients_au_lieu_de_les_couper() -> void:
	verifier(_monter_serveur(), "un port libre")
	var a := _nouveau_client("A")
	var ea := _espionner(a)
	verifier_egal(a.connecter("127.0.0.1", port, "Aki"), OK)
	verifier(await _jusqua(func() -> bool: return a.salon != null), "A reçoit le salon")
	var id := a.id_local()
	serveur.rouvrir_salon()
	# Quatorze secondes de serveur, par pas de 0,5 s, avec des images entre deux pour le réseau.
	for _i: int in 28:
		serveur.tick(0.5)
		for _k: int in 3:
			await arbre.process_frame
	verifier(ea.pertes.is_empty(), "aucune perte signalée : %s" % [ea.pertes])
	verifier_egal(serveur.nb_pairs(), 1, "le pair est toujours là")
	verifier(serveur.salon.joueurs.has(id), "et réenregistré dans le salon neuf")


func test_le_serveur_arrete_en_pleine_partie_donne_une_seule_perte() -> void:
	var cs := await _partie_a_deux()
	var a: Client = cs[0]
	var ea: Espion = cs[2]
	a.delai_silence_s = 1.5
	serveur.arreter()
	verifier(
		await _jusqua(func() -> bool: return not ea.pertes.is_empty()), "connexion_perdue émis"
	)
	verifier_egal(ea.pertes[0], "Connexion perdue")
	await attendre_images(90)
	verifier_egal(ea.pertes.size(), 1, "une seule fois")
	verifier_faux(a.est_connecte())


func test_le_silence_de_cinq_secondes_en_partie_est_une_perte() -> void:
	var cs := await _partie_a_deux()
	var a: Client = cs[0]
	var ea: Espion = cs[2]
	a.avancer_horloge(4.0)
	verifier_egal(ea.pertes.size(), 0, "4 s de silence : pas encore")
	a.avancer_horloge(1.5)
	verifier_egal(ea.pertes, ["Connexion perdue"] as Array[String])
	a.avancer_horloge(60.0)
	verifier_egal(ea.pertes.size(), 1)


# --- Octets injectés (sans socket) -----------------------------------------------------------


func _vue(tick: int) -> PackedByteArray:
	var p := AidesPartie.partie(d, 7, 1)
	AidesPartie.pas(p, 3)
	var v := p.vue_arene(1, 1)
	v.tick = tick
	return Protocole.encoder_etat_arene(v, d.ids_catalogue)


func test_seul_le_tick_le_plus_recent_compte_dans_le_desordre() -> void:
	var c := _nouveau_client("Nu")
	var e := _espionner(c)
	for t: int in [10, 12, 12, 11, 9, 13, 13, 5]:
		c._a_la_reception_arene(_vue(t))
	var ticks: Array[int] = []
	for v: VueArene in e.arenes:
		ticks.append(v.tick)
	verifier_egal(ticks, [10, 12, 13] as Array[int])


func test_la_vue_recue_egale_celle_encodee_a_la_quantification_pres() -> void:
	var c := _nouveau_client("Nu")
	var e := _espionner(c)
	var p := AidesPartie.partie(d, 7, 1)
	AidesPartie.pas(p, 200)
	var v := p.vue_arene(1, 1)
	c._a_la_reception_arene(Protocole.encoder_etat_arene(v, d.ids_catalogue))
	var recu := e.dernier()
	verifier_non_nul(recu)
	verifier_egal(recu.tick, v.tick)
	verifier_egal(recu.argent, v.argent)
	verifier_egal(recu.ennemis_id.size(), v.ennemis_id.size())
	var tolerance := 1.0 / 32.0 + 1e-4
	for i: int in v.ennemis_pos.size():
		verifier_proche(recu.ennemis_pos[i].x, v.ennemis_pos[i].x, tolerance, "x %d" % i)
		verifier_proche(recu.ennemis_pos[i].y, v.ennemis_pos[i].y, tolerance, "y %d" % i)


func test_les_paquets_malformes_ou_trop_gros_sont_ignores_et_comptes() -> void:
	var c := _nouveau_client("Nu")
	var e := _espionner(c)
	var bon := _vue(10)
	var tronque := bon.slice(0, bon.size() / 2)
	var bruit := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i: int in 300:
		bruit.append(rng.randi() % 256)
	var gros := PackedByteArray()
	gros.resize(Protocole.MAX_TAILLE + 1)
	gros[0] = Protocole.Msg.ETAT_ARENE
	var ignores := 0
	for mauvais: PackedByteArray in [PackedByteArray(), tronque, bruit, gros]:
		c._a_la_reception_arene(mauvais)
		c._a_la_reception_global(mauvais)
		c._a_la_reception_salon(mauvais)
		c._a_la_reception_resultat(mauvais)
		c._a_la_reception_refus(mauvais)
		ignores += 5
	# Un type valide dans le mauvais tuyau est ignoré aussi.
	c._a_la_reception_global(bon)
	ignores += 1
	verifier_egal(c.paquets_ignores, ignores)
	verifier_egal(e.arenes.size(), 0)
	verifier_egal(e.globales.size(), 0)
	verifier_egal(e.resultats.size(), 0)
	verifier_egal(e.pertes.size(), 0)
	c._a_la_reception_arene(bon)
	verifier_egal(e.arenes.size(), 1, "le client reste utilisable")


func test_un_etat_global_valide_est_relaye() -> void:
	var c := _nouveau_client("Nu")
	var e := _espionner(c)
	var p := AidesPartie.partie(d, 7, 2)
	c._a_la_reception_global(Protocole.encoder_etat_global(p.vue_globale()))
	verifier_egal(e.globales.size(), 1)
	verifier_egal(e.globales[0].joueurs.size(), 2)


func test_un_resultat_valide_est_relaye_pour_chaque_genre_et_code() -> void:
	var c := _nouveau_client("Nu")
	var e := _espionner(c)
	var attendus := 0
	for g: int in range(Protocole.Intention.ACHETER, Protocole.Intention.OPTIONS + 1):
		if g == Protocole.Intention.VENDRE_RETIREE:
			continue
		for k: int in range(Types.Resultat.OK, Types.Resultat.NON_DISPONIBLE + 1):
			c._a_la_reception_resultat(Protocole.encoder_resultat(g, k))
			attendus += 1
			verifier_egal(e.resultats.size(), attendus)
			verifier_egal(e.dernier_resultat()[1], k)
			verifier(not String(e.dernier_resultat()[0]).is_empty())


func test_un_resultat_du_genre_de_vente_retire_n_est_pas_relaye() -> void:
	var c := _nouveau_client("Nu")
	var e := _espionner(c)
	for k: int in range(Types.Resultat.OK, Types.Resultat.NON_DISPONIBLE + 1):
		c._a_la_reception_resultat(
			Protocole.encoder_resultat(Protocole.Intention.VENDRE_RETIREE, k)
		)
	verifier_egal(e.resultats.size(), 0, "le numéro 3 est réservé et refusé")


# --- Jeton d'hôte ------------------------------------------------------------------------------


func test_avec_jeton_le_client_local_est_hote_meme_si_un_autre_arrive_avant() -> void:
	verifier(_monter_serveur(), "un port libre")
	var jeton := PackedByteArray([21, 22, 23, 24, 25, 26, 27, 28])
	serveur.jeton_hote = jeton
	serveur.preparer(d)
	var autre := _nouveau_client("Autre")
	var local := _nouveau_client("Local")
	verifier_egal(autre.connecter("127.0.0.1", port, "Bo"), OK)
	verifier(
		await _jusqua(func() -> bool: return autre.salon != null or serveur.nb_pairs() == 1),
		"l'autre est connecté"
	)
	await _jusqua(func() -> bool: return serveur.salon.joueurs.size() == 1)
	verifier_egal(serveur.salon.hote, -1, "personne n'est hôte avant le client local")
	verifier_egal(local.connecter("127.0.0.1", port, "Aki", jeton), OK)
	verifier(
		await _jusqua(func() -> bool: return local.salon != null and local.salon.hote != -1),
		"le client local reçoit le salon avec un hôte"
	)
	verifier(local.est_hote(), "le client local est l'hôte")
	verifier(
		await _jusqua(
			func() -> bool: return autre.salon != null and autre.salon.joueurs.size() == 2
		),
		"l'autre voit le salon à deux"
	)
	verifier_faux(autre.est_hote(), "l'autre n'est pas hôte")


func test_un_client_au_mauvais_jeton_n_est_pas_hote() -> void:
	verifier(_monter_serveur(), "un port libre")
	serveur.jeton_hote = PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1])
	serveur.preparer(d)
	var c := _nouveau_client("C")
	verifier_egal(
		c.connecter("127.0.0.1", port, "Aki", PackedByteArray([2, 2, 2, 2, 2, 2, 2, 2])), OK
	)
	await _jusqua(func() -> bool: return serveur.salon.joueurs.size() == 1)
	verifier_egal(serveur.salon.hote, -1)
	verifier_faux(c.est_hote())


func test_un_bilan_valide_est_relaye_et_garde_et_un_bilan_malforme_est_ignore() -> void:
	var c := _nouveau_client("Nu")
	var recus: Array[Dictionary] = []
	c.bilan_recu.connect(func(b: Dictionary) -> void: recus.append(b))
	verifier_egal(c.bilan(), {}, "pas de bilan avant la fin")
	var bilan := BilanPartie.new()
	bilan.soin(42.0)
	c._a_la_reception_bilan(Protocole.encoder_bilan(bilan.a_dict()))
	verifier_egal(recus.size(), 1)
	verifier_egal(recus[0]["pv_soignes"], 42.0)
	verifier_egal(c.bilan(), recus[0], "le dernier bilan est gardé")
	var avant := c.paquets_ignores
	var bruit := PackedByteArray([Protocole.Msg.BILAN, 0, 0])
	for mauvais: PackedByteArray in [
		PackedByteArray(), bruit, Protocole.encoder_etat_global(_globale_vide())
	]:
		c._a_la_reception_bilan(mauvais)
	verifier_egal(recus.size(), 1, "aucun bilan de plus")
	verifier_egal(c.paquets_ignores, avant + 3)
	verifier_egal(c.bilan()["pv_soignes"], 42.0, "le bilan gardé n'est pas écrasé")


func _globale_vide() -> VueGlobale:
	return AidesPartie.partie(d, 7, 1).vue_globale()
