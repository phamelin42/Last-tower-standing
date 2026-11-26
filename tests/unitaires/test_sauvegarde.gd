extends CasDeTest
## Ce que le joueur retrouve de sa progression, et surtout ce qu'il ne perd jamais : un échec
## d'écriture, un fichier tronqué, corrompu ou d'une version plus récente laissent la dernière
## progression valide intacte (T11.3, points de vigilance 1 et 2 du lot 11).

const CLES_AUTORISEES: Array[String] = [
	"version",
	"defis_reussis",
	"skins_debloques",
	"skin_choisi",
	"parties",
	"meilleure_manche",
	"cumul_victoires",
	"cumul_eliminations",
	"cumul_or_gagne",
	"cumul_manches",
	"cumul_parties_multijoueur",
	"cumul_dernier_rempart",
]


func apres_chaque() -> void:
	Sauvegarde.simuler_echec("")
	super.apres_chaque()


# --- Aides ---------------------------------------------------------------------------------


func _chemin() -> String:
	return dossier_temporaire().path_join("progression.json")


func _profil(parties: int = 3, manche: int = 12) -> Profil:
	var p := Profil.new()
	p.defis_reussis.assign(["premier_sang", "tour_intacte"])
	p.skins_debloques.assign(["tour_bois", "tour_pierre"])
	p.skin_choisi = "tour_pierre"
	p.parties = parties
	p.meilleure_manche = manche
	return p


func _ecrire_brut(chemin: String, octets: PackedByteArray) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_buffer(octets)
	f.close()


func _octets(chemin: String) -> PackedByteArray:
	if not FileAccess.file_exists(chemin):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(chemin)


func _fichiers(dossier: String) -> PackedStringArray:
	var liste := PackedStringArray()
	for nom: String in DirAccess.get_files_at(dossier):
		liste.append(nom)
	liste.sort()
	return liste


func _corrompus(dossier: String) -> Array[String]:
	var sortie: Array[String] = []
	for nom: String in _fichiers(dossier):
		if nom.contains(".corrompu"):
			sortie.append(nom)
	return sortie


## Un fichier de la version `version` avec un contenu de profil valide.
func _json(version: int, extra: Dictionary = {}) -> String:
	var donnees: Dictionary = _profil().a_dict()
	donnees["version"] = version
	if version < 2:
		# Avant la version 2, le fichier n'a pas les six cumuls.
		for cle: String in Profil.BORNES_CUMULS:
			donnees.erase(cle)
	donnees.merge(extra, true)
	return JSON.stringify(donnees)


func _verifier_profil_vide(p: Profil, message: String) -> void:
	verifier_egal(p.defis_reussis, [] as Array[String], message + " : défis")
	verifier_egal(p.skins_debloques, [] as Array[String], message + " : skins")
	verifier_egal(p.skin_choisi, "", message + " : skin choisi")
	verifier_egal(p.parties, 0, message + " : parties")
	verifier_egal(p.meilleure_manche, 0, message + " : meilleure manche")


# --- Aller-retour --------------------------------------------------------------------------


func test_un_profil_complet_fait_l_aller_retour() -> void:
	var attendu := _profil()
	verifier(Sauvegarde.enregistrer(attendu, _chemin()), "l'écriture réussit")
	var relu := Sauvegarde.charger(_chemin())
	verifier_egal(relu.a_dict(), attendu.a_dict(), "le profil relu est celui qu'on a écrit")
	verifier_faux(relu.verrouille, "un fichier de la version courante n'est pas verrouillé")


func test_le_premier_lancement_donne_un_profil_vide_sans_erreur() -> void:
	var p := Sauvegarde.charger(_chemin())
	_verifier_profil_vide(p, "premier lancement")
	verifier_faux(p.verrouille, "un premier lancement n'est pas verrouillé")
	verifier_egal(_fichiers(dossier_temporaire()), PackedStringArray(), "rien n'est créé en lisant")


# --- Aucune perte (points de vigilance 1) -----------------------------------------------------


func test_un_echec_d_ecriture_garde_la_progression_precedente() -> void:
	var chemin := _chemin()
	var secours := chemin + Sauvegarde.EXTENSION_SECOURS
	verifier(Sauvegarde.enregistrer(_profil(1, 5), chemin), "première écriture")
	verifier(Sauvegarde.enregistrer(_profil(2, 8), chemin), "seconde écriture")
	var principal_avant := _octets(chemin)
	var secours_avant := _octets(secours)
	verifier_different(principal_avant.size(), 0, "le fichier existe")
	verifier_different(secours_avant.size(), 0, "la copie de secours existe")
	for etape: String in Sauvegarde.ETAPES:
		Sauvegarde.simuler_echec(etape)
		verifier_faux(Sauvegarde.enregistrer(_profil(9, 99), chemin), "échec à « %s »" % etape)
		Sauvegarde.simuler_echec("")
		verifier_egal(_octets(chemin), principal_avant, "« %s » : fichier identique" % etape)
		if etape == "renommage":
			# La copie de secours a déjà reçu l'état courant : elle égale le fichier, rien n'est perdu.
			verifier_egal(_octets(secours), principal_avant, "« renommage » : secours = fichier")
		else:
			verifier_egal(_octets(secours), secours_avant, "« %s » : secours identique" % etape)
		var reste := _fichiers(dossier_temporaire()).size()
		verifier_egal(reste, 2, "« %s » : aucun temporaire ne traîne" % etape)
		verifier_egal(
			Sauvegarde.charger(chemin).parties, 2, "« %s » : la progression reste" % etape
		)


func test_un_echec_au_premier_enregistrement_ne_laisse_aucun_fichier() -> void:
	# Sans fichier précédent, l'étape « secours » n'a pas lieu : seules les autres peuvent échouer.
	for etape: String in Sauvegarde.ETAPES:
		if etape == "secours":
			continue
		Sauvegarde.simuler_echec(etape)
		verifier_faux(Sauvegarde.enregistrer(_profil(), _chemin()), "échec à « %s »" % etape)
		Sauvegarde.simuler_echec("")
		verifier_egal(_fichiers(dossier_temporaire()).size(), 0, "« %s » : dossier vide" % etape)


func test_un_fichier_tronque_a_chaque_longueur_se_remplace_par_la_copie_de_secours() -> void:
	var chemin := _chemin()
	verifier(Sauvegarde.enregistrer(_profil(1, 5), chemin), "première écriture")
	verifier(Sauvegarde.enregistrer(_profil(2, 8), chemin), "seconde écriture")
	var complet := _octets(chemin)
	var secours_attendu := _profil(1, 5).a_dict()
	# Tous les préfixes strictement plus courts que le fichier, vide compris.
	for longueur: int in complet.size():
		_ecrire_brut(chemin, complet.slice(0, longueur))
		var p := Sauvegarde.charger(chemin)
		# Sans son seul retour à la ligne final, le fichier est encore un JSON entier et valide.
		var attendu := _profil(2, 8).a_dict() if longueur == complet.size() - 1 else secours_attendu
		verifier_egal(p.a_dict(), attendu, "préfixe de %d octets" % longueur)
		DirAccess.remove_absolute(chemin)
		for nom: String in _corrompus(dossier_temporaire()):
			DirAccess.remove_absolute(dossier_temporaire().path_join(nom))


func test_principal_et_secours_corrompus_donnent_un_profil_vide_et_conservent_le_fichier_corrompu(
) -> void:
	var chemin := _chemin()
	var secours := chemin + Sauvegarde.EXTENSION_SECOURS
	var abime := "{ pas du json".to_utf8_buffer()
	_ecrire_brut(chemin, abime)
	_ecrire_brut(secours, "[1, 2".to_utf8_buffer())
	var p := Sauvegarde.charger(chemin)
	_verifier_profil_vide(p, "tout est corrompu")
	var gardes := _corrompus(dossier_temporaire())
	verifier_egal(gardes.size(), 2, "les deux fichiers corrompus sont gardés : %s" % [gardes])
	var contenus: Array[String] = []
	for nom: String in gardes:
		contenus.append(_octets(dossier_temporaire().path_join(nom)).get_string_from_utf8())
	verifier_contient(contenus, "{ pas du json", "le fichier corrompu n'est pas effacé")
	# Un enregistrement suivant ne retrouve pas de progression, mais n'efface rien non plus.
	verifier(Sauvegarde.enregistrer(_profil(), chemin), "on peut réécrire un profil")
	verifier_egal(_corrompus(dossier_temporaire()).size(), 2, "les fichiers corrompus restent")


func test_un_fichier_corrompu_n_en_ecrase_pas_un_precedent() -> void:
	var chemin := _chemin()
	for i: int in Sauvegarde.CORROMPUS_MAX + 3:
		_ecrire_brut(chemin, ("{ abime %d" % i).to_utf8_buffer())
		Sauvegarde.charger(chemin)
	var gardes := _corrompus(dossier_temporaire())
	verifier_egal(gardes.size(), Sauvegarde.CORROMPUS_MAX, "au plus CORROMPUS_MAX fichiers gardés")
	var premier := _octets(chemin + Sauvegarde.EXTENSION_CORROMPU).get_string_from_utf8()
	verifier_egal(premier, "{ abime 0", "le premier fichier corrompu est conservé")


func test_deux_enregistrements_laissent_l_avant_dernier_etat_valide_en_secours() -> void:
	var chemin := _chemin()
	verifier(Sauvegarde.enregistrer(_profil(1, 5), chemin), "première écriture")
	verifier(Sauvegarde.enregistrer(_profil(2, 8), chemin), "seconde écriture")
	var secours := _lire_profil(chemin + Sauvegarde.EXTENSION_SECOURS)
	verifier_egal(secours.parties, 1, "le secours est l'état précédent")
	verifier_egal(Sauvegarde.charger(chemin).parties, 2, "le fichier est le dernier état")


func test_un_fichier_absent_se_remplace_par_la_copie_de_secours() -> void:
	var chemin := _chemin()
	verifier(Sauvegarde.enregistrer(_profil(1, 5), chemin), "première écriture")
	verifier(Sauvegarde.enregistrer(_profil(2, 8), chemin), "seconde écriture")
	DirAccess.remove_absolute(chemin)
	verifier_egal(Sauvegarde.charger(chemin).parties, 1, "le fichier a disparu : le secours sert")


func _lire_profil(chemin: String) -> Profil:
	# Charge une copie de secours comme un fichier principal, sans rien déplacer.
	var copie := dossier_temporaire().path_join("copie_lue.json")
	DirAccess.copy_absolute(chemin, copie)
	return Sauvegarde.charger(copie)


# --- Versions ------------------------------------------------------------------------------


func test_une_version_plus_recente_n_est_ni_lue_ni_ecrasee() -> void:
	var chemin := _chemin()
	var futur := _json(Sauvegarde.VERSION + 1, {"champ_du_futur": [1, 2, 3]})
	_ecrire_brut(chemin, futur.to_utf8_buffer())
	var avant := _octets(chemin)
	var p := Sauvegarde.charger(chemin)
	verifier(p.verrouille, "le profil est verrouillé")
	_verifier_profil_vide(p, "version plus récente")
	verifier_faux(Sauvegarde.enregistrer(_profil(), chemin), "pas d'écriture sur ce fichier")
	verifier_faux(Sauvegarde.enregistrer(Profil.new(), chemin), "même un profil neuf")
	verifier_egal(_octets(chemin), avant, "le fichier est identique à l'octet")
	verifier_egal(_corrompus(dossier_temporaire()).size(), 0, "il n'est pas mis de côté")


func test_chaque_version_precedente_se_migre() -> void:
	# Chaque format abandonné a sa fixture (écrite par `_json`) et son étape de migration.
	for version: int in range(1, Sauvegarde.VERSION):
		var chemin := dossier_temporaire().path_join("v%d.json" % version)
		_ecrire_brut(chemin, _json(version).to_utf8_buffer())
		var p := Sauvegarde.charger(chemin)
		verifier_egal(
			p.version, Sauvegarde.VERSION, "v%d est amenée à la version courante" % version
		)
		verifier_egal(p.parties, 3, "v%d garde ses compteurs" % version)
	var courant := dossier_temporaire().path_join("courant.json")
	_ecrire_brut(courant, _json(Sauvegarde.VERSION).to_utf8_buffer())
	verifier_egal(Sauvegarde.charger(courant).parties, 3, "la version courante se lit")


func test_une_version_absente_ou_invalide_est_refusee() -> void:
	var cas: Array[String] = [
		JSON.stringify({"defis_reussis": [], "skins_debloques": [], "skin_choisi": ""}),
		_json(0),
		_json(-3),
		'{"version": "1"}',
		_json(1, {"version": null}),
	]
	for texte: String in cas:
		var chemin := _chemin()
		_ecrire_brut(chemin, texte.to_utf8_buffer())
		var p := Sauvegarde.charger(chemin)
		_verifier_profil_vide(p, "version invalide : " + texte.left(40))
		verifier_faux(p.verrouille, "une version invalide n'est pas une version future")
		for nom: String in _corrompus(dossier_temporaire()):
			DirAccess.remove_absolute(dossier_temporaire().path_join(nom))


# --- Entrées d'un tiers (points de vigilance 2) ---------------------------------------------


func test_un_fichier_trop_gros_est_refuse_avant_lecture() -> void:
	var chemin := _chemin()
	var gros := _json(Sauvegarde.VERSION).to_utf8_buffer()
	gros.append_array(" ".repeat(Sauvegarde.TAILLE_MAX_FICHIER).to_utf8_buffer())
	_ecrire_brut(chemin, gros)
	_verifier_profil_vide(Sauvegarde.charger(chemin), "fichier trop gros")
	verifier_egal(_corrompus(dossier_temporaire()).size(), 1, "il est mis de côté, pas lu")


func test_valeurs_hors_bornes_ou_de_mauvais_types_sont_ramenees_ou_refusees() -> void:
	var p := _lire_texte(_json(Sauvegarde.VERSION, {"meilleure_manche": -5, "parties": -1}))
	verifier_egal(p.meilleure_manche, 0, "manche négative ramenée à 0")
	verifier_egal(p.parties, 0, "parties négatives ramenées à 0")
	p = _lire_texte(_json(Sauvegarde.VERSION, {"meilleure_manche": 1e30, "parties": 1e30}))
	verifier_egal(p.meilleure_manche, Profil.MANCHE_MAX, "manche énorme ramenée au maximum")
	verifier_egal(p.parties, Profil.PARTIES_MAX, "parties énormes ramenées au maximum")
	p = _lire_texte(_json(Sauvegarde.VERSION, {"parties": 3.7}))
	verifier_egal(p.parties, 3, "un flottant devient un entier")
	# Non fini : JSON.parse_string lit 1e999 comme l'infini, que le profil refuse.
	var infini := _json(Sauvegarde.VERSION).replace('"parties":3', '"parties":1e999')
	verifier(infini.contains("1e999"), "le texte de test contient bien l'infini")
	verifier_egal(_lire_texte(infini).parties, 0, "manche non finie : profil de secours (vide)")
	var faux: Array[Dictionary] = [
		{"defis_reussis": [1, 2]},
		{"defis_reussis": "premier_sang"},
		{"skins_debloques": {"a": 1}},
		{"skin_choisi": 7},
		{"parties": "beaucoup"},
		{"parties": true},
		{"meilleure_manche": [1]},
		{"defis_reussis": null},
	]
	for cas: Dictionary in faux:
		var refuse := _lire_texte(_json(Sauvegarde.VERSION, cas))
		_verifier_profil_vide(refuse, "type faux %s" % [cas])
	var enorme: Array[String] = []
	for i: int in 10000:
		enorme.append("defi_%d" % i)
	# Un tel fichier dépasse la taille maximale : il est refusé avant lecture. Le tableau lui-même
	# est borné à part, pour un profil construit en mémoire ou un fichier plus court.
	var trop_long := _lire_texte(_json(Sauvegarde.VERSION, {"defis_reussis": enorme}))
	_verifier_profil_vide(trop_long, "dix mille entrées : fichier trop gros")
	var brut: Dictionary = _profil().a_dict()
	brut["defis_reussis"] = enorme
	var borne := Profil.depuis_dict(brut)
	verifier_non_nul(borne, "dix mille entrées en mémoire")
	verifier_egal(
		borne.defis_reussis.size(), Profil.LISTE_MAX, "tableau de dix mille entrées borné"
	)
	var long := "x".repeat(500)
	var court := _lire_texte(_json(Sauvegarde.VERSION, {"skin_choisi": long}))
	verifier_egal(court.skin_choisi.length(), Profil.IDENTIFIANT_MAX, "identifiant tronqué")
	var doublons := _lire_texte(_json(Sauvegarde.VERSION, {"defis_reussis": ["a", "a", "", " "]}))
	verifier_egal(doublons.defis_reussis, ["a"] as Array[String], "doublons et vides retirés")
	var controle := _lire_texte(_json(Sauvegarde.VERSION, {"skin_choisi": "t\u0001our\u0085"}))
	verifier_egal(controle.skin_choisi, "tour", "caractères de contrôle retirés")


func test_un_fichier_arbitraire_ne_leve_aucune_exception() -> void:
	var graine := RandomNumberGenerator.new()
	graine.seed = 11
	var cas: Array[String] = ["", "null", "[]", "42", '"texte"', "{}", '{"version": 1}', "ÿþ"]
	for i: int in 200:
		var octets := PackedByteArray()
		for j: int in graine.randi_range(0, 120):
			octets.append(graine.randi() % 256)
		cas.append(octets.get_string_from_utf8())
	for texte: String in cas:
		var p := _lire_texte(texte)
		verifier_non_nul(p, "jamais null")
		for nom: String in _corrompus(dossier_temporaire()):
			DirAccess.remove_absolute(dossier_temporaire().path_join(nom))


func _lire_texte(texte: String) -> Profil:
	var chemin := _chemin()
	_ecrire_brut(chemin, texte.to_utf8_buffer())
	var p := Sauvegarde.charger(chemin)
	for nom: String in _corrompus(dossier_temporaire()):
		DirAccess.remove_absolute(dossier_temporaire().path_join(nom))
	DirAccess.remove_absolute(chemin)
	return p


# --- Fichier temporaire et liste blanche ---------------------------------------------------------


func test_deux_processus_n_ecrivent_pas_le_meme_fichier_temporaire() -> void:
	var chemin := _chemin()
	var a := Sauvegarde.chemin_temporaire(chemin, 100)
	var b := Sauvegarde.chemin_temporaire(chemin, 101)
	verifier_different(a, b, "un nom par processus")
	verifier(a.begins_with(chemin), "le temporaire est à côté du fichier (même volume)")
	verifier_egal(
		Sauvegarde.chemin_temporaire(chemin),
		Sauvegarde.chemin_temporaire(chemin, OS.get_process_id()),
		"par défaut : ce processus"
	)
	# Le temporaire d'un autre processus n'est ni lu, ni supprimé, ni écrasé.
	_ecrire_brut(b, "autre processus".to_utf8_buffer())
	verifier(Sauvegarde.enregistrer(_profil(), chemin), "l'écriture réussit")
	verifier_egal(
		_octets(b).get_string_from_utf8(), "autre processus", "le temporaire voisin reste"
	)


func test_le_fichier_ne_contient_aucun_champ_hors_de_la_liste() -> void:
	var chemin := _chemin()
	var p := _profil()
	verifier(Sauvegarde.enregistrer(p, chemin), "l'écriture réussit")
	var brut: Variant = JSON.parse_string(_octets(chemin).get_string_from_utf8())
	verifier(brut is Dictionary, "le fichier est un objet JSON")
	var donnees: Dictionary = brut
	var cles: Array = donnees.keys()
	cles.sort()
	var attendues: Array = CLES_AUTORISEES.duplicate()
	attendues.sort()
	verifier_egal(cles, attendues, "exactement les clés de la liste blanche")
	var profil_cles: Array = Profil.CLES.duplicate()
	profil_cles.sort()
	verifier_egal(profil_cles, attendues, "Profil.CLES et la liste du test concordent")
	# Une clé inconnue lue dans un fichier n'est pas réécrite.
	_ecrire_brut(chemin, _json(Sauvegarde.VERSION, {"nom_joueur": "Camille"}).to_utf8_buffer())
	var relu := Sauvegarde.charger(chemin)
	verifier(Sauvegarde.enregistrer(relu, chemin), "réécriture")
	verifier_faux(
		_octets(chemin).get_string_from_utf8().contains("Camille"), "pas de nom de joueur"
	)
