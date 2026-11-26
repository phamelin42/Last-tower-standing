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


## Π sur les catégories de (1 + Σ valeurs de la catégorie).
static func _produit(par_categorie: Dictionary) -> float:
	var p := 1.0
	for cat: String in par_categorie:
		p *= 1.0 + float(par_categorie[cat])
	return p
