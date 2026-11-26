extends CasDeTest
## Ce que la joueuse doit voir d'un tir : le genre de l'arme et son statut voyagent avec chaque
## événement, de la simulation jusqu'aux effets 2D, en solo comme en réseau. Sans eux, les mines,
## les pièges et la brûlure restaient invisibles dans une vraie partie.

const DT := 0.05
const PV := 5000.0
const GRAINE := 20261125

var _d: Donnees
var _catalogue: PackedStringArray
var _effets: Effets = null


func avant_chaque() -> void:
	_d = Donnees.charger()
	_catalogue = _d.ids_catalogue


func apres_chaque() -> void:
	if _effets != null and is_instance_valid(_effets):
		if _effets.get_parent() != null:
			_effets.get_parent().remove_child(_effets)
		_effets.free()
	_effets = null


# --- Aides -------------------------------------------------------------------------------------


## Joue 80 pas d'une arme réelle contre des ennemis immobiles au sol, proches et nombreux.
func _evenements_de(id: String) -> Array[Dictionary]:
	var ennemis := Ennemis.new(_d)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var arme := ArmeEquipee.new((_d.armes[id] as Dictionary).duplicate(true))
	var stats := StatsTour.new()
	var tous: Array[Dictionary] = []
	for k: int in 12:
		ennemis.ajouter(0, Vector2(60.0 + 20.0 * k, 10.0 * k), PV, 0.0, 0.0, 40.0, 1.0, 1, 4)
	for _pas: int in 80:
		var bilan := Tir.Bilan.new()
		Tir.avancer_arme(arme, DT, stats, ennemis, Vector2.ZERO, _d, rng, 1.0, bilan)
		tous.append_array(bilan.evenements)
	return tous


func _statut_attendu(def: Dictionary) -> int:
	var statuts: Array = def["statuts"]
	if statuts.is_empty():
		return 0
	var ligne: Dictionary = statuts[0]
	return VueArene.STATUTS_ARME.find(String(ligne["kind"]))


func _vue_avec_evenement(evt: Dictionary) -> VueArene:
	var v := VueArene.new()
	v.evenements = [evt] as Array[Dictionary]
	return v


func _evt(extra: Dictionary = {}) -> Dictionary:
	var e := {
		"k": "tir",
		"t": 1,
		"de": Vector2.ZERO,
		"vers": Vector2(5, 5),
		"type_degats": 1,
		"rayon": 0.0
	}
	e.merge(extra, true)
	return e


# --- Simulation --------------------------------------------------------------------------------


func test_chaque_arme_envoie_son_genre_et_son_statut() -> void:
	verifier(_d.armes.size() >= 25, "le catalogue d'armes est chargé")
	for id: String in _d.armes:
		var def: Dictionary = _d.armes[id]
		var effets: Array = def["effets"]
		var ligne: Dictionary = effets[0]
		var genre := VueArene.GENRES_ARME.find(String(ligne["kind"]))
		var statut := _statut_attendu(def)
		verifier(genre > 0, "%s : genre connu de la liste fixe" % id)
		var evenements := _evenements_de(id)
		verifier(not evenements.is_empty(), "%s : au moins un événement" % id)
		for ev: Dictionary in evenements:
			verifier_egal(ev.get("genre"), genre, "%s : genre de l'événement" % id)
			verifier_egal(ev.get("statut"), statut, "%s : statut de l'événement" % id)


func test_les_genres_et_statuts_couvrent_toutes_les_donnees() -> void:
	for id: String in _d.armes:
		var def: Dictionary = _d.armes[id]
		var effets: Array = def["effets"]
		for brut: Variant in effets:
			var ligne: Dictionary = brut
			verifier(VueArene.GENRES_ARME.has(String(ligne["kind"])), "%s : genre" % id)
		var statuts: Array = def["statuts"]
		for brut: Variant in statuts:
			var ligne: Dictionary = brut
			verifier(VueArene.STATUTS_ARME.has(String(ligne["kind"])), "%s : statut" % id)


# --- Vue d'arène -------------------------------------------------------------------------------


func test_la_vue_accepte_les_champs_sur_toute_la_plage() -> void:
	for g: int in VueArene.GENRES_ARME.size():
		for s: int in VueArene.STATUTS_ARME.size():
			var v := _vue_avec_evenement(_evt({"genre": g, "statut": s}))
			var relue := VueArene.from_dict(v.to_dict())
			verifier_non_nul(relue, "genre %d statut %d" % [g, s])
			if relue != null:
				verifier_egal(relue.evenements[0]["genre"], g)
				verifier_egal(relue.evenements[0]["statut"], s)


func test_la_vue_accepte_un_evenement_sans_genre_ni_statut() -> void:
	# Une mort n'a pas d'arme : les champs sont facultatifs.
	var relue := VueArene.from_dict(_vue_avec_evenement(_evt()).to_dict())
	verifier_non_nul(relue, "événement sans genre")


func test_la_vue_refuse_un_genre_ou_un_statut_invalide() -> void:
	var mauvais: Array[Dictionary] = [
		{"genre": -1},
		{"genre": VueArene.GENRES_ARME.size()},
		{"genre": "zone"},
		{"genre": 1.0},
		{"statut": -1},
		{"statut": VueArene.STATUTS_ARME.size()},
		{"statut": "givre"},
		{"statut": null},
	]
	for extra: Dictionary in mauvais:
		var v := _vue_avec_evenement(_evt(extra))
		verifier_nul(VueArene.from_dict(v.to_dict()), "refusé : %s" % str(extra))


func test_la_vue_refuse_un_champ_inconnu_dans_un_evenement() -> void:
	var v := _vue_avec_evenement(_evt({"intrus": 1}))
	verifier_nul(VueArene.from_dict(v.to_dict()), "champ inconnu refusé")


# --- Protocole ---------------------------------------------------------------------------------


func _vue_reseau(g: int, s: int) -> VueArene:
	var v := VueArene.new()
	v.phase = Types.Phase.MANCHE
	v.evenements = [_evt({"genre": g, "statut": s})] as Array[Dictionary]
	return v


func test_le_protocole_transporte_chaque_genre_et_chaque_statut() -> void:
	for g: int in VueArene.GENRES_ARME.size():
		for s: int in VueArene.STATUTS_ARME.size():
			var b := Protocole.encoder_etat_arene(_vue_reseau(g, s), _catalogue)
			var relue := Protocole.decoder_etat_arene(b, _catalogue)
			verifier_non_nul(relue, "genre %d statut %d décodé" % [g, s])
			if relue != null:
				verifier_egal(relue.evenements[0]["genre"], g, "genre %d" % g)
				verifier_egal(relue.evenements[0]["statut"], s, "statut %d" % s)
				verifier_egal(relue.evenements[0]["type_degats"], 1)


func test_le_protocole_refuse_un_genre_ou_un_statut_hors_bornes() -> void:
	var b := Protocole.encoder_etat_arene(_vue_reseau(1, 1), _catalogue)
	# Octet de genre et de statut de l'événement unique : il précède l'index d'arme (2), puis
	# eliminations (2), degats (4) et manche (2).
	var pos := b.size() - 8 - 2 - 1
	var hors: Array[int] = []
	for g: int in range(VueArene.GENRES_ARME.size(), 16):
		hors.append(g | (1 << 4))
	for s: int in range(VueArene.STATUTS_ARME.size(), 16):
		hors.append(1 | (s << 4))
	hors.append(255)
	for octet: int in hors:
		var c := b.duplicate()
		c[pos] = octet
		verifier_nul(Protocole.decoder_etat_arene(c, _catalogue), "octet %d refusé" % octet)


func test_le_protocole_ramene_un_champ_invalide_dans_les_bornes_a_l_envoi() -> void:
	# L'émetteur ne peut pas produire un octet que le récepteur refuserait.
	var v := _vue_reseau(1, 1)
	v.evenements[0]["genre"] = 99
	v.evenements[0]["statut"] = -4
	var relue := Protocole.decoder_etat_arene(
		Protocole.encoder_etat_arene(v, _catalogue), _catalogue
	)
	verifier_non_nul(relue, "paquet toujours valide")


func test_la_version_du_protocole_a_change_et_un_ancien_client_est_refuse() -> void:
	verifier(Protocole.VERSION >= 3, "le format a changé : version 3 au moins")
	var b := Protocole.encoder_bonjour("Phil", 1)
	b[1] = 2
	verifier_egal(Protocole.version_bonjour(b), 2)
	verifier(Protocole.decoder_bonjour(b).is_empty(), "version 2 refusée")


func test_un_octet_de_plus_par_evenement() -> void:
	var un := Protocole.encoder_etat_arene(_vue_reseau(1, 1), _catalogue)
	var v := _vue_reseau(1, 1)
	v.evenements.append(v.evenements[0].duplicate())
	var deux := Protocole.encoder_etat_arene(v, _catalogue)
	verifier_egal(deux.size() - un.size(), 14, "14 octets par événement (12 en version 4)")


# --- Effets 2D ---------------------------------------------------------------------------------


func _effets_neufs() -> Effets:
	_effets = Effets.new()
	arbre.root.add_child(_effets)
	return _effets


func test_dans_une_partie_simulee_les_mines_les_pieges_et_la_brulure_apparaissent() -> void:
	var attendu: Dictionary = {
		"petard_de_rempart": "mine",
		"mine_de_forge": "mine",
		"chausse_trape": "piege",
		"sablier_fele": "piege",
		"nova_d_ambre": "feu",
		"canon_de_cloche": "feu",
		"horloge_folle": "feu",
	}
	for id: String in attendu:
		var effets := _effets_neufs()
		# Les événements passent par la vue puis par le protocole, comme en réseau.
		var v := VueArene.new()
		v.phase = Types.Phase.MANCHE
		var evts: Array[Dictionary] = []
		for ev: Dictionary in _evenements_de(id):
			evts.append(ev)
		v.evenements = evts
		var relue := Protocole.decoder_etat_arene(
			Protocole.encoder_etat_arene(v, _catalogue), _catalogue
		)
		verifier_non_nul(relue, id)
		# Une mine ou un piège disparaît à son explosion : on cherche sa forme après chaque
		# événement, pas seulement à la fin.
		var vues: PackedStringArray = PackedStringArray()
		if relue != null:
			for ev: Dictionary in relue.evenements:
				effets.ajouter(ev)
				vues.append_array(effets.formes_vivantes())
		verifier(
			vues.has(String(attendu[id])), "%s : %s visible (%s)" % [id, attendu[id], str(vues)]
		)
		apres_chaque()


func test_les_effets_lisent_le_statut_de_chaque_valeur() -> void:
	var formes: Dictionary = {
		"poison": "bulles", "givre": "flocon", "etourdissement": "croix_plus", "brulure": "feu"
	}
	for nom: String in formes:
		var effets := _effets_neufs()
		var s := VueArene.STATUTS_ARME.find(nom)
		effets.ajouter(_evt({"k": "impact", "statut": s, "genre": 1}))
		verifier(effets.formes_vivantes().has(String(formes[nom])), "statut %s" % nom)
		apres_chaque()


# --- L'arme dans l'événement (lot 8) ------------------------------------------------------------


func test_chaque_tir_et_chaque_impact_portent_l_index_de_leur_arme() -> void:
	for id: String in _d.armes:
		var attendu := _catalogue.find(id)
		verifier(attendu >= 0, "%s est dans le catalogue" % id)
		var vus := 0
		for e: Dictionary in _evenements_de(id):
			var genre := String(e["k"])
			if genre != "tir" and genre != "impact":
				continue
			vus += 1
			verifier(e.has("arme"), "%s : un %s sans arme" % [id, genre])
			verifier_egal(e.get("arme"), attendu, "%s : index d'arme" % id)
		verifier(vus > 0, "%s tire au moins une fois" % id)


func test_une_mort_n_a_pas_de_cle_arme() -> void:
	var a := Arene.new(_d, GRAINE)
	a.inventaire.ajouter("de_pipe")
	a.synchroniser()
	a.demarrer_manche(1, 0, {"pv": 1.0, "degats": 1.0, "vitesse": 1.0, "resistance_controle": 1.0})
	var morts := 0
	var tirs := 0
	for _pas: int in 2400:
		a.avancer(DT)
		for e: Dictionary in a.vue(Types.Phase.MANCHE, 1.0, -1, false).evenements:
			if e["k"] == "mort":
				morts += 1
				verifier_faux(e.has("arme"), "une mort n'a pas d'arme")
			elif e["k"] == "tir":
				tirs += 1
				verifier(e.has("arme"))
		if morts > 0 and tirs > 0:
			break
	verifier(morts > 0 and tirs > 0, "une mort et un tir observés (%d, %d)" % [morts, tirs])
