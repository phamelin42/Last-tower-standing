extends CasDeTest
## Le catalogue d'armes du lot 9 (D18) : quinze armes par type de dégâts, réparties 1 commune,
## 6 peu communes, 6 rares et 2 épiques, avec les mécaniques que le plan impose à chaque type.
## Les cinq types sont terminés (T9.13 à T9.17) : boucle sur `Types.NOMS_TYPES`.

const RARETES: Array[String] = ["commune", "peu_commune", "rare", "epique"]
const REPARTITION: Array[int] = [1, 6, 6, 2]
const MANA_MAX_REFERENCE := 100.0
const PORTEES: Array[int] = [500, 750, 1000, 1250]

## Les dix communes d'origine : rendement (`Equilibrage.rendement`) mesuré par script aux prix
## d'avant le lot 9, avant toute modification du catalogue.
const RENDEMENT_AVANT: Dictionary = {
	"lame_de_fil": 0.478,
	"faucille_a_ressort": 0.434,
	"arbalete_de_bureau": 0.480,
	"chausse_trape": 0.433,
	"etincelle_runique": 0.481,
	"orbe_de_brume": 0.431,
	"bombarde_de_poche": 0.480,
	"petard_de_rempart": 0.432,
	"de_pipe": 0.478,
	"sablier_fele": 0.432,
}

## Mécaniques imposées parmi les nouvelles armes de chaque type : [clé, genre, nom]. Genre :
## `effet`, `statut` ou `champ` (champ facultatif de l'arme).
const MECANIQUES_IMPOSEES: Dictionary = {
	"tranchant":
	[
		["M1", "vulnerabilite_du_type", ""],
		["M2", "statut", "malediction_toucher"],
		["M7", "effet", "tournant"],
		["M10", "champ", "type_secondaire"],
	],
	"magique":
	[
		["M1", "vulnerabilite_du_type", ""],
		["M4", "statut", "mana_au_coup"],
		["M4", "statut", "siphon"],
		["M7", "effet", "tournant"],
		["M8", "effet", "zone_posee"],
	],
	"siège":
	[
		["M1", "vulnerabilite_du_type", ""],
		["M5", "champ", "degats_par_pv_max"],
		["M5", "champ", "degats_par_amelioration"],
		["M8", "effet", "zone_posee"],
		["M9", "effet", "bombe"],
	],
	"chaos":
	[
		["M1", "vulnerabilite_du_type", ""],
		["M2", "statut", "malediction_degats"],
		["M4", "siphon_de_vie", ""],
		["M5", "champ", "degats_par_niveau"],
		["M6", "effet", "invocation"],
	],
	"perçant":
	[
		["M1", "vulnerabilite_du_type", ""],
		["M3", "statut", "repoussement"],
		["M10", "champ", "type_secondaire"],
	],
}

var armes: Array = []


func avant_chaque() -> void:
	var brut: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/armes.json"))
	verifier(brut is Array, "armes.json doit contenir une liste")
	armes = brut if brut is Array else []


func _du_type(type_degats: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for arme: Dictionary in armes:
		if arme["type_degats"] == type_degats:
			res.append(arme)
	return res


func _nouvelles(type_degats: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for arme: Dictionary in _du_type(type_degats):
		if not RENDEMENT_AVANT.has(arme["id"]):
			res.append(arme)
	return res


func _forme(arme: Dictionary) -> String:
	var effets: Array = arme["effets"]
	return String((effets[0] as Dictionary)["kind"])


func _kinds_statuts(arme: Dictionary) -> PackedStringArray:
	var kinds := PackedStringArray()
	for statut: Dictionary in arme["statuts"]:
		kinds.append(String(statut["kind"]))
	kinds.sort()
	return kinds


func _porte(arme: Dictionary, genre: String, nom: String) -> bool:
	match genre:
		"effet":
			for effet: Dictionary in arme["effets"]:
				if effet["kind"] == nom:
					return true
		"statut":
			return _kinds_statuts(arme).has(nom)
		"champ":
			return arme.has(nom)
		"siphon_de_vie":
			for statut: Dictionary in arme["statuts"]:
				if statut["kind"] == "siphon" and statut["ressource"] == "vie":
					return true
		"vulnerabilite_du_type":
			for statut: Dictionary in arme["statuts"]:
				if (
					statut["kind"] == "vulnerabilite"
					and (
						String(statut.get("type_degats", arme["type_degats"]))
						== arme["type_degats"]
					)
				):
					return true
	return false


func test_la_cible_d18_quinze_armes_par_type_reparties_1_6_6_2() -> void:
	for type_degats in Types.NOMS_TYPES:
		var du_type := _du_type(type_degats)
		verifier_egal(du_type.size(), 15, "%s : nombre d'armes" % type_degats)
		for k in RARETES.size():
			var n := 0
			for arme in du_type:
				if arme["rarete"] == RARETES[k]:
					n += 1
			verifier_egal(n, REPARTITION[k], "%s : armes %s" % [type_degats, RARETES[k]])


func test_la_commune_conservee_est_la_moins_rentable_des_deux_d_origine() -> void:
	for type_degats in Types.NOMS_TYPES:
		var d_origine: Array[Dictionary] = []
		for arme in _du_type(type_degats):
			if RENDEMENT_AVANT.has(arme["id"]):
				d_origine.append(arme)
		verifier_egal(d_origine.size(), 2, "%s : deux communes d'origine" % type_degats)
		var plus_rentable := d_origine[0]
		var moins_rentable := d_origine[1]
		if (
			float(RENDEMENT_AVANT[plus_rentable["id"]])
			< float(RENDEMENT_AVANT[moins_rentable["id"]])
		):
			plus_rentable = d_origine[1]
			moins_rentable = d_origine[0]
		verifier_egal(moins_rentable["rarete"], "commune", "%s : commune conservée" % type_degats)
		verifier_egal(plus_rentable["rarete"], "peu_commune", "%s : commune promue" % type_degats)
		var plus_petit_prix := 1000000
		for arme in _du_type(type_degats):
			if arme["rarete"] == "peu_commune":
				plus_petit_prix = mini(plus_petit_prix, int(arme["prix"]))
		verifier(
			int(plus_rentable["prix"]) >= plus_petit_prix,
			"%s : la promue coûte %s" % [type_degats, plus_rentable["prix"]]
		)


func test_repartition_imposee_des_mecaniques_du_type() -> void:
	for type_degats in Types.NOMS_TYPES:
		var attendues: Array = MECANIQUES_IMPOSEES[type_degats]
		for mecanique: Array in attendues:
			var trouvee := false
			for arme in _nouvelles(type_degats):
				trouvee = trouvee or _porte(arme, String(mecanique[1]), String(mecanique[2]))
			verifier(trouvee, "%s : %s absente des nouvelles armes" % [type_degats, mecanique[0]])


func test_chaque_nouvelle_arme_agit_dans_une_arene() -> void:
	for type_degats in Types.NOMS_TYPES:
		for arme in _nouvelles(type_degats):
			var d := AidesPartie.donnees()
			var def: Dictionary = d.armes[arme["id"]]
			var e := Ennemis.new(d)
			var rng := RandomNumberGenerator.new()
			rng.seed = 4242
			var equipee := ArmeEquipee.new(def)
			var stats := StatsTour.new()
			var pv := 1.0e6
			var ids: Array[int] = []
			for k in 5:
				var pos := Vector2(200.0 + 25.0 * k, 40.0 * k - 80.0)
				ids.append(
					e.indice_de(e.ajouter(0, pos, pv, 0.0, 0.0, 40.0, 1.0, 1, Types.Armure.AUCUNE))
				)
			var bilan := Tir.Bilan.new()
			# Les zones, les bombes et les alliés vivent dans l'arène : sans eux, rien ne se pose.
			var lecture := Tir.Lecture.new()
			lecture.poses = Poses.new(d)
			lecture.allies = Allies.new(d)
			for pas in 100:
				Tir.avancer_arme(equipee, 0.05, stats, e, Vector2.ZERO, d, rng, 1.0, bilan, lecture)
				lecture.poses.avancer(0.05, e, stats, Vector2.ZERO, d, 1.0)
				lecture.allies.avancer(0.05, e, Vector2.ZERO)
			var perdu := 0.0
			for i in ids:
				perdu += pv - e.pv[i]
			verifier(perdu > 0.0, "%s n'inflige aucun dégât en 100 pas" % arme["id"])


func test_deux_armes_du_type_different_par_forme_statuts_mecanique_ou_portee() -> void:
	for type_degats in Types.NOMS_TYPES:
		var du_type := _du_type(type_degats)
		for i in du_type.size():
			for j in range(i + 1, du_type.size()):
				var a := du_type[i]
				var b := du_type[j]
				var identiques := (
					_forme(a) == _forme(b)
					and _kinds_statuts(a) == _kinds_statuts(b)
					and int(a["portee"]) == int(b["portee"])
					and a.has("type_secondaire") == b.has("type_secondaire")
				)
				verifier(not identiques, "%s et %s ont la même signature" % [a["id"], b["id"]])


func test_toute_nouvelle_arme_a_une_image_et_un_nom_original() -> void:
	var noms := PackedStringArray()
	for nom: String in NomsOrigine.lire():
		if not NomsOrigine.HOMOGRAPHES_FRANCAIS.has(nom):
			noms.append(nom)
	for type_degats in Types.NOMS_TYPES:
		for arme in _nouvelles(type_degats):
			var id: String = arme["id"]
			verifier(ImagesOffres.OFFRES.has(id), "%s : pas d'image" % id)
			verifier(
				FileAccess.file_exists(ImagesOffres.chemin_case(id)), "%s : case non composée" % id
			)
			verifier(String(arme["nom"]).length() > 0, "%s : nom vide" % id)
			verifier(String(arme["description"]).length() > 0, "%s : description vide" % id)
			var texte := String(arme["nom"]) + " " + String(arme["description"]) + " " + id
			verifier(
				NomsOrigine.trouver(texte, noms).is_empty(),
				"%s reprend un nom de la map d'origine" % id
			)
			verifier(PORTEES.has(int(arme["portee"])), "%s : portée hors palier" % id)


## Les quatre armes de mana du lot 8 gardent leurs champs : seul le prix de la promue change.
func test_les_armes_de_mana_du_lot_8_gardent_leurs_champs() -> void:
	var attendues: Dictionary = {
		"etincelle_runique": [30.3, 0.9, 0.08],
		"chaine_d_arcanes": [77.7, 1.4, 0.2],
		"nova_d_ambre": [247.0, 2.5, 0.6],
		"tempete_astrale": [372.3, 2.0, 0.9],
	}
	for id: String in attendues:
		var trouvee := false
		for arme: Dictionary in armes:
			if arme["id"] != id:
				continue
			trouvee = true
			var voulu: Array = attendues[id]
			verifier_proche(float(arme["degats"]), float(voulu[0]), 0.0001, "%s : dégâts" % id)
			verifier_proche(float(arme["recharge"]), float(voulu[1]), 0.0001, "%s : recharge" % id)
			verifier_proche(
				float(arme["degats_par_mana_max"]), float(voulu[2]), 0.0001, "%s : mana" % id
			)
		verifier(trouvee, "%s a disparu" % id)
	var avec_mana := 0
	for arme: Dictionary in armes:
		if arme.has("degats_par_mana_max"):
			avec_mana += 1
	verifier_egal(
		avec_mana, 4, "seules les quatre armes de mana du lot 8 ont des dégâts selon la mana"
	)


## Une zone posée qui frappe à chaque pas de simulation coûte trop cher (T9.7) : période minimale.
func test_toute_zone_posee_a_une_periode_d_au_moins_un_quart_de_seconde() -> void:
	var zones := 0
	for arme: Dictionary in armes:
		for effet: Dictionary in arme["effets"]:
			if effet["kind"] == "zone_posee":
				zones += 1
				verifier(
					float(effet["periode"]) >= 0.25,
					"%s : période %s sous 0,25 s" % [arme["id"], effet["periode"]]
				)
	verifier(zones >= 2, "au moins deux zones posées dans le catalogue")


func test_le_siege_a_deux_zones_posees_et_une_bombe_a_retardement_parmi_les_nouvelles() -> void:
	var zones := 0
	var bombes := 0
	for arme: Dictionary in _nouvelles("siège"):
		if _porte(arme, "effet", "zone_posee"):
			zones += 1
		if _porte(arme, "effet", "bombe"):
			bombes += 1
	verifier(zones >= 2, "siège : %d zones posées" % zones)
	verifier(bombes >= 1, "siège : %d bombes" % bombes)


func test_chaos_a_deux_invocations_parmi_les_nouvelles_armes() -> void:
	var n := 0
	for arme: Dictionary in _nouvelles("chaos"):
		if _porte(arme, "effet", "invocation"):
			n += 1
	verifier(n >= 2, "chaos : %d invocations" % n)


func test_la_cible_d18_est_75_armes_quinze_par_type_1_6_6_2_en_boucle_sur_les_cinq_types() -> void:
	verifier_egal(Types.NOMS_TYPES.size(), 5, "cinq types de dégâts")
	verifier_egal(armes.size(), 75, "75 armes au catalogue")
	for type_degats in Types.NOMS_TYPES:
		verifier_egal(_du_type(type_degats).size(), 15, "%s : quinze armes" % type_degats)


## M1 à M10 du lot 9 : chacune est portée par au moins une arme du catalogue.
func test_chaque_mecanique_est_portee_par_au_moins_une_arme() -> void:
	var mecaniques: Array = [
		["M1", "vulnerabilite_du_type", ""],
		["M2", "statut", "malediction_toucher"],
		["M2", "statut", "malediction_degats"],
		["M3", "statut", "repoussement"],
		["M4", "statut", "mana_au_coup"],
		["M4", "siphon_de_vie", ""],
		["M5", "champ", "degats_par_pv_max"],
		["M5", "champ", "degats_par_niveau"],
		["M5", "champ", "degats_par_amelioration"],
		["M6", "effet", "invocation"],
		["M7", "effet", "tournant"],
		["M8", "effet", "zone_posee"],
		["M9", "effet", "bombe"],
		["M10", "champ", "type_secondaire"],
	]
	for mecanique: Array in mecaniques:
		var trouvee := false
		for arme: Dictionary in armes:
			trouvee = trouvee or _porte(arme, String(mecanique[1]), String(mecanique[2]))
		verifier(trouvee, "%s (%s %s) n'est portée par aucune arme" % mecanique)


func test_les_pieges_d_origine_du_jeu_sont_toujours_la() -> void:
	for id: String in ["chausse_trape", "sablier_fele"]:
		var trouvee := false
		for arme: Dictionary in armes:
			if arme["id"] == id:
				trouvee = true
				verifier_egal(_forme(arme), "piege", "%s reste un piège" % id)
				verifier_egal(arme["rarete"], "commune", "%s reste commune" % id)
		verifier(trouvee, "%s a disparu" % id)
