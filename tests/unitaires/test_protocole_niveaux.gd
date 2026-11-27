extends CasDeTest
## Protocole version 12 (D23) : chaque arme de la vue porte son niveau, sur un octet. Tout octet
## vient d'un tiers : un niveau nul, un paquet tronqué ou forgé rend `null`, jamais une exception.

const GRAINE := 20261127
var _catalogue: PackedStringArray


func avant_chaque() -> void:
	_catalogue = PackedStringArray(["a", "b", "c"])


func _vue(niveaux: Array[int]) -> VueArene:
	var v := VueArene.new()
	v.tour_pv = 500.0
	v.tour_pv_max = 1000.0
	for i: int in niveaux.size():
		v.armes.append(
			{"id": _catalogue[i % _catalogue.size()], "recharge_ratio": 0.5, "niveau": niveaux[i]}
		)
	return v


func test_la_version_a_monte_et_les_precedentes_sont_refusees() -> void:
	verifier(Protocole.VERSION >= 12, "version %d" % Protocole.VERSION)
	for ancienne: int in range(1, Protocole.VERSION):
		var b := Protocole.encoder_bonjour("Phil", 42)
		b[1] = ancienne
		verifier_egal(Protocole.decoder_bonjour(b), {}, "version %d" % ancienne)


func test_la_vue_porte_le_niveau_de_chaque_arme_aller_retour() -> void:
	for brut: Array in [[1], [2, 1], [255, 1, 7], [1, 1, 1, 1, 200]]:
		var niveaux: Array[int] = []
		niveaux.assign(brut)
		var v := _vue(niveaux)
		var relue := Protocole.decoder_etat_arene(
			Protocole.encoder_etat_arene(v, _catalogue), _catalogue
		)
		verifier_non_nul(relue, str(niveaux))
		verifier_egal(relue.armes.size(), niveaux.size())
		for i: int in niveaux.size():
			verifier_egal(int(relue.armes[i]["niveau"]), niveaux[i], "arme %d de %s" % [i, niveaux])
		var regardee := Protocole.decoder_etat_arene_regardee(
			Protocole.encoder_etat_arene_regardee(123456789, v, _catalogue), _catalogue
		)
		verifier_non_nul(regardee.get("vue"), "regardée " + str(niveaux))
		var vr: VueArene = regardee["vue"]
		verifier_egal(int(vr.armes[0]["niveau"]), niveaux[0])


func test_un_niveau_hors_bornes_est_ramene_dans_un_octet_a_l_encodage() -> void:
	var relue := Protocole.decoder_etat_arene(
		Protocole.encoder_etat_arene(_vue([1000]), _catalogue), _catalogue
	)
	verifier_non_nul(relue)
	verifier_egal(int(relue.armes[0]["niveau"]), 255)


func test_un_niveau_a_zero_rend_null() -> void:
	var avec_3 := Protocole.encoder_etat_arene(_vue([3]), _catalogue)
	var avec_4 := Protocole.encoder_etat_arene(_vue([4]), _catalogue)
	var positions: Array[int] = []
	for i: int in avec_3.size():
		if avec_3[i] != avec_4[i]:
			positions.append(i)
	verifier_egal(positions.size(), 1, "un seul octet porte le niveau")
	var c := avec_3.duplicate()
	c[positions[0]] = 0
	verifier_nul(Protocole.decoder_etat_arene(c, _catalogue), "niveau 0 refusé")
	c[positions[0]] = 3
	verifier_non_nul(Protocole.decoder_etat_arene(c, _catalogue), "niveau 3 accepté")


func test_tous_les_prefixes_et_2000_tableaux_tires_rendent_null_ou_vide() -> void:
	var b := Protocole.encoder_etat_arene(_vue([2, 5]), _catalogue)
	for n: int in b.size():
		verifier_nul(Protocole.decoder_etat_arene(b.slice(0, n), _catalogue), "préfixe %d" % n)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	for _i: int in 2000:
		var c := b.duplicate()
		for _k: int in 1 + rng.randi() % 4:
			c[rng.randi() % c.size()] = rng.randi() % 256
		Protocole.decoder_etat_arene(c, _catalogue)
	verify_no_crash()


func verify_no_crash() -> void:
	verifier(true)


func test_une_vue_sans_niveau_ou_au_niveau_nul_n_est_pas_conforme() -> void:
	var v := _vue([1])
	var d := v.to_dict()
	verifier_non_nul(VueArene.from_dict(d), "vue valide")
	var arme: Dictionary = (d["armes"] as Array)[0]
	arme.erase("niveau")
	verifier_nul(VueArene.from_dict(d), "niveau manquant")
	arme["niveau"] = 0
	verifier_nul(VueArene.from_dict(d), "niveau nul")


func test_l_arene_expose_le_niveau_de_chaque_arme() -> void:
	var d := Donnees.charger()
	var a := Arene.new(d, 31)
	for i: int in 3:
		a.inventaire.ajouter("lame_de_fil")
	a.inventaire.ajouter("arbalete_de_bureau")
	a.synchroniser()
	var vue := a.vue(Types.Phase.PREPARATION, 10.0, -1, false)
	verifier_egal(vue.armes.size(), 2)
	verifier_egal(int(vue.armes[0]["niveau"]), 3)
	verifier_egal(int(vue.armes[1]["niveau"]), 1)
