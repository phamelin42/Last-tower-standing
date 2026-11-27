extends CasDeTest
## D23 (§6.17.2, Phil : « late game upgrade aussi ») : une amélioration ancestrale et une
## souveraine par famille des dix épiques, d'un effet 1,2 × et 1,5 × celui de l'épique, aux prix des
## raretés de fin de partie, sans jamais crever les plafonds. Les ids se lisent ici, les valeurs
## attendues se calculent depuis l'épique des données (ratios de Phil, jamais recopiés d'un code).

const RATIO_ANCESTRALE := 1.2
const RATIO_SOUVERAINE := 1.5
const PRIX_ANCESTRALE: Array[int] = [3000, 5000]
const PRIX_SOUVERAINE: Array[int] = [8000, 10000]
## épique → [ancestrale, souveraine].
const FAMILLES: Dictionary = {
	"couronne_de_rouages": ["balancier_des_ages", "cadran_souverain"],
	"engrenage_affole": ["rouage_des_tempetes", "volant_d_eternite"],
	"fonderie_de_pieces": ["forge_des_tresors", "tresor_du_royaume"],
	"meule_des_lames": ["affiloir_des_ages", "lame_du_souverain"],
	"carquois_des_siecles": ["carquois_des_legendes", "arc_du_souverain"],
	"chaire_des_arcanes": ["chaire_des_veilleurs", "grimoire_du_souverain"],
	"arsenal_des_remparts": ["bastion_des_machines", "arsenal_du_souverain"],
	"fracas_du_desordre": ["vacarme_des_ages", "tumulte_souverain"],
	"rempart_colossal": ["rempart_des_ages", "citadelle_souveraine"],
	"braise_de_phenix": ["cendre_des_ages", "flamme_souveraine"],
}

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _rarete(id: String) -> int:
	return int((d.ameliorations[id] as Dictionary)["rarete"])


func _effet(id: String) -> Dictionary:
	return ((d.ameliorations[id] as Dictionary)["effets"] as Array)[0]


func test_il_y_a_vingt_ameliorations_de_fin_de_partie_dix_par_rarete() -> void:
	verifier_egal(FAMILLES.size(), 10, "les dix familles des épiques")
	var anc := 0
	var sou := 0
	for id: String in d.ameliorations:
		match _rarete(id):
			Types.Rarete.ANCESTRALE:
				anc += 1
			Types.Rarete.SOUVERAINE:
				sou += 1
	verifier_egal(anc, 10, "ancestrales")
	verifier_egal(sou, 10, "souveraines")


func test_chaque_famille_a_son_ancestrale_et_sa_souveraine_aux_ratios_de_phil() -> void:
	for epique: String in FAMILLES:
		verifier(d.ameliorations.has(epique), epique)
		var e := _effet(epique)
		var ids: Array = FAMILLES[epique]
		var attendus: Array[float] = [RATIO_ANCESTRALE, RATIO_SOUVERAINE]
		var raretes: Array[int] = [Types.Rarete.ANCESTRALE, Types.Rarete.SOUVERAINE]
		for k: int in 2:
			var id: String = ids[k]
			verifier(d.ameliorations.has(id), id + " existe")
			if not d.ameliorations.has(id):
				continue
			verifier_egal(_rarete(id), raretes[k], id + " : rareté")
			var t := _effet(id)
			verifier_egal(t["stat"], e["stat"], id + " : même statistique")
			verifier_egal(
				(d.ameliorations[id] as Dictionary)["famille"],
				(d.ameliorations[epique] as Dictionary)["famille"],
				id + " : même famille"
			)
			verifier_proche(float(t["valeur"]), float(e["valeur"]) * attendus[k], 0.0001, id)
			for cle: String in ["type_degats", "categorie"]:
				verifier_egal(t.get(cle), e.get(cle), "%s : %s" % [id, cle])
			if e.has("par_arme_commune"):
				verifier_proche(
					float(t["par_arme_commune"]),
					float(e["par_arme_commune"]) * attendus[k],
					0.0001,
					id
				)


func test_les_prix_sont_dans_les_bandes_des_raretes_de_fin_de_partie() -> void:
	for epique: String in FAMILLES:
		var ids: Array = FAMILLES[epique]
		var bandes: Array = [PRIX_ANCESTRALE, PRIX_SOUVERAINE]
		for k: int in 2:
			var id: String = ids[k]
			if not d.ameliorations.has(id):
				verifier(false, id + " existe")
				continue
			var prix := int((d.ameliorations[id] as Dictionary)["prix"])
			var bande: Array = bandes[k]
			verifier(prix >= int(bande[0]) and prix <= int(bande[1]), "%s : %d or" % [id, prix])


func test_chaque_amelioration_tardive_a_un_nom_une_description_et_une_image_uniques() -> void:
	var noms: Dictionary = {}
	for epique: String in FAMILLES:
		for id: String in FAMILLES[epique]:
			if not d.ameliorations.has(id):
				verifier(false, id + " existe")
				continue
			var fiche: Dictionary = d.ameliorations[id]
			var nom: String = fiche["nom"]
			verifier(nom.length() > 2 and not noms.has(nom), "%s : nom « %s »" % [id, nom])
			noms[nom] = true
			verifier(String(fiche["description"]).length() > 10, id + " : description")
			verifier_faux(ImagesOffres.entree(id).is_empty(), id + " : une image")
			verifier(FileAccess.file_exists(ImagesOffres.chemin_case(id)), id + " : case composée")


func test_chaque_amelioration_tardive_est_offerte_a_partir_de_sa_manche_et_pas_avant() -> void:
	var vus: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261127
	for k: int in 600:
		var b := Boutique.new(d, rng)
		b.tirer(30)
		for o: Dictionary in b.offres:
			vus[str(o["id"])] = true
		var avant := Boutique.new(d, rng)
		avant.tirer(13 + (k % 8))
		for o: Dictionary in avant.offres:
			verifier(
				int(o["rarete"]) < Types.Rarete.SOUVERAINE or 13 + (k % 8) >= 22,
				"souveraine trop tôt"
			)
			verifier(
				int(o["rarete"]) != Types.Rarete.ANCESTRALE or 13 + (k % 8) >= 14,
				"ancestrale trop tôt"
			)
	for epique: String in FAMILLES:
		for id: String in FAMILLES[epique]:
			verifier(vus.has(id), "%s jamais offerte en manche 30 sur 600 tirages" % id)


func test_une_pile_d_ameliorations_tardives_reste_dans_les_plafonds() -> void:
	var a := Arene.new(d, 31)
	for epique: String in FAMILLES:
		for id: String in FAMILLES[epique]:
			for _k: int in 25:
				a.inventaire.ajouter(id)
	a.inventaire.ajouter("lame_de_fil")
	a.synchroniser()
	a.ennemis.ajouter(1, Vector2(100.0, 0.0), 1.0e12, 0.0, 0.0, 40.0, 1.0, 1, 4)
	for _i: int in 100:
		a.avancer(0.05)
	var vue := a.vue(Types.Phase.MANCHE, 10.0, -1, false)
	verifier(is_finite(vue.tour_pv) and vue.tour_pv <= vue.tour_pv_max, "PV bornés")
	verifier(is_finite(vue.revenu) and vue.revenu >= 0.0, "revenu fini")
	var stats := a.inventaire.stats()
	verifier(stats.resurrection > 0, "la résurrection s'empile")
	# La cadence totale d'une arme reste bornée par `niveaux.cadence_max`.
	verifier(a.armes[0].cadence_totale(stats) <= float(d.partie["niveaux"]["cadence_max"]) + 0.0001)
	var degats := 1.0e12 - a.ennemis.pv[0]
	var base := float((d.armes["lame_de_fil"] as Dictionary)["degats"])
	var facteur_max := float((d.partie["ameliorations"] as Dictionary)["facteur_degats_max"])
	verifier(degats > 0.0, "l'arme touche")
	# 100 pas de 50 ms, recharge 0,8 s à cadence maximale : au plus un coup par pas, critique
	# comprise (puissance de base de `partie.json`).
	var crit := float(d.partie["critique"]["puissance_base"]) * 4.0
	verifier(degats <= 100.0 * base * facteur_max * crit, "dégâts bornés par le plafond")
