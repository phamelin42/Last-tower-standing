extends CasDeTest
## Repères d'arme (S25) : type de dégâts, mécanique et statuts se lisent d'un coup d'œil par une
## icône et un mot ; chaque valeur des données a son icône et son texte, rien de silencieux.

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _tous(groupe: String) -> Array[String]:
	match groupe:
		ReperesArme.GROUPE_TYPE:
			return Types.NOMS_TYPES
		ReperesArme.GROUPE_GENRE:
			return VueArene.GENRES_ARME.slice(1)
		_:
			return VueArene.STATUTS_ARME.slice(1)


func test_chaque_type_genre_et_statut_a_son_icone_et_son_texte() -> void:
	for groupe: String in ReperesArme.GROUPES:
		for id: String in _tous(groupe):
			verifier(ReperesArme.icone(groupe, id) != null, "%s %s : icône chargée" % [groupe, id])
			var mot := ReperesArme.texte(groupe, id)
			verifier(not mot.is_empty(), "%s %s : texte non vide" % [groupe, id])
			var cle := str(ReperesArme.entree(groupe, id).get("texte", ""))
			verifier(mot != cle, "%s %s : %s est traduit" % [groupe, id, cle])


func test_les_donnees_ne_decrivent_que_des_valeurs_connues() -> void:
	for groupe: String in ReperesArme.GROUPES:
		var table: Dictionary = Assets.section("icones_offre").get(groupe, {})
		verifier_egal(
			table.size(), _tous(groupe).size(), "%s : autant d'icônes que de valeurs" % groupe
		)
		for id: String in table:
			verifier(id in _tous(groupe), "%s : %s est une valeur connue" % [groupe, id])


func test_chaque_arme_du_catalogue_montre_son_type_sa_mecanique_et_ses_statuts() -> void:
	for id: String in d.armes:
		var arme: Dictionary = d.armes[id]
		var reperes := ReperesArme.reperes(arme)
		var attendus := 1 + 1 + _statuts_distincts(arme)
		verifier_egal(reperes.size(), attendus, "%s : nombre de repères" % id)
		for repere: Dictionary in reperes:
			verifier(
				ReperesArme.icone(str(repere["groupe"]), str(repere["id"])) != null,
				"%s : icône de %s" % [id, repere]
			)
		var rangee := ReperesArme.creer_rangee(arme, "Test")
		verifier_egal(rangee.get_child_count(), attendus, "%s : une puce par repère" % id)
		rangee.free()


func _statuts_distincts(arme: Dictionary) -> int:
	var vus: Dictionary = {}
	for statut: Dictionary in arme.get("statuts", []):
		vus[str(statut["kind"])] = true
	return vus.size()


func test_chaque_puce_a_un_nom_en_infobulle_et_pour_les_lecteurs_d_ecran() -> void:
	for id: String in d.armes:
		var rangee := ReperesArme.creer_rangee(d.armes[id], "Test")
		for puce: Control in rangee.get_children():
			verifier(not puce.tooltip_text.is_empty(), "%s : infobulle de %s" % [id, puce.name])
			verifier_egal(puce.accessibility_name, puce.tooltip_text, "%s : nom accessible" % id)
			var groupe := str(puce.get_meta("groupe"))
			var mot := puce.find_child("Mot", false, false) as Label
			if groupe == ReperesArme.GROUPE_STATUT:
				verifier(
					mot == null, "%s : un statut est une icône seule, nommée en infobulle" % id
				)
			else:
				verifier(mot != null and mot.text == puce.tooltip_text, "%s : mot écrit" % id)
		rangee.free()


func test_la_ligne_courte_nomme_le_type_la_mecanique_et_les_statuts_dans_l_ordre() -> void:
	var arme := {
		"type_degats": "tranchant",
		"effets": [{"kind": "rebond"}, {"kind": "rebond"}],
		"statuts": [{"kind": "poison"}, {"kind": "poison"}, {"kind": "givre"}],
	}
	verifier_egal(
		ReperesArme.texte_court(arme), "Tranchant · Rebond · Poison · Givre", "ligne courte"
	)
	verifier_egal(ReperesArme.texte_court({}), "", "une arme sans donnée n'a pas de ligne")


func test_une_valeur_inconnue_ne_fait_ni_erreur_ni_puce() -> void:
	verifier(ReperesArme.icone("genres", "inconnu") == null, "pas d'icône")
	verifier_egal(ReperesArme.texte("genres", "inconnu"), "", "pas de texte")
	var rangee := ReperesArme.creer_rangee(
		{"type_degats": "inconnu", "effets": [{"kind": "x"}]}, "T"
	)
	verifier_egal(rangee.get_child_count(), 0, "aucune puce")
	rangee.free()
