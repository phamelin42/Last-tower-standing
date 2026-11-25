extends CasDeTest
## Ce que la joueuse lit et peut faire avant la partie : la liste des salons, la saisie de
## l'adresse et du port, le salon avec ses joueurs « prêts » en texte, et les réglages de l'hôte.

const CSV := "res://i18n/textes_salon.csv"
const SOURCES: Array[String] = ["res://ui/salon_ui.gd", "res://ui/connexion_ui.gd"]
const HAUTEUR_MIN := 48.0
const TAILLE_MIN := 16
const NOM_LONG := "Nom de salon long de 24c"

var _salon_ui: SalonUi
var _connexion: ConnexionUi
var _locale_avant: String = "en"


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	_salon_ui = (load("res://scenes/salon.tscn") as PackedScene).instantiate() as SalonUi
	_connexion = (load("res://scenes/connexion.tscn") as PackedScene).instantiate() as ConnexionUi
	arbre.root.add_child(_salon_ui)
	arbre.root.add_child(_connexion)


func apres_chaque() -> void:
	for noeud: Node in [_salon_ui, _connexion]:
		if is_instance_valid(noeud):
			noeud.get_parent().remove_child(noeud)
			noeud.free()
	TranslationServer.set_locale(_locale_avant)


func _t(cle: String) -> String:
	return TranslationServer.translate(cle)


func _salon_de(n: int) -> Salon:
	var s := Salon.new()
	for i: int in n:
		s.ajouter(i + 1, "Joueuse %d" % (i + 1))
	return s


# --- Salon -------------------------------------------------------------------------------------


func test_de_un_a_huit_joueurs_chacun_est_liste_avec_son_etat_en_texte() -> void:
	for n: int in range(1, Salon.MAX_JOUEURS + 1):
		var s := _salon_de(n)
		if n >= 2:
			s.marquer_pret(2, true)
		_salon_ui.afficher(s, 1)
		var lignes := _salon_ui.lignes_joueurs()
		verifier_egal(lignes.size(), n, "%d joueurs" % n)
		verifier(lignes[0].contains(_t("SALON_HOTE")), "l'hôte est nommé : %s" % lignes[0])
		verifier(lignes[0].contains(_t("SALON_VOUS")), "on se reconnaît : %s" % lignes[0])
		if n >= 2:
			verifier(lignes[1].contains(_t("SALON_PRET")), "prêt en texte : %s" % lignes[1])
			verifier_faux(lignes[1].contains(_t("SALON_PAS_PRET")))
		for i: int in range(2, n):
			verifier(lignes[i].contains(_t("SALON_PAS_PRET")), "pas prêt en texte : %s" % lignes[i])


func test_un_joueur_n_a_ni_lancer_ni_reglage_de_vitesse_actif() -> void:
	var s := _salon_de(3)
	_salon_ui.afficher(s, 2)
	verifier_faux(_salon_ui.est_hote())
	verifier_faux(_salon_ui.bouton_lancer.visible, "pas de bouton Lancer")
	verifier(_salon_ui.bouton_pret.visible, "le bouton Prêt est là")
	for b: Button in _salon_ui.boutons_vitesse:
		verifier(b.disabled, "réglage %s désactivé" % b.text)
		verifier_faux(b.get_parent_control().visible, "réglage masqué")


func test_l_hote_regle_la_vitesse_parmi_x1_x2_x4_en_boucle() -> void:
	var s := _salon_de(2)
	_salon_ui.afficher(s, 1)
	verifier(_salon_ui.est_hote())
	var textes := PackedStringArray()
	for b: Button in _salon_ui.boutons_vitesse:
		textes.append(b.text)
	verifier_egal(textes, PackedStringArray(["×1", "×2", "×4"]))
	var recues: Array[float] = []
	_salon_ui.options_changees.connect(
		func(v: float, _g: int, fixe: bool) -> void:
			recues.append(v)
			verifier_faux(fixe, "la graine reste aléatoire")
	)
	for i: int in _salon_ui.boutons_vitesse.size():
		var b := _salon_ui.boutons_vitesse[i]
		verifier_faux(b.disabled)
		b.pressed.emit()
		verifier_proche(recues[i], Salon.VITESSES[i], 0.0001, "vitesse du bouton %s" % b.text)
	verifier_egal(recues.size(), 3)


func test_le_non_hote_lit_la_vitesse_choisie_par_l_hote() -> void:
	for i: int in Salon.VITESSES.size():
		var s := _salon_de(2)
		s.regler(1, 1, Salon.VITESSES[i], 0, false)
		_salon_ui.afficher(s, 2)
		var attendu := SalonUi.libelle_vitesse(Salon.VITESSES[i])
		verifier(attendu in ["×1", "×2", "×4"], attendu)
		verifier(_salon_ui.find_children("Vitesse", "Label", true, false).size() == 1)
		var etiquette := _salon_ui.find_child("Vitesse", true, false) as Label
		verifier(etiquette.text.contains(attendu), "« %s » lit %s" % [etiquette.text, attendu])


func test_lancer_n_est_actif_que_si_tous_les_autres_sont_prets() -> void:
	var seul := _salon_de(1)
	_salon_ui.afficher(seul, 1)
	verifier_faux(_salon_ui.bouton_lancer.disabled, "l'hôte seul peut lancer")
	var s := _salon_de(3)
	_salon_ui.afficher(s, 1)
	verifier(_salon_ui.bouton_lancer.disabled, "personne n'est prêt")
	s.marquer_pret(2, true)
	_salon_ui.afficher(s, 1)
	verifier(_salon_ui.bouton_lancer.disabled, "un seul sur deux")
	s.marquer_pret(3, true)
	_salon_ui.afficher(s, 1)
	verifier_faux(_salon_ui.bouton_lancer.disabled, "tous prêts")
	var lances: Array[int] = [0]
	_salon_ui.lancer_demande.connect(func() -> void: lances[0] += 1)
	_salon_ui.bouton_lancer.pressed.emit()
	verifier_egal(lances[0], 1)


func test_le_bouton_pret_annonce_et_le_texte_dit_l_etat() -> void:
	var s := _salon_de(2)
	_salon_ui.afficher(s, 2)
	var recus: Array[bool] = []
	_salon_ui.pret_change.connect(func(p: bool) -> void: recus.append(p))
	verifier_egal(_salon_ui.bouton_pret.text, _t("SALON_BOUTON_PRET"))
	_salon_ui.bouton_pret.button_pressed = true
	_salon_ui.bouton_pret.pressed.emit()
	verifier_egal(recus, [true] as Array[bool])
	s.marquer_pret(2, true)
	_salon_ui.afficher(s, 2)
	verifier_egal(_salon_ui.bouton_pret.text, _t("SALON_BOUTON_PAS_PRET"), "l'état se lit")


func test_quitter_le_salon_est_toujours_possible() -> void:
	var fois: Array[int] = [0]
	_salon_ui.quitter.connect(func() -> void: fois[0] += 1)
	for id_local: int in [1, 2]:
		_salon_ui.afficher(_salon_de(2), id_local)
		_salon_ui.bouton_quitter.pressed.emit()
	verifier_egal(fois[0], 2)


func test_chaque_controle_du_salon_et_de_la_connexion_est_lisible() -> void:
	_salon_ui.afficher(_salon_de(2), 1)
	_connexion.ouvrir_creer("Mina")
	for racine: Control in [_salon_ui, _connexion]:
		for noeud: Node in racine.find_children("*", "Button", true, false):
			var b := noeud as Button
			verifier(b.custom_minimum_size.y >= HAUTEUR_MIN, "« %s » fait 48 px" % b.text)
		for noeud: Node in racine.find_children("*", "LineEdit", true, false):
			var c := noeud as LineEdit
			verifier(c.custom_minimum_size.y >= HAUTEUR_MIN, "« %s » fait 48 px" % c.name)
		verifier(
			racine.get_theme_font_size("font_size") >= TAILLE_MIN, "le texte fait 16 px au moins"
		)


func test_le_contraste_des_textes_du_salon_est_suffisant() -> void:
	verifier(ThemeJeu.contraste(ThemeJeu.PARCHEMIN, ThemeJeu.JAUGE_FOND) >= 4.5)
	verifier(ThemeJeu.contraste(ThemeJeu.PARCHEMIN, ThemeJeu.ENCRE) >= 4.5)


# --- Connexion : créer -------------------------------------------------------------------------


func test_creer_propose_salon_de_nom_et_le_port_7777() -> void:
	_connexion.ouvrir_creer("Mina")
	verifier(_connexion.page_creer_visible())
	verifier_egal(_connexion.champ_nom_salon.text, "Salon de Mina")
	verifier_egal(_connexion.champ_port_creer.text, "7777")


func test_creer_valide_et_annonce_le_nom_et_le_port() -> void:
	_connexion.ouvrir_creer("Mina")
	var recus: Array = []
	_connexion.creer_demande.connect(func(n: String, p: int) -> void: recus.append([n, p]))
	_connexion.champ_nom_salon.text = "  Chez Mina "
	_connexion.champ_port_creer.text = "9001"
	_connexion.bouton_creer.pressed.emit()
	verifier_egal(recus, [["Chez Mina", 9001]])


func test_creer_refuse_un_port_ou_un_nom_invalide_avec_un_message_et_sans_signal() -> void:
	_connexion.ouvrir_creer("Mina")
	var fois: Array[int] = [0]
	_connexion.creer_demande.connect(func(_n: String, _p: int) -> void: fois[0] += 1)
	for port: String in ["0", "65536", "-1", "abc", "", "77 77", "7777.5", "+80", "999999"]:
		_connexion.champ_nom_salon.text = "Salon"
		_connexion.champ_port_creer.text = port
		_connexion.bouton_creer.pressed.emit()
		verifier(_connexion.find_child("Message", true, false) != null, "un message existe")
		verifier_egal(
			(_connexion.find_children("Message", "Label", true, false)[0] as Label).text,
			_t("CONNEXION_ERREUR_PORT"),
			"port « %s »" % port
		)
	for nom: String in ["", "   ", NOM_LONG + "x"]:
		_connexion.champ_nom_salon.max_length = 0
		_connexion.champ_nom_salon.text = nom
		_connexion.champ_port_creer.text = "7777"
		_connexion.bouton_creer.pressed.emit()
	verifier_egal(fois[0], 0, "aucun signal sur saisie invalide")
	for port: String in ["1", "7777", "65535"]:
		_connexion.champ_nom_salon.text = NOM_LONG
		_connexion.champ_port_creer.text = port
		_connexion.bouton_creer.pressed.emit()
	verifier_egal(fois[0], 3, "les bornes sont valides")


func test_chaque_port_valide_et_invalide_en_boucle() -> void:
	for p: int in [1, 80, 7777, 65535]:
		verifier_egal(ConnexionUi.port_valide(str(p)), p)
	for brut: String in ["0", "65536", "-5", "x", "", " ", "1e3", "0x10", "٣"]:
		verifier_egal(ConnexionUi.port_valide(brut), 0, "« %s »" % brut)


# --- Connexion : rejoindre ---------------------------------------------------------------------


func test_rejoindre_liste_chaque_salon_avec_son_nom_et_ses_joueurs() -> void:
	_connexion.ouvrir_rejoindre()
	verifier(_connexion.page_rejoindre_visible())
	verifier_egal(_connexion.lignes_salons().size(), 0)
	var salons: Array[Dictionary] = []
	for i: int in 5:
		salons.append(
			{
				"nom": "Salon %d" % i,
				"joueurs": i,
				"max": 8,
				"adresse": "10.0.0.%d" % i,
				"port": 7777 + i
			}
		)
	_connexion.afficher_salons(salons)
	var lignes := _connexion.lignes_salons()
	verifier_egal(lignes.size(), 5)
	for i: int in 5:
		verifier(lignes[i].contains("Salon %d" % i), lignes[i])
		verifier(lignes[i].contains("%d sur 8" % i), lignes[i])
	var demandes: Array = []
	_connexion.rejoindre_demande.connect(func(a: String, p: int) -> void: demandes.append([a, p]))
	for i: int in 5:
		_connexion.presser_salon(i)
	verifier_egal(
		demandes,
		[
			["10.0.0.0", 7777],
			["10.0.0.1", 7778],
			["10.0.0.2", 7779],
			["10.0.0.3", 7780],
			["10.0.0.4", 7781]
		]
	)


func test_rejoindre_par_adresse_valide_et_refuse_le_reste() -> void:
	_connexion.ouvrir_rejoindre()
	verifier_egal(_connexion.champ_port_rejoindre.text, "7777")
	var demandes: Array = []
	_connexion.rejoindre_demande.connect(func(a: String, p: int) -> void: demandes.append([a, p]))
	for adresse: String in ["", "   ", "10.0.0.1 2", "a\tb", "x".repeat(300)]:
		_connexion.champ_adresse.max_length = 0
		_connexion.champ_adresse.text = adresse
		_connexion.bouton_rejoindre_adresse.pressed.emit()
	_connexion.champ_adresse.text = "192.168.1.20"
	_connexion.champ_port_rejoindre.text = "70000"
	_connexion.bouton_rejoindre_adresse.pressed.emit()
	verifier_egal(demandes.size(), 0, "aucun signal sur saisie invalide")
	_connexion.champ_port_rejoindre.text = "7790"
	_connexion.bouton_rejoindre_adresse.pressed.emit()
	verifier_egal(demandes, [["192.168.1.20", 7790]])


func test_une_erreur_de_connexion_s_affiche_en_texte() -> void:
	_connexion.ouvrir_rejoindre()
	_connexion.afficher_erreur_rejoindre("Version du protocole différente : reçue 2, attendue 1.")
	var message := _connexion.find_children("Message", "Label", true, false)[1] as Label
	verifier(message.visible)
	verifier(message.text.contains("Version du protocole"))
	_connexion.afficher_erreur_rejoindre("")
	verifier_faux(message.visible)


# --- Textes ------------------------------------------------------------------------------------


func test_chaque_cle_utilisee_par_les_interfaces_existe_dans_le_csv() -> void:
	var textes := CsvTextes.lire(CSV)
	verifier(textes.size() > 20)
	var motif := RegEx.create_from_string('tr\\("([A-Z_]+)"\\)')
	for chemin: String in SOURCES:
		var source := FileAccess.get_file_as_string(chemin)
		for m: RegExMatch in motif.search_all(source):
			var cle := m.get_string(1)
			verifier(textes.has(cle), "%s : clé %s absente de textes_salon.csv" % [chemin, cle])
			verifier_different(_t(cle), cle, "%s est traduite" % cle)


func test_typographie_francaise_des_textes_du_salon() -> void:
	var avant := RegEx.create_from_string("(?<!\\x{00A0})[:;?!]")
	var textes := CsvTextes.lire(CSV)
	for cle: String in textes:
		var texte: String = textes[cle]
		verifier(avant.search(texte) == null, "%s : espace insécable avant : ; ? !" % cle)
		verifier_faux("'" in texte, "%s : apostrophe droite" % cle)
