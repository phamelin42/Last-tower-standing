class_name BilanPartie
extends RefCounted
## Bilan d'une partie pour un joueur (nommé `BilanPartie` : `Tir.Bilan` porte déjà le nom `Bilan`) :
## des compteurs purs, déterministes, alimentés là où l'événement a lieu (`Arene`, `Boutique`,
## `Economie`) et lus par les défis (`docs/defis.md` §2).
## `sim/` ne sait rien des défis ni des skins : il range des nombres. Un compteur est un nombre
## fini, positif ou nul ; la liste (`noms()`) est celle que le réseau transporte, dans cet ordre.

## Compteurs de `docs/defis.md` §2 qui ne dépendent ni d'un type, ni d'un genre, ni d'un statut,
## plus `eliminations` (le cumul de §3 en est la somme).
const BASE: Array[String] = [
	"manche_atteinte",
	"victoire",
	"dernier_rempart",
	"pv_min_ratio",
	"manches_sans_degats_de_suite",
	"pv_soignes",
	"mana_max_avant_manche_1",
	"chutes_bouclier_mana",
	"degats_epines",
	"serie_eliminations_5s",
	"armes_equipees_max",
	"ameliorations_achetees",
	"ameliorations_revenu_achetees",
	"stats_revenu_distinctes",
	"or_max_detenu",
	"or_depense",
	"or_gagne_total",
	"or_gagne_primes",
	"armes_achetees",
	"armes_distinctes",
	"eliminations",
]
## Statistiques d'amélioration qui comptent comme « revenu » pour `stats_revenu_distinctes`.
const STATS_REVENU: Array[String] = [
	"revenu_fixe", "revenu_croissant", "revenu_mult", "prime_mult", "bonus_elim"
]
## Largeur de la fenêtre glissante des éliminations : 5 s de simulation à 20 Hz.
const FENETRE_PAS: int = 100

static var _noms: PackedStringArray = PackedStringArray()

## nom du compteur → valeur (flottant fini ≥ 0).
var valeurs: Dictionary = {}

var _armes_vues: Dictionary = {}
var _stats_revenu_vues: Dictionary = {}
var _serie_courante: int = 0
var _perte_pv_dans_la_manche: bool = false
var _fenetre: PackedInt32Array = PackedInt32Array()
var _rang: int = 0
var _somme_fenetre: int = 0


func _init() -> void:
	for nom: String in noms():
		valeurs[nom] = 0.0
	valeurs["pv_min_ratio"] = 1.0
	_fenetre.resize(FENETRE_PAS)


## Tous les compteurs, dans l'ordre du réseau : les compteurs de base, puis un par type de dégâts,
## par genre d'effet et par statut d'arme (une arme compte pour chacun des siens).
static func noms() -> PackedStringArray:
	if _noms.is_empty():
		_noms = PackedStringArray(BASE)
		for type_nom: String in Types.NOMS_TYPES:
			# Sans accent : « perçant » → `percant`, « siège » → `siege`.
			var sans_accent := type_nom.replace("ç", "c").replace("è", "e")
			_noms.append("armes_type_" + sans_accent)
		for genre: String in VueArene.GENRES_ARME:
			if not genre.is_empty():
				_noms.append("armes_genre_" + genre)
		for statut: String in VueArene.STATUTS_ARME:
			if not statut.is_empty():
				_noms.append("armes_statut_" + statut)
	return _noms


## Nom du compteur d'un type de dégâts : « tranchant » → `armes_type_tranchant`, « perçant » →
## `armes_type_percant`, « siège » → `armes_type_siege`.
static func nom_type(type_degats: int) -> String:
	return noms()[BASE.size() + type_degats]


# --- Alimentation (appelée par l'arène) ------------------------------------------------------


## Un pas de simulation : PV de la tour, or détenu, armes équipées, éliminations du pas.
func pas(pv: float, pv_max: float, or_detenu: int, armes_equipees: int, eliminations: int) -> void:
	if pv_max > 0.0 and is_finite(pv) and is_finite(pv_max):
		valeurs["pv_min_ratio"] = minf(
			float(valeurs["pv_min_ratio"]), clampf(pv / pv_max, 0.0, 1.0)
		)
	_maximum("or_max_detenu", float(or_detenu))
	_maximum("armes_equipees_max", float(armes_equipees))
	_somme_fenetre += eliminations - _fenetre[_rang]
	_fenetre[_rang] = eliminations
	_rang = (_rang + 1) % FENETRE_PAS
	_maximum("serie_eliminations_5s", float(_somme_fenetre))


func soin(montant: float) -> void:
	_ajouter("pv_soignes", montant)


func epines(montant: float) -> void:
	_ajouter("degats_epines", montant)


func chute_bouclier() -> void:
	_ajouter("chutes_bouclier_mana", 1.0)


## La tour a perdu des points de vie : la manche en cours ne compte plus comme « sans dégâts ».
func perte_pv() -> void:
	_perte_pv_dans_la_manche = true


## Une manche se termine : la série de manches sans perdre un point de vie continue ou retombe.
func fin_de_manche() -> void:
	if _perte_pv_dans_la_manche:
		_serie_courante = 0
	else:
		_serie_courante += 1
	_perte_pv_dans_la_manche = false
	_maximum("manches_sans_degats_de_suite", float(_serie_courante))


func debut_de_la_premiere_manche(mana_max: float) -> void:
	valeurs["mana_max_avant_manche_1"] = maxf(mana_max, 0.0) if is_finite(mana_max) else 0.0


## Une arme achetée : `fiche` est celle de `Donnees.armes` (type, effets, statuts).
func achat_arme(fiche: Dictionary) -> void:
	_ajouter("armes_achetees", 1.0)
	_armes_vues[str(fiche["id"])] = true
	valeurs["armes_distinctes"] = float(_armes_vues.size())
	_ajouter(nom_type(int(fiche["type_degats"])), 1.0)
	var genres: Dictionary = {}
	for effet: Variant in fiche["effets"] as Array:
		genres[str((effet as Dictionary)["kind"])] = true
	for genre: String in genres:
		_ajouter_si_connu("armes_genre_" + genre)
	var statuts: Dictionary = {}
	for statut: Variant in fiche.get("statuts", []) as Array:
		statuts[str((statut as Dictionary)["kind"])] = true
	for statut: String in statuts:
		_ajouter_si_connu("armes_statut_" + statut)


## Une amélioration achetée : `fiche` est celle de `Donnees.ameliorations`.
func achat_amelioration(fiche: Dictionary) -> void:
	_ajouter("ameliorations_achetees", 1.0)
	if int(fiche["categorie"]) == Types.Categorie.REVENU:
		_ajouter("ameliorations_revenu_achetees", 1.0)
	for effet: Variant in fiche["effets"] as Array:
		var stat := str((effet as Dictionary)["stat"])
		if stat in STATS_REVENU:
			_stats_revenu_vues[stat] = true
	valeurs["stats_revenu_distinctes"] = float(_stats_revenu_vues.size())


# --- Lecture ---------------------------------------------------------------------------------


## Une copie des compteurs : modifier le résultat ne touche pas au bilan.
func a_dict() -> Dictionary:
	return valeurs.duplicate()


## Un bilan reçu d'un tiers : `null` s'il manque un compteur, s'il en a un de trop, ou si une
## valeur n'est pas un nombre fini positif ou nul.
static func depuis_dict(d: Dictionary) -> BilanPartie:
	var attendus := noms()
	if d.size() != attendus.size():
		return null
	var bilan := BilanPartie.new()
	for nom: String in attendus:
		if not d.has(nom):
			return null
		var v: Variant = d[nom]
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
			return null
		var x := float(v)
		if not is_finite(x) or x < 0.0:
			return null
		bilan.valeurs[nom] = x
	return bilan


# --- Outils privés ---------------------------------------------------------------------------


func _ajouter(nom: String, montant: float) -> void:
	if montant > 0.0 and is_finite(montant):
		valeurs[nom] = float(valeurs[nom]) + montant


func _ajouter_si_connu(nom: String) -> void:
	if valeurs.has(nom):
		_ajouter(nom, 1.0)


func _maximum(nom: String, valeur: float) -> void:
	if is_finite(valeur) and valeur > float(valeurs[nom]):
		valeurs[nom] = valeur
