extends CasDeTest
## Armes dont les dégâts suivent un état de la tour (M5) ou les épines (M10) : PV maximum, copies,
## améliorations possédées, et le plafond qui les borne.

const DT := 0.05
const BASE := 100.0
const PLAFOND := 4.0

var d: Donnees


func avant_chaque() -> void:
	d = AidesPartie.donnees()


func _arme(champs: Dictionary = {}) -> Dictionary:
	var arme: Dictionary = {"degats": BASE}
	arme.merge(champs)
	return arme


func _dmg(
	arme: Dictionary,
	pv_max: float = 1000.0,
	exemplaires: int = 1,
	par_stat: Dictionary = {},
	temps: float = 0.0,
	stats: StatsTour = StatsTour.new(),
	mana_max: float = 0.0
) -> float:
	return Tir.degats_de_base(arme, stats, pv_max, exemplaires, par_stat, temps, mana_max, PLAFOND)


func test_degats_par_pv_max_ajoute_ratio_fois_les_pv_maximum_de_la_tour() -> void:
	var arme := _arme({"degats_par_pv_max": 0.01})
	verifier_proche(_dmg(arme, 1000.0), 110.0, 0.0001)
	verifier_proche(_dmg(arme, 2000.0), 120.0, 0.0001, "suit le maximum de la tour")
	verifier_proche(_dmg(arme, 0.0), BASE, 0.0001, "tour sans PV maximum : aucun bonus")


func test_degats_par_exemplaire_croit_avec_chaque_copie() -> void:
	var arme := _arme({"degats_par_exemplaire": 0.2})
	verifier_proche(_dmg(arme, 1000.0, 1), BASE, 0.0001, "une seule copie : aucun bonus")
	verifier_proche(_dmg(arme, 1000.0, 2), 120.0, 0.0001)
	verifier_proche(_dmg(arme, 1000.0, 5), 180.0, 0.0001)
	verifier_proche(_dmg(arme, 1000.0, 0), BASE, 0.0001, "un nombre aberrant ne retire rien")


func test_degats_par_amelioration_compte_chaque_exemplaire_achete() -> void:
	var arme := _arme({"degats_par_amelioration": {"stat": "cadence", "ratio": 0.1}})
	verifier_proche(_dmg(arme, 1000.0, 1, {}), BASE, 0.0001)
	verifier_proche(_dmg(arme, 1000.0, 1, {"cadence": 1}), 110.0, 0.0001)
	verifier_proche(_dmg(arme, 1000.0, 1, {"cadence": 3}), 130.0, 0.0001)
	verifier_proche(
		_dmg(arme, 1000.0, 1, {"esquive": 7}), BASE, 0.0001, "une autre stat ne compte pas"
	)


func test_le_bonus_total_est_borne_meme_avec_255_exemplaires_et_toutes_les_ameliorations() -> void:
	var arme := _arme(
		{
			"degats_par_pv_max": 1.0,
			"degats_par_exemplaire": 1.0,
			"degats_par_amelioration": {"stat": "cadence", "ratio": 1.0},
		}
	)
	var resultat := _dmg(arme, 1.0e9, 255, {"cadence": 87})
	verifier_proche(
		resultat, BASE * (1.0 + PLAFOND), 0.001, "au plus 4 × les dégâts de base en bonus"
	)
	verifier(is_finite(resultat))
	var avec_donnees := Tir.degats_de_base(
		arme,
		StatsTour.new(),
		1.0e9,
		255,
		{"cadence": 87},
		0.0,
		0.0,
		float((d.partie["armes"] as Dictionary)["bonus_selon_stat_max"])
	)
	verifier(
		(
			avec_donnees
			<= (
				BASE * (1.0 + float((d.partie["armes"] as Dictionary)["bonus_selon_stat_max"]))
				+ 0.001
			)
		)
	)


func test_les_trois_bonus_et_la_mana_s_additionnent_avant_le_critique() -> void:
	var arme := _arme(
		{
			"degats_par_mana_max": 0.5,
			"degats_par_pv_max": 0.01,
			"degats_par_exemplaire": 0.1,
			"degats_par_amelioration": {"stat": "cadence", "ratio": 0.05},
		}
	)
	# 100 + 0,5 × 40 (mana) + 0,01 × 1 000 + 0,1 × 2 × 100 + 0,05 × 3 × 100 = 100 + 20 + 10 + 20 + 15.
	verifier_proche(
		_dmg(arme, 1000.0, 3, {"cadence": 3}, 0.0, StatsTour.new(), 40.0), 165.0, 0.0001
	)
	# Le critique n'est pas dans cette fonction : il multiplie le résultat, une fois.
	var stats := StatsTour.new()
	stats.critique_chance = 0.0
	verifier_proche(_dmg(arme, 1000.0, 3, {"cadence": 3}, 0.0, stats, 40.0), 165.0, 0.0001)


func test_un_champ_absent_ou_nul_ne_change_rien() -> void:
	for id: String in d.armes:
		var arme: Dictionary = d.armes[id]
		var attendu := float(arme["degats"]) + float(arme["degats_par_mana_max"]) * 40.0
		if float(arme["degats_par_pv_max"]) == 0.0 and float(arme["degats_par_exemplaire"]) == 0.0:
			if float((arme["degats_par_amelioration"] as Dictionary)["ratio"]) == 0.0:
				var recu := Tir.degats_de_base(
					arme, StatsTour.new(), 1000.0, 7, {"cadence": 9}, 500.0, 40.0
				)
				verifier_proche(recu, attendu, 0.0001, id)
	# Un champ à zéro, négatif ou non fini est neutre.
	for mauvais: float in [0.0, -1.0, NAN, INF]:
		var arme := _arme(
			{
				"degats_par_pv_max": mauvais,
				"degats_par_exemplaire": mauvais,
				"degats_par_mana_max": mauvais
			}
		)
		verifier_proche(_dmg(arme, 1000.0, 4), BASE, 0.0001, "champ %s" % mauvais)


func test_le_type_secondaire_epines_multiplie_les_degats_par_le_facteur_d_epines() -> void:
	var arme := _arme({"type_secondaire": "epines"})
	var sans := StatsTour.new()
	verifier_proche(_dmg(arme, 1000.0, 1, {}, 100.0, sans), BASE, 0.0001, "sans épines : inchangé")
	var avec := StatsTour.new()
	avec.epines_degats = 0.5
	avec.epines_croissantes = 0.1
	avec.epines_croissantes_max = 1.0
	verifier_proche(_dmg(arme, 1000.0, 1, {}, 0.0, avec), BASE * 1.5, 0.0001)
	verifier_proche(
		_dmg(arme, 1000.0, 1, {}, 60.0, avec), BASE * 1.7, 0.0001, "deux tranches de 30 s"
	)
	var autre := _arme({})
	verifier_proche(_dmg(autre, 1000.0, 1, {}, 60.0, avec), BASE, 0.0001, "sans le type secondaire")


func test_l_efficacite_contre_l_armure_reste_celle_du_type_principal() -> void:
	var e := Ennemis.new(d)
	var arme_def := {
		"id": "arme_de_test",
		"nom": "Arme de test",
		"description": "x",
		"rarete": 0,
		"prix": 1,
		"type_degats": Types.TypeDegats.TRANCHANT,
		"degats": 100.0,
		"recharge": 1.0,
		"portee": 600,
		"ciblage": Types.Ciblage.PLUS_PROCHE,
		"effets": [{"kind": "cible_unique"}],
		"statuts": [],
		"type_secondaire": "epines",
	}
	var stats := StatsTour.new()
	stats.epines_degats = 1.0
	for armure: int in 6:
		e = Ennemis.new(d)
		var cible := e.indice_de(
			e.ajouter(0, Vector2(300, 0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, armure)
		)
		var bilan := Tir.Bilan.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		Tir.avancer_arme(ArmeEquipee.new(arme_def), DT, stats, e, Vector2.ZERO, d, rng, 1.0, bilan)
		var efficacite: float = (d.efficacite[Types.TypeDegats.TRANCHANT] as Array)[armure]
		verifier_proche(bilan.degats, 100.0 * 2.0 * efficacite, 0.01, "armure %d" % armure)
		verifier(e.pv[cible] < 1.0e6)


func test_le_tir_lit_les_pv_maximum_les_copies_et_les_ameliorations_de_la_lecture() -> void:
	var e := Ennemis.new(d)
	e.ajouter(0, Vector2(300, 0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, Types.Armure.AUCUNE)
	var def := {
		"id": "arme_selon",
		"nom": "Arme selon",
		"description": "x",
		"rarete": 0,
		"prix": 1,
		"type_degats": Types.TypeDegats.CHAOS,
		"degats": 100.0,
		"recharge": 1.0,
		"portee": 600,
		"ciblage": Types.Ciblage.PLUS_PROCHE,
		"effets": [{"kind": "cible_unique"}],
		"statuts": [],
		"degats_par_pv_max": 0.01,
		"degats_par_exemplaire": 0.1,
		"degats_par_amelioration": {"stat": "cadence", "ratio": 0.05},
	}
	var lecture := Tir.Lecture.new()
	lecture.pv_max_tour = 1000.0
	lecture.exemplaires = {"arme_selon": 3}
	lecture.ameliorations_par_stat = {"cadence": 2}
	var bilan := Tir.Bilan.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	Tir.avancer_arme(
		ArmeEquipee.new(def), DT, StatsTour.new(), e, Vector2.ZERO, d, rng, 1.0, bilan, lecture
	)
	# 100 + 0,01 × 1 000 + 0,1 × 2 × 100 + 0,05 × 2 × 100 = 140.
	verifier_proche(bilan.degats, 140.0, 0.01)
