class_name Arene
extends RefCounted
## L'arène d'un joueur : une tour, ses armes, sa boutique, son or et les ennemis qui la
## assiègent. `Partie` la pilote (manches, boss) et lit sa `VueArene`.
##
## Ordre d'un pas (`avancer`), qui fait la reproductibilité : le hasard d'une arène vient d'un seul
## `RandomNumberGenerator`, consommé toujours dans cet ordre.
##   1. revenu (versement périodique) ;
##   2. apparitions (un tirage d'angle par ennemi) ;
##   3. régénération de la tour, puis ennemis et statuts (`Ennemis.avancer` fait avancer les
##      statuts de chaque ennemi avant de le déplacer et de le faire attaquer), puis dégâts à la
##      tour (esquive tirée par attaque) et épines ;
##   4. armes, dans l'ordre d'équipement (critiques, éclaboussures et statuts tirés ici) ;
##   5. purge des morts : primes, bonus d'éliminations, évènements de mort ;
##   6. défaite : évaluée en dernier, donc une tour à 0 PV est détruite même si son dernier
##      ennemi (le boss) est tombé au même pas. La défaite l'emporte sur la victoire.

signal tour_detruite

## Évènements gardés entre deux lectures de la vue : au-delà, les nouveaux sont ignorés, pour
## qu'une arène que personne ne lit ne grossisse pas sans fin.
const EVENEMENTS_MAX := 2000
## Apparitions par pas au plus : un `dt` démesuré ne doit pas figer la simulation.
const APPARITIONS_MAX_PAR_PAS := 1000
## Tolérance sur le cumulateur : 40 pas de 0,05 s n'additionnent pas exactement 2,0 s.
const EPSILON_TEMPS := 1e-9
## Sous ce reste, la part « à distance » des dégâts subis n'est que du bruit d'arrondi.
const EPSILON_DEGATS := 1e-6
## Largeur (secondes) de la moyenne glissante des dégâts par seconde.
const FENETRE_DPS_S := 10.0
## Côté de la carte de densité, en cases.
const DENSITE_COTE := 16

## Points de vie de la tour, entre 0 et le maximum.
var pv: float = 0.0
## Mana de la tour, entre 0 et `mana_max()` : elle absorbe les coups avant les PV.
var mana: float = 0.0
var ennemis: Ennemis
## Zones posées et bombes : elles disparaissent avec la manche et la tour.
var poses: Poses
var economie: Economie
var inventaire: Inventaire
var boutique: Boutique
var armes: Array[ArmeEquipee] = []

var _donnees: Donnees
var _rng: RandomNumberGenerator
var _stats: StatsTour
var _tick: int = 0
var _temps: float = 0.0
var _manche: int = 0
var _manche_max: int = 0
var _composition: Composition = null
## Tire la famille de chaque apparition : graine de la composition, donc la même suite chez tous les
## joueurs ; à part de `_rng` (positions) pour ne pas décaler leur suite.
var _rng_familles := RandomNumberGenerator.new()
var _mult_pv: float = 1.0
var _mult_degats: float = 1.0
var _mult_vitesse: float = 1.0
var _resistance: float = 1.0
var _boss_en_cours: bool = false
var _boss_id: int = -1
var _boss_mort: bool = false
var _cumul_apparition: float = 0.0
var _relances_utilisees: int = 0
var _pv_max_connu: float = 0.0
var _mana_max_connu: float = 0.0
var _eliminations: int = 0
var _degats_infliges: float = 0.0
var _detruite: bool = false
## Dégâts infligés par pas, pour `dps` : seuls les pas où la tour a infligé quelque chose y sont
## notés (instant du pas, dégâts), les plus anciens en tête.
var _histo_temps: PackedFloat64Array = PackedFloat64Array()
var _histo_degats: PackedFloat64Array = PackedFloat64Array()
var _evenements: Array[Dictionary] = []
var _rayon_spawn: float
var _rayon_tour: float
var _armure_tour: float
var _esquive_k: float
var _intervalle_depart: float
var _baisse_par_manche: float
var _plancher: float


func _init(donnees: Donnees, graine: int) -> void:
	_donnees = donnees
	_rng = RandomNumberGenerator.new()
	_rng.seed = graine
	var partie: Dictionary = donnees.partie
	var tour: Dictionary = partie["tour"]
	_rayon_spawn = float(partie["rayon_spawn"])
	_rayon_tour = float(tour["rayon"])
	_armure_tour = float(tour["armure"])
	_esquive_k = float(partie["esquive_k"])
	_intervalle_depart = float(partie["spawn_intervalle_depart"])
	_baisse_par_manche = float(partie["spawn_baisse_par_manche"])
	_plancher = float(partie["spawn_plancher"])
	ennemis = Ennemis.new(donnees)
	poses = Poses.new(donnees)
	economie = Economie.new(donnees)
	inventaire = Inventaire.new(donnees)
	boutique = Boutique.new(donnees, _rng)
	boutique.tirer(1)
	_stats = inventaire.stats()
	_pv_max_connu = _pv_max()
	pv = _pv_max_connu
	_mana_max_connu = mana_max()
	mana = _mana_max_connu


# --- Manches -----------------------------------------------------------------------------------


## `composition` : les familles de la manche et leurs poids (`Composition.unique(familles.size())`
## pour le convoi) ; une composition sans famille ne fait rien apparaître. `mult` : {pv, degats,
## vitesse, resistance_controle}, lu une fois pour la manche.
func demarrer_manche(numero: int, composition: Composition, mult: Dictionary) -> void:
	if _detruite:
		return
	_manche = maxi(numero, 0)
	_manche_max = maxi(_manche_max, _manche)
	_composition = composition
	poses.vider()
	if composition != null:
		_rng_familles.seed = composition.graine
	_lire_mult(mult)
	_boss_en_cours = false
	# Sans fin : le boss tombé ne doit pas redonner la victoire à chaque pas.
	_boss_mort = false
	_cumul_apparition = 0.0
	_relances_utilisees = 0
	boutique.nouvelle_manche(_manche, _relances_gratuites())


## Le boss remplace les apparitions normales : il arrive seul, les ennemis déjà là restent.
func demarrer_boss(mult: Dictionary) -> void:
	if _detruite:
		return
	_manche = maxi(_manche, int(_donnees.partie["manche_boss"]))
	_manche_max = maxi(_manche_max, _manche)
	poses.vider()
	_lire_mult(mult)
	_boss_en_cours = true
	_composition = null
	_cumul_apparition = 0.0
	var b: Dictionary = _donnees.boss
	_boss_id = ennemis.ajouter(
		_donnees.familles.size() + 1,
		_point_d_apparition(),
		float(b["pv"]) * _mult_pv,
		float(b["vitesse"]) * _mult_vitesse,
		float(b["degats"]) * _mult_degats,
		float(b["portee_attaque"]),
		float(b["cadence_attaque"]),
		int(b.get("prime", 0)),
		Types.Armure.BOSS
	)


func _lire_mult(mult: Dictionary) -> void:
	_mult_pv = _facteur(mult, "pv")
	_mult_degats = _facteur(mult, "degats")
	_mult_vitesse = _facteur(mult, "vitesse")
	_resistance = _facteur(mult, "resistance_controle")


## Un multiplicateur absent, négatif ou non fini vaut 1 : il ne casse pas la manche.
static func _facteur(mult: Dictionary, cle: String) -> float:
	var v: Variant = mult.get(cle, 1.0)
	if not (v is float or v is int):
		return 1.0
	var f := float(v)
	return f if is_finite(f) and f >= 0.0 else 1.0


# --- Pas de simulation -------------------------------------------------------------------------


func avancer(dt: float) -> void:
	if _detruite or not dt > 0.0 or not is_finite(dt):
		return
	_tick += 1
	_temps += dt
	var degats_avant := _degats_infliges
	economie.avancer(dt, _manche, _stats, _temps)
	_faire_apparaitre(dt)
	_pas_tour_et_ennemis(dt)
	_pas_armes(dt)
	_pas_poses(dt)
	_noter_degats(_degats_infliges - degats_avant)
	_purger()
	_pv_borne()
	if pv <= 0.0:
		pv = 0.0
		_detruite = true
		poses.vider()
		tour_detruite.emit()


func _noter_degats(degats: float) -> void:
	if degats > 0.0:
		_histo_temps.append(_temps)
		_histo_degats.append(degats)
	var limite := _temps - FENETRE_DPS_S
	var perimes := 0
	while perimes < _histo_temps.size() and _histo_temps[perimes] <= limite:
		perimes += 1
	if perimes > 0:
		_histo_temps = _histo_temps.slice(perimes)
		_histo_degats = _histo_degats.slice(perimes)


## Dégâts infligés par seconde sur les `FENETRE_DPS_S` dernières secondes, épines comprises ;
## avant la fin de la première fenêtre, on divise par le temps écoulé.
func dps() -> float:
	if not _temps > 0.0:
		return 0.0
	var limite := _temps - FENETRE_DPS_S
	var somme := 0.0
	for i: int in _histo_temps.size():
		if _histo_temps[i] > limite:
			somme += _histo_degats[i]
	return somme / minf(_temps, FENETRE_DPS_S)


## Nombre d'ennemis vivants par case, `DENSITE_COTE` × `DENSITE_COTE` cases ligne par ligne, sur
## le carré de côté 2 × rayon d'apparition centré sur la tour ; une case sature à 255.
func carte_densite() -> PackedByteArray:
	var carte := PackedByteArray()
	carte.resize(DENSITE_COTE * DENSITE_COTE)
	var pas_case := 2.0 * _rayon_spawn / float(DENSITE_COTE)
	var maxi_case := DENSITE_COTE - 1
	for i: int in ennemis.pos.size():
		if ennemis.mort[i] != 0:
			continue
		var p := ennemis.pos[i]
		var cx := clampi(floori((p.x + _rayon_spawn) / pas_case), 0, maxi_case)
		var cy := clampi(floori((p.y + _rayon_spawn) / pas_case), 0, maxi_case)
		var k := cy * DENSITE_COTE + cx
		if carte[k] < 255:
			carte[k] += 1
	return carte


func _faire_apparaitre(dt: float) -> void:
	if _boss_en_cours or _manche < 1 or _composition == null or _composition.majoritaire() < 0:
		return
	_cumul_apparition += dt
	var intervalle := maxf(_plancher, _intervalle_depart - _baisse_par_manche * (_manche - 1))
	var n := 0
	while _cumul_apparition + EPSILON_TEMPS >= intervalle:
		_cumul_apparition = maxf(_cumul_apparition - intervalle, 0.0)
		_apparaitre()
		n += 1
		if n >= APPARITIONS_MAX_PAR_PAS:
			_cumul_apparition = 0.0
			break


func _apparaitre() -> void:
	var position := _point_d_apparition()
	var famille := _composition.tirer(_rng_familles)
	if famille >= _donnees.familles.size():
		# Convoi : il marche vers la tour sans jamais attaquer, et sa prime est élevée.
		var c: Dictionary = _donnees.convoi
		ennemis.ajouter(
			_donnees.familles.size(),
			position,
			float(c["pv"]) * _mult_pv,
			float(c["vitesse"]) * _mult_vitesse,
			0.0,
			0.0,
			0.0,
			int(c["prime"]),
			Types.Armure.AUCUNE
		)
		return
	var f: Dictionary = _donnees.familles[famille]
	ennemis.ajouter(
		famille,
		position,
		float(f["pv"]) * _mult_pv,
		float(f["vitesse"]) * _mult_vitesse,
		float(f["degats"]) * _mult_degats,
		float(f["portee_attaque"]),
		float(f["cadence_attaque"]),
		int(f["prime"]),
		int(f["armure"]),
		bool(f["explose"])
	)


func _point_d_apparition() -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU) * _rayon_spawn


func _pas_tour_et_ennemis(dt: float) -> void:
	if _stats.regen > 0.0:
		pv = minf(pv + _stats.regen * dt, _pv_max())
	mana = minf(mana + _mana_regen() * dt, mana_max())
	var resultat := ennemis.avancer(dt, Vector2.ZERO, _rayon_tour, 1.0, 1.0)
	mana_gagnee(float(resultat["siphon_mana"]))
	pv = minf(pv + float(resultat["siphon_vie"]), _pv_max())
	var total: float = resultat["degats_tour"]
	if not total > 0.0:
		return
	var attaquants: PackedInt32Array = resultat["attaquants_cac"]
	var chance := Combat.chance_esquive(_stats.esquive, _esquive_k)
	var subis := 0.0
	var total_cac := 0.0
	# Au corps à corps, chaque attaque est esquivée ou non (et ne déclenche les épines que si elle
	# touche). `Ennemis.avancer` ne rend que la somme des attaques à distance : elles forment un
	# seul tirage par pas.
	for i: int in attaquants:
		var coup: float = ennemis.degats_effectifs(i)
		total_cac += coup
		if _esquive(chance):
			continue
		subis += coup
		if _stats.epines > 0.0:
			_degats_infliges += ennemis.infliger(i, _stats.epines * coup, Types.TypeDegats.CHAOS)
	var a_distance := total - total_cac
	if a_distance > EPSILON_DEGATS and not _esquive(chance):
		subis += a_distance
	var apres_armure := Combat.degats_subis(subis, _armure_tour + _stats.armure)
	# Ordre : esquive, armure, mana, PV. Un point de mana absorbe un point de dégât.
	var absorbe := minf(mana, apres_armure)
	if absorbe > 0.0:
		mana -= absorbe
		_ajouter_evenement(
			{
				"k": "absorption",
				"t": _tick,
				"de": Vector2.ZERO,
				"vers": Vector2.ZERO,
				"type_degats": Types.TypeDegats.TRANCHANT,
				"rayon": 0.0
			}
		)
	pv -= apres_armure - absorbe


## Le hasard n'est consommé que si une chance existe : sans esquive, la suite des tirages ne
## change pas.
func _esquive(chance: float) -> bool:
	return chance > 0.0 and _rng.randf() < chance


func _pas_armes(dt: float) -> void:
	if armes.is_empty():
		return
	var bilan := Tir.Bilan.new()
	var lecture := Tir.Lecture.new()
	lecture.pv_max_tour = _pv_max()
	lecture.temps_s = _temps
	lecture.exemplaires = inventaire.comptes_armes()
	lecture.ameliorations_par_stat = inventaire.comptes_stats()
	lecture.poses = poses
	for arme: ArmeEquipee in armes:
		Tir.avancer_arme(
			arme, dt, _stats, ennemis, Vector2.ZERO, _donnees, _rng, _resistance, bilan, lecture
		)
	_degats_infliges += bilan.degats
	pv = minf(pv + bilan.soin, _pv_max())
	mana_gagnee(bilan.mana)
	for e: Dictionary in bilan.evenements:
		e["t"] = _tick
		_ajouter_evenement(e)


## Les impulsions des zones et l'explosion des bombes, sur les ennemis de l'arène.
func _pas_poses(dt: float) -> void:
	if poses.zones.is_empty() and poses.bombes.is_empty():
		return
	var bilan := poses.avancer(dt, ennemis, _stats, Vector2.ZERO, _donnees, _resistance)
	_degats_infliges += bilan.degats
	pv = minf(pv + bilan.soin, _pv_max())
	mana_gagnee(bilan.mana)
	for e: Dictionary in bilan.evenements:
		e["t"] = _tick
		_ajouter_evenement(e)


## Un objet ou une prime ne se compte qu'une fois par ennemi, quelle que soit la cause de la
## mort : tout passe par la purge.
func _purger() -> void:
	for r: Dictionary in ennemis.purger():
		var p: Vector2 = r["pos"]
		# Mort par explosion (un Tonneau au contact) : ni prime ni élimination, seulement
		# l'événement qui fait disparaître l'ennemi à l'écran.
		if not bool(r["sans_prime"]):
			_eliminations += 1
			economie.gagner(economie.prime(int(r["prime"]), _manche, _stats))
			economie.gagner(economie.enregistrer_elimination(_stats))
			if int(r["id"]) == _boss_id:
				_boss_mort = true
		_ajouter_evenement(
			{
				"k": "mort",
				"t": _tick,
				"de": p,
				"vers": p,
				"type_degats": Types.TypeDegats.CHAOS,
				"rayon": 0.0
			}
		)


func _ajouter_evenement(e: Dictionary) -> void:
	if _evenements.size() < EVENEMENTS_MAX:
		_evenements.append(e)


func _pv_borne() -> void:
	pv = clampf(pv, -INF, _pv_max())


# --- Intentions du joueur ----------------------------------------------------------------------


func acheter(index: int) -> int:
	if _detruite:
		return Types.Resultat.ARENE_MORTE
	var resultat := boutique.acheter(index, economie, inventaire)
	if resultat == Types.Resultat.OK:
		synchroniser()
	return resultat


func relancer() -> int:
	if _detruite:
		return Types.Resultat.ARENE_MORTE
	var libres := _relances_gratuites()
	var retour := boutique.relancer(economie, libres)
	if int(retour[0]) == Types.Resultat.OK and int(retour[1]) < libres:
		_relances_utilisees += 1
	return int(retour[0])


func vendre(index_arme: int) -> int:
	if _detruite:
		return Types.Resultat.ARENE_MORTE
	var resultat := boutique.vendre(index_arme, economie, inventaire)
	if resultat == Types.Resultat.OK:
		synchroniser()
	return resultat


func choisir_marche_noir(id: String) -> int:
	if _detruite:
		return Types.Resultat.ARENE_MORTE
	var resultat := boutique.acheter_marche_noir(id, economie, inventaire)
	if resultat == Types.Resultat.OK:
		synchroniser()
	return resultat


## Recalcule les statistiques et aligne les armes montées sur l'inventaire : une arme déjà
## montée garde sa recharge, une vente retire seulement la sienne. Appelée après chaque
## intention qui change l'inventaire (et par les tests qui l'équipent directement).
func synchroniser() -> void:
	_stats = inventaire.stats()
	var anciennes := armes
	var prises: Array[bool] = []
	prises.resize(anciennes.size())
	var nouvelles: Array[ArmeEquipee] = []
	for id: String in inventaire.armes:
		var trouvee: ArmeEquipee = null
		for k: int in anciennes.size():
			if not prises[k] and anciennes[k].id == id:
				prises[k] = true
				trouvee = anciennes[k]
				break
		if trouvee == null:
			trouvee = ArmeEquipee.new(_donnees.armes[id])
		nouvelles.append(trouvee)
	armes = nouvelles
	# Un objet de PV max soigne du même montant ; si le maximum baisse, les PV se recalent.
	var nouveau_max := _pv_max()
	if nouveau_max > _pv_max_connu:
		pv += nouveau_max - _pv_max_connu
	_pv_max_connu = nouveau_max
	pv = minf(pv, nouveau_max)
	# Un maximum de mana qui monte donne du même montant en mana, comme les PV.
	var nouvelle_mana_max := mana_max()
	if nouvelle_mana_max > _mana_max_connu:
		mana += nouvelle_mana_max - _mana_max_connu
	_mana_max_connu = nouvelle_mana_max
	mana = minf(mana, nouvelle_mana_max)


# --- Lecture -----------------------------------------------------------------------------------


## La vue publique, puis les évènements sont vidés : chacun n'est lu qu'une fois.
## `composition` : celle de la manche annoncée (familles et armures de la vue) ; sans elle, la seule
## famille `prochaine_famille` (négative : aucune) est annoncée.
func vue(
	phase: int,
	temps_restant: float,
	prochaine_famille: int,
	sans_fin: bool,
	composition: Composition = null
) -> VueArene:
	var v := VueArene.new()
	v.tick = _tick
	v.manche = _manche
	v.phase = Types.Phase.DEFAITE if _detruite else phase
	v.temps_restant = temps_restant
	var annoncees := PackedInt32Array()
	if composition != null:
		annoncees = composition.familles
	elif prochaine_famille >= 0:
		annoncees = PackedInt32Array([prochaine_famille])
	for f: int in annoncees:
		if f >= 0:
			v.prochaines_familles.append(f)
			v.prochaines_armures.append(_armure_de_famille(f))
	v.prochaine_famille = v.prochaines_familles[0] if not v.prochaines_familles.is_empty() else -1
	v.prochaine_armure = _armure_de_famille(v.prochaine_famille)
	v.sans_fin = sans_fin
	v.tour_pv = pv
	v.tour_pv_max = _pv_max()
	v.tour_mana = mana
	v.tour_mana_max = mana_max()
	v.tour_armure = _armure_tour + _stats.armure
	v.argent = economie.argent
	v.revenu = economie.revenu_par_periode(_manche, _stats, _temps)
	v.revenu_dans = economie.temps_avant_versement()
	v.cout_relance = boutique.cout_relance
	v.relances_gratuites = _relances_gratuites()
	for offre: Dictionary in boutique.offres:
		v.offres.append(offre.duplicate())
	for arme: ArmeEquipee in armes:
		v.armes.append({"id": arme.id, "recharge_ratio": arme.recharge_ratio(_stats)})
	v.ameliorations = inventaire.ameliorations.duplicate(true)
	v.marche_noir_ouvert = _stats.marche_noir - inventaire.jetons_marche_noir_utilises > 0
	ennemis.vers_vue(v)
	poses.vers_vue(v)
	v.evenements = _evenements
	_evenements = []
	v.eliminations = _eliminations
	v.degats_infliges = _degats_infliges
	v.manche_max = _manche_max
	return v


func est_detruite() -> bool:
	return _detruite


## Vrai quand le boss est mort et que la tour tient encore.
func boss_vaincu() -> bool:
	return _boss_mort and not _detruite


func nombre_ennemis() -> int:
	return ennemis.taille


func tick_courant() -> int:
	return _tick


func _pv_max() -> float:
	return float(_donnees.partie["tour"]["pv"]) + _stats.pv_max_bonus


## Mana maximale : la valeur de départ des données (0) plus les améliorations.
## Mana gagnée (siphon, mana au coup) : jamais au-delà de la mana maximale, donc rien sans maximum.
## Un montant nul, négatif ou non fini est ignoré.
func mana_gagnee(montant: float) -> void:
	if not montant > 0.0 or not is_finite(montant):
		return
	mana = minf(mana + montant, mana_max())


func mana_max() -> float:
	return float(_donnees.partie["tour"]["mana_max"]) + _stats.mana_max_bonus


## Points de mana par seconde : la valeur de départ des données plus les améliorations.
func _mana_regen() -> float:
	return float(_donnees.partie["tour"]["mana_regen"]) + _stats.mana_regen


func _relances_gratuites() -> int:
	return maxi(_stats.relances_gratuites - _relances_utilisees, 0)


func _armure_de_famille(index: int) -> int:
	if index < 0 or index >= _donnees.familles.size():
		return Types.Armure.AUCUNE
	return int(_donnees.familles[index]["armure"])
