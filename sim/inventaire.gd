class_name Inventaire
extends RefCounted
## Ce que la tour porte : des armes sans plafond de jeu (seulement celui du réseau, `ARMES_MAX`)
## et des améliorations empilables. `stats()` les agrège en un `StatsTour`.

## Plus grand nombre d'armes portables : le réseau le transporte sur un octet
## (`Protocole.MAX_ARMES`, vérifié par un test).
const ARMES_MAX: int = 255

## Ids des armes équipées (un id peut y figurer plusieurs fois).
var armes: Array[String] = []
## id d'amélioration → nombre d'exemplaires.
var ameliorations: Dictionary = {}
## Jetons de marché noir déjà dépensés : les jetons disponibles sont ceux de `stats()` moins
## ce compteur.
var jetons_marche_noir_utilises: int = 0

var _donnees: Donnees
var _ratio_vente: float


func _init(donnees: Donnees) -> void:
	_donnees = donnees
	_ratio_vente = float(donnees.partie["vente_ratio"])


## `OFFRE_INVALIDE` pour un id inconnu, `ARMES_AU_MAXIMUM` pour la 256e arme.
func ajouter(id: String) -> int:
	if _donnees.armes.has(id):
		if armes.size() >= ARMES_MAX:
			return Types.Resultat.ARMES_AU_MAXIMUM
		armes.append(id)
		return Types.Resultat.OK
	if _donnees.ameliorations.has(id):
		ameliorations[id] = int(ameliorations.get(id, 0)) + 1
		return Types.Resultat.OK
	return Types.Resultat.OFFRE_INVALIDE


## Nombre d'exemplaires équipés de l'arme `id_arme`.
func exemplaires(id_arme: String) -> int:
	var n := 0
	for id: String in armes:
		if id == id_arme:
			n += 1
	return n


## id d'arme → exemplaires équipés, en un seul balayage.
func comptes_armes() -> Dictionary:
	var comptes: Dictionary = {}
	for id: String in armes:
		comptes[id] = int(comptes.get(id, 0)) + 1
	return comptes


## stat → nombre d'améliorations possédées qui la portent ; une amélioration achetée n fois compte
## n fois, et une qui porte la stat par plusieurs effets ne compte qu'une fois par exemplaire.
func comptes_stats() -> Dictionary:
	var comptes: Dictionary = {}
	for id: String in ameliorations:
		var n: int = ameliorations[id]
		var amelio: Dictionary = _donnees.ameliorations[id]
		var vues: Dictionary = {}
		for e_brut: Variant in amelio["effets"] as Array:
			var e: Dictionary = e_brut
			var stat: String = e["stat"]
			if not vues.has(stat):
				vues[stat] = true
				comptes[stat] = int(comptes.get(stat, 0)) + n
	return comptes


## Combien d'améliorations possédées portent `stat` (chaque exemplaire acheté compte).
func compter_stat(stat: String) -> int:
	return int(comptes_stats().get(stat, 0))


func retirer_arme(index: int) -> String:
	if index < 0 or index >= armes.size():
		return ""
	var id := armes[index]
	armes.remove_at(index)
	return id


## 0 pour un indice invalide.
func prix_vente(index: int) -> int:
	if index < 0 or index >= armes.size():
		return 0
	var arme: Dictionary = _donnees.armes[armes[index]]
	return floori(float(int(arme["prix"])) * _ratio_vente)


func stats() -> StatsTour:
	var s := StatsTour.new()
	var reglages: Dictionary = _donnees.partie.get("ameliorations", {})
	s.pas_croissance_s = float(reglages.get("croissance_pas_s", s.pas_croissance_s))
	# catégorie → somme, par type de dégâts (et pour le global).
	var par_type: Array[Dictionary] = [{}, {}, {}, {}, {}]
	var global: Dictionary = {}
	for id: String in ameliorations:
		var n: int = ameliorations[id]
		var amelio: Dictionary = _donnees.ameliorations[id]
		var effets: Array = amelio["effets"]
		for e_brut: Variant in effets:
			var e: Dictionary = e_brut
			_appliquer(s, e, n, par_type, global)
	for t: int in 5:
		s.degats_type[t] = _produit(par_type[t])
	s.degats_global = _produit(global)
	return s


func _appliquer(
	s: StatsTour, e: Dictionary, n: int, par_type: Array[Dictionary], global: Dictionary
) -> void:
	var stat: String = e["stat"]
	if stat == "bonus_elim":
		s.bonus_elim_or += int(e["or"]) * n
		var tous_les := int(e["tous_les"])
		if s.bonus_elim_tous_les == 0 or tous_les < s.bonus_elim_tous_les:
			s.bonus_elim_tous_les = tous_les
		return
	if _appliquer_composite(s, e, stat, n):
		return
	var v: float = float(e["valeur"]) * n
	match stat:
		"degats_type":
			var cumul: Dictionary = par_type[int(e["type_degats"])]
			var cat: String = e["categorie"]
			cumul[cat] = float(cumul.get(cat, 0.0)) + v
		"degats_global":
			var cat: String = e["categorie"]
			global[cat] = float(global.get(cat, 0.0)) + v
		"pv_max":
			s.pv_max_bonus += v
		"regen":
			s.regen += v
		"mana_max":
			s.mana_max_bonus += v
		"mana_regen":
			s.mana_regen += v
		"armure":
			s.armure += v
		"esquive":
			s.esquive += v
		"epines":
			s.epines += v
		"critique_chance":
			s.critique_chance += v
		"cadence":
			s.cadence += v
		"tirs_multiples":
			s.tirs_multiples += roundi(v)
		"eclaboussure":
			s.eclaboussure += v
		"focalisation":
			s.focalisation += v
		"vol_de_vie_coup":
			s.vol_de_vie_coup += v
		"vol_de_vie_mort":
			s.vol_de_vie_mort += v
		"revenu_fixe":
			s.revenu_fixe += roundi(v)
		"revenu_croissant":
			s.revenu_croissant += v
		"revenu_mult":
			s.revenu_mult += v
		"prime_mult":
			s.prime_mult += v
		"relance_gratuite":
			s.relances_gratuites += roundi(v)
		"marche_noir":
			s.marche_noir += roundi(v)
		"degats_classe":
			_ajouter(s.degats_classe, String(e["classe"]), v)
		"etat_degats":
			_ajouter(s.etat_degats, String(e["etat"]), v)
		"etat_duree":
			_ajouter(s.etat_duree, String(e["etat"]), v)
		"degats_contre_etat":
			_ajouter(s.degats_contre_etat, String(e["etat"]), v)
		"epines_statut":
			_ajouter(s.epines_statut, String(e["statut"]), v)
		"riposte_statut":
			_ajouter(s.riposte_statut, String(e["statut"]), v)
		"epines_degats":
			s.epines_degats += v
		"epines_croissantes":
			s.epines_croissantes += v
			s.epines_croissantes_max += float(e["max"]) * n
		"epines_premier_coup":
			s.epines_premier_coup += v
		"epines_soin":
			s.epines_soin += v
		"epines_reduction":
			s.epines_reduction += v
		"pv_max_mult":
			s.pv_max_mult += v
		"soin_pv_manquants":
			s.soin_pv_manquants += v
		"degats_par_pv_max":
			s.degats_par_pv_max += v
		"resurrection":
			s.resurrection += roundi(v)
		"regen_croissante":
			s.regen_croissante += v
			s.regen_croissante_max += float(e["max"]) * n
		"armure_croissante":
			s.armure_croissante += v
			s.armure_croissante_max += float(e["max"]) * n
		"mana_max_mult":
			s.mana_max_mult += v
		"degats_tant_que_mana":
			s.degats_tant_que_mana += v
		"reduction_tant_que_mana":
			s.reduction_tant_que_mana += v


## Les stats qui portent plusieurs paramètres au lieu d'une `valeur`. Vrai si `stat` en est une.
func _appliquer_composite(s: StatsTour, e: Dictionary, stat: String, n: int) -> bool:
	match stat:
		"soin_periodique":
			s.soin_periodique["ratio"] = float(s.soin_periodique["ratio"]) + float(e["ratio"]) * n
			s.soin_periodique["tous_les"] = _plus_petit_non_nul(
				float(s.soin_periodique["tous_les"]), float(e["tous_les"])
			)
		"mana_rupture_etourdit":
			var rayon := maxf(float(s.mana_rupture_etourdit["rayon"]), float(e["rayon"]))
			var duree := maxf(float(s.mana_rupture_etourdit["duree"]), float(e["duree"]))
			s.mana_rupture_etourdit = {"rayon": rayon, "duree": duree}
		"revenu_contre_pv":
			s.revenu_contre_pv["or"] = int(s.revenu_contre_pv["or"]) + int(e["or"]) * n
			s.revenu_contre_pv["pv"] = _plus_petit_non_nul(
				float(s.revenu_contre_pv["pv"]), float(e["pv"])
			)
		"copie_prochaine_offre":
			s.copie_prochaine_offre = maxi(s.copie_prochaine_offre, int(e["raretes_max"]))
		"aura_mixte":
			s.aura_mixte["rayon"] = maxf(float(s.aura_mixte["rayon"]), float(e["rayon"]))
			s.aura_mixte["poison"] = float(s.aura_mixte["poison"]) + float(e["poison"]) * n
			s.aura_mixte["regen"] = float(s.aura_mixte["regen"]) + float(e["regen"]) * n
		_:
			return false
	return true


static func _ajouter(cumul: Dictionary, cle: String, valeur: float) -> void:
	cumul[cle] = float(cumul.get(cle, 0.0)) + valeur


## Le plus petit des deux, 0 voulant dire « pas encore de valeur ».
static func _plus_petit_non_nul(actuel: float, nouveau: float) -> float:
	return nouveau if actuel <= 0.0 else minf(actuel, nouveau)


## Π sur les catégories de (1 + Σ valeurs de la catégorie).
static func _produit(par_categorie: Dictionary) -> float:
	var p := 1.0
	for cat: String in par_categorie:
		p *= 1.0 + float(par_categorie[cat])
	return p
