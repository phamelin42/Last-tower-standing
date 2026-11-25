extends CasDeTest
## Ce que le joueur doit voir : des ennemis qui glissent d'une position reçue à la suivante,
## chacun sur sa propre trajectoire, sans téléportation ni fantôme.

const D: float = Interpolation.DELAI_S


func _vue(tick: int, ids: Array, positions: Array, familles: Array = []) -> VueArene:
	var vue := VueArene.new()
	vue.tick = tick
	for i: int in ids.size():
		vue.ennemis_id.append(int(ids[i]))
		vue.ennemis_pos.append(positions[i] as Vector2)
		vue.ennemis_famille.append(int(familles[i]) if i < familles.size() else 0)
	return vue


## Deux vues reçues à t = 1,0 et t = 2,0 ; `temps_rendu = t + D` donne `alpha = t - 1,0`.
func _deux_vues(a: VueArene, b: VueArene) -> Interpolation:
	var interp := Interpolation.new()
	interp.pousser(a, 1.0)
	interp.pousser(b, 2.0)
	return interp


func _pos_de(echantillon: Dictionary, id: int) -> Vector2:
	var ids: PackedInt32Array = echantillon["ids"]
	var pos: PackedVector2Array = echantillon["pos"]
	var i: int = ids.find(id)
	verifier(i >= 0, "id %d absent de l'échantillon" % id)
	return pos[i] if i >= 0 else Vector2(NAN, NAN)


func test_alpha_zero_demi_un_et_au_dela_sans_extrapolation() -> void:
	var interp := _deux_vues(_vue(1, [7], [Vector2(0, 0)]), _vue(2, [7], [Vector2(100, 40)]))
	verifier_egal(_pos_de(interp.echantillon(1.0 + D), 7), Vector2(0, 0))
	verifier_egal(_pos_de(interp.echantillon(1.5 + D), 7), Vector2(50, 20))
	verifier_egal(_pos_de(interp.echantillon(2.0 + D), 7), Vector2(100, 40))
	# Aucun nouvel état n'arrive : l'ennemi s'arrête à la dernière position connue,
	# il ne file pas hors de l'arène.
	for t: float in [2.5, 3.0, 10.0, 1000.0]:
		verifier_egal(_pos_de(interp.echantillon(t + D), 7), Vector2(100, 40), "t=%s" % t)


func test_temps_de_rendu_anterieur_a_la_vue_precedente() -> void:
	var interp := _deux_vues(_vue(1, [7], [Vector2(10, 10)]), _vue(2, [7], [Vector2(100, 40)]))
	for t: float in [0.0, -5.0, 0.5 + D]:
		verifier_egal(_pos_de(interp.echantillon(t), 7), Vector2(10, 10), "t=%s" % t)


func test_zero_etat_recu() -> void:
	var interp := Interpolation.new()
	var e: Dictionary = interp.echantillon(5.0)
	verifier_nul(e["vue"])
	verifier_egal((e["ids"] as PackedInt32Array).size(), 0)
	verifier_egal((e["pos"] as PackedVector2Array).size(), 0)


func test_une_seule_vue_renvoie_ses_positions() -> void:
	var interp := Interpolation.new()
	var vue := _vue(4, [1, 2], [Vector2(5, 6), Vector2(-7, 8)])
	interp.pousser(vue, 3.0)
	for t: float in [0.0, 3.0, 99.0]:
		var e: Dictionary = interp.echantillon(t)
		verifier_egal(_pos_de(e, 1), Vector2(5, 6))
		verifier_egal(_pos_de(e, 2), Vector2(-7, 8))
		verifier(e["vue"] == vue)


func test_zero_ennemi() -> void:
	var interp := _deux_vues(_vue(1, [], []), _vue(2, [], []))
	var e: Dictionary = interp.echantillon(1.5 + D)
	verifier_egal((e["ids"] as PackedInt32Array).size(), 0)
	verifier_egal((e["pos"] as PackedVector2Array).size(), 0)
	verifier_non_nul(e["vue"])


func test_ennemi_apparu_entre_les_deux_vues_est_a_sa_position_finale() -> void:
	var interp := _deux_vues(
		_vue(1, [1], [Vector2(0, 0)]),
		_vue(2, [1, 2], [Vector2(10, 0), Vector2(500, 500)]),
	)
	var e: Dictionary = interp.echantillon(1.5 + D)
	verifier_egal(_pos_de(e, 1), Vector2(5, 0))
	verifier_egal(_pos_de(e, 2), Vector2(500, 500), "pas de glissade depuis nulle part")


func test_ennemi_disparu_entre_les_deux_vues_n_est_plus_affiche() -> void:
	var interp := _deux_vues(
		_vue(1, [1, 2], [Vector2(0, 0), Vector2(50, 50)]), _vue(2, [1], [Vector2(10, 0)])
	)
	var e: Dictionary = interp.echantillon(1.5 + D)
	verifier_egal((e["ids"] as PackedInt32Array).size(), 1)
	verifier_egal((e["ids"] as PackedInt32Array).find(2), -1)


func test_ennemi_apparu_puis_disparu_entre_deux_etats_ne_laisse_aucune_trace() -> void:
	var interp := Interpolation.new()
	interp.pousser(_vue(1, [1], [Vector2(0, 0)]), 1.0)
	# L'ennemi 9 n'existe que dans une vue intermédiaire perdue ou dépassée.
	interp.pousser(_vue(2, [1, 9], [Vector2(10, 0), Vector2(3, 3)]), 2.0)
	interp.pousser(_vue(3, [1], [Vector2(20, 0)]), 3.0)
	for t: float in [1.0, 2.0, 2.5, 3.0, 4.0]:
		var e: Dictionary = interp.echantillon(t + D)
		verifier_egal((e["ids"] as PackedInt32Array).find(9), -1, "t=%s" % t)
		verifier_egal((e["ids"] as PackedInt32Array).size(), 1)


func test_saut_de_plus_de_200_unites_n_est_pas_interpole() -> void:
	var interp := _deux_vues(
		_vue(1, [1, 2], [Vector2(0, 0), Vector2(0, 0)]),
		_vue(2, [1, 2], [Vector2(199, 0), Vector2(201, 0)]),
	)
	var e: Dictionary = interp.echantillon(1.5 + D)
	verifier_egal(_pos_de(e, 1), Vector2(99.5, 0), "199 unités : interpolé")
	verifier_egal(_pos_de(e, 2), Vector2(201, 0), "201 unités : téléporté")


func test_chaque_ennemi_suit_son_id_quand_les_indices_changent() -> void:
	# Après une purge, les ids ne sont plus aux mêmes indices.
	var interp := _deux_vues(
		_vue(1, [10, 20, 30], [Vector2(0, 0), Vector2(0, 100), Vector2(0, 200)]),
		_vue(2, [30, 10], [Vector2(40, 200), Vector2(40, 0)]),
	)
	var e: Dictionary = interp.echantillon(1.5 + D)
	verifier_egal((e["ids"] as PackedInt32Array).size(), 2)
	verifier_egal(_pos_de(e, 10), Vector2(20, 0))
	verifier_egal(_pos_de(e, 30), Vector2(20, 200))


func test_id_reutilise_par_une_autre_famille_n_est_pas_melange() -> void:
	# Ne devrait pas arriver ; si c'est le cas, c'est un autre ennemi : pas de glissade.
	var interp := _deux_vues(
		_vue(1, [5], [Vector2(0, 0)], [2]), _vue(2, [5], [Vector2(100, 0)], [3])
	)
	verifier_egal(_pos_de(interp.echantillon(1.5 + D), 5), Vector2(100, 0))
	# Même famille : c'est bien le même ennemi.
	var meme := _deux_vues(_vue(1, [5], [Vector2(0, 0)], [2]), _vue(2, [5], [Vector2(100, 0)], [2]))
	verifier_egal(_pos_de(meme.echantillon(1.5 + D), 5), Vector2(50, 0))


func test_vue_plus_ancienne_ou_de_meme_tick_est_ignoree() -> void:
	var interp := Interpolation.new()
	var a := _vue(10, [1], [Vector2(0, 0)])
	var b := _vue(11, [1], [Vector2(10, 0)])
	interp.pousser(a, 1.0)
	interp.pousser(b, 2.0)
	interp.pousser(_vue(11, [1], [Vector2(999, 0)]), 2.1)  # doublon de tick
	interp.pousser(_vue(10, [1], [Vector2(-999, 0)]), 2.2)  # réseau : arrivée tardive
	interp.pousser(_vue(3, [1], [Vector2(-999, 0)]), 2.3)
	var e: Dictionary = interp.echantillon(1.5 + D)
	verifier(e["vue"] == b)
	verifier_egal(_pos_de(e, 1), Vector2(5, 0))
	verifier_egal(_pos_de(interp.echantillon(50.0), 1), Vector2(10, 0))


func test_saut_de_plusieurs_ticks_se_lisse_sur_le_temps_de_reception() -> void:
	var interp := _deux_vues(_vue(1, [1], [Vector2(0, 0)]), _vue(41, [1], [Vector2(100, 0)]))
	verifier_egal(_pos_de(interp.echantillon(1.25 + D), 1), Vector2(25, 0))
	verifier_egal(_pos_de(interp.echantillon(2.0 + D), 1), Vector2(100, 0))


func test_receptions_simultanees_ne_divisent_pas_par_zero() -> void:
	var interp := Interpolation.new()
	interp.pousser(_vue(1, [1], [Vector2(0, 0)]), 2.0)
	interp.pousser(_vue(2, [1], [Vector2(10, 0)]), 2.0)
	for t: float in [1.0, 2.0 + D, 3.0]:
		verifier_egal(_pos_de(interp.echantillon(t), 1), Vector2(10, 0))


func test_la_vue_renvoyee_est_la_plus_recente() -> void:
	var b := _vue(2, [1], [Vector2(10, 0)])
	var interp := _deux_vues(_vue(1, [1], [Vector2(0, 0)]), b)
	verifier(interp.echantillon(0.0)["vue"] == b)


func test_reinitialiser_oublie_tout_et_accepte_un_tick_plus_bas() -> void:
	var interp := _deux_vues(_vue(50, [1], [Vector2(0, 0)]), _vue(51, [1], [Vector2(10, 0)]))
	interp.reinitialiser()
	verifier_nul(interp.echantillon(5.0)["vue"])
	# Nouvelle partie : le compteur de ticks repart de zéro.
	var vue := _vue(1, [4], [Vector2(3, 3)])
	interp.pousser(vue, 6.0)
	verifier_egal(_pos_de(interp.echantillon(6.0), 4), Vector2(3, 3))


func test_300_ennemis_en_moins_de_2_ms() -> void:
	var ids: Array = []
	var pa: Array = []
	var pb: Array = []
	for i: int in 300:
		ids.append(i * 3 + 1)
		pa.append(Vector2(i, 2.0 * i))
		pb.append(Vector2(i + 10.0, 2.0 * i + 4.0))
	var interp := _deux_vues(_vue(1, ids, pa), _vue(2, ids, pb))
	var meilleur: int = 1 << 30
	for essai: int in 5:
		var debut: int = Time.get_ticks_usec()
		var e: Dictionary = interp.echantillon(1.5 + D)
		meilleur = mini(meilleur, Time.get_ticks_usec() - debut)
		verifier_egal((e["ids"] as PackedInt32Array).size(), 300)
	verifier(meilleur < 2000, "échantillon de 300 ennemis : %d µs" % meilleur)
	var e2: Dictionary = interp.echantillon(1.5 + D)
	for i: int in 300:
		verifier_egal(_pos_de(e2, i * 3 + 1), Vector2(i + 5.0, 2.0 * i + 2.0))
