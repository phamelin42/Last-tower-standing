extends CasDeTest
## Retour de partie de Phil (27/11) : « je ne vois pas les ennemis s'arrêter, es-tu sûr que le
## visuel suit ? ». La position dessinée suit la simulation (`test_arene_2d`), mais un Archer ou une
## Dynamite arrêtés à leur portée restaient immobiles, sans qu'on voie leur attaque. Un tireur à
## l'arrêt envoie un projectile visible vers la tour à chaque cadence de ses données.

const SCENE := "res://scenes/arene_2d.tscn"
const PAS_S := 0.05

var _arene: Arene2D = null
var _donnees: Donnees = null
var _tick: int = 0


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_arene = (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(_arene)
	_arene.reinitialiser()
	_tick = 0


func apres_chaque() -> void:
	if is_instance_valid(_arene):
		_arene.get_parent().remove_child(_arene)
		_arene.free()
	_arene = null


func _famille(i: int) -> Dictionary:
	return _donnees.familles[i]


func _a_distance(i: int) -> bool:
	return not Apparence.attaque_au_contact(_donnees, i)


func _rayon_tour() -> float:
	return float((_donnees.partie["tour"] as Dictionary)["rayon"])


func _arret(i: int) -> float:
	return Apparence.distance_arret(
		float(_famille(i)["portee_attaque"]), _rayon_tour(), int(not _a_distance(i))
	)


## Une vue avec `nb` ennemis de la famille `i`, tous à la distance `distance` de la tour, répartis
## sur le cercle.
func _vue(i: int, distance: float, nb: int = 1) -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	for k: int in nb:
		vue.ennemis_id.append(k + 1)
		vue.ennemis_pos.append(Vector2.from_angle(TAU * float(k) / float(nb)) * distance)
		vue.ennemis_famille.append(i)
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	return vue


## Plus grand nombre de projectiles visibles en `duree_s` secondes d'affichage de `vue`.
func _maximum(vue: VueArene, duree_s: float) -> int:
	var plus := 0
	var t := 1.0
	_arene.afficher(vue, t)
	while t < 1.0 + duree_s:
		t += PAS_S
		_arene.afficher_courant(t)
		plus = maxi(plus, _arene.tirs_ennemis().tirs().size())
	return plus


func test_chaque_tireur_a_l_arret_envoie_un_projectile_a_chaque_cadence() -> void:
	var tireurs := 0
	for i: int in _donnees.familles.size():
		if not _a_distance(i):
			continue
		tireurs += 1
		var cadence := float(_famille(i)["cadence_attaque"])
		var vus := _maximum(_vue(i, _arret(i)), 2.0 / cadence)
		verifier(vus >= 1, "%s à l'arrêt : aucun projectile visible" % _famille(i)["id"])
	verifier(tireurs > 0, "il existe des tireurs dans les données")


func test_le_projectile_va_du_tireur_vers_la_tour() -> void:
	for i: int in _donnees.familles.size():
		if not _a_distance(i):
			continue
		var cadence := float(_famille(i)["cadence_attaque"])
		var depart := Vector2(_arret(i), 0.0)
		_arene.afficher(_vue(i, depart.x), 1.0)
		var t := 1.0
		var vu := false
		while t < 1.0 + 2.0 / cadence:
			t += PAS_S
			_arene.afficher_courant(t)
			for tir: Dictionary in _arene.tirs_ennemis().tirs():
				vu = true
				var p: Vector2 = tir["pos"]
				var x_max := Apparence.vers_pixels(depart).x
				verifier(p.x <= x_max + 0.5 and p.x >= -0.5, "%s : hors du trajet (%s)" % [i, p])
		verifier(vu, "%s : un projectile vole" % _famille(i)["id"])


func test_un_tireur_qui_marche_ou_un_ennemi_au_contact_ne_tire_pas() -> void:
	for i: int in _donnees.familles.size():
		var cadence := maxf(float(_famille(i)["cadence_attaque"]), 0.1)
		if _a_distance(i):
			var loin := _maximum(_vue(i, _arret(i) + 400.0), 2.0 / cadence)
			verifier_egal(loin, 0, "%s en marche : pas de projectile" % _famille(i)["id"])
		else:
			var contact := _maximum(_vue(i, _arret(i)), 2.0 / cadence)
			verifier_egal(contact, 0, "%s au contact : pas de projectile" % _famille(i)["id"])


func test_sept_cents_tireurs_ne_depassent_pas_le_plafond_de_projectiles() -> void:
	var archer := -1
	for i: int in _donnees.familles.size():
		if _a_distance(i):
			archer = i
			break
	var plafond := _arene.tirs_ennemis().plafond()
	var plus := _maximum(_vue(archer, _arret(archer), 700), 3.0)
	verifier(plus >= 1, "des projectiles volent")
	verifier(plus <= plafond, "au plus %d projectiles (vus %d)" % [plafond, plus])


func test_le_plafond_le_vol_et_les_images_viennent_de_assets_json() -> void:
	# Règle des assets remplaçables : changer de pack ne demande que de changer le JSON.
	var reglages: Dictionary = Assets.section("tirs_ennemis")
	verifier_egal(_arene.tirs_ennemis().plafond(), int(reglages["plafond"]))
	for cle: String in ["fleche", "bombe"]:
		var chemin: String = Apparence.RACINE + String((reglages[cle] as Dictionary)["chemin"])
		verifier(ResourceLoader.exists(chemin), "%s : l'image existe (%s)" % [cle, chemin])
	var modifie: Dictionary = Assets.tout().duplicate(true)
	(modifie["tirs_ennemis"] as Dictionary)["plafond"] = 3
	Assets.remplacer(modifie)
	var arene := (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(arene)
	arene.reinitialiser()
	verifier_egal(arene.tirs_ennemis().plafond(), 3, "le plafond suit le JSON")
	arene.get_parent().remove_child(arene)
	arene.free()
	Assets.reinitialiser()


func test_assets_json_refuse_une_section_de_tirs_incomplete() -> void:
	for cle: String in ["plafond", "vol_s", "fleche", "bombe"]:
		var assets: Dictionary = Assets.tout().duplicate(true)
		(assets["tirs_ennemis"] as Dictionary).erase(cle)
		var erreurs: Array[String] = []
		DonneesAssets.valider(assets, erreurs)
		var cite := false
		for m: String in erreurs:
			cite = cite or m.contains("tirs_ennemis.%s" % cle)
		verifier(cite, "section sans %s : %s" % [cle, erreurs])
