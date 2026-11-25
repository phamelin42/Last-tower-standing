extends CasDeTest
## Le volume général des réglages se retrouve sur le bus principal : à zéro, le jeu est muet ; à
## un, il sonne à son niveau d'origine. Les bus de musique et d'effets existent une seule fois.


func test_les_bus_musique_et_effets_existent_une_seule_fois() -> void:
	BusAudio.assurer_bus()
	BusAudio.assurer_bus()
	verifier_non_nul(AudioServer.get_bus_index(BusAudio.BUS_MUSIQUE), "bus musique présent")
	verifier_non_nul(AudioServer.get_bus_index(BusAudio.BUS_EFFETS), "bus effets présent")
	var compte := 0
	for i: int in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == BusAudio.BUS_EFFETS:
			compte += 1
	verifier_egal(compte, 1, "pas de doublon après deux appels")


func test_chaque_niveau_de_volume_regle_le_bus_principal() -> void:
	BusAudio.assurer_bus()
	for volume: float in [0.25, 0.5, 0.75, 1.0]:
		BusAudio.appliquer_volume(volume)
		verifier_proche(
			AudioServer.get_bus_volume_db(0),
			linear_to_db(volume),
			0.01,
			"volume %.2f" % volume,
		)
		verifier_faux(AudioServer.is_bus_mute(0), "volume %.2f non muet" % volume)


func test_volume_nul_coupe_le_son() -> void:
	BusAudio.assurer_bus()
	BusAudio.appliquer_volume(0.0)
	verifier(AudioServer.is_bus_mute(0), "volume zéro : bus muet")


func test_un_volume_hors_bornes_est_ramene_dans_ses_bornes() -> void:
	BusAudio.assurer_bus()
	BusAudio.appliquer_volume(3.0)
	verifier_proche(AudioServer.get_bus_volume_db(0), 0.0, 0.01, "au-dessus de un : pas de gain")
	BusAudio.appliquer_volume(-2.0)
	verifier(AudioServer.is_bus_mute(0), "négatif : muet")
