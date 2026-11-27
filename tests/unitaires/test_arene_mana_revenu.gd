extends CasDeTest
## La mana, le revenu et l'aura mixte au lot 9 (T9.12) : chaque amélioration est une entrée de test
## injectée dans les données, pour ne pas dépendre du catalogue. On vérifie ce que la joueuse
## obtient : un bouclier qui se brise étourdit, une mana pleine frappe plus fort et protège, un
## revenu s'achète avec des PV, une aura blesse et soigne.

const DT := 0.05
const GRAINE := 7
const PV := 100000.0
const CADENCE_TEST := 16.0

var d: Donnees
var _compte: int = 0


func avant_chaque() -> void:
	d = Donnees.charger()
	# Ce test vérifie l'ordre des couches, pas le prix de la mana : un point de mana par point de dégât.
	(d.partie["tour"] as Dictionary)["mana_cout_par_pv"] = 1.0
	# Sans régénération, la mana ne remonte jamais seule : les tests la posent à la main.
	(d.partie["tour"] as Dictionary)["mana_regen"] = 0.0
	_compte = 0


# --- Aides -------------------------------------------------------------------------------------


func _arene() -> Arene:
	return Arene.new(d, GRAINE)


func _ennemi(a: Arene, degats: float, portee: float = 40.0, x: float = 100.0) -> int:
	return a.ennemis.ajouter(0, Vector2(x, 0), PV, 0.0, degats, portee, CADENCE_TEST, 0, 4)


func _pv_de(a: Arene, id: int) -> float:
	return a.ennemis.pv[a.ennemis.indice_de(id)]


func _etourdi(a: Arene, id: int) -> float:
	return a.ennemis.etourdi[a.ennemis.indice_de(id)]


## Donne `n` exemplaires d'une amélioration de test portant l'effet `effet`.
func _donner_effet(a: Arene, effet: Dictionary, n: int = 1) -> void:
	_compte += 1
	var id := "essai_%d" % _compte
	d.ameliorations[id] = {
		"id": id,
		"nom": id,
		"description": id,
		"rarete": Types.Rarete.COMMUNE,
		"prix": 1,
		"categorie": Types.Categorie.AMELIORATION,
		"famille": "mana",
		"effets": [effet],
	}
	a.inventaire.ameliorations[id] = n
	a.synchroniser()


func _donner(a: Arene, stat: String, valeur: float, n: int = 1) -> void:
	_donner_effet(a, {"stat": stat, "valeur": valeur}, n)


# --- Mana maximale -----------------------------------------------------------------------------


func test_la_mana_maximale_est_multipliee_par_mana_max_mult() -> void:
	var a := _arene()
	_donner(a, "mana_max", 100.0)
	verifier_proche(a.mana_max(), 100.0)
	_donner(a, "mana_max_mult", 0.5)
	verifier_proche(a.mana_max(), 150.0, 0.001, "100 de mana, +50 %")
	verifier_proche(a.mana, 150.0, 0.001, "la mana gagnée remplit la réserve, comme les PV")
	var vide := _arene()
	_donner(vide, "mana_max_mult", 2.0)
	verifier_proche(vide.mana_max(), 0.0, 0.001, "un multiple de rien reste rien")


# --- Chute du bouclier -------------------------------------------------------------------------


func test_la_chute_du_bouclier_etourdit_les_ennemis_du_rayon_une_seule_fois_par_chute() -> void:
	var a := _arene()
	_donner(a, "mana_max", 50.0)
	_donner_effet(a, {"stat": "mana_rupture_etourdit", "rayon": 500.0, "duree": 3.0})
	var voisin := _ennemi(a, 0.0, 40.0, 300.0)
	var loin := _ennemi(a, 0.0, 40.0, 900.0)
	var frappeur := _ennemi(a, 20.0)
	# 20 de dégâts contre 50 de mana : le bouclier tient, rien n'est étourdi.
	a.avancer(DT)
	verifier_proche(a.mana, 30.0, 0.001)
	verifier_proche(_etourdi(a, voisin), 0.0, 0.001, "le bouclier tient")
	# Le coup suivant (20, puis 20) le brise.
	for _i: int in 6:
		a.avancer(DT)
	verifier_proche(a.mana, 0.0, 0.001, "le bouclier est tombé")
	verifier(_etourdi(a, voisin) > 0.0, "l'ennemi du rayon est étourdi")
	verifier_proche(_etourdi(a, loin), 0.0, 0.001, "celui hors du rayon ne l'est pas")
	# Mana à 0 : les coups suivants ne font plus de chute, donc aucun nouvel étourdissement.
	a.ennemis.etourdi[a.ennemis.indice_de(voisin)] = 0.0
	a.ennemis.etourdi[a.ennemis.indice_de(frappeur)] = 0.0
	for _i: int in 6:
		a.avancer(DT)
	verifier_proche(_etourdi(a, voisin), 0.0, 0.001, "pas de seconde chute sans mana")
	# Une mana revenue puis tombée de nouveau est une nouvelle chute.
	a.mana = 10.0
	for _i: int in 6:
		a.avancer(DT)
	verifier(_etourdi(a, voisin) > 0.0, "une nouvelle chute étourdit de nouveau")


# --- Tant qu'il reste de la mana ---------------------------------------------------------------


func test_la_reduction_tant_que_mana_ne_vaut_que_mana_au_dessus_de_zero() -> void:
	var a := _arene()
	_donner(a, "mana_max", 100.0)
	_donner(a, "reduction_tant_que_mana", 0.5)
	_ennemi(a, 10.0)
	a.mana = 100.0
	a.avancer(DT)
	verifier_proche(100.0 - a.mana, 5.0, 0.001, "le coup de 10 est réduit de moitié")
	verifier_proche(a.pv, a.tour_pv_max(), 0.001, "la mana a tout absorbé")
	var b := _arene()
	_donner(b, "mana_max", 100.0)
	_donner(b, "reduction_tant_que_mana", 0.5)
	_ennemi(b, 10.0)
	b.mana = 0.0
	var avant := b.pv
	b.avancer(DT)
	verifier_proche(avant - b.pv, 10.0, 0.001, "sans mana, le coup passe en entier")


func _degats_du_premier_tir(mana: float) -> float:
	var a := _arene()
	_donner(a, "mana_max", 100.0)
	_donner(a, "degats_tant_que_mana", 0.5)
	a.inventaire.armes.append("lame_de_fil")
	a.synchroniser()
	a.mana = mana
	var cible := _ennemi(a, 0.0)
	a.avancer(DT)
	return PV - _pv_de(a, cible)


func test_degats_tant_que_mana_ne_valent_que_mana_au_dessus_de_zero() -> void:
	var sans := _degats_du_premier_tir(0.0)
	var avec := _degats_du_premier_tir(100.0)
	verifier(sans > 0.0, "l'arme frappe")
	verifier_proche(avec / sans, 1.5, 0.001, "+50 % de dégâts tant qu'il reste de la mana")
	verifier_proche(_degats_du_premier_tir(0.001) / sans, 1.5, 0.001, "même avec un reste de mana")


func test_les_degats_tant_que_mana_restent_sous_le_plafond_du_produit() -> void:
	(d.partie["ameliorations"] as Dictionary)["facteur_degats_max"] = 1.2
	var sans := _degats_du_premier_tir(0.0)
	var avec := _degats_du_premier_tir(100.0)
	verifier_proche(avec / sans, 1.2, 0.001, "le plafond borne le produit des facteurs")


# --- Revenu contre des PV ----------------------------------------------------------------------


func test_revenu_contre_pv_ajoute_l_or_retire_les_pv_et_ne_descend_pas_sous_un_pv_maximum() -> void:
	var a := _arene()
	var revenu_avant := a.vue(Types.Phase.MANCHE, 10.0, -1, false).revenu
	var pv_max_avant := a.tour_pv_max()
	_donner_effet(a, {"stat": "revenu_contre_pv", "pv": 150.0, "or": 14})
	var vue := a.vue(Types.Phase.MANCHE, 10.0, -1, false)
	verifier_egal(vue.revenu, revenu_avant + 14, "le revenu monte")
	verifier_proche(a.tour_pv_max(), pv_max_avant - 150.0, 0.001, "les PV maximum baissent")
	verifier(a.pv <= a.tour_pv_max(), "les PV se recalent sur le nouveau maximum")
	var argent := a.economie.argent
	a.avancer(10.0)
	verifier_egal(a.economie.argent - argent, revenu_avant + 14, "la période verse l'or en plus")
	# Deux exemplaires : deux fois l'or, deux fois la perte.
	var b := _arene()
	_donner_effet(b, {"stat": "revenu_contre_pv", "pv": 150.0, "or": 14}, 2)
	verifier_egal(b.vue(Types.Phase.MANCHE, 10.0, -1, false).revenu, revenu_avant + 28)
	verifier_proche(b.tour_pv_max(), pv_max_avant - 300.0, 0.001)
	# Une perte démesurée laisse un PV maximum, jamais zéro ni moins.
	var c := _arene()
	_donner_effet(c, {"stat": "revenu_contre_pv", "pv": 1.0e9, "or": 14})
	verifier_proche(c.tour_pv_max(), 1.0, 0.001, "jamais sous 1 PV maximum")
	verifier(c.pv > 0.0 and c.pv <= 1.0, "la tour vit encore avec 1 PV")
	c.avancer(DT)
	verifier_faux(c.est_detruite(), "sans ennemi, la tour tient")


# --- Aura mixte --------------------------------------------------------------------------------


func test_l_aura_mixte_inflige_et_soigne_tant_qu_un_ennemi_est_dans_le_rayon() -> void:
	var a := _arene()
	_donner_effet(a, {"stat": "aura_mixte", "rayon": 200.0, "poison": 40.0, "regen": 10.0})
	a.pv = 500.0
	var dedans := _ennemi(a, 0.0, 40.0, 150.0)
	var dehors := _ennemi(a, 0.0, 40.0, 900.0)
	for _i: int in 20:
		a.avancer(DT)
	# Une seconde d'aura : 40 dégâts de chaos par ennemi dans le rayon, 10 PV rendus.
	verifier_proche(PV - _pv_de(a, dedans), 40.0, 0.5, "l'ennemi du rayon est blessé")
	verifier_proche(_pv_de(a, dehors), PV, 0.001, "celui hors du rayon est épargné")
	verifier_proche(a.pv, 510.0, 0.5, "la tour regagne ses PV")
	# Plus personne dans le rayon : plus de soin.
	a.ennemis.pos[a.ennemis.indice_de(dedans)] = Vector2(900, 0)
	var avant := a.pv
	for _i: int in 20:
		a.avancer(DT)
	verifier_proche(a.pv, avant, 0.001, "sans ennemi dans le rayon, aucun soin")
