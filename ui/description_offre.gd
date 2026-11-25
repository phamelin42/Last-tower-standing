class_name DescriptionOffre
extends RefCounted
## Ligne d'effet d'une offre (arme ou amélioration), générée depuis `data/` : les chiffres sont
## ceux des données, et chaque phrase décrit la règle que la simulation applique vraiment (voir
## `Tir`, `Inventaire`, `Economie`, `Combat`, `Arene`). Le texte ne peut donc pas contredire un
## rééquilibrage. Les gabarits vivent dans `i18n/textes_boutique.csv` (`BOUTIQUE_EFFET_*`).
##
## Une entrée dont un genre d'effet, un statut ou une statistique n'a pas de modèle donne une ligne
## vide : le test des 70 offres l'attrape au lieu de laisser passer un texte faux.

const SEPARATEUR := " · "
const ESPACE_INSECABLE := " "
const EFFETS: Array[String] = [
	"cible_unique", "zone", "rebond", "onde", "barrage", "mine", "piege", "aura"
]
const STATUTS: Array[String] = ["poison", "brulure", "givre", "etourdissement", "vol_de_vie"]
const STATISTIQUES: Array[String] = [
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

const CLES_TYPE: Dictionary = {
	Types.TypeDegats.TRANCHANT: "BOUTIQUE_TYPE_TRANCHANT",
	Types.TypeDegats.PERCANT: "BOUTIQUE_TYPE_PERCANT",
	Types.TypeDegats.MAGIQUE: "BOUTIQUE_TYPE_MAGIQUE",
	Types.TypeDegats.SIEGE: "BOUTIQUE_TYPE_SIEGE",
	Types.TypeDegats.CHAOS: "BOUTIQUE_TYPE_CHAOS",
}
const CLES_TYPE_ADJECTIF: Dictionary = {
	Types.TypeDegats.TRANCHANT: "BOUTIQUE_EFFET_TYPE_TRANCHANT",
	Types.TypeDegats.PERCANT: "BOUTIQUE_EFFET_TYPE_PERCANT",
	Types.TypeDegats.MAGIQUE: "BOUTIQUE_EFFET_TYPE_MAGIQUE",
	Types.TypeDegats.SIEGE: "BOUTIQUE_EFFET_TYPE_SIEGE",
	Types.TypeDegats.CHAOS: "BOUTIQUE_EFFET_TYPE_CHAOS",
}
const CLES_ARMURE: Dictionary = {
	Types.Armure.LEGERE: "BOUTIQUE_EFFET_ARMURE_LEGERE",
	Types.Armure.MOYENNE: "BOUTIQUE_EFFET_ARMURE_MOYENNE",
	Types.Armure.LOURDE: "BOUTIQUE_EFFET_ARMURE_LOURDE",
	Types.Armure.FORTIFIEE: "BOUTIQUE_EFFET_ARMURE_FORTIFIEE",
	Types.Armure.AUCUNE: "BOUTIQUE_EFFET_ARMURE_AUCUNE",
	Types.Armure.BOSS: "BOUTIQUE_EFFET_ARMURE_BOSS",
}
const CLES_CIBLAGE: Dictionary = {
	Types.Ciblage.PLUS_PROCHE: "BOUTIQUE_EFFET_CIBLAGE_PLUS_PROCHE",
	Types.Ciblage.PLUS_FORT: "BOUTIQUE_EFFET_CIBLAGE_PLUS_FORT",
	Types.Ciblage.PLUS_FAIBLE: "BOUTIQUE_EFFET_CIBLAGE_PLUS_FAIBLE",
}

## Genres d'effet dont le premier tir est choisi par le ciblage de l'arme. Une onde et une aura
## ne visent personne : `Tir` ne s'en sert que pour déclencher l'onde.
const EFFETS_QUI_VISENT: Array[String] = [
	"cible_unique", "zone", "rebond", "barrage", "mine", "piege"
]
## Genres d'effet dont la portée de `data/` est celle du tir lui-même.
const EFFETS_A_PORTEE: Array[String] = ["cible_unique", "zone", "rebond", "barrage"]


## Ligne d'effet de l'entrée de `Donnees` (arme ou amélioration). `avec_type` ajoute le type de
## dégâts en tête d'une arme : la carte de la boutique l'affiche déjà sur sa propre ligne.
## Chaîne vide si une partie de l'entrée n'a pas de modèle.
static func ligne_effet(
	entree: Dictionary, genre: int, donnees: Donnees, avec_type: bool = true
) -> String:
	if donnees == null or not est_complete(entree, genre):
		return ""
	var morceaux: Array[String] = []
	if genre == Types.Genre.ARME:
		morceaux = _morceaux_arme(entree, donnees, avec_type)
	else:
		morceaux = _morceaux_amelioration(entree, donnees)
	return SEPARATEUR.join(morceaux)


## Vrai si chaque effet, statut ou statistique de l'entrée a son modèle.
static func est_complete(entree: Dictionary, genre: int) -> bool:
	var effets: Array = entree.get("effets", [])
	if effets.is_empty():
		return false
	for brut: Variant in effets:
		var effet: Dictionary = brut
		if genre == Types.Genre.ARME:
			if not EFFETS.has(String(effet.get("kind", ""))):
				return false
		elif not STATISTIQUES.has(String(effet.get("stat", ""))):
			return false
	var statuts: Array = entree.get("statuts", [])
	for brut: Variant in statuts:
		var statut: Dictionary = brut
		if not STATUTS.has(String(statut.get("kind", ""))):
			return false
	return true


# --- Armes -----------------------------------------------------------------------------------


static func _morceaux_arme(entree: Dictionary, donnees: Donnees, avec_type: bool) -> Array[String]:
	var morceaux: Array[String] = []
	var type_degats := int(entree["type_degats"])
	if avec_type:
		morceaux.append(_t(CLES_TYPE[type_degats]))
	var degats := _nombre(float(entree["degats"]))
	var recharge := _nombre(float(entree["recharge"]))
	var portee := _nombre(float(entree["portee"]), 0)
	var effets: Array = entree["effets"]
	var kinds: Array[String] = []
	for brut: Variant in effets:
		var effet: Dictionary = brut
		var kind: String = effet["kind"]
		kinds.append(kind)
		morceaux.append_array(_morceaux_effet(kind, effet, degats, recharge, portee))
	# La portée du tir et le ciblage ne se disent qu'une fois, après le dernier effet qui s'en sert.
	if _contient_un(kinds, EFFETS_A_PORTEE):
		morceaux.append(_t("BOUTIQUE_EFFET_PORTEE", [portee]))
	if _contient_un(kinds, EFFETS_QUI_VISENT):
		var ciblage := int(entree["ciblage"])
		if CLES_CIBLAGE.has(ciblage):
			morceaux.append(_t(CLES_CIBLAGE[ciblage]))
	morceaux.append_array(_morceaux_efficacite(type_degats, donnees))
	var statuts: Array = entree.get("statuts", [])
	for brut: Variant in statuts:
		var statut: Dictionary = brut
		morceaux.append(_statut(statut, donnees))
	return morceaux


static func _morceaux_effet(
	kind: String, effet: Dictionary, degats: String, recharge: String, portee: String
) -> Array[String]:
	var morceaux: Array[String] = []
	match kind:
		"cible_unique":
			morceaux.append(_t("BOUTIQUE_EFFET_CIBLE_UNIQUE", [degats, recharge]))
		"zone":
			morceaux.append(_t("BOUTIQUE_EFFET_ZONE", [degats, recharge]))
			morceaux.append(_t("BOUTIQUE_EFFET_ZONE_RAYON", [_nombre(float(effet["rayon"]), 0)]))
		"rebond":
			var perte := 1.0 - float(effet["decroissance"])
			morceaux.append(_t("BOUTIQUE_EFFET_REBOND", [degats, recharge]))
			(
				morceaux
				. append(
					_t(
						"BOUTIQUE_EFFET_REBOND_DETAIL",
						[
							_nombre(float(effet["cibles"]), 0),
							_pourcent(perte),
							_nombre(float(effet["portee_saut"]), 0),
						]
					)
				)
			)
		"barrage":
			morceaux.append(
				_t(
					"BOUTIQUE_EFFET_BARRAGE",
					[_nombre(float(effet["projectiles"]), 0), degats, recharge]
				)
			)
			morceaux.append(
				_t(
					"BOUTIQUE_EFFET_BARRAGE_DETAIL",
					[_nombre(float(effet["rayon"]), 0), _nombre(float(effet["dispersion_deg"]), 0)]
				)
			)
		"onde":
			morceaux.append(_t("BOUTIQUE_EFFET_ONDE", [degats, recharge]))
			morceaux.append(
				_t("BOUTIQUE_EFFET_ONDE_DETAIL", [_nombre(float(effet["rayon_max"]), 0)])
			)
			morceaux.append(_t("BOUTIQUE_EFFET_ONDE_PORTEE", [portee]))
		"mine", "piege":
			var majuscule := kind.to_upper()
			var maximum := _nombre(float(effet["max_actives"]), 0)
			morceaux.append(_t("BOUTIQUE_EFFET_" + majuscule, [degats, recharge, maximum]))
			morceaux.append(
				_t("BOUTIQUE_EFFET_" + majuscule + "_DETAIL", [_nombre(float(effet["rayon"]), 0)])
			)
			morceaux.append(_t("BOUTIQUE_EFFET_POSE_PORTEE", [portee]))
		"aura":
			# `Tir._aura` tire à chaque `periode` ; la recharge et la portée de data/ ne servent pas.
			(
				morceaux
				. append(
					_t(
						"BOUTIQUE_EFFET_AURA",
						[
							degats,
							_nombre(float(effet["periode"])),
							_nombre(float(effet["rayon"]), 0),
						]
					)
				)
			)
	return morceaux


## « ×2 contre armure moyenne » pour chaque colonne de `efficacite.json` qui n'est pas neutre.
static func _morceaux_efficacite(type_degats: int, donnees: Donnees) -> Array[String]:
	var morceaux: Array[String] = []
	if type_degats < 0 or type_degats >= donnees.efficacite.size():
		return morceaux
	var ligne: Array = donnees.efficacite[type_degats]
	for armure: int in ligne.size():
		var multiplicateur := float(ligne[armure])
		if is_equal_approx(multiplicateur, 1.0) or not CLES_ARMURE.has(armure):
			continue
		morceaux.append(
			_t("BOUTIQUE_EFFET_EFFICACITE", [_nombre(multiplicateur, 2), _t(CLES_ARMURE[armure])])
		)
	return morceaux


static func _statut(statut: Dictionary, donnees: Donnees) -> String:
	match String(statut["kind"]):
		"poison":
			return _t(
				"BOUTIQUE_EFFET_POISON",
				[_pourcent(float(statut["total_ratio"])), _nombre(float(statut["duree"]))]
			)
		"brulure":
			return _t(
				"BOUTIQUE_EFFET_BRULURE",
				[_pourcent(float(statut["ratio"])), _nombre(float(statut["duree"]))]
			)
		"givre":
			var givre: Dictionary = donnees.partie["givre"]
			return _t(
				"BOUTIQUE_EFFET_GIVRE",
				[
					_pourcent(float(givre["ralentissement_par_cumul"])),
					_pourcent(float(givre["plafond"])),
					_nombre(float(donnees.partie["gel_max_s"])),
					_nombre(float(givre["cumuls_max"]), 0),
				]
			)
		"etourdissement":
			return _t("BOUTIQUE_EFFET_ETOURDISSEMENT", [_nombre(float(statut["duree"]))])
		"vol_de_vie":
			var cle := (
				"BOUTIQUE_EFFET_VOL_DE_VIE_MORT"
				if bool(statut.get("a_la_mort", false))
				else "BOUTIQUE_EFFET_VOL_DE_VIE"
			)
			return _t(cle, [_pourcent(float(statut["ratio"]))])
	return ""


static func _contient_un(kinds: Array[String], parmi: Array[String]) -> bool:
	for kind: String in kinds:
		if parmi.has(kind):
			return true
	return false


# --- Améliorations ---------------------------------------------------------------------------


static func _morceaux_amelioration(entree: Dictionary, donnees: Donnees) -> Array[String]:
	var morceaux: Array[String] = []
	var effets: Array = entree["effets"]
	for brut: Variant in effets:
		var effet: Dictionary = brut
		morceaux.append_array(_morceaux_statistique(effet, donnees))
	return morceaux


static func _morceaux_statistique(effet: Dictionary, donnees: Donnees) -> Array[String]:
	var morceaux: Array[String] = []
	var stat: String = effet["stat"]
	var v := 0.0 if stat == "bonus_elim" else float(effet["valeur"])
	match stat:
		"degats_type":
			var type_degats := int(effet["type_degats"])
			morceaux.append(
				_t(
					"BOUTIQUE_EFFET_DEGATS_TYPE",
					[_pourcent(v), _t(CLES_TYPE_ADJECTIF[type_degats])]
				)
			)
			var rang: String = effet["categorie"]
			morceaux.append(_t("BOUTIQUE_EFFET_RANG", [rang, rang]))
		"degats_global":
			morceaux.append(_t("BOUTIQUE_EFFET_DEGATS_GLOBAL", [_pourcent(v)]))
			var rang: String = effet["categorie"]
			morceaux.append(_t("BOUTIQUE_EFFET_RANG", [rang, rang]))
		"pv_max":
			morceaux.append(_t("BOUTIQUE_EFFET_PV_MAX", [_nombre(v)]))
		"regen":
			morceaux.append(_t("BOUTIQUE_EFFET_REGEN", [_nombre(v)]))
		"armure":
			# Réduction d'une armure seule, comme `Arene` : 0,05·a / (1 + 0,05·a).
			var reduction := Combat.reduction_armure(v)
			morceaux.append(_t("BOUTIQUE_EFFET_ARMURE", [_nombre(v), _pourcent(reduction, 0)]))
		"esquive":
			var chance := Combat.chance_esquive(v, float(donnees.partie["esquive_k"]))
			morceaux.append(_t("BOUTIQUE_EFFET_ESQUIVE", [_pourcent(chance)]))
		"epines":
			morceaux.append(_t("BOUTIQUE_EFFET_EPINES", [_pourcent(v)]))
		"critique_chance":
			var critique: Dictionary = donnees.partie["critique"]
			(
				morceaux
				. append(
					_t(
						"BOUTIQUE_EFFET_CRITIQUE",
						[
							_pourcent(v),
							_nombre(float(critique["puissance_base"])),
							_pourcent(float(critique["palier"])),
						]
					)
				)
			)
		"cadence":
			# `ArmeEquipee.recharge_effective` : recharge / (1 + cadence).
			morceaux.append(_t("BOUTIQUE_EFFET_CADENCE", [_pourcent(v), _nombre(1.0 + v, 2)]))
		"tirs_multiples":
			var cle := (
				"BOUTIQUE_EFFET_TIRS_UN" if roundi(v) == 1 else "BOUTIQUE_EFFET_TIRS_PLUSIEURS"
			)
			morceaux.append(_t(cle, [_nombre(v, 0)]))
		"eclaboussure":
			morceaux.append(
				_t(
					"BOUTIQUE_EFFET_ECLABOUSSURE",
					[_pourcent(v), _nombre(Tir.RAYON_ECLABOUSSURE, 0)]
				)
			)
		"focalisation":
			morceaux.append(_t("BOUTIQUE_EFFET_FOCALISATION", [_pourcent(v)]))
		"vol_de_vie_coup":
			morceaux.append(_t("BOUTIQUE_EFFET_VOL_DE_VIE_COUP", [_pourcent(v)]))
		"vol_de_vie_mort":
			morceaux.append(_t("BOUTIQUE_EFFET_VOL_DE_VIE_MORT_PV", [_nombre(v)]))
		"revenu_fixe":
			morceaux.append(_t("BOUTIQUE_EFFET_REVENU_FIXE", [_nombre(v, 0), _periode(donnees)]))
		"revenu_croissant":
			morceaux.append(_t("BOUTIQUE_EFFET_REVENU_CROISSANT", [_nombre(v), _periode(donnees)]))
		"revenu_mult":
			morceaux.append(_t("BOUTIQUE_EFFET_REVENU_MULT", [_pourcent(v)]))
		"prime_mult":
			morceaux.append(_t("BOUTIQUE_EFFET_PRIME", [_pourcent(v)]))
		"bonus_elim":
			morceaux.append(
				_t(
					"BOUTIQUE_EFFET_BONUS_ELIM",
					[_nombre(float(effet["or"]), 0), _nombre(float(effet["tous_les"]), 0)]
				)
			)
		"relance_gratuite":
			var cle := (
				"BOUTIQUE_EFFET_RELANCE_UNE"
				if roundi(v) == 1
				else "BOUTIQUE_EFFET_RELANCE_PLUSIEURS"
			)
			morceaux.append(_t(cle, [_nombre(v, 0)]))
		"marche_noir":
			var reglage: Dictionary = donnees.boutique["marche_noir"]
			var rarete := Types.rarete_depuis_nom(str(reglage["raretes_max"]))
			var libelle := _t(Apparence.cle_libelle_rarete(rarete)).to_lower()
			morceaux.append(_t("BOUTIQUE_EFFET_MARCHE_NOIR", [libelle]))
	return morceaux


static func _periode(donnees: Donnees) -> String:
	return _nombre(float(donnees.economie["revenu_periode_s"]))


# --- Mise en forme ---------------------------------------------------------------------------


## Gabarit du CSV, rempli. `TranslationServer` plutôt que `tr` : la fonction est statique.
static func _t(cle: String, arguments: Array = []) -> String:
	var gabarit := String(TranslationServer.translate(cle))
	return gabarit % arguments if not arguments.is_empty() else gabarit


## Virgule décimale, séparateur de milliers de `Nombres`, aucun zéro inutile.
static func _nombre(valeur: float, decimales: int = 1) -> String:
	var texte := String.num(snappedf(absf(valeur), pow(10.0, -decimales)), decimales)
	if texte.contains("."):
		texte = texte.rstrip("0").rstrip(".")
	var parties := texte.split(".")
	var sortie := Nombres.groupe(int(parties[0]))
	if parties.size() > 1:
		sortie += "," + parties[1]
	return sortie


## « 10 % » avec l'espace insécable devant le signe.
static func _pourcent(ratio: float, decimales: int = 1) -> String:
	return _nombre(ratio * 100.0, decimales) + ESPACE_INSECABLE + "%"
