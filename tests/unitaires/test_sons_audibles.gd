extends CasDeTest
## Phil n'entend plus rien (27/11) : chaque son du catalogue doit se résoudre, par le chemin du jeu
## (`CatalogueSons.flux`, puis un `AudioStreamPlayer` sur son bus), en un flux existant, d'une
## durée audible, et les bus de jeu ne doivent être ni coupés ni muets.

const DUREE_MIN_S := 0.05


func test_chaque_son_du_catalogue_est_un_vrai_fichier_audible() -> void:
	var ids := CatalogueSons.tous()
	verifier(ids.size() > 80, "catalogue trop court : %d" % ids.size())
	for identifiant: String in ids:
		# Musique d'ambiance reportée par Phil (25/11/2026) : silence de substitution voulu.
		if identifiant == CatalogueSons.AMBIANCE:
			continue
		verifier_faux(CatalogueSons.est_substitution(identifiant), identifiant + " : substitution")
		var flux := CatalogueSons.flux(identifiant)
		verifier_non_nul(flux, identifiant)
		if flux == null:
			continue
		verifier(
			flux.get_length() > DUREE_MIN_S,
			"%s : flux vide (%s s)" % [identifiant, flux.get_length()]
		)


func test_les_bus_de_jeu_ne_sont_ni_coupes_ni_muets() -> void:
	BusAudio.assurer_bus()
	for nom: String in [BusAudio.BUS_EFFETS, BusAudio.BUS_MUSIQUE]:
		var i := AudioServer.get_bus_index(nom)
		verifier(i >= 0, nom + " absent")
		verifier_faux(AudioServer.is_bus_mute(i), nom + " muet")
		verifier(
			AudioServer.get_bus_volume_db(i) > -30.0,
			"%s : %s dB" % [nom, AudioServer.get_bus_volume_db(i)]
		)
	verifier_faux(AudioServer.is_bus_mute(0), "bus Master muet")
	verifier(AudioServer.get_bus_volume_db(0) > -30.0, "Master trop bas")
