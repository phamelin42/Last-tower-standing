extends CasDeTest
## Protocole version 5 : mana, familles suivantes, 255 armes, arme et absorption dans les
## événements, dps et densités, arène regardée, intention REGARDER. Tout octet vient d'un tiers :
## les paquets forgés rendent `null` ou `{}`, jamais une exception.

const GRAINE := 20261125
const OCTETS_EVENEMENT := 14
## Octets après la dernière liste d'événements : les trois compteurs d'alliés, de zones et de bombes
## (version 6), puis éliminations, dégâts et manche maximale.
const OCTETS_QUEUE := 11

var _catalogue: PackedStringArray


func avant_chaque() -> void:
	_catalogue = PackedStringArray()
	for i in 300:
		_catalogue.append("objet_%03d" % i)


func _vue() -> VueArene:
	var v := VueArene.new()
	v.tick = 4242
	v.manche = 9
	v.phase = Types.Phase.MANCHE
	v.tour_pv = 800.0
	v.tour_pv_max = 1000.0
	v.tour_mana = 35.5
	v.tour_mana_max = 90.0
	return v


func _evenement(genre: String, arme: int = -1) -> Dictionary:
	var e: Dictionary = {
		"k": genre,
		"t": 4242,
		"de": Vector2(10, -20),
		"vers": Vector2(300, 40),
		"type_degats": 2,
		"rayon": 16.0,
	}
	if arme >= 0:
		e["arme"] = arme
	return e


func _carte(valeur: int) -> PackedByteArray:
	var carte := PackedByteArray()
	carte.resize(VueGlobale.DENSITE_OCTETS)
	carte.fill(valeur)
	return carte


func _globale(nb: int, cartes: int) -> VueGlobale:
	var g := VueGlobale.new()
	g.temps_ecoule = 61.5
	g.en_cours = true
	for i in nb:
		(
			g
			. joueurs
			. append(
				{
					"id": i,
					"nom": "Joueur %d" % i,
					"manche": 3,
					"eliminations": 7,
					"degats": 100.5,
					"dps": 33.25 * float(i),
					"revenu": 20,
					"vivant": true,
					"victorieux": false,
				}
			)
		)
	for i in cartes:
		g.densites[i] = _carte(i + 1)
	return g


func _prefixes(b: PackedByteArray) -> Array[PackedByteArray]:
	var liste: Array[PackedByteArray] = []
	for n in b.size():
		liste.append(b.slice(0, n))
	return liste


func test_un_bonjour_de_version_4_est_refuse_avec_un_motif() -> void:
	verifier(Protocole.VERSION >= 5)
	var b := Protocole.encoder_bonjour("Phil", 42)
	b[1] = 4
	verifier_egal(Protocole.version_bonjour(b), 4)
	var motif := Protocole.motif_version(4)
	verifier(motif.contains("4") and motif.contains(str(Protocole.VERSION)), motif)


func test_mana_et_prochaines_familles_traversent_le_protocole() -> void:
	for nombre in range(0, 4):
		var v := _vue()
		for i in nombre:
			v.prochaines_familles.append(4 * i + 1)
			v.prochaines_armures.append(i)
		var b := Protocole.encoder_etat_arene(v, _catalogue)
		verifier_faux(b.is_empty(), "%d famille(s) encodables" % nombre)
		var d := Protocole.decoder_etat_arene(b, _catalogue)
		verifier_non_nul(d, "%d famille(s)" % nombre)
		if d == null:
			continue
		verifier_proche(d.tour_mana, 35.5, 0.001)
		verifier_proche(d.tour_mana_max, 90.0, 0.001)
		verifier_egal(d.prochaines_familles, v.prochaines_familles)
		verifier_egal(d.prochaines_armures, v.prochaines_armures)
		verifier_egal(d.prochaine_famille, -1 if nombre == 0 else 1)
		verifier_egal(d.prochaine_armure, 0)
		verifier_egal(b.size(), Protocole.TAILLE_FIXE + 2 * nombre)


func test_un_etat_vide_a_exactement_la_taille_fixe() -> void:
	verifier_egal(
		Protocole.encoder_etat_arene(VueArene.new(), _catalogue).size(), Protocole.TAILLE_FIXE
	)


func test_une_famille_unique_de_l_ancien_champ_est_annoncee() -> void:
	var v := _vue()
	v.prochaine_famille = 7
	v.prochaine_armure = Types.Armure.FORTIFIEE
	var d := Protocole.decoder_etat_arene(Protocole.encoder_etat_arene(v, _catalogue), _catalogue)
	verifier_non_nul(d)
	if d == null:
		return
	verifier_egal(d.prochaines_familles, PackedInt32Array([7]))
	verifier_egal(d.prochaine_famille, 7)
	verifier_egal(d.prochaine_armure, Types.Armure.FORTIFIEE)


func test_plus_de_trois_familles_ou_des_armures_de_taille_differente_ne_s_encodent_pas() -> void:
	var v := _vue()
	v.prochaines_familles = PackedInt32Array([1, 2, 3, 4])
	v.prochaines_armures = PackedByteArray([0, 0, 0, 0])
	verifier(Protocole.encoder_etat_arene(v, _catalogue).is_empty(), "quatre familles")
	var w := _vue()
	w.prochaines_familles = PackedInt32Array([1, 2])
	w.prochaines_armures = PackedByteArray([0])
	verifier(Protocole.encoder_etat_arene(w, _catalogue).is_empty(), "armures en nombre différent")


func test_255_armes_s_encodent_et_256_sont_refusees() -> void:
	verifier_egal(Protocole.MAX_ARMES, 255)
	var v := _vue()
	for i in 255:
		v.armes.append({"id": _catalogue[i], "recharge_ratio": 0.5})
	var d := Protocole.decoder_etat_arene(Protocole.encoder_etat_arene(v, _catalogue), _catalogue)
	verifier_non_nul(d, "255 armes")
	if d != null:
		verifier_egal(d.armes.size(), 255)
		verifier_egal(d.armes[254]["id"], _catalogue[254])
	v.armes.append({"id": _catalogue[255], "recharge_ratio": 0.5})
	verifier(Protocole.encoder_etat_arene(v, _catalogue).is_empty(), "256 armes refusées")


func test_un_evenement_absorption_traverse_et_un_type_inconnu_est_refuse() -> void:
	var v := _vue()
	v.evenements = [_evenement("absorption")]
	var b := Protocole.encoder_etat_arene(v, _catalogue)
	var d := Protocole.decoder_etat_arene(b, _catalogue)
	verifier_non_nul(d)
	if d != null:
		verifier_egal(d.evenements[0]["k"], "absorption")
	var inconnu := _vue()
	inconnu.evenements = [_evenement("explosion")]
	verifier(
		Protocole.encoder_etat_arene(inconnu, _catalogue).is_empty(), "genre inconnu à l'envoi"
	)
	var forge := b.duplicate()
	forge[forge.size() - OCTETS_QUEUE - OCTETS_EVENEMENT] = 4
	verifier_nul(Protocole.decoder_etat_arene(forge, _catalogue), "type d'événement 4 forgé")


func test_un_evenement_porte_l_arme_et_sans_arme_il_n_a_pas_la_cle() -> void:
	var v := _vue()
	v.evenements = [_evenement("tir", 17), _evenement("tir"), _evenement("impact", 299)]
	var b := Protocole.encoder_etat_arene(v, _catalogue)
	var d := Protocole.decoder_etat_arene(b, _catalogue)
	verifier_non_nul(d)
	if d == null:
		return
	verifier_egal(d.evenements[0]["arme"], 17)
	verifier_faux(d.evenements[1].has("arme"), "pas d'arme : pas de clé")
	verifier_egal(d.evenements[2]["arme"], 299)
	# L'événement décodé est conforme au schéma de la vue.
	verifier_non_nul(VueArene.from_dict(d.to_dict()))
	var hors := _vue()
	hors.evenements = [_evenement("tir", 300)]
	verifier(Protocole.encoder_etat_arene(hors, _catalogue).is_empty(), "arme hors catalogue")
	# Index d'arme forgé hors du catalogue : octets 12 et 13 du premier événement.
	var un := _vue()
	un.evenements = [_evenement("tir", 1)]
	var forge := Protocole.encoder_etat_arene(un, _catalogue)
	forge.encode_u16(forge.size() - OCTETS_QUEUE - 2, 300)
	verifier_nul(Protocole.decoder_etat_arene(forge, _catalogue), "index d'arme 300")


func test_l_etat_global_porte_dps_et_densites() -> void:
	var g := _globale(3, 2)
	var b := Protocole.encoder_etat_global(g)
	verifier_faux(b.is_empty())
	var d := Protocole.decoder_etat_global(b)
	verifier_non_nul(d)
	if d == null:
		return
	for i in 3:
		verifier_proche(float(d.joueurs[i]["dps"]), 33.25 * float(i), 0.001)
	verifier_egal(d.densites.size(), 2)
	verifier_egal(d.densites[0], _carte(1))
	verifier_egal(d.densites[1], _carte(2))
	verifier_non_nul(VueGlobale.from_dict(d.to_dict()), "la vue décodée est conforme")


func test_un_etat_global_sans_densites_les_decode_vides() -> void:
	var d := Protocole.decoder_etat_global(Protocole.encoder_etat_global(_globale(2, 0)))
	verifier_non_nul(d)
	if d != null:
		verifier(d.densites.is_empty(), "aucune densité diffusée")


func test_une_densite_qui_n_a_pas_256_octets_ou_trop_de_cartes_ne_s_encode_pas() -> void:
	for taille: int in [0, 255, 257]:
		var g := _globale(1, 1)
		var carte := _carte(3)
		carte.resize(taille)
		g.densites[0] = carte
		verifier(Protocole.encoder_etat_global(g).is_empty(), "carte de %d octets" % taille)
	verifier(Protocole.encoder_etat_global(_globale(1, 17)).is_empty(), "17 cartes")
	verifier_faux(Protocole.encoder_etat_global(_globale(1, 16)).is_empty(), "16 cartes")


func test_etat_arene_regardee_aller_retour() -> void:
	var v := _vue()
	v.armes.append({"id": _catalogue[3], "recharge_ratio": 1.0})
	v.evenements = [_evenement("tir", 3)]
	for id: int in [0, 1, 7, 255, 256, 665857105, Protocole.MAX_ID_REGARDE]:
		var b := Protocole.encoder_etat_arene_regardee(id, v, _catalogue)
		verifier_egal(Protocole.type_de(b), Protocole.Msg.ETAT_ARENE_REGARDEE)
		var r := Protocole.decoder_etat_arene_regardee(b, _catalogue)
		verifier_faux(r.is_empty(), "id %d" % id)
		if r.is_empty():
			continue
		verifier_egal(r["id"], id)
		var vue: VueArene = r["vue"]
		verifier_egal(vue.tick, 4242)
		verifier_proche(vue.tour_mana, 35.5, 0.001)
		verifier_egal(vue.evenements[0]["arme"], 3)
	for id_invalide: int in [-1, -665857105, Protocole.MAX_ID_REGARDE + 1]:
		verifier(
			Protocole.encoder_etat_arene_regardee(id_invalide, v, _catalogue).is_empty(),
			"id %d refusé" % id_invalide
		)
	# Le champ de l'identifiant (octets 1 à 4) tronqué, ou forgé négatif : `{}`, jamais d'erreur.
	var complet := Protocole.encoder_etat_arene_regardee(665857105, v, _catalogue)
	for longueur: int in range(0, 5):
		verifier_egal(
			Protocole.decoder_etat_arene_regardee(complet.slice(0, longueur), _catalogue),
			{},
			"tronqué à %d octets" % longueur
		)
	var negatif := complet.duplicate()
	negatif.encode_s32(1, -665857105)
	verifier_egal(Protocole.decoder_etat_arene_regardee(negatif, _catalogue), {}, "id négatif")
	# Un état d'arène ordinaire n'est pas un état d'arène regardée, et réciproquement.
	var ordinaire := Protocole.encoder_etat_arene(v, _catalogue)
	verifier_egal(Protocole.decoder_etat_arene_regardee(ordinaire, _catalogue), {})
	var regardee := Protocole.encoder_etat_arene_regardee(1, v, _catalogue)
	verifier_nul(Protocole.decoder_etat_arene(regardee, _catalogue))


func test_intention_regarder_aller_retour_avec_moins_un() -> void:
	for arg: int in [-1, 0, 1, 255, 256, 665857105, Protocole.MAX_ID_REGARDE]:
		var b := Protocole.encoder_intention(Protocole.Intention.REGARDER, arg)
		verifier_faux(b.is_empty(), "arg %d" % arg)
		var d := Protocole.decoder_intention(b)
		verifier_egal(d.get("genre"), Protocole.Intention.REGARDER)
		verifier_egal(d.get("arg"), arg)
	for arg: int in [-2, -100000, -665857105]:
		verifier(
			Protocole.encoder_intention(Protocole.Intention.REGARDER, arg).is_empty(),
			"arg %d refusé à l'envoi" % arg
		)
		var forge := Protocole.encoder_intention(Protocole.Intention.OBSERVER, arg)
		forge[1] = Protocole.Intention.REGARDER
		verifier_egal(Protocole.decoder_intention(forge), {}, "arg %d forgé" % arg)
	for trop_grand: int in [Protocole.MAX_ID_REGARDE + 1, 1 << 40]:
		verifier(
			Protocole.encoder_intention(Protocole.Intention.REGARDER, trop_grand).is_empty(),
			"arg %d refusé à l'envoi" % trop_grand
		)
	for code: int in range(Types.Resultat.OK, Types.Resultat.ARMES_AU_MAXIMUM + 1):
		var r := Protocole.decoder_resultat(
			Protocole.encoder_resultat(Protocole.Intention.REGARDER, code)
		)
		verifier_egal(r.get("code"), code, "code %d transportable" % code)


func test_un_etat_de_mille_ennemis_255_armes_et_40_ameliorations_tient_sous_max_taille() -> void:
	var v := _vue()
	for i in 1000:
		v.ennemis_id.append(i)
		v.ennemis_pos.append(Vector2(float(i), -float(i)))
		v.ennemis_famille.append(i % 26)
		v.ennemis_pv.append(200)
		v.ennemis_statuts.append(0)
	for i in 255:
		v.armes.append({"id": _catalogue[i], "recharge_ratio": 0.25})
	for i in 40:
		v.ameliorations[_catalogue[i]] = 3
	for i in Protocole.MAX_EVENEMENTS:
		v.evenements.append(_evenement("tir", i))
	var b := Protocole.encoder_etat_arene(v, _catalogue)
	verifier_faux(b.is_empty())
	verifier(b.size() <= Protocole.MAX_TAILLE, "%d octets" % b.size())
	verifier_non_nul(Protocole.decoder_etat_arene(b, _catalogue))
	var regardee := Protocole.encoder_etat_arene_regardee(1, v, _catalogue)
	verifier(
		regardee.size() <= Protocole.MAX_TAILLE, "arène regardée : %d octets" % regardee.size()
	)
	var global := Protocole.encoder_etat_global(_globale(16, 16))
	verifier(global.size() <= Protocole.MAX_TAILLE, "global : %d octets" % global.size())
	verifier_non_nul(Protocole.decoder_etat_global(global))


## Review Focus 3 : aucun paquet v5 forgé ne lève d'exception (une erreur de script fait échouer
## le test) et chacun rend `null` ou `{}`.
func test_aucun_paquet_v5_forge_ne_leve_d_exception() -> void:
	var v := _vue()
	v.prochaines_familles = PackedInt32Array([1, 2, 3])
	v.prochaines_armures = PackedByteArray([0, 1, 2])
	v.armes.append({"id": _catalogue[1], "recharge_ratio": 0.5})
	v.evenements = [_evenement("tir", 5), _evenement("absorption")]
	var arene := Protocole.encoder_etat_arene(v, _catalogue)
	var regardee := Protocole.encoder_etat_arene_regardee(4, v, _catalogue)
	var global := Protocole.encoder_etat_global(_globale(3, 3))
	var intention := Protocole.encoder_intention(Protocole.Intention.REGARDER, 4)
	for b: PackedByteArray in _prefixes(arene):
		verifier_nul(Protocole.decoder_etat_arene(b, _catalogue), "arène tronquée à %d" % b.size())
	for b: PackedByteArray in _prefixes(regardee):
		verifier_egal(Protocole.decoder_etat_arene_regardee(b, _catalogue), {}, "regardée")
	for b: PackedByteArray in _prefixes(global):
		verifier_nul(Protocole.decoder_etat_global(b), "global tronqué à %d" % b.size())
	for b: PackedByteArray in _prefixes(intention):
		verifier_egal(Protocole.decoder_intention(b), {}, "intention tronquée")
	# Compteurs forgés.
	var quatre := arene.duplicate()
	quatre[Protocole.OFFSET_NB_FAMILLES] = 4
	verifier_nul(Protocole.decoder_etat_arene(quatre, _catalogue), "4 familles forgées")
	var cartes := global.duplicate()
	cartes[global.size() - 3 * (4 + VueGlobale.DENSITE_OCTETS) - 1] = 17
	verifier_nul(Protocole.decoder_etat_global(cartes), "17 cartes forgées")
	var cartes_doublees := global.duplicate()
	cartes_doublees.encode_s32(global.size() - 2 * (4 + VueGlobale.DENSITE_OCTETS), 0)
	verifier_nul(Protocole.decoder_etat_global(cartes_doublees), "deux cartes pour le même joueur")
	# Bruit à graine fixe, avec le type de chaque message.
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	for i in 2000:
		var bruit := PackedByteArray()
		bruit.resize(rng.randi_range(1, 400))
		for k in bruit.size():
			bruit[k] = rng.randi() % 256
		for type: int in [
			Protocole.Msg.ETAT_ARENE, Protocole.Msg.ETAT_GLOBAL, Protocole.Msg.ETAT_ARENE_REGARDEE
		]:
			bruit[0] = type
			verifier_nul(Protocole.decoder_etat_arene(bruit, _catalogue))
			verifier_nul(Protocole.decoder_etat_global(bruit))
			verifier_egal(Protocole.decoder_etat_arene_regardee(bruit, _catalogue), {})
		bruit[0] = Protocole.Msg.INTENTION
		bruit.resize(mini(bruit.size(), 7))
		var intention_bruit := Protocole.decoder_intention(bruit)
		verifier(intention_bruit.is_empty() or intention_bruit["genre"] <= 10, "intention de bruit")
