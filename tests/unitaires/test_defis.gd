extends CasDeTest
## Défis : un bilan au seuil réussit chacun, un bilan juste en dessous non ; chaque défi
## débloque son skin ; un défi ne se valide qu'une fois (T11.4, `docs/defis.md`).

var _d: Donnees = AidesPartie.donnees()


## Valeur d'un compteur de profil que `Profil.ajouter_bilan` fait grimper tout seul à chaque partie
## multijoueur d'un bilan nul.
func _ajout_automatique(compteur: String) -> int:
	return 1 if compteur == "parties" or compteur == "cumul_parties_multijoueur" else 0


## Bilan nul et profil vide ajustés pour que la condition de `defi` tienne juste (`au_seuil`) ou
## qu'elle manque son premier terme chiffré d'une unité.
func _cas(defi: Dictionary, au_seuil: bool) -> Dictionary:
	var bilan := BilanPartie.new().a_dict()
	var profil := Profil.new()
	var viole := false
	var termes: Array[Dictionary] = []
	termes.assign(defi["termes"] as Array)
	for terme: Dictionary in termes:
		if not terme.has("valeur"):
			continue
		var cible := float(terme["valeur"]) + _ecart(String(terme["op"]), au_seuil or viole)
		viole = true
		_poser(String(terme["compteur"]), cible, bilan, profil)
	for terme: Dictionary in termes:
		if terme.has("autre"):
			bilan[terme["compteur"]] = bilan[terme["autre"]]
	return {"bilan": bilan, "profil": profil}


## Décalage de la valeur d'un terme : juste de quoi le tenir, ou de quoi le manquer d'une unité.
static func _ecart(op: String, tenir: bool) -> float:
	match op:
		">":
			return 1.0 if tenir else 0.0
		"<":
			return -1.0 if tenir else 0.0
		"≥":
			return 0.0 if tenir else -1.0
		_:
			return 0.0 if tenir else 1.0


func _poser(compteur: String, valeur: float, bilan: Dictionary, profil: Profil) -> void:
	if DonneesProgression.COMPTEURS_PROFIL.has(compteur):
		var courant := int(valeur) - _ajout_automatique(compteur)
		profil.set(compteur, maxi(courant, 0))
	else:
		bilan[compteur] = valeur


func _evaluer(defi: Dictionary, au_seuil: bool) -> Array[String]:
	var cas := _cas(defi, au_seuil)
	return Defis.evaluer(cas["bilan"], cas["profil"], _d, true)


func test_chaque_defi_se_reussit_avec_un_bilan_qui_remplit_sa_condition_et_pas_sans() -> void:
	verifier(_d.defis.size() > 0)
	for id: String in _d.defis:
		var defi: Dictionary = _d.defis[id]
		verifier(_evaluer(defi, true).has(id), "%s se réussit au seuil" % id)
		verifier_faux(_evaluer(defi, false).has(id), "%s échoue juste en dessous" % id)


func test_un_defi_deja_reussi_n_est_jamais_valide_deux_fois() -> void:
	for id: String in _d.defis:
		var cas := _cas(_d.defis[id], true)
		var profil: Profil = cas["profil"]
		verifier(Defis.evaluer(cas["bilan"], profil, _d, true).has(id))
		var skins := profil.skins_debloques.size()
		profil.set("cumul_parties_multijoueur", 0)
		verifier_faux(Defis.evaluer(cas["bilan"], profil, _d, true).has(id), "%s : une fois" % id)
		verifier_egal(profil.skins_debloques.size(), skins, "%s : skin une fois" % id)
		verifier_egal(profil.defis_reussis.count(id), 1)


func test_reussir_un_defi_debloque_son_skin_et_seulement_celui_la() -> void:
	for id: String in _d.defis:
		var cas := _cas(_d.defis[id], true)
		var profil: Profil = cas["profil"]
		var reussis := Defis.evaluer(cas["bilan"], profil, _d, true)
		verifier(profil.skins_debloques.has(_d.defis[id]["skin"]), "%s : son skin" % id)
		verifier_egal(profil.skins_debloques.size(), reussis.size(), "%s : un skin par défi" % id)
		for autre: String in reussis:
			verifier(profil.skins_debloques.has(_d.defis[autre]["skin"]))


func test_chaque_defi_debloque_un_skin_et_chaque_skin_a_un_defi() -> void:
	var skins: Dictionary = {}
	for id: String in _d.defis:
		var skin: String = _d.defis[id]["skin"]
		verifier(not skin.is_empty() and skin != "defaut", "%s : un vrai skin" % id)
		verifier_faux(skins.has(skin), "%s : skin %s déjà pris" % [id, skin])
		skins[skin] = id
	verifier_egal(skins.size(), _d.defis.size())


func test_aucun_defi_ne_cite_un_compteur_absent_du_bilan() -> void:
	var connus := DonneesProgression.compteurs_connus()
	for id: String in _d.defis:
		var termes: Array[Dictionary] = []
		termes.assign(_d.defis[id]["termes"] as Array)
		verifier(termes.size() > 0, "%s : une condition" % id)
		for terme: Dictionary in termes:
			verifier(connus.has(terme["compteur"]), "%s cite %s" % [id, terme["compteur"]])
			if terme.has("autre"):
				verifier(connus.has(terme["autre"]), "%s cite %s" % [id, terme["autre"]])


func test_un_defi_cumule_se_valide_apres_plusieurs_parties_et_pas_avant() -> void:
	var vus := 0
	for id: String in _d.defis:
		var termes: Array[Dictionary] = []
		termes.assign(_d.defis[id]["termes"] as Array)
		var cumule := false
		for terme: Dictionary in termes:
			cumule = cumule or DonneesProgression.COMPTEURS_PROFIL.has(terme["compteur"])
		if not cumule:
			continue
		vus += 1
		var cas := _cas(_d.defis[id], true)
		var profil: Profil = cas["profil"]
		# La partie qui manquait : le profil est un cran en dessous de la fin de la série.
		verifier(Defis.evaluer(cas["bilan"], profil, _d, true).has(id), "%s à la dernière" % id)
		var avant := _cas(_d.defis[id], false)
		verifier_faux(
			Defis.evaluer(avant["bilan"], avant["profil"], _d, true).has(id), "%s trop tôt" % id
		)
	verifier(vus >= 8, "les défis cumulés sont testés")


func test_chaque_defi_uniquement_ne_se_valide_que_si_toutes_les_armes_achetees_ont_la_classe(
) -> void:
	var vus := 0
	for id: String in _d.defis:
		if not id.begins_with("seul_"):
			continue
		vus += 1
		var cas := _cas(_d.defis[id], true)
		var bilan: Dictionary = cas["bilan"]
		verifier(Defis.evaluer(bilan, cas["profil"], _d, false).has(id), "%s : toutes" % id)
		bilan["armes_achetees"] = float(bilan["armes_achetees"]) + 1.0
		verifier_faux(
			Defis.evaluer(bilan, Profil.new(), _d, false).has(id), "%s : une de trop" % id
		)
		bilan["armes_achetees"] = 0.0
		for cle: String in bilan:
			if cle.begins_with("armes_type_") or cle.begins_with("armes_genre_"):
				bilan[cle] = 0.0
			if cle.begins_with("armes_statut_"):
				bilan[cle] = 0.0
		verifier_faux(Defis.evaluer(bilan, Profil.new(), _d, false).has(id), "%s : aucune" % id)
	verifier(vus >= 19, "les défis « uniquement » sont testés")


func test_un_defi_multijoueur_ne_se_valide_pas_en_solo() -> void:
	var vus := 0
	for id: String in _d.defis:
		if _d.defis[id]["mode"] != "multijoueur":
			continue
		vus += 1
		var cas := _cas(_d.defis[id], true)
		verifier_faux(Defis.evaluer(cas["bilan"], cas["profil"], _d, false).has(id), id)
		var cas2 := _cas(_d.defis[id], true)
		verifier(Defis.evaluer(cas2["bilan"], cas2["profil"], _d, true).has(id), id)
	verifier(vus >= 2)


func test_le_solo_valide_comme_le_multijoueur_un_defi_des_deux_modes() -> void:
	var vus := 0
	for id: String in _d.defis:
		if _d.defis[id]["mode"] != "les_deux" or id == "compagnon_de_table":
			continue
		vus += 1
		var cas := _cas(_d.defis[id], true)
		verifier(Defis.evaluer(cas["bilan"], cas["profil"], _d, false).has(id), id)
	verifier(vus > 30)


func test_deux_joueurs_valident_chacun_leur_defi() -> void:
	var a := BilanPartie.new().a_dict()
	a["victoire"] = 1.0
	var b := BilanPartie.new().a_dict()
	var profil_a := Profil.new()
	var profil_b := Profil.new()
	verifier(Defis.evaluer(a, profil_a, _d, true).has("siege_leve"))
	verifier_faux(Defis.evaluer(b, profil_b, _d, true).has("siege_leve"))
	verifier_faux(profil_b.defis_reussis.has("siege_leve"))
