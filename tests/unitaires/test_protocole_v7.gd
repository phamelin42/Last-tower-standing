extends CasDeTest
## Protocole version 7 : alliés, zones posées et bombes dans l'état d'arène. Tout octet vient d'un
## tiers : les paquets forgés rendent `null` ou `{}`, jamais une exception.

const GRAINE := 20261126
const NB_UNITES := 2
## Octets après la dernière liste d'événements, listes vides : trois compteurs, éliminations (u16),
## dégâts (f32), manche maximale (u16).
const OCTETS_QUEUE := 11

var _catalogue: PackedStringArray


func avant_chaque() -> void:
	_catalogue = PackedStringArray()
	for i: int in 300:
		_catalogue.append("objet_%03d" % i)


func _vue(allies: int = 0, zones: int = 0, bombes: int = 0) -> VueArene:
	var v := VueArene.new()
	v.tick = 99
	v.manche = 7
	v.phase = Types.Phase.MANCHE
	v.tour_pv = 800.0
	v.tour_pv_max = 1000.0
	for i: int in allies:
		v.allies.append(
			{"id": i, "pos": Vector2(10.5 * i - 300.0, 7.25 * i), "unite": i % NB_UNITES}
		)
	for i: int in zones:
		v.zones.append(
			{
				"pos": Vector2(-12.0 * i, 40.0 + i),
				"rayon": 60.0 + 4.0 * i,
				"reste": 0.5 + i,
				"arme": 10 + i
			}
		)
	for i: int in bombes:
		v.bombes.append({"pos": Vector2(8.0 * i, -33.0), "rayon": 72.0, "reste": 0.1 * (i + 1)})
	return v


func _evenement(genre: int = 0, statut: int = 0) -> Dictionary:
	return {
		"k": "impact",
		"t": 99,
		"de": Vector2(10, -20),
		"vers": Vector2(300, 40),
		"type_degats": 2,
		"rayon": 16.0,
		"genre": genre,
		"statut": statut,
	}


func _encoder(v: VueArene) -> PackedByteArray:
	return Protocole.encoder_etat_arene(v, _catalogue, NB_UNITES)


func _decoder(b: PackedByteArray) -> VueArene:
	return Protocole.decoder_etat_arene(b, _catalogue, NB_UNITES)


func test_la_version_a_ete_incrementee_et_toutes_les_precedentes_sont_refusees() -> void:
	verifier(Protocole.VERSION >= 7, "version %d" % Protocole.VERSION)
	for ancienne: int in range(1, Protocole.VERSION):
		var b := Protocole.encoder_bonjour("Phil", 42)
		b[1] = ancienne
		verifier_egal(Protocole.decoder_bonjour(b), {}, "version %d" % ancienne)
		verifier_egal(Protocole.version_bonjour(b), ancienne)
		var motif := Protocole.motif_version(ancienne)
		verifier(motif.contains(str(ancienne)) and motif.contains(str(Protocole.VERSION)), motif)
	var b_courante := Protocole.encoder_bonjour("Phil", 42)
	verifier_non_nul(Protocole.decoder_bonjour(b_courante))


func test_les_plafonds_du_protocole_sont_ceux_de_partie_json() -> void:
	var limites: Dictionary = AidesPartie.donnees().partie["limites"]
	verifier_egal(Protocole.MAX_ALLIES, int(limites["allies"]))
	verifier_egal(Protocole.MAX_ZONES, int(limites["zones"]))
	verifier_egal(Protocole.MAX_BOMBES, int(limites["bombes"]))


func test_un_etat_vide_a_exactement_la_taille_fixe_et_une_queue_de_onze_octets() -> void:
	var b := _encoder(_vue())
	verifier_egal(b.size(), Protocole.TAILLE_FIXE)
	verifier_egal(Protocole.TAILLE_FIXE, 79)
	verifier_egal(b[b.size() - OCTETS_QUEUE], 0, "aucun allié")
	verifier_egal(b[b.size() - OCTETS_QUEUE + 1], 0, "aucune zone")
	verifier_egal(b[b.size() - OCTETS_QUEUE + 2], 0, "aucune bombe")


func test_allies_zones_et_bombes_traversent_le_protocole() -> void:
	var nombres: Array[int] = [0, 1, 2, 3, Protocole.MAX_ZONES]
	for n: int in nombres:
		var allies := mini(n, Protocole.MAX_ALLIES)
		var v := _vue(allies, n, n)
		var b := _encoder(v)
		verifier_faux(b.is_empty(), "n = %d" % n)
		verifier_egal(
			b.size(),
			Protocole.TAILLE_FIXE + 5 * allies + 7 * n + 6 * n,
			"5, 7 et 6 octets par entrée (n = %d)" % n
		)
		var d := _decoder(b)
		verifier_non_nul(d, "n = %d" % n)
		if d == null:
			continue
		verifier_egal(d.allies.size(), allies)
		for i: int in allies:
			var a: Dictionary = d.allies[i]
			verifier_egal(a["id"], i, "le décodeur numérote les alliés par rang")
			verifier_egal(a["unite"], i % NB_UNITES)
			verifier(
				(
					(a["pos"] as Vector2).distance_to(v.allies[i]["pos"])
					<= 2.0 * Protocole.ERREUR_POS_MAX
				)
			)
		verifier_egal(d.zones.size(), n)
		for i: int in n:
			var z: Dictionary = d.zones[i]
			verifier_egal(z["arme"], 10 + i)
			verifier_proche(
				float(z["rayon"]), float(v.zones[i]["rayon"]), 2.0, "rayon par pas de 4"
			)
			verifier_proche(
				float(z["reste"]), float(v.zones[i]["reste"]), 0.125, "reste au quart de s"
			)
			verifier(
				(
					(z["pos"] as Vector2).distance_to(v.zones[i]["pos"])
					<= 2.0 * Protocole.ERREUR_POS_MAX
				)
			)
		verifier_egal(d.bombes.size(), n)
		for i: int in n:
			var bm: Dictionary = d.bombes[i]
			verifier_proche(float(bm["rayon"]), 72.0, 2.0)
			verifier_proche(float(bm["reste"]), float(v.bombes[i]["reste"]), 0.125)
		verifier_non_nul(VueArene.from_dict(d.to_dict()), "la vue décodée est valide")


func test_la_position_d_un_allie_garde_l_erreur_de_quantification_du_protocole() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	for _k: int in 200:
		var v := _vue()
		var voulue := Vector2(rng.randf_range(-1300.0, 1300.0), rng.randf_range(-1300.0, 1300.0))
		v.allies.append({"id": 0, "pos": voulue, "unite": 1})
		var d := _decoder(_encoder(v))
		verifier_non_nul(d)
		if d != null:
			var ecart := (d.allies[0]["pos"] as Vector2) - voulue
			verifier(absf(ecart.x) <= Protocole.ERREUR_POS_MAX + 0.0001, "x : %f" % ecart.x)
			verifier(absf(ecart.y) <= Protocole.ERREUR_POS_MAX + 0.0001, "y : %f" % ecart.y)


func test_plus_que_la_limite_est_refuse_a_l_encodage_et_au_decodage() -> void:
	verifier(_encoder(_vue(Protocole.MAX_ALLIES + 1)).is_empty(), "65 alliés")
	verifier(_encoder(_vue(0, Protocole.MAX_ZONES + 1)).is_empty(), "33 zones")
	verifier(_encoder(_vue(0, 0, Protocole.MAX_BOMBES + 1)).is_empty(), "33 bombes")
	# Au décodage : un compteur forgé au-delà du plafond, avec exactement les octets qu'il annonce
	# (sinon le paquet serait refusé pour une autre raison).
	var base := _encoder(_vue())
	var debut := base.slice(0, base.size() - OCTETS_QUEUE)
	var plafonds: Array[int] = [Protocole.MAX_ALLIES, Protocole.MAX_ZONES, Protocole.MAX_BOMBES]
	var octets_par_entree: Array[int] = [5, 7, 6]
	for compteur: int in 3:
		var c := plafonds[compteur] + 1
		var forge := debut.duplicate()
		for liste: int in 3:
			if liste == compteur:
				forge.append(c)
				for _k: int in octets_par_entree[liste] * c:
					forge.append(0)
			else:
				forge.append(0)
		for _k: int in 8:
			forge.append(0)
		verifier_nul(_decoder(forge), "compteur %d forgé à %d" % [compteur, c])
		# Le même paquet avec un compteur dans la limite est valide : le test ne passe pas à côté.
		var valide := debut.duplicate()
		for liste: int in 3:
			if liste == compteur:
				valide.append(plafonds[liste])
				for _k: int in octets_par_entree[liste] * plafonds[liste]:
					valide.append(0)
			else:
				valide.append(0)
		for _k: int in 8:
			valide.append(0)
		verifier_non_nul(_decoder(valide), "compteur %d à la limite" % compteur)


func test_un_index_d_unite_ou_d_arme_hors_plage_est_refuse() -> void:
	var allie := _vue(1)
	allie.allies[0]["unite"] = NB_UNITES
	verifier(_encoder(allie).is_empty(), "unité hors catalogue à l'envoi")
	allie.allies[0]["unite"] = 256
	verifier(Protocole.encoder_etat_arene(allie, _catalogue).is_empty(), "unité > 255")
	var zone := _vue(0, 1)
	zone.zones[0]["arme"] = _catalogue.size()
	verifier(_encoder(zone).is_empty(), "arme hors catalogue à l'envoi")
	zone.zones[0]["arme"] = -1
	verifier(_encoder(zone).is_empty())
	# Au décodage : un index d'unité forgé.
	var b := _encoder(_vue(1))
	var ou := b.size() - 11  # l'index d'unité du seul allié, avant bombes et queue
	var forge := b.duplicate()
	verifier_egal(forge[ou], 0)
	forge[ou] = NB_UNITES
	verifier_nul(_decoder(forge), "unité forgée hors catalogue")
	verifier_non_nul(
		Protocole.decoder_etat_arene(forge, _catalogue),
		"sans le nombre d'unités, seul le plafond d'octet vaut"
	)
	# Une arme de zone hors du catalogue du récepteur (ici de 5 objets) : paquet refusé.
	var petit := PackedStringArray(Array(_catalogue.slice(0, 5)))
	var bz := _encoder(_vue(0, 1))
	verifier_nul(Protocole.decoder_etat_arene(bz, petit, NB_UNITES), "arme de zone hors catalogue")
	verifier_non_nul(_decoder(bz), "et dans le catalogue complet il passe")


func test_une_zone_ou_une_bombe_aux_nombres_non_finis_ne_s_encode_pas() -> void:
	for cle: String in ["rayon", "reste"]:
		for mauvais: float in [NAN, INF, -INF, -1.0]:
			var z := _vue(0, 1)
			z.zones[0][cle] = mauvais
			verifier(_encoder(z).is_empty(), "zone %s = %s" % [cle, mauvais])
			var bm := _vue(0, 0, 1)
			bm.bombes[0][cle] = mauvais
			verifier(_encoder(bm).is_empty(), "bombe %s = %s" % [cle, mauvais])
	var a := _vue(1)
	a.allies[0]["pos"] = Vector2(NAN, 0.0)
	verifier(_encoder(a).is_empty(), "allié à la position non finie")


func test_chaque_genre_et_chaque_statut_d_evenement_traverse_le_protocole() -> void:
	for genre: int in VueArene.GENRES_ARME.size():
		for statut: int in VueArene.STATUTS_ARME.size():
			var v := _vue()
			v.evenements = [_evenement(genre, statut)]
			var d := _decoder(_encoder(v))
			verifier_non_nul(d, "genre %d statut %d" % [genre, statut])
			if d != null:
				verifier_egal(int(d.evenements[0]["genre"]), genre)
				verifier_egal(int(d.evenements[0]["statut"]), statut)
	verifier(VueArene.GENRES_ARME.size() <= 16 and VueArene.STATUTS_ARME.size() <= 16)


func test_l_etat_d_arene_regardee_porte_aussi_allies_zones_et_bombes() -> void:
	var v := _vue(3, 2, 1)
	var b := Protocole.encoder_etat_arene_regardee(123456789, v, _catalogue, NB_UNITES)
	verifier_faux(b.is_empty())
	var r := Protocole.decoder_etat_arene_regardee(b, _catalogue, NB_UNITES)
	verifier_egal(r.get("id"), 123456789)
	var d: VueArene = r.get("vue")
	verifier_non_nul(d)
	if d != null:
		verifier_egal(d.allies.size(), 3)
		verifier_egal(d.zones.size(), 2)
		verifier_egal(d.bombes.size(), 1)
	var trop := _vue(Protocole.MAX_ALLIES + 1)
	verifier(Protocole.encoder_etat_arene_regardee(1, trop, _catalogue, NB_UNITES).is_empty())


func _etat_le_plus_charge() -> VueArene:
	var v := _vue(Protocole.MAX_ALLIES, Protocole.MAX_ZONES, Protocole.MAX_BOMBES)
	for i: int in 1000:
		v.ennemis_id.append(i)
		v.ennemis_pos.append(Vector2(float(i), -float(i)))
		v.ennemis_famille.append(i % 26)
		v.ennemis_pv.append(200)
		v.ennemis_statuts.append(i % 256)
	for i: int in 255:
		v.armes.append({"id": _catalogue[i], "recharge_ratio": 0.25})
	for i: int in 87:
		v.ameliorations[_catalogue[i]] = 3
	for i in Protocole.MAX_EVENEMENTS:
		v.evenements.append(
			_evenement(i % VueArene.GENRES_ARME.size(), i % VueArene.STATUTS_ARME.size())
		)
	return v


func test_un_etat_charge_au_maximum_tient_sous_max_taille() -> void:
	var v := _etat_le_plus_charge()
	var b := _encoder(v)
	verifier_faux(b.is_empty())
	verifier(b.size() <= Protocole.MAX_TAILLE, "%d octets" % b.size())
	verifier_non_nul(_decoder(b))
	var regardee := Protocole.encoder_etat_arene_regardee(1, v, _catalogue, NB_UNITES)
	verifier(
		regardee.size() <= Protocole.MAX_TAILLE, "arène regardée : %d octets" % regardee.size()
	)
	# Ce que les alliés, zones et bombes ajoutent : 64 × 5 + 32 × 7 + 32 × 6 = 736 octets.
	var sans := _etat_le_plus_charge()
	sans.allies.clear()
	sans.zones.clear()
	sans.bombes.clear()
	verifier_egal(b.size() - _encoder(sans).size(), 736)


## Review Focus 4 : aucun paquet forgé ne lève d'exception et chacun rend `null` ou `{}`.
func test_aucun_paquet_forge_ne_leve_d_exception() -> void:
	var v := _vue(3, 2, 2)
	v.evenements = [_evenement(9, 6)]
	var arene := _encoder(v)
	var regardee := Protocole.encoder_etat_arene_regardee(4, v, _catalogue, NB_UNITES)
	for n: int in arene.size():
		verifier_nul(_decoder(arene.slice(0, n)), "arène tronquée à %d" % n)
	for n: int in regardee.size():
		verifier_egal(
			Protocole.decoder_etat_arene_regardee(regardee.slice(0, n), _catalogue, NB_UNITES),
			{},
			"regardée tronquée à %d" % n
		)
	verifier_nul(_decoder(arene + PackedByteArray([0])), "octet en trop")
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	for _i: int in 2000:
		var bruit := PackedByteArray()
		bruit.resize(rng.randi_range(1, 400))
		for k: int in bruit.size():
			bruit[k] = rng.randi() % 256
		bruit[0] = Protocole.Msg.ETAT_ARENE
		var d := _decoder(bruit)
		verifier(d == null or d.allies.size() <= Protocole.MAX_ALLIES, "bruit de type arène")
		bruit[0] = Protocole.Msg.ETAT_ARENE_REGARDEE
		var r := Protocole.decoder_etat_arene_regardee(bruit, _catalogue, NB_UNITES)
		verifier(r.is_empty() or r.has("vue"), "bruit de type regardée")
	# Un paquet valide dont un octet de la queue est modifié, à chaque position, ne plante pas.
	for k: int in range(arene.size() - 40, arene.size()):
		for valeur: int in [0, 1, 127, 128, 255]:
			var forge := arene.duplicate()
			forge[k] = valeur
			var d := _decoder(forge)
			verifier(d == null or d.allies.size() <= Protocole.MAX_ALLIES)
	# Un octet est toujours fini : un reste non fini ne se forge pas, la vue décodée est valide.
	var valide := _decoder(arene)
	verifier_non_nul(valide)
	if valide != null:
		verifier_non_nul(VueArene.from_dict(valide.to_dict()))
