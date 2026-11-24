extends CasDeTest
## Ennemis en tableaux compacts : ce que la joueuse voit approcher, mourir et subir.

const DT := 0.05
const CENTRE := Vector2.ZERO
const RAYON_TOUR := 60.0

var e: Ennemis


func avant_chaque() -> void:
	var brut: Dictionary = {}
	for nom: String in [
		"partie.json", "economie.json", "difficulte.json", "efficacite.json", "boutique.json"
	]:
		brut[nom] = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + nom))
	brut["armes.json"] = []
	brut["ameliorations.json"] = []
	brut["ennemis.json"] = {"familles": [], "convoi": {}, "boss": {}}
	e = Ennemis.new(Donnees.depuis_brut(brut))


func _p(recu: float, attendu: float, tolerance: float = 0.01, message: String = "") -> void:
	verifier_proche(recu, attendu, tolerance, message)


func _ajouter(
	pos: Vector2 = Vector2(500, 0),
	pv: float = 100.0,
	armure: int = Types.Armure.LEGERE,
	volant: bool = false,
	portee: float = 40.0,
	degats: float = 4.0,
	cadence: float = 1.0,
	prime: int = 2,
	vitesse: float = 60.0
) -> int:
	return e.ajouter(0, pos, pv, vitesse, degats, portee, cadence, prime, volant, armure)


## Avance de `n` pas et cumule les indices tués par statut, lus avant la purge.
func _pas(n: int, mult_vitesse: float = 1.0) -> Array[int]:
	var tues: Array[int] = []
	for _k: int in n:
		var r := e.avancer(DT, CENTRE, RAYON_TOUR, mult_vitesse, 1.0)
		var par_statut: PackedInt32Array = r["tues_par_statut"]
		for i: int in par_statut:
			tues.append(e.ids[i])
	return tues


func _i(id: int) -> int:
	return e.indice_de(id)


# --- Vide, ajout, purge ------------------------------------------------------------------------


func test_zero_ennemi_aucune_methode_ne_plante() -> void:
	verifier_egal(e.taille, 0)
	var r := e.avancer(DT, CENTRE, RAYON_TOUR, 1.0, 1.0)
	verifier_egal((r["attaquants_cac"] as PackedInt32Array).size(), 0)
	verifier_egal((r["tues_par_statut"] as PackedInt32Array).size(), 0)
	_p(r["degats_tour"], 0.0)
	verifier_egal(e.choisir(CENTRE, 1200.0, Types.Ciblage.PLUS_PROCHE), -1)
	verifier_egal(e.choisir(CENTRE, 1200.0, Types.Ciblage.PLUS_FORT), -1)
	verifier_egal(e.choisir(CENTRE, 1200.0, Types.Ciblage.PLUS_FAIBLE), -1)
	verifier_egal(e.dans_rayon(CENTRE, 1000.0, true).size(), 0)
	verifier_egal(e.purger().size(), 0)
	verifier_egal(e.indice_de(0), -1)
	var vue := VueArene.new()
	e.vers_vue(vue)
	verifier_egal(vue.ennemis_id.size(), 0)
	# Un indice qui n'existe pas ne plante pas et ne fait rien.
	_p(e.infliger(0, 50.0, Types.TypeDegats.CHAOS), 0.0)
	e.empoisonner(3, 10.0, 2.0)
	e.bruler(-1, 0.5, 10.0, 2.0)
	e.givrer(0, 1.0)
	e.etourdir(0, 1.0, 1.0)


func test_ajout_et_purge_de_0_1_et_1000() -> void:
	for combien: int in [0, 1, 1000]:
		avant_chaque()
		for k: int in combien:
			_ajouter(Vector2(500 + k, 0))
		verifier_egal(e.taille, combien)
		for k: int in combien:
			e.infliger(k, 1000.0, Types.TypeDegats.CHAOS)
		verifier_egal(e.taille, 0, "morts en attente non comptés (%d)" % combien)
		verifier_egal(e.purger().size(), combien)
		verifier_egal(e.ids.size(), 0, "aucune fuite de tableau (%d)" % combien)
		verifier_egal(e.pos.size(), 0)
		verifier_egal(e.pv.size(), 0)
		verifier_egal(e.statuts.size(), 0)


func test_ajout_invalide_est_refuse_sans_planter() -> void:
	verifier_egal(_ajouter(Vector2(10, 0), 0.0), -1)
	verifier_egal(_ajouter(Vector2(10, 0), -5.0), -1)
	verifier_egal(_ajouter(Vector2(10, 0), NAN), -1)
	verifier_egal(e.taille, 0)
	verifier_egal(_ajouter(), 0, "le refus ne consomme pas d'identifiant")


func test_identifiants_croissants_et_jamais_reutilises() -> void:
	var a := _ajouter()
	var b := _ajouter()
	verifier(b > a)
	e.infliger(_i(a), 999.0, Types.TypeDegats.CHAOS)
	e.purger()
	var c := _ajouter()
	verifier(c > b, "un id purgé n'est pas réutilisé")
	verifier_egal(e.indice_de(a), -1)


func test_purges_en_rafale_chaque_id_garde_ses_pv_et_ses_statuts() -> void:
	# 60 ennemis, chacun avec des PV propres ; un statut selon l'id ; on en tue un mélange
	# (dont le dernier et le premier), purge, vérifie, recommence avec de nouveaux arrivants.
	var pv_attendu: Dictionary = {}
	var statuts_attendus: Dictionary = {}
	var vivants: Array[int] = []
	for k: int in 60:
		var id := _ajouter(Vector2(400 + k * 3, k), 1000.0 + k)
		vivants.append(id)
		pv_attendu[id] = 1000.0 + k
		var bits := 0
		if k % 3 == 0:
			e.empoisonner(_i(id), 0.0001, 1000.0)
			bits |= Types.STATUT_EMPOISONNE
		if k % 4 == 0:
			e.etourdir(_i(id), 1000.0, 1.0)
			bits |= Types.STATUT_ETOURDI
		if k % 5 == 0:
			e.givrer(_i(id), 1.0)
			bits |= Types.STATUT_RALENTI
		statuts_attendus[id] = bits
	for ronde: int in 6:
		var restants: Array[int] = []
		for rang: int in vivants.size():
			var id: int = vivants[rang]
			var tue := rang == 0 or rang == vivants.size() - 1 or (rang * 7 + ronde) % 3 == 0
			if tue:
				e.infliger(_i(id), 1e9, Types.TypeDegats.CHAOS)
			else:
				restants.append(id)
		var morts: Array[int] = []
		for id: int in vivants:
			if not restants.has(id):
				morts.append(id)
		var purge := e.purger()
		verifier_egal(purge.size(), morts.size(), "ronde %d" % ronde)
		var ids_purges: Array[int] = []
		for ligne: Dictionary in purge:
			ids_purges.append(ligne["id"])
		var tries := ids_purges.duplicate()
		tries.sort()
		verifier_egal(ids_purges, tries, "purge rendue par id croissant")
		for id: int in morts:
			verifier_egal(e.indice_de(id), -1, "id %d purgé absent" % id)
		for id: int in restants:
			var i := _i(id)
			verifier(i >= 0, "id %d toujours présent" % id)
			if i < 0:
				continue
			_p(e.pv[i], pv_attendu[id], 0.01, "PV de l'id %d" % id)
			verifier_egal(int(e.statuts[i]), int(statuts_attendus[id]), "statuts de l'id %d" % id)
			verifier_egal(e.ids[i], id)
		verifier_egal(e.taille, restants.size())
		verifier_egal(e.ids.size(), restants.size())
		vivants = restants
		# Des arrivants entre deux rafales : ils se glissent à la place des partis.
		for k: int in 5:
			var id := _ajouter(Vector2(450, 10 * k), 2000.0 + ronde * 10 + k)
			vivants.append(id)
			pv_attendu[id] = 2000.0 + ronde * 10 + k
			statuts_attendus[id] = 0


# --- Dégâts et mort unique ---------------------------------------------------------------------


func test_coup_tranchant_sur_armure_moyenne_fait_exactement_le_double() -> void:
	var id := _ajouter(Vector2(500, 0), 100.0, Types.Armure.MOYENNE)
	var reels := e.infliger(_i(id), 10.0, Types.TypeDegats.TRANCHANT)
	_p(reels, 20.0, 0.0001)
	_p(e.pv[_i(id)], 80.0, 0.0001, "ni 4 fois (appliqué deux fois) ni 1 fois")


func test_efficacite_des_trente_couples_dans_infliger() -> void:
	var doubles := {
		Types.TypeDegats.TRANCHANT: Types.Armure.MOYENNE,
		Types.TypeDegats.PERCANT: Types.Armure.LEGERE,
		Types.TypeDegats.MAGIQUE: Types.Armure.LOURDE,
		Types.TypeDegats.SIEGE: Types.Armure.FORTIFIEE,
	}
	for t: int in range(5):
		for a: int in range(6):
			var id := _ajouter(Vector2(500, 0), 1000.0, a)
			var attendu := 2.0 if doubles.get(t, -1) == a else 1.0
			_p(e.infliger(_i(id), 10.0, t), 10.0 * attendu, 0.0001, "type %d armure %d" % [t, a])


func test_les_statuts_ne_subissent_pas_l_efficacite() -> void:
	# Un poison de 100 sur une armure « moyenne » retire 100, pas 200 : l'efficacité ne
	# s'applique qu'au coup direct.
	var id := _ajouter(Vector2(900, 0), 1000.0, Types.Armure.MOYENNE)
	e.empoisonner(_i(id), 100.0, 1.0)
	e.bruler(_i(id), 0.5, 40.0, 1.0)
	_pas(25)
	_p(e.pv[_i(id)], 1000.0 - 100.0 - 20.0, 0.05)


func test_montant_negatif_nul_ou_nan_ne_soigne_ni_ne_plante() -> void:
	var id := _ajouter(Vector2(500, 0), 100.0, Types.Armure.MOYENNE)
	e.infliger(_i(id), 30.0, Types.TypeDegats.CHAOS)
	for montant: float in [-50.0, -0.0001, 0.0, NAN, -INF]:
		_p(e.infliger(_i(id), montant, Types.TypeDegats.TRANCHANT), 0.0, 0.0001)
		_p(e.pv[_i(id)], 70.0, 0.0001, "PV inchangés après %s" % montant)
	verifier_egal(e.taille, 1)
	# Un coup énorme tue sans produire d'infini ni de NaN.
	e.infliger(_i(id), INF, Types.TypeDegats.CHAOS)
	verifier_egal(e.taille, 0)
	verifier_egal(e.purger().size(), 1)


func test_type_de_degats_inconnu_ne_plante_pas() -> void:
	var id := _ajouter()
	var reels := e.infliger(_i(id), 10.0, 99)
	_p(reels, 10.0, 0.0001)


func test_deux_coups_mortels_dans_le_meme_pas_comptent_une_mort() -> void:
	var id := _ajouter(Vector2(500, 0), 50.0, Types.Armure.LEGERE, false, 40.0, 4.0, 1.0, 7)
	var premier := e.infliger(_i(id), 100.0, Types.TypeDegats.CHAOS)
	var second := e.infliger(_i(id), 100.0, Types.TypeDegats.PERCANT)
	verifier(premier > 0.0)
	_p(second, 0.0, 0.0001, "un mort ne reçoit plus rien")
	verifier_egal(e.taille, 0)
	var purge := e.purger()
	verifier_egal(purge.size(), 1)
	verifier_egal(purge[0]["prime"], 7, "prime comptée une fois")
	verifier_egal(purge[0]["id"], id)
	verifier_egal(e.purger().size(), 0, "une seconde purge ne rend rien")


func test_coup_direct_puis_poison_dans_le_meme_pas_comptent_une_mort() -> void:
	var id := _ajouter(Vector2(900, 0), 10.0)
	e.empoisonner(_i(id), 500.0, 1.0)
	e.infliger(_i(id), 100.0, Types.TypeDegats.CHAOS)
	var tues := _pas(1)
	verifier_egal(tues.size(), 0, "déjà mort : le poison ne le retue pas")
	verifier_egal(e.taille, 0)
	verifier_egal(e.purger().size(), 1)


func test_poison_puis_coup_direct_dans_le_meme_pas_comptent_une_mort() -> void:
	var id := _ajouter(Vector2(900, 0), 10.0)
	e.empoisonner(_i(id), 500.0, 0.05)
	var tues := _pas(1)
	verifier_egal(tues, [id] as Array[int])
	_p(e.infliger(_i(id), 100.0, Types.TypeDegats.CHAOS), 0.0, 0.0001)
	verifier_egal(e.taille, 0)
	verifier_egal(e.purger().size(), 1)


func test_poison_et_brulure_mortels_ensemble_comptent_une_mort() -> void:
	var id := _ajouter(Vector2(900, 0), 5.0)
	e.empoisonner(_i(id), 100.0, 0.5)
	e.bruler(_i(id), 1.0, 100.0, 0.5)
	var tues := _pas(20)
	verifier_egal(tues, [id] as Array[int])
	verifier_egal(e.taille, 0)
	verifier_egal(e.purger().size(), 1)


# --- Zones et ciblage --------------------------------------------------------------------------


func test_dans_rayon_selon_le_drapeau_volant() -> void:
	var sol := _ajouter(Vector2(100, 0))
	var air := _ajouter(Vector2(0, 150), 100.0, Types.Armure.LEGERE, true)
	var loin := _ajouter(Vector2(0, 1000))
	var avec := e.dans_rayon(CENTRE, 300.0, true)
	var sans := e.dans_rayon(CENTRE, 300.0, false)
	verifier_egal(avec.size(), 2)
	verifier_egal(sans.size(), 1)
	verifier_egal(e.ids[sans[0]], sol)
	verifier_egal(e.ids[avec[0]], sol)
	verifier_egal(e.ids[avec[1]], air)
	verifier_egal(e.indice_de(loin) >= 0, true)


func test_dans_rayon_est_rendu_par_id_croissant_apres_des_purges() -> void:
	for k: int in 20:
		_ajouter(Vector2(50 + k, 0))
	for k: int in [0, 3, 7, 19, 11]:
		e.infliger(_i(k), 1e6, Types.TypeDegats.CHAOS)
	e.purger()
	var res := e.dans_rayon(CENTRE, 500.0, true)
	var ids: Array[int] = []
	for i: int in res:
		ids.append(e.ids[i])
	var tries := ids.duplicate()
	tries.sort()
	verifier_egal(ids, tries)
	verifier_egal(ids.size(), 15)


func test_dans_rayon_ignore_les_morts_en_attente_de_purge() -> void:
	var a := _ajouter(Vector2(100, 0))
	_ajouter(Vector2(120, 0))
	e.infliger(_i(a), 1e6, Types.TypeDegats.CHAOS)
	verifier_egal(e.dans_rayon(CENTRE, 500.0, true).size(), 1)
	verifier_egal(e.choisir(CENTRE, 500.0, Types.Ciblage.PLUS_PROCHE), _i(1))


func test_rayon_et_portee_invalides_ne_plantent_pas() -> void:
	_ajouter(Vector2(100, 0))
	verifier_egal(e.dans_rayon(CENTRE, -5.0, true).size(), 0)
	verifier_egal(e.dans_rayon(CENTRE, NAN, true).size(), 0)
	verifier_egal(e.choisir(CENTRE, -1.0, Types.Ciblage.PLUS_PROCHE), -1)
	verifier_egal(e.choisir(CENTRE, NAN, Types.Ciblage.PLUS_PROCHE), -1)
	verifier_egal(e.choisir(CENTRE, 500.0, 99), 0, "mode inconnu : le plus proche")


func test_choisir_aux_quatre_paliers_de_portee_et_a_la_limite() -> void:
	for portee: float in [300.0, 600.0, 900.0, 1200.0]:
		avant_chaque()
		_ajouter(Vector2(portee + 1.0, 0))
		verifier_egal(e.choisir(CENTRE, portee, Types.Ciblage.PLUS_PROCHE), -1, "%s+1" % portee)
		_ajouter(Vector2(0, portee))
		verifier_egal(e.choisir(CENTRE, portee, Types.Ciblage.PLUS_PROCHE), 1, "%s pile" % portee)
		_ajouter(Vector2(-(portee - 1.0), 0))
		verifier_egal(e.choisir(CENTRE, portee, Types.Ciblage.PLUS_PROCHE), 2, "%s-1" % portee)


func test_choisir_les_trois_modes() -> void:
	var a := _ajouter(Vector2(300, 0), 50.0)
	var b := _ajouter(Vector2(100, 0), 80.0)
	var c := _ajouter(Vector2(200, 0), 20.0, Types.Armure.LEGERE, true)
	verifier_egal(e.choisir(CENTRE, 1000.0, Types.Ciblage.PLUS_PROCHE), _i(b))
	verifier_egal(e.choisir(CENTRE, 1000.0, Types.Ciblage.PLUS_FORT), _i(b))
	verifier_egal(e.choisir(CENTRE, 1000.0, Types.Ciblage.PLUS_FAIBLE), _i(c), "volant inclus")
	verifier_egal(e.choisir(CENTRE, 150.0, Types.Ciblage.PLUS_FAIBLE), _i(b), "c hors portée")
	verifier(a >= 0)


func test_choisir_egalites_exactes_au_plus_petit_id() -> void:
	# Mêmes distances et mêmes PV : le plus petit id gagne, même après des échanges de
	# places dus aux purges.
	var ids: Array[int] = []
	for k: int in 6:
		ids.append(_ajouter(Vector2(100, 0) if k % 2 == 0 else Vector2(0, 100), 50.0))
	e.infliger(_i(ids[0]), 1e6, Types.TypeDegats.CHAOS)
	e.purger()
	for mode: int in [
		Types.Ciblage.PLUS_PROCHE, Types.Ciblage.PLUS_FORT, Types.Ciblage.PLUS_FAIBLE
	]:
		var i := e.choisir(CENTRE, 500.0, mode)
		verifier_egal(e.ids[i], ids[1], "mode %d" % mode)


# --- Déplacement et attaques -------------------------------------------------------------------


func test_corps_a_corps_s_arrete_au_contact_et_est_liste() -> void:
	var id := _ajouter(Vector2(200, 0), 100.0, Types.Armure.LEGERE, false, 40.0, 5.0, 1.0)
	var i := _i(id)
	var tour := 0.0
	var vu_attaquant := false
	for _k: int in 200:
		var r := e.avancer(DT, CENTRE, RAYON_TOUR, 1.0, 2.0)
		tour += r["degats_tour"]
		var att: PackedInt32Array = r["attaquants_cac"]
		if att.has(i):
			vu_attaquant = true
	_p(e.pos[i].length(), RAYON_TOUR + 40.0, 0.01, "arrêt à rayon_tour + portée")
	verifier(vu_attaquant, "listé parmi les attaquants au corps à corps")
	# 10 s à 1 attaque/s et ×2 de dégâts : environ 10 coups de 10.
	verifier(tour >= 80.0 and tour <= 110.0, "dégâts de la tour : %s" % tour)


func test_ennemi_a_distance_s_arrete_a_sa_portee_et_n_est_pas_cac() -> void:
	var id := _ajouter(Vector2(900, 0), 100.0, Types.Armure.LEGERE, false, 200.0, 5.0, 1.0)
	var i := _i(id)
	var tour := 0.0
	for _k: int in 400:
		var r := e.avancer(DT, CENTRE, RAYON_TOUR, 1.0, 1.0)
		tour += r["degats_tour"]
		verifier_faux((r["attaquants_cac"] as PackedInt32Array).has(i), "pas de contact")
	_p(e.pos[i].length(), 200.0, 0.01)
	verifier(tour > 0.0, "il frappe de loin")


func test_ne_depasse_jamais_le_point_d_arret_meme_avec_un_gros_pas() -> void:
	var id := _ajouter(Vector2(150, 0), 100.0, Types.Armure.LEGERE, false, 40.0)
	e.avancer(5.0, CENTRE, RAYON_TOUR, 1.0, 1.0)
	_p(e.pos[_i(id)].length(), RAYON_TOUR + 40.0, 0.01)


func test_gele_ou_etourdi_n_avance_ni_n_attaque() -> void:
	var a := _ajouter(Vector2(RAYON_TOUR + 40.0, 0), 100.0, Types.Armure.LEGERE, false, 40.0)
	var b := _ajouter(Vector2(RAYON_TOUR + 40.0, 5), 100.0, Types.Armure.LEGERE, false, 40.0)
	for _k: int in 8:
		e.givrer(_i(a), 1.0)
	e.etourdir(_i(b), 1.0, 1.0)
	var r := e.avancer(DT, CENTRE, RAYON_TOUR, 1.0, 1.0)
	_p(r["degats_tour"], 0.0, 0.0001)
	verifier_egal((r["attaquants_cac"] as PackedInt32Array).size(), 0)


func test_vitesse_nulle_ou_negative_ou_pas_invalide_ne_deplace_pas() -> void:
	var id := _ajouter(Vector2(500, 0))
	var i := _i(id)
	e.avancer(DT, CENTRE, RAYON_TOUR, 0.0, 1.0)
	e.avancer(DT, CENTRE, RAYON_TOUR, -3.0, 1.0)
	e.avancer(0.0, CENTRE, RAYON_TOUR, 1.0, 1.0)
	e.avancer(-1.0, CENTRE, RAYON_TOUR, 1.0, 1.0)
	e.avancer(NAN, CENTRE, RAYON_TOUR, 1.0, 1.0)
	verifier_egal(e.pos[i], Vector2(500, 0))


func test_ennemi_deja_au_centre_ne_produit_pas_de_nan() -> void:
	var id := _ajouter(Vector2.ZERO)
	for _k: int in 5:
		e.avancer(DT, CENTRE, RAYON_TOUR, 1.0, 1.0)
	verifier(is_finite(e.pos[_i(id)].x) and is_finite(e.pos[_i(id)].y))


func test_convoi_sans_degats_ne_frappe_pas() -> void:
	var id := _ajouter(Vector2(200, 0), 400.0, Types.Armure.AUCUNE, false, 40.0, 0.0, 1.0, 120)
	var tour := 0.0
	for _k: int in 200:
		var r := e.avancer(DT, CENTRE, RAYON_TOUR, 1.0, 1.0)
		tour += r["degats_tour"]
	_p(tour, 0.0, 0.0001)
	verifier(id >= 0)


# --- Vue ---------------------------------------------------------------------------------------


func test_vers_vue_copie_300_ennemis_sans_partage_de_memoire() -> void:
	for k: int in 300:
		e.ajouter(k % 8, Vector2(500 + k, k), 100.0, 60.0, 4.0, 40.0, 1.0, 2, false, 0)
	e.infliger(10, 25.0, Types.TypeDegats.CHAOS)
	e.etourdir(11, 5.0, 1.0)
	var vue := VueArene.new()
	e.vers_vue(vue)
	verifier_egal(vue.ennemis_id.size(), 300)
	verifier_egal(vue.ennemis_pos.size(), 300)
	verifier_egal(vue.ennemis_famille.size(), 300)
	verifier_egal(vue.ennemis_pv.size(), 300)
	verifier_egal(vue.ennemis_statuts.size(), 300)
	verifier_egal(int(vue.ennemis_pv[0]), 255)
	verifier_egal(int(vue.ennemis_pv[10]), int(roundf(0.75 * 255.0)))
	verifier_egal(int(vue.ennemis_statuts[11]), Types.STATUT_ETOURDI)
	verifier_egal(int(vue.ennemis_famille[9]), 1)
	# Copie profonde, dans les deux sens.
	var pos_vue := vue.ennemis_pos[0]
	e.pos[0] = Vector2(1, 1)
	e.pv[0] = 1.0
	verifier_egal(vue.ennemis_pos[0], pos_vue)
	verifier_egal(int(vue.ennemis_pv[0]), 255)
	vue.ennemis_id[5] = 12345
	vue.ennemis_pos[6] = Vector2(9, 9)
	verifier_egal(e.ids[5], 5)
	verifier(e.pos[6] != Vector2(9, 9))


func test_vers_vue_un_vivant_presque_mort_reste_visible_et_les_morts_sont_omis() -> void:
	var a := _ajouter(Vector2(500, 0), 10000.0)
	var b := _ajouter(Vector2(500, 10), 100.0)
	e.infliger(_i(a), 9999.5, Types.TypeDegats.CHAOS)
	e.infliger(_i(b), 1e6, Types.TypeDegats.CHAOS)
	var vue := VueArene.new()
	e.vers_vue(vue)
	verifier_egal(vue.ennemis_id.size(), 1, "le mort en attente n'est pas affiché")
	verifier_egal(int(vue.ennemis_pv[0]), 1, "vivant : jamais 0")
	# Appeler deux fois remplace le contenu au lieu de l'allonger.
	e.vers_vue(vue)
	verifier_egal(vue.ennemis_id.size(), 1)


# --- Performance -------------------------------------------------------------------------------


func test_performance_1000_ennemis_100_pas_sous_500_ms() -> void:
	for k: int in 1000:
		var angle := k * 0.6283
		var pos := Vector2(1300.0, 0.0).rotated(angle)
		var portee := 40.0 if k % 3 != 0 else 300.0
		var id := e.ajouter(k % 8, pos, 500.0, 60.0, 4.0, portee, 1.0, 2, k % 5 == 0, k % 6)
		if k % 7 == 0:
			e.empoisonner(e.indice_de(id), 50.0, 20.0)
		if k % 11 == 0:
			e.bruler(e.indice_de(id), 0.3, 20.0, 20.0)
		if k % 13 == 0:
			e.givrer(e.indice_de(id), 1.0)
	var debut := Time.get_ticks_usec()
	for _k: int in 100:
		e.avancer(DT, CENTRE, RAYON_TOUR, 1.0, 1.0)
	var ms := (Time.get_ticks_usec() - debut) / 1000.0
	print("PERF ennemis : 1000 ennemis x 100 pas = %.1f ms (%.2f ms/pas)" % [ms, ms / 100.0])
	verifier(ms < 500.0, "100 pas en %.1f ms (limite 500)" % ms)
	verifier_egal(e.taille, 1000)
