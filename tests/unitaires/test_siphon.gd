extends CasDeTest
## Siphon de mana et de vie, mana au coup (M4) : ce que la tour reçoit des ennemis qu'elle a touchés.

const DT := 0.05
const RAYON_TOUR := 60.0

var d: Donnees
var e: Ennemis


func avant_chaque() -> void:
	d = AidesPartie.donnees()
	e = Ennemis.new(d)


func _ennemi(pv: float = 1.0e6) -> int:
	return e.indice_de(e.ajouter(0, Vector2(900, 0), pv, 0.0, 0.0, 40.0, 1.0, 1, 0))


## Avance de `secondes` et cumule ce que les siphons ont versé.
func _avancer(secondes: float) -> Vector2:
	var total := Vector2.ZERO
	for _k: int in roundi(secondes / DT):
		var r := e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
		total += Vector2(float(r["siphon_mana"]), float(r["siphon_vie"]))
	return total


func test_un_ennemi_siphonne_verse_son_debit_chaque_seconde_a_la_tour() -> void:
	var i := _ennemi()
	e.siphonner(i, 0, 3.0, 4.0)
	e.siphonner(i, 1, 5.0, 4.0)
	verifier((e.statuts[i] & Types.STATUT_SIPHONNE) != 0, "le bit est posé")
	var total := _avancer(4.0)
	verifier_proche(total.x, 12.0, 0.01, "mana : 3 × 4 s")
	verifier_proche(total.y, 20.0, 0.01, "vie : 5 × 4 s")
	verifier_egal(int(e.statuts[i]) & Types.STATUT_SIPHONNE, 0, "le bit est retiré")


func test_le_siphon_s_arrete_a_la_mort_de_l_ennemi_et_a_la_fin_de_sa_duree() -> void:
	var i := _ennemi(100.0)
	e.siphonner(i, 0, 2.0, 10.0)
	var avant := _avancer(1.0)
	verifier_proche(avant.x, 2.0, 0.01)
	e.infliger(i, 1000.0, Types.TypeDegats.CHAOS)
	verifier_proche(_avancer(1.0).x, 0.0, 0.0001, "un mort ne verse plus")
	var j := _ennemi()
	e.siphonner(j, 1, 2.0, 1.0)
	verifier_proche(_avancer(3.0).y, 2.0, 0.01, "rien après la durée")


func test_un_ennemi_tue_par_son_poison_pendant_le_pas_ne_verse_pas_ce_pas() -> void:
	var i := _ennemi(10.0)
	e.siphonner(i, 0, 2.0, 5.0)
	e.empoisonner(i, 1000.0, 0.05)
	verifier_proche(_avancer(DT).x, 0.0, 0.0001)


func test_deux_ennemis_siphonnes_versent_chacun_leur_debit() -> void:
	var a := _ennemi()
	var b := _ennemi()
	e.siphonner(a, 0, 2.0, 2.0)
	e.siphonner(b, 0, 3.0, 2.0)
	verifier_proche(_avancer(2.0).x, 10.0, 0.01)


func test_un_siphon_plus_faible_ne_remplace_pas_un_plus_fort_mais_rafraichit_la_duree() -> void:
	var i := _ennemi()
	e.siphonner(i, 0, 5.0, 1.0)
	e.siphonner(i, 0, 1.0, 3.0)
	verifier_proche(e.siphon_mana[i], 5.0, 0.0001)
	verifier_proche(e.siphon_mana_t[i], 3.0, 0.0001)
	verifier_proche(_avancer(3.0).x, 15.0, 0.01, "le plus fort débit, sur la durée rafraîchie")


func test_un_siphon_invalide_est_ignore() -> void:
	var i := _ennemi()
	for mauvais: float in [NAN, INF, -1.0, 0.0]:
		e.siphonner(i, 0, mauvais, 2.0)
		e.siphonner(i, 1, 2.0, mauvais)
	e.siphonner(i, 7, 2.0, 2.0)
	e.siphonner(-1, 0, 2.0, 2.0)
	e.siphonner(500, 0, 2.0, 2.0)
	verifier_egal(e.statuts[i], 0)
	verifier_proche(_avancer(1.0).length(), 0.0, 0.0001)


func test_le_siphon_survit_a_la_purge() -> void:
	var a := e.ajouter(0, Vector2(900, 0), 5.0, 0.0, 0.0, 40.0, 1.0, 1, 0)
	var b := e.ajouter(0, Vector2(900, 0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, 0)
	e.siphonner(e.indice_de(b), 1, 4.0, 2.0)
	e.infliger(e.indice_de(a), 100.0, 0)
	e.purger()
	verifier_proche(_avancer(2.0).y, 8.0, 0.01)


# --- Dans l'arène ------------------------------------------------------------------------------


func _arene(mana_max_bonus: float = 0.0) -> Arene:
	var a := Arene.new(d, 99)
	a.demarrer_manche(
		1,
		Composition.unique(0),
		{"pv": 1.0, "degats": 1.0, "vitesse": 0.0, "resistance_controle": 1.0}
	)
	a._stats.mana_max_bonus = mana_max_bonus
	return a


func test_la_mana_gagnee_ne_depasse_pas_le_maximum_et_sans_maximum_rien_n_est_gagne() -> void:
	var sans := _arene(0.0)
	sans.mana = 0.0
	sans.mana_gagnee(100.0)
	verifier_egal(sans.mana, 0.0, "maximum 0 : rien de gagné, rien ne plante")
	var avec := _arene(40.0)
	avec.mana = 10.0
	avec.mana_gagnee(1000.0)
	verifier_proche(avec.mana, 40.0, 0.0001, "plafonnée à 40")
	for mauvais: float in [NAN, INF, -5.0, 0.0]:
		var avant := avec.mana
		avec.mana_gagnee(mauvais)
		verifier_egal(avec.mana, avant)


func test_la_mana_gagnee_est_propre_a_chaque_arene() -> void:
	var a := _arene(50.0)
	var b := _arene(50.0)
	a.mana = 0.0
	b.mana = 0.0
	a.mana_gagnee(20.0)
	verifier_proche(a.mana, 20.0, 0.0001)
	verifier_egal(b.mana, 0.0)


func test_les_pv_siphonnes_ne_depassent_pas_le_maximum() -> void:
	var a := _arene()
	var pv_max := float((d.partie["tour"] as Dictionary)["pv"])
	a.pv = pv_max - 3.0
	var id := a.ennemis.ajouter(0, Vector2(900, 0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, 0)
	a.ennemis.siphonner(a.ennemis.indice_de(id), 1, 100.0, 5.0)
	for _k: int in 40:
		a.avancer(DT)
	verifier_proche(a.pv, pv_max, 0.0001, "jamais au-dessus du maximum")


func test_la_mana_siphonnee_arrive_dans_la_tour() -> void:
	var a := _arene(200.0)
	a.mana = 0.0
	var id := a.ennemis.ajouter(0, Vector2(900, 0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, 0)
	a.ennemis.siphonner(a.ennemis.indice_de(id), 0, 10.0, 3.0)
	for _k: int in 60:
		a.avancer(DT)
	var regen := float((d.partie["tour"] as Dictionary)["mana_regen"])
	verifier_proche(a.mana, 30.0 + regen * 3.0, 0.2, "siphon 10 × 3 s plus la régénération")


func test_un_maximum_de_mana_qui_monte_ne_donne_pas_le_siphon_en_double() -> void:
	var a := _arene()
	a.inventaire.ajouter("fiole_d_azur")
	a.synchroniser()
	a.mana = 0.0
	a.mana_gagnee(30.0)
	verifier_proche(a.mana, 30.0, 0.0001)
	# Le maximum monte de 150 (cristal de réserve) : la mana monte de 150 une fois, le gain
	# précédent ne se recompte pas.
	a.inventaire.ajouter("cristal_de_reserve")
	a.synchroniser()
	verifier_proche(a.mana, 180.0, 0.0001, "30 gagnés + 150 du nouveau maximum")
	a.synchroniser()
	verifier_proche(a.mana, 180.0, 0.0001, "une seconde synchronisation ne donne plus rien")


func test_la_mana_rendue_sert_de_bouclier_au_coup_suivant() -> void:
	var a := _arene(100.0)
	a.mana = 0.0
	a.mana_gagnee(50.0)
	var id := a.ennemis.ajouter(0, Vector2(100, 0), 1.0e6, 0.0, 10.0, 40.0, 1.0, 1, 0)
	verifier(id >= 0)
	var pv_avant := a.pv
	a.avancer(DT)
	verifier_proche(a.pv, pv_avant, 0.001, "la mana rendue absorbe l'attaque")
	verifier(a.mana < 50.0 + 100.0, "et elle a servi")


# --- Dans le tir -------------------------------------------------------------------------------


func _def(statuts: Array, effet: Dictionary = {"kind": "cible_unique"}) -> Dictionary:
	return {
		"id": "arme_de_test",
		"nom": "Arme de test",
		"description": "Pour les tests.",
		"rarete": 0,
		"prix": 1,
		"type_degats": Types.TypeDegats.CHAOS,
		"degats": 10.0,
		"recharge": 1.0,
		"portee": 600,
		"ciblage": Types.Ciblage.PLUS_PROCHE,
		"effets": [effet],
		"statuts": statuts,
	}


func _tirer(def: Dictionary, stats: StatsTour = StatsTour.new()) -> Tir.Bilan:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bilan := Tir.Bilan.new()
	Tir.avancer_arme(ArmeEquipee.new(def), DT, stats, e, Vector2.ZERO, d, rng, 1.0, bilan)
	return bilan


func test_chaque_coup_qui_touche_rend_la_mana_au_coup_et_un_coup_sans_degats_n_en_rend_pas(
) -> void:
	var statut: Dictionary = {"kind": "mana_au_coup", "valeur": 2.5}
	e.ajouter(0, Vector2(300, 0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, 0)
	verifier_proche(_tirer(_def([statut])).mana, 2.5, 0.0001)
	var vide := Ennemis.new(d)
	e = vide
	verifier_proche(_tirer(_def([statut])).mana, 0.0, 0.0001, "aucune cible, aucun coup")


func test_un_tir_multiple_rend_la_mana_de_chaque_coup() -> void:
	var statut: Dictionary = {"kind": "mana_au_coup", "valeur": 2.0}
	for k: int in 3:
		e.ajouter(0, Vector2(300.0 + 10.0 * k, 0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, 0)
	var stats := StatsTour.new()
	stats.tirs_multiples = 2
	verifier_proche(_tirer(_def([statut]), stats).mana, 6.0, 0.0001, "trois coups")
	var zone := _def([statut], {"kind": "zone", "rayon": 200.0})
	var apres := _tirer(zone)
	verifier_proche(apres.mana, 6.0, 0.0001, "une zone qui touche trois ennemis rend trois fois")


func test_un_coup_mortel_rend_aussi_la_mana_au_coup() -> void:
	var statut: Dictionary = {"kind": "mana_au_coup", "valeur": 4.0}
	e.ajouter(0, Vector2(300, 0), 1.0, 0.0, 0.0, 40.0, 1.0, 1, 0)
	verifier_proche(_tirer(_def([statut])).mana, 4.0, 0.0001)


func test_le_tir_pose_le_siphon_des_deux_ressources() -> void:
	for ressource: String in ["mana", "vie"]:
		avant_chaque()
		var cible := e.indice_de(e.ajouter(0, Vector2(300, 0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, 0))
		var statut: Dictionary = {
			"kind": "siphon", "ressource": ressource, "par_seconde": 3.0, "duree": 4.0
		}
		_tirer(_def([statut]))
		var debit := e.siphon_mana[cible] if ressource == "mana" else e.siphon_vie[cible]
		verifier_proche(debit, 3.0, 0.0001, ressource)
		verifier((e.statuts[cible] & Types.STATUT_SIPHONNE) != 0)
