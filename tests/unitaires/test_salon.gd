extends CasDeTest
## Ce que le salon doit garantir : au plus huit joueurs aux noms lisibles et distincts, un hôte seul
## maître des options et du lancement, et un refus avec motif (jamais une exception) pour tout ce
## qui arrive hors de propos : pair inconnu, message après le lancement, octets de bruit.

const NOM_24 := "Ælfwyn Müller-Østerga日本語"


func _salon_de(n: int) -> Salon:
	var s := Salon.new()
	for i: int in range(1, n + 1):
		verifier(s.ajouter(i, "Joueur %d" % (i + 10)), "ajout du joueur %d" % i)
	return s


# --- Admission -------------------------------------------------------------------------------


func test_un_a_huit_joueurs_sont_admis_et_le_neuvieme_refuse() -> void:
	for n: int in range(1, Salon.MAX_JOUEURS + 1):
		var s := _salon_de(n)
		verifier_egal(s.joueurs.size(), n)
		if n == Salon.MAX_JOUEURS:
			verifier_faux(s.ajouter(100, "Trop"), "le neuvième joueur")
			verifier_egal(s.joueurs.size(), Salon.MAX_JOUEURS)
			verifier(s.motif_refus.contains("plein"), "motif : %s" % s.motif_refus)


func test_le_premier_arrive_est_l_hote() -> void:
	var s := _salon_de(3)
	verifier_egal(s.hote, 1)


func test_un_pair_deja_present_est_refuse_sans_toucher_a_son_etat() -> void:
	var s := _salon_de(2)
	s.marquer_pret(2, true)
	verifier_faux(s.ajouter(2, "Intrus"), "reconnexion du même pair")
	verifier(not s.motif_refus.is_empty(), "un motif est donné")
	verifier_egal(s.joueurs[2]["nom"], "Joueur 12")
	verifier_egal(s.joueurs[2]["pret"], true)
	verifier_egal(s.joueurs.size(), 2)


func test_un_nom_vide_donne_joueur_n_et_aucun_doublon() -> void:
	var s := Salon.new()
	for i: int in range(1, 9):
		var vide := "" if i % 2 == 0 else "   "
		verifier(s.ajouter(i, vide))
	var vus: Dictionary = {}
	for id: int in s.joueurs:
		var nom: String = s.joueurs[id]["nom"]
		verifier(nom.begins_with("Joueur "), "nom par défaut : %s" % nom)
		verifier_faux(vus.has(nom.to_lower()), "doublon %s" % nom)
		vus[nom.to_lower()] = true


func test_deux_connexions_de_meme_nom_sont_distinguees() -> void:
	var s := Salon.new()
	verifier(s.ajouter(1, "Marie"))
	verifier(s.ajouter(2, "Marie"))
	verifier(s.ajouter(3, "marie"), "la casse ne distingue pas deux noms")
	var uniques: Dictionary = {}
	for id: int in s.joueurs:
		uniques[String(s.joueurs[id]["nom"]).to_lower()] = true
	verifier_egal(uniques.size(), 3, "trois noms distincts")
	verifier_egal(s.joueurs[1]["nom"], "Marie", "le premier garde son nom")


func test_un_nom_a_la_limite_reste_dans_la_limite_apres_suffixe() -> void:
	var s := Salon.new()
	verifier_egal(NOM_24.length(), Salon.MAX_NOM)
	for i: int in range(1, 9):
		verifier(s.ajouter(i, NOM_24))
	var uniques: Dictionary = {}
	for id: int in s.joueurs:
		var nom: String = s.joueurs[id]["nom"]
		verifier(nom.length() <= Salon.MAX_NOM, "longueur de %s" % nom)
		uniques[nom] = true
	verifier_egal(uniques.size(), 8, "huit noms distincts")
	verifier_egal(s.joueurs[1]["nom"], NOM_24, "Unicode conservé")


func test_les_noms_unicode_sont_conserves() -> void:
	var s := Salon.new()
	for nom: String in ["Éloïse Dupont", "Zoë Ø", "日本語の名前", "O’Brien"]:
		var id := s.joueurs.size() + 1
		verifier(s.ajouter(id, nom), nom)
		verifier_egal(s.joueurs[id]["nom"], nom)


func test_un_nom_trop_long_ou_a_caracteres_de_controle_est_refuse() -> void:
	var s := Salon.new()
	verifier_faux(s.ajouter(1, "x".repeat(Salon.MAX_NOM + 1)), "25 caractères")
	verifier(s.motif_refus.contains("long"), s.motif_refus)
	for c: int in [0, 1, 9, 10, 13, 27, 127]:
		verifier_faux(s.ajouter(1, "Ma" + char(c) + "rie"), "contrôle %d" % c)
		verifier(not s.motif_refus.is_empty())
	verifier_egal(s.joueurs.size(), 0, "aucun joueur n'est entré")


func test_un_id_invalide_est_refuse() -> void:
	var s := Salon.new()
	verifier_faux(s.ajouter(0, "Zéro"))
	verifier_faux(s.ajouter(-5, "Négatif"))


# --- Départs et « prêt » -----------------------------------------------------------------------


func test_retirer_un_absent_ou_deux_fois_ne_change_rien() -> void:
	var s := _salon_de(3)
	verifier(s.retirer(2))
	verifier_faux(s.retirer(2), "départ en double")
	verifier(not s.motif_refus.is_empty())
	verifier_faux(s.retirer(99), "jamais présent")
	verifier_egal(s.joueurs.size(), 2)


func test_pret_d_un_inconnu_est_refuse() -> void:
	var s := _salon_de(2)
	verifier_faux(s.marquer_pret(99, true))
	verifier(not s.motif_refus.is_empty())
	verifier_egal(s.joueurs.size(), 2, "aucun joueur fantôme créé")
	verifier_faux(s.peut_demarrer(), "personne n'est prêt")


func test_l_hote_qui_part_laisse_la_main_au_plus_ancien() -> void:
	var s := _salon_de(3)
	s.retirer(1)
	verifier_egal(s.hote, 2)
	verifier_faux(s.regler(1, 1, 0.5, 0, false), "l'ancien hôte n'a plus la main")
	verifier(s.regler(2, 2, 0.5, 0, false), "le nouvel hôte règle")
	s.retirer(2)
	s.retirer(3)
	verifier_egal(s.hote, -1, "salon vide, plus d'hôte")
	verifier(s.ajouter(7, "Nouveau"))
	verifier_egal(s.hote, 7, "le suivant devient hôte")


func test_l_hote_parti_ne_lance_plus_et_le_nouvel_hote_lance() -> void:
	var s := _salon_de(2)
	s.marquer_pret(1, true)
	s.marquer_pret(2, true)
	s.retirer(1)
	verifier_faux(s.demarrer(1), "l'hôte parti ne lance pas")
	verifier(s.demarrer(2), "le nouvel hôte lance")


# --- Options et lancement ------------------------------------------------------------------------


func test_seul_l_hote_regle_les_options() -> void:
	var s := _salon_de(3)
	verifier_faux(s.regler(2, 2, 0.5, 5, true), "un autre joueur")
	verifier(s.motif_refus.contains("hôte"), s.motif_refus)
	verifier_faux(s.regler(99, 99, 0.5, 5, true), "un pair inconnu")
	verifier_faux(s.regler(2, 1, 0.5, 5, true), "usurpation de l'id de l'hôte")
	verifier_proche(s.vitesse, 1.0, 0.0001)
	verifier(s.regler(1, 1, 0.66, 12345, true))
	verifier_proche(s.vitesse, 0.66, 0.0001)
	verifier_egal(s.graine, 12345)
	verifier(s.graine_fixe)


func test_vitesse_hors_des_trois_valeurs_est_refusee() -> void:
	var s := _salon_de(1)
	for v: float in [0.0, -1.0, 0.7, 0.65, 2.0, 1.01, NAN, INF, -INF]:
		verifier_faux(s.regler(1, 1, v, 0, false), "vitesse %s" % str(v))
		verifier_proche(s.vitesse, 1.0, 0.0001, "inchangée")
	for v: float in [1.0, 0.66, 0.5]:
		verifier(s.regler(1, 1, v, 0, false), "vitesse %s" % str(v))
		verifier_proche(s.vitesse, v, 0.0001)


func test_une_graine_negative_est_refusee_et_aleatoire_ignore_la_graine() -> void:
	var s := _salon_de(1)
	verifier_faux(s.regler(1, 1, 1.0, -1, true))
	verifier(s.regler(1, 1, 1.0, 777, false))
	verifier_faux(s.graine_fixe)
	verifier_egal(s.graine, 0, "graine aléatoire : aucune valeur retenue")
	verifier(s.regler(1, 1, 1.0, 777, true))
	verifier_egal(s.graine_de_partie(), 777)


func test_peut_demarrer_selon_les_joueurs_presents() -> void:
	var vide := Salon.new()
	verifier_faux(vide.peut_demarrer(), "aucun joueur")
	for n: int in range(1, Salon.MAX_JOUEURS + 1):
		var t := _salon_de(n)
		for id: int in range(1, n + 1):
			verifier_faux(t.peut_demarrer(), "pas tous prêts (%d sur %d)" % [id - 1, n])
			t.marquer_pret(id, true)
		verifier(t.peut_demarrer(), "tous prêts, %d joueurs" % n)
		t.marquer_pret(1, false)
		verifier_faux(t.peut_demarrer(), "un joueur se dit non prêt")


func test_un_joueur_qui_part_peut_debloquer_le_lancement() -> void:
	var s := _salon_de(2)
	s.marquer_pret(1, true)
	verifier_faux(s.peut_demarrer())
	s.retirer(2)
	verifier(s.peut_demarrer(), "il ne reste que des joueurs prêts")


func test_seul_l_hote_lance_et_seulement_si_tous_sont_prets() -> void:
	var s := _salon_de(2)
	verifier_faux(s.demarrer(1), "personne prêt")
	s.marquer_pret(1, true)
	s.marquer_pret(2, true)
	verifier_faux(s.demarrer(2), "un non-hôte")
	verifier_faux(s.demarrer(99), "un inconnu")
	verifier_faux(s.lancee)
	verifier(s.demarrer(1))
	verifier(s.lancee)


func test_apres_le_lancement_tout_message_du_salon_est_refuse() -> void:
	var s := _salon_de(2)
	s.marquer_pret(1, true)
	s.marquer_pret(2, true)
	s.demarrer(1)
	verifier_faux(s.demarrer(1), "second lancement")
	verifier(s.motif_refus.contains("commencé"), s.motif_refus)
	verifier_faux(s.ajouter(3, "Retard"), "arrivée tardive")
	verifier(s.motif_refus.contains("commencé"), s.motif_refus)
	verifier_faux(s.marquer_pret(1, false), "prêt tardif")
	verifier_faux(s.regler(1, 1, 0.5, 1, true), "options tardives")
	verifier_egal(s.joueurs.size(), 2)
	verifier_egal(s.joueurs[1]["pret"], true, "le « prêt » ne bouge plus")
	verifier_proche(s.vitesse, 1.0, 0.0001)
	verifier_faux(s.retirer(2), "la présence est ensuite l'affaire de la partie")
	verifier_egal(s.joueurs.size(), 2)


# --- Sérialisation ---------------------------------------------------------------------------------


func _egaux(a: Salon, b: Salon) -> bool:
	return (
		a.joueurs == b.joueurs
		and absf(a.vitesse - b.vitesse) < 0.0001
		and a.graine == b.graine
		and a.graine_fixe == b.graine_fixe
		and a.hote == b.hote
		and a.lancee == b.lancee
	)


func test_aller_retour_pour_chaque_effectif_et_chaque_vitesse() -> void:
	for n: int in range(0, Salon.MAX_JOUEURS + 1):
		for v: float in [1.0, 0.66, 0.5]:
			var s := _salon_de(n)
			if n > 0:
				s.marquer_pret(1, true)
				s.regler(1, 1, v, 987654321012, true)
			var r := Salon.depuis_octets(s.vers_octets())
			verifier_non_nul(r, "décodage n=%d v=%s" % [n, str(v)])
			if r != null:
				verifier(_egaux(s, r), "égalité n=%d v=%s" % [n, str(v)])


func test_aller_retour_des_noms_unicode_et_de_l_etat_lance() -> void:
	var s := Salon.new()
	s.ajouter(4, NOM_24)
	s.ajouter(9, "日本 語")
	s.marquer_pret(4, true)
	s.marquer_pret(9, true)
	s.demarrer(4)
	var r := Salon.depuis_octets(s.vers_octets())
	verifier_non_nul(r)
	if r != null:
		verifier(_egaux(s, r))
		verifier(r.lancee)


func test_decodage_defensif_tronque_et_bruit() -> void:
	var s := _salon_de(5)
	s.marquer_pret(3, true)
	var b := s.vers_octets()
	for taille: int in b.size():
		verifier_nul(Salon.depuis_octets(b.slice(0, taille)), "tronqué à %d" % taille)
	var long := b.duplicate()
	long.append(0)
	verifier_nul(Salon.depuis_octets(long), "octet en trop")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i: int in 300:
		var bruit := PackedByteArray()
		bruit.resize(rng.randi_range(1, 120))
		for k: int in bruit.size():
			bruit[k] = rng.randi() & 0xFF
		var r := Salon.depuis_octets(bruit)
		verifier(r == null or r.joueurs.size() <= Salon.MAX_JOUEURS, "bruit %d" % i)


func test_un_octet_corrompu_donne_un_refus_ou_un_salon_valide() -> void:
	var s := _salon_de(3)
	var b := s.vers_octets()
	for k: int in b.size():
		var m := b.duplicate()
		m[k] = 0xFF
		var r := Salon.depuis_octets(m)
		if r == null:
			verifier(true)
			continue
		verifier(r.joueurs.size() <= Salon.MAX_JOUEURS)
		verifier(r.joueurs.is_empty() or r.joueurs.has(r.hote), "hôte parmi les joueurs, k=%d" % k)
		var ok := false
		for v: float in [1.0, 0.66, 0.5]:
			ok = ok or absf(r.vitesse - v) < 0.0001
		verifier(ok, "vitesse valide, k=%d" % k)
