extends CasDeTest
## Arène, côté tour : armure, épines, esquive, régénération, défaite simultanée, tirs et statuts.

const DT := 0.05
const GRAINE := 99
## PV des ennemis de test : assez bas pour que la précision 32 bits reste sous le centième.
const PV := 1000.0
## Cadence de 1/0,0625 s : une attaque tous les deux pas de 0,05 s, sans arrondi douteux.
const CADENCE_TEST := 20.0

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


# --- Aides -------------------------------------------------------------------------------------


func _mult() -> Dictionary:
	return {"pv": 1.0, "degats": 1.0, "vitesse": 0.0, "resistance_controle": 1.0}


func _avancer(a: Arene, pas: int) -> void:
	for _i: int in pas:
		a.avancer(DT)


func _vue(a: Arene) -> VueArene:
	return a.vue(Types.Phase.MANCHE, 10.0, -1, false)


## Un ennemi immobile (vitesse 0), sans armure (chaos ×1), prime nulle.
func _ennemi(
	a: Arene, position: Vector2, degats: float, portee: float, cadence: float, pv: float = PV
) -> int:
	return a.ennemis.ajouter(0, position, pv, 0.0, degats, portee, cadence, 0, 4)


func _avec_amelioration(a: Arene, id: String, nombre: int) -> void:
	a.inventaire.ameliorations[id] = nombre
	a.synchroniser()


# --- Armure de la tour -------------------------------------------------------------------------


func test_l_armure_de_la_tour_reduit_chaque_attaque() -> void:
	for armure: float in [0.0, 20.0, 1000.0]:
		d = Donnees.charger()
		d.partie["tour"]["armure"] = armure
		var a := Arene.new(d, GRAINE)
		_ennemi(a, Vector2(100, 0), 100.0, 40.0, 0.01)
		a.avancer(DT)
		# L'armure réduit chaque attaque, sans jamais la ramener sous le plancher de la tour
		# (`reduction_degats_max` : 15 % des dégâts bruts passent toujours).
		var plancher := 100.0 * (1.0 - float(d.partie["reduction_degats_max"]))
		var subi := maxf(Combat.degats_subis(100.0, armure), plancher)
		var attendu := float(d.partie["tour"]["pv"]) - subi
		verifier_proche(_vue(a).tour_pv, attendu, 0.01, "armure %s" % armure)
		verifier_proche(_vue(a).tour_armure, armure, 0.0001, "la vue affiche l'armure")
	verifier_proche(Combat.degats_subis(100.0, 20.0), 50.0, 0.01, "contrôle : 20 d'armure = −50 %")


func test_une_amelioration_d_armure_s_ajoute_a_celle_de_la_tour() -> void:
	d.partie["tour"]["armure"] = 17.0
	var a := Arene.new(d, GRAINE)
	_avec_amelioration(a, "plaques_de_laiton", 1)
	verifier_proche(_vue(a).tour_armure, 20.0, 0.0001, "17 + 3")


# --- Épines ------------------------------------------------------------------------------------


func test_epines_seulement_sur_les_attaquants_au_corps_a_corps() -> void:
	var a := Arene.new(d, GRAINE)
	_avec_amelioration(a, "couronne_d_epines", 1)  # 1,0 × dégâts
	var cac := _ennemi(a, Vector2(100, 0), 10.0, 40.0, 0.01)
	var archer := _ennemi(a, Vector2(0, 450), 10.0, 450.0, 0.01)
	a.avancer(DT)
	var i_cac := a.ennemis.indice_de(cac)
	var i_archer := a.ennemis.indice_de(archer)
	verifier_proche(a.ennemis.pv[i_cac], PV - 10.0, 0.01, "le corps à corps subit les épines")
	verifier_proche(a.ennemis.pv[i_archer], PV, 0.01, "l'archer à distance n'en subit pas")
	verifier_proche(_vue(a).tour_pv, 1000.0 - 20.0, 0.01, "la tour a pourtant subi les deux")
	verifier_proche(_vue(a).degats_infliges, 10.0, 0.01, "les épines comptent dans les dégâts")


func test_epines_proportionnelles_a_la_valeur() -> void:
	var a := Arene.new(d, GRAINE)
	_avec_amelioration(a, "herisson_de_fer", 1)  # 0,3
	var cac := _ennemi(a, Vector2(100, 0), 10.0, 40.0, 0.01)
	a.avancer(DT)
	verifier_proche(a.ennemis.pv[a.ennemis.indice_de(cac)], PV - 3.0, 0.01)


func test_sans_epines_l_attaquant_ne_subit_rien() -> void:
	var a := Arene.new(d, GRAINE)
	var cac := _ennemi(a, Vector2(100, 0), 10.0, 40.0, 0.01)
	a.avancer(DT)
	verifier_proche(a.ennemis.pv[a.ennemis.indice_de(cac)], PV, 0.0001)


# --- Esquive -----------------------------------------------------------------------------------


func test_sans_esquive_toutes_les_attaques_touchent() -> void:
	var a := Arene.new(d, GRAINE)
	_ennemi(a, Vector2(100, 0), 1.0, 40.0, CADENCE_TEST)  # une attaque par pas
	_avancer(a, 100)
	verifier_proche(_vue(a).tour_pv, 1000.0 - 100.0, 0.01, "100 attaques, 100 coups")


func test_une_esquive_tres_haute_evite_presque_tout() -> void:
	var a := Arene.new(d, GRAINE)
	_avec_amelioration(a, "meurtrieres_biaisees", 1000)  # 80 points
	_ennemi(a, Vector2(100, 0), 1.0, 40.0, CADENCE_TEST)
	_avancer(a, 400)
	var subi := 1000.0 - _vue(a).tour_pv
	# Le plancher de la tour (15 % des dégâts bruts) l'emporte : l'esquive ne la rend pas
	# invulnérable. Les 400 attaques valent 400 points bruts, quelques-unes passent en entier.
	var brut := 400.0
	var plancher := brut * (1.0 - float(d.partie["reduction_degats_max"]))
	verifier(subi >= plancher - 0.01, "au moins le plancher passe (reçu %s)" % subi)
	verifier(subi < plancher + 0.1 * brut, "peu au-delà du plancher (reçu %s)" % subi)


func test_esquive_moyenne_evite_une_part_des_attaques() -> void:
	var a := Arene.new(d, GRAINE)
	_avec_amelioration(a, "meurtrieres_biaisees", 12)  # 0,96 point → ≈ 49 %
	_ennemi(a, Vector2(100, 0), 1.0, 40.0, CADENCE_TEST)
	_avancer(a, 400)
	var subi := 1000.0 - _vue(a).tour_pv
	verifier(subi > 120.0 and subi < 280.0, "environ la moitié des 400 attaques (reçu %s)" % subi)


# --- Régénération et PV max --------------------------------------------------------------------


func test_la_regeneration_soigne_par_seconde() -> void:
	var a := Arene.new(d, GRAINE)
	_avec_amelioration(a, "mousse_de_guerison", 2)  # 3 PV/s
	a.pv = 500.0
	_avancer(a, 40)  # 2 s
	verifier_proche(_vue(a).tour_pv, 506.0, 0.01)


func test_la_regeneration_ne_depasse_jamais_les_pv_max() -> void:
	var a := Arene.new(d, GRAINE)
	_avec_amelioration(a, "seve_d_ambre", 5)  # 20 PV/s
	a.pv = 999.0
	_avancer(a, 200)
	verifier_proche(_vue(a).tour_pv, 1000.0, 0.0001, "plafonnée aux PV max")
	verifier(a.pv <= _vue(a).tour_pv_max)


func test_acheter_des_pv_max_soigne_du_meme_montant() -> void:
	var a := Arene.new(d, GRAINE)
	a.boutique.offres[0] = {
		"id": "fondations_de_pierre",
		"genre": Types.Genre.AMELIORATION,
		"rarete": Types.Rarete.COMMUNE,
		"prix": 240,
		"vendu": false,
	}
	a.pv = 400.0
	verifier_egal(a.acheter(0), Types.Resultat.OK)
	verifier_proche(_vue(a).tour_pv_max, 1300.0)
	verifier_proche(_vue(a).tour_pv, 700.0, 0.0001, "+300 PV max, +300 PV")


func test_la_regeneration_ne_depasse_pas_apres_une_baisse_des_pv_max() -> void:
	var a := Arene.new(d, GRAINE)
	_avec_amelioration(a, "mousse_de_guerison", 1)
	_avec_amelioration(a, "fondations_de_pierre", 1)
	a.pv = 1300.0
	# Un objet disparaît (aucun objet ne se vend aujourd'hui) : les PV se calent sur le nouveau max.
	a.inventaire.ameliorations.erase("fondations_de_pierre")
	a.synchroniser()
	_avancer(a, 20)
	verifier_proche(_vue(a).tour_pv_max, 1000.0)
	verifier(_vue(a).tour_pv <= 1000.0, "jamais au-dessus des PV max")


# --- Défaite et dernier ennemi -----------------------------------------------------------------


func _boss_a_un_pv(a: Arene) -> void:
	var mult := _mult()
	mult["pv"] = 0.0001  # 2 PV
	a.demarrer_boss(mult)
	a.ennemis.pos[0] = Vector2(80, 0)  # le boss attaque à distance : il s'arrête à sa portée (80)


func test_la_tour_qui_tombe_avec_le_dernier_ennemi_perd() -> void:
	# Au même pas, le boss meurt sous le tir de la tour et lui porte le coup fatal : la défaite
	# l'emporte (elle est évaluée en dernier, et la victoire exige une tour debout).
	var a := Arene.new(d, GRAINE)
	a.pv = 5.0
	a.inventaire.ajouter("de_pipe")
	a.synchroniser()
	_boss_a_un_pv(a)
	a.avancer(DT)
	verifier_egal(a.nombre_ennemis(), 0, "le boss est mort")
	verifier(a.est_detruite(), "et la tour aussi")
	verifier_faux(a.boss_vaincu(), "pas de victoire pour une tour détruite")


func test_la_tour_debout_au_dernier_ennemi_gagne() -> void:
	var a := Arene.new(d, GRAINE)
	a.inventaire.ajouter("de_pipe")
	a.synchroniser()
	_boss_a_un_pv(a)
	a.avancer(DT)
	verifier_egal(a.nombre_ennemis(), 0)
	verifier_faux(a.est_detruite())
	verifier(a.boss_vaincu(), "boss mort, tour debout : victoire")


func test_le_boss_tue_par_un_poison_donne_la_victoire() -> void:
	var a := Arene.new(d, GRAINE)
	var mult := _mult()
	mult["pv"] = 2000.0 / float(d.boss["pv"])  # 2 000 PV
	a.demarrer_boss(mult)
	a.ennemis.empoisonner(0, 2000.0, 1.0)
	_avancer(a, 10)
	verifier_faux(a.boss_vaincu(), "pas encore mort à mi-chemin")
	_avancer(a, 15)
	verifier_egal(a.nombre_ennemis(), 0, "le poison a tué le boss")
	verifier(a.boss_vaincu(), "la victoire ne dépend pas de la cause de la mort")
	verifier_egal(_vue(a).eliminations, 1, "une élimination")


# --- Armes -------------------------------------------------------------------------------------


func test_une_arme_tire_des_qu_un_ennemi_est_a_portee() -> void:
	var a := Arene.new(d, GRAINE)
	a.inventaire.ajouter("de_pipe")  # portée 600
	a.synchroniser()
	var loin := _ennemi(a, Vector2(1300, 0), 0.0, 30.0, 1.0)
	_avancer(a, 10)
	verifier_proche(a.ennemis.pv[a.ennemis.indice_de(loin)], PV, 0.0001, "hors de portée : rien")
	verifier_egal(_vue(a).evenements.size(), 0, "aucun tir dans le vide")
	var pres := _ennemi(a, Vector2(500, 0), 0.0, 30.0, 1.0)
	a.avancer(DT)
	verifier(a.ennemis.pv[a.ennemis.indice_de(pres)] < PV, "dans la portée : touché")
	var genres: Dictionary = {}
	for e: Dictionary in _vue(a).evenements:
		genres[e["k"]] = int(e["t"])
	verifier(genres.has("tir"), "un événement de tir")
	verifier_egal(genres["tir"], _vue(a).tick, "au tick courant")
	verifier(_vue(a).degats_infliges > 0.0)


func test_chaque_arme_du_contenu_reel_tire_sur_un_ennemi_a_portee() -> void:
	for id: String in d.armes:
		var a := Arene.new(d, GRAINE)
		a.inventaire.ajouter(id)
		a.synchroniser()
		var cible := _ennemi(a, Vector2(250, 0), 0.0, 30.0, 1.0, 4000.0)
		_avancer(a, 100)
		var i := a.ennemis.indice_de(cible)
		var touche := i < 0 or a.ennemis.pv[i] < 4000.0
		verifier(touche, "%s touche une cible à 250 unités" % id)


func test_le_vol_de_vie_soigne_la_tour() -> void:
	var a := Arene.new(d, GRAINE)
	_avec_amelioration(a, "gorgee_de_sang", 1)
	a.inventaire.ajouter("etincelle_runique")  # sans vol de vie propre
	a.synchroniser()
	a.pv = 500.0
	_ennemi(a, Vector2(300, 0), 0.0, 30.0, 1.0)
	a.avancer(DT)
	var soin := _vue(a).tour_pv - 500.0
	verifier_proche(soin, _vue(a).degats_infliges * 0.02, 0.0001, "2 % des dégâts réels")
	verifier(soin > 0.0)


func test_un_ennemi_tue_par_epines_poison_ou_arme_ne_verse_qu_une_prime() -> void:
	var a := Arene.new(d, GRAINE)
	_avec_amelioration(a, "couronne_d_epines", 1)
	a.inventaire.ajouter("de_pipe")
	a.synchroniser()
	var argent := a.economie.argent
	# Mort par épines : au corps à corps, 5 PV, dégâts 10 → renvoie 10.
	a.ennemis.ajouter(0, Vector2(100, 0), 5.0, 0.0, 10.0, 40.0, 0.01, 7, 4)
	# Mort par poison : loin, hors de portée.
	var p := a.ennemis.ajouter(0, Vector2(1300, 0), 100.0, 0.0, 0.0, 30.0, 1.0, 7, 4)
	a.ennemis.empoisonner(a.ennemis.indice_de(p), 100.0, 0.5)
	# Mort par l'arme : à portée, 1 PV.
	a.ennemis.ajouter(0, Vector2(0, 400), 1.0, 0.0, 0.0, 30.0, 1.0, 7, 4)
	_avancer(a, 30)
	verifier_egal(a.nombre_ennemis(), 0, "les trois sont morts")
	verifier_egal(_vue(a).eliminations, 3, "trois éliminations, pas une de plus")
	verifier_egal(a.economie.argent - argent, 21, "trois primes de 7, chacune une seule fois")
