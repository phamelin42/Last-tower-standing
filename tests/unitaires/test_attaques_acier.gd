extends CasDeTest
## Les six armes tranchantes (D22, famille acier), arme par arme : ce que le joueur voit part
## d'une anticipation, suit le genre de l'arme (cible unique, zone, rebond, aura, onde, barrage) et
## s'arrête au rayon réel de l'arme, lu dans `data/armes.json`. Durées en images à 60 i/s.

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
