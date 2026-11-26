extends CasDeTest
## Le contenu de la version 1 doit offrir au joueur de quoi bâtir des builds variés, rester
## original, et être équilibré par rareté. Ces tests lisent les JSON sans passer par `Donnees`
## (qui est testé à part dans `test_contenu_donnees.gd`).

const TYPES: Array[String] = ["tranchant", "perçant", "magique", "siège", "chaos"]
const RARETES: Array[String] = ["commune", "peu_commune", "rare", "epique"]
const KINDS_EFFET: Array[String] = [
	"cible_unique", "zone", "rebond", "onde", "barrage", "mine", "piege", "aura"
]
const KINDS_STATUT: Array[String] = ["poison", "brulure", "givre", "etourdissement", "vol_de_vie"]
const PORTEES: Array[int] = [500, 750, 1000, 1250]
const STATS: Array[String] = [
	"degats_type",
	"degats_global",
	"pv_max",
	"regen",
	"armure",
	"esquive",
	"epines",
	"critique_chance",
	"cadence",
	"tirs_multiples",
	"eclaboussure",
	"focalisation",
	"vol_de_vie_coup",
	"vol_de_vie_mort",
	"revenu_fixe",
	"revenu_croissant",
	"revenu_mult",
	"prime_mult",
	"bonus_elim",
	"relance_gratuite",
	"marche_noir",
]
const ARMURES: Array[String] = ["légère", "moyenne", "lourde", "fortifiée", "aucune"]
const LONGUEUR_MAX := 90
## Or de départ et revenu par période de 10 s au début de la partie (spec §5.2).
const OR_DEPART := 500
const REVENU_PERIODE := 20
## Marque de la map d’origine : aucun nom, aucune expression ne doit en venir.
const INTERDITS: Array[String] = [
	"warcraft",
	"blizzard",
	"tower survivors",
	"gold mine",
	"mine d’or",
	"shocker",
	"mortar",
	"mortier",
	"moonwell",
	"puits de lune",
	"ankh",
	"ankhs",
]

var armes: Array = []
var ameliorations: Array = []
var ennemis: Dictionary = {}


func avant_chaque() -> void:
	armes = _lire_tableau("res://data/armes.json")
	ameliorations = _lire_tableau("res://data/ameliorations.json")
	ennemis = _lire_dictionnaire("res://data/ennemis.json")


func _lire(chemin: String) -> Variant:
	var texte := FileAccess.get_file_as_string(chemin)
	return JSON.parse_string(texte)


func _lire_tableau(chemin: String) -> Array:
	var brut: Variant = _lire(chemin)
	verifier(brut is Array, "%s doit contenir une liste" % chemin)
	if brut is Array:
		var liste: Array = brut
		return liste
	return []


func _lire_dictionnaire(chemin: String) -> Dictionary:
	var brut: Variant = _lire(chemin)
	verifier(brut is Dictionary, "%s doit contenir un objet" % chemin)
	if brut is Dictionary:
		var dico: Dictionary = brut
		return dico
	return {}


func _armes_du_type(type_degats: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for arme: Dictionary in armes:
		if arme["type_degats"] == type_degats:
			res.append(arme)
	return res


func _mediane(valeurs: Array[float]) -> float:
	var triees := valeurs.duplicate()
	triees.sort()
	var n := triees.size()
	if n % 2 == 1:
		return triees[n / 2]
	return (float(triees[n / 2 - 1]) + float(triees[n / 2])) / 2.0


func _moyenne_rendement(liste: Array[Dictionary]) -> float:
	var somme := 0.0
	for arme in liste:
		somme += Equilibrage.rendement(arme)
	return somme / float(liste.size())


# --- Armes : couverture ---------------------------------------------------------------


func test_au_moins_vingt_cinq_armes() -> void:
	verifier(armes.size() >= 25, "%d armes" % armes.size())


func test_chaque_type_a_au_moins_cinq_armes_et_les_quatre_raretes() -> void:
	for type_degats in TYPES:
		var du_type := _armes_du_type(type_degats)
		verifier(du_type.size() >= 5, "%s : %d armes" % [type_degats, du_type.size()])
		for rarete in RARETES:
			var trouvee := false
			for arme in du_type:
				trouvee = trouvee or arme["rarete"] == rarete
			verifier(trouvee, "%s sans arme %s" % [type_degats, rarete])


func test_chaque_kind_d_effet_est_represente() -> void:
	for kind in KINDS_EFFET:
		var trouve := false
		for arme: Dictionary in armes:
			for effet: Dictionary in arme["effets"]:
				trouve = trouve or effet["kind"] == kind
		verifier(trouve, "aucune arme d’effet %s" % kind)


func test_chaque_kind_de_statut_est_represente() -> void:
	for kind in KINDS_STATUT:
		var trouve := false
		for arme: Dictionary in armes:
			for statut: Dictionary in arme["statuts"]:
				trouve = trouve or statut["kind"] == kind
		verifier(trouve, "aucune arme de statut %s" % kind)


func test_chaque_palier_de_portee_est_utilise_et_aucun_autre() -> void:
	for portee in PORTEES:
		var trouve := false
		for arme: Dictionary in armes:
			trouve = trouve or int(arme["portee"]) == portee
		verifier(trouve, "aucune arme de portée %d" % portee)
	for arme: Dictionary in armes:
		verifier(int(arme["portee"]) in PORTEES, "%s : portée %s" % [arme["id"], arme["portee"]])


func test_un_rebond_cible_entre_quatre_et_huit_ennemis() -> void:
	for arme: Dictionary in armes:
		for effet: Dictionary in arme["effets"]:
			if effet["kind"] == "rebond":
				var cibles := int(effet["cibles"])
				verifier(cibles >= 4 and cibles <= 8, "%s : %d cibles" % [arme["id"], cibles])


# --- Améliorations : couverture -------------------------------------------------------


func test_au_moins_trente_ameliorations() -> void:
	verifier(ameliorations.size() >= 30, "%d améliorations" % ameliorations.size())


func test_chaque_stat_du_schema_est_utilisee() -> void:
	for stat in STATS:
		var trouvee := false
		for amelioration: Dictionary in ameliorations:
			for effet: Dictionary in amelioration["effets"]:
				trouvee = trouvee or effet["stat"] == stat
		verifier(trouvee, "aucune amélioration de stat %s" % stat)


func test_aucune_stat_inconnue() -> void:
	for amelioration: Dictionary in ameliorations:
		for effet: Dictionary in amelioration["effets"]:
			verifier(
				String(effet["stat"]) in STATS, "%s : %s" % [amelioration["id"], effet["stat"]]
			)


func test_les_trois_categories_de_degats_sont_utilisees_et_chaque_type_est_servi() -> void:
	for categorie: String in ["A", "B", "C"]:
		var trouvee := false
		for amelioration: Dictionary in ameliorations:
			for effet: Dictionary in amelioration["effets"]:
				trouvee = trouvee or effet.get("categorie", "") == categorie
		verifier(trouvee, "aucune amélioration de catégorie %s" % categorie)
	for type_degats in TYPES:
		var trouve := false
		for amelioration: Dictionary in ameliorations:
			for effet: Dictionary in amelioration["effets"]:
				trouve = trouve or effet.get("type_degats", "") == type_degats
		verifier(trouve, "aucune amélioration de dégâts %s" % type_degats)


func test_les_quatre_raretes_existent_en_ameliorations() -> void:
	for rarete in RARETES:
		var trouvee := false
		for amelioration: Dictionary in ameliorations:
			trouvee = trouvee or amelioration["rarete"] == rarete
		verifier(trouvee, "aucune amélioration %s" % rarete)


# --- Identifiants, noms, textes ---------------------------------------------------------


func test_ids_uniques_et_en_snake_case_sur_armes_et_ameliorations() -> void:
	var regle := RegEx.create_from_string("^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
	var vus := {}
	for objet: Dictionary in armes + ameliorations:
		var id: String = objet["id"]
		verifier(regle.search(id) != null, "id hors snake_case : %s" % id)
		verifier_faux(vus.has(id), "id en double : %s" % id)
		vus[id] = true


func test_noms_uniques_et_non_vides() -> void:
	var vus := {}
	for objet: Dictionary in armes + ameliorations:
		var nom: String = objet["nom"]
		verifier(not nom.strip_edges().is_empty(), "nom vide : %s" % objet["id"])
		verifier_faux(vus.has(nom), "nom en double : %s" % nom)
		vus[nom] = true


func test_descriptions_non_vides_et_courtes() -> void:
	for objet: Dictionary in armes + ameliorations:
		var description: String = objet["description"]
		verifier(not description.strip_edges().is_empty(), "description vide : %s" % objet["id"])
		verifier(
			description.length() <= LONGUEUR_MAX,
			"%s : %d caractères" % [objet["id"], description.length()]
		)


func test_typographie_francaise_des_textes_visibles() -> void:
	var avant_ponctuation := RegEx.create_from_string("(?<!\\x{00A0})[:;?!]")
	var textes: Array[String] = []
	for objet: Dictionary in armes + ameliorations:
		textes.append(objet["nom"])
		textes.append(objet["description"])
	for famille: Dictionary in _familles():
		textes.append(famille["nom"])
	textes.append(ennemis["convoi"]["nom"])
	textes.append(ennemis["boss"]["nom"])
	for texte in textes:
		verifier(
			avant_ponctuation.search(texte) == null,
			"espace insécable manquante avant : ; ? ! dans « %s »" % texte
		)
		verifier_faux("'" in texte, "apostrophe droite dans « %s »" % texte)
		verifier_faux('"' in texte, "guillemet droit dans « %s »" % texte)
		verifier_faux(texte.begins_with(" ") or texte.ends_with(" "), "espace en bord : %s" % texte)


func test_la_typographie_detecte_une_espace_ordinaire_avant_deux_points() -> void:
	var avant_ponctuation := RegEx.create_from_string("(?<!\\x{00A0})[:;?!]")
	verifier(avant_ponctuation.search("Bonus : oui") != null)
	verifier(avant_ponctuation.search("Bonus : oui") == null)


func test_aucun_nom_de_la_map_d_origine() -> void:
	var textes: Array[String] = []
	for objet: Dictionary in armes + ameliorations:
		textes.append(String(objet["id"]) + " " + objet["nom"] + " " + objet["description"])
	for famille: Dictionary in _familles():
		textes.append(String(famille["id"]) + " " + famille["nom"])
	textes.append(String(ennemis["convoi"]["id"]) + " " + ennemis["convoi"]["nom"])
	textes.append(String(ennemis["boss"]["id"]) + " " + ennemis["boss"]["nom"])
	for texte in textes:
		var bas := texte.to_lower()
		for interdit in INTERDITS:
			verifier_faux(interdit in bas, "« %s » contient « %s »" % [texte, interdit])


# --- Ennemis -----------------------------------------------------------------------------


## Les familles telles que le jeu les dérive : un modèle et un palier de couleur (l'ordre est celui
## de `Donnees.familles`). Lues dans le JSON brut, sans passer par `Donnees`.
func _familles() -> Array[Dictionary]:
	var familles: Array[Dictionary] = []
	var paliers: Array = ennemis["paliers"]
	for m: Dictionary in ennemis["modeles"]:
		var noms: Array = m["noms"]
		for k: int in paliers.size():
			var p: Dictionary = paliers[k]
			(
				familles
				. append(
					{
						"id": "%s_%s" % [m["id"], p["id"]],
						"nom": noms[k],
						"armure": m["armure"],
						"portee_attaque": m["portee_attaque"],
						"vitesse": m["vitesse"],
						"pv": float(m["pv"]) * float(p["pv"]),
						"prime": float(m["prime"]) * float(p["prime"]),
					}
				)
			)
	return familles


func test_les_familles_couvrent_chaque_armure_et_comptent_des_modeles_a_distance() -> void:
	var modeles: Array = ennemis["modeles"]
	var paliers: Array = ennemis["paliers"]
	verifier_egal(_familles().size(), modeles.size() * paliers.size())
	for armure: String in ["légère", "moyenne", "lourde", "fortifiée", "aucune"]:
		var trouvee := false
		for modele: Dictionary in modeles:
			trouvee = trouvee or modele["armure"] == armure
		verifier(trouvee, "aucun modèle d’armure %s" % armure)
	for modele: Dictionary in modeles:
		verifier(
			String(modele["armure"]) in ARMURES, "%s : armure %s" % [modele["id"], modele["armure"]]
		)
	var a_distance := modeles.filter(func(m: Dictionary) -> bool: return m["portee_attaque"] > 60)
	verifier(a_distance.size() >= 1, "aucun modèle à distance")


func test_pv_vitesse_et_portee_different_d_un_modele_a_l_autre() -> void:
	for cle: String in ["pv", "vitesse", "portee_attaque"]:
		var vus := {}
		for modele: Dictionary in ennemis["modeles"]:
			var valeur: float = modele[cle]
			verifier_faux(vus.has(valeur), "%s en double : %s" % [cle, valeur])
			vus[valeur] = true


func test_les_pv_different_d_une_famille_a_l_autre() -> void:
	var vus := {}
	for famille: Dictionary in _familles():
		var pv: float = famille["pv"]
		verifier_faux(vus.has(pv), "%s : pv en double (%s)" % [famille["id"], pv])
		vus[pv] = true


func test_ids_d_ennemis_uniques_et_primes_positives() -> void:
	var vus := {}
	var tous: Array = _familles() + [ennemis["convoi"], ennemis["boss"]]
	for e: Dictionary in tous:
		verifier_faux(vus.has(e["id"]), "id d’ennemi en double : %s" % e["id"])
		vus[e["id"]] = true
		verifier(e["pv"] > 0 and e["vitesse"] > 0, "%s : pv ou vitesse nuls" % e["id"])
	for famille: Dictionary in _familles():
		verifier(famille["prime"] > 0, "%s sans prime" % famille["id"])


func test_le_convoi_ne_frappe_pas_et_rapporte_beaucoup() -> void:
	# Comparé aux primes de base des modèles : les paliers de couleur relèvent la prime d'une
	# famille, pas la valeur du convoi.
	var convoi: Dictionary = ennemis["convoi"]
	verifier_faux(convoi.has("degats"), "le convoi ne doit pas avoir de dégâts")
	for modele: Dictionary in ennemis["modeles"]:
		verifier(convoi["prime"] >= 10 * modele["prime"], "prime du convoi trop faible")


func test_le_boss_a_l_armure_boss_et_domine_les_familles() -> void:
	var boss: Dictionary = ennemis["boss"]
	verifier_egal(boss["armure"], "boss")
	for modele: Dictionary in ennemis["modeles"]:
		verifier(boss["pv"] > 10 * modele["pv"], "boss trop fragile face à %s" % modele["id"])


# --- Équilibrage -------------------------------------------------------------------------


func test_le_rendement_moyen_croit_strictement_avec_la_rarete_dans_chaque_type() -> void:
	for type_degats in TYPES:
		var du_type := _armes_du_type(type_degats)
		var precedent := 0.0
		for rarete in RARETES:
			var de_cette_rarete: Array[Dictionary] = []
			for arme in du_type:
				if arme["rarete"] == rarete:
					de_cette_rarete.append(arme)
			if de_cette_rarete.is_empty():
				continue
			var moyen := _moyenne_rendement(de_cette_rarete)
			verifier(
				moyen > precedent,
				(
					"%s : rendement %s (%.3f) pas au-dessus de la rareté précédente (%.3f)"
					% [type_degats, rarete, moyen, precedent]
				)
			)
			precedent = moyen


func test_aucune_arme_ne_sort_de_l_intervalle_un_quart_quatre_fois_la_mediane_du_type() -> void:
	for type_degats in TYPES:
		var du_type := _armes_du_type(type_degats)
		var rendements: Array[float] = []
		for arme in du_type:
			rendements.append(Equilibrage.rendement(arme))
		var mediane := _mediane(rendements)
		for arme in du_type:
			var r := Equilibrage.rendement(arme)
			verifier(
				r <= 4.0 * mediane, "%s trop puissante (%.3f / %.3f)" % [arme["id"], r, mediane]
			)
			verifier(r >= mediane / 4.0, "%s trop faible (%.3f / %.3f)" % [arme["id"], r, mediane])


func test_une_arme_commune_s_achete_des_le_depart() -> void:
	for type_degats in TYPES:
		for arme in _armes_du_type(type_degats):
			if arme["rarete"] == "commune":
				verifier(int(arme["prix"]) <= OR_DEPART, "%s coûte %s" % [arme["id"], arme["prix"]])


func test_une_epique_coute_plusieurs_minutes_de_revenu() -> void:
	var minutes_de_revenu := float(REVENU_PERIODE * 6)
	for objet: Dictionary in armes + ameliorations:
		if objet["rarete"] == "epique":
			verifier(
				float(objet["prix"]) >= 3.0 * minutes_de_revenu,
				"%s ne coûte que %s" % [objet["id"], objet["prix"]]
			)


func test_le_prix_moyen_croit_avec_la_rarete_pour_les_armes_et_les_ameliorations() -> void:
	for liste: Array in [armes, ameliorations]:
		var precedent := 0.0
		for rarete in RARETES:
			var somme := 0.0
			var n := 0
			for objet: Dictionary in liste:
				if objet["rarete"] == rarete:
					somme += float(objet["prix"])
					n += 1
			verifier(n > 0, "aucun objet %s" % rarete)
			if n == 0:
				continue
			verifier(somme / n > precedent, "prix moyen %s pas croissant" % rarete)
			precedent = somme / n


func test_toute_arme_a_des_valeurs_de_combat_positives() -> void:
	for arme: Dictionary in armes:
		var id: String = arme["id"]
		verifier(arme["degats"] > 0.0, "%s : dégâts" % id)
		verifier(arme["recharge"] > 0.0, "%s : recharge" % id)
		verifier(arme["prix"] > 0, "%s : prix" % id)
		verifier(String(arme["ciblage"]) in ["plus_proche", "plus_fort", "plus_faible"], id)
