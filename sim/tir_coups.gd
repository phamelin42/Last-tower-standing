class_name TirCoups
extends RefCounted
## Un coup d'arme sur un ennemi (`frapper`) : dégâts réels, vol de vie, mort, puis les statuts que
## l'arme pose, lus dans un plan préparé une fois par contexte. Sorti de `tir.gd` pour le garder
## sous la limite de lignes ; `Tir` résout les effets et appelle ce fichier à chaque ennemi touché.


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


## Un coup sur un ennemi : dégâts, vol de vie, mort ou statuts. Rend les dégâts réels.
static func frapper(ctx: Tir.Contexte, i: int, degats: float) -> float:
	var ennemis := ctx.ennemis
	var stats := ctx.stats
	if not stats.degats_contre_etat.is_empty():
		# Le coup est déjà au facteur sans contre-état : on y ajoute celui de l'état de la cible,
		# le produit total restant sous le plafond.
		if is_nan(ctx.sans_etat):
			ctx.sans_etat = Tir.facteur_degats(ctx, 0)
		if ctx.sans_etat > 0.0:
			var bits := int(ennemis.statuts[i])
			if not ctx.par_etat.has(bits):
				ctx.par_etat[bits] = Tir.facteur_degats(ctx, bits)
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
		preparer_plan(ctx)
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
static func preparer_plan(ctx: Tir.Contexte) -> void:
	ctx.plan_pret = true
	for brut: Variant in ctx.statuts:
		var statut: Dictionary = brut
		var plan := PlanStatut.new()
		match String(statut["kind"]):
			"poison":
				plan.kind = PlanStatut.POISON
				plan.a = float(statut["total_ratio"])
				plan.b = 1.0 + bonus_etat(ctx, "etat_degats", "poison")
				plan.c = float(statut["duree"]) * (1.0 + bonus_etat(ctx, "etat_duree", "poison"))
			"brulure":
				plan.kind = PlanStatut.BRULURE
				plan.a = float(statut["ratio"]) * (1.0 + bonus_etat(ctx, "etat_degats", "brulure"))
				plan.c = float(statut["duree"]) * (1.0 + bonus_etat(ctx, "etat_duree", "brulure"))
			"givre":
				plan.kind = PlanStatut.GIVRE
			"etourdissement":
				plan.kind = PlanStatut.ETOURDISSEMENT
				plan.c = (
					float(statut["duree"]) * (1.0 + bonus_etat(ctx, "etat_duree", "etourdissement"))
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


## Bonus d'`etat_degats` ou d'`etat_duree` pour l'état `etat`, 0 s'il n'y en a pas.
static func bonus_etat(ctx: Tir.Contexte, stat: String, etat: String) -> float:
	var table: Dictionary = ctx.stats.get(stat)
	return maxf(float(table.get(etat, 0.0)), 0.0)
