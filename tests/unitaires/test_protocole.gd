extends CasDeTest
## Ce que le réseau doit garantir : chaque message fait l'aller-retour sans perte visible, et
## tout paquet venu d'un tiers (tronqué, trop long, de mauvaise version, aux compteurs
## mensongers, hors catalogue, non UTF-8…) est refusé proprement, sans exception.

const NOM_24 := "Ælfwyn Müller-Østerga日本語"
const GRAINE := 20261124

var _donnees: Donnees
var _catalogue: PackedStringArray


func avant_chaque() -> void:
	if _donnees == null:
		_donnees = Donnees.depuis_brut(_brut_catalogue())
		_catalogue = _donnees.ids_catalogue


# --- Aides -----------------------------------------------------------------------------------


func _brut_catalogue() -> Dictionary:
	var brut: Dictionary = {}
	for nom: String in [
		"partie.json", "economie.json", "difficulte.json", "efficacite.json", "boutique.json"
	]:
		brut[nom] = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + nom))
	var armes: Array = []
	var amelios: Array = []
	for i in 30:
		(
			armes
			. append(
				{
					"id": "arme_%02d" % i,
					"nom": "Arme numéro %d" % i,
					"description": "Une arme de test.",
					"rarete": "commune",
					"prix": 100 + i,
					"type_degats": "tranchant",
					"degats": 10.0,
					"recharge": 1.0,
					"portee": 750,
					"ciblage": "plus_proche",
					"effets": [{"kind": "cible_unique"}],
				}
			)
		)
	for i in 35:
		(
			amelios
			. append(
				{
					"id": "amelio_%02d" % i,
					"nom": "Amélioration %d" % i,
					"description": "Une amélioration de test.",
					"rarete": "commune",
					"prix": 100 + i,
					"categorie": "amelioration",
					"effets":
					[
						{
							"stat": "degats_type",
							"type_degats": "tranchant",
							"valeur": 0.1,
							"categorie": "A"
						}
					],
				}
			)
		)
	brut["armes.json"] = armes
	brut["ameliorations.json"] = amelios
	brut["ennemis.json"] = {
		"modeles":
		[
			{
				"id": "rampant",
				"noms": ["Rampant"],
				"armure": "légère",
				"classe_portee": "corps_a_corps",
				"pv": 40,
				"vitesse": 60,
				"degats": 4,
				"portee_attaque": 40,
				"cadence_attaque": 1.0,
				"prime": 2,
				"manche_min": 1,
				"explose": false,
				"raison_lenteur": "",
			},
		],
		"paliers": [{"id": "jaune", "manche_entree": 1, "pv": 1.0, "degats": 1.0, "prime": 1.0}],
		"convoi": {"id": "convoi", "nom": "Convoi", "pv": 400, "vitesse": 45, "prime": 120},
		"boss":
		{
			"id": "boss",
			"nom": "Boss",
			"pv": 20000,
			"vitesse": 35,
			"degats": 60,
			"portee_attaque": 80,
			"cadence_attaque": 1.5,
		},
	}
	return brut


## Vue d'arène réaliste : `nb_ennemis` ennemis dans le disque de rayon 1300, 8 armes, 4 offres,
## `nb_evt` événements, quelques améliorations. Graine fixe.
func _vue(nb_ennemis: int, nb_evt: int = 0) -> VueArene:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var v := VueArene.new()
	v.tick = 123456
	v.manche = 17
	v.phase = Types.Phase.MANCHE
	v.temps_restant = 12.5
	v.prochaine_famille = 5
	v.prochaine_armure = Types.Armure.LOURDE
	v.prochaines_familles = PackedInt32Array([5])
	v.prochaines_armures = PackedByteArray([Types.Armure.LOURDE])
	v.tour_mana = 12.5
	v.tour_mana_max = 50.0
	v.sans_fin = false
	v.tour_pv = 812.5
	v.tour_pv_max = 1000.0
	v.tour_armure = 4.75
	v.argent = 320
	v.revenu = 45
	v.revenu_dans = 6.25
	v.cout_relance = 25
	v.relances_gratuites = 1
	v.marche_noir_ouvert = true
	for i in 4:
		(
			v
			. offres
			. append(
				{
					"id": _catalogue[i * 7],
					"genre": i % 2,
					"rarete": i,
					"prix": 120 * (i + 1),
					"vendu": i == 1,
				}
			)
		)
	for i in 8:
		v.armes.append({"id": _catalogue[i * 3], "recharge_ratio": float(i) / 8.0})
	v.ameliorations = {_catalogue[40]: 2, _catalogue[50]: 255, _catalogue[7]: 1}
	for i in nb_ennemis:
		var angle := rng.randf() * TAU
		var rayon := sqrt(rng.randf()) * 1300.0
		v.ennemis_id.append(1000 + i)
		v.ennemis_pos.append(Vector2(cos(angle), sin(angle)) * rayon)
		v.ennemis_famille.append(i % 8)
		v.ennemis_pv.append(rng.randi() % 256)
		v.ennemis_statuts.append(i % 32)
	var genres: Array[String] = ["tir", "impact", "mort"]
	for i in nb_evt:
		(
			v
			. evenements
			. append(
				{
					"k": genres[i % 3],
					"t": v.tick,
					"de": Vector2(rng.randf_range(-1300, 1300), rng.randf_range(-1300, 1300)),
					"vers": Vector2(rng.randf_range(-1300, 1300), rng.randf_range(-1300, 1300)),
					"type_degats": i % 5,
					"rayon": float((i % 20) * 8),
				}
			)
		)
	v.eliminations = 42
	v.degats_infliges = 15234.5
	v.manche_max = 17
	return v


func _globale(nb: int) -> VueGlobale:
	var v := VueGlobale.new()
	v.temps_ecoule = 754.5
	v.en_cours = nb < 8
	v.termine = nb == 8
	for i in nb:
		(
			v
			. joueurs
			. append(
				{
					"id": 1 + i * 1_000_003,
					"nom": NOM_24,
					"manche": 3 + i,
					"eliminations": 2 * i,
					"degats": 150.5 + float(i),
					"dps": 12.5 * float(i),
					"revenu": 40 + i,
					"vivant": i % 2 == 0,
					"victorieux": i == 0 and nb == 8,
				}
			)
		)
	if v.termine:
		for i in nb:
			v.classement.append(1 + (nb - 1 - i) * 1_000_003)
	v.dernier_rempart = 1 if nb > 0 else -1
	return v


func _bonjour_version(version: int) -> PackedByteArray:
	var b := Protocole.encoder_bonjour("Phil", 42)
	b[1] = version
	return b


## Toutes les troncatures strictes d'un message valide.
func _troncatures(b: PackedByteArray) -> Array[PackedByteArray]:
	var liste: Array[PackedByteArray] = []
	for n in b.size():
		liste.append(b.slice(0, n))
	return liste


func _avec_octet_en_plus(b: PackedByteArray) -> PackedByteArray:
	var c := b.duplicate()
	c.append(0)
	return c


func _arene(b: PackedByteArray) -> VueArene:
	return Protocole.decoder_etat_arene(b, _catalogue)


func _aller_retour(v: VueArene) -> VueArene:
	return _arene(Protocole.encoder_etat_arene(v, _catalogue))


func _bonjour_avec_nom(nom: PackedByteArray) -> PackedByteArray:
	var b := PackedByteArray([Protocole.Msg.BONJOUR, Protocole.VERSION, nom.size()])
	b.append_array(nom)
	b.resize(b.size() + 8)
	b.append(0)
	return b


## Écart maximal sur un axe entre deux positions.
func _ecart(a: Vector2, b: Vector2) -> float:
	return maxf(absf(a.x - b.x), absf(a.y - b.y))


## Position de l'octet de compteur d'une zone dans un état d'arène (disposition de la spec §4).
func _compteur(v: VueArene, zone: String) -> int:
	var o := Protocole.OFFSET_NB_FAMILLES + 1 + 2 * v.prochaines_familles.size()
	if zone == "offres":
		return o
	o += 1 + 5 * v.offres.size()
	if zone == "armes":
		return o
	o += 1 + 3 * v.armes.size()
	if zone == "amelios":
		return o
	o += 2 + 3 * v.ameliorations.size()
	if zone == "ennemis":
		return o
	o += 2 + 9 * v.ennemis_id.size()
	return o  # evenements


# --- Bonjour ---------------------------------------------------------------------------------


func test_bonjour_aller_retour_avec_nom_unicode_de_24_caracteres() -> void:
	verifier_egal(NOM_24.length(), 24)
	var d := Protocole.decoder_bonjour(Protocole.encoder_bonjour(NOM_24, -123456789012345))
	verifier_egal(d.get("version"), Protocole.VERSION)
	verifier_egal(d.get("nom"), NOM_24)
	verifier_egal(d.get("empreinte"), -123456789012345)


func test_bonjour_nom_vide_accepte_pour_que_le_salon_en_donne_un() -> void:
	var d := Protocole.decoder_bonjour(Protocole.encoder_bonjour("", 7))
	verifier_egal(d.get("nom"), "")


func test_bonjour_nom_de_1000_caracteres_est_tronque_par_l_emetteur() -> void:
	var b := Protocole.encoder_bonjour("é".repeat(1000), 1)
	verifier(b.size() < 200, "le paquet ne grossit pas avec le nom")
	verifier_egal(Protocole.decoder_bonjour(b).get("nom"), "é".repeat(24))


func test_bonjour_dont_le_nom_depasse_24_caracteres_est_refuse() -> void:
	# Un client malveillant n'est pas obligé de tronquer : on fabrique le paquet à la main.
	var b := _bonjour_avec_nom("a".repeat(25).to_utf8_buffer())
	verifier_egal(Protocole.decoder_bonjour(b), {})
	b = _bonjour_avec_nom("a".repeat(24).to_utf8_buffer())
	verifier_egal(Protocole.decoder_bonjour(b).get("nom"), "a".repeat(24))
	b = _bonjour_avec_nom("é".repeat(1000).to_utf8_buffer().slice(0, 200))
	verifier_egal(Protocole.decoder_bonjour(b), {}, "longueur d'octets très grande")


func test_bonjour_nom_non_utf8_ou_a_caracteres_de_controle_est_refuse() -> void:
	for octets: Array in [[0xFF, 0xFE], [0xC3], [0xE6, 0x97], [65, 0, 66], [65, 10, 66]]:
		var b := _bonjour_avec_nom(PackedByteArray(octets))
		verifier_egal(Protocole.decoder_bonjour(b), {}, "octets %s" % [octets])


func test_bonjour_mal_forme_est_refuse() -> void:
	var valide := Protocole.encoder_bonjour(NOM_24, 99)
	verifier_egal(Protocole.decoder_bonjour(PackedByteArray()), {})
	for b in _troncatures(valide):
		verifier_egal(Protocole.decoder_bonjour(b), {}, "taille %d" % b.size())
	verifier_egal(Protocole.decoder_bonjour(_avec_octet_en_plus(valide)), {}, "octet en trop")
	var autre := valide.duplicate()
	autre[0] = Protocole.Msg.INTENTION
	verifier_egal(Protocole.decoder_bonjour(autre), {}, "mauvais type")
	autre[0] = 200
	verifier_egal(Protocole.decoder_bonjour(autre), {}, "type inconnu")


func test_bonjour_de_version_differente_est_refuse_avec_un_motif_clair() -> void:
	for v: int in [0, Protocole.VERSION - 1, Protocole.VERSION + 1, 255]:
		var b := _bonjour_version(v)
		verifier_egal(Protocole.decoder_bonjour(b), {}, "version %d" % v)
		verifier_egal(Protocole.version_bonjour(b), v)
		var motif := Protocole.decoder_refus(Protocole.encoder_refus(Protocole.motif_version(v)))
		verifier(motif.contains(str(v)) and motif.contains(str(Protocole.VERSION)), motif)
	verifier_egal(Protocole.version_bonjour(PackedByteArray([1])), -1)
	verifier_egal(Protocole.version_bonjour(Protocole.encoder_intention(1, 0)), -1)


# --- Intention et refus ----------------------------------------------------------------------


func test_intention_aller_retour_pour_chaque_genre() -> void:
	for genre in range(Protocole.Intention.ACHETER, Protocole.Intention.OPTIONS + 1):
		for arg: int in [0, 3, -1, 2147483647, -2147483648]:
			var d := Protocole.decoder_intention(Protocole.encoder_intention(genre, arg, "id_é"))
			verifier_egal(d.get("genre"), genre)
			verifier_egal(d.get("arg"), arg)
			verifier_egal(d.get("texte"), "id_é")


func test_intention_sans_texte_a_un_texte_vide() -> void:
	verifier_egal(Protocole.decoder_intention(Protocole.encoder_intention(2, 0)).get("texte"), "")


func test_intention_de_genre_inconnu_ou_mal_formee_est_refusee() -> void:
	var valide := Protocole.encoder_intention(Protocole.Intention.MARCHE_NOIR, 5, "lame")
	for b in _troncatures(valide):
		verifier_egal(Protocole.decoder_intention(b), {}, "taille %d" % b.size())
	verifier_egal(Protocole.decoder_intention(_avec_octet_en_plus(valide)), {})
	for genre: int in [0, Protocole.Intention.REGARDER + 1, 255]:
		var b := valide.duplicate()
		b[1] = genre
		verifier_egal(Protocole.decoder_intention(b), {}, "genre %d" % genre)
	var mauvais_type := valide.duplicate()
	mauvais_type[0] = Protocole.Msg.BONJOUR
	verifier_egal(Protocole.decoder_intention(mauvais_type), {})
	verifier_egal(Protocole.encoder_intention(0, 0).size(), 0, "genre inconnu refusé à l'envoi")


func test_intention_au_texte_non_utf8_ou_trop_long_est_refusee() -> void:
	var b := PackedByteArray([Protocole.Msg.INTENTION, 1, 0, 0, 0, 0, 2, 0xFF, 0xFE])
	verifier_egal(Protocole.decoder_intention(b), {})
	var long := "x".repeat(Protocole.MAX_TEXTE_OCTETS + 1).to_utf8_buffer()
	b = PackedByteArray([Protocole.Msg.INTENTION, 1, 0, 0, 0, 0, long.size()])
	b.append_array(long)
	verifier_egal(Protocole.decoder_intention(b), {})
	verifier_egal(Protocole.encoder_intention(1, 0, "x".repeat(1000)).size(), 0, "refus à l'envoi")


func test_refus_aller_retour_et_decodage_defensif() -> void:
	var motif := "Version du protocole différente : « 2 » au lieu de 1."
	verifier_egal(Protocole.decoder_refus(Protocole.encoder_refus(motif)), motif)
	var valide := Protocole.encoder_refus(motif)
	for b in _troncatures(valide):
		verifier_egal(Protocole.decoder_refus(b), "", "taille %d" % b.size())
	verifier_egal(Protocole.decoder_refus(_avec_octet_en_plus(valide)), "")
	var non_utf8 := PackedByteArray([Protocole.Msg.REFUS, 2, 0xFF, 0xFE])
	verifier_egal(Protocole.decoder_refus(non_utf8), "")
	var long := Protocole.decoder_refus(Protocole.encoder_refus("é".repeat(5000)))
	verifier(long.length() > 0 and long.to_utf8_buffer().size() <= Protocole.MAX_MOTIF_OCTETS)


func test_type_de_reconnait_chaque_message_et_refuse_le_reste() -> void:
	verifier_egal(Protocole.type_de(Protocole.encoder_bonjour("a", 1)), Protocole.Msg.BONJOUR)
	verifier_egal(Protocole.type_de(Protocole.encoder_intention(1, 0)), Protocole.Msg.INTENTION)
	verifier_egal(Protocole.type_de(Protocole.encoder_refus("x")), Protocole.Msg.REFUS)
	var global := Protocole.encoder_etat_global(_globale(1))
	verifier_egal(Protocole.type_de(global), Protocole.Msg.ETAT_GLOBAL)
	var arene := Protocole.encoder_etat_arene(_vue(0), _catalogue)
	verifier_egal(Protocole.type_de(arene), Protocole.Msg.ETAT_ARENE)
	verifier_egal(Protocole.type_de(PackedByteArray()), -1)
	verifier_egal(Protocole.type_de(PackedByteArray([0])), -1)
	verifier_egal(Protocole.type_de(PackedByteArray([Protocole.Msg.ETAT_ARENE_REGARDEE + 1])), -1)
	verifier_egal(Protocole.type_de(Protocole.encoder_resultat(1, 0)), Protocole.Msg.RESULTAT)
	var gros := PackedByteArray()
	gros.resize(Protocole.MAX_TAILLE + 1)
	gros[0] = Protocole.Msg.BONJOUR
	verifier_egal(Protocole.type_de(gros), -1)


# --- État global -----------------------------------------------------------------------------


func test_etat_global_aller_retour_de_0_a_8_joueurs() -> void:
	for nb in 9:
		var v := _globale(nb)
		var d := Protocole.decoder_etat_global(Protocole.encoder_etat_global(v))
		verifier_non_nul(d, "%d joueurs" % nb)
		if d == null:
			continue
		verifier_egal(d.joueurs.size(), nb)
		for i in nb:
			var a: Dictionary = v.joueurs[i]
			var r: Dictionary = d.joueurs[i]
			for cle: String in ["id", "nom", "manche", "eliminations", "revenu"]:
				verifier_egal(r[cle], a[cle], "joueur %d.%s" % [i, cle])
			verifier_egal(r["vivant"], a["vivant"])
			verifier_egal(r["victorieux"], a["victorieux"])
			verifier_proche(float(r["degats"]), float(a["degats"]), 0.01)
		verifier_proche(d.temps_ecoule, v.temps_ecoule, 0.0001)
		verifier_egal(d.en_cours, v.en_cours)
		verifier_egal(d.termine, v.termine)
		verifier_egal(d.classement, v.classement)
		verifier_egal(d.dernier_rempart, v.dernier_rempart)


func test_etat_global_mal_forme_est_refuse() -> void:
	var valide := Protocole.encoder_etat_global(_globale(8))
	for b in _troncatures(valide):
		verifier_nul(Protocole.decoder_etat_global(b), "taille %d" % b.size())
	verifier_nul(Protocole.decoder_etat_global(_avec_octet_en_plus(valide)))
	var autre := valide.duplicate()
	autre[0] = Protocole.Msg.ETAT_ARENE
	verifier_nul(Protocole.decoder_etat_global(autre))


func test_etat_global_aux_compteurs_mensongers_est_refuse() -> void:
	for n: int in [1, 2, Protocole.MAX_JOUEURS + 1, 255]:
		var b := Protocole.encoder_etat_global(_globale(0))
		b[Protocole.OFFSET_NB_JOUEURS] = n
		verifier_nul(Protocole.decoder_etat_global(b), "joueurs=%d" % n)
	var plein := Protocole.encoder_etat_global(_globale(8))
	var fin := plein.size()
	# Le compteur du classement est le premier octet après le dernier joueur ; l'octet final est
	# le compteur de cartes de densité (0 ici).
	var o := fin - 1 - 1 - 8 * 4
	for n: int in [9, 255]:
		var b := plein.duplicate()
		b[o] = n
		verifier_nul(Protocole.decoder_etat_global(b), "classement=%d" % n)


func test_etat_global_a_trop_de_joueurs_refuse_a_l_envoi_et_nom_long_tronque() -> void:
	var v := _globale(Protocole.MAX_JOUEURS + 1)
	verifier_egal(Protocole.encoder_etat_global(v).size(), 0)
	var long := _globale(2)
	long.joueurs[0]["nom"] = "é".repeat(1000)
	var d := Protocole.decoder_etat_global(Protocole.encoder_etat_global(long))
	verifier_non_nul(d)
	if d != null:
		verifier_egal(String(d.joueurs[0]["nom"]), "é".repeat(24))


# --- État d'arène : aller-retour -------------------------------------------------------------


func test_etat_arene_aller_retour_complet() -> void:
	var v := _vue(300, 12)
	var d := _aller_retour(v)
	verifier_non_nul(d)
	if d == null:
		return
	verifier_egal(d.tick, v.tick)
	verifier_egal(d.manche, v.manche)
	verifier_egal(d.phase, v.phase)
	verifier_proche(d.temps_restant, v.temps_restant, 0.05)
	verifier_egal(d.prochaine_famille, v.prochaine_famille)
	verifier_egal(d.prochaine_armure, v.prochaine_armure)
	verifier_egal(d.sans_fin, v.sans_fin)
	verifier_egal(d.marche_noir_ouvert, v.marche_noir_ouvert)
	verifier_proche(d.tour_pv, v.tour_pv, 0.001)
	verifier_proche(d.tour_pv_max, v.tour_pv_max, 0.001)
	verifier_proche(d.tour_armure, v.tour_armure, 0.001)
	verifier_egal(d.argent, v.argent)
	verifier_egal(d.revenu, v.revenu)
	verifier_proche(d.revenu_dans, v.revenu_dans, 0.05)
	verifier_egal(d.cout_relance, v.cout_relance)
	verifier_egal(d.relances_gratuites, v.relances_gratuites)
	verifier_egal(d.offres, v.offres)
	verifier_egal(d.armes.size(), 8)
	for i in 8:
		verifier_egal(d.armes[i]["id"], v.armes[i]["id"])
		var ecart := absf(float(d.armes[i]["recharge_ratio"]) - float(v.armes[i]["recharge_ratio"]))
		verifier(ecart <= 1.0 / 510.0 + 1e-6, "recharge %d" % i)
	verifier_egal(d.ameliorations, v.ameliorations)
	verifier_egal(d.ennemis_id, v.ennemis_id)
	verifier_egal(d.ennemis_famille, v.ennemis_famille)
	verifier_egal(d.ennemis_pv, v.ennemis_pv)
	verifier_egal(d.ennemis_statuts, v.ennemis_statuts)
	for i in 300:
		verifier(_ecart(d.ennemis_pos[i], v.ennemis_pos[i]) <= Protocole.ERREUR_POS_MAX + 1e-9)
	verifier_egal(d.evenements.size(), 12)
	for i in 12:
		var a: Dictionary = v.evenements[i]
		var r: Dictionary = d.evenements[i]
		verifier_egal(r["k"], a["k"])
		verifier_egal(r["type_degats"], a["type_degats"])
		verifier_egal(r["t"], v.tick, "le tick de l'événement est celui du message")
		verifier_proche(float(r["rayon"]), float(a["rayon"]), 0.0)
		verifier(_ecart(r["de"], a["de"]) <= Protocole.ERREUR_POS_MAX + 1e-9)
		verifier(_ecart(r["vers"], a["vers"]) <= Protocole.ERREUR_POS_MAX + 1e-9)
	verifier_egal(d.eliminations, v.eliminations)
	verifier_proche(d.degats_infliges, v.degats_infliges, 0.01)
	verifier_egal(d.manche_max, v.manche_max)


func test_etat_arene_chaque_phase_chaque_rarete_chaque_genre() -> void:
	for phase in range(Types.Phase.PREPARATION, Types.Phase.DEFAITE + 1):
		for rarete in range(Types.Rarete.COMMUNE, Types.Rarete.EPIQUE + 1):
			for genre in range(Types.Genre.ARME, Types.Genre.AMELIORATION + 1):
				for vendu: bool in [false, true]:
					var v := _vue(1)
					v.phase = phase
					v.offres = [
						{
							"id": _catalogue[3],
							"genre": genre,
							"rarete": rarete,
							"prix": 65535,
							"vendu": vendu
						}
					]
					var d := _aller_retour(v)
					verifier_non_nul(d)
					if d != null:
						verifier_egal(d.phase, phase)
						verifier_egal(d.offres, v.offres)


func test_etat_arene_sans_ennemi_ni_arme_ni_offre() -> void:
	var d := _aller_retour(VueArene.new())
	verifier_non_nul(d)
	if d != null:
		verifier_egal(d.ennemis_id.size(), 0)
		verifier_egal(d.offres.size(), 0)
		verifier_egal(d.armes.size(), 0)
		verifier_egal(d.prochaine_famille, -1)


func test_etat_arene_borne_a_2000_ennemis() -> void:
	var plein := Protocole.encoder_etat_arene(_vue(Protocole.MAX_ENNEMIS), _catalogue)
	verifier(plein.size() > 0 and plein.size() <= Protocole.MAX_TAILLE, "2000 ennemis tiennent")
	var d := _arene(plein)
	verifier_non_nul(d)
	if d != null:
		verifier_egal(d.ennemis_id.size(), Protocole.MAX_ENNEMIS)
	var trop := Protocole.encoder_etat_arene(_vue(Protocole.MAX_ENNEMIS + 1), _catalogue)
	verifier_egal(trop.size(), 0, "2001 ennemis refusés à l'encodage")


func test_etat_arene_ne_garde_que_les_64_premiers_evenements() -> void:
	var d := _aller_retour(_vue(0, 100))
	verifier_non_nul(d)
	if d != null:
		verifier_egal(d.evenements.size(), Protocole.MAX_EVENEMENTS)


func test_etat_arene_refuse_a_l_envoi_ce_que_le_catalogue_ne_connait_pas() -> void:
	var v := _vue(1)
	v.offres[0]["id"] = "inconnue"
	verifier_egal(Protocole.encoder_etat_arene(v, _catalogue).size(), 0, "offre")
	v = _vue(1)
	v.armes[0]["id"] = "inconnue"
	verifier_egal(Protocole.encoder_etat_arene(v, _catalogue).size(), 0, "arme")
	v = _vue(1)
	v.ameliorations["inconnue"] = 1
	verifier_egal(Protocole.encoder_etat_arene(v, _catalogue).size(), 0, "amélioration")
	v = _vue(1)
	v.ennemis_pv.resize(0)
	verifier_egal(Protocole.encoder_etat_arene(v, _catalogue).size(), 0, "tableaux incohérents")


func test_taille_d_un_etat_arene_suit_la_formule() -> void:
	for nb: int in [0, 1, 300, 1000]:
		var v := _vue(nb, 5)
		var attendu := (
			Protocole.TAILLE_FIXE
			+ 5 * v.offres.size()
			+ 2 * v.prochaines_familles.size()
			+ 3 * v.armes.size()
			+ 3 * v.ameliorations.size()
			+ 9 * nb
			+ 14 * 5
		)
		verifier_egal(Protocole.encoder_etat_arene(v, _catalogue).size(), attendu, "%d" % nb)


# --- Quantification --------------------------------------------------------------------------


func test_position_quantifiee_a_un_trente_deuxieme_pres_jusqu_au_bord_de_l_arene() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var v := VueArene.new()
	var bornes: Array[float] = [0.0, 1300.0, -1300.0, 1400.0, -1400.0, 1500.0, -1500.0, 1300.03125]
	for x in bornes:
		for y in bornes:
			v.ennemis_pos.append(Vector2(x, y))
	while v.ennemis_pos.size() < 1000:
		v.ennemis_pos.append(Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500)))
	for i in v.ennemis_pos.size():
		v.ennemis_id.append(i)
		v.ennemis_famille.append(0)
		v.ennemis_pv.append(255)
		v.ennemis_statuts.append(0)
	var d := _aller_retour(v)
	verifier_non_nul(d)
	if d == null:
		return
	var pire := 0.0
	for i in v.ennemis_pos.size():
		pire = maxf(pire, _ecart(d.ennemis_pos[i], v.ennemis_pos[i]))
	verifier(pire <= 1.0 / 32.0 + 1e-9, "erreur max %f" % pire)
	verifier_egal(Protocole.ERREUR_POS_MAX, 1.0 / 32.0)


func test_position_hors_de_portee_est_ramenee_au_bord_sans_planter() -> void:
	var v := _vue(1)
	v.ennemis_pos = PackedVector2Array([Vector2(1.0e9, -1.0e9)])
	var d := _aller_retour(v)
	verifier_non_nul(d)
	if d != null:
		verifier_egal(d.ennemis_pos[0], Vector2(Protocole.POS_MAX, -Protocole.POS_MAX))
	verifier(Protocole.POS_MAX > 1500.0, "le bord de l'arène (1300) est couvert avec marge")


# --- Débit -----------------------------------------------------------------------------------


func test_debit_a_300_ennemis_reste_sous_50_ko_par_seconde_a_15_hz() -> void:
	# Cas réaliste : environ un tir ou impact par arme et par état, soit une vingtaine.
	var realiste := Protocole.encoder_etat_arene(_vue(300, 24), _catalogue).size()
	verifier(realiste * 15 < 50000, "300 ennemis, 24 événements : %d o/s" % [realiste * 15])
	var lignes: PackedStringArray = []
	for nb: int in [300, 1000]:
		for nb_evt: int in [0, 24, 64]:
			var taille := Protocole.encoder_etat_arene(_vue(nb, nb_evt), _catalogue).size()
			lignes.append("%d ennemis, %d evt : %d o -> %d o/s" % [nb, nb_evt, taille, taille * 15])
	print("DEBIT ", " | ".join(lignes))


# --- Décodage défensif de l'état d'arène -----------------------------------------------------


func test_etat_arene_tronque_a_chaque_longueur_est_refuse() -> void:
	var valide := Protocole.encoder_etat_arene(_vue(20, 3), _catalogue)
	verifier_non_nul(_arene(valide))
	for b in _troncatures(valide):
		verifier_nul(_arene(b), "taille %d" % b.size())


func test_etat_arene_avec_octets_en_trop_ou_trop_long_est_refuse() -> void:
	var valide := Protocole.encoder_etat_arene(_vue(20, 3), _catalogue)
	verifier_nul(_arene(_avec_octet_en_plus(valide)))
	var gros := valide.duplicate()
	gros.resize(Protocole.MAX_TAILLE + 1)
	verifier_nul(_arene(gros), "plus grand que MAX_TAILLE")
	verifier_nul(_arene(PackedByteArray()))


func test_etat_arene_de_type_inconnu_ou_d_un_autre_message_est_refuse() -> void:
	var valide := Protocole.encoder_etat_arene(_vue(5), _catalogue)
	for t: int in [
		0,
		Protocole.Msg.BONJOUR,
		Protocole.Msg.ETAT_GLOBAL,
		Protocole.Msg.SALON,
		Protocole.Msg.RESULTAT,
		8,
		255
	]:
		var b := valide.duplicate()
		b[0] = t
		verifier_nul(_arene(b), "type %d" % t)


func test_etat_arene_a_phase_ou_armure_ou_famille_hors_bornes_est_refuse() -> void:
	var valide := Protocole.encoder_etat_arene(_vue(5), _catalogue)
	var b := valide.duplicate()
	b[Protocole.OFFSET_PHASE] = Types.Phase.DEFAITE + 1
	verifier_nul(_arene(b), "phase")
	b = valide.duplicate()
	b[Protocole.OFFSET_ARMURE] = Types.Armure.BOSS + 1
	verifier_nul(_arene(b), "armure")
	b = valide.duplicate()
	b[Protocole.OFFSET_FAMILLE] = Protocole.MAX_FAMILLE + 1
	verifier_nul(_arene(b), "famille")


func test_etat_arene_a_flottant_non_fini_est_refuse() -> void:
	for decalage: int in [0, 4, 8]:
		for valeur: float in [NAN, INF, -INF]:
			var b := Protocole.encoder_etat_arene(_vue(5), _catalogue)
			b.encode_float(Protocole.OFFSET_TOUR_PV + decalage, valeur)
			verifier_nul(_arene(b), "décalage %d" % decalage)
	var b := Protocole.encoder_etat_arene(_vue(5), _catalogue)
	b.encode_float(b.size() - 6, NAN)  # degats_infliges
	verifier_nul(_arene(b), "degats_infliges")


func test_etat_arene_a_indice_de_catalogue_hors_bornes_est_refuse() -> void:
	var v := _vue(2)
	var valide := Protocole.encoder_etat_arene(v, _catalogue)
	verifier_non_nul(_arene(valide))
	var n := _catalogue.size()
	for zone: String in ["offres", "armes", "amelios"]:
		for mauvais: int in [n, n + 1, 65535]:
			var b := valide.duplicate()
			b.encode_u16(_compteur(v, zone) + (1 if zone == "armes" else 2), mauvais)
			verifier_nul(_arene(b), "%s %d" % [zone, mauvais])
	# Un catalogue plus petit que celui de l'émetteur : refus, pas d'exception.
	verifier_nul(Protocole.decoder_etat_arene(valide, PackedStringArray(["a"])))
	verifier_nul(Protocole.decoder_etat_arene(valide, PackedStringArray()))


func test_etat_arene_aux_compteurs_mensongers_est_refuse_sans_allouer() -> void:
	var v := _vue(5, 2)
	var valide := Protocole.encoder_etat_arene(v, _catalogue)
	for zone: String in ["offres", "armes", "amelios", "ennemis", "evenements"]:
		var o := _compteur(v, zone)
		var large := zone == "amelios" or zone == "ennemis"
		var mensonges: Array[int] = [255, 200, 100]
		if large:
			mensonges = [Protocole.MAX_ENNEMIS + 1, 65535, 40000]
		for n in mensonges:
			var b := valide.duplicate()
			if large:
				b.encode_u16(o, n)
			else:
				b[o] = n
			verifier_nul(_arene(b), "%s=%d" % [zone, n])
	# Un compteur trop petit laisse des octets en trop.
	var b := valide.duplicate()
	b.encode_u16(_compteur(v, "ennemis"), 4)
	verifier_nul(_arene(b))


func test_etat_arene_a_ameliorations_dupliquees_est_refuse() -> void:
	var v := _vue(0)
	v.ameliorations = {_catalogue[40]: 1, _catalogue[41]: 1}
	var b := Protocole.encoder_etat_arene(v, _catalogue)
	var o := _compteur(v, "amelios") + 2
	b.encode_u16(o + 3, b.decode_u16(o))
	verifier_nul(_arene(b))


func test_65536_octets_de_bruit_sont_refuses_pour_chaque_decodeur() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var bruit := PackedByteArray()
	bruit.resize(65536)
	for i in bruit.size():
		bruit[i] = rng.randi() % 256
	for t in range(Protocole.Msg.BONJOUR, Protocole.Msg.ETAT_ARENE_REGARDEE + 1):
		bruit[0] = t
		verifier_nul(_arene(bruit), "arène, type %d" % t)
		verifier_nul(Protocole.decoder_etat_global(bruit))
		verifier_egal(Protocole.decoder_bonjour(bruit), {})
		verifier_egal(Protocole.decoder_intention(bruit), {})
		verifier_egal(Protocole.decoder_refus(bruit), "")
		verifier_egal(Protocole.decoder_etat_arene_regardee(bruit, _catalogue), {})
	var plus_un := bruit.duplicate()
	plus_un.append(0)
	verifier_nul(_arene(plus_un))


# --- Fuzz à graine fixe ----------------------------------------------------------------------


func _muter(rng: RandomNumberGenerator, source: PackedByteArray) -> PackedByteArray:
	var b := source.duplicate()
	match rng.randi() % 6:
		0:  # bruit pur, longueur aléatoire, type valide
			b.resize(rng.randi() % 400)
			for i in b.size():
				b[i] = rng.randi() % 256
			if b.size() > 0:
				b[0] = 1 + rng.randi() % 6
		1:  # octets remplacés
			for k in 1 + rng.randi() % 4:
				if b.size() > 0:
					b[rng.randi() % b.size()] = rng.randi() % 256
		2:  # troncature
			if b.size() > 0:
				b.resize(rng.randi() % b.size())
		3:  # queue ajoutée
			for k in 1 + rng.randi() % 8:
				b.append(rng.randi() % 256)
		4:  # octet mis à 0xFF (compteurs, flottants, indices)
			if b.size() > 0:
				b[rng.randi() % b.size()] = 0xFF
		_:  # insertion au milieu
			if b.size() > 1:
				b.insert(rng.randi() % b.size(), rng.randi() % 256)
	return b


func test_fuzz_10000_paquets_sans_plantage_ni_erreur_journalisee() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var sources: Array[PackedByteArray] = [
		Protocole.encoder_bonjour(NOM_24, 5),
		Protocole.encoder_intention(Protocole.Intention.MARCHE_NOIR, 3, "amelio_03"),
		Protocole.encoder_refus("Refusé : motif"),
		Protocole.encoder_etat_global(_globale(8)),
		Protocole.encoder_etat_global(_globale(0)),
		Protocole.encoder_etat_arene(_vue(0), _catalogue),
		Protocole.encoder_etat_arene(_vue(3, 2), _catalogue),
		Protocole.encoder_etat_arene(_vue(40, 6), _catalogue),
	]
	var acceptes := 0
	for i in 10000:
		var b := _muter(rng, sources[rng.randi() % sources.size()])
		var arene := _arene(b)
		var global := Protocole.decoder_etat_global(b)
		var bonjour := Protocole.decoder_bonjour(b)
		var intention := Protocole.decoder_intention(b)
		var motif := Protocole.decoder_refus(b)
		Protocole.type_de(b)
		Protocole.version_bonjour(b)
		if arene != null:
			acceptes += 1
			# Ce qu'on accepte se réémet à l'identique : le décodeur ne laisse rien passer
			# que l'encodeur refuserait.
			var re := Protocole.encoder_etat_arene(arene, _catalogue)
			verifier(re.size() > 0, "paquet %d accepté mais non réémissible" % i)
			var arene2 := _arene(re)
			verifier_non_nul(arene2)
			if arene2 != null:
				verifier_egal(arene2.to_dict(), arene.to_dict(), "paquet %d" % i)
		if global != null:
			acceptes += 1
			verifier(Protocole.encoder_etat_global(global).size() > 0)
		if not bonjour.is_empty():
			acceptes += 1
		if not intention.is_empty():
			acceptes += 1
		if not motif.is_empty():
			acceptes += 1
	verifier(acceptes > 100, "le fuzz atteint des paquets valides (%d acceptés)" % acceptes)
	verifier(acceptes < 20000, "le fuzz ne rend pas tout valide")


func test_lecteur_public_refuse_toute_lecture_hors_des_octets_disponibles() -> void:
	var l := Protocole.LecteurOctets.new(PackedByteArray([1, 2, 3]))
	verifier_egal(l.u16(), 0x0201, "deux octets lus en petit-boutiste")
	verifier(l.ok, "lecture dans les bornes")
	verifier_egal(l.u32(), 0, "quatre octets demandés, un seul disponible")
	verifier(not l.ok, "une lecture hors bornes invalide le lecteur")
	verifier_egal(l.reste(), 1, "le curseur n'a pas avancé sur la lecture refusée")
