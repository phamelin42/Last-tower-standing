class_name Poses
extends RefCounted
## Zones posées et bombes à retardement d'une arène. Une pose est posée par une arme sur la position
## de sa cible ; ses dégâts, son critique et ses statuts sont figés à la pose, et elle disparaît
## d'elle-même (durée écoulée, bombe explosée) ou avec la manche, la tour ou `vider()`.
## Aucun hasard : l'ordre des poses est celui de la pose, et c'est lui qui départage les plafonds
## (la plus ancienne cède).

## Tolérance sur les durées : 100 pas de 0,05 s n'additionnent pas exactement 5,0 s.
const EPSILON := 1e-6

## `{pos, rayon, duree, periode, ecoule, faites, degats, type_degats, statuts, statut, arme (index
## de `Donnees.ids_catalogue`), proprietaire}` ; `proprietaire` groupe les poses d'une même arme
## équipée pour `max_actives`.
var zones: Array[Dictionary] = []
## `{pos, rayon, reste, degats, type_degats, statuts, statut, arme, proprietaire}`.
var bombes: Array[Dictionary] = []

var _limite_zones: int
var _limite_bombes: int


func _init(donnees: Donnees) -> void:
	var limites: Dictionary = donnees.partie["limites"]
	_limite_zones = int(limites["zones"])
	_limite_bombes = int(limites["bombes"])


## Pose une zone. `degats` est ce que chaque impulsion inflige (critique et bonus déjà inclus).
## Au-delà de `max_actives` zones de la même arme, ou de la limite globale, la plus ancienne cède.
func ajouter_zone(pose: Dictionary, max_actives: int) -> void:
	if not _valide(pose, ["rayon", "duree", "periode", "degats"]):
		return
	var zone: Dictionary = pose.duplicate(true)
	zone["ecoule"] = 0.0
	zone["faites"] = 0
	_retirer_les_plus_anciennes(zones, int(zone["proprietaire"]), max_actives)
	zones.append(zone)
	while zones.size() > _limite_zones:
		zones.remove_at(0)


## Pose une bombe : elle explose après `delai` à l'endroit où elle a été posée.
func ajouter_bombe(pose: Dictionary, max_actives: int) -> void:
	if not _valide(pose, ["rayon", "delai", "degats"]):
		return
	var bombe: Dictionary = pose.duplicate(true)
	bombe["reste"] = float(pose["delai"])
	_retirer_les_plus_anciennes(bombes, int(bombe["proprietaire"]), max_actives)
	bombes.append(bombe)
	while bombes.size() > _limite_bombes:
		bombes.remove_at(0)


## Fait avancer les poses d'un pas : les impulsions des zones, l'explosion des bombes arrivées au
## bout de leur délai. Rend ce qu'elles ont produit (dégâts, soin, mana, événements).
func avancer(
	dt: float,
	ennemis: Ennemis,
	stats: StatsTour,
	centre: Vector2,
	donnees: Donnees,
	resistance: float
) -> Tir.Bilan:
	var bilan := Tir.Bilan.new()
	if not dt > 0.0 or not is_finite(dt):
		return bilan
	var genre_zone := VueArene.genre_depuis_nom("zone_posee")
	var genre_bombe := VueArene.genre_depuis_nom("bombe")
	var restantes: Array[Dictionary] = []
	for zone: Dictionary in zones:
		zone["ecoule"] = float(zone["ecoule"]) + dt
		var periode := float(zone["periode"])
		var total := floori(float(zone["duree"]) / periode + EPSILON)
		var dues := mini(floori(float(zone["ecoule"]) / periode + EPSILON), total)
		var ctx := Tir.contexte_pose(
			zone, genre_zone, ennemis, stats, centre, donnees, resistance, bilan
		)
		while int(zone["faites"]) < dues:
			zone["faites"] = int(zone["faites"]) + 1
			Tir.impulsion(ctx, zone["pos"], float(zone["rayon"]), float(zone["degats"]))
		if float(zone["ecoule"]) < float(zone["duree"]) - EPSILON:
			restantes.append(zone)
	zones = restantes
	var bombes_restantes: Array[Dictionary] = []
	for bombe: Dictionary in bombes:
		bombe["reste"] = float(bombe["reste"]) - dt
		if float(bombe["reste"]) > EPSILON:
			bombes_restantes.append(bombe)
			continue
		var ctx := Tir.contexte_pose(
			bombe, genre_bombe, ennemis, stats, centre, donnees, resistance, bilan
		)
		Tir.impulsion(ctx, bombe["pos"], float(bombe["rayon"]), float(bombe["degats"]))
	bombes = bombes_restantes
	return bilan


## Retire toutes les poses : fin de manche, tour détruite, fin de partie.
func vider() -> void:
	zones.clear()
	bombes.clear()


## Remplit `zones` et `bombes` de la vue, dans l'ordre de pose, avec le temps qu'il leur reste.
func vers_vue(vue: VueArene) -> void:
	vue.zones.clear()
	vue.bombes.clear()
	for zone: Dictionary in zones:
		(
			vue
			. zones
			. append(
				{
					"pos": zone["pos"],
					"rayon": float(zone["rayon"]),
					"reste": maxf(float(zone["duree"]) - float(zone["ecoule"]), 0.0),
					"arme": int(zone["arme"]),
				}
			)
		)
	for bombe: Dictionary in bombes:
		(
			vue
			. bombes
			. append(
				{
					"pos": bombe["pos"],
					"rayon": float(bombe["rayon"]),
					"reste": maxf(float(bombe["reste"]), 0.0),
				}
			)
		)


## Les poses de `proprietaire` en trop pour en accueillir une de plus : les plus anciennes partent.
static func _retirer_les_plus_anciennes(
	liste: Array[Dictionary], proprietaire: int, max_actives: int
) -> void:
	var a_elle: Array[int] = []
	for i: int in liste.size():
		if int(liste[i]["proprietaire"]) == proprietaire:
			a_elle.append(i)
	var en_trop := a_elle.size() - maxi(max_actives, 1) + 1
	for k: int in range(en_trop - 1, -1, -1):
		liste.remove_at(a_elle[k])


## Une pose aux nombres finis et positifs, à la position finie : une donnée aberrante ne pose rien.
static func _valide(pose: Dictionary, cles: Array[String]) -> bool:
	var pos: Vector2 = pose.get("pos", Vector2(INF, INF))
	if not is_finite(pos.x) or not is_finite(pos.y):
		return false
	for cle: String in cles:
		var v := float(pose.get(cle, 0.0))
		if not v > 0.0 or not is_finite(v):
			return false
	return true
