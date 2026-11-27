extends CasDeTest
## Assets remplaçables (Phil, 26/11/2026, T10.4) : changer un pack d'images ou de sons ne demande
## que de remplacer les fichiers et `data/assets.json`. Chemin, taille de case, nombre d'images,
## régions, ancrages, échelle et durée ne s'écrivent donc jamais en dur dans `visuels/`, `ui/` ou
## `sons/`, et chaque fichier décrit existe avec des dimensions qui contiennent ce qu'on en lit.

const DOSSIERS: Array[String] = ["res://visuels", "res://ui", "res://sons"]
## Liste fermée : les valeurs de la forme `Vector2i(a, b)` ou `Rect2(a, b, c, d)` qui restent
## écrites en dur parce qu'elles ne sont la géométrie d'aucun fichier d'image. Une ligne par
## entrée (texte de la ligne, espaces de bord retirés) ;
## `test_la_liste_fermee_ne_garde_que_des_lignes_qui_existent` refuse une entrée dont le code n'a
## plus besoin.
const NON_ASSETS: Dictionary = {
	# Voisines d'une case de la grille du terrain : des directions, pas une case de feuille.
	"res://visuels/plan_decor.gd":
	[
		"for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:",
		"var nord: bool = terre.has(c + Vector2i(0, -1))",
		"var est: bool = terre.has(c + Vector2i(1, 0))",
		"var sud: bool = terre.has(c + Vector2i(0, 1))",
		"var ouest: bool = terre.has(c + Vector2i(-1, 0))",
	],
	# Images que le jeu dessine lui-même (traits, losanges, anneau) : leur taille n'est celle d'aucun
	# fichier.
	"res://visuels/formes_effets.gd":
	[
		'var taille := Vector2i(64, 8) if nom.begins_with("trait") else Vector2i(32, 32)',
		"taille = Vector2i(64, 64)",
	],
	# Boîte minimale d'un sprite entièrement transparent : un pixel, pas une région de feuille.
	"res://visuels/apparence.gd": ["boite = Rect2i(0, 0, 1, 1)"],
	# Zone libre de la caméra avant la première mise en page : des pixels d'écran.
	"res://visuels/camera_arene.gd": ["var _libre: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)"],
}


static func _fichiers(dossier: String) -> PackedStringArray:
	var liste := PackedStringArray()
	for sous: String in DirAccess.get_directories_at(dossier):
		liste.append_array(_fichiers(dossier.path_join(sous)))
	for fichier: String in DirAccess.get_files_at(dossier):
		if fichier.get_extension() == "gd":
			liste.append(dossier.path_join(fichier))
	return liste


## Les lignes (espaces de bord retirés) qui écrivent une géométrie ou un chemin d'asset : une
## constante de haut niveau qui est un chemin d'image ou de son, une `Rect2`, un `Vector2i` de
## nombres ; et, où que ce soit (dictionnaire rendu par une fonction, argument, retour), un
## `Vector2i(a, b)` ou un `Rect2(a, b, c, d)` dont tous les nombres sont écrits. Un
## `Vector2i(a, b)` calculé n'en est pas un. Les commentaires ne comptent pas.
static func lignes_en_dur(source: String) -> PackedStringArray:
	var trouvees := PackedStringArray()
	var constante := RegEx.create_from_string(
		(
			"^const [A-Z][A-Z0-9_]*(: [A-Za-z0-9]+)? ?:?= ?"
			+ '(Rect2i?\\(|Vector2i\\(\\s*[0-9]|"[^"]*\\.(png|ogg|svg|webp|wav)")'
		)
	)
	var nombre := "-?[0-9]+(\\.[0-9]+)?"
	var ecrite := RegEx.create_from_string(
		(
			"Rect2i?\\(\\s*%s(\\s*,\\s*%s){3}\\s*\\)" % [nombre, nombre]
			+ "|Vector2i\\(\\s*%s\\s*,\\s*%s\\s*\\)" % [nombre, nombre]
		)
	)
	for ligne: String in source.split("\n"):
		var texte := ligne.strip_edges()
		if texte.begins_with("#"):
			continue
		if constante.search(ligne) != null or ecrite.search(texte) != null:
			trouvees.append(texte)
	return trouvees


func test_aucune_geometrie_d_asset_en_dur() -> void:
	for dossier: String in DOSSIERS:
		for chemin: String in _fichiers(dossier):
			var permises: Array = NON_ASSETS.get(chemin, [])
			var fautives := PackedStringArray()
			for ligne: String in lignes_en_dur(FileAccess.get_file_as_string(chemin)):
				if not permises.has(ligne):
					fautives.append(ligne)
			verifier_egal(fautives, PackedStringArray(), "géométrie en dur dans " + chemin)


func test_la_garde_voit_une_geometrie_en_dur() -> void:
	var fautif := (
		"const CASE := Vector2i(192, 192)\nconst REGION := Rect2(1.0, 2.0, 3.0, 4.0)\n"
		+ 'const FEUILLE := "Effects/Fire/Fire.png"\nconst SON := "res://a.ogg"\n'
	)
	verifier_egal(lignes_en_dur(fautif).size(), 4)
	var sain := 'const NB: int = 4\nconst NOM := "tir"\nconst T := Vector2i(a, b)\n'
	verifier_egal(lignes_en_dur(sain).size(), 0)


func test_la_garde_voit_une_case_dans_une_fonction_et_pas_un_calcul() -> void:
	var fautif := (
		'func planches() -> Dictionary:\n\treturn {"boule_feu": Vector2i(16, 16)}\n'
		+ "func region() -> Rect2:\n\treturn Rect2(0.0, 28.0, 63.0, 14.0)\n"
		+ "func decalage() -> Vector2i:\n\treturn Vector2i(-1, 0)\n"
	)
	verifier_egal(lignes_en_dur(fautif).size(), 3)
	var multiligne := 'func planches() -> Dictionary:\n\treturn {\n\t\t"a": Vector2i(12, 12),\n\t}\n'
	verifier_egal(lignes_en_dur(multiligne).size(), 1)
	var calcule := (
		"func a(x: int) -> Vector2i:\n\treturn Vector2i(x, x)\n"
		+ "func b(t: Vector2) -> Rect2:\n\treturn Rect2(0.0, 0.0, t.x, t.y)\n"
		+ "func c() -> Vector2i:\n\treturn Vector2i(TAILLE, 4)\n"
		+ "# Vector2i(16, 16) en commentaire\n"
	)
	verifier_egal(lignes_en_dur(calcule).size(), 0)


func test_la_liste_fermee_ne_garde_que_des_lignes_qui_existent() -> void:
	for chemin: String in NON_ASSETS:
		verifier(FileAccess.file_exists(chemin), chemin + " n'existe plus : à retirer de la liste")
		var presentes := lignes_en_dur(FileAccess.get_file_as_string(chemin))
		for ligne: String in NON_ASSETS[chemin]:
			verifier(
				presentes.has(ligne),
				"plus besoin de la liste fermée dans %s : %s" % [chemin, ligne]
			)


func test_chaque_feuille_d_unite_existe_et_contient_ses_cases() -> void:
	var u: Dictionary = Assets.typee("unites")
	var modeles: Dictionary = u["modeles"]
	var couleurs: Dictionary = {}
	for t: Variant in (u["entites"] as Dictionary).values():
		var e: Dictionary = t
		couleurs[String(e["modele"]) + "|" + String(e["couleur_pack"])] = e
	verifier(couleurs.size() > 0)
	for cle: String in couleurs:
		var e: Dictionary = couleurs[cle]
		var m: Dictionary = modeles[e["modele"]]
		var chemin := Apparence.chemin_feuille(String(e["modele"]), String(e["couleur_pack"]))
		verifier(ResourceLoader.exists(chemin), "feuille absente : " + chemin)
		var texture := load(chemin) as Texture2D
		verifier_non_nul(texture, chemin)
		if texture == null:
			continue
		var case_px: Vector2i = m["case"]
		var colonnes: int = m["colonnes"]
		var lignes: int = m["lignes"]
		verifier(texture.get_width() >= colonnes * case_px.x, "largeur de " + chemin)
		verifier(texture.get_height() >= lignes * case_px.y, "hauteur de " + chemin)
		for anim: String in ["repos", "course", "attaque", "attaque_bas", "attaque_haut"]:
			var a: Vector2i = m[anim]
			verifier(a.x < lignes and a.y <= colonnes, "animation %s de %s" % [anim, chemin])
		verifier(float(m["pieds"]) <= float(case_px.y), "pieds hors de la case : " + chemin)


func test_chaque_objet_du_decor_existe_et_sa_boite_tient_dans_sa_cellule() -> void:
	var types: Dictionary = Assets.typee("decor")["types"]
	verifier(types.size() > 0)
	for id: String in types:
		var t: Dictionary = types[id]
		var chemin: String = Apparence.RACINE + String(t["fichier"])
		verifier(ResourceLoader.exists(chemin), "image absente : " + chemin)
		var texture := load(chemin) as Texture2D
		if texture == null:
			continue
		var cellule: Vector2i = t["cellule"]
		var origine: Vector2i = t["origine"]
		var images: int = t["images"]
		var ligne: int = t["ligne"]
		verifier(texture.get_width() >= origine.x + images * cellule.x, id + " : largeur")
		verifier(texture.get_height() >= origine.y + (ligne + 1) * cellule.y, id + " : hauteur")
		var boite: Rect2 = t["boite"]
		verifier(Rect2(Vector2.ZERO, Vector2(cellule)).encloses(boite), id + " : boîte")
		var pieds: Vector2 = t["pieds"]
		verifier(Rect2(Vector2.ZERO, Vector2(cellule)).has_point(pieds), id + " : pieds")


func test_chaque_son_decrit_est_celui_du_catalogue() -> void:
	verifier_egal(CatalogueSons.liste_ids_armes.size(), 75)
	verifier_egal(CatalogueSons.liste_suffixes_impact.size(), 5)
	verifier(CatalogueSons.dossier.begins_with("res://"))
	verifier(CatalogueSons.extension.begins_with("."))


func test_un_sprite_remplace_par_une_autre_taille_s_affiche_avec_la_nouvelle_case() -> void:
	var avant: Dictionary = Apparence.modeles.duplicate(true)
	var modele: Dictionary = (Apparence.modeles["torch"] as Dictionary).duplicate(true)
	modele["case"] = Vector2i(256, 160)
	modele["colonnes"] = 5
	modele["pieds"] = 140.0
	Apparence.modeles["torch"] = modele
	Apparence._entrees.clear()
	var entree: Dictionary = Apparence.entree("torche_jaune")
	verifier_egal(entree["case"], Vector2i(256, 160))
	verifier_egal(entree["colonnes"], 5)
	verifier_egal(entree["pieds"], 140.0)
	Apparence.modeles = avant
	Apparence._entrees.clear()
	var apres: Dictionary = Apparence.entree("torche_jaune")
	verifier_egal(apres["case"], Vector2i(192, 192))


func test_les_valeurs_du_fichier_sont_celles_des_tables() -> void:
	var u: Dictionary = Assets.typee("unites")
	verifier_egal(Apparence.modeles, u["modeles"])
	verifier_egal(Apparence.entites, u["entites"])
	verifier_egal(Apparence.allies, u["allies"])
	verifier_egal(Apparence.mort, u["mort"])
	verifier_egal(PlanDecor.types, Assets.typee("decor")["types"])
	verifier_egal(Apparence.tour_echelle, 2.1)
	verifier_egal(Apparence.tours_pack.size(), 4)
	verifier_egal(Apparence.teintes_calculees.size(), 4)


func test_chaque_planche_maison_decrite_existe_et_contient_ses_images() -> void:
	var cases: Dictionary = PlanchesEffets.cases()
	verifier(cases.size() > 80, "planches décrites : %d" % cases.size())
	for nom: String in cases:
		var chemin: String = PlanchesEffets.chemin_planche(nom)
		verifier(ResourceLoader.exists(chemin), "planche absente : " + chemin)
		var texture := load(chemin) as Texture2D
		verifier_non_nul(texture, chemin)
		if texture == null:
			continue
		var case_px: Vector2i = cases[nom]
		verifier_egal(texture.get_width() % case_px.x, 0, "largeur multiple de la case : " + nom)
		verifier_egal(texture.get_height(), case_px.y, "hauteur égale à la case : " + nom)
		if PlanchesEffets.visibles().has(nom):
			var visible: float = PlanchesEffets.visibles()[nom]
			verifier(visible <= float(maxi(case_px.x, case_px.y)), "visible dans la case : " + nom)
		if PlanchesEffets.cadence_de(nom) > 0.0:
			verifier(texture.get_width() > case_px.x, "une planche animée a des images : " + nom)


func test_chaque_planche_d_un_element_est_decrite_ou_carree() -> void:
	for id: String in AttaquesElementaires.registre():
		var element: AttaqueElement = AttaquesElementaires.registre()[id]
		for nom: String in element.planches():
			var case_px: Vector2i = element.planches()[nom]
			verifier(case_px.x > 0 and case_px.y > 0, "%s : case de %s" % [id, nom])
			verifier(ResourceLoader.exists(PlanchesEffets.chemin_planche(nom)), id + " : " + nom)


func test_chaque_image_du_pack_existe_et_contient_ses_cases_et_ses_regions() -> void:
	for nom: String in ["feu", "explosion", "fleche", "dynamite"]:
		var donnees: Dictionary = PlanchesEffets.pack(nom)
		var chemin: String = PlanchesEffets.chemin_pack(nom)
		verifier(ResourceLoader.exists(chemin), "image du pack absente : " + chemin)
		var texture := load(chemin) as Texture2D
		verifier_non_nul(texture, chemin)
		if texture == null:
			continue
		if donnees.has("case"):
			var case_px: Vector2i = donnees["case"]
			var images: int = donnees["images"]
			verifier(texture.get_width() >= images * case_px.x, nom + " : largeur")
			verifier(texture.get_height() >= case_px.y, nom + " : hauteur")
			if donnees.has("visible"):
				verifier(float(donnees["visible"]) <= float(case_px.x), nom + " : visible")
			if donnees.has("pieds"):
				verifier(float(donnees["pieds"]) <= float(case_px.y), nom + " : pieds")
		if donnees.has("region"):
			var plein := Rect2(Vector2.ZERO, texture.get_size())
			verifier(plein.encloses(donnees["region"]), nom + " : région dans la texture")


func test_chaque_combinaison_de_voisines_a_sa_tuile_dans_la_feuille_du_terrain() -> void:
	var texture := load(Apparence.RACINE + PlanDecor.feuille_terrain) as Texture2D
	verifier_non_nul(texture, "feuille du terrain")
	var vues: Dictionary = {}
	for i: int in 16:
		var atlas: Vector2i = PlanDecor.tuile_pour(
			bool((i >> 3) & 1), bool((i >> 2) & 1), bool((i >> 1) & 1), bool(i & 1)
		)
		verifier(not vues.has(atlas), "tuile partagée par deux combinaisons : %s" % str(atlas))
		vues[atlas] = true
		if texture != null:
			verifier((atlas.x + 1) * Decor.taille_tuile <= texture.get_width(), "colonne")
			verifier((atlas.y + 1) * Decor.taille_tuile <= texture.get_height(), "ligne")


func test_une_planche_d_attaque_remplacee_par_une_autre_taille_s_affiche() -> void:
	var origine: Dictionary = Assets.tout().duplicate(true)
	var autre: Dictionary = origine.duplicate(true)
	var planches: Dictionary = ((autre["effets"] as Dictionary)["maison"] as Dictionary)["planches"]
	(planches["carreau"] as Dictionary)["case"] = {"largeur": 32, "hauteur": 16}
	Assets.remplacer(autre)
	var element := AttaqueArbalete.new()
	verifier_egal(element.planches()["carreau"], Vector2i(32, 16), "l'élément")
	verifier_egal(AttaquesElementaires.planches()["carreau"], Vector2i(32, 16), "la table")
	var moteur := AttaquesElementaires.new()
	arbre.root.add_child(moteur)
	var effet: Dictionary = moteur.nouveau("vol", "carreau", 1.0)
	verifier_egal((effet["n"] as Sprite2D).region_rect.size, Vector2(32.0, 16.0), "le sprite")
	moteur.free()
	Assets.remplacer(origine)
	verifier_egal(AttaquesElementaires.planches()["carreau"], Vector2i(16, 8), "rétabli")
	Assets.reinitialiser()
