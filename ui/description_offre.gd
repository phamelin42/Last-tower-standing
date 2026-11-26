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
	"cible_unique",
	"zone",
	"rebond",
	"onde",
	"barrage",
	"mine",
	"piege",
	"aura",
	"tournant",
	"zone_posee",
	"bombe",
	"invocation",
]
const STATUTS: Array[String] = [
	"poison",
	"brulure",
	"givre",
	"etourdissement",
	"vol_de_vie",
	"vulnerabilite",
	"malediction_degats",
	"malediction_toucher",
	"repoussement",
	"siphon",
	"mana_au_coup",
]
## Champs facultatifs d'une arme qui ajoutent une ligne (`degats_par_amelioration` cite une stat).
const CHAMPS_ARME: Array[String] = [
	"degats_par_pv_max", "degats_par_exemplaire", "degats_par_amelioration", "type_secondaire"
]
const TYPES_SECONDAIRES: Array[String] = ["epines"]
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
	"mana_max",
	"mana_regen",
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
## ne visent personne : `Tir` ne s'en sert que pour déclencher l'onde. Le ciblage par défaut, le
## plus proche, ne s'écrit pas : la carte n'a pas la place de le répéter vingt fois.
const EFFETS_QUI_VISENT: Array[String] = [
	"cible_unique", "zone", "rebond", "barrage", "mine", "piege"
]
## Genres d'effet dont la portée de `data/` compte : celle du tir, ou celle qui déclenche l'onde ou
## la pose. L'aura ne la lit jamais.
const EFFETS_A_PORTEE: Array[String] = [
	"cible_unique",
	"zone",
	"rebond",
	"barrage",
	"onde",
	"mine",
	"piege",
	"tournant",
	"zone_posee",
	"bombe",
	"invocation",
]


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


## « ×2 contre armure moyenne » : ce que la table d'efficacité fait de l'arme. Chaîne vide pour
## une amélioration ou une arme sans avantage. Hors de la ligne d'effet : la carte n'a pas la place.
static func efficacite(entree: Dictionary, donnees: Donnees) -> String:
	if donnees == null or not entree.has("type_degats"):
		return ""
	return SEPARATEUR.join(_morceaux_efficacite(int(entree["type_degats"]), donnees))


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
	if genre == Types.Genre.ARME:
		var secondaire := String(entree.get("type_secondaire", ""))
		if not secondaire.is_empty() and not TYPES_SECONDAIRES.has(secondaire):
			return false
		var par_amelio: Dictionary = entree.get("degats_par_amelioration", {})
		var stat := String(par_amelio.get("stat", ""))
		if not stat.is_empty() and not STATISTIQUES.has(stat):
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
		morceaux.append_array(_morceaux_effet(kind, effet, degats, recharge, donnees))
	# La portée du tir et le ciblage ne se disent qu'une fois, après le dernier effet qui s'en sert.
	if _contient_un(kinds, EFFETS_A_PORTEE):
		morceaux.append(_t("BOUTIQUE_EFFET_PORTEE", [portee]))
	if _contient_un(kinds, EFFETS_QUI_VISENT):
		var ciblage := int(entree["ciblage"])
		if ciblage != Types.Ciblage.PLUS_PROCHE and CLES_CIBLAGE.has(ciblage):
			morceaux.append(_t(CLES_CIBLAGE[ciblage]))
	morceaux.append_array(_morceaux_champs_arme(entree, donnees))
	var statuts: Array = entree.get("statuts", [])
	for brut: Variant in statuts:
		var statut: Dictionary = brut
		morceaux.append(_statut(statut, donnees, type_degats))
	return morceaux


## Bonus de dégâts liés à la tour ou à l'inventaire (M5, bornés par `partie.json`), type secondaire.
static func _morceaux_champs_arme(entree: Dictionary, donnees: Donnees) -> Array[String]:
	var morceaux: Array[String] = []
	var borne := _t(
		"BOUTIQUE_EFFET_BORNE_M5", [_nombre(_reglage(donnees, "armes", "bonus_selon_stat_max"), 2)]
	)
	var par_pv := float(entree.get("degats_par_pv_max", 0.0))
	if par_pv > 0.0:
		morceaux.append(_t("BOUTIQUE_EFFET_ARME_PAR_PV_MAX", [_pourcent(par_pv), borne]))
	var par_exemplaire := float(entree.get("degats_par_exemplaire", 0.0))
	if par_exemplaire > 0.0:
		morceaux.append(
			_t("BOUTIQUE_EFFET_ARME_PAR_EXEMPLAIRE", [_pourcent(par_exemplaire), borne])
		)
	var par_amelio: Dictionary = entree.get("degats_par_amelioration", {})
	var stat := String(par_amelio.get("stat", ""))
	if not stat.is_empty() and float(par_amelio.get("ratio", 0.0)) > 0.0:
		var nom_stat := _t("BOUTIQUE_STAT_" + stat.to_upper())
		var ratio := _pourcent(float(par_amelio["ratio"]))
		morceaux.append(_t("BOUTIQUE_EFFET_ARME_PAR_AMELIORATION", [ratio, nom_stat, borne]))
	var secondaire := String(entree.get("type_secondaire", ""))
	if not secondaire.is_empty():
		morceaux.append(_t("BOUTIQUE_EFFET_TYPE_SECONDAIRE_" + secondaire.to_upper()))
	return morceaux


static func _morceaux_effet(
	kind: String, effet: Dictionary, degats: String, recharge: String, donnees: Donnees
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
			var restant := [_nombre(float(effet["cibles"]), 0), _pourcent(perte)]
			morceaux.append(_t("BOUTIQUE_EFFET_REBOND_DETAIL", restant))
		"barrage":
			morceaux.append(
				_t(
					"BOUTIQUE_EFFET_BARRAGE",
					[_nombre(float(effet["projectiles"]), 0), degats, recharge]
				)
			)
			morceaux.append(
				_t("BOUTIQUE_EFFET_BARRAGE_DETAIL", [_nombre(float(effet["rayon"]), 0)])
			)
		"onde":
			morceaux.append(_t("BOUTIQUE_EFFET_ONDE", [degats, recharge]))
			morceaux.append(
				_t("BOUTIQUE_EFFET_ONDE_DETAIL", [_nombre(float(effet["rayon_max"]), 0)])
			)
		"mine", "piege":
			var majuscule := kind.to_upper()
			var maximum := _nombre(float(effet["max_actives"]), 0)
			morceaux.append(_t("BOUTIQUE_EFFET_" + majuscule, [degats, recharge, maximum]))
			morceaux.append(
				_t("BOUTIQUE_EFFET_" + majuscule + "_DETAIL", [_nombre(float(effet["rayon"]), 0)])
			)
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
		"tournant":
			morceaux.append(_t("BOUTIQUE_EFFET_TOURNANT", [degats, recharge]))
			var sens := "BOUTIQUE_EFFET_SENS_" + String(effet["sens"]).to_upper()
			var tourne := [
				_nombre(float(effet["branches"]), 0),
				_nombre(float(effet["pas_deg"])),
				_t(sens),
				_nombre(float(effet["largeur"]), 0),
			]
			morceaux.append(_t("BOUTIQUE_EFFET_TOURNANT_DETAIL", tourne))
		"zone_posee":
			var zone := [
				_nombre(float(effet["rayon"]), 0),
				_nombre(float(effet["duree"])),
				_pourcent(float(effet["ratio"])),
				degats,
				_nombre(float(effet["periode"])),
				_nombre(float(effet["max_actives"]), 0),
			]
			morceaux.append(_t("BOUTIQUE_EFFET_ZONE_POSEE", [recharge] + zone))
		"bombe":
			var bombe := [
				_nombre(float(effet["delai"])),
				_pourcent(float(effet["ratio"])),
				degats,
				_nombre(float(effet["rayon"]), 0),
				_nombre(float(effet["max_actives"]), 0),
			]
			morceaux.append(_t("BOUTIQUE_EFFET_BOMBE", [recharge] + bombe))
		"invocation":
			var fiche: Dictionary = donnees.unites.get(String(effet["unite"]), {})
			var nom_unite := String(fiche.get("nom", _t("BOUTIQUE_EFFET_ALLIE")))
			var allie := [
				nom_unite,
				_nombre(float(effet["duree"])),
				_pourcent(float(effet["ratio_degats"])),
				degats,
				_nombre(float(effet["max_actives"]), 0),
			]
			morceaux.append(_t("BOUTIQUE_EFFET_INVOCATION", [recharge] + allie))
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


static func _statut(statut: Dictionary, donnees: Donnees, type_arme: int = -1) -> String:
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
		"vulnerabilite":
			var type_cible := int(statut.get("type_degats", -1))
			if type_cible < 0:
				type_cible = type_arme
			var plafond := _reglage(donnees, "vulnerabilite", "plafond")
			var vulnerable := [
				_pourcent(float(statut["ratio"])),
				_t(CLES_TYPE_ADJECTIF[type_cible]) if CLES_TYPE_ADJECTIF.has(type_cible) else "",
				_nombre(float(statut["duree"])),
				_pourcent(plafond, 0),
			]
			return _t("BOUTIQUE_EFFET_VULNERABILITE", vulnerable)
		"malediction_degats", "malediction_toucher":
			var maudit := [
				_pourcent(float(statut["ratio"])),
				_nombre(float(statut["duree"])),
				_pourcent(_reglage(donnees, "malediction", "plafond"), 0),
			]
			return _t("BOUTIQUE_EFFET_" + String(statut["kind"]).to_upper(), maudit)
		"repoussement":
			var facteur := _reglage(donnees, "repoussement", "facteur_boss")
			var cle_boss := "BOUTIQUE_EFFET_REPOUSSEMENT_BOSS_REDUIT"
			if facteur <= 0.0:
				cle_boss = "BOUTIQUE_EFFET_REPOUSSEMENT_BOSS_AUCUN"
			var recul := _t(cle_boss, [] if facteur <= 0.0 else [_nombre(facteur, 2)])
			return _t("BOUTIQUE_EFFET_REPOUSSEMENT", [_nombre(float(statut["distance"]), 0), recul])
		"siphon":
			var cle_siphon := "BOUTIQUE_EFFET_SIPHON_" + String(statut["ressource"]).to_upper()
			return _t(
				cle_siphon, [_nombre(float(statut["par_seconde"])), _nombre(float(statut["duree"]))]
			)
		"mana_au_coup":
			return _t("BOUTIQUE_EFFET_MANA_AU_COUP", [_nombre(float(statut["valeur"]))])
	return ""


## Réglage numérique de `partie.json` ; 0 s'il manque (les données de test n'ont pas tout).
static func _reglage(donnees: Donnees, section: String, cle: String) -> float:
	var bloc: Dictionary = donnees.partie.get(section, {})
	return float(bloc.get(cle, 0.0))


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
	var v := 0.0 if stat in Donnees.STATS_SANS_VALEUR else float(effet["valeur"])
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
			morceaux.append_array(_morceaux_croissance_degats(effet, donnees))
		"degats_global":
			morceaux.append(_t("BOUTIQUE_EFFET_DEGATS_GLOBAL", [_pourcent(v)]))
			var rang: String = effet["categorie"]
			morceaux.append(_t("BOUTIQUE_EFFET_RANG", [rang, rang]))
			morceaux.append_array(_morceaux_croissance_degats(effet, donnees))
		"pv_max":
			morceaux.append(_t("BOUTIQUE_EFFET_PV_MAX", [_nombre(v)]))
		"regen":
			morceaux.append(_t("BOUTIQUE_EFFET_REGEN", [_nombre(v)]))
		"mana_max":
			morceaux.append(_t("BOUTIQUE_EFFET_MANA_MAX", [_nombre(v)]))
		"mana_regen":
			morceaux.append(_t("BOUTIQUE_EFFET_MANA_REGEN", [_nombre(v)]))
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
		_:
			morceaux.append_array(_morceaux_statistique_lot9(stat, effet, donnees))
	return morceaux


## Statistiques du lot 9. Les plafonds et les pas de croissance se lisent dans `partie.json`.
static func _morceaux_statistique_lot9(
	stat: String, effet: Dictionary, donnees: Donnees
) -> Array[String]:
	var morceaux: Array[String] = []
	var v := float(effet.get("valeur", 0.0))
	var pas := _nombre(_reglage(donnees, "ameliorations", "croissance_pas_s"), 0)
	match stat:
		"degats_classe":
			var classe := "BOUTIQUE_CLASSE_" + String(effet["classe"]).to_upper()
			morceaux.append(_t("BOUTIQUE_EFFET_DEGATS_CLASSE", [_pourcent(v), _t(classe)]))
		"etat_degats":
			var etat := "BOUTIQUE_ETAT_DEGATS_" + String(effet["etat"]).to_upper()
			morceaux.append(_t("BOUTIQUE_EFFET_ETAT_DEGATS", [_pourcent(v), _t(etat)]))
		"etat_duree":
			var duree := "BOUTIQUE_ETAT_DUREE_" + String(effet["etat"]).to_upper()
			morceaux.append(_t("BOUTIQUE_EFFET_ETAT_DUREE", [_pourcent(v), _t(duree)]))
		"degats_contre_etat":
			var contre := "BOUTIQUE_ETAT_CONTRE_" + String(effet["etat"]).to_upper()
			morceaux.append(_t("BOUTIQUE_EFFET_DEGATS_CONTRE_ETAT", [_pourcent(v), _t(contre)]))
		"epines_degats":
			morceaux.append(_t("BOUTIQUE_EFFET_EPINES_DEGATS", [_pourcent(v)]))
		"epines_croissantes":
			var croit := [_pourcent(v), pas, _pourcent(float(effet["max"]))]
			morceaux.append(_t("BOUTIQUE_EFFET_EPINES_CROISSANTES", croit))
		"epines_premier_coup":
			morceaux.append(_t("BOUTIQUE_EFFET_EPINES_PREMIER_COUP", [_pourcent(v)]))
		"epines_soin":
			morceaux.append(_t("BOUTIQUE_EFFET_EPINES_SOIN", [_pourcent(v)]))
		"epines_reduction":
			morceaux.append(_t("BOUTIQUE_EFFET_EPINES_REDUCTION", [_pourcent(v)]))
		"epines_statut", "riposte_statut":
			var statut := "BOUTIQUE_STATUT_POSE_" + String(effet["statut"]).to_upper()
			var cle := "BOUTIQUE_EFFET_" + stat.to_upper()
			morceaux.append(_t(cle, [_t(statut), _nombre(v)]))
		"pv_max_mult":
			morceaux.append(_t("BOUTIQUE_EFFET_PV_MAX_MULT", [_pourcent(v)]))
		"soin_pv_manquants":
			morceaux.append(_t("BOUTIQUE_EFFET_SOIN_PV_MANQUANTS", [_pourcent(v)]))
		"degats_par_pv_max":
			morceaux.append(
				_t("BOUTIQUE_EFFET_DEGATS_PAR_PV_MAX", [_pourcent(v), _nombre(1000, 0)])
			)
		"resurrection":
			morceaux.append(_t("BOUTIQUE_EFFET_RESURRECTION", [_pourcent(v, 0)]))
		"regen_croissante":
			var regen := [_nombre(v, 2), pas, _nombre(float(effet["max"]), 2)]
			morceaux.append(_t("BOUTIQUE_EFFET_REGEN_CROISSANTE", regen))
		"soin_periodique":
			var soin := [_pourcent(float(effet["ratio"])), _nombre(float(effet["tous_les"]))]
			morceaux.append(_t("BOUTIQUE_EFFET_SOIN_PERIODIQUE", soin))
		"armure_croissante":
			var armure := [_nombre(v, 2), pas, _nombre(float(effet["max"]), 2)]
			morceaux.append(_t("BOUTIQUE_EFFET_ARMURE_CROISSANTE", armure))
		"mana_max_mult":
			morceaux.append(_t("BOUTIQUE_EFFET_MANA_MAX_MULT", [_pourcent(v)]))
		"mana_rupture_etourdit":
			var rupture := [_nombre(float(effet["duree"])), _nombre(float(effet["rayon"]), 0)]
			morceaux.append(_t("BOUTIQUE_EFFET_MANA_RUPTURE_ETOURDIT", rupture))
		"degats_tant_que_mana":
			morceaux.append(_t("BOUTIQUE_EFFET_DEGATS_TANT_QUE_MANA", [_pourcent(v)]))
		"reduction_tant_que_mana":
			morceaux.append(_t("BOUTIQUE_EFFET_REDUCTION_TANT_QUE_MANA", [_pourcent(v)]))
		"revenu_contre_pv":
			var contre_pv := [
				_nombre(float(effet["or"]), 0), _periode(donnees), _nombre(float(effet["pv"]))
			]
			morceaux.append(_t("BOUTIQUE_EFFET_REVENU_CONTRE_PV", contre_pv))
		"copie_prochaine_offre":
			var rarete := int(effet["raretes_max"])
			var libelle := _t(Apparence.cle_libelle_rarete(rarete)).to_lower()
			morceaux.append(_t("BOUTIQUE_EFFET_COPIE_PROCHAINE_OFFRE", [libelle]))
		"aura_mixte":
			var aura := [
				_nombre(float(effet["rayon"]), 0),
				_nombre(float(effet["poison"])),
				_nombre(float(effet["regen"])),
			]
			morceaux.append(_t("BOUTIQUE_EFFET_AURA_MIXTE", aura))
	return morceaux


## Croissance dans le temps et bonus par arme commune des bonus de dégâts, bornés par `partie.json`.
static func _morceaux_croissance_degats(effet: Dictionary, donnees: Donnees) -> Array[String]:
	var morceaux: Array[String] = []
	if effet.has("croissance"):
		var pas := _nombre(_reglage(donnees, "ameliorations", "croissance_pas_s"), 0)
		var croit := [
			_pourcent(float(effet["croissance"])), pas, _pourcent(float(effet["croissance_max"]))
		]
		morceaux.append(_t("BOUTIQUE_EFFET_DEGATS_CROISSANCE", croit))
	if effet.has("par_arme_commune"):
		var commune := _pourcent(float(effet["par_arme_commune"]))
		# Pour un type, seules les armes communes de ce type comptent ; pour le global, toutes.
		var cle := "BOUTIQUE_EFFET_DEGATS_PAR_ARME_COMMUNE"
		if effet["stat"] == "degats_type":
			cle += "_TYPE"
		morceaux.append(_t(cle, [commune]))
	if effet.has("croissance") or effet.has("par_arme_commune"):
		var plafond := _nombre(_reglage(donnees, "ameliorations", "facteur_degats_max"), 0)
		morceaux.append(_t("BOUTIQUE_EFFET_DEGATS_PLAFOND", [plafond]))
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
