extends CasDeTest
## Le message `RESULTAT` : ce que le serveur répond à une intention (son genre et son code),
## compact, et décodé sans jamais lever d'erreur, quel que soit le paquet reçu.

const GRAINE := 20261125


func _troncatures(b: PackedByteArray) -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	for n: int in b.size():
		out.append(b.slice(0, n))
	return out


func _avec_octet_en_plus(b: PackedByteArray) -> PackedByteArray:
	var out := b.duplicate()
	out.append(0)
	return out


func test_resultat_aller_retour_pour_chaque_genre_et_chaque_code() -> void:
	for genre: int in range(Protocole.Intention.ACHETER, Protocole.Intention.SKIN + 1):
		if genre == Protocole.Intention.VENDRE_RETIREE:
			continue  # numéro réservé et refusé (test_fin_de_la_vente.gd)
		for code: int in range(Types.Resultat.OK, Types.Resultat.ARMES_AU_MAXIMUM + 1):
			var b := Protocole.encoder_resultat(genre, code)
			verifier_egal(b.size(), 3, "message compact")
			verifier_egal(Protocole.type_de(b), Protocole.Msg.RESULTAT)
			verifier_egal(Protocole.decoder_resultat(b), {"genre": genre, "code": code})


func test_resultat_hors_bornes_n_est_pas_encode() -> void:
	for genre: int in [-1, 0, Protocole.Intention.SKIN + 1, 255, 1 << 20]:
		verifier(Protocole.encoder_resultat(genre, 0).is_empty(), "genre %d" % genre)
	for code: int in [-1, Types.Resultat.ARMES_AU_MAXIMUM + 1, 255, 1 << 20]:
		verifier(Protocole.encoder_resultat(1, code).is_empty(), "code %d" % code)


func test_resultat_decodage_defensif() -> void:
	var valide := Protocole.encoder_resultat(Protocole.Intention.ACHETER, Types.Resultat.OK)
	verifier_egal(Protocole.decoder_resultat(PackedByteArray()), {})
	for b in _troncatures(valide):
		verifier_egal(Protocole.decoder_resultat(b), {}, "taille %d" % b.size())
	verifier_egal(Protocole.decoder_resultat(_avec_octet_en_plus(valide)), {}, "octet en trop")
	for t: int in [0, Protocole.Msg.REFUS, Protocole.Msg.INTENTION, 8, 255]:
		var autre := valide.duplicate()
		autre[0] = t
		verifier_egal(Protocole.decoder_resultat(autre), {}, "type %d" % t)
	for genre: int in [0, Protocole.Intention.SKIN + 1, 255]:
		var mauvais := valide.duplicate()
		mauvais[1] = genre
		verifier_egal(Protocole.decoder_resultat(mauvais), {}, "genre %d" % genre)
	for code: int in [Types.Resultat.ARMES_AU_MAXIMUM + 1, 255]:
		var mauvais := valide.duplicate()
		mauvais[2] = code
		verifier_egal(Protocole.decoder_resultat(mauvais), {}, "code %d" % code)


func test_resultat_fuzz_a_graine_fixe_ne_leve_jamais_d_erreur() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var acceptes := 0
	for i: int in 2000:
		var b := PackedByteArray()
		b.resize(rng.randi_range(0, 6))
		for k: int in b.size():
			b[k] = rng.randi() % 256
		if not b.is_empty() and i % 2 == 0:
			b[0] = Protocole.Msg.RESULTAT
		if i % 4 == 0:
			b = PackedByteArray([Protocole.Msg.RESULTAT, rng.randi() % 12, rng.randi() % 12])
		var d := Protocole.decoder_resultat(b)
		if not d.is_empty():
			acceptes += 1
			verifier_egal(b.size(), 3, "un résultat accepté a la bonne taille")
			verifier(int(d["code"]) <= Types.Resultat.ARMES_AU_MAXIMUM)
	verifier(acceptes > 0, "le fuzz atteint aussi des paquets valides")


func test_65536_octets_de_bruit_ne_donnent_jamais_de_resultat() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var bruit := PackedByteArray()
	bruit.resize(65536)
	for i in bruit.size():
		bruit[i] = rng.randi() % 256
	bruit[0] = Protocole.Msg.RESULTAT
	verifier_egal(Protocole.decoder_resultat(bruit), {})
