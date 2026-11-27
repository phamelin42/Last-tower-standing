class_name Tir
extends RefCounted
## Résolution des tirs d'une arme équipée, pas par pas. Les dégâts d'un coup sont
## `degats × bonus du type × bonus global × critique × focalisation`, puis `Ennemis.infliger`
## applique seul, et une seule fois, l'efficacité type/armure : ne jamais la multiplier ici.
##
## Un critique est tiré une fois par tir (par projectile pour un barrage) et vaut pour toutes les
## cibles de ce tir. Les indices d'ennemis ne sont jamais conservés d'un pas à l'autre (une purge
## les échange) : mines et ondes gardent des positions et des identifiants.

## Rayon de l'éclaboussure autour de la cible d'un tir à cible unique.
const RAYON_ECLABOUSSURE := 80.0

## Plafond des bonus « selon » (en multiple des dégâts de base) quand l'appelant n'en donne pas : la
## valeur de départ de `partie.json` `armes.bonus_selon_stat_max`.
const BONUS_SELON_STAT_MAX_DEFAUT := 4.0


## Ce qu'un pas a produit, pour l'arène : dégâts réellement infligés, ennemis tués par un coup
## de l'arme, soin de la tour, évènements de rendu (le tick est posé par l'arène).
class Bilan:
	var degats: float = 0.0
	var tues_directs: int = 0
	var soin: float = 0.0
	## Mana gagnée par le pas (`mana_au_coup`), à verser à la tour par `Arene.mana_gagnee`.
	var mana: float = 0.0
	var evenements: Array[Dictionary] = []


## Ce que la tour sait de son inventaire et de la partie, lu une fois par pas par l'arène : sans lui
## (les tests de tir), une arme n'a ni PV maximum, ni niveau, ni améliorations à compter.
class Lecture:
	var pv_max_tour: float = 0.0
	var temps_s: float = 0.0
	## Vrai quand la tour a encore de la mana : `degats_tant_que_mana` ne joue que alors.
	var mana_active: bool = false
	## id d'arme → niveau de l'arme portée (chaque niveau compte comme un achat).
	var niveaux: Dictionary = {}
	## `partie.json` `niveaux.gain_degats` : part des dégâts de base gagnée par niveau au-dessus du
	## premier.
	var gain_degats: float = 0.0
	## stat d'amélioration → nombre d'améliorations possédées qui la portent (chaque achat compte).
	var ameliorations_par_stat: Dictionary = {}
	## `communes_par_type` des niveaux portés, calculé une fois par pas par l'arène : le refaire pour
	## chaque arme coûtait plus de 4 ms par pas à 75 armes. Vide : `_creer` le calcule lui-même.
	var communes: PackedInt32Array = PackedInt32Array()
	## Zones et bombes de l'arène : sans elles (tests de tir), une arme qui pose ne pose rien.
	var poses: Poses = null
	## Alliés de l'arène : sans eux (tests de tir), une arme qui invoque n'invoque rien.
	var allies: Allies = null
	var _cache_stats: StatsTour = null
	var _cache_temps: float = -1.0
	var _cache_type: PackedFloat64Array = PackedFloat64Array()
	var _cache_type_communes: PackedInt32Array = PackedInt32Array()
	var _cache_global: float = NAN
	var _cache_global_communes: int = -1

	## `StatsTour.facteur_degats_type`, calculé une fois par type et par pas : il ne dépend pas de
	## l'arme, et le refaire pour chacune coûtait environ 6 µs par arme (T27). Le cache vaut pour
	## les statistiques, l'instant et le nombre d'armes communes qu'on lui donne.
	func facteur_type(stats: StatsTour, type: int, temps_s: float, communes_du_type: int) -> float:
		_valider(stats, temps_s)
		if type < 0 or type >= _cache_type.size():
			return stats.facteur_degats_type(type, temps_s, communes_du_type)
		if is_nan(_cache_type[type]) or _cache_type_communes[type] != communes_du_type:
			_cache_type[type] = stats.facteur_degats_type(type, temps_s, communes_du_type)
			_cache_type_communes[type] = communes_du_type
		return _cache_type[type]

	## `StatsTour.facteur_degats_global`, calculé une fois par pas.
	func facteur_global(stats: StatsTour, temps_s: float, communes: int) -> float:
		_valider(stats, temps_s)
		if is_nan(_cache_global) or _cache_global_communes != communes:
			_cache_global = stats.facteur_degats_global(temps_s, communes)
			_cache_global_communes = communes
		return _cache_global

	func _valider(stats: StatsTour, temps_s: float) -> void:
		if stats == _cache_stats and temps_s == _cache_temps:
			return
		_cache_stats = stats
		_cache_temps = temps_s
		_cache_type = PackedFloat64Array([NAN, NAN, NAN, NAN, NAN])
		_cache_type_communes = PackedInt32Array([-1, -1, -1, -1, -1])
		_cache_global = NAN
		_cache_global_communes = -1


## Un statut de l'arme prêt à poser : `a`, `b` et `c` portent les nombres déjà calculés (ratio ou
## total, facteur de bonus, durée), `ressource` le type de dégâts ou la ressource du statut.
class PlanStatut:
	const POISON := 0
	const BRULURE := 1
	const GIVRE := 2
	const ETOURDISSEMENT := 3
	const VULNERABILITE := 4
	const SIPHON := 5
	const MALEDICTION_DEGATS := 6
	const MALEDICTION_TOUCHER := 7
	const REPOUSSEMENT := 8
	var kind: int = 0
	var a: float = 0.0
	var b: float = 1.0
	var c: float = 0.0
	var ressource: int = 0


## Ce qui est commun à toutes les résolutions d'un même pas.
class Contexte:
	var arme: ArmeEquipee
	var stats: StatsTour
	var ennemis: Ennemis
	var centre: Vector2
	var rng: RandomNumberGenerator
	var resistance: float
	var bilan: Bilan
	var type_degats: int
	## Index (`VueArene.GENRES_ARME`) de l'effet en cours de résolution ; posé avant chaque effet.
	var genre: int = 0
	## Index (`VueArene.STATUTS_ARME`) du statut principal de l'arme, 0 si elle n'en pose pas.
	var statut: int = 0
	## Index de l'arme dans `Donnees.ids_catalogue`, -1 si elle n'y figure pas : posé dans les
	## événements pour que le rendu choisisse l'effet et le son propres à l'arme.
	var index_arme: int = -1
	var degats_base: float
	## Produit des facteurs de dégâts qui ne dépendent pas de la cible (type, global, classe) et
	## plafond du produit complet (`partie.json` `ameliorations.facteur_degats_max`) : voir
	## `facteur_degats`.
	var facteur_fixe: float = 1.0
	var facteur_max: float = INF
	## `facteur_degats(ctx, 0)`, et `facteur_degats` par état de la cible rencontré : calculés au
	## premier coup, puisque le contexte ne change plus ensuite (T27 : 4 µs par ennemi touché).
	var sans_etat: float = NAN
	var par_etat: Dictionary = {}
	## Les statuts de l'arme, préparés par `_preparer_plan` au premier coup.
	var plan: Array[PlanStatut] = []
	var plan_pret: bool = false
	var statuts: Array
	var palier: float
	var puissance_base: float
	var coef_exces: float
	## Part du repoussement qui s'applique au boss (`partie.json` `repoussement.facteur_boss`).
	var facteur_boss_repoussement: float
	var pv_max_tour: float = 0.0
	var poses: Poses = null
	var allies: Allies = null
	var ids_unites: PackedStringArray = PackedStringArray()
	## `proprietaire` des poses de cette arme (`ArmeEquipee.get_instance_id()`).
	var proprietaire: int = 0


static func avancer_arme(
	arme: ArmeEquipee,
	dt: float,
	stats: StatsTour,
	ennemis: Ennemis,
	centre: Vector2,
	donnees: Donnees,
	rng: RandomNumberGenerator,
	resistance: float,
	bilan: Bilan,
	lecture: Lecture = null
) -> void:
	if not dt > 0.0 or not is_finite(dt):
		return
	# Une arme qui recharge, sans mine ni onde en route ni aura prête, n'a rien à résoudre ce pas :
	# on ne construit pas son contexte (75 armes équipées, 20 fois par seconde).
	if (
		arme.recharge_restante - dt > 0.0
		and arme.ondes.is_empty()
		and arme.mines.is_empty()
		and (not arme.a_aura or arme.aura_restante - dt > 0.0)
	):
		arme.recharge_restante -= dt
		arme.aura_restante = maxf(arme.aura_restante - dt, 0.0)
		return
	# Prête mais sans ennemi à sa portée : aucun effet ne trouve de cible (tous commencent par la
	# même recherche), il ne reste que les minuteurs. Le contexte, lui, coûte environ 30 µs.
	if (
		arme.ondes.is_empty()
		and arme.mines.is_empty()
		and ennemis.distance2_minimale(centre) > arme.reperage2
	):
		arme.recharge_restante = maxf(arme.recharge_restante - dt, 0.0)
		arme.aura_restante = maxf(arme.aura_restante - dt, 0.0)
		return
	var ctx := _creer(arme, stats, ennemis, centre, donnees, rng, resistance, bilan, lecture)
	var effets: Array = arme.def["effets"]
	_avancer_ondes(ctx, effets, dt)
	_declencher_mines(ctx, effets)
	arme.recharge_restante = maxf(arme.recharge_restante - dt, 0.0)
	arme.aura_restante = maxf(arme.aura_restante - dt, 0.0)
	if arme.recharge_restante <= 0.0:
		var a_tire := false
		for brut: Variant in effets:
			var effet: Dictionary = brut
			var kind: String = effet["kind"]
			ctx.genre = VueArene.genre_depuis_nom(kind)
			if kind != "aura" and _effet(ctx, kind, effet):
				a_tire = true
		if a_tire:
			arme.recharge_restante = arme.recharge_effective(stats)
	if arme.aura_restante <= 0.0:
		for brut: Variant in effets:
			var effet: Dictionary = brut
			ctx.genre = VueArene.genre_depuis_nom("aura")
			if effet["kind"] == "aura" and _aura(ctx, effet):
				arme.aura_restante = float(effet["periode"]) / (1.0 + arme.cadence_totale(stats))


static func _creer(
	arme: ArmeEquipee,
	stats: StatsTour,
	ennemis: Ennemis,
	centre: Vector2,
	donnees: Donnees,
	rng: RandomNumberGenerator,
	resistance: float,
	bilan: Bilan,
	lecture: Lecture
) -> Contexte:
	var ctx := Contexte.new()
	ctx.arme = arme
	ctx.stats = stats
	ctx.ennemis = ennemis
	ctx.centre = centre
	ctx.rng = rng
	ctx.resistance = resistance
	ctx.bilan = bilan
	ctx.type_degats = int(arme.def["type_degats"])
	var mana_max := stats.mana_max_totale(float(donnees.partie["tour"]["mana_max"]))
	var vue_tour := lecture if lecture != null else Lecture.new()
	ctx.pv_max_tour = vue_tour.pv_max_tour
	ctx.poses = vue_tour.poses
	ctx.allies = vue_tour.allies
	ctx.ids_unites = donnees.ids_unites
	ctx.proprietaire = arme.get_instance_id()
	var plafond: float = float(donnees.partie["armes"]["bonus_selon_stat_max"])
	var brut := degats_de_base(
		arme.def,
		stats,
		vue_tour.pv_max_tour,
		maxi(int(vue_tour.niveaux.get(arme.id, 1)), 1),
		vue_tour.ameliorations_par_stat,
		vue_tour.temps_s,
		mana_max,
		plafond,
		vue_tour.gain_degats
	)
	var reglages: Dictionary = donnees.partie.get("ameliorations", {})
	ctx.facteur_max = float(reglages.get("facteur_degats_max", INF))
	var communes := PackedInt32Array([0, 0, 0, 0, 0])
	if stats.a_des_degats_dynamiques():
		communes = (
			vue_tour.communes
			if vue_tour.communes.size() == communes.size()
			else communes_par_type(vue_tour.niveaux, donnees)
		)
	var temps_s := vue_tour.temps_s
	ctx.facteur_fixe = (
		vue_tour.facteur_type(stats, ctx.type_degats, temps_s, communes[ctx.type_degats])
		* vue_tour.facteur_global(
			stats, temps_s, communes[0] + communes[1] + communes[2] + communes[3] + communes[4]
		)
		* stats.facteur_classe(arme.def)
		* stats.facteur_pv_max(vue_tour.pv_max_tour)
		* (1.0 + stats.degats_tant_que_mana if vue_tour.mana_active else 1.0)
	)
	ctx.degats_base = brut * facteur_degats(ctx, 0)
	ctx.statuts = arme.def.get("statuts", [])
	ctx.statut = _statut_principal(ctx.statuts)
	ctx.index_arme = donnees.ids_catalogue.find(arme.id)
	var critique: Dictionary = donnees.partie["critique"]
	ctx.palier = float(critique["palier"])
	ctx.puissance_base = float(critique["puissance_base"])
	ctx.coef_exces = float(critique["coef_exces"])
	var repousse: Dictionary = donnees.partie["repoussement"]
	ctx.facteur_boss_repoussement = float(repousse["facteur_boss"])
	return ctx


# --- Aides communes ----------------------------------------------------------------------------


## Multiplicateur de dégâts d'un coup sur un ennemi dont `Ennemis.statuts` vaut `bits_ennemi` :
## type × global × classe × contre-état, borné par `partie.json` `ameliorations.facteur_degats_max`.
## C'est le seul endroit où ce produit est plafonné ; chaque stat reste son propre facteur.
static func facteur_degats(ctx: Contexte, bits_ennemi: int) -> float:
	return minf(ctx.facteur_fixe * ctx.stats.facteur_contre_etat(bits_ennemi), ctx.facteur_max)


## Armes communes équipées, par `Types.TypeDegats` : de quoi nourrir `par_arme_commune`. Chaque
## niveau compte comme un achat ; un id inconnu est ignoré.
static func communes_par_type(niveaux: Dictionary, donnees: Donnees) -> PackedInt32Array:
	var comptes := PackedInt32Array([0, 0, 0, 0, 0])
	for id: Variant in niveaux:
		var arme: Dictionary = donnees.armes.get(id, {})
		if arme.is_empty() or int(arme["rarete"]) != Types.Rarete.COMMUNE:
			continue
		var type_degats := int(arme["type_degats"])
		if type_degats >= 0 and type_degats < comptes.size():
			comptes[type_degats] += maxi(int(niveaux[id]), 0)
	return comptes


## Dégâts de base d'une arme avant les bonus de type et global : ses dégâts, plus `ratio × mana
## maximale` (T8.7), plus la somme des trois bonus « selon » (`degats_par_pv_max × PV maximum de la
## tour`, `degats_par_niveau × (niveau − 1) × dégâts`, `ratio × améliorations possédées
## portant la stat × dégâts`) bornée à `bonus_max × dégâts` ; le tout multiplié par le facteur
## d'épines pour une arme dont `type_secondaire` est « epines ». Fonction pure : un champ absent ou
## nul ne change rien, un nombre non fini est ignoré.
static func degats_de_base(
	arme: Dictionary,
	stats: StatsTour,
	pv_max_tour: float,
	niveau: int,
	ameliorations_par_stat: Dictionary,
	temps_s: float,
	mana_max: float = 0.0,
	bonus_max: float = BONUS_SELON_STAT_MAX_DEFAUT,
	gain_degats: float = 0.0
) -> float:
	var base := float(arme.get("degats", 0.0))
	# D23 : chaque niveau au-dessus du premier ajoute `gain_degats` fois les dégâts de base.
	var total := base * (1.0 + _positif(gain_degats) * float(maxi(niveau - 1, 0)))
	total += _positif(float(arme.get("degats_par_mana_max", 0.0))) * _positif(mana_max)
	var selon := _positif(float(arme.get("degats_par_pv_max", 0.0))) * _positif(pv_max_tour)
	selon += (
		_positif(float(arme.get("degats_par_niveau", 0.0))) * float(maxi(niveau - 1, 0)) * base
	)
	var par_amelioration: Dictionary = arme.get("degats_par_amelioration", {})
	if not par_amelioration.is_empty():
		var nombre := int(ameliorations_par_stat.get(String(par_amelioration.get("stat", "")), 0))
		selon += _positif(float(par_amelioration.get("ratio", 0.0))) * float(maxi(nombre, 0)) * base
	total += minf(selon, _positif(bonus_max) * base)
	if String(arme.get("type_secondaire", "")) == "epines":
		total *= stats.facteur_epines(temps_s)
	return total


## `x` s'il est fini et positif, sinon 0 : un ratio aberrant ne retire ni n'ajoute rien.
static func _positif(x: float) -> float:
	return x if x > 0.0 and is_finite(x) else 0.0


## Le premier statut qui se voit ; le vol de vie, invisible, ne passe qu'en dernier recours.
static func _statut_principal(statuts: Array) -> int:
	var repli := 0
	for brut: Variant in statuts:
		var statut: Dictionary = brut
		var index := VueArene.statut_depuis_nom(String(statut["kind"]))
		if String(statut["kind"]) == "vol_de_vie":
			repli = index
		else:
			return index
	return repli


## Multiplicateur de critique ; le hasard n'est tiré que si une chance existe.
static func _critique(ctx: Contexte) -> float:
	var chance := Combat.chance_critique_effective(ctx.stats.critique_chance, ctx.palier)
	if chance > 0.0 and ctx.rng.randf() < chance:
		return Combat.puissance_critique(
			ctx.stats.critique_chance, ctx.puissance_base, ctx.coef_exces
		)
	return 1.0


static func _evenement(
	ctx: Contexte, genre: String, de: Vector2, vers: Vector2, rayon: float
) -> void:
	var evenement: Dictionary = {
		"k": genre,
		"t": 0,
		"de": de,
		"vers": vers,
		"type_degats": ctx.type_degats,
		"rayon": rayon,
		"genre": ctx.genre,
		"statut": ctx.statut,
	}
	if ctx.index_arme >= 0:
		evenement["arme"] = ctx.index_arme
	ctx.bilan.evenements.append(evenement)


## Un coup sur un ennemi : dégâts, vol de vie, mort ou statuts. Rend les dégâts réels.
static func _frapper(ctx: Contexte, i: int, degats: float) -> float:
	var ennemis := ctx.ennemis
	var stats := ctx.stats
	if not stats.degats_contre_etat.is_empty():
		# Le coup est déjà au facteur sans contre-état : on y ajoute celui de l'état de la cible,
		# le produit total restant sous le plafond.
		if is_nan(ctx.sans_etat):
			ctx.sans_etat = facteur_degats(ctx, 0)
		if ctx.sans_etat > 0.0:
			var bits := int(ennemis.statuts[i])
			if not ctx.par_etat.has(bits):
				ctx.par_etat[bits] = facteur_degats(ctx, bits)
			degats *= float(ctx.par_etat[bits]) / ctx.sans_etat
	var reels := ennemis.infliger(i, degats, ctx.type_degats)
	if reels <= 0.0:
		return 0.0
	var bilan := ctx.bilan
	bilan.degats += reels
	# `soin_vol_de_vie` d'un coup de `reels` > 0 : ne rien ajouter quand le ratio est nul (le cas
	# courant), c'était un appel par coup et par ennemi touché.
	var vol_de_vie_coup := stats.vol_de_vie_coup
	if vol_de_vie_coup > 0.0:
		bilan.soin += Combat.soin_vol_de_vie(reels, vol_de_vie_coup)
	for brut: Variant in ctx.statuts:
		var statut: Dictionary = brut
		if statut["kind"] == "vol_de_vie" and not statut.get("a_la_mort", false):
			bilan.soin += Combat.soin_vol_de_vie(reels, float(statut["ratio"]))
		elif statut["kind"] == "mana_au_coup":
			bilan.mana += float(statut["valeur"])
	if ennemis.mort[i] != 0:
		bilan.tues_directs += 1
		bilan.soin += maxf(stats.vol_de_vie_mort, 0.0)
		for brut: Variant in ctx.statuts:
			var statut: Dictionary = brut
			if statut["kind"] == "vol_de_vie" and statut.get("a_la_mort", false):
				bilan.soin += maxf(float(statut["ratio"]), 0.0) * ennemis.pv_max[i]
		return reels
	if not ctx.plan_pret:
		_preparer_plan(ctx)
	for plan: PlanStatut in ctx.plan:
		match plan.kind:
			PlanStatut.POISON:
				ennemis.empoisonner(i, plan.a * reels * plan.b, plan.c)
			PlanStatut.BRULURE:
				ennemis.bruler(i, plan.a, reels, plan.c)
			PlanStatut.GIVRE:
				ennemis.givrer(i, ctx.resistance)
			PlanStatut.ETOURDISSEMENT:
				ennemis.etourdir(i, plan.c, ctx.resistance)
			PlanStatut.VULNERABILITE:
				ennemis.vulnerabiliser(i, plan.ressource, plan.a, plan.c)
			PlanStatut.SIPHON:
				ennemis.siphonner(i, plan.ressource, plan.a, plan.c)
			PlanStatut.MALEDICTION_DEGATS:
				ennemis.maudire_degats(i, plan.a, plan.c)
			PlanStatut.MALEDICTION_TOUCHER:
				ennemis.maudire_toucher(i, plan.a, plan.c)
			PlanStatut.REPOUSSEMENT:
				var facteur := 1.0
				if ennemis.armure[i] == Types.Armure.BOSS:
					facteur = ctx.facteur_boss_repoussement
				if facteur > 0.0:
					ennemis.repousser(i, plan.a, ctx.centre, facteur)
	return reels


## Les statuts que l'arme pose, avec leurs nombres déjà lus et multipliés par les bonus de la tour :
## ils ne changent pas d'un coup à l'autre, et les relire dans les dictionnaires coûtait l'essentiel
## d'un coup sur un ennemi (T27). Même formules que les coups d'avant, dans le même ordre.
static func _preparer_plan(ctx: Contexte) -> void:
	ctx.plan_pret = true
	for brut: Variant in ctx.statuts:
		var statut: Dictionary = brut
		var plan := PlanStatut.new()
		match String(statut["kind"]):
			"poison":
				plan.kind = PlanStatut.POISON
				plan.a = float(statut["total_ratio"])
				plan.b = 1.0 + _bonus_etat(ctx, "etat_degats", "poison")
				plan.c = float(statut["duree"]) * (1.0 + _bonus_etat(ctx, "etat_duree", "poison"))
			"brulure":
				plan.kind = PlanStatut.BRULURE
				plan.a = float(statut["ratio"]) * (1.0 + _bonus_etat(ctx, "etat_degats", "brulure"))
				plan.c = float(statut["duree"]) * (1.0 + _bonus_etat(ctx, "etat_duree", "brulure"))
			"givre":
				plan.kind = PlanStatut.GIVRE
			"etourdissement":
				plan.kind = PlanStatut.ETOURDISSEMENT
				plan.c = (
					float(statut["duree"])
					* (1.0 + _bonus_etat(ctx, "etat_duree", "etourdissement"))
				)
			"vulnerabilite":
				plan.kind = PlanStatut.VULNERABILITE
				plan.ressource = int(statut.get("type_degats", -1))
				if plan.ressource < 0:
					plan.ressource = ctx.type_degats
				plan.a = float(statut["ratio"])
				plan.c = float(statut["duree"])
			"siphon":
				plan.kind = PlanStatut.SIPHON
				plan.ressource = 0 if String(statut["ressource"]) == "mana" else 1
				plan.a = float(statut["par_seconde"])
				plan.c = float(statut["duree"])
			"malediction_degats":
				plan.kind = PlanStatut.MALEDICTION_DEGATS
				plan.a = float(statut["ratio"])
				plan.c = float(statut["duree"])
			"malediction_toucher":
				plan.kind = PlanStatut.MALEDICTION_TOUCHER
				plan.a = float(statut["ratio"])
				plan.c = float(statut["duree"])
			"repoussement":
				plan.kind = PlanStatut.REPOUSSEMENT
				plan.a = float(statut["distance"])
			_:
				continue
		ctx.plan.append(plan)


## Meilleur vivant à portée du centre selon le ciblage de l'arme, hors `exclus` (identifiants) ;
## égalité parfaite : plus petit identifiant. -1 si aucun.
## Bonus d'`etat_degats` ou d'`etat_duree` pour l'état `etat`, 0 s'il n'y en a pas.
static func _bonus_etat(ctx: Contexte, stat: String, etat: String) -> float:
	var table: Dictionary = ctx.stats.get(stat)
	return maxf(float(table.get(etat, 0.0)), 0.0)


static func _choisir(ctx: Contexte, portee: float, exclus: Array[int]) -> int:
	var ennemis := ctx.ennemis
	var mode := int(ctx.arme.def["ciblage"])
	var r2 := portee * portee
	if ennemis.distance2_minimale(ctx.centre) > r2:
		return -1
	var meilleur := -1
	var meilleure_cle := 0.0
	# Les tableaux sont lus une fois : une lecture de propriété par ennemi coûtait le tiers du pas.
	var mort := ennemis.mort
	var positions := ennemis.pos
	var identifiants := ennemis.ids
	for i: int in identifiants.size():
		if mort[i] != 0:
			continue
		var d2 := positions[i].distance_squared_to(ctx.centre)
		if d2 > r2 or (not exclus.is_empty() and exclus.has(identifiants[i])):
			continue
		var cle := d2
		if mode == Types.Ciblage.PLUS_FORT:
			cle = -ennemis.pv[i]
		elif mode == Types.Ciblage.PLUS_FAIBLE:
			cle = ennemis.pv[i]
		if (
			meilleur == -1
			or cle < meilleure_cle
			or (cle == meilleure_cle and ennemis.ids[i] < ennemis.ids[meilleur])
		):
			meilleur = i
			meilleure_cle = cle
	return meilleur


static func _existe(ctx: Contexte, point: Vector2, rayon: float) -> bool:
	var ennemis := ctx.ennemis
	var r2 := rayon * rayon
	if point == ctx.centre and ennemis.distance2_minimale(point) > r2:
		return false
	var mort := ennemis.mort
	var positions := ennemis.pos
	for i: int in mort.size():
		if mort[i] != 0:
			continue
		if positions[i].distance_squared_to(point) <= r2:
			return true
	return false


## Frappe tous les vivants dans `rayon` autour de `point` ; rend leur nombre.
static func _zone(ctx: Contexte, point: Vector2, rayon: float, degats: float, exclu: int) -> int:
	var ennemis := ctx.ennemis
	var r2 := rayon * rayon
	if point == ctx.centre and ennemis.distance2_minimale(point) > r2:
		return 0
	var touches := 0
	var mort := ennemis.mort
	var positions := ennemis.pos
	for i: int in mort.size():
		if i == exclu or mort[i] != 0:
			continue
		if positions[i].distance_squared_to(point) <= r2:
			_frapper(ctx, i, degats)
			touches += 1
	return touches


static func _effet(ctx: Contexte, kind: String, effet: Dictionary) -> bool:
	match kind:
		"cible_unique", "zone", "rebond", "barrage":
			return _volees(ctx, kind, effet)
		"onde":
			return _lancer_onde(ctx, effet)
		"mine", "piege":
			return _poser_mine(ctx, effet)
		"tournant":
			return _tournant(ctx, effet)
		"zone_posee", "bombe":
			return _poser(ctx, kind, effet)
		"invocation":
			return _invoquer(ctx, effet)
	return false


# --- Zones posées et bombes -----------------------------------------------------------------------


## Pose une zone ou une bombe sur la cible choisie par le ciblage de l'arme. Les dégâts, le critique
## et les bonus sont figés à la pose ; la pose ne frappe pas.
static func _poser(ctx: Contexte, kind: String, effet: Dictionary) -> bool:
	if ctx.poses == null:
		return false
	var i := _choisir(ctx, float(ctx.arme.def["portee"]), [])
	if i < 0:
		return false
	var position := ctx.ennemis.pos[i]
	var pose: Dictionary = {
		"pos": position,
		"rayon": float(effet["rayon"]),
		"degats": ctx.degats_base * _critique(ctx) * float(effet["ratio"]),
		"type_degats": ctx.type_degats,
		"statuts": ctx.statuts,
		"statut": ctx.statut,
		"arme": maxi(ctx.index_arme, 0),
		"proprietaire": ctx.proprietaire,
		"facteur_fixe": ctx.facteur_fixe,
		"facteur_max": ctx.facteur_max,
	}
	if kind == "zone_posee":
		pose["duree"] = float(effet["duree"])
		pose["periode"] = float(effet["periode"])
		ctx.poses.ajouter_zone(pose, int(effet["max_actives"]))
	else:
		pose["delai"] = float(effet["delai"])
		ctx.poses.ajouter_bombe(pose, int(effet["max_actives"]))
	_evenement(ctx, "tir", ctx.centre, position, float(effet["rayon"]))
	return true


## Invoque un allié près de la tour : l'arme tire (et sa recharge repart) quand un ennemi est à
## portée. Les dégâts de l'allié sont `ratio_degats × dégâts de base × critique`, figés ici ; le
## type est celui de l'arme, les statuts ne passent pas.
static func _invoquer(ctx: Contexte, effet: Dictionary) -> bool:
	if ctx.allies == null:
		return false
	var indice := ctx.ids_unites.find(String(effet["unite"]))
	if indice < 0 or not _existe(ctx, ctx.centre, float(ctx.arme.def["portee"])):
		return false
	var degats := ctx.degats_base * _critique(ctx) * float(effet["ratio_degats"])
	var id := ctx.allies.invoquer(
		indice,
		ctx.centre,
		float(effet["duree"]),
		degats,
		ctx.type_degats,
		ctx.index_arme,
		ctx.proprietaire,
		int(effet["max_actives"])
	)
	if id < 0:
		return false
	_evenement(ctx, "tir", ctx.centre, ctx.allies.pos[ctx.allies.ids.size() - 1], 0.0)
	return true


## Le contexte d'une pose qui frappe : ses dégâts, son type et ses statuts sont ceux de l'arme au
## moment de la pose ; le reste (vol de vie, résistance) est celui de la tour maintenant.
static func contexte_pose(
	pose: Dictionary,
	genre: int,
	ennemis: Ennemis,
	stats: StatsTour,
	centre: Vector2,
	donnees: Donnees,
	resistance: float,
	bilan: Bilan
) -> Contexte:
	var ctx := Contexte.new()
	ctx.stats = stats
	ctx.ennemis = ennemis
	ctx.centre = centre
	ctx.resistance = resistance
	ctx.bilan = bilan
	ctx.type_degats = int(pose["type_degats"])
	ctx.statuts = pose["statuts"]
	ctx.statut = int(pose["statut"])
	ctx.genre = genre
	ctx.index_arme = int(pose["arme"])
	ctx.facteur_fixe = float(pose.get("facteur_fixe", 1.0))
	ctx.facteur_max = float(pose.get("facteur_max", INF))
	var repousse: Dictionary = donnees.partie["repoussement"]
	ctx.facteur_boss_repoussement = float(repousse["facteur_boss"])
	return ctx


## Une impulsion de zone ou l'explosion d'une bombe : frappe tous les ennemis du rayon, puis
## l'événement `impact`.
static func impulsion(ctx: Contexte, point: Vector2, rayon: float, degats: float) -> void:
	_zone(ctx, point, rayon, degats, -1)
	_evenement(ctx, "impact", ctx.centre, point, rayon)


# --- Tir tournant ------------------------------------------------------------------------------


## `branches` rayons partent de la tour à des angles régulièrement répartis, décalés de la phase de
## l'arme ; chaque rayon frappe les ennemis dont la distance au segment (tour → portée) est au plus
## `largeur`. Un ennemi n'est frappé qu'une fois par tir. La phase avance ensuite de `pas_deg`
## dans le sens de l'arme. Vrai si un tir a eu lieu : il en faut un ennemi à portée, comme pour les
## autres effets qui visent. Aucun hasard hors critique (un seul tirage par rayon, s'il y a une
## chance).
static func _tournant(ctx: Contexte, effet: Dictionary) -> bool:
	var portee := float(ctx.arme.def["portee"])
	if not _existe(ctx, ctx.centre, portee):
		return false
	var branches := int(effet["branches"])
	var largeur := float(effet["largeur"])
	var ennemis := ctx.ennemis
	var deja: Dictionary = {}
	var phase := ctx.arme.phase_deg
	for k: int in branches:
		var angle := deg_to_rad(phase + 360.0 * float(k) / float(branches))
		var bout := ctx.centre + Vector2(cos(angle), sin(angle)) * portee
		_evenement(ctx, "tir", ctx.centre, bout, largeur)
		var degats := ctx.degats_base * _critique(ctx)
		# Les tableaux sont lus une fois : un coup ne change que l'ennemi déjà passé.
		var mort := ennemis.mort
		var positions := ennemis.pos
		var identifiants := ennemis.ids
		for i: int in identifiants.size():
			if mort[i] != 0:
				continue
			var p := positions[i]
			var proche := Geometry2D.get_closest_point_to_segment(p, ctx.centre, bout)
			if proche.distance_to(p) <= largeur and not deja.has(identifiants[i]):
				deja[identifiants[i]] = true
				_frapper(ctx, i, degats)
	var sens := -1.0 if String(effet["sens"]) == "antihoraire" else 1.0
	ctx.arme.phase_deg = fposmod(phase + sens * float(effet["pas_deg"]), 360.0)
	return true


# --- Effets qui visent : un tir par cible distincte ----------------------------------------------


## `1 + tirs_multiples` tirs, chacun sur une cible choisie au moment de tirer (un mort n'est
## jamais visé) et distincte des précédentes tant qu'il en reste ; sinon la meilleure, encore.
static func _volees(ctx: Contexte, kind: String, effet: Dictionary) -> bool:
	var portee := float(ctx.arme.def["portee"])
	var deja: Array[int] = []
	var a_tire := false
	for _tir: int in 1 + maxi(ctx.stats.tirs_multiples, 0):
		var i := _choisir(ctx, portee, deja)
		if i < 0 and not deja.is_empty():
			i = _choisir(ctx, portee, [])
		if i < 0:
			break
		deja.append(ctx.ennemis.ids[i])
		a_tire = true
		match kind:
			"cible_unique":
				_tir_cible_unique(ctx, i)
			"zone":
				_tir_zone(ctx, i, float(effet["rayon"]))
			"rebond":
				_tir_rebond(ctx, i, effet)
			"barrage":
				_tir_barrage(ctx, i, effet)
	return a_tire


static func _tir_cible_unique(ctx: Contexte, i: int) -> void:
	var position := ctx.ennemis.pos[i]
	var degats := ctx.degats_base * _critique(ctx) * (1.0 + maxf(ctx.stats.focalisation, 0.0))
	_evenement(ctx, "tir", ctx.centre, position, 0.0)
	_frapper(ctx, i, degats)
	var rayon := 0.0
	if ctx.stats.eclaboussure > 0.0:
		rayon = RAYON_ECLABOUSSURE
		_zone(ctx, position, rayon, degats * ctx.stats.eclaboussure, i)
	_evenement(ctx, "impact", ctx.centre, position, rayon)


static func _tir_zone(ctx: Contexte, i: int, rayon: float) -> void:
	var position := ctx.ennemis.pos[i]
	_evenement(ctx, "tir", ctx.centre, position, 0.0)
	_zone(ctx, position, rayon, ctx.degats_base * _critique(ctx), -1)
	_evenement(ctx, "impact", ctx.centre, position, rayon)


static func _tir_rebond(ctx: Contexte, depart: int, effet: Dictionary) -> void:
	var ennemis := ctx.ennemis
	var saut := float(effet["portee_saut"])
	var decroissance := float(effet["decroissance"])
	var degats := ctx.degats_base * _critique(ctx)
	var touchees: Array[int] = []
	var precedente := ctx.centre
	var c := depart
	_evenement(ctx, "tir", ctx.centre, ennemis.pos[depart], 0.0)
	for k: int in int(effet["cibles"]):
		if c < 0:
			break
		var position := ennemis.pos[c]
		touchees.append(ennemis.ids[c])
		_frapper(ctx, c, degats * pow(decroissance, k))
		_evenement(ctx, "impact", precedente, position, 0.0)
		precedente = position
		c = _choisir_autour(ctx, position, saut, touchees)
		if c >= 0 and ennemis.mort[c] != 0:
			c = -1


## Vivant le plus proche de `point` dans `rayon`, hors `exclus` (identifiants) ; -1 si aucun.
static func _choisir_autour(ctx: Contexte, point: Vector2, rayon: float, exclus: Array[int]) -> int:
	var ennemis := ctx.ennemis
	var r2 := rayon * rayon
	var meilleur := -1
	var meilleur_d2 := 0.0
	# Les tableaux sont lus une fois, et la portée se teste avant la liste des exclus : un rebond
	# parcourait mille ennemis par saut, propriété par propriété (T27).
	var mort := ennemis.mort
	var positions := ennemis.pos
	var identifiants := ennemis.ids
	for i: int in identifiants.size():
		if mort[i] != 0:
			continue
		var d2 := positions[i].distance_squared_to(point)
		if d2 > r2 or exclus.has(identifiants[i]):
			continue
		if (
			meilleur == -1
			or d2 < meilleur_d2
			or (d2 == meilleur_d2 and identifiants[i] < identifiants[meilleur])
		):
			meilleur = i
			meilleur_d2 = d2
	return meilleur


## Projectiles dirigés vers la cible, chacun écarté de la ligne de tir d'un angle tiré par le
## `rng` dans ± `dispersion_deg / 2`, tombant à la distance de la cible.
static func _tir_barrage(ctx: Contexte, i: int, effet: Dictionary) -> void:
	var position := ctx.ennemis.pos[i]
	var vers := position - ctx.centre
	var distance := vers.length()
	var direction := vers / distance if distance > 0.0 else Vector2.RIGHT
	var demi := float(effet["dispersion_deg"]) / 2.0
	var rayon := float(effet["rayon"])
	_evenement(ctx, "tir", ctx.centre, position, 0.0)
	for _p: int in int(effet["projectiles"]):
		var angle := deg_to_rad(ctx.rng.randf_range(-demi, demi))
		var point := ctx.centre + direction.rotated(angle) * distance
		_zone(ctx, point, rayon, ctx.degats_base * _critique(ctx), -1)
		_evenement(ctx, "impact", ctx.centre, point, rayon)


# --- Onde --------------------------------------------------------------------------------------


static func _lancer_onde(ctx: Contexte, _effet_onde: Dictionary) -> bool:
	var i := _choisir(ctx, float(ctx.arme.def["portee"]), [])
	if i < 0:
		return false
	(
		ctx
		. arme
		. ondes
		. append(
			{
				"rayon": 0.0,
				"deja_touches": PackedInt32Array(),
				"degats": ctx.degats_base * _critique(ctx),
			}
		)
	)
	_evenement(ctx, "tir", ctx.centre, ctx.ennemis.pos[i], 0.0)
	return true


## Fait grandir chaque onde de `vitesse × dt` au plus jusqu'à `rayon_max` et frappe une seule
## fois chaque ennemi qu'elle a atteint (identifiants triés, recherche dichotomique).
static func _avancer_ondes(ctx: Contexte, effets: Array, dt: float) -> void:
	var ondes := ctx.arme.ondes
	if ondes.is_empty():
		return
	var effet := _premier_effet(effets, ["onde"])
	if effet.is_empty():
		ondes.clear()
		return
	ctx.genre = VueArene.genre_depuis_nom("onde")
	var rayon_max := float(effet["rayon_max"])
	var vitesse := float(effet["vitesse"])
	var ennemis := ctx.ennemis
	for k: int in range(ondes.size() - 1, -1, -1):
		var onde := ondes[k]
		var rayon := minf(float(onde["rayon"]) + vitesse * dt, rayon_max)
		onde["rayon"] = rayon
		var touches: PackedInt32Array = onde["deja_touches"]
		var degats := float(onde["degats"])
		var r2 := rayon * rayon
		var nouveaux := 0
		# Les tableaux sont lus une fois : un coup ne change que l'ennemi déjà passé.
		var mort := ennemis.mort
		var positions := ennemis.pos
		var identifiants := ennemis.ids
		for i: int in identifiants.size():
			if mort[i] != 0 or positions[i].distance_squared_to(ctx.centre) > r2:
				continue
			var id := identifiants[i]
			var rang := touches.bsearch(id)
			if rang < touches.size() and touches[rang] == id:
				continue
			touches.insert(rang, id)
			_frapper(ctx, i, degats)
			nouveaux += 1
		onde["deja_touches"] = touches
		if nouveaux > 0:
			_evenement(ctx, "impact", ctx.centre, ctx.centre, rayon)
		if rayon >= rayon_max:
			ondes.remove_at(k)


static func _premier_effet(effets: Array, kinds: Array[String]) -> Dictionary:
	for brut: Variant in effets:
		var effet: Dictionary = brut
		if kinds.has(String(effet["kind"])):
			return effet
	return {}


# --- Mines et pièges ---------------------------------------------------------------------------


## Pose à la position d'un ennemi ; rien si le nombre de mines actives est atteint.
static func _poser_mine(ctx: Contexte, effet: Dictionary) -> bool:
	if ctx.arme.mines.size() >= int(effet["max_actives"]):
		return false
	var i := _choisir(ctx, float(ctx.arme.def["portee"]), [])
	if i < 0:
		return false
	var position := ctx.ennemis.pos[i]
	ctx.arme.mines.append(position)
	_evenement(ctx, "tir", ctx.centre, position, 0.0)
	return true


## Une mine explose, et disparaît, dès qu'un ennemi entre dans son rayon ; elle ne tient pas à
## l'ennemi sur lequel elle a été posée.
static func _declencher_mines(ctx: Contexte, effets: Array) -> void:
	var mines := ctx.arme.mines
	if mines.is_empty():
		return
	var effet := _premier_effet(effets, ["mine", "piege"])
	if effet.is_empty():
		return
	ctx.genre = VueArene.genre_depuis_nom(String(effet["kind"]))
	var rayon := float(effet["rayon"])
	for k: int in range(mines.size() - 1, -1, -1):
		var point := mines[k]
		if not _existe(ctx, point, rayon):
			continue
		mines.remove_at(k)
		_zone(ctx, point, rayon, ctx.degats_base * _critique(ctx), -1)
		_evenement(ctx, "impact", ctx.centre, point, rayon)


# --- Aura --------------------------------------------------------------------------------------


## Frappe tout ce qui est dans le rayon ; ne consomme rien s'il n'y a personne.
static func _aura(ctx: Contexte, effet: Dictionary) -> bool:
	var rayon := float(effet["rayon"])
	if not _existe(ctx, ctx.centre, rayon):
		return false
	_zone(ctx, ctx.centre, rayon, ctx.degats_base * _critique(ctx), -1)
	_evenement(ctx, "impact", ctx.centre, ctx.centre, rayon)
	return true
