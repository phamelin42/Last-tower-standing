extends CasDeTest
## Garde : les ressources graphiques (images, polices, nuanceurs) sont citées et chargées par une
## liste fermée de fichiers, jamais ailleurs. Un chemin d'image écrit en dur dans l'interface ou
## dans la logique de jeu ferait échapper l'image aux contrôles de licence et de découpage.
## Lit chaque `.gd` du projet, hors `tests/`, hors dossiers cachés (`.claude/` abrite les
## worktrees des agents) et hors `tools/` (scripts de génération lancés à la main, qui écrivent
## des images au lieu de les afficher).

## Fichiers qui écrivent un chemin d'image : correspondance entité → sprites, images des offres,
## recadrages, thème de l'interface, décor, effets.
const CITENT_DES_IMAGES: Array[String] = [
	"res://visuels/apparence.gd",
	"res://visuels/images_offres.gd",
	"res://visuels/recadrages.gd",
	"res://ui/theme.gd",
	"res://visuels/decor.gd",
	"res://visuels/plan_decor.gd",
	"res://visuels/effets.gd",
	"res://visuels/attaques_elementaires.gd",
]
## Fichiers qui chargent une texture ou un nuanceur : les précédents, plus les deux qui chargent
## les chemins que leur donnent `Apparence` et `ImagesOffres` (l'arène et l'image d'une offre).
const CHARGENT_DES_IMAGES: Array[String] = [
	"res://visuels/apparence.gd",
	"res://visuels/images_offres.gd",
	"res://visuels/recadrages.gd",
	"res://ui/theme.gd",
	"res://visuels/decor.gd",
	"res://visuels/plan_decor.gd",
	"res://visuels/effets.gd",
	"res://visuels/attaques_elementaires.gd",
	"res://visuels/textures_effets.gd",
	"res://visuels/flamme_boss.gd",
	"res://visuels/arene_2d.gd",
	"res://visuels/allies_2d.gd",
	"res://ui/image_offre.gd",
]


## Lignes de code qui écrivent un chemin d'image : une chaîne se terminant par une extension
## graphique, ou sous `res://assets/` hors des sons. Les commentaires ne comptent pas.
func _citations(source: String) -> Array[String]:
	var motif := RegEx.create_from_string(
		(
			'"[^"\\n]*(\\.png|\\.svg|\\.woff2|\\.ttf|\\.otf|\\.jpe?g|\\.webp|\\.gdshader)"'
			+ '|"res://assets/(?!sons/)'
		)
	)
	var trouvees: Array[String] = []
	for ligne: String in source.split("\n"):
		if ligne.strip_edges().begins_with("#"):
			continue
		if motif.search(ligne) != null:
			trouvees.append(ligne.strip_edges())
	return trouvees


## Lignes de code qui chargent une image, une police ou un nuanceur (`load` ou `preload` suivi
## d'un `as Texture2D`, `as Shader`, `as Font`…).
func _chargements(source: String) -> Array[String]:
	var motif := RegEx.create_from_string(
		(
			"(?<![A-Za-z_])(pre)?load\\(.*\\bas (Texture2D|Texture|CompressedTexture2D|ImageTexture"
			+ "|AtlasTexture|Shader|ShaderMaterial|Font|FontFile|FontVariation)\\b"
		)
	)
	var trouvees: Array[String] = []
	for ligne: String in source.split("\n"):
		if ligne.strip_edges().begins_with("#"):
			continue
		if motif.search(ligne) != null:
			trouvees.append(ligne.strip_edges())
	return trouvees


func _lister_gd(dossier: String, sortie: Array[String]) -> void:
	var acces := DirAccess.open(dossier)
	verifier_non_nul(acces, "dossier illisible : %s" % dossier)
	if acces == null:
		return
	acces.list_dir_begin()
	var nom: String = acces.get_next()
	while not nom.is_empty():
		var chemin: String = dossier.path_join(nom)
		if acces.current_is_dir():
			if not nom.begins_with(".") and chemin != "res://tests" and chemin != "res://tools":
				_lister_gd(chemin, sortie)
		elif nom.get_extension() == "gd":
			sortie.append(chemin)
		nom = acces.get_next()
	acces.list_dir_end()


func _fautifs(
	fichiers: Array[String], autorises: Array[String], detecteur: Callable
) -> Array[String]:
	var fautifs: Array[String] = []
	for chemin: String in fichiers:
		if chemin in autorises:
			continue
		var lignes: Array[String] = detecteur.call(FileAccess.get_file_as_string(chemin))
		for ligne: String in lignes:
			fautifs.append("%s : %s" % [chemin, ligne])
	return fautifs


func test_les_listes_ne_citent_que_des_fichiers_qui_existent() -> void:
	for chemin: String in CHARGENT_DES_IMAGES + CITENT_DES_IMAGES:
		verifier(FileAccess.file_exists(chemin), "liste de garde périmée : %s" % chemin)
	for chemin: String in CITENT_DES_IMAGES:
		verifier(
			chemin in CHARGENT_DES_IMAGES,
			"%s cite des images mais ne peut pas les charger" % chemin
		)


func test_aucun_chemin_d_image_n_est_ecrit_hors_de_la_liste_fermee() -> void:
	var fichiers: Array[String] = []
	_lister_gd("res://", fichiers)
	verifier(fichiers.size() > 10, "garde : trop peu de .gd lus (%d)" % fichiers.size())
	var fautifs := _fautifs(fichiers, CITENT_DES_IMAGES, _citations)
	verifier(
		fautifs.is_empty(),
		"chemin d'image écrit hors de la liste : %s" % " | ".join(PackedStringArray(fautifs))
	)


func test_aucune_image_n_est_chargee_hors_de_la_liste_fermee() -> void:
	var fichiers: Array[String] = []
	_lister_gd("res://", fichiers)
	var fautifs := _fautifs(fichiers, CHARGENT_DES_IMAGES, _chargements)
	verifier(
		fautifs.is_empty(),
		"image chargée hors de la liste : %s" % " | ".join(PackedStringArray(fautifs))
	)


func test_la_liste_fermee_contient_bien_des_citations_et_des_chargements() -> void:
	# Contrôle négatif : un détecteur qui ne voit rien ferait passer les deux tests précédents.
	var citent := 0
	var chargent := 0
	for chemin: String in CHARGENT_DES_IMAGES:
		var source := FileAccess.get_file_as_string(chemin)
		citent += 1 if not _citations(source).is_empty() else 0
		chargent += 1 if not _chargements(source).is_empty() else 0
	verifier(citent >= 5, "les citations ne sont plus détectées (%d fichiers)" % citent)
	verifier(chargent >= 5, "les chargements ne sont plus détectés (%d fichiers)" % chargent)


func test_le_detecteur_reconnait_chaque_forme_de_ressource_graphique() -> void:
	for extension: String in [
		".png", ".svg", ".woff2", ".ttf", ".otf", ".jpg", ".jpeg", ".webp", ".gdshader"
	]:
		verifier(
			not _citations('var a := "res://x/y%s"' % extension).is_empty(),
			"extension %s non détectée" % extension
		)
	verifier(
		not _citations('const D := "res://assets/tiny_swords/"').is_empty(), "dossier d'images"
	)
	verifier(not _chargements("var t := load(chemin) as Texture2D").is_empty(), "load Texture2D")
	verifier(not _chargements('var t := preload("res://a.png") as Texture2D').is_empty(), "preload")
	verifier(not _chargements("var s := load(SHADER) as Shader").is_empty(), "load Shader")
	verifier(not _chargements("var f := load(POLICE) as Font").is_empty(), "load Font")


func test_le_detecteur_ignore_commentaires_sons_et_scenes() -> void:
	verifier(_citations('# voir "a.png"').is_empty(), "commentaire")
	verifier(_citations('## chemin "res://assets/x/b.png"').is_empty(), "commentaire de doc")
	verifier(_citations('const S := "res://assets/sons/tir.ogg"').is_empty(), "son")
	verifier(_citations('const T := "res://scenes/jeu.tscn"').is_empty(), "scène")
	verifier(_chargements("var s := load(SCENE) as PackedScene").is_empty(), "scène chargée")
	verifier(_chargements("var s := load(chemin) as AudioStream").is_empty(), "son chargé")
	verifier(_chargements("# load(x) as Texture2D").is_empty(), "chargement commenté")
	verifier(_chargements("var c := ResourceLoader.exists(x)").is_empty(), "exists")
