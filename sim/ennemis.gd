class_name Ennemis
extends RefCounted
## Les ennemis d'une arène en tableaux compacts : un ennemi est un indice commun à tous les
## tableaux, jamais un objet. Un indice n'est valable que jusqu'à la prochaine `purger()` (qui
## échange le dernier élément avec la place libérée) ; l'identifiant (`ids[i]`) est, lui, stable.
## Un ennemi tué reste dans les tableaux jusqu'à la purge, mais n'est plus compté, plus ciblé,
## plus affiché ni plus avancé : c'est ce qui garantit qu'une mort compte une seule fois, quelle
## que soit la source.
##
## Toute entrée absurde (indice inconnu, montant négatif ou NaN, durée nulle) est ignorée sans
## erreur : la simulation ne plante pas sur une valeur venue des données ou d'un calcul.

## Au-delà, une portée d'attaque est « à distance » : l'ennemi s'arrête à cette portée.
const PORTEE_CORPS_A_CORPS := 60.0
## En deçà, un minuteur de statut est considéré fini (dérive des flottants 32 bits).
const EPSILON_TEMPS := 0.0001
## Garde-fou : un coup « infini » ne produit ni infini ni NaN dans les compteurs.
const DEGATS_MAX := 1e12
## Tolérance pour dire qu'un ennemi est arrivé à son point d'arrêt.
const TOLERANCE_ARRET := 0.01
## Bits réservés au rang de retrait dans la clé de tri de `purger` (16 millions de retraits).
const RANG_BITS := 24
const RANG_MASQUE := (1 << RANG_BITS) - 1

## Vivants uniquement ; les morts en attente de purge ne sont pas comptés.
var taille: int = 0

var ids: PackedInt32Array = PackedInt32Array()
var famille: PackedByteArray = PackedByteArray()
var pos: PackedVector2Array = PackedVector2Array()
var pv: PackedFloat32Array = PackedFloat32Array()
var pv_max: PackedFloat32Array = PackedFloat32Array()
var vitesse: PackedFloat32Array = PackedFloat32Array()
var degats: PackedFloat32Array = PackedFloat32Array()
var portee: PackedFloat32Array = PackedFloat32Array()
## Secondes entre deux attaques ; 0 = n'attaque jamais.
var intervalle: PackedFloat32Array = PackedFloat32Array()
var attaque_cd: PackedFloat32Array = PackedFloat32Array()
var prime: PackedInt32Array = PackedInt32Array()
## 1 : au contact de la tour, l'ennemi explose (dégâts à la tour, puis il disparaît).
var explose: PackedByteArray = PackedByteArray()
## 1 : mort par explosion, qui ne rapporte ni prime ni élimination.
var sans_prime: PackedByteArray = PackedByteArray()
var armure: PackedByteArray = PackedByteArray()
var mort: PackedByteArray = PackedByteArray()
## Bits `Types.STATUT_*`, tenus à jour à chaque changement de statut.
var statuts: PackedByteArray = PackedByteArray()
var poison_reste: PackedFloat32Array = PackedFloat32Array()
var poison_duree: PackedFloat32Array = PackedFloat32Array()
var brule_reste: PackedFloat32Array = PackedFloat32Array()
var brule_duree: PackedFloat32Array = PackedFloat32Array()
var gel: PackedFloat32Array = PackedFloat32Array()
var etourdi: PackedFloat32Array = PackedFloat32Array()
var givre_cumuls: PackedInt32Array = PackedInt32Array()
var givre_t: PackedFloat32Array = PackedFloat32Array()

var _donnees: Donnees
var _table_efficacite: Array
var _gel_max: float
var _cumuls_max: int
var _givre_par_cumul: float
var _givre_plafond: float
var _suivant: int = 0
## Plus petit carré de distance d'un vivant à `_centre_d2` (-1 : à recalculer). Les armes prêtes
## mais sans cible rebalayaient chaque pas tous les ennemis : avec quarante armes, cela coûtait
## plus de 10 ms par pas. Une mort ne l'invalide pas (il reste un minorant sûr) ; tout
## déplacement ou ajout le fait.
var _d2_min: float = -1.0
var _centre_d2: Vector2 = Vector2.ZERO
var _indice_par_id: Dictionary = {}
## Nombre d'entrées des tableaux, morts en attente compris.
var _n: int = 0


func _init(donnees: Donnees) -> void:
	_donnees = donnees
	_table_efficacite = donnees.efficacite
	_gel_max = float(donnees.partie["gel_max_s"])
	var givre: Dictionary = donnees.partie["givre"]
	_cumuls_max = int(givre["cumuls_max"])
	_givre_par_cumul = float(givre["ralentissement_par_cumul"])
	_givre_plafond = float(givre["plafond"])


## Identifiant stable et croissant, jamais réutilisé ; -1 (sans consommer d'identifiant) si
## les PV ou la position sont invalides.
func ajouter(
	fam: int,
	position: Vector2,
	points_de_vie: float,
	vitesse_de_base: float,
	degats_de_base: float,
	portee_attaque: float,
	cadence: float,
	prime_or: int,
	type_armure: int,
	explose_au_contact: bool = false
) -> int:
	if not points_de_vie > 0.0 or not is_finite(points_de_vie):
		return -1
	if not is_finite(position.x) or not is_finite(position.y):
		return -1
	var id := _suivant
	_suivant += 1
	_indice_par_id[id] = _n
	_n += 1
	taille += 1
	ids.append(id)
	famille.append(clampi(fam, 0, 255))
	pos.append(position)
	_d2_min = -1.0
	pv.append(points_de_vie)
	pv_max.append(points_de_vie)
	vitesse.append(maxf(vitesse_de_base, 0.0) if is_finite(vitesse_de_base) else 0.0)
	degats.append(maxf(degats_de_base, 0.0) if is_finite(degats_de_base) else 0.0)
	portee.append(maxf(portee_attaque, 0.0) if is_finite(portee_attaque) else 0.0)
	intervalle.append(1.0 / cadence if cadence > 0.0 and is_finite(cadence) else 0.0)
	attaque_cd.append(0.0)
	prime.append(prime_or)
	explose.append(1 if explose_au_contact else 0)
	sans_prime.append(0)
	armure.append(clampi(type_armure, 0, 255))
	mort.append(0)
	statuts.append(0)
	poison_reste.append(0.0)
	poison_duree.append(0.0)
	brule_reste.append(0.0)
	brule_duree.append(0.0)
	gel.append(0.0)
	etourdi.append(0.0)
	givre_cumuls.append(0)
	givre_t.append(0.0)
	return id


## -1 si l'identifiant est inconnu ou purgé.
## Minorant du carré de la distance de `centre` au vivant le plus proche : `INF` sans vivant. Une
## requête de portée `r` autour de `centre` ne trouve rien si `r × r` lui est inférieur.
func distance2_minimale(centre: Vector2) -> float:
	if _d2_min >= 0.0 and _centre_d2 == centre:
		return _d2_min
	var minimum := INF
	for i: int in _n:
		if mort[i] == 0:
			minimum = minf(minimum, pos[i].distance_squared_to(centre))
	_d2_min = minimum
	_centre_d2 = centre
	return minimum


func indice_de(id: int) -> int:
	return int(_indice_par_id.get(id, -1))


func _vivant(i: int) -> bool:
	return i >= 0 and i < _n and mort[i] == 0


func _tuer(i: int) -> void:
	mort[i] = 1
	taille -= 1


## Dégâts après efficacité type/armure, appliquée ici et nulle part ailleurs : les statuts
## (poison, brûlure) retirent leurs PV tels quels. Rend les dégâts effectivement infligés,
## plafonnés aux PV restants (c'est ce montant qui nourrit le score et le vol de vie) ; 0 pour
## un mort, un indice inconnu ou un montant négatif, nul ou NaN, qui ne soigne jamais.
func infliger(i: int, montant: float, type_degats: int) -> float:
	if not _vivant(i) or not montant > 0.0:
		return 0.0
	var apres := (
		minf(montant, DEGATS_MAX) * Combat.efficacite(_table_efficacite, type_degats, armure[i])
	)
	var reels := minf(apres, pv[i])
	pv[i] -= apres
	if pv[i] <= 0.0:
		_tuer(i)
	return reels


func empoisonner(i: int, total: float, duree: float) -> void:
	if not _vivant(i) or not _dot_valide(total, duree):
		return
	poison_reste[i] += total
	poison_duree[i] = maxf(poison_duree[i], duree)
	_recalculer_bits(i)


## Brûlure : `ratio` des dégâts du coup, répartis sur `duree`, cumulative.
func bruler(i: int, ratio: float, degats_du_coup: float, duree: float) -> void:
	var total := ratio * degats_du_coup
	if not _vivant(i) or not _dot_valide(total, duree):
		return
	brule_reste[i] += total
	brule_duree[i] = maxf(brule_duree[i], duree)
	_recalculer_bits(i)


## Pas de nouveau cumul pendant un gel, ni de prolongation du gel en cours. Un gel dure
## `gel_max_s × résistance` au plus `gel_max_s` : à résistance nulle, aucun gel.
func givrer(i: int, resistance: float) -> void:
	if not _vivant(i) or gel[i] > 0.0:
		return
	givre_cumuls[i] += 1
	givre_t[i] = 0.0
	if givre_cumuls[i] >= _cumuls_max:
		givre_cumuls[i] = 0
		gel[i] = Combat.duree_gel(_gel_max, _resistance_saine(resistance), _gel_max)
		if gel[i] <= 0.0:
			gel[i] = 0.0
	_recalculer_bits(i)


## Durée × résistance ; prolonge un étourdissement en cours sans l'additionner.
func etourdir(i: int, duree: float, resistance: float) -> void:
	if not _vivant(i) or not duree > 0.0 or not is_finite(duree):
		return
	var effective := Combat.duree_etourdissement(duree, _resistance_saine(resistance))
	if effective > etourdi[i]:
		etourdi[i] = effective
		_recalculer_bits(i)


func _resistance_saine(resistance: float) -> float:
	return resistance if resistance > 0.0 and is_finite(resistance) else 0.0


func _dot_valide(total: float, duree: float) -> bool:
	return total > 0.0 and duree > 0.0 and is_finite(total) and is_finite(duree)


func _recalculer_bits(i: int) -> void:
	var bits := 0
	if gel[i] > 0.0:
		bits |= Types.STATUT_GELE
	if givre_cumuls[i] > 0:
		bits |= Types.STATUT_RALENTI
	if poison_duree[i] > 0.0:
		bits |= Types.STATUT_EMPOISONNE
	if brule_duree[i] > 0.0:
		bits |= Types.STATUT_BRULE
	if etourdi[i] > 0.0:
		bits |= Types.STATUT_ETOURDI
	statuts[i] = bits


## Un pas de dégâts sur la durée : (dégâts, reste, durée restante). Le dernier pas verse tout
## le reste, pour que la somme des pas soit exactement le total malgré les flottants.
func _pas_dot(reste: float, duree: float, dt: float) -> Vector3:
	var fin := duree - dt
	if fin <= EPSILON_TEMPS:
		return Vector3(reste, 0.0, 0.0)
	var d := Combat.repartir_dot(reste, duree, dt)
	return Vector3(d, reste - d, fin)


## Fait avancer les minuteurs de statut d'un ennemi vivant. Peut le tuer.
func _avancer_statuts(i: int, dt: float) -> void:
	var perdu := 0.0
	if poison_duree[i] > 0.0:
		var p := _pas_dot(poison_reste[i], poison_duree[i], dt)
		perdu += p.x
		poison_reste[i] = p.y
		poison_duree[i] = p.z
	if brule_duree[i] > 0.0:
		var b := _pas_dot(brule_reste[i], brule_duree[i], dt)
		perdu += b.x
		brule_reste[i] = b.y
		brule_duree[i] = b.z
	if gel[i] > 0.0:
		gel[i] = gel[i] - dt if gel[i] - dt > EPSILON_TEMPS else 0.0
	if etourdi[i] > 0.0:
		etourdi[i] = etourdi[i] - dt if etourdi[i] - dt > EPSILON_TEMPS else 0.0
	if givre_cumuls[i] > 0:
		givre_t[i] += dt
		while givre_t[i] >= 1.0 and givre_cumuls[i] > 0:
			givre_cumuls[i] -= 1
			givre_t[i] -= 1.0
		if givre_cumuls[i] == 0:
			givre_t[i] = 0.0
	_recalculer_bits(i)
	if perdu > 0.0:
		pv[i] -= perdu
		if pv[i] <= 0.0:
			_tuer(i)


## Un pas de simulation. `tues_par_statut` et `attaquants_cac` sont des indices valables
## jusqu'à la prochaine purge. Un pas nul, négatif ou NaN ne change rien.
func avancer(
	dt: float, centre: Vector2, rayon_tour: float, mult_vitesse: float, mult_degats: float
) -> Dictionary:
	var degats_tour := 0.0
	var attaquants := PackedInt32Array()
	var tues := PackedInt32Array()
	var explosions := PackedInt32Array()
	var resultat := {
		"degats_tour": 0.0,
		"attaquants_cac": attaquants,
		"tues_par_statut": tues,
		"explosions": explosions,
	}
	if not dt > 0.0 or not is_finite(dt) or _n == 0:
		return resultat
	var vit_mult := mult_vitesse if mult_vitesse > 0.0 and is_finite(mult_vitesse) else 0.0
	var deg_mult := mult_degats if mult_degats > 0.0 and is_finite(mult_degats) else 0.0
	for i: int in _n:
		if mort[i] != 0:
			continue
		var bits: int = statuts[i]
		if bits != 0:
			_avancer_statuts(i, dt)
			if mort[i] != 0:
				tues.append(i)
				continue
			bits = statuts[i]
		var immobile := (bits & (Types.STATUT_GELE | Types.STATUT_ETOURDI)) != 0
		if immobile:
			continue
		var facteur := vit_mult
		if (bits & Types.STATUT_RALENTI) != 0:
			facteur *= (
				1.0 - Combat.ralentissement(givre_cumuls[i], _givre_par_cumul, _givre_plafond)
			)
		var p_att: float = portee[i]
		var corps_a_corps := p_att <= PORTEE_CORPS_A_CORPS
		var arret := rayon_tour + p_att if corps_a_corps else p_att
		var depart := pos[i]
		var vers := centre - depart
		var distance := vers.length()
		if distance > arret:
			var pas := minf(vitesse[i] * facteur * dt, distance - arret)
			pos[i] = depart + vers * (pas / distance)
			_d2_min = -1.0
			distance -= pas
		if distance > arret + TOLERANCE_ARRET:
			continue
		if explose[i] != 0:
			# Au contact : un seul coup, tout de suite, puis l'ennemi disparaît sans prime. Il n'est
			# pas un attaquant au corps à corps : ses dégâts rejoignent ceux à distance (une
			# esquive possible, aucune épine).
			degats_tour += degats[i] * deg_mult
			explosions.append(i)
			sans_prime[i] = 1
			_tuer(i)
			continue
		var cd: float = attaque_cd[i] - dt
		if cd <= 0.0 and degats[i] > 0.0 and intervalle[i] > 0.0:
			degats_tour += degats[i] * deg_mult
			if corps_a_corps:
				attaquants.append(i)
			cd = intervalle[i]
		attaque_cd[i] = maxf(cd, 0.0)
	resultat["degats_tour"] = degats_tour
	return resultat


## Indices des vivants à portée du centre, par identifiant croissant (l'ordre des indices ne
## l'est plus après une purge : le tri passe par les identifiants).
func dans_rayon(centre: Vector2, rayon: float) -> PackedInt32Array:
	var trouves := PackedInt32Array()
	if not rayon >= 0.0 or not is_finite(rayon):
		return trouves
	var r2 := rayon * rayon
	for i: int in _n:
		if mort[i] != 0:
			continue
		if pos[i].distance_squared_to(centre) <= r2:
			trouves.append(ids[i])
	trouves.sort()
	for k: int in trouves.size():
		trouves[k] = _indice_par_id[trouves[k]]
	return trouves


## Indice du meilleur vivant à portée ou -1 ; à égalité parfaite, le plus
## petit identifiant. Un mode inconnu se comporte comme PLUS_PROCHE.
func choisir(centre: Vector2, portee_max: float, mode: int) -> int:
	if not portee_max >= 0.0 or not is_finite(portee_max):
		return -1
	var r2 := portee_max * portee_max
	var meilleur := -1
	var meilleure_cle := 0.0
	for i: int in _n:
		if mort[i] != 0:
			continue
		var d2 := pos[i].distance_squared_to(centre)
		if d2 > r2:
			continue
		var cle := d2
		if mode == Types.Ciblage.PLUS_FORT:
			cle = -pv[i]
		elif mode == Types.Ciblage.PLUS_FAIBLE:
			cle = pv[i]
		if (
			meilleur == -1
			or cle < meilleure_cle
			or (cle == meilleure_cle and ids[i] < ids[meilleur])
		):
			meilleur = i
			meilleure_cle = cle
	return meilleur


## Retire les morts en échangeant chaque place libérée avec le dernier élément (l'identifiant
## suit ses propres données). Rend `[{id, famille, prime, pos, sans_prime}]` par identifiant croissant.
func purger() -> Array[Dictionary]:
	var retires: Array[Dictionary] = []
	# Clé de tri native : l'identifiant dans les bits de poids fort, le rang de retrait dessous.
	var cles := PackedInt64Array()
	_d2_min = -1.0
	var i := 0
	while i < _n:
		if mort[i] == 0:
			i += 1
			continue
		var dernier := _n - 1
		if mort[dernier] != 0:
			# Un mort en queue part sans copie (1 000 Tonneaux qui explosent ensemble : aucune).
			_noter_retrait(dernier, retires, cles)
			_n = dernier
			continue
		_noter_retrait(i, retires, cles)
		_copier(dernier, i)
		_indice_par_id[ids[i]] = i
		_n = dernier
	# Une seule réduction des tableaux, après le balayage : la refaire à chaque retrait coûtait
	# vingt-quatre `resize` par ennemi retiré.
	_redimensionner(_n)
	# Un tri par comparateur GDScript coûtait 5 ms pour 1 000 retraits : le tri natif des clés
	# donne le même ordre (identifiants uniques).
	cles.sort()
	var tries: Array[Dictionary] = []
	tries.resize(retires.size())
	for rang: int in cles.size():
		tries[rang] = retires[cles[rang] & RANG_MASQUE]
	return tries


func _noter_retrait(i: int, retires: Array[Dictionary], cles: PackedInt64Array) -> void:
	cles.append((ids[i] << RANG_BITS) | retires.size())
	(
		retires
		. append(
			{
				"id": ids[i],
				"famille": int(famille[i]),
				"prime": prime[i],
				"pos": pos[i],
				"sans_prime": sans_prime[i] != 0,
			}
		)
	)
	_indice_par_id.erase(ids[i])


func _copier(de: int, vers: int) -> void:
	ids[vers] = ids[de]
	famille[vers] = famille[de]
	pos[vers] = pos[de]
	pv[vers] = pv[de]
	pv_max[vers] = pv_max[de]
	vitesse[vers] = vitesse[de]
	degats[vers] = degats[de]
	portee[vers] = portee[de]
	intervalle[vers] = intervalle[de]
	attaque_cd[vers] = attaque_cd[de]
	prime[vers] = prime[de]
	explose[vers] = explose[de]
	sans_prime[vers] = sans_prime[de]
	armure[vers] = armure[de]
	mort[vers] = mort[de]
	statuts[vers] = statuts[de]
	poison_reste[vers] = poison_reste[de]
	poison_duree[vers] = poison_duree[de]
	brule_reste[vers] = brule_reste[de]
	brule_duree[vers] = brule_duree[de]
	gel[vers] = gel[de]
	etourdi[vers] = etourdi[de]
	givre_cumuls[vers] = givre_cumuls[de]
	givre_t[vers] = givre_t[de]


func _redimensionner(n: int) -> void:
	ids.resize(n)
	famille.resize(n)
	pos.resize(n)
	pv.resize(n)
	pv_max.resize(n)
	vitesse.resize(n)
	degats.resize(n)
	portee.resize(n)
	intervalle.resize(n)
	attaque_cd.resize(n)
	prime.resize(n)
	explose.resize(n)
	sans_prime.resize(n)
	armure.resize(n)
	mort.resize(n)
	statuts.resize(n)
	poison_reste.resize(n)
	poison_duree.resize(n)
	brule_reste.resize(n)
	brule_duree.resize(n)
	gel.resize(n)
	etourdi.resize(n)
	givre_cumuls.resize(n)
	givre_t.resize(n)


## Remplit les cinq tableaux `ennemis_*` de la vue avec des copies des vivants (les morts en
## attente de purge ne s'affichent plus). Un vivant n'affiche jamais 0 de PV.
func vers_vue(vue: VueArene) -> void:
	var ids_vue := PackedInt32Array()
	var pos_vue := PackedVector2Array()
	var famille_vue := PackedByteArray()
	var pv_vue := PackedByteArray()
	var statuts_vue := PackedByteArray()
	ids_vue.resize(taille)
	pos_vue.resize(taille)
	famille_vue.resize(taille)
	pv_vue.resize(taille)
	statuts_vue.resize(taille)
	var k := 0
	for i: int in _n:
		if mort[i] != 0:
			continue
		ids_vue[k] = ids[i]
		pos_vue[k] = pos[i]
		famille_vue[k] = famille[i]
		pv_vue[k] = clampi(roundi(pv[i] / pv_max[i] * 255.0), 1, 255)
		statuts_vue[k] = statuts[i]
		k += 1
	vue.ennemis_id = ids_vue
	vue.ennemis_pos = pos_vue
	vue.ennemis_famille = famille_vue
	vue.ennemis_pv = pv_vue
	vue.ennemis_statuts = statuts_vue
