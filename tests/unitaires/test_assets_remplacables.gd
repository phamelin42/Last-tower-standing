extends CasDeTest
## Assets remplaçables (Phil, 26/11/2026, T10.4) : changer un pack d'images ou de sons ne demande
## que de remplacer les fichiers et `data/assets.json`. Chemin, taille de case, nombre d'images,
## régions, ancrages, échelle et durée ne s'écrivent donc jamais en dur dans `visuels/`, `ui/` ou
## `sons/`, et chaque fichier décrit existe avec des dimensions qui contiennent ce qu'on en lit.

const DOSSIERS: Array[String] = ["res://visuels", "res://ui", "res://sons"]
## Liste fermée TEMPORAIRE : ce qui reste à migrer dans la partie 2 de T10.4 (effets d'attaque).
## Elle se vide, elle ne grossit jamais.
const A_MIGRER: Array[String] = [
	"res://visuels/effets.gd",
]
const DOSSIERS_A_MIGRER: Array[String] = ["res://visuels/attaques/"]


static func _fichiers(dossier: String) -> PackedStringArray:
	var liste := PackedStringArray()
	for sous: String in DirAccess.get_directories_at(dossier):
		liste.append_array(_fichiers(dossier.path_join(sous)))
	for fichier: String in DirAccess.get_files_at(dossier):
		if fichier.get_extension() == "gd":
			liste.append(dossier.path_join(fichier))
	return liste


static func _a_migrer(chemin: String) -> bool:
	if A_MIGRER.has(chemin):
		return true
	for d: String in DOSSIERS_A_MIGRER:
		if chemin.begins_with(d):
			return true
	return false


## Les lignes d'une constante de haut niveau qui écrit une géométrie ou un chemin d'asset :
## un chemin d'image ou de son, une `Rect2`, un `Vector2i` de nombres.
static func geometries_en_dur(source: String) -> PackedStringArray:
	var trouvees := PackedStringArray()
	var regex := RegEx.new()
	regex.compile(
		(
			"^const [A-Z][A-Z0-9_]*(: [A-Za-z0-9]+)? ?:?= ?"
			+ '(Rect2i?\\(|Vector2i\\(\\s*[0-9]|"[^"]*\\.(png|ogg|svg|webp|wav)")'
		)
	)
	var lignes := source.split("\n")
	for i: int in lignes.size():
		if regex.search(lignes[i]) != null:
			trouvees.append("ligne %d : %s" % [i + 1, lignes[i].strip_edges()])
	return trouvees


func test_aucune_geometrie_d_asset_en_dur() -> void:
	for dossier: String in DOSSIERS:
		for chemin: String in _fichiers(dossier):
			if _a_migrer(chemin):
				continue
			var source := FileAccess.get_file_as_string(chemin)
			verifier_egal(
				geometries_en_dur(source), PackedStringArray(), "géométrie en dur dans " + chemin
			)


func test_la_garde_voit_une_geometrie_en_dur() -> void:
	var fautif := (
		"const CASE := Vector2i(192, 192)\nconst REGION := Rect2(1.0, 2.0, 3.0, 4.0)\n"
		+ 'const FEUILLE := "Effects/Fire/Fire.png"\nconst SON := "res://a.ogg"\n'
	)
	verifier_egal(geometries_en_dur(fautif).size(), 4)
	var sain := 'const NB: int = 4\nconst NOM := "tir"\nconst T := Vector2i(a, b)\n'
	verifier_egal(geometries_en_dur(sain).size(), 0)


func test_la_liste_fermee_ne_garde_que_des_fichiers_qui_en_ont_besoin() -> void:
	for chemin: String in A_MIGRER:
		verifier(FileAccess.file_exists(chemin), chemin + " n'existe plus : à retirer de la liste")
		verifier(
			not geometries_en_dur(FileAccess.get_file_as_string(chemin)).is_empty(),
			chemin + " est migré : à retirer de la liste fermée"
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
	verifier_egal(CatalogueSons.IDS_ARMES.size(), 75)
	verifier_egal(CatalogueSons.SUFFIXES_IMPACT.size(), 5)
	verifier(CatalogueSons.DOSSIER.begins_with("res://"))
	verifier(CatalogueSons.EXTENSION.begins_with("."))


func test_un_sprite_remplace_par_une_autre_taille_s_affiche_avec_la_nouvelle_case() -> void:
	var avant: Dictionary = Apparence.MODELES.duplicate(true)
	var modele: Dictionary = (Apparence.MODELES["torch"] as Dictionary).duplicate(true)
	modele["case"] = Vector2i(256, 160)
	modele["colonnes"] = 5
	modele["pieds"] = 140.0
	Apparence.MODELES["torch"] = modele
	Apparence._entrees.clear()
	var entree: Dictionary = Apparence.entree("torche_jaune")
	verifier_egal(entree["case"], Vector2i(256, 160))
	verifier_egal(entree["colonnes"], 5)
	verifier_egal(entree["pieds"], 140.0)
	Apparence.MODELES = avant
	Apparence._entrees.clear()
	var apres: Dictionary = Apparence.entree("torche_jaune")
	verifier_egal(apres["case"], Vector2i(192, 192))


func test_les_valeurs_du_fichier_sont_celles_des_tables() -> void:
	var u: Dictionary = Assets.typee("unites")
	verifier_egal(Apparence.MODELES, u["modeles"])
	verifier_egal(Apparence.ENTITES, u["entites"])
	verifier_egal(Apparence.ALLIES, u["allies"])
	verifier_egal(Apparence.MORT, u["mort"])
	verifier_egal(PlanDecor.TYPES, Assets.typee("decor")["types"])
	verifier_egal(Apparence.TOUR_ECHELLE, 2.1)
	verifier_egal(Apparence.TOURS_PACK.size(), 4)
	verifier_egal(Apparence.TEINTES_CALCULEES.size(), 4)
