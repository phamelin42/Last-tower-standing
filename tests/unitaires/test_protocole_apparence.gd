extends CasDeTest
## Protocole version 9 : les quatre statistiques d'apparence de la tour (épines, esquive,
## régénération, vol de vie) accompagnent l'état d'arène, aussi pour l'arène regardée. Tout octet
## vient d'un tiers : les paquets forgés rendent `null` ou `{}`, jamais une exception.

const GRAINE := 20261126
const CHAMPS: Array[String] = ["tour_epines", "tour_esquive", "tour_regen", "tour_vol_de_vie"]

var _catalogue: PackedStringArray


func avant_chaque() -> void:
	_catalogue = PackedStringArray(["a", "b"])


func _vue(valeur: float) -> VueArene:
	var v := VueArene.new()
	v.tour_pv = 500.0
	v.tour_pv_max = 1000.0
	v.tour_epines = valeur
	v.tour_esquive = valeur / 2.0
	v.tour_regen = valeur * 3.0
	v.tour_vol_de_vie = valeur * 4.0
	return v


func test_les_versions_precedentes_du_protocole_sont_refusees() -> void:
	verifier(Protocole.VERSION >= 9, "version %d" % Protocole.VERSION)
	for ancienne: int in range(1, Protocole.VERSION):
		var b := Protocole.encoder_bonjour("Phil", 42)
		b[1] = ancienne
		verifier_egal(Protocole.decoder_bonjour(b), {}, "version %d" % ancienne)
		verifier_egal(Protocole.version_bonjour(b), ancienne)


func test_l_etat_d_arene_et_l_etat_d_arene_regardee_portent_les_quatre_champs_aller_retour(
) -> void:
	for valeur: float in [0.0, 0.25, 7.5, 123456.0, 3.0e9]:
		var v := _vue(valeur)
		var relue := Protocole.decoder_etat_arene(
			Protocole.encoder_etat_arene(v, _catalogue), _catalogue
		)
		verifier_non_nul(relue, "état %s" % valeur)
		var regardee := Protocole.decoder_etat_arene_regardee(
			Protocole.encoder_etat_arene_regardee(123456789, v, _catalogue), _catalogue
		)
		verifier_non_nul(regardee.get("vue"), "regardée %s" % valeur)
		for nom: String in CHAMPS:
			var attendu: float = v.get(nom)
			verifier_proche(relue.get(nom), attendu, absf(attendu) * 1e-6 + 1e-6, nom)
			var vue_regardee: VueArene = regardee["vue"]
			verifier_proche(vue_regardee.get(nom), attendu, absf(attendu) * 1e-6 + 1e-6, nom)


func test_un_flottant_d_apparence_non_fini_rend_null() -> void:
	var b := Protocole.encoder_etat_arene(_vue(1.0), _catalogue)
	for k: int in CHAMPS.size():
		for forge: float in [NAN, INF, -INF]:
			var c := b.duplicate()
			c.encode_float(Protocole.OFFSET_APPARENCE + 4 * k, forge)
			verifier_egal(
				Protocole.decoder_etat_arene(c, _catalogue), null, "%s %s" % [CHAMPS[k], forge]
			)
			var r := PackedByteArray([Protocole.Msg.ETAT_ARENE_REGARDEE, 0, 0, 0, 1])
			r.append_array(c.slice(1))
			verifier_egal(
				Protocole.decoder_etat_arene_regardee(r, _catalogue), {}, "regardée %s" % CHAMPS[k]
			)


func test_un_flottant_d_apparence_negatif_rend_null() -> void:
	var b := Protocole.encoder_etat_arene(_vue(1.0), _catalogue)
	for k: int in CHAMPS.size():
		var c := b.duplicate()
		c.encode_float(Protocole.OFFSET_APPARENCE + 4 * k, -1.0)
		verifier_egal(Protocole.decoder_etat_arene(c, _catalogue), null, CHAMPS[k])


func test_tous_les_prefixes_et_2000_tableaux_tires_rendent_null_ou_vide() -> void:
	var arene := Protocole.encoder_etat_arene(_vue(2.0), _catalogue)
	var regardee := Protocole.encoder_etat_arene_regardee(77, _vue(2.0), _catalogue)
	for i: int in arene.size():
		verifier_egal(
			Protocole.decoder_etat_arene(arene.slice(0, i), _catalogue), null, "préfixe %d" % i
		)
	for i: int in regardee.size():
		verifier_egal(
			Protocole.decoder_etat_arene_regardee(regardee.slice(0, i), _catalogue),
			{},
			"préfixe regardée %d" % i
		)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	for _i: int in 2000:
		var b := PackedByteArray()
		b.resize(rng.randi_range(0, 200))
		for j: int in b.size():
			b[j] = rng.randi() & 0xFF
		if b.size() > 0:
			b[0] = Protocole.Msg.ETAT_ARENE
		var vue := Protocole.decoder_etat_arene(b, _catalogue)
		verifier(vue == null or vue is VueArene)
		if b.size() > 0:
			b[0] = Protocole.Msg.ETAT_ARENE_REGARDEE
		var r := Protocole.decoder_etat_arene_regardee(b, _catalogue)
		verifier(r.is_empty() or r.has("vue"))


func test_la_taille_fixe_compte_les_quatre_flottants() -> void:
	verifier_egal(Protocole.TAILLE_FIXE, 79)
	verifier_egal(Protocole.encoder_etat_arene(VueArene.new(), _catalogue).size(), 79)
