extends CasDeTest
## La survie de la tour au lot 9 (T9.11) : épines enrichies, PV maximum, régénération, armure,
## résurrection. Chaque amélioration est une entrée de test injectée dans les données : ce qu'on
## vérifie est ce que la joueuse obtient, pas le texte du catalogue.

const DT := 0.05
const GRAINE := 7
const PV := 100000.0
## Une attaque tous les deux pas de 0,05 s : la première part au premier pas.
const CADENCE_TEST := 16.0

var d: Donnees
var _compte: int = 0


func avant_chaque() -> void:
	d = Donnees.charger()
	_compte = 0


# --- Aides -------------------------------------------------------------------------------------


func _mult() -> Dictionary:
	return {"pv": 1.0, "degats": 1.0, "vitesse": 0.0, "resistance_controle": 1.0}


func _vue(a: Arene) -> VueArene:
	return a.vue(Types.Phase.MANCHE, 10.0, -1, false)


func _avancer(a: Arene, pas: int, dt: float = DT) -> void:
	for _i: int in pas:
		a.avancer(dt)


## Un ennemi immobile, sans armure, au corps à corps (portée 40) ou à distance (portée 450).
func _ennemi(a: Arene, degats: float, portee: float = 40.0, x: float = 100.0) -> int:
	return a.ennemis.ajouter(0, Vector2(x, 0), PV, 0.0, degats, portee, CADENCE_TEST, 0, 4)


func _pv_de(a: Arene, id: int) -> float:
	return a.ennemis.pv[a.ennemis.indice_de(id)]


## Donne à la tour `n` exemplaires d'une amélioration de test portant `stat` ; `extra` complète
## l'effet (`max`, `statut`, `ratio`, `tous_les`).
func _donner(a: Arene, stat: String, valeur: float, extra: Dictionary = {}, n: int = 1) -> void:
	_compte += 1
	var id := "essai_%d" % _compte
	var effet: Dictionary = {"stat": stat, "valeur": valeur}
	effet.merge(extra)
	d.ameliorations[id] = {
		"id": id,
		"nom": id,
		"description": id,
		"rarete": Types.Rarete.COMMUNE,
		"prix": 1,
		"categorie": Types.Categorie.AMELIORATION,
		"famille": "epines",
		"effets": [effet],
	}
	a.inventaire.ameliorations[id] = n
	a.synchroniser()


func _arene() -> Arene:
	return Arene.new(d, GRAINE)


# --- Épines ------------------------------------------------------------------------------------


func test_les_epines_renvoient_le_facteur_d_epines_et_toujours_seulement_le_corps_a_corps() -> void:
	var a := _arene()
	_donner(a, "epines", 0.3)
	_donner(a, "epines_degats", 0.2)
	var cac := _ennemi(a, 10.0)
	var archer := _ennemi(a, 10.0, 450.0, 400.0)
	a.avancer(DT)
	# Au temps 0,05 s : aucune tranche de croissance ; 0,3 + 0,2 du coup de 10.
	verifier_proche(_pv_de(a, cac), PV - 5.0, 0.01, "le corps à corps subit 50 % du coup")
	verifier_proche(_pv_de(a, archer), PV, 0.01, "l'archer ne subit rien")


func test_la_croissance_des_epines_suit_les_tranches_de_la_partie() -> void:
	var a := _arene()
	_donner(a, "epines_croissantes", 0.5, {"max": 1.0})
	_donner(a, "epines", 0.1)
	var cac := _ennemi(a, 10.0)
	# Pas de 31 s : une tranche → 0,1 + 0,5 = 0,6 du coup.
	a.avancer(31.0)
	verifier_proche(_pv_de(a, cac), PV - 6.0, 0.01, "une tranche de croissance")


func test_epines_premier_coup_ne_joue_qu_une_fois_par_ennemi() -> void:
	var a := _arene()
	_donner(a, "epines", 0.2)
	_donner(a, "epines_premier_coup", 0.5)
	var premier := _ennemi(a, 10.0)
	a.avancer(DT)
	verifier_proche(_pv_de(a, premier), PV - 7.0, 0.01, "le premier renvoi : 0,2 + 0,5")
	_avancer(a, 4)
	verifier_proche(_pv_de(a, premier), PV - 7.0 - 2.0 * 2.0, 0.01, "ensuite 0,2 seulement")
	var second := _ennemi(a, 10.0, 40.0, 100.0)
	a.avancer(DT)
	verifier_proche(
		_pv_de(a, second), PV - 7.0, 0.01, "un autre ennemi a son propre premier renvoi"
	)


func test_epines_soin_rend_le_ratio_des_degats_renvoyes_sans_depasser_le_maximum() -> void:
	var a := _arene()
	_donner(a, "epines", 0.5)
	_donner(a, "epines_soin", 0.4)
	_ennemi(a, 10.0)
	a.pv = 500.0
	a.avancer(DT)
	# Renvoyé 5, rendu 2 ; la tour subit 10.
	verifier_proche(_vue(a).tour_pv, 500.0 - 10.0 + 2.0, 0.01, "le soin suit le renvoi")
	var b := _arene()
	_donner(b, "epines", 0.5)
	_donner(b, "epines_soin", 100.0)
	_ennemi(b, 10.0)
	b.avancer(DT)
	verifier_proche(_vue(b).tour_pv, float(d.partie["tour"]["pv"]), 0.001, "jamais au-delà du max")


func test_epines_reduction_passe_avant_l_armure_et_la_mana_et_est_plafonnee() -> void:
	d.partie["tour"]["armure"] = 20.0
	d.partie["tour"]["mana_max"] = 10.0
	var a := _arene()
	_donner(a, "epines_reduction", 0.3)
	_ennemi(a, 100.0)
	a.avancer(DT)
	# 100 − 30 % = 70 ; armure 20 : ×0,5 = 35 ; la mana en absorbe 10 : 25 PV perdus.
	verifier_proche(_vue(a).tour_pv, 1000.0 - 25.0, 0.01, "réduction, puis armure, puis mana")
	verifier_proche(a.mana, 0.0, 0.001, "la mana absorbe après")
	var b := _arene()
	_donner(b, "epines_reduction", 0.9)
	_ennemi(b, 100.0)
	b.avancer(DT)
	verifier_proche(_vue(b).tour_pv, 1000.0 - (50.0 * 0.5 - 10.0), 0.01, "plafond de 50 %")
	var c := _arene()
	_donner(c, "epines_reduction", 0.5)
	_ennemi(c, 100.0, 450.0, 400.0)
	c.avancer(DT)
	verifier_proche(_vue(c).tour_pv, 1000.0 - (100.0 * 0.5 - 10.0), 0.01, "pas à distance")


func test_chaque_statut_d_epines_est_pose_sur_l_attaquant() -> void:
	var bits: Dictionary = {
		"poison": Types.STATUT_EMPOISONNE,
		"brulure": Types.STATUT_BRULE,
		"givre": Types.STATUT_RALENTI,
		"etourdissement": Types.STATUT_ETOURDI,
	}
	for statut: String in bits:
		var a := _arene()
		_donner(a, "epines_statut", 3.0, {"statut": statut})
		var cac := _ennemi(a, 10.0)
		var loin := _ennemi(a, 10.0, 450.0, 400.0)
		a.avancer(DT)
		var i := a.ennemis.indice_de(cac)
		verifier(int(a.ennemis.statuts[i]) & int(bits[statut]) != 0, "%s sur l'attaquant" % statut)
		var j := a.ennemis.indice_de(loin)
		verifier_egal(int(a.ennemis.statuts[j]), 0, "%s : pas à distance" % statut)
	var b := _arene()
	_donner(b, "epines_statut", 3.0, {"statut": "etourdissement"})
	var cible := _ennemi(b, 10.0)
	b.avancer(DT)
	verifier_proche(b.ennemis.etourdi[b.ennemis.indice_de(cible)], 3.0, 0.001, "valeur = durée")


func test_chaque_statut_de_riposte_est_pose_sur_l_attaquant() -> void:
	var bits: Dictionary = {"givre": Types.STATUT_RALENTI, "poison": Types.STATUT_EMPOISONNE}
	for statut: String in bits:
		var a := _arene()
		_donner(a, "riposte_statut", 2.0, {"statut": statut})
		var cac := _ennemi(a, 10.0)
		a.avancer(DT)
		var i := a.ennemis.indice_de(cac)
		verifier(int(a.ennemis.statuts[i]) & int(bits[statut]) != 0, "riposte %s" % statut)


# --- PV maximum --------------------------------------------------------------------------------


func test_pv_max_mult_soigne_du_montant_gagne_et_un_maximum_qui_baisse_ne_tue_pas() -> void:
	var a := _arene()
	a.pv = 600.0
	_donner(a, "pv_max_mult", 0.5)
	verifier_proche(a.tour_pv_max(), 1500.0, 0.001, "+50 % du maximum")
	verifier_proche(a.pv, 1100.0, 0.001, "soigné du montant gagné, pas rempli")
	a.inventaire.ameliorations.clear()
	a.synchroniser()
	verifier_proche(a.tour_pv_max(), 1000.0, 0.001)
	verifier_proche(a.pv, 1000.0, 0.001, "recalé au nouveau maximum")
	_donner(a, "pv_max_mult", -5.0)
	verifier(a.tour_pv_max() >= 1.0, "le maximum reste au moins 1")
	verifier(a.pv > 0.0, "un maximum qui baisse ne tue jamais")
	verifier_faux(a.est_detruite())


func test_pv_max_mult_multiplie_aussi_les_pv_max_d_amelioration() -> void:
	var a := _arene()
	_donner(a, "pv_max", 500.0)
	_donner(a, "pv_max_mult", 1.0)
	verifier_proche(a.tour_pv_max(), 3000.0, 0.001, "(1000 + 500) × 2")


func test_soin_pv_manquants_joue_au_debut_de_chaque_manche() -> void:
	var a := _arene()
	_donner(a, "soin_pv_manquants", 0.5)
	a.pv = 400.0
	a.demarrer_manche(1, Composition.unique(0), _mult())
	verifier_proche(a.pv, 700.0, 0.001, "la moitié des 600 manquants")
	a.pv = 100.0
	a.demarrer_manche(2, Composition.unique(0), _mult())
	verifier_proche(a.pv, 550.0, 0.001, "et à la manche suivante : la moitié de 900")
	a.pv = 1000.0
	a.demarrer_manche(3, Composition.unique(0), _mult())
	verifier_proche(a.pv, 1000.0, 0.001, "rien à rendre")


# --- Résurrection ------------------------------------------------------------------------------


func test_la_resurrection_releve_la_tour_au_pourcentage_borne_a_cent() -> void:
	for cas: Array in [[50, 1, 500.0], [30, 2, 600.0], [60, 2, 1000.0], [80, 3, 1000.0]]:
		d = Donnees.charger()
		var a := _arene()
		_donner(a, "resurrection", float(cas[0]), {}, int(cas[1]))
		_ennemi(a, 5000.0)
		a.avancer(DT)
		verifier_faux(a.est_detruite(), "relevée : %s" % [cas])
		verifier_proche(a.pv, float(cas[2]), 0.001, "pourcentage cumulé et borné : %s" % [cas])


func test_la_resurrection_ne_joue_qu_une_fois_par_partie_meme_avec_deux_exemplaires() -> void:
	var a := _arene()
	_donner(a, "resurrection", 50.0, {}, 2)
	_ennemi(a, 5000.0)
	a.avancer(DT)
	verifier_faux(a.est_detruite(), "première mort : relevée")
	verifier_proche(a.pv, 1000.0, 0.001, "2 × 50 % = 100 %")
	_avancer(a, 2)
	verifier(a.est_detruite(), "deuxième mort : définitive, même avec deux exemplaires")
	verifier_egal(_vue(a).phase, Types.Phase.DEFAITE)


func test_la_resurrection_ne_joue_pas_quand_la_tour_survit() -> void:
	var a := _arene()
	_donner(a, "resurrection", 50.0)
	var ennemi := _ennemi(a, 100.0)
	a.avancer(DT)
	verifier_proche(a.pv, 900.0, 0.001, "la tour survit : pas de relèvement")
	a.ennemis.degats[a.ennemis.indice_de(ennemi)] = 5000.0
	_avancer(a, 2)
	verifier_faux(a.est_detruite(), "la résurrection n'avait pas été gaspillée")
	verifier_proche(a.pv, 500.0, 0.001)


# --- Régénération et armure croissantes --------------------------------------------------------


func test_regen_croissante_et_armure_croissante_s_arretent_a_leur_max() -> void:
	var a := _arene()
	_donner(a, "regen_croissante", 0.1, {"max": 0.25})
	_donner(a, "armure_croissante", 2.0, {"max": 5.0})
	verifier_proche(_vue(a).tour_armure, 0.0, 0.001, "rien à l'instant 0")
	_avancer(a, 31, 1.0)
	a.pv = 1.0
	a.avancer(1.0)
	verifier_proche(a.pv, 1.0 + 0.1, 0.001, "une tranche : +0,1 PV par seconde")
	verifier_proche(_vue(a).tour_armure, 2.0, 0.001, "une tranche : +2")
	_avancer(a, 150, 1.0)
	a.pv = 1.0
	a.avancer(1.0)
	verifier_proche(a.pv, 1.25, 0.001, "borné à 0,25 PV par seconde")
	verifier_proche(_vue(a).tour_armure, 5.0, 0.001, "borné à 5")
	_avancer(a, 400, 1.0)
	verifier_proche(_vue(a).tour_armure, 5.0, 0.001, "jamais au-delà")


func test_l_armure_croissante_reduit_les_coups() -> void:
	var a := _arene()
	_donner(a, "armure_croissante", 20.0, {"max": 20.0})
	a.avancer(31.0)
	_ennemi(a, 100.0)
	a.avancer(DT)
	verifier_proche(_vue(a).tour_pv, 1000.0 - 50.0, 0.01, "20 d'armure : −50 %")


# --- Soin périodique ---------------------------------------------------------------------------


func test_soin_periodique_rend_le_ratio_du_maximum_a_chaque_periode() -> void:
	var a := _arene()
	_donner(a, "soin_periodique", 0.0, {"ratio": 0.1, "tous_les": 2.0})
	a.pv = 500.0
	_avancer(a, 39)
	verifier_proche(a.pv, 500.0, 0.001, "pas avant la fin de la période")
	_avancer(a, 2)
	verifier_proche(a.pv, 600.0, 0.001, "10 % de 1000 à 2 s")
	_avancer(a, 40)
	verifier_proche(a.pv, 700.0, 0.001, "et de nouveau 2 s plus tard")
	a.pv = 990.0
	_avancer(a, 40)
	verifier_proche(a.pv, 1000.0, 0.001, "jamais au-delà du maximum")


# --- Neutralité --------------------------------------------------------------------------------


func test_toute_nouvelle_stat_de_survie_est_neutre_sans_amelioration() -> void:
	var a := _arene()
	var cac := _ennemi(a, 10.0)
	var archer := _ennemi(a, 10.0, 450.0, 400.0)
	_avancer(a, 40)
	# 20 attaques de chaque ennemi, sans épines, sans armure, sans mana.
	verifier_proche(_vue(a).tour_pv, 1000.0 - 20.0 * 10.0 * 2.0, 0.01, "dégâts subis")
	verifier_proche(_pv_de(a, cac), PV, 0.01, "aucun renvoi")
	verifier_proche(_pv_de(a, archer), PV, 0.01)
	verifier_egal(int(a.ennemis.statuts[a.ennemis.indice_de(cac)]), 0, "aucun statut")
	verifier_proche(_vue(a).tour_armure, 0.0, 0.0001)
	verifier_proche(a.tour_pv_max(), 1000.0, 0.0001)
	var stats := a.inventaire.stats()
	verifier_proche(stats.pv_max_mult, 1.0, 0.0)
	verifier_proche(stats.soin_pv_manquants, 0.0, 0.0)
	verifier_egal(stats.resurrection, 0)
	verifier_proche(stats.facteur_epines(0.0), 1.0, 0.0)
