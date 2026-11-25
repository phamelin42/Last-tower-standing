extends CasDeTest
## Le jeton d'hôte dans le bonjour (protocole version 4) : 0 ou 8 octets, tout le reste est refusé.

const NOM_24 := "Ælfwyn Müller-Østerga日本語"
const JETON := [1, 2, 3, 4, 5, 6, 7, 8]


func _troncatures(b: PackedByteArray) -> Array[PackedByteArray]:
	var liste: Array[PackedByteArray] = []
	for n in b.size():
		liste.append(b.slice(0, n))
	return liste


func _avec_octet_en_plus(b: PackedByteArray) -> PackedByteArray:
	var c := b.duplicate()
	c.append(0)
	return c


func _jeton_de(n: int) -> PackedByteArray:
	var j := PackedByteArray()
	for i: int in n:
		j.append(0xA0 + i)
	return j


func test_la_version_du_protocole_est_4() -> void:
	verifier_egal(Protocole.VERSION, 4)


func test_bonjour_sans_jeton_donne_un_jeton_vide() -> void:
	var d := Protocole.decoder_bonjour(Protocole.encoder_bonjour("Phil", 42))
	verifier_egal(d.get("nom"), "Phil")
	verifier_egal(d.get("jeton"), PackedByteArray())


func test_bonjour_porte_un_jeton_de_8_octets_aller_retour() -> void:
	var jeton := PackedByteArray(JETON)
	for nom: String in ["", "Phil", NOM_24]:
		var d := Protocole.decoder_bonjour(Protocole.encoder_bonjour(nom, -5, jeton))
		verifier_egal(d.get("jeton"), jeton, "nom « %s »" % nom)
		verifier_egal(d.get("empreinte"), -5)


func test_bonjour_dont_le_jeton_n_a_pas_0_ou_8_octets_est_refuse() -> void:
	for n: int in range(1, 12):
		var b := Protocole.encoder_bonjour("Phil", 1, _jeton_de(n))
		if n == Protocole.JETON_OCTETS:
			verifier(not Protocole.decoder_bonjour(b).is_empty(), "8 octets")
		else:
			verifier_egal(Protocole.decoder_bonjour(b), {}, "jeton de %d octets" % n)


func test_bonjour_avec_jeton_tronque_a_chaque_octet_est_refuse() -> void:
	var valide := Protocole.encoder_bonjour(NOM_24, 99, PackedByteArray(JETON))
	for b in _troncatures(valide):
		verifier_egal(Protocole.decoder_bonjour(b), {}, "taille %d" % b.size())
	verifier_egal(Protocole.decoder_bonjour(_avec_octet_en_plus(valide)), {}, "octet en trop")


func test_un_bonjour_de_version_2_ou_3_recoit_le_refus_de_version() -> void:
	# 3 : le format de T5.3b, sans jeton dans le bonjour.
	for ancienne: int in [2, 3]:
		var b := Protocole.encoder_bonjour("Phil", 42)
		b[1] = ancienne
		verifier_egal(Protocole.decoder_bonjour(b), {}, "version %d" % ancienne)
		verifier_egal(Protocole.version_bonjour(b), ancienne)
		var motif := Protocole.motif_version(ancienne)
		verifier(motif.contains(str(ancienne)) and motif.contains("4"), motif)
