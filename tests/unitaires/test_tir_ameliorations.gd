extends CasDeTest
## Les améliorations de dégâts, de classe et d'état au tir (T9.10) : ce que la joueuse obtient de la
## croissance, des armes communes, des classes d'arme, des états et du plafond du produit.

const DT := 0.05
const PV := 5000.0
const CENTRE := Vector2.ZERO
const CLASSES: Array[String] = ["onde", "portee_courte", "portee_longue", "commune"]

var d: Donnees
var e: Ennemis
var rng: RandomNumberGenerator
var stats: StatsTour


func avant_chaque() -> void:
	d = Donnees.charger()
	_neuf()
	stats = StatsTour.new()


func _neuf() -> void:
	e = Ennemis.new(d)
	rng = RandomNumberGenerator.new()
	rng.seed = 12345


func _p(recu: float, attendu: float, message: String = "", tolerance: float = 0.01) -> void:
	verifier_proche(recu, attendu, tolerance, message)


## Arme de test : un seul effet, tout le reste neutre (chaos ×1 contre toute armure).
func _def(
	effet: Dictionary,
	statuts: Array = [],
	degats: float = 10.0,
	recharge: float = 1.0,
	portee: int = 600
) -> Dictionary:
	return {
		"id": "arme_de_test",
		"nom": "Arme de test",
		"description": "Pour les tests.",
		"rarete": 0,
		"prix": 1,
		"type_degats": Types.TypeDegats.CHAOS,
		"degats": degats,
		"recharge": recharge,
		"portee": portee,
		"ciblage": Types.Ciblage.PLUS_PROCHE,
		"effets": [effet],
		"statuts": statuts,
	}


func _placer(pos: Vector2, pv: float = PV) -> int:
	return e.ajouter(0, pos, pv, 0.0, 0.0, 40.0, 1.0, 1, Types.Armure.AUCUNE)


func _pv(id: int) -> float:
	return e.pv[e.indice_de(id)]


func _pas(arme: ArmeEquipee) -> Tir.Bilan:
	var bilan := Tir.Bilan.new()
	Tir.avancer_arme(arme, DT, stats, e, CENTRE, d, rng, 1.0, bilan)
	return bilan


## Dégâts du premier tir d'une arme de test sur une cible neuve, avec les stats courantes.
func _degats_du_tir(def: Dictionary, lecture: Tir.Lecture = null) -> float:
	e = Ennemis.new(d)
	_placer(Vector2(300, 0))
	var bilan := Tir.Bilan.new()
	Tir.avancer_arme(ArmeEquipee.new(def), DT, stats, e, CENTRE, d, rng, 1.0, bilan, lecture)
	return bilan.degats


## Une arme de test qui est de la classe demandée et d'aucune autre, ou d'aucune classe.
func _arme_de_classe(classe: String) -> Dictionary:
	# Portée 900 : ni courte (≤ 750) ni longue (≥ 1 000), comme une arme sans classe de portée.
	var def := _def({"kind": "cible_unique"}, [], 10.0, 1.0, 900)
	def["rarete"] = Types.Rarete.PEU_COMMUNE
	match classe:
		"onde":
			def["effets"] = [{"kind": "onde", "vitesse": 400.0, "rayon_max": 400.0}]
		"portee_courte":
			def["portee"] = 750
		"portee_longue":
			def["portee"] = 1000
		"commune":
			def["rarete"] = Types.Rarete.COMMUNE
	return def


func test_chaque_classe_ne_boost_que_les_armes_de_sa_classe_dans_les_donnees() -> void:
	for classe: String in CLASSES:
		stats = StatsTour.new()
		stats.degats_classe = {classe: 0.5}
		var membres := 0
		var autres := 0
		for id: String in d.armes:
			var arme: Dictionary = d.armes[id]
			var attendu := 1.0
			match classe:
				"onde":
					for effet: Dictionary in arme["effets"]:
						if effet["kind"] == "onde":
							attendu = 1.5
				"portee_courte":
					attendu = 1.5 if int(arme["portee"]) <= 750 else 1.0
				"portee_longue":
					attendu = 1.5 if int(arme["portee"]) >= 1000 else 1.0
				"commune":
					attendu = 1.5 if int(arme["rarete"]) == Types.Rarete.COMMUNE else 1.0
			if attendu > 1.0:
				membres += 1
			else:
				autres += 1
			_p(stats.facteur_classe(arme), attendu, "%s pour %s" % [classe, id], 0.0001)
		verifier(membres > 0 and autres > 0, "%s : des armes dedans et dehors" % classe)


func test_chaque_classe_ne_boost_que_les_armes_de_sa_classe_au_tir() -> void:
	for classe: String in CLASSES:
		for autre: String in CLASSES:
			stats = StatsTour.new()
			var neutre := _degats_du_tir(_arme_de_classe(autre))
			stats.degats_classe = {classe: 0.5}
			var boostee := _degats_du_tir(_arme_de_classe(autre))
			var attendu := neutre * (1.5 if classe == autre else 1.0)
			_p(boostee, attendu, "classe %s sur une arme %s" % [classe, autre])
	# Une arme sans aucune classe (peu commune, portée 900) n'est jamais boostée.
	var sans_classe := _arme_de_classe("aucune")
	stats = StatsTour.new()
	var base := _degats_du_tir(sans_classe)
	stats.degats_classe = {"onde": 1.0, "portee_courte": 1.0, "portee_longue": 1.0, "commune": 1.0}
	_p(_degats_du_tir(sans_classe), base, "aucune classe, aucun bonus")


func test_une_arme_de_deux_classes_cumule_leurs_bonus_en_facteurs_separes() -> void:
	var def := _arme_de_classe("portee_courte")
	def["rarete"] = Types.Rarete.COMMUNE
	stats.degats_classe = {"portee_courte": 0.2, "commune": 0.5}
	_p(stats.facteur_classe(def), 1.2 * 1.5, "", 0.0001)


## Une arme de test qui pose les statuts demandés.
func _arme_a_statuts(statuts: Array) -> Dictionary:
	return _def({"kind": "cible_unique"}, statuts, 10.0, 1.0, 600)


func test_chaque_etat_boost_seulement_ce_qu_il_dit() -> void:
	var poison := {"kind": "poison", "total_ratio": 1.0, "duree": 4.0}
	var brulure := {"kind": "brulure", "ratio": 1.0, "duree": 4.0}
	var etourdi := {"kind": "etourdissement", "duree": 2.0}
	var def := _arme_a_statuts([poison, brulure, etourdi])
	var cible := _placer(Vector2(300, 0))
	_pas(ArmeEquipee.new(def))
	var i := e.indice_de(cible)
	var ref_poison := e.poison_reste[i]
	var ref_brulure := e.brule_reste[i]
	var ref_poison_duree := e.poison_duree[i]
	var ref_brulure_duree := e.brule_duree[i]
	var ref_etourdi := e.etourdi[i]
	var ref_degats := 10.0
	verifier(ref_poison > 0.0 and ref_brulure > 0.0 and ref_etourdi > 0.0, "référence posée")
	# Chaque réglage : (stat, état, ce qui bouge). Tout le reste doit rester à sa référence.
	var cas: Array[Array] = [
		["etat_degats", "poison", "poison_reste"],
		["etat_degats", "brulure", "brule_reste"],
		["etat_duree", "poison", "poison_duree"],
		["etat_duree", "brulure", "brule_duree"],
		["etat_duree", "etourdissement", "etourdi"],
	]
	for cas_courant: Array in cas:
		stats = StatsTour.new()
		var reglage: Dictionary = {String(cas_courant[1]): 0.5}
		stats.set(String(cas_courant[0]), reglage)
		_neuf()
		var c := _placer(Vector2(300, 0))
		var bilan := _pas(ArmeEquipee.new(def))
		var j := e.indice_de(c)
		var mesures: Dictionary = {
			"poison_reste": [e.poison_reste[j], ref_poison],
			"brule_reste": [e.brule_reste[j], ref_brulure],
			"poison_duree": [e.poison_duree[j], ref_poison_duree],
			"brule_duree": [e.brule_duree[j], ref_brulure_duree],
			"etourdi": [e.etourdi[j], ref_etourdi],
		}
		for nom: String in mesures:
			var mesure: Array = mesures[nom]
			var attendu := float(mesure[1]) * (1.5 if nom == String(cas_courant[2]) else 1.0)
			_p(float(mesure[0]), attendu, "%s/%s : %s" % [cas_courant[0], cas_courant[1], nom])
		_p(bilan.degats, ref_degats, "les dégâts du coup ne changent pas")


func test_sans_le_statut_sur_l_arme_un_bonus_d_etat_ne_change_rien() -> void:
	stats.etat_degats = {"poison": 5.0, "brulure": 5.0}
	stats.etat_duree = {"poison": 5.0, "brulure": 5.0, "etourdissement": 5.0}
	var cible := _placer(Vector2(300, 0))
	var bilan := _pas(ArmeEquipee.new(_arme_a_statuts([])))
	var i := e.indice_de(cible)
	_p(bilan.degats, 10.0)
	_p(e.poison_reste[i], 0.0)
	_p(e.brule_reste[i], 0.0)
	_p(e.etourdi[i], 0.0)
	verifier_egal(e.statuts[i], 0, "aucun statut posé")


## Les états d'ennemi que lit `degats_contre_etat`, posés par les méthodes publiques d'`Ennemis`.
func _poser_etat(cible: int, etat: String) -> void:
	var i := e.indice_de(cible)
	match etat:
		"etourdi":
			e.etourdir(i, 5.0, 1.0)
		"empoisonne":
			e.empoisonner(i, 10.0, 5.0)
		"ralenti":
			e.givrer(i, 1.0)


func test_les_degats_contre_un_etat_ne_valent_que_si_l_ennemi_a_cet_etat() -> void:
	var def := _arme_a_statuts([])
	for etat: String in ["etourdi", "empoisonne", "ralenti"]:
		for etat_cible: String in ["etourdi", "empoisonne", "ralenti", ""]:
			stats = StatsTour.new()
			stats.degats_contre_etat = {etat: 0.5}
			_neuf()
			var cible := _placer(Vector2(300, 0))
			if etat_cible != "":
				_poser_etat(cible, etat_cible)
			var avant := _pv(cible)
			_pas(ArmeEquipee.new(def))
			var infliges := avant - _pv(cible)
			var attendu := 15.0 if etat == etat_cible else 10.0
			_p(infliges, attendu, "bonus %s, cible %s" % [etat, etat_cible])


func test_les_degats_contre_un_etat_valent_aussi_pour_chaque_cible_d_une_zone() -> void:
	stats.degats_contre_etat = {"empoisonne": 1.0}
	var a := _placer(Vector2(300, 0))
	var b := _placer(Vector2(320, 0))
	_poser_etat(a, "empoisonne")
	var avant_a := _pv(a)
	var avant_b := _pv(b)
	_pas(ArmeEquipee.new(_def({"kind": "zone", "rayon": 100.0}, [], 10.0, 1.0, 600)))
	_p(avant_a - _pv(a), 20.0, "empoisonnée : ×2")
	_p(avant_b - _pv(b), 10.0, "saine : ×1")


# --- La croissance lit le temps de partie ------------------------------------------------------


func _stats_croissantes() -> StatsTour:
	var s := StatsTour.new()
	var cumul: Dictionary = {"A": 0.1}
	s.sommes_type[Types.TypeDegats.CHAOS] = cumul
	s.degats_type[Types.TypeDegats.CHAOS] = 1.1
	(
		s
		. degats_dynamiques
		. append(
			{
				"type": Types.TypeDegats.CHAOS,
				"categorie": "A",
				"croissance": 0.1,
				"croissance_max": 0.3,
				"par_arme_commune": 0.0,
				"n": 1,
			}
		)
	)
	return s


func test_la_croissance_des_degats_lit_le_temps_de_partie_de_la_lecture() -> void:
	stats = _stats_croissantes()
	var def := _arme_de_classe("aucune")
	var resultats: Array[float] = []
	# 0, 1 et 10 tranches de 30 s, puis la manche 60 du mode sans fin (une heure et demie).
	for temps: float in [0.0, 30.0, 300.0, 5400.0]:
		var lecture := Tir.Lecture.new()
		lecture.temps_s = temps
		resultats.append(_degats_du_tir(def, lecture))
	_p(resultats[0], 11.0, "0 tranche : 1,1")
	_p(resultats[1], 12.0, "1 tranche : 1,2")
	_p(resultats[2], 14.0, "10 tranches : borné à +0,3 : 1,4")
	_p(resultats[3], 14.0, "mode sans fin : toujours 1,4")


func test_les_armes_communes_du_type_possedees_viennent_de_la_lecture() -> void:
	stats = StatsTour.new()
	stats.sommes_type[Types.TypeDegats.CHAOS] = {"C": 0.0}
	(
		stats
		. degats_dynamiques
		. append(
			{
				"type": Types.TypeDegats.CHAOS,
				"categorie": "C",
				"croissance": 0.0,
				"croissance_max": 0.0,
				"par_arme_commune": 0.1,
				"n": 1,
			}
		)
	)
	var def := _arme_de_classe("aucune")
	var lecture := Tir.Lecture.new()
	lecture.exemplaires = {"de_pipe": 2, "etincelle_runique": 1, "lame_de_fil": 3, "disque_scie": 4}
	# Chaos communes : de_pipe ×2 ; les armes d'un autre type ou peu communes ne comptent pas.
	_p(_degats_du_tir(def, lecture), 12.0, "deux communes du chaos : ×1,2")
	lecture.exemplaires = {}
	_p(_degats_du_tir(def, lecture), 10.0, "aucune commune")
	var comptes := Tir.communes_par_type({"de_pipe": 2, "lame_de_fil": 3, "disque_scie": 4}, d)
	verifier_egal(comptes[Types.TypeDegats.CHAOS], 2)
	verifier_egal(comptes[Types.TypeDegats.TRANCHANT], 3, "disque_scie est peu commune")


# --- Le plafond du produit ---------------------------------------------------------------------


func test_le_produit_des_facteurs_ne_depasse_jamais_le_plafond() -> void:
	var plafond := float((d.partie["ameliorations"] as Dictionary)["facteur_degats_max"])
	stats.degats_type[Types.TypeDegats.CHAOS] = 3.0
	stats.degats_global = 3.0
	stats.degats_classe = {"portee_courte": 2.0, "commune": 2.0}
	stats.degats_contre_etat = {"empoisonne": 2.0}
	var def := _arme_de_classe("portee_courte")
	def["rarete"] = Types.Rarete.COMMUNE
	var base := 10.0
	_p(_degats_du_tir(def), base * plafond, "le tir est borné à ×plafond")
	# Même contre une cible qui déclenche aussi le bonus contre-état.
	_neuf()
	var cible := _placer(Vector2(300, 0), 1.0e6)
	_poser_etat(cible, "empoisonne")
	var avant := _pv(cible)
	_pas(ArmeEquipee.new(def))
	_p(avant - _pv(cible), base * plafond, "contre-état compris : toujours ×plafond", 0.5)


func test_un_produit_sous_le_plafond_n_est_pas_tronque() -> void:
	stats.degats_type[Types.TypeDegats.CHAOS] = 1.5
	stats.degats_global = 1.2
	stats.degats_classe = {"portee_courte": 0.5}
	var def := _arme_de_classe("portee_courte")
	_p(_degats_du_tir(def), 10.0 * 1.5 * 1.2 * 1.5, "produit exact")
