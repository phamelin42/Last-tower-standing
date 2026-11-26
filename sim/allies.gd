class_name Allies
extends RefCounted
## Alliés invoqués par les armes : des unités temporaires, invulnérables et ignorées des ennemis.
## Chacun marche vers l'ennemi le plus proche situé dans le rayon de garde de la tour, l'attaque
## à sa portée avec des dégâts figés à l'invocation, puis revient près de la tour faute de cible.
## Aucun hasard : les alliés agissent dans l'ordre de leur identifiant (l'ordre des tableaux), les
## ex æquo de cible sont départagés par l'identifiant de l'ennemi, et le placement d'un allié
## ne dépend que de son identifiant.

## Intervalle entre deux recherches de cible d'un allié ; les recherches sont échelonnées par
## identifiant sur `CRENEAUX` pas de temps pour que le coût d'un pas reste uniforme.
const INTERVALLE_RECHERCHE := 0.25
const CRENEAUX := 5
## Distance à la tour à laquelle un allié sans cible attend, et rayon où il apparaît.
const RAYON_RETOUR := 90.0
const RAYON_APPARITION := 80.0
## Angle d'or : répartit les alliés autour de la tour sans tirage.
const ANGLE_OR := 2.399963229728653
const EPSILON := 1e-6

var ids: PackedInt32Array = PackedInt32Array()
var pos: PackedVector2Array = PackedVector2Array()
## Index dans `Donnees.ids_unites`.
var unite: PackedInt32Array = PackedInt32Array()
## Secondes de vie restantes.
var reste: PackedFloat32Array = PackedFloat32Array()
## Secondes avant la prochaine attaque ; avant la prochaine recherche de cible.
var attaque_cd: PackedFloat32Array = PackedFloat32Array()
var recherche_cd: PackedFloat32Array = PackedFloat32Array()
## Identifiant de l'ennemi visé, -1 sans cible.
var cible: PackedInt32Array = PackedInt32Array()
## Dégâts d'une attaque (critique et bonus déjà inclus), type de dégâts, index de l'arme.
var degats: PackedFloat32Array = PackedFloat32Array()
var type_degats: PackedByteArray = PackedByteArray()
var arme: PackedInt32Array = PackedInt32Array()
## Caractéristiques de l'unité recopiées à l'invocation (`data/unites.json`) : un pas n'ouvre aucun
## dictionnaire.
var vitesse: PackedFloat32Array = PackedFloat32Array()
var portee: PackedFloat32Array = PackedFloat32Array()
var cadence: PackedFloat32Array = PackedFloat32Array()
var garde: PackedFloat32Array = PackedFloat32Array()
## Groupe l'arme équipée qui l'a invoqué, pour `max_actives`.
var proprietaire: PackedInt64Array = PackedInt64Array()

var taille: int:
	get:
		return ids.size()

var _donnees: Donnees
var _limite: int
var _suivant: int = 0
## Les ennemis vivants du rayon de garde maximal de la tour, listés une fois par pas à la première
## recherche : leurs indices et leur distance² à la tour.
var _candidats: PackedInt32Array = PackedInt32Array()
var _candidats_d2: PackedFloat32Array = PackedFloat32Array()
var _candidats_prets: bool = false
var _garde_max2: float = 0.0


func _init(donnees: Donnees) -> void:
	_donnees = donnees
	_limite = int((donnees.partie["limites"] as Dictionary)["allies"])
	for id: String in donnees.ids_unites:
		var garde_unite := float((donnees.unites[id] as Dictionary)["rayon_garde"])
		_garde_max2 = maxf(_garde_max2, garde_unite * garde_unite)


## Invoque un allié près de `centre_tour`. Rend son identifiant, ou -1 si la donnée est invalide
## (unité inconnue, durée ou dégâts non finis ou négatifs, type inconnu). `max_actives` (0 : sans
## limite) borne les alliés d'un même `proprio` ; au-delà de ce nombre ou de `limites.allies`, celui
## qui est le plus proche de sa fin cède (le plus petit identifiant à égalité).
func invoquer(
	indice_unite: int,
	centre_tour: Vector2,
	duree: float,
	degats_coup: float,
	type: int,
	indice_arme: int,
	proprio: int = 0,
	max_actives: int = 0
) -> int:
	if indice_unite < 0 or indice_unite >= _donnees.ids_unites.size():
		return -1
	if not duree > 0.0 or not is_finite(duree):
		return -1
	if not degats_coup >= 0.0 or not is_finite(degats_coup):
		return -1
	if type < 0 or type >= 5 or not is_finite(centre_tour.x) or not is_finite(centre_tour.y):
		return -1
	if max_actives > 0:
		while _compter(proprio) >= max_actives:
			_retirer(_plus_proche_de_sa_fin(proprio))
	while ids.size() >= _limite:
		_retirer(_plus_proche_de_sa_fin(-1))
	var id := _suivant
	_suivant += 1
	var angle := float(id) * ANGLE_OR
	ids.append(id)
	pos.append(centre_tour + Vector2(cos(angle), sin(angle)) * RAYON_APPARITION)
	unite.append(indice_unite)
	reste.append(duree)
	attaque_cd.append(0.0)
	recherche_cd.append(float(id % CRENEAUX) * INTERVALLE_RECHERCHE / float(CRENEAUX))
	cible.append(-1)
	degats.append(degats_coup)
	type_degats.append(type)
	arme.append(maxi(indice_arme, 0))
	var fiche: Dictionary = _donnees.unites[_donnees.ids_unites[indice_unite]]
	vitesse.append(float(fiche["vitesse"]))
	portee.append(float(fiche["portee"]))
	cadence.append(float(fiche["cadence"]))
	garde.append(float(fiche["rayon_garde"]))
	proprietaire.append(proprio)
	return id


## Un pas : la vie qui s'écoule, la recherche de cible (échelonnée), la marche, l'attaque. Rend les
## dégâts infligés et les événements (un `impact` de genre `invocation` par coup).
func avancer(dt: float, ennemis: Ennemis, centre_tour: Vector2) -> Tir.Bilan:
	var bilan := Tir.Bilan.new()
	if not dt > 0.0 or not is_finite(dt) or ids.is_empty():
		return bilan
	var genre := VueArene.genre_depuis_nom("invocation")
	_candidats_prets = false
	var k := 0
	while k < ids.size():
		reste[k] -= dt
		if reste[k] <= EPSILON:
			_retirer(k)
			continue
		_agir(k, dt, ennemis, centre_tour, genre, bilan)
		k += 1
	return bilan


func vider() -> void:
	ids.clear()
	pos.clear()
	unite.clear()
	reste.clear()
	attaque_cd.clear()
	recherche_cd.clear()
	cible.clear()
	degats.clear()
	type_degats.clear()
	arme.clear()
	vitesse.clear()
	portee.clear()
	cadence.clear()
	garde.clear()
	proprietaire.clear()


## Remplit `vue.allies` : `{id, pos, unite}`, par identifiant croissant.
func vers_vue(vue: VueArene) -> void:
	vue.allies.clear()
	for k: int in ids.size():
		vue.allies.append({"id": ids[k], "pos": pos[k], "unite": unite[k]})


func _agir(
	k: int, dt: float, ennemis: Ennemis, centre_tour: Vector2, genre: int, bilan: Tir.Bilan
) -> void:
	attaque_cd[k] = maxf(attaque_cd[k] - dt, 0.0)
	recherche_cd[k] -= dt
	var i := -1
	if cible[k] >= 0:
		i = ennemis.indice_de(cible[k])
		if i < 0 or ennemis.mort[i] != 0:
			cible[k] = -1
			i = -1
	if recherche_cd[k] <= 0.0:
		recherche_cd[k] = INTERVALLE_RECHERCHE
		i = _chercher(k, ennemis, centre_tour)
		cible[k] = ennemis.ids[i] if i >= 0 else -1
	var pas := vitesse[k] * dt
	if i < 0:
		_aller_vers(k, centre_tour, RAYON_RETOUR, pas)
		return
	var arret := portee[k]
	var distance := pos[k].distance_to(ennemis.pos[i])
	if distance > arret:
		_aller_vers(k, ennemis.pos[i], arret, pas)
		distance = pos[k].distance_to(ennemis.pos[i])
	if distance <= arret + EPSILON and attaque_cd[k] <= 0.0:
		attaque_cd[k] = cadence[k]
		var reels := ennemis.infliger(i, degats[k], type_degats[k])
		bilan.degats += reels
		if ennemis.mort[i] != 0:
			bilan.tues_directs += 1
		(
			bilan
			. evenements
			. append(
				{
					"k": "impact",
					"t": 0,
					"de": pos[k],
					"vers": ennemis.pos[i],
					"type_degats": int(type_degats[k]),
					"rayon": 0.0,
					"genre": genre,
					"statut": 0,
					"arme": arme[k],
				}
			)
		)


## L'ennemi vivant le plus proche de l'allié `k` parmi ceux du rayon de garde de la tour ; à égalité
## parfaite, le plus petit identifiant. -1 s'il n'y en a pas. La liste des candidats est dressée une
## seule fois par pas, pour tous les alliés qui cherchent.
func _chercher(k: int, ennemis: Ennemis, centre_tour: Vector2) -> int:
	if not _candidats_prets:
		_dresser_candidats(ennemis, centre_tour)
	var g2 := garde[k] * garde[k]
	var meilleur := -1
	var meilleure := 0.0
	var depart := pos[k]
	for c: int in _candidats.size():
		if _candidats_d2[c] > g2:
			continue
		var i := _candidats[c]
		var d2 := ennemis.pos[i].distance_squared_to(depart)
		if (
			meilleur == -1
			or d2 < meilleure
			or (d2 == meilleure and ennemis.ids[i] < ennemis.ids[meilleur])
		):
			meilleur = i
			meilleure = d2
	return meilleur


func _dresser_candidats(ennemis: Ennemis, centre_tour: Vector2) -> void:
	_candidats_prets = true
	_candidats.clear()
	_candidats_d2.clear()
	for i: int in ennemis.ids.size():
		if ennemis.mort[i] != 0:
			continue
		var d2 := ennemis.pos[i].distance_squared_to(centre_tour)
		if d2 <= _garde_max2:
			_candidats.append(i)
			_candidats_d2.append(d2)


## Marche vers `but` jusqu'à `arret` de lui, d'au plus `pas` ; ne dépasse jamais l'arrêt.
func _aller_vers(k: int, but: Vector2, arret: float, pas: float) -> void:
	var vers := but - pos[k]
	var distance := vers.length()
	if distance <= arret or distance <= 0.0:
		return
	pos[k] += vers * (minf(pas, distance - arret) / distance)


func _compter(proprio: int) -> int:
	var n := 0
	for p: int in proprietaire:
		if p == proprio:
			n += 1
	return n


## Indice de l'allié le plus proche de sa fin (parmi ceux de `proprio`, ou tous si -1) ; à égalité,
## le plus petit identifiant, donc le plus petit indice.
func _plus_proche_de_sa_fin(proprio: int) -> int:
	var meilleur := -1
	for k: int in ids.size():
		if proprio != -1 and proprietaire[k] != proprio:
			continue
		if meilleur == -1 or reste[k] < reste[meilleur]:
			meilleur = k
	return meilleur


func _retirer(k: int) -> void:
	ids.remove_at(k)
	pos.remove_at(k)
	unite.remove_at(k)
	reste.remove_at(k)
	attaque_cd.remove_at(k)
	recherche_cd.remove_at(k)
	cible.remove_at(k)
	degats.remove_at(k)
	type_degats.remove_at(k)
	arme.remove_at(k)
	vitesse.remove_at(k)
	portee.remove_at(k)
	cadence.remove_at(k)
	garde.remove_at(k)
	proprietaire.remove_at(k)
