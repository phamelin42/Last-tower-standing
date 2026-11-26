extends CasDeTest
## Chaque arme a une signature qu'on reconnaît d'un coup d'œil : forme et couleur du projectile,
## traînée, impact et statut. Les listes viennent de `data/` : une arme ajoutée sans signature
## fait échouer ce test, et aucun effectif n'est figé (le catalogue grossit).

var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func _ids_donnees() -> PackedStringArray:
	var ids: PackedStringArray = []
	for id: Variant in _donnees.armes:
		ids.append(String(id))
	ids.sort()
	return ids


func _paires() -> Array[PackedStringArray]:
	var ids: PackedStringArray = SignaturesArmes.ids()
	var paires: Array[PackedStringArray] = []
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			paires.append(PackedStringArray([ids[i], ids[j]]))
	return paires


func test_chaque_arme_a_une_signature_et_il_n_y_en_a_pas_d_autre() -> void:
	var attendus: PackedStringArray = _ids_donnees()
	var table: PackedStringArray = SignaturesArmes.ids()
	table.sort()
	verifier_egal(table, attendus)
	for id: String in attendus:
		verifier(not SignaturesArmes.de(id).is_empty(), "signature de %s" % id)


func test_une_arme_inconnue_n_a_pas_de_signature() -> void:
	verifier_egal(SignaturesArmes.de("arme_qui_n_existe_pas"), {})
	verifier_egal(SignaturesArmes.de(""), {})


func test_deux_armes_n_ont_jamais_la_meme_signature() -> void:
	for paire: PackedStringArray in _paires():
		var a: Dictionary = SignaturesArmes.de(paire[0])
		var b: Dictionary = SignaturesArmes.de(paire[1])
		var meme: bool = (
			a["projectile"] == b["projectile"]
			and a["couleur"] == b["couleur"]
			and a["trainee"] == b["trainee"]
			and a["impact"] == b["impact"]
		)
		verifier(not meme, "%s et %s ont la même signature" % [paire[0], paire[1]])


func test_deux_armes_ne_partagent_jamais_la_forme_et_la_couleur_du_projectile() -> void:
	for paire: PackedStringArray in _paires():
		var a: Dictionary = SignaturesArmes.de(paire[0])
		var b: Dictionary = SignaturesArmes.de(paire[1])
		var meme: bool = a["projectile"] == b["projectile"] and a["couleur"] == b["couleur"]
		verifier(not meme, "%s et %s : même projectile et même couleur" % [paire[0], paire[1]])


func test_deux_armes_different_par_deux_elements_au_moins() -> void:
	for paire: PackedStringArray in _paires():
		var a: Dictionary = SignaturesArmes.de(paire[0])
		var b: Dictionary = SignaturesArmes.de(paire[1])
		var ecarts: int = 0
		for cle: String in SignaturesArmes.ELEMENTS:
			if a[cle] != b[cle]:
				ecarts += 1
		verifier(
			ecarts >= 2, "%s et %s ne diffèrent que par %d élément" % [paire[0], paire[1], ecarts]
		)


func test_les_elements_sont_pris_dans_la_grammaire() -> void:
	for id: String in SignaturesArmes.ids():
		var s: Dictionary = SignaturesArmes.de(id)
		verifier(SignaturesArmes.PROJECTILES.has(s["projectile"]), "%s : projectile" % id)
		verifier(SignaturesArmes.TRAINEES.has(s["trainee"]), "%s : traînée" % id)
		verifier(SignaturesArmes.IMPACTS.has(s["impact"]), "%s : impact" % id)
		verifier(SignaturesArmes.PALETTE.values().has(s["couleur"]), "%s : couleur" % id)
		verifier_egal(s["son"], "tir_" + id)


func test_les_signatures_restent_lisibles_au_zoom_le_plus_lointain() -> void:
	for id: String in SignaturesArmes.ids():
		var c: Color = SignaturesArmes.de(id)["couleur"]
		verifier(c.v >= 0.6, "%s : valeur %.2f trop sombre" % [id, c.v])
		verifier(c.s >= 0.25, "%s : saturation %.2f trop faible" % [id, c.s])
		verifier(c.a >= 0.8, "%s : opacité %.2f trop faible" % [id, c.a])


func test_les_couleurs_de_la_palette_se_distinguent_deux_a_deux() -> void:
	var noms: Array = SignaturesArmes.PALETTE.keys()
	for i: int in noms.size():
		for j: int in range(i + 1, noms.size()):
			var a: Color = SignaturesArmes.PALETTE[noms[i]]
			var b: Color = SignaturesArmes.PALETTE[noms[j]]
			var ecart: float = Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			verifier(ecart >= 0.2, "%s et %s trop proches (%.2f)" % [noms[i], noms[j], ecart])


func test_le_statut_de_la_signature_est_celui_de_l_arme_vol_de_vie_compris() -> void:
	var vus: Dictionary = {}
	for id: String in _ids_donnees():
		var kinds: Array[String] = []
		for statut: Variant in (_donnees.armes[id] as Dictionary)["statuts"]:
			kinds.append(String((statut as Dictionary)["kind"]))
		var s: String = SignaturesArmes.de(id)["statut"]
		if kinds.is_empty():
			verifier_egal(s, "")
		else:
			verifier(kinds.has(s), "%s : statut %s absent de %s" % [id, s, kinds])
			vus[s] = true
	verifier(vus.has("vol_de_vie"), "le vol de vie a au moins une arme à signaler")
	for statut: Variant in vus:
		verifier(SignaturesArmes.STATUTS.has(statut), "statut %s sans visuel" % statut)


func test_chaque_forme_se_dessine_et_aucune_n_est_vide() -> void:
	var noms: Array[String] = []
	noms.append_array(SignaturesArmes.PROJECTILES)
	noms.append_array(SignaturesArmes.IMPACTS)
	noms.append_array(SignaturesArmes.TRAINEES)
	for forme: Variant in SignaturesArmes.STATUTS.values():
		noms.append(String(forme))
	for nom: String in noms:
		var image: Image = FormesSignatures.image(nom)
		verifier_non_nul(image, nom)
		var plein: int = 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					plein += 1
		verifier(plein > 12, "forme %s presque vide (%d pixels)" % [nom, plein])


func test_les_formes_de_projectile_ne_se_ressemblent_pas() -> void:
	var empreintes: Dictionary = {}
	for nom: String in SignaturesArmes.PROJECTILES:
		var image: Image = FormesSignatures.image(nom)
		var cle: int = hash(image.get_data())
		verifier(not empreintes.has(cle), "%s dessiné comme %s" % [nom, empreintes.get(cle, "")])
		empreintes[cle] = nom


func test_la_grammaire_laisse_de_la_place_pour_soixante_quinze_armes() -> void:
	var paires: int = SignaturesArmes.PROJECTILES.size() * SignaturesArmes.PALETTE.size()
	verifier(paires >= 75, "%d paires forme × couleur" % paires)
	verifier(SignaturesArmes.PALETTE.size() >= 10, "dix couleurs au moins")
