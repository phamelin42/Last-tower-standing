extends CasDeTest
## Protocole version 10 : le skin de tour de chaque joueur dans l'état global, et l'intention
## `SKIN` du client. Tout octet vient d'un tiers : les paquets forgés rendent `null` ou `{}`.

const GRAINE := 20261126
const SKINS: Array[int] = [0, 1, 7, 42, 255]


func _vue(skins: Array[int]) -> VueGlobale:
	var v := VueGlobale.new()
	for i: int in skins.size():
		(
			v
			. joueurs
			. append(
				{
					"id": 665857105 + i,
					"nom": "Joueuse %d" % i,
					"manche": 3,
					"eliminations": 12,
					"degats": 450.5,
					"dps": 20.0,
					"pv": 800.0,
					"pv_max": 1000.0,
					"revenu": 30,
					"vivant": true,
					"victorieux": false,
					"skin": skins[i],
				}
			)
		)
	return v


func test_la_version_a_ete_incrementee_et_toutes_les_precedentes_sont_refusees() -> void:
	verifier(Protocole.VERSION >= 10, "version %d" % Protocole.VERSION)
	for ancienne: int in range(1, Protocole.VERSION):
		var b := Protocole.encoder_bonjour("Phil", 42)
		b[1] = ancienne
		verifier_egal(Protocole.decoder_bonjour(b), {}, "version %d" % ancienne)
		verifier_egal(Protocole.version_bonjour(b), ancienne)
		var motif := Protocole.motif_version(ancienne)
		verifier(motif.contains(str(ancienne)) and motif.contains(str(Protocole.VERSION)), motif)
	verifier_non_nul(Protocole.decoder_bonjour(Protocole.encoder_bonjour("Phil", 42)))


func test_chaque_skin_fait_l_aller_retour_dans_l_etat_global() -> void:
	var v := _vue(SKINS)
	var relue := Protocole.decoder_etat_global(Protocole.encoder_etat_global(v))
	verifier_non_nul(relue)
	if relue == null:
		return
	for i: int in SKINS.size():
		verifier_egal(int(relue.joueurs[i]["skin"]), SKINS[i], "joueur %d" % i)
		verifier_egal(int(relue.joueurs[i]["id"]), 665857105 + i, "id sur 32 bits")


func test_un_joueur_sans_skin_se_relit_avec_le_skin_par_defaut() -> void:
	var v := _vue([5] as Array[int])
	(v.joueurs[0] as Dictionary).erase("skin")
	var relue := Protocole.decoder_etat_global(Protocole.encoder_etat_global(v))
	verifier_non_nul(relue)
	if relue != null:
		verifier_egal(int(relue.joueurs[0]["skin"]), 0)


func test_un_skin_hors_de_un_octet_est_ramene_dans_les_bornes() -> void:
	var v := _vue([-3, 256, 2147483647] as Array[int])
	var relue := Protocole.decoder_etat_global(Protocole.encoder_etat_global(v))
	verifier_non_nul(relue)
	if relue != null:
		for j: Dictionary in relue.joueurs:
			verifier(int(j["skin"]) >= 0 and int(j["skin"]) <= 255, "borné")


func test_la_vue_globale_refuse_un_skin_mal_type_ou_hors_bornes() -> void:
	var d := _vue([1] as Array[int]).to_dict()
	verifier_non_nul(VueGlobale.from_dict(d))
	for mauvais: Variant in [-1, 256, 1.5, "1", null]:
		var c := d.duplicate(true)
		(c["joueurs"][0] as Dictionary)["skin"] = mauvais
		verifier_nul(VueGlobale.from_dict(c), "skin %s" % str(mauvais))
	var sans := d.duplicate(true)
	(sans["joueurs"][0] as Dictionary).erase("skin")
	var relue := VueGlobale.from_dict(sans)
	verifier_non_nul(relue)
	if relue != null:
		verifier_egal(int(relue.joueurs[0]["skin"]), 0, "absent : skin par défaut")


func test_un_octet_de_skin_par_joueur_de_plus() -> void:
	for n: int in range(0, 9):
		var skins: Array[int] = []
		skins.resize(n)
		var avec := Protocole.encoder_etat_global(_vue(skins))
		verifier(avec.size() > 0, "%d joueurs encodables" % n)
		verifier_egal(
			avec.size() - Protocole.encoder_etat_global(VueGlobale.new()).size() > 0, n > 0
		)
	var huit: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
	var v8 := _vue(huit)
	var sans_skin := _vue(huit)
	for j: Dictionary in sans_skin.joueurs:
		j["skin"] = 0
	verifier_egal(
		Protocole.encoder_etat_global(v8).size(),
		Protocole.encoder_etat_global(sans_skin).size(),
		"la valeur du skin ne change pas la taille : un octet fixe par joueur"
	)


func test_l_intention_skin_fait_l_aller_retour_avec_n_importe_quel_entier() -> void:
	for arg: int in [-1, 0, 1, 7, 255, 256, 2147483647, -2147483648]:
		var b := Protocole.encoder_intention(Protocole.Intention.SKIN, arg)
		verifier(not b.is_empty(), "arg %d encodable" % arg)
		var i := Protocole.decoder_intention(b)
		verifier_egal(int(i.get("genre", -1)), Protocole.Intention.SKIN)
		verifier_egal(int(i.get("arg", -99)), arg)
	verifier(
		Protocole.encoder_intention(Protocole.Intention.SKIN + 1, 0).is_empty(),
		"aucun genre au-delà du dernier"
	)


func test_paquets_forges_prefixes_et_2000_tableaux_d_une_graine_fixe() -> void:
	var etat := Protocole.encoder_etat_global(_vue(SKINS))
	for i: int in etat.size():
		verifier_nul(Protocole.decoder_etat_global(etat.slice(0, i)), "préfixe global %d" % i)
	var intention := Protocole.encoder_intention(Protocole.Intention.SKIN, 3)
	for i: int in intention.size():
		verifier_egal(Protocole.decoder_intention(intention.slice(0, i)), {}, "préfixe %d" % i)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	for _i: int in 2000:
		var b := PackedByteArray()
		b.resize(rng.randi_range(0, 160))
		for k: int in b.size():
			b[k] = rng.randi() & 0xFF
		if b.size() > 0:
			b[0] = Protocole.Msg.ETAT_GLOBAL
		var g := Protocole.decoder_etat_global(b)
		verifier(g == null or g is VueGlobale)
		if b.size() > 0:
			b[0] = Protocole.Msg.INTENTION
		var i := Protocole.decoder_intention(b)
		verifier(i.is_empty() or i.has("genre"))
