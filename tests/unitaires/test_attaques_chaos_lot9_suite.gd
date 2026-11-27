extends CasAttaquesChaosLot9
## Les neuf armes de chaos du lot 9 (D22), les genres : invocation (urne des ombres, archère
## fantôme), rebond (miroir de discorde), barrage (tempête de maléfices), aura (coupe d'oubli) ;
## puis ce qui distingue les neuf armes les unes des autres. Durées en images à 60 i/s.

const APPARITIONS: Dictionary = {"urne": "apparition_ombre", "archere": "apparition_spectre"}

# --- Invocation : l'apparition d'un allié ---------------------------------------------------------


func test_l_apparition_de_l_allie_nait_a_l_arrivee_du_projectile_et_atteint_son_pic_vite() -> void:
	for element: String in APPARITIONS:
		var planche: String = String(APPARITIONS[element])
		_a.vider()
		var vol: int = int(ARMES[_arme_de(element)]["vol"])
		verifier_proche(_a.tirer(element, TOUR, CIBLE) / IMAGE, 3.0 + vol, 0.01, element)
		_avancer(3 + vol - 2)
		verifier_egal(_visibles(planche), 0, "%s : rien avant l'arrivée du projectile" % element)
		var rang: int = _rang_du_pic(planche, _image_du_pic(planche), 12)
		verifier(rang >= 0 and rang <= 12 / 4 + 2, "%s : pic %d images après" % [element, rang])
		verifier(_a.diametre_max() <= DIAMETRE_MAX_CIBLE_UNIQUE, "%s : petit" % element)


func test_l_apparition_de_l_allie_reste_en_mouvement_reduit_sans_particule() -> void:
	for element: String in APPARITIONS:
		_a.vider()
		_a.mouvement_reduit = true
		var planche: String = String(APPARITIONS[element])
		_a.tirer(element, TOUR, CIBLE)
		var vol: int = int(ARMES[_arme_de(element)]["vol"])
		_avancer(3 + vol + 2)
		verifier(_visibles(planche) > 0, "%s : l'apparition reste" % element)
		verifier_egal(_a.particules_actives(), 0)
		_a.mouvement_reduit = false


func test_le_coup_d_un_allie_est_celui_de_son_element_sur_sa_cible() -> void:
	for id: String in ["urne_des_ombres", "archere_fantome"]:
		var effets: Effets = _effets_neuf()
		var impacts: int = 0
		for evenement: Dictionary in _cycle(id):
			impacts += 1 if String(evenement["k"]) == "impact" else 0
			effets.ajouter(evenement)
		verifier_egal(impacts, 1, "%s : un impact par coup d'allié" % id)
		verifier(_premiere_apparition(effets, _impact(id), 40) >= 0, "%s : le coup" % id)
		effets.free()


func test_l_urne_et_l_archere_n_ont_ni_la_meme_apparition_ni_le_meme_coup() -> void:
	verifier(String(APPARITIONS["urne"]) != String(APPARITIONS["archere"]))
	verifier(_impact("urne_des_ombres") != _impact("archere_fantome"))
	verifier(
		(
			AttaquesElementaires.planche_projectile("urne")
			!= AttaquesElementaires.planche_projectile("archere")
		)
	)


func _arme_de(element: String) -> String:
	for id: String in ARMES:
		if _element(id) == element:
			return id
	return ""


# --- Miroir de discorde : un projectile et un impact par saut -------------------------------------


func test_le_miroir_lance_un_projectile_par_saut_et_un_impact_par_cible() -> void:
	var effets: Effets = _effets_neuf()
	var attendus: int = 0
	for evenement: Dictionary in _cycle("miroir_de_discorde"):
		attendus += 1 if String(evenement["k"]) == "impact" else 0
		effets.ajouter(evenement)
	verifier_egal(attendus, 3, "trois cibles")
	# Un projectile par saut, tous créés avec le tir : les suivants attendent leur départ.
	verifier_egal(effets.elementaires().etats("eclat_discorde").size(), 3, "un projectile par saut")
	var apparus: int = 0
	var avant: int = 0
	for _i: int in 90:
		effets.avancer(IMAGE)
		var impacts: int = _vus(effets, "pointes_discorde")
		apparus += maxi(impacts - avant, 0)
		avant = impacts
	verifier_egal(apparus, 3, "un impact par cible")
	effets.free()


func _vus(effets: Effets, planche: String) -> int:
	var n: int = 0
	for etat: Dictionary in effets.elementaires().etats(planche):
		n += 1 if etat["visible"] else 0
	return n


# --- Tempête de maléfices : neuf projectiles décalés de 2 images, un seul anneau ------------------


func test_les_projectiles_de_la_tempete_partent_a_deux_images_l_un_de_l_autre() -> void:
	var premier: float = _a.tirer("malefices", TOUR, CIBLE, 0.0)
	var deuxieme: float = _a.tirer("malefices", TOUR, CIBLE, 2.0 * IMAGE)
	verifier_proche((deuxieme - premier) / IMAGE, 2.0, 0.01, "décalage de deux images")


func test_la_tempete_dans_effets_montre_chaque_malefice_et_un_seul_anneau() -> void:
	var effets: Effets = _effets_neuf()
	var impacts: int = 0
	for evenement: Dictionary in _cycle("tempete_de_malefices"):
		impacts += 1 if String(evenement["k"]) == "impact" else 0
		effets.ajouter(evenement)
	var rangs: Array[int] = []
	var avant: int = 0
	var anneaux: int = 0
	for i: int in 60:
		effets.avancer(IMAGE)
		var vus: int = _vus(effets, "eclat_malefice")
		for _k: int in maxi(vus - avant, 0):
			rangs.append(i)
		avant = vus
		anneaux = maxi(anneaux, effets.elementaires().etats("").size())
	verifier_egal(rangs.size(), impacts, "un orbe d'impact par projectile")
	for k: int in range(1, rangs.size()):
		verifier_egal(rangs[k] - rangs[k - 1], 2, "décalés de deux images")
	verifier_egal(anneaux, 1, "un seul anneau au rayon réel pour tout le tir")
	effets.free()


# --- Les neuf armes ensemble ----------------------------------------------------------------------


func test_deux_armes_de_chaos_ne_produisent_jamais_le_meme_rendu() -> void:
	var ids: Array = ARMES.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: AttaqueElement = AttaquesElementaires.registre()[_element(String(ids[i]))]
			var b: AttaqueElement = AttaquesElementaires.registre()[_element(String(ids[j]))]
			verifier(
				(
					String(a.conf()["projectile"]) != String(b.conf()["projectile"])
					or String(a.conf()["projectile"]) == ""
				),
				"%s et %s : même projectile" % [ids[i], ids[j]]
			)
			verifier(
				_impact(String(ids[i])) != _impact(String(ids[j])),
				"%s et %s : même impact" % [ids[i], ids[j]]
			)


func test_une_arme_de_chaos_ne_partage_son_impact_avec_aucune_autre_arme() -> void:
	var planches: Dictionary = {}
	for element: String in AttaquesElementaires.registre():
		if not _est_chaos(element):
			var el: AttaqueElement = AttaquesElementaires.registre()[element]
			# Un élément de fin de partie reprend les planches de sa famille, teintées (T12.8).
			if el is AttaqueTardive:
				continue
			for planche: String in el.visibles():
				planches[planche] = true
	for id: String in ARMES:
		verifier_faux(planches.has(_impact(id)), "%s : impact déjà pris" % id)


func _est_chaos(element: String) -> bool:
	for id: String in ARMES:
		if _element(id) == element:
			return true
	return false


func test_chaque_planche_du_chaos_est_dessinee_et_declaree_par_son_element() -> void:
	for id: String in ARMES:
		var el: AttaqueElement = AttaquesElementaires.registre()[_element(id)]
		for planche: String in el.planches():
			verifier(
				ResourceLoader.exists("%s%s.png" % [PlanchesEffets.dossier(), planche]),
				"%s : planche %s" % [id, planche]
			)
		verifier(el.visibles().has(_impact(id)), "%s : diamètre visible de l'impact" % id)
