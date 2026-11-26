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


## Ce qu'un pas a produit, pour l'arène : dégâts réellement infligés, ennemis tués par un coup
## de l'arme, soin de la tour, évènements de rendu (le tick est posé par l'arène).
class Bilan:
	var degats: float = 0.0
	var tues_directs: int = 0
	var soin: float = 0.0
	var evenements: Array[Dictionary] = []


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
	var statuts: Array
	var palier: float
	var puissance_base: float
	var coef_exces: float
	## Part du repoussement qui s'applique au boss (`partie.json` `repoussement.facteur_boss`).
	var facteur_boss_repoussement: float


static func avancer_arme(
	arme: ArmeEquipee,
	dt: float,
	stats: StatsTour,
	ennemis: Ennemis,
	centre: Vector2,
	donnees: Donnees,
	rng: RandomNumberGenerator,
	resistance: float,
	bilan: Bilan
) -> void:
	if not dt > 0.0 or not is_finite(dt):
		return
	var ctx := _creer(arme, stats, ennemis, centre, donnees, rng, resistance, bilan)
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
				arme.aura_restante = float(effet["periode"]) / (1.0 + maxf(stats.cadence, 0.0))


static func _creer(
	arme: ArmeEquipee,
	stats: StatsTour,
	ennemis: Ennemis,
	centre: Vector2,
	donnees: Donnees,
	rng: RandomNumberGenerator,
	resistance: float,
	bilan: Bilan
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
	# Une arme de mana ajoute `ratio × mana maximale` aux dégâts de base, avant les multiplicateurs.
	var mana_max := float(donnees.partie["tour"]["mana_max"]) + stats.mana_max_bonus
	var brut := (
		float(arme.def["degats"]) + float(arme.def.get("degats_par_mana_max", 0.0)) * mana_max
	)
	ctx.degats_base = brut * stats.degats_type[ctx.type_degats] * stats.degats_global
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
	var reels := ctx.ennemis.infliger(i, degats, ctx.type_degats)
	if reels <= 0.0:
		return 0.0
	var bilan := ctx.bilan
	bilan.degats += reels
	bilan.soin += Combat.soin_vol_de_vie(reels, ctx.stats.vol_de_vie_coup)
	for brut: Variant in ctx.statuts:
		var statut: Dictionary = brut
		if statut["kind"] == "vol_de_vie" and not statut.get("a_la_mort", false):
			bilan.soin += Combat.soin_vol_de_vie(reels, float(statut["ratio"]))
	if ctx.ennemis.mort[i] != 0:
		bilan.tues_directs += 1
		bilan.soin += maxf(ctx.stats.vol_de_vie_mort, 0.0)
		for brut: Variant in ctx.statuts:
			var statut: Dictionary = brut
			if statut["kind"] == "vol_de_vie" and statut.get("a_la_mort", false):
				bilan.soin += maxf(float(statut["ratio"]), 0.0) * ctx.ennemis.pv_max[i]
		return reels
	for brut: Variant in ctx.statuts:
		var statut: Dictionary = brut
		match String(statut["kind"]):
			"poison":
				ctx.ennemis.empoisonner(
					i, float(statut["total_ratio"]) * reels, float(statut["duree"])
				)
			"brulure":
				ctx.ennemis.bruler(i, float(statut["ratio"]), reels, float(statut["duree"]))
			"givre":
				ctx.ennemis.givrer(i, ctx.resistance)
			"etourdissement":
				ctx.ennemis.etourdir(i, float(statut["duree"]), ctx.resistance)
			"vulnerabilite":
				var type_vulnerable := int(statut.get("type_degats", -1))
				if type_vulnerable < 0:
					type_vulnerable = ctx.type_degats
				ctx.ennemis.vulnerabiliser(
					i, type_vulnerable, float(statut["ratio"]), float(statut["duree"])
				)
			"malediction_degats":
				ctx.ennemis.maudire_degats(i, float(statut["ratio"]), float(statut["duree"]))
			"malediction_toucher":
				ctx.ennemis.maudire_toucher(i, float(statut["ratio"]), float(statut["duree"]))
			"repoussement":
				var facteur := 1.0
				if ctx.ennemis.armure[i] == Types.Armure.BOSS:
					facteur = ctx.facteur_boss_repoussement
				if facteur > 0.0:
					ctx.ennemis.repousser(i, float(statut["distance"]), ctx.centre, facteur)
	return reels


## Meilleur vivant à portée du centre selon le ciblage de l'arme, hors `exclus` (identifiants) ;
## égalité parfaite : plus petit identifiant. -1 si aucun.
static func _choisir(ctx: Contexte, portee: float, exclus: Array[int]) -> int:
	var ennemis := ctx.ennemis
	var mode := int(ctx.arme.def["ciblage"])
	var r2 := portee * portee
	if ennemis.distance2_minimale(ctx.centre) > r2:
		return -1
	var meilleur := -1
	var meilleure_cle := 0.0
	for i: int in ennemis.ids.size():
		if ennemis.mort[i] != 0:
			continue
		var d2 := ennemis.pos[i].distance_squared_to(ctx.centre)
		if d2 > r2 or (not exclus.is_empty() and exclus.has(ennemis.ids[i])):
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
	for i: int in ennemis.ids.size():
		if ennemis.mort[i] != 0:
			continue
		if ennemis.pos[i].distance_squared_to(point) <= r2:
			return true
	return false


## Frappe tous les vivants dans `rayon` autour de `point` ; rend leur nombre.
static func _zone(ctx: Contexte, point: Vector2, rayon: float, degats: float, exclu: int) -> int:
	var ennemis := ctx.ennemis
	var r2 := rayon * rayon
	if point == ctx.centre and ennemis.distance2_minimale(point) > r2:
		return 0
	var touches := 0
	for i: int in ennemis.ids.size():
		if i == exclu or ennemis.mort[i] != 0:
			continue
		if ennemis.pos[i].distance_squared_to(point) <= r2:
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
	return false


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
	for i: int in ennemis.ids.size():
		if ennemis.mort[i] != 0 or exclus.has(ennemis.ids[i]):
			continue
		var d2 := ennemis.pos[i].distance_squared_to(point)
		if d2 > r2:
			continue
		if (
			meilleur == -1
			or d2 < meilleur_d2
			or (d2 == meilleur_d2 and ennemis.ids[i] < ennemis.ids[meilleur])
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
		for i: int in ennemis.ids.size():
			if ennemis.mort[i] != 0 or ennemis.pos[i].distance_squared_to(ctx.centre) > r2:
				continue
			var id := ennemis.ids[i]
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
