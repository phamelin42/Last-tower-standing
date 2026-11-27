extends CasDeTest
## D21 pour les mécaniques du lot 9 : avec « mouvement réduit », une bombe ne grossit ni ne pulse,
## les chevrons d'un repoussement ne s'éloignent pas, un rayon ne tourne pas et aucune particule
## ne part ; les formes, elles, restent toutes.

const SCENE := "res://scenes/arene_2d.tscn"

var _arene: Arene2D = null
var _effets: Effets = null


func avant_chaque() -> void:
	_arene = (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(_arene)
	_arene.reinitialiser()
	_effets = Effets.new()
	arbre.root.add_child(_effets)


func apres_chaque() -> void:
	for noeud: Node in [_arene, _effets]:
		if is_instance_valid(noeud):
			if noeud.get_parent() != null:
				noeud.get_parent().remove_child(noeud)
			noeud.free()


func _vue_bombe(tick: int, reste: float) -> VueArene:
	var vue := VueArene.new()
	vue.tick = tick
	vue.bombes.append({"pos": Vector2(50, 50), "rayon": 90.0, "reste": reste})
	vue.zones.append({"pos": Vector2(-80, 40), "rayon": 100.0, "reste": 5.0, "arme": 0})
	return vue


func test_une_bombe_ne_grossit_ni_ne_pulse_en_mouvement_reduit_mais_garde_ses_formes() -> void:
	_arene.mouvement_reduit = true
	var poses: ZonesBombes2D = _arene.zones_bombes()
	verifier(poses.mouvement_reduit, "le réglage arrive jusqu'aux poses")
	_arene.afficher(_vue_bombe(1, 2.0), 1.0)
	var tailles: Dictionary = {}
	for k: int in 20:
		poses.avancer(0.04)
		tailles[poses.echelle_bombe(0)] = true
	_arene.afficher(_vue_bombe(2, 0.2), 1.1)
	tailles[poses.echelle_bombe(0)] = true
	verifier_egal(tailles.size(), 1, "une seule taille, du début à la fin")
	verifier_egal(poses.nombre_bombes(), 1, "la bombe est toujours dessinée")
	verifier_egal(poses.nombre_zones(), 1, "la zone aussi")
	verifier(poses.opacite_zone(0) > 0.0, "et visible")
	verifier(poses.avancement_bombe(0) > 0.8, "l'avancement reste lisible (l'anneau s'emplit)")


func _sprites_visibles() -> Array[Sprite2D]:
	var liste: Array[Sprite2D] = []
	for n: Node in _effets.get_children():
		if n is Sprite2D and (n as Sprite2D).visible:
			liste.append(n as Sprite2D)
	return liste


func test_un_repoussement_reste_en_place_en_mouvement_reduit_et_avance_sinon() -> void:
	var impact := {
		"k": "impact",
		"t": 1,
		"de": Vector2.ZERO,
		"vers": Vector2(300, -200),
		"type_degats": Types.TypeDegats.PERCANT,
		"rayon": 0.0,
		"statut": VueArene.STATUTS_ARME.find("repoussement"),
	}
	var deplacements: Array[float] = []
	for reduit: bool in [true, false]:
		_effets.vider()
		_effets.mouvement_reduit = reduit
		verifier(_effets.ajouter(impact.duplicate()))
		verifier_contient(_effets.formes_vivantes(), "recul", "la forme reste")
		var avant: PackedVector2Array = PackedVector2Array()
		for sprite: Sprite2D in _sprites_visibles():
			avant.append(sprite.position)
		_effets.avancer(0.15)
		var apres: Array[Sprite2D] = _sprites_visibles()
		verifier_egal(apres.size(), avant.size(), "rien n'a fini en 0,15 s")
		var plus_grand: float = 0.0
		for k: int in mini(avant.size(), apres.size()):
			plus_grand = maxf(plus_grand, avant[k].distance_to(apres[k].position))
		deplacements.append(plus_grand)
	verifier_egal(deplacements[0], 0.0, "mouvement réduit : les chevrons ne bougent pas")
	verifier(deplacements[1] > 1.0, "sinon ils s'éloignent")


func test_un_rayon_ne_tourne_pas_et_aucune_particule_ne_part_en_mouvement_reduit() -> void:
	_effets.mouvement_reduit = true
	var bout := Vector2(0.0, -400.0)
	var tir := {
		"k": "tir",
		"t": 1,
		"de": Vector2.ZERO,
		"vers": bout,
		"type_degats": Types.TypeDegats.TRANCHANT,
		"rayon": 20.0,
		"genre": VueArene.GENRES_ARME.find("tournant"),
	}
	verifier(_effets.ajouter(tir))
	verifier_contient(_effets.formes_vivantes(), "trait_rayon", "la forme reste")
	var angle: float = _sprites_visibles()[0].rotation
	_effets.avancer(0.1)
	verifier_egal(_sprites_visibles()[0].rotation, angle, "le rayon garde son angle")
	verifier_egal(_effets.etincelles_actives().size(), 0, "aucune particule")
	# Une zone posée et une bombe qui explose n'en lancent pas non plus.
	for genre: String in ["zone_posee", "bombe", "invocation"]:
		var impact := {
			"k": "impact",
			"t": 1,
			"de": Vector2.ZERO,
			"vers": Vector2(100, 100),
			"type_degats": Types.TypeDegats.SIEGE,
			"rayon": 90.0,
			"genre": VueArene.GENRES_ARME.find(genre),
		}
		verifier(_effets.ajouter(impact), genre)
		verifier_egal(_effets.etincelles_actives().size(), 0, "aucune particule : %s" % genre)
