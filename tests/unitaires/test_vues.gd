extends CasDeTest
## Contrat des vues : un aller-retour par dictionnaire restitue la vue à l'identique, et
## une donnée malformée donne `null`, jamais une exception.

const NOMS_JOUEURS := [
	"Renée-Marie de Châteauneuf-sur-Loire  (la Grande)",
	"Émile  Dupont-Lefèvre",
	"Ophélie de La Roche-aux-Fées",
	"Jean-Baptiste   Ça-Va-Très-Bien-Merci",
	"Ælfwyn Müller-Østergaard",
	"Ségolène Ben-Aïssa Dubois-Ménard",
	"Anne-Sophie   d'Armagnac-Lévêque",
	"Ǧamāl  al-Ḥāfiẓ Thérèse",
]


## Vue d'arène avec des valeurs de chaque genre : 300 ennemis, 8 armes, 4 offres dont une
## vendue, un événement de chaque genre.
func _vue_pleine() -> VueArene:
	var vue := VueArene.new()
	vue.tick = 123456
	vue.manche = 17
	vue.phase = 1
	vue.temps_restant = 12.5
	vue.prochaine_famille = 5
	vue.prochaine_armure = 2
	vue.sans_fin = false
	vue.tour_pv = 812.5
	vue.tour_pv_max = 1000.0
	vue.tour_armure = 4.75
	vue.tour_mana = 40.5
	vue.tour_mana_max = 120.0
	vue.prochaines_familles = PackedInt32Array([5, 7])
	vue.prochaines_armures = PackedByteArray([2, 0])
	vue.argent = 320
	vue.revenu = 45
	vue.revenu_dans = 6.25
	vue.cout_relance = 25
	vue.relances_gratuites = 1
	vue.offres = [
		{"id": "arc_de_ronce", "genre": 0, "rarete": 1, "prix": 120, "vendu": false},
		{"id": "bouclier_de_saule", "genre": 1, "rarete": 2, "prix": 240, "vendu": true},
		{"id": "sceptre_ocre", "genre": 0, "rarete": 3, "prix": 400, "vendu": false},
		{"id": "trempe_de_bronze", "genre": 1, "rarete": 0, "prix": 60, "vendu": false},
	]
	vue.armes = [
		{"id": "epee_courte", "recharge_ratio": 0.25, "niveau": 1},
		{"id": "lance_de_lin", "recharge_ratio": 0.5, "niveau": 1},
		{"id": "hache_de_cendre", "recharge_ratio": 1.0, "niveau": 1},
		{"id": "fronde_de_braise", "recharge_ratio": 0.0, "niveau": 1},
		{"id": "arc_de_ronce", "recharge_ratio": 0.75, "niveau": 1},
		{"id": "faux_de_brume", "recharge_ratio": 0.125, "niveau": 1},
		{"id": "marteau_de_gel", "recharge_ratio": 0.333, "niveau": 1},
		{"id": "sceptre_ocre", "recharge_ratio": 0.9, "niveau": 1},
	]
	vue.ameliorations = {"trempe_de_bronze": 2, "force_tranchante": 1}

	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var familles := PackedByteArray()
	var pvs := PackedByteArray()
	var statuts := PackedByteArray()
	# Toutes les familles du jeu, convoi et boss compris : l'index tient dans un octet.
	var nb_familles := Donnees.charger().familles.size() + 2
	for i in 300:
		ids.append(1000 + i)
		positions.append(Vector2(float(i) * 3.5 - 500.0, 250.0 - float(i) * 1.25))
		familles.append(i % nb_familles)
		pvs.append((i * 37) % 256)
		statuts.append(i % 32)
	vue.ennemis_id = ids
	vue.ennemis_pos = positions
	vue.ennemis_famille = familles
	vue.ennemis_pv = pvs
	vue.ennemis_statuts = statuts

	vue.evenements = [
		{
			"k": "tir",
			"t": 123450,
			"de": Vector2(10.5, -3.25),
			"vers": Vector2(400.0, 120.5),
			"type_degats": 0,
			"rayon": 0.0,
		},
		{
			"k": "impact",
			"t": 123451,
			"de": Vector2(10.5, -3.25),
			"vers": Vector2(400.0, 120.5),
			"type_degats": 2,
			"rayon": 36.0,
		},
		{
			"k": "mort",
			"t": 123452,
			"de": Vector2(-80.0, 15.0),
			"vers": Vector2(-80.0, 15.0),
			"type_degats": 4,
			"rayon": 0.0,
		},
	]
	vue.marche_noir_ouvert = true
	vue.eliminations = 42
	vue.degats_infliges = 15234.5
	vue.manche_max = 17
	return vue


## Vue globale avec `nb` joueurs ; la partie est terminée à 8 joueurs (classement rempli).
func _globale(nb: int) -> VueGlobale:
	var vue := VueGlobale.new()
	vue.temps_ecoule = 754.5 + float(nb)
	vue.en_cours = nb > 0 and nb < 8
	vue.termine = nb == 8
	var joueurs: Array[Dictionary] = []
	for i in nb:
		(
			joueurs
			. append(
				{
					"id": i,
					"nom": NOMS_JOUEURS[i % NOMS_JOUEURS.size()],
					"manche": 3 + i,
					"eliminations": 2 * i,
					"degats": 150.5 + float(i),
					"revenu": 40 + i,
					"dps": 12.5 * float(i),
					"pv": 100.0 * float(i),
					"pv_max": 1000.0,
					"skin": (i * 37) % 256,
					"vivant": i % 2 == 0,
					"victorieux": nb == 8 and i == 0,
				}
			)
		)
	vue.joueurs = joueurs
	if nb > 1:
		vue.densites = {0: _densite(7), 1: _densite(200)}
	if vue.termine:
		var classement: Array[int] = []
		for i in nb:
			classement.append(nb - 1 - i)
		vue.classement = classement
	vue.dernier_rempart = nb - 1 if nb > 0 else -1
	return vue


## Une carte de densité de 256 octets (16 × 16 cases), remplie d'une valeur reconnaissable.
func _densite(valeur: int) -> PackedByteArray:
	var carte := PackedByteArray()
	carte.resize(VueGlobale.DENSITE_OCTETS)
	carte.fill(valeur)
	return carte


## Une valeur d'un type différent de `valeur`. Un entier et un flottant sont distincts
## en GDScript : `1.5` remplace un entier, `3` remplace un flottant.
func _autre_type(valeur: Variant) -> Variant:
	match typeof(valeur):
		TYPE_INT:
			return 1.5
		TYPE_FLOAT:
			return 3
		TYPE_STRING:
			return 42
		TYPE_BOOL:
			return 1
	return 42


## Un tableau neuf de `longueur` cases, copié de `valeur` puis complété de zéros. Ne modifie
## jamais `valeur` : un `resize` sur place touchait le dictionnaire source du test.
func _avec_longueur(valeur: Variant, longueur: int) -> Variant:
	match typeof(valeur):
		TYPE_PACKED_INT32_ARRAY:
			var ids_source: PackedInt32Array = valeur
			var ids := PackedInt32Array()
			for i in longueur:
				ids.append(ids_source[i] if i < ids_source.size() else 0)
			return ids
		TYPE_PACKED_VECTOR2_ARRAY:
			var positions_source: PackedVector2Array = valeur
			var positions := PackedVector2Array()
			for i in longueur:
				positions.append(
					positions_source[i] if i < positions_source.size() else Vector2.ZERO
				)
			return positions
		TYPE_PACKED_BYTE_ARRAY:
			var octets_source: PackedByteArray = valeur
			var octets := PackedByteArray()
			for i in longueur:
				octets.append(octets_source[i] if i < octets_source.size() else 0)
			return octets
	return valeur


## Copies de `d` où la première entrée de la liste `nom` a une clé manquante, un mauvais
## type, ou n'est pas un dictionnaire.
func _copies_entree_abimee(d: Dictionary, nom: String) -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	var liste_ref: Array = d[nom]
	var premiere: Dictionary = liste_ref[0]
	for cle: String in premiere.keys():
		var sans: Dictionary = d.duplicate(true)
		var liste_sans: Array = sans[nom]
		var entree_sans: Dictionary = liste_sans[0]
		entree_sans.erase(cle)
		copies.append(sans)

		var mal: Dictionary = d.duplicate(true)
		var liste_mal: Array = mal[nom]
		var entree_mal: Dictionary = liste_mal[0]
		entree_mal[cle] = _autre_type(premiere[cle])
		copies.append(mal)

	var pas_un_dico: Dictionary = d.duplicate(true)
	pas_un_dico[nom] = [42]
	copies.append(pas_un_dico)
	return copies


func test_vue_arene_aller_retour_restitue_une_vue_remplie() -> void:
	var d := _vue_pleine().to_dict()
	var relue := VueArene.from_dict(d)
	verifier_non_nul(relue, "une vue remplie doit se relire")
	if relue == null:
		return
	verifier_egal(relue.to_dict(), d, "aller-retour exact")
	verifier_egal(relue.ennemis_id.size(), 300)
	verifier_egal(relue.armes.size(), 8)
	verifier_egal(relue.offres.size(), 4)
	verifier_egal(relue.evenements.size(), 3)
	verifier_egal(relue.ennemis_pos[299], Vector2(3.5 * 299.0 - 500.0, 250.0 - 1.25 * 299.0))
	verifier_egal(relue.tour_pv, 812.5)
	verifier_egal(relue.tick, 123456)
	verifier_egal(relue.evenements[2]["k"], "mort")


func test_vue_arene_aller_retour_sans_ennemi() -> void:
	var d := VueArene.new().to_dict()
	var relue := VueArene.from_dict(d)
	verifier_non_nul(relue, "une vue vide doit se relire")
	if relue == null:
		return
	verifier_egal(relue.to_dict(), d, "aller-retour exact")
	verifier_egal(relue.ennemis_id.size(), 0)
	verifier_egal(relue.offres.size(), 0)


func test_vue_arene_renvoie_null_si_une_cle_manque_ou_si_le_type_est_faux() -> void:
	var d := _vue_pleine().to_dict()
	for cle: String in d.keys():
		var sans: Dictionary = d.duplicate(true)
		sans.erase(cle)
		verifier_nul(VueArene.from_dict(sans), "sans la clé « %s »" % cle)
		var mal: Dictionary = d.duplicate(true)
		mal[cle] = _autre_type(d[cle])
		verifier_nul(VueArene.from_dict(mal), "« %s » de mauvais type" % cle)


func test_vue_arene_refuse_un_entier_la_ou_un_flottant_est_attendu_et_l_inverse() -> void:
	var d := _vue_pleine().to_dict()
	var tour_entier: Dictionary = d.duplicate(true)
	tour_entier["tour_pv"] = 812
	verifier_nul(VueArene.from_dict(tour_entier), "tour_pv donné en entier")
	var tick_flottant: Dictionary = d.duplicate(true)
	tick_flottant["tick"] = 123456.0
	verifier_nul(VueArene.from_dict(tick_flottant), "tick donné en flottant")


func test_vue_arene_renvoie_null_si_les_tableaux_d_ennemis_ne_sont_pas_de_meme_longueur() -> void:
	var d := _vue_pleine().to_dict()
	for cle: String in [
		"ennemis_id", "ennemis_pos", "ennemis_famille", "ennemis_pv", "ennemis_statuts"
	]:
		for longueur: int in [299, 301]:
			var copie: Dictionary = d.duplicate(true)
			copie[cle] = _avec_longueur(d[cle], longueur)
			verifier_nul(VueArene.from_dict(copie), "%s de longueur %d" % [cle, longueur])


func test_vue_arene_refuse_une_entree_imbriquee_malformee() -> void:
	var d := _vue_pleine().to_dict()
	for nom: String in ["offres", "armes", "evenements"]:
		for copie: Dictionary in _copies_entree_abimee(d, nom):
			verifier_nul(VueArene.from_dict(copie), "entrée abîmée dans « %s »" % nom)

	var cle_non_texte: Dictionary = d.duplicate(true)
	var ameliorations_ref: Dictionary = cle_non_texte["ameliorations"]
	ameliorations_ref[7] = 1
	verifier_nul(VueArene.from_dict(cle_non_texte), "amélioration dont la clé n'est pas un texte")

	var nombre_flottant: Dictionary = d.duplicate(true)
	var ameliorations_mal: Dictionary = nombre_flottant["ameliorations"]
	ameliorations_mal["trempe_de_bronze"] = 2.0
	verifier_nul(VueArene.from_dict(nombre_flottant), "amélioration au nombre flottant")


func test_vue_arene_copie_en_profondeur_dans_les_deux_sens() -> void:
	var reference := _vue_pleine().to_dict()

	# Du dictionnaire vers la vue : modifier la source après coup ne touche pas la vue.
	var source: Dictionary = _vue_pleine().to_dict()
	var vue := VueArene.from_dict(source)
	var entree_source: Dictionary = source["offres"][0]
	entree_source["prix"] = 999
	var ameliorations_source: Dictionary = source["ameliorations"]
	ameliorations_source["trempe_de_bronze"] = 9
	source["tour_pv"] = 1.0
	verifier_egal(vue.to_dict(), reference, "la source modifiée ne change pas la vue")

	# De la vue vers la sortie : modifier une sortie ne touche ni la vue ni une autre sortie.
	var sortie: Dictionary = vue.to_dict()
	var entree_sortie: Dictionary = sortie["offres"][0]
	entree_sortie["prix"] = 1
	var ameliorations_sortie: Dictionary = sortie["ameliorations"]
	ameliorations_sortie["trempe_de_bronze"] = 0
	verifier_egal(vue.to_dict(), reference, "modifier une sortie ne change pas la vue")

	var deja_rendue: Dictionary = vue.to_dict()
	vue.offres[0]["prix"] = 2
	verifier_egal(deja_rendue, reference, "modifier la vue ne change pas une sortie rendue")


func test_vue_globale_aller_retour_de_0_a_8_joueurs() -> void:
	for nb in range(0, 9):
		var d := _globale(nb).to_dict()
		var relue := VueGlobale.from_dict(d)
		verifier_non_nul(relue, "%d joueur(s) : relecture" % nb)
		if relue == null:
			continue
		verifier_egal(relue.to_dict(), d, "%d joueur(s) : aller-retour exact" % nb)
		verifier_egal(relue.joueurs.size(), nb, "%d joueur(s)" % nb)


func test_vue_globale_renvoie_null_si_une_cle_manque_ou_si_le_type_est_faux() -> void:
	var d := _globale(2).to_dict()
	for cle: String in d.keys():
		var sans: Dictionary = d.duplicate(true)
		sans.erase(cle)
		verifier_nul(VueGlobale.from_dict(sans), "sans la clé « %s »" % cle)
		var mal: Dictionary = d.duplicate(true)
		mal[cle] = _autre_type(d[cle])
		verifier_nul(VueGlobale.from_dict(mal), "« %s » de mauvais type" % cle)


func test_vue_globale_refuse_une_entree_de_joueur_malformee() -> void:
	var d := _globale(3).to_dict()
	# Dps, PV, PV max et skin sont facultatifs (un ancien état se relit avec 0.0 et 0) : leur
	# mauvaise forme est testée à part.
	for entree: Dictionary in d["joueurs"]:
		for cle: String in VueGlobale.CHAMPS_JOUEUR_FACULTATIFS:
			entree.erase(cle)
		for cle: String in VueGlobale.CHAMPS_JOUEUR_ENTIERS_FACULTATIFS:
			entree.erase(cle)
	for copie: Dictionary in _copies_entree_abimee(d, "joueurs"):
		verifier_nul(VueGlobale.from_dict(copie), "joueur abîmé")


func test_vue_globale_refuse_un_classement_qui_n_est_pas_que_d_entiers() -> void:
	var d := _globale(8).to_dict()
	var mal: Dictionary = d.duplicate(true)
	mal["classement"] = [0, "1"]
	verifier_nul(VueGlobale.from_dict(mal), "classement avec un texte")


func test_vue_globale_copie_en_profondeur_dans_les_deux_sens() -> void:
	var reference := _globale(8).to_dict()

	var source: Dictionary = _globale(8).to_dict()
	var vue := VueGlobale.from_dict(source)
	var joueur_source: Dictionary = source["joueurs"][0]
	joueur_source["nom"] = "Intrus"
	verifier_egal(vue.to_dict(), reference, "la source modifiée ne change pas la vue")

	var sortie: Dictionary = vue.to_dict()
	var joueur_sortie: Dictionary = sortie["joueurs"][0]
	joueur_sortie["nom"] = "Intrus"
	var classement_sortie: Array = sortie["classement"]
	classement_sortie.append(99)
	verifier_egal(vue.to_dict(), reference, "modifier une sortie ne change pas la vue")


# --- Lot 8 : mana, familles suivantes, armes illimitées, dps et densités -----------------------


func test_vue_arene_aller_retour_avec_mana_et_prochaines_familles() -> void:
	for nombre in range(0, 4):
		var vue := VueArene.new()
		vue.tour_mana = 12.5 * float(nombre)
		vue.tour_mana_max = 50.0
		var familles := PackedInt32Array()
		var armures := PackedByteArray()
		for i in nombre:
			familles.append(3 * i + 1)
			armures.append(i % 4)
		vue.prochaines_familles = familles
		vue.prochaines_armures = armures
		var relue := VueArene.from_dict(vue.to_dict())
		verifier_non_nul(relue, "%d famille(s) suivante(s) : relecture" % nombre)
		if relue == null:
			continue
		verifier_proche(relue.tour_mana, 12.5 * float(nombre))
		verifier_proche(relue.tour_mana_max, 50.0)
		verifier_egal(relue.prochaines_familles, familles)
		verifier_egal(relue.prochaines_armures, armures)


func test_vue_arene_refuse_plus_de_trois_familles_ou_des_armures_de_taille_differente() -> void:
	var d := _vue_pleine().to_dict()
	var quatre: Dictionary = d.duplicate(true)
	quatre["prochaines_familles"] = PackedInt32Array([1, 2, 3, 4])
	quatre["prochaines_armures"] = PackedByteArray([0, 1, 2, 3])
	verifier_nul(VueArene.from_dict(quatre), "quatre familles suivantes")
	var desaccord: Dictionary = d.duplicate(true)
	desaccord["prochaines_familles"] = PackedInt32Array([1, 2])
	desaccord["prochaines_armures"] = PackedByteArray([0, 1, 2])
	verifier_nul(VueArene.from_dict(desaccord), "deux familles pour trois armures")


func test_vue_arene_accepte_255_armes_et_les_evenements_absorption_et_arme() -> void:
	var d := _vue_pleine().to_dict()
	var armes: Array = []
	for i in 255:
		armes.append({"id": "arme_%d" % i, "recharge_ratio": 0.5, "niveau": 1})
	d["armes"] = armes
	d["evenements"] = [
		{
			"k": "absorption",
			"t": 4,
			"de": Vector2.ZERO,
			"vers": Vector2.ZERO,
			"type_degats": 0,
			"rayon": 0.0
		},
		{
			"k": "tir",
			"t": 5,
			"de": Vector2(1, 2),
			"vers": Vector2(30, 40),
			"type_degats": 1,
			"rayon": 0.0,
			"genre": 1,
			"statut": 0,
			"arme": 17,
		},
	]
	var relue := VueArene.from_dict(d)
	verifier_non_nul(relue, "255 armes, absorption et tir portant l'arme")
	if relue == null:
		return
	verifier_egal(relue.armes.size(), 255)
	verifier_egal(relue.evenements[1]["arme"], 17)
	verifier_egal(relue.to_dict(), d, "aller-retour exact")
	for arme_invalide: Variant in [-1, 1.5, "17"]:
		var mal: Dictionary = d.duplicate(true)
		var evenements: Array = mal["evenements"]
		var tir: Dictionary = evenements[1]
		tir["arme"] = arme_invalide
		verifier_nul(VueArene.from_dict(mal), "arme invalide %s" % str(arme_invalide))


func test_vue_globale_porte_dps_et_densites() -> void:
	var d := _globale(3).to_dict()
	var relue := VueGlobale.from_dict(d)
	verifier_non_nul(relue, "dps et densités se relisent")
	if relue == null:
		return
	verifier_egal(relue.to_dict(), d, "aller-retour exact")
	verifier_proche(float(relue.joueurs[2]["dps"]), 25.0)
	verifier_egal(relue.densites.size(), 2)
	var carte: PackedByteArray = relue.densites[1]
	verifier_egal(carte, _densite(200))
	for mauvaise_taille: int in [0, 255, 257]:
		var mal: Dictionary = d.duplicate(true)
		var densites: Dictionary = mal["densites"]
		var courte := _densite(1)
		courte.resize(mauvaise_taille)
		densites[0] = courte
		verifier_nul(VueGlobale.from_dict(mal), "densité de %d octets" % mauvaise_taille)
	for cle_invalide: Variant in ["0", 1.5]:
		var mal: Dictionary = d.duplicate(true)
		var densites: Dictionary = mal["densites"]
		densites[cle_invalide] = _densite(1)
		verifier_nul(VueGlobale.from_dict(mal), "identifiant %s" % str(cle_invalide))
	var pas_octets: Dictionary = d.duplicate(true)
	var densites_pas_octets: Dictionary = pas_octets["densites"]
	densites_pas_octets[0] = [1, 2, 3]
	verifier_nul(VueGlobale.from_dict(pas_octets), "densité qui n'est pas un tableau d'octets")


func test_un_joueur_sans_dps_se_relit_avec_un_dps_nul() -> void:
	var d := _globale(2).to_dict()
	for entree: Dictionary in d["joueurs"]:
		entree.erase("dps")
	var relue := VueGlobale.from_dict(d)
	verifier_non_nul(relue, "un état sans dps reste lisible")
	if relue == null:
		return
	for entree: Dictionary in relue.joueurs:
		verifier_proche(float(entree["dps"]), 0.0)
	var mal := _globale(2).to_dict()
	var joueur_mal: Dictionary = mal["joueurs"][0]
	joueur_mal["dps"] = 3
	verifier_nul(VueGlobale.from_dict(mal), "dps donné en entier")


func test_la_vue_globale_ne_partage_pas_ses_densites() -> void:
	var source := _globale(2).to_dict()
	var vue := VueGlobale.from_dict(source)
	var carte: PackedByteArray = vue.densites[0]
	carte[0] = 99
	vue.densites[0] = carte
	var relue_source: PackedByteArray = source["densites"][0]
	verifier_egal(relue_source[0], 7, "la source n'est pas modifiée par la vue")
	var sortie := vue.to_dict()
	var carte_sortie: PackedByteArray = sortie["densites"][1]
	carte_sortie[0] = 5
	var carte_vue: PackedByteArray = vue.densites[1]
	verifier_egal(carte_vue[0], 200, "modifier une sortie ne change pas la vue")


func test_la_source_factice_note_regarder_et_id_regarde() -> void:
	var source := SourceFactice.new()
	verifier_egal(source.id_regarde(), -1, "personne n'est regardé au départ")
	source.regarder(3)
	verifier_egal(source.id_regarde(), 3)
	source.regarder(-1)
	verifier_egal(source.id_regarde(), -1, "-1 cesse de regarder")
	verifier_egal(source.appels.size(), 2)
	verifier_egal(source.appels[0]["nom"], "regarder")
	verifier_egal(source.appels[0]["args"], [3])
	verifier_egal(source.appels[1]["args"], [-1])
	var recues: Array[int] = []
	source.vue_regardee_recue.connect(func(id: int, _vue: VueArene) -> void: recues.append(id))
	source.emettre_vue_regardee(4, VueArene.new())
	verifier_egal(recues, [4] as Array[int])
	source.free()
	var base := SourceVue.new()
	verifier_egal(base.id_regarde(), -1, "le stub de SourceVue ne regarde personne")
	base.regarder(2)
	verifier_egal(base.id_regarde(), -1, "le stub n'a aucun effet avant T8.10")
	base.free()
