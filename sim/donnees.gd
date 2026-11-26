class_name Donnees
extends RefCounted
## Chargement et validation de `data/*.json`. Toute donnée invalide produit un message
## « fichier: chemin.du.champ: raison » et un `null`, jamais un plantage plus loin.
##
## Règles de lecture, volontairement strictes :
## - un nombre doit être un nombre JSON fini (« "30" », NaN et l'infini sont refusés) ;
## - un nom français (« perçant », « siège », « légère »…) s'écrit exactement comme dans
##   `Types` : sans accent, en majuscules ou avec une espace en trop, il est refusé ;
## - une clé inconnue est ignorée, une clé manquante ou mal typée est une erreur.

## Seul dossier où l'absence d'`armes.json`, `ameliorations.json` ou `ennemis.json` est une
## erreur. Tout autre dossier est un « dossier de test » : ces fichiers y valent des listes vides.
const DOSSIER_REEL := "res://data"
const FICHIERS_OBJET: Array[String] = [
	"partie.json",
	"economie.json",
	"difficulte.json",
	"efficacite.json",
	"boutique.json",
	"ennemis.json",
]
const FICHIERS_LISTE: Array[String] = ["armes.json", "ameliorations.json", "unites.json"]
const FICHIERS_OPTIONNELS_EN_TEST: Array[String] = [
	"armes.json", "ameliorations.json", "ennemis.json", "unites.json"
]
const PORTEES: Array[int] = [500, 750, 1000, 1250]
const CATEGORIES: Array[String] = ["A", "B", "C"]
const STATS_AMELIORATION: Array[String] = [
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
	"mana_max",
	"mana_regen",
	# Lot 9 : acceptées et cumulées dès T9.2, consommées par T9.10 à T9.12.
	"degats_classe",
	"etat_degats",
	"etat_duree",
	"degats_contre_etat",
	"epines_degats",
	"epines_croissantes",
	"epines_premier_coup",
	"epines_soin",
	"epines_reduction",
	"epines_statut",
	"pv_max_mult",
	"soin_pv_manquants",
	"degats_par_pv_max",
	"resurrection",
	"regen_croissante",
	"soin_periodique",
	"armure_croissante",
	"riposte_statut",
	"mana_max_mult",
	"mana_rupture_etourdit",
	"degats_tant_que_mana",
	"reduction_tant_que_mana",
	"revenu_contre_pv",
	"copie_prochaine_offre",
	"aura_mixte",
]
## Statistiques dont la valeur est un compteur entier (≥ 0).
const STATS_ENTIERES: Array[String] = [
	"tirs_multiples", "revenu_fixe", "relance_gratuite", "marche_noir", "resurrection"
]
## Statistiques « croissantes » : un `max` obligatoire borne leur croissance dans le temps.
const STATS_CROISSANTES: Array[String] = [
	"epines_croissantes", "regen_croissante", "armure_croissante"
]
## Statistiques qui portent une clé de dictionnaire : stat → [paramètre, noms acceptés].
const STATS_A_CLE: Dictionary = {
	"degats_classe": ["classe", ["onde", "portee_courte", "portee_longue", "commune"]],
	"etat_degats": ["etat", ["poison", "brulure"]],
	"etat_duree": ["etat", ["poison", "brulure", "etourdissement"]],
	"degats_contre_etat": ["etat", ["etourdi", "empoisonne", "ralenti"]],
	"epines_statut": ["statut", ["poison", "brulure", "givre", "etourdissement"]],
	"riposte_statut": ["statut", ["givre", "poison"]],
}
## Statistiques qui portent leurs propres paramètres au lieu d'une `valeur`.
const STATS_SANS_VALEUR: Array[String] = [
	"bonus_elim",
	"soin_periodique",
	"mana_rupture_etourdit",
	"revenu_contre_pv",
	"copie_prochaine_offre",
	"aura_mixte",
]
const MODELES_UNITES: Array[String] = ["guerrier", "archer", "paysan"]
const RESSOURCES_SIPHON: Array[String] = ["mana", "vie"]
const SENS_TOURNANT: Array[String] = ["horaire", "antihoraire"]

var partie: Dictionary
var economie: Dictionary
var difficulte: Dictionary
var boutique: Dictionary
## 5 × 6 de float, dans l'ordre de `Types.TypeDegats` puis `Types.Armure`.
var efficacite: Array
## id → dictionnaire normalisé (énumérations déjà converties en int).
var armes: Dictionary
var ameliorations: Dictionary
var familles: Array[Dictionary]
var convoi: Dictionary
var boss: Dictionary
## Tous les ids d'armes et d'améliorations, triés : l'index sert de numéro réseau.
var ids_catalogue: PackedStringArray
## id → fiche des unités invocables (`data/unites.json`), et leurs ids triés : l'index sert de
## numéro réseau.
var unites: Dictionary
var ids_unites: PackedStringArray
## Hash stable du contenu des fichiers (poignée de main réseau). Il porte sur le contenu lu,
## pas sur sa mise en forme : un fichier reformaté garde la même empreinte.
var empreinte: int

# --- Chargement --------------------------------------------------------------------------------


## Lit les huit fichiers de `dossier`. Renvoie `null` (et un `push_error` par problème) si
## un fichier est absent, illisible ou invalide.
static func charger(dossier: String = DOSSIER_REEL) -> Donnees:
	var brut: Dictionary = {}
	var erreurs: Array[String] = []
	var tout: Array[String] = FICHIERS_OBJET + FICHIERS_LISTE
	for nom in tout:
		var chemin := dossier.path_join(nom)
		if not FileAccess.file_exists(chemin):
			if dossier != DOSSIER_REEL and nom in FICHIERS_OPTIONNELS_EN_TEST:
				brut[nom] = _contenu_vide(nom)
			else:
				erreurs.append("%s: absent (dossier %s)" % [nom, dossier])
			continue
		var json := JSON.new()
		var code := json.parse(FileAccess.get_file_as_string(chemin))
		if code != OK:
			var raison := (
				"JSON invalide ligne %d : %s" % [json.get_error_line(), json.get_error_message()]
			)
			erreurs.append("%s: %s" % [nom, raison])
			continue
		brut[nom] = json.data
	if not erreurs.is_empty():
		for message in erreurs:
			push_error(message)
		return null
	return depuis_brut(brut)


## `brut` : nom de fichier → contenu déjà décodé. Renvoie `null` si `valider(brut)` n'est
## pas vide ; chaque message est alors journalisé.
static func depuis_brut(brut: Dictionary) -> Donnees:
	var messages := valider(brut)
	if not messages.is_empty():
		for message in messages:
			push_error(message)
		return null
	var d := Donnees.new()
	d.partie = _copie(brut["partie.json"])
	d.economie = _copie(brut["economie.json"])
	d.difficulte = _copie(brut["difficulte.json"])
	d.boutique = _copie(brut["boutique.json"])
	d.efficacite = _matrice(brut["efficacite.json"])
	var liste_armes: Array = brut["armes.json"]
	for entree: Variant in liste_armes:
		var arme := _normaliser_arme(entree)
		d.armes[arme["id"]] = arme
	var liste_amelios: Array = brut["ameliorations.json"]
	for entree: Variant in liste_amelios:
		var amelio := DonneesLot9.normaliser_amelioration(entree)
		d.ameliorations[amelio["id"]] = amelio
	var ids: Array[String] = []
	for id: String in d.armes:
		ids.append(id)
	for id: String in d.ameliorations:
		ids.append(id)
	ids.sort()
	d.ids_catalogue = PackedStringArray(ids)
	var liste_unites: Array = brut.get("unites.json", [])
	for entree: Variant in liste_unites:
		var unite := DonneesLot9.normaliser_unite(entree)
		d.unites[unite["id"]] = unite
	var ids_u: Array[String] = []
	for id: String in d.unites:
		ids_u.append(id)
	ids_u.sort()
	d.ids_unites = PackedStringArray(ids_u)
	var ennemis: Dictionary = brut["ennemis.json"]
	d.familles = DonneesEnnemis.construire_familles(ennemis)
	d.convoi = _copie(ennemis["convoi"])
	d.boss = _copie(ennemis["boss"])
	# Un jeu bâti à la main sans unités vaut un jeu à liste d'unités vide : même empreinte.
	var complet: Dictionary = brut.duplicate()
	if not complet.has("unites.json"):
		complet["unites.json"] = []
	d.empreinte = _empreinte(complet)
	return d


## Catégorie d'une offre (`Types.Categorie`) : une arme est toujours `ARME`, une amélioration porte
## la sienne dans les données ; -1 pour un identifiant inconnu.
func categorie_de(id: String) -> int:
	if armes.has(id):
		return Types.Categorie.ARME
	if ameliorations.has(id):
		var amelioration: Dictionary = ameliorations[id]
		return int(amelioration["categorie"])
	return -1


## Famille d'une amélioration (`Types.FAMILLES_AMELIORATION`) ; « » pour une arme ou un id inconnu.
func famille_de(id: String) -> String:
	if not ameliorations.has(id):
		return ""
	var amelioration: Dictionary = ameliorations[id]
	return String(amelioration["famille"])


## Dernier palier dont `manche` ≤ la manche demandée. Avant le premier palier (la préparation,
## manche 0), c'est le premier qui s'applique. Une table vide ou une clé absente est une
## erreur de programmation : journalisée, et 0.0 renvoyé.
func palier(table: Array, manche: int, cle: String) -> float:
	if table.is_empty():
		push_error("palier : table vide (clé « %s »)" % cle)
		return 0.0
	var retenu: Dictionary = table[0]
	for entree: Variant in table:
		var ligne: Dictionary = entree
		if int(ligne["manche"]) > manche:
			break
		retenu = ligne
	if not retenu.has(cle):
		push_error("palier : clé « %s » absente du palier" % cle)
		return 0.0
	return float(retenu[cle])


# --- Validation --------------------------------------------------------------------------------


## Renvoie les erreurs « fichier: chemin.du.champ: raison » ; vide si tout est valide.
static func valider(brut: Dictionary) -> PackedStringArray:
	var err: Array[String] = []
	var tout: Array[String] = FICHIERS_OBJET + FICHIERS_LISTE
	var presents: Dictionary = {}
	for nom in tout:
		if not brut.has(nom):
			# Un jeu de données bâti à la main peut ignorer les unités : liste vide.
			if nom != "unites.json":
				err.append("%s: absent du jeu de données" % nom)
			continue
		var contenu: Variant = brut[nom]
		if nom in FICHIERS_OBJET and not contenu is Dictionary:
			_err(err, nom, "racine", "attendu un objet, reçu %s" % _decrire(contenu))
			continue
		if nom in FICHIERS_LISTE and not contenu is Array:
			_err(err, nom, "racine", "attendu un tableau, reçu %s" % _decrire(contenu))
			continue
		presents[nom] = contenu
	if presents.has("partie.json"):
		_valider_partie(presents["partie.json"], err)
	if presents.has("economie.json"):
		_valider_economie(presents["economie.json"], err)
	if presents.has("difficulte.json"):
		_valider_difficulte(presents["difficulte.json"], err)
	if presents.has("efficacite.json"):
		_valider_efficacite(presents["efficacite.json"], err)
	if presents.has("boutique.json"):
		_valider_boutique(presents["boutique.json"], err)
	var ids: Dictionary = {}
	var ids_unites_valides: Dictionary = {}
	if presents.has("unites.json"):
		DonneesLot9.valider_unites(presents["unites.json"], ids_unites_valides, err)
	if presents.has("armes.json"):
		_valider_armes(presents["armes.json"], ids, err, ids_unites_valides)
	if presents.has("ameliorations.json"):
		_valider_ameliorations(presents["ameliorations.json"], ids, err)
	if presents.has("ennemis.json"):
		DonneesEnnemis.valider(presents["ennemis.json"], err)
	return PackedStringArray(err)


static func _valider_partie(p: Dictionary, err: Array[String]) -> void:
	var f := "partie.json"
	var ok_depart := _nombre(p, _pos("spawn_intervalle_depart"), f, "", err)
	var ok_plancher := _nombre(p, _pos("spawn_plancher"), f, "", err)
	if ok_depart and ok_plancher:
		var depart: float = p["spawn_intervalle_depart"]
		var plancher: float = p["spawn_plancher"]
		if plancher > depart:
			_err(err, f, "spawn_plancher", "ne peut dépasser spawn_intervalle_depart")
	for spec: Dictionary in [
		_pos("pas_s"),
		_pos("preparation_s"),
		_pos("manche_s"),
		_ent("manche_boss", 1.0),
		_pos("rayon_spawn"),
		_nn("spawn_baisse_par_manche"),
		_ent("nb_offres", 1.0),
		_ratio("vente_ratio"),
		_nn("gel_max_s"),
		_pos("esquive_k"),
	]:
		_nombre(p, spec, f, "", err)
	var tour_ok := _objet(p, "tour", f, "", err)
	if tour_ok:
		var tour: Dictionary = p["tour"]
		for spec: Dictionary in [
			_pos("pv"),
			_nn("armure"),
			_nn("regen"),
			_pos("rayon"),
			_nn("mana_max"),
			_nn("mana_regen")
		]:
			_nombre(tour, spec, f, "tour", err)
	var givre_ok := _objet(p, "givre", f, "", err)
	if givre_ok:
		var givre: Dictionary = p["givre"]
		for spec: Dictionary in [
			_ent("cumuls_max", 1.0), _nn("ralentissement_par_cumul"), _ratio("plafond")
		]:
			_nombre(givre, spec, f, "givre", err)
	var critique_ok := _objet(p, "critique", f, "", err)
	if critique_ok:
		var critique: Dictionary = p["critique"]
		var palier_critique := _spec("palier", 0.0, true, 1.0)
		for spec: Dictionary in [palier_critique, _nn("puissance_base"), _nn("coef_exces")]:
			_nombre(critique, spec, f, "critique", err)
	var reseau_ok := _objet(p, "reseau", f, "", err)
	if reseau_ok:
		var reseau: Dictionary = p["reseau"]
		var ok_arene := _nombre(reseau, _pos("hz_arene"), f, "reseau", err)
		var ok_min := _nombre(reseau, _pos("hz_min"), f, "reseau", err)
		_nombre(reseau, _pos("hz_global"), f, "reseau", err)
		_nombre(reseau, _spec("budget_octets_s", 0.0, true, INF, true), f, "reseau", err)
		if ok_arene and ok_min and float(reseau["hz_min"]) > float(reseau["hz_arene"]):
			_err(err, f, "reseau.hz_min", "ne peut dépasser reseau.hz_arene")
		var ok_regardee := _nombre(reseau, _pos("hz_arene_regardee"), f, "reseau", err)
		var ok_min_regardee := _nombre(reseau, _pos("hz_min_regardee"), f, "reseau", err)
		if (
			ok_regardee
			and ok_min_regardee
			and float(reseau["hz_min_regardee"]) > float(reseau["hz_arene_regardee"])
		):
			_err(err, f, "reseau.hz_min_regardee", "ne peut dépasser reseau.hz_arene_regardee")
	var convoi_p_ok := _objet(p, "convoi", f, "", err)
	if convoi_p_ok:
		var convoi_p: Dictionary = p["convoi"]
		for spec: Dictionary in [_ratio("probabilite"), _ent("manche_min", 1.0)]:
			_nombre(convoi_p, spec, f, "convoi", err)
	if _objet(p, "vagues", f, "", err):
		var vagues: Dictionary = p["vagues"]
		var part := _spec("part_majoritaire", 0.0, true, 1.0)
		_nombre(vagues, part, f, "vagues", err)
		var ok_min_familles := _nombre(vagues, _ent("familles_min", 1.0), f, "vagues", err)
		var plafond_familles := _spec("familles_max", 1.0, false, 3.0, true)
		var ok_max_familles := _nombre(vagues, plafond_familles, f, "vagues", err)
		if (
			ok_min_familles
			and ok_max_familles
			and float(vagues["familles_max"]) < float(vagues["familles_min"])
		):
			_err(err, f, "vagues.familles_max", "ne peut être inférieur à vagues.familles_min")
	DonneesLot9.valider_partie_lot9(p, err)
	var vitesses_ok := _tableau(p, "vitesses_partie", f, "", err)
	if vitesses_ok:
		var vitesses: Array = p["vitesses_partie"]
		if vitesses.is_empty():
			_err(err, f, "vitesses_partie", "au moins une vitesse attendue")
		for i in vitesses.size():
			var element: Variant = vitesses[i]
			if not _est_nombre(element) or float(element) <= 0.0:
				var raison := "nombre > 0 attendu, reçu %s" % _decrire(element)
				_err(err, f, "vitesses_partie[%d]" % i, raison)


static func _valider_economie(e: Dictionary, err: Array[String]) -> void:
	var f := "economie.json"
	_nombre(e, _ent("or_depart", 0.0), f, "", err)
	_nombre(e, _pos("revenu_periode_s"), f, "", err)
	_table(e, "revenu_base", f, "", err, "manche", [_nn("valeur")])
	_table(e, "prime_mult", f, "", err, "manche", [_nn("valeur")])


static func _valider_difficulte(d: Dictionary, err: Array[String]) -> void:
	var f := "difficulte.json"
	var multiplicateurs: Array = [_pos("pv"), _pos("degats"), _pos("vitesse")]
	var paliers: Array = multiplicateurs + [_pos("resistance_controle")]
	_table(d, "paliers", f, "", err, "manche", paliers)
	_table(d, "accelerations", f, "", err, "temps_s", multiplicateurs, true)
	var apres_ok := _objet(d, "apres_table", f, "", err)
	if apres_ok:
		var apres: Dictionary = d["apres_table"]
		for spec: Dictionary in paliers:
			_nombre(apres, spec, f, "apres_table", err)
	_nombre(d, _ratio("resistance_plancher"), f, "", err)


static func _valider_efficacite(e: Dictionary, err: Array[String]) -> void:
	var f := "efficacite.json"
	_noms_ordonnes(e, "lignes", Types.NOMS_TYPES, f, err)
	_noms_ordonnes(e, "colonnes", Types.NOMS_ARMURES, f, err)
	if not _tableau(e, "valeurs", f, "", err):
		return
	var valeurs: Array = e["valeurs"]
	if valeurs.size() != Types.NOMS_TYPES.size():
		var raison := "%d lignes attendues, reçu %d" % [Types.NOMS_TYPES.size(), valeurs.size()]
		_err(err, f, "valeurs", raison)
	for i in valeurs.size():
		var chemin := "valeurs[%d]" % i
		var ligne: Variant = valeurs[i]
		if not ligne is Array:
			_err(err, f, chemin, "attendu un tableau, reçu %s" % _decrire(ligne))
			continue
		var cases: Array = ligne
		if cases.size() != Types.NOMS_ARMURES.size():
			var raison := (
				"%d colonnes attendues, reçu %d" % [Types.NOMS_ARMURES.size(), cases.size()]
			)
			_err(err, f, chemin, raison)
		for j in cases.size():
			var valeur: Variant = cases[j]
			if not _est_nombre(valeur) or float(valeur) < 0.0:
				_err(
					err, f, "%s[%d]" % [chemin, j], "nombre ≥ 0 attendu, reçu %s" % _decrire(valeur)
				)


static func _valider_boutique(b: Dictionary, err: Array[String]) -> void:
	var f := "boutique.json"
	var poids: Array = []
	for nom in Types.NOMS_RARETES:
		poids.append(_nn(nom))
	_table(b, "poids", f, "", err, "manche", poids, false, true)
	var relance_ok := _objet(b, "relance", f, "", err)
	if relance_ok:
		var relance: Dictionary = b["relance"]
		for spec: Dictionary in [_ent("cout_depart", 0.0), _ent("increment", 0.0)]:
			_nombre(relance, spec, f, "relance", err)
	var noir_ok := _objet(b, "marche_noir", f, "", err)
	if noir_ok:
		var noir: Dictionary = b["marche_noir"]
		_nom_enum(noir, "raretes_max", Types.NOMS_RARETES, f, "marche_noir", err)


static func _valider_armes(
	liste: Array, ids: Dictionary, err: Array[String], unites: Dictionary = {}
) -> void:
	var f := "armes.json"
	for i in liste.size():
		var ch := "[%d]" % i
		var entree: Variant = liste[i]
		if not entree is Dictionary:
			_err(err, f, ch, "attendu un objet, reçu %s" % _decrire(entree))
			continue
		var a: Dictionary = entree
		_identifiant(a, f, ch, err, ids)
		_texte(a, "nom", f, ch, err)
		_texte(a, "description", f, ch, err)
		_nom_enum(a, "rarete", Types.NOMS_RARETES, f, ch, err)
		_nombre(a, _ent("prix", 0.0), f, ch, err)
		_nom_enum(a, "type_degats", Types.NOMS_TYPES, f, ch, err)
		_nombre(a, _pos("degats"), f, ch, err)
		_nombre(a, _pos("recharge"), f, ch, err)
		_nom_enum(a, "ciblage", Types.NOMS_CIBLAGES, f, ch, err)
		for nom: String in ["degats_par_mana_max", "degats_par_pv_max", "degats_par_exemplaire"]:
			if a.has(nom):
				_nombre(a, _nn(nom), f, ch, err)
		if a.has("degats_par_amelioration"):
			DonneesLot9.valider_degats_par_amelioration(a["degats_par_amelioration"], f, ch, err)
		if a.has("type_secondaire") and a["type_secondaire"] != "epines":
			var brut_second := _decrire(a["type_secondaire"])
			_err(err, f, _sous(ch, "type_secondaire"), "« epines » attendu, reçu %s" % brut_second)
		if _nombre(a, _ent("portee", 0.0), f, ch, err):
			var portee: int = int(a["portee"])
			if not portee in PORTEES:
				_err(err, f, _sous(ch, "portee"), "doit valoir 500, 750, 1000 ou 1250")
		var effets_ok := _tableau(a, "effets", f, ch, err)
		if effets_ok:
			var effets: Array = a["effets"]
			if effets.is_empty():
				_err(err, f, _sous(ch, "effets"), "au moins un effet attendu")
			for j in effets.size():
				_valider_sous_effet(
					effets[j], f, "%s[%d]" % [_sous(ch, "effets"), j], err, _kinds_effets(), unites
				)
		if a.has("statuts"):
			var statuts_ok := _tableau(a, "statuts", f, ch, err)
			if statuts_ok:
				var statuts: Array = a["statuts"]
				for j in statuts.size():
					var chemin := "%s[%d]" % [_sous(ch, "statuts"), j]
					_valider_sous_effet(statuts[j], f, chemin, err, _kinds_statuts())


## Un effet d'arme ou un statut : `kind` connu, puis les paramètres de ce `kind`.
static func _valider_sous_effet(
	entree: Variant,
	f: String,
	ch: String,
	err: Array[String],
	kinds: Dictionary,
	unites: Dictionary = {}
) -> void:
	if not entree is Dictionary:
		_err(err, f, ch, "attendu un objet, reçu %s" % _decrire(entree))
		return
	var e: Dictionary = entree
	if not e.has("kind") or not e["kind"] is String:
		_err(err, f, _sous(ch, "kind"), "texte attendu, reçu %s" % _decrire(e.get("kind")))
		return
	var kind: String = e["kind"]
	if not kinds.has(kind):
		var connus := ", ".join(PackedStringArray(kinds.keys()))
		_err(err, f, _sous(ch, "kind"), "inconnu « %s » (attendu : %s)" % [kind, connus])
		return
	var specs: Array = kinds[kind]
	for spec: Dictionary in specs:
		_nombre(e, spec, f, ch, err)
	if kind == "vol_de_vie" and e.has("a_la_mort") and not e["a_la_mort"] is bool:
		_err(err, f, _sous(ch, "a_la_mort"), "booléen attendu, reçu %s" % _decrire(e["a_la_mort"]))
	DonneesLot9.valider_champs_texte(kind, e, f, ch, err, unites)


static func _kinds_effets() -> Dictionary:
	return {
		"cible_unique": [],
		"zone": [_pos("rayon")],
		"rebond":
		[
			_spec("cibles", 4.0, false, 8.0, true),
			_pos("portee_saut"),
			_spec("decroissance", 0.0, true, 1.0)
		],
		"onde": [_pos("rayon_max"), _pos("vitesse")],
		"barrage": [_ent("projectiles", 1.0), _nn("dispersion_deg"), _pos("rayon")],
		"mine": [_pos("rayon"), _ent("max_actives", 1.0)],
		"piege": [_pos("rayon"), _ent("max_actives", 1.0)],
		"aura": [_pos("rayon"), _pos("periode")],
		"tournant":
		[
			_spec("branches", 1.0, false, 8.0, true),
			_spec("pas_deg", 0.0, true, 180.0),
			_pos("largeur")
		],
		"zone_posee":
		[_pos("rayon"), _pos("duree"), _pos("periode"), _pos("ratio"), _ent("max_actives", 1.0)],
		"bombe":
		[_spec("delai", 0.0, true, 5.0), _pos("rayon"), _pos("ratio"), _ent("max_actives", 1.0)],
		"invocation": [_pos("duree"), _pos("ratio_degats"), _ent("max_actives", 1.0)],
	}


static func _kinds_statuts() -> Dictionary:
	return {
		"poison": [_pos("total_ratio"), _pos("duree")],
		"brulure": [_pos("ratio"), _pos("duree")],
		"givre": [],
		"etourdissement": [_pos("duree")],
		"vol_de_vie": [_pos("ratio")],
		"vulnerabilite": [_pos("ratio"), _pos("duree")],
		"malediction_degats": [_spec("ratio", 0.0, true, 1.0), _pos("duree")],
		"malediction_toucher": [_spec("ratio", 0.0, true, 1.0), _pos("duree")],
		"repoussement": [_pos("distance")],
		"siphon": [_pos("par_seconde"), _pos("duree")],
		"mana_au_coup": [_pos("valeur")],
	}


static func _valider_ameliorations(liste: Array, ids: Dictionary, err: Array[String]) -> void:
	var f := "ameliorations.json"
	for i in liste.size():
		var ch := "[%d]" % i
		var entree: Variant = liste[i]
		if not entree is Dictionary:
			_err(err, f, ch, "attendu un objet, reçu %s" % _decrire(entree))
			continue
		var a: Dictionary = entree
		_identifiant(a, f, ch, err, ids)
		_texte(a, "nom", f, ch, err)
		_texte(a, "description", f, ch, err)
		_nom_enum(a, "rarete", Types.NOMS_RARETES, f, ch, err)
		_nombre(a, _ent("prix", 0.0), f, ch, err)
		var categorie := _nom_enum(a, "categorie", Types.NOMS_CATEGORIES, f, ch, err)
		_nom_enum(a, "famille", Types.FAMILLES_AMELIORATION, f, ch, err)
		if categorie == Types.Categorie.ARME:
			var raison := "« arme » est réservé aux armes : « amelioration » ou « revenu » attendu"
			_err(err, f, _sous(ch, "categorie"), raison)
		if not _tableau(a, "effets", f, ch, err):
			continue
		var effets: Array = a["effets"]
		if effets.is_empty():
			_err(err, f, _sous(ch, "effets"), "au moins un effet attendu")
		for j in effets.size():
			DonneesLot9.valider_effet_amelioration(
				effets[j], f, "%s[%d]" % [_sous(ch, "effets"), j], err
			)


# --- Briques de validation ---------------------------------------------------------------------


static func _err(err: Array[String], fichier: String, chemin: String, raison: String) -> void:
	err.append("%s: %s: %s" % [fichier, chemin, raison])


static func _sous(chemin: String, cle: String) -> String:
	return cle if chemin.is_empty() else "%s.%s" % [chemin, cle]


static func _decrire(v: Variant) -> String:
	var texte := var_to_str(v).replace("\n", " ")
	if texte.length() > 40:
		texte = texte.substr(0, 40) + "…"
	return "%s %s" % [type_string(typeof(v)), texte]


static func _est_nombre(v: Variant) -> bool:
	match typeof(v):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var x: float = v
			return is_finite(x)
		_:
			return false


## Contrainte numérique : `nom`, borne basse (exclue ou non), borne haute, entier ou non.
static func _spec(
	nom: String,
	mini: float = 0.0,
	exclu: bool = false,
	maxi: float = INF,
	entier: bool = false,
) -> Dictionary:
	return {"nom": nom, "min": mini, "exclu": exclu, "max": maxi, "entier": entier}


static func _pos(nom: String) -> Dictionary:
	return _spec(nom, 0.0, true)


static func _nn(nom: String) -> Dictionary:
	return _spec(nom, 0.0)


static func _ent(nom: String, mini: float) -> Dictionary:
	return _spec(nom, mini, false, INF, true)


static func _ratio(nom: String) -> Dictionary:
	return _spec(nom, 0.0, false, 1.0)


## Vérifie `d[spec.nom]` ; renvoie vrai s'il est valide.
static func _nombre(
	d: Dictionary, spec: Dictionary, f: String, chemin: String, err: Array[String]
) -> bool:
	var nom: String = spec["nom"]
	var ch := _sous(chemin, nom)
	if not d.has(nom):
		_err(err, f, ch, "manquant")
		return false
	var v: Variant = d[nom]
	if not _est_nombre(v):
		_err(err, f, ch, "nombre fini attendu, reçu %s" % _decrire(v))
		return false
	var x := float(v)
	var mini: float = spec["min"]
	var exclu: bool = spec["exclu"]
	var maxi: float = spec["max"]
	if spec["entier"] and x != floorf(x):
		_err(err, f, ch, "entier attendu, reçu %s" % x)
		return false
	if x < mini or (exclu and x <= mini):
		_err(err, f, ch, "doit être %s %s, reçu %s" % [">" if exclu else "≥", mini, x])
		return false
	if x > maxi:
		_err(err, f, ch, "doit être ≤ %s, reçu %s" % [maxi, x])
		return false
	return true


static func _texte(
	d: Dictionary, cle: String, f: String, chemin: String, err: Array[String]
) -> bool:
	var ch := _sous(chemin, cle)
	if not d.has(cle):
		_err(err, f, ch, "manquant")
		return false
	var v: Variant = d[cle]
	if not v is String or String(v).is_empty():
		_err(err, f, ch, "texte non vide attendu, reçu %s" % _decrire(v))
		return false
	return true


static func _booleen(
	d: Dictionary, cle: String, f: String, chemin: String, err: Array[String]
) -> bool:
	var ch := _sous(chemin, cle)
	if not d.has(cle):
		_err(err, f, ch, "manquant")
		return false
	if not d[cle] is bool:
		_err(err, f, ch, "booléen attendu, reçu %s" % _decrire(d[cle]))
		return false
	return true


## Un identifiant non vide, unique dans `ids` (id → où il est déjà défini).
static func _identifiant(
	d: Dictionary, f: String, chemin: String, err: Array[String], ids: Dictionary
) -> void:
	if not _texte(d, "id", f, chemin, err):
		return
	var id: String = d["id"]
	var ici := "%s %s" % [f, chemin]
	if ids.has(id):
		_err(err, f, _sous(chemin, "id"), "dupliqué « %s » (déjà défini : %s)" % [id, ids[id]])
	else:
		ids[id] = ici


## Indice de l'énumération, ou -1 (avec une erreur) si le nom est absent ou inconnu.
static func _nom_enum(
	d: Dictionary, cle: String, noms: Array[String], f: String, chemin: String, err: Array[String]
) -> int:
	var ch := _sous(chemin, cle)
	if not d.has(cle):
		_err(err, f, ch, "manquant")
		return -1
	var v: Variant = d[cle]
	var indice := -1
	if v is String:
		indice = noms.find(String(v))
	if indice < 0:
		var attendu := ", ".join(PackedStringArray(noms))
		_err(err, f, ch, "inconnu %s (attendu exactement : %s)" % [_decrire(v), attendu])
	return indice


## Vrai si `d[cle]` est un objet ; sinon une erreur est ajoutée.
static func _objet(
	d: Dictionary, cle: String, f: String, chemin: String, err: Array[String]
) -> bool:
	var ch := _sous(chemin, cle)
	if not d.has(cle):
		_err(err, f, ch, "manquant")
		return false
	var v: Variant = d[cle]
	if not v is Dictionary:
		_err(err, f, ch, "attendu un objet, reçu %s" % _decrire(v))
		return false
	return true


static func _tableau(
	d: Dictionary, cle: String, f: String, chemin: String, err: Array[String]
) -> bool:
	var ch := _sous(chemin, cle)
	if not d.has(cle):
		_err(err, f, ch, "manquant")
		return false
	var v: Variant = d[cle]
	if not v is Array:
		_err(err, f, ch, "attendu un tableau, reçu %s" % _decrire(v))
		return false
	return true


## `lignes` / `colonnes` d'efficacité : exactement les noms de `attendus`, dans cet ordre.
static func _noms_ordonnes(
	d: Dictionary, cle: String, attendus: Array[String], f: String, err: Array[String]
) -> void:
	if not _tableau(d, cle, f, "", err):
		return
	var tableau: Array = d[cle]
	if tableau.size() != attendus.size():
		_err(err, f, cle, "%d noms attendus, reçu %d" % [attendus.size(), tableau.size()])
	for i in mini(tableau.size(), attendus.size()):
		if tableau[i] != attendus[i]:
			var raison := "attendu « %s », reçu %s" % [attendus[i], _decrire(tableau[i])]
			_err(err, f, "%s[%d]" % [cle, i], raison)


## Table à paliers : triée strictement par `cle_ordre`. Pour « manche », le premier palier est à
## la manche 1. Chaque palier porte les champs de `champs`. `somme_positive` : au moins un
## de ces champs doit être > 0 (poids de rareté).
static func _table(
	d: Dictionary,
	cle: String,
	f: String,
	chemin: String,
	err: Array[String],
	cle_ordre: String,
	champs: Array,
	vide_ok: bool = false,
	somme_positive: bool = false,
) -> void:
	if not _tableau(d, cle, f, chemin, err):
		return
	var ch := _sous(chemin, cle)
	var lignes: Array = d[cle]
	if lignes.is_empty():
		if not vide_ok:
			_err(err, f, ch, "au moins un palier attendu")
		return
	var precedent := -INF
	for i in lignes.size():
		var chi := "%s[%d]" % [ch, i]
		var entree: Variant = lignes[i]
		if not entree is Dictionary:
			_err(err, f, chi, "attendu un objet, reçu %s" % _decrire(entree))
			continue
		var palier_d: Dictionary = entree
		var spec_ordre := _ent("manche", 1.0) if cle_ordre == "manche" else _pos(cle_ordre)
		var ordre_ok := _nombre(palier_d, spec_ordre, f, chi, err)
		if ordre_ok:
			var valeur_ordre: float = palier_d[cle_ordre]
			if i == 0 and cle_ordre == "manche" and valeur_ordre != 1.0:
				_err(err, f, ch, "le premier palier doit commencer à la manche 1")
			if valeur_ordre <= precedent:
				_err(err, f, ch, "%s non strictement croissant au palier %d" % [cle_ordre, i])
			precedent = valeur_ordre
		var somme := 0.0
		var champs_ok := true
		for spec: Dictionary in champs:
			if _nombre(palier_d, spec, f, chi, err):
				somme += float(palier_d[spec["nom"]])
			else:
				champs_ok = false
		if somme_positive and champs_ok and somme <= 0.0:
			_err(err, f, chi, "au moins un poids doit être > 0")


# --- Normalisation (appelée seulement sur des données déjà validées) ---------------------------


static func _copie(v: Variant) -> Dictionary:
	var source: Dictionary = v
	return source.duplicate(true)


static func _matrice(v: Variant) -> Array:
	var source: Dictionary = v
	var valeurs: Array = source["valeurs"]
	var resultat: Array = []
	for ligne_brute: Variant in valeurs:
		var cases: Array = ligne_brute
		var ligne: Array = []
		for valeur: Variant in cases:
			ligne.append(float(valeur))
		resultat.append(ligne)
	return resultat


static func _entier_ou_flottant(valeur: Variant, entier: bool) -> Variant:
	return int(valeur) if entier else float(valeur)


static func _normaliser_sous_effet(v: Variant, kinds: Dictionary) -> Dictionary:
	var source: Dictionary = v
	var kind: String = source["kind"]
	var sortie: Dictionary = {"kind": kind}
	var specs: Array = kinds[kind]
	for spec: Dictionary in specs:
		var nom: String = spec["nom"]
		sortie[nom] = _entier_ou_flottant(source[nom], spec["entier"])
	if kind == "vol_de_vie":
		sortie["a_la_mort"] = source.get("a_la_mort", false)
	match kind:
		"tournant":
			sortie["sens"] = source["sens"]
		"siphon":
			sortie["ressource"] = source["ressource"]
		"invocation":
			sortie["unite"] = source["unite"]
		"vulnerabilite":
			# -1 : le type de l'arme qui pose le statut.
			sortie["type_degats"] = (
				Types.type_depuis_nom(source["type_degats"]) if source.has("type_degats") else -1
			)
	return sortie


static func _normaliser_arme(v: Variant) -> Dictionary:
	var a: Dictionary = v
	var sortie: Dictionary = {
		"id": a["id"],
		"nom": a["nom"],
		"description": a["description"],
		"rarete": Types.rarete_depuis_nom(a["rarete"]),
		"prix": int(a["prix"]),
		"type_degats": Types.type_depuis_nom(a["type_degats"]),
		"degats": float(a["degats"]),
		"recharge": float(a["recharge"]),
		"portee": int(a["portee"]),
		"ciblage": Types.ciblage_depuis_nom(a["ciblage"]),
		"degats_par_mana_max": float(a.get("degats_par_mana_max", 0.0)),
		"degats_par_pv_max": float(a.get("degats_par_pv_max", 0.0)),
		"degats_par_exemplaire": float(a.get("degats_par_exemplaire", 0.0)),
		"degats_par_amelioration": DonneesLot9.normaliser_par_amelioration(a),
		"type_secondaire": String(a.get("type_secondaire", "")),
	}
	var effets: Array = []
	var effets_bruts: Array = a["effets"]
	for e: Variant in effets_bruts:
		effets.append(_normaliser_sous_effet(e, _kinds_effets()))
	sortie["effets"] = effets
	var statuts: Array = []
	var statuts_bruts: Array = a.get("statuts", [])
	for s: Variant in statuts_bruts:
		statuts.append(_normaliser_sous_effet(s, _kinds_statuts()))
	sortie["statuts"] = statuts
	return sortie


static func _contenu_vide(nom: String) -> Variant:
	if nom == "ennemis.json":
		return {"modeles": [], "paliers": [], "convoi": {}, "boss": {}}
	return []


## Hash SHA-256 du contenu canonique de chaque fichier (clés triées, entiers et flottants
## de même valeur confondus), réduit à ses 8 premiers octets.
static func _empreinte(brut: Dictionary) -> int:
	var noms: Array[String] = []
	for nom: String in brut:
		noms.append(nom)
	noms.sort()
	var texte := ""
	for nom in noms:
		texte += "%s=%s\n" % [nom, _canonique(brut[nom])]
	var contexte := HashingContext.new()
	contexte.start(HashingContext.HASH_SHA256)
	contexte.update(texte.to_utf8_buffer())
	return contexte.finish().decode_s64(0)


static func _canonique(v: Variant) -> String:
	match typeof(v):
		TYPE_DICTIONARY:
			var dico: Dictionary = v
			var cles: Array[String] = []
			for cle: String in dico:
				cles.append(cle)
			cles.sort()
			var morceaux := PackedStringArray()
			for cle in cles:
				morceaux.append("%s:%s" % [JSON.stringify(cle), _canonique(dico[cle])])
			return "{%s}" % ",".join(morceaux)
		TYPE_ARRAY:
			var liste: Array = v
			var morceaux := PackedStringArray()
			for element: Variant in liste:
				morceaux.append(_canonique(element))
			return "[%s]" % ",".join(morceaux)
		TYPE_INT, TYPE_FLOAT:
			var x := float(v)
			return str(int(x)) if x == floorf(x) and absf(x) < 1e15 else str(x)
		_:
			return JSON.stringify(v)
