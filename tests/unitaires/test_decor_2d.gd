extends CasDeTest
## Ce que la joueuse voit autour de l'arène : un sol en tuiles du pack, un décor qui encadre le
## cercle sans jamais le recouvrir, une disposition propre à chaque arène et stable pendant la
## partie, le tout dessiné sous les ennemis.

const SCENE := "res://scenes/arene_2d.tscn"
const GRAINES: Array[int] = [1, 2, 3, 7, 42, 99, 1234, 20261125, 987654321, -5, 0, 31337]
const RACINE := "res://assets/tiny_swords/"

var _arene: Arene2D = null


func apres_chaque() -> void:
	if is_instance_valid(_arene):
		if _arene.get_parent() != null:
			_arene.get_parent().remove_child(_arene)
		_arene.free()
	_arene = null


func _instancier() -> Arene2D:
	var arene := (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(arene)
	return arene


func _signature(plan: PlanDecor2D) -> String:
	var morceaux := PackedStringArray()
	for o: Dictionary in plan.objets:
		morceaux.append(
			"%s@%.1f,%.1f" % [o["type"], (o["pieds"] as Vector2).x, (o["pieds"] as Vector2).y]
		)
	morceaux.append(str(plan.terre.size()))
	return "|".join(morceaux)


func test_chaque_texture_citee_existe() -> void:
	var fichiers: Array[String] = [PlanDecor2D.FEUILLE_TERRAIN, PlanDecor2D.FEUILLE_EAU]
	fichiers.append(PlanDecor2D.FEUILLE_ECUME)
	for type: String in PlanDecor2D.TYPES:
		fichiers.append(String((PlanDecor2D.TYPES[type] as Dictionary)["fichier"]))
	verifier(PlanDecor2D.TYPES.size() >= 25, "catalogue trop court : %d" % PlanDecor2D.TYPES.size())
	for f: String in fichiers:
		verifier(ResourceLoader.exists(RACINE + f), "texture absente : %s" % f)
		verifier(load(RACINE + f) is Texture2D, "texture illisible : %s" % f)


func test_chaque_type_decrit_une_image_contenue_dans_sa_feuille() -> void:
	for type: String in PlanDecor2D.TYPES:
		var t: Dictionary = PlanDecor2D.TYPES[type]
		var texture := load(RACINE + String(t["fichier"])) as Texture2D
		var cellule: Vector2i = t["cellule"]
		var origine: Vector2i = t["origine"]
		var images: int = t["images"]
		var feuille := Rect2(Vector2.ZERO, Vector2(texture.get_size()))
		var zone := Rect2(
			Vector2(origine) + Vector2(0, float(t["ligne"]) * cellule.y),
			Vector2(cellule.x * images, cellule.y)
		)
		verifier(feuille.encloses(zone), "%s : images hors de la feuille" % type)
		var boite: Rect2 = t["boite"]
		verifier(
			Rect2(Vector2.ZERO, Vector2(cellule)).encloses(boite), "%s : boîte hors case" % type
		)
		verifier(
			boite.has_point(t["pieds"]) or boite.grow(4.0).has_point(t["pieds"]),
			"%s : pieds" % type
		)


func test_les_16_voisinages_ont_chacun_leur_tuile_de_bord() -> void:
	var vues: Dictionary = {}
	for masque: int in 16:
		var n: bool = masque & 1 != 0
		var e: bool = masque & 2 != 0
		var s: bool = masque & 4 != 0
		var w: bool = masque & 8 != 0
		var atlas: Vector2i = PlanDecor2D.tuile_pour(n, e, s, w)
		verifier(atlas.x >= 0 and atlas.x <= 3 and atlas.y >= 0 and atlas.y <= 3, "hors herbe")
		verifier(not vues.has(atlas), "tuile %s utilisée deux fois" % atlas)
		vues[atlas] = true
	# Les cas que la joueuse reconnaît : l'intérieur, les quatre côtés, les quatre coins.
	verifier_egal(PlanDecor2D.tuile_pour(true, true, true, true), Vector2i(1, 1), "intérieur")
	verifier_egal(PlanDecor2D.tuile_pour(false, true, true, true), Vector2i(1, 0), "bord haut")
	verifier_egal(PlanDecor2D.tuile_pour(true, true, false, true), Vector2i(1, 2), "bord bas")
	verifier_egal(PlanDecor2D.tuile_pour(true, false, true, true), Vector2i(2, 1), "bord droit")
	verifier_egal(PlanDecor2D.tuile_pour(true, true, true, false), Vector2i(0, 1), "bord gauche")
	verifier_egal(
		PlanDecor2D.tuile_pour(false, true, true, false), Vector2i(0, 0), "coin haut gauche"
	)
	verifier_egal(
		PlanDecor2D.tuile_pour(false, false, true, true), Vector2i(2, 0), "coin haut droit"
	)
	verifier_egal(
		PlanDecor2D.tuile_pour(true, true, false, false), Vector2i(0, 2), "coin bas gauche"
	)
	verifier_egal(
		PlanDecor2D.tuile_pour(true, false, false, true), Vector2i(2, 2), "coin bas droit"
	)


func test_chaque_tuile_pose_correspond_a_ses_voisines() -> void:
	for graine: int in GRAINES:
		var plan := PlanDecor2D.generer(graine)
		verifier(plan.tuiles.size() > 200, "graine %d : trop peu de tuiles" % graine)
		verifier_egal(plan.tuiles.size(), plan.terre.size(), "une tuile par case de terre")
		for tuile: Dictionary in plan.tuiles:
			var c: Vector2i = tuile["cellule"]
			var attendu := PlanDecor2D.tuile_pour(
				plan.terre.has(c + Vector2i(0, -1)),
				plan.terre.has(c + Vector2i(1, 0)),
				plan.terre.has(c + Vector2i(0, 1)),
				plan.terre.has(c + Vector2i(-1, 0))
			)
			verifier_egal(tuile["atlas"], attendu, "graine %d, case %s" % [graine, c])
			if attendu != Vector2i(1, 1):
				verifier_egal(int(tuile["retournement"]), 0, "un bord ne se retourne jamais")


func test_le_sol_de_marche_est_entierement_de_l_herbe_sans_bord() -> void:
	for graine: int in GRAINES:
		var plan := PlanDecor2D.generer(graine)
		var rayon: float = PlanDecor2D.RAYON_ZONE + float(PlanDecor2D.CASE)
		var cases: int = ceili(rayon / float(PlanDecor2D.CASE)) + 1
		for j: int in range(-cases, cases + 1):
			for i: int in range(-cases, cases + 1):
				var centre := (Vector2(i, j) + Vector2(0.5, 0.5)) * float(PlanDecor2D.CASE)
				if centre.length() <= rayon:
					verifier(
						plan.terre.has(Vector2i(i, j)), "graine %d : trou en %s" % [graine, centre]
					)
					var voisines: bool = true
					for d: Vector2i in [
						Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)
					]:
						voisines = voisines and plan.terre.has(Vector2i(i, j) + d)
					verifier(
						voisines, "graine %d : bord dans la zone de marche en %s" % [graine, centre]
					)


func test_aucun_objet_haut_dans_la_zone_de_marche_ni_sur_le_cercle() -> void:
	for graine: int in GRAINES:
		var plan := PlanDecor2D.generer(graine)
		var hauts: int = 0
		for o: Dictionary in plan.objets:
			if not bool(o["haut"]):
				continue
			hauts += 1
			var rect: Rect2 = o["rect"]
			verifier_faux(
				PlanDecor2D.touche_la_zone(rect),
				"graine %d : %s en %s gêne la zone de marche" % [graine, o["type"], o["pieds"]]
			)
			var pieds: Vector2 = o["pieds"]
			verifier(
				pieds.length() > PlanDecor2D.RAYON_CERCLE + 1.0,
				"graine %d : pied dans le cercle" % graine
			)
		verifier(hauts >= 80, "graine %d : seulement %d objets hauts" % [graine, hauts])


func test_la_zone_de_marche_ne_garde_que_du_decor_plat() -> void:
	for graine: int in GRAINES:
		var plan := PlanDecor2D.generer(graine)
		var plats: int = 0
		for o: Dictionary in plan.objets:
			var pieds: Vector2 = o["pieds"]
			if pieds.length() <= PlanDecor2D.RAYON_ZONE and not bool(o["eau"]):
				verifier_faux(
					bool(o["haut"]), "graine %d : %s haut dans la zone" % [graine, o["type"]]
				)
				plats += 1
				# Le cercle et la tour restent nets.
				verifier(
					pieds.length() > PlanDecor2D.RAYON_TOUR_LIBRE,
					"graine %d : sur la tour" % graine
				)
				verifier(
					(
						absf(pieds.length() - PlanDecor2D.RAYON_CERCLE)
						> PlanDecor2D.LARGEUR_CERCLE_LIBRE
					),
					"graine %d : sur le trait du cercle" % graine
				)
		verifier(plats >= 60, "graine %d : zone vide (%d éléments plats)" % [graine, plats])


func test_chaque_categorie_de_decor_demandee_est_presente() -> void:
	var exigences: Dictionary = {
		"sapin": 30, "maison": 1, "mine": 1, "mouton": 3, "buisson": 5, "rocher": 3, "plat": 40
	}
	for graine: int in GRAINES:
		var plan := PlanDecor2D.generer(graine)
		var compte: Dictionary = {}
		for o: Dictionary in plan.objets:
			var categorie: String = (PlanDecor2D.TYPES[o["type"]] as Dictionary)["categorie"]
			compte[categorie] = int(compte.get(categorie, 0)) + 1
		for categorie: String in exigences:
			verifier(
				int(compte.get(categorie, 0)) >= int(exigences[categorie]),
				"graine %d : %d « %s »" % [graine, int(compte.get(categorie, 0)), categorie]
			)
		verifier(
			plan.ecume.size() >= 20, "graine %d : pas d'écume (%d)" % [graine, plan.ecume.size()]
		)
		verifier(compte.get("eau", 0) >= 2, "graine %d : pas de rochers d'eau" % graine)


func test_les_objets_reposent_sur_la_terre_et_les_rochers_d_eau_sur_l_eau() -> void:
	for graine: int in GRAINES:
		var plan := PlanDecor2D.generer(graine)
		for o: Dictionary in plan.objets:
			var pieds: Vector2 = o["pieds"]
			var cellule := Vector2i(
				floori(pieds.x / PlanDecor2D.CASE), floori(pieds.y / PlanDecor2D.CASE)
			)
			if bool(o["eau"]):
				verifier_faux(
					plan.terre.has(cellule), "graine %d : rocher d'eau sur la terre" % graine
				)
			else:
				verifier(plan.terre.has(cellule), "graine %d : %s dans l'eau" % [graine, o["type"]])


func test_meme_graine_meme_disposition_et_graines_differentes_dispositions_differentes() -> void:
	var vues: Dictionary = {}
	for graine: int in GRAINES:
		var a := _signature(PlanDecor2D.generer(graine))
		var b := _signature(PlanDecor2D.generer(graine))
		verifier_egal(a, b, "graine %d : disposition instable" % graine)
		verifier_faux(vues.has(a), "graine %d : même disposition qu'une autre graine" % graine)
		vues[a] = graine


func test_deux_graines_donnent_des_dispositions_vraiment_differentes() -> void:
	# Pas seulement un objet de décalé : moins de la moitié des objets au même endroit.
	var a := PlanDecor2D.generer(1)
	var b := PlanDecor2D.generer(2)
	var positions: Dictionary = {}
	for o: Dictionary in a.objets:
		positions["%s@%s" % [o["type"], o["pieds"]]] = true
	var communs: int = 0
	for o: Dictionary in b.objets:
		if positions.has("%s@%s" % [o["type"], o["pieds"]]):
			communs += 1
	verifier(
		communs * 10 < b.objets.size(), "%d objets sur %d en commun" % [communs, b.objets.size()]
	)
	verifier(a.terre.size() != b.terre.size() or _signature(a) != _signature(b), "même rivage")


func test_chaque_joueur_a_son_decor_et_il_ne_change_pas_pendant_la_partie() -> void:
	_arene = _instancier()
	var vus: Dictionary = {}
	for numero: int in range(1, 9):
		_arene.definir_joueur(numero, "Joueur %d" % numero)
		var signature := _signature(_arene.plan_decor())
		verifier_faux(vus.has(signature), "joueur %d : même décor qu'un autre" % numero)
		vus[signature] = numero
	_arene.definir_joueur(3, "Joueur 3")
	var avant := _signature(_arene.plan_decor())
	for i: int in 30:
		_arene._process(0.1)
	_arene.definir_joueur(3, "Joueur 3 renommé")
	verifier_egal(_signature(_arene.plan_decor()), avant, "le décor bouge pendant la partie")
	# La même arène recréée pour le même joueur retrouve la même disposition.
	var autre := _instancier()
	autre.definir_joueur(3, "Joueur 3")
	verifier_egal(_signature(autre.plan_decor()), avant, "décor différent après recréation")
	arbre.root.remove_child(autre)
	autre.free()


func test_une_graine_explicite_remplace_celle_du_joueur() -> void:
	_arene = _instancier()
	_arene.definir_graine(777)
	var a := _signature(_arene.plan_decor())
	verifier_egal(a, _signature(PlanDecor2D.generer(PlanDecor2D.graine_arene(777, 1))))
	_arene.definir_graine(778)
	verifier_different(_signature(_arene.plan_decor()), a, "la graine ne change rien")


func test_le_decor_est_dessine_sous_les_ennemis_et_sous_le_cercle() -> void:
	_arene = _instancier()
	var sol := _arene.get_node("Sol") as Node2D
	var ennemis := _arene.get_node("Ennemis") as Node2D
	var cercle := _arene.get_node("CercleApparition") as Node2D
	verifier(sol.get_index() < ennemis.get_index(), "le décor est après les ennemis dans l'arbre")
	verifier(sol.get_index() < cercle.get_index(), "le décor couvre le cercle")
	verifier(sol.z_index <= ennemis.z_index, "indice Z du décor au-dessus des ennemis")
	verifier_egal(sol.get_parent(), _arene, "le décor n'est pas sous l'arène")
	var nb: int = 0
	for noeud: Node in sol.find_children("*", "Sprite2D", true, false):
		nb += 1
		verifier((noeud as Sprite2D).z_index <= ennemis.z_index, "sprite du décor au-dessus")
		verifier((noeud as Sprite2D).z_as_relative, "indice Z absolu dans le décor")
	verifier(nb >= 80, "décor trop pauvre : %d sprites" % nb)
	# Le décor ne se glisse jamais dans la couche triée des ennemis.
	verifier_egal(ennemis.find_children("*", "Decor2D", true, false).size(), 0)


func test_le_decor_se_construit_une_fois_et_garde_ses_noeuds_entre_les_images() -> void:
	_arene = _instancier()
	var sol := _arene.get_node("Sol") as Node2D
	var avant: int = sol.find_children("*", "", true, false).size()
	for i: int in 50:
		_arene._process(0.05)
	verifier_egal(sol.find_children("*", "", true, false).size(), avant, "des nœuds apparaissent")


func test_les_sapins_les_moutons_et_les_rochers_d_eau_s_animent() -> void:
	_arene = _instancier()
	var decor := _arene.get_node("Sol") as Decor2D
	var avant: Dictionary = decor.images_courantes()
	for categorie: String in ["sapin", "mouton", "eau"]:
		verifier(avant.has(categorie), "rien n'est animé pour « %s »" % categorie)
	decor.avancer(0.0)
	# Une demi-seconde plus tard, chaque famille animée a changé d'image.
	decor.avancer(0.5)
	var apres: Dictionary = decor.images_courantes()
	for categorie: String in avant:
		verifier(avant[categorie] != apres[categorie], "« %s » n'a pas bougé" % categorie)
	# Les sapins ne battent pas tous en même temps.
	verifier(decor.nombre_images_distinctes("sapin") >= 3, "tous les sapins au même rythme")


func test_l_image_du_sol_est_pleine_a_une_teinte_d_eau_aux_coins_et_d_herbe_au_centre() -> void:
	_arene = _instancier()
	var decor := _arene.get_node("Sol") as Decor2D
	var image := decor.image_du_sol()
	verifier_non_nul(image)
	if image == null:
		return
	var eau: Color = (load(RACINE + PlanDecor2D.FEUILLE_EAU) as Texture2D).get_image().get_pixel(
		0, 0
	)
	verifier_egal(
		image.get_size(), Vector2i(PlanDecor2D.DEMI_COLONNES * 128, PlanDecor2D.DEMI_LIGNES * 128)
	)
	for coin: Vector2i in [Vector2i(0, 0), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
		verifier_egal(image.get_pixelv(coin), eau, "le coin %s n'est pas de l'eau" % coin)
	# Aucun trou : chaque pixel de l'image est opaque.
	for y: int in range(0, image.get_height(), 7):
		for x: int in range(0, image.get_width(), 7):
			verifier_egal(image.get_pixel(x, y).a, 1.0, "pixel transparent en %d,%d" % [x, y])
	# Sous la zone de marche, que de l'herbe : jamais la teinte de l'eau.
	var centre := Vector2i(image.get_width() / 2, image.get_height() / 2)
	for dy: int in range(-300, 301, 9):
		for dx: int in range(-300, 301, 9):
			if Vector2(dx, dy).length() <= 300.0:
				verifier(image.get_pixelv(centre + Vector2i(dx, dy)) != eau, "eau dans la zone")


func test_les_bandes_d_eau_prolongent_le_sol_jusqu_aux_bords_de_l_ecran_le_plus_large() -> void:
	_arene = _instancier()
	var decor := _arene.get_node("Sol") as Decor2D
	var image := decor.image_du_sol()
	var fond := decor.get_node("Fond") as Sprite2D
	var couvert: Array[Rect2] = [Rect2(fond.position, Vector2(image.get_size()) * fond.scale)]
	for k: int in 4:
		var bande := decor.get_node("Eau%d" % k) as Sprite2D
		couvert.append(Rect2(bande.position, bande.region_rect.size * bande.scale))
	# Un échantillon de points de l'écran le plus large (32:9) est couvert, sans trou.
	for y: int in range(-2500, 2501, 125):
		for x: int in range(-5000, 5001, 125):
			var trouve: bool = false
			for r: Rect2 in couvert:
				trouve = trouve or r.grow(1.0).has_point(Vector2(x, y))
			verifier(trouve, "rien ne couvre %d,%d" % [x, y])


func test_chaque_case_de_rivage_a_son_ecume_et_rien_d_autre() -> void:
	for graine: int in GRAINES:
		var plan := PlanDecor2D.generer(graine)
		var attendues: int = 0
		for tuile: Dictionary in plan.tuiles:
			if tuile["atlas"] != Vector2i(1, 1):
				attendues += 1
				verifier(plan.ecume.has(tuile["cellule"]), "graine %d : rivage sans écume" % graine)
		verifier_egal(
			plan.ecume.size(), attendues, "graine %d : écume ailleurs qu'au rivage" % graine
		)


func test_un_sapin_ou_un_mouton_qui_recouvre_un_objet_immobile_est_devant_lui() -> void:
	# Les immobiles sont dans l'image du sol, sous tous les sprites : l'ordre de profondeur ne
	# serait faux que si un animé recouvrait un immobile placé plus au sud que lui.
	for graine: int in GRAINES:
		var plan := PlanDecor2D.generer(graine)
		var chevauchements: int = 0
		for a: Dictionary in plan.objets:
			for b: Dictionary in plan.objets:
				var ta: String = a["type"]
				var tb: String = b["type"]
				if not (bool(a["haut"]) and bool(b["haut"])):
					continue
				if not PlanDecor2D.est_anime(ta) or PlanDecor2D.est_anime(tb):
					continue
				if (a["rect"] as Rect2).intersects(b["rect"]):
					chevauchements += 1
					verifier(
						(a["pieds"] as Vector2).y > (b["pieds"] as Vector2).y,
						"graine %d : %s passe derrière %s" % [graine, ta, tb]
					)
		verifier(chevauchements >= 0)
