extends CasDeTest
## Arène : apparitions, reproductibilité, défaite, boss, convoi, vue et intentions invalides.

const DT := 0.05
const GRAINE := 4242

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


# --- Aides -------------------------------------------------------------------------------------


func _mult(vitesse: float = 1.0, pv: float = 1.0, degats: float = 1.0) -> Dictionary:
	return {"pv": pv, "degats": degats, "vitesse": vitesse, "resistance_controle": 1.0}


func _avancer(a: Arene, pas: int) -> void:
	for _i: int in pas:
		a.avancer(DT)


func _vue(a: Arene) -> VueArene:
	return a.vue(Types.Phase.MANCHE, 10.0, -1, false)


## Une arène immobile : les ennemis apparaissent sur le cercle et n'en bougent plus.
func _arene_immobile(manche: int, graine: int = GRAINE) -> Arene:
	var a := Arene.new(d, graine)
	a.demarrer_manche(manche, 0, _mult(0.0))
	return a


# --- Apparitions -------------------------------------------------------------------------------


func test_intervalle_2_s_a_la_manche_1() -> void:
	var a := _arene_immobile(1)
	_avancer(a, 39)
	verifier_egal(a.nombre_ennemis(), 0, "pas d'apparition avant 2,0 s")
	_avancer(a, 1)
	verifier_egal(a.nombre_ennemis(), 1, "la première apparition a lieu à 2,0 s")
	_avancer(a, 360)
	verifier_egal(a.nombre_ennemis(), 10, "une apparition toutes les 2,0 s : 10 en 20 s")


func test_intervalle_1_92_s_a_la_manche_2() -> void:
	var a := _arene_immobile(2)
	_avancer(a, 38)
	verifier_egal(a.nombre_ennemis(), 0, "rien à 1,90 s")
	_avancer(a, 1)
	verifier_egal(a.nombre_ennemis(), 1, "la première à 1,92 s (pas de 1,95 s)")
	_avancer(a, 37)
	verifier_egal(a.nombre_ennemis(), 1, "la deuxième pas avant 3,84 s")
	_avancer(a, 1)
	verifier_egal(a.nombre_ennemis(), 2, "la deuxième à 3,84 s")
	_avancer(a, 323)
	verifier_egal(a.nombre_ennemis(), 10, "10 apparitions en 20 s")


func test_intervalle_par_manche_jusqu_au_plancher() -> void:
	# Apparitions en 10 s (200 pas) : floor(10 / max(0,1 ; 2,0 − 0,08 × (manche − 1))).
	var plancher := float(d.partie["spawn_plancher"])
	for manche: int in [1, 2, 10, 20, 24, 25, 26, 40, 100]:
		var intervalle := maxf(plancher, 2.0 - 0.08 * float(manche - 1))
		var attendu := floori(10.0 / intervalle + 1e-6)
		var a := _arene_immobile(manche)
		_avancer(a, 200)
		verifier_egal(a.nombre_ennemis(), attendu, "manche %d : %d apparitions" % [manche, attendu])


func test_plancher_0_1_s_des_la_manche_25() -> void:
	for manche: int in [25, 26, 60]:
		var a := _arene_immobile(manche)
		_avancer(a, 200)
		verifier_egal(a.nombre_ennemis(), 100, "manche %d : 10 par seconde" % manche)
	var avant := _arene_immobile(24)
	_avancer(avant, 200)
	verifier(
		avant.nombre_ennemis() < 100, "à la manche 24, l'intervalle (0,16 s) est encore > 0,1 s"
	)


func test_pas_d_apparition_pendant_la_preparation() -> void:
	var a := Arene.new(d, GRAINE)
	_avancer(a, 800)
	verifier_egal(a.nombre_ennemis(), 0, "la préparation n'invoque personne")


func test_apparitions_sur_le_cercle_exact_a_des_angles_dans_0_tau() -> void:
	var a := _arene_immobile(25)
	_avancer(a, 800)
	var rayon := float(d.partie["rayon_spawn"])
	var octants: Dictionary = {}
	verifier(a.ennemis.taille >= 300, "assez d'ennemis pour juger la répartition")
	for i: int in a.ennemis.taille:
		var p := a.ennemis.pos[i]
		verifier_proche(p.length(), rayon, 0.05, "à 1300 unités de la tour")
		var angle := fposmod(p.angle(), TAU)
		verifier(angle >= 0.0 and angle < TAU, "angle dans [0, TAU)")
		octants[int(angle / (TAU / 8.0))] = true
	verifier_egal(octants.size(), 8, "tous les huit secteurs reçoivent des ennemis")


func test_graines_differentes_donnent_des_apparitions_differentes() -> void:
	var a := _arene_immobile(25, 1)
	var b := _arene_immobile(25, 2)
	_avancer(a, 100)
	_avancer(b, 100)
	verifier_egal(a.nombre_ennemis(), b.nombre_ennemis(), "même cadence")
	verifier_different(a.ennemis.pos, b.ennemis.pos, "mais pas les mêmes positions")


func test_les_ennemis_recoivent_les_multiplicateurs_de_la_manche() -> void:
	var a := Arene.new(d, GRAINE)
	a.demarrer_manche(3, 1, _mult(2.0, 3.0, 5.0))
	_avancer(a, 40)
	var fam: Dictionary = d.familles[1]
	verifier_egal(a.nombre_ennemis(), 1)
	verifier_proche(a.ennemis.pv_max[0], float(fam["pv"]) * 3.0, 0.01, "PV × 3")
	verifier_proche(a.ennemis.vitesse[0], float(fam["vitesse"]) * 2.0, 0.01, "vitesse × 2")
	verifier_proche(a.ennemis.degats[0], float(fam["degats"]) * 5.0, 0.01, "dégâts × 5")
	verifier_egal(int(a.ennemis.famille[0]), 1)
	verifier_egal(int(a.ennemis.armure[0]), int(fam["armure"]))
	verifier_egal(int(a.ennemis.prime[0]), int(fam["prime"]))


# --- Reproductibilité --------------------------------------------------------------------------


## Mêmes intentions aux mêmes pas : achat, relance, vente, nouvelle manche.
func _jouer(a: Arene, vues: Array[Dictionary]) -> void:
	a.demarrer_manche(1, 0, _mult(8.0))
	for pas: int in 2000:
		if pas == 10:
			a.acheter(0)
		if pas == 200:
			a.relancer()
		if pas == 210:
			a.acheter(1)
		if pas == 600:
			a.acheter(2)
		if pas == 900:
			a.vendre(0)
		if pas == 1000:
			a.demarrer_manche(2, 3, _mult(8.0))
		a.avancer(DT)
		if (pas + 1) % 100 == 0:
			vues.append(_vue(a).to_dict())


func test_reproductibilite_meme_graine_memes_intentions_2000_pas() -> void:
	var va: Array[Dictionary] = []
	var vb: Array[Dictionary] = []
	_jouer(Arene.new(d, 777), va)
	_jouer(Arene.new(d, 777), vb)
	verifier_egal(va.size(), 20)
	for k: int in va.size():
		verifier_egal(va[k], vb[k], "vue identique au pas %d" % ((k + 1) * 100))
	var dernier: Dictionary = va[va.size() - 1]
	var ennemis_id: PackedInt32Array = dernier["ennemis_id"]
	verifier(ennemis_id.size() > 0, "la partie rejouée n'est pas vide")


func test_une_graine_differente_change_la_partie() -> void:
	var va: Array[Dictionary] = []
	var vb: Array[Dictionary] = []
	_jouer(Arene.new(d, 777), va)
	_jouer(Arene.new(d, 778), vb)
	verifier_different(va, vb)


# --- Défaite -----------------------------------------------------------------------------------


func _arene_fragile() -> Arene:
	var a := Arene.new(d, GRAINE)
	a.pv = 5.0
	a.ennemis.ajouter(1, Vector2(100, 0), 1000.0, 0.0, 10.0, 40.0, 1.0, 1, false, 4)
	return a


func test_defaite_a_pv_zero_emet_tour_detruite_une_seule_fois() -> void:
	var a := _arene_fragile()
	var compteur: Array[int] = [0]
	a.tour_detruite.connect(func() -> void: compteur[0] += 1)
	verifier_faux(a.est_detruite())
	_avancer(a, 400)
	verifier(a.est_detruite(), "la tour est détruite")
	verifier_egal(compteur[0], 1, "signal émis une seule fois malgré 400 pas")
	verifier_egal(_vue(a).phase, Types.Phase.DEFAITE, "la vue annonce la défaite")
	verifier_proche(_vue(a).tour_pv, 0.0, 0.0001, "PV de la tour à 0, jamais négatifs")


func test_arene_detruite_refuse_toute_intention() -> void:
	var a := _arene_fragile()
	_avancer(a, 100)
	verifier(a.est_detruite())
	var argent := a.economie.argent
	verifier_egal(a.acheter(0), Types.Resultat.ARENE_MORTE)
	verifier_egal(a.acheter(99), Types.Resultat.ARENE_MORTE, "même un indice invalide")
	verifier_egal(a.relancer(), Types.Resultat.ARENE_MORTE)
	verifier_egal(a.vendre(0), Types.Resultat.ARENE_MORTE)
	verifier_egal(a.choisir_marche_noir("x"), Types.Resultat.ARENE_MORTE)
	verifier_egal(a.economie.argent, argent, "rien n'est débité")


func test_arene_detruite_est_figee() -> void:
	var a := _arene_fragile()
	_avancer(a, 100)
	var avant := _vue(a).to_dict()
	_avancer(a, 100)
	var apres := _vue(a).to_dict()
	verifier_egal(apres["tick"], avant["tick"], "le temps de l'arène s'arrête")
	verifier_egal(apres["ennemis_pos"], avant["ennemis_pos"], "les ennemis ne bougent plus")


# --- Boss et convoi ----------------------------------------------------------------------------


func test_boss_arrete_les_apparitions_normales() -> void:
	var a := Arene.new(d, GRAINE)
	a.demarrer_manche(31, 0, _mult(0.0))
	_avancer(a, 100)
	var avant := a.nombre_ennemis()
	verifier(avant > 0, "des ennemis normaux étaient apparus")
	a.demarrer_boss(_mult(0.0))
	verifier_egal(a.nombre_ennemis(), avant + 1, "le boss s'ajoute")
	_avancer(a, 1000)
	verifier_egal(a.nombre_ennemis(), avant + 1, "plus aucune apparition normale")
	verifier_faux(a.boss_vaincu())


func test_boss_porte_les_donnees_du_boss() -> void:
	var a := Arene.new(d, GRAINE)
	a.demarrer_boss(_mult(1.0, 2.0, 3.0))
	verifier_egal(a.nombre_ennemis(), 1)
	verifier_proche(a.ennemis.pv_max[0], float(d.boss["pv"]) * 2.0, 1.0, "PV du boss × 2")
	verifier_proche(a.ennemis.degats[0], float(d.boss["degats"]) * 3.0, 0.01)
	verifier_egal(int(a.ennemis.armure[0]), Types.Armure.BOSS)
	verifier_egal(int(a.ennemis.famille[0]), d.familles.size() + 1, "famille de boss distincte")
	verifier_proche(a.ennemis.pos[0].length(), 1300.0, 0.05)


func test_convoi_verse_une_prime_elevee_et_n_inflige_aucun_degat() -> void:
	var a := Arene.new(d, GRAINE)
	a.demarrer_manche(5, d.familles.size(), _mult(10.0))
	_avancer(a, 100)
	verifier_egal(a.nombre_ennemis(), 2, "un convoi toutes les 1,68 s")
	verifier_egal(int(a.ennemis.famille[0]), d.familles.size(), "famille convoi")
	verifier_egal(int(a.ennemis.prime[0]), int(d.convoi["prime"]))
	_avancer(a, 300)
	# Les convois ont rejoint la tour : aucun dégât, et la tour est intacte.
	verifier_proche(_vue(a).tour_pv, float(d.partie["tour"]["pv"]), 0.0001, "aucun dégât")
	var argent := a.economie.argent
	var tues := a.nombre_ennemis()
	for i: int in a.ennemis.taille:
		a.ennemis.infliger(i, 1e9, Types.TypeDegats.CHAOS)
	a.avancer(DT)
	verifier_egal(
		a.economie.argent - argent, tues * int(d.convoi["prime"]), "chaque convoi verse 120"
	)


# --- Vue ---------------------------------------------------------------------------------------


func test_vue_quatre_offres_huit_armes_tableaux_alignes() -> void:
	var a := Arene.new(d, GRAINE)
	a.demarrer_manche(1, 0, _mult(1.0))
	for _i: int in 8:
		a.inventaire.ajouter("de_pipe")
	a.synchroniser()
	_avancer(a, 300)
	var v := _vue(a)
	verifier_egal(v.offres.size(), 4, "quatre offres")
	verifier_egal(v.armes.size(), 8, "huit armes")
	var n := v.ennemis_id.size()
	verifier_egal(v.ennemis_pos.size(), n)
	verifier_egal(v.ennemis_famille.size(), n)
	verifier_egal(v.ennemis_pv.size(), n)
	verifier_egal(v.ennemis_statuts.size(), n)
	verifier_egal(n, a.nombre_ennemis())
	verifier_non_nul(VueArene.from_dict(v.to_dict()), "la vue est sérialisable")


func test_vue_champs_de_base() -> void:
	var a := Arene.new(d, GRAINE)
	var v := a.vue(Types.Phase.PREPARATION, 30.0, 2, true)
	verifier_egal(v.phase, Types.Phase.PREPARATION)
	verifier_proche(v.temps_restant, 30.0)
	verifier_egal(v.prochaine_famille, 2)
	verifier_egal(v.prochaine_armure, int(d.familles[2]["armure"]), "armure de la famille annoncée")
	verifier(v.sans_fin)
	verifier_proche(v.tour_pv, float(d.partie["tour"]["pv"]))
	verifier_proche(v.tour_pv_max, float(d.partie["tour"]["pv"]))
	verifier_egal(v.argent, int(d.economie["or_depart"]))
	verifier_egal(v.revenu, 20)
	verifier_proche(v.revenu_dans, 10.0)
	verifier_egal(v.cout_relance, 50)
	verifier_egal(v.relances_gratuites, 0)
	verifier_egal(v.manche, 0)
	var convoi := a.vue(Types.Phase.MANCHE, 5.0, d.familles.size(), false)
	verifier_egal(convoi.prochaine_armure, Types.Armure.AUCUNE, "le convoi n'a pas d'armure")
	var aucune := a.vue(Types.Phase.MANCHE, 5.0, -1, false)
	verifier_egal(aucune.prochaine_armure, Types.Armure.AUCUNE)
	verifier_egal(aucune.prochaine_famille, -1)


func test_les_evenements_sont_vides_apres_lecture() -> void:
	var a := Arene.new(d, GRAINE)
	a.inventaire.ajouter("de_pipe")
	a.synchroniser()
	a.ennemis.ajouter(0, Vector2(300, 0), 1000.0, 0.0, 0.0, 30.0, 1.0, 1, false, 4)
	a.avancer(DT)
	var premiere := _vue(a)
	verifier(premiere.evenements.size() > 0, "un tir est arrivé")
	verifier_egal(_vue(a).evenements.size(), 0, "la lecture vide les événements")


func test_la_vue_ne_partage_rien_avec_l_arene() -> void:
	var a := Arene.new(d, GRAINE)
	var v := _vue(a)
	v.offres[0]["vendu"] = true
	v.ameliorations["x"] = 3
	verifier_faux(bool(_vue(a).offres[0]["vendu"]))
	verifier_faux(_vue(a).ameliorations.has("x"))


func test_les_evenements_ont_le_tick_courant_et_les_morts_sont_signales() -> void:
	var a := Arene.new(d, GRAINE)
	a.inventaire.ajouter("de_pipe")
	a.synchroniser()
	a.ennemis.ajouter(0, Vector2(300, 0), 1.0, 0.0, 0.0, 30.0, 1.0, 1, false, 4)
	_avancer(a, 3)
	var v := _vue(a)
	var genres: Dictionary = {}
	for e: Dictionary in v.evenements:
		genres[e["k"]] = true
		verifier(int(e["t"]) >= 1 and int(e["t"]) <= v.tick, "tick d'arène, pas 0")
	verifier(genres.has("tir"), "tir signalé")
	verifier(genres.has("mort"), "mort signalée")
	verifier_non_nul(VueArene.from_dict(v.to_dict()))


func test_les_evenements_ne_s_accumulent_pas_sans_fin() -> void:
	d.partie["tour"]["pv"] = 1e9
	var a := Arene.new(d, GRAINE)
	for _i: int in 8:
		a.inventaire.ajouter("de_pipe")
	a.synchroniser()
	a.demarrer_manche(40, 0, _mult(5.0))
	_avancer(a, 4000)
	verifier_egal(_vue(a).evenements.size(), 2000, "des milliers de tirs, la file reste bornée")


# --- Intentions invalides ----------------------------------------------------------------------


func test_intentions_invalides_sont_refusees_sans_effet() -> void:
	var a := Arene.new(d, GRAINE)
	a.inventaire.ajouter("de_pipe")
	a.synchroniser()
	var avant := _vue(a).to_dict()
	for i: int in [-1, 4, 8, 99]:
		verifier_egal(a.acheter(i), Types.Resultat.INDICE_INVALIDE, "acheter(%d)" % i)
	for i: int in [-1, 1, 8, 99]:
		verifier_egal(a.vendre(i), Types.Resultat.INDICE_INVALIDE, "vendre(%d)" % i)
	verifier_egal(_vue(a).to_dict(), avant, "aucun effet")
