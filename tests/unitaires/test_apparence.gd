extends CasDeTest
## Ce que la joueuse voit à l'écran : chaque ennemi, le convoi et le boss ont un sprite du pack
## Tiny Swords dont la feuille existe et dont le découpage tombe juste, la mort de tous est la
## même feuille, et les huit tours se distinguent deux à deux. Les listes viennent des données
## réelles : une famille ajoutée sans sprite fait échouer ce test. Une rareté ou une armure se lit
## sans sa couleur : symbole et libellé la portent aussi.

const ANIMATIONS: Array[String] = ["repos", "course", "attaque", "attaque_bas", "attaque_haut"]
## Écart minimal entre deux teintes de tour, en degrés : au-dessous, deux joueurs se confondent.
const ECART_TEINTE_MIN: float = 20.0

## Modèle de jeu → modèle du pack, et palier → couleur du pack (spécification, § 6.1).
const SPRITE_DU_MODELE: Dictionary = {
	"torche": "torch",
	"paysan": "pawn",
	"guerrier": "warrior",
	"tonneau": "barrel",
	"dynamite": "tnt",
	"archer": "archer",
}
const COULEUR_DU_PALIER: Dictionary = {
	"jaune": "Yellow", "rouge": "Red", "violet": "Purple", "bleu": "Blue"
}

var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func _ecart_teinte(a: float, b: float) -> float:
	var d: float = absf(fposmod(a - b, 360.0))
	return minf(d, 360.0 - d)


func _charger(chemin: String, id: String) -> Texture2D:
	verifier(ResourceLoader.exists(chemin), "%s : %s existe" % [id, chemin])
	return load(chemin) as Texture2D


func test_chaque_famille_le_convoi_et_le_boss_ont_une_entree_dans_l_ordre_des_index() -> void:
	var ids: PackedStringArray = Apparence.ids_entites(_donnees)
	verifier_egal(ids.size(), _donnees.familles.size() + 2)
	for i: int in _donnees.familles.size():
		verifier_egal(ids[i], String((_donnees.familles[i] as Dictionary)["id"]))
	verifier_egal(ids[_donnees.familles.size()], String(_donnees.convoi["id"]))
	verifier_egal(ids[_donnees.familles.size() + 1], String(_donnees.boss["id"]))


func test_chaque_entree_designe_une_feuille_qui_existe_et_se_decoupe_juste() -> void:
	for id: String in Apparence.ids_entites(_donnees):
		var e: Dictionary = Apparence.entree(id)
		verifier_faux(e.is_empty(), "entrée de %s" % id)
		if e.is_empty():
			continue
		var feuille := _charger(String(e["feuille"]), id)
		var taille: Vector2i = e["case"]
		var colonnes: int = e["colonnes"]
		var lignes: int = e["lignes"]
		verifier(taille.x > 0 and taille.y > 0 and colonnes > 0 and lignes > 0, "%s : tailles" % id)
		if feuille != null:
			verifier_egal(feuille.get_width(), colonnes * taille.x, "%s : largeur de feuille" % id)
			verifier_egal(feuille.get_height(), lignes * taille.y, "%s : hauteur de feuille" % id)
		for nom: String in ANIMATIONS:
			var anim: Vector2i = e[nom]
			verifier(anim.x >= 0 and anim.x < lignes, "%s : ligne de %s" % [id, nom])
			verifier(anim.y >= 1 and anim.y <= colonnes, "%s : images de %s" % [id, nom])
		var echelle: float = e["echelle"]
		verifier(echelle > 0.0, "%s : échelle" % id)
		verifier(e["couleur"] is Color, "%s : couleur" % id)
		if e.has("accessoire"):
			_charger(String((e["accessoire"] as Dictionary)["feuille"]), id)


func test_la_mort_de_toute_famille_utilise_la_meme_feuille() -> void:
	var mort: Dictionary = Apparence.MORT
	var feuille := _charger(String(mort["feuille"]), "mort")
	verifier(String(mort["feuille"]).ends_with("Dead.png"))
	var taille: Vector2i = mort["case"]
	if feuille != null:
		verifier_egal(feuille.get_width(), int(mort["colonnes"]) * taille.x)
		verifier_egal(feuille.get_height(), int(mort["lignes"]) * taille.y)
	var images: int = mort["images"]
	verifier(images <= int(mort["colonnes"]) * int(mort["lignes"]), "toutes les images existent")


func test_les_24_entrees_se_distinguent_par_modele_et_couleur() -> void:
	verifier_egal(_donnees.familles.size(), 24)
	var vues: Dictionary = {}
	var feuilles: Dictionary = {}
	for famille: Dictionary in _donnees.familles:
		var id: String = famille["id"]
		verifier(Apparence.ENTITES.has(id), "%s : une entrée" % id)
		if not Apparence.ENTITES.has(id):
			continue
		var source: Dictionary = Apparence.ENTITES[id]
		var signature: String = "%s/%s" % [source["modele"], source["couleur_pack"]]
		verifier_faux(
			vues.has(signature), "%s : %s déjà prise par %s" % [id, signature, vues.get(signature)]
		)
		vues[signature] = id
		var feuille: String = Apparence.entree(id)["feuille"]
		verifier_faux(
			feuilles.has(feuille), "%s : même feuille que %s" % [id, feuilles.get(feuille)]
		)
		feuilles[feuille] = id


func test_le_modele_de_sprite_suit_le_modele_de_jeu_et_le_tonneau_est_agrandi() -> void:
	for famille: Dictionary in _donnees.familles:
		var id: String = famille["id"]
		var source: Dictionary = Apparence.ENTITES[id]
		var attendu: String = String(SPRITE_DU_MODELE[famille["modele"]])
		verifier_egal(String(source["modele"]), attendu, "%s : modèle du pack" % id)
		var echelle: float = 1.5 if attendu == "barrel" else 1.0
		verifier_proche(float(source["echelle"]), echelle, 0.0001, "%s : échelle" % id)


func test_la_couleur_de_l_entree_suit_le_palier() -> void:
	var vus: Dictionary = {}
	for famille: Dictionary in _donnees.familles:
		var id: String = famille["id"]
		var couleur: String = String(COULEUR_DU_PALIER[famille["palier"]])
		verifier_egal(String((Apparence.ENTITES[id] as Dictionary)["couleur_pack"]), couleur, id)
		verifier(String(Apparence.entree(id)["feuille"]).contains(couleur), "%s : feuille" % id)
		vus[famille["palier"]] = true
	verifier_egal(vus.size(), COULEUR_DU_PALIER.size(), "tous les paliers sont couverts")


func test_aucune_trace_de_la_guepe_ni_du_vol() -> void:
	# `assets/maison/` existe (sprites d'effets dessinés par script) : il ne doit rien garder de la
	# guêpe ni du vol.
	for dossier: String in DirAccess.get_directories_at("res://assets/maison"):
		verifier_faux(dossier.to_lower().contains("guepe"), "assets/maison/%s" % dossier)
	for dossier: String in ["res://visuels", "res://tools"]:
		for nom: String in DirAccess.get_files_at(dossier):
			if not nom.ends_with(".gd"):
				continue
			var texte: String = FileAccess.get_file_as_string("%s/%s" % [dossier, nom]).to_lower()
			verifier_faux(texte.contains("guepe"), "%s/%s cite la guêpe" % [dossier, nom])
	for id: String in Apparence.ENTITES:
		var source: Dictionary = Apparence.ENTITES[id]
		verifier_faux(source.has("volant"), "%s : volant" % id)
		verifier_faux(source.has("flottement"), "%s : flottement" % id)
		var e: Dictionary = Apparence.entree(id)
		verifier_faux(e.has("volant"), "%s : entrée volante" % id)
		verifier_faux(e.has("flottement"), "%s : entrée flottante" % id)
	verifier(Apparence.entree("guepe_de_laiton").is_empty(), "plus d'entrée pour la guêpe")
	verifier_faux(Apparence.MODELES.has("guepe"), "plus de modèle de guêpe")


func test_le_convoi_est_un_mouton_a_deux_avec_son_sac_d_or_et_le_boss_un_guerrier_a_trois() -> void:
	var convoi: Dictionary = Apparence.entree(String(_donnees.convoi["id"]))
	verifier(String(convoi["feuille"]).contains("Sheep"))
	verifier_proche(float(convoi["echelle"]), 2.0, 0.0001)
	verifier(convoi.has("accessoire"), "le sac d'or accompagne le convoi")
	var boss: Dictionary = Apparence.entree(String(_donnees.boss["id"]))
	verifier(String(boss["feuille"]).contains("Warrior"))
	verifier_proche(float(boss["echelle"]), 3.0, 0.0001)


func test_une_famille_inconnue_n_a_pas_d_entree() -> void:
	verifier(Apparence.entree("inconnue").is_empty())


func test_les_huit_tours_sont_deux_a_deux_distinctes() -> void:
	for a: int in range(1, 9):
		var ta: Dictionary = Apparence.tour(a)
		for b: int in range(a + 1, 9):
			var tb: Dictionary = Apparence.tour(b)
			var ecart: float = _ecart_teinte(Apparence.teinte_tour(a), Apparence.teinte_tour(b))
			verifier(ecart >= ECART_TEINTE_MIN, "tours %d et %d : écart %.0f°" % [a, b, ecart])
			verifier(
				ta["fichier"] != tb["fichier"] or ta["decalage"] != tb["decalage"],
				"tours %d et %d : mêmes fichier et décalage" % [a, b]
			)


func test_les_quatre_premieres_tours_ont_les_couleurs_du_pack_et_les_suivantes_une_teinte_calculee(
) -> void:
	for numero: int in range(1, 9):
		var t: Dictionary = Apparence.tour(numero)
		verifier(ResourceLoader.exists(String(t["fichier"])), "tour %d : image" % numero)
		if numero <= 4:
			verifier_proche(float(t["decalage"]), 0.0, 0.0001, "tour %d sans décalage" % numero)
			verifier_nul(Apparence.materiau_tour(numero), "tour %d sans nuanceur" % numero)
		else:
			verifier(absf(float(t["decalage"])) > 0.05, "tour %d : décalage" % numero)
			verifier_non_nul(Apparence.materiau_tour(numero), "tour %d : nuanceur" % numero)
	verifier_egal(Apparence.tour(9), Apparence.tour(1), "au-delà de huit, on reboucle")


func test_la_conversion_des_unites_en_pixels_est_lineaire() -> void:
	verifier_egal(Apparence.vers_pixels(Vector2.ZERO), Vector2.ZERO)
	var p := Vector2(1300.0, -400.0)
	verifier_egal(Apparence.vers_pixels(p), p * Apparence.PX_PAR_UNITE)
	verifier_egal(Apparence.vers_pixels(p * 2.0), Apparence.vers_pixels(p) * 2.0)


func test_le_corps_a_corps_s_arrete_au_bord_de_la_tour_et_le_tireur_a_sa_portee() -> void:
	verifier_proche(Apparence.distance_arret(40.0, 60.0), 100.0, 0.0001, "corps à corps")
	verifier_proche(Apparence.distance_arret(60.0, 60.0), 120.0, 0.0001, "limite du corps à corps")
	verifier_proche(Apparence.distance_arret(450.0, 60.0), 450.0, 0.0001, "tireur")


func test_chaque_rarete_a_un_symbole_un_libelle_et_une_couleur() -> void:
	for r: int in Types.Rarete.values():
		verifier(not Apparence.symbole_rarete(r).is_empty(), "rareté %d sans symbole" % r)
		verifier(
			not Apparence.cle_libelle_rarete(r).is_empty(), "rareté %d sans libellé traduisible" % r
		)
		verifier(Apparence.couleur_rarete(r).a > 0.0, "rareté %d : couleur transparente" % r)


func test_deux_raretes_ne_partagent_ni_symbole_ni_couleur_ni_libelle() -> void:
	var raretes: Array = Types.Rarete.values()
	for a: int in raretes:
		for b: int in raretes:
			if a >= b:
				continue
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


func test_chaque_armure_a_une_couleur_un_symbole_et_un_libelle() -> void:
	for a: int in Types.Armure.values():
		verifier(not Apparence.symbole_armure(a).is_empty(), "armure %d sans symbole" % a)
		verifier(
			not Apparence.cle_libelle_armure(a).is_empty(), "armure %d sans libellé traduisible" % a
		)
		verifier(Apparence.couleur_texte_armure(a).a > 0.0, "armure %d : couleur transparente" % a)


func test_deux_armures_differentes_se_distinguent_par_couleur_symbole_et_libelle() -> void:
	var armures: Array = Types.Armure.values()
	for a: int in armures:
		for b: int in armures:
			if a >= b:
				continue
			verifier_different(
				Apparence.couleur_texte_armure(a),
				Apparence.couleur_texte_armure(b),
				"armures %d et %d : même couleur" % [a, b]
			)
			verifier_different(
				Apparence.symbole_armure(a),
				Apparence.symbole_armure(b),
				"armures %d et %d : même symbole" % [a, b]
			)
			verifier_different(
				Apparence.cle_libelle_armure(a),
				Apparence.cle_libelle_armure(b),
				"armures %d et %d : même libellé" % [a, b]
			)


func test_une_rarete_ou_une_armure_inconnue_prend_le_repli_visible() -> void:
	verifier_egal(Apparence.couleur_rarete(42), Apparence.COULEUR_REPLI, "rareté inconnue")
	verifier_egal(Apparence.couleur_texte_armure(42), Apparence.COULEUR_REPLI, "armure inconnue")
	verifier_egal(Apparence.cle_libelle_rarete(42), "", "rareté inconnue : pas de clé")
	verifier_egal(Apparence.cle_libelle_armure(42), "", "armure inconnue : pas de clé")
