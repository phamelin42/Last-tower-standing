extends CasDeTest
## Les six armes tranchantes (D22, famille acier), arme par arme : ce que le joueur voit part
## d'une anticipation, suit le genre de l'arme (cible unique, zone, rebond, aura, onde, barrage) et
## s'arrête au rayon réel de l'arme, lu dans `data/armes.json`. Durées en images à 60 i/s.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(360.0, 300.0)

var _a: AttaquesElementaires = null
var _donnees: Donnees = Donnees.charger()
var _effets_tourbillon: Effets = null


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


## Le premier effet de l'arme `id` dans `data/armes.json`.
func _effet(id: String) -> Dictionary:
	return (_donnees.armes[id]["effets"] as Array)[0]


## Vérifie que l'arme `id` est de ce genre et rendue par cet élément.
func _verifier_arme(id: String, element: String, genre: String) -> void:
	verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
	verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
	verifier_egal(String(_effet(id)["kind"]), genre, "genre de %s" % id)
	verifier_egal(
		int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.TRANCHANT, "type de %s" % id
	)


# --- Lame de fil : cible unique ----------------------------------------------------------------


func test_la_lame_de_fil_est_une_cible_unique() -> void:
	_verifier_arme("lame_de_fil", "lame", "cible_unique")


func test_la_lame_dure_dix_images_et_tourne_sur_elle_meme() -> void:
	verifier_proche(_a.tirer("lame", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var lame: Dictionary = _a.etats("lame_croissant")[0]
	verifier(lame["visible"], "la lame vole")
	var avant: int = lame["image"]
	_avancer(2)
	verifier(_a.etats("lame_croissant")[0]["image"] != avant, "elle tourne : une autre image")


func test_l_entaille_de_la_lame_reste_petite_et_jette_deux_eclats() -> void:
	_a.impacter("lame", CIBLE, 0.0)
	verifier_egal(_a.etats("entaille").size(), 1, "une entaille")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier_egal(_a.particules_actives(), 1, "une salve d'éclats")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")


func test_mouvement_reduit_la_lame_ne_tourne_pas_et_sans_eclat() -> void:
	_a.mouvement_reduit = true
	_a.tirer("lame", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var avant: int = _a.etats("lame_croissant")[0]["image"]
	_avancer(2)
	verifier_egal(_a.etats("lame_croissant")[0]["image"], avant, "ne tourne pas")
	_a.impacter("lame", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)


# --- Faucille à ressort : zone ------------------------------------------------------------------


func test_la_faucille_est_une_zone() -> void:
	_verifier_arme("faucille_a_ressort", "faucille", "zone")


func test_la_faucille_dure_quatorze_images_et_passe_au_dessus_de_la_ligne() -> void:
	verifier_proche(_a.tirer("faucille", TOUR, CIBLE) / IMAGE, 14.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
	var faucille: Dictionary = _a.etats("faucille")[0]
	verifier(faucille["visible"], "elle vole")
	verifier(faucille["position"].y < CIBLE.y - 10.0, "en léger arc, au-dessus de la ligne")
	var avant: float = faucille["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("faucille")[0]["rotation"] - avant) > 0.1, "elle tourne en volant")
	verifier_egal(_a.etats("ombre").size(), 1, "son ombre reste au sol")


func test_le_balayage_a_le_rayon_reel_de_la_zone() -> void:
	var rayon_px: float = float(_effet("faucille_a_ressort")["rayon"]) * Apparence.PX_PAR_UNITE
	_a.impacter("faucille", CIBLE, rayon_px)
	var balayage: Array[Dictionary] = _a.etats("balayage")
	verifier_egal(balayage.size(), 1, "un seul arc")
	verifier_proche(balayage[0]["diametre"], rayon_px * 2.0, rayon_px * 2.0 * 0.1, "au rayon réel")
	verifier_proche(_a.diametre_max(), rayon_px * 2.0, rayon_px * 2.0 * 0.1)


func test_le_balayage_tourne_sur_trois_cent_degres_en_six_images_puis_se_dissipe() -> void:
	_a.impacter("faucille", CIBLE, 55.0)
	_avancer(6)
	var image: int = _a.etats("balayage")[0]["image"]
	verifier(image >= 2, "l'arc est complet au bout de 6 images")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0)
	verifier_egal(_a.particules_actives(), 0)


func test_mouvement_reduit_la_faucille_ne_tourne_pas_et_sans_eclat() -> void:
	_a.mouvement_reduit = true
	_a.tirer("faucille", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 5)
	verifier_proche(_a.etats("faucille")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_a.impacter("faucille", CIBLE, 55.0)
	verifier_egal(_a.particules_actives(), 0)
	verifier_egal(_a.etats("balayage").size(), 1, "l'arc reste")


# --- Disque scie : rebond et poison ------------------------------------------------------------


func test_le_disque_est_un_rebond_qui_empoisonne() -> void:
	_verifier_arme("disque_scie", "disque", "rebond")
	verifier_egal(String(_donnees.armes["disque_scie"]["statuts"][0]["kind"]), "poison")


func test_le_disque_dure_dix_images_et_tourne_vite() -> void:
	verifier_proche(_a.tirer("disque", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var avant: float = _a.etats("disque_scie")[0]["rotation"]
	_avancer(2)
	var apres: float = _a.etats("disque_scie")[0]["rotation"]
	verifier(absf(apres - avant) > 0.5, "plus d'un demi-radian en deux images")


func test_un_saut_du_disque_est_un_vol_de_sept_images_sans_anticipation() -> void:
	var fin: float = _a.saut("disque", CIBLE, CIBLE + Vector2(90.0, 20.0), 4.0 * IMAGE)
	verifier_proche(fin / IMAGE, 4.0 + AttaquesElementaires.IMAGES_VOL_DIRECT, 0.01)
	verifier_egal(_a.etats("depart").size(), 0, "pas d'anticipation à chaque saut")
	var disque: Dictionary = _a.etats("disque_scie")[0]
	verifier_faux(disque["visible"], "il attend la fin du saut précédent")
	_avancer(5)
	verifier(_a.etats("disque_scie")[0]["visible"], "il vole")
	_avancer(10)
	verifier_egal(_a.nombre_vivants(), 0, "arrivé, il disparaît")


func test_l_impact_du_disque_a_des_etincelles_et_des_gouttes_vertes() -> void:
	_a.impacter("disque", CIBLE, 0.0)
	verifier_egal(_a.etats("eclat_acier").size(), 1, "un éclat d'acier")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier_egal(_a.particules_actives(), 2, "étincelles grises et gouttes vertes")


func test_mouvement_reduit_le_disque_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("disque", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var avant: int = _a.etats("disque_scie")[0]["image"]
	verifier_proche(_a.etats("disque_scie")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_avancer(2)
	verifier_egal(_a.etats("disque_scie")[0]["image"], avant, "image fixe")
	_a.impacter("disque", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)


# --- Moulinet de cuivre : aura -----------------------------------------------------------------


func _rayon_px(id: String, cle: String = "rayon") -> float:
	return float(_effet(id)[cle]) * Apparence.PX_PAR_UNITE


func test_le_moulinet_est_une_aura() -> void:
	_verifier_arme("moulinet_de_cuivre", "moulinet", "aura")


func test_le_moulinet_n_a_pas_de_projectile() -> void:
	verifier_egal(
		AttaquesElementaires.planche_projectile("moulinet"), "", "rien ne part de la tour"
	)


func test_six_lames_de_cuivre_atteignent_le_rayon_reel_de_l_aura() -> void:
	var rayon: float = _rayon_px("moulinet_de_cuivre")
	verifier(_a.aura("moulinet", TOUR, rayon))
	verifier_egal(_a.etats("lame_cuivre").size(), 6, "six lames")
	_avancer(AttaquesElementaires.IMAGES_COURONNE_OUVERTURE)
	var portee_max: float = 0.0
	for lame: Dictionary in _a.etats("lame_cuivre"):
		var d: float = (lame["position"] as Vector2).distance_to(TOUR)
		portee_max = maxf(portee_max, d + lame["taille"].y * 0.5)
		verifier(d < rayon, "le centre de la lame est dans la zone")
	verifier_proche(portee_max, rayon, rayon * 0.1, "le bord extérieur est au rayon")
	verifier(_a.diametre_max() <= rayon * 2.0 * 1.1, "rien au-delà de la zone")


func test_le_moulinet_s_efface_et_rend_le_pool() -> void:
	_a.aura("moulinet", TOUR, 140.0)
	_avancer(AttaquesElementaires.IMAGES_COURONNE + 1)
	verifier_egal(_a.nombre_vivants(), 0)
	verifier_egal(_a.particules_actives(), 0)


func test_le_moulinet_dans_effets_se_dessine_a_chaque_coup_de_l_aura() -> void:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = ["moulinet_de_cuivre"] as Array[String]
	var evenements: Array[Dictionary] = vitrine.evenements_du_cycle("moulinet_de_cuivre")
	verifier_egal(evenements.size(), 1, "une aura n'émet qu'un impact")
	effets.ajouter(evenements[0])
	verifier_egal(effets.elementaires().etats("lame_cuivre").size(), 6, "six lames")
	verifier_egal(effets.formes_vivantes().has("anneau"), false, "plus d'anneau générique")
	vitrine.free()
	effets.free()


func test_mouvement_reduit_le_moulinet_garde_ses_lames_sans_tourner() -> void:
	_a.mouvement_reduit = true
	_a.aura("moulinet", TOUR, 140.0)
	_avancer(3)
	var avant: Array[Dictionary] = _a.etats("lame_cuivre")
	_avancer(3)
	var apres: Array[Dictionary] = _a.etats("lame_cuivre")
	verifier_egal(apres.size(), 6, "les lames restent")
	verifier_proche(
		((avant[0]["position"] as Vector2) - TOUR).angle(),
		((apres[0]["position"] as Vector2) - TOUR).angle(),
		0.0001,
		"elles ne tournent pas"
	)


# --- Guillotine à vapeur : onde ----------------------------------------------------------------


func test_la_guillotine_est_une_onde() -> void:
	_verifier_arme("guillotine_a_vapeur", "guillotine", "onde")


## Le front est dessiné d'un trait à son départ : sa vitesse et son rayon sont ceux de l'onde de
## `data/armes.json`, sans quoi la lame passerait devant ou derrière les ennemis touchés.
func test_le_front_de_la_guillotine_suit_la_vitesse_et_le_rayon_de_l_onde() -> void:
	verifier_proche(AttaqueGuillotine.RAYON_PX, _rayon_px("guillotine_a_vapeur", "rayon_max"), 0.01)
	verifier_proche(AttaqueGuillotine.VITESSE_PX, _rayon_px("guillotine_a_vapeur", "vitesse"), 0.01)


func test_la_guillotine_n_a_pas_de_projectile() -> void:
	verifier_egal(AttaquesElementaires.planche_projectile("guillotine"), "")


func test_la_lame_d_acier_atteint_le_rayon_maximal_sans_le_depasser() -> void:
	verifier(_a.onde("guillotine", TOUR))
	var lames: Array[Dictionary] = _a.etats("arc_lame")
	verifier_egal(lames.size(), AttaqueGuillotine.LAMES, "des lames tout autour")
	var rayon: float = _rayon_px("guillotine_a_vapeur", "rayon_max")
	var images: int = int(rayon / AttaqueGuillotine.VITESSE_PX / IMAGE) - 1
	_avancer(images)
	var plus_loin: float = 0.0
	for lame: Dictionary in _a.etats("arc_lame"):
		plus_loin = maxf(plus_loin, (lame["position"] as Vector2).distance_to(TOUR))
	verifier_proche(plus_loin, rayon, 8.0, "le front est à son rayon maximal")
	verifier(plus_loin <= rayon + 0.01, "il ne le dépasse jamais")


func test_la_vapeur_se_forme_derriere_le_front_puis_se_dissipe() -> void:
	_a.onde("guillotine", TOUR)
	_avancer(25)
	var front: float = AttaqueGuillotine.VITESSE_PX * 25.0 * IMAGE
	var visibles: int = 0
	for bouffee: Dictionary in _a.etats("vapeur"):
		if bouffee["visible"]:
			visibles += 1
			verifier((bouffee["position"] as Vector2).distance_to(TOUR) <= front + 1.0, "derrière")
	verifier(visibles > 0, "de la vapeur déjà visible")
	_avancer(120)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")
	verifier(_a.opacite_max() <= AttaquesElementaires.ALPHA_MAX)


func test_la_guillotine_dans_effets_part_au_tir_et_les_impacts_n_ajoutent_rien() -> void:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = ["guillotine_a_vapeur"] as Array[String]
	var evenements: Array[Dictionary] = vitrine.evenements_du_cycle("guillotine_a_vapeur")
	effets.ajouter(evenements[0])
	var lames: int = effets.elementaires().etats("arc_lame").size()
	verifier_egal(lames, AttaqueGuillotine.LAMES, "le front part au tir")
	for k: int in range(1, evenements.size()):
		effets.ajouter(evenements[k])
	verifier_egal(effets.elementaires().etats("arc_lame").size(), lames, "l'impact n'en ajoute pas")
	verifier_egal(effets.formes_vivantes().has("anneau"), false, "plus d'anneau générique")
	vitrine.free()
	effets.free()


# --- Tourbillon d'acier : barrage et vol de vie ------------------------------------------------


func test_le_tourbillon_est_un_barrage_qui_soigne() -> void:
	_verifier_arme("tourbillon_d_acier", "tourbillon", "barrage")
	verifier_egal(String(_donnees.armes["tourbillon_d_acier"]["statuts"][0]["kind"]), "vol_de_vie")


func test_chaque_lame_du_tourbillon_part_deux_images_apres_la_precedente() -> void:
	var retard: float = AttaquesElementaires.RETARD_BARRAGE
	var premiere: float = _a.tirer("tourbillon", TOUR, CIBLE, 0.0)
	var seconde: float = _a.tirer("tourbillon", TOUR, CIBLE, retard)
	verifier_proche(premiere / IMAGE, 10.0, 0.01, "anticipation + vol")
	verifier_proche((seconde - premiere) / IMAGE, 2.0, 0.01, "décalées de 2 images")
	verifier_egal(_a.etats("lame_tournante").size(), 2, "une lame par tir")
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	var avant: float = _a.etats("lame_tournante")[0]["rotation"]
	_avancer(2)
	verifier(absf(_a.etats("lame_tournante")[0]["rotation"] - avant) > 0.5, "elle tourne")


func test_un_seul_anneau_au_rayon_reel_pour_tout_le_barrage() -> void:
	var rayon: float = _rayon_px("tourbillon_d_acier")
	for k: int in 8:
		_a.impacter_en_groupe("tourbillon", CIBLE + Vector2(0.0, k * 6.0), rayon)
	verifier_egal(_a.etats("").size(), 0, "aucun anneau par lame")
	_a.zone("tourbillon", CIBLE, rayon)
	verifier_egal(_a.etats("").size(), 1, "un anneau pour le tir")
	verifier_proche(_a.diametre_max(), rayon * 2.0, rayon * 2.0 * 0.1, "au rayon réel")


func test_chaque_impact_du_tourbillon_est_petit_avec_peu_d_eclats() -> void:
	_a.impacter_en_groupe("tourbillon", CIBLE, 30.0)
	verifier_egal(_a.etats("eclat_acier").size(), 1, "un éclat d'acier")
	verifier(_a.etats("eclat_acier")[0]["diametre"] <= 60.0, "reste petit")
	verifier(_a.particules_actives() <= 8, "au plus huit particules par impact")
	_avancer(60)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")


func test_le_tourbillon_dans_effets_lance_quatre_lames_et_un_soin_a_la_fois() -> void:
	_vitrine_tourbillon()
	var effets: Effets = _effets_tourbillon
	var avant: int = effets.elementaires().etats("lame_tournante").size()
	verifier_egal(avant, 4, "quatre lames pour quatre impacts")
	var anneaux: int = 0
	for _i: int in 40:
		effets.avancer(IMAGE)
		anneaux = maxi(anneaux, effets.elementaires().etats("").size())
	verifier_egal(anneaux, 1, "un seul anneau")


func _vitrine_tourbillon() -> void:
	_effets_tourbillon = Effets.new()
	_effets_tourbillon.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(_effets_tourbillon)
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = ["tourbillon_d_acier"] as Array[String]
	for evenement: Dictionary in vitrine.evenements_du_cycle("tourbillon_d_acier"):
		_effets_tourbillon.ajouter(evenement)
	vitrine.free()


func test_mouvement_reduit_le_tourbillon_ne_tourne_pas_et_sans_particule() -> void:
	_a.mouvement_reduit = true
	_a.tirer("tourbillon", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 2)
	verifier_proche(_a.etats("lame_tournante")[0]["rotation"], 0.0, 0.0001, "pas de rotation")
	_a.impacter_en_groupe("tourbillon", CIBLE, 30.0)
	verifier_egal(_a.particules_actives(), 0)
