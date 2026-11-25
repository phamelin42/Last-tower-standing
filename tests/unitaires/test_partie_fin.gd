extends CasDeTest
## Partie : boss, victoire, fin, classement, « Dernier rempart », observation, intentions.

const GRAINE := 2024
const PAS_MAX := 60000

var termines: Array = []
var elimines: Array[int] = []
var victorieux: Array[int] = []
var manches: Array[int] = []


func avant_chaque() -> void:
	termines = []
	elimines = []
	victorieux = []
	manches = []


func _brancher(p: Partie) -> void:
	p.partie_terminee.connect(func(classement: Array) -> void: termines.append(classement))
	p.joueur_elimine.connect(func(id: int) -> void: elimines.append(id))
	p.joueur_victorieux.connect(func(id: int) -> void: victorieux.append(id))
	p.manche_commencee.connect(func(n: int) -> void: manches.append(n))


## Manches courtes, tour intacte : seul le calendrier compte.
func _donnees_rapides() -> Donnees:
	return (
		AidesPartie
		. donnees(
			{
				"partie.json":
				[
					[["preparation_s"], 1.0],
					[["manche_s"], 2.0],
					[["tour", "pv"], 1000000.0],
				],
			}
		)
	)


## Le boss arrive à la manche 2, il est fragile et la tour solide : un bot qui a des armes gagne.
func _donnees_victoire() -> Donnees:
	return (
		AidesPartie
		. donnees(
			{
				"partie.json":
				[
					[["preparation_s"], 1.0],
					[["manche_s"], 4.0],
					[["manche_boss"], 2.0],
					[["tour", "pv"], 1000000.0],
				],
				"ennemis.json": [[["boss", "pv"], 50.0]],
				"economie.json": [[["or_depart"], 100000.0]],
			}
		)
	)


## Le boss est indestructible et dur : tout joueur finit par tomber, plus ou moins tard.
func _donnees_tomber() -> Donnees:
	return (
		AidesPartie
		. donnees(
			{
				"partie.json":
				[
					[["preparation_s"], 5.0],
					[["manche_s"], 10.0],
					[["manche_boss"], 4.0],
					[["tour", "pv"], 150.0],
				],
				"ennemis.json": [[["boss", "pv"], 1000000000.0], [["boss", "degats"], 400.0]],
				"economie.json": [[["or_depart"], 100000.0]],
			}
		)
	)


func _jouer_jusqu(p: Partie, condition: Callable) -> bool:
	for i: int in PAS_MAX:
		if condition.call():
			return true
		p.avancer(0.05)
	return condition.call()


func _joueur(p: Partie, id: int) -> Dictionary:
	for j: Dictionary in p.vue_globale().joueurs:
		if int(j["id"]) == id:
			return j
	return {}


# --- Boss --------------------------------------------------------------------------------------


func test_le_boss_n_arrive_qu_a_la_manche_31() -> void:
	var d := _donnees_rapides()
	var boss := d.familles.size() + 1
	var p := AidesPartie.partie(d, GRAINE, 2)
	_brancher(p)
	var vu_boss_avant := false
	var vu_boss_a_31 := false
	var phase_boss_avant := false
	for _i: int in 3000:
		p.avancer(0.05)
		for id: int in [1, 2]:
			var v := p.vue_arene(id, id)
			if v.phase == Types.Phase.DEFAITE:
				continue
			if v.manche < 31:
				vu_boss_avant = vu_boss_avant or boss in v.ennemis_famille
				phase_boss_avant = phase_boss_avant or v.phase == Types.Phase.BOSS
			elif v.phase == Types.Phase.BOSS:
				vu_boss_a_31 = vu_boss_a_31 or boss in v.ennemis_famille
		if p.vue_arene(1, 1).manche >= 31:
			break
	verifier_faux(vu_boss_avant, "aucun boss avant la manche 31")
	verifier_faux(phase_boss_avant, "la phase BOSS ne précède pas la manche 31")
	verifier_egal(p.vue_arene(1, 1).manche, 31)
	verifier_egal(p.vue_arene(1, 1).phase, Types.Phase.BOSS)
	AidesPartie.pas(p, 20)
	vu_boss_a_31 = boss in p.vue_arene(1, 1).ennemis_famille
	verifier(vu_boss_a_31, "le boss est là à la manche 31")
	var attendu: Array[int] = []
	for n: int in range(1, 32):
		attendu.append(n)
	verifier_egal(manches, attendu, "manches 1 à 31 dans l'ordre, sans doublon")
	verifier_egal(p.vue_arene(1, 1).temps_restant, 0.0, "pas de minuterie pendant le boss")


# --- Victoire ----------------------------------------------------------------------------------


func _partie_victoire(n: int, bots: Array[int]) -> Partie:
	var p := AidesPartie.partie(_donnees_victoire(), GRAINE, n)
	_brancher(p)
	for id: int in bots:
		BotAchat.jouer(p, id, 3)
	return p


func test_boss_mort_donne_la_victoire_et_fige_l_arene() -> void:
	var p := _partie_victoire(1, [1])
	verifier(p.vue_arene(1, 1).armes.size() > 0, "le bot a des armes")
	var gagne := _jouer_jusqu(p, func() -> bool: return not victorieux.is_empty())
	verifier(gagne, "le boss tombe")
	verifier_egal(victorieux, [1])
	var v := p.vue_arene(1, 1)
	verifier_egal(v.phase, Types.Phase.VICTOIRE)
	verifier_egal(v.manche_max, 2)
	verifier_faux(p.est_terminee(), "la victoire attend « continuer » ou « quitter »")
	var tick := v.tick
	AidesPartie.pas(p, 40)
	verifier_egal(p.vue_arene(1, 1).tick, tick, "l'arène est figée")
	verifier_egal(p.intention_acheter(1, 0), Types.Resultat.MAUVAISE_PHASE)
	verifier_egal(p.intention_relancer(1), Types.Resultat.MAUVAISE_PHASE)
	var j := _joueur(p, 1)
	verifier(bool(j["victorieux"]) and bool(j["vivant"]), "vainqueur, toujours en jeu")
	verifier_egal(p.intention_quitter(1), Types.Resultat.OK)
	verifier(p.est_terminee(), "le vainqueur parti termine la partie")
	verifier_egal(termines, [[1]], "classement : lui seul")
	verifier_egal(elimines.size(), 0, "un vainqueur n'est pas éliminé")
	var g := p.vue_globale()
	verifier(g.termine and bool(_joueur(p, 1)["victorieux"]))
	verifier_egal(g.dernier_rempart, -1, "un vainqueur n'est pas un « dernier rempart »")


func test_un_joueur_gagne_pendant_qu_un_autre_est_encore_en_vie() -> void:
	var p := _partie_victoire(2, [1])
	var gagne := _jouer_jusqu(p, func() -> bool: return not victorieux.is_empty())
	verifier(gagne and victorieux == [1], "le joueur 1 gagne")
	verifier_faux(bool(_joueur(p, 2)["victorieux"]), "le joueur 2 ne gagne pas")
	verifier(bool(_joueur(p, 2)["vivant"]), "le joueur 2 est encore en vie")
	var tick_2 := p.vue_arene(2, 2).tick
	AidesPartie.pas(p, 100)
	verifier_egal(p.vue_arene(2, 2).tick, tick_2 + 100, "l'arène du joueur 2 continue")
	verifier_faux(p.est_terminee(), "la partie continue pour l'autre")
	verifier_egal(p.intention_quitter(1), Types.Resultat.OK)
	verifier_faux(p.est_terminee(), "tant que le joueur 2 est en jeu")
	verifier_egal(termines.size(), 0)
	AidesPartie.pas(p, 20)
	verifier_egal(p.vue_arene(2, 2).tick, tick_2 + 120, "il joue toujours")
	p.retirer_joueur(2)
	verifier(p.est_terminee())
	verifier_egal(termines, [[1, 2]], "le vainqueur devant, puis celui qui est parti")
	verifier_egal(p.vue_globale().dernier_rempart, -1)


# --- Fin, classement, dernier rempart ----------------------------------------------------------


func test_deux_joueurs_qui_meurent_au_meme_pas_sont_classes_par_id() -> void:
	var d := AidesPartie.donnees({"partie.json": [[["tour", "pv"], 1.0]]})
	var p := Partie.new(d, AidesPartie.config(GRAINE))
	_brancher(p)
	p.ajouter_joueur(5, "Arrivé premier")
	p.ajouter_joueur(3, "Arrivé second")
	p.demarrer()
	var pas_de_mort: Array[int] = []
	var pas_courant := 0
	while not p.est_terminee() and pas_courant < PAS_MAX:
		var avant := elimines.size()
		p.avancer(0.05)
		pas_courant += 1
		for _k: int in elimines.size() - avant:
			pas_de_mort.append(pas_courant)
	_verifier_deux_morts(p, pas_de_mort)


func _verifier_deux_morts(p: Partie, pas_de_mort: Array[int]) -> void:
	verifier(p.est_terminee(), "la partie se termine")
	verifier_egal(pas_de_mort.size(), 2, "deux éliminations")
	if pas_de_mort.size() == 2:
		verifier_egal(pas_de_mort[0], pas_de_mort[1], "au même pas")
	verifier_egal(termines.size(), 1)
	verifier_egal(termines[0], [3, 5], "même manche, mêmes dégâts : l'id le plus bas d'abord")
	verifier_egal(p.vue_globale().classement, [3, 5])
	verifier_egal(p.vue_globale().dernier_rempart, -1, "ex æquo : pas de dernier rempart")


func test_en_solo_pas_de_dernier_rempart() -> void:
	var d := AidesPartie.donnees({"partie.json": [[["tour", "pv"], 1.0]]})
	var p := AidesPartie.partie(d, GRAINE, 1)
	_brancher(p)
	var fin := _jouer_jusqu(p, func() -> bool: return p.est_terminee())
	verifier(fin, "la tour tombe")
	verifier_egal(termines, [[1]])
	verifier_egal(p.vue_globale().dernier_rempart, -1, "personne n'est tombé avant lui")


func test_le_dernier_a_tomber_apres_un_autre_est_le_dernier_rempart() -> void:
	var p := AidesPartie.partie(_donnees_tomber(), GRAINE, 2)
	_brancher(p)
	BotAchat.jouer(p, 2, 6)
	var fin := _jouer_jusqu(p, func() -> bool: return p.est_terminee())
	verifier(fin, "les deux tours tombent")
	verifier_egal(elimines, [1, 2], "le joueur sans arme tombe en premier")
	var g := p.vue_globale()
	verifier_egal(g.classement, [2, 1])
	verifier_egal(g.dernier_rempart, 2, "le dernier debout, après l'autre, a la mention")
	verifier_egal(termines, [[2, 1]])


func test_le_classement_suit_manche_puis_degats_puis_id() -> void:
	var p := AidesPartie.partie(_donnees_tomber(), GRAINE, 4)
	_brancher(p)
	BotAchat.jouer(p, 3, 6)
	var fin := _jouer_jusqu(p, func() -> bool: return p.est_terminee())
	verifier(fin)
	var g := p.vue_globale()
	verifier_egal(g.classement.size(), 4)
	verifier_egal(g.classement[0], 3, "le joueur armé finit premier")
	for i: int in g.classement.size() - 1:
		var a := _joueur(p, g.classement[i])
		var b := _joueur(p, g.classement[i + 1])
		var ok := int(a["manche"]) > int(b["manche"])
		if int(a["manche"]) == int(b["manche"]):
			ok = float(a["degats"]) > float(b["degats"])
			if float(a["degats"]) == float(b["degats"]):
				ok = int(a["id"]) < int(b["id"])
		verifier(ok, "rang %d avant rang %d" % [i + 1, i + 2])


# --- Observation -------------------------------------------------------------------------------


func test_observation_un_mort_voit_tout_un_vivant_seulement_sa_tour() -> void:
	var p := AidesPartie.partie(_donnees_tomber(), GRAINE, 3)
	_brancher(p)
	BotAchat.jouer(p, 2, 6)
	BotAchat.jouer(p, 3, 6)
	var un_mort := _jouer_jusqu(p, func() -> bool: return elimines.has(1))
	verifier(un_mort and not p.est_terminee(), "le joueur 1 est tombé, les autres jouent")
	verifier_non_nul(p.vue_arene(1, 1), "le mort revoit sa propre arène")
	verifier_egal(p.vue_arene(1, 1).phase, Types.Phase.DEFAITE)
	verifier_non_nul(p.vue_arene(1, 2), "le mort observe un vivant")
	verifier_non_nul(p.vue_arene(1, 3), "le mort observe un autre vivant")
	verifier_non_nul(p.vue_arene(2, 2), "un vivant voit sa tour")
	verifier_nul(p.vue_arene(2, 3), "un vivant ne voit pas celle d'un autre vivant")
	verifier_nul(p.vue_arene(2, 1), "un vivant ne voit pas non plus une arène détruite")
	verifier_nul(p.vue_arene(1, 99), "cible inconnue")
	verifier_nul(p.vue_arene(99, 2), "demandeur inconnu")
	verifier_nul(p.vue_arene(99, 99), "les deux inconnus")
	verifier_nul(p.vue_arene(1, -1), "cible -1")


func test_observation_un_mort_ne_voit_pas_une_arene_retiree() -> void:
	var p := AidesPartie.partie(_donnees_tomber(), GRAINE, 3)
	_brancher(p)
	BotAchat.jouer(p, 2, 6)
	BotAchat.jouer(p, 3, 6)
	_jouer_jusqu(p, func() -> bool: return elimines.has(1))
	p.retirer_joueur(3)
	verifier_nul(p.vue_arene(1, 3), "l'arène d'un déconnecté n'existe plus")
	verifier_non_nul(p.vue_arene(1, 2))


# --- Intentions --------------------------------------------------------------------------------


func test_intentions_d_un_id_inconnu_ou_mort_sont_refusees_sans_exception() -> void:
	var p := AidesPartie.partie(_donnees_tomber(), GRAINE, 2)
	_brancher(p)
	BotAchat.jouer(p, 2, 6)
	_jouer_jusqu(p, func() -> bool: return elimines.has(1))
	for id: int in [1, 99, -1, 0]:
		var motif := "id %d" % id
		verifier_egal(p.intention_acheter(id, 0), Types.Resultat.ARENE_MORTE, motif)
		verifier_egal(p.intention_relancer(id), Types.Resultat.ARENE_MORTE, motif)
		verifier_egal(p.intention_vendre(id, 0), Types.Resultat.ARENE_MORTE, motif)
		verifier_egal(p.intention_marche_noir(id, "x"), Types.Resultat.ARENE_MORTE, motif)
	verifier_egal(
		p.intention_acheter(2, 99), Types.Resultat.INDICE_INVALIDE, "un vivant : l'arène répond"
	)


func test_intentions_avant_le_demarrage() -> void:
	var p := Partie.new(AidesPartie.donnees(), AidesPartie.config(GRAINE))
	p.ajouter_joueur(1, "Ali")
	verifier_egal(p.intention_acheter(1, 0), Types.Resultat.MAUVAISE_PHASE)
	verifier_egal(p.intention_acheter(2, 0), Types.Resultat.ARENE_MORTE)
