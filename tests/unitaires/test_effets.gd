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

var _effets: Effets = null
var _donnees: Donnees = null


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_effets = Effets.new()
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
		var rendu: Dictionary = Effets.rendu(type_degats, genre)
		verifier(not rendu.is_empty(), "pas de rendu décrit pour %s" % cle)


## Les formes vivantes d'un impact de zone, avec le statut `statut` ("" pour aucun).
func _formes_de_l_impact(type_degats: int, statut: String) -> PackedStringArray:
	_laisser_finir()
	var e := _evenement("impact", type_degats, Vector2.ZERO, Vector2(200, 100), 90.0)
	if statut != "":
		var index: int = VueArene.STATUTS_ARME.find(statut)
		e["statut"] = index if index > 0 else statut
	verifier(_effets.ajouter(e), "effet pour %s" % statut)
	var formes: PackedStringArray = _effets.formes_vivantes()
	formes.sort()
	return formes


func test_chaque_statut_laisse_sa_marque_ou_retombe_sur_le_rendu_par_type() -> void:
	# Tous les statuts que la simulation transporte et ceux des données : un statut du lot 9 sans
	# marque (avant T9.19) donne exactement l'impact du type de dégâts, sans erreur.
	var statuts: Dictionary = {}
	for statut: String in VueArene.STATUTS_ARME:
		if statut != "":
			statuts[statut] = true
	for id: String in _donnees.armes:
		for s: Dictionary in (_donnees.armes[id] as Dictionary)["statuts"]:
			statuts[String(s["kind"])] = true
	verifier(statuts.size() >= 11, "les statuts du lot 9 sont dans la boucle")
	var formes_vues: Dictionary = {}
	var marques: int = 0
	for statut: String in statuts:
		if statut == "vol_de_vie":
			continue  # remonte vers la tour : test_le_vol_de_vie_remonte_vers_la_tour_en_vert
		if Effets.FORMES_STATUT.has(statut):
			marques += 1
		for type_degats: int in TYPES:
			var sans_statut: PackedStringArray = _formes_de_l_impact(type_degats, "")
			var formes: PackedStringArray = _formes_de_l_impact(type_degats, statut)
			if not Effets.FORMES_STATUT.has(statut):
				verifier_egal(
					formes, sans_statut, "%s retombe sur le type %d" % [statut, type_degats]
				)
				continue
			var attendue: String = String(Effets.FORMES_STATUT[statut])
			verifier(formes.has(attendue), "%s dessine %s" % [statut, attendue])
			formes_vues[attendue] = true
	verifier(marques >= 4, "poison, brûlure, givre, étourdissement au moins")
	verifier_egal(formes_vues.size(), marques, "une marque différente par statut")


func test_chaque_type_de_degats_a_sa_propre_forme_de_projectile_et_pas_seulement_sa_couleur(
) -> void:
	var formes: Dictionary = {}
	for type_degats: int in TYPES:
		var forme: String = Effets.rendu(type_degats, "cible_unique")["projectile"]
		verifier(forme != "", "forme de projectile pour le type %d" % type_degats)
		formes[forme] = true
	verifier_egal(formes.size(), TYPES.size(), "cinq formes de projectile différentes")


func test_le_percant_tire_la_fleche_et_le_siege_la_dynamite_du_pack() -> void:
	var fleche: String = Effets.rendu(Types.TypeDegats.PERCANT, "cible_unique")["projectile"]
	var dynamite: String = Effets.rendu(Types.TypeDegats.SIEGE, "cible_unique")["projectile"]
	var explosion: String = Effets.rendu(Types.TypeDegats.SIEGE, "zone")["impact"]
	verifier_egal(fleche, "fleche")
	verifier_egal(dynamite, "dynamite")
	verifier_egal(explosion, "explosion")


func test_le_rebond_trace_un_trait_de_cible_en_cible() -> void:
	for type_degats: int in TYPES:
		var forme_rebond: String = Effets.rendu(type_degats, "rebond")["impact"]
		verifier(forme_rebond.begins_with("trait"), "rendu du rebond %s" % forme_rebond)
		_laisser_finir()
		_effets.ajouter(_evenement("impact", type_degats, Vector2(100, 0), Vector2(200, 0), 0.0))
		var formes: PackedStringArray = _effets.formes_vivantes()
		verifier_egal(formes.size(), 1, "un seul effet pour le saut")
		verifier(formes[0].begins_with("trait"), "trait pour %d" % type_degats)


func test_une_onde_et_une_aura_dessinent_un_anneau_qui_s_etend() -> void:
	for type_degats: int in TYPES:
		for genre: String in ["onde", "aura"]:
			var forme: String = Effets.rendu(type_degats, genre)["impact"]
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
		verifier(_effets.nombre_vivants() <= Effets.PLAFOND)
	verifier_egal(_effets.nombre_vivants(), Effets.PLAFOND, "le plafond est atteint")
	verifier(_effets.taille_pool() <= Effets.PLAFOND, "pool %d" % _effets.taille_pool())


func test_le_pool_revient_a_zero_noeud_actif_et_ne_fuit_pas() -> void:
	for tour: int in 3:
		for i: int in 500:
			_effets.ajouter(_evenement("tir", i % 5, Vector2.ZERO, Vector2(i, 3), 0.0))
			_effets.ajouter(_evenement("impact", i % 5, Vector2.ZERO, Vector2(i, 3), 90.0))
			_effets.exploser(Vector2(i, i))
		_laisser_finir()
		verifier_egal(_effets.nombre_vivants(), 0, "plus rien de vivant (tour %d)" % tour)
		verifier_egal(_effets.nombre_visibles(), 0, "plus aucun nœud visible (tour %d)" % tour)
	verifier(_effets.taille_pool() <= Effets.PLAFOND, "pool %d" % _effets.taille_pool())
	verifier_egal(
		_effets.get_child_count(),
		_effets.taille_pool() + _effets.emetteurs_etincelles().size() + 1,
		"aucun nœud perdu (le pool des attaques élémentaires est le « + 1 »)"
	)


## Les armes à signature sans élément : les six armes de la proposition D22 ont leur rendu à part
## (`test_effets_elementaires.gd`).
func _ids_sans_element() -> PackedStringArray:
	var ids := PackedStringArray()
	for id: String in SignaturesArmes.ids():
		if ElementsArmes.de(id) == "":
			ids.append(id)
	return ids


func test_chaque_texture_citee_existe() -> void:
	var chemins: PackedStringArray = Effets.textures_citees()
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
				_effets.opacite_max() <= Effets.ALPHA_MAX + 0.001, "opacité bornée pour %s" % genre
			)
			# Un impact attend son projectile, et un saut de rebond le saut d'avant.
			var attente: float = Effets.DUREE_TIR + 2.0 * Effets.DECALAGE_SAUT
			_effets.avancer(attente + Effets.DUREE_MAX + 0.01)
			verifier_egal(_effets.nombre_vivants(), 0, "%d/%s s'éteint" % [type_degats, genre])


func test_un_tonneau_qui_explose_au_contact_declenche_l_explosion_et_une_dynamite_aussi() -> void:
	var arene := _arene_avec_effets()
	var ids: PackedStringArray = Apparence.ids_entites(_donnees)
	var explosifs: Array[int] = []
	var autres: Array[int] = []
	for f: int in _donnees.familles.size():
		var famille: Dictionary = _donnees.familles[f]
		if famille["modele"] == "tonneau" or famille["modele"] == "dynamite":
			explosifs.append(f)
		else:
			autres.append(f)
	verifier_egal(explosifs.size(), 8, "quatre tonneaux et quatre dynamites")
	verifier(Effets.famille_explosive(ids[explosifs[0]]), "un tonneau explose")
	for f: int in autres:
		verifier_faux(Effets.famille_explosive(ids[f]), "%s n'explose pas" % ids[f])
	verifier_faux(Effets.famille_explosive(String(_donnees.convoi["id"])), "le convoi")
	verifier_faux(Effets.famille_explosive(String(_donnees.boss["id"])), "le boss")
	var tick: int = 1
	var places: Array[int] = explosifs.duplicate()
	places.append(autres[0])
	arene.afficher(_vue_avec(tick, places, []), 1.0)
	# Les explosifs meurent (ils quittent la vue), pas l'autre, avec leurs événements de mort.
	var morts: Array[Dictionary] = []
	for i: int in explosifs.size():
		var pos := Vector2(200 + i * 50, 100)
		morts.append(_evenement("mort", 4, pos, pos, 0.0))
	tick += 1
	var restant := _vue_avec(tick, [autres[0]], morts)
	restant.ennemis_id[0] = places.size()
	restant.ennemis_pos[0] = Vector2(200 + explosifs.size() * 50, 100)
	arene.afficher(restant, 1.1)
	var effets := arene.get_node("Effets") as Effets
	verifier_egal(
		effets.formes_vivantes().count("explosion"), explosifs.size(), "une explosion par explosif"
	)
	arene.get_parent().remove_child(arene)
	arene.free()


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
	var ids: PackedStringArray = Apparence.ids_entites(_donnees)
	var tonneau: int = ids.find("tonneau_jaune")
	var artificier: int = ids.find("dynamite_rouge")
	var autre: int = ids.find("torche_jaune")
	verifier(tonneau >= 0 and artificier >= 0 and autre >= 0)
	arene.afficher(_vue_avec(1, [tonneau, artificier, autre], []), 1.0)
	var morts: Array[Dictionary] = [
		_evenement("mort", 4, Vector2(200, 100), Vector2(200, 100), 0.0),
		_evenement("mort", 4, Vector2(250, 100), Vector2(250, 100), 0.0),
		_evenement("mort", 4, Vector2(300, 100), Vector2(300, 100), 0.0),
		_evenement("tir", 2, Vector2.ZERO, Vector2(500, 0), 0.0),
	]
	arene.afficher(_vue_avec(2, [], morts), 1.1)
	var effets := arene.get_node("Effets") as Effets
	verifier_non_nul(effets, "nœud Effets")
	if effets != null:
		verifier_egal(effets.formes_vivantes().count("explosion"), 2, "deux explosions")
		verifier(effets.nombre_vivants() >= 3, "explosions et tir")
	verifier_egal(arene.nombre_morts_visibles(), 1, "une seule mort sur Dead.png")
	arene.get_parent().remove_child(arene)
	arene.free()


func test_un_evenement_absorption_cree_un_eclat_bleu_dans_le_plafond() -> void:
	var absorption := _evenement("absorption", 0, Vector2.ZERO, Vector2.ZERO, 0.0)
	verifier(_effets.ajouter(absorption), "l'absorption crée un effet")
	verifier_egal(_effets.nombre_vivants(), 1)
	var couleur: Color = _effets.couleur_du_premier()
	verifier(couleur.b > couleur.r and couleur.b > 0.8, "bleu : %s" % couleur)
	_effets.avancer(Effets.DUREE_MAX + 0.01)
	verifier_egal(_effets.nombre_vivants(), 0, "l'éclat dure moins que DUREE_MAX")
	for i: int in 300:
		_effets.ajouter(absorption)
	verifier(
		_effets.nombre_vivants() <= Effets.PLAFOND, "plafond tenu : %d" % _effets.nombre_vivants()
	)


# --- Signatures d'armes en jeu (T8.16) --------------------------------------------------------


## Un événement d'arme réelle : `arme` est l'index de l'arme dans `Donnees.ids_catalogue`.
func _evenement_arme(
	k: String, id: String, de: Vector2, vers: Vector2, rayon: float = 0.0, statut: int = 0
) -> Dictionary:
	var type_degats: int = (_donnees.armes[id] as Dictionary)["type_degats"]
	var e: Dictionary = _evenement(k, type_degats, de, vers, rayon)
	e["arme"] = _donnees.ids_catalogue.find(id)
	if statut > 0:
		e["statut"] = statut
	return e


func _avec_catalogue() -> void:
	_effets.catalogue = _donnees.ids_catalogue


func _sans_alpha(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 1.0)


func test_chaque_arme_produit_un_tir_aux_formes_et_a_la_couleur_de_sa_signature() -> void:
	_avec_catalogue()
	for id: String in _ids_sans_element():
		_effets.vider()
		var sig: Dictionary = SignaturesArmes.de(id)
		verifier(_effets.ajouter(_evenement_arme("tir", id, Vector2.ZERO, Vector2(300, -200))), id)
		var formes: PackedStringArray = _effets.formes_vivantes()
		verifier_contient(formes, sig["projectile"], "projectile de %s" % id)
		verifier_contient(formes, sig["trainee"], "traînée de %s" % id)
		verifier_egal(
			_sans_alpha(_effets.couleur_du_premier()), sig["couleur"], "couleur de %s" % id
		)


func _rendu_du_tir(id: String) -> String:
	_effets.vider()
	_effets.ajouter(_evenement_arme("tir", id, Vector2.ZERO, Vector2(300, -200)))
	var formes: Array[String] = []
	for forme: String in _effets.formes_vivantes():
		formes.append(forme)
	formes.sort()
	var couleur: Color = _sans_alpha(_effets.couleur_du_premier())
	return "%s|%s|%.1f" % [",".join(formes), couleur.to_html(false), _effets.taille_du_premier()]


func test_deux_armes_ne_produisent_jamais_le_meme_rendu() -> void:
	_avec_catalogue()
	var ids: PackedStringArray = _ids_sans_element()
	var rendus: Dictionary = {}
	for id: String in ids:
		rendus[id] = _rendu_du_tir(id)
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			verifier(rendus[ids[i]] != rendus[ids[j]], "%s et %s : même rendu" % [ids[i], ids[j]])


func test_l_impact_suit_la_signature_de_l_arme() -> void:
	_avec_catalogue()
	for id: String in _ids_sans_element():
		_effets.vider()
		var sig: Dictionary = SignaturesArmes.de(id)
		verifier(
			_effets.ajouter(_evenement_arme("impact", id, Vector2.ZERO, Vector2(300, -200))), id
		)
		verifier_contient(_effets.formes_vivantes(), sig["impact"], "impact de %s" % id)


func test_un_evenement_sans_arme_garde_le_rendu_par_type_de_degats() -> void:
	_avec_catalogue()
	for type_degats: int in 5:
		_effets.vider()
		var tir: Dictionary = _evenement("tir", type_degats, Vector2.ZERO, Vector2(300, -200), 0.0)
		verifier(_effets.ajouter(tir))
		var attendu: Dictionary = Effets.rendu(type_degats, "")
		verifier_egal(_effets.formes_vivantes(), PackedStringArray([attendu["projectile"]]))
		verifier_egal(_sans_alpha(_effets.couleur_du_premier()), Effets.COULEURS[type_degats])
	# Une arme hors du catalogue retombe sur le rendu par type de dégâts.
	_effets.vider()
	var inconnu: Dictionary = _evenement("tir", 1, Vector2.ZERO, Vector2(300, -200), 0.0)
	inconnu["arme"] = 99999
	verifier(_effets.ajouter(inconnu))
	verifier_egal(_effets.formes_vivantes(), PackedStringArray([Effets.rendu(1, "")["projectile"]]))


func test_une_arme_du_catalogue_sans_signature_retombe_sur_le_rendu_par_type() -> void:
	# Avant T9.18, les armes du lot 9 sont dans les données sans signature.
	var catalogue: PackedStringArray = _donnees.ids_catalogue.duplicate()
	catalogue.append("arme_sans_signature")
	_effets.catalogue = catalogue
	var cas: Array[Array] = []
	for type_degats: int in TYPES:
		cas.append(["arme_sans_signature", type_degats])
	for id: String in _donnees.armes:
		if SignaturesArmes.de(id).is_empty():
			cas.append([id, int((_donnees.armes[id] as Dictionary)["type_degats"])])
	for c: Array in cas:
		var id: String = c[0]
		var type_degats: int = c[1]
		_effets.vider()
		var tir: Dictionary = _evenement("tir", type_degats, Vector2.ZERO, Vector2(300, -200), 0.0)
		tir["arme"] = catalogue.find(id)
		verifier(_effets.ajouter(tir), "tir de %s" % id)
		var attendu: Dictionary = Effets.rendu(type_degats, "")
		verifier_egal(_effets.formes_vivantes(), PackedStringArray([attendu["projectile"]]), id)
		verifier_egal(_sans_alpha(_effets.couleur_du_premier()), Effets.COULEURS[type_degats], id)
		var impact: Dictionary = _evenement("impact", type_degats, Vector2.ZERO, Vector2.ZERO, 0.0)
		_effets.vider()
		verifier(_effets.ajouter(impact.duplicate()))
		var par_type: PackedStringArray = _effets.formes_vivantes()
		_effets.vider()
		impact["arme"] = catalogue.find(id)
		verifier(_effets.ajouter(impact), "impact de %s" % id)
		verifier_egal(_effets.formes_vivantes(), par_type, "impact de %s par type" % id)


func test_chaque_statut_a_un_visuel_distinct() -> void:
	var statuts: Array[String] = ["poison", "brulure", "givre", "etourdissement", "vol_de_vie"]
	verifier_egal(statuts.size(), 5)
	for statut: String in statuts:
		verifier(Effets.FORMES_STATUT.has(statut), "forme de %s" % statut)
		verifier(
			VueArene.STATUTS_ARME.has(statut) and VueArene.STATUTS_ARME.find(statut) > 0,
			"%s voyage dans l'événement" % statut
		)
		_effets.vider()
		var impact: Dictionary = _evenement("impact", 0, Vector2.ZERO, Vector2(300, -200), 0.0)
		impact["statut"] = VueArene.STATUTS_ARME.find(statut)
		verifier(_effets.ajouter(impact), statut)
		verifier_contient(
			_effets.formes_vivantes(), Effets.FORMES_STATUT[statut], "marque de %s" % statut
		)
	for i: int in statuts.size():
		for j: int in range(i + 1, statuts.size()):
			var a: String = statuts[i]
			var b: String = statuts[j]
			verifier(
				Effets.FORMES_STATUT[a] != Effets.FORMES_STATUT[b], "%s et %s : forme" % [a, b]
			)
			var ecart: float = _distance(Effets.couleur_statut(a), Effets.couleur_statut(b))
			verifier(ecart >= 0.2, "%s et %s : couleurs trop proches (%.2f)" % [a, b, ecart])


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_le_vol_de_vie_remonte_vers_la_tour_en_vert() -> void:
	var ennemi := Vector2(300, -200)
	var impact: Dictionary = _evenement("impact", 0, Vector2.ZERO, ennemi, 0.0)
	impact["statut"] = VueArene.STATUTS_ARME.find("vol_de_vie")
	verifier(_effets.ajouter(impact))
	var trajet: Array[Vector2] = _effets.trajet_de("soin")
	verifier_egal(trajet.size(), 2, "un effet « soin » est vivant")
	if trajet.size() == 2:
		verifier_egal(trajet[0], Apparence.vers_pixels(ennemi), "il part de l'ennemi")
		verifier_egal(trajet[1], Vector2.ZERO, "il finit à la tour")
	var couleur: Color = _effets.couleur_de("soin")
	verifier_egal(_sans_alpha(couleur), Effets.COULEUR_SOIN)
	verifier(couleur.g > couleur.r and couleur.g > couleur.b, "vert")
	verifier(Effets.COULEUR_SOIN.v >= 0.6, "assez clair pour se lire de loin")
	_effets.avancer(Effets.DUREE_SOIN * 0.5)
	verifier(_effets.nombre_vivants() > 0, "encore en vol à mi-course")
	_effets.avancer(Effets.DUREE_SOIN)
	verifier_egal(_effets.nombre_vivants(), 0, "arrivé, il disparaît")
	verifier(Effets.DUREE_SOIN <= Effets.DUREE_MAX, "durée dans la limite des effets")


func test_le_plafond_de_200_effets_tient_avec_40_armes_qui_tirent() -> void:
	_avec_catalogue()
	var ids: PackedStringArray = SignaturesArmes.ids()
	for tour: int in 10:
		for k: int in 40:
			var id: String = ids[(tour * 40 + k) % ids.size()]
			_effets.ajouter(_evenement_arme("tir", id, Vector2.ZERO, Vector2(300 + k, -200)))
			_effets.ajouter(
				_evenement_arme("impact", id, Vector2.ZERO, Vector2(300 + k, -200), 0.0, 5)
			)
	verifier(
		_effets.nombre_vivants() <= Effets.PLAFOND, "plafond tenu : %d" % _effets.nombre_vivants()
	)
	verifier_egal(_effets.taille_pool() <= Effets.PLAFOND + Effets.PLAFOND, true, "pool borné")
