extends CasDeTest
## Ce que le joueur obtient de son or : un achat se paie exactement, un versement tombe à
## chaque période de 10 s, les primes et bonus suivent leurs paliers, et aucune donnée
## absurde (dt négatif, NaN, infini, somme énorme) ne fait plafonner ni déborder la bourse.

const PERIODE := 10.0
const OR_HAUT := 2147483647


## Copie de `data/economie.json` : les tests relisent les paliers réels ici.
func _economie_reference() -> Dictionary:
	return {
		"or_depart": 500,
		"revenu_periode_s": 10,
		"revenu_base": [{"manche": 1, "valeur": 20}, {"manche": 6, "valeur": 30}],
		"prime_mult": [{"manche": 1, "valeur": 1.0}, {"manche": 10, "valeur": 1.5}],
	}


func _donnees(economie: Dictionary) -> Donnees:
	var brut: Dictionary = {}
	for nom: String in ["partie.json", "difficulte.json", "efficacite.json", "boutique.json"]:
		brut[nom] = _lire_reel(nom)
	brut["economie.json"] = economie
	brut["armes.json"] = []
	brut["ameliorations.json"] = []
	brut["ennemis.json"] = {"familles": [], "convoi": {}, "boss": {}}
	return Donnees.depuis_brut(brut)


func _lire_reel(nom: String) -> Variant:
	var texte := FileAccess.get_file_as_string("res://data/" + nom)
	return JSON.parse_string(texte)


func _eco(economie: Dictionary) -> Economie:
	var donnees := _donnees(economie)
	verifier_non_nul(donnees, "les données de test doivent être valides")
	return Economie.new(donnees)


func _eco_ref() -> Economie:
	return _eco(_economie_reference())


func _stats() -> StatsTour:
	return StatsTour.new()


# --- Or : départ, paiement, gain ----------------------------------------------------------------


func test_or_de_depart_vient_du_fichier_reel_economie_json() -> void:
	var reel: Dictionary = _lire_reel("economie.json")
	var eco := _eco(reel)
	verifier_egal(eco.argent, 500)


func test_or_de_depart_suit_la_donnee_quand_elle_change() -> void:
	var economie := _economie_reference()
	economie["or_depart"] = 1234
	verifier_egal(_eco(economie).argent, 1234)


func test_payer_le_prix_exact_vide_la_bourse() -> void:
	var eco := _eco_ref()
	verifier(eco.payer(500), "un achat au prix exact doit passer")
	verifier_egal(eco.argent, 0)


func test_payer_un_de_plus_que_l_or_est_refuse_sans_rien_changer() -> void:
	var eco := _eco_ref()
	verifier_faux(eco.peut_payer(501))
	verifier_faux(eco.payer(501), "un achat d'un de plus que l'or doit être refusé")
	verifier_egal(eco.argent, 500, "l'or ne doit pas bouger après un refus")


func test_payer_zero_passe_sans_effet() -> void:
	var eco := _eco_ref()
	verifier(eco.payer(0), "un montant nul ne doit pas être refusé")
	verifier_egal(eco.argent, 500)


func test_payer_negatif_est_refuse_sans_effet() -> void:
	var eco := _eco_ref()
	verifier_faux(eco.peut_payer(-1))
	verifier_faux(eco.payer(-1), "un montant négatif ne doit jamais rapporter d'or")
	verifier_egal(eco.argent, 500)


func test_peut_payer_suit_payer_pour_chaque_montant_de_moins_un_a_501() -> void:
	for montant: int in range(-1, 502):
		var eco := _eco_ref()
		var possible := eco.peut_payer(montant)
		var paye := eco.payer(montant)
		verifier_egal(paye, possible, "montant %d" % montant)
		verifier_egal(eco.argent, 500 - montant if possible else 500, "or après %d" % montant)


func test_gagner_ajoute_l_or_et_ignore_les_montants_nuls_ou_negatifs() -> void:
	var eco := _eco_ref()
	eco.gagner(100)
	verifier_egal(eco.argent, 600)
	eco.gagner(0)
	eco.gagner(-50)
	verifier_egal(eco.argent, 600, "un gain nul ou négatif ne doit rien changer")


# --- Versements toutes les 10 s -----------------------------------------------------------------


func test_versement_pile_a_10_secondes() -> void:
	var eco := _eco_ref()
	var verse: int = eco.avancer(PERIODE, 1, _stats(), 0.0)
	verifier_egal(verse, 20, "10,0 s écoulées doivent verser une période")
	verifier_egal(eco.argent, 520)


func test_pas_de_versement_a_9_95_secondes_puis_versement_a_10() -> void:
	var eco := _eco_ref()
	verifier_egal(eco.avancer(9.95, 1, _stats(), 0.0), 0, "9,95 s ne verse pas encore")
	verifier_egal(eco.argent, 500)
	verifier_egal(eco.avancer(0.05, 1, _stats(), 0.0), 20, "0,05 s de plus atteint 10 s")
	verifier_egal(eco.argent, 520)


func test_pas_de_fin_de_pas_de_50_ms_verse_a_200_pas_pile() -> void:
	var eco := _eco_ref()
	for pas: int in 199:
		verifier_egal(eco.avancer(0.05, 1, _stats(), 0.0), 0, "pas %d" % pas)
	verifier_egal(eco.avancer(0.05, 1, _stats(), 0.0), 20, "le 200e pas de 50 ms verse")


func test_un_dt_de_35_secondes_verse_trois_fois() -> void:
	var eco := _eco_ref()
	verifier_egal(eco.avancer(35.0, 1, _stats(), 0.0), 60, "périodes à 10, 20 et 30 s")
	verifier_egal(eco.argent, 560)
	verifier_proche(eco.temps_avant_versement(), 5.0, 0.0001, "5 s restent avant le suivant")


func test_dt_negatif_est_ignore() -> void:
	var eco := _eco_ref()
	verifier_egal(eco.avancer(-5.0, 1, _stats(), 0.0), 0)
	verifier_proche(eco.temps_avant_versement(), PERIODE, 0.0001, "le temps ne doit pas reculer")
	verifier_egal(eco.avancer(PERIODE, 1, _stats(), 0.0), 20, "un seul versement, à 10 s")


func test_dt_nan_ou_infini_est_ignore_sans_plantage() -> void:
	var eco := _eco_ref()
	verifier_egal(eco.avancer(NAN, 1, _stats(), 0.0), 0, "NaN ignoré")
	verifier_egal(eco.avancer(INF, 1, _stats(), 0.0), 0, "infini ignoré")
	verifier_egal(eco.argent, 500, "aucun or ne doit apparaître")
	verifier_proche(eco.temps_avant_versement(), PERIODE, 0.0001, "le compteur est intact")


# --- Revenu de base et revenu acheté ------------------------------------------------------------


func test_revenu_de_base_suit_les_paliers_de_manche_sur_toutes_les_manches() -> void:
	var eco := _eco_ref()
	for manche: int in range(1, 41):
		var attendu := 20 if manche < 6 else 30
		verifier_egal(eco.revenu_par_periode(manche, _stats(), 0.0), attendu, "manche %d" % manche)


func test_revenu_de_base_du_jeu_reel_aux_manches_1_5_6_40() -> void:
	var eco := _eco(_lire_reel("economie.json"))
	verifier_egal(eco.revenu_par_periode(1, _stats(), 0.0), 20)
	verifier_egal(eco.revenu_par_periode(5, _stats(), 0.0), 20)
	verifier_egal(eco.revenu_par_periode(6, _stats(), 0.0), 30)
	verifier_egal(eco.revenu_par_periode(40, _stats(), 0.0), 30)


func test_revenu_fixe_et_croissant_s_ajoutent_au_revenu_de_base() -> void:
	var eco := _eco_ref()
	var stats := _stats()
	stats.revenu_fixe = 4
	stats.revenu_croissant = 6.0
	# base 20 + (4 + 6 × 120/60) × 1 = 20 + 16
	verifier_egal(eco.revenu_par_periode(1, stats, 120.0), 36)


func test_revenu_mult_ne_multiplie_que_la_partie_achetee() -> void:
	var eco := _eco_ref()
	var stats := _stats()
	stats.revenu_fixe = 4
	stats.revenu_mult = 2.0
	# base 20 non multipliée + 4 × 2
	verifier_egal(eco.revenu_par_periode(1, stats, 0.0), 28)


func test_revenu_mult_sans_achat_laisse_le_revenu_de_base_intact() -> void:
	var eco := _eco_ref()
	var stats := _stats()
	stats.revenu_mult = 3.0
	verifier_egal(eco.revenu_par_periode(1, stats, 600.0), 20)


func test_revenu_immense_reste_positif_et_borne() -> void:
	var eco := _eco_ref()
	var stats := _stats()
	stats.revenu_croissant = 1.0e18
	stats.revenu_mult = 1.0e3
	var revenu := eco.revenu_par_periode(1, stats, 1.0e4)
	verifier(revenu >= 0, "un revenu énorme ne doit pas devenir négatif (reçu %d)" % revenu)
	var avant := eco.argent
	eco.avancer(PERIODE, 1, stats, 1.0e4)
	verifier(eco.argent >= avant, "un versement ne doit jamais retirer d'or")


# --- Primes -------------------------------------------------------------------------------------


func test_prime_suit_le_palier_de_prime_mult_sans_objet() -> void:
	var eco := _eco_ref()
	var stats := _stats()
	verifier_egal(eco.prime(120, 1, stats), 120, "manche 1 : × 1,0")
	verifier_egal(eco.prime(120, 9, stats), 120, "manche 9 : encore × 1,0")
	verifier_egal(eco.prime(120, 10, stats), 180, "manche 10 : × 1,5")
	verifier_egal(eco.prime(120, 40, stats), 180, "manche 40 : × 1,5")


func test_prime_multiplie_par_prime_mult_des_objets() -> void:
	var eco := _eco_ref()
	var stats := _stats()
	stats.prime_mult = 2.0
	verifier_egal(eco.prime(120, 10, stats), 360, "120 × 1,5 × 2")


func test_prime_arrondit_au_plus_proche() -> void:
	var eco := _eco_ref()
	var stats := _stats()
	stats.prime_mult = 1.25
	# 2 × 1,5 × 1,25 = 3,75 → 4
	verifier_egal(eco.prime(2, 10, stats), 4)


func test_prime_jamais_negative() -> void:
	var eco := _eco_ref()
	verifier_egal(eco.prime(0, 10, _stats()), 0)
	verifier_egal(eco.prime(-5, 10, _stats()), 0, "une prime négative ne retire pas d'or")


# --- Bonus tous les n éliminations --------------------------------------------------------------


func test_bonus_tous_les_zero_ne_verse_jamais() -> void:
	var eco := _eco_ref()
	var stats := _stats()
	stats.bonus_elim_tous_les = 0
	stats.bonus_elim_or = 50
	for k: int in range(1, 61):
		verifier_egal(eco.enregistrer_elimination(stats), 0, "élimination %d" % k)


func test_bonus_tous_les_trois_verse_a_la_troisieme_et_a_la_sixieme() -> void:
	var eco := _eco_ref()
	var stats := _stats()
	stats.bonus_elim_tous_les = 3
	stats.bonus_elim_or = 50
	for k: int in range(1, 31):
		var attendu := 50 if k % 3 == 0 else 0
		verifier_egal(eco.enregistrer_elimination(stats), attendu, "élimination %d" % k)


# --- Grandes sommes -----------------------------------------------------------------------------


func test_grande_somme_d_or_ne_deborde_pas_et_reste_positive() -> void:
	var economie := _economie_reference()
	economie["or_depart"] = 2000000000
	var eco := _eco(economie)
	var precedent := eco.argent
	for i: int in 1000:
		eco.gagner(OR_HAUT)
		verifier(eco.argent > 0, "or négatif après le gain %d" % i)
		verifier(eco.argent >= precedent, "l'or ne doit jamais baisser après un gain")
		precedent = eco.argent
	verifier_egal(eco.argent, 2000000000 + 1000 * OR_HAUT)
	verifier(eco.payer(eco.argent), "la somme exacte doit pouvoir être payée")
	verifier_egal(eco.argent, 0)
