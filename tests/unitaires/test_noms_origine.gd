extends CasDeTest
## Le jeu ne reprend que les mécaniques de la map d'origine : aucun de ses noms d'armes ou
## d'améliorations (`docs/tower_survivors.md` §4) ne doit apparaître dans nos données, nos textes
## ni notre code. C'est le filet complet ; `test_contenu.gd` n'en garde que quelques noms.

const DOSSIERS: Array[String] = [
	"res://data",
	"res://i18n",
	"res://sim",
	"res://ui",
	"res://visuels",
	"res://app",
	"res://reseau",
	"res://sons",
]
const EXTENSIONS: Array[String] = ["gd", "json", "csv", "tres", "tscn"]
const NB_ARMES := 75
const NB_AMELIORATIONS := 84
const NB_HORS_BOUTIQUE := 8


func _noms() -> PackedStringArray:
	return NomsOrigine.lire()


func _noms_sans_homographes() -> PackedStringArray:
	var noms := PackedStringArray()
	for nom: String in _noms():
		if not NomsOrigine.HOMOGRAPHES_FRANCAIS.has(nom):
			noms.append(nom)
	return noms


static func _fichiers(dossier: String) -> PackedStringArray:
	var liste := PackedStringArray()
	for sous: String in DirAccess.get_directories_at(dossier):
		liste.append_array(_fichiers(dossier.path_join(sous)))
	for fichier: String in DirAccess.get_files_at(dossier):
		if EXTENSIONS.has(fichier.get_extension()):
			liste.append(dossier.path_join(fichier))
	return liste


## Les noms d'objets (`nom`) d'un JSON, à toute profondeur.
static func _noms_d_objets(valeur: Variant, sortie: PackedStringArray) -> void:
	if valeur is Dictionary:
		var dico: Dictionary = valeur
		for cle: Variant in dico:
			if cle == "nom" and dico[cle] is String:
				sortie.append(dico[cle])
			_noms_d_objets(dico[cle], sortie)
	elif valeur is Array:
		for element: Variant in valeur:
			_noms_d_objets(element, sortie)


## Les violations d'un fichier : « nom (ligne n) ». Les homographes ne comptent que comme nom
## entier d'un objet (`nom` d'un JSON, cellule entière d'un CSV).
static func violations(
	chemin: String, contenu: String, noms: PackedStringArray
) -> PackedStringArray:
	var trouvees := PackedStringArray()
	var source := NomsOrigine.sans_chemins_d_images(contenu) if chemin.ends_with(".gd") else contenu
	var lignes := source.split("\n")
	var courants := PackedStringArray()
	for nom: String in noms:
		if not NomsOrigine.HOMOGRAPHES_FRANCAIS.has(nom):
			courants.append(nom)
	for i: int in lignes.size():
		for nom: String in NomsOrigine.trouver(lignes[i], courants):
			trouvees.append("%s (ligne %d)" % [nom, i + 1])
	var entiers := PackedStringArray()
	if chemin.ends_with(".json"):
		_noms_d_objets(JSON.parse_string(contenu), entiers)
	elif chemin.ends_with(".csv"):
		for ligne: String in lignes:
			for cellule: String in ligne.split(","):
				entiers.append(cellule.strip_edges().trim_prefix('"').trim_suffix('"'))
	for entier: String in entiers:
		for nom: String in NomsOrigine.HOMOGRAPHES_FRANCAIS:
			if NomsOrigine.normaliser(entier) == NomsOrigine.normaliser(nom):
				trouvees.append("%s (nom entier d'un objet)" % nom)
	return trouvees


func test_la_liste_lue_compte_exactement_les_noms_du_document() -> void:
	var noms := _noms()
	verifier(not noms.is_empty(), "docs/tower_survivors.md absent ou sans nom")
	verifier_egal(noms.size(), NB_ARMES + NB_AMELIORATIONS + NB_HORS_BOUTIQUE)
	for attendu: String in ["Throwing Axes", "Necromancer’s Tome", "Blight Aura", "Golden Key"]:
		verifier_contient(noms, attendu)


func test_aucun_nom_d_origine_dans_les_donnees_les_textes_et_le_code() -> void:
	var noms := _noms()
	verifier(not noms.is_empty(), "aucun nom lu : le garde-fou ne garde rien")
	var nb_fichiers := 0
	for dossier: String in DOSSIERS:
		for chemin: String in _fichiers(dossier):
			nb_fichiers += 1
			var contenu := FileAccess.get_file_as_string(chemin)
			for v: String in violations(chemin, contenu, noms):
				verifier(false, "nom d'origine dans %s : %s" % [chemin, v])
	verifier(nb_fichiers > 50, "trop peu de fichiers lus (%d)" % nb_fichiers)


func test_un_nom_d_origine_dans_un_texte_est_detecte() -> void:
	var noms := _noms()
	for nom: String in noms:
		var variantes: Array[String] = [
			"une %s rare" % nom,
			"Une %s RARE" % nom.to_upper(),
			"voir : %s !" % nom,
			"l %s !" % nom.replace(" ", " "),
			"le %s." % nom.replace("'", "’"),
			"le %s." % nom.replace("’", "'"),
		]
		for texte: String in variantes:
			verifier_contient(
				NomsOrigine.trouver(texte, noms),
				nom,
				"« %s » non trouvé dans « %s »" % [nom, texte]
			)


func test_un_nom_d_origine_colle_a_d_autres_lettres_n_est_pas_un_faux_positif() -> void:
	var noms := _noms()
	for nom: String in noms:
		for texte: String in [
			"x%s" % nom, "%sx" % nom, "é%s" % nom, "%sé" % nom, "7%s" % nom, "%s7" % nom
		]:
			verifier_faux(
				NomsOrigine.trouver(texte, PackedStringArray([nom])).has(nom),
				"« %s » trouvé dans « %s »" % [nom, texte]
			)
	# Un tiret ou un point final n'est pas une lettre : le nom reste trouvé.
	verifier_contient(NomsOrigine.trouver("hache-Wisp.", PackedStringArray(["Wisp"])), "Wisp")


func test_un_homographe_n_est_refuse_que_comme_nom_entier() -> void:
	var noms := PackedStringArray(["Recharge"])
	verifier_egal(violations("res://data/x.json", '{"nom": "recharge réduite"}', noms).size(), 0)
	verifier_egal(violations("res://data/x.json", '{"recharge": 1.5}', noms).size(), 0)
	verifier_egal(violations("res://data/x.json", '{"nom": "Recharge"}', noms).size(), 1)
	verifier_egal(violations("res://i18n/x.csv", "cle,fr\nA,Recharge réduite\n", noms).size(), 0)
	verifier_egal(violations("res://i18n/x.csv", "cle,fr\nA,Recharge\n", noms).size(), 1)


func test_un_chemin_d_image_du_pack_ne_declenche_pas_le_garde_fou() -> void:
	var noms := _noms_sans_homographes()
	var nom: String = noms[0]
	var source := 'const A := "Pack/%s + C/d.png"\nvar x := "%s"\n' % [nom, nom]
	var propre := NomsOrigine.sans_chemins_d_images(source)
	verifier_faux(propre.contains("C/d.png"))
	verifier_egal(NomsOrigine.trouver(propre, noms).size(), 1, "seul le littéral hors chemin reste")
	verifier_egal(violations("res://visuels/a.gd", source, noms).size(), 1)


func test_la_liste_des_homographes_est_fermee_et_justifiee() -> void:
	var noms := _noms()
	verifier(NomsOrigine.HOMOGRAPHES_FRANCAIS.size() <= 3, "plus de 3 homographes")
	for h: String in NomsOrigine.HOMOGRAPHES_FRANCAIS:
		verifier_contient(noms, h, "« %s » n'est pas un nom lu" % h)
