extends CasDeTest
## Partie : mode sans fin. Après la victoire sur le boss, les manches reprennent pour ce joueur
## seul ; la partie ne se termine pas tant qu'un joueur y est en vie.

const GRAINE := 4242
const PAS_MAX := 60000
const MANCHE_BOSS := 3
const MANCHES_EN_PLUS := 20

var termines: Array = []


func avant_chaque() -> void:
	termines = []


## Boss à la manche 3, fragile ; tour très solide : la partie ne tombe jamais d'elle-même.
func _donnees_abregees() -> Donnees:
	return (
		AidesPartie
		. donnees(
			{
				"partie.json":
				[
					[["preparation_s"], 1.0],
					[["manche_s"], 4.0],
					[["manche_boss"], float(MANCHE_BOSS)],
					[["tour", "pv"], 1000000.0],
				],
				"ennemis.json": [[["boss", "pv"], 50.0]],
				"economie.json": [[["or_depart"], 100000.0]],
			}
		)
	)


func _partie(n: int, bots: Array[int]) -> Partie:
	var p := AidesPartie.partie(_donnees_abregees(), GRAINE, n)
	p.partie_terminee.connect(func(classement: Array) -> void: termines.append(classement))
	for id: int in bots:
		BotAchat.jouer(p, id, 3)
	return p


func _jouer_jusqu(p: Partie, condition: Callable) -> bool:
	for _i: int in PAS_MAX:
		if condition.call():
			return true
		p.avancer(AidesPartie.DT)
	return condition.call()


func _a_gagne(p: Partie, id: int) -> bool:
	return p.vue_arene(id, id).phase == Types.Phase.VICTOIRE


func _globale(p: Partie, id: int) -> Dictionary:
	for j: Dictionary in p.vue_globale().joueurs:
		if int(j["id"]) == id:
			return j
	return {}


func _victoire(p: Partie, id: int) -> void:
	verifier(_jouer_jusqu(p, func() -> bool: return _a_gagne(p, id)), "le boss tombe")


# --- Refus -------------------------------------------------------------------------------------


func test_continuer_avant_la_victoire_est_refuse_sans_rien_changer() -> void:
	var p := _partie(1, [1])
	verifier_egal(p.intention_continuer_sans_fin(1), Types.Resultat.MAUVAISE_PHASE, "préparation")
	AidesPartie.pas(p, 100)
	verifier_egal(p.intention_continuer_sans_fin(1), Types.Resultat.MAUVAISE_PHASE, "en manche")
	verifier_faux(p.vue_arene(1, 1).sans_fin)
	var salon := AidesPartie.partie(_donnees_abregees(), GRAINE, 1, 1.0, false)
	verifier_egal(salon.intention_continuer_sans_fin(1), Types.Resultat.MAUVAISE_PHASE, "salon")
	verifier_egal(p.intention_continuer_sans_fin(99), Types.Resultat.ARENE_MORTE, "id inconnu")


func test_continuer_au_boss_non_vaincu_est_refuse() -> void:
	var p := AidesPartie.partie(_donnees_abregees(), GRAINE, 1)
	verifier(
		_jouer_jusqu(p, func() -> bool: return p.vue_arene(1, 1).phase == Types.Phase.BOSS),
		"le boss arrive"
	)
	verifier_egal(p.intention_continuer_sans_fin(1), Types.Resultat.MAUVAISE_PHASE)


func test_un_joueur_mort_ne_peut_pas_continuer() -> void:
	var d := AidesPartie.donnees({"partie.json": [[["tour", "pv"], 1.0]]})
	var p := AidesPartie.partie(d, GRAINE, 2)
	verifier(
		_jouer_jusqu(p, func() -> bool: return not bool(_globale(p, 1)["vivant"])),
		"le joueur tombe"
	)
	verifier_egal(p.intention_continuer_sans_fin(1), Types.Resultat.ARENE_MORTE)


func test_continuer_deux_fois_est_refuse_la_seconde() -> void:
	var p := _partie(1, [1])
	_victoire(p, 1)
	verifier_egal(p.intention_continuer_sans_fin(1), Types.Resultat.OK)
	var tick := p.vue_arene(1, 1).tick
	var manche := p.vue_arene(1, 1).manche
	verifier_egal(p.intention_continuer_sans_fin(1), Types.Resultat.MAUVAISE_PHASE)
	var apres := p.vue_arene(1, 1)
	verifier_egal(apres.manche, manche, "la seconde demande ne relance rien")
	verifier_egal(apres.tick, tick)


# --- Reprise -----------------------------------------------------------------------------------


func test_apres_la_victoire_les_manches_reprennent_sans_boss() -> void:
	var p := _partie(1, [1])
	_victoire(p, 1)
	verifier_egal(p.intention_continuer_sans_fin(1), Types.Resultat.OK)
	var v := p.vue_arene(1, 1)
	verifier(v.sans_fin, "la vue le dit")
	verifier_egal(v.phase, Types.Phase.MANCHE)
	verifier_egal(v.manche, MANCHE_BOSS + 1, "numérotation continue")
	verifier(v.temps_restant > 0.0)
	verifier(v.prochaine_famille >= 0, "une famille est annoncée")
	verifier_faux(p.est_terminee())
	var vues: Array[int] = [v.manche]
	var tick := v.tick
	for _i: int in MANCHES_EN_PLUS * 100:
		p.avancer(AidesPartie.DT)
		var m := p.vue_arene(1, 1)
		verifier(m.phase == Types.Phase.MANCHE, "plus jamais de boss ni de victoire")
		if m.manche != vues[-1]:
			vues.append(m.manche)
		if vues.size() > MANCHES_EN_PLUS:
			break
	verifier(p.vue_arene(1, 1).tick > tick, "l'arène avance")
	for k: int in vues.size():
		verifier_egal(vues[k], MANCHE_BOSS + 1 + k, "une manche à la fois")
	verifier(vues.size() > MANCHES_EN_PLUS, "vingt manches au-delà de la victoire")
	verifier_egal(p.vue_arene(1, 1).manche_max, p.vue_arene(1, 1).manche)
	verifier_faux(bool(_globale(p, 1)["victorieux"]), "il rejoue : il n'est plus « terminé »")
	verifier(bool(_globale(p, 1)["vivant"]))


func test_la_boutique_et_les_primes_continuent() -> void:
	var p := _partie(1, [1])
	_victoire(p, 1)
	p.intention_continuer_sans_fin(1)
	var avant := p.vue_arene(1, 1)
	verifier_egal(p.intention_relancer(1), Types.Resultat.OK, "la boutique rouvre")
	AidesPartie.pas(p, 400)
	var apres := p.vue_arene(1, 1)
	verifier(apres.revenu > 0, "le revenu est calculé")
	verifier(apres.eliminations > avant.eliminations, "des ennemis tombent, les primes tombent")


func test_les_autres_joueurs_ne_sont_pas_touches() -> void:
	var p := _partie(2, [1])
	_victoire(p, 1)
	var avant := p.vue_arene(2, 2)
	verifier_egal(p.intention_continuer_sans_fin(1), Types.Resultat.OK)
	verifier_faux(p.vue_arene(2, 2).sans_fin, "le joueur 2 n'est pas en sans fin")
	verifier_egal(p.vue_arene(2, 2).manche, avant.manche)
	AidesPartie.pas(p, 100)
	var apres := p.vue_arene(2, 2)
	verifier_faux(apres.sans_fin)
	verifier(apres.manche <= MANCHE_BOSS, "l'arène 2 n'a pas quitté sa manche")
	verifier_egal(apres.tick, avant.tick + 100, "elle avance toujours à son rythme")
	verifier(p.vue_arene(1, 1).sans_fin)
	verifier_egal(p.intention_continuer_sans_fin(2), Types.Resultat.MAUVAISE_PHASE, "pas gagné")


func test_un_vainqueur_qui_part_reste_termine_pendant_qu_un_autre_continue() -> void:
	var p := _partie(2, [1, 2])
	_victoire(p, 1)
	_victoire(p, 2)
	verifier_egal(p.intention_continuer_sans_fin(2), Types.Resultat.OK)
	verifier_egal(p.intention_quitter(1), Types.Resultat.OK)
	verifier_faux(p.est_terminee(), "le joueur 2 est en sans fin")
	verifier_egal(p.vue_arene(2, 2).phase, Types.Phase.MANCHE)
	verifier(bool(_globale(p, 1)["victorieux"]), "le vainqueur parti reste vainqueur")
	verifier(bool(_globale(p, 2)["vivant"]))


# --- Fin de partie et classement ---------------------------------------------------------------


func test_la_partie_ne_se_termine_pas_tant_qu_un_joueur_en_sans_fin_vit() -> void:
	var p := _partie(1, [1])
	_victoire(p, 1)
	p.intention_continuer_sans_fin(1)
	AidesPartie.pas(p, 400)
	verifier_faux(p.est_terminee())
	verifier_egal(termines.size(), 0)
	verifier(p.vue_globale().en_cours)
	verifier_egal(p.intention_quitter(1), Types.Resultat.OK)
	verifier(p.est_terminee(), "quitter y met fin")
	verifier_egal(termines, [[1]])


func test_un_joueur_en_sans_fin_qui_tombe_termine_la_partie_avec_sa_manche() -> void:
	var p := _partie(1, [1])
	_victoire(p, 1)
	p.intention_continuer_sans_fin(1)
	verifier(
		_jouer_jusqu(p, func() -> bool: return p.est_terminee()), "la difficulté finit par gagner"
	)
	verifier_egal(termines, [[1]])
	var g := p.vue_globale()
	verifier(int(_globale(p, 1)["manche"]) > MANCHE_BOSS, "sa manche atteinte dépasse le boss")
	verifier_faux(bool(_globale(p, 1)["victorieux"]))
	verifier_egal(p.vue_arene(1, 1).phase, Types.Phase.DEFAITE)
	verifier(g.termine)


func test_un_joueur_en_sans_fin_qui_part_compte_sa_manche_atteinte() -> void:
	var p := _partie(2, [1, 2])
	_victoire(p, 1)
	_victoire(p, 2)
	verifier_egal(p.intention_continuer_sans_fin(2), Types.Resultat.OK)
	verifier(
		_jouer_jusqu(p, func() -> bool: return p.vue_arene(2, 2).manche >= MANCHE_BOSS + 4),
		"le joueur 2 va au-delà du boss"
	)
	p.intention_quitter(2)
	verifier_faux(p.est_terminee(), "le vainqueur 1 est toujours en jeu")
	p.intention_quitter(1)
	verifier(p.est_terminee())
	var classement: Array = termines[0]
	verifier_egal(classement, [2, 1], "manche 7 devant un vainqueur resté à la manche 3")
	verifier(int(_globale(p, 2)["manche"]) >= MANCHE_BOSS + 4)


func test_classement_un_sans_fin_tombe_tard_devant_un_vainqueur_parti_a_la_31() -> void:
	var vainqueur := {
		"id": 1, "manche": 31, "degats": 9e9, "pas_fin": 100, "cause": Classement.Cause.VICTOIRE
	}
	var sans_fin := {
		"id": 2, "manche": 40, "degats": 1.0, "pas_fin": 900, "cause": Classement.Cause.DEFAITE
	}
	var tombe := {
		"id": 3, "manche": 31, "degats": 1e12, "pas_fin": 90, "cause": Classement.Cause.DEFAITE
	}
	var entrees: Array[Dictionary] = [tombe, vainqueur, sans_fin]
	verifier_egal(Classement.ordonner(entrees), [2, 1, 3])
	for ordre: Array in [[0, 1, 2], [2, 1, 0], [1, 2, 0]]:
		var melange: Array[Dictionary] = []
		for k: int in ordre:
			melange.append(entrees[k])
		verifier_egal(Classement.ordonner(melange), [2, 1, 3], "indépendant de l'ordre d'entrée")


func test_reproductible_avec_la_meme_graine() -> void:
	var traces: Array[Array] = []
	for _essai: int in 2:
		var p := _partie(1, [1])
		_victoire(p, 1)
		p.intention_continuer_sans_fin(1)
		AidesPartie.pas(p, 1500)
		var v := p.vue_arene(1, 1)
		traces.append([v.manche, v.prochaine_famille, v.eliminations, v.ennemis_id.size()])
	verifier_egal(traces[0], traces[1])


# --- Difficulté --------------------------------------------------------------------------------


func test_les_multiplicateurs_croissent_strictement_au_dela_de_la_31() -> void:
	var d := AidesPartie.donnees()
	var plancher := float(d.difficulte["resistance_plancher"])
	var temps := 900.0
	var avant := Planning.multiplicateurs(d, 31, temps)
	for manche: int in range(32, 32 + MANCHES_EN_PLUS + 40):
		temps += 30.0
		var m := Planning.multiplicateurs(d, manche, temps)
		for cle: String in ["pv", "degats", "vitesse"]:
			verifier(float(m[cle]) > float(avant[cle]), "%s croît à la manche %d" % [cle, manche])
		verifier(
			float(m["resistance_controle"]) <= float(avant["resistance_controle"]),
			"la résistance ne remonte pas"
		)
		verifier(float(m["resistance_controle"]) >= plancher, "jamais sous le plancher")
		avant = m
	verifier_proche(float(avant["resistance_controle"]), plancher, 1e-9, "elle atteint le plancher")
