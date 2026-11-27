extends CasDeTest
## Garde-fous du catalogue complet (T9.22, lot 9) : la cible D18 reste tenue, chaque arme et chaque
## amélioration peut sortir à la boutique, et chaque arme a sa signature, son son, son image et sa
## description. Les tests propres à un fichier de données restent dans `test_catalogue_armes`,
## `test_catalogue_ameliorations` et `test_boutique` : celui-ci ne garde que les totaux.

const RARETES: Array[String] = ["commune", "peu_commune", "rare", "epique"]
## D18 : par type de dégâts, une commune, six peu communes, six rares, deux épiques.
const REPARTITION: Array[int] = [1, 6, 6, 2]
const ARMES_PAR_TYPE := 15
const ARMES_TOTAL := 75
const AMELIORATIONS_TOTAL := 87
## Fin de partie (D23) : 15 armes (T12.7) et 20 améliorations (T12.7b), au-dessus de l'épique.
const ARMES_TARDIVES := 15
const AMELIORATIONS_TARDIVES := 20
const MANCHE_MAX := 40
const GRAINES: Array[int] = [1, 7, 42]
const TIRAGES_PAR_MANCHE := 200

var _d: Donnees


func avant_chaque() -> void:
	_d = Donnees.charger()
	verifier_non_nul(_d, "les données réelles doivent se charger")


## Cinq types, quinze armes par type en 1 / 6 / 6 / 2, 75 armes et 87 améliorations de rareté
## jusqu'à l'épique : la cible de D18, qu'aucune passe d'équilibrage ne peut changer sans Phil.
## Les raretés de fin de partie (ancestrale, souveraine) s'y ajoutent sans la toucher.
func test_la_cible_d18_est_toujours_tenue() -> void:
	verifier_egal(Types.NOMS_TYPES.size(), 5, "cinq types de dégâts")
	verifier_egal(_d.armes.size() - _tardives(_d.armes), ARMES_TOTAL, "75 armes jusqu'à l'épique")
	verifier_egal(
		_d.ameliorations.size() - _tardives(_d.ameliorations),
		AMELIORATIONS_TOTAL,
		"87 améliorations jusqu'à l'épique"
	)
	verifier_egal(_tardives(_d.armes), ARMES_TARDIVES, "15 armes de fin de partie")
	verifier_egal(
		_tardives(_d.ameliorations), AMELIORATIONS_TARDIVES, "20 améliorations de fin de partie"
	)
	var comptes: Dictionary = {}
	for id: String in _d.armes:
		var arme: Dictionary = _d.armes[id]
		if int(arme["rarete"]) >= Types.Rarete.ANCESTRALE:
			continue
		var cle := (
			"%s/%s"
			% [Types.NOMS_TYPES[int(arme["type_degats"])], Types.NOMS_RARETES[int(arme["rarete"])]]
		)
		comptes[cle] = int(comptes.get(cle, 0)) + 1
	for type_degats: String in Types.NOMS_TYPES:
		var dans_le_type := 0
		for k: int in RARETES.size():
			var n := int(comptes.get("%s/%s" % [type_degats, RARETES[k]], 0))
			dans_le_type += n
			verifier_egal(n, REPARTITION[k], "%s : armes %s" % [type_degats, RARETES[k]])
		verifier_egal(dans_le_type, ARMES_PAR_TYPE, "%s : quinze armes" % type_degats)


## Le nombre d'objets d'un catalogue de rareté ancestrale ou souveraine.
func _tardives(catalogue: Dictionary) -> int:
	var n := 0
	for id: String in catalogue:
		if int((catalogue[id] as Dictionary)["rarete"]) >= Types.Rarete.ANCESTRALE:
			n += 1
	return n


## Une offre qui ne sortirait jamais est du contenu mort : à chaque graine, on tire à chaque manche
## de 1 à 40 et on retient les ids apparus. Les graines sont fixes ;
## l'union des trois suffit, une seule pouvant rater une rareté très rare.
func test_chaque_arme_et_chaque_amelioration_reste_proposable_a_une_manche() -> void:
	var vus: Dictionary = {}
	for graine: int in GRAINES:
		var rng := RandomNumberGenerator.new()
		rng.seed = graine
		var b := Boutique.new(_d, rng)
		for manche: int in range(1, MANCHE_MAX + 1):
			b.nouvelle_manche(manche, 0)
			for _i: int in TIRAGES_PAR_MANCHE:
				for offre: Dictionary in b.offres:
					var id := String(offre["id"])
					vus[id] = true
				b.tirer(manche)
	verifier_egal(
		_d.ids_catalogue.size(),
		ARMES_TOTAL + AMELIORATIONS_TOTAL + ARMES_TARDIVES + AMELIORATIONS_TARDIVES,
		"197 offres"
	)
	for id: String in _d.ids_catalogue:
		verifier(vus.has(id), "« %s » n'est jamais proposé de la manche 1 à 40" % id)


## Les quatre éléments qu'il faut à une arme pour être jouée de bout en bout : sa signature de
## tir, le fichier de son de son tir, l'image de sa case et une description complète.
func test_chaque_arme_du_catalogue_a_une_signature_un_son_une_image_et_une_description() -> void:
	for id: String in _d.armes:
		var arme: Dictionary = _d.armes[id]
		verifier_faux(SignaturesArmes.de(id).is_empty(), "%s : pas de signature" % id)
		var son := CatalogueSons.id_tir(id)
		verifier(CatalogueSons.tous().has(son), "%s : son %s absent du catalogue" % [id, son])
		verifier_faux(CatalogueSons.est_substitution(son), "%s : fichier de son manquant" % id)
		verifier(FileAccess.file_exists(CatalogueSons.chemin(son)), "%s : %s" % [id, son])
		verifier_faux(ImagesOffres.entree(id).is_empty(), "%s : pas d'image" % id)
		verifier(
			FileAccess.file_exists(ImagesOffres.chemin_case(id)), "%s : case non composée" % id
		)
		verifier(String(arme["description"]).length() > 10, "%s : description vide" % id)
		verifier(DescriptionOffre.est_complete(arme, Types.Genre.ARME), "%s : description" % id)
