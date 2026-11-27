extends CasDeTest
## Les neuf armes tranchantes du lot 9 (D22), arme par arme : mêmes phases et mêmes bornes que
## l'acier du lot 8 (anticipation 3 images, vol direct 7 ou en cloche 11, impact au pic dans le
## premier quart, zone au rayon réel lu dans `data/armes.json`). Durées en images à 60 i/s.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(360.0, 300.0)

var _a: AttaquesElementaires = null
var _donnees: Donnees = Donnees.charger()


func avant_chaque() -> void:
	_a = AttaquesElementaires.new()
	arbre.root.add_child(_a)


func apres_chaque() -> void:
	if is_instance_valid(_a):
		_a.free()
	_a = null


func _avancer(images: int) -> void:
	for i: int in images:
		_a.avancer(IMAGE)


func _effet(id: String) -> Dictionary:
	return (_donnees.armes[id]["effets"] as Array)[0]


func _rayon_px(id: String, cle: String = "rayon") -> float:
	return float(_effet(id)[cle]) * Apparence.PX_PAR_UNITE


## Vérifie que l'arme `id` est de ce genre, tranchante, et rendue par cet élément.
func _verifier_arme(id: String, element: String, genre: String) -> void:
	verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
	verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
	verifier_egal(String(_effet(id)["kind"]), genre, "genre de %s" % id)
	verifier_egal(
		int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.TRANCHANT, "type de %s" % id
	)


## Un `Effets` qui rend les événements de la vitrine pour l'arme `id`.
func _effets_de(id: String) -> Effets:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = [id] as Array[String]
	for evenement: Dictionary in vitrine.evenements_du_cycle(id):
		effets.ajouter(evenement)
	vitrine.free()
	return effets


# --- Serpe de vigne : zone, vulnérabilité ------------------------------------------------------


func test_la_serpe_est_une_zone() -> void:
	_verifier_arme("serpe_de_vigne", "serpe", "zone")


func test_la_serpe_dure_quatorze_images_et_passe_au_dessus_de_la_ligne() -> void:
	verifier_proche(_a.tirer("serpe", TOUR, CIBLE) / IMAGE, 14.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
	var serpe: Dictionary = _a.etats("serpe")[0]
	verifier(serpe["visible"], "elle vole")
	verifier(serpe["position"].y < CIBLE.y - 10.0, "en léger arc, au-dessus de la ligne")
	var avant: float = serpe["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("serpe")[0]["rotation"] - avant) > 0.1, "elle tourne en volant")
	verifier_egal(_a.etats("ombre").size(), 1, "son ombre reste au sol")


func test_le_balayage_de_la_serpe_a_le_rayon_reel_de_la_zone() -> void:
	var rayon: float = _rayon_px("serpe_de_vigne")
	_a.impacter("serpe", CIBLE, rayon)
	var balayage: Array[Dictionary] = _a.etats("balayage")
	verifier_egal(balayage.size(), 1, "un seul arc")
	verifier_proche(balayage[0]["diametre"], rayon * 2.0, rayon * 2.0 * 0.1, "au rayon réel")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1)
	verifier_egal(_a.particules_actives(), 2, "éclats d'acier et feuilles de vigne")
	_avancer(80)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_mouvement_reduit_la_serpe_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("serpe", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
	verifier_proche(_a.etats("serpe")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_a.impacter("serpe", CIBLE, 55.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("balayage").size(), 1, "l'arc reste")


# --- Rasoir tournoyant : tir tournant à deux branches -----------------------------------------


func test_le_rasoir_est_un_tir_tournant_a_deux_branches() -> void:
	_verifier_arme("rasoir_tournoyant", "rasoir", "tournant")
	verifier_egal(int(_effet("rasoir_tournoyant")["branches"]), 2, "deux branches")


func test_le_rasoir_dure_dix_images_et_tourne_sur_lui_meme() -> void:
	verifier_proche(_a.tirer("rasoir", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var rasoir: Dictionary = _a.etats("rasoir")[0]
	verifier(rasoir["visible"], "le rasoir vole")
	var avant: float = rasoir["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("rasoir")[0]["rotation"] - avant) > 0.1, "il tourne en volant")


func test_l_entaille_du_rasoir_reste_petite() -> void:
	_a.impacter("rasoir", CIBLE, 0.0)
	verifier_egal(_a.etats("entaille").size(), 1, "une entaille")
	verifier(_a.diametre_max() <= 60.0, "au plus 60 px")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


## Les bouts des rayons d'un tir de l'arme `id` (pixels), tels que la vitrine les émet.
func _bouts(id: String) -> Array[Vector2]:
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = [id] as Array[String]
	var bouts: Array[Vector2] = []
	for evenement: Dictionary in vitrine.evenements_du_cycle(id):
		bouts.append(Apparence.vers_pixels(evenement["vers"]))
	vitrine.free()
	return bouts


## Un tir tournant garde les rayons de sa marque ; chaque branche y ajoute une lame qui file
## jusqu'au bout du rayon et mord là, à l'arrivée du vol.
func _verifier_tournant_dans_effets(id: String, lame: String, impact: String) -> void:
	var branches: int = int(_effet(id)["branches"])
	var bouts: Array[Vector2] = _bouts(id)
	verifier_egal(bouts.size(), branches, "une branche par événement")
	var effets: Effets = _effets_de(id)
	verifier_egal(effets.elementaires().etats(lame).size(), branches, "une lame par branche")
	var rayons: int = 0
	for forme: String in effets.formes_vivantes():
		rayons += 1 if forme == "trait_rayon" else 0
	verifier_egal(rayons, branches, "les rayons de la marque restent")
	var arrivee: int = (
		AttaquesElementaires.IMAGES_ANTICIPATION + AttaquesElementaires.IMAGES_VOL_DIRECT
	)
	for _i: int in arrivee:
		effets.avancer(IMAGE)
	var coups: Array[Dictionary] = effets.elementaires().etats(impact)
	verifier_egal(coups.size(), branches, "un impact par bout")
	for coup: Dictionary in coups:
		var proche: float = INF
		for bout: Vector2 in bouts:
			proche = minf(proche, (coup["position"] as Vector2).distance_to(bout))
		verifier(proche < 1.0, "l'impact est au bout d'un rayon")
	effets.free()


func test_le_rasoir_dans_effets_file_le_long_de_chaque_rayon_et_mord_au_bout() -> void:
	_verifier_tournant_dans_effets("rasoir_tournoyant", "rasoir", "entaille")


func test_mouvement_reduit_le_rasoir_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("rasoir", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	verifier_proche(_a.etats("rasoir")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_a.impacter("rasoir", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)


# --- Couperet à épines : cible unique ----------------------------------------------------------


func test_le_couperet_est_une_cible_unique() -> void:
	_verifier_arme("couperet_a_epines", "couperet", "cible_unique")


func test_le_couperet_dure_dix_images_et_culbute() -> void:
	verifier_proche(_a.tirer("couperet", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var couperet: Dictionary = _a.etats("couperet")[0]
	verifier(couperet["visible"], "le couperet vole")
	var avant: float = couperet["rotation"]
	var image: int = couperet["image"]
	_avancer(3)
	verifier(absf(_a.etats("couperet")[0]["rotation"] - avant) > 0.1, "il tourne en volant")
	verifier(_a.etats("couperet")[0]["image"] != image, "l'image culbute aussi")


func test_l_entaille_du_couperet_reste_petite_et_jette_des_epines() -> void:
	_a.impacter("couperet", CIBLE, 0.0)
	verifier_egal(_a.etats("entaille").size(), 1, "une entaille")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier_egal(_a.particules_actives(), 1, "une salve d'épines")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_mouvement_reduit_le_couperet_ne_culbute_pas_et_sans_epine() -> void:
	_a.mouvement_reduit = true
	_a.tirer("couperet", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var avant: int = _a.etats("couperet")[0]["image"]
	_avancer(3)
	verifier_proche(_a.etats("couperet")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	verifier_egal(_a.etats("couperet")[0]["image"], avant, "pas de culbute")
	_a.impacter("couperet", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)


# --- Lame de brume : cible unique, malédiction -------------------------------------------------


func test_la_lame_de_brume_est_une_cible_unique() -> void:
	_verifier_arme("lame_de_brume", "brume", "cible_unique")


func test_la_lame_de_brume_est_une_lame_bleutee_de_dix_images() -> void:
	verifier_proche(_a.tirer("brume", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var lame: Dictionary = _a.etats("lame_croissant")[0]
	verifier(lame["visible"], "la lame vole")
	var teinte: Color = lame["teinte"]
	verifier(teinte.b > teinte.r + 0.1, "bleutée, pas l'acier nu de la lame de fil")
	var avant: int = lame["image"]
	_avancer(2)
	verifier(_a.etats("lame_croissant")[0]["image"] != avant, "elle tourne sur elle-même")


func test_la_brume_se_leve_a_l_impact_puis_se_dissipe() -> void:
	_a.impacter("brume", CIBLE, 0.0)
	verifier_egal(_a.etats("entaille").size(), 1, "une entaille")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	var teinte: Color = _a.etats("entaille")[0]["teinte"]
	verifier(teinte.b > teinte.r + 0.1, "l'entaille est bleutée")
	verifier_egal(_a.etats("vapeur").size(), 3, "trois bouffées de brume")
	var avant: float = _a.etats("vapeur")[0]["position"].y
	_avancer(10)
	verifier(_a.etats("vapeur")[0]["position"].y < avant, "la brume monte")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_mouvement_reduit_la_lame_de_brume_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("brume", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var avant: int = _a.etats("lame_croissant")[0]["image"]
	_avancer(2)
	verifier_egal(_a.etats("lame_croissant")[0]["image"], avant, "ne tourne pas")
	_a.impacter("brume", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)


# --- Faucheuse double : tir tournant à quatre branches, poison ---------------------------------


func test_la_faucheuse_est_un_tir_tournant_a_quatre_branches() -> void:
	_verifier_arme("faucheuse_double", "faucheuse", "tournant")
	verifier_egal(int(_effet("faucheuse_double")["branches"]), 4, "quatre branches")


func test_la_faucheuse_dure_dix_images_et_tourne_en_vert_pale() -> void:
	verifier_proche(_a.tirer("faucheuse", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var lame: Dictionary = _a.etats("lame_tournante")[0]
	var teinte: Color = lame["teinte"]
	verifier(teinte.g > teinte.r + 0.1 and teinte.g > teinte.b, "teintée de vert")
	var avant: float = lame["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("lame_tournante")[0]["rotation"] - avant) > 0.1, "elle tourne")


func test_l_impact_de_la_faucheuse_a_des_etincelles_et_des_gouttes_de_poison() -> void:
	_a.impacter("faucheuse", CIBLE, 0.0)
	verifier_egal(_a.etats("eclat_acier").size(), 1, "un éclat d'acier")
	verifier(_a.diametre_max() <= 60.0, "au plus 60 px")
	verifier_egal(_a.particules_actives(), 2, "étincelles et gouttes vertes")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier_egal(_a.particules_actives(), 0)


func test_la_faucheuse_dans_effets_file_sur_ses_quatre_rayons() -> void:
	_verifier_tournant_dans_effets("faucheuse_double", "lame_tournante", "eclat_acier")


func test_mouvement_reduit_la_faucheuse_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("faucheuse", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	verifier_proche(_a.etats("lame_tournante")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_a.impacter("faucheuse", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)


# --- Fléau de rasoirs : rebond, vulnérabilité --------------------------------------------------


func test_le_fleau_est_un_rebond_qui_rend_vulnerable() -> void:
	_verifier_arme("fleau_de_rasoirs", "fleau", "rebond")
	verifier_egal(String(_donnees.armes["fleau_de_rasoirs"]["statuts"][0]["kind"]), "vulnerabilite")


func test_le_fleau_dure_dix_images_et_ses_rasoirs_tournent() -> void:
	verifier_proche(_a.tirer("fleau", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var avant: float = _a.etats("rasoir")[0]["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("rasoir")[0]["rotation"] - avant) > 0.3, "il tourne en volant")


func test_un_saut_du_fleau_est_un_vol_de_sept_images_sans_anticipation() -> void:
	var fin: float = _a.saut("fleau", CIBLE, CIBLE + Vector2(90.0, 20.0), 4.0 * IMAGE)
	verifier_proche(fin / IMAGE, 4.0 + AttaquesElementaires.IMAGES_VOL_DIRECT, 0.01)
	verifier_egal(_a.etats("depart").size(), 0, "pas d'anticipation à chaque saut")
	verifier_faux(_a.etats("rasoir")[0]["visible"], "il attend la fin du saut précédent")
	_avancer(5)
	verifier(_a.etats("rasoir")[0]["visible"], "il vole")
	_avancer(10)
	verifier_egal(_a.nombre_vivants(), 0, "arrivé, il disparaît")


func test_chaque_saut_du_fleau_mord_petit_avec_un_eclat_d_acier() -> void:
	_a.impacter("fleau", CIBLE, 0.0)
	verifier_egal(_a.etats("eclat_acier").size(), 1, "un éclat d'acier")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier_egal(_a.particules_actives(), 1, "des étincelles")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")


func test_le_fleau_dans_effets_envoie_un_rasoir_par_saut() -> void:
	var effets: Effets = _effets_de("fleau_de_rasoirs")
	verifier_egal(effets.elementaires().etats("rasoir").size(), 3, "un tir puis deux sauts")
	effets.free()


func test_mouvement_reduit_le_fleau_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("fleau", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var avant: int = _a.etats("rasoir")[0]["image"]
	verifier_proche(_a.etats("rasoir")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_avancer(2)
	verifier_egal(_a.etats("rasoir")[0]["image"], avant, "image fixe")
	_a.impacter("fleau", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)
