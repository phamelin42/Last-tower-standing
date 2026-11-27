extends CasDeTest
## Zones posées et bombes à retardement (M8, M9) : ce qu'elles infligent, quand elles disparaissent.

const DT := 0.05
const CENTRE := Vector2.ZERO

var d: Donnees
var e: Ennemis
var poses: Poses
var stats: StatsTour


func avant_chaque() -> void:
	d = AidesPartie.donnees()
	e = Ennemis.new(d)
	poses = Poses.new(d)
	stats = StatsTour.new()


func _ennemi(pos: Vector2, pv: float = 1.0e6) -> int:
	return e.indice_de(e.ajouter(0, pos, pv, 0.0, 0.0, 40.0, 1.0, 1, Types.Armure.AUCUNE))


func _pose(pos: Vector2, proprietaire: int = 1, statuts: Array = []) -> Dictionary:
	return {
		"pos": pos,
		"rayon": 100.0,
		"degats": 10.0,
		"type_degats": Types.TypeDegats.CHAOS,
		"statuts": statuts,
		"statut": 0,
		"arme": 3,
		"proprietaire": proprietaire,
	}


func _zone(
	pos: Vector2, duree: float = 5.0, periode: float = 1.0, proprietaire: int = 1
) -> Dictionary:
	var pose := _pose(pos, proprietaire)
	pose["duree"] = duree
	pose["periode"] = periode
	return pose


func _bombe(pos: Vector2, delai: float = 2.0, proprietaire: int = 1) -> Dictionary:
	var pose := _pose(pos, proprietaire)
	pose["delai"] = delai
	return pose


func _avancer(secondes: float) -> Tir.Bilan:
	var total := Tir.Bilan.new()
	for _k: int in roundi(secondes / DT):
		var bilan := poses.avancer(DT, e, stats, CENTRE, d, 1.0)
		total.degats += bilan.degats
		total.mana += bilan.mana
		total.evenements.append_array(bilan.evenements)
	return total


# --- Zones ---------------------------------------------------------------------------------------


func test_une_zone_inflige_ses_degats_a_chaque_periode_pendant_sa_duree_et_pas_apres() -> void:
	var i := _ennemi(Vector2(300, 0))
	poses.ajouter_zone(_zone(Vector2(300, 0), 5.0, 1.0), 3)
	var bilan := _avancer(10.0)
	verifier_proche(1.0e6 - e.pv[i], 50.0, 0.01, "cinq impulsions de 10")
	verifier_egal(bilan.evenements.size(), 5, "un impact par impulsion")
	verifier(poses.zones.is_empty(), "la zone a disparu")


func test_le_nombre_d_impulsions_suit_duree_sur_periode_en_boucle() -> void:
	for cas: Array in [[3.0, 1.0, 3], [2.0, 0.5, 4], [1.0, 1.0, 1], [2.5, 1.0, 2], [0.4, 1.0, 0]]:
		avant_chaque()
		var i := _ennemi(Vector2(300, 0))
		poses.ajouter_zone(_zone(Vector2(300, 0), cas[0], cas[1]), 3)
		_avancer(8.0)
		verifier_proche(
			(1.0e6 - e.pv[i]) / 10.0, float(cas[2]), 0.001, "durée %s période %s" % [cas[0], cas[1]]
		)
		verifier(poses.zones.is_empty())


func test_une_zone_touche_tous_les_ennemis_du_rayon_et_aucun_en_dehors() -> void:
	var dedans: Array[int] = [
		_ennemi(Vector2(300, 0)), _ennemi(Vector2(380, 30)), _ennemi(Vector2(250, -60))
	]
	var dehors := _ennemi(Vector2(300, 150))
	poses.ajouter_zone(_zone(Vector2(300, 0), 1.0, 1.0), 3)
	_avancer(1.5)
	for i: int in dedans:
		verifier_proche(1.0e6 - e.pv[i], 10.0, 0.01)
	verifier_egal(e.pv[dehors], 1.0e6)


func test_une_zone_pose_les_statuts_de_l_arme() -> void:
	var i := _ennemi(Vector2(300, 0))
	var pose := _zone(Vector2(300, 0), 1.0, 1.0)
	pose["statuts"] = [
		{"kind": "vulnerabilite", "ratio": 0.2, "duree": 4.0},
		{"kind": "mana_au_coup", "valeur": 2.0}
	]
	poses.ajouter_zone(pose, 3)
	var bilan := _avancer(1.5)
	verifier_proche(e.vulnerabilite[i * 5 + Types.TypeDegats.CHAOS], 0.2, 0.0001)
	verifier_proche(bilan.mana, 2.0, 0.0001, "la mana au coup passe par la zone")


func test_la_zone_la_plus_ancienne_cede_au_dela_de_max_actives_et_de_la_limite_globale() -> void:
	for k: int in 3:
		poses.ajouter_zone(_zone(Vector2(100.0 * k, 0), 5.0, 1.0, 1), 2)
	verifier_egal(poses.zones.size(), 2)
	verifier_egal((poses.zones[0]["pos"] as Vector2).x, 100.0, "la première a cédé")
	verifier_egal((poses.zones[1]["pos"] as Vector2).x, 200.0)
	# Une autre arme a ses propres zones.
	poses.ajouter_zone(_zone(Vector2(500, 0), 5.0, 1.0, 2), 2)
	verifier_egal(poses.zones.size(), 3)
	# La limite globale : la plus ancienne cède, quelle que soit son arme.
	var limite := int((d.partie["limites"] as Dictionary)["zones"])
	for k: int in limite + 10:
		poses.ajouter_zone(_zone(Vector2(1000.0 + k, 0), 5.0, 1.0, 100 + k), 1)
	verifier_egal(poses.zones.size(), limite)
	verifier_egal(
		(poses.zones[limite - 1]["pos"] as Vector2).x,
		1000.0 + limite + 9.0,
		"la dernière posée reste"
	)


func test_des_poses_aberrantes_ne_posent_rien() -> void:
	var mauvaises: Array[Dictionary] = []
	for cle: String in ["rayon", "duree", "periode", "degats"]:
		for valeur: float in [0.0, -1.0, NAN, INF]:
			var pose := _zone(Vector2(300, 0))
			pose[cle] = valeur
			mauvaises.append(pose)
	var loin := _zone(Vector2(INF, 0))
	mauvaises.append(loin)
	for pose: Dictionary in mauvaises:
		poses.ajouter_zone(pose, 3)
		poses.ajouter_bombe(pose, 3)
	verifier(poses.zones.is_empty() and poses.bombes.is_empty())


# --- Bombes --------------------------------------------------------------------------------------


func test_une_bombe_explose_apres_son_delai_a_l_endroit_ou_elle_a_ete_posee() -> void:
	var qui_reste := _ennemi(Vector2(300, 0))
	var qui_part := _ennemi(Vector2(310, 0))
	poses.ajouter_bombe(_bombe(Vector2(300, 0), 2.0), 3)
	e.pos[qui_part] = Vector2(900, 0)
	var avant := _avancer(1.9)
	verifier_egal(avant.degats, 0.0, "rien avant le délai")
	verifier_egal(poses.bombes.size(), 1)
	var apres := _avancer(0.3)
	verifier_proche(1.0e6 - e.pv[qui_reste], 10.0, 0.01, "touché à l'endroit de la pose")
	verifier_egal(e.pv[qui_part], 1.0e6, "la bombe ne suit pas sa cible")
	verifier_egal(apres.evenements.size(), 1)
	verifier(poses.bombes.is_empty(), "elle disparaît après l'explosion")


func test_une_bombe_sans_ennemi_dans_le_rayon_disparait_sans_erreur() -> void:
	poses.ajouter_bombe(_bombe(Vector2(300, 0), 1.0), 3)
	var bilan := _avancer(1.5)
	verifier_egal(bilan.degats, 0.0)
	verifier(poses.bombes.is_empty())


func test_la_bombe_la_plus_ancienne_cede_au_dela_de_max_actives_et_de_la_limite_globale() -> void:
	for k: int in 3:
		poses.ajouter_bombe(_bombe(Vector2(100.0 * k, 0), 5.0, 1), 2)
	verifier_egal(poses.bombes.size(), 2)
	verifier_egal((poses.bombes[0]["pos"] as Vector2).x, 100.0)
	var limite := int((d.partie["limites"] as Dictionary)["bombes"])
	for k: int in limite + 10:
		poses.ajouter_bombe(_bombe(Vector2(1000.0 + k, 0), 5.0, 100 + k), 1)
	verifier_egal(poses.bombes.size(), limite)


func test_une_zone_dont_tous_les_ennemis_sont_morts_ou_purges_ne_plante_pas() -> void:
	var i := _ennemi(Vector2(300, 0), 5.0)
	poses.ajouter_zone(_zone(Vector2(300, 0), 3.0, 0.5), 3)
	poses.ajouter_bombe(_bombe(Vector2(300, 0), 1.0), 3)
	e.infliger(i, 100.0, Types.TypeDegats.CHAOS)
	_avancer(1.0)
	e.purger()
	_avancer(3.0)
	verifier(poses.zones.is_empty() and poses.bombes.is_empty())
	verifier_egal(e.taille, 0)


# --- Degats figés ------------------------------------------------------------------------------


func _def(effet: Dictionary, id: String = "essai_poses") -> Dictionary:
	var premiere: String = d.armes.keys()[0]
	var def: Dictionary = (d.armes[premiere] as Dictionary).duplicate(true)
	def["id"] = id
	def["effets"] = [effet]
	def["statuts"] = []
	def["type_degats"] = Types.TypeDegats.CHAOS
	def["degats"] = 10.0
	def["recharge"] = 1.0
	def["portee"] = 600
	def["degats_par_mana_max"] = 0.0
	return def


func _tirer(arme: ArmeEquipee, lecture: Tir.Lecture, st: StatsTour = null) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	Tir.avancer_arme(
		arme, 1.0, st if st != null else stats, e, CENTRE, d, rng, 1.0, Tir.Bilan.new(), lecture
	)


func test_le_tir_pose_une_zone_sur_la_cible_et_ne_frappe_pas() -> void:
	var i := _ennemi(Vector2(300, 0))
	var effet := {
		"kind": "zone_posee",
		"rayon": 90.0,
		"duree": 4.0,
		"periode": 1.0,
		"ratio": 0.5,
		"max_actives": 2
	}
	var arme := ArmeEquipee.new(_def(effet))
	var lecture := Tir.Lecture.new()
	lecture.poses = poses
	_tirer(arme, lecture)
	verifier_egal(e.pv[i], 1.0e6, "poser n'inflige rien")
	verifier_egal(poses.zones.size(), 1)
	verifier_egal(poses.zones[0]["pos"], Vector2(300, 0))
	verifier_proche(float(poses.zones[0]["degats"]), 5.0, 0.0001, "ratio 0,5 × 10")
	# Sans arène (pas de poses dans la lecture), l'arme ne pose rien et reste prête.
	var seule := ArmeEquipee.new(_def(effet))
	_tirer(seule, null)
	verifier_egal(seule.recharge_restante, 0.0)


func test_les_degats_sont_figes_a_la_pose() -> void:
	var i := _ennemi(Vector2(300, 0))
	var effet := {"kind": "bombe", "delai": 1.0, "rayon": 90.0, "ratio": 2.0, "max_actives": 2}
	var lecture := Tir.Lecture.new()
	lecture.poses = poses
	_tirer(ArmeEquipee.new(_def(effet)), lecture)
	# Une amélioration achetée après la pose n'y change rien.
	stats.degats_global = 5.0
	stats.degats_type[Types.TypeDegats.CHAOS] = 5.0
	_avancer(1.5)
	verifier_proche(1.0e6 - e.pv[i], 20.0, 0.01, "10 × ratio 2, figé à la pose")


func test_deux_exemplaires_de_la_meme_arme_ont_chacun_leur_max_actives() -> void:
	_ennemi(Vector2(300, 0))
	var effet := {
		"kind": "zone_posee",
		"rayon": 90.0,
		"duree": 9.0,
		"periode": 1.0,
		"ratio": 1.0,
		"max_actives": 1
	}
	var a := ArmeEquipee.new(_def(effet))
	var b := ArmeEquipee.new(_def(effet))
	var lecture := Tir.Lecture.new()
	lecture.poses = poses
	_tirer(a, lecture)
	_tirer(b, lecture)
	verifier_egal(poses.zones.size(), 2, "une zone par exemplaire")
	a.recharge_restante = 0.0
	_tirer(a, lecture)
	verifier_egal(poses.zones.size(), 2, "la nouvelle remplace l'ancienne du même exemplaire")


# --- Disparitions (Review Focus 2) ---------------------------------------------------------------


func _arene() -> Arene:
	var a := Arene.new(d, 31)
	a.demarrer_manche(
		1,
		Composition.unique(0),
		{"pv": 1.0, "degats": 1.0, "vitesse": 0.0, "resistance_controle": 1.0}
	)
	return a


func _remplir(a: Arene) -> void:
	a.poses.ajouter_zone(_zone(Vector2(300, 0), 50.0, 1.0), 3)
	a.poses.ajouter_bombe(_bombe(Vector2(300, 0), 50.0), 3)


func test_tout_disparait_a_la_fin_de_la_manche_a_la_mort_de_la_tour_et_sur_vider() -> void:
	var a := _arene()
	_remplir(a)
	a.demarrer_manche(2, Composition.unique(0), {})
	verifier(a.poses.zones.is_empty() and a.poses.bombes.is_empty(), "fin de manche")
	_remplir(a)
	a.demarrer_boss({})
	verifier(a.poses.zones.is_empty() and a.poses.bombes.is_empty(), "début du boss")
	_remplir(a)
	a.pv = 0.0
	a.avancer(DT)
	verifier(a.est_detruite())
	verifier(a.poses.zones.is_empty() and a.poses.bombes.is_empty(), "tour détruite")
	poses.ajouter_zone(_zone(Vector2(1, 1)), 3)
	poses.ajouter_bombe(_bombe(Vector2(1, 1)), 3)
	poses.vider()
	verifier(poses.zones.is_empty() and poses.bombes.is_empty(), "vider()")


func test_aucune_fuite_sur_cent_manches() -> void:
	var a := _arene()
	for manche: int in range(2, 102):
		_remplir(a)
		a.poses.ajouter_zone(_zone(Vector2(manche, 0), 9.0, 1.0, manche), 3)
		a.demarrer_manche(manche, Composition.unique(0), {})
		verifier_egal(a.poses.zones.size() + a.poses.bombes.size(), 0, "manche %d" % manche)


func test_la_vue_porte_les_zones_et_les_bombes_avec_leur_temps_restant() -> void:
	var a := _arene()
	a.poses.ajouter_zone(_zone(Vector2(300, 0), 5.0, 1.0), 3)
	a.poses.ajouter_bombe(_bombe(Vector2(200, 100), 2.0), 3)
	for _k: int in 20:
		a.avancer(DT)
	var vue := a.vue(Types.Phase.MANCHE, 10.0, -1, false)
	verifier_egal(vue.zones.size(), 1)
	verifier_egal(vue.bombes.size(), 1)
	verifier_proche(float((vue.zones[0] as Dictionary)["reste"]), 4.0, 0.01)
	verifier_proche(float((vue.bombes[0] as Dictionary)["reste"]), 1.0, 0.01)
	verifier_egal((vue.zones[0] as Dictionary)["arme"], 3)
	verifier_non_nul(VueArene.from_dict(vue.to_dict()), "la vue reste sérialisable")


func test_l_explosion_et_les_impulsions_emettent_un_impact_du_bon_genre() -> void:
	_ennemi(Vector2(300, 0))
	poses.ajouter_zone(_zone(Vector2(300, 0), 1.0, 1.0), 3)
	poses.ajouter_bombe(_bombe(Vector2(300, 0), 1.0), 3)
	var bilan := _avancer(1.5)
	var genres: Array[int] = []
	for ev: Dictionary in bilan.evenements:
		verifier_egal(ev["k"], "impact")
		verifier_egal(int(ev["arme"]), 3)
		genres.append(int(ev["genre"]))
	genres.sort()
	var attendu: Array[int] = [
		VueArene.genre_depuis_nom("zone_posee"), VueArene.genre_depuis_nom("bombe")
	]
	attendu.sort()
	verifier_egal(genres, attendu)


# --- Reproductibilité et performance -------------------------------------------------------------


func _donnees_avec_poses() -> Donnees:
	var brut := AidesPartie.brut()
	var armes: Array = brut["armes.json"]
	for nouvelle: Array in [
		[
			"zone_d_essai",
			{
				"kind": "zone_posee",
				"rayon": 90.0,
				"duree": 4.0,
				"periode": 0.5,
				"ratio": 0.5,
				"max_actives": 3
			}
		],
		[
			"bombe_d_essai",
			{"kind": "bombe", "delai": 1.5, "rayon": 90.0, "ratio": 3.0, "max_actives": 3}
		],
	]:
		var arme: Dictionary = (armes[0] as Dictionary).duplicate(true)
		arme["id"] = nouvelle[0]
		arme["nom"] = "Essai %s" % nouvelle[0]
		arme["effets"] = [nouvelle[1]]
		arme["statuts"] = []
		armes.append(arme)
	return Donnees.depuis_brut(brut)


func _empreinte_de_partie(graine: int) -> int:
	var donnees := _donnees_avec_poses()
	var a := Arene.new(donnees, graine)
	a.demarrer_manche(
		3,
		Composition.unique(0),
		{"pv": 1.0, "degats": 1.0, "vitesse": 1.0, "resistance_controle": 1.0}
	)
	a.inventaire.ajouter("zone_d_essai")
	a.inventaire.ajouter("bombe_d_essai")
	a.synchroniser()
	var cumul := 0
	var vu_des_poses := false
	for _pas: int in 600:
		a.avancer(DT)
		var v := a.vue(Types.Phase.MANCHE, 10.0, -1, false)
		vu_des_poses = vu_des_poses or not v.zones.is_empty() or not v.bombes.is_empty()
		cumul = hash(
			[
				cumul,
				str(v.ennemis_pos),
				str(v.ennemis_pv),
				str(v.zones),
				str(v.bombes),
				str(v.evenements),
				v.tour_pv
			]
		)
	verifier(vu_des_poses, "des zones ou des bombes ont existé")
	return cumul


func test_deux_parties_de_meme_graine_donnent_la_meme_empreinte_de_vue_sur_600_pas() -> void:
	var premiere := _empreinte_de_partie(2026)
	verifier_egal(premiere, _empreinte_de_partie(2026))
	verifier_different(premiere, _empreinte_de_partie(2027))


## Période de 0,5 s : les 32 zones impulsent ensemble toutes les dix pas. Une période égale au pas
## (impulsion à chaque pas pour les 32 zones) coûte environ 12 ms par pas : aucune donnée ne
## la choisit.
func test_trente_deux_zones_et_trente_deux_bombes_contre_mille_ennemis_sous_5_ms_par_pas() -> void:
	for k: int in 1000:
		_ennemi(Vector2(200.0 + float(k % 40) * 20.0, float(k / 40) * 20.0 - 250.0))
	for k: int in 32:
		var pos := Vector2(300.0 + float(k) * 10.0, float(k) * 5.0 - 80.0)
		poses.ajouter_zone(_zone(pos, 60.0, 0.5, k), 1)
		poses.ajouter_bombe(_bombe(pos, 60.0, 100 + k), 1)
	verifier_egal(poses.zones.size(), 32)
	verifier_egal(poses.bombes.size(), 32)
	# 10e centile de 40 pas (S16, `MesurePas`). Coût local : 0,20 ms par pas ; budget de 5 ms.
	var durees := PackedInt32Array()
	for _k: int in 40:
		var debut := Time.get_ticks_usec()
		poses.avancer(DT, e, stats, CENTRE, d, 1.0)
		durees.append(Time.get_ticks_usec() - debut)
	var rapide := MesurePas.centile_bas_ms(durees)
	print("PERF poses : %.3f ms par pas (10e centile)" % rapide)
	verifier(rapide < 5.0, "moins de 5 ms par pas (%f)" % rapide)
