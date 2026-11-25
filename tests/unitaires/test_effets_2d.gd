extends CasDeTest
## Ce que la joueuse doit voir des tirs, impacts et morts de l'arène 2D : chaque arme produit un
## effet reconnaissable à sa forme et pas seulement à sa couleur, la rafale ne dépasse jamais le
## plafond, et tout s'éteint sans laisser de nœud actif.

const SCENE := "res://scenes/arene_2d.tscn"
const TYPES: Array[int] = [
	Types.TypeDegats.TRANCHANT,
	Types.TypeDegats.PERCANT,
	Types.TypeDegats.MAGIQUE,
	Types.TypeDegats.SIEGE,
	Types.TypeDegats.CHAOS,
]
const GENRES: Array[String] = [
	"cible_unique", "zone", "rebond", "aura", "onde", "barrage", "piege", "mine"
]

var _effets: Effets2D = null
var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_effets = Effets2D.new()
	arbre.root.add_child(_effets)


func apres_chaque() -> void:
	if is_instance_valid(_effets):
		if _effets.get_parent() != null:
			_effets.get_parent().remove_child(_effets)
		_effets.free()
	_effets = null


func _evenement(
	k: String, type_degats: int, de: Vector2, vers: Vector2, rayon: float, genre: String = ""
) -> Dictionary:
	var e := {"k": k, "t": 1, "de": de, "vers": vers, "type_degats": type_degats, "rayon": rayon}
	if genre != "":
		e["genre"] = genre
	return e


## Les événements que la simulation émet pour un genre d'effet d'arme (voir `sim/tir.gd`).
func _evenements_du_genre(type_degats: int, genre: String) -> Array[Dictionary]:
	var de := Vector2(0, 0)
	var vers := Vector2(300, -200)
	var liste: Array[Dictionary] = []
	match genre:
		"aura", "onde":
			liste.append(_evenement("impact", type_degats, de, de, 250.0, genre))
		"rebond":
			liste.append(_evenement("tir", type_degats, de, vers, 0.0, genre))
			liste.append(_evenement("impact", type_degats, de, vers, 0.0, genre))
			liste.append(
				_evenement("impact", type_degats, vers, vers + Vector2(80, 40), 0.0, genre)
			)
		"piege", "mine":
			liste.append(_evenement("tir", type_degats, de, vers, 0.0, genre))
		"zone", "barrage":
			liste.append(_evenement("tir", type_degats, de, vers, 0.0, genre))
			liste.append(_evenement("impact", type_degats, de, vers, 120.0, genre))
		_:
			liste.append(_evenement("tir", type_degats, de, vers, 0.0, genre))
			liste.append(_evenement("impact", type_degats, de, vers, 0.0, genre))
	return liste


func _laisser_finir() -> void:
	_effets.vider()
	for i: int in 400:
		_effets.avancer(0.05)
		if _effets.nombre_vivants() == 0:
			return


func test_chaque_couple_type_de_degats_genre_d_effet_des_armes_produit_un_effet() -> void:
	var vus: Dictionary = {}
	for id: String in _donnees.armes:
		var arme: Dictionary = _donnees.armes[id]
		var type_degats: int = arme["type_degats"]
		for effet: Dictionary in arme["effets"]:
			vus["%d/%s" % [type_degats, effet["kind"]]] = [type_degats, String(effet["kind"])]
	verifier(vus.size() >= 20, "au moins vingt couples dans armes.json (%d)" % vus.size())
	for cle: String in vus:
		var couple: Array = vus[cle]
		var type_degats: int = couple[0]
		var genre: String = couple[1]
		_laisser_finir()
		var cree: bool = false
		for e: Dictionary in _evenements_du_genre(type_degats, genre):
			cree = _effets.ajouter(e) or cree
		verifier(cree, "aucun effet pour %s" % cle)
		verifier(_effets.nombre_vivants() > 0, "aucun effet vivant pour %s" % cle)
		var rendu: Dictionary = Effets2D.rendu(type_degats, genre)
		verifier(not rendu.is_empty(), "pas de rendu décrit pour %s" % cle)


func test_chaque_statut_des_armes_laisse_sa_marque_a_l_impact() -> void:
	var statuts: Dictionary = {}
	for id: String in _donnees.armes:
		var arme: Dictionary = _donnees.armes[id]
		for s: Dictionary in arme["statuts"]:
			statuts[String(s["kind"])] = true
	verifier(statuts.size() >= 4, "poison, brûlure, givre, étourdissement au moins")
	var formes_vues: Dictionary = {}
	for statut: String in statuts:
		if statut == "vol_de_vie":
			continue
		for type_degats: int in TYPES:
			_laisser_finir()
			var e := _evenement("impact", type_degats, Vector2.ZERO, Vector2(200, 100), 90.0)
			e["statut"] = statut
			verifier(_effets.ajouter(e), "effet pour %s" % statut)
			var formes: PackedStringArray = _effets.formes_vivantes()
			var attendue: String = String(Effets2D.FORMES_STATUT[statut])
			verifier(formes.has(attendue), "%s dessine %s" % [statut, attendue])
			formes_vues[attendue] = true
	verifier_egal(formes_vues.size(), 4, "quatre marques différentes")


func test_chaque_type_de_degats_a_sa_propre_forme_de_projectile_et_pas_seulement_sa_couleur(
) -> void:
	var formes: Dictionary = {}
	for type_degats: int in TYPES:
		var forme: String = Effets2D.rendu(type_degats, "cible_unique")["projectile"]
		verifier(forme != "", "forme de projectile pour le type %d" % type_degats)
		formes[forme] = true
	verifier_egal(formes.size(), TYPES.size(), "cinq formes de projectile différentes")


func test_le_percant_tire_la_fleche_et_le_siege_la_dynamite_du_pack() -> void:
	var fleche: String = Effets2D.rendu(Types.TypeDegats.PERCANT, "cible_unique")["projectile"]
	var dynamite: String = Effets2D.rendu(Types.TypeDegats.SIEGE, "cible_unique")["projectile"]
	var explosion: String = Effets2D.rendu(Types.TypeDegats.SIEGE, "zone")["impact"]
	verifier_egal(fleche, "fleche")
	verifier_egal(dynamite, "dynamite")
	verifier_egal(explosion, "explosion")


func test_le_rebond_trace_un_trait_de_cible_en_cible() -> void:
	for type_degats: int in TYPES:
		var forme_rebond: String = Effets2D.rendu(type_degats, "rebond")["impact"]
		verifier(forme_rebond.begins_with("trait"), "rendu du rebond %s" % forme_rebond)
		_laisser_finir()
		_effets.ajouter(_evenement("impact", type_degats, Vector2(100, 0), Vector2(200, 0), 0.0))
		var formes: PackedStringArray = _effets.formes_vivantes()
		verifier_egal(formes.size(), 1, "un seul effet pour le saut")
		verifier(formes[0].begins_with("trait"), "trait pour %d" % type_degats)


func test_une_onde_et_une_aura_dessinent_un_anneau_qui_s_etend() -> void:
	for type_degats: int in TYPES:
		for genre: String in ["onde", "aura"]:
			var forme: String = Effets2D.rendu(type_degats, genre)["impact"]
			verifier_egal(forme, "anneau")
	_effets.ajouter(_evenement("impact", 0, Vector2.ZERO, Vector2.ZERO, 300.0, "onde"))
	var avant: float = _effets.taille_du_premier()
	_effets.avancer(0.2)
	verifier(_effets.taille_du_premier() > avant, "l'anneau grandit")


func test_une_mine_reste_au_sol_tant_qu_elle_n_a_pas_explose() -> void:
	for genre: String in ["mine", "piege"]:
		_laisser_finir()
		var vers := Vector2(300, 100)
		_effets.ajouter(_evenement("tir", Types.TypeDegats.SIEGE, Vector2.ZERO, vers, 0.0, genre))
		_effets.avancer(5.0)
		verifier_egal(_effets.nombre_vivants(), 1, "%s encore posée après 5 s" % genre)
		_effets.ajouter(_evenement("impact", Types.TypeDegats.SIEGE, Vector2.ZERO, vers, 80.0))
		_effets.avancer(0.01)
		verifier(not _effets.formes_vivantes().has("mine"), "la mine a disparu")
		verifier(not _effets.formes_vivantes().has("piege"), "le piège a disparu")


func test_le_plafond_tient_sous_une_rafale() -> void:
	for i: int in 3000:
		_effets.ajouter(
			_evenement("impact", i % 5, Vector2(i, 0), Vector2(i, i), float(i % 200), "zone")
		)
		_effets.ajouter(_evenement("tir", i % 5, Vector2.ZERO, Vector2(i, 3), 0.0))
		verifier(_effets.nombre_vivants() <= Effets2D.PLAFOND)
	verifier_egal(_effets.nombre_vivants(), Effets2D.PLAFOND, "le plafond est atteint")
	verifier(_effets.taille_pool() <= Effets2D.PLAFOND, "pool %d" % _effets.taille_pool())
	verifier(Effets2D.PLAFOND >= Effets.PLAFOND, "au moins le plafond de l'arène 3D")


func test_le_pool_revient_a_zero_noeud_actif_et_ne_fuit_pas() -> void:
	for tour: int in 3:
		for i: int in 500:
			_effets.ajouter(_evenement("tir", i % 5, Vector2.ZERO, Vector2(i, 3), 0.0))
			_effets.ajouter(_evenement("impact", i % 5, Vector2.ZERO, Vector2(i, 3), 90.0))
			_effets.exploser(Vector2(i, i))
		_laisser_finir()
		verifier_egal(_effets.nombre_vivants(), 0, "plus rien de vivant (tour %d)" % tour)
		verifier_egal(_effets.nombre_visibles(), 0, "plus aucun nœud visible (tour %d)" % tour)
	verifier(_effets.taille_pool() <= Effets2D.PLAFOND, "pool %d" % _effets.taille_pool())
	verifier_egal(_effets.get_child_count(), _effets.taille_pool(), "aucun nœud perdu")


func test_chaque_texture_citee_existe() -> void:
	var chemins: PackedStringArray = Effets2D.textures_citees()
	verifier(chemins.size() >= 4, "au moins flamme, explosion, flèche, dynamite")
	for chemin: String in chemins:
		verifier(ResourceLoader.exists(chemin), "texture absente : %s" % chemin)
		verifier_non_nul(load(chemin) as Texture2D, chemin)


func test_un_evenement_inconnu_ou_incomplet_est_ignore() -> void:
	verifier_faux(_effets.ajouter({"k": "autre"}))
	verifier_faux(_effets.ajouter({}))
	verifier_egal(_effets.nombre_vivants(), 0)


func test_un_effet_ne_cache_jamais_la_tour_durablement() -> void:
	for type_degats: int in TYPES:
		for genre: String in GENRES:
			if genre == "mine" or genre == "piege":
				continue
			_laisser_finir()
			for e: Dictionary in _evenements_du_genre(type_degats, genre):
				_effets.ajouter(e)
			verifier(
				_effets.opacite_max() <= Effets2D.ALPHA_MAX + 0.001,
				"opacité bornée pour %s" % genre
			)
			_effets.avancer(Effets2D.DUREE_MAX + 0.01)
			verifier_egal(_effets.nombre_vivants(), 0, "%d/%s s'éteint" % [type_degats, genre])


func test_la_mort_d_un_tonneau_ou_d_un_artificier_prend_l_explosion_du_pack() -> void:
	_effets.exploser(Vector2(120, 40))
	verifier_egal(_effets.formes_vivantes(), PackedStringArray(["explosion"]))


func test_la_flamme_du_boss_est_posee_sous_ses_pieds() -> void:
	var arene := (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(arene)
	arene.reinitialiser()
	var boss: int = _donnees.familles.size() + 1
	var vue := VueArene.new()
	vue.tick = 1
	vue.ennemis_id.append(1)
	vue.ennemis_pos.append(Vector2(400, 0))
	vue.ennemis_famille.append(boss)
	vue.ennemis_pv.append(255)
	vue.ennemis_statuts.append(0)
	arene.afficher(vue, 1.0)
	var sprite: Sprite2D = arene.sprite_instance(boss, 0)
	verifier_non_nul(sprite)
	var flamme: Node = sprite.find_child("Flamme", false, false)
	verifier_non_nul(flamme, "flamme enfant du boss")
	if flamme is Sprite2D:
		verifier((flamme as Sprite2D).show_behind_parent, "derrière le boss")
	# Une famille ordinaire n'en a pas.
	var vue2 := VueArene.new()
	vue2.tick = 2
	vue2.ennemis_id.append(2)
	vue2.ennemis_pos.append(Vector2(400, 0))
	vue2.ennemis_famille.append(0)
	vue2.ennemis_pv.append(255)
	vue2.ennemis_statuts.append(0)
	arene.afficher(vue2, 1.0)
	verifier_nul(arene.sprite_instance(0, 0).find_child("Flamme", false, false))
	arene.get_parent().remove_child(arene)
	arene.free()


func _arene_avec_effets() -> Arene2D:
	var arene := (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(arene)
	arene.reinitialiser()
	return arene


func _vue_avec(tick: int, familles: Array[int], evenements: Array[Dictionary]) -> VueArene:
	var vue := VueArene.new()
	vue.tick = tick
	for i: int in familles.size():
		vue.ennemis_id.append(i + 1)
		vue.ennemis_pos.append(Vector2(200 + i * 50, 100))
		vue.ennemis_famille.append(familles[i])
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	vue.evenements = evenements
	return vue


func test_l_arene_envoie_ses_evenements_aux_effets_et_explose_les_tonneaux() -> void:
	var arene := _arene_avec_effets()
	var ids: PackedStringArray = Apparence2D.ids_entites(_donnees)
	var tonneau: int = ids.find("tonneau_de_poudre")
	var artificier: int = ids.find("artificier_de_fumee")
	var autre: int = ids.find("rodeur_de_suie")
	verifier(tonneau >= 0 and artificier >= 0 and autre >= 0)
	arene.afficher(_vue_avec(1, [tonneau, artificier, autre], []), 1.0)
	var morts: Array[Dictionary] = [
		_evenement("mort", 4, Vector2(200, 100), Vector2(200, 100), 0.0),
		_evenement("mort", 4, Vector2(250, 100), Vector2(250, 100), 0.0),
		_evenement("mort", 4, Vector2(300, 100), Vector2(300, 100), 0.0),
		_evenement("tir", 2, Vector2.ZERO, Vector2(500, 0), 0.0),
	]
	arene.afficher(_vue_avec(2, [], morts), 1.1)
	var effets := arene.get_node("Effets") as Effets2D
	verifier_non_nul(effets, "nœud Effets")
	if effets != null:
		verifier_egal(effets.formes_vivantes().count("explosion"), 2, "deux explosions")
		verifier(effets.nombre_vivants() >= 3, "explosions et tir")
	verifier_egal(arene.nombre_morts_visibles(), 1, "une seule mort sur Dead.png")
	arene.get_parent().remove_child(arene)
	arene.free()
