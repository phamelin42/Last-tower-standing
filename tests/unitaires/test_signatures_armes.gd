extends CasDeTest
## Chaque arme a une signature qu'on reconnaît d'un coup d'œil : forme et couleur du projectile,
## traînée, impact et statut. Les listes viennent de `data/` et aucun effectif n'est figé (le
## catalogue grossit). Les armes du lot 9 entrent dans les données avant leur signature (T9.18) :
## d'ici là, une signature désigne toujours une arme qui existe, les 30 armes du lot 8 gardent la
## leur, et une arme sans signature retombe sur le rendu par type (`test_effets.gd`).

const ArmesLot8 := preload("res://tests/unitaires/armes_lot_8.gd")
const SignaturesLot8 := preload("res://tests/unitaires/signatures_lot_8.gd")
## Rang des types de dégâts dans `data/armes.json`.
const TYPE_SIEGE: int = 3
const TYPE_CHAOS: int = 4
## Effet de l'arme → marque de sa mécanique ; sinon la vulnérabilité, sinon rien.
const MARQUES_DES_EFFETS: Dictionary = {
	"tournant": "rayon_tournant",
	"zone_posee": "disque_au_sol",
	"bombe": "bombe",
	"invocation": "allie",
}

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


func test_chaque_signature_designe_une_arme_des_donnees() -> void:
	var donnees: PackedStringArray = _ids_donnees()
	for id: String in SignaturesArmes.ids():
		verifier(donnees.has(id), "signature orpheline : %s" % id)
		verifier(not SignaturesArmes.de(id).is_empty(), "signature de %s" % id)


## Les armes de siège et de chaos du lot 9 entrent dans les données avant leur signature (une
## autre tâche) : seules celles-là peuvent en manquer. Tranchantes, perçantes et magiques ont
## toutes la leur, et le test strict (une ligne par arme, ni plus ni moins) reviendra avec elles.
func test_toute_arme_sans_signature_est_de_siege_ou_de_chaos() -> void:
	var avec: PackedStringArray = SignaturesArmes.ids()
	for id: String in _ids_donnees():
		if avec.has(id):
			continue
		var type_degats: int = int((_donnees.armes[id] as Dictionary)["type_degats"])
		verifier(
			type_degats == TYPE_SIEGE or type_degats == TYPE_CHAOS,
			"%s (type %d) n'a pas de signature" % [id, type_degats]
		)
	for id: String in ArmesLot8.IDS:
		verifier(avec.has(id), "signature de %s perdue" % id)


func test_les_trente_signatures_du_lot_8_ne_changent_pas() -> void:
	verifier_egal(SignaturesLot8.LIGNES.size(), 30)
	for id: Variant in SignaturesLot8.LIGNES:
		var ligne: Array = SignaturesLot8.LIGNES[id]
		var s: Dictionary = SignaturesArmes.de(String(id))
		verifier_egal(s.get("projectile"), ligne[0], "%s : projectile" % id)
		verifier_egal(s.get("couleur"), SignaturesArmes.PALETTE[ligne[1]], "%s : couleur" % id)
		verifier_egal(s.get("trainee"), ligne[2], "%s : traînée" % id)
		verifier_egal(s.get("impact"), ligne[3], "%s : impact" % id)
		verifier_egal(s.get("statut"), ligne[4], "%s : statut" % id)
		verifier_egal(s.get("son"), "tir_" + String(id), "%s : son" % id)
		verifier_egal(s.get("marque"), "", "%s : marque" % id)


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
	for id: String in SignaturesArmes.ids():
		if not _donnees.armes.has(id):
			continue
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


func test_le_libelle_affiche_de_chaque_statut_a_ses_accents() -> void:
	var attendus: Dictionary = {
		"givre": "givre",
		"poison": "poison",
		"etourdissement": "étourdissement",
		"brulure": "brûlure",
		"vol_de_vie": "vol de vie",
		"vulnerabilite": "vulnérabilité",
		"malediction_toucher": "malédiction",
		"repoussement": "repoussement",
		"siphon": "siphon",
		"mana_au_coup": "mana au coup",
	}
	for statut: Variant in SignaturesArmes.STATUTS:
		verifier(attendus.has(statut), "libellé attendu manquant pour %s" % statut)
		var libelle: String = SignaturesArmes.libelle_statut(String(statut))
		verifier_egal(libelle, attendus.get(statut, ""))
		verifier(not libelle.contains("_"), "%s : identifiant affiché" % statut)
	verifier_egal(SignaturesArmes.libelle_statut("inconnu"), "")


func _marque_attendue(id: String) -> String:
	var arme: Dictionary = _donnees.armes[id]
	for effet: Variant in arme["effets"]:
		var kind: String = String((effet as Dictionary)["kind"])
		if MARQUES_DES_EFFETS.has(kind):
			return String(MARQUES_DES_EFFETS[kind])
	for statut: Variant in arme["statuts"]:
		if String((statut as Dictionary)["kind"]) == "vulnerabilite":
			return "vulnerabilite"
	return ""


func test_la_marque_correspond_a_la_mecanique_de_l_arme() -> void:
	var vues: Dictionary = {}
	for id: String in SignaturesArmes.ids():
		var marque: String = SignaturesArmes.de(id)["marque"]
		verifier_egal(marque, _marque_attendue(id), "%s : marque" % id)
		verifier(SignaturesArmes.MARQUES.has(marque), "%s : marque %s inconnue" % [id, marque])
		vues[marque] = true
	for marque: String in ["", "rayon_tournant", "disque_au_sol", "vulnerabilite"]:
		verifier(vues.has(marque), "aucune arme n'a la marque « %s »" % marque)


func test_les_nouveaux_statuts_ont_chacun_leur_forme_et_leur_libelle() -> void:
	for statut: String in [
		"vulnerabilite", "malediction_toucher", "repoussement", "siphon", "mana_au_coup"
	]:
		verifier(SignaturesArmes.STATUTS.has(statut), "%s : forme" % statut)
		verifier(SignaturesArmes.libelle_statut(statut) != "", "%s : libellé" % statut)
	var formes: Dictionary = {}
	for forme: Variant in SignaturesArmes.STATUTS.values():
		verifier(not formes.has(forme), "forme de statut en double : %s" % forme)
		formes[forme] = true


func test_seules_les_signatures_validees_sont_en_jeu() -> void:
	for id: Variant in SignaturesLot8.LIGNES:
		verifier(SignaturesArmes.en_jeu(String(id)), "%s : validée" % id)
	var proposees: int = 0
	for id: String in SignaturesArmes.ids():
		if not SignaturesLot8.LIGNES.has(id):
			verifier(not SignaturesArmes.en_jeu(id), "%s : seulement proposée" % id)
			proposees += 1
	verifier(proposees >= 27, "%d signatures proposées" % proposees)
	verifier(not SignaturesArmes.en_jeu("arme_qui_n_existe_pas"))
