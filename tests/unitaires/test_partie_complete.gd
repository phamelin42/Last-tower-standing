extends CasDeTest
## Partie entière avec les vraies données : un bot d'achat joue jusqu'à la défaite ou au-delà du
## boss, sans erreur ; coût d'un pas à 8 joueurs en fin de partie.

const GRAINE := 99
const PAS_MAX := 40000
## Le bot rejoue la boutique toutes les 10 s de jeu.
const PERIODE_BOT := 200
const PAS_APRES_BOSS := 600
## Budget du plan : un pas reste sous 5 ms par arène (10e centile ; coût local : 0,05 ms par arène,
## soit un budget cent fois plus large).
const BUDGET_US_PAR_ARENE := 5000.0

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _jouer(p: Partie, ids: Array[int], jusqu_a_la_manche: int) -> int:
	var pas_faits := 0
	var apres_boss := 0
	var manche_boss: int = d.partie["manche_boss"]
	while not p.est_terminee() and pas_faits < PAS_MAX:
		if pas_faits % PERIODE_BOT == 0:
			for id: int in ids:
				BotAchat.jouer(p, id, 8)
		pas_faits += p.avancer(AidesPartie.DT)
		var vues: Array[VueArene] = []
		for id: int in ids:
			var v := p.vue_arene(id, id)
			if v != null:
				vues.append(v)
		var plus_haute := 0
		for v: VueArene in vues:
			plus_haute = maxi(plus_haute, v.manche_max)
			if v.phase == Types.Phase.VICTOIRE:
				p.intention_quitter(ids[vues.find(v)])
		if plus_haute >= jusqu_a_la_manche:
			break
		if plus_haute >= manche_boss:
			apres_boss += 1
			if apres_boss > PAS_APRES_BOSS:
				break
	return pas_faits


func test_une_partie_entiere_en_solo_jusqu_a_la_defaite_ou_apres_le_boss() -> void:
	var p := AidesPartie.partie(d, GRAINE, 1)
	var manche_boss: int = d.partie["manche_boss"]
	_jouer(p, [1], manche_boss + 5)
	var v := p.vue_arene(1, 1)
	var g := p.vue_globale()
	if p.est_terminee():
		verifier_egal(g.classement, [1], "défaite : le joueur est classé")
		verifier(int(g.joueurs[0]["manche"]) >= 1, "il a joué au moins une manche")
	else:
		verifier(
			v.manche_max >= manche_boss,
			"sans défaite, la partie va au moins jusqu'au boss (manche %d)" % v.manche_max
		)
	verifier(v.armes.size() > 0 or p.est_terminee(), "le bot a équipé des armes")
	verifier(g.temps_ecoule > 60.0, "la partie a duré")


func test_cout_d_un_pas_a_8_joueurs_en_fin_de_partie() -> void:
	# Manches de 6 s (au lieu de 30) pour tenir dans la limite de temps d'un test ; l'intervalle
	# d'apparition dépend du numéro de manche, donc la densité de la manche 30 reste la vraie.
	var rapides := (
		AidesPartie
		. donnees(
			{
				"partie.json":
				[[["preparation_s"], 3.0], [["manche_s"], 6.0], [["tour", "pv"], 1000000.0]],
			}
		)
	)
	var ids: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
	var p := AidesPartie.partie(rapides, GRAINE, 8)
	var manche_boss: int = rapides.partie["manche_boss"]
	var courante: Array[int] = [0]
	p.manche_commencee.connect(func(n: int) -> void: courante[0] = n)
	var pas_faits := 0
	# Durée de chaque appel, rapportée à un pas : le budget se juge au 10e centile (S16,
	# `MesurePas`), car la moyenne suit la charge de la machine.
	var durees := PackedInt32Array()
	var pas_mesures := 0
	var ennemis_vus := 0
	while not p.est_terminee() and pas_faits < PAS_MAX and courante[0] < manche_boss + 3:
		if pas_faits % 20 == 0:
			for id: int in ids:
				BotAchat.jouer(p, id, 8)
		var debut := Time.get_ticks_usec()
		var n := p.avancer(AidesPartie.DT)
		var fin := Time.get_ticks_usec()
		pas_faits += n
		if courante[0] >= manche_boss - 6:
			durees.append((fin - debut) / maxi(n, 1))
			pas_mesures += n
	for id: int in ids:
		ennemis_vus = maxi(ennemis_vus, p.vue_arene(id, id).ennemis_id.size())
	verifier(pas_mesures > 0, "la fin de partie a été atteinte")
	verifier(courante[0] >= manche_boss, "les 8 tours tiennent jusqu au boss")
	var par_pas := MesurePas.centile_bas_ms(durees) * 1000.0
	var par_arene := par_pas / float(ids.size())
	print(
		(
			"MESURE T1.10 : %d pas, %.0f µs par pas à 8 joueurs (10e centile), %.0f µs par arène, %d ennemis"
			% [pas_mesures, par_pas, par_arene, ennemis_vus]
		)
	)
	verifier(par_arene < BUDGET_US_PAR_ARENE, "coût par arène %.0f µs" % par_arene)


func test_une_partie_entiere_aux_vraies_durees_va_au_dela_du_boss() -> void:
	d = AidesPartie.donnees({"partie.json": [[["tour", "pv"], 1000000.0]]})
	var manche_boss: int = d.partie["manche_boss"]
	var p := AidesPartie.partie(d, GRAINE, 1)
	_jouer(p, [1], manche_boss + 5)
	var v := p.vue_arene(1, 1)
	var manche := v.manche_max
	verifier(p.est_terminee() or manche >= manche_boss, "défaite ou boss atteint (%d)" % manche)
	verifier(manche > 20, "la tour solide tient longtemps (manche %d)" % manche)
	verifier(p.temps_ecoule() > 30.0 * manche, "le temps écoulé suit les manches")
