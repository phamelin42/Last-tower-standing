extends CasDeTest
## La vitrine des armes (`tools/vitrines/vitrine_armes.tscn`) rejoue les six armes réelles dont Phil
## juge le rendu (D22), avec la signature que la simulation émet. Un agent qui la capture doit voir,
## dans chaque bande, un tir et un impact à chaque cycle.

const SCENE := "res://tools/vitrines/vitrine_armes.tscn"
const PAS := 1.0 / 60.0
## Trois périodes de tir, à 60 Hz.
const PAS_PAR_TEST: int = 216

var _vitrine: VitrineArmes = null
var _impacts: Dictionary = {}


func avant_chaque() -> void:
	var scene: PackedScene = load(SCENE)
	verifier_non_nul(scene, "la scène de la vitrine existe")
	_vitrine = scene.instantiate() as VitrineArmes
	arbre.root.add_child(_vitrine)
	_impacts = {}
	_vitrine.effets.impact_visible.connect(_noter_impact)


func apres_chaque() -> void:
	if is_instance_valid(_vitrine):
		_vitrine.free()
	_vitrine = null


func _noter_impact(ou: Vector2, _rayon: float, _fort: bool) -> void:
	var bande: int = VitrineArmes.bande_de(ou * Apparence.PX_PAR_UNITE)
	_impacts[bande] = int(_impacts.get(bande, 0)) + 1


func _jouer(pas: int) -> void:
	for i: int in pas:
		_vitrine.avancer(PAS)


func test_les_six_armes_sont_dans_l_ordre_demande() -> void:
	var attendu: Array[String] = [
		"canon_de_cloche",
		"orbe_de_brume",
		"bombarde_de_poche",
		"cornue_instable",
		"chaine_d_arcanes",
		"etincelle_runique",
	]
	verifier_egal(VitrineArmes.ARMES.size(), 6, "six armes")
	for i: int in attendu.size():
		verifier_egal(VitrineArmes.ARMES[i], attendu[i], "arme %d" % i)


func test_chaque_arme_existe_et_a_sa_signature() -> void:
	var donnees: Donnees = Donnees.charger()
	for id: String in VitrineArmes.ARMES:
		verifier(donnees.armes.has(id), "%s existe dans les données" % id)
		verifier(donnees.ids_catalogue.find(id) >= 0, "%s est au catalogue" % id)
		verifier(not SignaturesArmes.de(id).is_empty(), "%s a une signature" % id)
		var evenement: Dictionary = _vitrine.evenement_de(id, "tir")
		verifier_egal(
			evenement["arme"], donnees.ids_catalogue.find(id), "%s : index au catalogue" % id
		)
		verifier(typeof(evenement["genre"]) == TYPE_INT, "%s : genre en index" % id)
		verifier(typeof(evenement["statut"]) == TYPE_INT, "%s : statut en index" % id)
		var arme: Dictionary = donnees.armes[id]
		var effet: Dictionary = (arme["effets"] as Array)[0]
		verifier_egal(
			VueArene.GENRES_ARME[int(evenement["genre"])], String(effet["kind"]), "%s : genre" % id
		)
		verifier_egal(evenement["type_degats"], int(arme["type_degats"]), "%s : type" % id)


func test_chaque_bande_produit_un_effet_et_un_impact_visible() -> void:
	await attendre_images(2)
	_jouer(PAS_PAR_TEST)
	for bande: int in VitrineArmes.ARMES.size():
		var id: String = VitrineArmes.ARMES[bande]
		verifier(int(_vitrine.crees.get(id, 0)) > 0, "%s : un effet créé" % id)
		verifier(int(_impacts.get(bande, 0)) > 0, "%s : un impact visible" % id)


func test_le_rebond_saute_d_ennemi_en_ennemi_et_le_barrage_tire_plusieurs_fois() -> void:
	var rebond: Array[Dictionary] = _vitrine.evenements_du_cycle("chaine_d_arcanes")
	var impacts: int = 0
	for e: Dictionary in rebond:
		if e["k"] == "impact":
			impacts += 1
	verifier_egal(impacts, 1 + VitrineArmes.SAUTS_REBOND, "un impact par saut")
	var barrage: Array[Dictionary] = _vitrine.evenements_du_cycle("canon_de_cloche")
	impacts = 0
	for e: Dictionary in barrage:
		if e["k"] == "impact":
			impacts += 1
	verifier(impacts >= 3, "le barrage lance plusieurs projectiles")


func test_les_bandes_sont_decalees() -> void:
	verifier(VitrineArmes.DECALAGE > 0.0, "décalage positif")
	_jouer(1)
	verifier(_vitrine.effets.nombre_vivants() + _vitrine.effets.impacts_en_attente() > 0, "départ")
	var vues: int = 0
	for bande: int in VitrineArmes.ARMES.size():
		if int(_vitrine.crees.get(VitrineArmes.ARMES[bande], 0)) > 0:
			vues += 1
	verifier(vues < VitrineArmes.ARMES.size(), "toutes les bandes ne partent pas ensemble")


func test_le_plafond_des_effets_tient() -> void:
	_jouer(PAS_PAR_TEST * 2)
	verifier(_vitrine.pic_vivants > 0, "des effets ont vécu")
	verifier(_vitrine.pic_vivants <= Effets.PLAFOND, "vivants sous le plafond")
	verifier(_vitrine.effets.taille_pool() <= Effets.PLAFOND, "pool sous le plafond")


func test_mouvement_reduit_sans_recul() -> void:
	_vitrine.free()
	_vitrine = (load(SCENE) as PackedScene).instantiate() as VitrineArmes
	_vitrine.mouvement_reduit = true
	arbre.root.add_child(_vitrine)
	var recul_max: float = 0.0
	for i: int in PAS_PAR_TEST:
		_vitrine.avancer(PAS)
		verifier_egal(_vitrine.effets.gel_restant(), 0.0, "aucun gel")
		for id: int in _vitrine.ids_cibles():
			recul_max = maxf(recul_max, _vitrine.reactions.recul(id).length())
	verifier_egal(recul_max, 0.0, "les ennemis ne reculent pas")
