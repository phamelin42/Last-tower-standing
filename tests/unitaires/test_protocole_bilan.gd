extends CasDeTest
## Protocole version 8 : le bilan de fin de partie. Tout octet vient d'un tiers : les paquets forgés
## rendent `{}`, jamais une exception.

const GRAINE := 20261127

var d: Donnees


func avant_chaque() -> void:
	d = AidesPartie.donnees()


func _bilan_reel() -> Dictionary:
	var p := AidesPartie.partie(d, 12, 1, 8.0)
	StrategiesJoueur.jouer(StrategiesJoueur.BONNE, p, d, 1, false)
	AidesPartie.pas(p, 600)
	return p.bilan_joueur(1)


func test_la_version_est_8_et_toutes_les_precedentes_sont_refusees() -> void:
	verifier(Protocole.VERSION >= 8, "BILAN existe depuis la version 8")
	for ancienne: int in range(1, Protocole.VERSION):
		var b := Protocole.encoder_bonjour("Phil", 42)
		b[1] = ancienne
		verifier_egal(Protocole.decoder_bonjour(b), {}, "version %d" % ancienne)
		verifier_egal(Protocole.version_bonjour(b), ancienne)
		var motif := Protocole.motif_version(ancienne)
		verifier(motif.contains(str(ancienne)) and motif.contains(str(Protocole.VERSION)), motif)
	verifier_non_nul(Protocole.decoder_bonjour(Protocole.encoder_bonjour("Phil", 42)))


func test_un_bilan_fait_l_aller_retour_sans_rien_perdre() -> void:
	var bilan := _bilan_reel()
	var b := Protocole.encoder_bilan(bilan)
	verifier_faux(b.is_empty())
	verifier_egal(b.size(), 3 + 8 * BilanPartie.noms().size())
	verifier_egal(Protocole.type_de(b), Protocole.Msg.BILAN)
	var relu := Protocole.decoder_bilan(b)
	verifier_egal(relu.size(), bilan.size())
	for nom: String in bilan:
		verifier_egal(float(relu[nom]), float(bilan[nom]), nom)


func test_un_grand_montant_d_or_reste_exact() -> void:
	var bilan := BilanPartie.new().a_dict()
	bilan["or_gagne_total"] = 123456789012.0
	bilan["pv_min_ratio"] = 0.123456789
	var relu := Protocole.decoder_bilan(Protocole.encoder_bilan(bilan))
	verifier_egal(relu["or_gagne_total"], 123456789012.0)
	verifier_egal(relu["pv_min_ratio"], 0.123456789)


func test_un_bilan_invalide_ne_s_encode_pas() -> void:
	var bon := BilanPartie.new().a_dict()
	verifier_faux(Protocole.encoder_bilan(bon).is_empty())
	verifier(Protocole.encoder_bilan({}).is_empty(), "vide")
	for nom: String in BilanPartie.noms():
		var manquant := bon.duplicate()
		manquant.erase(nom)
		verifier(Protocole.encoder_bilan(manquant).is_empty(), "sans %s" % nom)
		for mauvais: Variant in [NAN, INF, -1.0, "x"]:
			var faux := bon.duplicate()
			faux[nom] = mauvais
			verifier(Protocole.encoder_bilan(faux).is_empty(), "%s = %s" % [nom, mauvais])
	var en_trop := bon.duplicate()
	en_trop["inconnu"] = 1.0
	verifier(Protocole.encoder_bilan(en_trop).is_empty())


## Review Focus : aucun paquet forgé ne lève d'exception et chacun rend `{}`.
func test_le_bilan_aller_retour_et_paquets_forges() -> void:
	var b := Protocole.encoder_bilan(_bilan_reel())
	for n: int in b.size():
		verifier_egal(Protocole.decoder_bilan(b.slice(0, n)), {}, "tronqué à %d" % n)
	verifier_egal(Protocole.decoder_bilan(b + PackedByteArray([0])), {}, "octet en trop")
	var mauvais_type := b.duplicate()
	mauvais_type[0] = Protocole.Msg.ETAT_ARENE
	verifier_egal(Protocole.decoder_bilan(mauvais_type), {})
	var mauvais_compteur := b.duplicate()
	mauvais_compteur.encode_u16(1, BilanPartie.noms().size() + 1)
	verifier_egal(Protocole.decoder_bilan(mauvais_compteur), {}, "compteur forgé")
	for valeur: float in [NAN, INF, -INF, -1.0]:
		var forge := b.duplicate()
		forge.encode_double(3, valeur)
		verifier_egal(Protocole.decoder_bilan(forge), {}, "valeur %s forgée" % valeur)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	for _i: int in 2000:
		var bruit := PackedByteArray()
		bruit.resize(rng.randi_range(1, 600))
		for k: int in bruit.size():
			bruit[k] = rng.randi() % 256
		bruit[0] = Protocole.Msg.BILAN
		var relu := Protocole.decoder_bilan(bruit)
		verifier(relu.is_empty() or relu.size() == BilanPartie.noms().size())
	var plein := PackedByteArray()
	plein.resize(b.size())
	plein[0] = Protocole.Msg.BILAN
	plein.encode_u16(1, BilanPartie.noms().size())
	verifier_egal(Protocole.decoder_bilan(plein).size(), BilanPartie.noms().size(), "des zéros")


func test_les_autres_messages_ne_se_prennent_pas_pour_un_bilan() -> void:
	var etat := Protocole.encoder_etat_arene(VueArene.new(), PackedStringArray())
	verifier_egal(Protocole.decoder_bilan(etat), {})
	verifier_egal(Protocole.type_de(PackedByteArray([Protocole.Msg.BILAN + 1])), -1)
