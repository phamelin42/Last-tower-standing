extends CasDeTest
## Ce que la joueuse doit voir quand l'arène est pleine : une vue sans allié, sans zone ni bombe ne
## dessine rien de plus qu'avant, et 255 armes qui tirent ne dépassent jamais le plafond d'effets.

const SCENE := "res://scenes/arene_2d.tscn"
const ARMES_QUI_TIRENT: int = 255

var _donnees: Donnees = null
var _arenes: Array[Arene2D] = []
var _effets: Effets = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()


func apres_chaque() -> void:
	for noeud: Node in [_effets] + _arenes:
		if is_instance_valid(noeud):
			if noeud.get_parent() != null:
				noeud.get_parent().remove_child(noeud)
			noeud.free()
	_arenes.clear()
	_effets = null


func _arene() -> Arene2D:
	var arene := (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(arene)
	arene.reinitialiser()
	_arenes.append(arene)
	return arene


func _vue_ennemis(tick: int) -> VueArene:
	var vue := VueArene.new()
	vue.tick = tick
	for k: int in 30:
		vue.ennemis_id.append(k + 1)
		vue.ennemis_pos.append(Vector2(300.0 + 20.0 * k, 15.0 * k))
		vue.ennemis_famille.append(k % 5)
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	return vue


## Les nœuds d'affichage visibles de l'arène (hors ceux qui ne dessinent rien par construction).
func _visibles(noeud: Node) -> int:
	var n: int = 0
	for enfant: Node in noeud.get_children():
		if enfant is CanvasItem and (enfant as CanvasItem).visible:
			n += 1
		n += _visibles(enfant)
	return n


func test_une_vue_sans_allies_ni_zones_ni_bombes_ne_dessine_rien_de_plus() -> void:
	var simple: Arene2D = _arene()
	simple.afficher(_vue_ennemis(1), 1.0)
	var charge: Arene2D = _arene()
	var pleine := _vue_ennemis(1)
	for k: int in 40:
		pleine.allies.append({"id": k + 1, "pos": Vector2(10.0 * k, 20.0), "unite": k % 2})
	pleine.zones.append({"pos": Vector2(100, 100), "rayon": 120.0, "reste": 4.0, "arme": 0})
	pleine.bombes.append({"pos": Vector2(-100, 100), "rayon": 90.0, "reste": 2.0})
	for k: int in pleine.ennemis_statuts.size():
		pleine.ennemis_statuts[k] = Types.STATUT_VULNERABLE | Types.STATUT_SIPHONNE
	charge.afficher(pleine, 1.0)
	verifier(_visibles(charge) > _visibles(simple), "la vue chargée dessine plus")
	charge.afficher(_vue_ennemis(2), 1.1)
	verifier_egal(charge.nombre_allies_visibles(), 0)
	verifier_egal(charge.zones_bombes().nombre_zones(), 0)
	verifier_egal(charge.zones_bombes().nombre_bombes(), 0)
	verifier_egal(charge.marques_statut().nombre(), 0)
	verifier_egal(_visibles(charge), _visibles(simple), "retour exact à l'arène sans mécaniques")


func _evenements_de(id: String, index: int) -> Array[Dictionary]:
	var arme: Dictionary = _donnees.armes[id]
	var genre: int = VueArene.GENRES_ARME.find(String((arme["effets"] as Array)[0]["kind"]))
	var statut: int = 0
	if not (arme["statuts"] as Array).is_empty():
		statut = VueArene.STATUTS_ARME.find(String((arme["statuts"] as Array)[0]["kind"]))
	var base := {
		"t": 1,
		"de": Vector2.ZERO,
		"type_degats": int(arme["type_degats"]),
		"genre": maxi(genre, 0),
		"statut": maxi(statut, 0),
		"arme": index,
	}
	var liste: Array[Dictionary] = []
	for branche: int in 8:
		var vers: Vector2 = Vector2.from_angle(TAU * float(branche) / 8.0) * 300.0
		for k: String in ["tir", "impact"]:
			var e: Dictionary = base.duplicate()
			e["k"] = k
			e["vers"] = vers
			e["rayon"] = 20.0 if genre == VueArene.GENRES_ARME.find("tournant") else 90.0
			liste.append(e)
	return liste


func test_le_plafond_de_200_effets_tient_avec_255_armes_qui_tirent() -> void:
	_effets = Effets.new()
	_effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(_effets)
	var catalogue: PackedStringArray = _donnees.ids_catalogue
	var armes: Array[int] = []
	for index: int in catalogue.size():
		if _donnees.armes.has(catalogue[index]):
			armes.append(index)
	verifier(armes.size() >= 75, "les 75 armes du catalogue (%d)" % armes.size())
	for tour: int in 3:
		for k: int in ARMES_QUI_TIRENT:
			var index: int = armes[(tour * 7 + k) % armes.size()]
			for e: Dictionary in _evenements_de(catalogue[index], index):
				_effets.ajouter(e)
			verifier(_effets.nombre_vivants() <= Effets.PLAFOND, "plafond tenu à l'arme %d" % k)
		_effets.avancer(0.05)
	verifier(_effets.taille_pool() <= Effets.PLAFOND * 2, "pool borné : %d" % _effets.taille_pool())
	for _i: int in 400:
		_effets.avancer(0.1)
	verifier_egal(_effets.nombre_vivants(), 0, "tout s'éteint")


func test_64_allies_32_zones_et_32_bombes_restent_dans_leurs_listes() -> void:
	var arene: Arene2D = _arene()
	var vue := _vue_ennemis(1)
	for k: int in 80:
		vue.allies.append({"id": k + 1, "pos": Vector2(5.0 * k, 10.0), "unite": k % 2})
	for k: int in 40:
		vue.zones.append({"pos": Vector2(20.0 * k, 0.0), "rayon": 80.0, "reste": 3.0, "arme": 0})
		vue.bombes.append({"pos": Vector2(0.0, 20.0 * k), "rayon": 70.0, "reste": 1.5})
	arene.afficher(vue, 1.0)
	verifier(arene.zones_bombes().nombre_zones() <= VueArene.ZONES_MAX, "zones")
	verifier(arene.zones_bombes().nombre_bombes() <= VueArene.BOMBES_MAX, "bombes")
	verifier(arene.nombre_allies_visibles() <= 80, "alliés")
