extends CasDeTest
## Fin de partie → profil → fichier (T11.4, B2, B4) : chaque poste évalue son bilan, un serveur
## dédié n'écrit rien, un profil d'une version plus récente n'est jamais écrasé.

var _d: Donnees = AidesPartie.donnees()


func apres_chaque() -> void:
	Sauvegarde.simuler_echec("")
	super.apres_chaque()


func _chemin() -> String:
	return dossier_temporaire().path_join("progression.json")


func _bilan(valeurs: Dictionary = {}) -> Dictionary:
	var b := BilanPartie.new().a_dict()
	b.merge(valeurs, true)
	return b


func test_la_fin_d_une_partie_est_enregistree_avec_ses_defis_et_ses_cumuls() -> void:
	var nouveaux := ProgressionLocale.enregistrer_fin(
		_bilan({"victoire": 1.0, "manche_atteinte": 45.0, "eliminations": 120.0}), 1, _d, _chemin()
	)
	verifier(nouveaux.has("siege_leve"))
	verifier(nouveaux.has("premier_rempart"))
	var profil := Sauvegarde.charger(_chemin())
	verifier(profil.defis_reussis.has("siege_leve"))
	verifier(profil.skins_debloques.has(_d.defis["siege_leve"]["skin"]))
	verifier_egal(profil.parties, 1)
	verifier_egal(profil.cumul_victoires, 1)
	verifier_egal(profil.cumul_eliminations, 120)


func test_un_defi_deja_reussi_n_est_pas_annonce_une_seconde_fois() -> void:
	var bilan := _bilan({"victoire": 1.0})
	verifier(ProgressionLocale.enregistrer_fin(bilan, 1, _d, _chemin()).has("siege_leve"))
	verifier_faux(ProgressionLocale.enregistrer_fin(bilan, 1, _d, _chemin()).has("siege_leve"))
	verifier_egal(Sauvegarde.charger(_chemin()).cumul_victoires, 2)


func test_un_serveur_dedie_n_ecrit_aucun_fichier() -> void:
	var nouveaux := ProgressionLocale.enregistrer_fin(
		_bilan({"victoire": 1.0}), 2, _d, _chemin(), true
	)
	verifier_egal(nouveaux.size(), 0)
	verifier_faux(FileAccess.file_exists(_chemin()))


func test_le_solo_valide_comme_le_multijoueur() -> void:
	var bilan := _bilan({"victoire": 1.0})
	for nb: int in [1, 2, 4]:
		DirAccess.remove_absolute(_chemin())
		verifier(
			ProgressionLocale.enregistrer_fin(bilan, nb, _d, _chemin()).has("siege_leve"), str(nb)
		)


func test_un_defi_multijoueur_demande_au_moins_deux_joueurs() -> void:
	var bilan := _bilan({"dernier_rempart": 1.0})
	verifier_faux(ProgressionLocale.enregistrer_fin(bilan, 1, _d, _chemin()).has("dernier_debout"))
	DirAccess.remove_absolute(_chemin())
	verifier(ProgressionLocale.enregistrer_fin(bilan, 2, _d, _chemin()).has("dernier_debout"))


func test_un_enregistrement_qui_echoue_n_annonce_rien_et_ne_perd_rien() -> void:
	ProgressionLocale.enregistrer_fin(_bilan({"manche_atteinte": 3.0}), 1, _d, _chemin())
	Sauvegarde.simuler_echec("renommage")
	var nouveaux := ProgressionLocale.enregistrer_fin(_bilan({"victoire": 1.0}), 1, _d, _chemin())
	Sauvegarde.simuler_echec("")
	verifier_egal(nouveaux.size(), 0)
	var profil := Sauvegarde.charger(_chemin())
	verifier_egal(profil.parties, 1)
	verifier_faux(profil.defis_reussis.has("siege_leve"))


func test_un_fichier_d_une_version_plus_recente_n_est_jamais_ecrase() -> void:
	var f := FileAccess.open(_chemin(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": Sauvegarde.VERSION + 1, "inconnu": true}))
	f.close()
	var avant := FileAccess.get_file_as_string(_chemin())
	var nouveaux := ProgressionLocale.enregistrer_fin(_bilan({"victoire": 1.0}), 1, _d, _chemin())
	verifier_egal(nouveaux.size(), 0)
	verifier_egal(FileAccess.get_file_as_string(_chemin()), avant)


func test_sans_bilan_ni_donnees_il_ne_se_passe_rien() -> void:
	verifier_egal(ProgressionLocale.enregistrer_fin({}, 1, _d, _chemin()).size(), 0)
	verifier_egal(ProgressionLocale.enregistrer_fin(_bilan(), 1, null, _chemin()).size(), 0)
	verifier_faux(FileAccess.file_exists(_chemin()))
