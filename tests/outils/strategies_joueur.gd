class_name StrategiesJoueur
extends RefCounted
## Stratégies de joueur automatique pour mesurer l'équilibrage (et le garder). Chacune est une
## fonction pure de la vue d'arène, des données et de l'API publique de `Partie` : aucune n'existe
## dans `sim/`. `jouer` est appelée une fois par seconde de jeu ; les achats faits sont rendus
## sous forme d'ids pour que l'outil de mesure les compte.

const PASSIVE := "passive"
const RAISONNABLE := "raisonnable"
const BONNE := "bonne"
const TOUTES: Array[String] = [PASSIVE, RAISONNABLE, BONNE]

const ACHATS_MAX_PAR_APPEL := 24
## Or gardé de côté par les stratégies actives, pour ne pas se vider sur une relance.
const RESERVE := 60
## La « bonne » stratégie investit dans l'économie jusqu'à cette manche, puis dans les dégâts.
const MANCHES_ECONOMIE := 6
const MANCHE_DEFENSE := 14
const ARMES_VISEES := 8


## Joue un tour d'achats pour le joueur `id`. Rend les ids achetés.
static func jouer(
	nom: String, p: Partie, d: Donnees, id: int, fin_de_manche: bool = false
) -> Array[String]:
	var achetes: Array[String] = []
	if nom == PASSIVE:
		return achetes
	for _i: int in ACHATS_MAX_PAR_APPEL:
		var v := p.vue_arene(id, id)
		if v == null:
			return achetes
		if v.marche_noir_ouvert:
			_marche_noir(p, d, id, nom, v.manche)
		var index := _choisir(nom, v, d)
		if index >= 0:
			var offre: Dictionary = v.offres[index]
			if p.intention_acheter(id, index) == Types.Resultat.OK:
				achetes.append(str(offre["id"]))
				continue
			return achetes
		if _veut_relancer(v, fin_de_manche) and p.intention_relancer(id) == Types.Resultat.OK:
			continue
		return achetes
	return achetes


static func _marche_noir(p: Partie, d: Donnees, id: int, nom: String, manche: int) -> void:
	var meilleur := ""
	var valeur := -1.0
	for ami: String in d.ameliorations:
		var a: Dictionary = d.ameliorations[ami]
		var s := _valeur_amelioration(a, PackedInt32Array([1, 1, 1, 1, 1]), nom, manche)
		if s > valeur:
			valeur = s
			meilleur = ami
	p.intention_marche_noir(id, meilleur)


static func _veut_relancer(v: VueArene, fin_de_manche: bool) -> bool:
	if v.relances_gratuites > 0:
		return true
	# On ne relance que pour dépenser un surplus, pas pour brûler l'or d'un achat futur.
	if v.argent < v.cout_relance + RESERVE * 2:
		return false
	return fin_de_manche or v.armes.size() < ARMES_VISEES


## Index de l'offre la meilleure selon la stratégie, ou −1 si aucune ne vaut le coup.
static func _choisir(nom: String, v: VueArene, d: Donnees) -> int:
	var types_possedes := PackedInt32Array([0, 0, 0, 0, 0])
	for arme: Dictionary in v.armes:
		var a: Dictionary = d.armes[str(arme["id"])]
		var t: int = Types.type_depuis_nom(str(a["type_degats"]))
		types_possedes[t] += 1
	var choix := -1
	var meilleur := 0.0
	for i: int in v.offres.size():
		var offre: Dictionary = v.offres[i]
		var prix := int(offre["prix"])
		if bool(offre["vendu"]) or prix > v.argent - _reserve_pour(v, prix):
			continue
		var s := _valeur_offre(nom, v, d, offre, types_possedes)
		if s > meilleur:
			meilleur = s
			choix = i
	return choix


## Une grosse dépense peut entamer la réserve ; une petite non.
static func _reserve_pour(v: VueArene, prix: int) -> int:
	return 0 if float(prix) >= float(v.argent) * 0.6 else RESERVE


static func _valeur_offre(
	nom: String, v: VueArene, d: Donnees, offre: Dictionary, types_possedes: PackedInt32Array
) -> float:
	var prix := float(maxi(int(offre["prix"]), 1))
	if int(offre["genre"]) == Types.Genre.ARME:
		if v.armes.size() >= ARMES_VISEES:
			return 0.0
		var a: Dictionary = d.armes[str(offre["id"])]
		var base := Equilibrage.rendement(a)
		if nom == BONNE:
			var t: int = Types.type_depuis_nom(str(a["type_degats"]))
			var eff := 1.0
			if v.prochaine_armure >= 0:
				eff = Combat.efficacite(d.efficacite, t, v.prochaine_armure)
			if v.manche < MANCHES_ECONOMIE:
				return base * 0.1 * eff
			return base * eff
		return base
	# Sans arme pour tuer, une amélioration ne sauve personne : on monte d'abord un arsenal minimal.
	var minimum := 2 if nom == BONNE else 4
	if v.armes.size() < minimum and _armes_disponibles(v):
		return 0.0
	var amelioration: Dictionary = d.ameliorations[str(offre["id"])]
	var poids := 1.0
	if nom == BONNE and v.armes.size() < 3 and v.manche >= MANCHES_ECONOMIE:
		poids = 0.3
	return _valeur_amelioration(amelioration, types_possedes, nom, v.manche) / prix * poids


## Vrai si une arme figure dans les offres encore à vendre (sinon on ne bloque pas les achats).
static func _armes_disponibles(v: VueArene) -> bool:
	for offre: Dictionary in v.offres:
		if not bool(offre["vendu"]) and int(offre["genre"]) == Types.Genre.ARME:
			return true
	return false


## Valeur grossière, en « dps équivalents », de chaque statistique ; les dégâts ne valent que si
## une arme du type est portée.
static func _valeur_amelioration(
	a: Dictionary, types_possedes: PackedInt32Array, nom: String, manche: int
) -> float:
	var total := 0.0
	var defense := 3.0 if nom == BONNE and manche >= MANCHE_DEFENSE else 1.0
	var effets: Array = a["effets"]
	for entree: Variant in effets:
		var effet: Dictionary = entree
		var stat := str(effet["stat"])
		var val := float(effet.get("valeur", 0.0))
		match stat:
			"degats_type":
				var t: int = Types.type_depuis_nom(str(effet["type_degats"]))
				total += val * 100.0 * float(types_possedes[t])
			"degats_global", "cadence":
				total += val * 200.0
			"critique_chance":
				total += val * 100.0
			"tirs_multiples":
				total += 40.0
			"eclaboussure", "focalisation":
				total += val * 30.0
			"pv_max":
				total += val * 0.12 * defense
			"regen":
				total += val * 5.0 * defense
			"armure":
				total += val * 4.0 * defense
			"esquive":
				total += val * 100.0
			"epines":
				total += val * 15.0
			"vol_de_vie_coup", "vol_de_vie_mort":
				total += val * 20.0
			"revenu_fixe":
				total += val * _valeur_revenu(nom, manche)
			"revenu_croissant":
				total += val * 3.0 * _valeur_revenu(nom, manche)
			"revenu_mult":
				total += val * 50.0 * _valeur_revenu(nom, manche)
			"prime_mult":
				total += val * 18.0 * _valeur_revenu(nom, manche)
			_:
				total += 5.0
	return total


## L'économie ne vaut quelque chose que tôt ; la « bonne » stratégie la privilégie.
static func _valeur_revenu(nom: String, manche: int) -> float:
	if nom == BONNE:
		return 12.0 if manche < MANCHE_DEFENSE else 2.0
	return 6.0 if manche < 15 else 1.5
