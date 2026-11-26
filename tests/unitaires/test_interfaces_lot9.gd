extends CasDeTest
## Interfaces figées du lot 9 (T9.2) : familles d'améliorations, nouveaux effets et statuts d'arme,
## stats d'amélioration, unités, plafonds de `partie.json`, bits de statut, vue d'arène.
## Aucune donnée de jeu n'utilise encore les nouveautés : ces tests parlent de ce que les
## schémas acceptent et refusent, jamais d'un effectif de catalogue.

const FICHIER_ARMES := "armes.json"
const FICHIER_AMELIOS := "ameliorations.json"

## Stats d'amélioration d'avant le lot 9 (celles de `Donnees.STATS_AMELIORATION` jusqu'à T8.7).
const STATS_ANCIENNES: Array[String] = [
	"degats_type",
	"degats_global",
	"pv_max",
	"regen",
	"armure",
	"esquive",
	"epines",
	"critique_chance",
	"cadence",
	"tirs_multiples",
	"eclaboussure",
	"focalisation",
	"vol_de_vie_coup",
	"vol_de_vie_mort",
	"revenu_fixe",
	"revenu_croissant",
	"revenu_mult",
	"prime_mult",
	"bonus_elim",
	"relance_gratuite",
	"marche_noir",
	"mana_max",
	"mana_regen",
]

## Stat → famille attendue pour les améliorations qui existaient avant le lot 9.
const FAMILLE_DE_STAT: Dictionary = {
	"degats_type": "degats_type",
	"degats_global": "degats_global",
	"focalisation": "degats_classe",
	"eclaboussure": "degats_classe",
	"tirs_multiples": "degats_classe",
	"cadence": "cadence",
	"pv_max": "pv_max",
	"regen": "regeneration",
	"vol_de_vie_coup": "regeneration",
	"vol_de_vie_mort": "regeneration",
	"armure": "armure",
	"esquive": "esquive",
	"epines": "epines",
	"mana_max": "mana",
	"mana_regen": "mana",
	"revenu_fixe": "revenu",
	"revenu_croissant": "revenu",
	"revenu_mult": "revenu",
	"prime_mult": "revenu",
	"bonus_elim": "revenu",
	"relance_gratuite": "boutique",
	"marche_noir": "boutique",
	"critique_chance": "critique",
}


func _unite() -> Dictionary:
	return {
		"id": "u1",
		"nom": "Unité d’essai",
		"modele": "guerrier",
		"vitesse": 80.0,
		"portee": 40.0,
		"cadence": 1.0,
		"rayon_garde": 300.0,
	}


func _effets_valides() -> Dictionary:
	return {
		"tournant":
		{"kind": "tournant", "branches": 3, "pas_deg": 20.0, "largeur": 10.0, "sens": "horaire"},
		"zone_posee":
		{
			"kind": "zone_posee",
			"rayon": 100.0,
			"duree": 5.0,
			"periode": 0.5,
			"ratio": 0.3,
			"max_actives": 2
		},
		"bombe": {"kind": "bombe", "delai": 2.0, "rayon": 100.0, "ratio": 3.0, "max_actives": 2},
		"invocation":
		{"kind": "invocation", "unite": "u1", "duree": 10.0, "ratio_degats": 0.5, "max_actives": 3},
	}


func _statuts_valides() -> Dictionary:
	return {
		"vulnerabilite": {"kind": "vulnerabilite", "ratio": 0.1, "duree": 3.0},
		"malediction_degats": {"kind": "malediction_degats", "ratio": 0.3, "duree": 4.0},
		"malediction_toucher": {"kind": "malediction_toucher", "ratio": 0.3, "duree": 4.0},
		"repoussement": {"kind": "repoussement", "distance": 50.0},
		"siphon": {"kind": "siphon", "ressource": "mana", "par_seconde": 2.0, "duree": 3.0},
		"mana_au_coup": {"kind": "mana_au_coup", "valeur": 2.0},
	}


func _stats_valides() -> Dictionary:
	return {
		"degats_classe": {"stat": "degats_classe", "classe": "onde", "valeur": 0.1},
		"etat_degats": {"stat": "etat_degats", "etat": "poison", "valeur": 0.1},
		"etat_duree": {"stat": "etat_duree", "etat": "etourdissement", "valeur": 0.2},
		"degats_contre_etat": {"stat": "degats_contre_etat", "etat": "ralenti", "valeur": 0.1},
		"epines_degats": {"stat": "epines_degats", "valeur": 0.1},
		"epines_croissantes": {"stat": "epines_croissantes", "valeur": 0.01, "max": 0.5},
		"epines_premier_coup": {"stat": "epines_premier_coup", "valeur": 0.5},
		"epines_soin": {"stat": "epines_soin", "valeur": 0.1},
		"epines_reduction": {"stat": "epines_reduction", "valeur": 0.1},
		"epines_statut": {"stat": "epines_statut", "statut": "givre", "valeur": 0.2},
		"pv_max_mult": {"stat": "pv_max_mult", "valeur": 0.1},
		"soin_pv_manquants": {"stat": "soin_pv_manquants", "valeur": 0.05},
		"degats_par_pv_max": {"stat": "degats_par_pv_max", "valeur": 0.02},
		"resurrection": {"stat": "resurrection", "valeur": 1},
		"regen_croissante": {"stat": "regen_croissante", "valeur": 0.1, "max": 5.0},
		"soin_periodique": {"stat": "soin_periodique", "tous_les": 5.0, "ratio": 0.1},
		"armure_croissante": {"stat": "armure_croissante", "valeur": 0.1, "max": 5.0},
		"riposte_statut": {"stat": "riposte_statut", "statut": "poison", "valeur": 0.2},
		"mana_max_mult": {"stat": "mana_max_mult", "valeur": 0.1},
		"mana_rupture_etourdit": {"stat": "mana_rupture_etourdit", "rayon": 100.0, "duree": 2.0},
		"degats_tant_que_mana": {"stat": "degats_tant_que_mana", "valeur": 0.1},
		"reduction_tant_que_mana": {"stat": "reduction_tant_que_mana", "valeur": 0.1},
		"revenu_contre_pv": {"stat": "revenu_contre_pv", "pv": 100.0, "or": 20},
		"copie_prochaine_offre": {"stat": "copie_prochaine_offre", "raretes_max": "rare"},
		"aura_mixte": {"stat": "aura_mixte", "rayon": 200.0, "poison": 0.1, "regen": 0.1},
	}


func _effet(kind: String) -> Dictionary:
	var d: Dictionary = _effets_valides()[kind]
	return d.duplicate()


func _statut(kind: String) -> Dictionary:
	var d: Dictionary = _statuts_valides()[kind]
	return d.duplicate()


func _stat(nom: String) -> Dictionary:
	var d: Dictionary = _stats_valides()[nom]
	return d.duplicate()


func _brut() -> Dictionary:
	var brut := AidesPartie.brut()
	brut["unites.json"] = [_unite()]
	return brut


## Données réelles où la première arme porte `effet` parmi ses effets (ou ses statuts).
func _brut_arme(sous_effet: Dictionary, dans_statuts: bool) -> Dictionary:
	var brut := _brut()
	var armes: Array = brut[FICHIER_ARMES]
	var arme: Dictionary = armes[0]
	arme["statuts" if dans_statuts else "effets"] = [sous_effet]
	return brut


func _brut_amelio(effet: Dictionary) -> Dictionary:
	var brut := _brut()
	var amelios: Array = brut[FICHIER_AMELIOS]
	var amelio: Dictionary = amelios[0]
	amelio["effets"] = [effet]
	return brut


func _nomme(messages: PackedStringArray, fichier: String, champ: String) -> bool:
	for m in messages:
		if m.begins_with(fichier + ": ") and champ in m:
			return true
	return false


func _chemin_dans_arme(dans_statuts: bool) -> String:
	return "[0]." + ("statuts" if dans_statuts else "effets") + "[0]."


# --- Familles ------------------------------------------------------------------------------------


func test_chaque_amelioration_a_une_famille_valide() -> void:
	var d := AidesPartie.donnees()
	for id: String in d.ameliorations:
		verifier(d.famille_de(id) in Types.FAMILLES_AMELIORATION, "famille de %s" % id)
	verifier_egal(d.famille_de("n_existe_pas"), "")
	verifier_egal(d.famille_de(d.armes.keys()[0]), "", "une arme n'a pas de famille")


func test_famille_absente_ou_inconnue_est_refusee_en_nommant_le_fichier_et_le_champ() -> void:
	for valeur: Variant in [null, "inconnue", "", 3, "Degats_type"]:
		var brut := _brut()
		var amelios: Array = brut[FICHIER_AMELIOS]
		var amelio: Dictionary = amelios[0]
		if valeur == null:
			amelio.erase("famille")
		else:
			amelio["famille"] = valeur
		var messages := Donnees.valider(brut)
		verifier(
			_nomme(messages, FICHIER_AMELIOS, "[0].famille"), "famille %s : %s" % [valeur, messages]
		)
		attendre_erreur(FICHIER_AMELIOS)
		verifier_nul(Donnees.depuis_brut(brut))


func test_la_famille_de_chaque_amelioration_existante_suit_ses_stats() -> void:
	var d := AidesPartie.donnees()
	var vues := 0
	for id: String in d.ameliorations:
		var amelio: Dictionary = d.ameliorations[id]
		var effets: Array = amelio["effets"]
		var effet: Dictionary = effets[0]
		var stat: String = effet["stat"]
		if not FAMILLE_DE_STAT.has(stat):
			continue
		vues += 1
		verifier_egal(d.famille_de(id), FAMILLE_DE_STAT[stat], "%s (%s)" % [id, stat])
	verifier(vues > 0)


func test_toutes_les_familles_sont_nommees_une_fois() -> void:
	verifier_egal(Types.FAMILLES_AMELIORATION.size(), 15)
	var vus: Dictionary = {}
	for nom: String in Types.FAMILLES_AMELIORATION:
		verifier_faux(vus.has(nom), "doublon %s" % nom)
		vus[nom] = true


# --- Effets et statuts d'arme --------------------------------------------------------------------


func test_les_fiches_valides_des_nouveaux_kinds_sont_acceptees() -> void:
	for kind: String in _effets_valides():
		var brut := _brut_arme(_effet(kind), false)
		verifier_egal(Donnees.valider(brut), PackedStringArray(), "effet %s" % kind)
		var d := Donnees.depuis_brut(brut)
		verifier_non_nul(d, kind)
	for kind: String in _statuts_valides():
		var brut := _brut_arme(_statut(kind), true)
		verifier_egal(Donnees.valider(brut), PackedStringArray(), "statut %s" % kind)
		verifier_non_nul(Donnees.depuis_brut(brut), kind)


func test_chaque_nouveau_kind_d_effet_et_de_statut_est_accepte_et_chaque_champ_invalide_est_refuse(
) -> void:
	var cas: Array[Array] = []
	for kind: String in _effets_valides():
		cas.append([kind, _effet(kind), false])
	for kind: String in _statuts_valides():
		cas.append([kind, _statut(kind), true])
	verifier_egal(cas.size(), 10, "4 effets et 6 statuts")
	for c in cas:
		var kind: String = c[0]
		var fiche: Dictionary = c[1]
		var statuts: bool = c[2]
		var prefixe := _chemin_dans_arme(statuts)
		for champ: String in fiche:
			if champ == "kind":
				continue
			var numerique := typeof(fiche[champ]) != TYPE_STRING
			var mauvaises: Array = ["x", null]
			if numerique:
				mauvaises.append_array([0, -1, NAN, INF])
			for mauvaise: Variant in mauvaises:
				var essai: Dictionary = fiche.duplicate()
				if mauvaise == null:
					essai.erase(champ)
				else:
					essai[champ] = mauvaise
				var messages := Donnees.valider(_brut_arme(essai, statuts))
				verifier(
					_nomme(messages, FICHIER_ARMES, prefixe + champ),
					"%s.%s = %s : %s" % [kind, champ, mauvaise, messages]
				)


func test_les_bornes_des_nouveaux_champs_sont_exactes() -> void:
	# Au-dessus d'une borne haute, ou hors de ]0 ; 1], c'est refusé ; sur la borne, accepté.
	var cas: Array[Array] = [
		["tournant", "branches", 9, 8, false],
		["tournant", "pas_deg", 181.0, 180.0, false],
		["bombe", "delai", 5.5, 5.0, false],
		["malediction_degats", "ratio", 1.5, 1.0, true],
		["malediction_toucher", "ratio", 1.5, 1.0, true],
		["zone_posee", "max_actives", 1.5, 1, false],
		["invocation", "max_actives", 0, 1, false],
	]
	for c in cas:
		var kind: String = c[0]
		var champ: String = c[1]
		var statuts: bool = c[4]
		var base: Dictionary = _statut(kind) if statuts else _effet(kind)
		var trop: Dictionary = base.duplicate()
		trop[champ] = c[2]
		verifier(
			not Donnees.valider(_brut_arme(trop, statuts)).is_empty(),
			"%s.%s = %s" % [kind, champ, c[2]]
		)
		var limite: Dictionary = base.duplicate()
		limite[champ] = c[3]
		verifier_egal(
			Donnees.valider(_brut_arme(limite, statuts)),
			PackedStringArray(),
			"%s.%s = %s" % [kind, champ, c[3]]
		)


func test_les_textes_des_nouveaux_kinds_refusent_une_valeur_inconnue() -> void:
	var vulnerabilite: Dictionary = _statut("vulnerabilite")
	verifier_egal(Donnees.valider(_brut_arme(vulnerabilite, true)), PackedStringArray())
	vulnerabilite["type_degats"] = "perçant"
	verifier_egal(Donnees.valider(_brut_arme(vulnerabilite, true)), PackedStringArray())
	vulnerabilite["type_degats"] = "percant"
	verifier(_nomme(Donnees.valider(_brut_arme(vulnerabilite, true)), FICHIER_ARMES, "type_degats"))
	var tournant: Dictionary = _effet("tournant")
	tournant["sens"] = "gauche"
	verifier(_nomme(Donnees.valider(_brut_arme(tournant, false)), FICHIER_ARMES, "sens"))
	var siphon: Dictionary = _statut("siphon")
	siphon["ressource"] = "or"
	verifier(_nomme(Donnees.valider(_brut_arme(siphon, true)), FICHIER_ARMES, "ressource"))


func test_les_champs_facultatifs_d_arme_sont_valides() -> void:
	var cas: Array[Array] = [
		["degats_par_pv_max", 0.0, -0.1],
		["degats_par_exemplaire", 0.5, -1.0],
		["type_secondaire", "epines", "feu"],
		[
			"degats_par_amelioration",
			{"stat": "cadence", "ratio": 0.2},
			{"stat": "inconnue", "ratio": 0.2}
		],
		[
			"degats_par_amelioration",
			{"stat": "cadence", "ratio": 0.2},
			{"stat": "cadence", "ratio": -1.0}
		],
	]
	for c in cas:
		var champ: String = c[0]
		var bonne := _brut()
		var armes: Array = bonne[FICHIER_ARMES]
		var arme: Dictionary = armes[0]
		arme[champ] = c[1]
		verifier_egal(Donnees.valider(bonne), PackedStringArray(), "%s = %s" % [champ, c[1]])
		var mauvaise := _brut()
		var armes_m: Array = mauvaise[FICHIER_ARMES]
		var arme_m: Dictionary = armes_m[0]
		arme_m[champ] = c[2]
		verifier(
			_nomme(Donnees.valider(mauvaise), FICHIER_ARMES, champ),
			"%s = %s refusé" % [champ, c[2]]
		)


func test_les_champs_facultatifs_sont_normalises_avec_leur_valeur_neutre() -> void:
	var d := AidesPartie.donnees()
	for id: String in d.armes:
		var arme: Dictionary = d.armes[id]
		verifier(arme.has("degats_par_pv_max") and arme.has("degats_par_exemplaire"), id)
		verifier(arme.has("degats_par_amelioration") and arme.has("type_secondaire"), id)


# --- Unités --------------------------------------------------------------------------------------


func test_une_invocation_d_une_unite_inconnue_est_refusee() -> void:
	var fiche: Dictionary = _effet("invocation")
	fiche["unite"] = "fantome"
	var messages := Donnees.valider(_brut_arme(fiche, false))
	verifier(_nomme(messages, FICHIER_ARMES, "unite"), str(messages))
	var sans_unites := _brut_arme(_effet("invocation"), false)
	sans_unites["unites.json"] = []
	verifier(_nomme(Donnees.valider(sans_unites), FICHIER_ARMES, "unite"))


func test_unites_json_refuse_un_modele_un_id_en_double_ou_une_vitesse_nulle() -> void:
	var cas: Array[Array] = [["modele", "dragon"], ["modele", null], ["id", null]]
	for champ: String in ["vitesse", "portee", "cadence", "rayon_garde"]:
		for mauvaise: Variant in [0, -1, NAN, "x", null]:
			cas.append([champ, mauvaise])
	for c in cas:
		var unite := _unite()
		if c[1] == null:
			unite.erase(c[0])
		else:
			unite[c[0]] = c[1]
		var brut := _brut()
		brut["unites.json"] = [unite]
		verifier(
			_nomme(Donnees.valider(brut), "unites.json", String(c[0])), "%s = %s" % [c[0], c[1]]
		)
	var doublon := _brut()
	doublon["unites.json"] = [_unite(), _unite()]
	verifier(_nomme(Donnees.valider(doublon), "unites.json", "id"))
	for modele: String in Donnees.MODELES_UNITES:
		var unite := _unite()
		unite["modele"] = modele
		var brut := _brut()
		brut["unites.json"] = [unite]
		verifier_egal(Donnees.valider(brut), PackedStringArray(), modele)


func test_les_unites_sont_triees_et_indexees() -> void:
	var b := _unite()
	b["id"] = "a0"
	var brut := _brut()
	brut["unites.json"] = [_unite(), b]
	var d := Donnees.depuis_brut(brut)
	verifier_non_nul(d)
	verifier_egal(d.ids_unites, PackedStringArray(["a0", "u1"]))
	verifier_egal(d.unites.size(), 2)
	verifier(Donnees.FICHIERS_LISTE.has("unites.json"))
	# Les données livrées ont au moins une unité par modèle de combat (T9.8).
	var livrees := AidesPartie.donnees()
	var modeles: Array[String] = []
	for id: String in livrees.ids_unites:
		modeles.append(String((livrees.unites[id] as Dictionary)["modele"]))
	verifier_contient(modeles, "guerrier")
	verifier_contient(modeles, "archer")


# --- Stats d'amélioration ------------------------------------------------------------------------


func test_la_table_de_stats_couvre_toutes_les_nouvelles_stats() -> void:
	var attendues: Array[String] = []
	for stat in Donnees.STATS_AMELIORATION:
		if not stat in STATS_ANCIENNES:
			attendues.append(stat)
	var vues: Array[String] = []
	vues.assign(_stats_valides().keys())
	attendues.sort()
	vues.sort()
	verifier_egal(vues, attendues)


func test_chaque_nouvelle_stat_est_acceptee_et_chaque_valeur_ou_parametre_invalide_est_refuse(
) -> void:
	for stat: String in _stats_valides():
		var fiche: Dictionary = _stat(stat)
		verifier_egal(Donnees.valider(_brut_amelio(fiche)), PackedStringArray(), stat)
		verifier_non_nul(Donnees.depuis_brut(_brut_amelio(fiche)), stat)
		for champ: String in fiche:
			if champ == "stat":
				continue
			var numerique := typeof(fiche[champ]) != TYPE_STRING
			var mauvaises: Array = ["x", null]
			if numerique:
				mauvaises.append_array([NAN, INF])
			for mauvaise: Variant in mauvaises:
				var essai: Dictionary = fiche.duplicate()
				if mauvaise == null:
					essai.erase(champ)
				else:
					essai[champ] = mauvaise
				var messages := Donnees.valider(_brut_amelio(essai))
				verifier(
					_nomme(messages, FICHIER_AMELIOS, "[0].effets[0]." + champ),
					"%s.%s = %s : %s" % [stat, champ, mauvaise, messages]
				)


func test_les_bornes_des_stats_d_amelioration_sont_exactes() -> void:
	var cas: Array[Array] = [
		["epines_croissantes", "max", 0.0],
		["regen_croissante", "max", -1.0],
		["armure_croissante", "max", 0.0],
		["resurrection", "valeur", -1],
		["resurrection", "valeur", 0.5],
		["soin_periodique", "ratio", 0.0],
		["soin_periodique", "tous_les", 0.0],
		["revenu_contre_pv", "pv", 0.0],
		["revenu_contre_pv", "or", -1],
		["mana_rupture_etourdit", "duree", 0.0],
		["aura_mixte", "rayon", 0.0],
		["aura_mixte", "poison", -0.1],
		["copie_prochaine_offre", "raretes_max", "legendaire"],
		["degats_classe", "classe", "distance"],
		["etat_degats", "etat", "givre"],
		["etat_duree", "etat", "ralenti"],
		["degats_contre_etat", "etat", "poison"],
		["epines_statut", "statut", "ralenti"],
		["riposte_statut", "statut", "brulure"],
	]
	for c in cas:
		var fiche: Dictionary = _stat(String(c[0]))
		fiche[c[1]] = c[2]
		var messages := Donnees.valider(_brut_amelio(fiche))
		verifier(_nomme(messages, FICHIER_AMELIOS, String(c[1])), "%s.%s = %s" % [c[0], c[1], c[2]])


func test_la_croissance_et_le_bonus_par_arme_commune_sont_valides_et_conserves() -> void:
	for stat: String in ["degats_type", "degats_global"]:
		var fiche: Dictionary = {"stat": stat, "valeur": 0.1, "categorie": "A"}
		if stat == "degats_type":
			fiche["type_degats"] = "tranchant"
		fiche["croissance"] = 0.01
		fiche["croissance_max"] = 0.5
		fiche["par_arme_commune"] = 0.02
		verifier_egal(Donnees.valider(_brut_amelio(fiche)), PackedStringArray(), stat)
		var d := Donnees.depuis_brut(_brut_amelio(fiche))
		verifier_non_nul(d)
		var amelios: Array = _brut_amelio(fiche)[FICHIER_AMELIOS]
		var amelio: Dictionary = d.ameliorations[(amelios[0] as Dictionary)["id"]]
		var effet: Dictionary = (amelio["effets"] as Array)[0]
		verifier_proche(float(effet["croissance"]), 0.01)
		verifier_proche(float(effet["croissance_max"]), 0.5)
		verifier_proche(float(effet["par_arme_commune"]), 0.02)
		var sans_max := fiche.duplicate()
		sans_max.erase("croissance_max")
		verifier(_nomme(Donnees.valider(_brut_amelio(sans_max)), FICHIER_AMELIOS, "croissance_max"))
		var negative := fiche.duplicate()
		negative["par_arme_commune"] = -0.1
		verifier(
			_nomme(Donnees.valider(_brut_amelio(negative)), FICHIER_AMELIOS, "par_arme_commune")
		)


func test_partie_json_refuse_un_plafond_hors_bornes() -> void:
	var cas: Array[Array] = [
		["vulnerabilite", "plafond", 0.0],
		["vulnerabilite", "plafond", 5.5],
		["vulnerabilite", "duree_max", 0.0],
		["malediction", "plafond", 0.0],
		["malediction", "plafond", 1.5],
		["repoussement", "distance_max", 0.0],
		["repoussement", "facteur_boss", 1.5],
		["limites", "allies", 0],
		["limites", "allies", 1.5],
		["limites", "zones", 0],
		["limites", "bombes", 0],
		["armes", "bonus_selon_stat_max", 0.0],
		["ameliorations", "facteur_degats_max", 0.5],
		["ameliorations", "croissance_pas_s", 0.0],
	]
	for c in cas:
		var brut := _brut()
		var partie: Dictionary = brut["partie.json"]
		var bloc: Dictionary = partie[c[0]]
		bloc[c[1]] = c[2]
		var messages := Donnees.valider(brut)
		verifier(_nomme(messages, "partie.json", "%s.%s" % [c[0], c[1]]), "%s : %s" % [c, messages])
	for bloc_manquant: String in [
		"vulnerabilite", "malediction", "repoussement", "limites", "armes", "ameliorations"
	]:
		var brut := _brut()
		var partie: Dictionary = brut["partie.json"]
		partie.erase(bloc_manquant)
		verifier(_nomme(Donnees.valider(brut), "partie.json", bloc_manquant), bloc_manquant)


func test_les_limites_de_la_vue_sont_celles_de_partie_json() -> void:
	var limites: Dictionary = AidesPartie.donnees().partie["limites"]
	verifier_egal(VueArene.ALLIES_MAX, int(limites["allies"]))
	verifier_egal(VueArene.ZONES_MAX, int(limites["zones"]))
	verifier_egal(VueArene.BOMBES_MAX, int(limites["bombes"]))


# --- Genres, statuts d'événement et bits ----------------------------------------------------------


func test_les_genres_et_les_statuts_d_evenement_tiennent_sur_quatre_bits() -> void:
	verifier(VueArene.GENRES_ARME.size() <= 16)
	verifier(VueArene.STATUTS_ARME.size() <= 16)
	var genres_d_avant: Array[String] = [
		"", "cible_unique", "zone", "rebond", "aura", "onde", "barrage", "piege", "mine"
	]
	var statuts_d_avant: Array[String] = [
		"", "poison", "brulure", "givre", "etourdissement", "vol_de_vie"
	]
	for i in genres_d_avant.size():
		verifier_egal(VueArene.GENRES_ARME[i], genres_d_avant[i], "l'ordre ne bouge pas")
	for i in statuts_d_avant.size():
		verifier_egal(VueArene.STATUTS_ARME[i], statuts_d_avant[i], "l'ordre ne bouge pas")
	for nom: String in ["tournant", "zone_posee", "bombe", "invocation"]:
		var index := VueArene.genre_depuis_nom(nom)
		verifier(index >= genres_d_avant.size(), "%s ajouté à la fin" % nom)
		verifier_egal(VueArene.GENRES_ARME[index], nom)
	for nom: String in [
		"vulnerabilite",
		"malediction_degats",
		"malediction_toucher",
		"repoussement",
		"siphon",
		"mana_au_coup",
	]:
		var index := VueArene.statut_depuis_nom(nom)
		verifier(index >= statuts_d_avant.size(), "%s ajouté à la fin" % nom)
		verifier_egal(VueArene.STATUTS_ARME[index], nom)


func test_chaque_kind_des_donnees_a_son_genre_et_son_statut_d_evenement() -> void:
	for kind: String in Donnees._kinds_effets():
		verifier(kind in VueArene.GENRES_ARME, "genre %s" % kind)
	for kind: String in Donnees._kinds_statuts():
		verifier(kind in VueArene.STATUTS_ARME, "statut %s" % kind)


func test_les_bits_de_statut_sont_distincts_et_tiennent_dans_un_octet() -> void:
	var bits: Array[int] = [
		Types.STATUT_GELE,
		Types.STATUT_RALENTI,
		Types.STATUT_EMPOISONNE,
		Types.STATUT_BRULE,
		Types.STATUT_ETOURDI,
		Types.STATUT_VULNERABLE,
		Types.STATUT_MAUDIT,
		Types.STATUT_SIPHONNE,
	]
	verifier_egal(bits, [1, 2, 4, 8, 16, 32, 64, 128] as Array[int])
	var union := 0
	for bit in bits:
		verifier_egal(union & bit, 0, "bit %d déjà pris" % bit)
		union |= bit
	verifier_egal(union, 255)


# --- Vue d'arène ---------------------------------------------------------------------------------


func _vue_avec(allies: int, zones: int, bombes: int) -> VueArene:
	var vue := VueArene.new()
	for i in allies:
		vue.allies.append({"id": 100 + i, "pos": Vector2(i, 2.0 * i), "unite": i % 3})
	for i in zones:
		vue.zones.append({"pos": Vector2(i, 1.0), "rayon": 90.0 + i, "reste": 2.5 + i, "arme": i})
	for i in bombes:
		vue.bombes.append({"pos": Vector2(3.0, i), "rayon": 70.0, "reste": 1.0 + i})
	return vue


func test_vue_arene_aller_retour_avec_allies_zones_et_bombes() -> void:
	for n in 4:
		var vue := _vue_avec(n, n, n)
		var relue := VueArene.from_dict(vue.to_dict())
		verifier_non_nul(relue, "n = %d" % n)
		if relue == null:
			continue
		verifier_egal(relue.allies, vue.allies)
		verifier_egal(relue.zones, vue.zones)
		verifier_egal(relue.bombes, vue.bombes)
		# La copie ne partage rien avec la source.
		if n > 0:
			(relue.allies[0] as Dictionary)["id"] = -1
			verifier_different((vue.allies[0] as Dictionary)["id"], -1)


func test_vue_arene_refuse_des_allies_zones_et_bombes_malformes() -> void:
	var sans_pos := _vue_avec(1, 0, 0).to_dict()
	((sans_pos["allies"] as Array)[0] as Dictionary).erase("pos")
	verifier_nul(VueArene.from_dict(sans_pos), "allié sans position")
	for mauvais: Variant in [-1.0, NAN, INF]:
		var zone := _vue_avec(0, 1, 0).to_dict()
		((zone["zones"] as Array)[0] as Dictionary)["reste"] = mauvais
		verifier_nul(VueArene.from_dict(zone), "zone au reste %s" % mauvais)
		var bombe := _vue_avec(0, 0, 1).to_dict()
		((bombe["bombes"] as Array)[0] as Dictionary)["reste"] = mauvais
		verifier_nul(VueArene.from_dict(bombe), "bombe au reste %s" % mauvais)
	var rayon_fou := _vue_avec(0, 1, 0).to_dict()
	((rayon_fou["zones"] as Array)[0] as Dictionary)["rayon"] = NAN
	verifier_nul(VueArene.from_dict(rayon_fou), "rayon non fini")
	var position_folle := _vue_avec(1, 0, 0).to_dict()
	((position_folle["allies"] as Array)[0] as Dictionary)["pos"] = Vector2(INF, 0.0)
	verifier_nul(VueArene.from_dict(position_folle), "position non finie")
	var type_faux := _vue_avec(1, 0, 0).to_dict()
	((type_faux["allies"] as Array)[0] as Dictionary)["unite"] = 1.5
	verifier_nul(VueArene.from_dict(type_faux), "unité flottante")
	for cle: String in ["allies", "zones", "bombes"]:
		var absente := _vue_avec(0, 0, 0).to_dict()
		absente.erase(cle)
		verifier_nul(VueArene.from_dict(absente), "%s absent" % cle)


func test_vue_arene_accepte_les_plafonds_et_refuse_un_de_plus() -> void:
	verifier_non_nul(VueArene.from_dict(_vue_avec(VueArene.ALLIES_MAX, 0, 0).to_dict()))
	verifier_non_nul(VueArene.from_dict(_vue_avec(0, VueArene.ZONES_MAX, 0).to_dict()))
	verifier_non_nul(VueArene.from_dict(_vue_avec(0, 0, VueArene.BOMBES_MAX).to_dict()))
	verifier_nul(VueArene.from_dict(_vue_avec(VueArene.ALLIES_MAX + 1, 0, 0).to_dict()))
	verifier_nul(VueArene.from_dict(_vue_avec(0, VueArene.ZONES_MAX + 1, 0).to_dict()))
	verifier_nul(VueArene.from_dict(_vue_avec(0, 0, VueArene.BOMBES_MAX + 1).to_dict()))


# --- StatsTour et Inventaire ---------------------------------------------------------------------


func _proprietes_de_stats() -> Array[String]:
	var noms: Array[String] = []
	for p: Dictionary in StatsTour.new().get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			noms.append(String(p["name"]))
	return noms


func test_les_stats_neutres_au_depart() -> void:
	var s := StatsTour.new()
	for nom: String in ["degats_classe", "etat_degats", "etat_duree", "degats_contre_etat"]:
		verifier((s.get(nom) as Dictionary).is_empty(), nom)
	verifier((s.epines_statut as Dictionary).is_empty())
	verifier((s.riposte_statut as Dictionary).is_empty())
	for nom: String in [
		"epines_degats",
		"epines_croissantes",
		"epines_croissantes_max",
		"epines_premier_coup",
		"epines_soin",
		"epines_reduction",
		"soin_pv_manquants",
		"degats_par_pv_max",
		"regen_croissante",
		"regen_croissante_max",
		"armure_croissante",
		"armure_croissante_max",
		"degats_tant_que_mana",
		"reduction_tant_que_mana",
	]:
		verifier_proche(float(s.get(nom)), 0.0, 0.000001, nom)
	verifier_proche(s.pv_max_mult, 1.0)
	verifier_proche(s.mana_max_mult, 1.0)
	verifier_egal(s.resurrection, 0)
	verifier_egal(s.copie_prochaine_offre, -1)
	verifier_proche(float(s.soin_periodique["ratio"]), 0.0)
	verifier_proche(float(s.mana_rupture_etourdit["rayon"]), 0.0)
	verifier_egal(int(s.revenu_contre_pv["or"]), 0)
	verifier_proche(float(s.aura_mixte["rayon"]), 0.0)
	verifier_proche(s.facteur_epines(100.0), 1.0)
	var autre := StatsTour.new()
	autre.degats_classe["onde"] = 1.0
	autre.soin_periodique["ratio"] = 1.0
	verifier(
		(s.degats_classe as Dictionary).is_empty(),
		"les instances ne partagent pas leurs dictionnaires"
	)
	verifier_proche(float(s.soin_periodique["ratio"]), 0.0)


func test_l_inventaire_accumule_chaque_nouvelle_stat() -> void:
	var avant := StatsTour.new()
	var proprietes := _proprietes_de_stats()
	for stat: String in _stats_valides():
		var fiche: Dictionary = _stat(stat)
		var brut := _brut_amelio(fiche)
		var d := Donnees.depuis_brut(brut)
		verifier_non_nul(d, stat)
		if d == null:
			continue
		var inventaire := Inventaire.new(d)
		var amelios: Array = brut[FICHIER_AMELIOS]
		verifier_egal(
			inventaire.ajouter(String((amelios[0] as Dictionary)["id"])), Types.Resultat.OK
		)
		var apres := inventaire.stats()
		var changes: Array[String] = []
		for nom in proprietes:
			if nom == "pas_croissance_s":
				continue
			if apres.get(nom) != avant.get(nom):
				changes.append(nom)
		verifier(
			stat in changes, "%s doit changer le champ de même nom (changés : %s)" % [stat, changes]
		)
		for nom in changes:
			verifier(
				nom == stat or nom == stat + "_max", "%s : %s ne devait pas changer" % [stat, nom]
			)


func test_deux_exemplaires_doublent_la_valeur_et_le_maximum() -> void:
	var brut := _brut_amelio(_stat("epines_croissantes"))
	var d := Donnees.depuis_brut(brut)
	var inventaire := Inventaire.new(d)
	var amelios: Array = brut[FICHIER_AMELIOS]
	var id := String((amelios[0] as Dictionary)["id"])
	inventaire.ajouter(id)
	inventaire.ajouter(id)
	var s := inventaire.stats()
	verifier_proche(s.epines_croissantes, 0.02)
	verifier_proche(s.epines_croissantes_max, 1.0)


func test_facteur_epines_croit_par_tranches_et_reste_borne() -> void:
	var s := StatsTour.new()
	s.pas_croissance_s = 30.0
	s.epines_degats = 0.25
	s.epines_croissantes = 0.1
	s.epines_croissantes_max = 0.35
	verifier_proche(s.facteur_epines(0.0), 1.25)
	verifier_proche(s.facteur_epines(29.9), 1.25)
	verifier_proche(s.facteur_epines(30.0), 1.35)
	verifier_proche(s.facteur_epines(90.0), 1.55)
	verifier_proche(s.facteur_epines(1.0e9), 1.6, 0.000001, "borné par le maximum")
	verifier_proche(s.facteur_epines(-5.0), 1.25, 0.000001, "un temps négatif ne retire rien")


func test_le_pas_de_croissance_vient_de_partie_json() -> void:
	var brut := _brut()
	var partie: Dictionary = brut["partie.json"]
	(partie["ameliorations"] as Dictionary)["croissance_pas_s"] = 45.0
	var d := Donnees.depuis_brut(brut)
	verifier_proche(Inventaire.new(d).stats().pas_croissance_s, 45.0)
