extends CasDeTest
## Dans le menu, l'écran des réglages occupe sa vraie hauteur : le bouton « Retour » vient après
## le dernier champ, il ne se pose pas dessus.

var _locale_avant: String = ""


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")


func apres_chaque() -> void:
	TranslationServer.set_locale(_locale_avant)


func _menu_aux_reglages() -> MenuPrincipal:
	var menu := MenuPrincipal.new()
	arbre.root.add_child(menu)
	menu.configurer(dossier_temporaire().path_join("reglages.cfg"))
	menu._sur_reglages()
	return menu


func test_le_bouton_retour_ne_recouvre_aucune_commande_des_reglages() -> void:
	var menu := _menu_aux_reglages()
	await attendre_images(3)
	var retour := menu._bouton_retour.get_global_rect()
	var controles := menu._reglages.controles()
	verifier(controles.size() >= 6, "les commandes sont listées (%d)" % controles.size())
	for c: Control in controles:
		verifier_faux(
			retour.intersects(c.get_global_rect()),
			"« Retour » %s recouvre %s %s" % [retour, c.name, c.get_global_rect()]
		)
		verifier(
			c.get_global_rect().end.y <= retour.position.y,
			"%s est avant « Retour »" % c.get_class()
		)


func test_les_reglages_reservent_la_hauteur_de_leur_contenu() -> void:
	var menu := _menu_aux_reglages()
	await attendre_images(3)
	var hauteur := menu._reglages.get_combined_minimum_size().y
	var derniere := menu._reglages.controles().back() as Control
	verifier(
		hauteur >= derniere.get_global_rect().end.y - menu._reglages.get_global_rect().position.y,
		"hauteur minimale %.0f px sous le dernier champ" % hauteur
	)
