extends CasDeTest
## Ce que le joueur doit voir : des ennemis qui glissent d'une position reçue à la suivante,
## sans saut à l'arrivée d'une vue, chacun sur sa propre trajectoire, sans téléportation ni
## fantôme. L'affichage est en retard d'un intervalle entre vues (mesuré), pour que la position
## affichée soit continue d'une vue à l'autre.

## Intervalle entre deux vues des tests unitaires simples (une vue tous les 0,1 s).
const P: float = 0.1
const IPS: float = 60.0
## Vitesse de l'ennemi des tests de fluidité (unités par seconde) : 100 u/s fait 20 unités par
## vue à 5 Hz, sous `SAUT_MAX`.
const VITESSE: float = 100.0
const IMAGE: float = 1.0 / 60.0
## L'ennemi du rejeu avance à 100 u/s : 1,67 u par image de rendu.
const PAS_IDEAL: float = VITESSE * IMAGE


func _vue(tick: int, ids: Array, positions: Array, familles: Array = []) -> VueArene:
	var vue := VueArene.new()
	vue.tick = tick
	for i: int in ids.size():
		vue.ennemis_id.append(int(ids[i]))
		vue.ennemis_pos.append(positions[i] as Vector2)
		vue.ennemis_famille.append(int(familles[i]) if i < familles.size() else 0)
	return vue


## Deux vues reçues à t = 1,0 et t = 1,0 + P : le retard mesuré vaut P.
func _deux_vues(a: VueArene, b: VueArene) -> Interpolation:
	var interp := Interpolation.new()
	interp.pousser(a, 1.0)
	interp.pousser(b, 1.0 + P)
	return interp


## Temps de rendu où `_deux_vues` affiche la fraction `alpha` du trajet de a vers b : l'affichage
## a P de retard, donc la vue a (reçue à 1,0) est affichée à 1,0 + P, la vue b à 1,0 + 2 P.
func _t(alpha: float) -> float:
	return 1.0 + P + alpha * P


func _pos_de(echantillon: Dictionary, id: int) -> Vector2:
	var ids: PackedInt32Array = echantillon["ids"]
	var pos: PackedVector2Array = echantillon["pos"]
	var i: int = ids.find(id)
	verifier(i >= 0, "id %d absent de l'échantillon" % id)
	return pos[i] if i >= 0 else Vector2(NAN, NAN)


func _proche(recu: Vector2, attendu: Vector2, message: String = "") -> void:
	verifier_proche(
		recu.distance_to(attendu), 0.0, 0.001, "%s : %s ≠ %s" % [message, recu, attendu]
	)


## Un ennemi à vitesse constante sur x, vu `hz` fois par seconde, rendu à 60 images par seconde
## pendant `secondes`. Renvoie, image par image, `{t, x, recues}` : la position affichée et la
## dernière abscisse reçue. Une vue arrive à l'image où son instant tombe (hz divise 60).
func _rendu(hz: int, secondes: float, retards: Dictionary = {}) -> Array[Dictionary]:
	var interp := Interpolation.new()
	var sortie: Array[Dictionary] = []
	var tick: int = 0
	var recue: float = 0.0
	var en_attente: Dictionary = {}
	var pas_vue: int = roundi(IPS / hz)
	for image: int in roundi(secondes * IPS):
		var t: float = image / IPS
		if image % pas_vue == 0:
			tick += 1
			var x: float = VITESSE * image / IPS
			var arrivee: int = image + int(retards.get(tick, 0))
			en_attente[arrivee] = [tick, x]
		if en_attente.has(image):
			var v: Array = en_attente[image]
			interp.pousser(_vue(int(v[0]), [1], [Vector2(float(v[1]), 0)]), t)
			recue = maxf(recue, float(v[1]))
		var e: Dictionary = interp.echantillon(t)
		var ids: PackedInt32Array = e["ids"]
		var x_affiche: float = NAN
		if not ids.is_empty():
			x_affiche = (e["pos"] as PackedVector2Array)[0].x
		sortie.append({"t": t, "x": x_affiche, "recue": recue, "image": image})
	return sortie


func test_deplacement_fluide_a_5_15_et_20_vues_par_seconde() -> void:
	for hz: int in [5, 15, 20]:
		var images: Array[Dictionary] = _rendu(hz, 2.0)
		# Les deux premiers intervalles servent à mesurer le retard : on juge ensuite.
		var depart: int = roundi(3.0 * IPS / hz)
		var pas: Array[float] = []
		for i: int in range(depart + 1, images.size()):
			pas.append(float(images[i]["x"]) - float(images[i - 1]["x"]))
		var moyenne: float = 0.0
		for d: float in pas:
			moyenne += d
		moyenne /= pas.size()
		verifier_proche(moyenne, VITESSE / IPS, 0.01, "%d Hz : vitesse moyenne" % hz)
		for i: int in pas.size():
			verifier(
				absf(pas[i] - moyenne) < 0.1 * moyenne,
				(
					"%d Hz, image %d : pas de %.3f pour une moyenne de %.3f"
					% [hz, i + depart, pas[i], moyenne]
				),
			)


func test_position_continue_a_l_arrivee_d_une_vue() -> void:
	for hz: int in [5, 15, 20]:
		var interp := Interpolation.new()
		var pas_vue: int = roundi(IPS / hz)
		for k: int in 8:
			var t: float = k * pas_vue / IPS
			var x: float = VITESSE * t
			var avant: Dictionary = interp.echantillon(t)
			interp.pousser(_vue(k + 1, [1], [Vector2(x, 0)]), t)
			var apres: Dictionary = interp.echantillon(t)
			# À partir de la 3e vue le retard est mesuré : rien ne doit bouger à l'arrivée.
			if k >= 2:
				_proche(_pos_de(apres, 1), _pos_de(avant, 1), "%d Hz, vue %d" % [hz, k])


func test_vue_en_retard_arrete_l_ennemi_puis_repart_sans_saut() -> void:
	# La vue 8 (15 Hz) arrive 6 images (0,1 s) trop tard : jamais d'extrapolation, puis la
	# reprise ne saute pas de plus d'un pas entre deux vues.
	var images: Array[Dictionary] = _rendu(15, 2.0, {8: 6})
	var pas_vue: float = VITESSE / 15.0
	var arret: int = 0
	for i: int in images.size():
		var x: float = float(images[i]["x"])
		verifier(
			x <= float(images[i]["recue"]) + 0.001,
			"image %d : %.2f dépasse la dernière position reçue %.2f" % [i, x, images[i]["recue"]]
		)
		if i > 0:
			var d: float = x - float(images[i - 1]["x"])
			verifier(d >= -0.001, "image %d : recul de %.3f" % [i, d])
			verifier(
				d <= pas_vue + 0.01, "image %d : saut de %.3f (un pas : %.3f)" % [i, d, pas_vue]
			)
			if d < 0.0001 and i > 12:
				arret += 1
	verifier(arret > 0, "l'ennemi doit s'arrêter pendant le retard de la vue")


func test_alpha_zero_demi_un_et_au_dela_sans_extrapolation() -> void:
	var interp := _deux_vues(_vue(1, [7], [Vector2(0, 0)]), _vue(2, [7], [Vector2(100, 40)]))
	verifier_egal(_pos_de(interp.echantillon(_t(0.0)), 7), Vector2(0, 0))
	verifier_egal(_pos_de(interp.echantillon(_t(0.5)), 7), Vector2(50, 20))
	verifier_egal(_pos_de(interp.echantillon(_t(1.0)), 7), Vector2(100, 40))
	# Aucun nouvel état n'arrive : l'ennemi s'arrête à la dernière position connue,
	# il ne file pas hors de l'arène.
	for t: float in [1.3, 2.0, 10.0, 1000.0]:
		verifier_egal(_pos_de(interp.echantillon(t), 7), Vector2(100, 40), "t=%s" % t)


func test_temps_de_rendu_anterieur_a_la_vue_precedente() -> void:
	var interp := _deux_vues(_vue(1, [7], [Vector2(10, 10)]), _vue(2, [7], [Vector2(100, 40)]))
	for t: float in [0.0, -5.0, _t(-0.5)]:
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
	var e: Dictionary = interp.echantillon(_t(0.5))
	verifier_egal((e["ids"] as PackedInt32Array).size(), 0)
	verifier_egal((e["pos"] as PackedVector2Array).size(), 0)
	verifier_non_nul(e["vue"])


func test_ennemi_apparu_entre_les_deux_vues_est_a_sa_position_finale() -> void:
	var interp := _deux_vues(
		_vue(1, [1], [Vector2(0, 0)]),
		_vue(2, [1, 2], [Vector2(10, 0), Vector2(500, 500)]),
	)
	var e: Dictionary = interp.echantillon(_t(0.5))
	verifier_egal(_pos_de(e, 1), Vector2(5, 0))
	verifier_egal(_pos_de(e, 2), Vector2(500, 500), "pas de glissade depuis nulle part")


func test_ennemi_disparu_entre_les_deux_vues_n_est_plus_affiche() -> void:
	var interp := _deux_vues(
		_vue(1, [1, 2], [Vector2(0, 0), Vector2(50, 50)]), _vue(2, [1], [Vector2(10, 0)])
	)
	var e: Dictionary = interp.echantillon(_t(0.5))
	verifier_egal((e["ids"] as PackedInt32Array).size(), 1)
	verifier_egal((e["ids"] as PackedInt32Array).find(2), -1)


func test_ennemi_apparu_puis_disparu_entre_deux_etats_ne_laisse_aucune_trace() -> void:
	var interp := Interpolation.new()
	interp.pousser(_vue(1, [1], [Vector2(0, 0)]), 1.0)
	# L'ennemi 9 n'existe que dans une vue intermédiaire perdue ou dépassée.
	interp.pousser(_vue(2, [1, 9], [Vector2(10, 0), Vector2(3, 3)]), 1.1)
	interp.pousser(_vue(3, [1], [Vector2(20, 0)]), 1.2)
	for t: float in [1.0, 1.1, 1.15, 1.2, 1.4]:
		var e: Dictionary = interp.echantillon(t)
		verifier_egal((e["ids"] as PackedInt32Array).find(9), -1, "t=%s" % t)
		verifier_egal((e["ids"] as PackedInt32Array).size(), 1)


func test_saut_de_plus_de_200_unites_n_est_pas_interpole() -> void:
	var interp := _deux_vues(
		_vue(1, [1, 2], [Vector2(0, 0), Vector2(0, 0)]),
		_vue(2, [1, 2], [Vector2(199, 0), Vector2(201, 0)]),
	)
	var e: Dictionary = interp.echantillon(_t(0.5))
	verifier_egal(_pos_de(e, 1), Vector2(99.5, 0), "199 unités : interpolé")
	verifier_egal(_pos_de(e, 2), Vector2(201, 0), "201 unités : téléporté")


func test_chaque_ennemi_suit_son_id_quand_les_indices_changent() -> void:
	# Après une purge, les ids ne sont plus aux mêmes indices.
	var interp := _deux_vues(
		_vue(1, [10, 20, 30], [Vector2(0, 0), Vector2(0, 100), Vector2(0, 200)]),
		_vue(2, [30, 10], [Vector2(40, 200), Vector2(40, 0)]),
	)
	var e: Dictionary = interp.echantillon(_t(0.5))
	verifier_egal((e["ids"] as PackedInt32Array).size(), 2)
	verifier_egal(_pos_de(e, 10), Vector2(20, 0))
	verifier_egal(_pos_de(e, 30), Vector2(20, 200))


func test_id_reutilise_par_une_autre_famille_n_est_pas_melange() -> void:
	# Ne devrait pas arriver ; si c'est le cas, c'est un autre ennemi : pas de glissade.
	var interp := _deux_vues(
		_vue(1, [5], [Vector2(0, 0)], [2]), _vue(2, [5], [Vector2(100, 0)], [3])
	)
	verifier_egal(_pos_de(interp.echantillon(_t(0.5)), 5), Vector2(100, 0))
	# Même famille : c'est bien le même ennemi.
	var meme := _deux_vues(_vue(1, [5], [Vector2(0, 0)], [2]), _vue(2, [5], [Vector2(100, 0)], [2]))
	verifier_egal(_pos_de(meme.echantillon(_t(0.5)), 5), Vector2(50, 0))


func test_vue_plus_ancienne_ou_de_meme_tick_est_ignoree() -> void:
	var interp := Interpolation.new()
	var a := _vue(10, [1], [Vector2(0, 0)])
	var b := _vue(11, [1], [Vector2(10, 0)])
	interp.pousser(a, 1.0)
	interp.pousser(b, 1.0 + P)
	interp.pousser(_vue(11, [1], [Vector2(999, 0)]), 2.1)  # doublon de tick
	interp.pousser(_vue(10, [1], [Vector2(-999, 0)]), 2.2)  # réseau : arrivée tardive
	interp.pousser(_vue(3, [1], [Vector2(-999, 0)]), 2.3)
	var e: Dictionary = interp.echantillon(_t(0.5))
	verifier(e["vue"] == b)
	verifier_egal(_pos_de(e, 1), Vector2(5, 0))
	verifier_egal(_pos_de(interp.echantillon(50.0), 1), Vector2(10, 0))


func test_saut_de_plusieurs_ticks_se_lisse_sur_le_temps_de_reception() -> void:
	var interp := _deux_vues(_vue(1, [1], [Vector2(0, 0)]), _vue(41, [1], [Vector2(100, 0)]))
	verifier_egal(_pos_de(interp.echantillon(_t(0.25)), 1), Vector2(25, 0))
	verifier_egal(_pos_de(interp.echantillon(_t(1.0)), 1), Vector2(100, 0))


func test_receptions_simultanees_ne_divisent_pas_par_zero() -> void:
	var interp := Interpolation.new()
	interp.pousser(_vue(1, [1], [Vector2(0, 0)]), 2.0)
	interp.pousser(_vue(2, [1], [Vector2(10, 0)]), 2.0)
	for t: float in [1.0, 2.03, 3.0]:
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
		var e: Dictionary = interp.echantillon(_t(0.5))
		meilleur = mini(meilleur, Time.get_ticks_usec() - debut)
		verifier_egal((e["ids"] as PackedInt32Array).size(), 300)
	verifier(meilleur < 2000, "échantillon de 300 ennemis : %d µs" % meilleur)
	var e2: Dictionary = interp.echantillon(_t(0.5))
	for i: int in 300:
		verifier_egal(_pos_de(e2, i * 3 + 1), Vector2(i + 5.0, 2.0 * i + 2.0))


func test_une_longue_pause_entre_deux_vues_ne_fige_pas_l_ennemi() -> void:
	# Cinq secondes sans vue (onglet en arrière-plan, coupure) : le retard reste borné, l'ennemi
	# ne reste pas des secondes à sa position d'avant.
	var interp := Interpolation.new()
	interp.pousser(_vue(1, [1], [Vector2(0, 0)]), 1.0)
	interp.pousser(_vue(2, [1], [Vector2(100, 0)]), 6.0)
	verifier(_pos_de(interp.echantillon(6.0), 1).x >= 90.0, "retard borné : proche de la vue reçue")


# --- Rejeu : un ennemi à vitesse constante, vues reçues à des images de rendu précises ---------


## Rejoue `arrivees` (`[image de rendu, rang de la vue]`, la vue de rang k porte l'état de la
## simulation à k × `dt_sim`) et rend le plus grand pas affiché d'une image à la suivante, une fois
## les trois premières vues passées (l'affichage démarre sur la première).
func _pas_max_du_rejeu(arrivees: Array, dt_sim: float, images: int) -> float:
	var interp := Interpolation.new()
	var suivante: int = 0
	var precedent: float = NAN
	var pire: float = 0.0
	for image: int in images:
		var t: float = image * IMAGE
		while suivante < arrivees.size() and int(arrivees[suivante][0]) <= image:
			var rang: int = int(arrivees[suivante][1])
			interp.pousser(_vue(rang + 1, [1], [Vector2(VITESSE * rang * dt_sim, 0)]), t)
			suivante += 1
		var e: Dictionary = interp.echantillon(t)
		if e["vue"] == null:
			continue
		var x: float = _pos_de(e, 1).x
		if suivante >= 3 and not is_nan(precedent):
			pire = maxf(pire, x - precedent)
		precedent = x
	return pire


func _regulieres(images_par_vue: int, nombre: int) -> Array:
	var liste: Array = []
	for k: int in nombre:
		liste.append([k * images_par_vue, k])
	return liste


func test_deux_vues_dans_la_meme_image_ne_font_pas_sauter_l_ennemi() -> void:
	# Vues à 20 Hz (toutes les 3 images) ; la vue 50 est retenue et arrive avec la 51.
	var arrivees: Array = []
	for k: int in 100:
		arrivees.append([3 * 51 if k == 50 else 3 * k, k])
	var pas: float = _pas_max_du_rejeu(arrivees, 0.05, 400)
	verifier(pas <= 2.0 * PAS_IDEAL + 0.001, "pas max %.2f u pour %.2f u idéal" % [pas, PAS_IDEAL])


func test_une_cadence_reguliere_garde_le_pas_ideal_a_20_15_et_5_hz() -> void:
	# 20 Hz = une vue toutes les 3 images, 15 Hz = 4, 5 Hz = 12.
	for images_par_vue: int in [3, 4, 12]:
		var dt: float = images_par_vue * IMAGE
		var pas: float = _pas_max_du_rejeu(_regulieres(images_par_vue, 80), dt, 80 * images_par_vue)
		verifier_proche(pas, PAS_IDEAL, 0.01, "%d images par vue" % images_par_vue)
