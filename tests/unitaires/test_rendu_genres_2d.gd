extends CasDeTest
## Ce que la joueuse doit voir de chaque genre d'effet d'arme et de chaque statut d'événement : un
## rendu, jamais un tir qui disparaît ; et un index que le jeu ne connaît pas retombe sur le rendu
## par type de dégâts, sans erreur.

const TYPES: Array[int] = [
	Types.TypeDegats.TRANCHANT,
	Types.TypeDegats.PERCANT,
	Types.TypeDegats.MAGIQUE,
	Types.TypeDegats.SIEGE,
	Types.TypeDegats.CHAOS,
]

var _effets: Effets = null


func avant_chaque() -> void:
	_effets = Effets.new()
	arbre.root.add_child(_effets)


func apres_chaque() -> void:
	if is_instance_valid(_effets):
		if _effets.get_parent() != null:
			_effets.get_parent().remove_child(_effets)
		_effets.free()
	_effets = null


func _evenement(k: String, type_degats: int, genre: int, statut: int) -> Dictionary:
	var e := {
		"k": k,
		"t": 1,
		"de": Vector2.ZERO,
		"vers": Vector2(300, -200),
		"type_degats": type_degats,
		"rayon": 90.0 if k == "impact" else 0.0,
	}
	if genre > 0:
		e["genre"] = genre
	if statut > 0:
		e["statut"] = statut
	return e


## Les événements d'un genre : un tir et son impact (un rayon tournant n'a que le tir).
func _joue(type_degats: int, genre: int, statut: int) -> bool:
	_effets.vider()
	var cree: bool = _effets.ajouter(_evenement("tir", type_degats, genre, statut))
	cree = _effets.ajouter(_evenement("impact", type_degats, genre, statut)) or cree
	return cree


func test_chaque_genre_et_chaque_statut_d_evenement_a_un_rendu() -> void:
	for genre: int in VueArene.GENRES_ARME.size():
		for type_degats: int in TYPES:
			verifier(
				_joue(type_degats, genre, 0),
				"genre %s, type %d : aucun rendu" % [VueArene.GENRES_ARME[genre], type_degats]
			)
			verifier(_effets.nombre_vivants() > 0, "genre %d : rien de vivant" % genre)
	for statut: int in range(1, VueArene.STATUTS_ARME.size()):
		var nom: String = VueArene.STATUTS_ARME[statut]
		verifier(Effets.FORMES_STATUT.has(nom), "%s : une forme" % nom)
		verifier(Effets.COULEURS_STATUT.has(nom), "%s : une couleur" % nom)
		for type_degats: int in TYPES:
			# L'impact seul : avec un tir, il attendrait l'arrivée du projectile avant sa marque.
			_effets.vider()
			var impact: Dictionary = _evenement("impact", type_degats, 0, statut)
			verifier(_effets.ajouter(impact), "statut %s, type %d" % [nom, type_degats])
			verifier_contient(
				_effets.formes_vivantes(), Effets.FORMES_STATUT[nom], "marque de %s" % nom
			)


func test_un_index_inconnu_retombe_sur_le_rendu_par_type_de_degats_sans_erreur() -> void:
	var inconnus: Array[int] = [VueArene.GENRES_ARME.size(), 15, 16, 255, -1]
	for type_degats: int in TYPES:
		_joue(type_degats, 0, 0)
		var attendu: PackedStringArray = _effets.formes_vivantes()
		attendu.sort()
		verifier(attendu.size() > 0, "le rendu par type existe")
		for inconnu: int in inconnus:
			_effets.vider()
			var e1: Dictionary = _evenement("tir", type_degats, 0, 0)
			var e2: Dictionary = _evenement("impact", type_degats, 0, 0)
			e1["genre"] = inconnu
			e2["genre"] = inconnu
			e1["statut"] = inconnu
			e2["statut"] = inconnu
			_effets.ajouter(e1)
			_effets.ajouter(e2)
			var formes: PackedStringArray = _effets.formes_vivantes()
			formes.sort()
			verifier_egal(formes, attendu, "index %d, type %d" % [inconnu, type_degats])
