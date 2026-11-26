extends CasDeTest
## Alliés invoqués (M6) : des unités temporaires, invulnérables et ignorées des ennemis.

const DT := 0.05
const CENTRE := Vector2.ZERO
const SENTINELLE := "sentinelle_de_braise"
const ARCHERE := "archere_des_brumes"

var d: Donnees
var e: Ennemis
var allies: Allies


func avant_chaque() -> void:
	d = AidesPartie.donnees()
	e = Ennemis.new(d)
	allies = Allies.new(d)


func _u(id: String) -> int:
	return d.ids_unites.find(id)


func _ennemi(pos: Vector2, armure: int = Types.Armure.AUCUNE, pv: float = 1.0e6) -> int:
	return e.indice_de(e.ajouter(0, pos, pv, 0.0, 0.0, 40.0, 1.0, 1, armure))


func _invoquer(unite: String = SENTINELLE, duree: float = 10.0, degats: float = 40.0) -> int:
	return allies.invoquer(_u(unite), CENTRE, duree, degats, Types.TypeDegats.TRANCHANT, 5)


func _avancer(secondes: float) -> Tir.Bilan:
	var total := Tir.Bilan.new()
	for _k: int in roundi(secondes / DT):
		var bilan := allies.avancer(DT, e, CENTRE)
		total.degats += bilan.degats
		total.evenements.append_array(bilan.evenements)
	return total


func test_les_donnees_livrees_ont_un_guerrier_et_un_archer() -> void:
	verifier(_u(SENTINELLE) >= 0 and _u(ARCHERE) >= 0)
	verifier_egal((d.unites[SENTINELLE] as Dictionary)["modele"], "guerrier")
	verifier_egal((d.unites[ARCHERE] as Dictionary)["modele"], "archer")


func test_une_invocation_cree_une_unite_pour_sa_duree_et_la_retire_ensuite() -> void:
	var id := _invoquer(SENTINELLE, 2.0)
	verifier(id >= 0)
	verifier_egal(allies.taille, 1)
	_avancer(1.9)
	verifier_egal(allies.taille, 1, "encore là à 1,9 s")
	_avancer(0.3)
	verifier_egal(allies.taille, 0, "partie après sa durée")


func test_une_invocation_invalide_ne_cree_rien() -> void:
	var t := Types.TypeDegats.CHAOS
	for mauvais: Array in [
		[-1, 5.0, 10.0, t],
		[99, 5.0, 10.0, t],
		[0, 0.0, 10.0, t],
		[0, NAN, 10.0, t],
		[0, INF, 10.0, t],
		[0, 5.0, -1.0, t],
		[0, 5.0, NAN, t],
		[0, 5.0, 10.0, 9],
		[0, 5.0, 10.0, -1]
	]:
		verifier_egal(
			allies.invoquer(mauvais[0], CENTRE, mauvais[1], mauvais[2], mauvais[3], 0), -1
		)
	verifier_egal(allies.invoquer(0, Vector2(INF, 0), 5.0, 10.0, t, 0), -1)
	verifier_egal(allies.taille, 0)


func test_les_identifiants_croissent_et_les_allies_naissent_pres_de_la_tour() -> void:
	var precedent := -1
	for _k: int in 10:
		var id := _invoquer()
		verifier(id > precedent, "identifiants croissants")
		precedent = id
	for k: int in allies.taille:
		verifier_proche(allies.pos[k].length(), Allies.RAYON_APPARITION, 0.001)
	var distincts: Dictionary = {}
	for p: Vector2 in allies.pos:
		distincts[p] = true
	verifier_egal(distincts.size(), 10, "chacun a sa place")


func test_l_allie_marche_vers_l_ennemi_le_plus_proche_dans_le_rayon_de_garde_et_ignore_les_autres(
) -> void:
	var proche := _ennemi(Vector2(450, 0))
	var plus_loin := _ennemi(Vector2(520, 60))
	var hors_garde := _ennemi(Vector2(-900, 0))
	_invoquer(SENTINELLE)
	var avant := allies.pos[0].distance_to(e.pos[proche])
	_avancer(1.0)
	verifier(
		allies.pos[0].distance_to(e.pos[proche]) < avant,
		"il se rapproche de l'ennemi le plus proche"
	)
	verifier_egal(allies.cible[0], e.ids[proche])
	_avancer(8.0)
	verifier(e.pv[proche] < 1.0e6, "il l'a attaqué")
	verifier_egal(e.pv[hors_garde], 1.0e6, "l'ennemi hors du rayon de garde est ignoré")
	verifier(e.pv[plus_loin] >= 1.0e6 - 1.0, "l'autre n'est pas visé tant que le premier vit")


func test_deux_ennemis_a_egale_distance_sont_departages_par_l_identifiant() -> void:
	var premier := e.ajouter(0, Vector2(80, 100), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, 0)
	e.ajouter(0, Vector2(80, -100), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, 0)
	_invoquer(SENTINELLE)
	verifier_proche(allies.pos[0].x, 80.0, 0.001)
	_avancer(DT)
	verifier_egal(allies.cible[0], premier, "le plus petit identifiant")


func test_l_allie_attaque_a_sa_portee_a_sa_cadence_avec_le_ratio_des_degats_figes() -> void:
	var cadence := float((d.unites[SENTINELLE] as Dictionary)["cadence"])
	for armure: int in 6:
		avant_chaque()
		var cible := _ennemi(Vector2(80, 30), armure)
		_invoquer(SENTINELLE, 30.0, 40.0)
		var bilan := _avancer(3.0)
		var efficacite: float = (d.efficacite[Types.TypeDegats.TRANCHANT] as Array)[armure]
		var attaques := roundi((1.0e6 - e.pv[cible]) / (40.0 * efficacite))
		verifier_egal(
			attaques, 3, "trois attaques en 3 s (cadence %s s), armure %d" % [cadence, armure]
		)
		verifier_proche(
			bilan.degats, 1.0e6 - e.pv[cible], 0.5, "les dégâts rendus sont les dégâts réels"
		)
		verifier_egal(bilan.evenements.size(), 3, "un événement par coup")


func test_une_archere_tire_de_plus_loin_qu_une_sentinelle() -> void:
	var cible := _ennemi(Vector2(80, 240))
	_invoquer(ARCHERE)
	var depart := allies.pos[0]
	_avancer(0.2)
	verifier(e.pv[cible] < 1.0e6, "à 240 de distance, l'archère tire déjà")
	verifier_proche(allies.pos[0].distance_to(depart), 0.0, 0.001, "sans bouger")
	avant_chaque()
	var cible2 := _ennemi(Vector2(80, 240))
	_invoquer(SENTINELLE)
	_avancer(0.2)
	verifier_egal(e.pv[cible2], 1.0e6, "la sentinelle doit d'abord s'approcher")


func test_l_allie_revient_vers_la_tour_sans_cible() -> void:
	_invoquer(SENTINELLE, 60.0)
	allies.pos[0] = Vector2(300, 0)
	_avancer(6.0)
	verifier_proche(allies.pos[0].length(), Allies.RAYON_RETOUR, 0.5, "il attend près de la tour")
	# Sa cible meurt : il repart vers la tour.
	var cible := _ennemi(Vector2(400, 0), Types.Armure.AUCUNE, 10.0)
	_avancer(3.0)
	e.infliger(cible, 1.0e6, Types.TypeDegats.CHAOS)
	_avancer(10.0)
	verifier(allies.pos[0].length() <= Allies.RAYON_RETOUR + 0.5, "retourné près de la tour")


func test_un_allie_dont_la_cible_est_purgee_ne_plante_pas() -> void:
	_ennemi(Vector2(150, 0), Types.Armure.AUCUNE, 5.0)
	_invoquer(SENTINELLE, 20.0, 1000.0)
	_avancer(2.0)
	e.purger()
	_avancer(2.0)
	verifier_egal(allies.taille, 1)


# --- Arène -----------------------------------------------------------------------------------


func _arene(donnees: Donnees = null) -> Arene:
	var a := Arene.new(donnees if donnees != null else d, 31)
	a.demarrer_manche(
		1,
		Composition.unique(0),
		{"pv": 1.0, "degats": 1.0, "vitesse": 0.0, "resistance_controle": 1.0}
	)
	return a


func test_les_ennemis_ignorent_les_allies() -> void:
	var seule := _arene()
	var accompagnee := _arene()
	for a: Arene in [seule, accompagnee]:
		a.ennemis.ajouter(0, Vector2(100, 0), 1.0e6, 0.0, 10.0, 40.0, 1.0, 1, 0)
	for _k: int in 5:
		accompagnee.allies.invoquer(_u(SENTINELLE), CENTRE, 60.0, 0.0, Types.TypeDegats.CHAOS, 0)
	for _k: int in 100:
		seule.avancer(DT)
		accompagnee.avancer(DT)
	verifier_proche(seule.pv, accompagnee.pv, 0.001, "la tour reçoit les mêmes dégâts")
	verifier(seule.pv < float((d.partie["tour"] as Dictionary)["pv"]), "et elle en reçoit")


func _donnees_avec_invocatrice(max_actives: int = 3) -> Donnees:
	var brut := AidesPartie.brut()
	var armes: Array = brut["armes.json"]
	var arme: Dictionary = (armes[0] as Dictionary).duplicate(true)
	arme["id"] = "meneuse_d_essai"
	arme["nom"] = "Meneuse d’essai"
	arme["recharge"] = 0.5
	arme["portee"] = 1000
	arme["effets"] = [
		{
			"kind": "invocation",
			"unite": SENTINELLE,
			"duree": 8.0,
			"ratio_degats": 0.5,
			"max_actives": max_actives
		}
	]
	arme["statuts"] = []
	armes.append(arme)
	var donnees := Donnees.depuis_brut(brut)
	verifier_non_nul(donnees)
	return donnees


func test_le_tir_invoque_un_allie_et_ne_frappe_pas() -> void:
	var donnees := _donnees_avec_invocatrice()
	var a := _arene(donnees)
	a.inventaire.ajouter("meneuse_d_essai")
	a.synchroniser()
	a.ennemis.ajouter(0, Vector2(400, 0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, 0)
	a.avancer(DT)
	verifier_egal(a.allies.taille, 1)
	verifier_egal(a.ennemis.pv[0], 1.0e6, "invoquer n'inflige rien")


func test_sans_ennemi_a_portee_l_arme_n_invoque_pas() -> void:
	var a := _arene(_donnees_avec_invocatrice())
	a.inventaire.ajouter("meneuse_d_essai")
	a.synchroniser()
	for _k: int in 40:
		a.avancer(DT)
	verifier_egal(a.allies.taille, 0)


func test_les_degats_d_un_allie_sont_figes_a_l_invocation_et_suivent_le_ratio_et_le_type() -> void:
	var donnees := _donnees_avec_invocatrice()
	var a := _arene(donnees)
	a.inventaire.ajouter("meneuse_d_essai")
	a.synchroniser()
	var arme_def: Dictionary = donnees.armes["meneuse_d_essai"]
	a.ennemis.ajouter(0, Vector2(400, 0), 1.0e6, 0.0, 0.0, 40.0, 1.0, 1, Types.Armure.AUCUNE)
	a.avancer(DT)
	var attendu := float(arme_def["degats"]) * 0.5
	verifier_proche(a.allies.degats[0], attendu, 0.001, "ratio 0,5 × dégâts de base")
	verifier_egal(int(a.allies.type_degats[0]), int(arme_def["type_degats"]))
	verifier_egal(int(a.allies.arme[0]), donnees.ids_catalogue.find("meneuse_d_essai"))


func test_la_plus_proche_de_sa_fin_cede_au_dela_de_max_actives_et_de_la_limite_globale() -> void:
	var limite := int((d.partie["limites"] as Dictionary)["allies"])
	for exemplaires: int in [1, 10, 100, 255]:
		var donnees := _donnees_avec_invocatrice(3)
		var a := _arene(donnees)
		for _k: int in exemplaires:
			a.inventaire.ajouter("meneuse_d_essai")
		a.synchroniser()
		verifier_egal(a.armes.size(), exemplaires)
		a.ennemis.ajouter(0, Vector2(400, 0), 1.0e12, 0.0, 0.0, 40.0, 1.0, 1, 0)
		for _pas: int in 200:
			a.avancer(DT)
			verifier(
				a.allies.taille <= limite,
				"jamais plus de %d alliés (%d armes)" % [limite, exemplaires]
			)
		verifier_egal(a.allies.taille, mini(3 * exemplaires, limite), "%d armes" % exemplaires)
		a.demarrer_manche(2, Composition.unique(0), {})
		verifier_egal(a.allies.taille, 0)


func test_le_plus_proche_de_sa_fin_est_celui_qui_cede() -> void:
	for _k: int in 3:
		allies.invoquer(0, CENTRE, 10.0, 1.0, Types.TypeDegats.CHAOS, 0, 7, 3)
	_avancer(1.0)
	var vieux := allies.ids[0]
	allies.invoquer(0, CENTRE, 10.0, 1.0, Types.TypeDegats.CHAOS, 0, 7, 3)
	verifier_egal(allies.taille, 3)
	verifier(not allies.ids.has(vieux), "le plus ancien (le plus proche de sa fin) a cédé")


func test_les_allies_disparaissent_a_la_fin_de_la_manche_a_la_mort_de_la_tour_et_sur_vider(
) -> void:
	var a := _arene()
	a.allies.invoquer(0, CENTRE, 50.0, 1.0, Types.TypeDegats.CHAOS, 0)
	a.demarrer_manche(2, Composition.unique(0), {})
	verifier_egal(a.allies.taille, 0, "fin de manche")
	a.allies.invoquer(0, CENTRE, 50.0, 1.0, Types.TypeDegats.CHAOS, 0)
	a.demarrer_boss({})
	verifier_egal(a.allies.taille, 0, "boss")
	a.allies.invoquer(0, CENTRE, 50.0, 1.0, Types.TypeDegats.CHAOS, 0)
	a.pv = 0.0
	a.avancer(DT)
	verifier(a.est_detruite())
	verifier_egal(a.allies.taille, 0, "tour détruite")
	_invoquer()
	allies.vider()
	verifier_egal(allies.taille, 0, "vider()")
	verifier_egal(
		allies.pos.size() + allies.cible.size() + allies.degats.size(), 0, "tous les tableaux"
	)


func test_aucune_fuite_sur_cent_manches() -> void:
	var a := _arene()
	for manche: int in range(2, 102):
		for _k: int in 5:
			a.allies.invoquer(0, CENTRE, 50.0, 1.0, Types.TypeDegats.CHAOS, 0)
		a.demarrer_manche(manche, Composition.unique(0), {})
		verifier_egal(a.allies.taille, 0, "manche %d" % manche)
		verifier_egal(a.allies.pos.size(), 0)


func test_chaque_coup_d_un_allie_emet_un_evenement_du_genre_invocation_et_l_arme() -> void:
	_ennemi(Vector2(80, 30))
	allies.invoquer(_u(SENTINELLE), CENTRE, 30.0, 40.0, Types.TypeDegats.TRANCHANT, 11)
	var bilan := _avancer(2.0)
	verifier(bilan.evenements.size() >= 2)
	for ev: Dictionary in bilan.evenements:
		verifier_egal(ev["k"], "impact")
		verifier_egal(int(ev["genre"]), VueArene.genre_depuis_nom("invocation"))
		verifier_egal(int(ev["arme"]), 11)
		verifier_egal(int(ev["type_degats"]), Types.TypeDegats.TRANCHANT)


func test_la_vue_porte_les_allies_avec_l_index_de_leur_unite() -> void:
	var a := _arene()
	a.allies.invoquer(_u(ARCHERE), CENTRE, 30.0, 1.0, Types.TypeDegats.CHAOS, 0)
	a.allies.invoquer(_u(SENTINELLE), CENTRE, 30.0, 1.0, Types.TypeDegats.CHAOS, 0)
	var vue := a.vue(Types.Phase.MANCHE, 10.0, -1, false)
	verifier_egal(vue.allies.size(), 2)
	verifier_egal((vue.allies[0] as Dictionary)["unite"], _u(ARCHERE))
	verifier_egal((vue.allies[1] as Dictionary)["unite"], _u(SENTINELLE))
	verifier(
		(vue.allies[0] as Dictionary)["id"] < (vue.allies[1] as Dictionary)["id"], "par identifiant"
	)
	verifier_non_nul(VueArene.from_dict(vue.to_dict()))


# --- Reproductibilité et performance ---------------------------------------------------------


func _empreinte_de_partie(graine: int) -> int:
	var donnees := _donnees_avec_invocatrice(4)
	var a := Arene.new(donnees, graine)
	a.demarrer_manche(
		3,
		Composition.unique(0),
		{"pv": 1.0, "degats": 1.0, "vitesse": 1.0, "resistance_controle": 1.0}
	)
	for _k: int in 3:
		a.inventaire.ajouter("meneuse_d_essai")
	a.synchroniser()
	var cumul := 0
	var vu := false
	for _pas: int in 600:
		a.avancer(DT)
		var v := a.vue(Types.Phase.MANCHE, 10.0, -1, false)
		vu = vu or not v.allies.is_empty()
		for k: int in v.allies.size() - 1:
			var avant: int = (v.allies[k] as Dictionary)["id"]
			var apres: int = (v.allies[k + 1] as Dictionary)["id"]
			verifier(avant < apres, "alliés rangés par identifiant croissant")
		cumul = hash(
			[
				cumul,
				str(v.ennemis_pos),
				str(v.ennemis_pv),
				str(v.allies),
				str(v.evenements),
				v.tour_pv
			]
		)
	verifier(vu, "des alliés ont existé")
	return cumul


func test_les_allies_agissent_par_identifiant_et_la_meme_graine_donne_la_meme_empreinte() -> void:
	var premiere := _empreinte_de_partie(2026)
	verifier_egal(premiere, _empreinte_de_partie(2026))
	verifier_different(premiere, _empreinte_de_partie(2027))


## Mille ennemis immobiles sur le cercle d'apparition (comme `test_arene_charge`), dans la portée
## des armes les plus longues. Entassés à 300-1 050 de la tour, ils coûtent 4,6 à 6 ms par pas :
## c'est le pire cas, que T9.22 remesure avec le catalogue complet.
func test_75_armes_1000_ennemis_64_allies_32_zones_32_bombes_sous_5_ms_par_pas() -> void:
	d.partie["tour"]["pv"] = 1.0e12
	var a := _arene()
	var ids: Array[String] = []
	for id: String in d.armes:
		ids.append(id)
	ids.sort()
	for k: int in 75:
		a.inventaire.ajouter(ids[k % ids.size()])
	a.synchroniser()
	verifier_egal(a.armes.size(), 75)
	for k: int in 1000:
		var angle := float(k) * 0.37
		var rayon := 1100.0 + float(k % 50) * 4.0
		a.ennemis.ajouter(
			0, Vector2(cos(angle), sin(angle)) * rayon, 1.0e12, 0.0, 0.0, 40.0, 1.0, 1, 0
		)
	for k: int in 64:
		a.allies.invoquer(k % 2, CENTRE, 1000.0, 5.0, Types.TypeDegats.CHAOS, 0)
	for k: int in 32:
		var pos := Vector2(350.0 + float(k) * 10.0, float(k) * 6.0)
		a.poses.ajouter_zone(
			{
				"pos": pos,
				"rayon": 80.0,
				"duree": 1000.0,
				"periode": 0.5,
				"degats": 1.0,
				"type_degats": 4,
				"statuts": [],
				"statut": 0,
				"arme": 0,
				"proprietaire": k
			},
			1
		)
		a.poses.ajouter_bombe(
			{
				"pos": pos,
				"rayon": 80.0,
				"delai": 4.0,
				"degats": 1.0,
				"type_degats": 4,
				"statuts": [],
				"statut": 0,
				"arme": 0,
				"proprietaire": 100 + k
			},
			1
		)
	verifier_egal(a.allies.taille, 64)
	# Médiane de cinq fenêtres de 20 pas : une machine partagée ne fait pas échouer un budget tenu.
	var fenetres: Array[float] = []
	for _f: int in 5:
		var debut := Time.get_ticks_usec()
		for _k: int in 20:
			a.avancer(DT)
			if a.tick_courant() % 4 == 0:
				a.vue(Types.Phase.MANCHE, 1.0, -1, false)
		fenetres.append(float(Time.get_ticks_usec() - debut) / 1000.0 / 20.0)
	fenetres.sort()
	var moyenne := fenetres[2]
	print("PERF charge maximale : %.3f ms par pas (médiane)" % moyenne)
	verifier(moyenne < 5.0, "moins de 5 ms par pas en moyenne (%f)" % moyenne)
