extends CasDeTest
## Ce que le joueur voit : chaque famille, chaque convoi, le boss, chaque type de dégâts, chaque
## rareté et chaque armure a une apparence distincte, faite de primitives Godot intégrées. Une
## rareté se lit sans sa couleur (symbole et libellé), et deux familles d'armures différentes se
## distinguent par la forme en plus de la couleur. Les listes viennent des données réelles : un
## ennemi ajouté sans apparence fait échouer ce test.

const PRIMITIVES: Array[String] = [
	"BoxMesh", "CylinderMesh", "SphereMesh", "CapsuleMesh", "PrismMesh", "TorusMesh"
]
const NB_ARMURES := 6
const NB_RARETES := 4
const NB_TYPES := 5
## Garde : seul `visuels/apparence.gd` crée des primitives et des matériaux. Lit chaque `.gd` du
## projet (hors `tests/` et dossiers cachés, comme `.claude/` qui abrite les worktrees).
const CREATIONS_INTERDITES: Array[String] = [
	"StandardMaterial3D.new",
	"BoxMesh.new",
	"CylinderMesh.new",
	"SphereMesh.new",
	"CapsuleMesh.new",
	"PrismMesh.new",
	"TorusMesh.new",
	"PlaneMesh.new",
	"QuadMesh.new",
]
const FICHIER_AUTORISE := "res://visuels/apparence.gd"


func _donnees() -> Donnees:
	var d := Donnees.charger()
	verifier_non_nul(d, "les données réelles doivent se charger")
	return d


func _luminance_relative(c: Color) -> float:
	return (
		0.2126 * _canal_lineaire(c.r)
		+ 0.7152 * _canal_lineaire(c.g)
		+ 0.0722 * _canal_lineaire(c.b)
	)


## Formule WCAG 2.x : composante sRGB linéarisée.
func _canal_lineaire(canal: float) -> float:
	if canal <= 0.03928:
		return canal / 12.92
	return pow((canal + 0.055) / 1.055, 2.4)


func _contraste(a: Color, b: Color) -> float:
	var la := _luminance_relative(a)
	var lb := _luminance_relative(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func test_position_monde_convertit_les_unites_de_jeu_en_metres() -> void:
	var p := Apparence.position_monde(Vector2(1300, 0))
	verifier_proche(p.x, 26.0, 0.0001, "1300 unités doivent faire 26 m")
	verifier_proche(p.y, 0.0, 0.0001, "au sol, la hauteur est nulle")
	verifier_proche(p.z, 0.0, 0.0001)
	var haut := Apparence.position_monde(Vector2(0, 1300), 1.5)
	verifier_proche(haut.x, 0.0, 0.0001)
	verifier_proche(haut.y, 1.5, 0.0001, "la hauteur passée est reprise telle quelle")
	verifier_proche(haut.z, 26.0, 0.0001, "l'axe y du plan devient z en 3D")


func test_chaque_famille_convoi_et_boss_ont_une_primitive_et_un_materiau() -> void:
	var d := _donnees()
	if d == null:
		return
	# Familles, puis le convoi, puis le boss.
	for i: int in range(d.familles.size() + 2):
		var maillage := Apparence.maillage_famille(i)
		verifier_non_nul(maillage, "entité %d sans maillage" % i)
		verifier(
			maillage.get_class() in PRIMITIVES,
			"entité %d : %s n'est pas une primitive" % [i, maillage.get_class()]
		)
		var materiau := Apparence.materiau_famille(i)
		verifier_non_nul(materiau, "entité %d sans matériau" % i)
		verifier(materiau is StandardMaterial3D, "entité %d : matériau non standard" % i)


func test_les_maillages_et_materiaux_sont_integres_sans_ressource_externe() -> void:
	var d := _donnees()
	if d == null:
		return
	var maillages: Array[Mesh] = [Apparence.maillage_tour(), Apparence.forme_projectile(0)]
	for i: int in range(d.familles.size() + 2):
		maillages.append(Apparence.maillage_famille(i))
	for m: Mesh in maillages:
		verifier(m.get_class() in PRIMITIVES, "%s n'est pas une primitive intégrée" % m.get_class())
		verifier(m.resource_path.is_empty(), "maillage issu d'un fichier : %s" % m.resource_path)
	var materiaux: Array[StandardMaterial3D] = [Apparence.materiau_tour()]
	for i: int in range(d.familles.size() + 2):
		materiaux.append(Apparence.materiau_famille(i))
	for mat: StandardMaterial3D in materiaux:
		verifier(
			mat.resource_path.is_empty(), "matériau issu d'un fichier : %s" % mat.resource_path
		)


func test_la_tour_a_un_maillage_et_un_materiau() -> void:
	verifier(Apparence.maillage_tour().get_class() in PRIMITIVES, "la tour doit être une primitive")
	verifier(
		Apparence.materiau_tour() is StandardMaterial3D, "la tour doit avoir un matériau standard"
	)


func test_chaque_type_de_degats_a_une_couleur_et_un_projectile() -> void:
	for t: int in range(NB_TYPES):
		verifier_non_nul(Apparence.forme_projectile(t), "type %d sans projectile" % t)
		verifier(
			Apparence.forme_projectile(t).get_class() in PRIMITIVES,
			"type %d : projectile non primitif" % t
		)
		var c := Apparence.couleur_type(t)
		verifier(c.a > 0.0, "type %d : couleur transparente" % t)


func test_les_types_de_degats_ont_des_couleurs_distinctes() -> void:
	for a: int in range(NB_TYPES):
		for b: int in range(a + 1, NB_TYPES):
			verifier_different(
				Apparence.couleur_type(a),
				Apparence.couleur_type(b),
				"types %d et %d de même couleur" % [a, b]
			)


func test_chaque_rarete_a_un_symbole_un_libelle_et_une_couleur() -> void:
	for r: int in range(NB_RARETES):
		verifier(not Apparence.symbole_rarete(r).is_empty(), "rareté %d sans symbole" % r)
		verifier(
			not Apparence.cle_libelle_rarete(r).is_empty(), "rareté %d sans libellé traduisible" % r
		)
		verifier(Apparence.couleur_rarete(r).a > 0.0, "rareté %d : couleur transparente" % r)


func test_deux_raretes_ne_partagent_ni_symbole_ni_couleur_ni_libelle() -> void:
	for a: int in range(NB_RARETES):
		for b: int in range(a + 1, NB_RARETES):
			verifier_different(
				Apparence.symbole_rarete(a),
				Apparence.symbole_rarete(b),
				"raretés %d et %d : même symbole" % [a, b]
			)
			verifier_different(
				Apparence.couleur_rarete(a),
				Apparence.couleur_rarete(b),
				"raretés %d et %d : même couleur" % [a, b]
			)
			verifier_different(
				Apparence.cle_libelle_rarete(a),
				Apparence.cle_libelle_rarete(b),
				"raretés %d et %d : même libellé" % [a, b]
			)


func test_le_texte_de_chaque_rarete_tient_4_5_sur_le_fond_d_interface() -> void:
	for r: int in range(NB_RARETES):
		var contraste := _contraste(Apparence.couleur_rarete(r), Apparence.FOND_INTERFACE)
		verifier(contraste >= 4.5, "rareté %d : contraste %.2f:1 sous 4,5:1" % [r, contraste])


func test_chaque_armure_a_une_couleur_un_symbole_une_forme_et_un_libelle() -> void:
	for a: int in range(NB_ARMURES):
		verifier(not Apparence.symbole_armure(a).is_empty(), "armure %d sans symbole" % a)
		verifier(
			not Apparence.cle_libelle_armure(a).is_empty(), "armure %d sans libellé traduisible" % a
		)
		verifier(
			Apparence.forme_armure(a).get_class() in PRIMITIVES,
			"armure %d : forme non primitive" % a
		)
		verifier(Apparence.couleur_armure(a).a > 0.0, "armure %d : couleur transparente" % a)


func test_deux_armures_differentes_se_distinguent_par_couleur_et_forme() -> void:
	for a: int in range(NB_ARMURES):
		for b: int in range(a + 1, NB_ARMURES):
			verifier_different(
				Apparence.couleur_armure(a),
				Apparence.couleur_armure(b),
				"armures %d et %d : même couleur" % [a, b]
			)
			verifier_different(
				Apparence.forme_armure(a).get_class(),
				Apparence.forme_armure(b).get_class(),
				"armures %d et %d : même forme" % [a, b]
			)
			verifier_different(
				Apparence.symbole_armure(a),
				Apparence.symbole_armure(b),
				"armures %d et %d : même symbole" % [a, b]
			)


func test_deux_familles_d_armures_differentes_se_distinguent_a_l_ecran() -> void:
	var d := _donnees()
	if d == null:
		return
	for i: int in range(d.familles.size()):
		for j: int in range(i + 1, d.familles.size()):
			var ai: int = d.familles[i]["armure"]
			var aj: int = d.familles[j]["armure"]
			if ai == aj:
				continue
			verifier_different(
				Apparence.materiau_famille(i).albedo_color,
				Apparence.materiau_famille(j).albedo_color,
				"familles %d et %d d'armures différentes, même couleur" % [i, j]
			)
			verifier_different(
				Apparence.maillage_famille(i).get_class(),
				Apparence.maillage_famille(j).get_class(),
				"familles %d et %d d'armures différentes, même forme" % [i, j]
			)


func test_un_volant_flotte_et_un_marcheur_reste_au_sol() -> void:
	var d := _donnees()
	if d == null:
		return
	var volant_vu := false
	for i: int in range(d.familles.size()):
		var hauteur := Apparence.hauteur_famille(i)
		if d.familles[i]["volant"]:
			volant_vu = true
			verifier(hauteur > 0.0, "famille %d volante posée au sol" % i)
		else:
			verifier_proche(hauteur, 0.0, 0.0001, "famille %d marcheuse au-dessus du sol" % i)
	verifier(volant_vu, "les données doivent contenir au moins un volant")
	verifier_proche(Apparence.hauteur_famille(d.familles.size()), 0.0, 0.0001, "convoi au sol")
	verifier_proche(Apparence.hauteur_famille(d.familles.size() + 1), 0.0, 0.0001, "boss au sol")


func test_les_maillages_et_materiaux_sont_partages_par_cache() -> void:
	var d := _donnees()
	if d == null:
		return
	for i: int in range(d.familles.size() + 2):
		verifier(
			is_same(Apparence.maillage_famille(i), Apparence.maillage_famille(i)),
			"entité %d : maillage recréé à chaque appel" % i
		)
		verifier(
			is_same(Apparence.materiau_famille(i), Apparence.materiau_famille(i)),
			"entité %d : matériau recréé à chaque appel" % i
		)
	verifier(
		is_same(Apparence.maillage_tour(), Apparence.maillage_tour()), "tour : maillage recréé"
	)
	verifier(
		is_same(Apparence.materiau_tour(), Apparence.materiau_tour()), "tour : matériau recréé"
	)
	verifier(
		is_same(Apparence.forme_projectile(2), Apparence.forme_projectile(2)),
		"projectile : forme recréée"
	)


func test_un_index_hors_bornes_recoit_une_primitive_de_repli() -> void:
	var d := _donnees()
	if d == null:
		return
	var hors: Array[int] = [-1, d.familles.size() + 2, 999]
	for i: int in hors:
		var maillage := Apparence.maillage_famille(i)
		verifier_non_nul(maillage, "index %d : maillage nul" % i)
		verifier(maillage.get_class() in PRIMITIVES, "index %d : repli non primitif" % i)
		verifier_non_nul(Apparence.materiau_famille(i), "index %d : matériau nul" % i)
		verifier_proche(Apparence.hauteur_famille(i), 0.0, 0.0001, "index %d : repli au sol" % i)
	verifier_non_nul(Apparence.forme_projectile(42), "type de dégâts inconnu : forme nulle")
	verifier_non_nul(Apparence.forme_armure(42), "armure inconnue : forme nulle")


func test_chaque_type_de_degats_a_un_materiau_de_projectile_de_sa_couleur() -> void:
	for t: int in range(NB_TYPES):
		var mat: StandardMaterial3D = Apparence.materiau_projectile(t)
		verifier_non_nul(mat, "type %d : matériau de projectile absent" % t)
		if mat == null:
			continue
		verifier_egal(
			mat.albedo_color,
			Apparence.couleur_type(t),
			"type %d : projectile d'une autre couleur que son type" % t
		)
		verifier_egal(
			mat.shading_mode,
			BaseMaterial3D.SHADING_MODE_UNSHADED,
			"type %d : projectile éclairé, il se perd sur la tour" % t
		)


func test_materiau_de_projectile_partage_par_cache() -> void:
	for t: int in range(NB_TYPES):
		verifier(
			is_same(Apparence.materiau_projectile(t), Apparence.materiau_projectile(t)),
			"type %d : matériau de projectile recréé" % t
		)


func test_l_impact_a_une_forme_d_anneau_partagee() -> void:
	verifier(Apparence.forme_impact().get_class() in PRIMITIVES, "impact : forme non primitive")
	verifier(is_same(Apparence.forme_impact(), Apparence.forme_impact()), "impact : forme recréée")


func test_l_impact_et_la_mort_ont_un_materiau_visible_partage() -> void:
	var impact: StandardMaterial3D = Apparence.materiau_impact()
	var mort: StandardMaterial3D = Apparence.materiau_mort()
	verifier_non_nul(impact, "impact : matériau absent")
	verifier_non_nul(mort, "mort : matériau absent")
	if impact != null:
		verifier(impact.albedo_color.a > 0.0, "impact : couleur transparente")
		verifier(is_same(impact, Apparence.materiau_impact()), "impact : matériau recréé")
	if mort != null:
		verifier(mort.albedo_color.a > 0.0, "mort : couleur transparente")
		verifier(is_same(mort, Apparence.materiau_mort()), "mort : matériau recréé")


func test_le_sol_est_un_plan_carre_de_80_metres_partage() -> void:
	var plan := Apparence.maillage_sol() as PlaneMesh
	verifier_non_nul(plan, "sol : maillage absent ou non plan")
	if plan != null:
		verifier_egal(plan.size, Vector2.ONE * Apparence.COTE_SOL, "sol : taille inattendue")
	verifier(is_same(Apparence.maillage_sol(), Apparence.maillage_sol()), "sol : maillage recréé")


func test_le_sol_est_un_damier_de_deux_teintes_qui_alternent() -> void:
	var mat := Apparence.materiau_sol()
	verifier_non_nul(mat, "sol : matériau absent")
	if mat == null:
		return
	var texture := mat.albedo_texture as ImageTexture
	verifier_non_nul(texture, "sol : pas de damier (texture absente)")
	if texture == null:
		return
	var image := texture.get_image()
	verifier_egal(image.get_width(), 2, "damier : 2 cases de côté attendues")
	verifier_egal(
		image.get_pixel(0, 0), image.get_pixel(1, 1), "damier : cases diagonales différentes"
	)
	verifier_egal(image.get_pixel(1, 0), image.get_pixel(0, 1), "damier : cases voisines pareilles")
	verifier_different(image.get_pixel(0, 0), image.get_pixel(1, 0), "damier : aucune alternance")
	verifier_egal(mat.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST, "damier : flou")
	verifier_proche(
		mat.uv1_scale.x,
		Apparence.COTE_SOL / Apparence.COTE_CASE / 2.0,
		0.0001,
		"damier : échelle de répétition modifiée"
	)


func test_le_materiau_du_sol_partage_par_cache() -> void:
	verifier(is_same(Apparence.materiau_sol(), Apparence.materiau_sol()), "sol : matériau recréé")


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
			if not nom.begins_with(".") and chemin != "res://tests":
				_lister_gd(chemin, sortie)
		elif nom.get_extension() == "gd":
			sortie.append(chemin)
		nom = acces.get_next()
	acces.list_dir_end()


func test_seul_apparence_cree_primitives_et_materiaux() -> void:
	var fichiers: Array[String] = []
	_lister_gd("res://", fichiers)
	verifier(fichiers.size() > 10, "garde : trop peu de .gd lus (%d)" % fichiers.size())
	var fautifs: Array[String] = []
	for chemin: String in fichiers:
		if chemin == FICHIER_AUTORISE:
			continue
		var source := FileAccess.get_file_as_string(chemin)
		for creation: String in CREATIONS_INTERDITES:
			if source.contains(creation):
				fautifs.append("%s (%s)" % [chemin, creation])
	verifier(
		fautifs.is_empty(),
		(
			"création de primitive ou de matériau hors d'Apparence : %s"
			% "; ".join(PackedStringArray(fautifs))
		)
	)
