extends CasDeTest
## Partie : salon, démarrage, temps, vitesse, reproductibilité, déconnexions, vues.

const GRAINE := 777

var d: Donnees
var termines: Array = []
var elimines: Array[int] = []
var manches: Array[int] = []


func avant_chaque() -> void:
	d = Donnees.charger()
	termines = []
	elimines = []
	manches = []


func _brancher(p: Partie) -> void:
	p.partie_terminee.connect(func(classement: Array) -> void: termines.append(classement))
	p.joueur_elimine.connect(func(id: int) -> void: elimines.append(id))
	p.manche_commencee.connect(func(n: int) -> void: manches.append(n))


# --- Salon -------------------------------------------------------------------------------------


func test_de_1_a_8_joueurs_600_pas_et_vues_coherentes() -> void:
	for n: int in range(1, 9):
		var p := AidesPartie.partie(d, GRAINE, n)
		AidesPartie.pas(p, 600)
		var g := p.vue_globale()
		verifier_egal(g.joueurs.size(), n, "%d joueurs" % n)
		verifier(g.en_cours and not g.termine, "partie en cours à %d joueurs" % n)
		verifier_proche(g.temps_ecoule, 30.0, 1e-6, "30 s après 600 pas")
		verifier_proche(p.temps_ecoule(), 30.0, 1e-6)
		verifier_egal(g.classement.size(), 0, "pas de classement avant la fin")
		verifier_egal(g.dernier_rempart, -1)
		for i: int in n:
			var j: Dictionary = g.joueurs[i]
			verifier_egal(j["id"], i + 1, "ordre d'arrivée conservé")
			verifier(bool(j["vivant"]) and not bool(j["victorieux"]), "joueur %d vivant" % (i + 1))
			var v := p.vue_arene(i + 1, i + 1)
			verifier_non_nul(v, "chaque joueur voit son arène")
			verifier_egal(v.tick, 600)
			verifier_egal(v.manche, 1, "la manche 1 commence après la préparation")
			verifier_egal(v.phase, Types.Phase.MANCHE)
			verifier_egal(v.offres.size(), 4)


func test_neuvieme_joueur_refuse() -> void:
	var p := Partie.new(d, AidesPartie.config(GRAINE))
	for i: int in range(1, 9):
		verifier(p.ajouter_joueur(i, "J%d" % i), "joueur %d accepté" % i)
	verifier_faux(p.ajouter_joueur(9, "Trop"), "le 9e joueur est refusé")
	verifier_egal(p.vue_globale().joueurs.size(), 8)


func test_identifiant_duplique_ou_negatif_refuse() -> void:
	var p := Partie.new(d, AidesPartie.config(GRAINE))
	verifier(p.ajouter_joueur(5, "Anne"))
	verifier_faux(p.ajouter_joueur(5, "Autre Anne"), "id déjà pris")
	verifier_faux(p.ajouter_joueur(-1, "Négatif"), "-1 est réservé à « aucun joueur »")
	verifier_egal(p.vue_globale().joueurs.size(), 1)
	verifier_egal(p.vue_globale().joueurs[0]["nom"], "Anne")


func test_ajout_apres_demarrage_refuse() -> void:
	var p := AidesPartie.partie(d, GRAINE, 2)
	verifier_faux(p.ajouter_joueur(3, "Retardataire"))
	verifier_egal(p.vue_globale().joueurs.size(), 2)


func test_demarrer_deux_fois_refuse() -> void:
	var p := AidesPartie.partie(d, GRAINE, 1)
	verifier_faux(p.demarrer(), "une partie ne démarre qu'une fois")


func test_un_joueur_retire_au_salon_libere_sa_place() -> void:
	var p := Partie.new(d, AidesPartie.config(GRAINE))
	for i: int in range(1, 9):
		p.ajouter_joueur(i, "J%d" % i)
	p.retirer_joueur(3)
	verifier_egal(p.vue_globale().joueurs.size(), 7)
	verifier(p.ajouter_joueur(9, "Remplaçant"), "la place libérée est reprenable")


func test_vue_globale_avant_demarrer() -> void:
	var p := Partie.new(d, AidesPartie.config(GRAINE))
	var vide := p.vue_globale()
	verifier_non_nul(vide, "même sans joueur")
	verifier_faux(vide.en_cours)
	verifier_faux(vide.termine)
	verifier_egal(vide.joueurs.size(), 0)
	p.ajouter_joueur(2, "Bea")
	p.ajouter_joueur(1, "Ali")
	var g := p.vue_globale()
	verifier_faux(g.en_cours, "pas encore en cours")
	verifier_faux(g.termine)
	verifier_egal(g.classement.size(), 0)
	verifier_egal(g.dernier_rempart, -1)
	verifier_proche(g.temps_ecoule, 0.0)
	verifier_egal(g.joueurs.size(), 2)
	verifier_egal(g.joueurs[0]["id"], 2, "ordre d'arrivée")
	verifier_egal(g.joueurs[1]["nom"], "Ali")
	verifier(bool(g.joueurs[0]["vivant"]), "un joueur du salon est présent")
	verifier_nul(p.vue_arene(1, 1), "pas d'arène avant le démarrage")
	verifier_faux(p.est_terminee())
	verifier_egal(p.avancer(1.0), 0, "rien ne bouge avant le démarrage")
	verifier(VueGlobale.from_dict(g.to_dict()) != null, "la vue du salon est sérialisable")


# --- Zéro joueur et déconnexions ---------------------------------------------------------------


func test_zero_joueur_ne_demarre_pas_et_ne_plante_pas() -> void:
	var p := Partie.new(d, AidesPartie.config(GRAINE))
	_brancher(p)
	verifier_faux(p.demarrer(), "demarrer() est faux sans joueur")
	verifier_egal(p.avancer(5.0), 0)
	verifier_faux(p.est_terminee())
	verifier_proche(p.temps_ecoule(), 0.0)
	p.retirer_joueur(42)
	verifier_egal(p.intention_acheter(42, 0), Types.Resultat.ARENE_MORTE)
	verifier_nul(p.vue_arene(1, 1))
	verifier_egal(termines.size(), 0, "aucune fin sans partie")


func test_tous_deconnectes_pendant_la_preparation() -> void:
	var p := AidesPartie.partie(d, GRAINE, 3)
	_brancher(p)
	AidesPartie.pas(p, 100)
	for i: int in range(1, 4):
		p.retirer_joueur(i)
	verifier(p.est_terminee())
	verifier_egal(termines.size(), 1, "partie_terminee émis une fois")
	verifier_egal(termines[0], [], "personne n'a atteint une manche : classement vide")
	verifier_egal(elimines.size(), 3, "chaque départ est une élimination")
	var g := p.vue_globale()
	verifier(g.termine and not g.en_cours)
	verifier_egal(g.classement, [])
	verifier_egal(g.dernier_rempart, -1)
	var ticks := p.temps_ecoule()
	verifier_egal(p.avancer(1.0), 0, "plus rien ne se simule après la fin")
	verifier_proche(p.temps_ecoule(), ticks)
	p.retirer_joueur(1)
	verifier_egal(termines.size(), 1, "pas de seconde fin")


func test_deconnexion_en_pleine_manche_les_autres_continuent() -> void:
	var p := AidesPartie.partie(d, GRAINE, 3)
	_brancher(p)
	AidesPartie.pas(p, 900)
	p.retirer_joueur(2)
	verifier_egal(elimines, [2])
	verifier_faux(p.est_terminee())
	verifier_nul(p.vue_arene(2, 2), "son arène est retirée")
	verifier_nul(p.vue_arene(1, 2), "personne ne peut plus la voir")
	var avant := p.vue_arene(1, 1).tick
	AidesPartie.pas(p, 50)
	verifier_egal(p.vue_arene(1, 1).tick, avant + 50, "l'arène 1 continue")
	verifier_egal(p.vue_arene(3, 3).tick, avant + 50, "l'arène 3 continue")
	var j := _joueur(p, 2)
	verifier_faux(bool(j["vivant"]), "il est compté éliminé")
	verifier_egal(p.vue_globale().joueurs.size(), 3, "il reste dans la liste")
	verifier_egal(p.intention_acheter(2, 0), Types.Resultat.ARENE_MORTE)
	p.retirer_joueur(2)
	verifier_egal(elimines, [2], "retirer deux fois ne l'élimine qu'une fois")


func test_un_joueur_vivant_qui_quitte_est_elimine() -> void:
	var p := AidesPartie.partie(d, GRAINE, 2)
	_brancher(p)
	AidesPartie.pas(p, 700)
	verifier_egal(p.intention_quitter(1), Types.Resultat.OK)
	verifier_egal(elimines, [1])
	verifier_faux(p.est_terminee())
	verifier_egal(p.intention_quitter(99), Types.Resultat.ARENE_MORTE, "id inconnu : refus propre")


func _joueur(p: Partie, id: int) -> Dictionary:
	for j: Dictionary in p.vue_globale().joueurs:
		if int(j["id"]) == id:
			return j
	return {}


# --- Temps, vitesse, bornes --------------------------------------------------------------------


func test_la_preparation_dure_30_s_puis_les_manches_30_s() -> void:
	var p := AidesPartie.partie(d, GRAINE, 1)
	_brancher(p)
	var v := p.vue_arene(1, 1)
	verifier_egal(v.phase, Types.Phase.PREPARATION)
	verifier_egal(v.manche, 0)
	verifier_proche(v.temps_restant, 30.0, 1e-6)
	verifier(v.prochaine_famille >= 0, "la famille de la manche 1 est annoncée")
	AidesPartie.pas(p, 100)
	verifier_proche(p.vue_arene(1, 1).temps_restant, 25.0, 1e-6)
	AidesPartie.pas(p, 499)
	verifier_egal(p.vue_arene(1, 1).phase, Types.Phase.PREPARATION, "encore 0,05 s")
	AidesPartie.pas(p, 1)
	v = p.vue_arene(1, 1)
	verifier_egal(v.phase, Types.Phase.MANCHE)
	verifier_egal(v.manche, 1)
	verifier_proche(v.temps_restant, 30.0, 1e-6)
	AidesPartie.pas(p, 600)
	verifier_egal(p.vue_arene(1, 1).manche, 2)
	verifier_egal(manches, [1, 2], "manche_commencee à chaque manche, pas à la préparation")


func test_les_familles_annoncees_sont_celles_qui_apparaissent() -> void:
	var solide := AidesPartie.donnees({"partie.json": [[["tour", "pv"], 1000000.0]]})
	for graine: int in range(1, 6):
		var p := AidesPartie.partie(solide, graine, 1)
		var annoncee := p.vue_arene(1, 1).prochaines_familles
		AidesPartie.pas(p, 600)
		for manche: int in range(1, 5):
			var avant := p.vue_arene(1, 1)
			AidesPartie.pas(p, 60)
			var v := p.vue_arene(1, 1)
			verifier_egal(v.manche, manche)
			var nouveaux := 0
			for i: int in v.ennemis_id.size():
				if v.ennemis_id[i] in avant.ennemis_id:
					continue
				nouveaux += 1
				verifier(
					v.ennemis_famille[i] in annoncee,
					(
						"graine %d manche %d : famille %d hors de %s"
						% [graine, manche, v.ennemis_famille[i], annoncee]
					)
				)
			verifier(nouveaux > 0, "des ennemis de la manche %d sont apparus" % manche)
			annoncee = v.prochaines_familles
			AidesPartie.pas(p, 540)


func test_facteur_0_5_atteint_le_meme_etat_en_deux_fois_moins_de_temps_reel() -> void:
	var lent := AidesPartie.partie(d, GRAINE, 2, 1.0)
	var rapide := AidesPartie.partie(d, GRAINE, 2, 0.5)
	var pas_lent := 0
	var pas_rapide := 0
	for _i: int in 1500:
		pas_lent += lent.avancer(0.05)
		pas_rapide += rapide.avancer(0.025)
	verifier_egal(pas_lent, 1500)
	verifier_egal(pas_rapide, 1500, "autant de pas avec la moitié du temps réel")
	verifier_egal(rapide.vue_globale().to_dict(), lent.vue_globale().to_dict())
	for id: int in [1, 2]:
		verifier_egal(rapide.vue_arene(id, id).to_dict(), lent.vue_arene(id, id).to_dict())
	verifier_proche(lent.temps_ecoule(), 75.0, 1e-6)


func test_facteur_invalide_vaut_1() -> void:
	for facteur: float in [0.0, -2.0, NAN, INF]:
		var p := AidesPartie.partie(d, GRAINE, 1, facteur)
		verifier_egal(p.avancer(0.05), 1, "facteur %s ramené à 1" % facteur)


func test_dt_de_60_s_reste_borne() -> void:
	var p := AidesPartie.partie(d, GRAINE, 8)
	var debut := Time.get_ticks_msec()
	var n := p.avancer(60.0)
	var duree := Time.get_ticks_msec() - debut
	_verifier_borne(n, duree)
	var m := p.avancer(60.0)
	verifier(m <= Partie.PAS_MAX_PAR_APPEL and m > 0, "toujours borné au deuxième appel")
	var apres := p.avancer(0.05)
	verifier_egal(apres, 1, "le retard n'est pas rattrapé : le pas suivant est normal")


func _verifier_borne(n: int, duree_ms: int) -> void:
	verifier(n > 0, "un gros dt fait avancer")
	verifier(n <= Partie.PAS_MAX_PAR_APPEL, "au plus PAS_MAX_PAR_APPEL pas, reçu %d" % n)
	verifier(duree_ms < 5000, "pas de gel : %d ms" % duree_ms)


func test_dt_nul_negatif_ou_non_fini_ne_fait_rien() -> void:
	var p := AidesPartie.partie(d, GRAINE, 1)
	for dt: float in [0.0, -1.0, NAN, INF, -INF]:
		verifier_egal(p.avancer(dt), 0, "dt = %s" % dt)
	verifier_proche(p.temps_ecoule(), 0.0)
	verifier_egal(p.avancer(0.01), 0, "un dt trop court s'accumule sans pas")
	verifier_egal(p.avancer(0.04), 1, "…jusqu'à faire un pas")


func test_dt_irregulier_donne_le_meme_nombre_de_pas() -> void:
	var p := AidesPartie.partie(d, GRAINE, 1)
	var total := 0
	for _i: int in 1000:
		total += p.avancer(0.0125)
	verifier_egal(total, 250, "1000 × 0,0125 s = 12,5 s = 250 pas")


# --- Reproductibilité --------------------------------------------------------------------------


func _jouer_3000_pas(graine: int, lire_la_vue_globale: bool) -> Partie:
	var p := AidesPartie.partie(d, graine, 3)
	for pas_courant: int in 3000:
		if pas_courant % 100 == 0:
			BotAchat.jouer(p, 1 + (pas_courant / 100) % 3)
		if lire_la_vue_globale and pas_courant % 40 == 0:
			p.vue_globale()
		p.avancer(0.05)
	return p


func test_meme_graine_memes_intentions_memes_vues_a_3000_pas() -> void:
	var a := _jouer_3000_pas(GRAINE, false)
	var b := _jouer_3000_pas(GRAINE, false)
	verifier_egal(a.vue_globale().to_dict(), b.vue_globale().to_dict())
	for id: int in range(1, 4):
		verifier_egal(a.vue_arene(id, id).to_dict(), b.vue_arene(id, id).to_dict(), "arène %d" % id)
	var c := _jouer_3000_pas(GRAINE + 1, false)
	verifier_different(
		c.vue_arene(1, 1).to_dict(),
		a.vue_arene(1, 1).to_dict(),
		"une autre graine change la partie"
	)
	verifier(a.vue_arene(1, 1).armes.size() > 0, "le bot a bien acheté : le test n'est pas vide")


func test_lire_la_vue_globale_ne_change_pas_la_partie() -> void:
	var a := _jouer_3000_pas(GRAINE, false)
	var b := _jouer_3000_pas(GRAINE, true)
	for id: int in range(1, 4):
		var va := a.vue_arene(id, id).to_dict()
		var vb := b.vue_arene(id, id).to_dict()
		va.erase("evenements")
		vb.erase("evenements")
		verifier_egal(vb, va, "arène %d" % id)
	var ga := a.vue_globale().to_dict()
	var gb := b.vue_globale().to_dict()
	verifier_egal(gb, ga)


func test_les_evenements_lus_par_la_vue_globale_ne_sont_pas_perdus() -> void:
	var solide := AidesPartie.donnees({"partie.json": [[["tour", "pv"], 1000000.0]]})
	var comptes: Array[int] = []
	for lire: bool in [false, true]:
		var p := AidesPartie.partie(solide, GRAINE, 1)
		BotAchat.jouer(p, 1)
		for i: int in 1500:
			if lire and i % 40 == 0:
				p.vue_globale()
			p.avancer(0.05)
		comptes.append(p.vue_arene(1, 1).evenements.size())
	verifier(comptes[0] > 0, "des événements existent")
	verifier_egal(comptes[1], comptes[0], "lire la vue globale ne vole aucun événement")
