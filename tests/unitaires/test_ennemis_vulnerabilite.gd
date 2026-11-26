extends CasDeTest
## Vulnérabilité (M1) : ce que la joueuse obtient quand ses armes l'empilent sur un ennemi.

const DT := 0.05

var e: Ennemis
var d: Donnees
var plafond: float
var duree_max: float


func avant_chaque() -> void:
	d = AidesPartie.donnees()
	e = Ennemis.new(d)
	var vuln: Dictionary = d.partie["vulnerabilite"]
	plafond = float(vuln["plafond"])
	duree_max = float(vuln["duree_max"])


func _ajouter(armure: int = Types.Armure.AUCUNE, pv: float = 100000.0) -> int:
	return e.ajouter(0, Vector2(900, 0), pv, 60.0, 4.0, 40.0, 1.0, 2, armure)


func _avancer(secondes: float) -> void:
	for _k: int in roundi(secondes / DT):
		e.avancer(DT, Vector2.ZERO, 60.0, 1.0, 1.0)


func test_la_vulnerabilite_multiplie_les_degats_du_type_et_pas_les_autres() -> void:
	for type_touche: int in 5:
		var id := _ajouter()
		var i := e.indice_de(id)
		e.vulnerabiliser(i, type_touche, 0.2, 5.0)
		for type_degats: int in 5:
			var pv_avant := e.pv[i]
			var reels := e.infliger(i, 100.0, type_degats)
			var attendu := 120.0 if type_degats == type_touche else 100.0
			verifier_proche(
				reels, attendu, 0.01, "vulnérable %d, coup %d" % [type_touche, type_degats]
			)
			verifier_proche(pv_avant - e.pv[i], attendu, 0.01)
		e.purger()


func test_la_vulnerabilite_se_cumule_entre_coups_et_entre_armes_jusqu_au_plafond() -> void:
	for type_degats: int in 5:
		var i := e.indice_de(_ajouter())
		for application: int in 100:
			# Deux armes de ratios différents, 100 fois chacune.
			e.vulnerabiliser(i, type_degats, 0.03, 4.0)
			e.vulnerabiliser(i, type_degats, 0.07, 4.0)
			var somme := e.vulnerabilite[i * 5 + type_degats]
			verifier(somme <= plafond + 0.00001, "jamais au-dessus du plafond (%f)" % somme)
			verifier(is_finite(somme) and somme >= 0.0, "toujours fini et positif")
		verifier_proche(e.vulnerabilite[i * 5 + type_degats], plafond, 0.00001, "plafond exact")
		for autre: int in 5:
			if autre != type_degats:
				verifier_egal(
					e.vulnerabilite[i * 5 + autre], 0.0, "les autres types ne bougent pas"
				)


func test_deux_types_vulnerables_sont_plafonnes_chacun_de_leur_cote() -> void:
	var i := e.indice_de(_ajouter())
	for _k: int in 50:
		e.vulnerabiliser(i, Types.TypeDegats.TRANCHANT, 0.1, 3.0)
		e.vulnerabiliser(i, Types.TypeDegats.MAGIQUE, 0.1, 3.0)
	verifier_proche(e.vulnerabilite[i * 5 + Types.TypeDegats.TRANCHANT], plafond, 0.00001)
	verifier_proche(e.vulnerabilite[i * 5 + Types.TypeDegats.MAGIQUE], plafond, 0.00001)


func test_la_vulnerabilite_se_rafraichit_et_expire_sans_s_additionner_dans_le_temps() -> void:
	var i := e.indice_de(_ajouter())
	e.vulnerabiliser(i, 0, 0.2, 2.0)
	verifier((e.statuts[i] & Types.STATUT_VULNERABLE) != 0, "le bit est posé")
	_avancer(1.0)
	e.vulnerabiliser(i, 0, 0.1, 2.0)
	verifier_proche(e.vuln_reste[i], 2.0, 0.001, "repart de duree, pas de duree + reste")
	_avancer(1.9)
	verifier(e.vulnerabilite[i * 5] > 0.0, "encore vulnérable à 1,9 s")
	_avancer(0.3)
	verifier_egal(e.vulnerabilite[i * 5], 0.0, "retombée à zéro")
	verifier_egal(int(e.statuts[i]) & Types.STATUT_VULNERABLE, 0, "le bit est retiré")


func test_la_duree_est_bornee_par_duree_max() -> void:
	var i := e.indice_de(_ajouter())
	e.vulnerabiliser(i, 0, 0.1, duree_max * 10.0)
	verifier_proche(e.vuln_reste[i], duree_max, 0.001)


func test_la_vulnerabilite_ne_change_ni_le_poison_ni_la_brulure() -> void:
	var i := e.indice_de(_ajouter())
	e.vulnerabiliser(i, 0, 0.5, 5.0)
	e.empoisonner(i, 40.0, 2.0)
	e.bruler(i, 1.0, 40.0, 2.0)
	var avant := e.pv[i]
	_avancer(2.5)
	verifier_proche(avant - e.pv[i], 80.0, 0.05, "poison 40 + brûlure 40, sans la vulnérabilité")


func test_la_vulnerabilite_passe_avant_l_efficacite_d_armure() -> void:
	for type_degats: int in 5:
		for armure: int in 6:
			var i := e.indice_de(_ajouter(armure))
			e.vulnerabiliser(i, type_degats, 0.3, 5.0)
			var efficacite: float = (d.efficacite[type_degats] as Array)[armure]
			var reels := e.infliger(i, 100.0, type_degats)
			verifier_proche(
				reels, 100.0 * 1.3 * efficacite, 0.01, "type %d armure %d" % [type_degats, armure]
			)
			e.purger()


func test_un_ennemi_mort_ou_un_indice_inconnu_ne_plante_pas() -> void:
	var i := e.indice_de(_ajouter(Types.Armure.AUCUNE, 10.0))
	e.infliger(i, 1000.0, 0)
	for indice: int in [i, -1, 99, 100000]:
		e.vulnerabiliser(indice, 0, 0.1, 1.0)
		e.maudire_degats(indice, 0.1, 1.0)
		e.maudire_toucher(indice, 0.1, 1.0)
		e.repousser(indice, 50.0, Vector2.ZERO, 1.0)
	verifier_egal(e.vulnerabilite[i * 5], 0.0, "un mort ne reçoit rien")
	verifier_egal(e.vuln_reste[i], 0.0)


func test_un_ratio_non_fini_ou_negatif_est_ignore() -> void:
	var i := e.indice_de(_ajouter())
	for mauvais: float in [NAN, INF, -INF, -0.5, 0.0]:
		e.vulnerabiliser(i, 0, mauvais, 3.0)
		e.vulnerabiliser(i, 0, 0.1, mauvais)
		e.maudire_degats(i, mauvais, 3.0)
		e.maudire_toucher(i, 0.3, mauvais)
		e.repousser(i, mauvais, Vector2.ZERO, 1.0)
	e.vulnerabiliser(i, -1, 0.1, 1.0)
	e.vulnerabiliser(i, 5, 0.1, 1.0)
	for t: int in 5:
		verifier_egal(e.vulnerabilite[i * 5 + t], 0.0)
	verifier_egal(e.maudit_degats[i], 0.0)
	verifier_egal(e.maudit_toucher[i], 0.0)
	verifier_egal(e.statuts[i], 0, "aucun bit")
	verifier_proche(e.pos[i].x, 900.0)


func test_la_vulnerabilite_survit_a_la_purge() -> void:
	var a := _ajouter(Types.Armure.AUCUNE, 5.0)
	var b := _ajouter()
	var c := _ajouter()
	e.vulnerabiliser(e.indice_de(c), 2, 0.25, 4.0)
	e.infliger(e.indice_de(a), 100.0, 0)
	e.purger()
	var i := e.indice_de(c)
	verifier_proche(e.vulnerabilite[i * 5 + 2], 0.25, 0.00001, "la fiche suit son identifiant")
	verifier_egal(e.vulnerabilite[e.indice_de(b) * 5 + 2], 0.0, "et pas celle d'un voisin")
	verifier_egal(e.vulnerabilite.size(), e.taille * 5)


func test_le_pas_reste_sous_5_ms_avec_mille_ennemis_maudits_et_vulnerables() -> void:
	for k: int in 1000:
		var id := e.ajouter(0, Vector2(300.0 + k, 0), 1.0e6, 30.0, 4.0, 40.0, 1.0, 1, 0)
		var i := e.indice_de(id)
		e.vulnerabiliser(i, k % 5, 0.1, 5.0)
		e.maudire_degats(i, 0.3, 5.0)
		e.maudire_toucher(i, 0.2, 5.0)
	var debut := Time.get_ticks_usec()
	for _k: int in 20:
		e.avancer(DT, Vector2.ZERO, 60.0, 1.0, 1.0)
	var moyenne_ms := float(Time.get_ticks_usec() - debut) / 1000.0 / 20.0
	print("PERF ennemis maudits : %.3f ms par pas" % moyenne_ms)
	verifier(moyenne_ms < 5.0, "moins de 5 ms par pas (%f)" % moyenne_ms)
