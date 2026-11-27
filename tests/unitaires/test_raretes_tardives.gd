extends CasDeTest
## Raretés de fin de partie (T12.6, §6.17.2) : « ancestrale » dès la manche 14, « souveraine » dès
## la manche 22, jamais au marché noir ; chaque rareté a sa couleur, son symbole et son libellé.

const NOMS: Array[String] = ["commune", "peu_commune", "rare", "epique", "ancestrale", "souveraine"]
const MANCHE_ANCESTRALE := 14
const MANCHE_SOUVERAINE := 22
const MANCHE_MAX := 40
const NB_GRAINES := 200
## Poids de départ des quatre raretés d'avant : la partie jusqu'à la manche 20 ne bouge pas.
const POIDS_ANCIENS: Dictionary = {
	1: [30.0, 55.0, 15.0, 0.0],
	6: [55.0, 30.0, 12.0, 3.0],
	12: [40.0, 32.0, 20.0, 8.0],
	20: [28.0, 32.0, 26.0, 14.0],
	28: [20.0, 30.0, 30.0, 20.0],
}

var _reel: Donnees
var _fin: Donnees


func avant_chaque() -> void:
	_reel = Donnees.charger()
	_fin = _donnees_avec_objets_tardifs()


## Données réelles, plus une arme et une amélioration de chaque rareté tardive (copies d'objets
## existants) : le catalogue de fin de partie n'existe pas encore, les tirages se testent ainsi.
func _donnees_avec_objets_tardifs() -> Donnees:
	var brut := AidesPartie.brut()
	var armes: Array = brut["armes.json"]
	var ameliorations: Array = brut["ameliorations.json"]
	for nom: String in ["ancestrale", "souveraine"]:
		var arme: Dictionary = (armes[0] as Dictionary).duplicate(true)
		arme["id"] = "arme_test_" + nom
		arme["nom"] = "Arme test " + nom
		arme["rarete"] = nom
		arme["prix"] = 3000 if nom == "ancestrale" else 8000
		armes.append(arme)
		var amelio: Dictionary = (ameliorations[0] as Dictionary).duplicate(true)
		amelio["id"] = "amelio_test_" + nom
		amelio["nom"] = "Amélio test " + nom
		amelio["rarete"] = nom
		amelio["prix"] = 3000 if nom == "ancestrale" else 8000
		ameliorations.append(amelio)
	var d := Donnees.depuis_brut(brut)
	verifier_non_nul(d, "les données de test doivent être valides")
	return d


func _rng(graine: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	return rng


func test_il_y_a_six_raretes_dont_ancestrale_et_souveraine() -> void:
	verifier_egal(Types.NOMS_RARETES, NOMS, "noms des raretés, dans l'ordre")
	verifier_egal(Types.Rarete.size(), 6, "six raretés")
	verifier_egal(Types.Rarete.ANCESTRALE, 4, "ancestrale suit l'épique")
	verifier_egal(Types.Rarete.SOUVERAINE, 5, "souveraine est la dernière")
	for i: int in NOMS.size():
		verifier_egal(Types.rarete_depuis_nom(NOMS[i]), i, "%s : index" % NOMS[i])


func test_chaque_rarete_a_une_couleur_un_symbole_et_un_libelle_distincts_et_traduits() -> void:
	var textes := CsvTextes.lire("res://i18n/textes_communs.csv")
	var vus: Dictionary = {}
	for r: int in Types.Rarete.values():
		var cle := Apparence.cle_libelle_rarete(r)
		verifier(textes.has(cle), "rareté %d : clé %s dans le csv" % [r, cle])
		var empreinte := (
			"%s|%s|%s"
			% [
				Apparence.couleur_rarete(r).to_html(),
				Apparence.symbole_rarete(r),
				textes.get(cle, "")
			]
		)
		for autre: String in vus:
			var morceaux := autre.split("|")
			var mien := empreinte.split("|")
			for i: int in 3:
				verifier(morceaux[i] != mien[i], "rareté %d : champ %d distinct" % [r, i])
		vus[empreinte] = true
		verifier(Apparence.symbole_rarete(r) != "?", "rareté %d : symbole connu" % r)


func test_les_poids_des_raretes_tardives_suivent_la_conception() -> void:
	var table: Array = _reel.boutique["poids"]
	for manche: int in range(1, MANCHE_MAX + 1):
		var anc := _reel.palier(table, manche, "ancestrale")
		var sou := _reel.palier(table, manche, "souveraine")
		var anc_attendu := 0.0
		if manche >= 28:
			anc_attendu = 10.0
		elif manche >= MANCHE_ANCESTRALE:
			anc_attendu = 4.0
		var sou_attendu := 0.0
		if manche >= 28:
			sou_attendu = 6.0
		elif manche >= MANCHE_SOUVERAINE:
			sou_attendu = 2.0
		verifier_egal(anc, anc_attendu, "manche %d : poids ancestrale" % manche)
		verifier_egal(sou, sou_attendu, "manche %d : poids souveraine" % manche)


func test_les_raretes_actuelles_gardent_leurs_poids() -> void:
	var table: Array = _reel.boutique["poids"]
	for manche: int in POIDS_ANCIENS:
		var attendus: Array = POIDS_ANCIENS[manche]
		for i: int in 4:
			verifier_egal(
				_reel.palier(table, manche, NOMS[i]),
				attendus[i],
				"manche %d : %s" % [manche, NOMS[i]]
			)


func test_les_raretes_tardives_n_apparaissent_pas_avant_leur_manche() -> void:
	for graine: int in range(1, NB_GRAINES + 1):
		var b := Boutique.new(_fin, _rng(graine))
		for manche: int in range(1, MANCHE_SOUVERAINE):
			b.nouvelle_manche(manche, 0)
			for o: Dictionary in b.offres:
				var r := int(o["rarete"])
				verifier(
					r != Types.Rarete.SOUVERAINE,
					"graine %d, manche %d : souveraine trop tôt" % [graine, manche]
				)
				verifier(
					r != Types.Rarete.ANCESTRALE or manche >= MANCHE_ANCESTRALE,
					"graine %d, manche %d : ancestrale trop tôt" % [graine, manche]
				)


func test_chaque_rarete_est_atteignable() -> void:
	var vues: Dictionary = {}
	for graine: int in range(1, NB_GRAINES + 1):
		var b := Boutique.new(_fin, _rng(graine))
		b.nouvelle_manche(MANCHE_MAX, 0)
		for o: Dictionary in b.offres:
			vues[int(o["rarete"])] = true
		for _i: int in 5:
			b.relancer(_economie_riche(), 0)
			for o: Dictionary in b.offres:
				vues[int(o["rarete"])] = true
	for r: int in Types.Rarete.values():
		verifier(vues.has(r), "la rareté %s sort en boutique" % NOMS[r])


func _economie_riche() -> Economie:
	var e := Economie.new(_fin)
	e.argent = 1000000
	return e


func test_le_marche_noir_ne_propose_jamais_une_rarete_tardive() -> void:
	var b := Boutique.new(_fin, _rng(1))
	var choix := b.choix_marche_noir(_fin)
	verifier(not choix.is_empty(), "le marché noir propose des améliorations")
	for id: String in choix:
		var r := int((_fin.ameliorations[id] as Dictionary)["rarete"])
		verifier(r <= Types.Rarete.RARE, "%s : rareté %d au marché noir" % [id, r])
	verifier(not choix.has("amelio_test_ancestrale"), "pas d'ancestrale au marché noir")
	verifier(not choix.has("amelio_test_souveraine"), "pas de souveraine au marché noir")
	verifier_egal(
		str((_fin.boutique["marche_noir"] as Dictionary)["raretes_max"]), "rare", "plafond inchangé"
	)


func test_une_offre_tardive_passe_par_le_reseau() -> void:
	var catalogue := PackedStringArray(["arme_test_ancestrale", "arme_test_souveraine"])
	for r: int in Types.Rarete.values():
		var v := VueArene.new()
		v.offres = [
			{"id": catalogue[r % 2], "genre": 0, "rarete": r, "prix": 8000, "vendu": r % 2 == 0}
		]
		var octets := Protocole.encoder_etat_arene(v, catalogue)
		verifier(octets.size() > 0, "rareté %d : encodée" % r)
		var d := Protocole.decoder_etat_arene(octets, catalogue)
		verifier_non_nul(d, "rareté %d : décodée" % r)
		if d != null:
			verifier_egal(d.offres, v.offres, "rareté %d : l'offre revient telle quelle" % r)
	var hors := VueArene.new()
	hors.offres = [{"id": catalogue[0], "genre": 0, "rarete": 6, "prix": 1, "vendu": false}]
	verifier_egal(
		Protocole.encoder_etat_arene(hors, catalogue).size(), 0, "une rareté inconnue est refusée"
	)


func test_une_rarete_inconnue_recue_du_reseau_est_refusee() -> void:
	var catalogue := PackedStringArray(["arme_test_ancestrale"])
	var v := VueArene.new()
	v.offres = [{"id": catalogue[0], "genre": 0, "rarete": 0, "prix": 1, "vendu": false}]
	var base := Protocole.encoder_etat_arene(v, catalogue)
	v.offres[0]["rarete"] = Types.Rarete.SOUVERAINE
	var souveraine := Protocole.encoder_etat_arene(v, catalogue)
	var index := -1
	for i: int in base.size():
		if base[i] != souveraine[i]:
			index = i
			break
	verifier(index >= 0, "l'octet de rareté se repère")
	for inconnue: int in range(Types.NOMS_RARETES.size(), 8):
		var abime := base.duplicate()
		abime[index] = inconnue << 1
		verifier(
			Protocole.decoder_etat_arene(abime, catalogue) == null, "rareté %d refusée" % inconnue
		)
