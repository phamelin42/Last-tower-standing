extends CasDeTest
## La liste de défis de `docs/defis.md` : ce que Phil valide doit se lire par la machine, avec des
## noms et des textes originaux, des conditions qui ne citent que des compteurs du bilan, et un
## skin par défi (D20, B3 à B5).

const DOCUMENT := "res://docs/defis.md"
const NBSP := " "
const MODES: Array[String] = ["solo", "multijoueur", "les deux"]
## Ce que `docs/defis.md` annonce : un document sans défi ou sans compteur ne passe pas.
const COLONNES_DEFIS: Array[String] = ["id", "nom", "texte", "condition", "compteurs", "mode"]
const COLONNES_COMPTEURS: Array[String] = ["compteur", "définition", "unité"]
const COLONNES_SKINS: Array[String] = ["défi", "skin (identifiant)", "idée de silhouette"]


## Les lignes du tableau qui suit le titre `## <prefixe>` : un dictionnaire par ligne, rangé par
## nom de colonne. Les puces de code (`) sont retirées des cellules.
func _tableau(prefixe: String) -> Array[Dictionary]:
	var texte := FileAccess.get_file_as_string(DOCUMENT)
	verifier_faux(texte.is_empty(), "%s existe et n'est pas vide" % DOCUMENT)
	var lignes := texte.split("\n")
	var en_section := false
	var colonnes: Array[String] = []
	var sortie: Array[Dictionary] = []
	for ligne: String in lignes:
		if ligne.begins_with("## "):
			en_section = ligne.begins_with("## " + prefixe)
			continue
		if not en_section or not ligne.begins_with("|"):
			continue
		var cellules: Array[String] = []
		for brute: String in ligne.strip_edges().trim_prefix("|").trim_suffix("|").split("|"):
			cellules.append(brute.strip_edges())
		if colonnes.is_empty():
			colonnes = cellules
			continue
		if cellules[0].begins_with("-"):
			continue
		var rang: Dictionary = {}
		for i: int in mini(colonnes.size(), cellules.size()):
			rang[colonnes[i]] = cellules[i]
		sortie.append(rang)
	return sortie


func _sans_puces(texte: String) -> String:
	return texte.replace("`", "")


## Les noms de compteurs écrits entre puces dans une cellule.
func _citations(cellule: String) -> Array[String]:
	var sortie: Array[String] = []
	var motif := RegEx.create_from_string("`([a-z_0-9]+)`")
	for trouve: RegExMatch in motif.search_all(cellule):
		sortie.append(trouve.get_string(1))
	return sortie


func _defis() -> Array[Dictionary]:
	return _tableau("3.")


func _compteurs() -> Array[String]:
	var sortie: Array[String] = []
	for rang: Dictionary in _tableau("2."):
		sortie.append(_sans_puces(String(rang["compteur"])))
	return sortie


func test_au_moins_un_defi_et_la_liste_n_est_jamais_vide() -> void:
	var defis := _defis()
	verifier(defis.size() >= 1, "au moins un défi")
	verifier(_compteurs().size() >= 1, "au moins un compteur")
	verifier(_tableau("4.").size() >= 1, "au moins un skin")
	for rang: Dictionary in defis:
		for colonne: String in COLONNES_DEFIS:
			verifier(rang.has(colonne), "colonne « %s » présente" % colonne)
			verifier_faux(
				String(rang.get(colonne, "")).is_empty(), "colonne « %s » remplie" % colonne
			)
	for rang: Dictionary in _tableau("2."):
		for colonne: String in COLONNES_COMPTEURS:
			verifier_faux(String(rang.get(colonne, "")).is_empty(), "compteur : « %s »" % colonne)
	for rang: Dictionary in _tableau("4."):
		for colonne: String in COLONNES_SKINS:
			verifier_faux(String(rang.get(colonne, "")).is_empty(), "skin : « %s »" % colonne)


func test_chaque_defi_a_un_id_un_nom_un_texte_et_une_condition_uniques() -> void:
	var vus: Dictionary = {}
	for colonne: String in ["id", "nom", "texte", "condition"]:
		vus[colonne] = {}
	var forme_id := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	for rang: Dictionary in _defis():
		var id := _sans_puces(String(rang["id"]))
		verifier(forme_id.search(id) != null, "%s : identifiant en snake_case sans accent" % id)
		for colonne: String in ["id", "nom", "texte", "condition"]:
			var valeur := String(rang[colonne])
			var deja: Dictionary = vus[colonne]
			verifier_faux(deja.has(valeur), "%s : « %s » en double (%s)" % [id, colonne, valeur])
			deja[valeur] = true
		var mode := String(rang["mode"])
		verifier(MODES.has(mode), "%s : mode « %s » inconnu" % [id, mode])


func test_aucun_nom_ni_texte_de_defi_n_est_un_nom_d_origine() -> void:
	var noms := NomsOrigine.lire()
	verifier(noms.size() > 100, "la liste des noms d'origine est lue")
	for rang: Dictionary in _defis() + _tableau("4."):
		for colonne: String in rang:
			var trouves := NomsOrigine.trouver(_sans_puces(String(rang[colonne])), noms)
			verifier_egal(trouves, PackedStringArray(), "« %s » : nom d'origine" % rang[colonne])


func test_chaque_condition_ne_cite_que_des_compteurs_de_la_liste() -> void:
	var connus := _compteurs()
	for rang: Dictionary in _defis():
		var id := _sans_puces(String(rang["id"]))
		var citees := _citations(String(rang["condition"]))
		verifier(citees.size() >= 1, "%s : la condition cite au moins un compteur" % id)
		for nom: String in citees:
			verifier(connus.has(nom), "%s : compteur « %s » absent de la liste" % [id, nom])
		# La colonne des compteurs dit exactement ce que la condition lit.
		var annonces := _citations(String(rang["compteurs"]))
		citees.sort()
		annonces.sort()
		verifier_egal(annonces, citees, "%s : colonne « compteurs » et condition concordent" % id)


func test_chaque_compteur_de_la_liste_est_utilise_par_un_defi() -> void:
	var utilises: Dictionary = {}
	for rang: Dictionary in _defis():
		for nom: String in _citations(String(rang["compteurs"])):
			utilises[nom] = true
	var vus: Dictionary = {}
	for nom: String in _compteurs():
		verifier_faux(vus.has(nom), "compteur « %s » en double" % nom)
		vus[nom] = true
		verifier(utilises.has(nom), "compteur « %s » inutilisé" % nom)


func test_chaque_defi_a_exactement_un_skin_et_chaque_skin_un_defi() -> void:
	var ids: Array[String] = []
	for rang: Dictionary in _defis():
		ids.append(_sans_puces(String(rang["id"])))
	var par_defi: Dictionary = {}
	var skins_vus: Dictionary = {}
	for rang: Dictionary in _tableau("4."):
		var defi := _sans_puces(String(rang["défi"]))
		var skin := _sans_puces(String(rang["skin (identifiant)"]))
		verifier(ids.has(defi), "skin « %s » : défi « %s » inconnu" % [skin, defi])
		verifier_faux(par_defi.has(defi), "défi « %s » : deux skins" % defi)
		verifier_faux(skins_vus.has(skin), "skin « %s » en double" % skin)
		par_defi[defi] = skin
		skins_vus[skin] = true
	for id: String in ids:
		verifier(par_defi.has(id), "défi « %s » sans skin" % id)


func test_typographie_francaise_des_textes_de_defis() -> void:
	var avant_ponctuation := RegEx.create_from_string("(?<!\\x{00A0})[:;?!]")
	var guillemets := RegEx.create_from_string("«(?!\\x{00A0})|(?<!\\x{00A0})»")
	for rang: Dictionary in _defis():
		for colonne: String in ["nom", "texte"]:
			var texte := String(rang[colonne])
			var message := "« %s » (%s)" % [texte, colonne]
			verifier(
				avant_ponctuation.search(texte) == null, "%s : espace insécable manquante" % message
			)
			verifier(guillemets.search(texte) == null, "%s : guillemets sans insécable" % message)
			verifier_faux(texte.contains("'"), "%s : apostrophe droite" % message)
			verifier_faux(texte.contains("  "), "%s : espaces doublées" % message)
			verifier(
				RegEx.create_from_string("[0-9]\\.[0-9]").search(texte) == null,
				"%s : point décimal" % message
			)
	verifier(
		FileAccess.get_file_as_string(DOCUMENT).contains(NBSP), "le document porte des insécables"
	)


func test_le_document_detecte_ses_fautes() -> void:
	var avant_ponctuation := RegEx.create_from_string("(?<!\\x{00A0})[:;?!]")
	verifier(
		avant_ponctuation.search("Tenez : bien") != null, "l'espace simple avant « : » est vue"
	)
	verifier(avant_ponctuation.search("Tenez" + NBSP + ": bien") == null, "l'insécable passe")
