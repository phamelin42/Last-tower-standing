class_name Arene3D
extends Node3D
## L'arène vue d'en haut : sol en damier, tour au centre, un `MultiMeshInstance3D` par famille
## d'ennemis (le convoi et le boss ont chacun le leur), effets en pool. Elle ne lit que
## `VueArene`, reçue par les signaux d'une `SourceVue`, et `Donnees` pour savoir combien de
## familles existent. Index : 0 à n-1 les familles, n le convoi, n+1 le boss (voir `Apparence`).

## Capacité minimale d'un MultiMesh qui s'agrandit : évite de réallouer à chaque petite hausse.
const CAPACITE_MIN: int = 16

## Injectable avant l'entrée dans l'arbre (tests) ; sinon chargé depuis `data/`.
var donnees: Donnees = null

var _interpolation := Interpolation.new()
var _horloge: float = 0.0
var _dernier_tick: int = -1
var _source: SourceVue = null
var _multis: Array[MultiMeshInstance3D] = []
var _altitudes: PackedFloat32Array = PackedFloat32Array()
## Copie côté CPU des origines écrites : le rendu de test (sans écran) ne relit pas le MultiMesh.
var _origines: Array[PackedVector3Array] = []
var _effets: Effets = null
var _construite: bool = false


func _ready() -> void:
	_assurer_construite()


## Construction paresseuse : le lanceur de tests ajoute les nœuds avant que `_ready` ne soit
## appelé, et une arène doit répondre dès qu'on lui parle.
func _assurer_construite() -> void:
	if _construite:
		return
	_construite = true
	if donnees == null:
		donnees = Donnees.charger()
	_construire_sol()
	_construire_tour()
	_effets = Effets.new()
	_effets.name = "Effets"
	add_child(_effets)
	var nb: int = donnees.familles.size() + 2 if donnees != null else 0
	for index: int in nb:
		_construire_famille(index)


## S'abonne aux vues reçues. Un nouveau `lier` remplace le précédent.
func lier(source: SourceVue) -> void:
	_assurer_construite()
	if _source != null and _source.vue_arene_recue.is_connected(_sur_vue):
		_source.vue_arene_recue.disconnect(_sur_vue)
	_source = source
	if _source != null:
		_source.vue_arene_recue.connect(_sur_vue)


## Oublie les vues reçues : à appeler quand une autre partie commence (les ticks repartent de 0).
func reinitialiser() -> void:
	_assurer_construite()
	_interpolation.reinitialiser()
	_dernier_tick = -1
	_afficher_echantillon()


## Affiche `vue` telle quelle, sans lissage ni délai, à l'instant `temps_rendu`.
func afficher(vue: VueArene, temps_rendu: float) -> void:
	_assurer_construite()
	if vue == null:
		return
	_horloge = temps_rendu
	_interpolation.reinitialiser()
	_dernier_tick = -1
	_recevoir(vue, temps_rendu)
	_afficher_echantillon()


## Rend l'état lissé à l'instant `temps_rendu` (l'horloge interne en jeu).
func afficher_courant(temps_rendu: float) -> void:
	_assurer_construite()
	_horloge = temps_rendu
	_afficher_echantillon()


func nombre_instances_visibles(famille: int) -> int:
	_assurer_construite()
	if famille < 0 or famille >= _multis.size():
		return 0
	return _multis[famille].multimesh.visible_instance_count


## Transformation d'une instance affichée, pour les tests et les captures.
func transform_instance(famille: int, i: int) -> Transform3D:
	_assurer_construite()
	if famille < 0 or famille >= _multis.size() or i < 0 or i >= nombre_instances_visibles(famille):
		return Transform3D.IDENTITY
	return Transform3D(Basis.IDENTITY, _origines[famille][i])


func _process(delta: float) -> void:
	_assurer_construite()
	_horloge += delta
	_afficher_echantillon()
	if _effets != null:
		_effets.avancer(delta)


func _sur_vue(vue: VueArene) -> void:
	_recevoir(vue, _horloge)


## Une vue plus ancienne que la dernière reçue (réseau non fiable) est ignorée, effets compris.
func _recevoir(vue: VueArene, temps: float) -> void:
	if vue == null or vue.tick <= _dernier_tick:
		return
	_dernier_tick = vue.tick
	_interpolation.pousser(vue, temps)
	for evenement: Dictionary in vue.evenements:
		_effets.ajouter(evenement)


func _afficher_echantillon() -> void:
	var echantillon: Dictionary = _interpolation.echantillon(_horloge + Interpolation.DELAI_S)
	var vue: VueArene = echantillon["vue"] as VueArene
	var positions: PackedVector2Array = echantillon["pos"]
	var nb: int = _multis.size()
	var decompte: PackedInt32Array = PackedInt32Array()
	decompte.resize(nb)
	var familles: PackedByteArray = PackedByteArray()
	if vue != null:
		familles = vue.ennemis_famille
	var total: int = mini(familles.size(), positions.size())
	for i: int in total:
		var f: int = familles[i]
		if f < nb:
			decompte[f] += 1
	for f: int in nb:
		_dimensionner(f, decompte[f])
		decompte[f] = 0
	for i: int in total:
		var f: int = familles[i]
		if f >= nb:
			continue
		var p: Vector2 = positions[i]
		var monde: Vector3 = Apparence.position_monde(p, _altitudes[f])
		_multis[f].multimesh.set_instance_transform(decompte[f], Transform3D(Basis.IDENTITY, monde))
		_origines[f][decompte[f]] = monde
		decompte[f] += 1


## N'agrandit que si le nombre demandé dépasse ce qui est alloué, en doublant.
func _dimensionner(famille: int, voulu: int) -> void:
	var multimesh: MultiMesh = _multis[famille].multimesh
	if voulu > multimesh.instance_count:
		multimesh.instance_count = maxi(voulu, maxi(multimesh.instance_count * 2, CAPACITE_MIN))
		_origines[famille].resize(multimesh.instance_count)
	multimesh.visible_instance_count = voulu


func _construire_sol() -> void:
	var sol := MeshInstance3D.new()
	sol.name = "Sol"
	sol.mesh = Apparence.maillage_sol()
	sol.material_override = Apparence.materiau_sol()
	sol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sol)


func _construire_tour() -> void:
	var maillage: Mesh = Apparence.maillage_tour()
	var tour := MeshInstance3D.new()
	tour.name = "Tour"
	tour.mesh = maillage
	tour.material_override = Apparence.materiau_tour()
	# Le centre du maillage est à l'origine du nœud : la tour est posée une demi-hauteur plus haut.
	tour.position = Vector3(0.0, maillage.get_aabb().size.y * 0.5, 0.0)
	add_child(tour)


func _construire_famille(index: int) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = Apparence.maillage_famille(index)
	multimesh.instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.name = "Famille%d" % index
	instance.multimesh = multimesh
	instance.material_override = Apparence.materiau_famille(index)
	add_child(instance)
	_multis.append(instance)
	_origines.append(PackedVector3Array())
	# Un volant flotte à son altitude ; le reste repose sur le sol, à une demi-hauteur.
	var altitude: float = Apparence.hauteur_famille(index)
	if altitude <= 0.0:
		altitude = Apparence.maillage_famille(index).get_aabb().size.y * 0.5
	_altitudes.append(altitude)
