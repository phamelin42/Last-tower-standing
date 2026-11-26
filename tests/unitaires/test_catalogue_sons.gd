extends CasDeTest
## Le catalogue de sons : chaque identifiant a un fichier attendu sous `assets/sons/`, et un
## fichier absent devient un silence de substitution : le jeu reste jouable sans le son.
## Chaque type de dégâts a son impact. Chaque arme de `data/armes.json` a son son de tir, et
## la liste des sons de tir est exactement celle des données.

## Le pack n'a aucune boucle de fond : l'ambiance reste un silence de substitution.
const SANS_FICHIER: Array[String] = [CatalogueSons.AMBIANCE]

const TYPES_DEGATS: Array[String] = ["tranchant", "percant", "magique", "siege", "chaos"]
const TAILLE_MAX_OCTETS: int = 80 * 1024

var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func test_chaque_son_a_un_identifiant_distinct() -> void:
	var vus: Dictionary = {}
	for identifiant: String in CatalogueSons.tous():
		verifier(not vus.has(identifiant), "identifiant en double : %s" % identifiant)
		vus[identifiant] = true
	verifier_egal(vus.size(), CatalogueSons.tous().size())


func test_chaque_son_pointe_vers_un_fichier_du_dossier_des_sons() -> void:
	for identifiant: String in CatalogueSons.tous():
		var chemin := CatalogueSons.chemin(identifiant)
		verifier(
			chemin.begins_with("res://assets/sons/"),
			"%s hors de assets/sons : %s" % [identifiant, chemin],
		)
		verifier(chemin.ends_with(".ogg"), "%s n'est pas un .ogg" % identifiant)


func test_un_son_absent_devient_un_silence_de_substitution() -> void:
	for identifiant: String in CatalogueSons.tous():
		var flux := CatalogueSons.flux(identifiant)
		verifier_non_nul(flux, "flux présent pour %s" % identifiant)


func test_un_identifiant_inconnu_donne_le_silence_sans_erreur() -> void:
	verifier_non_nul(CatalogueSons.flux("son_qui_n_existe_pas"), "silence de repli")
	verifier(CatalogueSons.est_substitution("son_qui_n_existe_pas"), "marqué comme substitution")


func test_chaque_son_du_catalogue_a_son_fichier_sauf_l_ambiance() -> void:
	for identifiant: String in CatalogueSons.tous():
		var attendu := SANS_FICHIER.has(identifiant)
		verifier_egal(
			CatalogueSons.est_substitution(identifiant),
			attendu,
			"%s : substitution inattendue (fichier manquant ?)" % identifiant,
		)


func _ids_armes() -> PackedStringArray:
	var ids: PackedStringArray = []
	for id: Variant in _donnees.armes:
		ids.append(String(id))
	return ids


func _empreinte(chemin: String) -> int:
	return hash(FileAccess.get_file_as_bytes(chemin))


## Lignes du tableau de `SOURCES.md` : identifiant (sans les accents graves) → fichier d'origine.
func _origines() -> Dictionary:
	var origines: Dictionary = {}
	var texte: String = FileAccess.get_file_as_string("res://assets/sons/SOURCES.md")
	for ligne: String in texte.split("\n"):
		if not ligne.begins_with("| `"):
			continue
		var colonnes: PackedStringArray = ligne.split("|")
		var identifiant: String = colonnes[1].strip_edges().trim_prefix("`").trim_suffix("`")
		var origine: String = colonnes[3].strip_edges().trim_prefix("`").trim_suffix("`")
		origines[identifiant] = {"dossier": colonnes[2].strip_edges(), "fichier": origine}
	return origines


func _ids_a_fichier() -> PackedStringArray:
	var ids: PackedStringArray = []
	for id: String in _ids_armes():
		ids.append(CatalogueSons.id_tir(id))
	for type: int in TYPES_DEGATS.size():
		ids.append(CatalogueSons.id_impact(type))
	return ids


func test_aucun_fichier_d_origine_n_est_utilise_deux_fois() -> void:
	var vus: Dictionary = {}
	var origines: Dictionary = _origines()
	for identifiant: Variant in origines:
		var cle: String = (
			"%s/%s" % [origines[identifiant]["dossier"], origines[identifiant]["fichier"]]
		)
		if cle.begins_with("—"):
			continue
		verifier(
			not vus.has(cle), "%s et %s : même origine %s" % [identifiant, vus.get(cle, ""), cle]
		)
		vus[cle] = identifiant


func test_chaque_type_de_degats_a_son_impact_et_les_cinq_sont_distincts() -> void:
	var empreintes: Dictionary = {}
	for type: int in TYPES_DEGATS.size():
		var son: String = CatalogueSons.id_impact(type)
		verifier_egal(son, "impact_" + TYPES_DEGATS[type])
		verifier_faux(CatalogueSons.est_substitution(son), "%s : fichier manquant" % son)
		var cle: int = _empreinte(CatalogueSons.chemin(son))
		verifier(not empreintes.has(cle), "%s identique à %s" % [son, empreintes.get(cle, "")])
		empreintes[cle] = son
		verifier(
			(
				_empreinte(CatalogueSons.chemin(son))
				!= _empreinte(CatalogueSons.chemin(CatalogueSons.IMPACT))
			),
			"%s identique au repli impact" % son,
		)


func test_un_tir_d_arme_inconnue_retombe_sur_le_son_tir() -> void:
	verifier_egal(CatalogueSons.id_tir("arme_qui_n_existe_pas"), CatalogueSons.TIR)
	verifier_egal(CatalogueSons.id_tir(""), CatalogueSons.TIR)


func test_un_type_de_degats_inconnu_retombe_sur_le_son_impact() -> void:
	verifier_egal(CatalogueSons.id_impact(-1), CatalogueSons.IMPACT)
	verifier_egal(CatalogueSons.id_impact(TYPES_DEGATS.size()), CatalogueSons.IMPACT)


func test_chaque_fichier_de_son_pese_moins_de_80_ko() -> void:
	for identifiant: String in CatalogueSons.tous():
		if CatalogueSons.est_substitution(identifiant):
			continue
		var octets: int = FileAccess.get_file_as_bytes(CatalogueSons.chemin(identifiant)).size()
		verifier(octets < TAILLE_MAX_OCTETS, "%s pèse %d octets" % [identifiant, octets])


func test_chaque_arme_du_catalogue_a_son_fichier_de_tir() -> void:
	for id: String in _ids_armes():
		var son: String = CatalogueSons.id_tir(id)
		verifier_egal(son, "tir_" + id)
		verifier(CatalogueSons.tous().has(son), "%s absent du catalogue" % son)
		verifier_faux(CatalogueSons.est_substitution(son), "%s : fichier manquant" % son)
		var octets: int = FileAccess.get_file_as_bytes(CatalogueSons.chemin(son)).size()
		verifier(octets > 2000, "%s : fichier vide ou presque (%d octets)" % [son, octets])
		var flux: AudioStream = CatalogueSons.flux(son)
		verifier(flux.get_length() > 0.1, "%s : silence (%f s)" % [son, flux.get_length()])


func test_deux_armes_n_ont_jamais_le_meme_fichier_ni_le_meme_fichier_d_origine() -> void:
	var origines: Dictionary = _origines()
	var ids: PackedStringArray = _ids_armes()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: String = CatalogueSons.id_tir(ids[i])
			var b: String = CatalogueSons.id_tir(ids[j])
			verifier(
				_empreinte(CatalogueSons.chemin(a)) != _empreinte(CatalogueSons.chemin(b)),
				"%s et %s : même fichier" % [a, b],
			)
			verifier(
				origines.has(a) and origines.has(b) and origines[a] != origines[b],
				"%s et %s : même fichier d'origine" % [a, b],
			)


func test_un_son_d_impact_n_est_jamais_un_son_de_tir() -> void:
	var origines: Dictionary = _origines()
	for type: int in TYPES_DEGATS.size():
		var impact: String = CatalogueSons.id_impact(type)
		for id: String in _ids_armes():
			var tir: String = CatalogueSons.id_tir(id)
			verifier(
				_empreinte(CatalogueSons.chemin(impact)) != _empreinte(CatalogueSons.chemin(tir)),
				"%s et %s : même fichier" % [impact, tir],
			)
			verifier(origines[impact] != origines[tir], "%s et %s : même origine" % [impact, tir])


func test_chaque_son_est_liste_dans_sources_md() -> void:
	var origines: Dictionary = _origines()
	for son: String in _ids_a_fichier():
		verifier(origines.has(son), "%s absent de SOURCES.md" % son)
		if origines.has(son):
			var fichier: String = origines[son]["fichier"]
			verifier(fichier.ends_with(".wav") or fichier.ends_with(".ogg"), "%s : origine" % son)


func test_la_liste_des_sons_de_tir_suit_les_donnees() -> void:
	var donnees: Array[String] = []
	for id: String in _ids_armes():
		donnees.append(id)
	var catalogue: Array[String] = []
	for id: String in CatalogueSons.ids_armes():
		catalogue.append(id)
	verifier_egal(catalogue, donnees, "ids_armes() diverge de data/armes.json")
	var tires: Array[String] = []
	for son: String in CatalogueSons.tous():
		if son.begins_with("tir_"):
			tires.append(son.trim_prefix("tir_"))
	verifier_egal(tires, donnees, "tous() diverge de data/armes.json")
