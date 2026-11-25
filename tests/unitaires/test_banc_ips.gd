extends CasDeTest
## Banc d'essai à N ennemis (T5.1b) : ligne de commande, ennemis visibles, résumé, sortie.

const NBSP := " "
const SCENE_BANC := "res://scenes/banc_ips.tscn"

var _banc: BancIps = null
var _principal: Principal = null
var _donnees: Donnees = null
var _codes: Array[int] = []


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func apres_chaque() -> void:
	for noeud: Node in [_banc, _principal]:
		if noeud != null and is_instance_valid(noeud):
			if noeud.get_parent() != null:
				noeud.get_parent().remove_child(noeud)
			noeud.free()
	_banc = null
	_principal = null


func _lire(args: Array[String]) -> Dictionary:
	return Arguments.lire(PackedStringArray(args))


## `manuel` coupe l'horloge propre du banc : le test la mène lui-même par `avancer`.
func _banc_avec(nombre: int, duree: float = BancIps.DUREE_S, manuel: bool = false) -> BancIps:
	_banc = (load(SCENE_BANC) as PackedScene).instantiate() as BancIps
	_banc.duree = duree
	arbre.root.add_child(_banc)
	_banc.set_process(not manuel)
	verifier(_banc.lancer(_donnees, nombre), "le banc démarre")
	return _banc


func _touche(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


# --- Ligne de commande --------------------------------------------------------------------------


func test_sans_option_le_banc_est_eteint() -> void:
	var r := _lire([])
	verifier_egal(r["banc_ips"], 0)
	verifier_egal((r["messages"] as Array).size(), 0)


func test_l_option_seule_lance_le_banc_a_mille_ennemis() -> void:
	var r := _lire(["--banc-ips"])
	verifier_egal(r["banc_ips"], 1000)
	verifier_egal((r["messages"] as Array).size(), 0)


func test_l_option_lit_le_nombre_separe_ou_avec_egal() -> void:
	for n: int in [1, 2, 8, 999, 1000, 1234, 4999, 5000]:
		var separe := _lire(["--banc-ips", str(n)])
		verifier_egal(separe["banc_ips"], n, "séparé %d" % n)
		verifier_egal((separe["messages"] as Array).size(), 0, "aucun message pour %d" % n)
		var egal := _lire(["--banc-ips=%d" % n])
		verifier_egal(egal["banc_ips"], n, "avec égal %d" % n)


func test_le_nombre_est_borne_entre_1_et_5000_avec_un_message() -> void:
	var cas := {"0": 1, "-3": 1, "5001": 5000, "99999": 5000, "100000000000": 5000}
	for texte: String in cas:
		var r := _lire(["--banc-ips", texte])
		verifier_egal(r["banc_ips"], int(cas[texte]), "valeur %s" % texte)
		verifier_egal((r["messages"] as Array).size(), 1, "un message pour %s" % texte)


func test_un_nombre_illisible_donne_mille_et_un_message() -> void:
	for texte: String in ["abc", "12x", "1.5", "", "٣"]:
		var r := _lire(["--banc-ips=" + texte])
		verifier_egal(r["banc_ips"], 1000, "valeur « %s »" % texte)
		verifier_egal((r["messages"] as Array).size(), 1, "un message pour « %s »" % texte)


func test_l_option_suivie_d_une_autre_option_ne_la_mange_pas() -> void:
	var r := _lire(["--banc-ips", "--graine", "5"])
	verifier_egal(r["banc_ips"], 1000)
	verifier_egal(r["graine"], 5, "l'option suivante garde sa valeur")
	verifier_egal((r["messages"] as Array).size(), 0)


func test_les_autres_options_ne_changent_pas() -> void:
	var r := _lire(["--port", "8000", "--banc-ips", "300", "--vitesse", "0.5"])
	verifier_egal(r["banc_ips"], 300)
	verifier_egal(r["port"], 8000)
	verifier_egal(r["vitesse"], 0.5)


func test_la_ligne_de_commande_du_serveur_laisse_passer_l_option() -> void:
	var r := ServeurDedie.lire_options(PackedStringArray(["--banc-ips", "250"]))
	verifier_egal(r["banc_ips"], 250)


func test_la_scene_de_demarrage_aiguille_vers_le_banc() -> void:
	verifier_egal(Principal.scene_de_demarrage({"banc_ips": 1000}), Principal.SCENE_BANC)
	verifier_egal(Principal.scene_de_demarrage({"banc_ips": 0}), "")
	verifier_egal(
		Principal.scene_de_demarrage({"banc_ips": 1000, "serveur": true}), Principal.SCENE_SERVEUR
	)


# --- Le banc ------------------------------------------------------------------------------------


func test_le_banc_montre_exactement_n_ennemis() -> void:
	for n: int in [1, 8, 9, 300, 1000]:
		var banc := _banc_avec(n)
		await attendre_images(3)
		verifier_egal(CompteurIps.ennemis_visibles(banc.arene), n, "%d ennemis visibles" % n)
		arbre.root.remove_child(banc)
		banc.free()
		_banc = null


func test_le_banc_utilise_les_huit_familles() -> void:
	var banc := _banc_avec(1000)
	await attendre_images(3)
	var familles := 0
	for f: int in _donnees.familles.size():
		if banc.arene.nombre_instances_visibles(f) > 0:
			familles += 1
	verifier_egal(familles, _donnees.familles.size(), "toutes les familles sont présentes")
	verifier_egal(_donnees.familles.size(), 8)


func test_les_ennemis_avancent_vers_la_tour() -> void:
	var banc := _banc_avec(50, BancIps.DUREE_S, true)
	await attendre_images(3)
	var avant := _distance_moyenne(banc)
	for i: int in 40:
		banc.avancer(0.05, 60.0)
	await attendre_images(3)
	verifier(_distance_moyenne(banc) < avant - 5.0, "les ennemis se rapprochent de la tour")


func _distance_moyenne(banc: BancIps) -> float:
	var somme := 0.0
	var compte := 0
	for f: int in _donnees.familles.size():
		for i: int in banc.arene.nombre_instances_visibles(f):
			somme += banc.arene.position_instance(f, i).length()
			compte += 1
	return somme / float(maxi(1, compte))


func _dispersion(rayons: PackedFloat32Array) -> float:
	var somme := 0.0
	for r: float in rayons:
		somme += r
	var moyenne := somme / float(rayons.size())
	var variance := 0.0
	for r: float in rayons:
		variance += (r - moyenne) * (r - moyenne)
	return sqrt(variance / float(rayons.size()))


func test_apres_trente_secondes_les_ennemis_restent_repartis() -> void:
	var banc := _banc_avec(1000, 1000.0, true)
	var depart := banc.rayons_courants()
	var dispersion_depart := _dispersion(depart)
	for i: int in 600:
		banc.avancer(0.05, 60.0)
	var rayons := banc.rayons_courants()
	verifier_egal(rayons.size(), 1000)
	var proches := 0
	for r: float in rayons:
		verifier(
			r >= BancIps.RAYON_ARRET - 0.001 and r <= BancIps.RAYON_MAX + 0.001, "rayon %s" % r
		)
		if r < 150.0:
			proches += 1
	verifier(proches < 100, "%d ennemis sur 1000 à moins de 150 unités de la tour" % proches)
	verifier(
		_dispersion(rayons) > 0.7 * dispersion_depart,
		"dispersion %s contre %s au départ" % [_dispersion(rayons), dispersion_depart]
	)


func test_un_ennemi_arrive_reapparait_sur_le_cercle_avec_un_autre_angle() -> void:
	var banc := _banc_avec(200, 1000.0, true)
	var angles_depart := banc.angles_courants()
	var vus_au_bord := 0
	for i: int in 700:
		banc.avancer(0.05, 60.0)
	var angles := banc.angles_courants()
	var rayons := banc.rayons_courants()
	for i: int in rayons.size():
		if rayons[i] > BancIps.RAYON_MAX - 100.0:
			vus_au_bord += 1
	verifier(vus_au_bord > 0, "des ennemis sont repartis du cercle d'apparition")
	var changes := 0
	for i: int in angles.size():
		if absf(angles[i] - angles_depart[i]) > 0.5:
			changes += 1
	verifier(changes > 0, "les ennemis réapparus ont un angle neuf")


func test_le_banc_n_ouvre_aucune_partie_ni_reseau() -> void:
	var banc := _banc_avec(10)
	for noeud: Node in banc.find_children("*", "", true, false):
		verifier(not (noeud is SourceLocale), "aucune partie locale : %s" % noeud.name)
		verifier(not (noeud is SessionReseau), "aucune session réseau : %s" % noeud.name)
		verifier(not (noeud is Serveur), "aucun serveur : %s" % noeud.name)
	verifier(not (banc.multiplayer.multiplayer_peer is ENetMultiplayerPeer), "aucun pair ENet")


func test_le_resume_apparait_apres_la_duree_et_une_seule_fois() -> void:
	var banc := _banc_avec(100, 10.0, true)
	await attendre_images(3)
	var resumes: Array[Dictionary] = []
	banc.termine.connect(func(r: Dictionary) -> void: resumes.append(r))
	verifier_faux(banc.resume_visible(), "pas de résumé pendant la mesure")
	for i: int in 190:
		banc.avancer(0.05, 60.0)
	verifier_faux(banc.resume_visible(), "9,5 s : encore en cours")
	for i: int in 30:
		banc.avancer(0.05, 60.0)
	verifier(banc.resume_visible(), "10 s écoulées : le résumé est là")
	verifier_egal(resumes.size(), 1, "le résumé est annoncé une fois")
	for i: int in 40:
		banc.avancer(0.05, 60.0)
	verifier_egal(resumes.size(), 1, "pas de second résumé")
	verifier_egal(resumes[0]["ennemis"], 100)


func test_le_resume_donne_la_moyenne_et_le_minimum_apres_la_chauffe() -> void:
	var banc := _banc_avec(100, 10.0, true)
	await attendre_images(3)
	var resumes: Array[Dictionary] = []
	banc.termine.connect(func(r: Dictionary) -> void: resumes.append(r))
	# Les 2 premières secondes (chauffe) tombent à 5 : elles ne comptent pas.
	for i: int in 200:
		var t := float(i) * 0.05
		var ips := 5.0 if t < BancIps.CHAUFFE_S - 0.1 else (40.0 if absf(t - 6.0) < 0.2 else 60.0)
		banc.avancer(0.05, ips)
	verifier_egal(resumes.size(), 1)
	var r := resumes[0]
	verifier_proche(float(r["minimum"]), 40.0, 0.001, "minimum")
	verifier(float(r["moyenne"]) > 58.0 and float(r["moyenne"]) < 60.0, "moyenne %s" % r["moyenne"])
	var texte := banc.texte_resume()
	verifier(texte.contains("100"), texte)
	verifier(texte.contains("40"), texte)
	verifier(texte.contains(NBSP + ":"), "typographie : " + texte)


func test_echap_demande_a_quitter() -> void:
	var banc := _banc_avec(10)
	var demandes: Array[int] = []
	banc.quitter_demande.connect(func() -> void: demandes.append(1))
	Input.parse_input_event(_touche(KEY_ESCAPE))
	await attendre_images(2)
	verifier_egal(demandes.size(), 1)


# --- Dans Principal -----------------------------------------------------------------------------


func _principal_avec(args: PackedStringArray) -> Principal:
	_codes = []
	var p := (load("res://scenes/principal.tscn") as PackedScene).instantiate() as Principal
	p.arguments = ServeurDedie.lire_options(args)
	p.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	p.sortie = func(code: int) -> void: _codes.append(code)
	arbre.root.add_child(p)
	_principal = p
	return p


func test_principal_ouvre_le_banc_a_la_place_du_menu_avec_le_compteur_visible() -> void:
	var p := _principal_avec(PackedStringArray(["--banc-ips", "120"]))
	await attendre_images(3)
	verifier_nul(p.menu(), "pas de menu")
	verifier_non_nul(p.banc(), "banc ouvert")
	verifier(p.compteur().visible, "compteur affiché d'office")
	verifier_egal(p.compteur().fournisseur_ennemis.call(), 120)


func test_echap_dans_le_banc_ferme_le_processus() -> void:
	var p := _principal_avec(PackedStringArray(["--banc-ips", "10"]))
	await attendre_images(2)
	Input.parse_input_event(_touche(KEY_ESCAPE))
	await attendre_images(2)
	verifier_egal(_codes, [0] as Array[int])
	verifier_non_nul(p)


func test_le_compteur_de_principal_suit_le_reglage_sans_perdre_f3() -> void:
	var p := _principal_avec(PackedStringArray())
	await attendre_images(2)
	verifier_faux(p.compteur().visible, "masqué par défaut")
	p.compteur()._unhandled_input(_touche(KEY_F3))
	verifier(p.compteur().visible, "F3 affiche pour la séance")
	var r := Reglages.new()
	r.volume_general = 0.5
	p.menu().reglages_modifies.emit(r)
	verifier(p.compteur().visible, "un autre réglage ne défait pas F3")
	r.afficher_ips = true
	p.menu().reglages_modifies.emit(r)
	verifier(p.compteur().visible, "la case cochée affiche")
	r.afficher_ips = false
	p.menu().reglages_modifies.emit(r)
	verifier_faux(p.compteur().visible, "la case décochée masque")


func test_le_reglage_enregistre_affiche_le_compteur_au_demarrage() -> void:
	var chemin := dossier_temporaire().path_join("reglages.cfg")
	var r := Reglages.new()
	r.afficher_ips = true
	verifier(r.sauver(chemin))
	var p := _principal_avec(PackedStringArray())
	await attendre_images(2)
	verifier(p.compteur().visible)
