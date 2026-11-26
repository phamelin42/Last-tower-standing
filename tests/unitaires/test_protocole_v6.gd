extends CasDeTest
## Protocole version 6 : l'état global porte les PV et les PV max de chaque tour, pour que la barre
## d'une vignette d'observation soit connue même pour une arène jamais regardée (suivi S14).

const GRAINE := 20261126


func _globale() -> VueGlobale:
	var g := VueGlobale.new()
	g.temps_ecoule = 12.5
	g.en_cours = true
	for i: int in 3:
		(
			g
			. joueurs
			. append(
				{
					"id": 100 + i,
					"nom": "Joueur %d" % i,
					"manche": 3,
					"eliminations": 7,
					"degats": 100.5,
					"dps": 33.25,
					"pv": 250.0 * float(i + 1),
					"pv_max": 1000.0 + float(i),
					"revenu": 20,
					"vivant": true,
					"victorieux": false,
				}
			)
		)
	return g


func test_la_version_du_protocole_est_6() -> void:
	verifier_egal(Protocole.VERSION, 6)


func test_un_bonjour_d_une_version_precedente_est_refuse_avec_un_motif() -> void:
	for ancienne: int in range(0, Protocole.VERSION):
		var b := Protocole.encoder_bonjour("Phil", 42)
		b[1] = ancienne
		verifier_egal(Protocole.decoder_bonjour(b), {}, "version %d" % ancienne)
		verifier_egal(Protocole.version_bonjour(b), ancienne)
		var motif := Protocole.motif_version(ancienne)
		verifier(motif.contains(str(ancienne)) and motif.contains(str(Protocole.VERSION)), motif)


func test_l_etat_global_porte_les_pv_et_pv_max_de_chaque_joueur() -> void:
	var g := _globale()
	var d := Protocole.decoder_etat_global(Protocole.encoder_etat_global(g))
	verifier_non_nul(d)
	if d == null:
		return
	verifier_egal(d.joueurs.size(), 3)
	for i: int in 3:
		verifier_proche(float(d.joueurs[i]["pv"]), 250.0 * float(i + 1), 0.001)
		verifier_proche(float(d.joueurs[i]["pv_max"]), 1000.0 + float(i), 0.001)
	verifier_non_nul(VueGlobale.from_dict(d.to_dict()), "la vue décodée est conforme")


func test_un_etat_global_tronque_est_refuse_a_chaque_longueur() -> void:
	var b := Protocole.encoder_etat_global(_globale())
	for n: int in b.size():
		verifier_nul(Protocole.decoder_etat_global(b.slice(0, n)), "tronqué à %d octets" % n)


func test_la_vue_globale_relit_un_ancien_etat_sans_pv_avec_zero() -> void:
	var dico := _globale().to_dict()
	for entree: Dictionary in dico["joueurs"]:
		entree.erase("pv")
		entree.erase("pv_max")
	var relue := VueGlobale.from_dict(dico)
	verifier_non_nul(relue)
	if relue == null:
		return
	verifier_egal(float(relue.joueurs[0]["pv"]), 0.0)
	verifier_egal(float(relue.joueurs[0]["pv_max"]), 0.0)


func test_la_vue_globale_de_la_simulation_porte_les_pv_de_chaque_tour() -> void:
	var p := AidesPartie.partie(Donnees.charger(), GRAINE, 2)
	AidesPartie.pas(p, 40)
	for j: Dictionary in p.vue_globale().joueurs:
		var vue := p.vue_arene(int(j["id"]), int(j["id"]))
		verifier_egal(float(j["pv"]), vue.tour_pv, "PV du joueur %d" % int(j["id"]))
		verifier_egal(float(j["pv_max"]), vue.tour_pv_max, "PV max du joueur %d" % int(j["id"]))
		verifier(float(j["pv_max"]) > 0.0, "PV max connus")
